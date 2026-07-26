# Post-Midyear Evaluation: Verification Recovery and FPGA Validation Plan

**Project:** Hardware Design and Verification of CRYSTALS-Dilithium / ML-DSA  
**Date:** 2026-07-20  
**Status:** Working plan after the midyear evaluation  
**Immediate priority:** Establish credible, requirements-driven verification of Keccak and NTT before implementing another Dilithium block

## 1. Executive Decision

The Keccak and NTT work is useful, but neither block should currently be described as "completely verified" or simply as having "100% coverage."

The immediate project goal changes from:

> Build the sampler next, then integrate Keccak + sampler + NTT.

to:

> Freeze new feature development, repair the verification methodology, close the Keccak verification plan, perform a structural and verification audit of NTT, verify the Quartus post-synthesis and post-fit implementations, and validate both blocks on an FPGA through a small UART test harness.

After those gates pass, the previous roadmap resumes:

1. Rejection sampler.
2. Keccak + sampler + NTT integration.
3. Rounding, decomposition, packing, and the ML-DSA controller.
4. End-to-end FIPS 204 known-answer testing.

This does not discard the previous work. It changes the standard of evidence used to accept it.

## 2. What the Evaluation Exposed

### 2.1 The reported 100% numbers are narrow

The NTT UCDB contains one functional covergroup:

- 3 operation bins: NTT, INTT, PWM.
- 4 input-kind bins: zero, max, delta, random.
- 12 operation x input-kind cross bins.
- 19 total functional bins.

All 19 bins were hit, so that covergroup correctly reports 100%. However, the current NTT compile flow does not enable RTL statement, branch, condition, expression, FSM, or toggle coverage. Therefore, "100% functional coverage" currently means only "all 19 hand-written bins were sampled." It does not mean 100% of the requirements, RTL, control paths, protocol behavior, arithmetic corner cases, or mapped implementation were verified.

The Keccak UCDB is stronger because RTL code coverage was enabled. Its actual Questa result is:

- Functional covergroup: 100% (32/32 bins).
- Total filtered coverage: 86.29%.
- `keccak_core` FSM states: 100%.
- `keccak_core` FSM transitions: 72.72% (8/11).
- `keccak_core` statements: 94.44%.
- `keccak_core` branches: 97.33%.
- Several conditions, output-unit paths, and toggles remain uncovered.

The correct claim is therefore that the current functional covergroups reached 100%, not that either design has total or complete verification coverage.

### 2.2 Coverage is sampled at the wrong place

Both functional coverage subscribers receive the driver's expected transaction before the DUT runs. This violates the main rule in the Coverage Cookbook: functional coverage should be based on observed DUT behavior and should only count when the associated check passes.

The current connection can award coverage when:

- The DUT later returns a wrong result.
- The DUT times out.
- A transfer is not accepted correctly.
- A reset or handshake corrupts the transaction.
- The intended operation was requested but never completed.

The repaired flow will sample a checked transaction emitted by the scoreboard only after the monitor observes a complete response and the scoreboard passes it.

### 2.3 The presentation overstates implemented coverage

The NTT presentation lists coverpoints for transform case, coefficient/output range, and crosses involving those items. They are not implemented in `ntt_coverage.sv`; only operation, input kind, and their cross exist.

The Keccak presentation says the covergroup samples completed transactions. The implementation samples expected driver transactions before completion.

These are documentation errors and must be corrected before the next review.

### 2.4 The Keccak area result is mislabeled

Quartus synthesized `keccak_core`, not `keccak_engine_parallel`. The reported approximately 3,738 ALMs, 3,270 registers, and 84.31 MHz are single-core results. The slide labels approximately 3,747 ALMs as a four-lane result, which is incorrect.

The four-lane 3.84x figure is a simulation wall-clock speedup from replicating four cores. It is not a four-lane synthesis result and does not show improved area efficiency. A four-lane hardware claim requires a separate synthesis of `keccak_engine_parallel` and an area/throughput comparison against one lane.

### 2.5 The Keccak pipeline is not an effective throughput pipeline

The design changed from one round per cycle to one round every two cycles by inserting a 1600-bit register between `(theta + rho + pi)` and `(chi + iota)`.

