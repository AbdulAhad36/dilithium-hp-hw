# LightHD NTT simulation

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


All design RTL is in `src/ntt/`. The main UVM environment and standalone vector-capture
SystemVerilog testbench files are in `tb_uvm/tb_uvm_ntt_LightHD/`.
Scripts, simulation libraries and generated artifacts are here in `sim/ntt/`.
The older four-bank UVM environment is archived at
`experiments/ntt_cleanup_archive/2026-10-12/legacy/tb_uvm/tb_uvm_ntt/`.

Run the Questa commands below sequentially: they share the local `work`
library mapping in `modelsim.ini`. Parallel simulator launches can race on it.

## Questa GUI: waves, coverage and results

Open Questa normally. In its Transcript, paste these commands:

```tcl
cd D:/GitHub/dilithium-hp-hw/sim
do ntt/run_uvm.do
```

This compiles and runs the **main UVM** regression, then leaves the simulation
loaded for inspection. Do not append `quit -f` or `quit -sim` when using the GUI.
The command opens:

| Window | What to inspect |
|---|---|
| Wave | Control, input/output handshakes, FSM/stage/issue, FIFO occupancy, butterfly operands/results and routing |
| Covergroups | Expand the UVM coverage component, then each group/coverpoint/cross to see bin hit counts and misses |
| Instance Coverage | Select `tb_top.dut` and expand its children for statements, branches, conditions, expressions, toggles and FSM coverage |
| Code Coverage Analysis | Select a DUT instance and coverage category to inspect covered and missed code |
| Structure / Objects / Source | Browse DUT hierarchy, current signal values and RTL lines |
| Transcript | Named checked jobs, final PASS, UVM error/fatal counts, automatic seven-category DUT code coverage table and report paths |

The Wave window opens separately at 1280 x 720 with visible signal rows and
section dividers. It initially shows **16 to 24 us**, the nonzero directed NTT
job (the first two jobs intentionally use zero data). Use **Zoom Full** for the
whole run, or zoom into another transaction. Wave history
is recorded before running; logging is limited to the clock/interface observations
to avoid recording every internal memory. Wave history is saved in `ntt/ntt_full_test.wlf`; post-netlist runs use `post_synthesis.wlf` or `post_fit.wlf`. These paths avoid sharing the default WLF with another GUI session.

At completion require `NTT INTERACTION UVM PASS: 748/748 jobs` and zero UVM errors/fatals.
Files in `sim/ntt/`: `uvm_gui.log`, `ntt_lighthd_cov.ucdb` (both coverage
kinds), and `ntt_lighthd_coverage.rpt`. Coverage is saved immediately, not only on exit.
The GUI retains its design even after UVM finishes.

After the final UVM report, the Transcript automatically prints
`DUT CODE COVERAGE - raw local-instance bins (testbench excluded)` with hit,
total and percentage for statements, branches, conditions, expressions,
toggles, FSM states and FSM transitions. Counts are calculated from the
just-generated detailed report across DUT instances, with duplicate summary
rows removed; no coverage percentages are hardcoded. The overall DUT code row uses summed hit
bins divided by summed total bins across all seven categories (so toggle bins
carry most of the weight). Functional covergroups are excluded. All rows use
Questa `echo` to display in its Transcript, rather than Tcl terminal output. The UVM report above it
prints the actual overall functional coverage separately.

To return to the useful nonzero transaction after changing the zoom:

```tcl
view wave -undock -width 1280 -height 720
wave zoom range 16us 24us
```


To reopen hidden panes without rerunning:

```tcl
view wave
view covergroups
view instance
view canalysis
view transcript
```

`do ntt/run_uvm.do` also sets up these views when run from the GUI
with `sim/` as the working folder. Headless `-c` runs still unload normally.

## Three simulation entry points

Run these from the Questa Transcript after `cd D:/GitHub/dilithium-hp-hw/sim`:

| Script | Purpose |
|---|---|
| `do ntt/run_uvm.do` | Main UVM with GUI, waves, functional bins and DUT code coverage |
| `do ntt/run_post_synthesis.do` | Functional post-synthesis UVM; GUI keeps waves/design loaded |
| `do ntt/run_post_fit.do` | Functional post-fit UVM; GUI keeps waves/design loaded |

