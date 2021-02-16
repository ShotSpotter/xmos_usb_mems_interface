/*
 * @brief       Defines relating to device configuration and customisation.
 * @author      Ross Owen, XMOS Limited
 */

#ifndef _DEVICEDEFINES_H_
#define _DEVICEDEFINES_H_

#include "customdefines.h"

/* Default tile arrangement */

/**
 * @brief Location (tile) of IAP. Default: AUDIO_IO_TILE
 */
#ifndef IAP_TILE
#define IAP_TILE        AUDIO_IO_TILE
#endif

/**
 * @brief Location (tile) of MIDI I/O. Default: AUDIO_IO_TILE
 */
#ifndef MIDI_TILE
#define MIDI_TILE       AUDIO_IO_TILE
#endif

/**
 * @brief Location (tile) of SPDIF Tx. Default: AUDIO_IO_TILE
 */
#ifndef SPDIF_TX_TILE
#define SPDIF_TX_TILE   AUDIO_IO_TILE
#endif

/**
 * @brief Number of DSD output channels. Default: 0 (disabled)
 */
#define DSD_CHANS_DAC        0

/**
 * @brief Channels per I2S frame. *
 *
 * Default: 2 i.e standard stereo I2S (8 if using TDM i.e. I2S_MODE_TDM).
 *
 **/
#define I2S_CHANS_PER_FRAME 2

/**
 * @brief Number of IS2 channesl to DAC/CODEC. Must be a multiple of 2.
 *
 * Default: NONE (Must be defined by app)
 */
#define I2S_WIRES_DAC            (I2S_CHANS_DAC / I2S_CHANS_PER_FRAME)


/**
 * @brief Number of I2S channels from ADC/CODEC. Must be a multiple of 2.
 *
 * Default: NONE (Must be defined by app)
 */
#define I2S_WIRES_ADC            (I2S_CHANS_ADC / I2S_CHANS_PER_FRAME)

/**
 * @brief Default device sample frequency. A safe default should be used. Default: MIN_FREQ
 */
#ifndef DEFAULT_FREQ
#define DEFAULT_FREQ             (MAX_FREQ)
#endif

/* Audio Class Defines */

/**
 * @brief USB Audio Class Version. Default: 2 (Audio Class version 2.0)
 */
#ifndef AUDIO_CLASS
#define AUDIO_CLASS 2
#endif

/**
 * @brief Whether or not to fall back to Audio Class 1.0 in USB Full-speed. Default: 0 (Disabled)
 */
#ifndef AUDIO_CLASS_FALLBACK
#define AUDIO_CLASS_FALLBACK  0     /* Default to not falling back to UAC 1 */
#endif

#if defined(AUDIO_CLASS_FALLBACK) && (AUDIO_CLASS_FALLBACK==0)
#undef AUDIO_CLASS_FALLBACK
#endif

/**
 * @brief Whether or not to run UAC2 in full-speed. When disabled device can either operate in
 *        UAC1 mode in full-speed (if AUDIO_CLASS_FALLBACK enabled) or return "null" descriptors.
 *
 * Default: 1 (Enabled) when AUDIO_CLASS_FALLBACK disabled.
 */
#if (AUDIO_CLASS == 2)
    /* Whether to run in Audio Class 2.0 mode in USB Full-speed */
    #if !defined(FULL_SPEED_AUDIO_2) && !defined(AUDIO_CLASS_FALLBACK)
        #define FULL_SPEED_AUDIO_2    1     /* Default to falling back to UAC2 */
    #endif
#endif

/* Some checks on full-speed functionality */
#if defined(FULL_SPEED_AUDIO_2) && defined(AUDIO_CLASS_FALLBACK)
#error FULL_SPEED_AUDIO_2 and AUDIO_CLASS_FALLBACK enabled!
#endif

#if (AUDIO_CLASS == 1) && defined(FULL_SPEED_AUDIO_2)
#error AUDIO_CLASS set to 1 and FULL_SPEED_AUDIO_2 enabled!
#endif


/* Feature defines */

