// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
    .section    .dp.data,"awd",@progbits
    .text

#include "mic_array_conf.h"

#ifndef MIC_ARRAY_MAX_FRAME_SIZE_LOG2
    #error MIC_ARRAY_MAX_FRAME_SIZE_LOG2 is not defined in mic_array_conf.h
#endif

#define SECOND_STAGE_COEF_COUNT         16
#define SECOND_STAGE_DOUBLE_TAP_COUNT   (SECOND_STAGE_COEF_COUNT / 2)
#define SECOND_STAGE_BUFFER_ENTRIES     64
#define SECOND_STAGE_BUFFER_SIZE        (SECOND_STAGE_BUFFER_ENTRIES * 2)

//
// Debug prints
//
//#define DEBUG_PRINT_1
//#define DEBUG_PRINT_2
//#define DEBUG_PRINT_3

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

#define S_UNUSED                        0	// Values are word (32 bit) offsets into S_STORAGE when data is held
#define S_C_INPUT                       4 
#define S_C_OUTPUT                      5 
#define S_CHAN_COUNT                    6

#define S_FAR_END_CHANNEL_0             7
#define S_FAR_END_CHANNEL_1             8	
#define S_FAR_END_CHANNEL_2             9 
#define S_FAR_END_CHANNEL_3             10
#define S_STORAGE_SIZE                  12

//
// S_SECOND_STAGE_DATA - Contains history of received from first fir filter so that second stage filter can be calculated
//
#define S_SECOND_STAGE_DATA             (S_STORAGE + S_STORAGE_SIZE)
#define S_SECOND_STAGE_DATA_SIZE        (SECOND_STAGE_BUFFER_SIZE * 4)        // 4 channels

//
// S_SECOND_STAGE - Control variables for second stage fir filter
//
#define S_SECOND_STAGE			(S_SECOND_STAGE_DATA + S_SECOND_STAGE_DATA_SIZE)
#define S_SECOND_STAGE_PHASE		0	// Values are word (32 bit) offsets into S_SECOND_STAGE where data is held
#define S_SECOND_STAGE_PHASE_COUNT	1
#define S_SECOND_STAGE_BUFFER_INDEX     2
#define S_SECOND_STAGE_SIZE		12

//
// S_OUTPUT_STORAGE - Location to store output values
//
#define S_OUTPUT_STORAGE                (S_SECOND_STAGE + S_SECOND_STAGE_SIZE)
//
// Add storage fields for output of second stage fir filter
// - stored in function divide_by_four
// - retrieved in output_phase
//
#define S_D_OUTPUT_STORAGE_0            0	// Values are word (32 bit) offsets into S_OUTPUT_STORAGE where data is held
#define S_D_OUTPUT_STORAGE_1            1
#define S_D_OUTPUT_STORAGE_2            2
#define S_D_OUTPUT_STORAGE_3            3
#define S_OUTPUT_STORAGE_SIZE           12

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
#define FRAME_STACK_SIZE                12

#define S_CONTROL_VARIABLES 		(S_FRAME_OFFSET + FRAME_STACK_SIZE)
#define S_BUFFER_INDEX  		(0)
#define S_COUNTER_1     		(1)
#define S_COUNTER_2     		(2)
#define S_R0            		(3)
#define S_R1            		(4)
#define S_R2            		(5)
#define S_R3           			(6)
#define S_R4           			(7)
#define S_R5           			(8)
#define S_R6           			(9)
#define S_DATA_VALUE			(10)
#define S_4CHAN_INDEX                   (11)
#define S_CONTROL_VARIABLES_SIZE 	(12)

#define S_BUFFER        		(S_CONTROL_VARIABLES + S_CONTROL_VARIABLES_SIZE)
#define S_BUFFER_SIZE   		(4096)
#define S_BUFFER_MASK   		(S_BUFFER_SIZE - 1)
#define S_COUNTER_MASK_1 		(0)
#define S_COUNTER_SIZE_1 		(1024)
#define S_COUNTER_MASK_2 		(S_COUNTER_SIZE_1 - 1)

#define STACKWORDS      		(S_BUFFER + S_BUFFER_SIZE + 16)

    .section .cp.rodata, "ac", @progbits
    .globl str3
    .cc_top str3.data, str3
    .align 4
