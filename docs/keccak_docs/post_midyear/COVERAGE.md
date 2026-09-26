# Keccak Coverage and Test Inventory

This document describes the current source-RTL verification model for the
single-core Keccak engine and the dual-core interleaved wrapper. Functional
coverage is sampled only after the corresponding output and protocol behavior
have passed checking. A hit therefore means that a behavior was observed and
verified, not merely requested by a sequence.

**Evidence status (2026-09-27):** The percentages and test counts below
are the last recorded source-RTL regression, not a new run from this
documentation audit. The integrated dual DUT is the primary code-coverage
scope. Its Stage 2/3 netlist simulations remain pending.

## 1. Coverage Model

### Coverage flow

The complete source-RTL run uses three complementary mechanisms:

- **Scoreboards and reference models:** compare every produced byte with a
  trusted expected SHAKE result and check protocol observations.
- **Functional coverage:** records which specified operating modes, boundary
  cases, disturbances, and combinations were successfully verified.
- **Structural code coverage:** Questa records which RTL statements, branches,
  conditions, expressions, FSM paths, and signal toggles executed.
- **Assertions:** continuously check interface rules and independently validate
  every Keccak permutation step and round.

There are three functional covergroups in
`tb_uvm/tb_uvm_keccak_v2/keccak_coverage.sv`:

| Covergroup | Scope |
|---|---|
| `cg_keccak` | Detailed behavior of a single Keccak core, instantiated once for each UVM lane |
| `cg_dual_core` | Behavior of each physical core as used through the dual-core wrapper |
| `cg_dual_interleaved` | Dispatch, spacing, arbitration, stalls, reset, stop, and recovery behavior of the wrapper |

### `cg_keccak`: detailed single-core coverpoints

| Coverpoint | What it proves was checked |
|---|---|
| `cp_mode` | Both SHAKE128 and SHAKE256 |
| `cp_msg_boundary` | Empty, one-byte, 7/8/9-byte, rate-1/rate/rate+1, two-rate boundaries, and three-or-more-rate messages |
| `cp_final_input_bytes` | Every legal final 64-bit input-beat size from 1 to 8 bytes, plus an empty message |
| `cp_absorb_blocks` | One, two, three, and four-or-more absorb blocks |
| `cp_output_kind` | Bounded output and continuous output terminated by `stop` |
| `cp_output_boundary` | Output sizes 1 through 8, rate boundaries, two-rate boundaries, and the 600-byte maximum regression case |
| `cp_final_output_bytes` | Every legal final output-byte count from 1 to 8 bytes |
| `cp_squeeze_blocks` | One, two, three, and four-or-more squeeze blocks |
| `cp_input_gap` | No input gap, one-cycle gap, burst gaps, and random gaps |
| `cp_output_stall` | No stall, one-cycle stall, burst stalls, and random stalls |
| `cp_stall_position` | Backpressure during an ordinary beat, final beat, or rate-boundary beat |
| `cp_reset_state` | Reset from idle, absorb, suffix padding, either permutation phase, and squeeze |
| `cp_stop_position` | Continuous-mode stop on first output, mid-block, rate boundary, after re-permutation, and while stalled |
| `cp_active_lanes` | One active lane and both lanes active |
| `cp_latency_class` | Unstalled, input-stalled, output-stalled, and multiblock transactions |
| `cp_back_to_back` | 128-to-128, 128-to-256, 256-to-128, and 256-to-256 mode transitions |
| `cp_config_latch` | Mode pin, output-length pin, or both pins changed after start while the accepted configuration remains effective |
| `cp_reset_recovery` | A valid golden-checked transaction after reset from each internal phase |
| `cp_stop_recovery` | A valid golden-checked transaction after each stop position |
| `cp_stall_equivalence` | Stalled and unstalled runs produce identical bytes at ordinary, final, and rate-boundary stalls |
| `cp_lane_isolation` | One lane remains correct while its peer is reset, stalled, or stopped |
| `cp_mixed_lane_work` | Both lanes simultaneously process different messages, modes, and output sizes |
| `cp_prefix_consistency` | A short XOF is a prefix of a longer XOF within one rate block, across a rate boundary, and across multiple rates |
| `cp_byte_order_suite` | Walking-bit and walking-byte cases confirm byte and bit ordering |
| `cp_permutation_suite` | The independent checker passed all five Keccak steps across all 24 rounds |

