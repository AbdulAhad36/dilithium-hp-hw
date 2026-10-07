set RTL ../experiments/ntt_stage3/banked_baseline/rtl
set CAND ../experiments/ntt_stage3/lighthd_fifo
if {![file exists ntt_lighthd_fifo_work]} {vlib ntt_lighthd_fifo_work}
vmap work ntt_lighthd_fifo_work
vlog -sv -work work $CAND/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $CAND/ntt_core.sv $RTL/ntt_engine.sv \
  $CAND/tb_ntt_vectors.sv
vsim -c -voptargs=+acc work.tb_ntt_vectors \
  +NTT_OUTPUT_FILE=../experiments/ntt_stage3/lighthd_fifo/ntt_dut_outputs.txt
run -all