str3:
    .asciiz "%d\n"
    .cc_bottom str3.data

    .globl str4
    .cc_top str4.data, str4
    .align 4
str4:
    .asciiz "---------------\n"
    .cc_bottom str4.data

    .globl    get_input_fir1_output_fir2
    .align    8
    .type    get_input_fir1_output_fir2,@function
    .cc_top get_input_fir1_output_fir2.function

    //
    // get_input_fir1_output_fir2
    // function to obtain input from fir1 filter and store data in double sized buffer
    // so that processing of the data is linear in the second stage fir calculation
    //
    // r7 - Control variables
    // r8 - r10[S_C_INPUT]
    // r9 - coefficient (SECOND_STAGE_BUFFER_ENTRIES - 1 to 0)
    // r11 - data pointer
    //
get_input_fir1_output_fir2:
    .cfi_startproc
    .issue_mode dual

    in r0, res[r8]				// Get data from fir1 filter - Channel 0
    add r1, r9, 0                               // Copy r9 (Coefficient) to r1 = Coefficient
    ldc r2, SECOND_STAGE_BUFFER_ENTRIES
    add r2, r2, r1                              // r2 = CoefficientCount + Coefficient
    stw r0, r11[r1]				// Store in two places so that fir2 filter can have linear access
    stw r0, r11[r2]
    stw r0, r7[S_DATA_VALUE]
    in r0, res[r8]				// Channel 1
    ldc r3, SECOND_STAGE_BUFFER_SIZE
    add r1, r1, r3                             // r1 = Coefficient + BufferSize
    add r2, r2, r3                             // r2 = CoefficientCount + Coefficient + BufferSize
    stw r0, r11[r1]
    stw r0, r11[r2]
    in r0, res[r8]			       // Channel 2
    add r1, r1, r3                             // r1 = Coefficient + BufferSize * 2
    add r2, r2, r3                             // r2 = CoefficientCount + Coefficient + BufferSize * 2
    stw r0, r11[r1]
    stw r0, r11[r2]
    in r0, res[r8]			       // Channel 3
    add r1, r1, r3                             // r1 = Coefficient + BufferSize * 3
    add r2, r2, r3                             // r2 = CoefficientCount + Coefficient + BufferSize * 3
    stw r0, r11[r1]
    stw r0, r11[r2]

    retsp 0

    .cc_bottom get_input_fir1_output_fir2.function
    .cfi_endproc

#define SAVE_SAMPLES_NORMAL(POINTER, N)\
    {ldc r5, 1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2)};\
    {add r7, r6, r5; ldw r8, r11[POINTER]};\
    {add r5, r5, r5};\
    stw r1, r8[r7];\
    stw r0, r8[r6];\
    {add r7, r7, r5; add r6, r6, r5};\
    stw r3, r8[r7];\
    stw r2, r8[r6]

    .globl    mic_array_decimate_to_pcm_4ch
    .align    8
    .type    mic_array_decimate_to_pcm_4ch,@function
    .cc_top mic_array_decimate_to_pcm_4ch.function
mic_array_decimate_to_pcm_4ch:
    .cfi_startproc
    .issue_mode dual

    DUALENTSP_lu6 STACKWORDS

    ldaw r10, sp[0]
    ldaw r3, r10[S_STORAGE]
    stw r0, r3[S_C_INPUT]
    stw r1, r3[S_C_OUTPUT]

    clre			// Stop events for this thread

    stw r2, r3[S_FAR_END_CHANNEL_0]
    stw r2, r3[S_FAR_END_CHANNEL_1]
    stw r2, r3[S_FAR_END_CHANNEL_2]
    stw r2, r3[S_FAR_END_CHANNEL_3]

