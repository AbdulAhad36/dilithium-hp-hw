# Permanent stage-specific constraints for both GUI and command-line builds.
# Intel Standard Edition Timing Analyzer guide, section 2.4.3:
# https://www.intel.com/programmable/technical-pdfs/683068.pdf
# Fit at 200 MHz for optimization; final timing analysis uses approved 148 MHz.
# The standalone 200 MHz signoff benchmark is ntt_benchmark_200mhz.sdc.
if {![info exists ::TimingAnalyzerInfo(nameofexecutable)]} {
    error "Cannot identify Quartus stage; refusing to select a timing constraint."
}
set ntt_constraint_executable $::TimingAnalyzerInfo(nameofexecutable)
if {$ntt_constraint_executable eq "quartus_fit" || $ntt_constraint_executable eq "quartus_map"} {
    set ntt_constraint_period 5.000
    puts "NTT_CONSTRAINT_MODE=FIT_TARGET executable=$ntt_constraint_executable period_ns=$ntt_constraint_period"
} else {
    set ntt_constraint_period 6.756757
    puts "NTT_CONSTRAINT_MODE=OPERATING executable=$ntt_constraint_executable period_ns=$ntt_constraint_period"
}
create_clock -name clk -period $ntt_constraint_period [get_ports clk]

# Standalone internal timing only: board integration needs real I/O delays.
set_false_path -from [all_inputs]
set_false_path -to [all_outputs]
derive_clock_uncertainty
unset ntt_constraint_executable
unset ntt_constraint_period
