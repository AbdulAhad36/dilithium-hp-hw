# Expanded main UVM coverage checkpoint - 2026-10-11

**620/620 jobs, 158,720/158,720 coefficients**, zero UVM errors/fatals.
Adds 502 jobs to the original 118; 22 covergroup types, average 99.51%, minimum 92.36%.
The eight new groups' equal-weight average is 98.65%. RTL/golden are unchanged.

## New functional groups

| Group | Hit/legal bins | Coverage | Meaning |
|---|---:|---:|---|
| `cg_input_range` | 37/37 | 100.00% | Four ordinary operand streams plus bounded Pre A; accepted coefficient ranges. |
| `cg_output_range` | 31/32 | 96.88% | Four operations x eight canonical output ranges. |
| `cg_pwm_pairs` | 256/256 | 100.00% | Eight A ranges x eight B ranges x four coefficient lanes. |
| `cg_input_gap_duration` | 60/60 | 100.00% | Four modes x three input regions x five nonzero gap durations. |
| `cg_output_stall_duration` | 60/60 | 100.00% | Four modes x first/middle/last output x five nonzero stall durations. |
| `cg_flow_combination` | 133/144 | 92.36% | Four modes x six maximum-gap classes x six maximum-stall classes. |
| `cg_operation_transition` | 32/32 | 100.00% | Previous/current checked mode x observed intervening reset. |
| `cg_polynomial_shape` | 32/32 | 100.00% | Four modes x eight shapes classified from accepted operand A. |

One Pre output-q-1 bin and eleven flow-cross bins remain unhit, with no waiver.
Exact IDs and raw per-instance code counts are in `results.json`; definitions,
decoding, justification, remaining code holes and study order are in
[the coverage document](../../../docs/ntt_docs/post_midyear/COVERAGE.md).

## Raw DUT code coverage

| Metric | Hit/total | Coverage |
|---|---:|---:|
| Statements | 762/775 | 98.32% |
| Branches | 388/402 | 96.52% |
| Conditions | 56/85 | 65.88% |
| Expressions | 56/59 | 94.92% |
| Toggles | 11,691/12,735 | 91.80% |
| FSM States | 13/13 | 100.00% |
| FSM Transitions | 24/24 | 100.00% |

Metrics sum each RTL instance's self counts; TB/golden are outside the code
denominator. Raw counts match Stage 5 exactly. Condition coverage is below 90%;
reviewed guards/correlations and unresolved misses stay visible. No exclusions.

## Evidence and reproduction

- `rtl/`, `tb/`, `sim/`, `source_hashes.json`: exact sources and scripts.
- `results/`: passing full transcript, main UCDB and detailed raw report.
- `results.json`: parsed test counts, group hits/misses and code counts.
- `checker_gates/`: seven-fault source credit test and five-fault fitted-netlist
  compatibility test, separately logged; source negative UCDB is never merged.

Run from Questa with cwd `sim/`: `do ntt_LightHD/run_uvm.do`. Require the explicit
`NTT EXPANDED UVM PASS`, zero errors/fatals, 620 passing jobs and all 22 groups>=90%.
Default simulator seed 20261011; independent extended flow seed 439041101.
Full source runtime about 21 seconds on this run; future wall time may vary.
New sequence: 32 shapes +3 result-range jobs +2 bounded impulses +1 PWM Cartesian
job +400 randomized flow jobs +64 jobs for 32 transitions = 502 additional jobs.
Observations are checked against golden outputs, internal routing and requested
per-region duration counts before bins are sampled. Failed items receive no credit.

Stage 5's full 117-job netlist suites are retained, not rerun as 620-job suites.
Only fitted-netlist checker compatibility was rerun. RTL and golden hashes match
the Stage 5 checkpoint. No new timing/synthesis, integrated throughput, FPGA or
Stage 6 result, and no commit.
