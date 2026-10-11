# Early FIFO A/B selection control trial - 2026-10-10

Base: selected lighthd_fold_pipeline_checkpoint, 148.46 MHz / 2490 ALMs,
committed c2cccd2. Exact six RTL files for this trial are in rtl/.
Only ntt_core.sv changes; TB/reference/clock/interface/FIFO capacities do not.

## Method

Decode !PWM && dest_b==FIFO in three control flops from tag[8], in parallel
with the existing result_a/b registers. The return-stage data mux uses these
registered bits instead of tag[9] PWM and binary destination decoding.
The tag pipeline, memory write controls and load/Pre/compute priority stay
unchanged. No wide compute-word registers, extra pipeline clock or FIFO slot.
Multiplier/BF/issue-return pipeline remains 5/7/10.

## Fresh source verification

Main uvm_write_select.log: 118/118, zero UVM errors/fatals, all fourteen checked
functional covergroup types at 100%. All observed operands, physical writes,
complete outputs, framing and nine reset/recovery points remain checked.
vector_write_select.log / compare_write_select.log: 18/18 cases and all
4608 coefficients match. Core NTT/INTT/PWM/Pre cycles 267/267/75/236;
no-stall wrapper cycles 781/781/845/750.

routing_writeback_write_select.log detects an injected observation fault
while real outputs remain correct and checked_jobs=0. Its failed UCDB/report
are saved separately and not merged. Other unchanged negative-test evidence
remains preserved and is not claimed as freshly rerun for this trial.

Core raw coverage: 300/312 statements, 234/247 branches, 49/78 conditions,
55/58 expressions, 5/5 states, 9/9 transitions, 3409/3689 toggles. The two
active select bits each toggle both ways; bit2 never toggles because legal
routes place B only in FIFO1 or FIFO2 (FIFO3 receives A). It contributes two
new constant toggle misses, beyond the baseline's 278. Expression/condition
denominators also change with the source form; no exclusions or raw closure
claim. Other DUT instance counts remain unchanged.

## Fitted result: not selected

Fresh map/fit/STA/critical paths: slow85 Fmax 149.59 MHz, slow0 144.72 MHz.
Worst144.72 MHz; 2479 ALMs, 2451 registers, 5 DSP, 20 M10K, 37325 RAM bits.
At unchanged 5 ns, worst setup -1.910 ns, hold +0.102 ns, pulse -0.555 ns.
Fit completed2026-10-10 04:30:14. Both slow corners now limit at wrapper
tx_idx[4] -> core FIFO head1[4] via prefetch-address and output-pop decoding.
Slow85 improves 0.051 ns, but slow0 worsens enough that worst setup regresses
0.174 ns and worst Fmax falls3.74 MHz against selected 148.46 MHz. The 11ALM and
oneM10K savings do not make this the selected timing result. Kept as the base
for a measured follow-up that simplifies the prefetch address path.
