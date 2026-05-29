# SST-XMOS-001 Firmware Test Plan
Version 2.8.0 - eco3026 Branch

## Test Environment Setup

### Hardware Required
- [ ] SST-XMOS-001 board with Vesper VM3000 microphones (boardrev = 15)
- [ ] SST-XMOS-001 board with Infineon IM72D128 microphones (boardrev = 14)
- [ ] SST-XMOS-001 board with Primo EM215 microphones (boardrev = 13)
- [ ] XMOS XTAG debug adapter
- [ ] Linux test machine with USB audio support
- [ ] Acoustic calibrator (94 dB SPL @ 1 kHz)
- [ ] Sound level meter

### Software Required
- [ ] XMOS XTC Tools 15.3.1
- [ ] Target device: Linux with ALSA utilities (arecord) - /bin/sh (ash) shell
- [ ] Analysis machine: Linux/Mac/Windows with Python (numpy, scipy, matplotlib)
- [ ] Audio analysis software on analysis machine (e.g., Audacity, or custom scripts)

---

## Test Cases

### TC-001: Firmware Build
**Objective:** Verify firmware builds without errors

**Steps:**
1. Navigate to `01Firmware/PDM_USB/PDM_USB`
2. Run `xmake clean`
3. Run `xmake`

**Expected Results:**
- [ ] Build completes successfully
- [ ] No compilation errors
- [ ] Binary created: `bin/SST-XMOS-001_v2.8.0.xe`
- [ ] Constraint check passes for tile[0] (8 cores used)
- [ ] Constraint check passes for tile[1]

**Jira Field:** Build Status
**Result:** [ PASS / FAIL ]
**Notes:** ___________________________________________

---

### TC-002: Firmware Flash via XTAG
**Objective:** Verify firmware can be loaded to device via JTAG

**Steps:**
1. Connect XTAG to SST-XMOS-001 board
2. Run `xflash bin/SST-XMOS-001_v2.8.0.xe`

**Expected Results:**
- [ ] Flash operation completes successfully
- [ ] No errors reported
- [ ] Device boots with new firmware

**Jira Field:** Flash Status
**Result:** [ PASS / FAIL ]
**Notes:** ___________________________________________

---

### TC-003: Board Revision Detection - Vesper VM3000
**Objective:** Verify boardrev fuse reading and distribution

**Board Type:** Vesper VM3000
**Expected boardrev:** 15 (0x0F)

**Steps:**
1. Uncomment `BUILD_FLAGS += -DDEBUG` in Makefile
2. Rebuild firmware with `xmake clean && xmake`
3. Flash to Vesper board
4. Run `xrun --io bin/SST-XMOS-001_v2.8.0.xe`
5. Observe console output

**Expected Results:**
- [ ] `boardrev_fuse_read value 15`
- [ ] `boardrev_fuse_wait_value tile 0 retval 15`
- [ ] `boardrev_fuse_wait_value tile 1 retval 15`
- [ ] `user_pdm_init(15) set gain to 1`
- [ ] `In pcm_pdm_mic(), boardrev is 15`

**Jira Field:** Vesper Boardrev Detection
**Result:** [ PASS / FAIL ]
**Boardrev Value Read:** _____
**Notes:** ___________________________________________

---

### TC-004: Board Revision Detection - Infineon IM72D128
**Objective:** Verify boardrev fuse reading and distribution

**Board Type:** Infineon IM72D128
**Expected boardrev:** 14 (0x0E)

**Steps:**
1. Flash firmware to Infineon board
2. Run `xrun --io bin/SST-XMOS-001_v2.8.0.xe`
3. Observe console output

**Expected Results:**
- [ ] `boardrev_fuse_read value 14`
- [ ] `boardrev_fuse_wait_value tile 0 retval 14`
- [ ] `boardrev_fuse_wait_value tile 1 retval 14`
- [ ] `user_pdm_init(14) set gain to 3`
- [ ] `In pcm_pdm_mic(), boardrev is 14`

