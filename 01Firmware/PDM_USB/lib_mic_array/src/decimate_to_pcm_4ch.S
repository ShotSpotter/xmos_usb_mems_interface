// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
    .section    .dp.data,"awd",@progbits
    .text

#include "mic_array_conf.h"

#ifndef MIC_ARRAY_MAX_FRAME_SIZE_LOG2
    #error MIC_ARRAY_MAX_FRAME_SIZE_LOG2 is not defined in mic_array_conf.h
#endif

#ifndef MIC_ARRAY_DC_OFFSET_LOG2
        #define MIC_ARRAY_DC_OFFSET_LOG2 8
#endif

//
// Define critical frequency of third stage fir filter
// Only define ONE of the following values - default (if no defines used is 8kHz)
//
//#define THIRD_STAGE_8kHz
#define THIRD_STAGE_12kHz
//#define THIRD_STAGE_16kHz
//#define THIRD_STAGE_24kHz
//#define THIRD_STAGE_32kHz
//#define THIRD_STAGE_40kHz

#define SECOND_STAGE_COEF_COUNT         32
#define SECOND_STAGE_BUFFER_SIZE        (SECOND_STAGE_COEF_COUNT * 2)
#define SECOND_STAGE_HALF_FILTER_OFFSET (SECOND_STAGE_COEF_COUNT * 2)

#define THIRD_STAGE_COEF_COUNT         	32
#define THIRD_STAGE_BUFFER_SIZE        	(THIRD_STAGE_COEF_COUNT * 2)
#define THIRD_STAGE_HALF_FILTER_OFFSET 	(THIRD_STAGE_COEF_COUNT * 2)

//
// Stack layout
//
// All sizes are 32 bit words
//
//  S_STORAGE                       of S_STORAGE_SIZE 
//  S_SECOND_STAGE_DATA             of S_SECOND_STAGE_DATA_SIZE
//  S_SECOND_STAGE                  of S_SECOND_STAGE_SIZE
//  S_OUTPUT_STORAGE                of S_OUTPUT_STORAGE_SIZE
//

//
// S_STORAGE - Contains input and output channels
//
#define S_STORAGE                       0

#define S_UNUSED                        0
#define S_C_INPUT                       1
#define S_C_OUTPUT                      2

#define S_D_DC_OFFSET_LOG2_CH01		2

#define S_DC_OFFSET_LOG2_CH0    	4
#define S_DC_OFFSET_LOG2_CH1    	5

#define S_FAR_END_CHANNEL_0             10
#define S_FAR_END_CHANNEL_1             11
#define S_STORAGE_SIZE                  12

#define S_DC_ELIMINATE                  (S_STORAGE + S_STORAGE_SIZE)
#define S_PREV_X_0                      0
#define S_PREV_X_1                      1

#define S_D_PREV_X_01                   0
#define S_D_PREV_Y_0                    2
#define S_D_PREV_Y_1                    3
#define DC_ELIMINATE_STACK_SIZE         12

//
// S_SECOND_STAGE_DATA - Contains history of received from first fir filter so that second stage filter can be calculated
//
#define S_SECOND_STAGE_DATA             (S_DC_ELIMINATE + DC_ELIMINATE_STACK_SIZE)
#define S_SECOND_STAGE_DATA_SIZE        (SECOND_STAGE_COEF_COUNT * 2 * 2)        // word count 32 poles * 2 blocks * 2 channels

//
// S_SECOND_STAGE - Control variables for second stage fir filter
//
#define S_SECOND_STAGE			(S_SECOND_STAGE_DATA + S_SECOND_STAGE_DATA_SIZE)
#define S_SECOND_STAGE_PHASE		0
#define S_SECOND_STAGE_PHASE_COUNT	1
#define S_SECOND_STAGE_SIZE		8

