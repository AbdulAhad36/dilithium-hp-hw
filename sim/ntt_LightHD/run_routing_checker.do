# Separate UVM observation-corruption test; preserves main regression coverage.
# Default flips one observed registered operand bit; ROUTING_TEST can select
# ntt_routing_writeback_fault_test to flip one observed FIFO writeback bit.
if {![info exists ROUTING_TEST]} {set ROUTING_TEST ntt_routing_operand_fault_test}
set NTT_TEST $ROUTING_TEST
set NTT_WORK ntt_LightHD/work_routing_gate
set NTT_UCDB ntt_LightHD/ntt_routing_gate.ucdb
set NTT_REPORT ntt_LightHD/ntt_routing_gate_code.rpt
do ntt_LightHD/run_uvm.do
unset ROUTING_TEST
