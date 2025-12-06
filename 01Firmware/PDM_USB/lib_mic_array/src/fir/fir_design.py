#!/usr/bin/env python
# Copyright 2016-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import argparse
import numpy
import scipy
import ctypes
import matplotlib
import sys
import math
import datetime
from scipy import signal
import numpy as np
import matplotlib.pyplot as plt

int32_max = np.int64(np.iinfo(np.int32).max)
int64_max = np.int64(np.iinfo(np.int64).max)

###############################################################################

def parseArguments(third_stage_configs):
    parser = argparse.ArgumentParser(description="Filter builder")

    #this must be set for all other bandwidths to be relative to
    parser.add_argument('--pdm-sample-rate', type=float, default=3072.0,
                        help='The sample rate (in kHz) of the PDM microphones',
                        metavar='kHz')

    parser.add_argument('--use-low-ripple-first-stage', type=bool, default=False,
      help='Use the lowest ripple possible for the given output passband.')

    parser.add_argument('--first-stage-num-taps', type=int, default=48,
      help='The number of FIR taps in the first stage of decimation.')
    parser.add_argument('--first-stage-pass-bw', type=float, default = 96.0,
      help='The pass bandwidth (in kHz) of the first stage filter.'
          ' Starts at 0Hz and ends at this frequency', metavar='kHz')
    parser.add_argument('--first-stage-stop-bw', type=float, default = 192.0,
      help='The stop bandwidth (in kHz) of the first stage filter.',
      metavar='kHz')
    parser.add_argument('--first-stage-stop-atten', type=float, default = -80.0,
      help='The stop band attenuation(in dB) of the first stage filter(Normally negative).', metavar='dB')

    parser.add_argument('--second-stage-pass-bw', type=float, default=12,
       help='The pass bandwidth (in kHz) of the second stage filter '
          ' Starts at 0Hz and ends at this frequency', metavar='kHz')
    parser.add_argument('--second-stage-stop-bw', type=float, default=23.999,
       help='The stop bandwidth (in kHz) of the second stage filter.'
          ' Starts at 0Hz and ends at this frequency', metavar='kHz')
    parser.add_argument('--second-stage-stop-atten', type=float, default = -80.0,
      help='The stop band attenuation(in dB) of the second stage filter(Normally negative).', metavar='dB')

    parser.add_argument('--third-stage-num-taps', type=int, default=32,
       help='The number of FIR taps per stage '
      '(decimation factor). The fewer there are the lower the group delay.')

    parser.add_argument('--third-stage-stop-atten', type=float, default = -70.0,
      help='The stop band attenuation(in dB) of the third stage filter(Normally negative).', metavar='dB')

    parser.add_argument('--add-third-stage', nargs=5,
      help='Add a custom third stage filter; e.g. 6 6.2 8.1 custom_16k_filt 32',
                        metavar=('DIVIDER', 'PASS_BANDWIDTH', 'STOP_BAND_START', 'NAME', 'NUM_TAPS'))

    args = parser.parse_args()

    to_add = args.add_third_stage
    if to_add:
        pdm_rate = float(args.pdm_sample_rate)
        print("****** Input rate for custom filter: " + str(args.pdm_sample_rate) + "kHz. ********")
        try:
            divider = int(to_add[0])
            passbw = float(to_add[1])
            stopbw = float(to_add[2])
            name = str(to_add[3])
            num_taps = int(to_add[4])
            norm_pass = passbw / (pdm_rate/8/4 / divider)
            norm_stop = stopbw / (pdm_rate/8/4 / divider)
            third_stage_configs.append(
                [divider, norm_pass, norm_stop, name, num_taps, True])
        except:
            print("ERROR: Invalid arguments for third stage")
            sys.exit(1)

    return args

###############################################################################

