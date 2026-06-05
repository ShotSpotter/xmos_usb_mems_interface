// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
// Additional code by Richard Boulderstone and
// Robert B. Calhoun is Copyright (c) 2024-2025 SoundThinking Inc.
// Code not written by XMOS is released under the MIT License.
//
// Assembly-language implementation of decimate_to_pcm_cascade(),
// based on XMOS reference code. The reference code used FIR filters of
// inadequate size because of compute limitations and has an error in
// the DC offset calcuation. In this version, we run
// one decimator for every two channels instead of one decimator for
// every four channels, removing the compute limtation but limiting
// the total number of channels supported by a two-tile XMOS chip to 8.
// This provides sufficient MIPS for Type 1 and Type 2 filter with up to 48 taps.
//
// In thsi file, two 48-tap filters are set up as a cascade:
// - 384 kHz input -> second stage buffers -> second stage filter -> 2:1 decimation
// - second stage buffers -> second stage filter + 2:1 decimation
// - second stage filter + 2:1 decimation -> third stage buffer
// - third stage buffer -> third stage filter + 2:1 decimation
// - third stage filter + 2:1 decimation to output.
// The main processing code is unrolled to conserve registers and
// improve performance. To regenerate the components, see helper
// script lib_mic_array/src/fir/generate_filter_loop.py.
//
// See decimate_to_pcm_2cs.S for a simpler version of this code that
// still supports Type I and Type II FIR filters but does not use a cascaded design.

// The filters used are defined by at runtime by hardware fuses that
// are passed into this code via the boardrev argument. Hardware uses
// 4-bit fuses (0-15). Currently, three boardrev values are defined:
// 0x0F (15) 7-mic board with Vesper VM3000 digital microphone     (resonance ~12.5 kHz => 10 kHz pass, 20 kHz stop)
// 0x0E (14) 7-mic board with Infineon IM72D128 digital microphone (resonance ~37 kHz   => 12 kHz pass, 24 kHz stop)
// 0x0D (13) unused
// 0x0C (12) 8-mic board with Primo EM215 analog mic + PDM ADC     (high as possible    => 40 kHz pass, 48 kHz stop)

// If runtime filter selection is not required, the jump tables can
// be removed.

.section    .dp.data,"awd",@progbits
.text

#include "mic_array_conf.h"

#ifndef MIC_ARRAY_MAX_FRAME_SIZE_LOG2
    #error MIC_ARRAY_MAX_FRAME_SIZE_LOG2 is not defined in mic_array_conf.h
#endif

#ifndef MIC_ARRAY_DC_OFFSET_LOG2
        #define MIC_ARRAY_DC_OFFSET_LOG2 8
#endif

// We implement Type 1 (odd # of tap) filters with a final zero pad, so they also
// have an "even" number of taps from the software perspective. Use "32" for 31 taps + pad.
// Supportable tap sizes as 32, 36, 40, 44, 48, but right now the code is set up for 47 + 1 pad = 48.

#define SECOND_STAGE_TAPS 48                                                                        // Number of coefficient/taps in the whole (symmetric) filter. In words.
#define SECOND_STAGE_HISTORY_SIZE              (((SECOND_STAGE_TAPS + 3) / 4) * 4)                  // Enforce SECOND_STAGE_HISTORY_SIZE >= SECOND_STAGE_TAPS and is a multiple of 4. In words.
#define SECOND_STAGE_BUFFER_SIZE               (SECOND_STAGE_HISTORY_SIZE * 2)                      // We need 2x SECOND_STAGE_HISTORY_SIZE for the circular buffer. In words.
#define SECOND_STAGE_ALL_CHANNELS_SIZE         (SECOND_STAGE_BUFFER_SIZE * 2)                       // Total size of second stage storage. In words.
#define SECOND_STAGE_MIDPOINT_BYTES        ((SECOND_STAGE_TAPS / 2) * 4)                        // offset of the right pointer (r8), in bytes.

