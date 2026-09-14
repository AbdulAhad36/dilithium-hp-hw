# Accepted Seed-5 Reproduction

Date: 2026-09-13  
Tool: Quartus Prime Lite 25.1  
Device: Cyclone V `5CGXFC7C7F23C8`

## Configuration

- One complete Keccak-f[1600] round per clock.
- Seed 5.
- 7.407 ns clock constraint (135 MHz operating point).
- High Performance Effort, Standard Fit, physical synthesis, register
  duplication/retiming, and maximum router timing optimization.
- Virtual data/control pins; physical clock retained.

## Result

| Metric | Value |
|---|---:|
| TimeQuest Fmax estimate | 142.90 MHz |
| Slow-85 C setup slack | +0.409 ns |
| Worst hold slack across all corners | +0.168 ns |
| Setup / hold TNS | 0.000 ns / 0.000 ns |
| ALMs | 3,431 |
| Registers | 1,674 |
| DSP / block RAM | 0 / 0 |

The full compilation completed with zero errors. Analysis and Synthesis had
zero warnings. The fitter's three existing warnings concern the unavailable
LogicLock subscription feature, incomplete board I/O standards, and the clock
pin without a board-specific location. TimeQuest completed with zero warnings
and reports all setup and hold paths constrained.

This run reproduces the earlier seed-5 checkpoint after a rejected 140 MHz
experiment. Quartus report files are not expected to be byte-identical because
they contain run timestamps; the timing and resource metrics reproduced.
