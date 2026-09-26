# Keccak LightHD Challenge Plan

**Status reviewed 2026-09-27:** The numerical baseline below is the older
standalone-core checkpoint. The dual-core architecture has since been
implemented: its last recorded fit is 7,581 ALMs, timing-clean at 148 MHz,
with 149.63 MHz reported by TimeQuest. Its source-simulation throughput is
1.341026 GB/s for SHAKE128 and 1.147989 GB/s for SHAKE256 across two jobs.
The 212.8 MHz target and dual-core netlist simulations remain open.
See [the living report](keccak-design-and-verification.md).

## Throughput-First Correction - 2026-09-14

Throughput is now the first acceptance gate. A two-cycle round pipeline raised
Fmax but reduced a permutation to 48 clocks, so it is retained only as an
archived experiment and is not the active architecture.

The active RTL performs one complete Keccak round per clock while retaining
the direct absorb-to-padding FSM optimization. The full source-RTL regression
passes 888/888 transactions with zero UVM errors or fatals. The current seed-1
placement signs off at 142.86 MHz with +0.030 ns worst setup slack, +0.169 ns
worst all-corner hold slack, 3,441 ALMs, and 1,674 registers.

Current single-core throughput calculated from the post-fit Fmax is:

| Metric | SHAKE128 | SHAKE256 |
|---|---:|---:|
| Permutation throughput, 24 clocks | 1.000 GB/s | 0.810 GB/s |
| Long-stream transfer-inclusive estimate | 0.533 GB/s | 0.474 GB/s |

The next acceptance sequence is:

1. Raise the one-round core above 157.15 MHz for at least 1.10 GB/s SHAKE128
   permutation throughput, without setup or hold violations.
2. Raise it above 194.12 MHz for at least 1.10 GB/s SHAKE256 permutation
   throughput.
3. Approach 212.8 MHz for 1.490 GB/s SHAKE128 and 1.206 GB/s SHAKE256.
4. Synthesize a dedicated two-core `N_LANES=2` benchmark and verify independent
   jobs launched 26 clocks apart. Report aggregate throughput and total area;
   do not present doubled single-core arithmetic as a measured result.
5. Pursue maximum Fmax and area reduction only after the throughput gates are
   met with positive multicorner setup and hold slack.

LightHD RTL is not publicly available in the evidence currently held by this
project. Its published high-level idea may be independently reproduced, but no
claim will be made that proprietary source RTL was copied.

## Summary

Optimize the existing Cyclone V SHAKE128/SHAKE256 core while preserving one
round per clock. Development is staged: first close timing above LightHD's
212.8 MHz without uncontrolled area growth, then reduce the accepted
implementation below 3,150 ALMs, attempt 230 MHz, and finally benchmark two
staggered cores.

The comparison remains Cyclone V-only. LightHD's Artix-7 numbers are
directional references, not proof of area superiority across FPGA families.

| Metric | Baseline | Required | Stretch |
|---|---:|---:|---:|
| Single-core frequency | 142.86 MHz | **>212.8 MHz** | **>230 MHz** |
| ALMs/core | 3,441 | **<3,150** | **<3,000** |
| Permutation latency | 24 clocks | **24 clocks** | 24 clocks |
| Setup slack | +0.030 ns | **>=+0.100 ns** | >=+0.100 ns |
| Hold slack | +0.169 ns | **>=+0.100 ns** | >=+0.100 ns |
| SHAKE128 permutation throughput | 1.000 GB/s | **>1.490 GB/s** | >1.610 GB/s at 230 MHz |
| SHAKE256 permutation throughput | 0.810 GB/s | **>1.206 GB/s** | >1.303 GB/s at 230 MHz |

## Execution Status - 2026-09-14

The first optimization pass is complete, but the LightHD gate has **not**
passed. The active result is a clean, timing-closed checkpoint for continued
work, not a claim that the final target has been reached.