//
// S_THIRD_STAGE_DATA - Contains history of received from first fir filter so that second stage filter can be calculated
//
#define S_THIRD_STAGE_DATA             (S_SECOND_STAGE + S_SECOND_STAGE_SIZE)
#define S_THIRD_STAGE_DATA_SIZE        (THIRD_STAGE_COEF_COUNT * 2 * 2)        // word count 32 poles * 2 blocks * 2 channels

//
// S_THIRD_STAGE - Control variables for second stage fir filter
//
#define S_THIRD_STAGE			(S_THIRD_STAGE_DATA + S_THIRD_STAGE_DATA_SIZE)
#define S_THIRD_STAGE_INDEX		0
#define S_THIRD_STAGE_SIZE		8

//
// S_OUTPUT_STORAGE - Location to store output values
//
#define S_OUTPUT_STORAGE                (S_THIRD_STAGE + S_THIRD_STAGE_SIZE)
//
// Add storage fields for output of second stage fir filter
// - stored in function divide_by_four
// - retrieved in output_phase
//
#define S_OUTPUT_STORAGE_0            	0
#define S_OUTPUT_STORAGE_1            	1
#define S_OUTPUT_0			2
#define S_D_OUTPUT_0			1
#define S_D_OUTPUT_1			2
#define S_D_OUTPUT_2			3
#define S_D_OUTPUT_3			4
#define S_D_OUTPUT_4			5
#define S_OUTPUT_STORAGE_SIZE           16 

//
// Frame - used to transfer output to calling process
//
#define S_FRAME_OFFSET                  (S_OUTPUT_STORAGE + S_OUTPUT_STORAGE_SIZE)
#define S_D_FRAME_POINTER_AND_INDEX_0   3
#define S_D_FRAME_POINTER_AND_INDEX_1   4
#define S_D_FRAME_NO_OVERLAPPING        1
#define S_D_METADATA_POINTERS           2
#define S_FRAME_SIZE_LOG2               1    //this is the current frame size log2
#define S_FRAME_NUMBER                  2    //should this be presistant between configs?
#define S_OVERLAPPING_FRAMES            3    //0 for on overlap, 1 for overlapping
#define S_METADATA_POINTER_0            4
#define S_METADATA_POINTER_1            5
#define S_FRAME_POINTER_0               6    //pointer to the current frame
#define S_FRAME_0_INDEX                 7    //index to write to the current frame
#define S_FRAME_POINTER_1               8    //pointer to the next frame
#define S_FRAME_1_INDEX                 9    //index to write to the next frame
#define FRAME_STACK_SIZE                16

#define S_SETTINGS_OFFSET		(S_FRAME_OFFSET + FRAME_STACK_SIZE)
#define S_DC_OFFSET_REMOVAL_ENABLED     2
#define S_SETTINGS_SIZE                 8

#define STACKWORDS                      (S_SETTINGS_OFFSET + S_SETTINGS_SIZE)

//This inputs from the channel to the pdm interface and saves it twice in the
//second stage FIR at offset OFFSET and OFFSET + SECOND_STAGE_COEF_COUNT
#define INPUT_TO_OFFSET(OFFSET)\
    ldw r1, sp[S_C_INPUT];\
    in r0, res[r1];\
    {stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
    {stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_COEF_COUNT + OFFSET]; in r0, res[r1]};\
    {stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
    {stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_COEF_COUNT + OFFSET]};

#define SAVE_SAMPLES_NORMAL(POINTER)\
    {ldc r5, 1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2)};\
    {add r7, r6, r5; ldw r8, r4[POINTER]};\
    {add r5, r5, r5};\
    stw r1, r8[r7];\
    stw r0, r8[r6];

#define FIR_POINT(FILTER_INDEX, DATA_INDEX_1, DATA_INDEX_2) \
    ldd r3, r2, r11[FILTER_INDEX]; \
    ldd r5, r4, r7[DATA_INDEX_1]; \
    maccs r0, r1, r4, r2; \
    maccs r0, r1, r5, r3; \
    ldd r5, r4, r8[DATA_INDEX_2]; \
    maccs r0, r1, r4, r3; \
    maccs r0, r1, r5, r2;

