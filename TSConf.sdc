derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {emu|tsconf|U16|*} -setup 2
set_multicycle_path -to {emu|tsconf|U16|*} -hold 1

set_multicycle_path -from {emu|tsconf|CPU|*} -setup 2
set_multicycle_path -from {emu|tsconf|CPU|*} -hold 1
set_multicycle_path -to {emu|tsconf|CPU|*} -setup 2
set_multicycle_path -to {emu|tsconf|CPU|*} -hold 1

set_multicycle_path -to {emu|tsconf|U15|*} -setup 2
set_multicycle_path -to {emu|tsconf|U15|*} -hold 1
