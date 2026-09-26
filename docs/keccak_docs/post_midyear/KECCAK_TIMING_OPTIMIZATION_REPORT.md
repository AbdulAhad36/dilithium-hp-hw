# Keccak Timing Optimization Report

Date: 2026-09-14  
Branch: `keccak_v2`  
Recorded Git HEAD: `5d386c9291e36e316d4671958e01c60ec27709e8` plus documented local changes  
Device: Cyclone V `5CGXFC7C7F23C8`  
Result: **one round per clock at a timing-closed 142.86 MHz operating point**

**Archive status (2026-09-27):** This is the last separately fitted
one-core benchmark. The active synthesis top is `keccak_dual_interleaved`;
its last recorded fit uses 7,581 ALMs and closes the 148 MHz constraint.
See [SPECIFICATION.md](SPECIFICATION.md) for the active architecture.

## Scope

This report measures one `keccak_core` as an internal FPGA block. It is separate
from the 50 MHz Stage 3 interface-verification project. The dedicated project is
in `quartus/performance/` and now uses a 7.000 ns clock, virtual data/control
pins, High Performance Effort, Standard Fit, maximum router timing
optimization, and fitter seed 1.

Top-level data and control I/O paths are intentionally false-pathed because no
board pinout or surrounding registered shell exists yet. All internal
register-to-register setup and hold paths are timed. Asynchronous reset is also
false-pathed. TimeQuest reports the analyzed setup and hold domains fully
constrained. This is therefore a core-internal timing benchmark, not board-level
timing sign-off.

The 186.92 MHz normal-build and 198.57 MHz performance-build figures below are
retained as the final record of the superseded two-clock-per-round architecture.
They must not be presented as Fmax results for the active one-round design.

## Current One-Round Result

The mid-round 1,600-bit register was removed. Theta, rho, pi, chi, and iota now
form one combinational round path, and `keccak_core` commits the resulting state
and increments the round index on every permutation clock. A Keccak-f[1600]
permutation therefore takes 24 round clocks instead of 48.

After the initial seed sweep, the optimized Theta/reset RTL was fitted with
seeds 1 and 5 near its real timing limit. A seed-1 141.84 MHz attempt missed
setup by 0.093 ns, and a seed-5 140 MHz attempt missed by 0.184 ns. A complete
seed-1 fit at 139.66 MHz produced a placement whose fitted netlist then passed
TimeQuest at the final 142.86 MHz operating constraint:

| Corner/check | Final result |
|---|---:|
| Slow 1100 mV, 85 C setup | **+0.047 ns** |
| Slow 1100 mV, 0 C setup | **+0.030 ns** |
| Worst hold across all corners | **+0.169 ns** |
| Slow 85 C reported Fmax | 143.82 MHz |
| Slow 0 C reported Fmax | 143.47 MHz |

TimeQuest reports the design fully constrained for setup and hold. The
accepted claim is **142.86 MHz with no setup or hold violation**, not the
143.47 MHz estimate and not 200 MHz. The 30 ps worst setup margin is valid but tight, so board-specific
integration must be timed again after the clock pin, I/O standards, and wrapper
are known.

| Resource | Current one-round fit | Final two-clock fit | Change |
|---|---:|---:|---:|
| ALMs | **3,441** | 3,460 | -19 (-0.5%) |
| Registers | **1,674** | 3,315 | -1,641 (-49.5%) |
| DSP blocks | 0 | 0 | 0 |
| Block memory bits | 0 | 0 | 0 |

At 142.86 MHz, publication-style permutation throughput is 1.000 GB/s for
SHAKE128 and 0.810 GB/s for SHAKE256. Including one 64-bit input transfer per
clock gives 0.533 GB/s and 0.474 GB/s respectively. These are calculated
core-level rates, not measured FPGA/UART throughput.

## Reproduce

From `quartus/performance/`:

```powershell
& 'F:/altera/quartus/bin64/quartus_sh.exe' --flow compile keccak_performance
& 'F:/altera/quartus/bin64/quartus_sta.exe' -t report_critical_paths.tcl
```

The final timing summaries are generated under
`quartus/performance/output_files/`. Generated Quartus output is ignored by Git;
the QPF, QSF, SDC, and reporting Tcl file are the reproducible project inputs.

## Historical Two-Clock Optimization Record

- Replaced the output total-count feedback path with a registered remaining-byte
  count. Final-output detection is now a small compare against one 8-byte word.
- Registered input word metadata: byte count, byte-enable mask, and final-word
  status. This removed length decode from the absorb write path.
- Added a registered absorb-block-full flag and direct constant-width counter
  increments.
- Removed the 1600-bit operand-isolation mux in front of the Keccak round
  pipeline. It created a high-fanout timing path and was not required for
  functional correctness.