#define FIR_POINT_WORD() \
    ldw r4, r11[r2]; \
    ldw r5, r7[r2]; \
    maccs r0, r1, r5, r4; \
    ldw r5, r7[r3]; \
    maccs r0, r1, r5, r4; \
    add r2, r2, 1; \
    sub r3, r3, 1;

#define DC_OFFSET_REMOVAL(PREV_Y, PREV_X, REGISTER) \
    ldd r6, r5, r4[PREV_Y];\
    ldc r7, MIC_ARRAY_DC_OFFSET_LOG2;\
    ashr r9, r6, r7;\
    lextract r8, r6, r5, r7, 32;\
    lsub r11, r5, r5, r8, r4;\
    lsub r11, r6, r6, r9, r11;\
    {ldw r7, r4[PREV_X]};\
    ashr r9, REGISTER, 32;\
    ashr r10, r7, 32;\
    lsub r11, r8, REGISTER, r7, r4;\
    lsub r11, r9, r9, r10, r11;\
    {ldc r10, 16};\
    lextract r9, r9, r8, r10, 32;\
    {shl r8, r8, r10; stw REGISTER, r4[PREV_X]};\
    lsub r11, r5, r5, r8, r4;\
    lsub r11, r6, r6, r9, r11;\
    std r6, r5, r4[PREV_Y];\
    lextract REGISTER, r6, r5, r10, 32

    .globl    mic_array_decimate_to_pcm_2ch
    .align    8
    .type    mic_array_decimate_to_pcm_2ch,@function
    .cc_top mic_array_decimate_to_pcm_2ch.function
mic_array_decimate_to_pcm_2ch:
    .cfi_startproc
    .issue_mode dual

    DUALENTSP_lu6 STACKWORDS

    ldaw r3, sp[S_STORAGE]
    stw r0, r3[S_C_INPUT]
    stw r1, r3[S_C_OUTPUT]

    clre			// Stop events for this thread

    stw r2, sp[S_FAR_END_CHANNEL_0]
    stw r2, sp[S_FAR_END_CHANNEL_1]

internal_channel_setup_complete:
    //Set the dp to point to the data area for the second stage FIR
    ldaw dp, sp[S_SECOND_STAGE_DATA]

    outct res[r1], 8        // We say we are ready
    inct r2, res[r1]        // They say CONFIGURE_DECIMATOR

    //
    // Initialise the DC offset removal.
    //
    ldaw r0, sp[S_DC_ELIMINATE];
    ldc r1, 0
    std r1, r1, r0[S_D_PREV_X_01]
    std r1, r1, r0[S_D_PREV_Y_0]
    std r1, r1, r0[S_D_PREV_Y_1]

configure:
    DUALENTSP_lu6 0
    //
    // Zero second stage data
    //
    ldaw r0, sp[S_SECOND_STAGE_DATA]
    ldc r1, S_SECOND_STAGE_DATA_SIZE
    bl zero_data_structure
    //
    // Zero second stage
    //
    ldaw r0, sp[S_SECOND_STAGE]
    ldc r1, S_SECOND_STAGE_SIZE
    bl zero_data_structure
    //
    // Zero third stage data
    //
    ldaw r0, sp[S_THIRD_STAGE_DATA]
    ldc r1, S_THIRD_STAGE_DATA_SIZE
    bl zero_data_structure
    //
    // Zero third stage
    //
    ldaw r0, sp[S_THIRD_STAGE]
    ldc r1, S_THIRD_STAGE_SIZE
    bl zero_data_structure
    //
    // Zero output storage
    //
    ldaw r0, sp[S_OUTPUT_STORAGE]
    ldc r1, S_OUTPUT_STORAGE_SIZE
    bl zero_data_structure
    //
    // Zero dc eliminate area
    //
    ldaw r0, sp[S_DC_ELIMINATE]
    ldc r1, DC_ELIMINATE_STACK_SIZE
    bl zero_data_structure
    //
    // Set configuration values
    //
    ldc r3, 0
    ldaw r4, sp[S_FRAME_OFFSET]
    stw r3, r4[S_FRAME_NUMBER]      //and save the new frame number back
    //
    // Get configuration information
    //
    ldw r0, sp[S_C_OUTPUT]
    in r2, res[r0]        		//deciamtor_config
    ldw r3, r2[0];        		//r3 is the pointer to the decimator_config_common

    ldaw r0, sp[S_FRAME_OFFSET]
    ldw r11, r3[0]
    stw r11, r0[S_FRAME_SIZE_LOG2]

    ldaw r0, sp[S_SETTINGS_OFFSET]
    ldw r11, r3[1]			//apply_dc_offset
    stw r11, r0[S_DC_OFFSET_REMOVAL_ENABLED]

    ldw r11, r3[4]			// decimation factor
    ldaw r10, sp[S_SECOND_STAGE]
    stw r11, r10[S_SECOND_STAGE_PHASE_COUNT]