/**
 * @brief Enable DFU functionality. A driver required for Windows operation.
 *
 * Default: 1 (Enabled)
 */
#define DFU                   (1)

/**
 * @brief Vendor String used by the device. This is also pre-pended to various strings used by the design.
 *
 * Default: "XMOS"
 */
#ifndef VENDOR_STR
#define VENDOR_STR               "XMOS"
#endif

/**
 * @brief Device firmware version number in Binary Coded Decimal format: 0xJJMN where JJ: major, M: minor, N: sub-minor version number.
 */
#define BCD_DEVICE_J             0

/**
 * @brief Device firmware version number in Binary Coded Decimal format: 0xJJMN where JJ: major, M: minor, N: sub-minor version number.
 */
#define BCD_DEVICE_M             1

/**
 * @brief Device firmware version number in Binary Coded Decimal format: 0xJJMN where JJ: major, M: minor, N: sub-minor version number.
 */
#define BCD_DEVICE_N             0

/**
 * @brief Device firmware version number in Binary Coded Decimal format: 0xJJMN where JJ: major, M: minor, N: sub-minor version number.
 *
 * NOTE: User code should not modify this but should modify BCD_DEVICE_J, BCD_DEVICE_M, BCD_DEVICE_N instead
 *
 * Default: XMOS USB Audio Release version (e.g. 0x0651 for 6.5.1).
 */
#define BCD_DEVICE               ((BCD_DEVICE_J << 8) | ((BCD_DEVICE_M & 0xF) << 4) | (BCD_DEVICE_N & 0xF))

/**
 * @brief Number of supported output stream formats.
 *
 * Values 1,2,3 supported
 *
 * Default: 2
 */

#define OUTPUT_FORMAT_COUNT 2

#if(OUTPUT_FORMAT_COUNT > 3)
    #error only OUTPUT_FORMAT_COUNT of 3 or less supported
#endif

/* Default sample resolutions for each alternate */

/**
 * @brief Sample resolution (bits) of output stream Alternate 1.
 *
 * Default: 24 if Alternate 1 is PCM, else 32 if DSD/RAW
 *
 * Note, 24 on the lowests alt in case of OUTPUT_FORMAT_COUNT = 1 leaving 24bit as the designs default
 * resolution.
 */
#define STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS      24

/**
 * @brief Sample resolution (bits) of output stream Alternate 2.
 *
 * Default: 16 if Alternate 2 is PCM, else 32 if DSD/RAW
 *
 */
#define STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS      16

/**
 * @brief Sample resolution (bits) of output stream Alternate 3.
 *
 * Default: 32 if Alternate 2 is PCM, else 32 if DSD/RAW
 *
 */
#define STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS      32

/* Default resolutions for HS */
#ifndef HS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS
    #define HS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS   STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS
#endif

#ifndef HS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS
    #define HS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS   STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS
#endif

#ifndef  HS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS
    #define HS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS   STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS
#endif

/* Default resolutions for FS (same as HS) */
#ifndef FS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS
    #define FS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS   STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS
#endif

#ifndef FS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS
    #define FS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS   STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS
#endif

#ifndef FS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS
    #define FS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS   STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS
#endif

/* Default sample subslot sizes (based on resolution) */

/**
 * @brief Sample sub-slot size (bytes) of output stream Alternate 1 when running in high-speed
 *
 * Default: 4 if resolution for Alternate 1 is 24bits, else resolution / 8
 *
 * Note, the default catchs the 24bit special case where 4-byte subslot is nicer for our 32-bit machine.
 * Typically do not care about this extra bus overhead at High-speed
 *
 */
#ifndef HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES
    #if (HS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS == 24)
        #define HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES        4 /* 4 byte subslot is nicer for our 32 bit machine to unpack.. */
    #else
        #define HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES        (HS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS/8)
    #endif
#endif

/**
 * @brief Sample sub-slot size (bytes) of output stream Alternate 2 when running in high-speed
 *
 * Default: 4 if resolution for Alternate 2 is 24bits, else resolution / 8
 *
 * Note, the default catchs the 24bit special case where 4-byte subslot is nicer for our 32-bit machine.
 * Typically do not care about this extra bus overhead at High-speed
 *
 */
