# Keccak/SHAKE Requirements-to-Verification Testplan

**Project:** ML-DSA hardware accelerator  
**DUT branch:** `1_hashing`  
**Audited branch head:** local uncommitted state based on `1_hashing`
**Target DUTs:** `keccak_core` and `keccak_dual_interleaved`
**Target device:** Cyclone V `5CGXFC7C7F23C8`  
**Status:** One-round source RTL, Stage 2, and one-core Stage 3 gates passing; 147 MHz setup/hold closed; P1 closure remains incomplete
**Date:** 2026-09-12

## 1. Purpose

This document is the sign-off contract for the Keccak/SHAKE block. It replaces the claim "100% coverage" with traceable evidence for each requirement:

1. What behavior is required.
2. How the behavior is stimulated.
3. How the result is checked.
4. How execution is measured.
5. At which design representation it is rerun.
6. What evidence is required before closure.

The current design is a verified timing-optimized baseline, but it is not yet
verification-complete. Any further architectural optimization must preserve the
three-stage regression evidence and must not be accepted from timing alone.

## 2. Authoritative Sources

| Source | Use |
|---|---|
| [FIPS 202](../../FIPS/nist.fips.202.pdf) Sections 3, 4, 5, and 6.2 | Keccak-f[1600], sponge, pad10*1, SHAKE128, and SHAKE256 behavior |
| [NIST SHA-3 Validation System](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/sha3/sha3vs.pdf) Section 6.3 | Short-message, long-message, Monte Carlo, and variable-output test families |
| [NIST CAVP secure hashing vectors](https://csrc.nist.gov/Projects/Cryptographic-Algorithm-Validation-Program/Secure-Hashing) | Independent SHAKE response files and validation-oriented vectors |
| Coverage Cookbook (supervisor-provided manual; repository copy currently unavailable) | Requirements-driven coverage, testplan fields, datapath coverage, and coverage closure methodology |
| `1_hashing:src/keccak_engine/*.sv` | Implemented architecture and interface behavior |
| `1_hashing:tb_uvm/tb_uvm_keccak_v2/*.sv` | Existing UVM stimulus, monitoring, checking, and coverage |
| [Living Keccak design and verification report](../pre_midyear/keccak-design-and-verification.md) | Master design history, current results, reproduction flow, and progress log |

The pure-SystemVerilog model is useful, but it is not the sole authority because it shares language, constants, and implementation assumptions with the RTL. Official NIST vectors and an independent implementation such as Python `hashlib.shake_128`/`shake_256` must anchor the results.

## 3. Verification Scope and Proposed Contract

The verification target is the arithmetic core with an explicit-length,
protocol-neutral ready/valid word interface. AXI ports and framing signals have
been removed from the RTL and active UVM environment.

| Item | Contract to verify |
|---|---|
| Algorithms | Byte-oriented SHAKE128 and SHAKE256 only |
| Permutation | Keccak-f[1600], 24 rounds |
| Input width | 64 bits / 8 bytes per accepted beat |
| Input framing | `message_len_i` declares the exact byte count; the core derives final-word byte enables |
| Empty message | `message_len_i=0`; no dummy input transfer is required |
| SHAKE128 | Capacity 256 bits, rate 1344 bits / 168 bytes |
| SHAKE256 | Capacity 512 bits, rate 1088 bits / 136 bytes |
| Domain separation | SHAKE suffix `1111`, represented by effective byte `0x1f` with multi-rate padding |
| Fixed output | `output_len_i` is a byte count from 1 through 65,535; `output_bytes_o` reports 1..8 valid bytes and `done_o` marks completion |
| Continuous output | `output_len_i=0`; output continues until `stop_i` |
| Input transfer | Occurs only when `input_valid_i && input_ready_o` |
| Output transfer | Occurs only when `output_valid_o && output_ready_i` |
| Configuration | Mode and output length are sampled on a one-cycle `start_i` pulse in IDLE |
| Reset | Active-high asynchronous reset aborts work and returns the visible interface to idle |
| Stop | Sampled only in SQUEEZE; it terminates continuous output and asserts `done_o` |
| Parallel wrapper | Lanes share only the clock; reset, control, input, state, and output behavior are independent |

### 3.1 Contract questions to resolve before RTL changes

- Confirm whether mode and length may change after `start_i`; the proposed contract says they are latched and later changes have no effect.
- Confirm whether `start_i` while busy is illegal and assertion-only, or must receive a defined response.
- Confirm whether `stop_i` in fixed-length mode is legal or illegal.
- Confirm the minimum supported fixed output length. The RTL supports one byte, so the supported range must be declared and tested explicitly.

These are specification questions, not coverage holes. They must be decided before illegal bins or assertions are written.

## 4. Audited Baseline

The baseline below describes the checked-in UVM implementation and the existing `sim/keccak_cov.ucdb`. The UCDB must be regenerated from a pinned commit before it is accepted as formal evidence.

| Area | Audited result | Status |
|---|---|---|
| Active UVM workload | Common, boundary, stress, recovery, reset-phase, deep-consistency, lane-isolation, controlled 1/2/3/4-lane, and input-backpressure suites; 888 checked transactions total | Passing |
| Four-lane workload | Common and targeted per-lane transactions execute concurrently | Passing |
| Documentation count | Existing comments/docs say 13 directed + 19 closure; source implements 12 + 20 | Must correct |
| Golden checking | Observed output bytes are compared against `exp_hex`; random expected values come from the pure-SV model | Partial independence |
| Official vectors | A small hardcoded subset is present; full NIST CAVP suites are not imported | Partial |
| Expanded P1 functional covergroup | 281 bins; 281 hit; equal-bin score 100.00% | Implemented functional model closed; not total verification closure |
| Strict source-RTL P1 closure | 14 fully passing rows out of 44 | 31.82%; incomplete |
| Strict all-stage P1 closure | 18 fully passing rows out of 50 | 36.00%; incomplete |
| Coverage sampling | Scoreboard-passed monitor observations only | Corrected |
| Code coverage | Complete lane-0 RTL hierarchy: 96.74% | Passing with reviewed non-FSM holes pending |
| FSM coverage | States 100%; transitions 100% | Closed in source RTL |
| Assertions | 8 assertions per lane plus 6 cover properties per lane | 32/32 assertion instances passed; 20/24 cover directives hit |
| Input timing | None, single-cycle, burst, and random valid gaps | Passing |
| Output timing | Driver applies none, single-cycle, burst, and random backpressure | Passing |
| Transaction separation | Normal tests reset before start; reset/stop recovery and the complete mode-transition matrix deliberately omit selected intervening resets | Recovery and four-way back-to-back matrix proved |
| Mid-operation reset | Six observed FSM phases in both modes on every lane | Passing |
| Abort checking | Monitor captures pre-reset phase; scoreboard requires target match, idle recovery, and an immediately following no-reset KAT | Passing |
| Parallel isolation | Observed 1/2/3/4 active-lane waves plus peer reset/stall/stop isolation in both modes | Passing for implemented functional scenarios |
| Legacy unit benches | Obsolete core benches for the removed interface were deleted; active submodule benches remain | Cleanup complete |
| RTL documentation | `keccak_core.sv` documents the protocol-neutral interface and two-phase, 48-cycle permutation | Corrected |

### 4.1 Meaning of the old 100%

The 32 functional bins are:

- 2 mode bins.
- 4 broad output-length bins.
- 6 broad message-length bins.
- 12 mode x message-length cross bins.
- 8 mode x output-kind cross bins.

Hitting one value in a broad range closes the entire bin. For example, a single 300-byte output closes `[169:65535]`. This proves that the selected categories were requested, not that the full range or all boundary behaviors were checked.

### 4.2 Required checked-transaction flow

Functional coverage shall move behind successful checking:

```text
sequence -> driver -> DUT -> monitor -> scoreboard/reference comparison
                                      -> protocol checks
                                      -> checked_tx analysis port -> coverage
```

A transaction may be sampled only when all of these are true:

- The intended input handshakes were observed.
- The expected amount of output completed, or the specified reset/stop recovery completed.
- Output data matched an independent expected result where applicable.
- Byte ordering, accepted transfer counts, `output_bytes_o`, and completion were correct.
- No timeout, unknown value, assertion failure, or protocol error occurred.

The checked transaction contains observed facts such as accepted message bytes,
output bytes, final input/output byte count, absorb/squeeze block count, input-gap
class, output-stall class and position, stop position, observed reset phase,
observed active-lane count, lane ID, and protocol result.

## 5. Verification Stages

| Stage | DUT representation | Regression scope | Primary evidence |
|---|---|---|---|
| 1 | Hand-written source RTL | Full UVM, assertions, functional coverage, DUT code/FSM/toggle coverage | UCDB, logs, requirement closure |
| 2 | Quartus post-synthesis functional netlist | KATs, boundary tests, reset, protocol smoke, selected random seeds | Zero mismatches; synthesis warnings reviewed |
| 3 | Quartus post-fit netlist | KATs, boundary tests, reset, focused random smoke | Zero mismatches; Fitter and TimeQuest reports |
| FPGA | Board image with UART harness | KATs and reproducible random batches | UART logs, bitstream/build identity |

The same interface-level monitor, golden checker, and vectors should be reused. Internal RTL assertions and hierarchy coverage are Stage 1 evidence and may not survive synthesis.

For the implemented one-lane focused suite, all three representations hit the
same 201/281 functional bins (71.53%): source RTL, post-synthesis netlist, and
post-fit netlist. This is expected because all runs use the same 125
transactions and seed. The full four-lane Stage 1 suite remains the primary
coverage campaign at 281/281 bins (100.00%); generated-netlist code coverage is
not substituted for source RTL code coverage.

The Quartus projects have deliberately separate ownership:

| Project | Verification ownership |
|---|---|
| `quartus/keccak.qpf` | Normal/historical one-core compilation; not the current one-round timing sign-off |
| `quartus/stage2/keccak_stage2.qpf` | Stable wrapper and netlist generation for Stage 2 and Stage 3 |
| `quartus/performance/keccak_performance.qpf` | Tuned one-round internal-core benchmark; 147 MHz constraint met |

## 6. Priority and Status Definitions

| Mark | Meaning |
|---|---|
| P1 | Required before Keccak verification sign-off |
| P2 | Important robustness or diagnostic evidence; waive only with review |
| P3 | Optional characterization or future integration behavior |
| Pass | Implemented, run, checked, and linked to reproducible evidence |
| Partial | Some stimulus/checking exists, but the requirement is not closed |
| Missing | No adequate implementation or evidence exists |
| Decision | Interface behavior must be specified before implementation |

## 7. Requirements Matrix

### 7.1 Algorithm and datapath requirements

| ID | P | Requirement | Stimulus and checker | Coverage/evidence | Baseline |
|---|---:|---|---|---|---|
| K-ALG-001 | P1 | SHAKE128 output shall match FIPS 202 for supported byte-oriented messages and output lengths. | NIST vectors plus independent `hashlib`; byte-for-byte scoreboard. | `mode=SHAKE128`, requirement result. | Partial |
| K-ALG-002 | P1 | SHAKE256 output shall match FIPS 202 for supported byte-oriented messages and output lengths. | NIST vectors plus independent `hashlib`; byte-for-byte scoreboard. | `mode=SHAKE256`, requirement result. | Partial |
| K-ALG-003 | P1 | Keccak-f[1600] shall execute 24 rounds in the FIPS 202 theta, rho, pi, chi, iota order. | Unit vectors for every step and round; full permutation intermediate-state vectors. | Round-index bins 0..23; step checks; latency property. | Partial/stale |
| K-ALG-004 | P1 | SHAKE128 shall use rate 168 bytes, capacity 256 bits, and effective suffix `0x1f`. | Parameter-unit directed check and end-to-end padding vectors. | Mode x observed rate/suffix. | Partial |
| K-ALG-005 | P1 | SHAKE256 shall use rate 136 bytes, capacity 512 bits, and effective suffix `0x1f`. | Parameter-unit directed check and end-to-end padding vectors. | Mode x observed rate/suffix. | Partial |
| K-ALG-006 | P1 | The empty message shall be accepted and padded correctly in both modes. | Official empty-message KATs in fixed and continuous operation. | Mode x empty x output kind. | Implemented; resample after pass |
| K-ALG-007 | P1 | Every final input byte count 1..8 shall be absorbed in byte order. | Messages whose length modulo 8 is 1..7 and 0; independent output comparison. | Mode x final-byte-count bins 1..8. | Pass, 18/18 cross bins |
| K-ALG-008 | P1 | Padding shall be correct immediately before, exactly at, and immediately after each rate boundary. | SHAKE128 lengths 167/168/169 and 335/336/337; SHAKE256 lengths 135/136/137 and 271/272/273. | Mode x boundary-position. | Pass |
| K-ALG-009 | P1 | Multi-block absorption shall preserve every input byte and permute between full rate blocks. | Official short-message suite 0..2x rate, selected long vectors, and random 3+ block messages. | Absorb-block count 1/2/3/4+. | Partial |
| K-ALG-010 | P1 | Fixed output shall return exactly `output_len_i` bytes and no extra accepted beat. | Lengths 1..8, rate-1/rate/rate+1, 2x rate boundaries, and 600 bytes. | Mode x final-output-byte-count; squeeze blocks. | Pass for tested range |
| K-ALG-011 | P1 | Multi-block squeeze shall return the continuous SHAKE prefix across every rate transition. | Output lengths 135/136/137 and 167/168/169 plus 2x-rate boundaries. | Mode x output boundary x squeeze-block count. | Partial, boundaries missing |
| K-ALG-012 | P1 | For a fixed message, a shorter output shall equal the prefix of every longer output. | Metamorphic pairs/triples from the same message and mode. | Mode x prefix-length class. | Missing |
| K-ALG-013 | P1 | Input and output bytes shall use FIPS 202 little-endian lane ordering. | Walking-byte and walking-bit messages; intermediate-state and final-output comparison. | Byte position 0..7; lane boundary classes. | Implicit only |
| K-ALG-014 | P2 | Long-message behavior shall match the NIST byte-oriented selected-long-message suite. | Import official response files; compare every case. | NIST suite case result. | Missing |
| K-ALG-015 | P2 | Variable outputs shall match the NIST byte-oriented VariableOut suite over the declared supported range. | Import response files; compare output and length. | Output-length boundary and suite case. | Missing |
| K-ALG-016 | P2 | Repeated dependent SHAKE invocations shall match NIST Monte Carlo checkpoints. | Implement SHA3VS XOF Monte procedure as a slow regression. | Mode x checkpoint index. | Missing |

### 7.2 Input, configuration, and reset requirements

| ID | P | Requirement | Stimulus and checker | Coverage/evidence | Baseline |
|---|---:|---|---|---|---|
| K-IN-001 | P1 | `start_i` shall initialize exactly one transaction when pulsed for one cycle in IDLE. | Normal starts and delayed starts; state/protocol assertion. | Start-in-IDLE cover property. | Partial |
| K-IN-002 | P1 | Mode and fixed output length shall be sampled at start and remain effective for the transaction. | Change input pins after start; compare against originally selected configuration. | Mode x post-start-pin-change. | Pass |
| K-IN-003 | P1 | Input data shall be consumed only on `valid && ready`. | Insert zero, one, burst, and random valid gaps; compare accepted bytes and output. | Input-gap class x mode. | Pass |
| K-IN-004 | P1 | While `valid=1 && ready=0`, the source shall hold input data stable. | Driver creates legal waits; interface assertion checks source behavior. | Input-wait cover property and stability assertion. | Pass |
| K-IN-005 | P1 | The core shall derive the final accepted byte count from `message_len_i`. | Explicit lengths with modulo 8 = 0..7. | Mode x final input bytes 0..8. | Pass |
| K-IN-006 | P1 | Message completion shall occur only after exactly `message_len_i` bytes are accepted. | Accepted-stream reconstruction and exact count check. | Message boundary and final-byte crosses. | Pass |
| K-IN-007 | P1 | Consecutive transactions shall work without applying global reset between them. | Alternating modes, lengths, and messages back-to-back. | Prior mode x next mode; no-reset transition. | Missing |
| K-IN-008 | P1 | Asynchronous reset in IDLE, ABSORB, SUFFIX_PADDING, PERMUTE, and SQUEEZE shall cancel work and return the interface to idle without stale output. | State-targeted reset sequence with observed pre-reset phase and visible recovery checks. | Reset-state bins and reset-state x mode. | Pass |
| K-IN-009 | P1 | A transaction after mid-operation reset shall produce the same output as from a clean power-on reset. | Abort each state, then run a KAT without another reset. | Reset state x recovery result. | Pass |
| K-IN-010 | P2 | Illegal `start_i` while busy shall follow the agreed contract. | Attempt in every active state; assertion or defined response check. | Busy state x start attempt. | Decision |
| K-IN-011 | P2 | Unknown control values shall not be accepted or emitted as valid behavior. | Assertions on controls and outputs when valid. | Assertion pass/fail, not a covergroup goal. | Missing |

### 7.3 Output and stop requirements

| ID | P | Requirement | Stimulus and checker | Coverage/evidence | Baseline |
|---|---:|---|---|---|---|
| K-OUT-001 | P1 | Output data shall transfer only on `output_valid_o && output_ready_i`. | Random output backpressure; reconstruct accepted output stream. | Stall class x mode x output kind. | Pass |
| K-OUT-002 | P1 | Data, byte count, and valid shall remain stable while valid is asserted and ready is low. | One-cycle, burst, and random stalls on ordinary/final/rate-boundary beats. | Stall-position cross; stability assertion. | Pass |
| K-OUT-003 | P1 | Every fixed-length non-final beat shall carry eight valid bytes. | Fixed outputs spanning partial, full, and multiple beats. | Output beat type. | Partial |
| K-OUT-004 | P1 | The final fixed-length transfer shall report the exact `output_bytes_o` count and assert `done_o`. | Output lengths modulo 8 = 1..7 and 0. | Mode x final-byte-count 1..8. | Pass |
| K-OUT-005 | P1 | Continuous mode shall continue until a legal `stop_i`. | Outputs shorter than, equal to, and longer than one rate block. | Output kind x squeeze-block count and stop position. | Pass except exact-boundary contract decision |
| K-OUT-006 | P1 | Backpressure shall not duplicate, drop, reorder, or alter bytes. | Compare stalled and unstalled runs of identical transactions. | Stall-duration and stall-position crosses. | Missing |
| K-OUT-007 | P1 | `stop_i` shall terminate continuous output at the specified accepted-byte boundary without later stale output. | Stop on first beat, mid-block, rate boundary, post-boundary, and during a stall. | Stop-position x mode. | Pass |
| K-OUT-008 | P1 | A new operation after stop shall start from a clean state. | Stop continuous output, then run a KAT without global reset. | Stop position x recovery result. | Pass |
| K-OUT-009 | P2 | `stop_i` outside SQUEEZE and in fixed mode shall follow the agreed contract. | Pulse in every state and fixed mode; assertion or defined behavior check. | State x stop attempt. | Decision |
| K-OUT-010 | P1 | No output byte count may be illegal when `output_valid_o=1`. | SVA on every lane. | Assertion result. | Pass |

### 7.4 Parallel-wrapper requirements

| ID | P | Requirement | Stimulus and checker | Coverage/evidence | Baseline |
|---|---:|---|---|---|---|
| K-PAR-001 | P1 | Each lane shall produce the same result as a standalone core for identical input. | Same KAT on one lane and all lanes; per-lane scoreboard. | Lane ID x mode. | Partial |
| K-PAR-002 | P1 | Different modes, messages, and output lengths shall execute concurrently without cross-lane corruption. | Deliberately different transaction on every lane. | Active-lane count x mode mix. | Randomly partial |
| K-PAR-003 | P1 | Resetting one lane shall not alter another active lane. | Reset each lane while peers absorb, permute, and squeeze. | Reset lane x peer state. | Missing |
| K-PAR-004 | P1 | Backpressuring one lane shall not stall or alter another lane. | Independent randomized ready patterns. | Stalled lane x active-lane count. | Missing |
| K-PAR-005 | P1 | Stopping one continuous lane shall not stop or alter another lane. | Independent stop positions with mixed fixed/continuous lanes. | Stop lane x mode mix. | Missing |
| K-PAR-006 | P2 | Supported `N_LANES` configurations shall elaborate and preserve the same per-lane behavior. | Compile/run N=1 and N=4; optional N=2. | Configuration result. | N=1/4 historically run; hardcoded TB |

### 7.5 Unit and internal-control requirements

| ID | P | Requirement | Stimulus and checker | Coverage/evidence | Baseline |
|---|---:|---|---|---|---|
| K-UNIT-001 | P1 | Theta shall match FIPS 202 Section 3.2.1. | Directed plus random 1600-bit states against independent model. | Unit regression and code coverage. | Existing bench not in main regression |
| K-UNIT-002 | P1 | Rho shall apply every FIPS 202 rotation offset. | Walking-bit per lane plus random states. | All 25 lanes/offsets. | Existing bench not requalified |
| K-UNIT-003 | P1 | Pi shall map every source lane to the correct destination. | Lane-tagged state and random states. | All 25 source/destination mappings. | Existing bench not requalified |
| K-UNIT-004 | P1 | Chi shall match the nonlinear row transform for every row. | Structured all-zero/all-one/walking patterns plus random states. | Row/pattern coverage. | Existing bench not requalified |
| K-UNIT-005 | P1 | Iota shall XOR the correct round constant only into lane (0,0). | All 24 round indices and random states. | Round index 0..23. | Existing bench appears narrow |
| K-UNIT-006 | P1 | The two-phase round pipeline shall commit exactly one round every two clocks and complete 24 rounds in 48 phase clocks. | Internal assertion and known permutation states. | Round x phase; permutation-latency property. | Missing; comments stale |
| K-UNIT-007 | P1 | Absorb/padding shall never write outside the active rate portion of the state. | Boundary messages and internal assertions. | Mode x head/tail lane classes. | Partial unit bench |
| K-UNIT-008 | P1 | Squeeze shall select the correct state word, output byte count, completion, and re-permute point. | Word positions within both rates and boundary lengths. | Word index x mode x terminal class. | Partial unit bench; end-to-end boundaries pass |
| K-UNIT-009 | P2 | Every FSM state and legal transition shall be reached; illegal transitions shall never occur. | Cover properties plus reset/stop/backpressure scenarios. | State and transition coverage with reviewed waivers. | States 100%, transitions 100% |

### 7.6 Synthesis, post-fit, and hardware requirements

| ID | P | Requirement | Stimulus and checker | Evidence | Baseline |
|---|---:|---|---|---|---|
| K-IMP-001 | P1 | Stage 2 post-synthesis netlist shall match source RTL at the external interface. | KATs, all boundary tests, reset smoke, and fixed random seeds. | Stage 2 transcript with zero mismatches. | Pass |
| K-IMP-002 | P1 | Stage 3 post-fit netlist shall match source RTL at the external interface. | Focused KAT/boundary/reset/random regression. | Stage 3 transcript with zero mismatches. | Pass: 125/125 source and 125/125 fitted-netlist transactions; identical checked-record hash |
| K-IMP-003 | P1 | TimeQuest shall analyze every intended synchronous path under documented constraints. | `check_timing`, unconstrained-path report, and clock report. | Zero unexplained unconstrained setup paths. | Pass: Stage 3 setup/hold fully constrained at 50 MHz; separate one-round core closes 147 MHz with +0.010 ns worst setup and +0.168 ns worst hold. |
| K-IMP-004 | P1 | Mapping shall contain no unexplained optimized functional input, latch, truncation, or inferred memory/DSP. | Warning and resource-by-entity audit. | Signed mapping checklist. | Pass |
| K-IMP-005 | P1 | The benchmark build shall identify one core versus N-lane wrapper unambiguously. | Separate project revisions/configurations. | Top entity, parameters, ALMs, registers, Fmax, and throughput recorded together. | Partial: Stage 2 project explicitly builds one `keccak_core`; N-lane comparison remains open |
| K-IMP-006 | P1 | FPGA/UART output shall match the same KAT and random-vector checker used in simulation. | Board harness batches. | Commit, bitstream hash, UART log, seed, pass/fail count. | Board pending |

## 8. Planned Functional Coverage Model

Coverage shall describe successfully observed behavior, not requested stimulus. Bins are split at architectural boundaries and only meaningful crosses are retained.

| Coverpoint | Required bins |
|---|---|
| `cp_mode` | SHAKE128, SHAKE256 |
| `cp_msg_boundary` | 0; 1; 7/8/9; rate-1/rate/rate+1; 2rate-1/2rate/2rate+1; 3+ blocks, interpreted per mode |
| `cp_final_input_bytes` | 0 for empty, 1..8 for non-empty final beats |
| `cp_absorb_blocks` | 1, 2, 3, 4+ |
| `cp_output_kind` | fixed, continuous |
| `cp_output_boundary` | 1..8; rate-1/rate/rate+1; 2rate-1/2rate/2rate+1; maximum tested |
| `cp_final_output_bytes` | 1..8 |
| `cp_squeeze_blocks` | 1, 2, 3, 4+ |
| `cp_input_gap` | none, single-cycle, burst, random |
| `cp_output_stall` | none, single-cycle, burst, random |
| `cp_stall_position` | ordinary beat, final beat, rate-boundary beat |
| `cp_reset_state` | IDLE, ABSORB, SUFFIX_PADDING, PERMUTE phase A, PERMUTE phase B, SQUEEZE |
| `cp_stop_position` | first beat, mid-block, rate boundary, after re-permute, while stalled |
| `cp_lane_id` | every configured lane |
| `cp_active_lanes` | 1, 2, 3, all |
| `cp_latency_class` | expected no-stall latency, input-stalled, output-stalled, multi-block |
| `cp_back_to_back` | SHAKE128/256 prior-mode x next-mode transitions without reset |
| `cp_config_latch` | mode pin changed, length pin changed, both changed after start |
| `cp_reset_recovery` | recovery KAT after reset from each FSM state/phase without another reset |
| `cp_stop_recovery` | recovery KAT after each stop position without global reset |
| `cp_stall_equivalence` | stalled and unstalled result equivalence at ordinary/final/rate-boundary positions |
| `cp_lane_isolation` | peer reset, peer output stall, peer stop |
| `cp_mixed_lane_work` | independently checked mixed messages/modes/lengths on concurrent lanes |
| `cp_prefix_consistency` | shorter/longer output prefix checks within, across, and beyond one rate |
| `cp_byte_order_suite` | walking-byte and walking-bit suite passes |
| `cp_permutation_suite` | all Keccak steps and 24 rounds pass independent internal checks |

Required crosses:

- Mode x message boundary.
- Mode x output boundary.
- Mode x final input bytes.
- Mode x final output bytes.
- Output kind x squeeze-block count.
- Output stall class x stall position.
- Reset state x mode.
- Lane ID x mode.
- Active-lane count x mode mix.
- Reset-recovery state x mode.
- Stop-recovery position x mode.
- Lane-isolation kind x mode.

Do not cross every coverpoint. Uncontrolled cross products create bins with no requirement and make closure less meaningful.

### 8.1 Coverage exclusions

- Illegal byte counts and control combinations are assertion checks; they are not normal functional bins.
- Code generated inside UVM packages is excluded from DUT code-coverage goals.
- Constant configuration branches proven unreachable for the SHAKE-only build require written waivers.
- Toggle coverage is reviewed on architecturally relevant DUT state/control signals; it is not used as a standalone correctness claim.

## 9. Planned Assertions and Cover Properties

| ID | Property |
|---|---|
| K-A-001 | Input data and valid remain stable while input valid is high and ready is low. |
| K-A-002 | No input byte is counted without an input valid/ready handshake. |
| K-A-003 | Accepted input bytes never exceed the configured message length. |
| K-A-004 | `start_i` is a one-cycle pulse accepted only in IDLE under the selected contract. |
| K-A-005 | Configuration used internally remains equal to the configuration captured at start. |
| K-A-006 | Output data, byte count, and valid remain stable while output valid is high and ready is low. |
| K-A-007 | `done_o` without `stop_i` has a valid accepted bounded-output cause. |
| K-A-008 | A legal continuous stop produces `done_o` and returns the core to idle. |
| K-A-009 | `output_bytes_o` is in 1..8 whenever output valid is high. |
| K-A-010 | No output control or data is X/Z while output valid is high. |
| K-A-011 | `round_idx` remains in 0..23 and advances only after phase B. |
| K-A-012 | A permutation entering round 0 completes exactly 24 rounds / 48 phases later when not reset. |
| K-A-013 | State-array writes occur only from the selected valid source. |
| K-A-014 | Reset drives the FSM to IDLE and prevents stale valid output. |
| K-A-015 | Stop in continuous SQUEEZE returns to IDLE according to the documented latency. |
| K-A-016 | A completed fixed transaction produces exactly the configured number of accepted bytes. |
| K-A-017 | Per-lane reset, stop, input stall, and output stall cannot directly change peer-lane controls. |

Each temporal requirement should have an associated `cover property` where reaching the antecedent is meaningful. Assertion pass with a vacuous antecedent is not closure.

## 10. Planned Test Suite

| Test | Contents | Tier | Stages |
|---|---|---|---|
| `keccak_smoke_test` | Empty and short KAT for both modes, fixed output | Per commit | 1/2/3 |
| `keccak_existing_regression_test` | Preserve the current 52 cases per lane during infrastructure changes | Per commit initially | 1 |
| `keccak_nist_shortmsg_test` | Official byte-oriented message lengths 0..336 for SHAKE128 and 0..272 for SHAKE256 | Nightly/closure | 1; selected 2/3 |
| `keccak_nist_longmsg_test` | Official selected-long-message vectors | Closure | 1 |
| `keccak_nist_variableout_test` | Official variable-output vectors over declared supported lengths | Closure | 1; selected 2/3 |
| `keccak_nist_monte_test` | SHA3VS dependent Monte Carlo checkpoints | Slow closure | 1 |
| `keccak_rate_boundary_test` | Explicit input and output rate +/-1 and 2rate +/-1 cases | Per commit | 1/2/3 |
| `keccak_boundary_seq` | Every legal final input/output byte count and rate boundary | Per commit | 1/2/3 |
| `keccak_protocol_stress_seq` | Input gaps and output stalls by kind and position | Per commit | 1/2/3 |
| `keccak_continuous_stop_seq` | First-word, re-permute, multi-block, and stalled stop | Per commit | 1/2/3 |
| `keccak_concurrency_seq` | Observed one/two/three/four active lanes in both modes | Per commit | 1/2/3 |
| `keccak_input_gap_test` | None, single, burst, and random input gaps | Nightly | 1 |
| `keccak_output_backpressure_test` | Stalls on ordinary, final, and rate-boundary output beats | Per commit subset; nightly full | 1/2/3 subset |
| `keccak_back_to_back_test` | Mixed consecutive jobs without reset | Per commit | 1/2/3 |
| `keccak_abort_seq` | Reset in every observed FSM state/phase with visible idle/stale-output recovery checks | Per commit | 1; selected 2/3 |
| `keccak_continuous_stop_test` | Stop positions before and after squeeze boundaries | Nightly | 1 |
| `keccak_parallel_isolation_test` | Different per-lane work, asymmetric reset/backpressure/stop | Per commit subset; nightly full | 1 |
| `keccak_random_regression_test` | Reproducible constrained-random traffic with independent model | 20 seeds nightly; 100+ closure | 1 |
| `keccak_post_synth_test` | Focused KAT, boundary, reset, and fixed-seed suite | Build gate | 2 |
| `keccak_post_fit_test` | Smaller deterministic implementation smoke | Release gate | 3 |

Random tests complement requirements; they do not replace the official and directed suites. Every run records its seed even when it passes.

## 11. Regression and Evidence Rules

Every regression artifact shall record:

- Git commit and dirty/clean status.
- Branch and DUT top-level.
- Simulator or Quartus version.
- Test name and random seed.
- Lane count and relevant parameters.
- Passed, failed, timed out, and not-run counts.
- Scoreboard mismatch count and first mismatch.
- Assertion failures and non-vacuous cover-property results.
- Functional coverage by requirement-linked coverpoint.
- DUT-only code/FSM/toggle coverage.
- Exact UCDB and log paths.

Suggested evidence layout:

```text
verification/results/keccak/<commit>/<stage>/<run-id>/
  manifest.txt
  transcript.log
  summary.txt
  coverage.ucdb
  coverage.html
```

Generated evidence should normally be archived outside Git or through the project's artifact mechanism. The testplan stores links/identifiers, not large UCDB binaries.

## 12. Closure Criteria

Keccak is verification-complete only when:

- All P1 requirements have passing Stage 1 evidence.
- Every selected official NIST vector passes both modes as applicable.
- There are zero scoreboard mismatches, protocol errors, unexpected timeouts, and assertion failures.
- Functional coverage is sampled only from checked observed transactions.
- Every required functional bin and cover property is hit or has a reviewed waiver.
- Every DUT code/FSM hole is reviewed; unreachable logic has a written reason.
- FSM states and all required legal transitions, including reset recovery, are covered.
- Stage 2 and Stage 3 focused regressions pass.
- Quartus warnings, resources, constraints, and top-level configuration are audited.
- The FPGA/UART KAT and random batches pass when the board is available.
- Documentation reports source RTL, post-synthesis, post-fit, and FPGA evidence separately.

Code coverage is not averaged with functional or assertion coverage. A working review threshold may flag statement or branch coverage below 90%, but sign-off depends on the reviewed holes and requirements, not on forcing an arbitrary aggregate number.

## 13. Implementation Order

1. Resolve the five interface-contract questions in Section 3.1.
2. Preserve a pinned baseline run and correct the 12/20 test-count documentation.
3. Extend the observed transaction with protocol and timing facts.
4. Add a scoreboard `checked_ap` that publishes only fully passed transactions.
5. Connect functional coverage to `checked_ap` instead of `driver.drv_ap`.
6. Make monitor protocol errors and reset recovery part of scoreboard pass/fail.
7. Add the assertion interface and bind it to every lane.
8. Add back-to-back and observed reset-state tests; the complete mode-transition
   matrix, reset/no-reset recovery, boundary, byte-count, backpressure,
   concurrency, and stop/recovery suites now pass.
9. Import official NIST byte-oriented vector suites and add an independent reference path.
10. Add asymmetric parallel-lane tests; peer reset/stall/stop isolation now
    passes in both SHAKE modes.
11. Functional bins are closed; review and justify remaining Stage 1
    structural-code holes.
12. Stage 2 mapping and Stage 3 one-core post-fit regression are complete; review optional SDF scope with the supervisor.
13. Run the FPGA/UART suite after board bring-up.

## 14. First Implementation Task

The first code change is verification infrastructure, not RTL optimization:

- Add observed fields and `protocol_ok`/`data_ok`/`passed` status to `keccak_transaction` or a dedicated checked-result item.
- Have the monitor reconstruct accepted input and output transfers, including gap/stall/reset/stop metadata.
- Have the scoreboard compare the observed transaction, set pass status, and publish it through `checked_ap` only on complete success.
- Connect `keccak_coverage` to `scoreboard.checked_ap`.
- Preserve the original checked workload while extending it; the current clean regression passes all 728 checked transactions.

This change makes every future coverage bin trustworthy. Adding more coverpoints before this repair would only make the existing sampling error larger.

## 15. First Implementation Result - 2026-07-26

Status: **implemented and regression-tested on `1_hashing`**.

The implementation was made in an isolated worktree based on commit `a90c2e2` so the active NTT worktree and its uncommitted files were not changed.

### 15.1 Changes completed

- `keccak_transaction` now carries monitor-observed input, output, control, gap/stall, reset/stop, protocol, data, and final pass status.
- `keccak_monitor` reconstructs the message only from accepted
  `input_valid_i && input_ready_o` transfers. It captures mode and lengths from
  the observed start and checks accepted byte counts, output data,
  `output_bytes_o`, `done_o`, stop, stalls, and active-lane count.
- `keccak_scoreboard` checks observed control, complete accepted input, exact output length/data, and protocol status. It publishes `checked_ap` only when all checks pass.
- `keccak_coverage` now samples `scoreboard.checked_ap`; the previous driver-to-coverage connection was removed.
- `sim/run.do` now works when the `work` library is initially absent and registers `coverage save -onexit` before UVM can call `$finish`.

### 15.2 Regression evidence

Command run from `sim/`:

```text
vsim -c -do "do run.do; quit -f"
```

Result:

| Evidence | Result |
|---|---:|
| Compile errors | 0 |
| UVM errors | 0 |
| UVM fatals | 0 |
| Lane 0 scoreboard | 52/52 passed |
| Lane 1 scoreboard | 52/52 passed |
| Lane 2 scoreboard | 52/52 passed |
| Lane 3 scoreboard | 52/52 passed |
| Total data/protocol checked transactions | 208/208 passed |
| Existing functional bins | 32/32 hit (100%) |

The 100% figure is now based on passed observed transactions, but it still describes only the existing 32 broad bins. It is not a claim of complete Keccak verification.

### 15.3 Structural coverage evidence

The UCDB was saved successfully. The all-compiled-scope total is 80.36%, but that number includes RTL, interfaces, UVM classes, and packages and must not be presented as DUT coverage.

`keccak_core` design-unit results:

| Metric | Hit/total | Coverage |
|---|---:|---:|
| Branches | 73/75 | 97.33% |
| Conditions | 13/15 | 86.66% |
| Expressions | 5/5 | 100.00% |
| FSM states | 5/5 | 100.00% |
| FSM transitions | 8/11 | 72.72% |
| Statements | 102/108 | 94.44% |
| Toggles | 17163/17409 | 98.58% |
| Weighted core total | - | 92.82% |

The complete `/tb_top/dut` hierarchy reports 92.54% total. These results explain why the supervisor challenged the original presentation: 100% was a small functional model, while important structural and requirement coverage remains open.

### 15.4 Remaining gaps

The next implementation work is still required before Stage 1 closure:

- Replace the 32-bin model with the requirement-driven coverpoints and crosses in this testplan.
- Extend the passing protocol assertions with internal reset-phase binding and
  round/permutation latency properties.
- Add deliberate input gaps, output backpressure, back-to-back requests, active-state reset, stop timing, exact rate-boundary, and asymmetric-lane tests.
- Add an independent official-vector path and complete coverage-hole review with written waivers where necessary.

## 16. Current Stage 1 Evidence - 2026-09-12

The active `1_hashing` working tree now uses the protocol-neutral Keccak
interface and the 281-bin expanded P1 functional model. The full four-lane run
completed with 888/888 scoreboard passes, zero UVM warnings/errors/fatals,
zero simulator errors, and
100.00% functional covergroup coverage (281/281 bins). Every coverpoint and
cross is weighted by its number of requirement bins, so small coverpoints do
not receive disproportionate influence.

That covergroup number is not Keccak verification completion. Counting testplan
rows whose status is exactly `Pass`, source-RTL P1 closure is 14/44 (31.82%).
Including the six post-synthesis, post-fit, timing, mapping, and FPGA P1 rows,
overall planned P1 closure is 18/50 (36.00%). Partial, caveated, missing, and
decision-pending rows receive no closure credit.

Reset is no longer credited by a test label or delay. Verification-only
hierarchy observation exposes the current FSM state and permutation phase to
the testbench. The driver waits for the requested observed phase, the top-level
captures that phase immediately before asynchronous reset, and the monitor and
scoreboard require an exact target match plus idle/no-stale-output recovery.
All six phases were reached in both SHAKE modes on every lane:

- IDLE.
- ABSORB.
- SUFFIX_PADDING.
- PERMUTE phase A.
- PERMUTE phase B.
- SQUEEZE.

The reset-state coverpoint is 6/6 and reset-state x mode is 12/12. Source-RTL
FSM state coverage is 20/20 and transition coverage is 44/44 across four cores;
one `keccak_core` instance reports 5/5 states and 11/11 transitions. Assertions
are 32/32 with zero failures, and cover directives are 20/24.

Configuration latching is checked by changing mode, output length, or both
after the observed start while the scoreboard still requires the result for the
start-time configuration. Reset and stop recovery use predecessor evidence: an
abort/stop result creates a lane-local pending token, and only the immediately
following golden-checked transaction can close the recovery bin when it starts
without another global reset. The reset-recovery bins are 6/6 with their 12/12
mode cross; stop position and stop recovery are 5/5, with the recovery mode
cross at 10/10.

The final 22 functional bins were closed by independently checked scenarios:

- Back-to-back mode transitions without reset: 4.
- Stalled-versus-unstalled equivalence: 3.
- Asymmetric peer-lane reset/stall/stop isolation: 3.
- Independently checked mixed-lane work: 1.
- Shorter/longer output prefix consistency: 3.
- Walking-byte/bit ordering suite: 1.
- Independent all-step/all-round permutation suite: 1.
- Lane-isolation scenario x SHAKE mode: 6.

Broader independent NIST vectors, additional internal pipeline assertions, and
review of non-FSM code-coverage holes remain. The 100.00% number is therefore a
reproducible result for this fixed covergroup, not a target-shaped percentage
and not a complete-design claim. Two additional valid-during-input-backpressure
cases per full sequence now pass in the complete 888-transaction QuestaSim
2024.1 regression with zero assertion, UVM, and simulator errors.

## 17. Stage 2 Post-Synthesis Evidence - 2026-09-12

The one-core Stage 2 flow is implemented and reproducible. Quartus Analysis and
Synthesis generated a Cyclone V technology-mapped functional Verilog netlist
for `keccak_synth_top`. The existing port-level UVM driver, monitor, scoreboard,
reference model, and coverage subscriber were then run first against source RTL
and then against that generated netlist with seed `20260909`.

| Evidence | Source RTL | Post-synthesis netlist |
|---|---:|---:|
| Checked transactions | 125/125 passed | 125/125 passed |
| UVM errors/fatals | 0/0 | 0/0 |
| Checked-record SHA-256 | `726C5025...2BC54C` | `726C5025...2BC54C` |
| Focused-suite functional bins | 201/281 (71.53%) | 201/281 (71.53%) |

The matching checked-record hash proves that the two DUT representations
produced the same externally checked results for this fixed regression. The
71.53% covergroup result is only the coverage reached by the smaller Stage 2
suite; it neither replaces nor lowers the 100.00% full Stage 1 result.

The suite covers known-answer/directed cases, both SHAKE modes, exact rate
boundaries, output boundaries, configuration latching, stop and recovery,
protocol stress, and fixed-seed random cases. It intentionally does not claim
internal FSM/round coverage because synthesis changes that hierarchy. Active
state reset coverage remains Stage 1 evidence.

After warning cleanup, synthesis completed with 0 errors and 0 warnings. The
result estimates 3,501 ALMs, contains 3,274 registers, uses no DSP blocks or
block memory, and has 174 virtual pins plus the real clock pin. The 17 removed
registers were reviewed: 15 are rate/suffix bits whose values are constant in
both supported SHAKE modes, and two are Quartus-generated one-hot FSM nodes
that lost all fanout. No truncation, latch, ignored-input, memory, or DSP issue
remains unexplained, so `K-IMP-004` passes.

Post-map TimeQuest found zero unconstrained clocks, input/output ports, or
input/output paths. The 20 ns setup requirement passes in the pre-fit estimate
with +1.757 ns worst slow-corner setup slack. Pre-fit hold is negative because
routing has not occurred; it is not used for sign-off. The fitted Stage 3 flow
provides the authoritative hold result.

Full details and reproduction steps are in
[KECCAK_STAGE2_SYNTHESIS_REPORT.md](KECCAK_STAGE2_SYNTHESIS_REPORT.md).

## 18. Stage 3 Post-Fit Evidence - 2026-09-12

The reproducible Stage 3 flow completed fitting, post-fit TimeQuest, fitted
functional-netlist generation, and source-versus-fitted UVM comparison.

| Evidence | Result |
|---|---:|
| Source RTL | 125/125 passed |
| Post-fit netlist | 125/125 passed |
| UVM errors/fatals | 0/0 in both runs |
| Checked-record hash | Identical: `726C5025...2BC54C` |
| Focused functional coverage | 201/281 (71.53%) in both runs |
| 50 MHz setup/hold | Pass; fully constrained |
| Worst slow-corner setup slack | +5.037 ns |
| Worst hold slack across corners | +0.169 ns |
| Conservative slow-corner Fmax | 66.83 MHz |
| Fitted ALMs/registers | 3,903 / 1,979 |
| DSP/memory | 0 / 0 |

The fitted netlist contains physical Cyclone V locations and global-clock
cells; it is not the Stage 2 mapped model relabeled. Fitter warnings are limited
to the LogicLock license and the intentionally absent board clock-pin/I/O
assignments. The latter must be resolved in the separate board project.

This closes `K-IMP-002` and `K-IMP-003` for the documented one-core module
benchmark. It does not close the N-lane comparison, FPGA/UART test, remaining
Stage 1 holes, or optional SDF timing-simulation decision. Full evidence is in
[KECCAK_STAGE3_POSTFIT_REPORT.md](KECCAK_STAGE3_POSTFIT_REPORT.md).

## 19. Timing Optimization Evidence - 2026-09-12

The dedicated direct-core performance project implements one full round per
clock and closes its 6.803 ns, or 147 MHz, constraint. Worst setup slack is
+0.010 ns and worst hold slack is +0.168 ns across all reported corners. The
performance fit uses 4,265 ALMs, 1,674 registers, no DSP blocks, and no block
memory. A 150 MHz run with -0.057 ns setup slack was rejected. The full
888-transaction source regression and refreshed Stage 2 and Stage 3 netlist
comparisons all pass after the architectural change. Full details are in
[KECCAK_TIMING_OPTIMIZATION_REPORT.md](KECCAK_TIMING_OPTIMIZATION_REPORT.md).
