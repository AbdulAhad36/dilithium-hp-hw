# Keccak Verification Baseline and Closure Record

Date: 2026-09-12

Branch: `1_hashing`

Simulator: QuestaSim-64 2024.1 (`C:\questasim64_2024.1\win64`)

Status: local working tree, not committed

**Archive status (2026-09-27):** This is the September 12 single-core
coverage model. For the active dual-core regression and latest recorded
results, see [COVERAGE.md](COVERAGE.md).

## Why the Old 100% Was Wrong

The old functional model contained only 32 broad bins. A single value could
close a large range, and coverage sampled driver intent before the DUT result
was checked. Its 100% result therefore meant only that every broad stimulus
category had been requested. It did not prove that the DUT completed the
transaction correctly or that boundary, stall, reset, and concurrency behavior
had been exercised.

The expanded model has 281 requirement-oriented bins across 26 coverpoints
and 12 crosses. It samples only monitor-observed transactions published by the
scoreboard after control, accepted input, output data, byte counts, completion,
and requested stress behavior all pass.

This model is still not the denominator for complete Keccak verification. It
measures the functional scenarios currently encoded in the covergroup, not
every P1 row in the verification plan. The strict status snapshot is:

| Scope | Fully passing P1 rows | Total P1 rows | Closure |
| --- | ---: | ---: | ---: |
| Source-RTL requirements (`K-ALG`, `K-IN`, `K-OUT`, `K-PAR`, `K-UNIT`) | 14 | 44 | 31.82% |
| Implementation/hardware requirements (`K-IMP`) | 4 | 6 | 66.67% |
| All planned P1 requirements | 18 | 50 | 36.00% |

The earlier 99.20% result was the 223-bin intermediate model. Adding the open
P1 scenarios initially produced 65.26% because Questa weighted every
coverpoint and cross equally, making a one-bin suite count as much as a 30-bin
cross. Each coverage item is now weighted by its number of requirement bins.
The weights total 281. At the 259-bin milestone Questa therefore reported
**92.17%**, exactly equal to 259/281 hit bins. The latest fully executed source
regression reaches all 281 bins and reports 100%. This is still not total
design coverage or verification completion.

## Interface Change

The Keccak RTL and active UVM environment no longer use AXI signals. The simple
per-lane contract is:

- `start_i`, `keccak_mode_i`, `message_len_i`, `output_len_i`, and `stop_i`.
- `busy_o` and `done_o`.
- `input_data_i`, `input_valid_i`, and `input_ready_o`.
- `output_data_o`, `output_valid_o`, `output_bytes_o`, and `output_ready_i`.

Message completion and the number of valid bytes in the final input word are
derived from the explicit message length. Bounded output completion and the
number of bytes in the final output word are derived from the explicit output
length. Continuous output uses `output_len_i=0` and terminates through `stop_i`.

The old unreferenced core benches that depended on the removed interface were
deleted. Unit benches that still target active submodules remain.

## Closure Timeline

| Step | Checked transactions | Implemented covergroup coverage | Result |
| --- | ---: | ---: | --- |
| Original broad-bin baseline | 208 | 100% reported | Rejected as misleading |
| Checked requirement model | 208 | 50.61% | Honest initial baseline |
| Rate/message/output boundaries | 424 | 66.60% | 424/424 pass |
| Input gaps and output backpressure | 484 | 82.60% | 484/484 pass |
| Observed 1/2/3/4-lane concurrency | 496 | 88.60% | 496/496 pass |
| Continuous stop and long squeeze cases | 516 | 91.20% | 516/516 pass |
| Observed reset from every FSM phase | 564 | 99.20% | 564/564 pass |
| Expanded P1 model, equal coverpoint weighting | 564 | 65.26% | Rejected weighting artifact |
| Expanded P1 model, equal requirement-bin weighting | 564 | 79.00% | 564/564 pass |
| Evidence-driven configuration and reset/stop recovery | 696 | 91.46% | 696/696 pass |
| Restored 3-block and 4+-block continuous squeeze cases | 728 | 92.17% | 728/728 pass |
| Deep consistency, lane isolation, mixed-lane work, ordering, and independent permutation checks | 880 | 100.00% | 880/880 pass |
| Valid held stable during input backpressure | 888 | 100.00% | 888/888 pass; zero simulator errors |

An intermediate run exposed 157 input-stability assertion failures in the UVM
driver. The driver had waited for ready while leaving the previous valid/data
word asserted. It was repaired to present each word first and hold it stable
until acceptance. That failing run is diagnostic history, not sign-off evidence.

Another intermediate run showed that a stop pulse issued just after a transfer
that exhausted the rate occurs during re-permutation, where `stop_i` is not
sampled. The driver now waits for SQUEEZE to resume and the coverage model
records this as stop after re-permutation.

