set RTL ../experiments/ntt_stage3/banked_baseline/rtl
set CAND ../experiments/ntt_stage3/lighthd_fifo
set TB ../tb_uvm/tb_uvm_ntt
if {![file exists ntt_lighthd_engine_work]} {vlib ntt_lighthd_engine_work}
vmap work ntt_lighthd_engine_work
vlog -sv -work work $CAND/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $CAND/ntt_core.sv $RTL/ntt_engine.sv \
  $TB/ntt_ref_pkg.sv $CAND/tb_ntt_engine.sv
vsim -c -voptargs=+acc work.tb_ntt_engine
run -all

