# Register control tags and one-hot FIFO write masks ? 2026-10-10

Follow up the tag-register trial, whose slow85 limit is Pre valid -> FIFO1
write-data selection. Preserve the independent tag-only trial evidence.
Keep control-tag delays in FFs. In parallel with existing result/Pre arithmetic
registers, decode compute A/B masks per FIFO and the load/Pre sum/difference
masks. Combine masked data with OR rather than serial Pre-valid, upper-word,
compute-valid and A/B muxes. Data on inactive write ports may differ; every
enabled write, FIFO pointer, enable and active value must match the independent
UVM content/routing model. The FIFO controls themselves are unchanged.

No wide data register, added operation clock, arithmetic/golden-model change,
coefficient capacity change, interface change, clock-constraint change or TB
change. BF/return remains 7/10 clocks. Core cycles 267/267/75/236 and no-stall
wrapper cycles 781/781/845/750 remain unchanged.

Fresh main UVM passes 118/118 jobs, zero errors/fatals, fourteen checked
functional covergroup types 100%. Python passes 18/18 cases, 4,608/4,608
coefficients. Exact six-file RTL, hashes, UCDB/raw report and transcripts are
saved here. Main UVM was rerun after comment cleanup, so raw coverage line references
match the exact fitted RTL. Fresh implementation results are recorded below.

Raw core coverage: 305/317 statements, 221/233 branches, 49/78 conditions,
63/64 expressions, 5/5 states, 9/9 transitions and 3,421/3,701 toggles. The
280 constant misses remain visible; no exclusions. New source-selection bits
toggle as exercised by passing jobs; FIFO3's compute B source remains zero
because B never routes there. BF, wrapper and multiplier counts are unchanged.
The changed source form changes denominators, not the functional coverage plan.

## Fitted result: rejected

Fit completed 2026-10-10 18:34:21. Resources: 2,541 ALMs, 2,477 registers,
5 DSPs, 19 M10Ks, 37,280 RAM bits. Slow85/slow0 Fmax 144.89/143.53 MHz;
setup -1.902/-1.967 ns at unchanged 5 ns. Setup TNS -948.843/-1046.085 ns;
worst all-corner hold +0.152 ns, pulse -0.555 ns. Slow85 now limits at
Pre valid -> FIFO2 write data; slow0 at packed BF delay RAM -> a_o. The
one-hot masks pass every enabled-write/content check, but routing and the
remaining write-data paths worsen overall timing. Worst setup regresses
0.322 ns versus the selected -1.645 ns source. Reject and preserve this
trial; restore all six selected RTL files. No cycle increase or functional
failure is observed, and no implementation-timing improvement is claimed.
