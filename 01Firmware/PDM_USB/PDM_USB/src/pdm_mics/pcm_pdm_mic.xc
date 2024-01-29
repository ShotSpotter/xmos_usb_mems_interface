#include "devicedefines.h"
#include "../core/customdefines.h"
#include "pcm_pdm_mic.h"

/* This file includes an example integration of lib_array_mic into USB Audio */

#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>

#include "mic_array.h"

#define MAX_DECIMATION_FACTOR 12

// Defines for mic_array_decimator_conf_common_t
#define DC_OFFSET_REMOVAL 0
#define INDEX_BIT_REVERSAL 0
#define WINDOWING_FUNCTION 0
#define MIC_GAIN_COMPENSATION 0
#define FIR_GAIN_COMPENSATION 0

/* Hardware resources */
in port p_pdm_clk                = PORT_PDM_CLK;
in port p_mclk                   = PORT_PDM_MCLK;
clock pdmclk                     = on tile[PDM_TILE]: XS1_CLKBLK_3;

// Mic input ports
in buffered port:32 p_pdm_mics_0_to_7   = PORT_PDM_DATA_0_to_7;

/* User hooks */
unsafe void user_pdm_process(mic_array_frame_time_domain * unsafe audio, int output[]);

mic_array_frame_time_domain mic_audio[MIC_ARRAY_DECIMATORS];

void pdm_process(streaming chanend c_ds_output[MIC_ARRAY_DECIMATORS], chanend c_audio)
{
    unsigned buffer = 1;     // Buffer index
    int output[NUM_PDM_MICS];

    while(1)
    {
        unsigned samplerate;

        c_audio :> samplerate;

        unsigned decimationfactor = 96000/samplerate;
        printf("decimationfactor: %d, samplerate: %d\n", decimationfactor, samplerate);

        unsafe
        {
            // FIR coefficients for different sample rates
            const int * unsafe fir_coefs[7] = {0, 0, 0, 0, 0, 0, 0};

            // General config for the decimator
            mic_array_decimator_conf_common_t dcc = {
                MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
                DC_OFFSET_REMOVAL,
                INDEX_BIT_REVERSAL,
                WINDOWING_FUNCTION,
                decimationfactor,
                fir_coefs[decimationfactor/2],
                MIC_GAIN_COMPENSATION,
                FIR_GAIN_COMPENSATION,
                DECIMATOR_NO_FRAME_OVERLAP,
                MIC_ARRAY_DECIMATORS
            };
            // Decimator specific config
            mic_array_decimator_config_t dc[MIC_ARRAY_DECIMATORS] = {
                                                                {&dcc, 0, {0, 0, 0, 0}, MIC_ARRAY_CHANS_PER_DECIMATOR}
                                                               ,{&dcc, 0, {0, 0, 0, 0}, MIC_ARRAY_CHANS_PER_DECIMATOR}
                                                               ,{&dcc, 0, {0, 0, 0, 0}, MIC_ARRAY_CHANS_PER_DECIMATOR}
                                                               ,{&dcc, 0, {0, 0, 0, 0}, MIC_ARRAY_CHANS_PER_DECIMATOR}
                                                               };

            mic_array_decimator_configure(c_ds_output, MIC_ARRAY_DECIMATORS, dc);

            mic_array_init_time_domain_frame(c_ds_output, MIC_ARRAY_DECIMATORS, buffer, mic_audio, dc);

            while(1)
            {
                mic_array_frame_time_domain * unsafe current = mic_array_get_next_time_domain_frame(c_ds_output, MIC_ARRAY_DECIMATORS,
                                                                                                buffer, mic_audio, dc);

                unsafe
                {
                    int req;
                    user_pdm_process(current, output);

                    c_audio :> req;

                    if(req)
                    {
                        for(int i = 0; i < NUM_PDM_MICS; i++)
                        {
                            //TODO: Multiply by -1 to compensate for false differential signaling
                            c_audio <: output[i];
                        }
                    }
                    else
                    {
                        break;
                    }
                }
            }
        }
    }
}

#if MAX_FREQ > 48000
#error MAX_FREQ > 48000 NOT CURRENTLY SUPPORTED
#endif

void pcm_pdm_mic(chanend c_pcm_out)
{
    streaming chan c_pdm_mic_0_to_1, c_pdm_mic_2_to_3;
    streaming chan c_pdm_mic_4_to_5, c_pdm_mic_6_to_7;
    streaming chan c_ds_output[MIC_ARRAY_DECIMATORS];

    /* Note, this divide should be based on master clock freq */
    configure_clock_src_divide(pdmclk, p_mclk, MCLK_48 / ( 2 * PDM_MIC_CLK));
    configure_port_clock_output(p_pdm_clk, pdmclk);

    //Mics 1 to 8
    configure_in_port(p_pdm_mics_0_to_7, pdmclk);
    start_clock(pdmclk);

    par
    {
        // Mics 1 to 8
        mic_array_pdm_rx(p_pdm_mics_0_to_7, c_pdm_mic_0_to_1, c_pdm_mic_2_to_3, c_pdm_mic_4_to_5, c_pdm_mic_6_to_7);
        mic_array_decimate_to_pcm_2ch(c_pdm_mic_0_to_1, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_2ch(c_pdm_mic_2_to_3, c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_2ch(c_pdm_mic_4_to_5, c_ds_output[2], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_2ch(c_pdm_mic_6_to_7, c_ds_output[3], MIC_ARRAY_NO_INTERNAL_CHANS);
        // Process decimated data
        pdm_process(c_ds_output, c_pcm_out);
    }
}