**Jira Field:** Infineon Boardrev Detection
**Result:** [ PASS / FAIL ]
**Boardrev Value Read:** _____
**Notes:** ___________________________________________

---

### TC-005: Board Revision Detection - Primo EM215
**Objective:** Verify boardrev fuse reading and distribution

**Board Type:** Primo EM215
**Expected boardrev:** 13 (0x0D)

**Steps:**
1. Flash firmware to Primo board
2. Run `xrun --io bin/SST-XMOS-001_v2.8.0.xe`
3. Observe console output

**Expected Results:**
- [ ] `boardrev_fuse_read value 13`
- [ ] `boardrev_fuse_wait_value tile 0 retval 13`
- [ ] `boardrev_fuse_wait_value tile 1 retval 13`
- [ ] `user_pdm_init(13) set gain to 16`
- [ ] `In pcm_pdm_mic(), boardrev is 13`

**Jira Field:** Primo Boardrev Detection
**Result:** [ PASS / FAIL ]
**Boardrev Value Read:** _____
**Notes:** ___________________________________________

---

### TC-006: USB Enumeration - Vesper
**Objective:** Verify device enumerates on Linux host

**Board Type:** Vesper VM3000
**Steps:**
1. Comment out `BUILD_FLAGS += -DDEBUG` in Makefile (production build)
2. Rebuild and flash firmware
3. Connect board to Linux machine via USB
4. Run `lsusb`

**Expected Results:**
- [ ] Device appears in lsusb output
- [ ] VID: 0x20b1
- [ ] PID: 0x0008
- [ ] Device string: "SST-XMOS-001 UAC2.0"

**Jira Field:** Vesper USB Enumeration
**Result:** [ PASS / FAIL ]
**lsusb output:** ___________________________________________

---

### TC-007: USB Enumeration - Infineon
**Objective:** Verify device enumerates on Linux host

**Board Type:** Infineon IM72D128
**Steps:**
1. Connect board to Linux machine via USB
2. Run `lsusb`

**Expected Results:**
- [ ] Device appears in lsusb output
- [ ] VID: 0x20b1
- [ ] PID: 0x0008
- [ ] Device string: "SST-XMOS-001 UAC2.0"

**Jira Field:** Infineon USB Enumeration
**Result:** [ PASS / FAIL ]
**lsusb output:** ___________________________________________

---

### TC-008: USB Enumeration - Primo
**Objective:** Verify device enumerates on Linux host

**Board Type:** Primo EM215
**Steps:**
1. Connect board to Linux machine via USB
2. Run `lsusb`

**Expected Results:**
- [ ] Device appears in lsusb output
- [ ] VID: 0x20b1
- [ ] PID: 0x0008
- [ ] Device string: "SST-XMOS-001 UAC2.0"

**Jira Field:** Primo USB Enumeration
**Result:** [ PASS / FAIL ]
**lsusb output:** ___________________________________________

---

### TC-009: USB Audio Descriptor - Vesper
**Objective:** Verify AudioControl interface descriptors contain correct iTerminal string

**Board Type:** Vesper VM3000
**Expected iTerminal string:** "microphone:vm3000"

**Steps:**
1. Run `lsusb -v -d 20b1:0008 > lsusb_vesper.out`
2. Run `grep "iTerminal.*microphone" lsusb_vesper.out`