internal_channel_setup_complete:
    outct res[r1], 8        // We say we are ready
    inct r2, res[r1]        // They say CONFIGURE_DECIMATOR
    //
    // Zero second stage data
    //
    ldc r1, S_SECOND_STAGE_DATA
    ldaw r0, r10[r1]
    ldc r1, S_SECOND_STAGE_DATA_SIZE
    bl zero_data_structure
    //
    // Zero second stage
    //
    ldc r1, S_SECOND_STAGE
    ldaw r0, r10[r1]
    ldc r1, S_SECOND_STAGE_SIZE
    bl zero_data_structure
    //
    // Zero output storage
    //
    ldc r1, S_OUTPUT_STORAGE
    ldaw r0, r10[r1]
    ldc r1, S_OUTPUT_STORAGE_SIZE
    bl zero_data_structure
    //
    // Zero data buffer
    //
    ldc r1, S_BUFFER
    ldaw r0, r10[r1]
    ldc r1, S_BUFFER_SIZE
    bl zero_data_structure
    //
    // Zero control variables
    //
    ldc r1, 0
    ldc r3, S_CONTROL_VARIABLES
    ldaw r11, r10[r3]
    stw r1, r11[S_BUFFER_INDEX]
    stw r1, r11[S_COUNTER_1]
    stw r1, r11[S_COUNTER_2]
    //
    // Set configuration values
    //
    ldc r3, S_FRAME_OFFSET
    ldaw r5, r10[r3]
    stw r1, r5[S_FRAME_NUMBER]      //and save the new frame number back
    //
    // Get configuration information
    //
    ldaw r5, r10[S_STORAGE]
    ldw r0, r5[S_C_OUTPUT]
    in r2, res[r0]        //decimator_config
    ldw r3, r2[0];        //r3 is the pointer to the decimator_config_common

    ldc r5, S_FRAME_OFFSET
    ldaw r0, r10[r5]
    ldw r11, r3[0]
    stw r11, r0[S_FRAME_SIZE_LOG2]

    ldw r11, r3[1]             // Set of 4 channels index
    ldc r4, S_CONTROL_VARIABLES;
    ldaw r5, r10[r4];
    stw r11, r5[S_4CHAN_INDEX]

    ldw r11, r3[4]             // decimation factor
    ldc r5, S_SECOND_STAGE
    ldaw r5, r10[r5]
    stw r11, r5[S_SECOND_STAGE_PHASE_COUNT]

    ldw r11, r2[6];            //channel count
    stw r11, r10[S_CHAN_COUNT]

init_frame_index:
    ldc r5, S_FRAME_OFFSET
    ldaw r11, r10[r5]
    ldc r1, 0
    stw r1, r11[S_FRAME_0_INDEX]

    ldw r1, r11[S_FRAME_SIZE_LOG2]
    {sub r1, r1, 1; ldc r5, 1}
    shl r1, r5, r1
    stw r1, r11[S_FRAME_1_INDEX]

get_frame_pointer:
    ldw r2, r10[S_C_OUTPUT]
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
    ldc r5, S_SECOND_STAGE
    ldaw r5, r10[r5]
    ldw r9, r5[S_SECOND_STAGE_PHASE_COUNT]
    sub r9, r9, 1
    stw r9, r5[S_SECOND_STAGE_PHASE]

confirm_init_complete:
    ldw r5, r10[S_C_OUTPUT]
    outct res[r5], 8 //WARNING: do not change this
    //
    // Setup counter for the processing loop
    //
    ldc r5, S_SECOND_STAGE
    ldaw r5, r10[r5]
    ldc r0, SECOND_STAGE_BUFFER_ENTRIES
    stw r0, r5[S_SECOND_STAGE_BUFFER_INDEX]

data_input_loop:
    //
    // Get values from stage 1 filter and put into stage 2 buffer for each channel
    //
    // r9 - coefficient (SECOND_STAGE_BUFFER_ENTRIES - 1 to 0)
    // r8 - r10[S_C_INPUT]
    // r11 - data pointer
    //
    ldc r5, S_SECOND_STAGE
    ldaw r5, r10[r5]
    ldw r9, r5[S_SECOND_STAGE_BUFFER_INDEX]      // Get CoefIndex and decrement
    sub r9, r9, 1
    stw r9, r5[S_SECOND_STAGE_BUFFER_INDEX]
    bt r9, updated_buffer_index
    ldc r0, SECOND_STAGE_BUFFER_ENTRIES
    stw r0, r5[S_SECOND_STAGE_BUFFER_INDEX]
