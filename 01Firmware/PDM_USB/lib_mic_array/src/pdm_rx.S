// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
	.section	.dp.data,"awd",@progbits
	.text
        .extern		printf

.xtacommand "analyse endpoints pdm_rx_4ch_loop_ep pdm_rx_4ch_loop_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints pdm_rx_8ch_loop_ep pdm_rx_8ch_loop_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__

//This mapping accounts for the muddling of the unzips
//(do not change).
#define PIN0 0
#define PIN1 4
#define PIN2 2
#define PIN3 6
#define PIN4 1
#define PIN5 5
#define PIN6 3
#define PIN7 7

#include "mic_array_conf.h"

	//This mapping allows pins to be mapped to channels
#ifndef MIC_ARRAY_CH0
	#define MIC_ARRAY_CH0 PIN0
#endif
#ifndef MIC_ARRAY_CH1
	#define MIC_ARRAY_CH1 PIN1
#endif
#ifndef MIC_ARRAY_CH2
	#define MIC_ARRAY_CH2 PIN2
#endif
#ifndef MIC_ARRAY_CH3
	#define MIC_ARRAY_CH3 PIN3
#endif
#ifndef MIC_ARRAY_CH4
	#define MIC_ARRAY_CH4 PIN4
#endif
#ifndef MIC_ARRAY_CH5
	#define MIC_ARRAY_CH5 PIN5
#endif
#ifndef MIC_ARRAY_CH6
	#define MIC_ARRAY_CH6 PIN6
#endif
#ifndef MIC_ARRAY_CH7
	#define MIC_ARRAY_CH7 PIN7
#endif

#define S_IN_DATA			(0)
#define S_IN_DATA_DW_0			(0)
#define S_IN_DATA_DW_1			(1)
#define S_IN_DATA_DW_2			(2)
#define S_IN_DATA_DW_3			(3)
#define S_IN_DATA_DW_4			(4)
#define S_IN_DATA_DW_5			(5)
#define S_IN_DATA_SIZE  		(12)

#define S_CONTROL_VARIABLES 		(S_IN_DATA_SIZE)
#define S_IN_PORT			(0)
#define S_IMPULSE_INDEX			(1)
#define S_OUT_PORT_0			(2)
#define S_OUT_PORT_1			(3)
#define S_OUT_PORT_2			(4)
#define S_OUT_PORT_3			(5)
#define S_TEST_PATTERN_CACHE    (6)
#define S_CONTROL_VARIABLES_SIZE 	(12)

#define S_BUFFER			(S_CONTROL_VARIABLES + S_CONTROL_VARIABLES_SIZE)
#define S_BUFFER_SIZE			(1 << 12)
#define S_BUFFER_MASK			(S_BUFFER_SIZE - 1)
#define S_IMPULSE_PERIOD		(65536)

// you may define ONE of these to generate a test pattern
//#define OUTPUT_IMPULSE
//#define OUTPUT_SAWTOOTH

// Define 0 to 7 of these as desired to replace PDM input data with the test pattern.
//#define TEST_PATTERN_CH0
//#define TEST_PATTERN_CH1
//#define TEST_PATTERN_CH2
//#define TEST_PATTERN_CH3
//#define TEST_PATTERN_CH4
//#define TEST_PATTERN_CH5
//#define TEST_PATTERN_CH6
//#define TEST_PATTERN_CH7

// one-line, zero-cost-when-undefined override for each channel slot
#ifdef TEST_PATTERN_CH0
#define TEST_PATTERN_OVERRIDE_CH0 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH0
#endif
#ifdef TEST_PATTERN_CH1
#define TEST_PATTERN_OVERRIDE_CH1 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH1
#endif
#ifdef TEST_PATTERN_CH2
#define TEST_PATTERN_OVERRIDE_CH2 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH2
#endif
#ifdef TEST_PATTERN_CH3
#define TEST_PATTERN_OVERRIDE_CH3 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH3
#endif
#ifdef TEST_PATTERN_CH4
#define TEST_PATTERN_OVERRIDE_CH4 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH4
#endif
#ifdef TEST_PATTERN_CH5
#define TEST_PATTERN_OVERRIDE_CH5 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH5
#endif
#ifdef TEST_PATTERN_CH6
#define TEST_PATTERN_OVERRIDE_CH6 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH6
#endif
#ifdef TEST_PATTERN_CH7
#define TEST_PATTERN_OVERRIDE_CH7 ldw r3, r11[S_TEST_PATTERN_CACHE]
#else
#define TEST_PATTERN_OVERRIDE_CH7
#endif