#define THIRD_STAGE_TAPS 48                                                               // Number of coefficient/taps in the whole (symmetric) filter. In words.
#define THIRD_STAGE_HISTORY_SIZE              (((THIRD_STAGE_TAPS + 3) / 4) * 4)          // Enforce THIRD_STAGE_HISTORY_SIZE >= THIRD_STAGE_TAPS and is a multiple of 4. In words.
#define THIRD_STAGE_BUFFER_SIZE               (THIRD_STAGE_HISTORY_SIZE * 2)              // We need 2x THIRD_STAGE_HISTORY_SIZE for the circular buffer. In words.
#define THIRD_STAGE_ALL_CHANNELS_SIZE         (THIRD_STAGE_BUFFER_SIZE * 2)               // Total size of third stage storage. In words.
#define THIRD_STAGE_MIDPOINT_BYTES        ((THIRD_STAGE_TAPS / 2) * 4)                // offset of the right pointer (r8), in bytes.

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
#define S_BOARDREV                      3

#define S_D_DC_OFFSET_LOG2_CH01		2

#define S_DC_OFFSET_LOG2_CH0    	4
#define S_DC_OFFSET_LOG2_CH1    	5

#define S_FAR_END_CHANNEL_0             10
#define S_FAR_END_CHANNEL_1             11
#define S_STORAGE_SIZE                  12

#define S_DC_ELIMINATE                  (S_STORAGE + S_STORAGE_SIZE)
#define S_D_PREV_X_01                   0
#define S_PREV_X_0                      0
#define S_PREV_X_1                      1

#define S_D_PREV_Y_01                   2
#define S_D_PREV_Y_0                    2
#define S_D_PREV_Y_1                    3

#define DC_ELIMINATE_STACK_SIZE         12

// place second and third stage buffers directly next to each other so we can reference them via dp[u16]
//
// S_SECOND_STAGE_DATA - circular buffer 2 x filter size of data received from input
//
#define S_SECOND_STAGE_DATA             (S_DC_ELIMINATE + DC_ELIMINATE_STACK_SIZE) // <---- this is dp[0]!!
#define S_SECOND_STAGE_DATA_SIZE        (SECOND_STAGE_ALL_CHANNELS_SIZE)        // num taps * 2 copies * 2 channels. In words.

// S_THIRD_STAGE_DATA -  circular buffer 2 x filter size of data received from second sage
#define S_THIRD_STAGE_DATA              (S_SECOND_STAGE_DATA + S_SECOND_STAGE_DATA_SIZE)
#define S_THIRD_STAGE_DATA_SIZE         (THIRD_STAGE_ALL_CHANNELS_SIZE)        // num taps * 2 copies * 2 channels. In words.

// We set dp[0] to the address of the start of the second stage data. dp[u16] loads index in WORDS
// relative that. These four offsets are "relative words from start of second stage data"
#define DP_STAGE_2_CH0             (0)
#define DP_STAGE_2_CH1             (0 + SECOND_STAGE_BUFFER_SIZE)
#define DP_STAGE_3_CH0             (SECOND_STAGE_ALL_CHANNELS_SIZE)
#define DP_STAGE_3_CH1             (SECOND_STAGE_ALL_CHANNELS_SIZE + THIRD_STAGE_BUFFER_SIZE)



//
// S_SECOND_STAGE - Control variables for second stage fir filter
//
#define S_SECOND_STAGE			   (S_THIRD_STAGE_DATA + S_THIRD_STAGE_DATA_SIZE)
#define S_SECOND_STAGE_PHASE		0
#define S_SECOND_STAGE_PHASE_COUNT	1
#define S_DEBUG_MAX_CYCLES          2
#define S_CYCLE_START               3
#define S_SECOND_STAGE_SIZE		8


//
// S_THIRD_STAGE - Control variables for second stage fir filter
//
#define S_THIRD_STAGE			(S_SECOND_STAGE + S_SECOND_STAGE_SIZE)
#define S_THIRD_STAGE_INDEX		0
#define S_THIRD_STAGE_SIZE		8

//
// S_OUTPUT_STORAGE - Location to store output values
//
#define S_OUTPUT_STORAGE                (S_THIRD_STAGE + S_THIRD_STAGE_SIZE)
//
// Add storage fields for output of second stage fir filter
// - stored in function second_to_third
// - retrieved in output_phase
//
#define S_OUTPUT_SECOND_TO_THIRD_01     0  // when used with ldd
#define S_OUTPUT_SECOND_TO_THIRD_0      0
#define S_OUTPUT_SECOND_TO_THIRD_1      1

