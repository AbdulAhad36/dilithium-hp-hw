# Run from an empty per-run directory; script locates sources relative to itself.
onerror {quit -code 1 -f}
if {![info exists ::env(KECCAK_REPO)]} {error "Set KECCAK_REPO to the repository root"}
set repo [file normalize $::env(KECCAK_REPO)]
if {![info exists ::env(KECCAK_REPRESENTATION)]} {error "Set KECCAK_REPRESENTATION to rtl or netlist"}
set representation $::env(KECCAK_REPRESENTATION)
if {$representation ni {rtl netlist}} {error "Invalid KECCAK_REPRESENTATION"}
set tb [file join $repo tb_uvm tb_uvm_keccak_v2]
set rtl [file join $repo src keccak_engine]
vlib work
vmap work work
vlog -sv [file join $rtl keccak_pkg.sv]
if {$representation eq "rtl"} {
    foreach source {theta_step rho_step pi_step chi_step iota_step keccak_step_unit keccak_param_unit keccak_absorb_unit keccak_output_unit keccak_core} {
        vlog -sv [file join $rtl ${source}.sv]
    }
    vlog -sv [file join $repo quartus stage2 keccak_synth_top.sv]
} else {
    if {![info exists ::env(QUARTUS_ROOTDIR)]} {error "Set QUARTUS_ROOTDIR"}
    set libs [file join $::env(QUARTUS_ROOTDIR) eda sim_lib]
    foreach source {altera_primitives.v 220model.v sgate.v altera_mf.v altera_lnsim.sv cyclonev_atoms.v mentor/cyclonev_atoms_ncrypt.v} {
        vlog -sv [file join $libs $source]
    }
    set netlist [file join $repo quartus stage2 simulation keccak_stage2.vo]
    if {[info exists ::env(KECCAK_NETLIST)]} {set netlist $::env(KECCAK_NETLIST)}
    if {![file exists $netlist]} {error "Missing synthesis netlist: $netlist"}
    vlog $netlist
}
vlog -sv +incdir+$tb [file join $tb keccak_ref_pkg.sv]
vlog -sv +incdir+$tb [file join $tb keccak_if.sv]
vlog -sv +incdir+$tb [file join $tb keccak_assertions.sv]
vlog -sv +define+KECCAK_EXTERNAL_DUT +incdir+$tb [file join $tb tb_top.sv]
set seed 20260909
if {[info exists ::env(KECCAK_SEED)]} {set seed $::env(KECCAK_SEED)}
set ucdb stage2.ucdb
if {[info exists ::env(KECCAK_UCDB)]} {set ucdb $::env(KECCAK_UCDB)}
vsim -coverage -sv_seed $seed work.tb_top +UVM_TESTNAME=keccak_stage2_test
coverage save -onexit $ucdb
onfinish stop
run -all
quit -code 0 -f
