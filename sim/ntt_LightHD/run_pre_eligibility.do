# Expected-illegal-input UVM test; NOT part of the normal passing regression.
# Defaults to coefficient 0 = +5; set PRE_INVALID_TEST to
# ntt_pre_invalid_middle_test (-5 at 128) or ntt_pre_invalid_last_test (+5 at 255).
# ntt_pre_invalid_alias_test (+8 at 0, same lookup key as zero).
# Require the exact DUT fatal: Pre-NTT requires every coefficient in [-4,4].
# A timeout, generic UVM failure or zero simulator exit alone is not a pass.
if {![info exists PRE_INVALID_TEST]} {set PRE_INVALID_TEST ntt_pre_invalid_first_test}
set NTT_TEST $PRE_INVALID_TEST
set NTT_WORK ntt_LightHD/work_illegal
set NTT_UCDB ntt_LightHD/ntt_illegal.ucdb
set NTT_REPORT ntt_LightHD/ntt_illegal_code.rpt
do ntt_LightHD/run_uvm.do
unset PRE_INVALID_TEST
