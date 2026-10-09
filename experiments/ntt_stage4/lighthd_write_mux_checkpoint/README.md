# Selected 131.22 MHz subtraction / FIFO-data checkpoint

2026-10-09, same Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite, 5 ns.
Fresh fitted resources: 2,428 ALMs, 2,022 registers, 5 DSPs, 20 M10Ks.
Slow 85 C Fmax 131.32 MHz; slow 0 C 131.22 MHz (worst). Worst setup
-2.621 ns; worst hold +0.129 ns; minimum pulse width -0.555 ns. 200 MHz
setup and pulse width still fail. No netlist or FPGA result is claimed.

Main UVM uvm_write_mux.log passes 116/116, zero errors/fatals, fourteen
implemented checked covergroups 100%, including ten CT arithmetic bins.
Vector/Python vector_write_mux.log + compare_write_mux.log passes 18/18 cases,
4,608/4,608 coefficients. coverage_gate_write_mux.log rejects five corrupted
jobs with no coverage credit. routing_writeback_write_mux.log detects a
corrupted observed writeback with zero checked jobs/bins, real outputs correct.
Core cycles 266/266/74/235 and wrapper 780/780/844/749 remain unchanged.

Parallel butterfly and Pre modular subtraction replaces comparison/serial
correction with parallel raw and carry-save corrected candidates. FIFO
write-data selection is separated from the state/input-valid/address decode;
write enables and pointers are unchanged. Load/Pre/compute phases cannot
write simultaneously; a simulation guard checks this. Unused data ports are
not zeroed, while every actual write is checked by the independent UVM model.

Saved 129.08 MHz build remains the comparison/rollback reference. Two slower
intermediates are saved separately and not selected. New slow 85 C path is
load_pack -> Pre lookup -> pre_product_q; slow 0 C path is multiplier
t1_q -> folds 2/3 -> t3_q. Nothing was staged or committed.