- Baseline: 73.96 MHz, 24 cycles per permutation.
- Pipelined: 84.31 MHz, 48 cycles per permutation.
- Fmax improved by only about 14%, while cycles per permutation doubled.

The design notes already show why: the actual critical path was squeeze/XOF length control, not the Keccak round. The pipeline split added many registers but did not cut the limiting path. It reduced estimated single-lane SHAKE128 throughput from roughly 518 MB/s to roughly 295 MB/s.

This does not necessarily make the hash result incorrect. It means the pipeline decision must be reconsidered after verification closure, and performance claims must use throughput and area together rather than Fmax alone.

### 2.6 Quartus explains the NTT DSP concern

The NTT fitter report shows six DSP blocks:

- Four expected independent 27x27 multipliers, one in each butterfly unit.
- Two unexpected independent 9x9 multipliers named `Mult0` and `Mult1` in `ntt_core`.

The two extra DSPs come from address-generation expressions:

```systemverilog
g_outer_r * (L << 1)
g_outer_r * (L << 2)
```

`L` is always a power of two, so these operations should be encoded as shifts or a small `case` table. Spending DSPs on address generation is an avoidable architecture/synthesis flaw.

The four main DSP blocks also report no input registers and an output register. The multiplier input path includes butterfly input selection and, for GS mode, modular subtraction before the DSP. This is consistent with the low 75.44 MHz Fmax and with the existing note that registering `mod_mul` inputs is the next timing step.

The current high ALM-to-DSP balance also has a logical explanation: replacing Barrett multiplication with four q-specific shift/add folds moved work out of DSPs and into ALMs and routing. Each butterfly uses roughly 333-345 ALMs including about 99 ALMs in `mod_mul`; the four butterflies account for a large part of the 2,313-ALM design. This is a trade-off, not automatically an arithmetic bug, but it must be measured honestly.

### 2.7 The NTT top-level latency claim is incomplete

The approximately 299-cycle number is core compute latency. The synthesized top is `ntt_engine`, which also performs:

- 256 input beats for NTT/INTT.
- Core computation.
- 256 outputs through separate `E_TX_RD` and `E_TX_VALID` states, currently requiring about two clocks per output coefficient.

With no stalls, a full top-level NTT transaction is therefore around 1,067 cycles, not 299 cycles. Both numbers may be reported, but they must be labeled as:

- Compute-only core latency.
- End-to-end interface latency.

The front-end also exposes `s_tlast` but ignores it, and the UVM environment never applies output backpressure or random input gaps. This is another reason to remove the AXI claim and verify a simpler interface first.

## 3. Why the Supervisor's Recommendations Make Sense

### 3.1 Remove AXI from the current verification target

AXI is a protocol, not just a group of `valid`, `ready`, `data`, and `last` signal names. Claiming AXI support creates additional requirements for:

- Handshake timing.
- Stability while stalled.
- Packet boundaries.
- Backpressure.
- Reset behavior.
- Legal and illegal transfers.
- Protocol assertions or a verified VIP.

The current project goal is to prove Keccak and NTT arithmetic and control behavior. A small custom interface makes that evidence easier to produce.

Recommended interfaces:

- NTT: addressed coefficient load/read ports plus `start`, `op`, `busy`, and `done`.
- Keccak: protocol-neutral input-word valid/ready and output-word valid/ready signals, with explicit message and output length controls.

An AXI adapter can be added and verified separately later if system integration requires it. The arithmetic core should not depend on AXI.

### 3.2 Use virtual pins for module-level Quartus projects

A Quartus virtual pin maps a module port to internal FPGA logic instead of consuming a physical package pin. It is appropriate when compiling a reusable lower-level block that will later be connected to other FPGA logic.

This project currently has:

- Keccak: 202 physical pins, zero virtual pins, and no exact pin assignments.
- NTT: 59 physical pins, zero virtual pins, and no exact pin assignments.

Keccak also accidentally uses a default 32-bit enum for a two-value mode. Thirty mode input bits do not drive logic, which contributes to the excessive pin count.

The module benchmark projects should:

1. Make enum widths explicit.
2. Keep a real constrained clock.
3. Mark data/control module ports as virtual pins or place registered wrapper logic around the core.
4. Use an explicit timing policy for module inputs and outputs.
5. Run `check_timing` and report all unconstrained paths.

