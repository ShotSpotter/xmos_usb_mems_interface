
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
    switch(boardrev){
        // Vesper VM3000
        case 0x0F:  // 15 decimal
            gain = 1;
            break;
        // Infineon IM72D128
        case 0x0E:  // 14 decimal
            gain = 3;
            break;
        // Primo EM215
        case 0x0D:  // 13 decimal
            gain = 16;
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
    // Output must be negated to address a long-standing issue with XMOS firmware
    // in which it outputs inverse phase (positive pressure results in negative ouput.)
    // Negate the output here until the root cause can be identified and fixed.
    for(unsigned i=0; i<NUM_PDM_MICS; i++){
        output[i] = -(gain * audio->data[i][0]);
    }
}
