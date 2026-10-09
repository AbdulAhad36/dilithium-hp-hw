# Saved Stage 4 101.28 MHz checkpoint

Accepted working checkpoint before carry-save fold optimization, 2026-10-09.
Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite, 5 ns target.
2,937 ALMs, 2,017 registers, 6 DSPs, 20 M10Ks.
Worst-corner Fmax 101.28 MHz; setup -4.874 ns, hold +0.121 ns.
Core NTT/INTT/PWM/Pre cycles 266/266/74/235; wrapper 780/780/844/749.
Main UVM 115/115 and independent Python 18/18 cases, 4,608/4,608 coefficients.
These files are rollback evidence; active design sources remain under src/ntt_LightHD.

## Next candidate: carry-save fold

The prior slow-corner critical path traverses two folds between `t1_q` and
`t3_q`. Each old fold computes `hs-hi+lo` with serial carry chains. The candidate
replaces each fold with a three-operand compressor and one final carry chain:

- `hs = hi << 13`, `w = ~zero_extend(hi)`.
- `save = hs XOR lo XOR w`.
- `carry = ((hs AND lo) OR (hs AND w) OR (lo AND w)) << 1`.
- `result = save + (carry OR 1)` in 38-bit unsigned arithmetic.

The compressor identity gives `save+carry = hs+lo+w` modulo `2^38`.
Since `w = 2^38-1-hi`, injecting the low-bit one gives `hs+lo-hi` modulo
`2^38`. The mathematical fold is nonnegative and fits 38 bits, so this is
exact, not an approximation. `carry[0]` is zero before injection.
The existing 4-cycle multiplier and 6-cycle butterfly are unchanged.
Verification passes 115/115 UVM jobs and 4,608/4,608 Python coefficients;
routed timing must pass the comparison before this candidate is retained.