Virtual pins do not replace clock constraints. They make a block-level implementation and timing experiment more representative of later internal integration.

The separate FPGA board project must use real board pin assignments for clock, reset, UART RX/TX, and any LEDs/buttons.

### 3.3 Put both designs on an FPGA through UART

RTL simulation verifies a model. FPGA validation additionally exercises:

- Real clock and reset behavior.
- Synthesis and fitting.
- Device memory and DSP inference.
- Physical routing.
- I/O pins and voltage standards.
- UART framing and host communication.
- Repeated operation over real time.

It does not replace UVM. It is a separate verification level that catches integration and implementation problems that RTL simulation cannot expose.

### 3.4 Follow a written verification process

The Coverage Cookbook's central process is:

1. Derive requirements from the specification and architecture.
2. Put one requirement on each testplan row.
3. Define how to generate the condition.
4. Define how to check the result.
5. Define how to measure coverage.
6. Run regressions and investigate holes.
7. Add tests, fix bugs, or justify unreachable bins.
8. Review and sign off the plan.

Coverage is a progress metric. It is not proof by itself.

## 4. Corrected Three-Stage Verification Flow

The supervisor's clarification describes verification of three successive representations of the same design:

1. The source SystemVerilog RTL.
2. The synthesized netlist generated by Quartus.
3. The mapped and fitted implementation generated by Quartus.

The same requirements, external stimulus, golden model, and scoreboard should be reused at all three stages. Only the DUT representation changes. Intel documents both RTL and gate-level simulation in the Quartus flow, and the EDA Netlist Writer can generate simulation netlists after synthesis and after the Fitter.

### Stage 1: Source RTL verification with UVM

This is the main verification stage and the place where complete regressions and coverage closure occur.

- Compile the hand-written RTL directly in Questa and drive it through UVM sequences.
- Compare every completed operation against independent golden models and known-answer vectors.
- Run directed, constrained-random, reset, error, backpressure, and stress tests.
- Collect functional coverage from scoreboard-passed observed transactions.
- Collect DUT-only statement, branch, condition, expression, FSM, and selected toggle coverage.
- Run assertions for protocol, sequencing, latency, arithmetic range, reset, and pipeline behavior.
- Merge multiple random seeds and review or waive every important coverage hole.

**Stage 1 gate:** all P1 requirements pass, there are no scoreboard or assertion failures, and all remaining coverage holes are understood.

### Stage 2: Quartus post-synthesis functional verification

Run Quartus Analysis and Synthesis, then use its EDA simulation flow to generate a post-synthesis gate-level functional netlist. This generated netlist represents the logic after synthesis transformations such as optimization, constant propagation, resource inference, and technology mapping.

- Compile the generated Verilog or VHDL simulation netlist in Questa with the required Cyclone V simulation libraries.
- Reuse the same interface-level UVM testbench, vectors, golden model, and scoreboard.
- Run all official known-answer tests, arithmetic corner cases, reset tests, and a representative constrained-random subset.
- Compare outputs and externally visible control behavior with the Stage 1 results.
- Inspect synthesis warnings, the post-synthesis hierarchy, inferred RAMs/DSPs, removed signals, and width changes.

The Quartus RTL Viewer or Technology Map Viewer helps inspect the generated logic, but viewing the schematic is not verification by itself. The verification evidence is the simulation pass/fail result against the same checker.

Internal RTL hierarchy and signal names may be changed or removed by synthesis. Therefore, internal `bind` assertions and hierarchy-dependent coverage may not be portable to this stage. The reusable UVM environment must primarily depend on stable top-level ports. If necessary, use a thin simulation wrapper without changing the checker.

**Stage 2 gate:** the post-synthesis netlist passes the selected regression with zero output mismatches, and every important synthesis warning or optimized signal is explained.

### Stage 3: Quartus post-fit/mapped implementation verification

Run the complete Quartus compilation, including fitting, placement, routing, and TimeQuest timing analysis. Generate a post-fit simulation netlist and verify the implementation that is closest to the FPGA configuration.

