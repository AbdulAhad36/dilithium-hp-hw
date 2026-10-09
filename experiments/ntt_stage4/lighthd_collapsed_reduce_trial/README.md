# Collapsed reduction trial - not selected

Same four-cycle multiplier, six-cycle butterfly and nine-cycle return tag.
Stage 3: t1=L+2^23*H, H=1024*Hhi+Hlo; since 1024*8191=q+7167,
T=L+(Hlo<<13)-Hlo+7167*Hhi is congruent to t1 mod q.
T <= 16818169 can exceed 2q. Stage 3 conditionally subtracts q using parallel
raw/biased carry-save candidates; stage 4 completes canonical correction.
Stage-3 maximum after correction 8437752 is below stage-4 bound 8454135.

Main UVM 117/117, 14 checked functional covergroup types 100%, zero errors/fatals.
Each multiplier: 46/46 statements, 21/21 branches, 2/2 conditions, 1024/1124 toggles.
Separate Python: 18/18 cases, 4608/4608 coefficients; golden mathematics unchanged.
The new PWM job repeats five real operand pairs across all four lanes:
(0,0), (q-1,q-1), (4643571,5678082), (7083480,6206081), (6777144,6489384).
Observed results 0/1/1/10000/30000, with expected physical writebacks and output checked.
The last pair also toggles raw T bit 24; it was reachable, not a constant hole.
Inline algebra check exercised 65614 split-value boundary cases, not an exhaustive RTL proof.

Fresh fit: 2671 ALMs, 2078 registers, 5 DSP, 20 M10K.
Slow 85 C Fmax 125.23 MHz, slow 0 C 123.38 MHz (worst).
Worst setup -3.105 ns, hold +0.172 ns, minimum pulse width -0.555 ns at 5 ns.
Both slow critical paths: multiplier t1_q[6] -> t3_q[14].
Rejected: lower Fmax and higher area than selected 131.22 MHz / 2428 ALMs.
All six active RTL files restored from lighthd_write_mux_checkpoint after measurement.
The useful directed UVM boundary job is retained on the selected implementation.
