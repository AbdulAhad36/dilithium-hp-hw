# Main LightHD UVM regression: checked functional coverage + DUT code coverage.
# Run from sim/: vsim -c -do "do ntt_LightHD/run_uvm.do; quit -f"
onerror {quit -code 1 -f}
if {![info exists NTT_WORK]} {set NTT_WORK ntt_LightHD/work_uvm}
if {![info exists NTT_UCDB]} {set NTT_UCDB ntt_LightHD/ntt_lighthd_cov.ucdb}
if {![info exists NTT_REPORT]} {set NTT_REPORT ntt_LightHD/ntt_lighthd_coverage.rpt}
if {![info exists NTT_TEST]} {set NTT_TEST ntt_full_test}
vlib $NTT_WORK
vmap work $NTT_WORK
set RTL ../src/ntt_LightHD
set TB ../tb_uvm/tb_uvm_ntt_LightHD
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv +cover=sbceft -work work $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv
vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_ref_pkg.sv $TB/ntt_if.sv
vlog -sv +define+NTT_FIFO +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
vsim -coverage -voptargs=+acc work.tb_top +UVM_TESTNAME=$NTT_TEST
coverage save -onexit $NTT_UCDB
onfinish stop
run -all
coverage report -details -output $NTT_REPORT
quit -sim
foreach variable {NTT_WORK NTT_UCDB NTT_REPORT NTT_TEST} {unset $variable}