#ifndef HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES
    #if (HS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS == 24)
        #define HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES        4 /* 4 byte subslot is nicer for our 32 bit machine to unpack.. */
    #else
        #define HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES        (HS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS/8)
    #endif
#endif

/**
 * @brief Sample sub-slot size (bytes) of output stream Alternate 3 when running in high-speed
 *
 * Default: 4 if resolution for Alternate 3 is 24bits, else resolution / 8
 *
 * Note, the default catchs the 24bit special case where 4-byte subslot is nicer for our 32-bit machine.
 * Typically do not care about this extra bus overhead at High-speed
 *
 */
#ifndef HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES
    #if (HS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS == 24)
        #define HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES        4 /* 4 byte subslot is nicer for our 32 bit machine to unpack.. */
    #else
        #define HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES        (HS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS/8)
    #endif
#endif

/* Default sub-slot sizes for full-speed operation */

/**
 * @brief Sample sub-slot size (bytes) of output stream Alternate 1 when running in full-speed
 *
 * Note, in full-speed mode bus bandwidth is at a premium, therefore pack samples into smallest
 * possible sub-slot.
 *
 * Default: STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS / 8
 */
#ifndef FS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES
    #define FS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES            (FS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS/8)
#endif

/**
 * @brief Sample sub-slot size (bytes) of output stream Alternate 2 when running in full-speed
 *
 * Note, in full-speed mode bus bandwidth is at a premium, therefore pack samples into smallest
 * possible sub-slot.
 *
 * Default: STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS / 8
 */
#ifndef FS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES
    #define FS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES            (FS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS/8)
#endif

/**
 * @brief Sample sub-slot size (bytes) of output stream Alternate 3 when running in full-speed
 *
 * Note, in full-speed mode bus bandwidth is at a premium, therefore pack samples into smallest
 * possible sub-slot.
 *
 * Default: STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS / 8
 *
 */
#ifndef FS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES
    #define FS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES            (FS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS/8)
#endif

/* Setup default audio data formats */

/**
 * @brief Sample audio data-format if output stream Alternate 1.
 *
 * Default: UAC_FORMAT_TYPEI_RAW_DATA when Alternate 1 is RAW/DSD else UAC_FORMAT_TYPEI_PCM
 */
//#ifndef STREAM_FORMAT_OUTPUT_1_DATAFORMAT
//    #if (NATIVE_DSD_FORMAT_NUM == 1)
//        #define STREAM_FORMAT_OUTPUT_1_DATAFORMAT               UAC_FORMAT_TYPEI_RAW_DATA
//    #else
        #define STREAM_FORMAT_OUTPUT_1_DATAFORMAT               UAC_FORMAT_TYPEI_PCM
//    #endif
//#endif

/**
 * @brief Sample audio data-format if output stream Alternate 2.
 *
 * Default: UAC_FORMAT_TYPEI_RAW_DATA when Alternate 2 is RAW/DSD else UAC_FORMAT_TYPEI_PCM
 */
//#ifndef STREAM_FORMAT_OUTPUT_2_DATAFORMAT
//    #if (NATIVE_DSD_FORMAT_NUM == 2)
//        #define STREAM_FORMAT_OUTPUT_2_DATAFORMAT               UAC_FORMAT_TYPEI_RAW_DATA
//    #else
        #define STREAM_FORMAT_OUTPUT_2_DATAFORMAT               UAC_FORMAT_TYPEI_PCM
//    #endif
//#endif

/**
 * @brief Sample audio data-format if output stream Alternate 3.
 *
 * Default: UAC_FORMAT_TYPEI_RAW_DATA when Alternate 3 is RAW/DSD else UAC_FORMAT_TYPEI_PCM
 */
