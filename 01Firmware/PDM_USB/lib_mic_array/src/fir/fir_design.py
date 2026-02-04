#!/usr/bin/env python
# Copyright 2016-2021 XMOS LIMITED.
# Copyright 2024-2025 SoundThinking Inc.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

"""
Clean filter coefficient generator for XMOS microphone array decimation filters.

This script generates three stages of FIR filters:
1. First stage: PDM to 384 kHz (8:1 decimation) using lookup tables
2. Second stage: 384 kHz to 48 kHz (8:1 decimation) using symmetric FIR
3. Third stage: 48 kHz to 12 kHz (4:1 decimation) using symmetric FIR

Key design principle: Separation of coefficient generation from file formatting.
- Coefficient generation functions return data structures
- File writing functions format and write those structures to output files
"""

import datetime
import math
import ctypes
import numpy as np
from scipy import signal

# ============================================================================
# CONSTANTS
# ============================================================================

INT32_MAX = np.int64(np.iinfo(np.int32).max)
INT64_MAX = np.int64(np.iinfo(np.int64).max)

# ============================================================================
# CONFIGURATION - Hard-coded filter specifications
# ============================================================================

# PDM sample rate in kHz
PDM_SAMPLE_RATE_KHZ = 3072.0

# First stage: PDM (3072 kHz) -> 384 kHz (decimation by 8)
FIRST_STAGE_CONFIG = {
    'num_taps': 48,
    'pass_bw_khz': 96.0,
    'stop_bw_khz': 192.0,
    'stop_atten_db': -80.0,
    'use_low_ripple': False  # Set True for multi-null design
}

# Second stage: 384 kHz -> 48 kHz (decimation by 8)
# Generate filters for different microphone types with different cutoff frequencies
SECOND_STAGE_CONFIG = {
    'num_taps': 32,
    'stop_atten_db': -65.0,
    'transition_width_khz': 4.0,
    'filters_khz': [43.999, 42.0, 36.0, 28.0, 20.0, 12.0]  # Cutoff frequencies
}