updated_buffer_index:
    //
    // Get data and store in second stage buffer
    //
    ldw r8, r10[S_C_INPUT]
    ldc r11, S_SECOND_STAGE_DATA
    ldaw r11, r10[r11]
    ldc r7, S_CONTROL_VARIABLES
    ldaw r7, r10[r7]
    bl get_input_fir1_output_fir2               // Call input function
#ifdef DEBUG_PRINT_1
    //
    // Print data value -- debug -- data looks good here
    //
    ldc r7, S_CONTROL_VARIABLES
    ldaw r7, r10[r7]
    ldw r1, r7[S_4CHAN_INDEX]
    bt r1, dont_print_buffer1
    ldw r0, r7[S_DATA_VALUE]
    ldc r11, S_BUFFER
    ldaw r11, r10[r11]
    bl print_data_buffer
dont_print_buffer1:
#endif
    //
    // After every 4 iterations call post_process and divide_by_four
    // Compute iteration index modulo 4 into r1
    // Assumes r9 still holds index
    //
    ldc r0, 3
    and r1, r9, r0                              // coef_index mod4 is in r1
    //
    // Compute second stage fir filter
    //
    bt r1, after_divide_by_four                 // If r1 is zero call divide_by_four
    ldc r7, S_SECOND_STAGE_DATA
    ldaw r7, r10[r7]
    shl r0, r9, 2				// Multiply r9 by 4 and put into r0
    add r7, r7, r0				// Address of data
    bl divide_by_four

#ifdef DEBUG_PRINT_2
    ldc r5, S_OUTPUT_STORAGE
    ldaw r5, r10[r5]
    ldw r0, r5[S_D_OUTPUT_STORAGE_0]
    //
    // Print data value -- debug
    //
    ldc r7, S_CONTROL_VARIABLES
    ldaw r7, r10[r7]
    ldw r1, r7[S_4CHAN_INDEX]
    bt r1, dont_print_buffer2
    ldc r11, S_BUFFER
    ldaw r11, r10[r11]
    bl print_data_buffer
dont_print_buffer2:
#endif
    bu after_post_process
    //
    // Output results
    //
after_divide_by_four:
    ldc r0, 3
    and r1, r9, r0                              // coef_index mod4 is in r1
    eq r2, r1, 2                                // If r1 is 2 do post_process
    bf r2, after_post_process
    bu post_process                             // Call post process function

after_post_process:
    bu data_input_loop

    .cc_bottom mic_array_decimate_to_pcm_4ch.function
    .set    mic_array_decimate_to_pcm_4ch.nstackwords, STACKWORDS
    .globl  mic_array_decimate_to_pcm_4ch.nstackwords
    .set    mic_array_decimate_to_pcm_4ch.maxcores,1
    .globl  mic_array_decimate_to_pcm_4ch.maxcores
    .set    mic_array_decimate_to_pcm_4ch.maxtimers,0
    .globl  mic_array_decimate_to_pcm_4ch.maxtimers
    .set    mic_array_decimate_to_pcm_4ch.maxchanends,0
    .globl  mic_array_decimate_to_pcm_4ch.maxchanends
    .Lmic_array_decimate_to_pcm_4ch_tmp:
    .size    mic_array_decimate_to_pcm_4ch, .Lmic_array_decimate_to_pcm_4ch_tmp-mic_array_decimate_to_pcm_4ch
    .cfi_endproc

.globl    post_process
.align    8
.type    post_process,@function
.cc_top post_process.function
post_process:
    .cfi_startproc
    .issue_mode dual

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1

#ifdef DEBUG_PRINT_3
    ldc r11, S_OUTPUT_STORAGE;
    ldaw r11, r10[r11];
    //
    ldw r0, r11[S_D_OUTPUT_STORAGE_0];
    //
    // Print data value -- debug
    //
    ldc r7, S_CONTROL_VARIABLES
    ldaw r7, r10[r7]
    ldw r1, r7[S_4CHAN_INDEX]
    bt r1, dont_print_buffer3

    ldc r11, S_BUFFER
    ldaw r11, r10[r11]
    bl print_data_buffer
