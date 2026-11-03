# User priority:150+MHz minimum. Target6.500ns=153.85MHz with timing margin.
# Area reduction is deferred;retain existing device and hold constraints.
create_clock -name clk -period 6.500 [get_ports clk]
derive_clock_uncertainty
# Standalone internal benchmark;physical I/O timing is not closed here.
set_false_path -from [get_ports rst]
set_false_path -from [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_false_path -to [all_outputs]