#define S_OUTPUT_THIRD_TO_CALLER_01     2  // when used with ldd
#define S_OUTPUT_THIRD_TO_CALLER_0      2
#define S_OUTPUT_THIRD_TO_CALLER_1      3


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
#define S_SECOND_STAGE_FILTER_PTR       3
#define S_THIRD_STAGE_FILTER_PTR        4
#define S_SETTINGS_SIZE                 8

#define STACKWORDS                      (S_SETTINGS_OFFSET + S_SETTINGS_SIZE)

//This inputs from the channel to the pdm interface and saves it twice in the
//second stage FIR at offset OFFSET and OFFSET + SECOND_STAGE_HISTORY_SIZE
#define INPUT_TO_SECOND_STAGE(OFFSET)\
    ldw r1, sp[S_C_INPUT];\
    in r0, res[r1];\
    {stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
    {stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_HISTORY_SIZE + OFFSET]};\
    {in r0, res[r1]};\
    {stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
    {stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_HISTORY_SIZE + OFFSET]};

// input from second stage is in r0.
// apply a factor of 2 digital gain and store in third stage buffer
#define SECOND_STAGE_TO_THIRD_STAGE_CH0(OFFSET)\
    shl r0, r0, 1;\
    {stw r0, dp[DP_STAGE_3_CH0 + OFFSET]};\
    {stw r0, dp[DP_STAGE_3_CH0 + THIRD_STAGE_HISTORY_SIZE + OFFSET]};

// input in r0, store in third stage buffer
#define SECOND_STAGE_TO_THIRD_STAGE_CH1(OFFSET)\
    {stw r0, dp[DP_STAGE_3_CH1 + OFFSET]};\
    {stw r0, dp[DP_STAGE_3_CH1 + THIRD_STAGE_HISTORY_SIZE + OFFSET]};


#define SAVE_SAMPLES_NORMAL(POINTER)\
    {ldc r5, 1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2)};\
    {add r7, r6, r5; ldw r8, r4[POINTER]};\
    {add r5, r5, r5};\
    stw r1, r8[r7];\
    stw r0, r8[r6];


// MAC a pair of data using using indexed double word load
// for a total of two 2 MACs in 4 cycles
// assembly: ldd e, d, b[i]
// d <- mem[b+i×Bpw×2], i in (0.11)
// e <- mem[b+i×Bpw×2+Bpw]
// r0, r1: accumulators
// r2, r3: coefficients
// r4, r5: data
// r6: coefficient pointer
// r7: data pointer
#define FIR_POINT_PAIR(FILTER_INDEX, DATA_INDEX) \
    ldd r3, r2, r6[FILTER_INDEX]; \
    ldd r5, r4, r7[DATA_INDEX]; \
    maccs r0, r1, r4, r2; \
    maccs r0, r1, r5, r3;

// With half-band kernels, every other coefficient is zero.
// Continue to use ldd to maintain consistent stride 2 * index
// but throw away the second value
#define FIR_POINT_PAIR_RIGHT_ZERO(FILTER_INDEX, DATA_INDEX) \
    ldd r3, r2, r6[FILTER_INDEX]; \
    ldd r5, r4, r7[DATA_INDEX]; \
    maccs r0, r1, r4, r2;
    // r3 is 0.0 => skip "maccs r0, r1, r5, r3;"


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
    ladd r11, r5, r5, r8, r4;\
    ladd r11, r6, r6, r9, r11;\
    std r6, r5, r4[PREV_Y];\
    lextract REGISTER, r6, r5, r10, 32


