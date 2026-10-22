# User-selected initial integration target:about148MHz. Do not relax silently.
create_clock -name clk -period 6.757 [get_ports clk]
derive_clock_uncertainty
# Standalone internal benchmark;physical I/O timing is not closed here.
set_false_path -from [get_ports rst]
set_false_path -from [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_false_path -to [all_outputs]