There are no helper `.do` dependencies. Optional checker tests use `NTT_TEST`
on the main script and separate databases. Standalone Python vector capture
uses `set NTT_MODE vectors; do ntt/run_uvm.do`; it remains separate
from the default UVM regression. No testbench or golden model was removed.

## Main UVM coverage run

From the repository's `sim/` directory in PowerShell:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt/uvm_expanded.log -do 'do ntt/run_uvm.do; quit -f'
```

Or enter `do ntt/run_uvm.do` in Questa with `sim/` as the working directory.
This runs the main `tb_top.sv` UVM environment: 53 standard jobs, 13 Pre jobs,
four no-reset operation changes, four input-gap/output-stall jobs,
nine reset/recovery scenarios and 32
bounded-random paired general/Pre jobs, one CT arithmetic-boundary job and
one all-lane PWM product/carry-boundary job and one inverse GS-sum
boundary job: **118 original jobs**. It additionally runs 502 expanded jobs
(input shapes, output ranges, PWM pairs, variable flow and transitions),
for 620 jobs at that checkpoint. The current sequence adds another 128 interaction jobs for **748 total**, with fixed simulator seed 20261011.
It checks every output and observed internal trace before crediting functional
coverage. The independent `ntt_routing_trace.sv` checks coefficient pairs,
registered operands, FIFO contents/writeback, destinations and output order.
`CHECKED_COEFFICIENT_ROUTING` logs counts per checked job. `CHECKED_TRACE` names the passing job and its observed event masks.
The earlier 620-job checkpoint had 22 groups: the original fourteen remain at 100%; the average
is 99.51%, minimum 92.36%. Each group must reach at least 90%, with misses
visible. `CHECKED_EXTENDED` prints measured flow/shape observations.
The scoreboard independently checks requested run counts/durations before credit.

The same run instruments only the DUT for code coverage and generates:

- `ntt_lighthd_cov.ucdb`: functional and DUT code coverage database.
- `ntt_lighthd_coverage.rpt`: detailed individual bin and DUT code counts.
- `uvm_expanded.log`: named witnesses, 748/748 current summary, zero UVM errors/fatals.

There are exactly three active `.do` files: `run_uvm.do`, `run_post_synthesis.do`, and `run_post_fit.do`. Wave setup and vendor-library setup are embedded in these scripts.
See `docs/ntt_docs/post_midyear/COVERAGE.md` for exact counts and exclusions.

## Separate UVM checker self-test

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt/coverage_gate_expanded.log -do 'set NTT_TEST ntt_coverage_gate_test; do ntt/run_uvm.do; quit -f'
```

Require `UVM COVERAGE GATE PASS`. The test runs one real passing DUT job, then
corrupts coefficient data, beat count, framing, trace, reset-clear status and
maximum gap/stall observations. Seven expected
scoreboard errors are caught locally; checked coverage remains unchanged.
The failed jobs carry poisoned arithmetic masks; arithmetic bins must also
remain unchanged; the eight new groups must also gain no credit.
The one-pass/seven-fail scoreboard summary is intentional for this checker test.
Its UCDB/report remain separate from the main regression artifacts, named after `NTT_TEST` (for example `ntt_coverage_gate_test.ucdb` and `ntt_coverage_gate_test_code.rpt`).

## Separate routing checker self-tests

From `sim/` in Questa:

```tcl
set ROUTING_TEST ntt_routing_operand_fault_test
set NTT_TEST $ROUTING_TEST; do ntt/run_uvm.do
set ROUTING_TEST ntt_routing_writeback_fault_test
set NTT_TEST $ROUTING_TEST; do ntt/run_uvm.do
```

Or from PowerShell, capture the default operand-observation test:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt/routing_operand_gate.log -do 'set NTT_TEST ntt_routing_operand_fault_test; do ntt/run_uvm.do; quit -f'
```

Require `UVM ROUTING CHECKER PASS`. These tests each corrupt one internal
observation, verify the real DUT output is still correct, and require zero
checked jobs/bins. Two expected errors are caught (routing checker and
scoreboard). Their UCDB remains separate from the normal passing regression, named after the selected `NTT_TEST`.

## Separate expected-illegal Pre input tests

Run from `sim/` in Questa:

```tcl
set PRE_INVALID_TEST ntt_pre_invalid_first_test
set NTT_TEST $PRE_INVALID_TEST; do ntt/run_uvm.do
set PRE_INVALID_TEST ntt_pre_invalid_middle_test
set NTT_TEST $PRE_INVALID_TEST; do ntt/run_uvm.do
set PRE_INVALID_TEST ntt_pre_invalid_last_test
set NTT_TEST $PRE_INVALID_TEST; do ntt/run_uvm.do
```

The cases send +5 at coefficient 0, -5 at 128 and +5 at 255. Require the exact
DUT fatal `Pre-NTT requires every coefficient in [-4,4]` for each case.
These are expected rejection runs, with no normal scoreboard PASS summary;
do not merge their UCDB into the passing main run. The guard is simulation-only.

## Separate standalone vector capture

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt/vector.log -do 'set NTT_MODE vectors; do ntt/run_uvm.do; quit -f'
```

