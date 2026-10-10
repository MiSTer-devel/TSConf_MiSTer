# OPL3 FPGA upstream

Imported from [`MiSTer-devel/ao486_MiSTer/rtl/soc/sound/opl3`](https://github.com/MiSTer-devel/ao486_MiSTer/tree/master/rtl/soc/sound/opl3).

The imported source blobs match the upstream tree at commit
`55fe09ce88b767a47a6f93d87b9ef26db9a36c26`. `synchronizer.sv` is the
matching dependency from `rtl/common` in the same repository.

TSConf-specific integration changes are limited to the clock frequency and
sample divider in `opl3_pkg.sv`; the core runs from the 28 MHz peripheral
clock and produces a 49.73357 kHz sample enable.
