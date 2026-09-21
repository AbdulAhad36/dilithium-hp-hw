# Keccak Design and Verification - Post-Midyear Living Report

**Branch:** `keccak_v2` (created from `1_hashing`)  
**Last updated:** 2026-09-17

**Status:** Authoritative post-midyear Keccak progress record

This document records the current design, evidence, accepted checkpoints, and
open work after the midyear evaluation. The earlier AXI design and historical
results remain in
[the pre-midyear report](../pre_midyear/keccak-design-and-verification.md).

## 1. Current Design

- Supports SHAKE128 and SHAKE256 for ML-DSA.
- Uses a protocol-neutral ready/valid interface; AXI is not part of the core or
  verification target. Input is 64 bits. Output is parameterized, with 128 bits
  selected by the active dual-core top and 64 bits retained as the legacy
  single-core default.
- Accepts explicit message and output lengths and supports bounded or
  continuous SHAKE output.
- Executes theta, rho, pi, chi, and iota as one combinational round and commits
  one round on every permutation clock.
- Completes the 24 Keccak-f[1600] rounds in 24 round clocks.
- Uses no DSP blocks and no block RAM.
- Active working-tree integration uses two independent cores, one input elastic
  register per core, a 26-cycle launch offset and one tagged, arbitrated 128-bit
  output stream. The former four-lane wrapper is obsolete for active development.
- The active round datapath uses replicated local Theta parity logic to reduce
  high-fanout routing on Cyclone V.

## 2. Verification Method

The supervisor's three representations are kept separate:

| Stage | Representation | Purpose |
|---|---|---|
| 1 | Source SystemVerilog RTL | Full UVM, assertions, functional coverage, and code coverage |
| 2 | Quartus post-synthesis netlist | Check mapped logic against the same expected SHAKE results |
| 3 | Quartus post-fit netlist | Check the placed/routed representation and sign off static timing |

Coverage is not manipulated to obtain a preferred percentage. Functional
coverage measures planned scenarios; code coverage measures exercised RTL
structure; Stage 2/3 comparison shows agreement for the selected test suite.

## 3. Current Verified Evidence

| Evidence | Result |
|---|---:|
| Stage 1 checked transactions | **888/888 passed** |
| UVM errors / fatals | **0 / 0** |
| Functional coverage | **281/281 bins (100.00%)** |
| Complete lane-0 code coverage | **98.78%** |
| Current Stage 2 comparison | **125/125 source and netlist matched** |
| Current Stage 3 comparison | **125/125 source and fitted netlist matched** |

The 98.78% code result followed removal of unreachable or redundant control
conditions. It is not a fabricated target: remaining misses are principally
constant or difficult toggle cases and a residual condition in the round
datapath. The current one-round RTL passed all three verification stages on
2026-09-14.

## 4. One-Round Baseline

The first accepted one-round build used a 147 MHz constraint, seed 3, virtual
data/control pins, High Performance Effort, physical synthesis, Standard Fit,
and maximum router timing optimization.

| Metric | Preserved-placement baseline |
|---|---:|
| Operating point | 147 MHz |
| Worst setup slack | +0.010 ns |
| Worst hold slack | +0.168 ns |
| ALMs | 4,265 |
| Registers | 1,674 |

This result is preserved for comparison. It depended on root-partition
placement/routing preservation in the project database and is not used as the
clean implementation baseline for new experiments.

## 5. LightHD Challenge Work

### Throughput-first architecture update - 2026-09-13

The temporary two-cycle-per-round pipeline reached 208.46 MHz but required 48
clocks per permutation, reducing single-stream throughput. It was rejected as
the active architecture. The core is again one round per clock and retains the
new direct absorb-to-padding transitions that remove unnecessary control
cycles.

The restored and optimized 24-cycle core passes the complete 888-transaction
source-RTL regression with zero failures. The accepted seed-1 placement signs
off at 142.86 MHz with +0.030 ns worst setup slack, +0.169 ns worst all-corner
hold slack, 3,441 ALMs, and 1,674 registers. Its permutation-only rates are
1.000 GB/s for SHAKE128 and 0.810 GB/s for SHAKE256.

Development order is now: improve one-round throughput with clean timing,
verify and synthesize a two-core 26-cycle-offset benchmark, then maximize Fmax
and reduce area. The detailed numerical gates are maintained in
[KECCAK_LIGHTHD_CHALLENGE_PLAN.md](KECCAK_LIGHTHD_CHALLENGE_PLAN.md).

The current optimization goal is to exceed 212.8 MHz, then reduce the core
below 3,150 ALMs, while preserving one round per clock and positive multicorner
setup/hold slack. The stretch clock target is above 230 MHz.

Changes retained in RTL:

- Folded theta's temporary `D` network directly into the output equations.
- Simplified control predicates whose earlier priority branches already made
  the repeated conditions true.
