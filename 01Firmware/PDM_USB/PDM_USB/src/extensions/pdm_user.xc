
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"
#ifdef DEBUG
#include <stdio.h>
#endif
#include "../core/customdefines.h"

unsigned gain = 1;

void user_pdm_init(int boardrev){
    /* Set digital gain based on board revision (4-bit fuse value 0-15) */
    // A factor of 2 digital gain is applied in SECOND_STAGE_TO_THIRD_STAGE_CH0(OFFSET)
    // (see 01Firmware/PDM_USB/lib_mic_array/src/decimate_to_pcm_cascade.S) between the
    // second and third stage filters, so the total digital gain applied is 2 * gain.
    switch(boardrev){
        // Vesper VM3000: AOP 122 dB SPL
        // target is 124 dB SPL at 0 dBFS.
        // See https://soundthinking.atlassian.net/browse/SAPP-639
        // 18 Aug 2026: Increase gain to 3 based on SAPP-664 (probably toque effect)
        case 0x0F:  // 15 decimal
            gain = 3;
            break;
        // Infineon IM72D128: AOP 128 dB SPL
        // This mic has 10 dB lower sensitivity than the VM3000 and 6 dB more range
        // but SensApp will treat both boards as "Scepter3", so scale by 10^(10/20) = 3.162 => 3 as an int
        // target is 128 dB SPL at 0 dBFS.
        // 18 Aug 2026: Increase gain to 11 based on SAPP-664 (probably toque effect)
        case 0x0E:  // 14 decimal
            gain = 9;
            break;
        // Primo EM215. This mic + amplifier chain has approximately 24 dB lower
        // sensitivity than the VM3000, but the board will be identified as Scepter3_HDR
        // target is 150 dB SPL at 0 dBFS.
        case 0x0C:  // 12 decimal
            gain = 4;
            break;
        default:
            gain = 1;
            break;
    }
#ifdef DEBUG
    printf("user_pdm_init(%d) set gain to %d\n", boardrev, gain);
#endif
}

unsafe void user_pdm_process(mic_array_frame_time_domain * unsafe audio, int output[]){
    // Sign flip removed after fixing issue with DC_OFFSET_REMOVAL macro in decimate_to_pcm_4ch.S
    for(unsigned i=0; i<NUM_PDM_MICS; i++){
        output[i] = gain * audio->data[i][0];
    }
}
