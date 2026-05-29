// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
	.section	.dp.data,"awd",@progbits
	.text

.xtacommand "analyse endpoints pdm_rx_4ch_loop_ep pdm_rx_4ch_loop_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints pdm_rx_8ch_loop_ep pdm_rx_8ch_loop_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__

#define temp_one 			 r0
#define c_one                r1
#define c_two                r2
#define a                 	 r3
#define b                 	 r4
#define fir0                 r5
#define fir1                 r6
#define fir2                 r7
#define temp_two             r8
#define c			     	 r9
#define p                 	 r10
#define t                 	 r11
#define temp_three           r11

#include "mic_array_conf.h"

#ifndef MIC_ARRAY_MUTE_CH_0
#define MIC_ARRAY_MUTE_CH_0 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_1
#define MIC_ARRAY_MUTE_CH_1 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_2
#define MIC_ARRAY_MUTE_CH_2 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_3
#define MIC_ARRAY_MUTE_CH_3 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_4
#define MIC_ARRAY_MUTE_CH_4 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_5
#define MIC_ARRAY_MUTE_CH_5 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_6
#define MIC_ARRAY_MUTE_CH_6 0
#endif
#ifndef MIC_ARRAY_MUTE_CH_7
#define MIC_ARRAY_MUTE_CH_7 0
#endif

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

// Stack slot 12 is unused in the 4.6.0 frame (slots 0-11 = input data,
// 14 = pdm_counter ptr, 15 = port). Reuse slot 12 for impulse counter.
#define S_IMPULSE_INDEX		12
#define S_IMPULSE_PERIOD	(65536)

//#define OUTPUT_IMPULSE
//#define OUTPUT_SAWTOOTH
//#define OUTPUT_RANDOM

#define STACKWORDS 16

#define FIR_BLOCK(P) \
	{ld8u b, p[c]; add a, a, b};\
	{ldw b, P[b];add c, c, 8};

#define FIR() \
	{ld8u a, p[c]; ldc b, 0};\
	{ldw a, fir0[a]; add c, c, 8};\
	FIR_BLOCK(fir1)\
	FIR_BLOCK(fir2)\
	FIR_BLOCK(fir2)\
	FIR_BLOCK(fir1)\
	FIR_BLOCK(fir0)\
	{add a, a, b; ldc b, 0}

#define OUTPUT(I, C)\
	{out res[C], a; ldc c, I}

.globl	pdm_rx_asm_debug
.align	8
.type	pdm_rx_asm_debug,@function
.cc_top pdm_rx_asm_debug.function
pdm_rx_asm_debug:
.cfi_startproc
.issue_mode dual
  bu pdm_rx_asm

	.cc_bottom pdm_rx_asm_debug.function
	.set	pdm_rx_asm_debug.nstackwords, 0 $M pdm_rx_asm.nstackwords
	.globl	pdm_rx_asm_debug.nstackwords
	.set	pdm_rx_asm_debug.maxcores, 1 $M pdm_rx_asm.maxcores
	.globl	pdm_rx_asm_debug.maxcores
	.set	pdm_rx_asm_debug.maxtimers,0
	.globl	pdm_rx_asm_debug.maxtimers
	.set	pdm_rx_asm_debug.maxchanends,0
	.globl	pdm_rx_asm_debug.maxchanends
.Lpdm_rx_asm_debug_tmp:
	.size	pdm_rx_asm_debug, .Lpdm_rx_asm_debug_tmp-pdm_rx_asm_debug
	.cfi_endproc

.cc_top pdm_rx_asm.function
.globl	pdm_rx_asm
.align	4
.type	pdm_rx_asm,@function
pdm_rx_asm://(
        //in buffered port:32 p_pdm_mics,
        //streaming chanend c,
        //streaming chanend ?d,

.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

	stw r0, sp[15]

#ifdef TEST_MODE
	ldc t, 0
#else
	ldc t, 0x5555
	shl t, t, 16; mov c, t
	add t, t, c
#endif
	std t, t, sp[0]
	std t, t, sp[1]
	std t, t, sp[2]
	std t, t, sp[3]
	std t, t, sp[4]
	std t, t, sp[5]

	ldaw t, cp[pdm_counter]
	stw t, sp[14]
	// Initialize impulse/debug counter to 0
	ldc r0, 0
	stw r0, sp[S_IMPULSE_INDEX]
	ldaw t, cp[g_first_stage_fir_0]
	mov fir0, t
	ldaw t, cp[g_first_stage_fir_1]
	mov fir1, t
	ldaw t, cp[g_first_stage_fir_2]
	mov fir2, t

	ldaw p, sp[0]

	ldc c,  MIC_ARRAY_CH0
	bt c_two, pdm_rx_8ch_loop

	ldc c,  MIC_ARRAY_CH0
	.align 8
