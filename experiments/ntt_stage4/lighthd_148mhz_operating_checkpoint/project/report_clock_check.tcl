# Reanalyse the fitted implementation at an explicitly selected constraint.
# Default: operating ntt.sdc. Benchmark: pass ntt_benchmark_200mhz.sdc.
set constraint_file ntt.sdc
if {[llength $quartus(args)] > 0} {set constraint_file [lindex $quartus(args) 0]}
project_open ntt -revision ntt
puts "CONSTRAINT_FILE=$constraint_file"
foreach model {slow fast} {
    create_timing_netlist -model $model
    read_sdc $constraint_file
    foreach temperature {85 0} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "==== $model ${temperature}C, 1100mV ===="
        report_timing -setup -npaths 1 -detail summary -stdout
        report_timing -hold -npaths 1 -detail summary -stdout
        report_min_pulse_width -nworst 1 -stdout
        report_clock_fmax_summary -stdout
    }
    delete_timing_netlist
}
project_close
