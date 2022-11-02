# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = SST-XMOS-001_V1.xn

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = SST-XMOS-001_v2.0.0

BUILD_FLAGS = \
	-DADAT_TX_USE_SHARED_BUFF=1 \
	-DFLASH_MAX_UPGRADE_SIZE=128*1024 \
	-DQUAD_SPI_FLASH=1 \
	-DUSB_TILE=tile[1] \
	-DXSCOPE \
	-DXUD_SERIES_SUPPORT=4 \
	-fcomment-asm \
	-fxscope \
	-g \
	-lquadflash \
	-march=xs2a \
	-O3 \
	-report \
	-save-temps \
	-Wall \
	-Wno-timing \
	-Xmapper --map \
	-Xmapper MAPFILE


# The USED_MODULES variable lists other module used by the application.
USED_MODULES = \
	lib_dsp \
	lib_logging \
	lib_mic_array \
	lib_xassert \
	module_dfu \
	module_locks \
	module_usb_device \
	module_usb_shared \
	module_xud


# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
XCC_FLAGS = $(BUILD_FLAGS)

# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 0

MODULE_LIBRARIES = xud_x200

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
