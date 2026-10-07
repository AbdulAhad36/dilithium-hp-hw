# Standalone NTT DUT-output capture; no UVM, full regression, or coverage run.
# From sim/: vsim -c -do "do run_ntt_vectors.do; quit -f"
set RTL ../src/ntt_engine
set TB ../tb_uvm/tb_uvm_ntt
if {![file exists ntt_vector_work]} {vlib ntt_vector_work}
vmap work ntt_vector_work
vlog -sv -work work $RTL/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv $TB/tb_ntt_vectors.sv
vsim -c -voptargs=+acc work.tb_ntt_vectors
run -all