// FILTER_GENERIC: Convolve length 48 coefficients with length 48 data.
// Dispense with any fancy symmetry tricks and just blast through the
// coefficient and data arrays two at a time. Odd kernels must be zero padded.
//
// We can only use immediate mode index (0.11) so shift the pointer half-way
// through by SECOND_STAGE_MIDPOINT_BYTES. Kernel length 48 is the longest
// kernel that can be implemnted using this approach. Shorter kernels can
// be supported by deleting code.
// r0, r1 : FIR_POINT_PAIR accumulators
// r2, r3 : FIR_POINT_PAIR coefficients
// r4, r5 : FIR_POINT_PAIR data
// r6     : INPUT coefficient pointer
// r7     : INPUT data pointer
// r8     : local variable
// r9, r10, r11 unused
// algorithm:
// - Initialize the accumulators
// - MAC the first half of the arrays
// - shift the pointers forward by HALF_LENGTH_BYTES
// - MAC the second half of the arrays
// - Output is in (r0, r1) with r0 MSB
#define FILTER_GENERIC(HALF_LENGTH_BYTES) \
    {ldc r0, 0; ldc r1, 0}; \
    FIR_POINT_PAIR(0, 0); \
    FIR_POINT_PAIR(1, 1); \
    FIR_POINT_PAIR(2, 2); \
    FIR_POINT_PAIR(3, 3); \
    FIR_POINT_PAIR(4, 4); \
    FIR_POINT_PAIR(5, 5); \
    FIR_POINT_PAIR(6, 6); \
    FIR_POINT_PAIR(7, 7); \
    FIR_POINT_PAIR(8, 8); \
    FIR_POINT_PAIR(9, 9); \
    FIR_POINT_PAIR(10, 10); \
    FIR_POINT_PAIR(11, 11); \
    ldc r8, HALF_LENGTH_BYTES ;\
    {add r6, r6, r8; add r7, r7, r8;}; \
    FIR_POINT_PAIR(0, 0); \
    FIR_POINT_PAIR(1, 1); \
    FIR_POINT_PAIR(2, 2); \
    FIR_POINT_PAIR(3, 3); \
    FIR_POINT_PAIR(4, 4); \
    FIR_POINT_PAIR(5, 5); \
    FIR_POINT_PAIR(6, 6); \
    FIR_POINT_PAIR(7, 7); \
    FIR_POINT_PAIR(8, 8); \
    FIR_POINT_PAIR(9, 9); \
    FIR_POINT_PAIR(10, 10); \
    FIR_POINT_PAIR(11, 11)

// FILTER_HALFBAND: Convolve length 48 coefficients with length 48 data,
// but take advantage of the fact that every other coefficient is zero
// (except the center) on a half-band filter. Odd kernels must be zero padded.
//
// We can only use immediate mode index (0.11) so shift the pointer half-way
// through by SECOND_STAGE_MIDPOINT_BYTES. Kernel length 48 is the longest
// kernel that can be implemnted using this approach. Shorter kernels can
// be supported by deleting code.
// r0, r1 : FIR_POINT_PAIR accumulators
// r2, r3 : FIR_POINT_PAIR coefficients
// r4, r5 : FIR_POINT_PAIR data
// r6     : INPUT coefficient pointer
// r7     : INPUT data pointer
// r8     : local variable
// r9, r10, r11 unused
// algorithm:
// - Initialize the accumulators
// - MAC the first half of the arrays
// - shift the pointers forward by HALF_LENGTH_BYTES
// - MAC the second half of the arrays
// - Output is in (r0, r1) with r0 MSB
#define FILTER_HALFBAND(HALF_LENGTH_BYTES) \
    {ldc r0, 0; ldc r1, 0}; \
    FIR_POINT_PAIR_RIGHT_ZERO(0, 0); \
    FIR_POINT_PAIR_RIGHT_ZERO(1, 1); \
    FIR_POINT_PAIR_RIGHT_ZERO(2, 2); \
    FIR_POINT_PAIR_RIGHT_ZERO(3, 3); \
    FIR_POINT_PAIR_RIGHT_ZERO(4, 4); \
    FIR_POINT_PAIR_RIGHT_ZERO(5, 5); \
    FIR_POINT_PAIR_RIGHT_ZERO(6, 6); \
    FIR_POINT_PAIR_RIGHT_ZERO(7, 7); \
    FIR_POINT_PAIR_RIGHT_ZERO(8, 8); \
    FIR_POINT_PAIR_RIGHT_ZERO(9, 9); \
    FIR_POINT_PAIR_RIGHT_ZERO(10, 10); \
    FIR_POINT_PAIR(11, 11); \
    ldc r8, HALF_LENGTH_BYTES ;\
    {add r6, r6, r8; add r7, r7, r8;}; \
    FIR_POINT_PAIR_RIGHT_ZERO(0, 0); \
    FIR_POINT_PAIR_RIGHT_ZERO(1, 1); \
    FIR_POINT_PAIR_RIGHT_ZERO(2, 2); \
    FIR_POINT_PAIR_RIGHT_ZERO(3, 3); \
    FIR_POINT_PAIR_RIGHT_ZERO(4, 4); \
    FIR_POINT_PAIR_RIGHT_ZERO(5, 5); \
    FIR_POINT_PAIR_RIGHT_ZERO(6, 6); \
    FIR_POINT_PAIR_RIGHT_ZERO(7, 7); \
    FIR_POINT_PAIR_RIGHT_ZERO(8, 8); \
    FIR_POINT_PAIR_RIGHT_ZERO(9, 9); \
    FIR_POINT_PAIR_RIGHT_ZERO(10, 10); \
    FIR_POINT_PAIR_RIGHT_ZERO(11, 11)



    .globl    decimate_to_pcm_cascade
    .align    8
    .type    decimate_to_pcm_cascade,@function
    .cc_top decimate_to_pcm_cascade.function
