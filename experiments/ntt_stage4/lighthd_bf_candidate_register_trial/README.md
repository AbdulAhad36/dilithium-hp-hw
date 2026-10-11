# Butterfly arithmetic candidates before correction mux ? 2026-10-10

Base: `lighthd_write_select_prefetch_checkpoint`, 150.49 MHz, 2,475 ALMs,
worst setup -1.645 ns at 5 ns. Only `butterfly_unit.sv` changes. Exact six
RTL files and SHA256 hashes are retained in this folder.

## Method

The baseline slow0 critical path is packed kept-operand delay RAM through
modular addition and final selection to the BF output register. Register the
raw/biased sum and raw/corrected difference candidates before their correction
and CT/GS mode selection. Keep GS passthrough operands and the mode aligned in
that same register stage. Canonical a_o/b_o are selected combinationally from
these registered candidates before the core's existing result register.

All arithmetic identities are unchanged, including the canonical-input
requirement. Total BF latency stays seven clocks and issue-to-return stays ten.
This is a changed cut within the existing pipeline, with more registered
candidates. There is no added operation clock, interface/FIFO capacity change,
timing-constraint change, testbench change or golden-model change. A positive
physical benefit must be established by the complete fit and STA.

## Fresh source verification

`uvm_bf_candidates.log`: 118/118 jobs, zero errors/fatals, all fourteen checked
functional covergroup types 100%. `compare_bf_candidates.log`: 18/18 cases,
4,608/4,608 coefficients. Core NTT/INTT/PWM/Pre cycles remain 267/267/75/236;
no-stall wrapper cycles remain 781/781/845/750. Raw main coverage and UCDB are
archived separately here. No raw-code exclusions or coverage-model edits.

Raw BF coverage per instance: 72/72 statements, 22/22 branches and 1,500/1,610
toggles. The 110 missed toggle bins belong to 55 constant bits: 24 bias bits,
24 modulus bits, and seven zero/sign-extension or compressor top bits. They
are visible in the raw report, not excluded. The registered candidates and
mode do not have missed toggle bins. Core/wrapper/multiplier counts remain
unchanged. A lower raw percentage here reflects newly visible constants,
not a newly untested functional case.

## Implementation result: rejected

Fit completed 2026-10-10 18:14:15. Resources: 2,525 ALMs, 2,793 registers,
5 DSPs, 20 M10Ks, 37,305 RAM bits. Slow85/slow0 Fmax 135.59/131.20 MHz.
At unchanged 5 ns, setup -2.375/-2.622 ns and TNS -1027.721/-1090.113 ns.
Worst all-corner hold +0.136 ns; pulse -0.555 ns. Slow85 now limits
at GS kept-sum register -> packed BF delay RAM input. Slow0 limits at
registered CT difference borrow -> core result through correction/scaling;
that path also appears among the slow85 top three.
The moved register boundary removes the former output-mux path but lengthens
other paths. Worst setup regresses 0.977 ns; reject this mapping and preserve
its complete evidence. No source-correctness failure or cycle increase.
