# Main UVM with GUI/waves/functional and code coverage; run from sim/.
if {![info exists NTT_MODE]} {set NTT_MODE uvm}
if {$NTT_MODE ni {uvm vectors}} {error "NTT_MODE must be uvm or vectors"}
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
if {![batch_mode]} {
  transcript on
}
if {$NTT_MODE eq "vectors"} {
if {![batch_mode]} {transcript file ntt/vectors_gui.log}
# Run from sim/. This capture is separate from the full UVM regression.
set RTL ../src/ntt
set TB ../tb_uvm/tb_uvm_ntt_LightHD
set CAND ntt
if {![file exists $CAND/work_vectors]} {vlib $CAND/work_vectors}
vmap work $CAND/work_vectors
vlog -sv -work work $RTL/ntt_pkg.sv $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv \
  $TB/tb_ntt_vectors.sv
vsim -wlf ntt/vectors.wlf -voptargs=+acc work.tb_ntt_vectors \
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
# GUI: cd D:/GitHub/dilithium-hp-hw/sim; do ntt/run_uvm.do
# Batch from sim/: vsim -c -do "do ntt/run_uvm.do; quit -f"
if {[batch_mode]} {
  onerror {quit -code 1 -f}
} else {
  onerror {abort}
}
# Optional checker tests keep their coverage separate from the main regression.
if {[info exists NTT_TEST] && $NTT_TEST ne "ntt_full_test"} {
  if {![regexp {^ntt_[a-z_]+_test$} $NTT_TEST]} {error "Invalid NTT_TEST name"}
  if {![info exists NTT_WORK]} {set NTT_WORK ntt/work_$NTT_TEST}
  if {![info exists NTT_UCDB]} {set NTT_UCDB ntt/$NTT_TEST.ucdb}
  if {![info exists NTT_REPORT]} {set NTT_REPORT ntt/${NTT_TEST}_code.rpt}
}
if {![info exists NTT_WORK]} {set NTT_WORK ntt/work_uvm}
if {![info exists NTT_UCDB]} {set NTT_UCDB ntt/ntt_lighthd_cov.ucdb}
if {![info exists NTT_REPORT]} {set NTT_REPORT ntt/ntt_lighthd_coverage.rpt}
if {![info exists NTT_TEST]} {set NTT_TEST ntt_full_test}
if {![info exists NTT_SEED]} {set NTT_SEED 20261011}
if {![batch_mode]} {
  if {$NTT_TEST eq "ntt_full_test"} {transcript file ntt/uvm_gui.log} else {
    transcript file ntt/${NTT_TEST}_gui.log
  }
}
if {![file exists $NTT_WORK]} {vlib $NTT_WORK}
vmap work $NTT_WORK
set RTL ../src/ntt
set TB ../tb_uvm/tb_uvm_ntt_LightHD
vlog -sv -work work $RTL/ntt_pkg.sv
vlog -sv +cover=sbceft -work work $RTL/mod_mul.sv $RTL/butterfly_unit.sv \
  $RTL/twiddle_rom.sv $RTL/ntt_core.sv $RTL/ntt_engine.sv
vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_ref_pkg.sv $TB/ntt_if.sv
vlog -sv +define+NTT_FIFO +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
vsim -wlf ntt/${NTT_TEST}.wlf -coverage -sv_seed $NTT_SEED -voptargs=+acc work.tb_top +UVM_TESTNAME=$NTT_TEST
coverage save -onexit $NTT_UCDB
onfinish stop
if {![batch_mode]} {
  # Load after elaboration, BEFORE running, to retain waveform history.
  view transcript
  view structure
  view objects
  view wave
  delete wave *
  view covergroups
  view instance
  view canalysis
  view source
  log /tb_top/clk
  log /tb_top/vif/*
  add wave -divider {Control}
  add wave /tb_top/clk /tb_top/vif/rst /tb_top/vif/start /tb_top/vif/op /tb_top/vif/busy /tb_top/vif/done
  add wave -divider {Input}
  add wave -radix unsigned /tb_top/vif/s_tdata /tb_top/vif/s_tvalid /tb_top/vif/s_tready /tb_top/vif/s_tlast
  add wave -divider {Output}
  add wave -radix unsigned /tb_top/vif/m_tdata /tb_top/vif/m_tvalid /tb_top/vif/m_tready /tb_top/vif/m_tlast
  add wave -divider {Schedule}
  add wave -radix unsigned /tb_top/vif/wrapper_state /tb_top/vif/core_state /tb_top/vif/stage /tb_top/vif/issue /tb_top/vif/tick /tb_top/vif/run_issue /tb_top/vif/pwm_issue /tb_top/vif/return_valid /tb_top/vif/pending_tags
  add wave -divider {FIFOs}
  add wave -radix unsigned /tb_top/vif/fifo_count1 /tb_top/vif/fifo_count2 /tb_top/vif/fifo_count3 /tb_top/vif/fifo_push /tb_top/vif/fifo_pop
  add wave -divider {Butterfly}
  add wave -radix unsigned /tb_top/vif/bf_input_a /tb_top/vif/bf_input_b /tb_top/vif/bf_input_z /tb_top/vif/bf_input_mode /tb_top/vif/bf_a /tb_top/vif/bf_b
  add wave -divider {Routing}
  add wave -radix unsigned /tb_top/vif/source_a /tb_top/vif/source_b /tb_top/vif/dest_a /tb_top/vif/dest_b /tb_top/vif/output_address
  configure wave -namecolwidth 260
  configure wave -signalnamewidth 1
  configure wave -valuecolwidth 100
  configure wave -timeline 1
  configure wave -timelineunits us
}
run -all
coverage save $NTT_UCDB
coverage report -details -output $NTT_REPORT
# Print the same raw DUT bin arithmetic documented in COVERAGE.md.
# Count each local DUT instance/category once; omit TB and vendor coverage.
set ntt_cov_totals [dict create]
set ntt_cov_seen [dict create]
set ntt_cov_instance ""
set ntt_cov_file [open $NTT_REPORT r]
while {[gets $ntt_cov_file ntt_cov_line]>=0} {
  if {[regexp {^=== Instance: (\S+)} $ntt_cov_line -> ntt_cov_path]} {
    set ntt_cov_instance $ntt_cov_path
  }
  if {$ntt_cov_instance ne "/tb_top/dut" && ![string match "/tb_top/dut/*" $ntt_cov_instance]} {continue}
  if {[regexp {^\s+(Statements|Branches|Conditions|Expressions|Toggles|FSM States|FSM Transitions)\s+(\d+)\s+(\d+)\s+(\d+)\s+[0-9.]+%} $ntt_cov_line -> ntt_cov_metric ntt_cov_bins ntt_cov_hits ntt_cov_misses]} {
    set ntt_cov_key [list $ntt_cov_instance $ntt_cov_metric]
    if {[dict exists $ntt_cov_seen $ntt_cov_key]} {continue}
    dict set ntt_cov_seen $ntt_cov_key 1
    if {![dict exists $ntt_cov_totals $ntt_cov_metric]} {dict set ntt_cov_totals $ntt_cov_metric {0 0}}
    lassign [dict get $ntt_cov_totals $ntt_cov_metric] ntt_cov_h ntt_cov_b
    dict set ntt_cov_totals $ntt_cov_metric [list [expr {$ntt_cov_h+$ntt_cov_hits}] [expr {$ntt_cov_b+$ntt_cov_bins}]]
  }
}
close $ntt_cov_file
echo "DUT CODE COVERAGE - raw local-instance bins (testbench excluded)"
echo "Metric                 Hit / Total       Coverage"
set ntt_cov_all_hits 0
set ntt_cov_all_bins 0
foreach ntt_cov_metric {Statements Branches Conditions Expressions Toggles {FSM States} {FSM Transitions}} {
  if {![dict exists $ntt_cov_totals $ntt_cov_metric]} {error "Missing DUT code coverage category: $ntt_cov_metric"}
  lassign [dict get $ntt_cov_totals $ntt_cov_metric] ntt_cov_h ntt_cov_b
  echo [format "%-18s %7d / %-7d %8.2f%%" $ntt_cov_metric $ntt_cov_h $ntt_cov_b [expr {100.0*$ntt_cov_h/$ntt_cov_b}]]
  incr ntt_cov_all_hits $ntt_cov_h
  incr ntt_cov_all_bins $ntt_cov_b
}
echo [format "OVERALL DUT CODE COVERAGE (raw bins): %d / %d = %.2f%%" $ntt_cov_all_hits $ntt_cov_all_bins [expr {100.0*$ntt_cov_all_hits/$ntt_cov_all_bins}]]
echo "Overall = summed hits / summed enabled code bins across the seven categories; toggle bins carry most of the weight. Functional covergroups are excluded."
echo "END DUT CODE COVERAGE"
foreach ntt_cov_var [info vars ntt_cov_*] {unset $ntt_cov_var}
unset ntt_cov_var
if {[batch_mode]} {
  quit -sim
} else {
  # First two directed jobs are zero. Show the third, nonzero NTT job.
  view wave -undock -width 1280 -height 720
  if {$NTT_TEST in {ntt_full_test ntt_directed_test}} {
    wave zoom range 16us 24us
  } else {wave zoom full}
  echo "Wave tip: Zoom Full shows the whole regression; zoom 16us..24us shows the nonzero directed NTT."
  echo "GUI READY: simulation retained; waves, functional bins and DUT code coverage available."
  echo "Coverage database: $NTT_UCDB"
  echo "Detailed coverage report: $NTT_REPORT"
}
foreach variable {NTT_WORK NTT_UCDB NTT_REPORT NTT_TEST NTT_SEED} {unset $variable}

}
unset NTT_MODE