- Removed dead arithmetic and control signals exposed by the timing cleanup.

These changes do not alter the external ready/valid interface or SHAKE result.
They were accepted only after source RTL, post-synthesis, and post-fit checking.

### Physical synthesis in this build

The performance QSF enables combinational physical synthesis, register
duplication, and register retiming. Unlike RTL synthesis alone, these steps can
use placement and routing information to restructure equivalent combinational
logic, copy a high-fanout register closer to its loads, or move eligible
register boundaries while preserving behavior. Physical synthesis is one part
of the measured 11.65 MHz normal-to-performance gain, together with High
Performance Effort, maximum router timing optimization, seed 12, virtual-pin
treatment, and the resulting placement/routing. No isolated physical-synthesis
or virtual-pin A/B result is claimed.

## Timing Progression

| Checkpoint | Worst slow setup slack at 5 ns | Approximate result |
|---|---:|---:|
| Initial honest 200 MHz baseline | -7.199 ns | about 82 MHz |
| Output remaining-count redesign | -2.644 ns | about 131 MHz |
| Registered input metadata/counter cleanup | -0.673 ns | about 176 MHz |
| Final RTL, fitter seed 1 | -0.831 ns | about 171 MHz |
| Final RTL, fitter seed 2 | -0.197 ns | 192.42 MHz |
| Final RTL, fitter seed 10 milestone | -0.132 ns | 194.86 MHz |
| Final RTL, selected fitter seed 12 | **-0.036 ns** | **198.57 MHz** |
| Rejected `MAX_FANOUT=64` experiment | -0.463 ns | about 183 MHz |
| Rejected forced-global state clock-enable experiment | -3.612 ns | about 116 MHz |
| Rejected absorb/padding XOR refactor | -1.527 ns | about 153 MHz |
| Rejected temporary-pipeline reset removal | -0.215 ns | 191.75 MHz |
| Rejected one-hot absorb-lane pointer | -0.342 ns | about 187 MHz |

The seed sweep was necessary because the remaining paths are dominated by
placement and routing. Results for seeds 1 through 5 were:

| Seed | Slow 85 C setup slack | Slow 0 C setup slack |
|---:|---:|---:|
| 1 | -0.815 ns | -0.831 ns |
| 2 | **-0.174 ns** | **-0.197 ns** |
| 3 | -0.473 ns | -0.427 ns |
| 4 | -0.611 ns | -0.478 ns |
| 5 | -0.585 ns | -0.586 ns |

The second sweep covered seeds 6 through 10:

| Seed | ALMs | Slow 85 C setup slack | Slow 0 C setup slack |
|---:|---:|---:|---:|
| 6 | 3,460 | -0.404 ns | -0.359 ns |
| 7 | 3,445 | -0.524 ns | -0.555 ns |
| 8 | 3,457 | -0.674 ns | -0.875 ns |
| 9 | 3,454 | -0.481 ns | -0.522 ns |
| 10 | 3,452 | **-0.039 ns** | **-0.132 ns** |

The extended sweep covered seeds 11 through 30. Seed 12 was the only result
within 40 ps of closure at both slow corners:

| Seed | ALMs | Slow 85 C setup slack | Slow 0 C setup slack |
|---:|---:|---:|---:|
| 11 | 3,457 | -0.439 ns | -0.567 ns |
| 12 | 3,460 | **-0.027 ns** | **-0.036 ns** |
| 13 | 3,452 | -0.367 ns | -0.347 ns |
| 14 | 3,452 | -0.580 ns | -0.809 ns |
| 15 | 3,460 | -0.365 ns | -0.598 ns |
| 16 | 3,448 | -0.168 ns | -0.220 ns |
| 17 | 3,448 | -0.119 ns | -0.145 ns |
| 18 | 3,459 | -0.658 ns | -0.684 ns |
| 19 | 3,451 | -0.467 ns | -0.293 ns |
| 20 | 3,455 | -0.144 ns | -0.358 ns |
| 21 | 3,458 | -0.297 ns | -0.291 ns |
| 22 | 3,449 | -0.354 ns | -0.557 ns |
| 23 | 3,457 | -0.378 ns | -0.483 ns |
| 24 | 3,452 | -0.283 ns | -0.246 ns |
| 25 | 3,459 | -0.370 ns | -0.514 ns |
| 26 | 3,452 | -0.321 ns | -0.185 ns |
| 27 | 3,452 | -0.414 ns | -0.442 ns |
| 28 | 3,445 | -0.228 ns | -0.198 ns |
| 29 | 3,452 | -0.445 ns | -0.449 ns |
| 30 | 3,458 | -0.311 ns | -0.416 ns |

Seed 12 is fixed in `keccak_performance.qsf`; the result was reproduced by a
fresh full compile and is not an unrecorded command-line override. The sweep is
reproducible with `quartus/performance/sweep_fitter_seeds.ps1`.

