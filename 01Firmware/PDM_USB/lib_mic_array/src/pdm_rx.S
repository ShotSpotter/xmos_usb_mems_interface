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

//#define PRINT_BUFFER
//#define OUTPUT_SINE_WAVE

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
#define S_IN_DATA_SIZE  		(16)

#define S_CONTROL_VARIABLES 		(S_IN_DATA_SIZE)
#define S_IN_PORT			(0)
#define S_BUFFER_INDEX			(1)
#define S_COUNTER_1     		(2)
#define S_COUNTER_2			(3)
#define S_R0				(4)
#define S_R1				(5)
#define S_R2				(6)
#define S_R3				(7)
#define S_SINE_INDEX			(8)
#define S_CONTROL_VARIABLES_SIZE 	(16)

#define S_BUFFER			(S_CONTROL_VARIABLES + S_CONTROL_VARIABLES_SIZE)
#define S_BUFFER_SIZE			(1 << 12)
#define S_BUFFER_MASK			(S_BUFFER_SIZE - 1)
#define S_COUNTER_MASK_1 		((1 << 3) - 1)
#define S_COUNTER_MASK_2 		((1 << 7) - 1)
#define S_SINE_INDEX_MASK		((1 << 7) - 1)

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

#define INCREMENT_COUNTER(COUNTER_OFFSET, COUNTER_MASK) \
	ldaw r9, sp[S_CONTROL_VARIABLES]; \
        ldw r4, r9[COUNTER_OFFSET]; \
        add r4, r4, 1; \
        ldc r11, COUNTER_MASK; \
        and r4, r4, r11; \
        stw r4, r9[COUNTER_OFFSET]

	.section .cp.rodata, "ac", @progbits
	.globl str1
	.cc_top str1.data, str1
	.align 4
str1:
	.asciiz "%d\n"
        .cc_bottom str1.data

	.globl str2
	.cc_top str2.data, str2
	.align 4
str2:
	.asciiz "---------------\n"
        .cc_bottom str2.data

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
pdm_rx_asm:
        //r0 - in buffered port:32 p_pdm_mics,
        //r1 - streaming chanend c,
        //r2 - streaming chanend ?d,

	.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

        ldaw r11, sp[S_CONTROL_VARIABLES]
	stw r0, r11[S_IN_PORT]

#ifdef TEST_MODE
	ldc r11, 0
#else
	ldc r11, 0x5555
	shl r11, r11, 16; mov r9, r11
	add r11, r11, r9
#endif
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

#ifdef PRINT_BUFFER
        ldc r3, 0
	ldaw r10, sp[S_CONTROL_VARIABLES]
        stw r3, r10[S_BUFFER_INDEX];
        stw r3, r10[S_COUNTER_1];
        stw r3, r10[S_COUNTER_2];
        stw r3, r10[S_SINE_INDEX];

	ldaw r11, sp[S_BUFFER]
	ldc r4, S_BUFFER_SIZE
zero_buffer:
        sub r4, r4, 1
        stw r3, r11[r4]
        bt r4, zero_buffer
#endif

	ldaw r10, sp[S_IN_DATA]

	ldc r9, MIC_ARRAY_CH0
	bt r2, pdm_rx_8ch_loop

	ldc r9, MIC_ARRAY_CH0

	.align 8
pdm_rx_4ch_loop:

	ldaw r11, sp[S_CONTROL_VARIABLES]
	ldw r3, r11[S_IN_PORT]
	in r4, res[r3]
	in r3, res[r3]
	unzip r3, r4, 2
	unzip r3, r4, 1
	unzip r3, r4, 0
	std r3, r4, r10[0]

	FIR();
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH1}
	FIR();
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH2}
	FIR();
	{mov r0, r3; ldc r9, MIC_ARRAY_CH3}
	FIR();
	{out res[r1], r0}
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
	bl pdm_rx_4ch_loop
//2604ns per loop
	.align 8
pdm_rx_8ch_loop:
//about 6 inst spare without optimisation

	ldaw r11, sp[S_CONTROL_VARIABLES]
	ldw r3, r11[S_IN_PORT]
	in r4, res[r3]
	in r3, res[r3]
	unzip r3, r4, 2
	unzip r3, r4, 1
	unzip r3, r4, 0
	std r3, r4, r10[0]

	FIR();

#ifdef OUTPUT_SINE_WAVE
        INCREMENT_COUNTER(S_SINE_INDEX, S_SINE_INDEX_MASK)
	ldaw r11, cp[g_sine_wave3]
        ldw r3, r11[r4]
#endif

	{out res[r1], r3; ldc r9, MIC_ARRAY_CH4}
	FIR();
	{out res[r2], r3; ldc r9, MIC_ARRAY_CH1}
	FIR();
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH5}


#ifdef PRINT_BUFFER
        //
        // Update S_COUNTER_1
        //
        INCREMENT_COUNTER(S_COUNTER_1, S_COUNTER_MASK_1)
        bt r4, print_buffer_end
        //
        // Update S_BUFFER_INDEX and store data point
        //
        INCREMENT_COUNTER(S_BUFFER_INDEX, S_BUFFER_MASK)
        ldaw r11, sp[S_BUFFER]
        stw r3, r11[r4]
        bt r4, print_buffer_end
        //
        // Update S_COUNTER_2
        //
        INCREMENT_COUNTER(S_COUNTER_2, S_COUNTER_MASK_2)
        bt r4, print_buffer_end
        //
        // Print output buffer - save registers
        //
	ldaw r9, sp[S_CONTROL_VARIABLES]
        stw r0, r9[S_R0]
        stw r1, r9[S_R1]
        stw r2, r9[S_R2]
        stw r3, r9[S_R3]
        //
        // Get data values
        //
        ldc r9, 0
printf_loop:
        ldaw r11, sp[S_BUFFER]
        ldw r1, r11[r9]
        //
        // Print data in r1
        //
        ldaw r11, cp[str1]
        mov r0, r11
        bl printf
        add r9, r9, 1
        ldc r4, S_BUFFER_SIZE
        eq r11, r9, r4
        bf r11, printf_loop
        //
        // Print trailer
        //
        ldaw r11, cp[str2]
        mov r0, r11
        bl printf
        //
        // Restore registers
        //
	ldaw r9, sp[S_CONTROL_VARIABLES]
        ldw r3, r9[S_R3]
        ldw r2, r9[S_R2]
        ldw r1, r9[S_R1]
        ldw r0, r9[S_R0]

print_buffer_end:
	ldc r9, MIC_ARRAY_CH5
#endif

	FIR();

	{out res[r2], r3; ldc r9, MIC_ARRAY_CH2}
	FIR();
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH6}
	FIR();
	{out res[r2], r3; ldc r9, MIC_ARRAY_CH3}
	FIR();
	{out res[r1], r3; ldc r9, MIC_ARRAY_CH7}
        FIR();
	{out res[r2], r3; ldc r9, MIC_ARRAY_CH0}

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
