# Separate UVM checker self-test; preserves the main regression UCDB/report.
set NTT_WORK ntt_LightHD/work_gate
set NTT_UCDB ntt_LightHD/ntt_gate.ucdb
set NTT_REPORT ntt_LightHD/ntt_gate_code.rpt
set NTT_TEST ntt_coverage_gate_test
do ntt_LightHD/run_uvm.do