decimate_to_pcm_cascade:
    .cfi_startproc
    .issue_mode dual

    DUALENTSP_lu6 STACKWORDS

// For clarity, read the three arguments passed to decimate_to_pcm_cascade()
// off the stack in one place. However, as r3 will be overwritten before it can be
// used, we will have to re-read boardrev in lines 576 and 682
    ldaw r11, sp[S_STORAGE]
    stw r0, r11[S_C_INPUT]
    stw r1, r11[S_C_OUTPUT]
    stw r3, r11[S_BOARDREV]

    clre			// Stop events for this thread

    stw r2, sp[S_FAR_END_CHANNEL_0]
    stw r2, sp[S_FAR_END_CHANNEL_1]

internal_channel_setup_complete:
    //Set the dp to point to the data area for the second stage FIR
    ldaw dp, sp[S_SECOND_STAGE_DATA]

    outct res[r1], 8        // We say we are ready
    inct r2, res[r1]        // They say CONFIGURE_DECIMATOR

    //
    // Initialise the DC offset removal using double-word store
    //
    ldaw r0, sp[S_DC_ELIMINATE];
    ldc r1, 0
    std r1, r1, r0[S_D_PREV_X_01]
    std r1, r1, r0[S_D_PREV_Y_01]

configure:
    DUALENTSP_lu6 0
    //
    // Zero second stage data
    //
    ldaw r0, sp[S_SECOND_STAGE_DATA]
    ldc r1, S_SECOND_STAGE_DATA_SIZE
    bl zero_data_structures_cascade
    //
    // Zero second stage
    //
    ldaw r0, sp[S_SECOND_STAGE]
    ldc r1, S_SECOND_STAGE_SIZE
    bl zero_data_structures_cascade
    //
    // Zero third stage data
    //
    ldaw r0, sp[S_THIRD_STAGE_DATA]
    ldc r1, S_THIRD_STAGE_DATA_SIZE
    bl zero_data_structures_cascade
    //
    // Zero third stage
    //
    ldaw r0, sp[S_THIRD_STAGE]
    ldc r1, S_THIRD_STAGE_SIZE
    bl zero_data_structures_cascade
    //
    // Zero output storage
    //
    ldaw r0, sp[S_OUTPUT_STORAGE]
    ldc r1, S_OUTPUT_STORAGE_SIZE
    bl zero_data_structures_cascade
    //
    // Zero dc eliminate area
    //
    ldaw r0, sp[S_DC_ELIMINATE]
    ldc r1, DC_ELIMINATE_STACK_SIZE
    bl zero_data_structures_cascade
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
    ldw r11, r3[1]			// Enable DC offset removal
    stw r11, r0[S_DC_OFFSET_REMOVAL_ENABLED]

    ldw r11, r3[4]			// decimation factor
    ldaw r10, sp[S_SECOND_STAGE]
    stw r11, r10[S_SECOND_STAGE_PHASE_COUNT]

    //
    // Select filter coefficients based on boardrev (done once during configuration)
    // Use r8 for boardrev value to avoid conflicts with r11 (required for LDWCPL)
    //
    ldaw r4, sp[S_STORAGE]
    ldw r8, r4[S_BOARDREV]

    // Select second stage filter based on boardrev (4-bit fuse value 0-15)
    // 2026-FEB-08: All filters currently use the same second stage, but leave
    // the jump table in place for now
    ldc r9, 0x0F
    eq r9, r8, r9
    bt r9, config_second_stage_0x0F
    ldc r9, 0x0E
    eq r9, r8, r9
    bt r9, config_second_stage_0x0E
    ldc r9, 0x0C
    eq r9, r8, r9
    bt r9, config_second_stage_0x0C
    // Default case
    ldaw r11, cp[g_second_to_third_fir47_48kHz] // default like IM72D128
    bu config_second_stage_done
