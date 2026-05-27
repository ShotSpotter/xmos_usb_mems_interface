#!/usr/bin/env python
# Copyright 2016-2021 XMOS LIMITED.
# Copyright 2024-2025 SoundThinking Inc.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

"""
Clean filter coefficient generator for XMOS microphone array decimation filters.

This script generates three stages of FIR filters:
1. First stage: PDM to 384 kHz (8:1 decimation) using lookup tables
2. Second stage: 384 kHz to 192 kHz (2:1 decimation) using Type I FIR
3. Third stage: 192 kHz to 96 kHz (2:1 decimation) using Type I FIR

Key design principle: Separation of coefficient generation from file formatting.
- Coefficient generation functions return data structures
- File writing functions format and write those structures to output files
"""

import datetime
import math
import ctypes
import numpy as np
from scipy import signal
from dataclasses import dataclass
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend; renders to file without requiring a display
import matplotlib.pyplot as plt

# ============================================================================
# CONSTANTS
# ============================================================================

INT32_MAX = np.int64(np.iinfo(np.int32).max)
INT64_MAX = np.int64(np.iinfo(np.int64).max)

# ============================================================================
# DEFINITIONS
# ============================================================================

@dataclass
class FilterSpec:
    """Specification for a single filter variant."""
    num_taps: int
    passband_khz: float
    transition_khz: float
    min_attenuation: float



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

# Second stage: 384 kHz -> 192 kHz (decimation by 2)
# Generate a Type 1 FIR low pass filter designed to address these issues:
# 1) avoid signal aliasing prior to a 2:1 downsample to 192 kHz
# 2) maximize flatness of the frequency response at or below 48 kHz,
#    the Nyquist frequency of the third stage output.

second_stage_taps = 47
min_atten = -60.0

# Stop band is passband_khz + transition_khz
SECOND_STAGE_FILTERS = [
    FilterSpec(num_taps=second_stage_taps, passband_khz=48.0, transition_khz = 48.0, min_attenuation = min_atten),
]

# Third stage: 192 kHz -> 96 kHz (decimation by 2)
# Generate a Type 1 FIR low pass filter designed to address these issues:
# 1) avoid signal aliasing prior to a 2:1 downsample to 96 kHz
# 2) avoid non-linearity in the microphone response, especially
#    with the Vesper VM3000, which has a resonance at ~12.5 kHz
# Generate filters for different microphone types with different cutoff frequencies

third_stage_taps = 47
min_atten = -50.0

# Stop band is passband_khz + transition_khz
THIRD_STAGE_FILTERS = [
    FilterSpec(num_taps=third_stage_taps, passband_khz=40.0, transition_khz =  8.0, min_attenuation = min_atten),
    FilterSpec(num_taps=third_stage_taps, passband_khz=24.0, transition_khz = 12.0, min_attenuation = min_atten),
    FilterSpec(num_taps=third_stage_taps, passband_khz=16.0, transition_khz = 12.0, min_attenuation = min_atten),
    FilterSpec(num_taps=third_stage_taps, passband_khz=12.0, transition_khz = 12.0, min_attenuation = min_atten),
    FilterSpec(num_taps=third_stage_taps, passband_khz= 8.0, transition_khz =  8.0, min_attenuation = min_atten),
]

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


def generate_filter_coefficients(stage_sample_rate: float, filterSpec : FilterSpec):
    """
    Generate second/third stage Type I filter for given filter specification

    Args:
        stage_sample_rate: input sample rate in kHz
        filterSpec: filter specification

    Returns:
        dict with keys:
            'coefs': Filter coefficients (all taps, zero-padded if num coefs is odd)
            'name': Filter name (e.g., '36kHz')
    """

    # Normalize frequencies
    passband = filterSpec.passband_khz / stage_sample_rate
    transition_width = filterSpec.transition_khz / stage_sample_rate

    stopband = passband + transition_width

    a = [1, 0]  # Passband gain = 1, Stopband gain = 0
    w = [1, 1]  # Equal weighting for passband and stopband
    bands = [0, passband,
                stopband, 0.5]

    h = signal.remez(filterSpec.num_taps, bands, a, weight=w)
    (_, H) = signal.freqz(h, worN=2048)
    [stop_band_atten, _, _] = measure_stopband_and_ripple(bands, a, H)

    if stop_band_atten > filterSpec.min_attenuation:
        print(f"  Warning: stop band attenuation {stop_band_atten} for {filterSpec.passband_khz} is less than target {filterSpec.min_attenuation}")

    coefs = h
    # Check if filter generation succeeded
    if coefs is None:
        raise ValueError(f"Failed to generate {filterSpec.num_taps}-tap filter for {filterSpec.passband_khz} kHz cutoff. "
                        f"Try adjusting transition width, number of taps, or cutoff frequency.")

    # Normalize to prevent overflow
    coefs /= sum(abs(coefs))

    # Squish near-zero values (numerical noise from Remez) to exactly zero
    coefs[np.abs(coefs) < 1.0e-8] = 0.0

    name = f"{int(round(filterSpec.passband_khz))}kHz"

    return {
        'coefs': coefs,
        'name': name
    }