init_frame_index:
    ldaw r11, sp[S_FRAME_OFFSET]
    ldc r1, 0
    stw r1, r11[S_FRAME_0_INDEX]

    ldw r1, r11[S_FRAME_SIZE_LOG2]
    {sub r1, r1, 1; ldc r10, 1}
    shl r1, r10, r1
    stw r1, r11[S_FRAME_1_INDEX]

get_frame_pointer:
    ldw r2, sp[S_C_OUTPUT]
rx_buffer_count:
    in r5, res[r2]
    sub r5, r5, 1
    bt r5, overlapping

non_overlapping:
    {in r1, res[r2];stw r5, r11[S_OVERLAPPING_FRAMES]}
    {in r1, res[r2];stw r1, r11[S_FRAME_POINTER_0]}

saving_non_overlapping_metadata_pointer:
    {stw r1, r11[S_METADATA_POINTER_0];ldc r2, 0 }
    std r2, r2, r1[0]    //init the sig bits
    std r2, r2, r1[1]    //init the sig bits
    bu setup_phase_counters

overlapping:
    {in r1, res[r2];}
    {in r1, res[r2];stw r1, r11[S_FRAME_POINTER_1]}

saving_overlapping_metadata_pointer_1:
    {stw r1, r11[S_METADATA_POINTER_0]; ldc r3, 0}
    std r3, r3, r1[0]    //init the sig bits
    std r3, r3, r1[1]    //init the sig bits

    {in r1, res[r2];stw r5, r11[S_OVERLAPPING_FRAMES]}
    {in r1, res[r2];stw r1, r11[S_FRAME_POINTER_0]}

saving_overlapping_metadata_pointer_0:
    {stw r1, r11[S_METADATA_POINTER_1];ldc r2, 0 }
    std r2, r2, r1[0]    //init the sig bits
    std r2, r2, r1[1]    //init the sig bits

setup_phase_counters:
    ldaw r10, sp[S_SECOND_STAGE]
    ldw r9, r10[S_SECOND_STAGE_PHASE_COUNT]
    sub r9, r9, 1
    stw r9, r10[S_SECOND_STAGE_PHASE]

confirm_init_complete:
    ldw r4, sp[S_C_OUTPUT]
    outct res[r4], 8 //WARNING: do not change this

