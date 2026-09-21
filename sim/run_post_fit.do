# Dual-core interleaved Keccak post-fit timing simulation.
# Generate the timing netlist and SDF first with Quartus EDA Netlist Writer.

onerror {quit -code 1 -f}
set launch_dir [file normalize [pwd]]
if {[file exists [file join $launch_dir run_post_fit.do]]} {
    set script_dir $launch_dir
} elseif {[file exists [file join $launch_dir sim run_post_fit.do]]} {
    set script_dir [file join $launch_dir sim]
} else {
    error "Run from the repository root or its sim directory"
}
set repo [file normalize [file join $script_dir ..]]
set project [file join $repo quartus dual_interleaved]
set tb [file join $repo tb_uvm tb_uvm_keccak_v2]
set netlist [file join $project simulation_postfit keccak_dual_interleaved.vo]
set sdf [file join $project simulation_postfit keccak_dual_interleaved_v.sdo]
if {[info exists ::env(KECCAK_NETLIST)]} {
    set netlist [file normalize $::env(KECCAK_NETLIST)]
}
if {[info exists ::env(KECCAK_SDF)]} {
    set sdf [file normalize $::env(KECCAK_SDF)]
}
if {![file exists $netlist]} {
    error "Missing post-fit netlist: $netlist"
}
if {![file exists $sdf]} {
    error "Missing post-fit SDF: $sdf"
}

set worklib [file join $script_dir post_fit_work]
if {[file isdirectory $worklib]} {
    vdel -lib $worklib -all
}
vlib $worklib
vmap post_fit_work $worklib

vlog -work post_fit_work -sv [file join $repo src keccak_engine keccak_pkg.sv]
vlog -work post_fit_work $netlist
vlog -work post_fit_work -sv [file join $tb keccak_ref_pkg.sv]
vlog -work post_fit_work -sv +define+KECCAK_DUAL_NETLIST [file join $tb tb_top.sv]

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cyclonev_ver \
    -sdfmax /tb_top/u_dual_throughput/dut=$sdf \
    post_fit_work.tb_top
onfinish stop
run -all
quit -sim
echo "PASS: dual-core post-fit timing simulation"
