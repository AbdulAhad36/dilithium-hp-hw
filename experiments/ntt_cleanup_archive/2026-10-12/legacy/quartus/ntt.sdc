# =============================================================================
# ntt.sdc  -  Timing Constraints
# Target clock: 200 MHz (5 ns period) — aggressive; the fitter reports the
# achieved Fmax regardless. Mirrors the keccak benchmark SDC for consistency.
# =============================================================================

create_clock -name clk -period 5.0 [get_ports clk]

# We only care about Fmax (register-to-register), not I/O timing.
set_false_path -from [all_inputs]
set_false_path -to   [all_outputs]

derive_clock_uncertainty
