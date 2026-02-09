#!/usr/bin/env python

stage2_taps = 48
stage3_taps = 48


reps = 24

for n in range(reps):
    stage2_start = ((stage2_taps - 1) - (4 * n))
    stage3_start = (stage3_taps - (2 * n))
    codeblock1 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[{(stage3_start) % stage3_taps} + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[{stage3_start % stage3_taps} + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1
"""
    stage2_start = stage2_start - 1
    stage3_start = stage3_start - 1
    codeblock2 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_HALFBAND(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0({stage3_start % stage3_taps})            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_HALFBAND(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1({stage3_start % stage3_taps})            // output channel 0
"""
    stage2_start = stage2_start - 1
    codeblock3 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11
"""

    stage2_start = stage2_start - 1
    stage3_start = stage3_start - 1
    codeblock4 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_HALFBAND(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0({stage3_start % stage3_taps})             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_HALFBAND(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1({stage3_start % stage3_taps})             // output channel 0
"""
    combined = codeblock1 + codeblock2 + codeblock3 + codeblock4
    print(combined)