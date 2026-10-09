# LightHD NTT simulation

All design RTL is in `src/ntt_LightHD/`. The main UVM environment and standalone vector-capture
SystemVerilog testbench files are in `tb_uvm/tb_uvm_ntt_LightHD/`.
Scripts, simulation libraries and generated artifacts are here in `sim/ntt_LightHD/`.
The saved four-bank UVM environment remains in `tb_uvm/tb_uvm_ntt/`.

Run the Questa commands below sequentially: they share the local `work`
library mapping in `modelsim.ini`. Parallel simulator launches can race on it.

## Main UVM coverage run

From the repository's `sim/` directory in PowerShell:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/uvm_stage4.log -do 'do ntt_LightHD/run_uvm.do; quit -f'
```

Or enter `do ntt_LightHD/run_uvm.do` in Questa with `sim/` as the working directory.
This runs the main `tb_top.sv` UVM environment: 53 standard jobs, 13 Pre jobs,
four no-reset operation changes, four input-gap/output-stall jobs,
nine reset/recovery scenarios and 32
bounded-random paired general/Pre jobs, one CT arithmetic-boundary job and
one all-lane PWM product/carry-boundary job and one inverse GS-sum
boundary job, **118 total**.
It checks every output and observed internal trace before crediting functional
coverage. The independent `ntt_routing_trace.sv` checks coefficient pairs,
registered operands, FIFO contents/writeback, destinations and output order.
`CHECKED_COEFFICIENT_ROUTING` logs counts per checked job. `CHECKED_TRACE` names the passing job and its observed event masks.
All fourteen implemented covergroups reach 100%; this is not full Stage 4 closure.

The same run instruments only the DUT for code coverage and generates:

- `ntt_lighthd_cov.ucdb`: functional and DUT code coverage database.
- `ntt_lighthd_coverage.rpt`: detailed individual bin and DUT code counts.
- `uvm_stage4.log`: named witnesses, 118/118 summary, zero UVM errors/fatals.

`run_uvm_code_coverage.do` is a compatibility alias for this main flow.
See `docs/ntt_docs/post_midyear/COVERAGE.md` for exact counts and exclusions.

## Separate UVM checker self-test

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/coverage_gate.log -do 'do ntt_LightHD/run_scoreboard_gate.do; quit -f'
```

Require `UVM COVERAGE GATE PASS`. The test runs one real passing DUT job, then
corrupts coefficient data, beat count, framing, trace and reset-clear checks. Five expected
scoreboard errors are caught locally; checked coverage remains unchanged.
The failed jobs carry poisoned arithmetic masks; arithmetic bins must also
remain unchanged.
The one-pass/five-fail scoreboard summary is intentional for this checker test.
Its UCDB/report remain separate from the main regression artifacts.

## Separate routing checker self-tests

From `sim/` in Questa:

```tcl
do ntt_LightHD/run_routing_checker.do
set ROUTING_TEST ntt_routing_writeback_fault_test
do ntt_LightHD/run_routing_checker.do
```

Or from PowerShell, capture the default operand-observation test:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/routing_operand_gate.log -do 'do ntt_LightHD/run_routing_checker.do; quit -f'
```

Require `UVM ROUTING CHECKER PASS`. These tests each corrupt one internal
observation, verify the real DUT output is still correct, and require zero
checked jobs/bins. Two expected errors are caught (routing checker and
scoreboard). Their UCDB remains separate from the normal passing regression.

## Separate expected-illegal Pre input tests

Run from `sim/` in Questa:

```tcl
do ntt_LightHD/run_pre_eligibility.do
set PRE_INVALID_TEST ntt_pre_invalid_middle_test
do ntt_LightHD/run_pre_eligibility.do
set PRE_INVALID_TEST ntt_pre_invalid_last_test
do ntt_LightHD/run_pre_eligibility.do
```

The cases send +5 at coefficient 0, -5 at 128 and +5 at 255. Require the exact
DUT fatal `Pre-NTT requires every coefficient in [-4,4]` for each case.
These are expected rejection runs, with no normal scoreboard PASS summary;
do not merge their UCDB into the passing main run. The guard is simulation-only.

## Separate standalone vector capture

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/vector.log -do 'do ntt_LightHD/run_vectors.do; quit -f'
```