Vector capture is separate from UVM; `NTT VECTOR CAPTURE COMPLETE` alone is
not correctness. From the root, prepare missing vectors and compare captured
coefficients with the independent reference:

```powershell
py -3 FIPS204_NTT/ntt_vectors.py prepare
py -3 FIPS204_NTT/ntt_vectors.py compare --observed sim/ntt/ntt_dut_outputs.txt
py -3 sim/ntt/fifo_schedule.py
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
set NTT_WORK ntt/work_gs_gate
set NTT_UCDB ntt/ntt_gs_gate.ucdb
set NTT_REPORT ntt/ntt_gs_gate_code.rpt
set NTT_TEST ntt_gs_sum_gate_test
do ntt/run_uvm.do
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

## Latest selected early-write/prefetch evidence (2026-10-10)

Commands are unchanged. Current main transcript:uvm_write_select_prefetch.log
(also refreshed uvm_stage4.log),118/118 passing, zero UVM errors/fatals, fourteen
checked functional groups 100%. Main UCDB/report describe the selected source.
Separate vector_write_select_prefetch.log / compare_write_select_prefetch.log
passes 18/18 cases, 4608/4608 coefficients; core 267/267/75/236 and wrapper 781/781/845/750.
Fresh coverage_gate_write_select_prefetch.log and
routing_writeback_write_select_prefetch.log reject faults without new credit;
negative UCDBs stay separate. Fitted worst Fmax 150.49 MHz, setup -1.645 ns at 5 ns.
Exact source and full evidence:experiments/ntt_stage4/lighthd_write_select_prefetch_checkpoint.
The earlier first-fold and control-only trials remain historical evidence.

## Fresh selected-source verification after delay trials (2026-10-10)

Both BF delay timing trials are rejected after full fits. The selected 150.49 MHz
source is restored byte-for-byte; normal launch commands are unchanged.
Current main transcript: `uvm_bf_delay_restore.log` (also `uvm_stage4.log`),
118/118 jobs, zero errors/fatals, fourteen checked covergroup types 100%.
Separate `vector_bf_delay_restore.log` / `compare_bf_delay_restore.log` passes
18/18 cases, 4,608/4,608 coefficients; all operation cycles are unchanged.
No TB, reference or golden-model change. Archived trial UCDBs are separate from
the current main UCDB; previous negative-checker evidence remains retained,
not newly rerun. The plan contains both rejected trials' timing comparisons.

## Fresh restored baseline after candidate/tag trials (2026-10-10)

The BF candidate-register, tag-register-only and tag/write-mask trials pass
source verification but regress worst setup, so all are rejected and saved.
All six selected RTL files are restored byte-for-byte. Fresh current source logs:
`uvm_candidate_tag_restore.log` (also `uvm_stage4.log`),
`vector_candidate_tag_restore.log`, `compare_candidate_tag_restore.log`.
Main UVM: 118/118 jobs, zero errors/fatals, fourteen checked functional groups
100%. Python: 18/18 cases, 4,608/4,608 coefficients. All operation cycles remain
unchanged. Golden/reference and TB files are unchanged. Exact source hashes and
complete restoration evidence are saved in
`experiments/ntt_stage4/lighthd_candidate_tag_trials_restore/`.
The plan records rejected timing results; no timing improvement is claimed.

## Stage 5: post-synthesis and post-fit main UVM

First build the main Quartus project (`ntt.qpf`, revision `ntt`) using GUI
**Processing > Start Compilation**. Then generate both functional netlists:

```powershell
cd 'D:\GitHub\dilithium-hp-hw\quartus\ntt'
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_netlists.ps1
```

The exporter runs synthesis only in the generated `postsynth_build/` helper
project, and exports post-fit from the main fitted project. It keeps the main
fit database intact. This prevents Standard Edition from exporting the same
fitted database twice. The helper uses the same six RTL sources and settings;
only its relative source paths change. Its generated database is ignored.

In Questa set the working directory to `sim/`, then run one at a time:

```tcl
do ntt/run_post_synthesis.do
do ntt/run_post_fit.do
```

Or capture each transcript from PowerShell (working directory `sim/`):

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt/post_synthesis_uvm.log -do 'do ntt/run_post_synthesis.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt/post_fit_uvm.log -do 'do ntt/run_post_fit.do; quit -f'
```

