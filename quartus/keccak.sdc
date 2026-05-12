# =============================================================================
# keccak.sdc  -  Timing Constraints
# Target clock: 200 MHz (5 ns period)
# Adjust downward if the fitter cannot meet timing.
# =============================================================================

create_clock -name clk -period 5.0 [get_ports clk]

# Cut input/output delay paths (we only care about Fmax, not I/O timing)
set_false_path -from [all_inputs]
set_false_path -to   [all_outputs]

derive_clock_uncertainty
