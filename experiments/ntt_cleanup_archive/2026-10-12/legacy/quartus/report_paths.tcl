project_open ntt -revision ntt
create_timing_netlist -model slow
read_sdc
update_timing_netlist
puts "==== WORST 3 SETUP PATHS (Slow 85C) ===="
report_timing -setup -npaths 3 -detail summary -stdout
puts "==== WORST PATH FULL DETAIL ===="
report_timing -setup -npaths 1 -detail full_path -stdout
delete_timing_netlist
project_close
