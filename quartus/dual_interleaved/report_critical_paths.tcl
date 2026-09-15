load_package report
load_package flow
project_open keccak_dual_interleaved -revision keccak_dual_interleaved
create_timing_netlist
read_sdc
update_timing_netlist
file mkdir critical_paths
report_clock_fmax_summary -file critical_paths/fmax_summary.rpt
report_timing -setup -multi_corner -npaths 20 -detail full_path -show_routing -file critical_paths/worst_setup_paths.rpt
report_timing -hold -multi_corner -npaths 20 -detail full_path -show_routing -file critical_paths/worst_hold_paths.rpt
report_ucp -file critical_paths/unconstrained_paths.rpt
project_close