Require `NTT NETLIST REGRESSION PASS`,117/117 passing jobs,29,952/29,952
coefficients and zero UVM errors/fatals for each. A simulator exit code alone
is not sufficient. The embedded setup in both post-netlist scripts compiles local Quartus primitives
once, including `altera_lnsim` M10K models and encrypted Cyclone V atoms.

This uses the same `tb_top.sv`, UVM agent, monitor, scoreboard, sequences and
independent SV golden model as the source regression. `NTT_NETLIST` removes
RTL-only hierarchy hookups; `ntt_netlist.sv` selects external-only checking.
All 109 non-reset source cases are reused; nine RTL-state reset cases are
replaced by eight resets witnessed through public pins (117 total). The
scoreboard checks all 256 outputs, exact framing and stall stability; a public
protocol checker checks input/output counts, busy/done and seven aborted jobs.
Sixteen real Pre/general pairs and eight reset/recovery witnesses are required.
No source internal trace or functional/code coverage is credited or merged.

The separate external-checker self-test intentionally rejects five corruptions:

```tcl
set NTT_TEST ntt_netlist_gate_test
do ntt/run_post_fit.do
```

Require `NTT NETLIST CHECKER GATE PASS`. Its 1 pass / 5 rejections are intentional
and separate from the 117-job regressions. Cyclone V export warning 10905 means
the post-fit model is functional; no SDF is used. Timing remains TimeQuest's
standalone internal signoff, not a gate-level delay or board test.

### Verified Stage 5 results - 2026-10-11

Post-synthesis and post-fit each pass **117/117 jobs, 29,952/29,952 coefficients**,
zero UVM errors/fatals, sixteen equivalence pairs and eight reset witnesses.
Fresh source `uvm_stage5_source.log` passes **118/118**, fourteen functional
groups at 100%, unchanged raw code counts. Both separate checker self-tests
reject their five deliberate corruptions; source failures add no coverage credit.
Exact transcripts, source hashes, netlist provenance, UCDB/report and parsed
results are in [the checkpoint](../../experiments/ntt_stage5/netlist_verification_checkpoint/README.md).
No RTL or golden-model change, board result or new commit.

## Current expanded coverage - 2026-10-11

620/620 source jobs, 158,720 checked coefficients, 22 covergroup types.
Functional type average 99.51%, minimum 92.36%, eight new groups mean 98.65%.
Raw statements 98.32%, branches 96.52%, conditions 65.88%, expressions 94.92%,
toggles 91.80%, FSM states/transitions 100%. Raw code counts are unchanged from
Stage 5; no exclusions. Exact remaining bins, code counts, study flow and sources
are in [COVERAGE.md](../../docs/ntt_docs/post_midyear/COVERAGE.md) and
[the new checkpoint](../../experiments/ntt_stage4/lighthd_expanded_coverage_checkpoint/README.md).
The current source seven-fault credit gate and netlist five-fault compatibility
gate pass separately. Historical netlist 117-job results above are not expanded
620-job netlist results. RTL/golden/timing/cycle counts are unchanged.

## Three-script consolidation check (2026-10-12)

The main GUI launcher passed 620/620 jobs and 158,720/158,720 coefficients,
with zero UVM errors/fatals after the wave setup was embedded. Both self-contained
post-netlist GUI launchers were checked with `ntt_netlist_gate_test`: each ran
one real golden-compared transaction and rejected five deliberately corrupted
observations, with zero UVM errors/fatals. These are launcher checks; the retained
117-job post-netlist results above remain the full-suite evidence. Optional
vector mode passed Python comparison: 18/18 cases, 4,608/4,608 coefficients.
No RTL or golden-model changes were required for this consolidation.
