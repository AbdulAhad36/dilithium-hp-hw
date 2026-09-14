# Current closed checkpoint: 135 MHz with margin after RTL optimization.
create_clock -name clk -period 7.407 [get_ports clk]
derive_clock_uncertainty

# Board delays cannot be signed off until the FPGA board and pinout are known.
# Exclude only top-level I/O paths; all internal register paths remain timed.
set_false_path -from [get_ports rst]
set_false_path -from [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_false_path -to [all_outputs]
