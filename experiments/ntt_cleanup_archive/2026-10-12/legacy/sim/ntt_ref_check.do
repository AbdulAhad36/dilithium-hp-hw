# ============================================================================
# ntt_ref_check.do  --  Self-check run for the NTT golden model
# ----------------------------------------------------------------------------
# Compiles ntt_pkg + the pure-SV golden model (ntt_ref_pkg) + its self-check
# testbench (tb_ntt_ref) and runs it. No DUT involved -- this proves the
# reference model is internally consistent before it is used to golden-compare
# the ntt_core RTL.
#
#   vsim -c -do "do ntt_ref_check.do; quit -f"     (headless)
#   vsim    -do ntt_ref_check.do                   (GUI)
#
# Separate from ntt_run.do (the eventual UVM core flow) on purpose: this is the
# verification-foundation step and must pass first.
# ============================================================================

quietly set REF_WORK ntt_ref_work
if {[file exists $REF_WORK]} { vdel -all -lib $REF_WORK }
vlib $REF_WORK
vmap work $REF_WORK

quietly set RTL ../src/ntt_engine
quietly set TB  ../tb_uvm/tb_uvm_ntt

# ntt_pkg supplies q, N, zeta, N_INV used by the golden model.
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv -work work $TB/ntt_ref_pkg.sv
vlog -sv -work work $TB/tb_ntt_ref.sv

vsim -c work.tb_ntt_ref
run -all
