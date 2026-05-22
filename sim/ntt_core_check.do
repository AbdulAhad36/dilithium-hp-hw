# ============================================================================
# ntt_core_check.do  --  Directed self-check run for ntt_core
# ----------------------------------------------------------------------------
# Compiles the NTT RTL + the golden model + the directed core testbench and
# runs it. Increment-2 verification: ntt_core golden-compared against the
# (already self-verified) ntt_ref_pkg.
#
#   vsim -c -do "do ntt_core_check.do; quit -f"     (headless)
#   vsim    -do ntt_core_check.do                   (GUI)
# ============================================================================

quietly set CORE_WORK ntt_core_work
if {[file exists $CORE_WORK]} { vdel -all -lib $CORE_WORK }
vlib $CORE_WORK
vmap work $CORE_WORK

quietly set RTL ../src/ntt_engine
quietly set TB  ../tb_uvm/tb_uvm_ntt

# ---- RTL (package first) ----------------------------------------------------
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv -work work $RTL/mod_mul.sv
vlog -sv -work work $RTL/butterfly_unit.sv
vlog -sv -work work $RTL/twiddle_rom.sv
vlog -sv -work work $RTL/ntt_core.sv

# ---- golden model + testbench ----------------------------------------------
vlog -sv -work work $TB/ntt_ref_pkg.sv
vlog -sv -work work $TB/tb_ntt_core.sv

vsim -c -voptargs=+acc work.tb_ntt_core
run -all