#define STACKWORDS			(S_BUFFER + S_BUFFER_SIZE)

#define FIR_BLOCK(COEF)\
        {add r3, r3, r4; ld8u r4, r10[r9]};\
        {ldw r4, COEF[r4];add r9, r9, 8};\

#define FIR() \
        {ldc r3, 0; ldc r4, 0};\
        FIR_BLOCK(r5);\
	FIR_BLOCK(r6);\
	FIR_BLOCK(r7);\
	FIR_BLOCK(r7);\
	FIR_BLOCK(r6);\
	FIR_BLOCK(r5);\
        add r3, r3, r4

	.cc_top pdm_rx_asm.function
	.globl	pdm_rx_asm
	.align	4
	.type	pdm_rx_asm,@function
pdm_rx_asm:
        //r0 - in buffered port:32 p_pdm_mics,
        //r1 - streaming chanend c,
        //r2 - streaming chanend d,
        //r3 - streaming chanend e,
        //sp[1] - streaming chanend f,

	.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

        mov r4, r11

        ldaw r11, sp[S_CONTROL_VARIABLES]
	stw r0, r11[S_IN_PORT]
        stw r1, r11[S_OUT_PORT_0]
        stw r2, r11[S_OUT_PORT_1]
        stw r3, r11[S_OUT_PORT_2]
        stw r4, r11[S_OUT_PORT_3]
	// initialize S_IMPULSE_INDEX, S_TEST_PATTERN_CACHE
	ldc r0, 0
	stw r0, r11[S_IMPULSE_INDEX]
	stw r0, r11[S_TEST_PATTERN_CACHE]

	ldc r11, 0x5555
	shl r11, r11, 16; mov r9, r11
	add r11, r11, r9
        ldaw r10, sp[S_IN_DATA]
	std r11, r11, r10[S_IN_DATA_DW_0]
	std r11, r11, r10[S_IN_DATA_DW_1]
	std r11, r11, r10[S_IN_DATA_DW_2]
	std r11, r11, r10[S_IN_DATA_DW_3]
	std r11, r11, r10[S_IN_DATA_DW_4]
	std r11, r11, r10[S_IN_DATA_DW_5]

	ldaw r11, cp[g_first_stage_fir_0]
        mov r5, r11
	ldaw r11, cp[g_first_stage_fir_1]
        mov r6, r11
	ldaw r11, cp[g_first_stage_fir_2]
        mov r7, r11

	ldaw r10, sp[S_IN_DATA]

	.align 8

pdm_rx_8ch_loop:

	ldaw r11, sp[S_CONTROL_VARIABLES]

// These options generate test patterns
// OUTPUT_IMPULSE/OUTPUT_SAWTOOTH are mutually exclusive
#ifdef OUTPUT_IMPULSE
// Periodic impulse for filter frequency response analysis.
// Output injected at 384 kHz into stage 2 + stage 3 filters.
// FFT the captured output to see the complete magnitude response.

	ldw r4, r11[S_IMPULSE_INDEX]	// Load impulse counter
	add r4, r4, 1					// Increment counter
	ldc r3, S_IMPULSE_PERIOD-1		// Load period mask
	and r4, r4, r3					// Wrap counter to [0, PERIOD-1]
	stw r4, r11[S_IMPULSE_INDEX]	// Store updated counter
	eq r3, r4, 0					// r3 = 1 if counter==0, else 0
	neg r3, r3						// r3 = 0xFFFFFFFF if impulse, else 0
	shr r3, r3, 1					// r3 = 0x7FFFFFFF if impulse, else 0
	stw r3, r11[S_TEST_PATTERN_CACHE]  // store r3 so we can reuse
