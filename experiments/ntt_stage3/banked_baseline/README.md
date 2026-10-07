# Saved Stage 2 banked NTT baseline

This is the uncommitted four-bank 2x2-tile RTL state at the Stage 3 handoff (2026-10-06). The copied `quartus/ntt.qsf` points to the copied `rtl/` directory, so it can be fitted independently. The original `src/ntt_engine/` remains untouched by the parallel8 experiment. SHA256.txt identifies each preserved source and evidence file.

Evidence copied from the last Stage 2 fit: `quartus/ntt_stage2_stallfix_fit.summary`, `ntt_stage2_stallfix_sta.rpt`, and `ntt_stage2_stallfix_paths.log`. These reports apply to this saved source snapshot on Cyclone V 5CGXFC7C7F23C8 with the 5 ns `ntt.sdc` constraint. Results: core 284 NTT / 288 INTT / 74 PWM cycles; complete no-stall transaction 798 / 802 / 844 cycles; fitted 2,873 ALMs, 1,718 registers, 8 DSPs, 19 M10Ks; worst slow-corner Fmax 92.71 MHz, setup slack -5.786 ns, hold slack +0.150 ns. Exact output comparison: 18/18 cases and 4,608/4,608 coefficients; core 33/33, engine 30/30, UVM 53/53. Logs for those tests are in the existing `sim/ntt_stage2_stall_fix_*.log` files.

To repeat the fit, run `quartus_map ntt -c ntt`, `quartus_fit ntt -c ntt`, and `quartus_sta ntt -c ntt` from this `quartus/` directory. To rerun source vector capture, use the copied RTL with `sim/tb_ntt_vectors.sv`, or use `sim/run_ntt_vectors.do` against the original `src/ntt_engine/` (currently byte identical to the copied RTL).
