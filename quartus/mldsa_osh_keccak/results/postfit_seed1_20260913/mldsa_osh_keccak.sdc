# Aggressive comparison target. Actual achievable Fmax is reported by TimeQuest.
create_clock -name clk -period 4.348 [get_ports clk]
derive_clock_uncertainty

# Board I/O delays are unknown; benchmark all internal register paths only.
set_false_path -from [get_ports rst]
set_false_path -from [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_false_path -to [all_outputs]
