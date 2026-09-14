# Keccak Design and Verification - Post-Midyear Living Report

**Branch:** `keccak_v2` (created from `1_hashing`)  
**Last updated:** 2026-09-14  
**Status:** Authoritative post-midyear Keccak progress record

This document records the current design, evidence, accepted checkpoints, and
open work after the midyear evaluation. The earlier AXI design and historical
results remain in
[the pre-midyear report](../pre_midyear/keccak-design-and-verification.md).

## 1. Current Design

- Supports SHAKE128 and SHAKE256 for ML-DSA.
- Uses a protocol-neutral 64-bit ready/valid interface; AXI is not part of the
  core or UVM verification target.
- Accepts explicit message and output lengths and supports bounded or
  continuous SHAKE output.
- Executes theta, rho, pi, chi, and iota as one combinational round and commits
  one round on every permutation clock.
- Completes the 24 Keccak-f[1600] rounds in 24 round clocks.
- Uses no DSP blocks and no block RAM.

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

- Correctness gate: passing at source RTL, post-synthesis, and post-fit.
- Setup/hold gate: passing at the 142.86 MHz clean checkpoint.
- LightHD frequency gate: **not passed**; 69.94 MHz remains.
- Area gate: **not passed**; current fit is 291 ALMs above 3,150.
- Stage 2/3 gate for the latest RTL: passed 125/125 at both stages.
- Hardware/UART test: pending FPGA board details.

## 9. Next Work

1. Prototype a state-feedback/placement change targeted at the 83% routing
   component, without relaxing any internal timing path.
2. Run the complete 888-transaction Stage 1 regression for each RTL candidate.
3. Retain only candidates that improve the timing/area frontier and preserve
   at least the current verification result.
4. Sweep fitter seeds only after a real RTL or placement improvement exists.
5. Run Stage 2 and Stage 3 on the final retained candidate.
6. Begin dual-stream work only after the single-core frontier is stable.

Detailed targets and acceptance rules are in
[KECCAK_LIGHTHD_CHALLENGE_PLAN.md](KECCAK_LIGHTHD_CHALLENGE_PLAN.md).

## 10. ML-DSA-OSH Comparison Branch - 2026-09-13

- Restored the local one-round-per-clock design before creating `keccak_v2`.
- Preserved the historical 147.21 MHz fit and separately measured a clean
  rebuild at 141.82 MHz, 3,452 ALMs, and 1,674 registers.
- Imported all 16 ML-DSA-OSH Keccak VHDL files unchanged from upstream commit
  `751009199ac081091a9059805e6921453bde0154`.
- Added a separate protocol adapter so the existing UVM environment can test
  the upstream core without modifying vendor code.
- Passed 888/888 source transactions with 99.64% functional and 83.36% total
  filtered structural coverage.
- Passed the same 125/125 transactions at source, post-synthesis, and post-fit;
  all three checked-output records have the same SHA-256 hash.
- Fitted the native upstream core on Cyclone V at 143.64 MHz, 4,251 ALMs, and
  4,455 registers. It reaches 1,005.48 MB/s SHAKE128 and 813.96 MB/s SHAKE256
  permutation-only throughput, but does not meet the 230 MHz test constraint.

Full provenance, commands, coverage, and comparison caveats are in
[MLDSA_OSH_KECCAK_CYCLONE_V_COMPARISON.md](MLDSA_OSH_KECCAK_CYCLONE_V_COMPARISON.md).