pdm_rx_4ch_loop:

	ldd a, temp_one, sp[7]
	{in b, res[a];ldw t, temp_one[0]}
	{in a, res[a]; add t, t, 1}
#if USE_PDM_COUNTER
	stw t, temp_one[0]
#endif
	unzip a, b, 2
	unzip a, b, 1
	unzip a, b, 0
	std a, b, p[0]

	FIR();

#if MIC_ARRAY_MUTE_CH_0
	{out res[c_one], b; ldc c,MIC_ARRAY_CH1}
#else
	OUTPUT( MIC_ARRAY_CH1, c_one)	//output c_one
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_1
	{out res[c_one], b; ldc c, MIC_ARRAY_CH2}
#else
	OUTPUT( MIC_ARRAY_CH2, c_one)	//output c_one
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_2
	{ldc temp_one, 0; ldc c, MIC_ARRAY_CH3}
#else
	{mov temp_one, a; ldc c, MIC_ARRAY_CH3}
#endif

	FIR();

	{out res[c_one], temp_one}
#if MIC_ARRAY_MUTE_CH_3
	{out res[c_one], b; ldc c, MIC_ARRAY_CH0}
#else
	OUTPUT( MIC_ARRAY_CH0, c_one)	//output unused0 then this to c_one
#endif
	ldd a, b, p[4]
	std a, b, p[5]

	ldd a, b, p[3]
	std a, b, p[4]

	ldd a, b, p[2]
	{bitrev a, a; bitrev b, b}
	{byterev a, a; byterev b, b}
	std a, b, p[3]

	ldd a, b, p[1]
	std a, b, p[2]

	ldd a, b, p[0]
	std a, b, p[1]
	bl pdm_rx_4ch_loop
//2604ns per loop
	.align 8
pdm_rx_8ch_loop:
//about 6 inst spare without optimisation

	ldd a, temp_one, sp[7]
	{in b, res[a];ldw t, temp_one[0]}
	{in a, res[a]; add t, t, 1}
#if USE_PDM_COUNTER
	stw t, temp_one[0]
#endif
	unzip a, b, 2
	unzip a, b, 1
	unzip a, b, 0
	std a, b, p[0]

	FIR();

#if MIC_ARRAY_MUTE_CH_0
	{out res[c_one], b; ldc c, MIC_ARRAY_CH4}
#else
	OUTPUT( MIC_ARRAY_CH4, c_one)	//output c_one
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_4
	{out res[c_two], b; ldc c, MIC_ARRAY_CH1}
#else
	OUTPUT( MIC_ARRAY_CH1, c_two)	//output c_two
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_1
	{out res[c_one], b; ldc c, MIC_ARRAY_CH5}
#else
	OUTPUT( MIC_ARRAY_CH5, c_one)	//output c_one
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_5
	{out res[c_two], b; ldc c, MIC_ARRAY_CH2}
#else
	OUTPUT( MIC_ARRAY_CH2, c_two)	//output c_two
#endif
	FIR();

#if MIC_ARRAY_MUTE_CH_2
	{ldc temp_one, 0; ldc c,  MIC_ARRAY_CH6}
#else
	{mov temp_one, a; ldc c,  MIC_ARRAY_CH6}
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_6
	{ldc temp_two, 0; ldc c,  MIC_ARRAY_CH3}
#else
	{mov temp_two, a; ldc c,  MIC_ARRAY_CH3}
#endif

	FIR();

#if MIC_ARRAY_MUTE_CH_3
	{ldc temp_three, 0; ldc c,  MIC_ARRAY_CH7}
#else
	{mov temp_three, a; ldc c,  MIC_ARRAY_CH7}
#endif

	FIR();	// CH7 result in `a`

