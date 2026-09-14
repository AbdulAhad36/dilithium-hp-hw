onerror {quit -code 1 -f}
if {![info exists ::env(KECCAK_REPO)]} {error "Set KECCAK_REPO"}
if {![info exists ::env(MLDSA_OSH_NETLIST)]} {error "Set MLDSA_OSH_NETLIST"}
if {![info exists ::env(QUARTUS_ROOTDIR)]} {error "Set QUARTUS_ROOTDIR"}

set repo [file normalize $::env(KECCAK_REPO)]
set netlist [file normalize $::env(MLDSA_OSH_NETLIST)]
set libs [file join $::env(QUARTUS_ROOTDIR) eda sim_lib]
set tb [file join $repo tb_uvm tb_uvm_keccak_v2]

vlib work
vmap work work
foreach source {
    altera_primitives.v
    220model.v
    sgate.v
    altera_mf.v
    altera_lnsim.sv
    cyclonev_atoms.v
    mentor/cyclonev_atoms_ncrypt.v
} {
    vlog -sv [file join $libs $source]
}
vlog $netlist
vlog -sv [file join $repo src keccak_engine keccak_pkg.sv]
vlog -sv [file join $repo src keccak_mldsa_osh mldsa_osh_keccak_adapter.sv]
vlog -sv [file join $repo src keccak_mldsa_osh mldsa_osh_keccak_parallel.sv]
vlog -sv +incdir+$tb [file join $tb keccak_ref_pkg.sv]
vlog -sv +incdir+$tb [file join $tb keccak_if.sv]
vlog -sv +incdir+$tb [file join $tb keccak_assertions.sv]
vlog -sv +define+KECCAK_MLDSA_OSH_DUT +define+KECCAK_STAGE2_SUITE +incdir+$tb [file join $tb tb_top.sv]

vsim -coverage -voptargs=+acc work.tb_top +UVM_TESTNAME=keccak_stage2_test
coverage save -onexit mldsa_osh_netlist.ucdb
run -all
quit -code 0 -f
