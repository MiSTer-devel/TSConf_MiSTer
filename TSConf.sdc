derive_pll_clocks

set core_clk  [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set video_clk [get_clocks {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]
if {[get_collection_size $core_clk] != 1}  { error "TSConf.sdc: expected exactly one 84 MHz core clock" }
if {[get_collection_size $video_clk] != 1} { error "TSConf.sdc: expected exactly one 56 MHz video clock" }

# fclk is clk_sys gated by ce_28m. ce_28m is updated on the falling edge of
# clk_sys and enables one complete clk_sys pulse out of every three. With the
# divider initialized to 2, the first active pulse is described by source-clock
# edges 5 (rise) and 6 (fall), and the next rise is edge 11. This preserves the
# actual 1/6 duty cycle instead of treating fclk as a 50% duty-cycle /3 clock.
set fclk_pin [get_pins -nowarn {emu|fclk_clkena|outclk}]
if {[get_collection_size $fclk_pin] != 1} { error "TSConf.sdc: expected exactly one fclk CLKCTRL output pin" }
create_generated_clock \
	-name fclk \
	-master_clock $core_clk \
	-source [get_pins {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
	-edges {5 6 11} \
	$fclk_pin

set fclk_clk [get_clocks {fclk}]
if {[get_collection_size $fclk_clk] != 1} { error "TSConf.sdc: expected exactly one 28 MHz fclk clock" }

# The audio PLL is independent of the TSConf PLL.
set audio_clk [get_clocks {pll_audio|pll_audio_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
if {[get_collection_size $audio_clk] != 1} { error "TSConf.sdc: expected exactly one audio output clock" }
set_clock_groups -asynchronous -group $fclk_clk -group $audio_clk

# resetter asynchronously asserts reset and synchronously releases it.
set fclk_reset_clear_pins [get_pins -hierarchical -nowarn {*rst_sync*|clrn}]
if {[get_collection_size $fclk_reset_clear_pins] != 2} { error "TSConf.sdc: expected two fclk reset clear pins" }
set_false_path -to $fclk_reset_clear_pins

derive_clock_uncertainty

set_multicycle_path -from $core_clk -to $video_clk -setup 2
set_multicycle_path -from $core_clk -to $video_clk -hold 1

set gs_cpu_keepers [get_keepers -no_duplicates -nowarn {*|gs_top:gs_top|gs:gs|*CPU|*}]
if {[get_collection_size $gs_cpu_keepers] == 0} { error "TSConf.sdc: GS CPU registers were not found" }
set_multicycle_path -from $gs_cpu_keepers -to $gs_cpu_keepers -setup 2
set_multicycle_path -from $gs_cpu_keepers -to $gs_cpu_keepers -hold 1

set sdram_sources [get_keepers -no_duplicates -nowarn {
	emu|tsconf|CPU|*
	*|arbiter:arbiter|*
	*|zmem:zmem|*
	*|dma:dma|*
	*|zsignals:zsignals|*
	*|zports:zports|*
	*|video_top:video_top|*
}]
set sdram_keepers [get_keepers -no_duplicates -nowarn {*|sdram:sdram|*}]
if {[get_collection_size $sdram_sources] == 0 || [get_collection_size $sdram_keepers] == 0} { error "TSConf.sdc: SDRAM multicycle endpoints were not found" }
set_multicycle_path -from $sdram_sources -to $sdram_keepers -setup 3
set_multicycle_path -from $sdram_sources -to $sdram_keepers -hold 2

set spi_keepers    [get_keepers -no_duplicates -nowarn {*|spi:spi|*}]
set sdcard_keepers [get_keepers -no_duplicates -nowarn {*|sd_card:sd_card|*}]
if {[get_collection_size $spi_keepers] == 0 || [get_collection_size $sdcard_keepers] == 0} { error "TSConf.sdc: SPI-to-SD multicycle endpoints were not found" }
set_multicycle_path -from $spi_keepers -to $sdcard_keepers -setup 3
set_multicycle_path -from $spi_keepers -to $sdcard_keepers -hold 2

set rtc_sources [get_keepers -no_duplicates -nowarn {
	*|zports:zports|*
	*|zmem:zmem|*
	*|zsignals:zsignals|*
}]
set rtc_keepers [get_keepers -no_duplicates -nowarn {*|mc146818a:mc146818a|*}]
if {[get_collection_size $rtc_sources] == 0 || [get_collection_size $rtc_keepers] == 0} { error "TSConf.sdc: RTC multicycle endpoints were not found" }
set_multicycle_path -from $rtc_sources -to $rtc_keepers -setup 3
set_multicycle_path -from $rtc_sources -to $rtc_keepers -hold 2
