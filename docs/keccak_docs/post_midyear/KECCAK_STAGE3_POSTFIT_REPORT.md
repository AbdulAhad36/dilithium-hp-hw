# Keccak Stage 3 Post-Fit Verification Report

Date: 2026-09-12  
Branch: `1_hashing`  
Recorded Git HEAD: `5d386c9291e36e316d4671958e01c60ec27709e8`  
Result: **Post-fit functional comparison and 50 MHz timing gate passed**

## Scope

This is the third design representation in the supervisor's flow. Quartus
fitted one `keccak_core` through the flat-port `keccak_synth_top` benchmark
wrapper for Cyclone V `5CGXFC7C7F23C8`. The 174 data/control ports are virtual
pins; `clk` is the only real package pin. Only UVM lane 0 is driven because
the fitted benchmark contains one core.

This report keeps three claims separate:

- Interface-level functional agreement between source RTL and fitted netlist.
- Static timing closure for the documented 50 MHz module constraint.
- Final resource use for this one-core benchmark.

It does not treat gate-level code coverage as source-RTL design coverage and
does not claim FPGA/UART validation.

## Reproduce

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_stage3.ps1
```

The script hashes all inputs, runs Analysis and Synthesis, Fitter, post-fit
TimeQuest, and the EDA Netlist Writer, then runs the same 125-transaction UVM
suite against source RTL and the fitted functional netlist. It rejects negative
timing slack, incomplete setup/hold constraints, transaction-count differences,
output-record differences, and source changes during the run.

This can also be performed manually in Quartus by opening
`quartus/stage2/keccak_stage2.qpf`, running a full compilation, and then running
the EDA Netlist Writer. The script remains the authoritative reproducible flow
because it compiles the correct Questa libraries, runs both representations,
compares every checked record, and archives the exact inputs and reports.

Validated evidence directory:

```text
sim/stage3_runs/20260912_161304_153
```

Generated reports, netlists, UCDBs, and transcripts remain ignored by Git. The
tracked project and scripts reproduce them.

## Functional Result

| Item | Source RTL | Post-fit netlist |
|---|---:|---:|
| Seed | 20260909 | 20260909 |
| Checked transactions | 125/125 passed | 125/125 passed |
| Failed transactions | 0 | 0 |
| UVM errors/fatals | 0/0 | 0/0 |
| Focused-suite functional bins | 201/281 (71.53%) | 201/281 (71.53%) |

Both complete checked-result files have SHA-256:

```text
726C5025632F6D3C3CD6C68626CBEAC7669590420EC62D96824257F0852BC54C
```

The fitted netlist has SHA-256:

```text
22ECAD1A85B16176029A3FB755B9E41B01EF34B5DB9EB19CC693E10A41D0E6F8
```

Questa's fitted-netlist database also reports 11/32 assertion instances, 5/24
cover directives, and a 42.24% filtered aggregate. Those numbers mainly reflect
the smaller one-lane suite and synthesized primitive hierarchy. They are not
used as source-RTL structural coverage or as an overall verification score.
The meaningful Stage 3 evidence is the 201/281 checked functional bins plus
record-for-record output agreement.

This proves agreement for the selected external behavior, not exhaustive formal
equivalence. The focused suite covers both SHAKE modes, known answers, empty and
non-empty messages, rate and output boundaries, bounded and continuous output,
configuration latching, input/output stalls, stop/recovery, and fixed-seed
random traffic.

## Post-Fit Timing

The SDC defines a 20 ns clock, derives uncertainty, gives synchronous data ports
2 ns input/output budgets, and false-paths only asynchronous reset. TimeQuest
reported the design fully constrained for both setup and hold.

| Corner/check | Slack | Fmax |
|---|---:|---:|
| Slow 1100 mV, 85 C setup | +5.040 ns | 66.84 MHz |
| Slow 1100 mV, 85 C hold | +0.475 ns | - |
| Slow 1100 mV, 0 C setup | +5.037 ns | 66.83 MHz |
| Slow 1100 mV, 0 C hold | +0.256 ns | - |
| Worst hold across all reported corners | +0.169 ns | - |

The 50 MHz requirement passes with positive setup and hold slack. The
conservative quoted Fmax for this interface-constrained Auto Fit project is
**66.83 MHz**, the lower slow-corner result.
TimeQuest static timing is the timing authority; no SDF timing simulation was
claimed.

## Final Resources

| Resource | Fitted result |
|---|---:|
| ALMs | 3,903 / 56,480 (7%) |
| Registers | 1,979 |
| Virtual pins | 174 |
| Real pins | 1 (`clk`) |
| DSP blocks | 0 / 156 |
| Block memory bits | 0 / 7,024,640 |

The Fitter completed with 0 errors and three understood benchmark-flow
warnings: LogicLock requires a subscription, board I/O assignments are
incomplete, and the clock has no board-specific pin location. A real board
project must replace the last two conditions with the board oscillator pin and
I/O standard; they are not waived for FPGA sign-off.

## Relationship to the Performance Build

This Stage 3 project is the implementation-verification flow: it uses a flat
wrapper, explicit 2 ns input/output budgets, and Quartus Lite Auto Fit. It is
not the project's maximum-Fmax measurement.

A separate direct-core project now targets 6.803 ns with High Performance
Effort, Standard Fit, maximum router timing optimization, and fitter seed 3.
The active one-round-per-clock architecture closes **147 MHz**, with +0.010 ns
worst setup and +0.168 ns worst hold slack across all corners. See
[KECCAK_TIMING_OPTIMIZATION_REPORT.md](KECCAK_TIMING_OPTIMIZATION_REPORT.md).

The two projects answer different questions. This report proves the current
fitted netlist matches source behavior and closes its 50 MHz interface timing
contract. The performance project measures internal core Fmax while excluding
board I/O timing. Neither is a substitute for board-specific timing sign-off.

The focused source-RTL reference, post-synthesis netlist, and post-fit netlist
all reach 201/281 functional bins (71.53%). This equality is normal because the
same accepted transactions are sampled at each representation. It does not mean
that source code coverage is meaningful or directly comparable in a generated
gate-level netlist.

## Closure

`K-IMP-002` passes because source RTL and the fitted netlist produced
identical checked records for all 125 transactions. `K-IMP-003` passes for
this module benchmark because setup and hold are fully constrained and have
positive slack at every analyzed corner. This raises implementation/hardware
P1 closure to 4/6 and all planned P1 closure to 18/50 (36.00%).

The one-core Stage 3 gate is complete for the current timing-optimized RTL.
Still open are the N-lane implementation comparison, remaining Stage 1
requirement holes, the supervisor's decision on optional SDF simulation, and
FPGA/UART validation.
