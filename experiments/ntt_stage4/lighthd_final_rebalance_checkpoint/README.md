# Selected final-stage multiplier rebalance - 2026-10-09

Four-cycle multiplier: product / fold1 / fold2 / fold3+canonical correction.
BF latency 6 and issue-to-return tag delay 9 unchanged; core cycles 266/266/74/235,
wrapper no-stall 780/780/844/749 for NTT/INTT/PWM/Pre. Control/FIFO/twiddle RTL
is unchanged from lighthd_write_mux_checkpoint; only mod_mul.sv changes.

After fold2, t2<=75481088, H=t2>>23<=8. T=low+8191*H<=8454135<2q.
Compute T and T+8191 in parallel with carry-save compressors and one carry
propagation per candidate. Since T+8191<2^24, its bit23 is true exactly when
T>=q; selecting its low23 bits then gives T-q. Otherwise return T.
This replaces the separate fourth fold while preserving exact modular results.
Inline split-value boundary algebra check: 78 cases; not exhaustive RTL proof.

Fresh same-device map/fit/STA and report_paths.tcl:
Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite, standard fit, 5ns constraint.
2487 ALMs, 2081 registers, 5 DSP, 20 M10K, 37220 memory bits.
Slow85 Fmax 139.30 MHz, slow0 Fmax 134.50 MHz (worst).
Worst setup -2.435ns, hold +0.172ns, pulse width -0.555ns.
Compared with 131.22 MHz/2428 ALMs: +2.50% Fmax for 59 more ALMs (+2.43%).
New worst path at both slow corners: bf_bi_q[0][0] -> mul_gs_reg[10].
200MHz timing is not closed; post-netlist/board validation not performed.

Main UVM 117/117, zero errors/fatals, all 14 checked covergroup types 100%.
Each multiplier 35/35 statements, 10/10 branches, 876/990 raw toggles.
All 114 missed toggle bins are both directions on 57 constant bits; no exclusions.
Python compare 18/18 cases, 4608/4608 coefficients. Golden mathematics unchanged.
Coverage-credit negative test rejects five corruptions; writeback checker detects
corrupted observations with real DUT output correct and checked_jobs=0.
Both are separate UVM tests and their coverage is not merged into the main run.
All selected reports/logs are copied under results/. Nothing staged/committed.
