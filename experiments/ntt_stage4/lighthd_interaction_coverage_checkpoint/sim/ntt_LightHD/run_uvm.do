# Main UVM with GUI/waves/functional and code coverage; run from sim/.
if {![info exists NTT_MODE]} {set NTT_MODE uvm}
if {$NTT_MODE ni {uvm vectors}} {error "NTT_MODE must be uvm or vectors"}
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
if {![batch_mode]} {
  transcript on
}
if {$NTT_MODE eq "vectors"} {
if {![batch_mode]} {transcript file ntt_LightHD/vectors_gui.log}
# Run from sim/. This capture is separate from the full UVM regression.
set RTL ../src/ntt_LightHD
set TB ../tb_uvm/tb_uvm_ntt_LightHD
set CAND ntt_LightHD
if {![file exists $CAND/work_vectors]} {vlib $CAND/work_vectors}
vmap work $CAND/work_vectors
vlog -sv -work work $RTL/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv \
  $TB/tb_ntt_vectors.sv
vsim -wlf ntt_LightHD/vectors.wlf -voptargs=+acc work.tb_ntt_vectors \
  +NTT_OUTPUT_FILE=$CAND/ntt_dut_outputs.txt
onfinish stop
if {![batch_mode]} {
  view transcript
  view wave
  add wave -r /tb_ntt_vectors/*
}
run -all
if {[batch_mode]} {quit -sim} else {wave zoom full}
unset RTL TB CAND

} else {
# Main LightHD UVM regression: checked functional coverage + DUT code coverage.
# GUI: cd D:/GitHub/dilithium-hp-hw/sim; do ntt_LightHD/run_uvm.do
# Batch from sim/: vsim -c -do "do ntt_LightHD/run_uvm.do; quit -f"
if {[batch_mode]} {
  onerror {quit -code 1 -f}
} else {
  onerror {abort}
}
# Optional checker tests keep their coverage separate from the main regression.
if {[info exists NTT_TEST] && $NTT_TEST ne "ntt_full_test"} {
  if {![regexp {^ntt_[a-z_]+_test$} $NTT_TEST]} {error "Invalid NTT_TEST name"}
  if {![info exists NTT_WORK]} {set NTT_WORK ntt_LightHD/work_$NTT_TEST}
  if {![info exists NTT_UCDB]} {set NTT_UCDB ntt_LightHD/$NTT_TEST.ucdb}
  if {![info exists NTT_REPORT]} {set NTT_REPORT ntt_LightHD/${NTT_TEST}_code.rpt}
}
if {![info exists NTT_WORK]} {set NTT_WORK ntt_LightHD/work_uvm}
if {![info exists NTT_UCDB]} {set NTT_UCDB ntt_LightHD/ntt_lighthd_cov.ucdb}
if {![info exists NTT_REPORT]} {set NTT_REPORT ntt_LightHD/ntt_lighthd_coverage.rpt}
if {![info exists NTT_TEST]} {set NTT_TEST ntt_full_test}
if {![info exists NTT_SEED]} {set NTT_SEED 20261011}
if {![batch_mode]} {
  if {$NTT_TEST eq "ntt_full_test"} {transcript file ntt_LightHD/uvm_gui.log} else {
    transcript file ntt_LightHD/${NTT_TEST}_gui.log
  }
}
if {![file exists $NTT_WORK]} {vlib $NTT_WORK}
vmap work $NTT_WORK
set RTL ../src/ntt_LightHD
set TB ../tb_uvm/tb_uvm_ntt_LightHD
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv +cover=sbceft -work work $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv
vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_ref_pkg.sv $TB/ntt_if.sv
vlog -sv +define+NTT_FIFO +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
vsim -wlf ntt_LightHD/${NTT_TEST}.wlf -coverage -sv_seed $NTT_SEED -voptargs=+acc work.tb_top +UVM_TESTNAME=$NTT_TEST
coverage save -onexit $NTT_UCDB
onfinish stop
if {![batch_mode]} {
  # Load after elaboration, BEFORE running, to retain waveform history.
  view transcript
  view structure
  view objects
  view wave
  view covergroups
  view instance
  view canalysis
  view source
  log /tb_top/clk
  log /tb_top/vif/*
  add wave -group Control /tb_top/clk /tb_top/vif/rst /tb_top/vif/start /tb_top/vif/op /tb_top/vif/busy /tb_top/vif/done
  add wave -group Input -radix unsigned /tb_top/vif/s_tdata /tb_top/vif/s_tvalid /tb_top/vif/s_tready /tb_top/vif/s_tlast
  add wave -group Output -radix unsigned /tb_top/vif/m_tdata /tb_top/vif/m_tvalid /tb_top/vif/m_tready /tb_top/vif/m_tlast
  add wave -group Schedule -radix unsigned /tb_top/vif/wrapper_state /tb_top/vif/core_state /tb_top/vif/stage /tb_top/vif/issue /tb_top/vif/tick /tb_top/vif/run_issue /tb_top/vif/pwm_issue /tb_top/vif/return_valid /tb_top/vif/pending_tags
  add wave -group FIFOs -radix unsigned /tb_top/vif/fifo_count1 /tb_top/vif/fifo_count2 /tb_top/vif/fifo_count3 /tb_top/vif/fifo_push /tb_top/vif/fifo_pop
  add wave -group Butterfly -radix unsigned /tb_top/vif/bf_input_a /tb_top/vif/bf_input_b /tb_top/vif/bf_input_z /tb_top/vif/bf_input_mode /tb_top/vif/bf_a /tb_top/vif/bf_b
  add wave -group Routing -radix unsigned /tb_top/vif/source_a /tb_top/vif/source_b /tb_top/vif/dest_a /tb_top/vif/dest_b /tb_top/vif/output_address
  configure wave -namecolwidth 220
  configure wave -valuecolwidth 100
  configure wave -timelineunits us
}
run -all
coverage save $NTT_UCDB
coverage report -details -output $NTT_REPORT
if {[batch_mode]} {
  quit -sim
} else {
  wave zoom range 0ns 12us
  echo "GUI READY: simulation retained; waves, functional bins and DUT code coverage available."
  echo "Coverage database: $NTT_UCDB"
  echo "Detailed coverage report: $NTT_REPORT"
}
foreach variable {NTT_WORK NTT_UCDB NTT_REPORT NTT_TEST NTT_SEED} {unset $variable}

}
unset NTT_MODE
