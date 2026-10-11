# Common main-UVM netlist flow; invoke run_post_synthesis.do or run_post_fit.do.
onerror {quit -code 1 -f}
if {![info exists NTT_REPRESENTATION] || ![info exists NTT_NETLIST_FILE]} {error "Use run_post_synthesis.do or run_post_fit.do"}
if {![file exists $NTT_NETLIST_FILE]} {error "Generate netlists using quartus/ntt_LightHD/generate_netlists.ps1 first"}
if {![info exists NTT_TEST]} {set NTT_TEST ntt_netlist_test}
do ntt_LightHD/setup_cyclonev_libs.do
set NTT_WORK ntt_LightHD/work_$NTT_REPRESENTATION
if {![file exists $NTT_WORK]} {vlib $NTT_WORK}
vmap work $NTT_WORK
set RTL ../src/ntt_LightHD
set TB ../tb_uvm/tb_uvm_ntt_LightHD
vlog -sv -work work $RTL/ntt_pkg.sv
# Only the generated DUT; source ntt_engine/core/datapath must not be compiled.
vlog -work work $NTT_NETLIST_FILE
vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_ref_pkg.sv $TB/ntt_if.sv
vlog -sv +define+NTT_FIFO +define+NTT_NETLIST +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver work.tb_top +UVM_TESTNAME=$NTT_TEST +NTT_REPRESENTATION=$NTT_REPRESENTATION
onfinish stop
run -all
quit -sim
foreach variable {NTT_WORK NTT_TEST NTT_REPRESENTATION NTT_NETLIST_FILE} {unset $variable}