- Removed the 1,600-bit state register from the asynchronous reset network.
  State is synchronously cleared on every accepted start before it can be used.
- Kept the original state selector after a direct-update experiment proved
  both slower and substantially larger.

Quartus project changes:

- Removed stale root-partition source and placement/routing preservation
  assignments so experiments are clean and reproducible from RTL.
- Kept High Performance Effort, physical synthesis, register duplication and
  retiming, maximum router timing optimization, seed 1, and virtual I/O pins.
- Added a repeatable TimeQuest script reporting 20 multicorner setup and hold
  paths, routing details, Fmax, and unconstrained paths.
- Swept fitter seeds 1, 2, 4, 5, and 1245 after the RTL change. A final
  constraint-directed comparison selected seed 1 because its retained
  placement reached the best timing-closed operating point.

## 6. Experiment Results

| Experiment | Constraint | Fmax | Setup | Worst hold | ALMs | Outcome |
|---|---:|---:|---:|---:|---:|---|
| Preserved baseline | 147 MHz | 147.21 MHz | +0.010 ns | +0.168 ns | 4,265 | Archived baseline |
| State selector removal | 147 MHz | 146.69 MHz | -0.014 ns | Pass | 4,652 | Reverted |
| Clean fit | 147 MHz | 137.53 MHz | -0.468 ns | Pass | 3,429 | Diagnostic |
| Clean target | 180 MHz | 134.63 MHz | -1.872 ns | +0.500 ns | 3,452 | Rejected target |
| Theta fold | 180 MHz | 135.81 MHz | -1.807 ns | +0.492 ns | 3,487 | RTL retained |
| No async state reset | 180 MHz | 137.25 MHz | -1.730 ns | +0.492 ns | 3,435 | RTL retained |
| Clean seed-3 checkpoint | 135 MHz | 137.99 MHz | +0.160 ns | +0.169 ns | 3,466 | Superseded |
| Former clean seed-5 checkpoint | 135 MHz | 142.90 MHz | +0.409 ns | +0.168 ns | 3,431 | Superseded |
| Seed-5 tighter-clock attempt | 140 MHz | 136.48 MHz | -0.184 ns | +0.168 ns | 3,461 | Rejected |
| Seed-1 aggressive attempt | 141.84 MHz | 140.00 MHz | -0.093 ns | +0.168 ns | 3,450 | Rejected |
| **Current seed-1 placement** | **142.86 MHz** | **143.47 MHz worst slow corner** | **+0.030 ns** | **+0.169 ns** | **3,441** | **Timing closed** |

The active checkpoint is fully constrained with zero setup and hold TNS. Its
declared operating frequency is **142.86 MHz**. The 143.47 MHz value is the
lower of the two slow-corner Fmax estimates, not the operating constraint.

The 140 MHz experiment was not retained: 15 setup paths violated timing and
Slow-85 C TNS was -0.873 ns. The active project was restored and fully
recompiled at 135 MHz after archiving that failed result.

At 142.86 MHz, the publication-style permutation-only rates are 1.000 GB/s for
SHAKE128 and 0.810 GB/s for SHAKE256. Including 64-bit input transfers gives
0.533 GB/s and 0.474 GB/s respectively. These are calculated core rates, not
UART or measured board throughput.

## 7. Timing Diagnosis

The current worst path is state register to state register through the round
logic. TimeQuest reports:

- 6.728 ns data delay.
- Five logic levels.
- 2.292 ns cell delay.
- 4.437 ns routing delay, or 66% of data delay.

The round is therefore placement/routing dominated. Additional false paths,
multicycle exceptions, or an unrealistically tight clock would only make the
report misleading. The next architectural experiment must shorten the
physical state feedback path while preserving the real cycle count and SHAKE
behavior.

## 8. Current Standing

- Single-core correctness gate: passing at source RTL, post-synthesis, and post-fit.
- Dual-core source correctness gate: passing directed, throughput and coverage regressions.
- Dual-core setup/hold gate: passing at 148 MHz with zero setup and hold TNS.
- Dual-core throughput gate: passing above 1 GB/s for SHAKE128 and SHAKE256.
- Dual-core functional-coverage gate: passing above 80 percent for both cores and the interleaver.
- LightHD frequency gate: **not passed**; 69.94 MHz remains.
- Dual-core area: 7,581 Cyclone V ALMs; cross-FPGA LUT comparisons remain approximate.
- Stage 2/3 gate for the latest dual RTL: pending. The 125/125 Stage 2/3 result applies to the established single core.
- Hardware/UART test: pending FPGA board details.

## 9. Next Work

1. Move the dual-top self-checking regression and covergroups into a complete
   UVM environment while preserving the current measured bins.
