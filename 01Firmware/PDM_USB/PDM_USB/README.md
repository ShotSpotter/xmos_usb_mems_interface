Rebuilding:

```
#  start xmos shell

/Applications/XMOS_XTC_15.1.4/SetEnv.command
cd xmos_usb_mems_interface/01Firmware/PDM_USB/PDM_USB
xmake clean
xmake
```

Factory image:

This is done on a host machine that has XMOS Tools installed.

Our "factory image" is version 2.0.0. This can be inspected on the sensor with lsusb or the xmos-dfu tool.

```
xflash --factory bin/SST-XMOS-001_v2.0.0.xe
```

Upgrade images:

These will be installed from the sensor's dfu tool, but we need to format the firmware image using xflash on the build host.

* make any needed coded changes
* update 01Firmware/PDM_USB/PDM_USB/src/core/customdefines.h
* check it in
* xmake clean && xmake
* make it into a firmware image using xflash

We use "upgrade 1" to be the last digit of our version.

Factory image => 2.0.0
Upgrade 1     => 2.0.1

```
xflash --factory-version 15.1 --upgrade 1 bin/SST-XMOS-001_v2.0.1.xe -o SST-XMOS-001_v2.0.1.bin
```

Add this to the root file system via buildroot


Then on the sensor, check version using xmosdfu. Our devices is VID 0x20b1, PID 0x8.

The version is "0x200", which is "2.0.0".

```
$ xmosdfu --listdevices
VID = 0x1bc7, PID = 0x1201, BCDDevice: 0x318
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
VID = 0x20b1, PID = 0x8, BCDDevice: 0x200
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
```

 install the upgrade using:
```
$ xmosdfu SST_XMOS_001_V1 --download SST-XMOS-001_v2.0.1.bin

XMOS DFU application started - Interface 2 claimed
Detaching device from application mode.
Waiting for device to restart and enter DFU mode...
DFU device plugged on bus 1, dev 3
... DFU firmware upgrade device opened
... Downloading image (SST-XMOS-001_v2.0.1.bin) to device
... Download complete
... Returning device to application mode

Application (eMMC:2p5):~ $ xmosdfu --listdevices
VID = 0x1bc7, PID = 0x1201, BCDDevice: 0x318
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
VID = 0x20b1, PID = 0x8, BCDDevice: 0x101
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
```

You can upgrade without stopping the user application. It will throw an audio error and recover after the xmos board reboots.
```
Nov  2 20:33:21 kern.err kernel: [  929.818710] usb 1-1: 1:0: usb_set_interface failed (-71)
Nov  2 20:33:21 kern.info kernel: [  930.182461] usb 1-1: USB disconnect, device number 2
Nov  2 20:33:21 kern.info kernel: [  930.461687] usb 1-1: new high-speed USB device number 3 using ci_hdrc
Nov  2 20:33:21 kern.info kernel: [  930.622566] usb 1-1: New USB device found, idVendor=20b1, idProduct=0008, bcdDevice= 1.00
Nov  2 20:33:21 kern.info kernel: [  930.630796] usb 1-1: New USB device strings: Mfr=1, Product=3, SerialNumber=0
Nov  2 20:33:21 kern.info kernel: [  930.638067] usb 1-1: Product: SST-XMOS-001 UAC2.0
Nov  2 20:33:21 kern.info kernel: [  930.642819] usb 1-1: Manufacturer: SST
Nov  2 20:33:22 Application user.notice watcher: Application failed a status check:1
Nov  2 20:33:27 kern.info kernel: [  936.196003] usb 1-1: USB disconnect, device number 3
Nov  2 20:33:27 kern.info kernel: [  936.469817] usb 1-1: new high-speed USB device number 4 using ci_hdrc
Nov  2 20:33:27 kern.info kernel: [  936.630686] usb 1-1: New USB device found, idVendor=20b1, idProduct=0008, bcdDevice= 1.01
Nov  2 20:33:27 kern.info kernel: [  936.638897] usb 1-1: New USB device strings: Mfr=1, Product=3, SerialNumber=0
Nov  2 20:33:27 kern.info kernel: [  936.646157] usb 1-1: Product: SST-XMOS-001 UAC2.0
Nov  2 20:33:27 kern.info kernel: [  936.650906] usb 1-1: Manufacturer: SST
Nov  2 20:34:15 kern.debug Application: Starting
Nov  2 20:34:15 kern.debug Application: usbArray: 'xCORE-200'
```