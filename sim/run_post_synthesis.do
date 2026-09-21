# Dual-core interleaved Keccak post-synthesis (pre-fit) functional simulation.
# Generate the functional netlist first with Quartus EDA Netlist Writer.

onerror {quit -code 1 -f}
set launch_dir [file normalize [pwd]]
if {[file exists [file join $launch_dir run_post_synthesis.do]]} {
    set script_dir $launch_dir
} elseif {[file exists [file join $launch_dir sim run_post_synthesis.do]]} {
    set script_dir [file join $launch_dir sim]
} else {
    error "Run from the repository root or its sim directory"
}
set repo [file normalize [file join $script_dir ..]]
set project [file join $repo quartus dual_interleaved]
set tb [file join $repo tb_uvm tb_uvm_keccak_v2]
set netlist [file join $project simulation_postsynth keccak_dual_interleaved.vo]
if {[info exists ::env(KECCAK_NETLIST)]} {
    set netlist [file normalize $::env(KECCAK_NETLIST)]
}
if {![file exists $netlist]} {
    error "Missing post-synthesis netlist: $netlist"
}

set worklib [file join $script_dir post_synthesis_work]
if {[file isdirectory $worklib]} {
    vdel -lib $worklib -all
}
vlib $worklib
vmap post_synthesis_work $worklib

vlog -work post_synthesis_work -sv [file join $repo src keccak_engine keccak_pkg.sv]
vlog -work post_synthesis_work $netlist
vlog -work post_synthesis_work -sv [file join $tb keccak_ref_pkg.sv]
vlog -work post_synthesis_work -sv +define+KECCAK_DUAL_NETLIST [file join $tb tb_top.sv]

vsim -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cyclonev_ver \
    post_synthesis_work.tb_top
onfinish stop
run -all
quit -sim
echo "PASS: dual-core post-synthesis functional simulation"
