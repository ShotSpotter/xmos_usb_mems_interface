
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
        // target is 124 dB SPL at 0 dBFS.
        case 0x0F:  // 15 decimal
            gain = 1;
            break;
        // Infineon IM72D128. This mic has 10 dB lower sensitivity than the VM3000
        // but SensApp will treat both boards as "Scepter3", so scale by 10^(10/20) = 3.162 => 3 as an int
        // target is 124 dB SPL at 0 dBFS.
        case 0x0E:  // 14 decimal
            gain = 3;
            break;
        // Primo EM215. This mic + amplifier chain has approximately 24 dB lower
        // sensitivity than the VM3000, but the board will be identified as Scepter3_HDR
        // target is 148 dB SPL at 0 dBFS.
        case 0x0C:  // 12 decimal
            gain = 1;
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
