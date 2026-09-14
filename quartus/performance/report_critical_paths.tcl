package require ::quartus::project
package require ::quartus::sta

set project_name keccak_performance
set revision_name keccak_performance
set report_dir critical_paths

if {[llength $quartus(args)] >= 1} {
    set project_name [lindex $quartus(args) 0]
}
if {[llength $quartus(args)] >= 2} {
    set revision_name [lindex $quartus(args) 1]
}

project_open $project_name -revision $revision_name
create_timing_netlist
read_sdc
update_timing_netlist

file mkdir $report_dir

report_timing -setup -multi_corner -npaths 20 -detail full_path -show_routing -panel_name "LightHD challenge: worst setup paths" -file [file join $report_dir worst_setup_paths.rpt]

report_timing -hold -multi_corner -npaths 20 -detail full_path -show_routing -panel_name "LightHD challenge: worst hold paths" -file [file join $report_dir worst_hold_paths.rpt]

report_clock_fmax_summary -panel_name "LightHD challenge: Fmax summary" -file [file join $report_dir fmax_summary.rpt]

report_ucp -panel_name "LightHD challenge: unconstrained paths" -file [file join $report_dir unconstrained_paths.rpt]

delete_timing_netlist
project_close