The first reset-state run exposed a testbench concurrency defect: a named
`disable` in one driver instance could terminate another lane's input worker.
Waveform inspection showed the affected lane stuck in ABSORB with its full
message pending. The reset workers are now lane-local and reset-aware; the
subsequent full four-lane regression passed.

The expanded recovery suite exposed a second abort race. The source worker could
leave `input_valid_i` and stale data asserted after reset cancelled an active
operation. The driver now asserts abort reset before releasing the worker and
explicitly clears all source and stop controls. The active-wait assertion was
refined to distinguish a legal reset cancellation from an ordinary busy wait;
the final regression has no suppressed assertion failures.

## Final Clean Regression

- Lane 0: 228/228 passed.
- Lane 1: 226/226 passed.
- Lane 2: 218/218 passed.
- Lane 3: 216/216 passed.
- Total: 888/888 passed.
- UVM warnings/errors/fatals: 0/0/0.
- Simulator errors: 0.
- Expanded P1 functional covergroup coverage: 100.00%.
- Raw functional bins: 281/281 (100.00%).
- Assertion pass coverage: 32/32 (100%).
- Cover directives: 20/24 (83.33%).

The unequal per-lane counts are intentional. After the common four-lane suite,
controlled waves run one, two, and three lanes. The monitor observes the number
of simultaneously busy lanes, and the scoreboard checks it against the expected
count before coverage receives the transaction.

Two valid-during-input-backpressure cases per full sequence deliberately
present an unaccepted word after message end. The first implementation exposed
eight assertion failures because the driver withdrew valid/data while ready
remained low. The corrected producer holds valid and data stable until the core
leaves its busy state, and the complete 888-transaction rerun has zero
assertion, UVM, and simulator errors.

## Functional Coverage Status

Fully covered requirement crosses include:

- SHAKE mode x message boundary: 24/24.
- SHAKE mode x output boundary: 30/30.
- SHAKE mode x final input byte count: 18/18.
- SHAKE mode x final output byte count: 16/16.
- Bounded/continuous output x squeeze block count: 8/8.
- Stall pattern x observed stall position: 9/9.
- Lane ID x SHAKE mode: 8/8.
- Observed active lane count x SHAKE mode: 8/8.
- Reset state: 6/6.
- Reset state x SHAKE mode: 12/12.
- Configuration changes after start: 3/3.
- Post-reset recovery state and mode crosses: 6/6 and 12/12.
- Continuous stop position and mode cross: 5/5 and 10/10.
- Post-stop recovery position and mode crosses: 5/5 and 10/10.

The final 22 bins were closed by independently checked deep scenarios:

- Back-to-back mode transitions without reset: 4 bins.
- Stalled-versus-unstalled equivalence: 3 bins.
- Asymmetric peer-lane reset/stall/stop isolation: 3 bins.
- Lane-isolation scenario x SHAKE mode: 6 bins.
- Independently checked mixed-lane work: 1 bin.
- Shorter/longer output prefix consistency: 3 bins.
- Walking-byte/bit ordering suite: 1 bin.
- Independent all-step/all-round permutation suite: 1 bin.

Reset-state coverage uses verification-only hierarchy observation in `tb_top`.
The driver waits for the actual FSM state and permutation phase, `tb_top`
captures the phase immediately before asynchronous reset clears it, and the
monitor and scoreboard require the captured phase to match the requested phase
before coverage receives the transaction. No synthesizable RTL port or
cycle-delay guess is used. This internal observation is Stage 1 evidence and is
not expected to survive synthesis.

## RTL Structural Coverage

Whole compiled RTL:

| Metric | Covered | Percentage |
| --- | ---: | ---: |
| Branches | 392/392 | 100.00% |
| Conditions | 64/76 | 84.21% |
| Expressions | 88/92 | 95.65% |
| FSM states | 20/20 | 100.00% |
| FSM transitions | 44/44 | 100.00% |
| Statements | 1100/1100 | 100.00% |
| Toggles | 202812/204590 | 99.13% |

`keccak_core` only:

| Metric | Covered | Percentage |
| --- | ---: | ---: |
| Branches | 79/79 | 100.00% |
| Conditions | 11/13 | 84.61% |
| Expressions | 15/16 | 93.75% |
| FSM states | 5/5 | 100.00% |
| FSM transitions | 11/11 | 100.00% |
| Statements | 121/121 | 100.00% |
| Toggles | 16851/17059 | 98.78% |

The complete lane-0 RTL hierarchy aggregate is **96.74%** after the one-round
architectural change. It is not functional coverage or requirement closure and
must not be presented as one combined sign-off percentage. Statement and toggle
coverage can rise quickly in this design
because directed boundary tests execute most straight-line datapath code and
random data toggles wide state buses. Conditions remain 84.21% and directives
83.33%; every structural hole still requires review.