dont_print_buffer3:
#endif

    ldc r11, S_OUTPUT_STORAGE;
    ldaw r11, r10[r11];
    //
    ldw r0, r11[S_D_OUTPUT_STORAGE_0];
    ldw r1, r11[S_D_OUTPUT_STORAGE_1];
    ldw r2, r11[S_D_OUTPUT_STORAGE_2];
    ldw r3, r11[S_D_OUTPUT_STORAGE_3];

    ldc r11, S_FRAME_OFFSET
    ldaw r11, r10[r11]
    ldw r6, r11[S_FRAME_0_INDEX]
    SAVE_SAMPLES_NORMAL(S_FRAME_POINTER_0, 0);

    ldw r5, r11[S_FRAME_0_INDEX]
    add r5, r5, 1
    stw r5, r11[S_FRAME_0_INDEX]

    ldw r6, r11[S_FRAME_SIZE_LOG2]
    {shr r5, r5, r6; ldc r6, 0}
    bf r5, do_the_rest;

reset_the_frame_index:
    ldc r11, S_FRAME_OFFSET
    ldaw r11, r10[r11]
    stw r6, r11[S_FRAME_0_INDEX]

write_the_current_frames_metadata:
    ldw r5, r11[S_METADATA_POINTER_0]
    ldw r3, r11[S_FRAME_NUMBER]
    {stw r3, r5[4]; add r3, r3, 1}    //if metadata layout changes then this needs to change too
    stw r3, r11[S_FRAME_NUMBER]      //and save the new frame number back

exchange_buffers:
    ldw r6, r10[S_C_OUTPUT]
    outct res[r6], 8 //WARNING: do not change this
    inct r3, res[r6]

    eq r5, r3, EXCHANGE_BUFFERS        //if the incomming token is EXCHANGE_BUFFERS then do that
    bt r5, do_the_exchange
    bu after_post_process

do_the_exchange:
    {in r3, res[r6]; ldc r0, 0}
    {std r0, r3, r11[S_D_FRAME_POINTER_AND_INDEX_0]}

get_the_new_metadata_pointer:
    {in r3, res[r6]}
    {stw r3, r11[S_METADATA_POINTER_0]}
    std r0, r0, r3[0]    //set the frame sig bits to 0
    std r0, r0, r3[1]      //set the frame sig bits to 0

    ldw r0, r10[S_C_OUTPUT]
    outct res[r0], 8 //WARNING: do not change this

do_the_rest:
    bu after_post_process

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

    .globl    print_data_buffer
    .align    8
    .type     print_data_buffer,@function
    .cc_top   print_data_buffer.function

#define INCREMENT_COUNTER(COUNTER_INDEX, COUNTER_MASK) \
    ldw r4, r7[COUNTER_INDEX]; \
    add r4, r4, 1; \
    ldc r5, COUNTER_MASK; \
    and r4, r4, r5; \
    stw r4, r7[COUNTER_INDEX]

    //
    // r0 - data point
    // r7 - control variables
    // r10 - stack pointer
    // r11 - data buffer
    //
print_data_buffer:
    .cfi_startproc
    //
    // Update S_BUFFER_INDEX and store data point
    //
    INCREMENT_COUNTER(S_BUFFER_INDEX, S_BUFFER_MASK)
    stw r0, r11[r4]
    bt r4, print_buffer_end
    //
    // Print output buffer - save registers
    //
    stw r0, r7[S_R0]
    stw r1, r7[S_R1]
    stw r2, r7[S_R2]
    stw r3, r7[S_R3]
    stw r4, r7[S_R4]
    stw r5, r7[S_R5]
    stw r6, r7[S_R6]
    mov r5, r11
    //
    // Get data values
    //
    ldc r4, 0
printf_loop:
    ldaw r11, cp[str3]
    mov r0, r11
    ldw r1, r5[r4]		// Data
    bl printf
    add r4, r4, 1		// Increment index
    ldc r3, S_BUFFER_SIZE	// Compare with buffer size
    eq r6, r4, r3		
    bf r6, printf_loop
    //
    // Print trailer
    //
    ldaw r11, cp[str4]
    mov r0, r11
    bl printf
    //
    // Restore registers
    //
    mov r11, r5
    ldw r6, r7[S_R6]
    ldw r5, r7[S_R5]
    ldw r4, r7[S_R4]
    ldw r3, r7[S_R3]
    ldw r2, r7[S_R2]
    ldw r1, r7[S_R1]
    ldw r0, r7[S_R0]
