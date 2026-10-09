# Selected fixed Boolean operand selector - 2026-10-10

Combined read-launch FIFO/coefficient masks, fixed Boolean equations instead
of variable bit-index decoder. Packed arrays expose per-bit toggle coverage.
Unused source_a_q/source_b_q registers removed; independent checker unchanged.
Same FIFO/butterfly/tag latencies; no added pipeline or changed cycle counts.
Main117/117, zero UVM errors/fatals,14checked covergroup types100%.
Python18/18cases,4608/4608coefficients. Exact code counts in saved raw report;
no exclusions or failed-UCDB merges. Selected for higher worst-corner Fmax after fresh map/fit/STA/paths:
145.18MHz worst(slow85),148.37MHz slow0;2592ALMs,2152registers,5DSP,
21M10Ks,37252memorybits. Worst setup/hold/pulse slacks -1.888/+0.168/-0.555ns.
Compared with saved140.69MHz reference: Fmax+3.19%,ALMs+165(+6.80%),
registers+29,M10Ks+1,memorybits+32. Hold improves0.082ns. This is a speed/area
tradeoff, not a simultaneous area improvement. Same device/Quartus/5ns constraint.
Core cycles266/266/74/235;wrapper780/780/844/749, unchanged.
NTT modeled wrapper/core latency780/145.18=5.37us,266/145.18=1.83us;
latency-based rate145.18e6/780=186128polynomials/s. Excludes restart gaps,
stalls and SHAKE/sampler waiting; not sustained integrated Dilithium throughput.
Slow85 worst path: BF lane2 keep_sum_reg -> shared lane3 keep_dly shift RAM.
Slow0 worst path: FIFO1 RAM -> bf_bi_q lane0. Both remain measured targets.
200MHz setup/pulse target unmet; Stage4 remains open. No netlist/FPGA claim.
The smaller140.69MHz checkpoint is preserved, and the137.87MHz generic-selector
trial is rejected/saved. Fresh coverage-credit and operand/writeback corruption
self-tests detect failures without credit; their UCDBs remain separate.
Nothing staged/committed.

Raw core coverage:270/282 statements,219/233branches,55/92conditions,
47/48expressions,5/5FSMstates9/9transitions,3399/3677toggles. Other instances
unchanged. No exclusions. Selector arrays are packed and instrumented.
Reachable A mask bits by lane:2/3/3/4 (12); B:5/4/4/3 (16), total28.
For each combinational and registered copy, all28 variable bits toggle both
ways:28*2copies*2directions=112hits. Four masks contain192bits total;
136constant-zero selector bits produce272missed toggle bins. Three remaining
constant nodes(source_a[1],dest_b[1],load_dest[1]) add6misses:272+6=278.
The previous unpacked trial's3293/3301 raw counts omitted selector array bits.
Remove the unused source registers:8bins,6hits removed; add packed masks:
384bins,112hits. Thus3293-6+112=3399hits;3301-8+384=3677bins. These are
source/tool denominator changes, not a functional coverage gain or an exclusion.

The first trial's extra32memory bits are a Quartus-inferred8x4tag inverse
shift RAM, not a coefficient buffer or selector ROM. Fixed Boolean coding
alone does not guarantee a different memory mapping; fresh reports decide.
