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

Our "factory image" is version 1.0.0. This can be inspected on the sensor with lsusb or the xmos-dfu tool.

```
xflash --factory bin/SST-XMOS-001_v1.0.0.xe
```

Upgrade images:

These will be installed from the sensor's dfu tool, but we need to format the firmware image using xflash on the build host.

* make any needed coded changes
* update 01Firmware/PDM_USB/PDM_USB/src/core/customdefines.h
* check it in
* xmake clean && xmake
* make it into a firmware image using xflash

We use "upgrade 1" to be the last digit of our version.

Factory image => 1.0.0
Upgrade 1     => 1.0.1

```
xflash --factory-version 15.1 --upgrade 1 bin/SST-XMOS-001_v1.0.1.xe -o SST-XMOS-001_v1.0.1.bin
```

Add this to the root file system via buildroot


Then on the sensor, check version using xmosdfu. Our devices is VID 0x20b1, PID 0x8.

The version is "0x100", which is "1.0.0".

```
SCP-00-CEX-0000 (eMMC:2p5):~ $ xmosdfu --listdevices
VID = 0x1bc7, PID = 0x1201, BCDDevice: 0x318
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
VID = 0x20b1, PID = 0x8, BCDDevice: 0x100
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
SCP-00-CEX-0000 (eMMC:2p5):~ $
```

 install the upgrade using:
```
SCP-00-CEX-0000 (eMMC:2p5):~ $ xmosdfu SST_XMOS_001_V1 --download SST-XMOS-001_v1.0.1.bin

XMOS DFU application started - Interface 2 claimed
Detaching device from application mode.
Waiting for device to restart and enter DFU mode...
DFU device plugged on bus 1, dev 3
... DFU firmware upgrade device opened
... Downloading image (SST-XMOS-001_v1.0.1.bin) to device
... Download complete
... Returning device to application mode

SCP-00-CEX-0000 (eMMC:2p5):~ $ xmosdfu --listdevices
VID = 0x1bc7, PID = 0x1201, BCDDevice: 0x318
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
VID = 0x20b1, PID = 0x8, BCDDevice: 0x101
VID = 0x1d6b, PID = 0x2, BCDDevice: 0x515
```

You can upgrade without stopping SensApp. It will throw an audio error and recover after the xmos board reboots.
```
Nov  2 20:33:21 SCP-00-CEX-0000 kern.debug SensApp: Audio stalled.  availableFrames = 112, counter = 51, MaxInputFrameNumber = 29933376
Nov  2 20:33:21 SCP-00-CEX-0000 kern.debug SensApp: Stopping buffer thread
Nov  2 20:33:21 SCP-00-CEX-0000 kern.debug SensApp: [DBUG] Exiting with code 3 : audio error
Nov  2 20:33:21 SCP-00-CEX-0000 kern.debug SensApp: Stopping spool thread
Nov  2 20:33:21 SCP-00-CEX-0000 kern.debug SensApp: Stopping GPSD input thread
Nov  2 20:33:21 SCP-00-CEX-0000 kern.err kernel: [  929.818710] usb 1-1: 1:0: usb_set_interface failed (-71)
Nov  2 20:33:21 SCP-00-CEX-0000 kern.info kernel: [  930.182461] usb 1-1: USB disconnect, device number 2
Nov  2 20:33:21 SCP-00-CEX-0000 kern.info kernel: [  930.461687] usb 1-1: new high-speed USB device number 3 using ci_hdrc
Nov  2 20:33:21 SCP-00-CEX-0000 kern.info kernel: [  930.622566] usb 1-1: New USB device found, idVendor=20b1, idProduct=0008, bcdDevice= 1.00
Nov  2 20:33:21 SCP-00-CEX-0000 kern.info kernel: [  930.630796] usb 1-1: New USB device strings: Mfr=1, Product=3, SerialNumber=0
Nov  2 20:33:21 SCP-00-CEX-0000 kern.info kernel: [  930.638067] usb 1-1: Product: SST-XMOS-001 UAC2.0
Nov  2 20:33:21 SCP-00-CEX-0000 kern.info kernel: [  930.642819] usb 1-1: Manufacturer: SST
Nov  2 20:33:22 SCP-00-CEX-0000 user.notice watcher: sensapp failed a status check:1
Nov  2 20:33:27 SCP-00-CEX-0000 kern.info kernel: [  936.196003] usb 1-1: USB disconnect, device number 3
Nov  2 20:33:27 SCP-00-CEX-0000 kern.info kernel: [  936.469817] usb 1-1: new high-speed USB device number 4 using ci_hdrc
Nov  2 20:33:27 SCP-00-CEX-0000 kern.info kernel: [  936.630686] usb 1-1: New USB device found, idVendor=20b1, idProduct=0008, bcdDevice= 1.01
Nov  2 20:33:27 SCP-00-CEX-0000 kern.info kernel: [  936.638897] usb 1-1: New USB device strings: Mfr=1, Product=3, SerialNumber=0
Nov  2 20:33:27 SCP-00-CEX-0000 kern.info kernel: [  936.646157] usb 1-1: Product: SST-XMOS-001 UAC2.0
Nov  2 20:33:27 SCP-00-CEX-0000 kern.info kernel: [  936.650906] usb 1-1: Manufacturer: SST
Nov  2 20:34:14 SCP-00-CEX-0000 user.notice AppData: Restarting unproductive SensApp!
Nov  2 20:34:14 SCP-00-CEX-0000 user.notice /etc/init.d/sensapp: remove configure script touchfiles
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: Starting
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: usbArray: 'xCORE-200'
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: reading configuration from /config/SensApp.conf
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: ServerName = "10.111.0.126", ServerPort = 24025, ServiceName = ""
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: reading MQTT config from file /config/SensApp.ini
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: MQTT Configuration: disabled
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: Changed PrimaryChannelID from -1 to 0
Nov  2 20:34:15 SCP-00-CEX-0000 kern.debug SensApp: HexSensorID = 56770A3500000000, LinuxBuild = shotspotter, RFS = ECO2121rc17-10.0.16.78570, ServerName = 10.111.0.126
```