- Run a focused gate-level regression using the same interface-level UVM checker.
- Include all official known-answer tests, boundary cases, reset, and a small reproducible random suite.
- Run post-fit functional simulation and timing-annotated simulation if supported by the selected Quartus/device/simulator flow.
- Use TimeQuest static timing analysis as the timing sign-off authority.
- Confirm there are no unconstrained timing paths under the documented timing policy.
- Confirm that DSPs, M10Ks, registers, ALMs, clocks, resets, and optimized signals match the architecture.
- Archive the post-fit netlist, simulation transcript, Fitter report, TimeQuest report, seed, and exact Git commit.

Gate-level simulation is much slower and harder to debug than source RTL simulation. It is a focused implementation check, not where the full functional coverage campaign should be repeated.

**Stage 3 gate:** the post-fit netlist passes the focused regression, timing is correctly constrained and reported, and every mapped resource is understood.

FPGA/UART testing follows these three simulation stages as physical hardware validation.

These stages are not three percentages to average together:

- Stage 1 produces requirements, functional, code, FSM, toggle, and assertion coverage.
- Stages 2 and 3 primarily produce equivalence-style pass/fail evidence against the same external checker.
- A testplan row records which stages exercised it and links to the corresponding logs.

## 5. Verification Plan Format

Create one testplan table for Keccak and one for NTT. Each row should contain:

| Field | Purpose |
|---|---|
| ID | Stable identifier such as `K-REQ-001` or `N-REQ-001` |
| Requirement | One clear behavior the DUT shall or shall not perform |
| Source | FIPS 202, FIPS 204, design spec, or interface spec section |
| Priority | P1 critical, P2 important, P3 optional |
| Stimulus | How the condition is generated |
| Checker | Scoreboard, assertion, reference model, or manual lab check |
| Coverage | Coverpoint, cross, cover property, code metric, or test result |
| Stage | Source RTL, post-synthesis, post-fit, FPGA, or a combination |
| Tests | Test or sequence names that exercise the row |
| Status | Planned, implemented, passing, waived, or blocked |
| Evidence | UCDB path, regression log, report, or hardware log |

Coverage goals will be based on risk:

- 100% of P1 testplan rows implemented and passing.
- 100% of official known-answer vectors selected by the plan passing.
- 0 scoreboard mismatches.
- 0 assertion failures.
- All cover properties attempted and non-vacuous.
- High DUT code coverage, with every remaining hole reviewed and justified.
- Functional bins closed or explicitly waived; no target is accepted merely because it reaches a round percentage.

## 6. Keccak Verification Closure

### 6.1 Correctness sources

- FIPS 202 SHAKE128 and SHAKE256 vectors.
- NIST short-message, long-message, and variable-output vectors.
- An independent software implementation such as Python `hashlib` or the Dilithium software model.
- The existing pure-SystemVerilog model as a convenient simulation model, but not as the only authority.

### 6.2 Required stimulus families

- Empty message.
- One-byte and one-word messages.
- Last input beat containing 1 through 8 valid bytes.
- SHAKE128 lengths around 168-byte rate boundaries: 167, 168, 169, 335, 336, 337.
- SHAKE256 lengths around 136-byte rate boundaries: 135, 136, 137, 271, 272, 273.
- Random and structured data: all zero, all one, all `0xff`, alternating, counting, and random.
- Bounded outputs around 8-byte and rate boundaries.
- Continuous output stopped at the first beat, mid-block, boundary, and later block.
- Input valid gaps: none, single-cycle, burst, and random.
- Output backpressure: none, single-cycle, burst, and random.
- Back-to-back transactions without a global reset between every test.
- Async reset from every active FSM state.
- Start while busy and stop outside squeeze, with behavior explicitly specified.

### 6.3 Functional coverage

- Mode.
- Message-length boundary category, with separate SHAKE128 and SHAKE256 rate bins.
- Valid-byte count on the final input word.
- Number of absorb blocks.
- Bounded versus continuous output.
- Output-length boundary category.
- Number of squeeze blocks.
- Input stall category.
- Output backpressure category.
- Reset state.
- Stop position.
- Per-lane concurrency and independent reset for the parallel wrapper.
- Important crosses only, such as mode x rate boundary, mode x output boundary, and reset state x mode.

The current broad range bins must be split. Hitting output length 300 must not imply that every value from 169 to 65,535 was meaningfully covered.

### 6.4 Assertions

