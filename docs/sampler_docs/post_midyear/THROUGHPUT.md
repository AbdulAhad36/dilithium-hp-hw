# Sampler throughput and resources

## Current retained Stage4.9r - 2026-10-19

Area means final-placement ALMs. Needed estimates do not enter selection or
improvement claims. Same device,Quartus25.1std,seed1 and6.500ns constraint.
R combines the simpler20-bit mask arithmetic at the original pre-packing stage
with HIGH PERFORMANCE EFFORT and physical register retiming explicitly OFF.
All original register guards pass. Both RTL and compiler settings contribute
to this implementation;the full PPA gain is not attributed to RTL alone.

| Metric |Previous4.9j|Retained4.9r|
|---|---:|---:|
| Actual placed ALMs |3628|3537|
| Registers |3928|3931|
| Combinational ALUTs |4405|4256|
| Worst Fmax MHz |163.16|164.74|
| Worst setup ns at6.5ns |+0.371|+0.430|
| Worst hold ns |+0.161|+0.141|
| M10K / logical bits |1 /1024|1 /1024|
| DSP |0|0|

Physical area falls91 ALMs(2.51%);ALUTs fall149(3.38%). Fmax rises1.58MHz.
Registers are3860 implementation+71 router copies:3 extra router registers
compared withJ. Slow85/0 Fmax167.59/164.74MHz. All4 corners have0 setup/hold
TNS and positive pulse-width margins. Hold margin remains positive but is
0.020ns smaller thanJ. No timing corner is omitted.

| Continuous single-job mode |J cycles|R cycles|Mcoeff/s at153.85MHz|
|---|---:|---:|---:|
| Matrix A |302-304|302-304|129.555-130.413|
| Secret |285-320|285-320|123.077-138.192|
| Mask |270|270|145.869|
| Challenge |902-969|902-969|40.645-43.664|

All96 CSV records are byte-identical toJ,including paired and stalled cases.
Operating throughput at153.85MHz is preserved;Fmax is headroom,not a changed
operating clock. Source TB uses100MHz;rates are cycle-derived and qualified
by fitted internal timing. No board/integration throughput claim.

Source is byte-identical toO. Its621-job UVM/159628 comparisons,Python104/
19456,C48/12288,checker12,performance96 and5 zero-credit faults are reused only
after26 source/model/launcher hashes match. R has a fresh full fit,complete
structural guards and multicorner timing. Evidence: STAGE4_9R_RESULTS.json and evidence/stage4_9r.zip. User acceptance: 2026-10-19.

## Measurement boundary

Cycles run from accepted descriptor to the last accepted coefficient. The
continuous figures assume available input and output readiness; paired/stalled
results are retained in sim/sampler/performance.csv. Source TB runs at 100 MHz;
the table scales measured cycles to the fitted 153.85 MHz operating constraint.
Fmax is timing headroom, not the operating clock or measured board throughput.

## LightHD comparison

Published source: LightHD, Section III.C and Section V, Tables II/III; retained
in docs/refernce-paper-hw. Different FPGA families prevent direct LUT/ALM ratios.

| Metric | LightHD publication | Accepted sampler |
|---|---|---|
| FPGA/tools | Artix-7 XC7A200T / Vivado 2020.1 | Cyclone V 5CGXFC7C7F23C8 / Quartus 25.1std |
| Sampling functions | Four | Four |
| Logic | 4035 LUTs | 3537 placed ALMs; 4256 ALUTs |
| Registers | 1157 FFs | 3931 fitted registers |
| Dedicated memory | 0 BRAM; challenge uses distributed RAM | 1 M10K, 1024 logical bits |
| DSPs | 0 | 0 |
| Frequency | 212.8 MHz full accelerator; standalone sampler Fmax not separately given | 164.74 MHz standalone worst Fmax |
| Processing width | 64-bit words | Tagged 128-bit input split into 64-bit chunks |
| Polynomial latency | Comparable standalone boundary not published in reviewed section | A302–304, secret285–320, mask270, challenge902–969 cycles |
| Integration/security | Full accelerator scope | Standalone functional/internal timing evidence; no integration or security signoff |

212.8 MHz is not a published isolated sampler benchmark. No standalone sampler
throughput advantage over LightHD is claimed.