# Third stage: 48 kHz -> 12 kHz (decimation by 4)
# Windowed FIR filters
THIRD_STAGE_CONFIG = {
    'num_taps': 32,
    'sample_rate_khz': 96.0,  # Input sample rate to third stage
    'filters_khz': [47.999, 40.0, 32.0, 24.0, 16.0, 12.0, 8.0]  # Cutoff frequencies
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def break_every_8(i, indent="    "):
    """Format helper: Add newline every 8 items, otherwise space."""
    return "\n" + indent if i % 8 == 7 else " "


def measure_stopband_and_ripple(bands, a, H):
    """
    Measure stopband attenuation and passband ripple from frequency response.

    Args:
        bands: Frequency band edges (normalized 0-0.5)
        a: Desired amplitudes for each band
        H: Frequency response array

    Returns:
        [stopband_max, passband_max, passband_min] in dB
    """
    passband_max = float('-inf')
    passband_min = float('inf')
    stopband_max = float('-inf')

    for h in range(len(H)):
        freq = 0.5 * h / len(H)
        mag = 20.0 * np.log10(abs(H[h]))

        for r in range(0, len(bands), 2):
            if bands[r] < freq < bands[r+1]:
                if a[r//2] == 0:  # Stopband
                    stopband_max = max(stopband_max, mag)
                else:  # Passband
                    passband_max = max(passband_max, mag)
                    passband_min = min(passband_min, mag)

    return [stopband_max, passband_max, passband_min]


def generate_stage_remez(num_taps, bands, a, weights, stopband_attenuation=-65.0):
    """
    Generate FIR filter using Parks-McClellan (Remez) algorithm with automatic weight tuning.

    Iteratively adjusts passband weights to achieve target stopband attenuation.

    Args:
        num_taps: Number of filter taps
        bands: Frequency band edges (normalized 0-0.5)
        a: Desired amplitudes for each band
        weights: Relative weights for each band
        stopband_attenuation: Target stopband attenuation in dB (negative)

    Returns:
        (H, h) where H is frequency response and h is filter coefficients
    """
    w = np.ones(len(a))
    weight_min = 0.0
    weight_max = 1024.0
    epsilon = 0.0000000001
    num_frequency_points = 2048

    while True:
        test_weight = (weight_min + weight_max) / 2.0

        # Apply weights to passbands only
        for i in range(len(a) - 1):
            if a[i] != 0:
                w[i] = test_weight * weights[i]

        try:
            h = signal.remez(num_taps, bands, a, weight=w)
            (_, H) = signal.freqz(h, worN=num_frequency_points)
            [stop_band_atten, _, _] = measure_stopband_and_ripple(bands, a, H)

            if -stop_band_atten > -stopband_attenuation:
                weight_min = test_weight
            else:
                weight_max = test_weight

            if abs(weight_min - weight_max) < epsilon:
                break

        except ValueError:
            if abs(test_weight - weight_max) < epsilon:
                print("ERROR: Failed to converge - unable to create filter")
                return None, None
            weight_min = test_weight

    return H, h


# ============================================================================
# COEFFICIENT GENERATION FUNCTIONS
# ============================================================================

def generate_first_stage_coefficients():
    """
    Generate first stage filter coefficients and lookup tables.

    First stage decimates PDM (3072 kHz) to 384 kHz (8:1 decimation).
    Uses lookup tables for efficient PDM bit processing.

    Returns:
        dict with keys:
            'lookup_tables': List of 256-entry lookup tables (one per block)
            'debug_coefs': Full coefficient array for debugging
            'max_passband_output': Maximum passband output value
    """
    config = FIRST_STAGE_CONFIG

    # Normalize frequencies
    pbw = config['pass_bw_khz'] / PDM_SAMPLE_RATE_KHZ
    sbw = config['stop_bw_khz'] / PDM_SAMPLE_RATE_KHZ
    nulls = 1.0 / 8.0  # Decimation ratio

    if config['use_low_ripple']:
        # Multi-null design for lowest ripple
        a = np.zeros(5)
        a[0] = 1.0
        w = np.ones(len(a))
        bands = [0, pbw,
                 nulls*1-sbw, nulls*1+sbw,
                 nulls*2-sbw, nulls*2+sbw,
                 nulls*3-sbw, nulls*3+sbw,
                 nulls*4-sbw, 0.5]
    else:
        # Standard design
        a = np.zeros(2)
        a[0] = 1.0
        w = np.ones(len(a))
        bands = [0, pbw, nulls-sbw, 0.5]

    H, coefs = generate_stage_remez(
        config['num_taps'], bands, a, w,
        stopband_attenuation=config['stop_atten_db']
    )

    # Normalize to prevent overflow
    coefs /= sum(abs(coefs))

    # Calculate max passband output (using high resolution frequency response)
    # Note: Original code has swapped variable names, using passband_min instead of passband_max
    (_, H_highres) = signal.freqz(coefs, worN=8192*8)
    [_, _, passband_min] = measure_stopband_and_ripple(bands, a, H_highres)
    max_passband_output = int(float(INT32_MAX) * 10.0 ** (passband_min/20.0) + 1)

    # Generate 256-entry lookup tables (one per 8-tap block)
    lookup_tables = []
    total_abs_sum = 0

    for block in range(len(coefs) // (8 * 2)):
        table = []
        max_for_block = np.int64(0)

        for x in range(256):
            # Each bit position corresponds to a coefficient
            d = 0.0
            for b in range(8):
                if ((x >> (7 - b)) & 1) == 1:
                    d += coefs[block * 8 + b]
                else:
                    d -= coefs[block * 8 + b]

            d_int = np.int32(d * np.float64(INT32_MAX))
            max_for_block = max(max_for_block, np.abs(np.int64(d_int)))
            table.append(d_int)

        lookup_tables.append(table)
        total_abs_sum += max_for_block * 2

    return {
        'lookup_tables': lookup_tables,
        'debug_coefs': coefs,
        'max_passband_output': max_passband_output,
        'total_abs_sum': total_abs_sum
    }


def generate_second_stage_coefficients(cutoff_khz):
    """
    Generate second stage filter for given cutoff frequency.

    Second stage decimates 384 kHz to 48 kHz (8:1 decimation).

    Args:
        cutoff_khz: Cutoff frequency in kHz

    Returns:
        dict with keys:
            'coefs': Filter coefficients (all taps)
            'name': Filter name (e.g., '36kHz')
    """
    config = SECOND_STAGE_CONFIG
    stage_sample_rate = PDM_SAMPLE_RATE_KHZ / 8.0  # 384 kHz

    # Normalize frequencies
    passband = cutoff_khz / stage_sample_rate
    transition_width = config['transition_width_khz'] / stage_sample_rate
    nulls = 1.0 / 8.0  # Decimation ratio

    # Three-band design: passband, transition, stopband
    a = [1, 0, 0]
    w = [1, 1, 1]
    bands = [0, passband,
             nulls*1 - transition_width, nulls*1 + transition_width,
             nulls*2 - transition_width, 0.5]

    _, coefs = generate_stage_remez(
        config['num_taps'], bands, a, w,
        stopband_attenuation=config['stop_atten_db']
    )

    # Normalize to prevent overflow
    coefs /= sum(abs(coefs))

    # Generate name based on normalized passband frequency
    normalized_freq = passband * 384  # Convert to kHz equivalent
    name = f"{int(round(normalized_freq))}kHz"

    return {
        'coefs': coefs,
        'name': name
    }


def generate_third_stage_coefficients(cutoff_khz):
    """
    Generate third stage filter using windowed design.

    Third stage decimates 48 kHz to 12 kHz (4:1 decimation).
    Uses Hamming window for simple, effective design.

    Args:
        cutoff_khz: Cutoff frequency in kHz

    Returns:
        dict with keys:
            'coefs': Filter coefficients (symmetric, only first half stored)
            'name': Filter name (e.g., '24kHz')
    """
    config = THIRD_STAGE_CONFIG
    N = config['num_taps']
    Fs = config['sample_rate_khz'] * 1000.0  # Convert to Hz
    fc = cutoff_khz * 1000.0  # Convert to Hz

    # Generate windowed sinc filter
    coefs = np.zeros(N)
    for n in range(N):
        m = n - ((N - 1) / 2)
        gamma = (2.0 * math.pi * fc) / Fs

        # Sinc function
        h = math.sin(m * gamma) / (m * math.pi) if m != 0 else gamma / math.pi

        # Hamming window
        n_w = n - (N / 2)
        h_w = 0.54 + 0.46 * math.cos((math.pi * (2.0 * n_w + 1)) / (N - 1.0))

        coefs[n] = h * h_w

    # Normalize to prevent overflow
    coefs /= sum(abs(coefs))

    name = f"{int(round(cutoff_khz))}kHz"

    return {
        'coefs': coefs,
        'name': name
    }


# ============================================================================
# FILE WRITING FUNCTIONS
# ============================================================================

def write_first_stage(header, body, coef_data):
    """Write first stage lookup tables and debug coefficients to files."""
    lookup_tables = coef_data['lookup_tables']
    debug_coefs = coef_data['debug_coefs']
    max_passband = coef_data['max_passband_output']

    # Write lookup tables
    for t, table in enumerate(lookup_tables):
        header.write(f"extern const int g_first_stage_fir_{t}[256];\n")
        body.write(f"const int g_first_stage_fir_{t}[256] = {{\n    ")
        for x, value in enumerate(table):
            body.write(f"0x{ctypes.c_uint(value).value:08x},")
            body.write(break_every_8(x))
        body.write("};\n\n")

    # Write debug coefficients
    num_taps = len(debug_coefs)
    header.write(f"extern const int g_first_stage_fir_debug[{num_taps}];\n")
    body.write(f"const int g_first_stage_fir_debug[{num_taps}] = {{\n    ")
    for i, coef in enumerate(debug_coefs):
        body.write("{:10d},".format(int(float(INT32_MAX) * coef)))
        body.write(break_every_8(i))
    body.write("};\n")
    body.write("\n")

    # Write max passband define
    header.write("\n")
    header.write(f"#define FIRST_STAGE_MAX_PASSBAND_OUTPUT ({max_passband})\n")
    header.write("\n")


def write_second_stage(header, body, coef_data):
    """Write second stage filter coefficients to files."""
    coefs = coef_data['coefs']
    name = coef_data['name']
    num_taps = len(coefs)

    # Write optimized coefficients (only first half for symmetric filter)
    num_output_coefs = num_taps // 2
    header.write(f"extern const int g_second_stage_fir{num_taps}_{name}[{num_output_coefs}];\n")
    body.write(f"const int g_second_stage_fir{num_taps}_{name}[{num_output_coefs}] = {{\n    ")

    for i in range(num_output_coefs):
        d_int = np.int32(coefs[i] * float(INT32_MAX) * 2.0)
        body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
        body.write(break_every_8(i))
    body.write("};\n\n")

    # Write debug coefficients (full precision decimal)
    header.write(f"extern const int g_second_stage_fir{num_taps}_{name}_debug[{num_taps}];\n")
    header.write("\n")
    body.write(f"const int g_second_stage_fir{num_taps}_{name}_debug[{num_taps}] = {{\n    ")

    for i, coef in enumerate(coefs):
        decimalized_coef = int(float(INT32_MAX) * coef)
        body.write(f"{decimalized_coef:10d},")
        body.write(break_every_8(i))
    body.write("};\n\n")


def write_third_stage(header, body, coef_data):
    """Write third stage filter coefficients to files."""
    coefs = coef_data['coefs']
    name = coef_data['name']

    # Only output first half of coefficients (symmetric filter)
    num_output_coefs = len(coefs) // 2

    header.write(f"extern const int g_third_stage_fir_{name}[{num_output_coefs}];\n")
    body.write(f"const int g_third_stage_fir_{name}[{num_output_coefs}] = {{\n    ")

    for i in range(num_output_coefs):
        d_int = np.int32(coefs[i] * float(INT32_MAX) * 2.0)
        body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
        body.write(break_every_8(i))
    body.write("};\n\n")


def write_constants(header, body):
    """Write constant definitions and disabled filter."""
    # CRC constants
    header.write("extern const int g_crc_constants[2];\n")
    header.write("\n")
    body.write("// CRC polynominal to use, bogus data to checksum\n")
    body.write("const int g_crc_constants[2] = {0xEDB88320, 0xFFFFFFFF};\n")
    body.write("\n")

    # Disabled third stage filter (all zeros)
    num_taps = THIRD_STAGE_CONFIG['num_taps']
    num_output_coefs = num_taps // 2
    name = 'g_third_stage_fir_disabled'

    body.write("// Fake filter used to disable third stage entirely.\n")
    header.write(f"extern const int {name}[{num_output_coefs}];\n")
    body.write(f"const int {name}[{num_output_coefs}] = {{\n    ")

    for i in range(num_output_coefs):
        body.write("0x00000000,")
        body.write(break_every_8(i))
    body.write("};\n\n")


# ============================================================================
# MAIN
# ============================================================================

def main():
    """Generate all filter coefficients and write to output files."""

    # Open output files
    header = open("fir_coefs.h", 'w', newline='')
    body = open("fir_coefs.xc", 'w', newline='')

    # Write copyright headers
    year = datetime.datetime.now().year
    header.write(f"// Copyright (c) {year}, XMOS Ltd, All rights reserved\n")
    body.write(f"// Copyright (c) {year}, XMOS Ltd, All rights reserved\n")

    # Generate and write first stage
    print("Generating first stage filter...")
    first_stage_data = generate_first_stage_coefficients()
    write_first_stage(header, body, first_stage_data)
    
    # Print summary matching original script format
    if first_stage_data['total_abs_sum'] > INT32_MAX:
        print("WARNING: error in first stage too large")
    else:
        print(f"Max output of first stage: {first_stage_data['total_abs_sum']}")

    # Generate and write second stage filters
    print("\nGenerating second stage filters...")
    for cutoff in SECOND_STAGE_CONFIG['filters_khz']:
        print(f"  {cutoff} kHz cutoff")
        second_stage_data = generate_second_stage_coefficients(cutoff)
        write_second_stage(header, body, second_stage_data)

    # Write constants and disabled filter
    write_constants(header, body)

    # Generate and write third stage filters
    print("\nGenerating third stage filters...")
    for cutoff in THIRD_STAGE_CONFIG['filters_khz']:
        print(f"  {cutoff} kHz cutoff")
        third_stage_data = generate_third_stage_coefficients(cutoff)
        write_third_stage(header, body, third_stage_data)

    # Write third stage define at the end
    num_taps = THIRD_STAGE_CONFIG['num_taps']
    header.write(f"#define THIRD_STAGE_COEFS_PER_STAGE ({num_taps})\n")

    # Close files
    header.close()
    body.close()

    print("\nFilter coefficient generation complete!")
    print("Output files: fir_coefs.h, fir_coefs.xc")


if __name__ == "__main__":
    main()