### `cg_keccak`: crosses

Cross coverage asks whether important conditions were verified together rather
than only separately.

| Cross | Combination checked |
|---|---|
| `cross_mode_msg` | SHAKE mode x message boundary |
| `cross_mode_output` | SHAKE mode x output boundary |
| `cross_mode_final_input` | SHAKE mode x final input-beat size |
| `cross_mode_final_output` | SHAKE mode x final output-beat size |
| `cross_kind_squeeze` | Bounded/continuous output x squeeze depth |
| `cross_mode_absorb_blocks` | SHAKE mode x absorb depth |
| `cross_mode_squeeze_blocks` | SHAKE mode x squeeze depth |
| `cross_mode_input_gap` | SHAKE mode x input-gap pattern |
| `cross_mode_output_stall` | SHAKE mode x output-stall pattern |
| `cross_mode_latency` | SHAKE mode x latency class |
| `cross_mode_output_kind` | SHAKE mode x bounded/continuous output |
| `cross_mode_back_to_back` | SHAKE mode x valid preceding-to-current mode transition; impossible combinations are ignored |
| `cross_mode_config_latch` | SHAKE mode x changed configuration pin |
| `cross_mode_prefix_consistency` | SHAKE mode x XOF prefix distance |
| `cross_mode_message_kind` | SHAKE mode x message boundary x output kind |
| `cross_mode_flow_depth` | SHAKE mode x absorb depth x squeeze depth |
| `cross_mode_backpressure` | SHAKE mode x input-gap pattern x output-stall pattern |
| `cross_mode_stall_equivalence` | SHAKE mode x stalled-versus-unstalled equivalence case |
| `cross_stall_position` | Active stall pattern x stall position; the no-stall case is ignored |
| `cross_reset_mode` | Reset phase x SHAKE mode |
| `cross_active_lane_mode` | Active-lane count x SHAKE mode |
| `cross_reset_recovery_mode` | Successful reset recovery x SHAKE mode |
| `cross_stop_recovery_mode` | Successful stop recovery x SHAKE mode |
| `cross_lane_isolation_mode` | Peer disturbance x target SHAKE mode |

### `cg_dual_core`: per-core coverage inside the wrapper

This covergroup is instantiated for core 0 and core 1. It confirms that both
physical cores, when reached through the shared dual-core interface, handle the
same meaningful classes of work.

| Coverpoint | What it checks |
|---|---|
| `cp_mode` | SHAKE128 and SHAKE256 on the selected physical core |
| `cp_message` | Empty, short unaligned, word-aligned, rate-1, rate, rate+1, and multirate messages |
| `cp_output` | Tiny, full-beat, partial-after-beat, rate-1, rate, rate+1, and multirate outputs |
| `cp_stall` | No stall, periodic stall, and burst stall profiles |
| `cp_final_beat` | Full, 8-byte, and other partial final output beats |
| `cp_rate_tail` | Whether a partial beat occurred at a SHAKE rate boundary |
| `cp_multi_absorb` | Single- versus multiple-block absorption |
| `cp_multi_squeeze` | Single- versus multiple-block squeezing |

| Cross | Combination checked |
|---|---|
| `cross_mode_message` | Mode x message class |
| `cross_mode_output` | Mode x output class |
| `cross_mode_stall` | Mode x stall profile |
| `cross_mode_final_beat` | Mode x final output-beat class |
| `cross_mode_multi_absorb` | Mode x single/multiple absorb blocks |
| `cross_mode_multi_squeeze` | Mode x single/multiple squeeze blocks |
| `cross_message_output` | Message class x output class |
| `cross_mode_message_output` | Mode x message class x output class |
| `cross_mode_message_stall` | Mode x message class x stall profile |
| `cross_mode_output_stall` | Mode x output class x stall profile |
| `cross_mode_stall_final_beat` | Mode x stall profile x final-beat class |
| `cross_mode_flow_depth` | Mode x absorb depth x squeeze depth |
| `cross_mode_rate_tail` | Mode x rate-boundary partial-tail observation |

### `cg_dual_interleaved`: wrapper coverpoints