input_0_0:
    INPUT_TO_OFFSET(31)
    INPUT_TO_OFFSET(30)
    bl third_stage
    INPUT_TO_OFFSET(29)
    bl post_process
    INPUT_TO_OFFSET(28)
    ldaw r7, dp[28]
    bl divide_by_four

    INPUT_TO_OFFSET(27)
    INPUT_TO_OFFSET(26)
    bl third_stage
    INPUT_TO_OFFSET(25)
    bl post_process
    INPUT_TO_OFFSET(24)
    ldaw r7, dp[24]
    bl divide_by_four

    INPUT_TO_OFFSET(23)
    INPUT_TO_OFFSET(22)
    bl third_stage
    INPUT_TO_OFFSET(21)
    bl post_process
    INPUT_TO_OFFSET(20)
    ldaw r7, dp[20]
    bl divide_by_four

    INPUT_TO_OFFSET(19)
    INPUT_TO_OFFSET(18)
    bl third_stage
    INPUT_TO_OFFSET(17)
    bl post_process
    INPUT_TO_OFFSET(16)
    ldaw r7, dp[16]
    bl divide_by_four

    INPUT_TO_OFFSET(15)
    INPUT_TO_OFFSET(14)
    bl third_stage
    INPUT_TO_OFFSET(13)
    bl post_process
    INPUT_TO_OFFSET(12)
    ldaw r7, dp[12]
    bl divide_by_four

    INPUT_TO_OFFSET(11)
    INPUT_TO_OFFSET(10)
    bl third_stage
    INPUT_TO_OFFSET(9)
    bl post_process
    INPUT_TO_OFFSET(8)
    ldaw r7, dp[8]
    bl divide_by_four

    INPUT_TO_OFFSET(7)
    INPUT_TO_OFFSET(6)
    bl third_stage
    INPUT_TO_OFFSET(5)
    bl post_process
    INPUT_TO_OFFSET(4)
    ldaw r7, dp[4]
    bl divide_by_four

    INPUT_TO_OFFSET(3)
    INPUT_TO_OFFSET(2)
    bl third_stage
    INPUT_TO_OFFSET(1)
    bl post_process
    INPUT_TO_OFFSET(0)
    ldaw r7, dp[0]
    bl divide_by_four
    bu input_0_0

    .cc_bottom mic_array_decimate_to_pcm_2ch.function
    .set    mic_array_decimate_to_pcm_2ch.nstackwords, STACKWORDS
    .globl  mic_array_decimate_to_pcm_2ch.nstackwords
    .set    mic_array_decimate_to_pcm_2ch.maxcores,1
    .globl  mic_array_decimate_to_pcm_2ch.maxcores
    .set    mic_array_decimate_to_pcm_2ch.maxtimers,0
    .globl  mic_array_decimate_to_pcm_2ch.maxtimers
    .set    mic_array_decimate_to_pcm_2ch.maxchanends,0
    .globl  mic_array_decimate_to_pcm_2ch.maxchanends

.Lmic_array_decimate_to_pcm_2ch_tmp:
    .size    mic_array_decimate_to_pcm_2ch, .Lmic_array_decimate_to_pcm_2ch_tmp-mic_array_decimate_to_pcm_2ch
    .cfi_endproc

.globl    post_process
.align    8
.type    post_process,@function
.cc_top post_process.function
post_process:
    .cfi_startproc
    .issue_mode dual

    //increment SECOND_STAGE_PHASE mod SECOND_STAGE_PHASE_COUNT
    ldaw r11, sp[S_SECOND_STAGE]
    ldw r10, r11[S_SECOND_STAGE_PHASE];
    {add r9, r10, 1; ldw r8, r11[S_SECOND_STAGE_PHASE_COUNT]}
    {stw r9, r11[S_SECOND_STAGE_PHASE];eq r8, r8, r9}

    bt r8, output_phase        //do this on phase S_SECOND_STAGE_PHASE_COUNT-1 (last phase)
    retsp 0

output_phase:

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1

    ldaw r4, sp[S_OUTPUT_STORAGE];
    //
    ldw r0, r4[S_OUTPUT_STORAGE_0];
    ldw r1, r4[S_OUTPUT_STORAGE_1];

    //
    // DC offset removal
    //
    ldaw r4, sp[S_SETTINGS_OFFSET]
    ldw r4, r4[S_DC_OFFSET_REMOVAL_ENABLED]
    bf r4, dc_offset_removal_complete

    ldaw r4, sp[S_DC_ELIMINATE]
dc_offset_removal_ch0:
    DC_OFFSET_REMOVAL(S_D_PREV_Y_0, S_PREV_X_0, r0);
