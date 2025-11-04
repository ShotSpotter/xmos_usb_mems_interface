
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"
#include "../core/customdefines.h"

unsigned gain = 1;

void user_pdm_init(int boardrev){
    /* Set digital gain based on board revision */
    switch(boardrev){
        // Vesper VM3000
        case 0xFF:
            gain = 1;
            break;
        // Infineon IM72D128
        case 0xFE:
            gain = 3;
            break;
        // Primo EM215
        case 0xFD:
            gain = 16;
            break;
        default:
            gain = 1;
            break;
    }
}

unsafe void user_pdm_process(mic_array_frame_time_domain * unsafe audio, int output[]){
    // Output must be negated to address a long-standing issue with XMOS firmware
    // in which it outputs inverse phase (positive pressure results in negative ouput.)
    // Negate the output here until the root cause can be identified and fixed.
    for(unsigned i=0; i<NUM_PDM_MICS; i++){
        output[i] = -(gain * audio->data[i][0]);
    }
}