| Coverpoint | What it checks |
|---|---|
| `cp_mode_pair` | Both jobs SHAKE128, both SHAKE256, or a mixed-mode pair |
| `cp_stall` | No output stall, periodic stalls, and burst stalls |
| `cp_launch_gap` | Exact 26-cycle stagger or a launch delayed by input traffic |
| `cp_output_overlap` | Whether both cores had output available concurrently |
| `cp_output_stall` | Wrapper output backpressure was observed |
| `cp_simultaneous_stall` | Both cores were blocked at the same time |
| `cp_source_switches` | One or multiple output-source changes during a pair |
| `cp_request_wait` | Immediate request acceptance or request backpressure |
| `cp_first_core` | Core 0 and core 1 each launch first |
| `cp_dispatch_fallback` | Preferred core unavailable, so dispatch correctly falls back |
| `cp_wait_offset` | A request waits for the required inter-core launch offset |
| `cp_wait_ingress` | A request waits because the shared input path is occupied |
| `cp_wait_all_busy` | A request waits while both cores are occupied |
| `cp_output_only_core0` | Only core 0 has valid output |
| `cp_output_only_core1` | Only core 1 has valid output |
| `cp_both_select_core0` | Both outputs valid and the arbiter selects core 0 |
| `cp_both_select_core1` | Both outputs valid and the arbiter selects core 1 |
| `cp_locked_stall_core0` | A stalled output remains locked to core 0 |
| `cp_locked_stall_core1` | A stalled output remains locked to core 1 |
| `cp_reset_while_busy` | Wrapper reset while active work exists |
| `cp_stop_core0` | Core 0 stop and recovery path |
| `cp_stop_core1` | Core 1 stop and recovery path |

| Cross | Combination checked |
|---|---|
| `cross_mode_stall` | Mode pair x stall profile |
| `cross_first_mode_pair` | First-launched core x mode pair |
| `cross_mode_launch_gap` | Mode pair x launch-gap class |
| `cross_mode_request_wait` | Mode pair x immediate/backpressured request |
| `cross_mode_output_overlap` | Mode pair x overlapping core outputs |
| `cross_first_core_stall` | First core x stall profile |
| `cross_mode_first_core_stall` | Mode pair x first core x stall profile |
| `cross_mode_dispatch_fallback` | Mode pair x fallback dispatch observed |
| `cross_mode_wait_offset` | Mode pair x wait-for-offset observed |
| `cross_mode_wait_ingress` | Mode pair x wait-for-ingress observed |
| `cross_mode_wait_all_busy` | Mode pair x both-cores-busy wait observed |
| `cross_mode_locked_stall_core0` | Mode pair x stalled arbitration lock on core 0 |
| `cross_mode_locked_stall_core1` | Mode pair x stalled arbitration lock on core 1 |
| `cross_mode_reset_while_busy` | Mode pair x reset while work is active |
| `cross_mode_stop_core0` | Mode pair x stop of core 0 |
| `cross_mode_stop_core1` | Mode pair x stop of core 1 |

### Scoreboards, references, and assertions

- The UVM monitor reconstructs accepted messages and output streams from the
  interface. The scoreboard compares mode, lengths, protocol observations, and
  every output byte before allowing `cg_keccak` to sample.
- Published SHAKE vectors are embedded in the directed suite. Generated UVM
  cases use the independent pure-SystemVerilog `keccak_ref_pkg::shake_hex`
  model. Direct dual-wrapper and throughput jobs use `shake_compute` to fill
  expected byte queues.
- The dual-wrapper regression checks every accepted output beat, byte count,
  source-core tag, arbitration stability under stalls, and expected queue.
- Eight interface assertions per core check legal start, transition to busy,
  stable input and output while waiting, legal output-byte count, legal done,
  no idle output, and reset clearing the interface.
- Assertion cover properties observe start, input wait, output wait, normal
  completion, continuous stop, and reset while busy.
- The independent permutation checker validates Theta, Rho, Pi, Chi, and Iota
  against a separate implementation for every round. This protects against a
  design and scoreboard sharing the same internal error.

Functional coverage and structural code coverage answer different questions.
Functional coverage measures requirements represented by the covergroups;
code coverage measures which RTL structures executed. Neither percentage is a
substitute for byte-exact checking or assertion results.

## 2. Test Inventory

### UVM single-core and two-lane tests

`keccak_full_test` runs the complete sequence twice on each physical core, then
runs the cross-lane tests. The two core regressions execute in parallel. The
latest run checked 904 transactions: 453 on core 0 and 451 on core 1.

