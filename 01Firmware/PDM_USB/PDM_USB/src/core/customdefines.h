/**
 * @file       customdefines.h
 * @brief      Defines relating to device configuration and customisation.
 *             For xCORE-200 Microphone Array board
 * @author     Ross Owen, XMOS Limited
 */
#ifndef _CUSTOMDEFINES_H_
#define _CUSTOMDEFINES_H_
#endif

/* Prototype for our custom genclock() task */
void genclock();

#define USER_MAIN_CORES \
            on tile[1] : genclock();

/*
 * Device configuration option defines to override default defines found devicedefines.h
 *
 * Build can be customised but changing and adding defines here
 *
 * Note, we check if they are already defined in Makefile
 */

/* Enable PDM and PDM->PCM conversion code */

/* Defines relating to channel count and channel arrangement (Set to 0 for disable) */
//:audio_defs
/* Number of USB streaming channels - Default is 8 in 2 out */
#ifndef NUM_USB_CHAN_IN
#define NUM_USB_CHAN_IN    (8)         /* Device to Host */
#endif
#ifndef NUM_USB_CHAN_OUT
#define NUM_USB_CHAN_OUT   (0)         /* Host to Device */
#endif

/* Number of IS2 chans to DAC..*/
#ifndef I2S_CHANS_DAC
#define I2S_CHANS_DAC      (0)
#endif

/* Number of I2S chans from ADC */
#ifndef I2S_CHANS_ADC
#define I2S_CHANS_ADC      (0)
#endif

/* Master clock defines (in Hz) */
#define MCLK_48            (512 * 48000)   /* 48 kHz, 96 kHz etc with 24.576 MHz master clock */
#define PDM_MIC_CLK        (64 * 48000)   /* input clock speed for PDM mic (3.072 MHz) */

/* Maximum frequency device runs at */
#ifndef MIN_FREQ
#if(AUDIO_CLASS == 1)
#define MIN_FREQ           (8000)
#else
// TODO: fs limited to 48kHz, originally set to 11.025kHz
#define MIN_FREQ           (48000)
#endif

/* Maximum frequency device runs at */
#ifndef MAX_FREQ
#define MAX_FREQ           (48000)
#endif

/* Maximum frequency in full-speed mode */
#ifndef MAX_FREQ_FS
#define MAX_FREQ_FS        (44100)  /* FS can't handle 8in2out at 48000 */
#endif

//:
/***** Defines relating to USB descriptors etc *****/
//:usb_defs
#define VENDOR_ID          (0x20B1) /* XMOS VID */
#define PID_AUDIO_2        (0x0008)
#define PID_AUDIO_1        (0x0009)
#define PRODUCT_STR_A2     "SST-XMOS-001 UAC2.0"
#define PRODUCT_STR_A1     "SST-XMOS-001 UAC1.0"

/* Avoid compiler warnings by defining vars that will be defaulted */

#define DEFAULT_FREQ            (48000)
#define SPDIF_TX_INDEX          (0)
// DFU name will be "{VENDOR_STR} DFU"
#define VENDOR_STR              "SST"

// BCD_DEVICE is j.m.n version bitpacked into bytes 12 and 13 of the
// USB descriptor as "bcdDevice". This is important for firmware upgrades.

// warnings.h complains about BCD_DEVICE being undefined, but
// code will overwrite with BCD_DEVICE_J, BCD_DEVICE_M, BCD_DEVICE_N

// From src/devicedefines.h:
// "User code should not modify [BCD_DEVICE] but should modify
// BCD_DEVICE_J, BCD_DEVICE_M, BCD_DEVICE_N instead"

// #define BCD_DEVICE              0x0001
#define BCD_DEVICE_J            2
#define BCD_DEVICE_M            0
#define BCD_DEVICE_N            8
#define AUDIO_CLASS             2
#define AUDIO_CLASS_FALLBACK    0

/* this is the default devicedefines.h but add here to be explicit */
#define DFU (1)


#endif
