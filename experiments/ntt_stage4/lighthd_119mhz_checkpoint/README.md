# Verified 119.33 MHz arithmetic checkpoint

Saved before specializing final multiplier reduction and Pre modular addition.
Fresh map/fit/STA: 2,808 ALMs, 2,042 registers, 5 DSPs, 20 M10Ks.
Slow 85 C 121.33 MHz, slow 0 C 119.33 MHz. Worst setup -3.380 ns and hold
+0.072 ns at 5 ns; setup/minimum pulse width fail. Core cycles 266/266/74/235,
wrapper 780/780/844/749 (NTT/INTT/PWM/Pre).

Main UVM uvm_biased_add.log passes 116/116 with fourteen checked covergroups
100%; vector_biased_add.log plus compare_biased_add.log pass 18/18 cases,
4,608/4,608 coefficients. coverage_gate_arithmetic.log rejects five corrupted
jobs without crediting arithmetic bins. These are source checks, not netlist
or FPGA results.

The butterfly madd computes parallel raw and biased candidates. q=2^23-8191;
for canonical inputs, biased=x+y+8191 <2^24, bit 23 iff raw>=q, and low 23
bits already equal raw-q when selected. A three-operand carry-save compressor
limits the biased candidate to one carry-propagate addition. No latency changes.