| Sequence or test | Brief purpose |
|---|---|
| `keccak_directed_seq` | Twelve published-vector cases: empty, short, and boundary/long messages for both modes, each in continuous and bounded forms |
| `keccak_stress_seq` | Twenty generated transactions per execution with message lengths from 0 to 600 bytes and generated golden outputs |
| `keccak_cov_seq` | Deterministic message-size and output-kind cases used to reach basic mode/length classes |
| `keccak_boundary_seq` | Exhaustive selected boundaries: 0/1/7/8/9 bytes, rate and two-rate edges, final-beat sizes 1-8, and output up to 600 bytes |
| `keccak_protocol_stress_seq` | Input gaps, valid held while not ready, output backpressure profiles, and stalls on ordinary/final/rate-boundary beats |
| `keccak_config_latch_seq` | Changes mode, output length, or both after start and confirms the accepted configuration remains latched |
| `keccak_continuous_stop_seq` | Stops continuous output at first beat, mid-block, rate boundary, after re-permutation, after deep squeezing, and while stalled; checks recovery after each |
| `keccak_abort_seq` | Resets from idle, absorb, suffix padding, both permutation phases, and squeeze; follows each abort with a checked recovery transaction |
| `keccak_deep_consistency_seq` | Back-to-back mode changes, stalled/unstalled equivalence, XOF prefix consistency, and 16 walking-bit/walking-byte ordering cases |
| `keccak_concurrency_seq` | Verifies one-active-lane and two-active-lane operation in both modes |
| `keccak_lane_isolation_target_seq` and `peer_seq` | Proves a target lane remains byte-correct while its peer is reset, stalled, or stopped, for both target modes |
| `keccak_mixed_lane_seq` | Runs different modes, messages, and output sizes simultaneously on the two lanes and checks them independently |

`keccak_directed_test` remains available as a smaller directed-only test, but
the main `run.do` regression selects `keccak_full_test`.

### Dual-core interleaver tests

The directed dual-wrapper regression in `tb_top.sv` verifies the integrated
wrapper with both cores instantiated. It completed 81 checked jobs. Ten
additional in-flight jobs are deliberately cancelled by reset or stop; those
are negative recovery scenarios, not hash failures.

| Scenario family | Brief purpose |
|---|---|
| Boundary job pairs | Same-mode and mixed-mode pairs cover empty, tiny, unaligned, full-beat, rate-edge, multirate, and 600-byte outputs |
| Stall profiles | No stall, periodic, burst, simultaneous, and forced locked-source backpressure |
| Launch ordering | Core 0 first, core 1 first, exact 26-cycle spacing, and ingress-delayed spacing |
| Shared-ingress wait | Confirms the second request waits correctly while the input path belongs to another core |
| Busy fallback | Occupies both cores, applies another request, and verifies waiting plus dispatch to the newly available core |
| Arbitration | Checks output source tags, source switching, round-robin choices when both outputs are valid, and stable selection during stalls |
| Reset recovery | Resets while both cores are busy, confirms wrapper state is cleared, then runs a checked mixed-mode pair |
| Targeted state reset | Resets each physical core from absorb, suffix-padding, and permutation states, then checks same-core recovery |
| Stop recovery | Stops core 0 and core 1 independently during output and verifies a later job on that same core |
| Continuous output | Runs `output_len == 0` on each physical core, checks every requested byte, asserts stop, and verifies clean completion |
| Empty SHAKE256 routing | Explicitly sends an empty SHAKE256 message to each physical core |
| Byte-exact checking | Every accepted beat is checked for legal byte count, source core, and expected byte sequence |

### Throughput tests

`tb_keccak_dual_throughput` runs four additional long-output jobs: two
SHAKE128 jobs and two SHAKE256 jobs. It verifies every byte before reporting
throughput. Its purpose and calculations are documented in `THROUGHPUT.md`.

## Verification Results

These results come from the latest complete source-RTL run recorded in
`sim/transcript` on September 24, 2026.

### Pass results

| Check | Result |
|---|---:|
| UVM golden-checked transactions | **904/904 passed** |
| UVM core 0 / core 1 samples | **453 / 451** |
| Dual-wrapper checked jobs | **81 passed** |
| Deliberate reset/stop cancellations | **10 handled correctly** |
| Throughput jobs | **4 byte-exact jobs passed** |
| UVM errors / fatals | **0 / 0** |
| Simulator errors | **0** |

### Functional coverage