- Output data, keep, and last remain stable while valid is high and ready is low.
- Input words are consumed only on valid/ready handshakes.
- `m_last` is legal only with `m_valid` and on the final bounded output beat.
- `keep` is legal and contiguous on a partial final beat.
- Round index remains in 0..23.
- A permutation request completes in the specified number of pipeline cycles.
- No unknown control/output values when valid.
- Reset returns the FSM and visible protocol state to idle.
- One lane's reset or stalls do not change another lane's transaction.

### 6.5 Keccak closure deliverables

- Correct the enum width and synthesis warnings.
- Move coverage to scoreboard-passed observed transactions.
- Repair the currently disabled reset/abort sequence.
- Add DUT-only code and assertion coverage reports.
- Synthesize one lane and four lanes as separate configurations.
- Report per-core and aggregate throughput, area, and cycles without mixing them.
- Defer pipeline redesign until the verification gate passes.

## 7. NTT Verification and Architecture Audit

### 7.1 Correctness sources

- FIPS 204 / ML-DSA algorithm conventions.
- The repository's Dilithium C reference model.
- Pre-generated C-model vectors for NTT, INTT, and PWM.
- Independent schoolbook negacyclic polynomial multiplication.
- The existing pure-SystemVerilog model as a simulation reference, cross-checked against the C vectors.

### 7.2 Unit-level verification before full core UVM

Verify these units independently before relying on end-to-end transform tests:

1. `mod_mul`: exhaustive testing is impossible for 23-bit operands, so use directed modular boundaries plus large constrained-random campaigns and compare every result against a wider software calculation.
2. `butterfly_unit`: CT and GS, modular overflow/underflow, every latency position, and one-operation-per-cycle pipeline stress.
3. `twiddle_rom`: every reachable address compared against independently generated values.
4. Bank/address generator: every pass, group, offset, address boundary, and bank permutation; assert that each four-address tile uses four distinct banks.
5. `ntt_core`: NTT, INTT, scale, PWM, pipeline drains, and operation sequencing.

### 7.3 Required data patterns

- All zero, all one, all `q-1`, all `q-2`, and midpoint coefficients.
- Delta coefficients at indices 0, 1, 127, 128, and 255.
- Alternating 0/`q-1`.
- Increasing and decreasing ramps modulo q.
- Sparse and dense polynomials.
- Single-bit coefficient patterns.
- Random coefficients biased near 0 and q.
- PWM pairs involving zero, one, `q-1`, equal operands, and independent random operands.
- NTT -> INTT round trip.
- NTT(A), NTT(B), PWM, INTT compared with schoolbook multiplication.

### 7.4 Functional coverage

- Operation: NTT, INTT, PWM.
- Input-pattern family.
- Coefficient value region: zero, one, low, middle, high, `q-2`, `q-1`.
- Edge coefficient position.
- Forward/CT, inverse/GS, scale, and PWM datapath modes.
- All four passes and all eight conceptual NTT stages.
- Twiddle address and important twiddle classes.
- Address low/high boundaries.
- All legal bank permutations.
- Pipeline drain length and operation latency.
- Input gap and output backpressure class if a stream wrapper remains.
- Reset state.
- Back-to-back operation transition: NTT->INTT, NTT->PWM, PWM->INTT, and repeated operations.
- Output range below q, sampled only after the scoreboard passes.

### 7.5 Assertions

- Every valid coefficient is in `[0, q-1]` at defined normalized boundaries.
- Four addresses in a tile are in range and map to distinct banks.
- No two writes target the same bank in one tile.
- Pipeline valid at issue implies writeback at the documented latency.
- No writeback occurs without a corresponding valid issue.
- Pass, group, offset, twiddle, and memory addresses remain in range.
- `done` is a one-cycle pulse and is not asserted with `busy` deasserted prematurely.
- Reset cancels in-flight work and prevents stale writeback.
- Output data remains stable during backpressure if a ready/valid wrapper is retained.
- No unknown data is emitted when output valid is asserted.

### 7.6 Structural audit before optimization