//#ifndef STREAM_FORMAT_OUTPUT_3_DATAFORMAT
//    #if (NATIVE_DSD_FORMAT_NUM == 3)
//        #define STREAM_FORMAT_OUTPUT_3_DATAFORMAT               UAC_FORMAT_TYPEI_RAW_DATA
//    #else
        #define STREAM_FORMAT_OUTPUT_3_DATAFORMAT               UAC_FORMAT_TYPEI_PCM
//    #endif
//#endif

/***** INPUT STREAMS FORMAT ******/

/**
 * @brief Number of supported input stream formats.
 * Default: 1
 */
#ifndef INPUT_FORMAT_COUNT
    #define INPUT_FORMAT_COUNT 1
#endif

/**
 * @brief Sample resolution (bits) of input stream Alternate 1.
 *
 * Default: 24
 */
#ifndef STREAM_FORMAT_INPUT_1_RESOLUTION_BITS
    #define STREAM_FORMAT_INPUT_1_RESOLUTION_BITS           24
#endif

#ifndef STREAM_FORMAT_INPUT_2_RESOLUTION_BITS
    #define STREAM_FORMAT_INPUT_2_RESOLUTION_BITS           24
#endif

#ifndef STREAM_FORMAT_INPUT_3_RESOLUTION_BITS
    #define STREAM_FORMAT_INPUT_3_RESOLUTION_BITS           24
#endif



/* Default resolutions for HS */
#ifndef HS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS
    #define HS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS        STREAM_FORMAT_INPUT_1_RESOLUTION_BITS
#endif

#ifndef HS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS
    #define HS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS        STREAM_FORMAT_INPUT_2_RESOLUTION_BITS
#endif

#ifndef HS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS
    #define HS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS        STREAM_FORMAT_INPUT_3_RESOLUTION_BITS
#endif


/* Default resolutions for FS (same as HS) */
#ifndef FS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS
    #define FS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS        STREAM_FORMAT_INPUT_1_RESOLUTION_BITS
#endif

#ifndef FS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS
    #define FS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS        STREAM_FORMAT_INPUT_2_RESOLUTION_BITS
#endif

#ifndef FS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS
    #define FS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS        STREAM_FORMAT_INPUT_3_RESOLUTION_BITS
#endif


/* Channel count defines for input streams */
#ifndef HS_STREAM_FORMAT_INPUT_1_CHAN_COUNT
    #define HS_STREAM_FORMAT_INPUT_1_CHAN_COUNT             NUM_USB_CHAN_IN
#endif

#ifndef HS_STREAM_FORMAT_INPUT_2_CHAN_COUNT
    #define HS_STREAM_FORMAT_INPUT_2_CHAN_COUNT             NUM_USB_CHAN_IN
#endif

#ifndef HS_STREAM_FORMAT_INPUT_3_CHAN_COUNT
    #define HS_STREAM_FORMAT_INPUT_3_CHAN_COUNT             NUM_USB_CHAN_IN
#endif



/**
 * @brief Sample sub-slot size (bytes) of input stream Alternate 1 when running in high-speed
 *
 * Default: 4 if resolution for Alternate 1 is 24bits, else resolution / 8
 *
 * Note, the default catchs the 24bit special case where 4-byte subslot is nicer for our 32-bit machine.
 * Typically do not care about this extra bus overhead at High-speed
 *
 */
#ifndef HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES
     #if (HS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS == 24)
        #define HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES      4 /* 4 byte subslot is nicer for our 32 bit machine to unpack.. */
    #else
        #define HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES      (HS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS/8)
    #endif
#endif

#ifndef HS_STREAM_FORMAT_INPUT_2_SUBSLOT_BYTES
     #if (HS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS == 24)
        #define HS_STREAM_FORMAT_INPUT_2_SUBSLOT_BYTES      4 /* 4 byte subslot is nicer for our 32 bit machine to unpack.. */
    #else
        #define HS_STREAM_FORMAT_INPUT_2_SUBSLOT_BYTES      (HS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS/8)
    #endif
#endif

