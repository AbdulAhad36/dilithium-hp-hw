# Keccak Post-Midyear Improvement Summary

Date: 2026-09-14  
Branch: `keccak_v2`  
Scope: Meaningful Keccak design, verification, synthesis, and timing work completed after the midyear evaluation

Current accepted architecture: **one complete Keccak-f[1600] round per clock**.
The latest clean direct-core Cyclone V checkpoint closes a **142.86 MHz**
constraint with +0.030 ns worst setup slack and +0.169 ns worst all-corner
hold slack. It uses 3,441 ALMs. The archived 147 MHz build used preserved
placement and 4,265 ALMs; the 198.57 MHz figure belongs to the superseded
two-clock-per-round architecture.

## 1. Direction After the Evaluation

- Stopped treating one high coverage percentage as proof that Keccak was fully verified.
- Adopted the supervisor's three-stage verification process:
  - Stage 1: verify the source SystemVerilog RTL with UVM.
  - Stage 2: verify the Quartus post-synthesis functional netlist.
  - Stage 3: verify the Quartus post-fit netlist after placement and routing.
- Kept functional coverage, code coverage, assertions, netlist comparison, timing, and FPGA testing as separate results.
- Created requirements-based verification documents so every test and remaining hole can be explained.

### Project and result map

| Project | Top/scope | Virtual pins | Primary purpose | Current result |
|---|---|---|---|---|
| `quartus/keccak.qpf` | One `keccak_core` | No | Historical/normal compilation | Not rerun as the current one-round performance sign-off |
| `quartus/stage2/keccak_stage2.qpf` | One core through `keccak_synth_top` | Data/control ports | Reproducible Stage 2 and Stage 3 implementation verification | 125/125 at both netlist stages; 50 MHz Stage 3 timing gate passes |
| `quartus/performance/keccak_performance.qpf` | Direct one-core benchmark | Data/control ports | Current internal-core timing sign-off | Seed-1 142.86 MHz constraint met; +0.030 ns worst setup, +0.169 ns worst hold |

The Stage 2 project is separate so netlist generation, simulation settings,
evidence directories, and the stable flat-port wrapper do not overwrite or
confuse the historical or performance projects. Despite its directory name,
both the Stage 2 and Stage 3 scripts use this implementation-verification
project. The three projects compile the same current Keccak RTL but answer
different questions.

### Reproduce the flows