config_second_stage_0x0F: // VM3000
    ldaw r11, cp[g_second_to_third_fir47_48kHz]
    bu config_second_stage_done
config_second_stage_0x0E: // IM72D128
    ldaw r11, cp[g_second_to_third_fir47_48kHz]
    bu config_second_stage_done
config_second_stage_0x0C: // EM215
    ldaw r11, cp[g_second_to_third_fir47_48kHz]
    bu config_second_stage_done
config_second_stage_done:
    ldaw r0, sp[S_SETTINGS_OFFSET]
    stw r11, r0[S_SECOND_STAGE_FILTER_PTR]

    // Select third stage filter (r8 still contains boardrev, 4-bit value 0-15)
    ldc r9, 0x0F
    eq r9, r8, r9
    bt r9, config_third_stage_0x0F
    ldc r9, 0x0E
    eq r9, r8, r9
    bt r9, config_third_stage_0x0E
    ldc r9, 0x0C
    eq r9, r8, r9
    bt r9, config_third_stage_0x0C
    // Default case
    ldaw r11, cp[g_third_to_output_fir47_12kHz]  // default like IM72D128
    bu config_third_stage_done
config_third_stage_0x0F:
    ldaw r11, cp[g_third_to_output_fir47_10kHz]   // VM3000
    bu config_third_stage_done
config_third_stage_0x0E:
    ldaw r11, cp[g_third_to_output_fir47_12kHz]  // IM72D128
    bu config_third_stage_done
config_third_stage_0x0C:
    ldaw r11, cp[g_third_to_output_fir47_40kHz] // EM215
    bu config_third_stage_done
config_third_stage_done:
    ldaw r0, sp[S_SETTINGS_OFFSET]
    stw r11, r0[S_THIRD_STAGE_FILTER_PTR]

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

    // while (1) process

// ===============================================================
// MAIN WHILE(1) LOOP
// ===============================================================
//
// This is unrolled for performance. the pattern repeat period is
// on based on 4 input samples -> 1 output sample. The code interleaves
// reads and computation to avoid falling behind on the input but the
// basic algorithm is:
// - read two inputs and store in stage 2 buffers
// - apply stage 2 filter and store the 2:1 decimated result in stage 3 buffers
// - read two inputs and store in stage 2 buffers
// - apply stage 2 filter and store the 2:1 decimated result in stage 3 buffers
// - apply stage 3 filter and store 2:1 decimated output in the output
// - The code interleaves data reads with computation to avoid falling behind.
// - Apply stage 3 is logically after stage 2, but we are on circle so is is called first.

// r0, r1 : FIR_POINT_PAIR/FIR_POINT_PAIR_RIGHT_ZERO accumulators
// r2, r3 : FIR_POINT_PAIR/FIR_POINT_PAIR_RIGHT_ZERO coefficients
// r4, r5 : FIR_POINT_PAIR/FIR_POINT_PAIR_RIGHT_ZERO data
// r6     : FIR_POINT_PAIR/FIR_POINT_PAIR_RIGHT_ZERO coefficient pointer
// r7     : FIR_POINT_PAIR/FIR_POINT_PAIR_RIGHT_ZERO data pointer
// r8     : local variable
// r9     : sp[S_SETTINGS_OFFSET], used to load coefficients
// r10    : use to store
// Note: dp was set above to the start of the second stage circular buffer
// "Set the dp to point to the data area for the second stage FIR"
// ldaw dp, sp[S_SECOND_STAGE_DATA]

// set r9 with setting offset and never change it

