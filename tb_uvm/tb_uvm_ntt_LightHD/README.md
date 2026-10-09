# LightHD NTT UVM testbench

This folder contains **all LightHD candidate testbench source files**:
the UVM interface, transaction, sequences, driver, monitor, scoreboard,
coverage, tests, top module, SV reference package, and the standalone vector
capture testbench. The redundant non-UVM core/engine/arithmetic benches have
been removed; the main UVM environment owns regression and coverage. The candidate's simulation scripts are in
`sim/ntt_LightHD/`; run them from `sim/` as shown in that folder's README.

The four-bank design keeps its separate testbench in `tb_uvm/tb_uvm_ntt/`.
`sim/ntt_LightHD/` holds scripts, generated libraries, logs, and DUT output
captures. It does not hold testbench `.sv` source files.

Current main regression is 118/118 with fourteen implemented checked covergroups
at 100%. `ntt_arithmetic_boundary_seq` supplies the directed CT thresholds;
`ntt_routing_trace` checks actual operands/writebacks, `ntt_scoreboard` checks
all outputs/framing, and only its `checked_ap` can credit `ntt_coverage`.
Start studying at `ntt_sequence.sv`, then driver, monitor/routing trace,
scoreboard, coverage and top. Exact bins and current metrics are in
`docs/ntt_docs/post_midyear/COVERAGE.md` and the post-midyear plan.

`ntt_reduction_boundary_seq` adds one main-UVM PWM job with five real operand
pairs on all four multiplier lanes. `CHECKED_REDUCTION_BOUNDARIES` prints
checked observed results 0/1/1/10000/30000. Study its stimulus, routing trace and
scoreboard before the multiplier RTL. The added case preserves the fourteen
covergroup types; golden mathematics are unchanged. Current main log is
`sim/ntt_LightHD/uvm_fold_pipeline.log`. The separate +8 Pre eligibility test
checks exact DUT rejection; expected failures do not credit normal coverage.

`ntt_inverse_sum_boundary_seq` adds one INTT job with5actual GS sum classes on
all4lanes. Study `ntt_routing_trace.note_gs_sum()` and the scoreboard's named-job
mask requirement, then the S+8191carry reduction in `butterfly_unit.sv`.
`ntt_gs_sum_gate_test` separately rejects a missing lane2 exact-q witness without
credit despite correct outputs. Fourteen covergroup types remain unchanged.

Current return latency is ten clocks (multiplier/BF/return5/7/10). Study the
registered first-fold carry-save words in mod_mul.sv and the extra kept-operand
and tag delays, then the independent ten-clock trace/pending-write models.
The oracle arithmetic is unchanged. Current measured core267/267/75/236 and
wrapper781/781/845/750 include the added drain clock. Nine reset/recovery
points and fresh separate fault-credit gates pass; failed UCDBs stay separate.