From the repository root, run the focused post-synthesis and post-fit flows with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_stage1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_stage2.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_stage3.ps1
```

All three wrappers default to QuestaSim 2024.1 at
`C:\questasim64_2024.1\win64`; they do not depend on whichever `vsim` happens
to be first on `PATH`.

For interactive Quartus use, open the required `.qpf`, select
`Processing -> Start Compilation`, and inspect `Compilation Report -> TimeQuest
Timing Analyzer -> Multicorner Timing Analysis Summary`, `Fmax Summary`,
`Setup Summary`, and `Hold Summary`. A quick compile is not itself evidence of
a skipped stage; confirm Analysis and Synthesis, Fitter, Assembler, and
TimeQuest completion in the report. Existing Quartus databases may make repeat
compiles much faster than a clean pre-midyear build.

## 2. AXI Removal and Interface Simplification

- Removed AXI-Stream dependencies from the active Keccak core and UVM environment.
- Replaced AXI framing signals such as `tkeep` and `tlast` with a simple protocol-neutral interface.
- Added explicit message length and output length controls.
- Input data now uses a simple valid/ready handshake.
- Output data uses valid/ready plus an explicit valid-byte count.
- Added `done_o` for visible operation completion.
- Kept continuous SHAKE output support, terminated using `stop_i`.
- Retained a simple core interface that can later be connected to UART or wrapped with AXI separately if integration requires it.

## 3. UVM Environment Improvements

- Changed the monitor to reconstruct messages only from transfers accepted by `input_valid_i && input_ready_o`.
- Changed output monitoring to count only accepted output transfers.
- Made the scoreboard compare the complete observed message and output against the SHAKE reference result.
- Moved functional coverage sampling behind successful scoreboard checking.
- Coverage is no longer credited merely because the driver requested a scenario.
- Added protocol-error tracking to the monitor and scoreboard.
- Added visible tracking for input gaps, output stalls, resets, stop behavior, output byte counts, and active lanes.
- Added reproducible random seeds and separate evidence files for generated-netlist comparisons.

## 4. Tests Added or Expanded

- Tested SHAKE128 and SHAKE256.
- Tested empty, short, normal, and multi-block messages.
- Tested input lengths around the SHAKE128 168-byte rate boundary.
- Tested input lengths around the SHAKE256 136-byte rate boundary.
- Tested output lengths around word and rate boundaries.
- Tested final input words containing different valid byte counts.
- Tested bounded output and continuous output.
- Tested continuous-output stop at several positions, including a rate boundary and after re-permutation.
- Tested recovery after stop without requiring another global reset.
- Tested no input gaps, single gaps, burst gaps, and random gaps.
- Tested output backpressure at ordinary, final, and boundary output positions.
- Tested that a producer may hold valid data stable while the core is busy and
  that the core does not accept an extra word after the declared message end.
- Tested reset from IDLE, ABSORB, SUFFIX_PADDING, both permutation phases, and SQUEEZE.
- Tested successful recovery after reset from each observed phase.
- Tested configuration latching by changing mode and output-length inputs after start.
- Tested concurrent operation using one, two, three, and four active lanes.

## 5. Assertions and Internal Checks

- Added assertions for valid/ready protocol behavior.
- Checked that output data and byte count remain stable while output is stalled.
- Checked legal output byte counts.
- Checked bounded completion and continuous-stop completion behavior.
- Checked that reset returns the visible interface to idle without stale output.
- Checked for unknown output and control values during valid operation.
- Checked round-index limits and important FSM behavior.
- Bound assertion instances to each Keccak lane in the source-RTL environment.
- Added an independent FIPS 202 checker for theta, rho, pi, chi, and iota in
  every clock of the one-round permutation datapath.

## 6. Coverage Correction

- Replaced the misleading 100% coverage claim with separate, scoped metrics.
- Full source-RTL functional coverage is **100.00%**, representing 281 of 281 implemented functional bins.
- The latest fully executed source-RTL regression passes **888/888 checked transactions** across four lanes.
- Complete lane-0 RTL hierarchy code coverage was **96.74%** immediately after
  the one-round architectural change and is **98.78%** for the latest
  theta/reset-optimized source RTL.
- Source FSM state and legal transition coverage reached 100% for the measured model.
- All 32 assertion instances pass; 20 of 24 cover directives are reached.
- The focused one-lane suite reaches **71.53% functional coverage**, or 201 of 281 bins, in its Stage 1 source-RTL reference run, Stage 2 post-synthesis run, and Stage 3 post-fit run.
- The lower 71.53% result is expected because netlist simulation uses a smaller 125-transaction suite.
- Equal functional coverage across these three focused runs is expected because the stimulus, seed, checker, and coverage model are identical; only the DUT representation changes.
- Coverage is not reduced or manipulated to produce a more believable percentage.
- All implemented functional bins are closed, but Keccak is not described as
  verification-complete because structural holes, broader external vectors,
  FPGA execution, and remaining requirement rows are separate obligations.

## 7. RTL and Synthesis Cleanup

- Corrected enum and constant widths that produced unnecessary logic or warnings.
- Removed stale and unused signals.
- Removed unnecessary byte-mask population counting from critical control paths.
- Replaced variable arithmetic with constant-width counter increments where possible.
- Reviewed all 17 registers removed by synthesis.
- Confirmed that the removed registers are constant rate/suffix bits or unused Quartus-generated FSM nodes.
- Achieved zero Analysis and Synthesis warnings in the current one-core benchmark.
- Confirmed that Keccak infers no DSP blocks and no block RAM.
- Used virtual pins so the wide internal interface is not incorrectly treated as a physical FPGA package interface.

## 8. Post-Synthesis Verification

- Created a reproducible Quartus Stage 2 project for one Keccak core.
- Generated the technology-mapped post-synthesis Verilog netlist.
- Ran the same focused UVM checker against source RTL and the generated netlist.
- Source RTL passed **125/125 transactions**.
- Post-synthesis netlist passed **125/125 transactions**.
- Complete checked-result files have the same SHA-256 hash.
- Current one-round synthesis estimate is **3,187 ALMs and 1,673 registers**.
- Stage 2 proves agreement for the selected tests; it is not exhaustive formal equivalence.

## 9. Post-Fit Verification

- Created a reproducible Stage 3 flow including fitting, placement, routing, TimeQuest, and post-fit netlist generation.
- Ran the focused UVM checker against the current source RTL and fitted netlist.
- Source RTL passed **125/125 transactions**.
- Post-fit netlist passed **125/125 transactions**.
- Complete source and post-fit checked-result files have the same SHA-256 hash.
- The interface-verification project passes its fully constrained 50 MHz setup and hold requirement.
- Current Stage 3 verification-wrapper fit uses **3,210 ALMs** and **1,929 registers**.
- Stage 3 contains no DSP blocks or block memory.
- Board pin constraints and physical UART testing remain separate future work.

## 10. Architecture and Timing Improvement

- Created a separate direct-core performance project for reproducible internal-core timing measurement.
- Used High Performance Effort and Standard Fit instead of relying on Auto Fit.
- Enabled physical synthesis, register duplication, register retiming, and maximum router timing optimization.
- Physical synthesis lets Quartus restructure combinational logic, duplicate high-fanout registers, and retime eligible registers using placement/routing information. Its individual contribution is not isolated by the current evidence.
- The earlier two-clock architecture was swept across seeds 1 through 30 and reached 198.57 MHz with seed 12.
- Replaced total-output-byte feedback arithmetic with a registered remaining-byte count.
- Simplified final-output detection to compare the remaining count with one 8-byte output word.
- Registered input byte count, byte-enable mask, and final-word status before the absorb write path.
- Added a registered absorb-block-full flag instead of repeatedly placing a rate comparison in FSM control paths.
- Removed a 1600-bit operand-isolation multiplexer from the permutation input.
- Removed the 1,600-bit mid-round pipeline register and now evaluates theta,
  rho, pi, chi, and iota combinationally before committing one round each clock.
- Reduced one permutation from 48 round clocks to **24 round clocks**.
- Swept one-round seeds 1, 2, 3, and 12; seed 3 gave the best measured timing.
- A 150 MHz constraint on the preserved-placement baseline missed Slow 85 C
  setup by 0.057 ns and was rejected.
- The archived 6.803 ns, or 147 MHz, preserved-placement baseline passes with
  **+0.010 ns** worst setup slack and **+0.168 ns** worst hold slack. It uses
  4,265 ALMs and 1,674 registers.
- Clean recompilation without stale root-partition placement/routing
  preservation reduced area substantially but exposed the real routing
  limit. Retained RTL changes fold theta's temporary delta network, remove
  redundant control predicates, and remove the 1,600-bit state from the
  asynchronous reset network.
- A controlled post-RTL fitter sweep tested seeds 1, 2, 4, 5, and 1245. A
  final constraint-directed comparison retained seed 1.
- The latest clean checkpoint closes a 7.000 ns, or 142.86 MHz, constraint
  with **+0.030 ns** worst setup slack and **+0.169 ns** worst all-corner hold
  slack. The lower slow-corner Fmax estimate is 143.47 MHz, and the fit uses
  **3,441 ALMs and 1,674 registers**.
- A 140 MHz seed-5 attempt was rejected after producing -0.184 ns worst setup
  slack, -0.873 ns TNS, and 15 violating setup paths. The project was restored
  and fully recompiled at the passing 135 MHz checkpoint.
- The worst detailed state-feedback path has five logic levels, but routing
  accounts for 4.437 ns, or 66%, of its 6.728 ns data delay. Further progress requires
  a placement/state-feedback change rather than a tighter paper constraint.
- Relative to the final two-clock build, ALMs decrease by 19 while registers
  decrease by 1,641 (49.5%). Halving permutation clocks increases SHAKE128
  permutation throughput by about 43.9% despite the lower clock frequency.
- Virtual pins mainly remove package-I/O pressure. Because both projects exclude top-level I/O paths, no exact part of the 11.65 MHz gain is attributed to virtual pins without a controlled A/B build.
- A proposed absorb/padding XOR refactor passed 888/888 RTL tests but increased
  synthesized logic cells from 5,267 to 6,870 and reduced Fmax to about
  153 MHz. It was rejected and reverted before the final build.
- Removing reset from the temporary 1,600-bit permutation pipeline register
  and replacing the absorb decoder with a one-hot pointer each passed 888/888
  source checks, but both reduced Fmax. They were rejected and reverted.

## 11. Current Verified Result

- Keccak supports SHAKE128 and SHAKE256 through the simplified interface.
- Full source regression: **888/888 passed**.
- Source functional coverage: **281/281 bins (100.00%)**.
- Complete lane-0 hierarchy code coverage: **98.78%**.
- Focused source/post-synthesis comparison for the current one-round
  candidate: **125/125 matched**.
- Focused source/post-fit comparison for the current one-round candidate:
  **125/125 matched**.
- Current clean one-core operating point: **142.86 MHz**, with no setup or hold violations.
- Performance-fit resources: **3,441 ALMs and 1,674 registers**.
- Calculated per-core SHAKE128 throughput is **1.000 GB/s** using the
  publication-style permutation-only convention, or **0.533 GB/s** when the
  21 input-transfer clocks per rate block are included.
- Calculated per-core SHAKE256 throughput is **0.810 GB/s permutation-only**,
  or **0.474 GB/s** including 17 input-transfer clocks per rate block.
- These are no-stall core-level calculations, not measured FPGA/UART throughput; a four-lane hardware throughput claim remains open.
- DSP blocks: **0**.
- Block memory: **0**.
- No UVM errors or fatals in the accepted regressions.

## 12. Remaining Work

- Add broader independent NIST/CAVP vectors.
- Review remaining non-FSM code-coverage holes.
- Ask the supervisor whether SDF timing simulation is required in addition to static timing analysis.
- Build and measure a separate four-lane Quartus configuration.
- Obtain the FPGA board model, oscillator frequency, pin table, and UART details.
- Build the board-specific top level and perform FPGA/UART known-answer and random tests.
- Improve the full-round combinational critical path only through a separately
  verified architectural change; do not tighten constraints beyond routed timing.
- Continue the LightHD challenge from the clean 142.86 MHz / 3,441-ALM checkpoint.
  The 212.8 MHz and sub-3,150-ALM gates are not yet met.

## 13. Detailed Supporting Documents

- Living post-midyear report: [keccak-design-and-verification.md](keccak-design-and-verification.md)
- Historical pre-midyear report: [keccak-design-and-verification.md](../pre_midyear/keccak-design-and-verification.md)
- LightHD challenge plan and execution log: [KECCAK_LIGHTHD_CHALLENGE_PLAN.md](KECCAK_LIGHTHD_CHALLENGE_PLAN.md)
- Overall roadmap: [POST_MIDYEAR_VERIFICATION_PLAN.md](POST_MIDYEAR_VERIFICATION_PLAN.md)
- Verification requirements and status: [KECCAK_VERIFICATION_TESTPLAN.md](KECCAK_VERIFICATION_TESTPLAN.md)
- Coverage details: [keccak-coverage-baseline.md](keccak-coverage-baseline.md)
- Post-synthesis evidence: [KECCAK_STAGE2_SYNTHESIS_REPORT.md](KECCAK_STAGE2_SYNTHESIS_REPORT.md)
- Post-fit evidence: [KECCAK_STAGE3_POSTFIT_REPORT.md](KECCAK_STAGE3_POSTFIT_REPORT.md)
- Timing optimization details: [KECCAK_TIMING_OPTIMIZATION_REPORT.md](KECCAK_TIMING_OPTIMIZATION_REPORT.md)