| Scope | Result |
|---|---:|
| Overall weighted covergroup metric | **87.55%** |
| Detailed single-core `cg_keccak`, core 0 | **88.47%** |
| Detailed single-core `cg_keccak`, core 1 | **88.47%** |
| Combined two-core `cg_keccak` | **88.47%** |
| Dual per-core `cg_dual_core`, core 0 | **86.87%** |
| Dual per-core `cg_dual_core`, core 1 | **87.24%** |
| `cg_dual_core` type coverage | **87.05%** |
| Dual wrapper `cg_dual_interleaved` | **87.13%** |
| Raw covergroup bins | **848/1232 = 68.83%** |

The 87.55% and 68.83% values are not contradictory. Questa's main
covergroup percentage applies coverpoint/cross weights and per-instance/type
rules. The raw-bin line simply divides all hit bins by all generated bins,
including large multidimensional crosses. For review, report 87.55% as the
weighted functional-coverage result and retain 848/1232 as transparent raw-bin
evidence.

The uncovered functional bins are retained intentionally because they
represent combinations that have not yet been demonstrated. No passing result
was hidden, no bin was marked hit manually, and no failing hash was counted as
coverage.

### Structural code coverage

The sign-off scope is the actual integrated dual-core DUT instance
`/tb_top/u_uvm_core/dual_dut`, including both instantiated Keccak cores. The
latest recursive instance report is:

| Metric | Hits / bins | Coverage |
|---|---:|---:|
| Branches | 212 / 212 | **100.00%** |
| Conditions | 34 / 36 | **94.44%** |
| Expressions | 47 / 47 | **100.00%** |
| FSM states | 10 / 10 | **100.00%** |
| FSM transitions | 22 / 22 | **100.00%** |
| Statements | 605 / 605 | **100.00%** |
| Toggles | 104344 / 105352 | **99.04%** |
| Questa filtered total for the primary DUT | - | **99.06%** |

This is the meaningful source-RTL code-coverage result for the design. The
remaining misses are two condition bins from the defensive absorb-lane bound
and toggle bins, mostly individual state-bit values that the finite regression
did not toggle. Functional coverage remains 87.55% because it measures
specification scenarios and crosses, not executed RTL syntax.

Questa also prints an unscoped all-instance diagnostic total:

| Metric | Hits / bins | Coverage |
|---|---:|---:|
| Assertions | 16 / 16 | **100.00%** |
| Branches | 594 / 610 | **97.37%** |
| Conditions | 78 / 100 | **78.00%** |
| Directives | 10 / 12 | **83.33%** |
| Expressions | 111 / 134 | **82.83%** |
| FSM states | 30 / 30 | **100.00%** |
| FSM transitions | 56 / 66 | **84.84%** |
| Statements | 1747 / 1762 | **99.14%** |
| Toggles | 310218 / 314058 | **98.77%** |
| Questa filtered total across every instance and metric | - | **91.18%** |

The 91.18% number is not the primary DUT's code coverage. It blends the UVM
DUT, the integrated dual-core DUT, the specialized throughput-benchmark DUT
copy, assertions, and functional coverage. The throughput copy intentionally
runs only four long, always-ready jobs, so it does not exercise every protocol
path and lowers that global diagnostic. It remains in the suite because it
performs byte-exact throughput measurement, not because it is a coverage DUT.

The defensive `current_lane_idx < MAX_POSSIBLE_LANES` condition in
`keccak_absorb_unit.sv` is retained even though legal SHAKE modes cannot make
it false while `current_lane_idx < rate_lane_limit` is true. Removing it made
the RTL simulation coverage higher, but caused Quartus to synthesize a larger
absorb selector: ALMs increased from 7,581 to 7,973 and worst setup slack fell
from +0.074 ns to -0.035 ns. The guard is therefore justified implementation
logic, and its unreachable false outcome is documented rather than deleted.

### Reproducing the run

From `sim`, use the fixed QuestaSim 2024.1 installation:

```text
C:\questasim64_2024.1\win64\vsim.exe -do run.do
```

The script compiles the source RTL and testbench, runs `tb_top`, saves
`keccak_dual_coverage.ucdb`, and prints the summary. A valid run must show
`COMPLETE_KECCAK_SUITE_PASS`, both throughput results, zero errors, and the
coverage table. The UCDB remains available for detailed per-instance and
per-bin inspection in the Questa Coverage window.
