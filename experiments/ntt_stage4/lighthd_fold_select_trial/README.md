# First-fold carry-select trial - 2026-10-10

Base: saved lighthd_route_pre_key_trial (145.20 MHz, 2362 ALMs, 20 M10Ks).
Only mod_mul.sv changes from that source. The selected speed checkpoint
lighthd_keep_bias_checkpoint (145.73 MHz) remains preserved separately.

## Change and arithmetic argument

Fold1 computes (hi<<13)-hi+lo from the registered 46-bit product. A carry-save
compressor represents this as two 36-bit words S and C, with subtraction's
+1 in C[0]. The result is nonnegative and fits 36 bits for all 23-bit operands.
Thus addition modulo 2^36 gives the exact first fold.

Compute S[17:0]+C[17:0] as a 19-bit lower sum. In parallel compute both upper
18-bit sums, one with carry-in zero and one with carry-in one. The lower
sum's bit18 selects the upper result. Concatenating it with the lower 18 bits
is exactly (S+C) mod 2^36. No register boundary, reset behavior, interface,
operation cycle count or mathematical result changes. Other folds unchanged.

## Source verification

Main UVM uvm_fold_select.log: 118/118 passing jobs, zero errors/fatals,
fourteen checked functional covergroup types at 100%. Existing all-lane PWM
boundary pairs include (0,0), whose lower carry is one, and (q-1,q-1), whose
lower carry is zero. Both are driven on every physical lane and independently
checked by registered operand, physical-writeback and full-output comparisons.
Golden SV model and Python/reference files unchanged.

Separate vector_fold_select.log / compare_fold_select.log: all 18 cases and
4608 coefficients match. Core cycles 266/266/74/235; wrapper 780/780/844/749.

Each multiplier's raw coverage: 44/44 statements, 12/12 branches, 1266/1460
toggle bins. All 194 missed toggle bins are the two directions of 97 constant
bits listed in the saved code report. The split exposes 40 additional constant
bits (80 bins) compared with the previous multiplier: C[0], 13 shift zeros,
13 high zero-extension bits and 13 high complement-one bits. Changed source
changes denominators; the lower toggle percentage is not a new dynamic hole.
No exclusions and no failed-UCDB merges. Main UVM remains the coverage source.

## Fitted result: rejected

Worst Fmax 121.30 MHz (slow0), slow85 127.53 MHz; 2397 ALMs, 2074 registers,
5 DSPs, 20 M10Ks, 37216 RAM bits. Worst setup/hold/pulse at 5 ns:
-3.244/+0.131/-0.555 ns. Same device, tools and constraints as the selected fit.
The full path shows Add1 feeding Add2: Quartus implements the upper carry-one
candidate as an addition followed by an increment. This serial path defeats
the intended parallel selection. Correct outputs do not make this a timing win.
All source and full map/fit/STA/path/UVM/Python evidence are saved here.
Do not select this trial. No netlist/FPGA claim or commit.
