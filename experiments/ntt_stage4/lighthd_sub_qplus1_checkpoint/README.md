# Selected q+1 butterfly subtraction - 2026-10-09

Only butterfly_unit.sv differs from lighthd_final_rebalance_checkpoint.
For canonical x/y, raw 24-bit x-y has bit23 set iff x<y. The corrected candidate
x-y+q is formed as x+~y+(q+1), with a 24-bit complement. Absorb +1 into the
constant before carry-save compression; add the save word to the shifted carry
word with bit0=0. Previous code compressed q and injected +1 at the final adder.
Both are identical modulo 2^24; the corrected exact result lies in [1,2q-1].
On borrow select correction [1,q-1]; otherwise select raw [0,q-1].
The helper is shared by inverse GS input subtraction and forward CT output
subtraction. Pre first-stage helper in ntt_core.sv is unchanged.
Inline boundary algebra check: 81 pairs; not exhaustive RTL proof.

Fresh map/fit/STA/report_paths on same Cyclone V 5CGXFC7C7F23C8,
Quartus25.1std Lite, standard fit, 5ns constraint:
2451 ALMs, 2071 registers, 5 DSP, 20 M10K, 37220 memory bits.
Slow85 Fmax139.06MHz, slow0 Fmax137.04MHz (worst).
Worst setup -2.297ns, hold +0.169ns, pulse width -0.555ns.
Previous134.50MHz/2487ALMs: worst Fmax +1.89%, area -36ALMs(-1.45%),
registers -10. Slow85 Fmax falls0.24MHz; worst hold falls0.003ns but stays positive.
Both slow critical paths now originate in twiddle ROM and end in bf_zi_q.
200MHz target is not met. No netlist or FPGA verification claim.

Main UVM117/117, zero errors/fatals; all14 checked covergroup types100%.
Each BF54/54 statements,17/17 branches,1/1 condition,656/656 toggles.
Each multiplier35/35 statements,10/10 branches,876/990 toggles; no exclusions.
Core/wrapper raw coverage unchanged. Python18/18 cases,4608/4608coefficients.
BF/mult/tag latency6/4/9; core266/266/74/235 and wrapper780/780/844/749 unchanged.
Golden mathematics unchanged. Existing checker self-tests are preserved in the
preceding checkpoint; checker code and latency contracts were not modified.
Source/results copied here; nothing staged or committed.