// These options replace CH7 with a debug pattern.
// OUTPUT_IMPULSE / OUTPUT_SAWTOOTH / OUTPUT_RANDOM are mutually exclusive.
// g_crc_constants must be defined (see fir_coefs.xc).
#ifdef OUTPUT_IMPULSE
// Periodic impulse for filter frequency response analysis.
	ldw b, sp[S_IMPULSE_INDEX]		// Load impulse counter
	add b, b, 1				// Increment counter
	ldc a, S_IMPULSE_PERIOD-1		// Load period mask
	and b, b, a				// Wrap counter to [0, PERIOD-1]
	stw b, sp[S_IMPULSE_INDEX]		// Store updated counter
	eq a, b, 0				// a = 1 if counter==0, else 0
	neg a, a				// a = 0xFFFFFFFF if impulse, else 0
	shr a, a, 1				// a = 0x7FFFFFFF if impulse, else 0
#endif

#ifdef OUTPUT_SAWTOOTH
// Sawtooth wave (~1 kHz) for frequency response analysis.
	ldw b, sp[S_IMPULSE_INDEX]		// Load counter
	ldc a, 171				// Increment (171/65536 * 48000 ≈ 125 Hz; adjust as needed)
	add b, b, a				// Increment counter
	ldc a, S_IMPULSE_PERIOD-1
	and b, b, a				// Wrap
	stw b, sp[S_IMPULSE_INDEX]
	shl a, b, 16				// a = sawtooth output
#endif

#ifdef OUTPUT_RANDOM
// White noise for frequency response analysis (deterministic CRC32-based).
	ldaw t, cp[g_crc_constants]		// t = &g_crc_constants
	ldw temp_two, t[1]			// temp_two = -1 (data to CRC)
	ldw b, t[0]				// b = 0xEDB88320 (polynomial)
	ldw a, sp[S_IMPULSE_INDEX]		// a = previous CRC state
	crc32 a, temp_two, b			// compute CRC; result in a
	stw a, sp[S_IMPULSE_INDEX]		// store updated state
#endif

	{out res[c_one], temp_one}

	{out res[c_two], temp_two}

	{out res[c_one], temp_three; ldc b, 0}

#if MIC_ARRAY_MUTE_CH_7
	{out res[c_two], b; ldc c, MIC_ARRAY_CH0}
#else
	OUTPUT( MIC_ARRAY_CH0, c_two)	// output a (CH7 or debug value)
#endif


	ldd a, b, p[4]
	std a, b, p[5]

	ldd a, b, p[3]
	std a, b, p[4]

	ldd a, b, p[2]
	{bitrev a, a; bitrev b, b}
	{byterev a, a; byterev b, b}
	std a, b, p[3]

	ldd a, b, p[1]
	std a, b, p[2]

	ldd a, b, p[0]
	std a, b, p[1]
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


#define EPT_MARCO(ID, PASS) \
.cc_top cc_a ## ID ## _ ## PASS,input_ ## ID ## _ ## PASS ;\
	.ascii	"";\
	.byte	0;\
	.long	0;\
	.long	input_ ## ID ## _ ## PASS;\
.cc_bottom cc_a ## ID ## _ ## PASS

	.section	.xtaendpoint,"",@progbits
.Lentries_start0:
	.long	.Lentries_end0-.Lentries_start0
	.long	1
	.ascii	""
    .byte	0

	.ascii	"pdm_rx_4ch_loop_ep"
	.byte	0
	.ascii	""
	.byte	0
	.long	0
	.long	.Laddr_end0 -.Laddr_start0
	.Laddr_start0:
	.cc_top cc_0 ,pdm_rx_4ch_loop
	.long	pdm_rx_4ch_loop
	.byte	0
	.cc_bottom cc_0
	.Laddr_end0 :

	.ascii	"pdm_rx_8ch_loop_ep"
	.byte	0
	.ascii	""
	.byte	0
	.long	0
	.long	.Laddr_end1 -.Laddr_start1
	.Laddr_start1:
	.cc_top cc_1 ,pdm_rx_8ch_loop
	.long	pdm_rx_8ch_loop
	.byte	0
	.cc_bottom cc_1
	.Laddr_end1 :
.Laddr_end9:

.Lentries_end0:

	.section	.xtaendpointtable,"",@progbits
.Lentries_start1:
	.long	.Lentries_end1-.Lentries_start1
	.long	0
	.ascii	""
	.byte	0

.cc_top cc_a0,pdm_rx_4ch_loop
	.ascii	""
	.byte	0
	.long	0
	.long	pdm_rx_4ch_loop
.cc_bottom cc_a0

.cc_top cc_a1,pdm_rx_8ch_loop
	.ascii	""
	.byte	0
	.long	0
	.long	pdm_rx_8ch_loop
.cc_bottom cc_a1


.Lentries_end1:

