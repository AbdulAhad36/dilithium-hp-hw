# ============================================================================
# ntt_engine_check.do  --  Directed self-check run for ntt_engine
# ----------------------------------------------------------------------------
# Compiles the full NTT RTL + golden model + the engine testbench and runs it.
# Increment-4 verification: ntt_engine (stream front-end + core) golden-compared
# against ntt_ref_pkg.
#
#   vsim -c -do "do ntt_engine_check.do; quit -f"     (headless)
# ============================================================================

quietly set ENG_WORK ntt_engine_work
if {[file exists $ENG_WORK]} { vdel -all -lib $ENG_WORK }
vlib $ENG_WORK
vmap work $ENG_WORK

quietly set RTL ../src/ntt_engine
quietly set TB  ../tb_uvm/tb_uvm_ntt

vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv -work work $RTL/mod_mul.sv
vlog -sv -work work $RTL/butterfly_unit.sv
vlog -sv -work work $RTL/twiddle_rom.sv
vlog -sv -work work $RTL/ntt_core.sv
vlog -sv -work work $RTL/ntt_engine.sv

vlog -sv -work work $TB/ntt_ref_pkg.sv
vlog -sv -work work $TB/tb_ntt_engine.sv

vsim -c -voptargs=+acc work.tb_ntt_engine
run -all