# ============================================================================
# PLOTTING FUNCTIONS
# ============================================================================

def plot_stage_filters(stagename, sample_rate_khz, filter_data_list, spec_list, show_title=False):
    """
    Plot frequency responses for all filters in a stage and save to PDF.

    Args:
        stagename: Name of the stage (e.g., 'second_to_third')
        sample_rate_khz: Input sample rate in kHz
        filter_data_list: List of dicts from generate_filter_coefficients
        spec_list: List of FilterSpec objects corresponding to filter_data_list
    """
    # IEEE page-wide figure (7.16 in) with golden-ratio height
    PHI = (1.0 + np.sqrt(5.0)) / 2.0
    fig_width = 7.16          # inches — IEEE page width
    fig_height = fig_width / PHI

    FONT_SIZE_LABEL  = 10
    FONT_SIZE_TICK   =  9
    FONT_SIZE_LEGEND =  9
    FONT_SIZE_TITLE  = 10
    LINE_WIDTH_DATA  = 1.5
    LINE_WIDTH_EDGE  = 1.0
    LINE_WIDTH_NYQUIST = 1.5

    fig, ax = plt.subplots(figsize=(fig_width, fig_height))
    colors = [plt.cm.tab10(i) for i in range(len(filter_data_list))]
    worN = 8192

    for i, (fdata, spec) in enumerate(zip(filter_data_list, spec_list)):
        coefs = fdata['coefs']
        name = f"{fdata['name']} passband"
        color = colors[i]

        _, H = signal.freqz(coefs, worN=worN)
        freqs_khz = np.linspace(0, sample_rate_khz / 2.0, worN)
        mag_db = 20.0 * np.log10(np.maximum(np.abs(H), 1e-12))

        ax.plot(freqs_khz, mag_db, color=color, label=name, linewidth=LINE_WIDTH_DATA)

        stopband_khz = spec.passband_khz + spec.transition_khz
        ax.axvline(spec.passband_khz, color=color, linestyle='--', linewidth=LINE_WIDTH_EDGE, alpha=0.7)
        ax.axvline(stopband_khz,      color=color, linestyle=':',  linewidth=LINE_WIDTH_EDGE, alpha=0.7)


    ax.set_xlabel('Frequency (kHz)', fontsize=FONT_SIZE_LABEL)
    ax.set_ylabel('Magnitude (dB)', fontsize=FONT_SIZE_LABEL)
    ax.tick_params(axis='both', labelsize=FONT_SIZE_TICK)
    if show_title:
        ax.set_title(
            f'{stagename} — Frequency Response\n'
            f'Input: {sample_rate_khz:.0f} kHz  |  '
            f'Dashed: passband edge  |  Dotted: stopband edge',
            fontsize=FONT_SIZE_TITLE
        )
    ax.set_xlim(0, 0.3125 * sample_rate_khz)
    ax.set_ylim(-70, 5)
    if sample_rate_khz > 300:
        ax.xaxis.set_major_locator(plt.MultipleLocator(12.0))
    else:
        ax.xaxis.set_major_locator(plt.MultipleLocator(4.0))
    ax.legend(loc='lower left', fontsize=FONT_SIZE_LEGEND)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()

    filename = f'filter_response_{stagename}.pdf'
    try:
        fig.savefig(filename, bbox_inches='tight', dpi=300)
        print(f"  Saved plot: {filename}")
    except Exception:
        filename = f'filter_response_{stagename}.png'
        fig.savefig(filename, bbox_inches='tight', dpi=300)
        print(f"  Saved plot: {filename}")
    plt.close(fig)


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


