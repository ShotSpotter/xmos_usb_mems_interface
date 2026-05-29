cmake_minimum_required (VERSION 3.0.0)
project(xmosdfu)

find_path(LIBUSB_INCLUDE_DIR NAMES libusb.h
	PATH_SUFFIXES "libusb" "libusb-1.0")
find_library(LIBUSB_LIBRARY NAMES usb-1.0)

add_executable(xmosdfu xmosdfu.cpp)
include_directories(xmosdfu ${LIBUSB_INCLUDE_DIR})
target_link_libraries(xmosdfu ${LIBUSB_LIBRARY})
