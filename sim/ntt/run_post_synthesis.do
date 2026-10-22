# Self-contained post_synthesis functional main-UVM flow. Run from sim/.
# Cyclone V netlists are functional only; timing signoff uses TimeQuest.
set NTT_REPRESENTATION post_synthesis
set NTT_NETLIST_FILE ../quartus/ntt/simulation_postsynth/ntt.vo
if {![batch_mode]} {transcript file ntt/post_synthesis_gui.log}
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
if {![info exists NTT_REPRESENTATION] || ![info exists NTT_NETLIST_FILE]} {error "Use run_post_synthesis.do or run_post_fit.do"}
if {![file exists $NTT_NETLIST_FILE]} {error "Generate netlists using quartus/ntt/generate_netlists.ps1 first"}
if {![info exists NTT_TEST]} {set NTT_TEST ntt_netlist_test}
# Run from sim/. Compile local vendor primitives once, including encrypted atoms.
if {![info exists QUARTUS_SIMLIB]} {set QUARTUS_SIMLIB F:/altera/quartus/eda/sim_lib}
set vendor_root ntt/vendor_libs
file mkdir $vendor_root
set vendor_pairs [list altera_ver altera_primitives.v lpm_ver 220model.v sgate_ver sgate.v altera_mf_ver altera_mf.v altera_lnsim_ver altera_lnsim.sv cyclonev_ver cyclonev_atoms.v]
foreach {lib source_file} $vendor_pairs {
    set lib_dir $vendor_root/$lib
    if {![file exists $lib_dir]} {vlib $lib_dir}
    vmap $lib $lib_dir
    if {![file exists $lib_dir/compiled.ok]} {
        if {[file extension $source_file] eq ".sv"} {
            vlog -sv -work $lib $QUARTUS_SIMLIB/$source_file
        } else {vlog -work $lib $QUARTUS_SIMLIB/$source_file}
        if {$lib eq "cyclonev_ver"} {vlog -work $lib $QUARTUS_SIMLIB/mentor/cyclonev_atoms_ncrypt.v}
        set marker [open $lib_dir/compiled.ok w]
        puts $marker "Questa primitives compiled from $QUARTUS_SIMLIB"
        close $marker
    }
}
unset vendor_root vendor_pairs lib source_file lib_dir

set NTT_WORK ntt/work_$NTT_REPRESENTATION
if {![file exists $NTT_WORK]} {vlib $NTT_WORK}
vmap work $NTT_WORK
set RTL ../src/ntt
set TB ../tb_uvm/tb_uvm_ntt_LightHD
vlog -sv -work work $RTL/ntt_pkg.sv
# Only the generated DUT; source ntt_engine/core/datapath must not be compiled.
vlog -work work $NTT_NETLIST_FILE
vlog -sv +incdir+$TB -L mtiUvm -work work $TB/ntt_ref_pkg.sv $TB/ntt_if.sv
vlog -sv +define+NTT_FIFO +define+NTT_NETLIST +incdir+$TB -L mtiUvm -work work $TB/tb_top.sv
vsim -wlf ntt/${NTT_REPRESENTATION}.wlf -voptargs=+acc -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver work.tb_top +UVM_TESTNAME=$NTT_TEST +NTT_REPRESENTATION=$NTT_REPRESENTATION
onfinish stop
if {![batch_mode]} {
  transcript on
  view transcript
  view structure
  view objects
  view wave
  delete wave *
  view source
  add wave -divider {Control}
  add wave /tb_top/clk /tb_top/vif/rst /tb_top/vif/start /tb_top/vif/op /tb_top/vif/busy /tb_top/vif/done
  add wave -divider {Input}
  add wave -radix unsigned /tb_top/vif/s_tdata /tb_top/vif/s_tvalid /tb_top/vif/s_tready /tb_top/vif/s_tlast
  add wave -divider {Output}
  add wave -radix unsigned /tb_top/vif/m_tdata /tb_top/vif/m_tvalid /tb_top/vif/m_tready /tb_top/vif/m_tlast
}
run -all
if {[batch_mode]} {quit -sim} else {
  view wave -undock -width 1280 -height 720
  configure wave -namecolwidth 260
  configure wave -valuecolwidth 100
  configure wave -signalnamewidth 1
  configure wave -timeline 1
  configure wave -timelineunits us
  if {$NTT_TEST eq "ntt_netlist_test"} {wave zoom range 16us 24us} else {wave zoom full}
  echo "NETLIST GUI READY: functional simulation retained; no source coverage or SDF timing claim."
}
foreach variable {NTT_WORK NTT_TEST NTT_REPRESENTATION NTT_NETLIST_FILE} {unset $variable}
