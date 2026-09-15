create_clock -name clk -period 6.897 [get_ports clk]
derive_clock_uncertainty

set_false_path -from [get_ports rst]
set_false_path -from [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_false_path -to [all_outputs]