Vector capture is separate from UVM; `NTT VECTOR CAPTURE COMPLETE` alone is
not correctness. From the root, prepare missing vectors and compare captured
coefficients with the independent reference:

```powershell
py -3 FIPS204_NTT/ntt_vectors.py prepare
py -3 FIPS204_NTT/ntt_vectors.py compare --observed sim/ntt_LightHD/ntt_dut_outputs.txt
py -3 sim/ntt_LightHD/fifo_schedule.py
```

The redundant non-UVM core, engine and arithmetic benches and their launchers
have been removed. Functional and DUT code coverage come from the main UVM
regression. The standalone vector capture remains separate for Python comparison.
Historical Stage 3 results remain in `experiments/ntt_stage3/lighthd_fifo/`.
Generated logs, libraries, reports, UCDBs and captured outputs are ignored by Git.

## Earlier pipeline-rebalance checkpoint (2026-10-09)

The retained sum-split/reduction-rebalance RTL passes main UVM 115/115
(`uvm_balanced.log`, also copied to `uvm_stage4.log`) and separate Python
comparison 18/18 cases, 4,608/4,608 coefficients (`vector_balanced.log` and
`compare_balanced.log`). The implemented checked functional covergroups all
reach 100%; code coverage remains the raw counts documented in `COVERAGE.md`.
Cycles are unchanged. Fresh fitted performance is 101.28 MHz worst-corner
Fmax, 2,937 ALMs, 6 DSPs and 20 M10Ks; 200 MHz timing closure remains open.

## Earlier carry-save/fixed-packing RTL (2026-10-09)

`uvm_fixed_load.log` (also copied to `uvm_stage4.log`) passes 115/115 jobs with zero errors/fatals; `vector_fixed_load.log` and `compare_fixed_load.log` pass 18/18 cases and 4,608/4,608 coefficients. Cycles remain unchanged. That checkpoint fitted resources were 2,777 ALMs, 2,058 registers, 5 DSPs and 20 M10Ks at 114.26 MHz worst-corner Fmax. Setup at 200 MHz remains open. The same launch commands above use the latest RTL.

## Earlier retained arithmetic RTL (2026-10-09)

The commands above use the selected latest RTL. `uvm_final_fold.log` (also
`uvm_stage4.log`) records 116/116 passing jobs, zero UVM errors/fatals, and
fourteen implemented checked covergroup types at 100%. The new first-stage
arithmetic-boundary job forces raw CT sums 0/below q/equal q/above q/maximum
and negative/zero/positive subtraction. Its actual operands and writebacks
must pass before final golden output comparison allows coverage credit.
Search for `CHECKED_ARITHMETIC_BOUNDARIES`; see `COVERAGE.md` for all eight bins.

`coverage_gate_final_fold.log` records `UVM COVERAGE GATE PASS`; the five
rejected jobs cannot raise arithmetic coverage even with falsely complete masks.
`vector_final_fold.log` and `compare_final_fold.log` record 18/18 cases and
4,608/4,608 coefficients. The independent SV oracle is unchanged.

Current fitted resources: 2,717 ALMs, 2,078 registers, 5 DSPs, 20 M10Ks;
worst-corner Fmax 129.08 MHz. Core NTT/INTT/PWM/Pre cycles remain
266/266/74/235 and wrapper cycles 780/780/844/749. Setup at 200 MHz still fails.
The prior 114.26 and 119.33 MHz builds and the selected 129.08 MHz RTL/reports
are saved under `experiments/ntt_stage4/`. Stage 4 remains open.

## Earlier selected subtraction/FIFO source run (2026-10-09)

The launch commands above use the latest selected design. `uvm_write_mux.log`
(also `uvm_stage4.log`) passes 116/116, zero errors/fatals; all fourteen
implemented checked covergroups reach 100%. The directed arithmetic job now
checks ten bins: five sums and five subtraction classes, including minimum
`-(q-1)` and maximum `q-1`, with required canonical outputs 1 and q-1.

