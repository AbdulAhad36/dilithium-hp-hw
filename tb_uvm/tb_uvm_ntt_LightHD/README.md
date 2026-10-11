# LightHD NTT UVM testbench

**Current source verification (2026-10-12):** 748/748 UVM jobs,
191,488 compared coefficients, zero UVM errors/fatals, 32 checked covergroup
types at **90.47% overall functional type average**. Ten new groups and 128
new tests extend the prior 620-job checkpoint. The raw bin aggregation is
73.33%; the large transition/shape/flow cross remains only 5.47%, so this is
an incomplete-coverage review checkpoint. Original 22 groups retain their
>=90% gate; overall must reach >=90%, with no upper-bound failure or suppression
of valid hits. Code counts, RTL, golden model and fit metrics are unchanged.
See `docs/ntt_docs/post_midyear/COVERAGE.md` for exact definitions, all misses and evidence.
Older dated counts below are historical checkpoints. Stage 6 has not begun.


This folder contains **all LightHD candidate testbench source files**:
the UVM interface, transaction, sequences, driver, monitor, scoreboard,
coverage, tests, top module, SV reference package, and the standalone vector
capture testbench. The redundant non-UVM core/engine/arithmetic benches have
been removed; the main UVM environment owns regression and coverage. The candidate's simulation scripts are in
`sim/ntt_LightHD/`; run them from `sim/` as shown in that folder's README.

The older four-bank testbench is archived at
`experiments/ntt_cleanup_archive/2026-10-12/legacy/tb_uvm/tb_uvm_ntt/`.
`sim/ntt_LightHD/` holds scripts, generated libraries, logs, and DUT output
captures. It does not hold testbench `.sv` source files.

Earlier expanded checkpoint: 620/620 with 22 checked covergroup types,
99.51% type average and minimum 92.36%. `ntt_arithmetic_boundary_seq` supplies the directed CT thresholds;
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
`sim/ntt_LightHD/uvm_expanded.log`. The separate +8 Pre eligibility test
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

Selected early write-control/prefetch RTL keeps this UVM source unchanged.
Main 118/118 and fourteen checked groups 100%; no timing-model or golden update
was needed because pipeline and every enabled read are unchanged. Fresh coverage
credit/writeback negative checks pass; their failed UCDBs remain separate.
Current source counts/timing are in COVERAGE.md and the post-midyear plan.

## Netlist adapters in the main UVM environment

`ntt_netlist.sv` contains UVM driver/monitor adapters, an external reset
sequence, the 117-job `ntt_netlist_test`, and a separate checker self-test.
It is included by `tb_top.sv` only with `NTT_NETLIST`. It does not instantiate
a separate non-UVM bench. The same public DUT interface and golden model are
used; only RTL hierarchy-dependent observations and coverage are omitted.
The current source `ntt_full_test` requires 748 checked jobs, the original 22
groups at least 90%, and an overall 32-group type average at least 90%. See `sim/ntt_LightHD/README.md` for generation/launches.

Fresh Stage 5 verification (2026-10-11): source 118/118, each distinct netlist
117/117 (29,952 coefficients), zero UVM errors/fatals. Source and netlist
checker self-tests each reject five deliberately corrupted observations.
Internal coverage remains source-only. Evidence is in
`experiments/ntt_stage5/netlist_verification_checkpoint/`.

## Expanded model and study order

Start with `ntt_extended_seq` (502 added jobs), the gap/stall fields in
`ntt_transaction`, the driver/monitor, `ntt_trace.sample_durations`,
`ntt_scoreboard.flow_profile_ok`, then `ntt_coverage.sample_expanded`.
Only scoreboard-accepted jobs can sample the eight new groups. Independent
actual operand capture supplies range/pair/shape bins; actual observed outputs
supply result bins. Flow runs are counted from pins and checked against the
requested per-region profile before publication. The separate seven-fault
source checker rejects forged gap/stall maxima as well as the original five
corruptions without new coverage. Old netlist suites remain historical 117-job
checks; the current shared UVM passes their separate compatibility checker.
See COVERAGE.md for all new bins, exact misses and raw DUT code totals.