2. Generate the final post-synthesis and post-fit netlists for the dual top and
   run byte-exact Stage 2 and Stage 3 comparisons.
3. Retain the 148 MHz fit as the accepted floor while investigating further
   state-feedback placement or area improvements.
4. Integrate the dual-context downstream consumer only after the three-stage
   dual verification flow is complete.

Detailed targets and acceptance rules are in
[KECCAK_LIGHTHD_CHALLENGE_PLAN.md](KECCAK_LIGHTHD_CHALLENGE_PLAN.md).

## 10. Dual-Core Interleaved Development - 2026-09-16

LightHD was checked against the paper rather than inferred from its headline. It uses two independent iterative Keccak cores with a fixed 26-cycle offset and interleaved SHA-3 outputs. It is not a cascaded two-round datapath. The paper reports 6,019 LUTs, 3,220 FFs and 212.8 MHz for its complete dual-core SHA-3 block on Artix-7; those numbers are not directly comparable to Cyclone V ALMs.

The new `keccak_dual_interleaved` top applies the same scheduling principle to the existing verified cores:

- One shared ready/valid command and 64-bit message-input channel.
- One elastic 64-bit input register per core, decoupling the shared scheduler
  from each 1600-bit state update.
- Round-robin dispatch across exactly two cores.
- At least 26 clocks between accepted core launches.
- Independent execution after input dispatch.
- Parameterized squeeze datapaths configured for a shared 128-bit output.
- One fair tagged output arbiter with backpressure isolation.
- `output_core_o` identifies which SHAKE context produced each word.

Source verification passes mixed SHAKE128/SHAKE256 jobs against the independent
golden model, exact 26-cycle offset checking, input routing, output
interleaving, partial and rate-tail output beats, deterministic output stalls
and simultaneous pending outputs while backpressured. All three dual source
regressions were rerun after the final RTL timing changes.

The expanded coverage regression runs 38 byte-exact jobs across both cores. It
covers both SHAKE modes, empty and unaligned inputs, rate boundaries,
multirate messages, full/partial/rate-tail outputs, exact and delayed launches,
mixed modes, arbitration and no/periodic/burst backpressure.

| Functional-coverage scope | Result |
|---|---:|
| Core 0 | 99.35%, 61/62 bins |
| Core 1 | 99.35%, 61/62 bins |
| Interleaved scheduler/protocol | 90.91%, 31/35 bins |
| Aggregate covergroup metric | 95.12% |

The complete dual regression's structural code coverage is 91.32%. Component
results are 99.66% statements, 99.05% branches, 77.77% conditions, 87.23%
expressions, 100% FSM states, 72.72% FSM transitions and 99.02% toggles. No
coverage exclusions were added to manufacture the total. These dual tests are
self-checking SystemVerilog with functional covergroups; migration into the
full UVM architecture remains open.

Accepted Cyclone V timing-clean checkpoint:

| Metric | Dual interleaved | Single-core reference |
|---|---:|---:|
| Constraint | 147.99 MHz | 142.86 MHz |
| Estimated Fmax | 149.63 MHz | 143.47 MHz |
| Setup slack | +0.074 ns | +0.030 ns |
| Worst hold slack | +0.166 ns | +0.169 ns |
| ALMs | 7,581 | 3,441 |
| Registers | 3,501 | 1,674 |
| DSP / RAM | 0 / 0 | 0 / 0 |

The final fit has zero setup and hold TNS at every analyzed corner. Timing was
recovered after widening the output by removing variable XOF-byte arithmetic
from the feedback decision, using replicated local Theta parity logic and
registering each core's input independently. A follow-up area experiment
reduced the parity replicas from five per core to three. The accepted result
saves 574 ALMs (7.0 percent) and raises the constrained clock by 3 MHz without
changing the interface, cycle counts or SHAKE results. Failed or dominated
intermediate fits are not accepted results.

The long-run benchmark measures from the first accepted command to the final
accepted output beat and verifies every output byte against an independent
model. At the timing-closed 148 MHz operating point it reports:

| Mode | Bytes | Cycles | Actual transfer-inclusive throughput |
|---|---:|---:|---:|
| SHAKE128 | 131,040 | 14,462 | 1.341026 GB/s |
| SHAKE256 | 130,832 | 16,867 | 1.147989 GB/s |

These figures include commands, 64-bit input transfers, setup, all permutation
cycles and 128-bit output transfers with no output stalls. They are sustained
source-simulation core results at a timing-closed clock, not UART/board or
complete ML-DSA throughput.

The throughput, 148 MHz timing and greater-than-80-percent functional-coverage
targets are met. The next gates are full dual-top UVM integration and byte-exact
post-synthesis/post-fit functional comparisons. The authoritative current
interface and limitations are in [SPECIFICATION.md](SPECIFICATION.md).