`coverage_gate_write_mux.log` rejects five corrupted jobs without adding
coverage; `routing_writeback_write_mux.log` proves an incorrect observed write
cannot credit bins, even when actual DUT output remains correct. Both are
separate UVM self-tests. Python `vector_write_mux.log` + `compare_write_mux.log`
passes 18/18 cases and 4,608/4,608 coefficients. Golden mathematics are unchanged.

Fresh selected fit: 2,428 ALMs, 2,022 registers, 5 DSPs, 20 M10Ks; 131.22 MHz
worst-corner Fmax. All core and wrapper cycle counts remain unchanged. The
prior 129.08 MHz result, both slower arithmetic trials and the selected FIFO
result are saved under `experiments/ntt_stage4/`. Current timing targets are
Pre lookup and multiplier folds 2/3; 200 MHz setup/pulse width still fail.
See the plan/coverage/throughput documents for exact metrics and remaining gates.

## Earlier restored selected source (2026-10-09)

Both new timing trials were saved and rejected: narrow Pre decoder 129.70 MHz /
2,392 ALMs; collapsed multiplier reduction 123.38 MHz / 2,671 ALMs. The faster
131.22 MHz / 2,428 ALM checkpoint is restored. Main UVM now passes **117/117**,
zero errors/fatals and fourteen checked covergroup types 100%; the useful
all-lane product/carry-boundary PWM job remains. Look for
`CHECKED_REDUCTION_BOUNDARIES` and observed results `0/1/1/10000/30000`.

Current source logs are `uvm_selected_restore.log` (also `uvm_stage4.log`),
`vector_selected_restore.log` and `compare_selected_restore.log`. Python passes
18/18 cases, 4,608/4,608 coefficients. The separate
`pre_invalid_alias_selected_restore.log` reaches the exact DUT eligibility fatal
for +8 without any passing job; its UCDB is not merged. Commands above are unchanged.
Active RTL/golden semantics and cycle counts match the selected checkpoint.
Stage 4 remains open. No files were staged or committed.

## Earlier selected four-cycle rebalance (2026-10-09)

The same commands run the latest RTL. `uvm_final_rebalance.log` (also
`uvm_stage4.log`) passes 117/117, zero UVM errors/fatals and fourteen checked
covergroup types 100%. `vector_final_rebalance.log` and
`compare_final_rebalance.log` pass 18/18 cases, 4,608/4,608 coefficients.
Golden models, input/output format and cycle counts are unchanged.

The multiplier registers product / fold1 / fold2 / fold3+canonical correction.
Fresh fit: 134.50 MHz worst Fmax, 2,487 ALMs, 2,081 registers, 5 DSP, 20 M10K.
This is 2.50% higher Fmax for 59 more ALMs than the saved 131.22 MHz design.
`coverage_gate_final_rebalance.log` and `routing_writeback_final_rebalance.log`
confirm failed observations add no checked coverage; their UCDBs stay separate.
Raw multiplier coverage is 35/35 statements, 10/10 branches, 876/990 toggles;
`COVERAGE.md` explains all 114 missed constant-bit toggle bins. No exclusions.
Stage 4 remains open and nothing was staged or committed.

## Earlier selected q+1 subtraction (2026-10-09)

The same commands run current RTL. `uvm_sub_qplus1.log` (also `uvm_stage4.log`)
passes 117/117, zero UVM errors/fatals and fourteen checked covergroup types 100%.
`vector_sub_qplus1.log` / `compare_sub_qplus1.log` pass 18/18 cases, 4,608/4,608
coefficients. Existing SV/Python mathematics, formats and cycle counts are unchanged.

Fresh fit: **137.04 MHz worst Fmax, 2,451 ALMs, 2,071 registers, 5 DSPs,
20 M10Ks**. The butterfly's corrected subtraction candidate compresses q+1
instead of injecting +1 in the final carry word. The preceding 134.50 MHz /
2,487 ALM checkpoint remains saved; raw source coverage counts are unchanged.
See `COVERAGE.md` for arithmetic/coverage justification and the plan for exact
corner/slack tradeoffs. Stage 4 remains open; nothing staged or committed.

## Earlier selected twiddle-guard removal (2026-10-10)