| Experiment | Constraint | Reported Fmax | Setup slack | ALMs | Decision |
|---|---:|---:|---:|---:|---|
| Preserved-placement baseline, seed 3 | 147 MHz | 147.21 MHz | +0.010 ns | 4,265 | Historical baseline archived |
| Simplified state selector | 147 MHz | 146.69 MHz | -0.014 ns | 4,652 | Rejected: slower and larger |
| Clean fit without stale root-partition preservation | 147 MHz | 137.53 MHz | -0.468 ns | 3,429 | Retained as diagnostic evidence |
| Clean fit, unchanged RTL | 180 MHz | 134.63 MHz | -1.872 ns | 3,452 | Rejected operating point |
| Theta delta folded into lane equations | 180 MHz | 135.81 MHz | -1.807 ns | 3,487 | RTL retained after verification |
| State removed from asynchronous reset network | 180 MHz | 137.25 MHz | -1.730 ns | 3,435 | RTL retained after verification |
| Clean seed-3 checkpoint | 135 MHz | 137.99 MHz | +0.160 ns | 3,466 | Superseded by seed 5 |
| Former clean seed-5 checkpoint | 135 MHz | 142.90 MHz | +0.409 ns | 3,431 | Superseded |
| Seed-5 tighter-clock attempt | 140 MHz | 136.48 MHz | -0.184 ns | 3,461 | Rejected: 15 setup paths violated |
| Seed-1 aggressive attempt | 141.84 MHz | 140.00 MHz | -0.093 ns | 3,450 | Rejected: setup violation |
| **Current seed-1 placement** | **142.86 MHz** | **143.47 MHz worst slow corner** | **+0.030 ns** | **3,441** | **Accepted; timing closed** |

Current checkpoint details:

- Worst hold slack across all corners is **+0.169 ns**; setup and hold are
  fully constrained with zero TNS.
- The design remains one round per clock and uses 1,674 registers, zero DSPs,
  and zero block RAMs.
- Stage 1 passes 888/888 checked transactions with zero UVM errors/fatals,
  281/281 functional bins, and **98.78%** complete lane-0 code coverage.
- Folding theta's temporary `D` net and simplifying logically redundant
  control conditions improved the synthesized structure without changing
  SHAKE behavior.
- The 1,600-bit state register no longer uses asynchronous reset. Every
  accepted `start_i` synchronously clears it before use; the complete
  reset-heavy regression confirms reset recovery and output behavior.
- A controlled placement sweep covered seeds 1, 2, 4, 5, and an accidental
  but valid seed 1245. Final constraint-directed fits selected seed 1 because
  its retained placement closed the highest operating clock.
- Raising the same project to 140 MHz changed placement and produced -0.184 ns
  setup slack and -0.873 ns TNS. That result remains rejected.
- The current worst detailed state-to-state path has five logic levels and
  6.728 ns of data delay. Routing contributes 4.437 ns, or 66%, so the next attempt must
  address placement/state feedback rather than merely add constraints.
- The current checkpoint is **69.94 MHz below** LightHD's 212.8 MHz reference
  and **291 ALMs above** the 3,150-ALM gate. Both challenge goals remain open.

Final reproduced evidence is archived under
`quartus/performance/experiments/one_round_142_86_seed1_closed_20260914`.
The first seed-5 run, rejected 140 MHz run, and intermediate experiments are
retained beside it.

## Implementation

### 1. Establish reproducible evidence

- Preserve the accepted 147 MHz reports and record RTL hashes, area, latency,
  coverage, and all-corner slack.
- Add a TimeQuest reporting script for the 20 worst setup and hold paths,
  including logic versus routing delay, fan-out, source, destination, and
  intermediate cells.
- Remove the unsupported Tan comparison from active documentation and use
  verified LightHD and ML-DSA-OSH data only.

### 2. Optimize the combinational round

- Keep the public interfaces of `keccak_core` and `keccak_step_unit`
  unchanged.
- Flatten the internal 1,600-bit round representation while retaining
  verification-visible step outputs.
- Fuse rho and pi into one compile-time wiring permutation.
- Express theta parity as balanced XOR trees.
- Express chi as five explicit 64-bit row equations suitable for ALM packing.
- Replace sparse variable-index iota lookup with a static 64-bit round-constant
  case table.
