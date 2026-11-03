# Called inside Questa so both summaries appear in its Transcript.
coverage report -cvg -details -output ${prefix}_functional.rpt
set fd [open ${prefix}_functional.rpt r];set functional_text [read $fd];close $fd
if {![regexp {Covergroup Bins\s+(\d+)\s+(\d+)\s+(\d+)} $functional_text -> bins hits misses]} {error "Functional coverage totals missing"}
echo [format {OVERALL FUNCTIONAL COVERAGE (raw defined bins): %d / %d = %.2f%%; %d misses} $hits $bins [expr {100.0*$hits/$bins}] $misses]
coverage report -codeAll -summary -instance=/tb_top/dut
coverage report -codeAll -details -output ${prefix}_code.rpt
set fd [open ${prefix}_code.rpt r];set code_text [read $fd];close $fd
set hits 0;set bins 0;set seen [dict create];set instance {}
foreach line [split $code_text "\n"] {
  if {[regexp {^=== Instance: (\S+)} $line -> path]} {set instance $path}
  if {[regexp {^/tb_top/dut(?:/|$)} $instance] && [regexp {^\s*(Statements|Branches|Conditions|Expressions|Toggles|States|Transitions)\s+(\d+)\s+(\d+)\s+(\d+)\s+} $line -> kind total hit miss]} {
    set key "$instance/$kind"
    if {![dict exists $seen $key]} {dict set seen $key 1;incr hits $hit;incr bins $total}
  }
}
if {$bins==0} {error "DUT code coverage totals missing"}
echo [format {DUT MODULE CODE COVERAGE (raw enabled bins): %d / %d = %.2f%%} $hits $bins [expr {100.0*$hits/$bins}]]
# Executable package functions have DU counters, not DUT instance counters.
# Count that single service package explicitly, once, alongside the modules.
coverage report -codeAll -details -package=dilithium_pkg -output ${prefix}_package_code.rpt
set fd [open ${prefix}_package_code.rpt r];set package_text [read $fd];close $fd
set phits 0;set pbins 0;set seen [dict create]
foreach line [split $package_text "\n"] {
  if {[regexp {^\s*(Statements|Branches|Conditions|Expressions|Toggles|States|Transitions)\s+(\d+)\s+(\d+)\s+(\d+)\s+} $line -> kind total hit miss] && ![dict exists $seen $kind]} {
    dict set seen $kind 1;incr phits $hit;incr pbins $total
  }
}
if {$pbins==0} {error "Executable service-package coverage missing"}
echo [format {SHARED DUT PACKAGE CODE COVERAGE: %d / %d = %.2f%%} $phits $pbins [expr {100.0*$phits/$pbins}]]
incr hits $phits;incr bins $pbins
echo [format {OVERALL DUT CODE COVERAGE (modules + executable service package): %d / %d = %.2f%%} $hits $bins [expr {100.0*$hits/$bins}]]
echo {Raw code total sums enabled statement, branch, condition, expression, toggle and inferred FSM bins; it is not a mean of percentages. No coverage percentage ceiling is applied.}