- Replace address-generation multiplications with shifts or a pass-indexed case table; expected DSP count for the current four-BFU datapath is four, unless another use is explicitly justified.
- Decide whether the q-specific fold architecture remains preferable after comparing ALM, DSP, Fmax, and latency with a clean alternative.
- Register multiplier inputs only after the updated tests and assertions are in place.
- Remove or specify `s_tlast`; do not expose an ignored protocol signal.
- Replace the two-cycle-per-coefficient read/valid FSM with a simple addressed result interface for verification. Optimize streaming later only if integration requires it.
- Clean stale comments, ignored ports, truncation warnings, and vestigial Barrett parameters.
- Re-run directed tests, UVM, code coverage, assertions, synthesis, and timing after every structural change.

### 7.7 NTT closure deliverables

- C-reference vectors and independent cross-checks.
- Unit-level UVM or self-checking benches for multiplier, butterfly, ROM, and address/bank logic.
- Full-core UVM with observed-pass coverage.
- DUT code, FSM, assertion, and functional coverage reports.
- An architecture audit explaining every DSP, M10K, and major ALM consumer.
- Separate compute-only and end-to-end latency results.
- Post-synthesis and post-fit functional smoke tests.

## 8. Quartus Constraint and Mapping Plan

Create two project types per block.

### 8.1 Module benchmark project

- Core or simple-interface wrapper as top.
- Registered input/output shell or virtual pins for data/control ports.
- Explicit clock constraint.
- Explicit virtual-pin clock/timing policy where supported.
- No blanket claim that ignored I/O timing represents complete system timing.
- `check_timing` and an unconstrained-path report.
- Resource-by-entity, RAM, DSP, critical-path, and warning reports archived.

### 8.2 Board project

- Board-specific top-level.
- Actual oscillator clock and reset conditioning.
- Real UART RX/TX pin and I/O-standard assignments.
- Optional status LEDs.
- No virtual pins on physical board interfaces.
- Timing sign-off for all real clock domains.

### 8.3 Mapping acceptance checklist

- No unexpected multiplier/DSP inference.
- Expected coefficient memories infer as block RAM.
- No latches.
- No functional input optimized away without an explanation.
- No unexplained width truncation.
- No unconstrained setup paths.
- Fitter and TimeQuest reports correspond to the exact tested RTL commit.
- Post-synthesis and post-fit outputs match the RTL golden model on focused regressions.

## 9. FPGA UART Validation Plan

The UART path is a test harness, not the final ML-DSA interface.

### 9.1 Data path

```text
PC test program
  -> USB-UART
  -> FPGA UART RX
  -> command parser and input buffer
  -> Keccak or NTT simple interface
  -> result buffer
  -> FPGA UART TX
  -> PC checker and golden model
```

### 9.2 Bring-up order

1. Obtain board name, FPGA device, oscillator frequency, USB-UART device, voltage, and pin table.
2. Compile and program a blinking LED design.
3. Implement and test UART echo at a conservative baud rate such as 115200.
4. Add a framed command parser and checksum.
5. Connect Keccak and pass a small SHAKE known-answer test.
6. Connect NTT and pass a small pre-generated vector.
7. Run directed and random batches from the PC.
8. Use SignalTap for internal observation if a hardware-only failure occurs.

### 9.3 Suggested command frame

```text
SYNC | VERSION | CORE | OP | INPUT_LENGTH | OUTPUT_LENGTH | PAYLOAD | CHECKSUM
```

- Keccak payload: message bytes; operation selects SHAKE128/SHAKE256.
- NTT payload: 256 little-endian 23-bit coefficients packed into three bytes each; PWM sends two polynomials.
- Response: status, measured core cycles, result length, result payload, checksum.

### 9.4 Hardware evidence

Each run should record:

- Git commit hash.
- Quartus version and device.
- Board and clock frequency.
- Bitstream build timestamp or checksum.
- Test-vector source and random seed.
- Number of passed/failed cases.
- UART log and first mismatch, if any.

Hardware pass/fail evidence is not a replacement for simulation coverage; it is a separate sign-off column in the testplan.

## 10. Execution Timeline

### Phase 0 - Baseline correction (2-3 days)

- Freeze Keccak and NTT feature development.
- Correct the midyear claims and establish a known baseline commit.
- Archive current UCDB, Questa reports, Quartus reports, and simulation logs.
- Create Keccak and NTT requirement/testplan tables. The initial [Keccak verification testplan](verification/KECCAK_VERIFICATION_TESTPLAN.md) was created on 2026-07-26; NTT remains pending.

