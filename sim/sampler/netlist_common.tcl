if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
if {![file exists $SAMPLER_NETLIST]} {error "Generate netlists using quartus/sampler/generate_netlists.ps1 first"}
# Stage 5 must record freshly exported netlist hashes and accepted source
# identity. A missing record fails closed instead of running stale logic.
set check_script {
import hashlib,json,pathlib
root=pathlib.Path('..')
record=root/'quartus/sampler/netlist_provenance.json'
if not record.exists():raise SystemExit('Stage 5 current-build netlist provenance is pending; generate and record distinct accepted-build netlists first.')
r=json.loads(record.read_text())
files={n:h for n,h in r['source_hashes'].items() if n.startswith('src/sampler/') or (n.startswith('quartus/sampler/') and n.endswith(('.qsf','.qpf','.sdc')))}
bad=[n for n,h in files.items() if hashlib.sha256((root/n).read_bytes()).hexdigest()!=h]
if bad:raise SystemExit('Netlist DUT/settings differ from the recorded implementation: '+', '.join(bad))
netlist_key=__NETLIST_PATH__
netlist=root/netlist_key
expected=r.get('netlist_hashes',{}).get(netlist_key)
if not expected or hashlib.sha256(netlist.read_bytes()).hexdigest()!=expected:raise SystemExit('Generated netlist hash is missing or differs from Stage 5 provenance.')
print('Recorded Stage5 DUT/settings and netlist identity verified.')
}
set netlist_relative [string range $SAMPLER_NETLIST 3 end]
set check_script [string map [list __NETLIST_PATH__ "'$netlist_relative'"] $check_script]
if {[catch {exec python -c $check_script} check_result]} {error $check_result}
echo $check_result
unset check_script check_result netlist_relative
if {![file exists ../FIPS204_SAMPLER/sampler_inputs.txt]} {error "Run Python prepare first"}
if {![info exists QUARTUS_SIMLIB]} {set QUARTUS_SIMLIB F:/altera/quartus/eda/sim_lib}
set prefix sampler/$SAMPLER_REPRESENTATION
if {![batch_mode]} {transcript file ${prefix}_gui.log;transcript on}
set vendor_root sampler/vendor_libs
file mkdir $vendor_root
foreach {lib source_file} {altera_ver altera_primitives.v lpm_ver 220model.v sgate_ver sgate.v altera_mf_ver altera_mf.v altera_lnsim_ver altera_lnsim.sv cyclonev_ver cyclonev_atoms.v} {
  set path $vendor_root/$lib
  if {![file exists $path]} {vlib $path}
  vmap $lib $path
  set sources [list $QUARTUS_SIMLIB/$source_file]
  if {$lib eq "cyclonev_ver"} {lappend sources $QUARTUS_SIMLIB/mentor/cyclonev_atoms_ncrypt.v}
  set key [list [info nameofexecutable] [file mtime [info nameofexecutable]]]
  foreach f $sources {lappend key [file normalize $f] [file mtime $f] [file size $f]}
  set prior {}
  if {[file exists $path/compiled.ok]} {set fd [open $path/compiled.ok r];set prior [read $fd];close $fd}
  if {$prior ne $key} {
    foreach f $sources {
      if {[file extension $f] eq ".sv"} {vlog -sv -work $lib $f} else {vlog -work $lib $f}
    }
    set fd [open $path/compiled.ok w];puts -nonewline $fd $key;close $fd
  }
}
set work_dir sampler/work_$SAMPLER_REPRESENTATION
if {![file exists $work_dir]} {vlib $work_dir}
vmap work $work_dir
set TB ../tb_uvm/tb_uvm_sampler
vlog -sv -work work ../src/sampler/sampler_pkg.sv
# Only the generated DUT: never compile sampler.sv/datapath RTL into this work.
vlog -work work $SAMPLER_NETLIST
vlog -sv +define+SAMPLER_NETLIST -work work $TB/sampler_ref_pkg.sv $TB/sampler_if.sv
vlog -sv +define+SAMPLER_NETLIST +incdir+$TB -L mtiUvm -work work $TB/sampler_uvm_pkg.sv $TB/tb_top.sv
vsim -coverage -t 1ps -wlf ${prefix}.wlf -voptargs=+acc -sv_seed 20261016 -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver work.tb_top +UVM_TESTNAME=sampler_netlist_test +SAMPLER_COV_PREFIX=$prefix +SAMPLER_OUTPUT_FILE=${prefix}_outputs.txt
onfinish stop
coverage save -onexit ${prefix}.ucdb
if {![batch_mode]} {
  view transcript;view wave;view covergroups;view instance
  delete wave *
  add wave -divider {Clock and tagged jobs}
  add wave /tb_top/clk /tb_top/vif/rst /tb_top/vif/job_*
  add wave -divider {SHAKE input}
  add wave -radix hexadecimal /tb_top/vif/input_*
  add wave -divider {Coefficients and completion}
  add wave -radix unsigned /tb_top/vif/output_* /tb_top/vif/status_*
  add wave /tb_top/vif/active /tb_top/vif/source_stop
  log /tb_top/vif/*
}
run -all
coverage save ${prefix}.ucdb
coverage report -cvg -details -output ${prefix}_functional.rpt
set fd [open ${prefix}_functional.rpt r];set cov [read $fd];close $fd
if {![regexp {Covergroup Bins\s+(\d+)\s+(\d+)\s+(\d+)} $cov -> bins hits misses]} {error "Functional coverage totals missing"}
echo [format {NETLIST FUNCTIONAL COVERAGE: %d/%d = %.2f%%; source-only groups are unsampled and not waived} $hits $bins [expr {100.0*$hits/$bins}]]
echo {Functional netlist only. RTL code coverage remains the separate source result; TimeQuest supplies timing evidence.}
echo "Independent Python command: python ../FIPS204_SAMPLER/sampler_vectors.py compare --outputs sampler/${SAMPLER_REPRESENTATION}_outputs.txt"
if {[batch_mode]} {quit -sim} else {wave zoom range 0ns 2500ns;view wave}
foreach variable {SAMPLER_REPRESENTATION SAMPLER_NETLIST prefix vendor_root lib source_file path sources key prior f fd work_dir TB cov bins hits misses} {unset $variable}
