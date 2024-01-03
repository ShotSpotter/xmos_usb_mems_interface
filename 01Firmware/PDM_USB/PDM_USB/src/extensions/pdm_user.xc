
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"
#include "../core/customdefines.h"

unsigned gain = -1;

unsafe void user_pdm_process(mic_array_frame_time_domain * unsafe audio, int output[]){
    /* Send individual mics (with gain applied) */
    for(unsigned i=0; i<NUM_PDM_MICS; i++){
        output[i] = gain * audio->data[i][0];
    }
}
