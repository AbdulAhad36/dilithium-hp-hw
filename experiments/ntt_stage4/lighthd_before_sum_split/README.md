# Saved LightHD baseline before Stage 4 sum split

Saved on 2026-10-09 before editing the active RTL. These six RTL files are a
rollback checkpoint; active design sources remain in `src/ntt_LightHD/`.
The copied reports are the existing 2026-10-08 fitted baseline, not a new build.

- Device: Cyclone V 5CGXFC7C7F23C8; Quartus 25.1std Lite.
- Resources: 3,003 ALMs, 1,973 registers, 6 DSP blocks, 20 M10Ks.
- Worst-corner Fmax: 96.56 MHz (slow 0 C).
- Worst setup/hold at 5 ns: -5.356 ns / +0.087 ns.
- Core cycles: NTT 266, INTT 266, PWM 74, bounded Pre-NTT 235.
- Wrapper launch-to-last-output: 780, 780, 844, 749 cycles respectively.

The measured slow 85 C critical path goes from butterfly `keep_b_reg` through
modular addition/comparison into the inferred RAM delay line. Stage 4's first
optimization registers the raw sum one stage earlier, replacing `keep_b_reg`,
and reduces it in the existing next stage. Butterfly latency stays six clocks;
core issue-to-return latency stays nine. The independent reference model is
unchanged. Restore these RTL files if a later candidate must be rolled back.