The `keccak_core` itself has complete branch, statement, FSM-state, and
FSM-transition coverage. Including the parameter, absorb, output, round unit,
and five step instances gives the 96.74% complete lane-0 result. The remaining
condition and toggle holes
include defensive or logically dependent cases and must be reviewed rather
than excluded merely to raise a score.

## Assertions

Per lane, assertions check:

- Start is issued only while idle and enters busy.
- Input data remains stable while valid is waiting for ready.
- Output data and byte count remain stable during backpressure.
- Every valid output reports 1 through 8 bytes.
- `done_o` has a bounded-transfer or explicit-stop cause.
- Idle suppresses output valid.
- Reset clears busy and output valid.

Cover properties exercise start, input waiting, output waiting, bounded done,
continuous stop, and reset while busy. Every implemented assertion passed and
every reset phase was reached in both modes on every lane. The 32/32 assertion
result means these eight properties were exercised on four lanes; it is not a
claim that the assertion plan itself is complete. Four of 24 cover-property
instances remain unhit.

## Reproduce

From `sim`:

```powershell
& 'F:\altera\questa_fse\win64\vsim.exe' -c -do 'do run.do; quit -f'
& 'F:\altera\questa_fse\win64\vcover.exe' report -summary keccak_cov.ucdb
& 'F:\altera\questa_fse\win64\vcover.exe' report -instance='/tb_top/dut/g_lane[0].' -code bcesft keccak_cov.ucdb
& 'F:\altera\questa_fse\win64\vcover.exe' report -assert -details keccak_cov.ucdb
& 'F:\altera\questa_fse\win64\vcover.exe' report -cvg -details -zeros keccak_cov.ucdb
```

## Next Gate

1. Review and justify each remaining structural condition/expression hole.
2. Add broader independent NIST/CAVP evidence.
3. Review with the supervisor whether optional SDF timing simulation is needed,
   then prepare the board-specific FPGA/UART project when the board is known.

## Stage 2 Addendum - refreshed 2026-09-12

Stage 2 post-synthesis functional equivalence now passes for the focused
one-core port-only regression: 125/125 source-RTL transactions and 125/125
technology-mapped netlist transactions passed with identical checked-record
SHA-256 values. This earns closure for `K-IMP-001` only.

It does not change this document's Stage 1 coverage measurements. The smaller
Stage 2 suite reached 201/281 functional bins (71.53%), 11/32 assertion
instances, and 5/24 cover directives because internal hierarchy-dependent reset
tests were deliberately not used on the synthesized netlist.

The `rtl` half of this focused flow is the apples-to-apples single-lane Stage 1
reference. It also reaches 201/281 bins (71.53%). The full Stage 1 campaign is a
different, larger four-lane run and reaches 281/281 bins (100.00%). These two
Stage 1 numbers must always be labeled by suite scope.

The warning-cleaned one-round rerun completed with zero synthesis warnings. Its
two removed registers are reviewed dead generated/control optimizations, so the
Stage 2 functional/mapping gate passes. See
[KECCAK_STAGE2_SYNTHESIS_REPORT.md](KECCAK_STAGE2_SYNTHESIS_REPORT.md).

## Stage 3 Addendum - refreshed 2026-09-12

The fitted Cyclone V netlist and source RTL each passed the same 125 checked
transactions with zero UVM errors/fatals and identical checked-record SHA-256
`726C5025...2BC54C`. Both runs reached 201/281 focused-suite functional bins
(71.53%); this remains separate from the 888-transaction Stage 1 result.

Post-fit TimeQuest reported fully constrained setup and hold. The 50 MHz target
passes with +5.040 ns worst slow-corner setup slack and +0.169 ns worst hold
slack across reported corners. Conservative slow-corner Fmax for this
interface-constrained flow is 66.83 MHz. Final one-core use is 3,903 ALMs and
1,979 registers, with no DSP or memory.

This closes `K-IMP-002` and `K-IMP-003` for the one-core module benchmark,
raising strict all-stage P1 closure to 18/50 (36.00%). It does not close FPGA
testing or the N-lane implementation comparison. See
[KECCAK_STAGE3_POSTFIT_REPORT.md](KECCAK_STAGE3_POSTFIT_REPORT.md).

The separate 6.803 ns internal-core performance project closes a 147 MHz
one-round operating point with +0.010 ns worst setup and +0.168 ns worst hold
slack. This performance result does not change any Stage 1 coverage percentage.
See
[KECCAK_TIMING_OPTIMIZATION_REPORT.md](KECCAK_TIMING_OPTIMIZATION_REPORT.md).

For the same focused one-lane suite, functional coverage is therefore 71.53%
at source RTL, post-synthesis, and post-fit. Equal functional coverage is the
expected consistency result when the stimulus and observed passing behavior
are identical. Generated-netlist code coverage is not compared with source RTL
code coverage.
