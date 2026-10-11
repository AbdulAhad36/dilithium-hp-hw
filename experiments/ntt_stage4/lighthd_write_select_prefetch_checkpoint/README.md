# Early write selection plus unconditional prefetch address trial - 2026-10-10

Base: lighthd_write_select_trial (144.72 MHz worst, not selected).
Selected rollback remains lighthd_fold_pipeline_checkpoint (148.46 MHz).
Exact six trial RTL files are in rtl/. Only core and wrapper change from
selected baseline; no TB/reference/interface/FIFO or clock change.

## Method

Keep the three predecoded A/B write-select control bits in the result stage.
The measured new worst path was tx_idx -> terminal-count comparator ->
conditional core_rd_addr -> pop1 -> head1. In ntt_engine.sv, compute the next
coefficient address throughout E_TX_VALID, regardless of m_tready or last.
The existing core_rd_en still requires ready AND not-last. Every enabled read
address and read edge is identical. During stalls/final beat the inactive
address may differ; the core does not consume it. Synchronous read data and
stalled output remain stable. E_TX_RD still requests coefficient zero.

No pipeline clock, word register, FIFO capacity or external latency change.
Core267/267/75/236 and no-stall wrapper 781/781/845/750 unchanged.

## Fresh source verification

Main uvm_write_select_prefetch.log:118/118, zero UVM errors/fatals, all fourteen
checked functional covergroup types 100%. Independent actual read-address,
FIFO-write, output-order, stalled data/framing and reset checks pass.
vector_write_select_prefetch.log / compare_write_select_prefetch.log:
18/18 cases, 4608/4608 coefficients. Golden/reference files are unchanged.
Fresh coverage_gate_write_select_prefetch.log rejects five deliberately
corrupted jobs without additional checked credit (UVM COVERAGE GATE PASS).
Fresh routing_writeback_write_select_prefetch.log detects the injected observed
write fault with real outputs correct and checked_jobs=0 (ROUTING CHECKER PASS).
Failed UCDBs remain separate. Other unchanged operand/GS/Pre-eligibility negative
evidence remains saved, not freshly rerun here.

## Selected fitted result

Fresh map/fit/STA and both slow-corner detailed paths all complete successfully.
Same Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite, standard fit, unchanged
5 ns clock. Fit completed 2026-10-10 04:55:50.

| Metric | Prior selected fold pipeline | Selected control/prefetch |
|---|---:|---:|
| Worst Fmax (MHz) | 148.46 | 150.49 |
| Slow85 / slow0 (MHz) | 148.46 / 150.20 | 151.79 / 150.49 |
| ALMs / registers | 2490 / 2396 | 2475 / 2414 |
| DSP / M10K | 5 / 21 | 5 / 20 |
| RAM bits | 37348 | 37325 |
| Worst setup / hold / pulse at 5 ns | -1.736 / +0.133 / -0.555 | -1.645 / +0.152 / -0.555 |

Worst Fmax improves 1.37%, setup 0.091 ns, ALMs fall15, registers rise18,
RAM bits fall23 and one fewer M10K is mapped. Coefficient FIFO capacity does
not change. Both measured cycle boundaries stay unchanged. NTT wrapper/core
estimates at worst Fmax are5.19/1.77 us; latency-based rate 192689 poly/s excludes
restart gaps, stalls and SHAKE/sampler time. Not sustained system throughput.

Current review copies and active implementation database match this source.
Slow85 now limits at tick[7] -> packed tag shift-memory input; slow0 at packed
BF kept-operand delay RAM -> final BF result. These are mapped netlist labels;
shared RAM instance names do not imply a logical cross-lane dataflow change.
No 200 MHz setup/pulse closure, Stage 5/netlist/FPGA result or new commit.

## Why enabled read behavior is unchanged

| Wrapper condition | Read enable | Old consumed address | New consumed address |
|---|---:|---:|---:|
| First E_TX_RD clock | 1 | 0 | 0 |
| E_TX_VALID, ready, index below 255 | 1 | index+1 | index+1 |
| E_TX_VALID, stalled | 0 | not consumed | not consumed |
| E_TX_VALID, final coefficient | 0 | not consumed | not consumed |

Raw core counts match the preceding control trial:300/312 statements,
234/247 branches, 49/78 conditions, 55/58 expressions, 5/5 states, 9/9 transitions,
3409/3689 toggles. The wrapper now has50/51 statements, 38/39 branches,
7/7 conditions, 1/1 expressions, 8/8 states, 15/15 transitions, 298/302 toggles.
Other DUT instance counts are unchanged. The source form changes coverage
categories/denominators; no exclusions. FIFO3's B-select bit remains constant
for the legal routes, contributing the same two new constant toggle misses.
