# Current Dilithium simulation

The complete production top is `dilithium_fpga`; sources are listed in
`quartus/dilithium/dilithium_full.qsf`. Use Questa 2024.1 from
`C:/questasim64_2024.1/win64`. The full user guide is
[OUTPUT_SIM_COMAPRE.md](../../docs/dilithium_docs/OUTPUT_SIM_COMAPRE.md).

## Capture selected operations

In the Questa Transcript, from the repository root:

```tcl
set DILITHIUM_TEST all
set DILITHIUM_FAST 1
do sim/dilithium/run.do
```

Set `DILITHIUM_TEST` to `keygen`, `sign` or `verify` for only that operation.
Set it explicitly for each launch. All choices use `tb/tb_dilithium/tb_main.sv`
and the production top. Cases preserve NIST group/case IDs, ordered by selected
operation. The launcher reports the actual supported case count from the inputs.

Fast mode disables broad debug access/wave logging without dropping RTL checks
or cases. GUI defaults to fast=0; batch defaults to fast=1. Set
`DILITHIUM_FAST 0` before launching when you need GUI waves/debug access.
The setting does not modify a running simulation.

Unchanged fixture preparation is cached using current content hashes of source,
references, NIST JSON and prepared artifacts. Compilation is one separate-unit
`vlog -sv -sfcu` invocation when needed and is reused for unchanged sources.
Includes force recompilation to avoid stale headers. Set `DILITHIUM_REBUILD 1`
to force compilation after manual library changes, then set it back to zero.
Stamps live inside the ignored `work_main_<tool>/` library directory. The cache
permits edited NIST data and invalidates on changes; it is not pinned provenance.

The 15-case runtime check measured 18.092-23.893 seconds in fast mode versus
80.844 seconds with broad debug visibility. Outputs/retries/clocks were exact.
This 3.4-4.5x result is diagnostic host runtime, not guaranteed full-corpus speed
or improved hardware performance. Cold/warm preparation/compilation costs differ.

## Current file names

| File | Purpose |
|---|---|
| `main_inputs.txt` | Selected complete main input cases |
| `main_outputs.txt` | Detailed complete main capture |
| `main_diagnostic_inputs.txt` / `main_diagnostic_outputs.txt` | Small mixed-mode diagnostic subset and capture |
| `main_protocol_inputs.txt` / `main_protocol_outputs.txt` | Error, busy-command, reset and recovery campaign |
| `outputs_hw.txt` | Readable keys/signatures/verdicts written directly by the bench |
| `main.wlf` | Main waveform database when logged |
| `uvm_inputs.txt` / `uvm_expected.txt` | UVM inputs and independent expected outputs |
| `uvm.ucdb`, `uvm.wlf` | Full UVM coverage and waveform databases |
| `uvm_*` reports / CSVs | Functional/code detail, checked outcomes and latencies |

Generated main artifacts are refreshed by the launcher. UVM fixtures are
prepared separately after source changes. Named captures remain bound to their
own recorded source tokens: a filename change alone is not a new full run.
Frozen reports/captures are retained under `reference_build/`; do not overwrite
those during experimentation. The naming-cleanup manifest is under
`reference_build/evidence/current_names/`.

## Independent comparison

After a normal full capture, run in PowerShell from the repository root:

```powershell
python sim/dilithium/dilithium_vectors.py main_compare --operation all
```

Use the same operation selection as the simulation. Expected values are not
fed into RTL. A capture completion footer confirms transaction checks, while
the independent command compares exact outputs and additional arithmetic audit
records. Do not bypass a stale-source error by editing capture headers.

For readable HW/SW files:

```powershell
python sim/dilithium/compare_outputs.py --sw dilithium-sw-model/golden/output_compare/outputs_sw.txt --hw sim/dilithium/outputs_hw.txt
```

This compares case IDs, levels and operations, then full keys/signatures or
Verify results. Missing/extra cases fail. `--operation` selects one operation
from mixed files. Default report: `comparison_hw_sw.txt` in the current directory.

## Main UVM

Prepare fixtures in PowerShell:

```powershell
python sim/dilithium/dilithium_vectors.py uvm_prepare
```

Launch in the Questa Transcript:

```tcl
do sim/dilithium/run_uvm.do
```

The GUI shows waves and functional/code coverage. Summaries appear in the
Transcript at completion. Default test: `dilithium_regression_test`; choose
`dilithium_random_stall_test` with `DILITHIUM_UVM_TEST` for bounded random
transport stalls. UVM's internal-message stimulus/coverage still needs extension;
saved source-bound coverage is not signoff for that API.

## Focused checks and isolated data

`DILITHIUM_TEST main_diagnostic` selects the quick main subset. Compare with
`main_diagnostic_compare` using the same `--operation`. `main_protocol` runs
the main protocol campaign; compare with `main_protocol_compare`. These write
separate detailed captures, but a diagnostic can replace `outputs_hw.txt`.

For isolated checks, `DILITHIUM_DATA_DIR`, `DILITHIUM_WORK_DIR` and
`DILITHIUM_LIBRARY` select a separate main data directory, compiled library
directory and library alias. Independent preparation/comparison accepts
`--output-dir` for normal/diagnostic captures. These variables persist in Tcl;
unset them before returning to default paths. Reuse one scratch workspace.

Do not change physical source/constraints or claim fitted timing based on this
simulation cleanup. Current scope and gates are in the integration documents;
past experiment summaries are centralized in
[PAST_BUILDS.md](../../docs/dilithium_docs/PAST_BUILDS.md).
