# Keccak Stage 2 Synthesis and Post-Synthesis Verification Report

Date: 2026-09-12  
Branch: `1_hashing`  
Recorded Git HEAD: `5d386c9291e36e316d4671958e01c60ec27709e8`  
Result: **Stage 2 functional comparison and mapping audit passed**

**Archive status (2026-09-27):** The 125/125 comparison is for the older
one-core `keccak_synth_top` benchmark. Active dual-core post-synthesis
netlist simulation remains pending.

## Purpose and Scope

This report records the second representation in the supervisor's verification
flow: Quartus's post-synthesis functional netlist. It does not combine source
RTL coverage, post-synthesis equivalence, timing, or post-fit verification into
one percentage.

The benchmark synthesizes one `keccak_core` through the flat-port
`keccak_synth_top` wrapper. Only UVM lane 0 is driven because the synthesized
benchmark contains one core. The target is Cyclone V `5CGXFC7C7F23C8`.

`keccak_stage2.qpf` is intentionally separate from `quartus/keccak.qpf` and
`quartus/performance/keccak_performance.qpf`. It owns the stable synthesis
wrapper, virtual-pin policy, EDA Netlist Writer settings, and generated-netlist
evidence used by both Stage 2 and Stage 3. This prevents verification settings
and outputs from being confused with the normal and maximum-Fmax projects.

## Reproducible Flow

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_stage2.ps1
```

The script performs these steps in order:

1. Hashes every RTL, testbench, script, and Quartus project input.
2. Runs Quartus Analysis and Synthesis.
3. Runs the EDA Netlist Writer to generate the technology-mapped Verilog model.
4. Runs post-map TimeQuest with the project constraints.
5. Runs the focused UVM suite against source RTL.
6. Runs the same suite and seed against the generated netlist.
7. Requires 125 successful checked transactions in each run and compares the
   complete checked-result files by SHA-256.
8. Re-hashes all inputs to reject a run whose sources changed during execution.

Generated evidence is stored under a timestamped directory in
`sim/stage2_runs/`. The validated one-round run for this report is
`20260912_161053_163`. Generated netlists, UCDBs, logs, and reports are ignored
by Git; the scripts and project definition are the reproducible tracked assets.

## Functional Result

| Item | Source RTL | Post-synthesis netlist |
|---|---:|---:|
| Seed | 20260909 | 20260909 |
| Checked transactions | 125/125 passed | 125/125 passed |
| Failed transactions | 0 | 0 |
| UVM errors | 0 | 0 |
| UVM fatals | 0 | 0 |
| Functional coverage | 201/281 bins (71.53%) | 201/281 bins (71.53%) |

Both checked-result files have SHA-256:

```text
726C5025632F6D3C3CD6C68626CBEAC7669590420EC62D96824257F0852BC54C
```

The generated technology-mapped netlist has SHA-256:

```text
DF85047139E3DD75F1223B966F1D45501408429C52A3752A1FABD48D1F30D6C1
```

The fixed suite includes directed known-answer work, SHAKE128 and SHAKE256,
empty and non-empty messages, exact rate boundaries, bounded and continuous
output, backpressure/protocol stress, configuration latching, stop and
recovery, and fixed-seed random transactions.

This result proves external functional agreement for those 125 transactions.
It does not prove exhaustive equivalence. Internal phase/FSM observation is a
Stage 1 mechanism and is intentionally absent from the technology-mapped run.

## Synthesis Result

| Item | Result |
|---|---:|
| Quartus Analysis and Synthesis | Success |
| Errors | 0 |
| Synthesis warnings | 0 |
| Estimated ALMs | 3,968 |
| Logic cells | 5,958 |
| Registers | 1,673 |
| DSP blocks | 0 |
| Block memory bits | 0 |
| Real pins | 1 (`clk`) |
| Virtual pins | 174 |
| Removed registers | 2, reviewed |

Virtual pins prevent the wide verification interface from being mistaken for
a board-level pinout and allow the internal core to be benchmarked without an
artificial external-I/O limit. The ALM number is an Analysis and Synthesis
estimate, not a final Fitter utilization result.

The initial baseline had 15 synthesis warnings and 44 removed registers.
Explicit enum and constant widths, exact index slices, and removal of the unused
`rate_bytes` object eliminated those warnings. The one-round change removed the
1,600-bit mid-round register, reducing mapped registers from 3,274 to 1,673.
Quartus reports only two registers losing all fanout in the final map; both are
dead generated/control nodes and have no externally observable behavior.

The cleaned report contains no synthesis warning for truncation, latches,
ignored functional inputs, or unintended memory/DSP inference. This closes
`K-IMP-004`.

## Constraints and Timing

The SDC creates a 20 ns (50 MHz) clock, derives clock uncertainty, assigns 2 ns
input/output delays relative to that clock, and false-paths only asynchronous
reset. Current post-map TimeQuest reports:

| Item | Result |
|---|---:|
| Unconstrained clocks | 0 |
| Unconstrained input ports/paths | 0/0 |
| Unconstrained output ports/paths | 0/0 |
| Slow 85 C setup slack | +1.974 ns |
| Slow 0 C setup slack | +1.757 ns |
| Worst pre-fit hold estimate | -6.113 ns |
| 50 MHz setup requirement | Met in post-map estimate |

This analysis is pre-fit. Placement and routing have not occurred, so its
negative hold estimate is not a timing failure to sign off or optimize against.
The fitted design has positive setup and hold slack at 50 MHz. The separate
6.803 ns performance project closes a 147 MHz one-round operating point; see
[KECCAK_TIMING_OPTIMIZATION_REPORT.md](KECCAK_TIMING_OPTIMIZATION_REPORT.md).

## Coverage Interpretation

The Stage 2 suite reports 71.53% functional coverage because it is deliberately
smaller than the full Stage 1 four-lane regression. The number is not adjusted
to look realistic and is not compared as though it were a replacement for the
Stage 1 result. Gate-level code/toggle coverage is also not used to claim source
RTL structural closure because technology primitives and synthesized hierarchy
dominate that database.

For the focused one-lane suite, the Stage 1 source-RTL reference and Stage 2
post-synthesis run both hit 201/281 bins (71.53%). Equal coverage is expected:
the same 125 transactions, seed, monitor, checker, and covergroup are used, and
only the DUT representation changes. This is test-based functional comparison,
not exhaustive formal equivalence.

## Status and Next Gate

`K-IMP-001` passes: source RTL and the post-synthesis netlist match at the
checked external interface for the fixed Stage 2 suite.

`K-IMP-004` also passes: synthesis is warning-free and every removed register
has a documented optimization cause. The Stage 2 functional/mapping gate is
therefore complete.

Stage 3 was refreshed for the current RTL on 2026-09-12. The fitted netlist passed the
same 125-transaction comparison and the fully constrained 50 MHz TimeQuest
target passed. See
[KECCAK_STAGE3_POSTFIT_REPORT.md](KECCAK_STAGE3_POSTFIT_REPORT.md). The remaining
scope question is whether the supervisor also requires SDF timing simulation.