- Test each transformation independently and retain only Pareto-improving
  candidates.

### 3. Shorten state feedback and control

- Replace the generic state-input selector with explicit sequential updates
  for initialize, absorb, padding, and permutation.
- Ensure the permutation path is directly
  `state register -> round logic -> state register`.
- Remove unnecessary enables and control fan-out from the 1,600 state bits.
- Keep absorb, squeeze, mode selection, message length, and output semantics
  unchanged.

### 4. Close timing incrementally

- Compile accepted RTL at 160, 180, 190, 200, 212.8, and 230 MHz.
- Permit at most 5% temporary ALM growth during timing exploration.
- Use physical synthesis and seed sweeps only after RTL optimization.
- Sweep seeds 1-30 for shortlisted candidates; select by worst-corner slack
  first, then ALMs and registers.
- Reject multicycle exceptions, internal false paths, unconstrained paths,
  negative slack, and seed-only results that cannot be reproduced.

### 5. Reduce area after the timing plateau

- Preserve the best timing-closed architecture while removing duplicated
  expressions, redundant intermediate nets, and control muxing.
- Compare Quartus hierarchy and resource reports after every area change.
- Final single-core success requires all metrics simultaneously: above
  212.8 MHz, below 3,150 ALMs, one round per clock, and the required slack
  margins.
- Attempt 230 MHz only after the LightHD gate passes. If 230 MHz fails, retain
  the highest lower frequency satisfying every gate.

## Dual-Stream Phase

- After the single-core experiments reach their best stable point, instantiate
  the existing parallel engine with `N_LANES=2` in a dedicated benchmark top.
- Keep two independent protocol-neutral ready/valid interfaces; do not add AXI
  or a production scheduler.
- Launch lane 1 exactly 26 clocks after lane 0 for the LightHD-style benchmark.
- Exercise equal and unequal SHAKE128/SHAKE256 jobs, independent stalls,
  resets, stop requests, and continuous streams.
- Report single-stream latency, aggregate sustained throughput, total ALMs,
  per-instance resources, and multicorner Fmax.
- Dual target: each core below 3,150 ALMs, wrapper overhead below 100 ALMs,
  total below 6,400 ALMs, and no reduction in single-core Fmax.
- Describe results as a Cyclone V numerical comparison; do not claim direct
  LUT/ALM superiority over LightHD.

## Verification and Acceptance

- Run a focused source regression after every experimental RTL change.
- Before retaining any candidate, run the complete Stage 1 regression:
  888/888 transactions, zero UVM errors/fatals, 281/281 functional bins, and
  at least 96.74% complete lane-0 code coverage.
- Require correct SHAKE128 and SHAKE256 operation for empty, partial-word,
  exact-rate, multiblock, fixed-output, continuous-output, backpressure, stop,
  and reset cases.
- Run the independent five-step round checker for all 24 rounds.
- For milestone and final candidates, run Stage 2 post-synthesis and Stage 3
  post-fit comparison, requiring 125/125 matching observations at each
  representation.
- Require zero unexplained synthesis warnings, zero setup/hold violations,
  zero unconstrained internal paths, zero DSPs, and zero RAM.
- Recalculate throughput from the accepted post-fit clock and measured cycle
  counts; never substitute requested frequency for achieved frequency.
- Archive reports for every accepted or rejected experiment and document why
  each candidate was retained or reverted.

## Assumptions

- Quartus Prime Lite 25.1 and Cyclone V `5CGXFC7C7F23C8` remain the official
  tool and target.
- QuestaSim remains fixed at `C:\\questasim64_2024.1\\win64`.
- Virtual pins remain limited to benchmark I/O; internal timing paths stay
  constrained.
- No worktrees, commits, or pushes are created without explicit instruction.
- Existing uncommitted user changes are not reverted or overwritten.
- If the physical architecture cannot satisfy all targets, the documented
  outcome is the genuine Pareto frontier rather than altered constraints or
  misleading performance claims.