#ifndef HS_STREAM_FORMAT_INPUT_3_SUBSLOT_BYTES
     #if (HS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS == 24)
        #define HS_STREAM_FORMAT_INPUT_3_SUBSLOT_BYTES      4 /* 4 byte subslot is nicer for our 32 bit machine to unpack.. */
    #else
        #define HS_STREAM_FORMAT_INPUT_3_SUBSLOT_BYTES      (HS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS/8)
    #endif
#endif

/**
 * @brief Sample sub-slot size (bytes) of input stream Alternate 1 when running in full-speed
 *
 * Note, in full-speed mode bus bandwidth is at a premium, therefore pack samples into smallest
 * possible sub-slot.
 *
 * Default: STREAM_FORMAT_INPUT_1_RESOLUTION_BITS / 8
 */
#ifndef FS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES
    #define FS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES         (FS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS/8)
#endif

#ifndef FS_STREAM_FORMAT_INPUT_2_SUBSLOT_BYTES
    #define FS_STREAM_FORMAT_INPUT_2_SUBSLOT_BYTES         (FS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS/8)
#endif

#ifndef FS_STREAM_FORMAT_INPUT_3_SUBSLOT_BYTES
    #define FS_STREAM_FORMAT_INPUT_3_SUBSLOT_BYTES         (FS_STREAM_FORMAT_INPUT_3_RESOLUTION_BITS/8)
#endif

/**
 * @brief Sample audio data-format for input stream Alternate 1.
 *
 * Default: UAC_FORMAT_TYPEI_PCM
 */
#ifndef STREAM_FORMAT_INPUT_1_DATAFORMAT
    #define STREAM_FORMAT_INPUT_1_DATAFORMAT               UAC_FORMAT_TYPEI_PCM
#endif

#ifndef STREAM_FORMAT_INPUT_2_DATAFORMAT
    #define STREAM_FORMAT_INPUT_2_DATAFORMAT               UAC_FORMAT_TYPEI_PCM
#endif

#ifndef STREAM_FORMAT_INPUT_3_DATAFORMAT
    #define STREAM_FORMAT_INPUT_3_DATAFORMAT               UAC_FORMAT_TYPEI_PCM
#endif


/****** END INPUT STREAMS FORMAT *****/


/**
 * @brief Enable/disable output volume control including all processing and descriptor support
 *
 * Default: 1 (Enabled)
 */
#ifndef OUTPUT_VOLUME_CONTROL
#define OUTPUT_VOLUME_CONTROL 	    (1)
#endif

/**
 * @brief Enable/disable input volume control including all processing and descriptor support
 *
 * Default: 1 (Enabled)
 */
#ifndef INPUT_VOLUME_CONTROL
#define INPUT_VOLUME_CONTROL 	    (1)
#endif

/* Power */

/**
 * @brief Report as self to the host when enabled, else reports as bus-powered. This affects descriptors
 * and XUD usage.
 *
 * Default: 0 (Disabled)
 */
// TODO:Changed to self powered, was 0
#ifndef SELF_POWERED
#define SELF_POWERED                (1)
#endif

/* Tidy-up historical ifndef usage */
#if defined(SELF_POWERED) && (SELF_POWERED==0)
#undef SELF_POWERED
#endif

/**
 * @brief Power drawn from the host (in mA x 2)
 *
 * Default: 0 when SELF_POWERED enabled else 250 (500mA)
 */
#ifdef SELF_POWERED
    /* Default to taking no power from the bus in self-powered mode */
    #ifndef BMAX_POWER
        #define BMAX_POWER 0
    #endif
#else
    /* Default to taking 500mA from the bus in bus-powered mode */
    #ifndef BMAX_POWER
        #define BMAX_POWER 250
    #endif
#endif

#ifndef XUD_PWR_CFG
    #ifdef SELF_POWERED
        #define XUD_PWR_CFG XUD_PWR_SELF
    #else
        #define XUD_PWR_CFG XUD_PWR_BUS
    #endif
#endif

/* Mixer defines */

/**
 * @brief Number of seperate mixes to perform
 *
 * Default: 8 if MIXER enabled, else 0
 */
#define MAX_MIX_COUNT          (0)

