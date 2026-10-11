# Stage 5 functional netlist verification checkpoint - 2026-10-11

Completed using the main UVM environment, active `src/ntt_LightHD/` RTL,
Questa 2024.1 and Quartus Lite 25.1std for Cyclone V 5CGXFC7C7F23C8.

| Run | Passing jobs | Compared coefficients | UVM errors/fatals |
|---|---:|---:|---:|
| Post-synthesis functional | 117/117 | 29,952/29,952 | 0/0 |
| Post-fit functional | 117/117 | 29,952/29,952 | 0/0 |
| Fresh source UVM | 118/118 | 30,208/30,208 | 0/0 |

Each netlist run additionally gates 117 public completions, seven aborted jobs,
eight reset/recovery witnesses and sixteen Pre/general output-equivalence pairs.
All 109 non-reset source cases are reused; eight public-interface reset scenarios
replace nine source-state scenarios. Output count, coefficient equality, framing,
stall stability and public protocol are checked. No internal coverage is awarded
by netlist mode. The fresh source run retains 118 checked trace/routing witnesses,
fourteen functional covergroup types at 100% and unchanged raw code counts.
This is sampled verification, not exhaustive equivalence or complete code coverage.

## Files and provenance

- `rtl/`, `tb/`, `sim/`, `project/`: exact verification sources/scripts/settings.
  Project snapshots retain paths for the original repository, not a standalone build.
- `source_hashes.json`: hashes checked against the final active sources. All six
  RTL files are byte-identical to the accepted Stage 4 GUI checkpoint; the golden
  model is unchanged.
- `netlist_provenance.json`: exact generated-netlist hashes/sizes and main fit
  summary. Generated netlists/vendor libraries stay ignored in the active project.
- `export/`: export/map logs and the synthesis-only helper QSF. The helper has
  no fitter database; main fitted output was exported separately. The two graphs
  differ even with date headers removed.
- `post_synthesis/`, `post_fit/`: passing transcripts and generated reports.
- `source/`: fresh main UVM transcript, UCDB and full raw coverage report.
- `source_coverage_baseline.json`: previous per-instance raw bins/hits/misses;
  fresh counts were compared against it and match.
- `checker_gate/`: separate source and netlist checker self-tests. Each uses
  one real passing DUT job and rejects five corrupted observed transactions.
  Source gate UCDB is separate and never merged with the main UCDB.
- `results.json`: parsed explicit-pass/count/error gates; no exit-code-only pass.
- `operating_timing_gate.json`: twenty positive checks with zero TNS parsed
  from the current main TimeQuest summary.

The rejected `post_fit_completion_gate_trial.log` is retained: outputs all
matched, but early driver resets prevented observing every completion pulse.
The netlist adapter now waits for `done` before releasing the next item.
The source driver uses an empty default hook; source timing behavior is unchanged.
Both final netlist runs and both checker self-tests use this corrected version.

## Reproduce

Build `quartus/ntt_LightHD/ntt.qpf`, revision `ntt`, using Quartus GUI
**Processing > Start Compilation**. Then from `quartus/ntt_LightHD/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_netlists.ps1
```

From Questa with working directory `sim/`, run sequentially:

```tcl
do ntt_LightHD/run_post_synthesis.do
do ntt_LightHD/run_post_fit.do
do ntt_LightHD/run_uvm.do
```

Require each netlist's `NTT NETLIST REGRESSION PASS` and zero UVM errors/fatals.
For the source run require 118 passes, zero failures/errors/fatals and fourteen
functional covergroup types at 100%. See the main simulation README for
headless transcript commands and the two separate checker self-tests.

## Limits

Cyclone V export warning 10905 means functional only, without SDF. Main fit
summary timestamp is 2026-10-11 01:38:46; export times are in the logs. Resource
counts remain 2,475 ALMs, 2,414 registers, five DSPs, twenty M10Ks. Worst Fmax
is 150.49 MHz; nominal operation is 148 MHz with worst setup/hold +0.111/+0.152 ns.
All twenty current operating checks pass with zero TNS. The 200 MHz benchmark
remains unmet; external I/O is false-pathed. Netlist simulation is not delay,
board, sampler or complete ML-DSA validation. No RTL/performance improvement
or new Python-vector run is claimed for Stage 5.

Synthesis-only map has five warnings: three unused inferred-ROM write inputs,
the unused `s_tlast` input and its summary. Fixed 256-coefficient operands are
the interface contract; input framing is not validated by RTL. Netlist runs
retain vendor warnings: 38 post-fit (protected widths/tri0-tri1 port coercions/port widths),
39 synthesis (also `altera_lnsim` sensitivity). Full logs and parsed warning
counts are retained; no warnings were suppressed. Stage 6 integration and
FPGA/UART validation remain pending. Nothing committed.