A targeted maximum-fanout assignment on `STATE_SUFFIX_PADDING` was also tested.
Quartus inserted two replication cells, but worst slow-corner slack regressed
from -0.197 ns to -0.463 ns. The assignment was removed and a clean seed-2 full
compile restored the 3,451-ALM, -0.197 ns baseline. This rejected experiment is
not part of the final configuration.

The synthesized 1,600-fanout state-register clock enable was also tested on a
dedicated global clock network. Quartus accepted the assignment, but slow-corner
setup slack regressed to -3.612 ns at 85 C and -3.523 ns at 0 C. The assignment
was removed immediately. A complete seed-2 recompile restored 3,451 ALMs,
3,320 registers, and the original -0.174/-0.197 ns slow-corner slacks. Therefore
the final project leaves this enable on ordinary routing.

An RTL refactor of the absorb/padding XOR plane was tested after the seed-2
baseline. It always formed the absorb mapping, gated the 64-bit input mask, and
overlaid padding lanes. The change remained functionally correct in the full
888-transaction source regression, but synthesis grew from 5,267 to 6,870
logic cells and slow-corner setup regressed to -1.360/-1.527 ns, about 153 MHz.
It was therefore rejected and reverted. A clean baseline build was restored
before the extended seed sweep.

Two additional targeted RTL experiments were also rejected:

- Removing asynchronous reset from the 1,600-bit temporary permutation
  pipeline register passed all 888 source checks and reduced the reset fanout
  by 1,600 loads. It saved one ALM and 16 fitted registers, but reduced the
  worst-corner Fmax to 191.75 MHz, so the reset was restored.
- Replacing the binary absorb-lane decoder with a registered one-hot pointer
  also passed all 888 source checks. It increased synthesis from 5,267 to
  5,383 logic cells and worsened setup slack to -0.342/-0.237 ns, so it was
  reverted.

## Historical Two-Clock Final Timing

| Corner/check | Slack | Quartus Fmax |
|---|---:|---:|
| Slow 1100 mV, 85 C setup | -0.027 ns | 198.93 MHz |
| Slow 1100 mV, 0 C setup | -0.036 ns | 198.57 MHz |
| Slow 1100 mV, 85 C hold | +0.445 ns | - |
| Slow 1100 mV, 0 C hold | +0.429 ns | - |
| Worst hold across all reported corners | +0.168 ns | - |

At exactly 200 MHz, setup timing is not closed: the maximum miss is 36 ps and
slow-corner TNS is -0.081 ns at 85 C and -0.082 ns at 0 C. Hold timing is clean
at every reported corner. The conservative claim is therefore **198.57 MHz**,
not 200 MHz. Running at or below that reported Fmax removes the 5 ns setup
violation; an actual board build still needs board-specific clock and I/O
constraints.

The final slow-corner critical paths remain state-update control and
bookkeeping paths into the 1,600-bit state register. They are routing-dominated
rather than a deep Keccak round-logic chain. The remaining gap is small, and
the attempted absorb/padding redesign made it substantially worse, so that
larger architectural change is not accepted for the current near-200 MHz goal.

## Historical Two-Clock Resources

| Resource | Final performance fit |
|---|---:|
| ALMs | 3,460 / 56,480 (6%) |
| Registers | 3,315 |
| DSP blocks | 0 / 156 |
| Block memory bits | 0 / 7,024,640 |
| Real pins | 1 (`clk`) |
| Virtual pins | 174 |

Compared with the historical pre-midyear 84.31 MHz, this build is about 2.35
times faster in reported Fmax and uses fewer ALMs than the historical 3,738-ALM
fit. The comparison is directional rather than board sign-off because the
project constraints and RTL interface have changed.

## Verification After One-Round Optimization

- Full source-RTL UVM regression: 888/888 passed, 281/281 functional bins,
  98.78% complete lane-0 RTL code coverage, zero UVM errors, and zero UVM
  fatals.
- Stage 2 current-RTL comparison: 125/125 source transactions and 125/125
  post-synthesis transactions passed with identical checked-record SHA-256
  `726C5025632F6D3C3CD6C68626CBEAC7669590420EC62D96824257F0852BC54C`.
- Stage 2 evidence: `sim/stage2_runs/20260914_220435_361`.
- Stage 3 current-RTL comparison: 125/125 source transactions and 125/125
  post-fit transactions passed with the same checked-record SHA-256.
- Stage 3 evidence: `sim/stage3_runs/20260914_220642_785`.

The next implementation step is board-specific integration and timing once the
supervisor provides the FPGA board and oscillator/pin information. Any further
Fmax attempt must optimize the full-round state-to-state path and repeat all
three verification stages; constraints alone cannot create genuine timing
margin.