fir_loop_type1:
// BEGIN_GENERATED_LOOP -- do not edit below; regenerate with generate_filter_loop.py

    INPUT_TO_SECOND_STAGE(47)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[0 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[0 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(46)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[46 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(47)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[46 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(47)            // output channel 0

    INPUT_TO_SECOND_STAGE(45)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(44)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[44 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(46)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[44 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(46)             // output channel 0

    INPUT_TO_SECOND_STAGE(43)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[46 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[46 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(42)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[42 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(45)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[42 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(45)            // output channel 0

    INPUT_TO_SECOND_STAGE(41)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(40)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[40 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(44)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[40 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(44)             // output channel 0

    INPUT_TO_SECOND_STAGE(39)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[44 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[44 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(38)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[38 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(43)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[38 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(43)            // output channel 0

    INPUT_TO_SECOND_STAGE(37)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(36)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[36 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(42)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[36 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(42)             // output channel 0

    INPUT_TO_SECOND_STAGE(35)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[42 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[42 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(34)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[34 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(41)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[34 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(41)            // output channel 0

    INPUT_TO_SECOND_STAGE(33)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(32)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[32 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(40)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[32 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(40)             // output channel 0

    INPUT_TO_SECOND_STAGE(31)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[40 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[40 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(30)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[30 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(39)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[30 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(39)            // output channel 0

    INPUT_TO_SECOND_STAGE(29)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(28)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[28 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(38)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[28 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(38)             // output channel 0

    INPUT_TO_SECOND_STAGE(27)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[38 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[38 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(26)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[26 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(37)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[26 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(37)            // output channel 0

    INPUT_TO_SECOND_STAGE(25)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(24)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[24 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(36)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[24 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(36)             // output channel 0

    INPUT_TO_SECOND_STAGE(23)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[36 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[36 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(22)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[22 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(35)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[22 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(35)            // output channel 0

    INPUT_TO_SECOND_STAGE(21)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(20)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[20 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(34)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[20 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(34)             // output channel 0

    INPUT_TO_SECOND_STAGE(19)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[34 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[34 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(18)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[18 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(33)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[18 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(33)            // output channel 0

    INPUT_TO_SECOND_STAGE(17)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(16)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[16 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(32)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[16 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(32)             // output channel 0

    INPUT_TO_SECOND_STAGE(15)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[32 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[32 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(14)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[14 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(31)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[14 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(31)            // output channel 0

    INPUT_TO_SECOND_STAGE(13)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(12)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[12 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(30)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[12 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(30)             // output channel 0

    INPUT_TO_SECOND_STAGE(11)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[30 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[30 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(10)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[10 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(29)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[10 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(29)            // output channel 0

    INPUT_TO_SECOND_STAGE(9)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(8)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[8 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(28)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[8 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(28)             // output channel 0

    INPUT_TO_SECOND_STAGE(7)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[28 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[28 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(6)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[6 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(27)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[6 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(27)            // output channel 0

    INPUT_TO_SECOND_STAGE(5)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(4)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[4 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(26)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[4 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(26)             // output channel 0

    INPUT_TO_SECOND_STAGE(3)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[26 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[26 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(2)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[2 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(25)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[2 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(25)            // output channel 0

    INPUT_TO_SECOND_STAGE(1)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(0)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[0 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(24)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[0 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(24)             // output channel 0

    INPUT_TO_SECOND_STAGE(47)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[24 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[24 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(46)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[46 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(23)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[46 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(23)            // output channel 0

    INPUT_TO_SECOND_STAGE(45)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(44)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[44 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(22)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[44 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(22)             // output channel 0

    INPUT_TO_SECOND_STAGE(43)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[22 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[22 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(42)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[42 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(21)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[42 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(21)            // output channel 0

    INPUT_TO_SECOND_STAGE(41)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(40)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[40 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(20)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[40 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(20)             // output channel 0

    INPUT_TO_SECOND_STAGE(39)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[20 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[20 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(38)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[38 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(19)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[38 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(19)            // output channel 0

    INPUT_TO_SECOND_STAGE(37)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(36)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[36 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(18)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[36 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(18)             // output channel 0

    INPUT_TO_SECOND_STAGE(35)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[18 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[18 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(34)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[34 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(17)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[34 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(17)            // output channel 0

    INPUT_TO_SECOND_STAGE(33)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(32)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[32 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(16)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[32 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(16)             // output channel 0

    INPUT_TO_SECOND_STAGE(31)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[16 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[16 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(30)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[30 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(15)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[30 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(15)            // output channel 0

    INPUT_TO_SECOND_STAGE(29)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(28)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[28 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(14)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[28 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(14)             // output channel 0

    INPUT_TO_SECOND_STAGE(27)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[14 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[14 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(26)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[26 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(13)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[26 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(13)            // output channel 0

    INPUT_TO_SECOND_STAGE(25)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(24)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[24 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(12)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[24 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(12)             // output channel 0

    INPUT_TO_SECOND_STAGE(23)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[12 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[12 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(22)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[22 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(11)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[22 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(11)            // output channel 0

    INPUT_TO_SECOND_STAGE(21)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(20)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[20 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(10)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[20 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(10)             // output channel 0

    INPUT_TO_SECOND_STAGE(19)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[10 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[10 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(18)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[18 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(9)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[18 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(9)            // output channel 0

    INPUT_TO_SECOND_STAGE(17)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(16)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[16 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(8)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[16 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(8)             // output channel 0

    INPUT_TO_SECOND_STAGE(15)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[8 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[8 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(14)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[14 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(7)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[14 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(7)            // output channel 0

    INPUT_TO_SECOND_STAGE(13)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(12)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[12 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(6)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[12 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(6)             // output channel 0

    INPUT_TO_SECOND_STAGE(11)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[6 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[6 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(10)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[10 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(5)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[10 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(5)            // output channel 0

    INPUT_TO_SECOND_STAGE(9)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(8)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[8 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(4)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[8 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(4)             // output channel 0

    INPUT_TO_SECOND_STAGE(7)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[4 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[4 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(6)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[6 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(3)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[6 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(3)            // output channel 0

    INPUT_TO_SECOND_STAGE(5)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(4)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[4 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(2)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[4 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(2)             // output channel 0

    INPUT_TO_SECOND_STAGE(3)                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[2 + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[2 + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1

    INPUT_TO_SECOND_STAGE(2)                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[2 + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(1)            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[2 + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(1)            // output channel 0

    INPUT_TO_SECOND_STAGE(1)
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11

    INPUT_TO_SECOND_STAGE(0)
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[0 + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0(0)             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[0 + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1(0)             // output channel 0
// END_GENERATED_LOOP
    bu fir_loop_type1

    .cc_bottom decimate_to_pcm_cascade.function
    .set    decimate_to_pcm_cascade.nstackwords, STACKWORDS
    .globl  decimate_to_pcm_cascade.nstackwords
    .set    decimate_to_pcm_cascade.maxcores,1
    .globl  decimate_to_pcm_cascade.maxcores
    .set    decimate_to_pcm_cascade.maxtimers,0
    .globl  decimate_to_pcm_cascade.maxtimers
    .set    decimate_to_pcm_cascade.maxchanends,0
    .globl  decimate_to_pcm_cascade.maxchanends

.Ldecimate_to_pcm_cascade_tmp:
    .size    decimate_to_pcm_cascade, .Ldecimate_to_pcm_cascade_tmp-decimate_to_pcm_cascade
    .cfi_endproc

.globl    post_process_cascade
.align    8
.type    post_process_cascade,@function
.cc_top post_process_cascade.function
post_process_cascade:
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
    ldw r0, r4[S_OUTPUT_THIRD_TO_CALLER_0];
    ldw r1, r4[S_OUTPUT_THIRD_TO_CALLER_1];

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

.cc_bottom post_process_cascade.function
    .set    post_process_cascade.nstackwords, 0
    .globl    post_process_cascade.nstackwords
    .set    post_process_cascade.maxcores,1
    .globl    post_process_cascade.maxcores
    .set    post_process_cascade.maxtimers,0
    .globl    post_process_cascade.maxtimers
    .set    post_process_cascade.maxchanends,0
    .globl    post_process_cascade.maxchanends
.Lpost_process_cascade_tmp:
    .size    post_process_cascade, .Lpost_process_cascade_tmp-post_process_cascade
    .cfi_endproc


    .globl    zero_data_structures_cascade
    .align    8
    .type     zero_data_structures_cascade,@function
    .cc_top   zero_data_structures_cascade.function

//
// r0 - Address to be zeroed
// r1 - Words to zero
//
zero_data_structures_cascade:
    .cfi_startproc

    ldc r2, 0                 // Zero register
    ldc r3, 0                 // Index in data structure
zero_loop:
    stw r2, r0[r3]            // Zero data
    add r3, r3, 1             // Increment index
    eq r4, r3, r1             // Test for index equal to number of words
    bf r4, zero_loop

    retsp 0
    .cc_bottom zero_data_structures_cascade.function
    .cfi_endproc
