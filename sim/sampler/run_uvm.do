# Run from sim/: do sampler/run_uvm.do
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
if {![info exists SAMPLER_MODE]} {set SAMPLER_MODE regression}
if {$SAMPLER_MODE ni {regression vectors performance}} {error "SAMPLER_MODE must be regression, vectors or performance"}
set RUN_PREFIX sampler/smoke
set RUN_TEST sampler_stage4_9_test
set GUI_LOG sampler/uvm_gui.log
set EXTRA_ARGS {}
if {[info exists SAMPLER_INJECT_FAULT] && $SAMPLER_INJECT_FAULT} {
  if {$SAMPLER_MODE ne "regression"} {error "Fault injection uses only the default regression"}
  set RUN_PREFIX sampler/checker_negative
  set GUI_LOG sampler/checker_negative_gui.log
  set EXTRA_ARGS {+SAMPLER_INJECT_BAD_OUTPUT}
  if {[info exists SAMPLER_FAULT_KIND]} {
    if {$SAMPLER_FAULT_KIND ni {value index tag last status}} {error "Unknown SAMPLER_FAULT_KIND"}
    lappend EXTRA_ARGS +SAMPLER_FAULT_KIND=$SAMPLER_FAULT_KIND
    if {$SAMPLER_FAULT_KIND ne "value"} {
      set RUN_PREFIX sampler/checker_negative_$SAMPLER_FAULT_KIND
      set GUI_LOG sampler/checker_negative_${SAMPLER_FAULT_KIND}_gui.log
    }
  }
}
if {$SAMPLER_MODE eq "vectors"} {
  set RUN_PREFIX sampler/vector
  set RUN_TEST sampler_vector_test
  set GUI_LOG sampler/vector_gui.log
  file delete -force sampler/sampler_dut_outputs.txt sampler/compare.log
  if {![file exists ../FIPS204_SAMPLER/sampler_inputs.txt]} {error "Run Python prepare first"}
}
if {$SAMPLER_MODE eq "performance"} {
  set RUN_PREFIX sampler/performance
  set RUN_TEST sampler_performance_test
  set GUI_LOG sampler/performance_gui.log
  set EXTRA_ARGS {+SAMPLER_PERFORMANCE}
  file delete -force sampler/performance.csv
  if {![file exists ../FIPS204_SAMPLER/sampler_inputs.txt]} {error "Run Python prepare first"}
}
if {![file exists sampler/work_uvm]} {vlib sampler/work_uvm}
vmap work sampler/work_uvm
if {![batch_mode]} {transcript file $GUI_LOG}
set RTL ../src/sampler
set TB ../tb_uvm/tb_uvm_sampler
vlog -sv -work work $RTL/sampler_pkg.sv
vlog -sv +cover=sbceft -work work $RTL/sampler_secret_lane.sv $RTL/sampler_mask_unpack.sv $RTL/sampler_input_prepare.sv $RTL/sampler_ball.sv $RTL/sampler_compact.sv $RTL/sampler.sv
vlog -sv -work work $TB/sampler_ref_pkg.sv $TB/sampler_if.sv
vlog -sv +incdir+$TB -L mtiUvm -work work $TB/sampler_uvm_pkg.sv $TB/tb_top.sv
vsim -coverage -wlf ${RUN_PREFIX}.wlf -sv_seed 20261016 -voptargs=+acc work.tb_top +UVM_TESTNAME=$RUN_TEST +SAMPLER_COV_PREFIX=$RUN_PREFIX {*}$EXTRA_ARGS
onfinish stop
coverage save -onexit ${RUN_PREFIX}.ucdb
if {![batch_mode]} {
  view transcript
  view wave
  view covergroups
  view instance
  view canalysis
  delete wave *
  add wave -divider {Clock and job}
  add wave /tb_top/clk /tb_top/vif/rst /tb_top/vif/job_*
  add wave -divider {Tagged input}
  add wave -radix hexadecimal /tb_top/vif/input_*
  add wave -divider {Tagged coefficients}
  add wave -radix unsigned /tb_top/vif/output_*
  add wave -divider {Completion}
  add wave /tb_top/vif/status_* /tb_top/vif/active /tb_top/vif/source_stop
  add wave -divider {Candidate and packed pipeline}
  add wave /tb_top/dut/decode_valid_r /tb_top/dut/decode_core_r /tb_top/dut/packed_valid_r /tb_top/dut/packed_core_r
  add wave -radix unsigned /tb_top/dut/packed_count_r /tb_top/dut/generated_r /tb_top/dut/emitted_r
  add wave -divider {Circular collectors}
  add wave -radix unsigned /tb_top/dut/count_r /tb_top/dut/head_r /tb_top/dut/tail_r
  add wave -divider {Challenge control}
  add wave /tb_top/dut/u_ball/state /tb_top/dut/u_ball/done_o /tb_top/dut/u_ball/exhausted_o
  log /tb_top/vif/* /tb_top/dut/u_ball/state
  log /tb_top/dut/decode_valid_r /tb_top/dut/packed_valid_r /tb_top/dut/count_r /tb_top/dut/head_r /tb_top/dut/tail_r
  configure wave -signalnamewidth 1
}
run -all
coverage save ${RUN_PREFIX}.ucdb
coverage report -details -output ${RUN_PREFIX}_coverage.rpt
coverage report -cvg -details -output ${RUN_PREFIX}_functional.rpt
set functional_fd [open ${RUN_PREFIX}_functional.rpt r]
set functional_text [read $functional_fd]
close $functional_fd
if {![regexp {Covergroup Bins\s+(\d+)\s+(\d+)\s+(\d+)} $functional_text -> functional_bins functional_hits functional_misses]} {
  error "Functional coverage bin totals missing"
}
echo [format {OVERALL FUNCTIONAL COVERAGE (raw bins): %d / %d = %.2f%%; %d misses} $functional_hits $functional_bins [expr {100.0*$functional_hits/$functional_bins}] $functional_misses]
unset functional_fd functional_text functional_bins functional_hits functional_misses
echo {FUNCTIONAL COVERAGE: 15 successful-operation groups plus8 checked outcome/internal/protocol/random groups. Raw-bin total above includes all23; the15-group success mean is separate. Reachable unhit combinations remain visible; no percentage ceiling is applied.}
echo "DUT CODE COVERAGE (details in ${RUN_PREFIX}_code.rpt):"
coverage report -codeAll -summary -instance=/tb_top/dut
coverage report -codeAll -details -output ${RUN_PREFIX}_code.rpt
set cov_fd [open ${RUN_PREFIX}_code.rpt r]
set cov_text [read $cov_fd]
close $cov_fd
set cov_hits 0
set cov_total 0
set cov_seen [dict create]
set cov_instance {}
foreach cov_line [split $cov_text "\n"] {
  if {[regexp {^=== Instance: (\S+)} $cov_line -> cov_path]} {set cov_instance $cov_path}
  if {[regexp {^/tb_top/dut(?:/|$)} $cov_instance] && [regexp {^\s*(Statements|Branches|Conditions|Expressions|Toggles|States|Transitions)\s+(\d+)\s+(\d+)\s+(\d+)\s+} $cov_line -> cov_kind cov_bins cov_hit cov_miss]} {
    set cov_key "$cov_instance/$cov_kind"
    if {![dict exists $cov_seen $cov_key]} {
      dict set cov_seen $cov_key 1
      incr cov_hits $cov_hit
      incr cov_total $cov_bins
    }
  }
}
if {$cov_total == 0} {error "DUT code coverage totals missing"}
echo [format {OVERALL DUT CODE COVERAGE (raw bins): %d / %d = %.2f%%} $cov_hits $cov_total [expr {100.0*$cov_hits/$cov_total}]]
echo {Overall = summed hits / enabled code bins; toggle bins dominate. FSM coverage is reported only if Questa infers it; an RTL enum alone does not prove an inferred FSM.}
unset cov_fd cov_text cov_hits cov_total cov_seen cov_line cov_kind cov_bins cov_hit cov_miss cov_instance cov_path cov_key
if {![batch_mode]} {wave zoom range 0ns 2500ns;view wave} else {quit -sim}
unset RTL TB RUN_PREFIX RUN_TEST GUI_LOG EXTRA_ARGS SAMPLER_MODE
catch {unset SAMPLER_INJECT_FAULT}
catch {unset SAMPLER_FAULT_KIND}
