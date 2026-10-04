# Source-RTL reference for the focused four-job dual-netlist suite.
onerror {quit -code 1 -f}

set launch_dir [file normalize [pwd]]
if {[file exists [file join $launch_dir run_netlist_reference.do]]} {
    set script_dir $launch_dir
} elseif {[file exists [file join $launch_dir sim run_netlist_reference.do]]} {
    set script_dir [file join $launch_dir sim]
} else {
    error "Run from the repository root or its sim directory"
}
set repo [file normalize [file join $script_dir ..]]
set rtl [file join $repo src keccak_engine]
set tb [file join $repo tb_uvm tb_uvm_keccak_v2]
set worklib [file join $script_dir netlist_reference_work]
if {[file isdirectory $worklib]} {
    vdel -lib $worklib -all
}
vlib $worklib
vmap netlist_reference_work $worklib

foreach source {
    keccak_pkg.sv
    keccak_param_unit.sv
    keccak_absorb_unit.sv
    theta_step.sv
    rho_step.sv
    pi_step.sv
    chi_step.sv
    iota_step.sv
    keccak_step_unit.sv
    keccak_output_unit.sv
    keccak_core.sv
    keccak_dual_interleaved.sv
} {
    vlog -work netlist_reference_work -sv [file join $rtl $source]
}
vlog -work netlist_reference_work -sv [file join $tb keccak_ref_pkg.sv]
vlog -work netlist_reference_work -sv +define+KECCAK_DUAL_NETLIST [file join $tb tb_top.sv]

vsim netlist_reference_work.tb_top
onfinish stop
run -all
quit -sim
echo "PASS: dual-core focused source-RTL reference"