/**
 * @brief Number of channels input into the mixer.
 *
 * Note, total number of mixer nodes is MIX_INPUTS * MAX_MIX_COUNT
 *
 * Default: 18
 */
#ifndef MIX_INPUTS
    #define MIX_INPUTS                 (18)
#endif

/* Volume processing defines */

/**
 * @brief The minimum volume setting above -inf. This is a signed 8.8 fixed point
 *        number that must be strictly greater than -128 (0x8000)
 *
 * Default: 0x8100 (-127db)
 */
#ifndef MIN_VOLUME
#define MIN_VOLUME                     (0x8100)
#endif


/**
 * @brief The maximum volume setting. This is a signed 8.8 fixed point number.
 *
 * Default: 0x0000 (0db)
 */
#ifndef MAX_VOLUME
#define MAX_VOLUME                     (0x0000)
#endif

/**
 * @brief The resolution of the volume control in db as a 8.8 fixed point number
 *
 * Default: 0x100 (1db)
 */
#ifndef VOLUME_RES
#define VOLUME_RES                     (0x100)
#endif

/**
 * @brief The minimum volume setting for the mixer unit above -inf.
 * This is a signed 8.8 fixed point number that must be strictly greater than -128 (0x8000)
 *
 * Default: 0x8100 (-127db)
 */
#ifndef MIN_MIXER_VOLUME
#define MIN_MIXER_VOLUME             (0x8100)
#endif

/**
 * @brief The maximum volume setting for the mixer. This is a signed 8.8 fixed point number.
 *
 * Default: 0x0000 (0db)
 */
#ifndef MAX_MIXER_VOLUME
#define MAX_MIXER_VOLUME            (0x0000)
#endif

/**
 * @brief The resolution of the volume control in db as a 8.8 fixed point number
 *
* Default: 0x100 (1db)
*/
#ifndef VOLUME_RES_MIXER
#define VOLUME_RES_MIXER            (0x100)
#endif


/* Endpoint addresses enums */
enum USBEndpointNumber_In
{
    ENDPOINT_NUMBER_IN_CONTROL,     /* Endpoint 0 */
#if (NUM_USB_CHAN_IN == 0) || defined (UAC_FORCE_FEEDBACK_EP)
    ENDPOINT_NUMBER_IN_FEEDBACK,
#endif
    ENDPOINT_NUMBER_IN_AUDIO,
    ENDPOINT_COUNT_IN               /* End marker */
};

enum USBEndpointNumber_Out
{
    ENDPOINT_NUMBER_OUT_CONTROL,    /* Endpoint 0 */
    ENDPOINT_NUMBER_OUT_AUDIO,
    ENDPOINT_COUNT_OUT              /* End marker */
};

/*** Internal defines below here. NOT FOR MODIFICATION ***/

#define AUDIO_STOP_FOR_DFU       (0x12345678)
#define AUDIO_START_FROM_DFU     (0x87654321)
#define AUDIO_REBOOT_FROM_DFU    (0xa5a5a5a5)

#define MAX_VOL                  (0x20000000)


/* The number of clock ticks to wait for the audio feeback to stabalise
 * Note, feedback always counts 128 SOFs (16ms @ HS, 128ms @ FS) */
#ifndef FEEDBACK_STABILITY_DELAY_HS
#define FEEDBACK_STABILITY_DELAY_HS     (2000000)
#endif

#ifndef FEEDBACK_STABILITY_DELAY_FS
#define FEEDBACK_STABILITY_DELAY_FS     (20000000)
#endif

/* Length of clock unit/clock-selector units */
#define NUM_CLOCKS               (1)

/* Audio Unit ID defines */
#define FU_USBIN                 11              /* Feature Unit: USB Audio device -> host */
#define FU_USBOUT                10              /* Feature Unit: USB Audio host -> device*/
#define ID_IT_USB                2               /* Input terminal: USB streaming */
#define ID_IT_AUD                1               /* Input terminal: Analogue input */
#define ID_OT_USB                22              /* Output terminal: USB streaming */
#define ID_OT_AUD                20              /* Output terminal: Analogue output */

