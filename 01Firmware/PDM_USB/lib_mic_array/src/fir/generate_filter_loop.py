#!/usr/bin/env python
"""
Generates the unrolled FIR loop body for decimate_to_pcm_cascade.S.

Usage:
    python generate_filter_loop.py  # update decimate_to_pcm_cascade.S

The target .S file must contain the sentinel comments:
    // BEGIN_GENERATED_LOOP -- do not edit below; regenerate with generate_filter_loop.py
    // END_GENERATED_LOOP
"""

import os
import sys

stage2_taps = 48
stage3_taps = 48

# Path to the assembly file, relative to this script
ASM_FILE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         '..', 'decimate_to_pcm_cascade.S'))

BEGIN_MARKER = '// BEGIN_GENERATED_LOOP'
END_MARKER   = '// END_GENERATED_LOOP'


def generate_loop_text():
    blocks = []
    reps = 24
    for n in range(reps):
        stage2_start = ((stage2_taps - 1) - (4 * n))
        stage3_start = (stage3_taps - (2 * n))

        codeblock1 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})                     // input data
    ldaw r9, sp[S_SETTINGS_OFFSET];               // set settings pointer
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[{stage3_start % stage3_taps} + DP_STAGE_3_CH0];              // third stage data, channel 0
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 0
    ldaw r10, sp[S_OUTPUT_STORAGE];               // set ouput pointer
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_0];      // output channel 0
    ldw r6, r9[S_THIRD_STAGE_FILTER_PTR];         // third stage coefficients
    ldaw r7, dp[{stage3_start % stage3_taps} + DP_STAGE_3_CH1];              // third stage data, channel 1
    FILTER_GENERIC(THIRD_STAGE_MIDPOINT_BYTES)    // filter channel 1
    stw r0, r10[S_OUTPUT_THIRD_TO_CALLER_1];      // output channel 1
"""
        stage2_start -= 1
        stage3_start -= 1

        codeblock2 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})                      // input data
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];         // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH0];              // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0({stage3_start % stage3_taps})            // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR]          // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH1];               // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)   // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1({stage3_start % stage3_taps})            // output channel 0
"""
        stage2_start -= 1

        codeblock3 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})
    bl post_process_cascade                         // this trashes r0 r1 r3 r4 r8 r9 r10 r11
"""
        stage2_start -= 1
        stage3_start -= 1

        codeblock4 = f"""
    INPUT_TO_SECOND_STAGE({stage2_start % stage2_taps})
    ldaw r9, sp[S_SETTINGS_OFFSET];                 // set settings pointer
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH0];               // second stage data, channel 0
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 0
    SECOND_STAGE_TO_THIRD_STAGE_CH0({stage3_start % stage3_taps})             // output channel 0
    ldw r6, r9[S_SECOND_STAGE_FILTER_PTR];          // second stage coefficients
    ldaw r7, dp[{stage2_start % stage2_taps} + DP_STAGE_2_CH1];                // second stage data, channel 1
    FILTER_GENERIC(SECOND_STAGE_MIDPOINT_BYTES)    // filter channel 1
    SECOND_STAGE_TO_THIRD_STAGE_CH1({stage3_start % stage3_taps})             // output channel 0
"""
        blocks.append(codeblock1 + codeblock2 + codeblock3 + codeblock4)

    return ''.join(blocks)


def write_to_asm_file(new_loop_text):
    with open(ASM_FILE, 'r') as f:
        original = f.read()

    begin_idx = original.find(BEGIN_MARKER)
    end_idx   = original.find(END_MARKER)

    if begin_idx == -1 or end_idx == -1:
        print(f"ERROR: sentinel markers not found in {ASM_FILE}", file=sys.stderr)
        sys.exit(1)
    if end_idx <= begin_idx:
        print(f"ERROR: END_GENERATED_LOOP appears before BEGIN_GENERATED_LOOP", file=sys.stderr)
        sys.exit(1)

    # Keep the begin marker line intact; replace everything after it up to end marker
    begin_line_end = original.index('\n', begin_idx) + 1
    updated = original[:begin_line_end] + new_loop_text + original[end_idx:]

    with open(ASM_FILE, 'w') as f:
        f.write(updated)

    print(f"Updated {ASM_FILE}", file=sys.stderr)


def main():
    loop_text = generate_loop_text()

    if os.path.exists(ASM_FILE):
        write_to_asm_file(loop_text)
    else:
        print(f"ERROR: expected {ASM_FILE}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()