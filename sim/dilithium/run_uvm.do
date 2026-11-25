# Full-operation main UVM. Questa Transcript, repository root or sim/:
# do sim/dilithium/run_uvm.do   (root); do dilithium/run_uvm.do   (sim/)
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
set launch [file normalize [pwd]]
if {[file exists [file join $launch sim dilithium run_uvm.do]]} {
  set here [file join $launch sim dilithium]
} elseif {[file exists [file join $launch dilithium run_uvm.do]]} {
  set here [file join $launch dilithium]
} else {set here $launch}
set repo [file normalize [file join $here .. ..]]
source [file join $here setup_cyclonev.tcl]
if {[catch {exec python [file join $here dilithium_vectors.py] uvm_check} freshness]} {error $freshness}
echo $freshness
set prefix [file join $here uvm]
set extra {}
if {[info exists DILITHIUM_INJECT_BAD_KEY] && $DILITHIUM_INJECT_BAD_KEY} {
  set prefix [file join $here uvm_negative]
  lappend extra +DILITHIUM_INJECT_BAD_KEY
}
if {![batch_mode]} {transcript file ${prefix}_gui.log}
set workdir [file join $here work_uvm]
if {![file exists $workdir]} {vlib $workdir}
vmap dilithium_uvm_work $workdir
set fd [open [file join $repo quartus dilithium dilithium_full.qsf] r]
set qsf [read $fd];close $fd
foreach line [split $qsf "\n"] {
  if {[regexp {SYSTEMVERILOG_FILE\s+(.+)$} [string trim $line] -> source]} {
    set source [file normalize [file join $repo quartus dilithium $source]]
    if {[file tail $source] in {keccak_pkg.sv sampler_pkg.sv ntt_pkg.sv}} {
      vlog -sv -work dilithium_uvm_work $source
    } else {vlog -sv +cover=sbceft -work dilithium_uvm_work $source}
  }
}
set tb [file join $repo tb_uvm tb_uvm_dilithium]
vlog -sv -work dilithium_uvm_work [file join $tb dilithium_if.sv]
vlog -sv -L mtiUvm +incdir+$tb -work dilithium_uvm_work [file join $tb dilithium_uvm_pkg.sv] [file join $tb tb_top.sv]
if {![info exists DILITHIUM_UVM_TEST]} {set DILITHIUM_UVM_TEST dilithium_regression_test}
set visibility {}
if {![batch_mode]} {set visibility {-voptargs=+acc}}
vsim -L cyclonev_ver -coverage {*}$visibility -sv_seed 20261024 -wlf ${prefix}.wlf dilithium_uvm_work.tb_top +UVM_TESTNAME=$DILITHIUM_UVM_TEST +DILITHIUM_DIR=$here +DILITHIUM_PREFIX=$prefix {*}$extra
onfinish stop
coverage save -onexit ${prefix}.ucdb
if {![batch_mode]} {
  view transcript;view wave;view covergroups;view instance;view canalysis
  delete wave *
  add wave -divider {Main clock and accepted commands}
  add wave /tb_top/clk /tb_top/vif/rst /tb_top/vif/start_* /tb_top/vif/busy_o /tb_top/vif/main_state /tb_top/vif/owners
  add wave -divider {Sign and Verify frames}
  add wave -radix hexadecimal /tb_top/vif/sign_input_* /tb_top/vif/verify_input_*
  add wave -divider {Encoded keys and signatures}
  add wave -radix hexadecimal /tb_top/vif/key_* /tb_top/vif/signature_*
  add wave -divider {Completion and retries}
  add wave /tb_top/vif/done_* /tb_top/vif/verify_accept_o /tb_top/vif/sign_attempts_o /tb_top/vif/sign_rejections_o /tb_top/vif/sign_next_nonce_o
  add wave -divider {Shared engines and memory}
  add wave /tb_top/vif/hash_active /tb_top/vif/ntt_busy /tb_top/vif/process_busy /tb_top/vif/bank_ports /tb_top/vif/bank_owners /tb_top/vif/datapath_idle /tb_top/vif/bank_collision /tb_top/vif/fault_o
  log /tb_top/vif/*
  configure wave -signalnamewidth 1
}
run -all
coverage save ${prefix}.ucdb
source [file join $here report_uvm_coverage.tcl]
if {[examine -radix unsigned /tb_top/vif/test_passed] != 1} {error "Dilithium UVM failed; inspect SCOREBOARD/PROTOCOL messages"}
if {![batch_mode]} {wave zoom range 0ns 4000ns;view wave}
echo {Full-operation UVM complete; raw functional/code coverage and latency CSV are saved next to the launcher.}
