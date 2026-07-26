# Keccak Coverage Baseline

Date: 2026-07-26

Branch: `1_hashing`

Simulator: QuestaSim 2024.1

## What This Baseline Measures

The previous functional coverage model contained 32 broad bins. The existing
regression happened to touch every broad range, so it reported 100%. That number
did not demonstrate complete verification of the Keccak requirements.

The replacement model contains 223 requirement-oriented bins across 16
coverpoints and 9 meaningful crosses. Coverage is sampled only after the
scoreboard marks a monitor-observed transaction as passed, protocol-correct,
and data-correct.

RTL is compiled with structural coverage enabled. UVM testbench code is not
included in structural coverage. Functional covergroups remain enabled.

## Regression Result

- Tests: 52/52 passed per lane, 208/208 total
- UVM warnings: 0
- UVM errors: 0
- UVM fatals: 0
- Functional requirement coverage: 50.61%
- Raw functional bins hit: 95/223 (42.60%)

The weighted 50.61% is the Questa covergroup score. The raw 42.60% is included
to show the exact number of bins hit. Neither number should be replaced by the
combined UCDB total.

## Functional Coverage Detail

| Requirement | Result | Important missing cases |
| --- | ---: | --- |
| Message boundaries | 5/12 (41.66%) | 7, 9, rate-1, rate, rate+1, 2rate-1, 2rate bytes |
| Output boundaries | 1/15 (6.66%) | 1-7, rate-1, rate, rate+1, 2rate-1, 2rate, 2rate+1, maximum |
| Squeeze block count | 3/4 (75.00%) | 4 or more blocks |
| Input gap pattern | 1/4 (25.00%) | single-cycle, burst, random gaps |
| Output stall pattern | 1/4 (25.00%) | single-cycle, burst, random stalls |
| Stall position | 0/3 (0.00%) | ordinary, final, and rate-boundary beats |
| Reset state | 0/6 (0.00%) | absorb, padding, both permutation phases, squeeze, and explicit idle reset |
| Stop position | 2/5 (40.00%) | first beat, rate boundary, while stalled |
| Active lane count | 1/4 (25.00%) | one, two, and three active lanes |
| Latency class | 2/4 (50.00%) | input-stalled and output-stalled transactions |

Cross-coverage results:

- Mode x message boundary: 7/24 (29.16%)
- Mode x output boundary: 1/30 (3.33%)
- Mode x final input bytes: 17/18 (94.44%)
- Mode x final output bytes: 10/16 (62.50%)
- Output kind x squeeze blocks: 5/8 (62.50%)
- Stall pattern x stall position: 0/9 (0.00%)
- Reset state x mode: 0/12 (0.00%)
- Lane x mode: 8/8 (100.00%)
- Active lane count x mode: 2/8 (25.00%)

## RTL Structural Coverage

Whole RTL:

| Metric | Covered | Percentage |
| --- | ---: | ---: |
| Branches | 380/392 | 96.93% |
| Conditions | 72/88 | 81.81% |
| Expressions | 32/32 | 100.00% |
| FSM states | 20/20 | 100.00% |
| FSM transitions | 32/44 | 72.72% |
| Statements | 1044/1072 | 97.38% |
| Toggles | 203524/205638 | 98.97% |

`keccak_core` only:

| Metric | Covered | Percentage |
| --- | ---: | ---: |
| Branches | 73/75 | 97.33% |
| Conditions | 13/15 | 86.66% |
| Expressions | 5/5 | 100.00% |
| FSM states | 5/5 | 100.00% |
| FSM transitions | 8/11 | 72.72% |
| Statements | 102/108 | 94.44% |
| Toggles | 17163/17409 | 98.58% |

Structural coverage is not proof of functional correctness. In particular, the
100% expression and FSM-state results do not compensate for missing functional
requirements or unvisited FSM transitions.

## Immediate Verification Work

1. Add directed output-length tests for 1-7 bytes, both mode-dependent rate
   boundaries, two-rate boundaries, and the declared maximum output.
2. Add input-gap and output-backpressure sequences with single, burst, and
   randomized pauses.
3. Instrument the monitor transaction with the observed stall position and DUT
   state at reset, then add reset-in-each-state tests.
4. Add stop tests at the first output beat, a rate boundary, and during
   backpressure.
5. Add regressions with one, two, and three active lanes.
6. Review uncovered RTL branches, conditions, and FSM transitions after the
   functional holes above are exercised.

## Reproducing the Reports

Run the regression from `sim`:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -do 'do run.do; quit -f'
```

Then report the saved `keccak_cov.ucdb`:

```powershell
& 'C:\questasim64_2024.1\win64\vcover.exe' report -summary keccak_cov.ucdb
& 'C:\questasim64_2024.1\win64\vcover.exe' report -du=keccak_core keccak_cov.ucdb
& 'C:\questasim64_2024.1\win64\vcover.exe' report -cvg -details -zeros keccak_cov.ucdb
```