dc_offset_removal_ch1:
    DC_OFFSET_REMOVAL(S_D_PREV_Y_1, S_PREV_X_1, r1);
dc_offset_removal_complete:

    ldaw r4, sp[S_FRAME_OFFSET]
    ldw r6, r4[S_FRAME_0_INDEX]
    SAVE_SAMPLES_NORMAL(S_FRAME_POINTER_0);

    ldw r5, r4[S_FRAME_0_INDEX]
    add r5, r5, 1
    stw r5, r4[S_FRAME_0_INDEX]

    ldw r6, r4[S_FRAME_SIZE_LOG2]
    {shr r5, r5, r6; ldc r6, 0}
    bf r5, do_the_rest;

reset_the_frame_index:
    stw r6, r4[S_FRAME_0_INDEX]

write_the_current_frames_metadata:
    ldw r5, r4[S_METADATA_POINTER_0]
    ldw r3, r4[S_FRAME_NUMBER]
    {stw r3, r5[4]; add r3, r3, 1}    //if metadata layout changes then this needs to change too
    stw r3, r4[S_FRAME_NUMBER]      //and save the new frame number back

exchange_buffers:
    ldw r6, sp[S_C_OUTPUT]
    outct res[r6], 8 //WARNING: do not change this
    inct r3, res[r6]

    eq r5, r3, EXCHANGE_BUFFERS        //if the incomming token is EXCHANGE_BUFFERS then do that
    {bt r5, do_the_exchange; eq r5, r3, CONFIGURE_DECIMATOR}    //if the incomming token is CONFIGURE_DECIMATOR then do that

    ldap r11, configure
    stw r11, sp[0]
    ldw lr, sp[0]
    retsp 0

do_the_exchange:
    {in r3, res[r6]; ldc r0, 0}
    {std r0, r3, r4[S_D_FRAME_POINTER_AND_INDEX_0]}

get_the_new_metadata_pointer:
    {in r3, res[r6]}
    {stw r3, r4[S_METADATA_POINTER_0]}
    std r0, r0, r3[0]    //set the frame sig bits to 0
    std r0, r0, r3[1]    //set the frame sig bits to 0

    ldw r4, sp[S_C_OUTPUT]
    outct res[r4], 8 //WARNING: do not change this

do_the_rest:
    ldc r10, 0
    ldaw r11, sp[S_SECOND_STAGE]
    stw r10, r11[S_SECOND_STAGE_PHASE];

    retsp 0

.cc_bottom post_process.function
    .set    post_process.nstackwords, 0
    .globl    post_process.nstackwords
    .set    post_process.maxcores,1
    .globl    post_process.maxcores
    .set    post_process.maxtimers,0
    .globl    post_process.maxtimers
    .set    post_process.maxchanends,0
    .globl    post_process.maxchanends
.Lpost_process_tmp:
    .size    post_process, .Lpost_process_tmp-post_process
    .cfi_endproc

.globl    divide_by_four
.align    8
.type    divide_by_four,@function
.cc_top divide_by_four.function
divide_by_four:
    .cfi_startproc
    .issue_mode dual

    ldaw r10, sp[S_OUTPUT_STORAGE]
    //
    // This instruction changes sp so cannot reference sp directly for the remainder of this function
    //
    dualentsp 1
    //
    // Pointer to second stage fir filter coefficients
    //
    ldaw r11, cp[g_second_stage_fir32]
    //
    // Value to increment data pointer for next channel (bytes)
    //
    ldc r6, SECOND_STAGE_BUFFER_SIZE
    shl r6, r6, 2
    ldc r8, SECOND_STAGE_HALF_FILTER_OFFSET
    add r8, r7, r8

    // r11 = coefs, r7 = data, r6 = buffer length for each channel
    bl mic_array_decimate_to_pcm_2ch_fir_impl
    //
    // Store channel 0 output
    //
    stw r0, r10[S_OUTPUT_STORAGE_0]
    //
    add r7, r7, r6
    add r8, r8, r6
    bl mic_array_decimate_to_pcm_2ch_fir_impl
    //
    // Store channel 1 output
    //
    stw r0, r10[S_OUTPUT_STORAGE_1]
    //
    retsp 1
    .cc_bottom divide_by_four.function
    .set    divide_by_four.nstackwords,1
    .globl    divide_by_four.nstackwords
    .set    divide_by_four.maxcores,1
    .globl    divide_by_four.maxcores
    .set    divide_by_four.maxtimers,0
    .globl    divide_by_four.maxtimers
    .set    divide_by_four.maxchanends,0
    .globl    divide_by_four.maxchanends