#define ID_CLKSEL                40              /* Clock selector ID */
#define ID_CLKSRC_INT            41              /* Clock source ID (internal) */
#define ID_CLKSRC_SPDIF          42              /* Clock source ID (external) */
#define ID_CLKSRC_ADAT           43              /* Clock source ID (external) */

#define ID_XU_MIXSEL             50
#define ID_XU_OUT                51
#define ID_XU_IN                 52

#define ID_MIXER_1               60

/* Defines for DFU */
#define DFU_PID                     PID_AUDIO_2
#define DFU_VENDOR_ID               VENDOR_ID
#define DFU_BCD_DEVICE              BCD_DEVICE
#define DFU_MANUFACTURER_STR_INDEX  offsetof(StringDescTable_t, vendorStr)/sizeof(char *)
#define DFU_PRODUCT_STR_INDEX       offsetof(StringDescTable_t, productStr_Audio2)/sizeof(char *)
#endif

/* USB test mode support enabled by default (Required for compliance testing) */
#if defined(TEST_MODE_SUPPORT) && (TEST_MODE_SUPPORT == 0)
#undef TEST_MODE_SUPPORT
#else
#define TEST_MODE_SUPPORT  1
#endif

#if defined(FAST_MODE) && (FAST_MODE == 0)
#undef FAST_MODE
#endif


/* Some stream format checks */
#if (OUTPUT_FORMAT_COUNT > 0)
    #if !defined(HS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS) || \
                                        !defined(HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES) || \
                                        !defined(STREAM_FORMAT_OUTPUT_1_DATAFORMAT)
        #error HS_OUTPUT_STREAM_1 not properly defined
    #endif
#endif

#if (OUTPUT_FORMAT_COUNT > 1)
    #if !defined(HS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS) || \
                                        !defined(HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES) || \
                                        !defined(STREAM_FORMAT_OUTPUT_2_DATAFORMAT)
        #error HS_OUTPUT_STREAM_2 not properly defined
    #endif
#endif

#if (OUTPUT_FORMAT_COUNT > 2)
    #if !defined(HS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS) || \
                                        !defined(HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES) || \
                                        !defined(STREAM_FORMAT_OUTPUT_3_DATAFORMAT)
        #error HS_OUTPUT_STREAM_3 not properly defined
    #endif
#endif

/* Some defines that allow us to remove unused code */

/* Useful for dropping lower part of macs in volume processing... */
#if (FS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS > 24) || (FS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS > 24) || \
    (FS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS > 24) || (HS_STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS > 24)  || \
    (HS_STREAM_FORMAT_OUTPUT_2_RESOLUTION_BITS > 24) || (HS_STREAM_FORMAT_OUTPUT_3_RESOLUTION_BITS > 24)
    #define STREAM_FORMAT_OUTPUT_RESOLUTION_32BIT_USED 1
#else
    #define STREAM_FORMAT_OUTPUT_RESOLUTION_32BIT_USED 0
#endif

/* SUBSLOT defines useful for removing packing/unpacking code in USB buffering code */
#if (FS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES == 2) || (FS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES == 2) || \
    (FS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES == 2) || (HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES == 2) || \
    (HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES == 2) || (HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES == 2)
    #define STREAM_FORMAT_OUTPUT_SUBSLOT_2_USED 1
#else
    #define STREAM_FORMAT_OUTPUT_SUBSLOT_2_USED 0
#endif

#if (FS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES == 3) || (FS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES == 3) || \
    (FS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES == 3) || (HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES == 3) || \
    (HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES == 3) || (HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES == 3)
    #define STREAM_FORMAT_OUTPUT_SUBSLOT_3_USED 1
#else
    #define STREAM_FORMAT_OUTPUT_SUBSLOT_3_USED 0
#endif

