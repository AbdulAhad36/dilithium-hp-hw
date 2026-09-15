# Compile and run the byte-exact dual-core throughput benchmark.
if {[file isdirectory dual_throughput_work]} {
    vdel -lib dual_throughput_work -all
}
vlib dual_throughput_work

vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_pkg.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_param_unit.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_absorb_unit.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/theta_step.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/rho_step.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/pi_step.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/chi_step.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/iota_step.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_step_unit.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_output_unit.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_core.sv
vlog -work dual_throughput_work -sv ../src/keccak_engine/keccak_dual_interleaved.sv
vlog -work dual_throughput_work -sv ../tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv
vlog -work dual_throughput_work -sv ../tb_uvm/tb_uvm_keccak_v2/tb_keccak_dual_throughput.sv

vsim dual_throughput_work.tb_keccak_dual_throughput
run -all