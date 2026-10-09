# Saved carry-save reduction checkpoint

2026-10-09, same Cyclone V device/Quartus/5 ns constraint as the prior fit.
Resources: 2,942 ALMs, 2,040 registers, 6 DSPs, 20 M10Ks.
Worst setup -4.349 ns; worst hold +0.146 ns. Worst-corner Fmax is 106.96 MHz (slow 0 C).
Main UVM 115/115, Python 18/18 cases and 4,608/4,608 coefficients, unchanged cycles.
Critical path moved from the multiplier to rx_idx[0] -> load_pack[36].
Active RTL remains in src/ntt_LightHD; this is rollback evidence.

The next fixed-lane packing change is retained at 114.26 MHz, 2,777 ALMs and 5 DSPs; see the active project results. This remains a saved intermediate checkpoint.