print_buffer_end:
    set sp, r10
    retsp 0
    .cc_bottom print_data_buffer.function
    .cfi_endproc

    .globl    divide_by_four
    .align    8
    .type    divide_by_four,@function
    .cc_top divide_by_four.function
divide_by_four:
    .cfi_startproc
    .issue_mode dual

    dualentsp 1

#if SECOND_STAGE_COEF_COUNT == 16
    ldaw r11, cp[g_second_stage_fir16]
#elif SECOND_STAGE_COEF_COUNT == 32
    ldaw r11, cp[g_second_stage_fir32]
#elif SECOND_STAGE_COEF_COUNT == 48
    ldaw r11, cp[g_second_stage_fir48]
#elif SECOND_STAGE_COEF_COUNT == 64
    ldaw r11, cp[g_second_stage_fir64]
#endif
    //
    // r6 = Value to increment data pointer for next channel (bytes)
    //
    ldc r6, SECOND_STAGE_BUFFER_SIZE
    shl r6, r6, 2

    //
    // r11 = coefs, r7 = data, r6 = buffer length for each channel
    //
    bl mic_array_decimate_to_pcm_4ch_fir_taps
    add r7, r7, r6
    ldc r5, S_OUTPUT_STORAGE
    ldaw r5, r10[r5]
    stw r0, r5[S_D_OUTPUT_STORAGE_0]
    //

    bl mic_array_decimate_to_pcm_4ch_fir_taps
    add r7, r7, r6
    ldc r5, S_OUTPUT_STORAGE
    ldaw r5, r10[r5]
    stw r0, r5[S_D_OUTPUT_STORAGE_1]
    //

    bl mic_array_decimate_to_pcm_4ch_fir_taps
    add r7, r7, r6
    ldc r5, S_OUTPUT_STORAGE
    ldaw r5, r10[r5]
    stw r0, r5[S_D_OUTPUT_STORAGE_2]
    //

    bl mic_array_decimate_to_pcm_4ch_fir_taps
    add r7, r7, r6
    ldc r5, S_OUTPUT_STORAGE
    ldaw r5, r10[r5]
    stw r0, r5[S_D_OUTPUT_STORAGE_3]
    //

    retsp 1
    .cc_bottom divide_by_four.function
    .set    divide_by_four.nstackwords, 1
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

#define TAPS(DOUBLE_TAP_COUNT, TAP_INDEX)\
    ldc r8, TAP_INDEX;\
    ldd r3, r2, r11[r8];\
    ldd r5, r4, r7[r8];\
    maccs r0, r1, r4, r2;\
    maccs r0, r1, r5, r3;\
    ldc r8, DOUBLE_TAP_COUNT - 1 - TAP_INDEX;\
    ldd r5, r4, r7[r8];\
    maccs r0, r1, r4, r3;\
    maccs r0, r1, r5, r2;

    .globl    mic_array_decimate_to_pcm_4ch_fir_taps
    .align    8
    .type    mic_array_decimate_to_pcm_4ch_fir_taps,@function
    .cc_top mic_array_decimate_to_pcm_4ch_fir_taps.function
mic_array_decimate_to_pcm_4ch_fir_taps:
    .cfi_startproc
    .issue_mode dual

    //
    // Registers used r0, r1, r2, r3, r4, r5, r7, r8, r11
    // {r0, r1} Accumulated sum
    // {r2, r3} Data values
    // {r5, r4} Coefficients
    // r7 Pointer to coefficients
    // r8 Scratch register for TAP_INDEX
    // r11 Pointer to data
    //

    {ldc r0, 0; ldc r1, 0}      // Initialise the accumulators

    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 0);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 1);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 2);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 3);

#if SECOND_STAGE_COEF_COUNT >= 32
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 4);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 5);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 6);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 7);

#if SECOND_STAGE_COEF_COUNT >= 48
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 8);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 9);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 10);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 11);

#if SECOND_STAGE_COEF_COUNT >= 64
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 12);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 13);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 14);
    TAPS(SECOND_STAGE_DOUBLE_TAP_COUNT, 15);
#endif
#endif
#endif
    retsp 0
    .cc_bottom mic_array_decimate_to_pcm_4ch_fir_taps.function
    .cfi_endproc
