# Run from sim/. This capture is separate from the full UVM regression.
set RTL ../src/ntt_LightHD
set TB ../tb_uvm/tb_uvm_ntt_LightHD
set CAND ntt_LightHD
if {![file exists $CAND/work_vectors]} {vlib $CAND/work_vectors}
vmap work $CAND/work_vectors
vlog -sv -work work $RTL/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv \
  $TB/tb_ntt_vectors.sv
vsim -c -voptargs=+acc work.tb_ntt_vectors \
  +NTT_OUTPUT_FILE=$CAND/ntt_dut_outputs.txt
run -all
