// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <stdint.h>

#if DEBUG_MIC_ARRAY
#include "xassert.h"
#include "xs2a_kernel.h"
#endif

extern void pdm_rx_asm(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_2x_pdm_mic_0,
        streaming chanend ?c_2x_pdm_mic_1,
        streaming chanend ?c_2x_pdm_mic_2,
        streaming chanend ?c_2x_pdm_mic_3);

void mic_array_pdm_rx(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_2x_pdm_mic_0,
        streaming chanend ?c_2x_pdm_mic_1,
        streaming chanend ?c_2x_pdm_mic_2,
        streaming chanend ?c_2x_pdm_mic_3){

#if DEBUG_MIC_ARRAY
    unsigned x;
    asm("mov %0, %1": "=r"(x):"r"(p_pdm_mics));
    x = XS1_RES_ID_PORTWIDTH(x);
    //This interface requires an 8-bit port
    if(x != 8)
        fail("Invalid port width of p_pdm_mics (PDM input ports)");
#endif

    //This will never return
    pdm_rx_asm(p_pdm_mics,
            c_2x_pdm_mic_0, c_2x_pdm_mic_1, c_2x_pdm_mic_2, c_2x_pdm_mic_3);
}