The same commands run current RTL. `uvm_tw_nonzero.log` (also `uvm_stage4.log`)
passes 117/117, zero UVM errors/fatals and fourteen checked covergroup types 100%.
`vector_tw_nonzero.log` / `compare_tw_nonzero.log` pass 18/18 cases and
4,608/4,608 coefficients. Golden mathematics, formats and cycle counts unchanged.
Separate current checker logs are `coverage_gate_tw_nonzero.log`,
`routing_writeback_tw_nonzero.log` and `pre_invalid_alias_tw_nonzero.log`;
expected-failure coverage remains separate from passing regression.

Fresh fit: **140.69 MHz worst Fmax, 2,427 ALMs, 2,123 registers, 5 DSPs,
20 M10Ks**. The redundant inverse twiddle zero guard is removed; no added
pipeline stage. Core raw condition denominator decreases by one, with no added
hit. See `COVERAGE.md` and the plan for proofs, counts and timing tradeoffs.
Previous checkpoint stays saved; Stage 4 remains open. Nothing committed.

## Earlier selected fixed Boolean operand selectors (2026-10-10)

Same commands run current RTL. `uvm_operand_boolean.log` (also `uvm_stage4.log`)
passes117/117, zero UVM errors/fatals and14checked covergroup types100%.
`vector_operand_boolean.log` / `compare_operand_boolean.log` pass18/18cases,
4608/4608coefficients. Formats, oracles and cycle counts unchanged. Separate
checker logs: `coverage_gate_operand_boolean.log`,
`routing_operand_operand_boolean.log`, `routing_writeback_operand_boolean.log`.
Expected failures remain separate from the passing UCDB.

Fresh selected fit145.18MHz/2592ALMs/2152registers/5DSP/21M10K improves worst
Fmax3.19% at the cost of165ALMs and1M10K versus saved140.69MHz/2427ALMs/20M10Ks.
No added pipeline stage. Packed selectors increase raw toggle instrumentation;
`COVERAGE.md` explains the exact counts. Stage4 remains open; nothing committed.

## Latest selected kept-sum reduction (2026-10-10)

Same main command runs118/118jobs, zero UVM errors/fatals,14checked groups100%
(`uvm_keep_bias.log`, also `uvm_stage4.log`). The added inverse GS boundary job
forces and checks5sum classes per physical lane, plus every write/output.
`vector_keep_bias.log` / `compare_keep_bias.log` pass18/18cases,4608coefficients.
No golden/vector/format/cycle changes. Separate `gs_sum_gate_keep_bias.log`
rejects a missing exact-q observation despite correct outputs; existing
`coverage_gate_keep_bias.log` rejects five deliberate failures. Failed UCDBs separate.

Fresh fit145.73MHz/2568ALMs/2117registers/5DSP/21M10K; worstsetup-1.862ns,
hold+0.104ns,pulse-0.555ns. Stage4open,200MHz unmet,nothing committed.

To reproduce the separate GS witness gate from the Questa console in sim/:
```tcl
set NTT_WORK ntt_LightHD/work_gs_gate
set NTT_UCDB ntt_LightHD/ntt_gs_gate.ucdb
set NTT_REPORT ntt_LightHD/ntt_gs_gate_code.rpt
set NTT_TEST ntt_gs_sum_gate_test
do ntt_LightHD/run_uvm.do
```
Require `UVM GS SUM GATE PASS`; this self-test intentionally records one rejected
comparison and uses its own UCDB. It does not replace the118passing main jobs.

## Latest selected first-fold pipeline (2026-10-10)

Commands above are unchanged. Current main log is uvm_fold_pipeline.log
(also uvm_stage4.log):118/118,zero errors/fatals,fourteen checked groups100%.
The multiplier/BF/return latency is5/7/10, checked by independent ten-clock
UVM tag and physical-writeback models. Separate vector_fold_pipeline.log /
compare_fold_pipeline.log passes18/18cases,4608/4608coefficients, with measured
core267/267/75/236 and wrapper781/781/845/750. The extra stage adds one clock.
Fresh fitted worst Fmax148.46MHz and setup-1.736ns at5ns are in the plan.
The existing FIFO index model now checks current PIPE=10 and saved8/9 schedules.
