.PHONY: build clean report

build:
	quartus_sh --no_banner --flow compile TSConf -c TSConf

clean:
	rm -rf db incremental_db output_files

report:
	cat output_files/TSConf.*.smsg output_files/TSConf.*.rpt |grep -e Error -e Critical -e Warning |grep -v -e "Family doesn't support jitter analysis" -e "Force Fitter to Avoid Periphery Placement Warnings"

export PATH:=/cygdrive/c/Hwdev/quartus170/quartus/bin64:/cygdrive/c/Dev/srec/bin/:${PATH}

-include Makefile.local
