# Operating clock approved by user: 148 MHz = 6.756757 ns.
# This is an operating-frequency choice, not a 200 MHz timing claim.
# Retain ntt_benchmark_200mhz.sdc for the aggressive comparison.
create_clock -name clk -period 6.756757 [get_ports clk]

# Standalone register-to-register benchmark: external I/O timing is excluded.
# Board integration must replace these with real input/output constraints.
set_false_path -from [all_inputs]
set_false_path -to [all_outputs]
derive_clock_uncertainty
