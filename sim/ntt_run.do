# ============================================================================
# ntt_run.do  --  QuestaSim build + simulate script for the NTT engine
# ----------------------------------------------------------------------------
# Single entry point for branch 2_ntt: clean rebuild, compile RTL + UVM TB,
# launch vsim with coverage and waveform access, run, save coverage.
#
#   vsim -do ntt_run.do                        (GUI)
#   vsim -c -do "do ntt_run.do; quit -f"       (headless)
#
# Filenames are NTT-specific (ntt_run.do, ntt_cov.ucdb, ntt_work) so this
# branch never collides with the keccak sim flow on branch 1_hashing.
# ============================================================================

# ---- clean rebuild ----------------------------------------------------------
quietly set NTT_WORK ntt_work
if {[file exists $NTT_WORK]} { vdel -all -lib $NTT_WORK }
vlib $NTT_WORK
vmap work $NTT_WORK

# ---- source paths -----------------------------------------------------------
quietly set RTL ../src/ntt_engine
quietly set TB  ../tb_uvm/tb_uvm_ntt

# ---- compile RTL (package first) -------------------------------------------
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv -work work $RTL/mod_mul.sv
vlog -sv -work work $RTL/butterfly_unit.sv
vlog -sv -work work $RTL/twiddle_rom.sv
vlog -sv -work work $RTL/ntt_core.sv
vlog -sv -work work $RTL/ntt_engine.sv

# ---- compile UVM testbench --------------------------------------------------
# Populated when tb_uvm_ntt/ is built (verification step on branch 2_ntt).
if {[file exists $TB/tb_top.sv]} {
    vlog -sv +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
}

# ---- simulate ---------------------------------------------------------------
if {[file exists $TB/tb_top.sv]} {
    vsim -coverage -voptargs=+acc work.tb_top
    add wave -r /*
    coverage save -onexit ntt_cov.ucdb
    run -all
} else {
    echo "tb_uvm_ntt/tb_top.sv not present yet -- RTL compiled only."
}
