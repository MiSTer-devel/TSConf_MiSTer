# TSConf for MiSTer
This is the port of TSConf (one of ZX Spectrum clone with extra functionalities) to MiSTer.

## Features of the port
* Scandoubler with HQ2x and Scanlines.
* RTC.
* Configurable CMOS settings through OSD.
* Supports both secondary SD and image on primary SD.
* Kempston Joystick.
* Kempston Mouse.
* Turbosound (dual AY)
* General Sound (384KB)
* SAA1099

## Installation
place RBF into root of primary SD card. And then you have 2 options:
1) Format secondary SD card with FAT32 and unpack content of SDCard.zip to it.
2) Create TSConf.vhd image (non-MBR!) with FAT32 format and unpack SDCard.zip to it. Then place TSConf.vhd to root of primary SD card.

Put some TAP, SNA, SCL, TRD files to secondary SD card (or to TSConf.vhd image) as well.

By default, if everything is done right, Wild Commander will be loaded where you can choose the games to start.

### Note
Although original CMOS setting page can be launched (CTRL+F11), the settings made there won't have effect. You need to use OSD for CMOS settings.

Original TSConf F12 key (reset) is transferred to F11.
