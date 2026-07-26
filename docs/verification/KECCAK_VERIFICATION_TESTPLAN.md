# Keccak/SHAKE Requirements-to-Verification Testplan

**Project:** ML-DSA hardware accelerator  
**DUT branch:** `1_hashing`  
**Audited branch head:** `a90c2e2`  
**Target DUTs:** `keccak_core` and `keccak_engine_parallel`  
**Target device:** Cyclone V `5CGXFC7C7F23C8`  
**Status:** Initial baseline and closure plan  
**Date:** 2026-07-26

## 1. Purpose

This document is the sign-off contract for the Keccak/SHAKE block. It replaces the claim "100% coverage" with traceable evidence for each requirement:

1. What behavior is required.
2. How the behavior is stimulated.
3. How the result is checked.
4. How execution is measured.
5. At which design representation it is rerun.
6. What evidence is required before closure.

The current design is a useful baseline, but it is not yet verification-complete. New performance optimization is frozen until all P1 requirements in this plan either pass or receive a reviewed waiver.

## 2. Authoritative Sources

| Source | Use |
|---|---|
| [FIPS 202](../FIPS/nist.fips.202.pdf) Sections 3, 4, 5, and 6.2 | Keccak-f[1600], sponge, pad10*1, SHAKE128, and SHAKE256 behavior |
| [NIST SHA-3 Validation System](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/sha3/sha3vs.pdf) Section 6.3 | Short-message, long-message, Monte Carlo, and variable-output test families |
| [NIST CAVP secure hashing vectors](https://csrc.nist.gov/Projects/Cryptographic-Algorithm-Validation-Program/Secure-Hashing) | Independent SHAKE response files and validation-oriented vectors |
| [Coverage Cookbook](../coverage-cookbook.pdf) | Requirements-driven coverage, testplan fields, datapath coverage, and coverage closure methodology |
| `1_hashing:src/keccak_engine/*.sv` | Implemented architecture and interface behavior |
| `1_hashing:tb_uvm/tb_uvm_keccak_v2/*.sv` | Existing UVM stimulus, monitoring, checking, and coverage |
| `1_hashing:docs/keccak_docs/keccak-design-and-verification.md` | Design intent, historical decisions, and reported results |

The pure-SystemVerilog model is useful, but it is not the sole authority because it shares language, constants, and implementation assumptions with the RTL. Official NIST vectors and an independent implementation such as Python `hashlib.shake_128`/`shake_256` must anchor the results.

## 3. Verification Scope and Proposed Contract

The verification target is the arithmetic core with a small ready/valid interface. The signal names may retain `s_axis_*` and `m_axis_*` temporarily, but this plan does not claim AXI4-Stream protocol compliance.

| Item | Contract to verify |
|---|---|
| Algorithms | Byte-oriented SHAKE128 and SHAKE256 only |
| Permutation | Keccak-f[1600], 24 rounds |
| Input width | 64 bits / 8 bytes per accepted beat |
| Input framing | `tlast` marks the final accepted beat; `tkeep` is full on non-final beats and contiguous from bit 0 on the final beat |
| Empty message | One accepted beat with `tlast=1` and `tkeep=0` |
| SHAKE128 | Capacity 256 bits, rate 1344 bits / 168 bytes |
| SHAKE256 | Capacity 512 bits, rate 1088 bits / 136 bytes |
| Domain separation | SHAKE suffix `1111`, represented by effective byte `0x1f` with multi-rate padding |
| Fixed output | `xof_len_i` is a byte count from 1 through 65,535; final beat uses `tlast` and a contiguous `tkeep` |
| Continuous output | `xof_len_i=0`; output continues until `stop_i`, with no `tlast` |
| Input transfer | Occurs only when `s_axis_tvalid && s_axis_tready` |
| Output transfer | Occurs only when `m_axis_tvalid && m_axis_tready` |
| Configuration | Mode and output length are sampled on a one-cycle `start_i` pulse in IDLE |
| Reset | Active-high asynchronous reset aborts work and returns the visible interface to idle |
| Stop | Sampled only in SQUEEZE; it terminates continuous output without creating a final `tlast` beat |
| Parallel wrapper | Lanes share only the clock; reset, control, input, state, and output behavior are independent |

### 3.1 Contract questions to resolve before RTL changes

- Confirm that only contiguous low-order `tkeep` masks are legal.
- Confirm whether mode and length may change after `start_i`; the proposed contract says they are latched and later changes have no effect.
- Confirm whether `start_i` while busy is illegal and assertion-only, or must receive a defined response.
- Confirm whether `stop_i` in fixed-length mode is legal or illegal.
- Confirm the minimum supported fixed output length. The RTL supports one byte, so the supported range must be declared and tested explicitly.

These are specification questions, not coverage holes. They must be decided before illegal bins or assertions are written.

## 4. Audited Baseline

The baseline below describes the checked-in UVM implementation and the existing `sim/keccak_cov.ucdb`. The UCDB must be regenerated from a pinned commit before it is accepted as formal evidence.

| Area | Audited result | Status |
|---|---|---|
| Active UVM workload | 52 transactions per lane: 12 directed, 20 stress, and 20 deterministic closure items | Implemented |
| Four-lane workload | Source and historical reports describe 208 requested and data-compared transactions | Must rerun on pinned commit |
| Documentation count | Existing comments/docs say 13 directed + 19 closure; source implements 12 + 20 | Must correct |
| Golden checking | Observed output bytes are compared against `exp_hex`; random expected values come from the pure-SV model | Partial independence |
| Official vectors | A small hardcoded subset is present; full NIST CAVP suites are not imported | Partial |
| Functional coverage | One covergroup type, 32/32 bins hit | Too narrow |
| Coverage sampling | Coverage subscribes to `driver.drv_ap` and samples before the DUT executes | Incorrect |
| Code coverage | UCDB total: 86.29% filtered; this includes DUT, testbench, and packages | Must separate |
| FSM coverage | States 100%; transitions 72.72% | Open holes |
| Assertions | No `assert property` or `cover property` exists | Missing |
| Input timing | Driver presents beats without randomized valid gaps | Missing |
| Output timing | Monitor holds `m_axis_tready=1` throughout collection | Missing |
| Transaction separation | Driver resets the DUT before every transaction | Hides back-to-back behavior |
| Mid-operation reset | Abort sequence exists but is disabled due to deadlock | Missing |
| Abort checking | Scoreboard automatically counts abort transactions as passed without checking recovery | Incorrect |
| Parallel isolation | Four lanes run concurrently, but asymmetric reset/stall/stop behavior is not deliberately exercised | Partial |
| Legacy unit benches | Several are not in `sim/run.do`; `keccak_core_tb.sv` still references removed SHA3 modes | Stale until requalified |
| RTL documentation | `keccak_core.sv` header still claims one-cycle rounds/24-cycle permutation; implementation uses two phases/48 cycles | Must correct |

### 4.1 Meaning of the current 100%

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
- `tkeep`, `tlast`, ordering, and transfer counts were correct.
- No timeout, unknown value, assertion failure, or protocol error occurred.

The checked transaction must contain observed facts such as accepted message bytes, output bytes, final keep count, absorb-block count, squeeze-block count, input-gap class, output-stall class, stop position, reset state, lane ID, and measured latency.

## 5. Verification Stages

| Stage | DUT representation | Regression scope | Primary evidence |
|---|---|---|---|
| 1 | Hand-written source RTL | Full UVM, assertions, functional coverage, DUT code/FSM/toggle coverage | UCDB, logs, requirement closure |
| 2 | Quartus post-synthesis functional netlist | KATs, boundary tests, reset, protocol smoke, selected random seeds | Zero mismatches; synthesis warnings reviewed |
| 3 | Quartus post-fit netlist | KATs, boundary tests, reset, focused random smoke | Zero mismatches; Fitter and TimeQuest reports |
| FPGA | Board image with UART harness | KATs and reproducible random batches | UART logs, bitstream/build identity |

The same interface-level monitor, golden checker, and vectors should be reused. Internal RTL assertions and hierarchy coverage are Stage 1 evidence and may not survive synthesis.

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
| K-ALG-007 | P1 | Every final input byte count 1..8 shall be absorbed in byte order with the correct contiguous keep mask. | Messages whose length modulo 8 is 1..7 and 0; independent output comparison. | Mode x final-byte-count bins 1..8. | Random only, not explicit |
| K-ALG-008 | P1 | Padding shall be correct immediately before, exactly at, and immediately after each rate boundary. | SHAKE128 lengths 167/168/169 and 335/336/337; SHAKE256 lengths 135/136/137 and 271/272/273. | Mode x boundary-position. | Missing |
| K-ALG-009 | P1 | Multi-block absorption shall preserve every input byte and permute between full rate blocks. | Official short-message suite 0..2x rate, selected long vectors, and random 3+ block messages. | Absorb-block count 1/2/3/4+. | Partial |
| K-ALG-010 | P1 | Fixed output shall return exactly `xof_len_i` bytes and no extra accepted beat. | Lengths 1..17, rate-1/rate/rate+1, 2x rate boundaries, and max supported length. | Mode x final-output-byte-count; squeeze blocks. | Partial |
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
| K-IN-002 | P1 | Mode and fixed output length shall be sampled at start and remain effective for the transaction. | Change input pins after start; compare against originally selected configuration. | Mode x post-start-pin-change. | Missing/decision |
| K-IN-003 | P1 | Input data shall be consumed only on `valid && ready`. | Insert zero, one, burst, and random valid gaps; compare accepted bytes and output. | Input-gap class x mode. | Missing |
| K-IN-004 | P1 | While `valid=1 && ready=0`, the source shall hold input data, keep, and last stable. | Driver creates legal stalls; interface assertion checks source behavior. | Sink-stall cover property. | Missing |
| K-IN-005 | P1 | Non-final beats shall use `tkeep=8'hff`; the final beat shall use empty or contiguous low-order valid bytes. | All legal final masks; protocol assertion. | Final keep bins 0..8. | Partial |
| K-IN-006 | P1 | `tlast` shall affect the message only when its beat is accepted. | Hold final beat while not ready and vary unrelated cycles; accepted-stream reconstruction. | Last-under-stall cover property. | Missing |
| K-IN-007 | P1 | Consecutive transactions shall work without applying global reset between them. | Alternating modes, lengths, and messages back-to-back. | Prior mode x next mode; no-reset transition. | Missing |
| K-IN-008 | P1 | Asynchronous reset in IDLE, ABSORB, SUFFIX_PADDING, PERMUTE, and SQUEEZE shall cancel work and return the interface to idle without stale output. | State-targeted reset sequence plus recovery KAT. | Reset-state bins and reset-state x mode. | Missing; prototype disabled |
| K-IN-009 | P1 | A transaction after mid-operation reset shall produce the same output as from a clean power-on reset. | Abort each state, then run a KAT without another reset. | Reset state x recovery result. | Missing |
| K-IN-010 | P2 | Illegal `start_i` while busy shall follow the agreed contract. | Attempt in every active state; assertion or defined response check. | Busy state x start attempt. | Decision |
| K-IN-011 | P2 | Unknown control values shall not be accepted or emitted as valid behavior. | Assertions on controls and outputs when valid. | Assertion pass/fail, not a covergroup goal. | Missing |

### 7.3 Output and stop requirements

| ID | P | Requirement | Stimulus and checker | Coverage/evidence | Baseline |
|---|---:|---|---|---|---|
| K-OUT-001 | P1 | Output data shall transfer only on `m_axis_tvalid && m_axis_tready`. | Random output backpressure; reconstruct accepted output stream. | Stall class x mode x output kind. | Missing |
| K-OUT-002 | P1 | Data, keep, last, and valid shall remain stable while valid is asserted and ready is low. | One-cycle, burst, and random stalls on ordinary/final/rate-boundary beats. | Stall-position bins; stability assertion. | Missing |
| K-OUT-003 | P1 | Every fixed-length non-final beat shall carry eight valid bytes. | Fixed outputs spanning partial, full, and multiple beats. | Output beat type. | Partial |
| K-OUT-004 | P1 | The final fixed-length beat shall assert `tlast` with the exact contiguous keep mask. | Output lengths modulo 8 = 1..7 and 0. | Mode x final-byte-count 1..8. | Partial, not explicit |
| K-OUT-005 | P1 | Continuous mode shall never assert `tlast`. | Continuous outputs shorter than, equal to, and longer than one rate block. | Mode x continuous x squeeze-block count. | Implemented check; resample after pass |
| K-OUT-006 | P1 | Backpressure shall not duplicate, drop, reorder, or alter bytes. | Compare stalled and unstalled runs of identical transactions. | Stall-duration and stall-position crosses. | Missing |
| K-OUT-007 | P1 | `stop_i` shall terminate continuous output at the specified accepted-byte boundary without later stale output. | Stop on first beat, mid-block, rate boundary, post-boundary, and during a stall. | Stop-position x mode. | Partial: one monitor-driven position |
| K-OUT-008 | P1 | A new operation after stop shall start from a clean state. | Stop continuous output, then run a KAT without global reset. | Stop position x recovery result. | Missing |
| K-OUT-009 | P2 | `stop_i` outside SQUEEZE and in fixed mode shall follow the agreed contract. | Pulse in every state and fixed mode; assertion or defined behavior check. | State x stop attempt. | Decision |
| K-OUT-010 | P1 | No output control or data bit may be unknown when `m_axis_tvalid=1`. | SVA on every lane. | Assertion result. | Missing |

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
| K-UNIT-008 | P1 | Squeeze shall select the correct state word, keep mask, last flag, and re-permute point. | Exhaustive word index within both rates and boundary lengths. | Word index x mode x terminal class. | Partial unit bench |
| K-UNIT-009 | P2 | Every FSM state and legal transition shall be reached; illegal transitions shall never occur. | Cover properties plus reset/stop/backpressure scenarios. | State and transition coverage with reviewed waivers. | States 100%, transitions 72.72% |

### 7.6 Synthesis, post-fit, and hardware requirements

| ID | P | Requirement | Stimulus and checker | Evidence | Baseline |
|---|---:|---|---|---|---|
| K-IMP-001 | P1 | Stage 2 post-synthesis netlist shall match source RTL at the external interface. | KATs, all boundary tests, reset smoke, and fixed random seeds. | Stage 2 transcript with zero mismatches. | Missing |
| K-IMP-002 | P1 | Stage 3 post-fit netlist shall match source RTL at the external interface. | Focused KAT/boundary/reset/random regression. | Stage 3 transcript with zero mismatches. | Missing |
| K-IMP-003 | P1 | TimeQuest shall analyze every intended synchronous path under documented constraints. | `check_timing`, unconstrained-path report, and clock report. | Zero unexplained unconstrained setup paths. | Missing; I/O currently false-pathed |
| K-IMP-004 | P1 | Mapping shall contain no unexplained optimized functional input, latch, truncation, or inferred memory/DSP. | Warning and resource-by-entity audit. | Signed mapping checklist. | Open warnings |
| K-IMP-005 | P1 | The benchmark build shall identify one core versus N-lane wrapper unambiguously. | Separate project revisions/configurations. | Top entity, parameters, ALMs, registers, Fmax, and throughput recorded together. | Current slide mislabeled |
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

Do not cross every coverpoint. Uncontrolled cross products create bins with no requirement and make closure less meaningful.

### 8.1 Coverage exclusions

- Illegal input keep patterns are assertion checks after the legal-pattern decision; they are not normal functional bins.
- Code generated inside UVM packages is excluded from DUT code-coverage goals.
- Constant configuration branches proven unreachable for the SHAKE-only build require written waivers.
- Toggle coverage is reviewed on architecturally relevant DUT state/control signals; it is not used as a standalone correctness claim.

## 9. Planned Assertions and Cover Properties

| ID | Property |
|---|---|
| K-A-001 | Input data, keep, and last remain stable while input valid is high and ready is low. |
| K-A-002 | No input byte is counted without an input valid/ready handshake. |
| K-A-003 | Legal non-final input beats have full keep; legal final keep is empty or contiguous from bit 0. |
| K-A-004 | `start_i` is a one-cycle pulse accepted only in IDLE under the selected contract. |
| K-A-005 | Configuration used internally remains equal to the configuration captured at start. |
| K-A-006 | Output data, keep, last, and valid remain stable while output valid is high and ready is low. |
| K-A-007 | `m_axis_tlast` implies `m_axis_tvalid`, fixed mode, and the final fixed-output transfer. |
| K-A-008 | Continuous mode never asserts `m_axis_tlast`. |
| K-A-009 | Output keep is nonzero and contiguous whenever output valid is high. |
| K-A-010 | No output control or data is X/Z while output valid is high. |
| K-A-011 | `round_idx` remains in 0..23 and advances only after phase B. |
| K-A-012 | A permutation entering round 0 completes exactly 24 rounds / 48 phases later when not reset. |
| K-A-013 | State-array writes occur only from the selected valid source. |
| K-A-014 | Reset drives the FSM to IDLE and prevents stale valid output. |
| K-A-015 | Stop in continuous SQUEEZE returns to IDLE according to the documented latency. |
| K-A-016 | A completed fixed transaction produces exactly one accepted last beat. |
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
| `keccak_final_keep_test` | Every legal final input/output byte count | Per commit | 1/2/3 |
| `keccak_input_gap_test` | None, single, burst, and random input gaps | Nightly | 1 |
| `keccak_output_backpressure_test` | Stalls on ordinary, final, and rate-boundary output beats | Per commit subset; nightly full | 1/2/3 subset |
| `keccak_back_to_back_test` | Mixed consecutive jobs without reset | Per commit | 1/2/3 |
| `keccak_reset_state_test` | Reset in every FSM state/phase, followed by recovery KAT | Per commit | 1/2/3 |
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
8. Add explicit rate-boundary, final-keep, backpressure, back-to-back, reset, and stop tests.
9. Import official NIST byte-oriented vector suites and add an independent reference path.
10. Add asymmetric parallel-lane tests.
11. Close and review Stage 1 coverage holes.
12. Build and run Stage 2 and Stage 3 netlist regressions.
13. Run the FPGA/UART suite after board bring-up.

## 14. First Implementation Task

The first code change is verification infrastructure, not RTL optimization:

- Add observed fields and `protocol_ok`/`data_ok`/`passed` status to `keccak_transaction` or a dedicated checked-result item.
- Have the monitor reconstruct accepted input and output transfers, including gap/stall/reset/stop metadata.
- Have the scoreboard compare the observed transaction, set pass status, and publish it through `checked_ap` only on complete success.
- Connect `keccak_coverage` to `scoreboard.checked_ap`.
- Keep the existing 52-case-per-lane workload unchanged during this refactor and prove that all 208 data comparisons still pass.

This change makes every future coverage bin trustworthy. Adding more coverpoints before this repair would only make the existing sampling error larger.

## 15. First Implementation Result - 2026-07-26

Status: **implemented and regression-tested on `1_hashing`**.

The implementation was made in an isolated worktree based on commit `a90c2e2` so the active NTT worktree and its uncommitted files were not changed.

### 15.1 Changes completed

- `keccak_transaction` now carries monitor-observed input, output, control, gap/stall, reset/stop, protocol, data, and final pass status.
- `keccak_monitor` reconstructs the message only from accepted `s_axis_tvalid && s_axis_tready` transfers. It captures mode and XOF length from the observed start transaction and checks input/output `tkeep` and `tlast` behavior.
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
- Add protocol assertions and assertion coverage for start, input/output stability, keep/last legality, reset, bounded output, and continuous stop.
- Add deliberate input gaps, output backpressure, back-to-back requests, active-state reset, stop timing, exact rate-boundary, and asymmetric-lane tests.
- Add an independent official-vector path and complete coverage-hole review with written waivers where necessary.
