# Parallel butterfly subtraction only - intermediate, not selected

2026-10-09, same Cyclone V project and 5 ns constraints. Fresh fit: 2,589 ALMs,
2,009 registers, 5 DSPs, 20 M10Ks. Slow 85 C 125.16 MHz, slow 0 C 126.55 MHz;
worst setup -2.990 ns and hold +0.137 ns. Minimum pulse width -0.555 ns.

Main UVM uvm_parallel_sub.log 116/116, zero errors/fatals, fourteen covergroups
100%, including ten sum/subtraction bins. Python vector_parallel_sub.log +
compare_parallel_sub.log 18/18 cases and 4,608/4,608 coefficients. Separate
gate coverage_gate_parallel_sub.log rejects five corrupted jobs without credit.
No latency or golden math changes. Prior 129.08 MHz checkpoint remains saved.

The measured path moved from final butterfly subtraction to Pre-NTT
pre_product_q -> pre_diff_q at both slow corners. Area falls but Fmax regresses;
this intermediate is not selected by itself. The next trial applies the same
parallel correction to that measured Pre subtraction path.
