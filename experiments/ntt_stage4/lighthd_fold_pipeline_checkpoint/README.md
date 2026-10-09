# Selected first-fold pipeline checkpoint - 2026-10-10

Base: saved smaller route/Pre-key alternative. The selected 145.73 MHz
keep-bias checkpoint remains saved. No carry-select trial logic is used.

## Change

Register two 36-bit carry-save words from the product in a new stage. Their
sum modulo 2^36 gives the exact first fold because (hi<<13)-hi+lo is
nonnegative and fits 36 bits for all 23-bit operands. Carry propagation now
starts from ordinary registers rather than following DSP clock-to-output and
compression logic in the same timing interval. The second fold and final
canonical correction are unchanged. Still accepts one operand pair per clock.

Multiplier/BF/issue-return latency changes from 4/6/9 to 5/7/10. The BF kept
operand/mode arrays and core valid/destination/inverse tags include the extra
clock. FIFO capacities, issue counts, wrapper interface and golden mathematics
are unchanged. Independent UVM delayed-tag and physical-writeback models now
require ten clocks; they do not derive expected delay from the observed tag.
All three changed TB files and their previous versions are saved here.

## Measured source verification

Main uvm_fold_pipeline.log: 118/118 passing, zero errors/fatals, fourteen
checked functional covergroup types at 100%. Nine reset/cancel/recovery points,
all physical operands/writes, pipeline drain and every output remain checked.
vector_fold_pipeline.log / compare_fold_pipeline.log: 18/18 cases and all
4608 coefficients match independently. No golden/reference file changes.

| Operation | Previous core / wrapper | Trial core / wrapper |
|---|---:|---:|
| NTT | 266 / 780 | 267 / 781 |
| INTT | 266 / 780 | 267 / 781 |
| PWM | 74 / 844 | 75 / 845 |
| Pre-NTT | 235 / 749 | 236 / 750 |

Measured no-stall wrapper counts include loading and output. Issue counts
remain 256/256/64/224. These clock counts do not establish FPGA frequency.

Separate coverage-credit test rejects five faults without credit. Separate
operand/writeback corruption tests both reject with checked_jobs=0 despite
correct real outputs. The missing GS witness test rejects without new credit.
All PASS markers are saved in the corresponding *_fold_pipeline.log files.
Failed UCDBs are separate and never merged into main passing coverage.
Earlier +8 eligibility evidence is preserved, not newly rerun here.

Raw core: 295/307 statements, 232/245 branches, 53/84 conditions, 51/52
expressions, 5/5 states, 9/9 transitions, 3405/3683 toggles. Each multiplier:
45/45 statements, 12/12 branches, 1228/1418 toggles. Its 190 missed toggle
bins are both directions of 95 constant bits listed in the report. Each BF:
55/55 statements, 17/17 branches, 704/704 toggles. Wrapper counts unchanged.
Source changes alter denominators. No exclusions or aggregate code-coverage
closure claim. Main UVM remains the coverage source.

## Selected fitted result

Fresh map/fit/STA/paths: slow85/worst148.46MHz, slow0 150.20MHz;
2490ALMs,2396registers,5DSP/21M10K,37348RAMbits. Worst setup/hold/pulse
at5ns:-1.736/+0.133/-0.555ns. Same device/tools/fit/constraint as prior.
Compared with selected145.73MHz: setup+0.126ns,Fmax+1.87%,ALMs-78,
registers+279,RAMbits+96,unchanged DSP/M10K count. NTT wrapper estimate
781/148.46=5.26us,core267/148.46=1.80us;latency-based190090poly/s(+1.74%).
Excludes gaps/stalls/SHAKE/sampler; not sustained integrated throughput.
Both slow corners now worst at tag[9].pwm -> FIFO2 write-data selection.
The first fold is no longer among reported top-three paths. Setup/pulse at
200MHz still fail; Stage4open. Nothing staged or committed.
Active RTL and current review reports/database match this checkpoint.
Prior145.73MHz source/TB rollback is preserved. No netlist/FPGA claim.
