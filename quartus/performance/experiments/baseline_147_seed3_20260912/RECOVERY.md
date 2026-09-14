# 147.21 MHz Baseline Recovery Record

The original archive contained Quartus settings and reports, but it did not
contain an RTL snapshot or the Quartus fitter database.

The RTL in the `rtl/` directory was reconstructed from the retained Codex
session record by restoring the source state before the three later
optimizations:

- theta D-expression folding
- redundant control-predicate removal
- removal of the 1,600-bit state array from the asynchronous reset network

The archived reports remain the authoritative evidence for the historical
147.21 MHz fit (setup slack +0.010 ns, hold slack +0.168 ns, 4,265 ALMs and
1,674 registers). A clean recompilation may produce a different Fmax because
the placement-and-routing database used by that fit was not archived.

This record does not claim that a new compile reproduced the historical fit.

## Clean Recompile

A clean Quartus Prime Standard 25.1 compilation of the recovered RTL produced:

- 137.53 MHz worst-corner Fmax
- -0.468 ns worst-case setup slack against the 6.803 ns constraint
- +0.168 ns worst-case hold slack across all reported corners
- 3,429 ALMs
- 1,674 registers

The full source UVM regression passed all 888 checked transactions with zero
UVM errors and zero UVM fatals before this compile.