**Gate:** Supervisor agrees with the three representations, regression scope at each stage, and testplan format.

### Phase 1 - Verification infrastructure (1 week)

- Move functional coverage behind scoreboard pass.
- Add DUT-only code coverage to NTT.
- Separate DUT coverage from testbench/package coverage in reports.
- Add assertion interfaces and regression scripts.
- Add seed control, UCDB naming, merging, and coverage summaries.

**Gate:** One smoke test demonstrates functional, code, FSM, and assertion coverage as separate metrics.

### Phase 2 - Keccak closure (1-2 weeks)

- Add rate-boundary, keep, stall, backpressure, continuous-stop, reset-state, and back-to-back tests.
- Repair abort/reset testing.
- Correct enum width and warnings.
- Review every uncovered branch, condition, and FSM transition.
- Run one-lane and four-lane regressions separately.

**Gate:** All P1 Keccak requirements pass; remaining holes have reviewed waivers.

### Phase 3 - NTT audit and closure (2-3 weeks)

- Verify multiplier, butterfly, ROM, and address/bank units.
- Add C-reference vectors and richer UVM stimulus.
- Add internal and interface assertions.
- Remove the two address-generation DSP multipliers.
- Simplify the verification interface and separate core/end-to-end latency.
- Review all code and functional coverage holes.

**Gate:** All P1 NTT requirements pass and every mapped DSP/RAM is explained.

### Phase 4 - Post-synthesis and post-fit verification (1 week)

- Build virtual-pin or registered-shell benchmark projects.
- Generate a post-synthesis functional simulation netlist.
- Run the Stage 2 regression against the existing UVM checker.
- Complete fitting and generate a post-fit simulation netlist.
- Run the focused Stage 3 regression.
- Audit timing constraints, warnings, critical paths, and inferred resources.

**Gate:** Both generated netlists pass, with no unexplained warnings or unconstrained paths.

### Phase 5 - FPGA/UART validation (1-2 weeks after board arrival)

- Board bring-up, UART echo, command framing, Keccak tests, then NTT tests.
- Archive reproducible PC and FPGA logs.

**Gate:** Both cores pass known-answer and random hardware batches.

### Phase 6 - Resume the old roadmap

- Build the rejection sampler on a new branch.
- Apply the same requirements -> source RTL UVM -> post-synthesis -> post-fit -> FPGA process from its first commit.
- Integrate only blocks that have passed their module gates.

## 11. Definition of Done for Each Core

A core is accepted only when all of the following are true:

- Its interface and behavior are written as requirements.
- All P1 requirements are linked to generation, checking, and coverage.
- Official and independent known-answer vectors pass.
- Directed and constrained-random regressions pass with reproducible seeds.
- Functional coverage is sampled from successfully checked observed behavior.
- DUT code, FSM, functional, and assertion coverage are reported separately.
- Every important coverage hole is closed or justified in writing.
- No unexplained synthesis warning, ignored functional input, latch, truncation, DSP, or RAM remains.
- Timing constraints are complete for the stated benchmark scope.
- Post-synthesis and post-fit functional smoke tests pass.
- FPGA/UART known-answer and random batches pass.
- Documentation reports the exact scope of every number.

## 12. Immediate Next Actions

1. Confirm with the supervisor whether his second stage specifically means a post-synthesis functional netlist and whether he expects timing annotation in the post-fit stage.
2. Review and approve the Keccak testplan, then build the NTT requirement/testplan before adding more coverpoints.
3. Keccak coverage sampling was repaired and regression-tested on 2026-07-26; NTT coverage sampling and DUT-only code coverage remain pending.
4. Correct the presentation's Keccak lane/area and NTT coverage claims.
5. Close Keccak first because it is nearly ready.
6. Perform the NTT DSP/address/pipeline audit before any performance optimization.
7. Obtain the exact FPGA board details before writing board pin constraints or the UART top-level.

The main lesson is not that the existing work is worthless. The arithmetic scoreboards and known vectors are a solid start. The problem is that the evidence was summarized too aggressively. The revised process makes each claim traceable, reproducible, and much harder to challenge in the next evaluation.
