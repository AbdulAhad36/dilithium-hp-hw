# Source-RTL verification for the unchanged ML-DSA-OSH Keccak.
# The VHDL is compiled into its own library to avoid a package-name collision
# with the project's SystemVerilog keccak_pkg.
if {[file isdirectory work]} {vdel -lib work -all}
if {[file isdirectory osh]} {vdel -lib osh -all}
vlib work
vmap work work
vlib osh
vmap osh osh

set osh_root ../third_party/ML-DSA-OSH/keccak
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
    vcom -2008 -work osh -cover bcesft [file join $osh_root $source]
}

vlog -sv -cover bcesft ../src/keccak_engine/keccak_pkg.sv
vlog -sv -cover bcesft -L osh ../src/keccak_mldsa_osh/mldsa_osh_keccak_adapter.sv
vlog -sv -cover bcesft -L osh ../src/keccak_mldsa_osh/mldsa_osh_keccak_parallel.sv

set tb ../tb_uvm/tb_uvm_keccak_v2
vlog -sv +incdir+$tb [file join $tb keccak_ref_pkg.sv]
vlog -sv +incdir+$tb [file join $tb keccak_if.sv]
vlog -sv +incdir+$tb [file join $tb keccak_assertions.sv]
vlog -sv +define+KECCAK_MLDSA_OSH_DUT +incdir+$tb [file join $tb tb_top.sv]

vsim -coverage -voptargs=+acc -L osh work.tb_top
coverage save -onexit mldsa_osh_keccak_cov.ucdb
log -r /*
run -all
