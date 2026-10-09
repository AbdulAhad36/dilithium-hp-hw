# Parallel butterfly + Pre subtraction - intermediate, not selected

Fresh fit 2026-10-09: 2,594 ALMs, 2,005 registers, 5 DSPs, 20 M10Ks.
Slow 85 C Fmax 121.33 MHz (worst), slow 0 C 124.86 MHz; worst setup
-3.242 ns, hold +0.122 ns, minimum pulse width -0.555 ns at 5 ns.
Main UVM uvm_pre_parallel_sub.log 116/116, zero errors/fatals, fourteen
implemented covergroups 100%, ten arithmetic bins. Independent Python
vector_pre_parallel_sub.log + compare_pre_parallel_sub.log passes 18/18 cases,
4,608/4,608 coefficients. Cycles and SV golden mathematics unchanged.

This fit regresses Fmax against the preserved 129.08 MHz checkpoint and is
not selected alone. Both slow critical paths now start at state.IDLE and pass
through the FIFO write-data mux into FIFO2. The following trial separates
write-data selection from the load/write-valid control chain, preserving
all active write enables and cycle counts.
