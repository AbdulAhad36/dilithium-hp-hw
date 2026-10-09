# Selected inverse kept-sum carry reduction - 2026-10-10

Only butterfly_unit.sv differs from lighthd_operand_boolean_checkpoint.
For canonical a/b, S=a+b lies in[0,2q-2]. With2^23-q=8191,
B=S+8191 lies in[8191,16769023], strictly below2^24. B[23]=1 iffS>=q.
Ifset,B[22:0]=S-q;elseS[22:0]=S. This replaces a separate comparator and
subtraction selection, without adding stages or changing arithmetic results.
CT still selects keep_a_reg. Multiplier/BF/return latency4/6/9 unchanged.
Core266/266/74/235;wrapper780/780/844/749 unchanged. Independent oracle and
UVM trace/routing/value checks unchanged. Main118/118,zero UVM errors/fatals,
14checked covergroup types100%. Python18/18cases,4608/4608coefficients.
Raw counts are in saved report; no exclusions or failed-UCDB merges.
Fresh map/fit/STA/paths select145.73MHz worst(slow85),146.01MHz slow0;
2568ALMs,2117registers,5DSP,21M10Ks,37252memorybits.
Worst setup/hold/pulse slacks at5ns:-1.862/+0.104/-0.555ns.
Against145.18MHz/2592ALMs: worstFmax+0.38%,ALMs-24(-0.93%),registers-35,
setup+0.026ns. Slow0Fmaxfalls2.36MHz and worstholdfalls0.064ns but stayspositive.
Same CycloneVdevice,Quartus25.1stdLite,standardfit and5ns constraint.
NTT modeled wrapper/core780/145.73=5.35us,266/145.73=1.83us;
rate145.73e6/780=186833polynomials/s, excluding gaps/stalls/SHAKE/sampler time.
Not sustained integrated throughput. Prior145.18 andsmaller140.69checkpoints saved.
Nextslow85path:tick[6] -> FIFO read-enable;slow0:lane2 multiplier prod_s1 -> t1_q.
200MHz setup/pulse timing stillfails;Stage4open. No netlist/FPGA claim. No staging/commits.

Main118 adds one GS-sum boundary job to prior117. At stage0, plant pairs
(0,0),(0,q-1),(1,q-1),(2,q-1),(q-1,q-1) on all four physical lanes.
The actual registered GS operand classifier uses plain integer sums and
requires all5class bits per lane before scoreboard publication. Independent
mathematical FIFO writeback/physical-memory and all256output checks must pass.
CHECKED_GS_SUM_BOUNDARIES reports11111/11111/11111/11111. No new covergroup
percentage is invented:14existing groups remain100%; this is an extra witness.
A separate negative GS gate clears only lane2 exact-q metadata, retains correct
real outputs and trace, and must reject without new checked coverage.
UVM GS SUM GATE PASS and existing five-failure UVM COVERAGE GATE PASS both
record correct rejection. Their UCDBs are not merged into the passing database.
Each BF now55/55statements,17/17branches,704/704toggles; oldcomparator condition
is replaced by a single carry-bit selection with no logical condition bin.
Core/wrapper/multiplier raw counts remain unchanged; no exclusions.

## Fresh restoration after decoder trials (2026-10-10)

Both direct-route alternatives remain saved separately. Restored active RTL
matches these six source files byte-for-byte. Fresh keep_bias_restore map,
fit, STA and critical-path logs reproduce 145.73/146.01 MHz, 2568 ALMs,
2117 registers, 5 DSPs, 21 M10Ks and worst setup/hold/pulse slacks
-1.862/+0.104/-0.555 ns. Restored reports are saved with a restored_ prefix.
Fresh main UVM passes 118/118 with fourteen checked groups at 100%; separate
Python comparison passes all 4608 coefficients in 18 cases. Latest active
results and implementation database match the restored source. Stage 4 open.
Nothing staged or committed.

## Fresh restoration after first-fold trials (2026-10-10)

fold_trials_restore map/fit/STA/paths again reproduce 145.73/146.01 MHz,
2568 ALMs, 2117 registers, 5 DSPs / 21 M10Ks, 37252 RAM bits and worst
setup/hold/pulse -1.862/+0.104/-0.555 ns at 5 ns. Fresh main UVM118/118,
14 checked groups100%; Python18/18cases,4608/4608coefficients. Active RTL
is byte-identical to this checkpoint and active database/results match it.
Both rejected trials remain saved. No staging or commits.
