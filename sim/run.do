# =========================================================================
# run.do  -  Single entry point: compile + simulate + coverage + waveform
#
# GUI:       vsim -do run.do
# Headless:  vsim -c -do "do run.do; quit -f"
#
# Targets keccak_engine_parallel (N_LANES configurable in tb_top.sv).
# Every transaction on every lane is golden-compared against the pure-SV
# SHAKE reference model in keccak_ref_pkg.sv.
# =========================================================================

# 1. Clean previous work
if {[file isdirectory work]} {
    vdel -all
}
vlib work
vmap work work

# 2. Compile RTL
vlog -sv -cover bcesft ../src/keccak_engine/keccak_pkg.sv
vlog -sv -cover bcesft ../src/keccak_engine/*.sv

# 3. Compile UVM TB without code coverage. Functional covergroups remain
# enabled, while structural metrics are restricted to the RTL compiled above.
vlog -sv +incdir+../tb_uvm/tb_uvm_keccak_v2 ../tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv
vlog -sv +incdir+../tb_uvm/tb_uvm_keccak_v2 ../tb_uvm/tb_uvm_keccak_v2/keccak_if.sv
vlog -sv +incdir+../tb_uvm/tb_uvm_keccak_v2 ../tb_uvm/tb_uvm_keccak_v2/tb_top.sv

# 4. Start sim with coverage and full visibility
vsim -coverage -voptargs=+acc work.tb_top

# Register the save before UVM can call $finish in headless mode.
coverage save -onexit keccak_cov.ucdb

# 5. Open standard GUI views (no-op in -c console mode)
if {[batch_mode] == 0} {
    view wave
    view structure
    view signals
}

# 6. Log ALL signals recursively so waveforms are captured before display
log -r /*

# 7. GUI: add curated wave groups for lane 0 (extend per lane as needed)
if {[batch_mode] == 0} {
    add wave -divider "CLK + RST (lane 0)"
    add wave -radix binary   /tb_top/clk
    add wave -radix binary   /tb_top/vif[0]/rst

    add wave -divider "DUT Control (lane 0)"
    add wave -radix binary   /tb_top/vif[0]/start
    add wave -radix binary   /tb_top/vif[0]/stop
    add wave -radix unsigned /tb_top/vif[0]/mode
    add wave -radix unsigned /tb_top/vif[0]/xof_len

    add wave -divider "Sink (s_axis, lane 0)"
    add wave -radix hex      /tb_top/vif[0]/s_axis_tdata
    add wave -radix binary   /tb_top/vif[0]/s_axis_tvalid
    add wave -radix binary   /tb_top/vif[0]/s_axis_tlast
    add wave -radix binary   /tb_top/vif[0]/s_axis_tkeep
    add wave -radix binary   /tb_top/vif[0]/s_axis_tready

    add wave -divider "Source (m_axis, lane 0)"
    add wave -radix hex      /tb_top/vif[0]/m_axis_tdata
    add wave -radix binary   /tb_top/vif[0]/m_axis_tvalid
    add wave -radix binary   /tb_top/vif[0]/m_axis_tlast
    add wave -radix binary   /tb_top/vif[0]/m_axis_tkeep
    add wave -radix binary   /tb_top/vif[0]/m_axis_tready

    add wave -divider "DUT Internals (lane 0)"
    add wave -radix unsigned /tb_top/dut/g_lane[0]/u_core/state
    add wave -radix unsigned /tb_top/dut/g_lane[0]/u_core/rate
    add wave -radix hex      /tb_top/dut/g_lane[0]/u_core/suffix
    add wave -radix unsigned /tb_top/dut/g_lane[0]/u_core/bytes_absorbed
    add wave -radix unsigned /tb_top/dut/g_lane[0]/u_core/round_idx
    add wave -radix unsigned /tb_top/dut/g_lane[0]/u_core/total_bytes_squeezed
}

# 8. Run to completion
run -all

# In headless mode invoke as: vsim -c -do "do run.do; quit -f"