#if (FS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES == 4) || (FS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES == 4) || \
    (FS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES == 4) || (HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES == 4) || \
    (HS_STREAM_FORMAT_OUTPUT_2_SUBSLOT_BYTES == 4) || (HS_STREAM_FORMAT_OUTPUT_3_SUBSLOT_BYTES == 4)
    #define STREAM_FORMAT_OUTPUT_SUBSLOT_4_USED 1
#else
    #define STREAM_FORMAT_OUTPUT_SUBSLOT_4_USED 0
#endif

/* Useful for dropping lower part of macs in volume processing... */
    #if (FS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS > 24) || (FS_STREAM_FORMAT_INPUT_2_RESOLUTION_BITS > 24)
        #define STREAM_FORMAT_INPUT_RESOLUTION_32BIT_USED 1
    #else
        #define STREAM_FORMAT_INPUT_RESOLUTION_32BIT_USED 0
    #endif

    #if((FS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES == 4) || (HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES == 4))
        #define STREAM_FORMAT_INPUT_SUBSLOT_4_USED 1
    #else
        #define STREAM_FORMAT_INPUT_SUBSLOT_4_USED 0
    #endif

    #if((FS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES == 3) || (HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES == 3))
        #define STREAM_FORMAT_INPUT_SUBSLOT_3_USED 1
    #else
        #define STREAM_FORMAT_INPUT_SUBSLOT_3_USED 0
    #endif

    #if((FS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES == 2) || (HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES == 2))
        #define STREAM_FORMAT_INPUT_SUBSLOT_2_USED 1
    #else
        #define STREAM_FORMAT_INPUT_SUBSLOT_2_USED 0
    #endif

#if MAX_FREQ < MIN_FREQ
#error MAX_FREQ should be >= MIN_FREQ!!
#endif

/* For Audio Class 1.0 and Full-speed Audio 2.0 we default having at most 2 channels */
#ifndef NUM_USB_CHAN_OUT_FS
    #if (NUM_USB_CHAN_OUT > 2)
        #define NUM_USB_CHAN_OUT_FS  (2)
    #else
        #define NUM_USB_CHAN_OUT_FS  (NUM_USB_CHAN_OUT)
    #endif
#endif

#ifndef NUM_USB_CHAN_IN_FS
    #if (NUM_USB_CHAN_IN > 2)
        #define NUM_USB_CHAN_IN_FS (2)
    #else
        #define NUM_USB_CHAN_IN_FS  (NUM_USB_CHAN_IN)
    #endif
#endif

/* Apply sample-rate restrictions to full-speed operation */
#ifndef MAX_FREQ_FS
#if (NUM_USB_CHAN_OUT_FS > 0) && (NUM_USB_CHAN_IN_FS > 0)
    #if(MAX_FREQ > 48000)
        #define MAX_FREQ_FS              48000
    #else
        #define MAX_FREQ_FS              MAX_FREQ
    #endif
#else
    #if (MAX_FREQ > 96000)
        #define MAX_FREQ_FS              96000
    #else
        #define MAX_FREQ_FS              MAX_FREQ
    #endif
#endif
#endif

#define MIN_FREQ_FS              MIN_FREQ



/* Setup DEFAULT_MCLK_FREQ based on MCLK_ and DEFAULT_FREQ defines */
#if ((MCLK_441 % DEFAULT_FREQ) == 0)
#define DEFAULT_MCLK_FREQ MCLK_441
#elif ((MCLK_48 % DEFAULT_FREQ) == 0)
#define DEFAULT_MCLK_FREQ MCLK_48
#else
#error Bad DEFAULT_MCLK_FREQ
#endif

#if ((MCLK_441 % MIN_FREQ) == 0)
#define MIN_FREQ_44 MIN_FREQ
#define MIN_FREQ_48 ((48000 * 512)/((44100 * 512)/MIN_FREQ))
#endif

#if ((MCLK_48 % MIN_FREQ) == 0)
#define MIN_FREQ_48 MIN_FREQ
/* * 2 required since we want the next 44.1 based freq above MIN_FREQ */
#define MIN_FREQ_44 (((44100*512)/((48000 * 512)/MIN_FREQ))*2)
#endif