**Expected Results:**
- [ ] `iTerminal` field shows "microphone:vm3000"
- [ ] Line matches pattern: `iTerminal              ## microphone:vm3000` (where ## is string index)

**Jira Field:** Vesper USB Descriptor
**Result:** [ PASS / FAIL ]
**iTerminal string:** ___________________________________________

---

### TC-010: USB Audio Descriptor - Infineon
**Objective:** Verify AudioControl interface descriptors contain correct iTerminal string

**Board Type:** Infineon IM72D128
**Expected iTerminal string:** "microphone:im72d128v01"

**Steps:**
1. Run `lsusb -v -d 20b1:0008 > lsusb_infineon.out`
2. Run `grep "iTerminal.*microphone" lsusb_infineon.out`

**Expected Results:**
- [ ] `iTerminal` field shows "microphone:im72d128v01"
- [ ] Line matches pattern: `iTerminal              ## microphone:im72d128v01` (where ## is string index)

**Jira Field:** Infineon USB Descriptor
**Result:** [ PASS / FAIL ]
**iTerminal string:** ___________________________________________

---

### TC-011: USB Audio Descriptor - Primo
**Objective:** Verify AudioControl interface descriptors contain correct iTerminal string

**Board Type:** Primo EM215
**Expected iTerminal string:** "microphone:primo-em215"

**Steps:**
1. Run `lsusb -v -d 20b1:0008 > lsusb_primo.out`
2. Run `grep "iTerminal.*microphone" lsusb_primo.out`

**Expected Results:**
- [ ] `iTerminal` field shows "microphone:primo-em215"
- [ ] Line matches pattern: `iTerminal              ## microphone:primo-em215` (where ## is string index)

**Jira Field:** Primo USB Descriptor
**Result:** [ PASS / FAIL ]
**iTerminal string:** ___________________________________________

---

### TC-012: Audio Recording - Basic Functionality
**Objective:** Verify device can record audio

**Board Type:** Any
**Steps:**
1. Identify device: `arecord -l`
2. Record 5 seconds: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 5 test.wav`
3. Verify file created and playable

**Expected Results:**
- [ ] Recording completes without errors
- [ ] File size is reasonable (~15 MB for 5 seconds, 8 channels)
- [ ] Audio data is present (not all zeros)

**Jira Field:** Basic Recording
**Result:** [ PASS / FAIL ]
**File size (bytes):** _____
**Notes:** ___________________________________________

---

### TC-013: Audio Format Verification
**Objective:** Verify correct sample rate and format

**Steps:**
1. Record audio: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 1 format_test.wav`
2. Check format: `soxi format_test.wav` or `ffprobe format_test.wav`

**Expected Results:**
- [ ] Sample Rate: 96000 Hz
- [ ] Sample Encoding: 32-bit Signed Integer PCM
- [ ] Channels: 8
- [ ] Endianness: Little-endian

**Jira Field:** Audio Format
**Result:** [ PASS / FAIL ]
**Actual Sample Rate:** _____
**Actual Format:** ___________________________________________

---

### TC-014: Gain Verification - Vesper VM3000
**Objective:** Verify digital gain and output level at 94 dB SPL

**Board Type:** Vesper VM3000
**Expected Gain:** 1 (or -1 with phase inversion)
**Mic Sensitivity:** -26 dBFS @ 94 dB SPL
**Target Output:** x dBFS @ 94 dB SPL (TBD based on design intent)

**Steps:**
1. Connect acoustic calibrator (94 dB SPL @ 1 kHz) to microphone
2. Record 10 seconds on target device: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 10 vesper_gain_test.wav`
3. Transfer WAV file to analysis machine (scp, USB, etc.)
4. Analyze channel 0 (or any channel) RMS level in dBFS using Python or Audacity
5. Calculate: Measured dBFS - Expected dBFS = Gain Error

**Expected Results:**
- [ ] Output level is x dBFS ± 1 dB (TBD)
- [ ] No clipping observed
- [ ] Signal is clean 1 kHz tone

**Jira Field:** Vesper Gain
**Result:** [ PASS / FAIL ]
**Measured Level (dBFS):** _____
**Gain Error (dB):** _____
**Notes:** ___________________________________________

---

### TC-015: Gain Verification - Infineon IM72D128
**Objective:** Verify digital gain and output level at 94 dB SPL

**Board Type:** Infineon IM72D128
**Expected Gain:** 3 (or -3 with phase inversion)
**Mic Sensitivity:** -36 dBFS @ 94 dB SPL
**Target Output:** x dBFS @ 94 dB SPL (TBD based on design intent)

**Steps:**
1. Connect acoustic calibrator (94 dB SPL @ 1 kHz) to microphone
2. Record 10 seconds on target device: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 10 infineon_gain_test.wav`
3. Transfer WAV file to analysis machine
4. Analyze channel 0 RMS level in dBFS using Python or Audacity
5. Expected output should be ~9.5 dB higher than Vesper (20*log10(3) ≈ 9.54 dB)

**Expected Results:**
- [ ] Output level is x dBFS ± 1 dB (TBD)
- [ ] No clipping observed
- [ ] Signal is clean 1 kHz tone
- [ ] Level is approximately 9.5 dB higher than Vesper output

**Jira Field:** Infineon Gain
**Result:** [ PASS / FAIL ]
**Measured Level (dBFS):** _____
**Gain Error (dB):** _____
**Difference from Vesper (dB):** _____
**Notes:** ___________________________________________

---

### TC-016: Gain Verification - Primo EM215
**Objective:** Verify digital gain and output level at 94 dB SPL

**Board Type:** Primo EM215
**Expected Gain:** 16 (or -16 with phase inversion)
**Mic Sensitivity:** -67 dBFS @ 94 dB SPL (with ADC)
**Target Output:** x dBFS @ 94 dB SPL (TBD based on design intent)

**Steps:**
1. Connect acoustic calibrator (94 dB SPL @ 1 kHz) to microphone
2. Record 10 seconds on target device: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 10 primo_gain_test.wav`
3. Transfer WAV file to analysis machine
4. Analyze channel 0 RMS level in dBFS using Python or Audacity
5. Expected output should be ~24 dB higher than Vesper (20*log10(16) ≈ 24.08 dB)

**Expected Results:**
- [ ] Output level is x dBFS ± 1 dB (TBD)
- [ ] No clipping observed
- [ ] Signal is clean 1 kHz tone
- [ ] Level is approximately 24 dB higher than Vesper output

**Jira Field:** Primo Gain
**Result:** [ PASS / FAIL ]
**Measured Level (dBFS):** _____
**Gain Error (dB):** _____
**Difference from Vesper (dB):** _____
**Notes:** ___________________________________________

---

### TC-017: Clipping Test - Vesper VM3000
**Objective:** Verify no clipping before microphone AOP

**Board Type:** Vesper VM3000
**Microphone AOP:** 122 dB SPL
**32-bit signed int range:** ±2,147,483,648 (±2^31)

**Steps:**
1. Apply increasing SPL from 94 dB to 122 dB SPL
2. Record at each level: 94, 100, 106, 112, 118, 122 dB SPL
3. Analyze peak values in recordings
4. Check for clipping (samples at ±2^31)

**Expected Results:**
- [ ] No clipping at 122 dB SPL
- [ ] Headroom exists above 122 dB SPL
- [ ] Linear response across SPL range

**Jira Field:** Vesper Clipping Test
**Result:** [ PASS / FAIL ]
**Max SPL without clipping (dB):** _____
**Headroom at AOP (dB):** _____
**Notes:** ___________________________________________

---

### TC-018: Clipping Test - Infineon IM72D128
**Objective:** Verify no clipping before microphone AOP

**Board Type:** Infineon IM72D128
**Microphone AOP:** 130 dB SPL

**Steps:**
1. Apply increasing SPL from 94 dB to 130 dB SPL
2. Record at each level
3. Analyze peak values
4. Check for clipping

**Expected Results:**
- [ ] No clipping at 130 dB SPL
- [ ] Headroom exists above 130 dB SPL
- [ ] Linear response across SPL range

**Jira Field:** Infineon Clipping Test
**Result:** [ PASS / FAIL ]
**Max SPL without clipping (dB):** _____
**Headroom at AOP (dB):** _____
**Notes:** ___________________________________________

---

### TC-019: Clipping Test - Primo EM215
**Objective:** Verify no clipping before microphone AOP

**Board Type:** Primo EM215
**Microphone AOP:** 150 dB SPL

**Steps:**
1. Apply increasing SPL from 94 dB to 150 dB SPL
2. Record at each level
3. Analyze peak values
4. Check for clipping

**Expected Results:**
- [ ] No clipping at 150 dB SPL
- [ ] Headroom exists above 150 dB SPL
- [ ] Linear response across SPL range

**Jira Field:** Primo Clipping Test
**Result:** [ PASS / FAIL ]
**Max SPL without clipping (dB):** _____
**Headroom at AOP (dB):** _____
**Notes:** ___________________________________________

---

### TC-020: Sine Wave Injection - Filter Verification
**Objective:** Verify 2nd and 3rd stage filters using known sine wave

**Board Type:** Any
**Steps:**
1. In `lib_mic_array/src/pdm_rx.S`, uncomment `#define OUTPUT_SINE_WAVE`
2. Rebuild and flash firmware
3. Record audio: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 10 sine_test.wav`
4. Analyze channel 7 (sine wave output channel)
5. Verify sine wave amplitude and frequency
6. Compare to expected filter response

**Expected Results:**
- [ ] Channel 7 contains clean sine wave
- [ ] Amplitude matches expected value after filter stages
- [ ] THD is low (<1%)
- [ ] Filter gain at sine frequency is as expected

**Jira Field:** Sine Wave Test
**Result:** [ PASS / FAIL ]
**Sine frequency (Hz):** _____
**Measured amplitude (dBFS):** _____
**THD (%):** _____
**Notes:** ___________________________________________

---

### TC-021: White Noise Injection - Filter Response
**Objective:** Verify 2nd and 3rd stage filter frequency response using white noise

**Board Type:** Vesper (8 kHz cutoff), then repeat for Infineon (16 kHz) and Primo (40 kHz)

**Steps:**
1. In `lib_mic_array/src/pdm_rx.S`, uncomment `#define OUTPUT_RANDOM`
2. Rebuild and flash firmware
3. Record audio on target device: `arecord -D hw:CARD=SST,DEV=0 -f S32_LE -r 96000 -c 8 -d 30 noise_test.wav`
4. Transfer WAV file to analysis machine
5. Extract channel 7 audio on analysis machine
6. Compute FFT and plot frequency response using Python script (see below)
7. Verify filter cutoff frequency and rolloff

**Expected Results for Vesper:**
- [ ] Channel 7 contains uniform noise (white noise filtered)
- [ ] -3 dB point at approximately 8 kHz
- [ ] Rolloff beyond cutoff frequency
- [ ] Stopband attenuation sufficient

**Expected Results for Infineon:**
- [ ] -3 dB point at approximately 16 kHz
- [ ] Rolloff beyond cutoff frequency
- [ ] Stopband attenuation sufficient

**Expected Results for Primo:**
- [ ] -3 dB point at approximately 40 kHz
- [ ] Rolloff beyond cutoff frequency
- [ ] Stopband attenuation sufficient

**Jira Field:** Filter Response Test
**Result:** [ PASS / FAIL ]
**Measured -3dB point (Hz):** _____
**Rolloff rate (dB/octave):** _____
**Plot attached:** [ YES / NO ]
**Notes:** ___________________________________________

---

### TC-022: Phase Inversion Verification
**Objective:** Verify phase inversion compensation is working

**Steps:**
1. Apply 1 kHz tone at known phase
2. Record audio
3. Verify phase is correct (not inverted)
4. Compare to expected phase

**Expected Results:**
- [ ] Positive acoustic pressure produces positive digital values
- [ ] Phase is not inverted
- [ ] Phase relationship between channels is correct

**Jira Field:** Phase Test
**Result:** [ PASS / FAIL ]
**Notes:** ___________________________________________

---

## Test Summary

### Board-Specific Results

#### Vesper VM3000 (boardrev=15)
- Build: [ PASS / FAIL ]
- Flash: [ PASS / FAIL ]
- Boardrev Detection: [ PASS / FAIL ]
- USB Enumeration: [ PASS / FAIL ]
- USB Descriptors: [ PASS / FAIL ]
- Audio Recording: [ PASS / FAIL ]
- Gain Verification: [ PASS / FAIL ]
- Clipping Test: [ PASS / FAIL ]
- Filter Response (8 kHz): [ PASS / FAIL ]

#### Infineon IM72D128 (boardrev=14)
- Build: [ PASS / FAIL ]
- Flash: [ PASS / FAIL ]
- Boardrev Detection: [ PASS / FAIL ]
- USB Enumeration: [ PASS / FAIL ]
- USB Descriptors: [ PASS / FAIL ]
- Audio Recording: [ PASS / FAIL ]
- Gain Verification: [ PASS / FAIL ]
- Clipping Test: [ PASS / FAIL ]
- Filter Response (16 kHz): [ PASS / FAIL ]

#### Primo EM215 (boardrev=13)
- Build: [ PASS / FAIL ]
- Flash: [ PASS / FAIL ]
- Boardrev Detection: [ PASS / FAIL ]
- USB Enumeration: [ PASS / FAIL ]
- USB Descriptors: [ PASS / FAIL ]
- Audio Recording: [ PASS / FAIL ]
- Gain Verification: [ PASS / FAIL ]
- Clipping Test: [ PASS / FAIL ]
- Filter Response (40 kHz): [ PASS / FAIL ]

---

## Open Issues / Design Questions

### Scaling and Headroom
**Question:** What should the target output level be at 94 dB SPL?

Current implementation appears to target 0 dBFS at the Vesper mic's AOP (122 dB SPL), which would be:
- Vesper @ 94 dB SPL: approximately -28 dBFS (122 - 94 = 28 dB below AOP)
- Infineon @ 94 dB SPL: approximately -28 dBFS + 9.5 dB (gain) = -18.5 dBFS
- Primo @ 94 dB SPL: approximately -28 dBFS + 24 dB (gain) = -4 dBFS

**Concern:** With current gain settings:
- Infineon will clip at ~120.5 dB SPL (130 - 9.5 dB headroom consumed by gain)
- Primo will clip at ~126 dB SPL (150 - 24 dB headroom consumed by gain)

**Recommendation:** Verify the scaling strategy and adjust gains if necessary to ensure no clipping before microphone AOP.

---

## Test Scripts

### Python Script for Filter Analysis (Run on Analysis Machine)
```python
# filter_analysis.py
# Run on analysis machine (with Python, numpy, scipy, matplotlib)
# Not on target device (which only has /bin/sh)

import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
from scipy.io import wavfile

def analyze_filter_response(wav_file, channel=7):
    """Analyze filter frequency response from white noise recording"""
    fs, data = wavfile.read(wav_file)
    
    # Extract channel
    if len(data.shape) > 1:
        channel_data = data[:, channel]
    else:
        channel_data = data
    
    # Compute PSD
    f, psd = signal.welch(channel_data, fs, nperseg=8192)
    
    # Convert to dB
    psd_db = 10 * np.log10(psd)
    
    # Normalize
    psd_db = psd_db - np.max(psd_db)
    
    # Find -3dB point
    idx_3db = np.where(psd_db < -3)[0][0]
    f_3db = f[idx_3db]
    
    # Plot
    plt.figure(figsize=(10, 6))
    plt.semilogx(f, psd_db)
    plt.grid(True)
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Magnitude (dB)')
    plt.title(f'Filter Frequency Response\n-3dB point: {f_3db:.0f} Hz')
    plt.axhline(-3, color='r', linestyle='--', label='-3dB')
    plt.axvline(f_3db, color='r', linestyle='--')
    plt.legend()
    plt.ylim([-60, 5])
    plt.xlim([100, fs/2])
    plt.savefig('filter_response.png', dpi=300)
    plt.show()
    
    print(f"-3dB cutoff frequency: {f_3db:.2f} Hz")
    return f_3db

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python filter_analysis.py <wav_file> [channel]")
        sys.exit(1)
    
    channel = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    analyze_filter_response(sys.argv[1], channel)
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-05 | R. Calhoun | Initial test plan for eco3026 branch |

