# =========================================================================
# run.do  -  Full compile + sim + coverage + waveform capture
# Run in QuestaSim GUI:   vsim -do run.do
# Run in headless console: vsim -c -do run.do
# =========================================================================

# 1. Compile everything (calls compile.do which does vdel -all first)
do compile.do

# 2. Start sim with coverage and full visibility (-voptargs=+acc)
vsim -coverage -voptargs=+acc work.tb_top

# 3. Open the standard GUI views (no-op in -c console mode)
if {[batch_mode] == 0} {
    view wave
    view structure
    view signals
}

# 4. Log ALL signals recursively so waveforms are captured even before the
#    wave window is told to display them.  This makes the entire run visible
#    after simulation completes.
log -r /*

# 5. Add signal groups to the wave window (GUI only).
if {[batch_mode] == 0} {
    # ---- Top-level clock + reset ----
    add wave -divider "CLK + RST"
    add wave -radix binary  /tb_top/clk
    add wave -radix binary  /tb_top/vif/rst

    # ---- DUT control / status ----
    add wave -divider "DUT Control"
    add wave -radix binary  /tb_top/vif/start
    add wave -radix binary  /tb_top/vif/stop
    add wave -radix unsigned /tb_top/vif/mode
    add wave -radix unsigned /tb_top/vif/xof_len
    add wave -radix unsigned /tb_top/dut/state

    # ---- AXI4-Stream Sink (TB -> DUT) ----
    add wave -divider "Sink (s_axis)"
    add wave -radix hex      /tb_top/vif/s_axis_tdata
    add wave -radix binary   /tb_top/vif/s_axis_tvalid
    add wave -radix binary   /tb_top/vif/s_axis_tlast
    add wave -radix binary   /tb_top/vif/s_axis_tkeep
    add wave -radix binary   /tb_top/vif/s_axis_tready

    # ---- AXI4-Stream Source (DUT -> TB) ----
    add wave -divider "Source (m_axis)"
    add wave -radix hex      /tb_top/vif/m_axis_tdata
    add wave -radix binary   /tb_top/vif/m_axis_tvalid
    add wave -radix binary   /tb_top/vif/m_axis_tlast
    add wave -radix binary   /tb_top/vif/m_axis_tkeep
    add wave -radix binary   /tb_top/vif/m_axis_tready

    # ---- DUT internal signals (rate, suffix, counters) ----
    add wave -divider "DUT Internals"
    add wave -radix unsigned /tb_top/dut/rate
    add wave -radix hex      /tb_top/dut/suffix
    add wave -radix unsigned /tb_top/dut/bytes_absorbed
    add wave -radix unsigned /tb_top/dut/round_idx
    add wave -radix unsigned /tb_top/dut/total_bytes_squeezed
}

# 6. Run to completion
run -all

# 7. Save coverage database
coverage save keccak_cov.ucdb

# Note: NOT calling quit here so the GUI stays open for waveform inspection.
# When running headless (-c), pipe `-do "run.do; quit -f"` to exit.