.Ldivide_by_four_tmp:
    .size    divide_by_four, .Ldivide_by_four_tmp-divide_by_four
    .cfi_endproc

.globl    third_stage
.align    8
.type    third_stage,@function
.cc_top third_stage.function
third_stage:
    .cfi_startproc
    .issue_mode dual
    //
    // Load current values from output stage 2
    //
    ldaw r10, sp[S_OUTPUT_STORAGE]
    ldw r0, r10[S_OUTPUT_STORAGE_0]
    ldw r1, r10[S_OUTPUT_STORAGE_1]
    //
    // Store latest values in third stage buffer - reverse order
    //
    ldaw r11, sp[S_THIRD_STAGE]
    //
    // Compute and store new third stage index
    //
    ldw r2, r11[S_THIRD_STAGE_INDEX]
    sub r2, r2, 1
    ldc r3, (THIRD_STAGE_COEF_COUNT - 1)
    and r2, r2, r3
    stw r2, r11[S_THIRD_STAGE_INDEX]
    //
    // Store latest value for channel 0
    //
    ldaw r11, sp[S_THIRD_STAGE_DATA]
    stw r0, r11[r2]			// Store latest channel 0 value
    ldaw r7, r11[r2]			// Initial pointer to data in r7
    ldc r3, THIRD_STAGE_COEF_COUNT
    add r2, r2, r3			// Index second buffer
    stw r0, r11[r2]			// Store latest channel 0 value
    //
    // Store latest value for channel 1
    //
    add r2, r2, r3			// Index to channel 1 first buffer
    stw r1, r11[r2]			// Store latest channel 1 value
    add r2, r2, r3			// Index to second buffer
    stw r1, r11[r2]			// Store latest channel 1 value
    //
    // Now apply filter to data in third stage buffer at r7
    //
    // Pointer to fir filter coefficients
    //
#if defined(THIRD_STAGE_8kHz)
    ldaw r11, cp[g_third_stage_fir_8kHz]
#elif defined(THIRD_STAGE_12kHz)
    ldaw r11, cp[g_third_stage_fir_12kHz]
#elif defined(THIRD_STAGE_16kHz)
    ldaw r11, cp[g_third_stage_fir_16kHz]
#elif defined(THIRD_STAGE_24kHz)
    ldaw r11, cp[g_third_stage_fir_24kHz]
#elif defined(THIRD_STAGE_32kHz)
    ldaw r11, cp[g_third_stage_fir_32kHz]
#elif defined(THIRD_STAGE_40kHz)
    ldaw r11, cp[g_third_stage_fir_40kHz]
#else
    ldaw r11, cp[g_third_stage_fir_8kHz]
#endif
    //
    // Value to increment data pointer for next channel (bytes)
    //
    ldc r6, THIRD_STAGE_BUFFER_SIZE
    shl r6, r6, 2

    ldc r2, 0				// filter index and first half data index
    ldc r3, THIRD_STAGE_COEF_COUNT	// second half data index
    sub r3, r3, 1
    ldc r8, THIRD_STAGE_COEF_COUNT
    shr r8, r8, 1			// iteration count
    {ldc r0, 0; ldc r1, 0}		// accumulated sum
