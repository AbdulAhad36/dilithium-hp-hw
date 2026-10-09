# Direct route plus narrow Pre lookup trial - 2026-10-10

Apply the nine-value Pre lookup's four-bit key to the direct FIFO decoder
trial. For legal canonical residues representing -4..4, {x[22],x[2:0]}
uniquely identifies all nine values because q mod 8 = 1. Every table entry
matches (x*4808194) mod q. The full simulation eligibility guard is unchanged;
unsupported inputs can alias legal keys. Hardware callers must guarantee
canonical small-secret inputs; there is no new hardware eligibility flag.

Main UVM: 118/118 passing, zero errors/fatals, fourteen checked covergroup
types at 100%, including 27/27 Pre value/position bins and 16 observed
Pre/general bounded-secret equivalence pairs. Python: 18/18 cases and all
4608 coefficients match. Separate +8 alias test triggers the exact DUT fatal
"Pre-NTT requires every coefficient in [-4,4]". Its failed UCDB is separate.
Pipeline/core/wrapper cycles and independent golden mathematics unchanged.

| Metric | Selected keep-bias | Route plus narrow key |
|---|---:|---:|
| Worst Fmax MHz | 145.73 | 145.20 |
| Slow 85 C Fmax MHz | 145.73 | 150.24 |
| Slow 0 C Fmax MHz | 146.01 | 145.20 |
| ALMs | 2568 | 2362 |
| Registers | 2117 | 2102 |
| DSP / M10K | 5 / 21 | 5 / 20 |
| RAM bits | 37252 | 37216 |
| Worst setup at 5 ns | -1.862 | -1.887 |
| Worst all-corner hold ns | +0.104 | +0.156 |
| Worst pulse-width at 5 ns | -0.555 | -0.555 |

206 fewer ALMs (8.02%), 15 fewer registers and one fewer M10K. Slow 85 C
improves, but worst-corner Fmax falls 0.36%; preserve as a smaller alternative,
not the speed selection. Same Cyclone V, Quartus 25.1std Lite, fit and 5 ns
constraint. Core NTT/INTT/PWM/Pre cycles 266/266/74/235; wrapper 780/780/844/749.

Slow 0 C worst path: lane0 multiplier prod_s1[37] -> t1_q[34]. Slow 85 C:
pre_sum_q[24] -> FIFO1 write data. Lookup is no longer the reported worst path.
Core raw coverage: 295/307 statements, 232/245 branches, 53/84 conditions,
51/52 expressions, 5/5 FSM states, 9/9 transitions, 3405/3683 toggles.
Denominators differ from selected source; 278 constant-bit misses remain.
No coverage exclusions. Failed UCDBs not merged. No netlist/FPGA claim.

All exact RTL and map/fit/STA/path/main UVM/Python/alias-test evidence are
preserved here. The active RTL was restored to the faster keep-bias checkpoint
for a fresh rebuild. Nothing staged or committed.
