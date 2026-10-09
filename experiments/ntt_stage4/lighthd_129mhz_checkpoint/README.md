# Verified 129.08 MHz arithmetic checkpoint

Fresh main UVM uvm_final_fold.log: 116/116, zero errors/fatals, fourteen checked
functional covergroups 100%. vector_final_fold.log + compare_final_fold.log:
18/18 cases, 4,608/4,608 coefficients. coverage_gate_final_fold.log:
five deliberately corrupted jobs rejected without crediting arithmetic bins.
Golden SV mathematics are unchanged. These are source RTL checks, not netlist
or FPGA results.

Fresh Quartus map/fit/STA/report_paths.tcl: 2,717 ALMs, 2,078 registers, 5 DSPs,
20 M10Ks. Slow 85 C Fmax 130.79 MHz; worst slow 0 C 129.08 MHz. Worst setup
-2.747 ns, hold +0.154 ns at 5 ns. Minimum pulse width -0.555 ns. The 200 MHz
constraint fails. Core cycles NTT/INTT/PWM/Pre 266/266/74/235 and wrapper
780/780/844/749 remain unchanged.

Changes beyond the saved 114.26 MHz checkpoint:
- Parallel raw and biased CT add candidates in butterfly madd; q=2^23-8191.
- Apply the same canonical-input add identity to the measured Pre sum path.
- Specialize the multiplier's last fold. For any 23-bit inputs, fold3 <=
  8,454,135. If bit 23 is one, low <=65,527 and low+8191 <=73,718 <q.
  Otherwise fold4 is low itself. Its canonical result is low when low<q or
  the low 23 bits of low+8191 when low>=q. One 24-bit sum and a selector
  implement both cases, without serial fold/comparison/subtraction.

No added pipeline cycles or changes to FIFO architecture. Next fitted critical
path: inferred butterfly operand-delay RAM through final CT subtraction to b_o.
Both prior 114.26 and 119.33 MHz checkpoints are preserved. No commit was made.
