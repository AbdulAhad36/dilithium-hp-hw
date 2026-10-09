# Inspect both slow corners; slow 0 C can be worse than slow 85 C.
project_open ntt -revision ntt
create_timing_netlist -model slow
read_sdc
foreach temperature {85 0} {
    set_operating_conditions -model slow -temperature $temperature -voltage 1100
    update_timing_netlist
    puts "==== WORST 3 SETUP PATHS (Slow ${temperature}C, 1100mV) ===="
    report_timing -setup -npaths 3 -detail summary -stdout
    puts "==== WORST PATH FULL DETAIL (Slow ${temperature}C) ===="
    report_timing -setup -npaths 1 -detail full_path -stdout
}
delete_timing_netlist
project_close