#endif

#ifdef OUTPUT_SAWTOOTH
// Sawtooth wave for general stage 2 + stage 3 debugging
// Output is 1 kHz sawtooth wave at 384 kHz sample rate

	ldw r4, r11[S_IMPULSE_INDEX]	// Load impulse counter
	ldc r3, 171						// Load increment value
	add r4, r4, r3					// Increment counter by 171 for ~1 kHz
	ldc r3, S_IMPULSE_PERIOD-1		// Load period mask
	and r4, r4, r3					// Wrap counter to [0, PERIOD-1]
	stw r4, r11[S_IMPULSE_INDEX]	// Store updated counter
	shl r3, r4, 16					// r3 = counter << 16 (sawtooth output)
	stw r3, r11[S_TEST_PATTERN_CACHE]  // store r3 so we can reuse
#endif

	ldw r3, r11[S_IN_PORT]
	in r4, res[r3]
	in r3, res[r3]
	unzip r3, r4, 2
	unzip r3, r4, 1
	unzip r3, r4, 0
	std r3, r4, r10[0]

	//
	// Map to output ports:          0, 2, 0, 2, 1, 3, 1, 3
	// so that mic sequence becomes: 0, 1, 2, 3, 4, 5, 6, 7
	//
	ldc r9, MIC_ARRAY_CH0
	FIR();						// FIR filter result is in r3
	TEST_PATTERN_OVERRIDE_CH0
	ldw r1, r11[S_OUT_PORT_0]			// Get first output port
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH4}
	FIR();						// FIR filter based on r9, result is in r3
	TEST_PATTERN_OVERRIDE_CH1
	ldw r1, r11[S_OUT_PORT_2]			// Get second output port
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH1}
	FIR();
	TEST_PATTERN_OVERRIDE_CH2
    ldw r1, r11[S_OUT_PORT_0]
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH5}
	FIR();
	TEST_PATTERN_OVERRIDE_CH3
	ldw r1, r11[S_OUT_PORT_2]
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH2}
	FIR();
	TEST_PATTERN_OVERRIDE_CH4
        ldw r1, r11[S_OUT_PORT_1]
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH6}
	FIR();
	TEST_PATTERN_OVERRIDE_CH5
	ldw r1, r11[S_OUT_PORT_3]
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH3}
	FIR();
	TEST_PATTERN_OVERRIDE_CH6
	ldw r1, r11[S_OUT_PORT_1]
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH7}
	FIR();							// CH7 FIR filter result is in r3
	// output is in r3; load on MIC_ARRAY_CH0 is a pointless
	// refill for next iteration (overwrtten in line 146)
	TEST_PATTERN_OVERRIDE_CH7
	ldw r1, r11[S_OUT_PORT_3]
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH0}

	ldd r3, r4, r10[4]
	std r3, r4, r10[5]

	ldd r3, r4, r10[3]
	std r3, r4, r10[4]

	ldd r3, r4, r10[2]
	{bitrev r3, r3; bitrev r4, r4}
	{byterev r3, r3; byterev r4, r4}
	std r3, r4, r10[3]

	ldd r3, r4, r10[1]
	std r3, r4, r10[2]

	ldd r3, r4, r10[0]
	std r3, r4, r10[1]
	bl pdm_rx_8ch_loop

.pdm_rx_asm_tmp:
	.size	pdm_rx_asm, .pdm_rx_asm_tmp-pdm_rx_asm
	.align	4
	.cc_bottom pdm_rx_asm.function

	.set	pdm_rx_asm.nstackwords, STACKWORDS
	.globl	pdm_rx_asm.nstackwords
	.set	pdm_rx_asm.maxcores,1
	.globl	pdm_rx_asm.maxcores
	.set	pdm_rx_asm.maxtimers,0
	.globl	pdm_rx_asm.maxtimers
	.set	pdm_rx_asm.maxchanends,0
	.globl	pdm_rx_asm.maxchanends