def measure_stopband_and_ripple(bands, a, H):

    passband_max = float('-inf')
    passband_min = float('inf')
    stopband_max = float('-inf')

    # freq = 0.5*np.arange(len(h))/len(h)
    # mag  = 20.0*np.log10(H)

    #The bands are evenly spaced throughout 0 to 0.5 of the bandwidth
    for h in range(0, H.size):
      freq = 0.5*h/(H.size)
      mag = 20.0 * numpy.log10(abs(H[h]))
      for r in range(0, len(bands), 2):
        if freq > bands[r] and freq < bands[r+1]:
          if a[r//2] == 0:
            stopband_max = max(stopband_max, mag)
          else:
            passband_max = max(passband_max, mag)
            passband_min = min(passband_min, mag)

    return [stopband_max, passband_max, passband_min]

###############################################################################

def plot_response(H, file_name):
  magnitude_response = 20 * numpy.log10(abs(H))
  input_freq = numpy.arange(0.0, 0.5, 0.5/len(magnitude_response))
  plt.clf()
  plt.plot(input_freq, magnitude_response)
  plt.ylabel('Magnitude Response')
  plt.xlabel('Normalised Input Freq')
  plt.savefig(file_name +'.pdf', format='pdf', dpi=1000)

###############################################################################

# function to help format filters in a consistent way
def break_every_8(i, indent="    "):
  whitespace = ""
  if(i%8 == 7):
    whitespace = "\n" + indent
  else:
    whitespace = " "
  return whitespace

########################################

def generate_stage(num_taps, bands, a, weights, divider=1, num_frequency_points=2048, stopband_attenuation = -65.0):

  print(f"calling generate_stage num_taps={num_taps}, bands={bands}, a={a}, weights={weights}, stopband_attenuation={stopband_attenuation} ")
  w = np.ones(len(a))

  weight_min = 0.0
  weight_max = 1024.0

  running = True

  epsilon = 0.0000000001

  while running:
    test_weight = (weight_min + weight_max)/2.0
    for i in range(0, len(a)-1):
      if a[i] != 0:
        w[i] = test_weight*weights[i]
    # w = weights*test_weight*(a!= 0.0)

    try:
      h = signal.remez(num_taps, bands, a, weight=w)

      (_, H) = signal.freqz(h, worN=2048)

      [stop_band_atten, passband_min, passband_max ] = measure_stopband_and_ripple(bands, a, H)

      if (-stop_band_atten) >  -stopband_attenuation:
        weight_min = test_weight
      else:
        weight_max = test_weight

      #print(f"stop_band_atten={stop_band_atten},  passband_max={passband_max}, passband_min={passband_min}, test_weight={test_weight}")
      if abs(weight_min - weight_max) < epsilon:
        running=False
    except ValueError:
      if abs(test_weight - weight_max) < epsilon:
        print("Failed to converge - unable to create filter")
        return
      else:
        weight_min = test_weight

  (_, H) = signal.freqz(h, worN=num_frequency_points)

  return H, h

###############################################################################

def generate_first_stage(header, body, points, pbw, sbw, first_stage_num_taps, first_stage_stop_atten):

  nulls = 1.0/8.0
  a = np.zeros(2)
  a[0] = 1.0
  w = np.ones(len(a))

  bands = [ 0, pbw, nulls-sbw, 0.5]

  return first_stage_output_coefficients(header, body, points, first_stage_num_taps, first_stage_stop_atten, nulls, a, w, bands)

def generate_first_stage_low_ripple(header, body, points, pbw, sbw, first_stage_num_taps, first_stage_stop_atten):

  nulls = 1.0/8.0
  a = np.zeros(5)
  a[0] = 1.0
  w = np.ones(len(a))
  bands = [ 0,           pbw,
            nulls*1-sbw, nulls*1+sbw,
            nulls*2-sbw, nulls*2+sbw,
            nulls*3-sbw, nulls*3+sbw,
            nulls*4-sbw, 0.5]

  return first_stage_output_coefficients(header, body, points, first_stage_num_taps, first_stage_stop_atten, nulls, a, w, bands)

def first_stage_output_coefficients(header, body, points, first_stage_num_taps, first_stage_stop_atten, nulls, a, w, bands):

  first_stage_response, coefs =  generate_stage(
    first_stage_num_taps, bands, a, w, stopband_attenuation = first_stage_stop_atten)

  #ensure the there is never any overflow
  coefs /= sum(abs(coefs))

  total_abs_sum = 0
  for t in range(0, len(coefs)//(8*2)):
    header.write(f"extern const int g_first_stage_fir_{str(t)}[256];\n")
    body.write(         f"const int g_first_stage_fir_{str(t)}[256] = {{\n    ")
    max_for_block = np.int64(0)
    for x in range(0, 256):
      d=0.0
      for b in range(0, 8):
        if(((x>>(7-b))&1) == 1) :
          d = d + coefs[t*8 + b]
        else:
          d = d - coefs[t*8 + b]
      d_int = np.int32(d*np.float64(int32_max))
      max_for_block = max(max_for_block, np.abs(np.int64(d_int)))
      body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
      body.write(break_every_8(x))
    body.write("};\n\n")
    total_abs_sum += (max_for_block*2)

  if total_abs_sum > int32_max:
    print("WARNING: error in first stage too large")
  else:
    print("Max output of first stage: " + str(total_abs_sum))

  header.write(f"extern const int g_first_stage_fir_debug[{str(first_stage_num_taps)}];\n")
  body.write(         f"const int g_first_stage_fir_debug[{str(first_stage_num_taps)}] = {{\n    ")
  for i in range(0, len(coefs)):
    body.write("{:10d},".format(int(float(int32_max)*coefs[i])))
    body.write(break_every_8(i))
  body.write("};\n")
  body.write("\n")

  (_, H) = signal.freqz(coefs, worN=points)
  plot_response(H, 'first_stage')
  [stop, passband_min, passband_max] = measure_stopband_and_ripple(bands, a, H)
  max_passband_output = int(float(int32_max) * 10.0 ** (passband_max/20.0) + 1)
  header.write("\n")
  header.write("#define FIRST_STAGE_MAX_PASSBAND_OUTPUT (" + str(max_passband_output) +")\n")
  header.write("\n")

  return H


###############################################################################

# Despite how this is used in the reference code, sbw is actually a transition half-width,
# not a stop band frequency. The reference code only works because it is called with
# pbw = 0.0313 (12 kHz), sbw = 0.0625 (24 kz) resulting in
# bands = [0, 0.0313, 0.0625, 0.1875, 0.1875, 0.5]

def generate_second_stage(header, body, points, pbw, sbw, second_stage_num_taps, stop_band_atten):

  # This must reflect the output decimation ratio: 48/384 => 1/8
  nulls = 1.0/8.0
  a = [1, 0, 0]
  w = [1, 1, 1]

  bands = [ 0,           pbw,
            nulls*1-sbw, nulls*1+sbw,
            nulls*2-sbw, 0.5]

  second_stage_response, coefs =  generate_stage(
    second_stage_num_taps, bands, a, w, stopband_attenuation = stop_band_atten)


  #ensure the there is never any overflow
  coefs /= sum(abs(coefs))

  passband_kHz = int(pbw * 384)

  header.write(f"extern const int g_second_stage_fir32_{passband_kHz}kHz[{len(coefs)//2}];\n")
  body.write(         f"const int g_second_stage_fir32_{passband_kHz}kHz[{len(coefs)//2}] = {{\n    ")

  total_abs_sum = np.int64(0)
  for i in range(0, len(coefs)//2):
    if coefs[i] > 0.5:
      print("Single coefficient too big in second stage FIR")
    d_int = np.int32(coefs[i]*float(int32_max)*2.0)
    total_abs_sum += np.abs(np.int64(d_int)*2)
    body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
    body.write(break_every_8(i))
  body.write("};\n\n")

  if total_abs_sum*int32_max > int64_max:
    print("WARNING: error in second stage too large")

  # Same filter in a decimal format for python / matlab
  header.write(f"extern const int g_second_stage_fir32_{passband_kHz}kHz_debug[{str(second_stage_num_taps)}];\n")
  header.write("\n")
  body.write(         f"const int g_second_stage_fir32_{passband_kHz}kHz_debug[{str(second_stage_num_taps)}] = {{\n    ")
  for i in range(0, len(coefs)):
    decimalized_coef = int(float(int32_max)*coefs[i])
    body.write(f"{decimalized_coef:10d},")
    body.write(break_every_8(i))
  body.write("};\n\n")

  (_, H) = signal.freqz(coefs, worN=points) # this is where the ripple is derived from
  plot_response(H, 'second_stage')

  [stop, passband_min, passband_max] = measure_stopband_and_ripple(bands, a, H)

  # plt.clf()
  # plt.plot(np.log10(np.abs(H))*20.)
  # plt.show()
  return H

###############################################################################
def generate_constant_expressions(taps):

  header.write(f"extern const int g_crc_constants[2];\n")
  header.write("\n")

  body.write("// CRC polynominal to use, bogus data to checksum\n")
  body.write("const int g_crc_constants[2] = {0xEDB88320, 0xFFFFFFFF};\n")
  body.write("\n")

  body.write("// Fake filter used to disable third stage entirely.\n")
  N = taps
  coefs = np.zeros(N)
  num_output_coefs = N // 2
  name = 'g_third_stage_fir_' + 'disabled'
  header.write(f"extern const int {name}[{num_output_coefs}];\n")
  body.write(         f"const int {name}[{num_output_coefs}] = {{\n    ")
  print(f"creating third stage disabled coefficients")
  print(coefs)
  for i in range(0, num_output_coefs):
    d_int = np.int32(coefs[i]*float(int32_max)*2.0)
    body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
    body.write(break_every_8(i))
  body.write("};\n\n")

  return


###############################################################################

def generate_third_stage_coefficients(body, name, Fs, fc, N):

# this uses the window technique to generate all N coefficients
  coefs = np.zeros(N)
  for n in range(0, N):
    m = n - ((N - 1) / 2)
    gamma = (2.0 * math.pi * fc) / Fs
    h = math.sin(m * gamma) / (m * math.pi)
    n_w = n - (N / 2)
    h_w = 0.54 + 0.46 * math.cos((math.pi * (2.0 * n_w + 1)) / (N - 1.0))
    coefs[n] = h * h_w

  # Use same method as second stage to ensure the there is never any overflow
  # Use of abs() covers worst-case situation where data and coefficients match in sign.
  coefs /= sum(abs(coefs))

  # Filter is symmetric, so only output the first half of coefficients
  num_output_coefs = N // 2
  total_abs_sum = np.int64(0)
  header.write(f"extern const int {name}[{num_output_coefs}];\n")
  body.write(         f"const int {name}[{num_output_coefs}] = {{\n    ")
  print(f"creating third stage coefficients: {name} with {N} poles, {num_output_coefs} coefficients output (symmetric), Fs: {int(Fs/1000)} kHz and fc: {int(fc/1000)} kHz")
  print(coefs)
  for i in range(0, num_output_coefs):
    if coefs[i] > 0.5:
      print("Single coefficient too big in third-stage FIR")
    d_int = np.int32(coefs[i]*float(int32_max)*2.0)
    total_abs_sum += np.abs(np.int64(d_int)*2)
    body.write(f"0x{ctypes.c_uint(d_int).value:08x},")
    body.write(break_every_8(i))
  body.write("};\n\n")

  if total_abs_sum*int32_max > int64_max:
    print("WARNING: error in second stage too large")

def generate_third_stage(header, body, third_stage_configs, combined_response, points, input_sample_rate, stop_band_atten):

  Fs = 96000.0					# sampling frequency
  fcList = [47999, 40000, 32000, 24000, 16000, 12000, 8000]   # critical frequency
  N = 32					# coefficients
  for listIndex in range(0, len(fcList)):
    fc = fcList[listIndex]
    fcName = str(int(fc / 1000)) + 'kHz'
    name = 'g_third_stage_fir_' + fcName
    generate_third_stage_coefficients(body, name, Fs, float(fc), N)


###############################################################################

if __name__ == "__main__":
  # Each entry generates a output
  third_stage_configs = [
      #divider, normalised pb, normalised sb, name, taps per phase, is_custom
      [2,  0.38, 0.50, "div_2", 32, False],
      [4,  0.42, 0.52, "div_4", 32, False],
      [6,  0.42, 0.52, "div_6", 32, False],
      [8,  0.42, 0.52, "div_8", 32, False],
      [12, 0.42, 0.52, "div_12", 32, False]
  ]
  args = parseArguments(third_stage_configs)

  input_sample_rate = args.pdm_sample_rate
  input_band_width = input_sample_rate/2.0
  first_stage_pbw = args.first_stage_pass_bw/args.pdm_sample_rate
  first_stage_sbw = args.first_stage_stop_bw/args.pdm_sample_rate
  first_stage_num_taps = int(args.first_stage_num_taps)
  first_stage_stop_band_atten = args.first_stage_stop_atten
  first_stage_low_ripple = args.use_low_ripple_first_stage

#warnings
  if first_stage_stop_band_atten > 0:
      print("Warning first stage stop band attenuation is positive.")

  print("Filter Configuration:")
  print("Input(PDM) sample rate: " + str(input_sample_rate) + "kHz")
  print("First Stage")
  print("Num taps: " + str(first_stage_num_taps))
  print("Pass bandwidth: " + str(args.first_stage_pass_bw) + "kHz of " + str(input_band_width) + "kHz total bandwidth.")
  print("Pass bandwidth(normalised): " + str(first_stage_pbw*2) + " of Nyquist.")
  print("Stop band attenuation: " + str(first_stage_stop_band_atten)+ "dB.")
  print("Stop bandwidth: " + str(args.first_stage_stop_bw) + "kHz")
  print("Lowest Ripple: " + str(first_stage_low_ripple) )


  header = open ("fir_coefs.h", 'w', newline='')
  body   = open ("fir_coefs.xc", 'w', newline='')

  year = datetime.datetime.now().year
  header.write("// Copyright (c) " +str(year) +", XMOS Ltd, All rights reserved\n")
  body.write("// Copyright (c) " +str(year) +", XMOS Ltd, All rights reserved\n")

  points = 8192*8
  combined_response = []

  if first_stage_low_ripple:
    first_stage_response = generate_first_stage_low_ripple(header, body, points, first_stage_pbw, first_stage_sbw, first_stage_num_taps, first_stage_stop_band_atten)
  else:
    first_stage_response = generate_first_stage(header, body, points, first_stage_pbw, first_stage_sbw, first_stage_num_taps, first_stage_stop_band_atten)
  #Save the response between 0 and 48kHz
  for r in range(0, (points//(8*4))+1):
    combined_response.append(abs(first_stage_response[r]))

  second_stage_num_taps = 32
  second_stage_pbw = args.second_stage_pass_bw/(input_sample_rate/8.0)
  second_stage_sbw = args.second_stage_stop_bw/(input_sample_rate/8.0)
  second_stage_stop_band_atten = args.second_stage_stop_atten

  print("")
#warnings
  if second_stage_stop_band_atten > 0:
      print("Warning second stage stop band attenuation is positive.")

  print("Second Stage")
  print("Num taps: " + str(second_stage_num_taps))
  print("Pass bandwidth: " + str(args.second_stage_pass_bw) + "kHz of " + str(input_sample_rate/8.0) + "kHz total bandwidth.")
  print("Pass bandwidth(normalised): " + str(second_stage_pbw*2) + " of Nyquist.")
  print("Stop band attenuation: " + str(second_stage_stop_band_atten)+ "dB.")
  print("Stop bandwidth: " + str(args.second_stage_stop_bw) + "kHz")


  # third stage filter list: fcList = [40000, 32000, 24000, 16000, 12000, 8000]   # critical frequency

  second_stage_filters_kHz = [43.999, 42.0, 36.0, 28.0, 20.0, 12.0]
  for f in second_stage_filters_kHz:
    print(f"Generate three-band 2nd stage with pass band {f}kHz")
    second_stage_response = generate_second_stage(header, body, points//8, f/(input_sample_rate/8.0), 4.0/(input_sample_rate/8.0), second_stage_num_taps, -65.0)

#  second_stage_response = generate_second_stage(header, body, points//8, second_stage_pbw, second_stage_sbw - second_stage_pbw, second_stage_num_taps, second_stage_stop_band_atten)


  for r in range(0, points//(8*4)):
    combined_response[r] = combined_response[r] * abs(second_stage_response[r])

  generate_constant_expressions(second_stage_num_taps)

  third_stage_stop_band_atten = args.third_stage_stop_atten
  print("")
#warnings
  if third_stage_stop_band_atten > 0:
      print("Warning third stage stop band attenuation is positive.")

  print("Third Stage")
  generate_third_stage(header, body, third_stage_configs, combined_response, points//(8*4), input_sample_rate/8.0/4.0, third_stage_stop_band_atten)

  header.write("#define THIRD_STAGE_COEFS_PER_STAGE (32)\n")
  
  header.close()
  body.close()