third_stage_loop1:
    FIR_POINT_WORD()
    sub r8, r8, 1
    bt r8, third_stage_loop1
    //
    // Store channel 0 output (overwrite second stage output value)
    //
    stw r0, r10[S_OUTPUT_STORAGE_0]
    //
    add r7, r7, r6		// r7 = data pointer, r6 = bytes to next channel's data

    ldc r2, 0				// filter index and first half data index
    ldc r3, THIRD_STAGE_COEF_COUNT	// second half data index
    sub r3, r3, 1
    ldc r8, THIRD_STAGE_COEF_COUNT
    shr r8, r8, 1			// iteration count
    {ldc r0, 0; ldc r1, 0}		// accumulated sum
third_stage_loop2:
    FIR_POINT_WORD()
    sub r8, r8, 1
    bt r8, third_stage_loop2
    //
    // Store channel 1 output (overwrite second stage output value)
    //
    stw r0, r10[S_OUTPUT_STORAGE_1]

    //
    retsp 0

    .cc_bottom third_stage.function
    .set    third_stage.nstackwords,0
    .globl    third_stage.nstackwords
    .set    third_stage.maxcores,1
    .globl    third_stage.maxcores
    .set    third_stage.maxtimers,0
    .globl    third_stage.maxtimers
    .set    third_stage.maxchanends,0
    .globl    third_stage.maxchanends
.Lthird_stage_tmp:
    .size    third_stage, .Lthird_stage_tmp-third_stage
    .cfi_endproc

    .globl    zero_data_structure
    .align    8
    .type     zero_data_structure,@function
    .cc_top   zero_data_structure.function

//
// r0 - Address to be zeroed
// r1 - Words to zero
//
zero_data_structure:
    .cfi_startproc

    ldc r2, 0                 // Zero register
    ldc r3, 0                 // Index in data structure
zero_loop:
    stw r2, r0[r3]            // Zero data
    add r3, r3, 1             // Increment index
    eq r4, r3, r1             // Test for index equal to number of words
    bf r4, zero_loop

    retsp 0
    .cc_bottom zero_data_structure.function
    .cfi_endproc

.globl    mic_array_decimate_to_pcm_2ch_fir_impl
.align    8
.type    mic_array_decimate_to_pcm_2ch_fir_impl,@function
.cc_top mic_array_decimate_to_pcm_2ch_fir_impl.function
mic_array_decimate_to_pcm_2ch_fir_impl:
    .cfi_startproc
    .issue_mode dual

    //r0, r1, r2, r3, r4, r5, r7
    {ldc r0, 0; ldc r1, 0} //Initialise the accumulators

    FIR_POINT(0, 0, 7)
    FIR_POINT(1, 1, 6)
    FIR_POINT(2, 2, 5)
    FIR_POINT(3, 3, 4)
    FIR_POINT(4, 4, 3)
    FIR_POINT(5, 5, 2)
    FIR_POINT(6, 6, 1)
    FIR_POINT(7, 7, 0)

    retsp 0
    .cc_bottom mic_array_decimate_to_pcm_2ch_fir_impl.function
    .set    mic_array_decimate_to_pcm_2ch_fir_impl.nstackwords, 0
    .globl    mic_array_decimate_to_pcm_2ch_fir_impl.nstackwords
    .set    mic_array_decimate_to_pcm_2ch_fir_impl.maxcores,1
    .globl    mic_array_decimate_to_pcm_2ch_fir_impl.maxcores
    .set    mic_array_decimate_to_pcm_2ch_fir_impl.maxtimers,0
    .globl    mic_array_decimate_to_pcm_2ch_fir_impl.maxtimers
    .set    mic_array_decimate_to_pcm_2ch_fir_impl.maxchanends,0
    .globl    mic_array_decimate_to_pcm_2ch_fir_impl.maxchanends
.Lmic_array_decimate_to_pcm_2ch_fir_impl_tmp:
    .size    mic_array_decimate_to_pcm_2ch_fir_impl, .Lmic_array_decimate_to_pcm_2ch_fir_impl_tmp-mic_array_decimate_to_pcm_2ch_fir_impl
    .cfi_endproc