def write_stage(stagename, header, body, coef_data):
    """Write [stagename] stage Type I filter coefficients to files."""
    coefs = coef_data['coefs']
    name = coef_data['name']
    # actual number of taps e.g. "47"
    num_taps = len(coefs)

    # Type I filters: Output all coefficients plus padding zero for alignment
    # XMOS ldd instruction requires double-word alignment, so pad to even count.
    if coefs.shape[0] % 2 == 1:
        coefs = np.append(coefs, 0.0)

    num_output_coefs = coefs.shape[0]

    dc_gain = coefs.sum()
    body.write(f"const float g_{stagename}_fir{num_taps}_{name}_gain = {dc_gain};\n\n")

    body.write(f"const int g_{stagename}_fir{num_taps}_{name}_gain_scaling_factor = {int(1.0/dc_gain)};\n\n")

    header.write(f"extern const int g_{stagename}_fir{num_taps}_{name}[{num_output_coefs}];\n")
    body.write(f"const int g_{stagename}_fir{num_taps}_{name}[{num_output_coefs}] = {{\n    ")

    # Write all coefficients
    for i in range(num_output_coefs):
        d_int = np.int32(coefs[i] * float(INT32_MAX))
        body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
        body.write(break_every_8(i))

    body.write("};\n\n")

    # Write debug coefficients (full precision decimal, including padding)
    header.write(f"extern const int g_{stagename}_fir{num_taps}_{name}_debug[{num_output_coefs}];\n")
    header.write("\n")
    body.write(f"const int g_{stagename}_fir{num_taps}_{name}_debug[{num_output_coefs}] = {{\n    ")

    for i, coef in enumerate(coefs):
        decimalized_coef = int(float(INT32_MAX) * coef)
        body.write(f"{decimalized_coef:10d},")
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

# ============================================================================
# MAIN
# ============================================================================

def main():
    """Generate all filter coefficients and write to output files."""

    # Open output files
    header = open("fir_coefs_cascade.h", 'w', newline='')
    body = open("fir_coefs_cascade.xc", 'w', newline='')

    # Write copyright headers
    year = datetime.datetime.now().year
    header.write(f"// Copyright (c) {year}, XMOS Ltd, All rights reserved\n")
    header.write(f"// Copyright (c) {year}, SoundThinking Inc.\n")
    body.write(f"// Copyright (c) {year}, XMOS Ltd, All rights reserved\n")
    body.write(f"// Copyright (c) {year}, SoundThinking Inc.\n")

    # Avoid conflicts with the old code
    print_first_stage = False
    if print_first_stage:
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
    second_stage_results = []
    second_stage_rate = PDM_SAMPLE_RATE_KHZ / 8.0
    for filter_spec in SECOND_STAGE_FILTERS:
        print(f"  {filter_spec.passband_khz} kHz passband")
        second_stage_data = generate_filter_coefficients(second_stage_rate, filter_spec)
        second_stage_results.append(second_stage_data)
        write_stage("second_to_third", header, body, second_stage_data)
    plot_stage_filters("second_to_third", second_stage_rate, second_stage_results, SECOND_STAGE_FILTERS)

    # Generate and write third stage filters
    print("\nGenerating third stage filters...")
    third_stage_results = []
    third_stage_rate = PDM_SAMPLE_RATE_KHZ / (8.0 * 2.0)
    for filter_spec in THIRD_STAGE_FILTERS:
        print(f"  {filter_spec.passband_khz} kHz passband")
        third_stage_data = generate_filter_coefficients(third_stage_rate, filter_spec)
        third_stage_results.append(third_stage_data)
        write_stage("third_to_output", header, body, third_stage_data)
    plot_stage_filters("third_to_output", third_stage_rate, third_stage_results, THIRD_STAGE_FILTERS)

    if print_first_stage:
        # Write third stage define at the end
        num_taps = THIRD_STAGE_FILTERS[0].num_taps
        header.write(f"#define THIRD_STAGE_COEFS_PER_STAGE ({num_taps})\n")


    if print_first_stage:
        # Write constants
        write_constants(header, body)

    # Close files
    header.close()
    body.close()

    print("\nFilter coefficient generation complete!")
    print("Output files: fir_coefs.h, fir_coefs.xc")


if __name__ == "__main__":
    main()
