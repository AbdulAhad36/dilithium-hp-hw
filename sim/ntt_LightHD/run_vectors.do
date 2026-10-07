# Run from sim/. This capture is separate from the full UVM regression.
set RTL ../src/ntt_LightHD
set TB ntt_LightHD
if {![file exists $TB/work_vectors]} {vlib $TB/work_vectors}
vmap work $TB/work_vectors
vlog -sv -work work $RTL/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv \
  $TB/tb_ntt_vectors.sv
vsim -c -voptargs=+acc work.tb_ntt_vectors \
  +NTT_OUTPUT_FILE=$TB/ntt_dut_outputs.txt
run -all
