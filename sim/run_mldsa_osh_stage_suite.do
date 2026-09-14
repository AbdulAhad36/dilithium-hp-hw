# Port-only source-RTL suite matching the post-synthesis and post-fit runs.
if {[file isdirectory work]} {vdel -lib work -all}
if {[file isdirectory osh]} {vdel -lib osh -all}
vlib work
vmap work work
vlib osh
vmap osh osh

if {[info exists ::env(KECCAK_REPO)]} {
    set repo [file normalize $::env(KECCAK_REPO)]
} else {
    set repo [file normalize ..]
}
set osh_root [file join $repo third_party ML-DSA-OSH keccak]
foreach source {
    sha3_pkg.vhd
    keccak_pkg.vhd
    regn.vhd
    countern.vhd
    piso.vhd
    sipo.vhd
    sr_reg.vhd
    keccak_bytepad.vhd
    keccak_cons.vhd
    keccak_round.vhd
    keccak_fsm1.vhd
    keccak_fsm2.vhd
    sha3_fsm3.vhd
    keccak_control.vhd
    keccak_datapath.vhd
    keccak_top.vhd
} {
    vcom -2008 -work osh [file join $osh_root $source]
}

vlog -sv [file join $repo src keccak_engine keccak_pkg.sv]
vlog -sv -L osh [file join $repo src keccak_mldsa_osh mldsa_osh_keccak_adapter.sv]
vlog -sv -L osh [file join $repo src keccak_mldsa_osh mldsa_osh_keccak_parallel.sv]

set tb [file join $repo tb_uvm tb_uvm_keccak_v2]
vlog -sv +incdir+$tb [file join $tb keccak_ref_pkg.sv]
vlog -sv +incdir+$tb [file join $tb keccak_if.sv]
vlog -sv +incdir+$tb [file join $tb keccak_assertions.sv]
vlog -sv +define+KECCAK_MLDSA_OSH_DUT +define+KECCAK_STAGE2_SUITE +incdir+$tb [file join $tb tb_top.sv]

vsim -voptargs=+acc -L osh work.tb_top +UVM_TESTNAME=keccak_stage2_test
run -all
quit -code 0 -f
