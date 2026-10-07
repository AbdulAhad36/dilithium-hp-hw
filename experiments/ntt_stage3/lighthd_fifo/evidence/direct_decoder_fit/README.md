# Direct-decoder FIFO checkpoint

This directory freezes the candidate package/core, source-test logs, and
post-fit reports used for the Stage 3 comparison. The remaining RTL comes
from `../../../banked_baseline/rtl/`; the Quartus source list is
`../../quartus/ntt.qsf`. `SHA256.txt` identifies the frozen candidate files.

Questa: Python output comparison 18/18 cases and 4,608/4,608 coefficients;
core directed 39/39; engine directed 34/34; standard-mode UVM 53/53.

Quartus Prime Lite 25.1std, Cyclone V 5CGXFC7C7F23C8, 5 ns clock:
3,003 ALMs, 1,973 registers, 6 DSP blocks, 20 RAM blocks. TimeQuest
multicorner worst Fmax is 96.56 MHz (Slow 0 C), worst setup slack is
-5.356 ns at the 5 ns constraint, and worst hold slack is +0.087 ns.
The timing target is unmet. The detailed critical path report is
`critical_paths.log` (Slow 85 C path); all corners are in `ntt.sta.rpt`.

Complete no-stall NTT transaction: 780 cycles / 96.56 MHz = 8.0779 us.
The measurement includes the 256-beat input and 256-beat output wrapper.
