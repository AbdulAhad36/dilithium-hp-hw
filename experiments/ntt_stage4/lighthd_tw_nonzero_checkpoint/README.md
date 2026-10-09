# Selected inverse twiddle zero-guard removal - 2026-10-10

Only ntt_core.sv differs from lighthd_sub_qplus1_checkpoint.
Remove the tw[lane] != 0 guard on inverse twiddle negation. All 256 initialized
ROM entries are canonical and nonzero, including entry zero (value 1). Thus
Q-tw is in [1,Q-1] for every ROM address; the legal issued values are unchanged.
After reset the registered ROM settles before a legal butterfly issue. The
existing independent UVM checks registered addresses/values and FIFO writebacks.
No pipeline, control schedule, interface, golden mathematics or vector changes.

Main UVM: 117/117, zero UVM errors/fatals, fourteen checked covergroup types 100%.
Python: 18/18 cases, 4608/4608 coefficients; cycles unchanged.
Separate checker self-tests reject five deliberately bad jobs without coverage
credit and detect an incorrect observed FIFO write with correct final outputs.
Illegal +8 Pre input reaches the exact intended DUT fatal. These expected-failure
UCDBs are not merged into main passing coverage.

Raw core condition coverage changes 64/103 -> 64/102 because one redundant
condition is removed; no extra condition hit is claimed. Other raw counts are
unchanged. No exclusions. Fresh map/fit/STA/paths select this candidate on Cyclone V 5CGXFC7C7F23C8,
Quartus25.1std Lite, standard fit and the unchanged 5ns constraint:
2427 ALMs, 2123 registers, 5 DSPs, 20 M10Ks, 37220 memory bits.
Slow85 Fmax143.43MHz, slow0 Fmax140.69MHz (worst).
Worst all-corner setup/hold/pulse slacks: -2.108/+0.086/-0.555ns.
Compared with the preserved137.04MHz/2451ALM checkpoint: worst Fmax +2.66%,
area -24ALMs(-0.98%), registers +52. Worst hold falls0.083ns but stays positive.
NTT wrapper/core modeled latency 780/140.69=5.54us,266/140.69=1.89us;
latency-based rate140.69e6/780=180372polynomials/s, excluding restart gaps,
stalls and SHAKE/sampler time. Not sustained integrated throughput.
Both slow-corner worst paths now run from FIFO1 RAM through word/operand muxes
to bf_bi_q[0][12]. 200MHz setup/pulse target remains unmet; Stage4 remains open.
Previous lighthd_sub_qplus1_checkpoint remains saved. No netlist/FPGA claim.
Nothing staged or committed.
