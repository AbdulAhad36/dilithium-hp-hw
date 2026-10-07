# ============================================================================
# ntt_run.do  --  QuestaSim build + simulate script for the NTT engine
# ----------------------------------------------------------------------------
# Full UVM run of src/ntt_LightHD, including bounded-secret Pre-NTT.
#
# Run from sim/: vsim -c -do "do ntt_LightHD/run_uvm.do; quit -f"
#
# The work library and UCDB stay under sim/ntt_LightHD/.
# ============================================================================

# ---- clean rebuild ----------------------------------------------------------
quietly set NTT_WORK ntt_LightHD/work_uvm
vlib $NTT_WORK
vmap work $NTT_WORK

# ---- source paths -----------------------------------------------------------
quietly set RTL ../src/ntt_LightHD
quietly set TB  ../tb_uvm/tb_uvm_ntt

# ---- compile RTL (package first) -------------------------------------------
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv -work work $RTL/mod_mul.sv
vlog -sv -work work $RTL/butterfly_unit.sv
vlog -sv -work work $RTL/twiddle_rom.sv
vlog -sv -work work $RTL/ntt_core.sv
vlog -sv -work work $RTL/ntt_engine.sv

# ---- compile UVM testbench --------------------------------------------------
# Golden model + interface compiled stand-alone; tb_top.sv `includes the rest
# of the UVM class files.
if {[file exists $TB/tb_top.sv]} {
    vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_ref_pkg.sv
    vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_if.sv
    vlog -sv +define+NTT_FIFO +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
}

# ---- simulate ---------------------------------------------------------------
if {[file exists $TB/tb_top.sv]} {
    vsim -coverage -voptargs=+acc work.tb_top

    coverage save -onexit ntt_LightHD/ntt_lighthd_cov.ucdb
    run -all
} else {
    echo "tb_uvm_ntt/tb_top.sv not present yet -- RTL compiled only."
}
