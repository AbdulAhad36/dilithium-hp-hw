set RTL ../src/ntt_LightHD
set CAND ntt_LightHD
set TB ../tb_uvm/tb_uvm_ntt
if {![file exists $CAND/work_core]} {vlib $CAND/work_core}
vmap work $CAND/work_core
vlog -sv -work work $RTL/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $TB/ntt_ref_pkg.sv \
  $CAND/tb_ntt_core.sv
vsim -c -voptargs=+acc work.tb_ntt_core
run -all
