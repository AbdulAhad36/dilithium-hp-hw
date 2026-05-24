// ============================================================================
// ntt_coverage.sv  --  UVM functional coverage for ntt_engine
// ----------------------------------------------------------------------------
// Subscribes to the driver's analysis port (the expected transaction) and
// samples per transform. cross(op, in_kind) gives 2 x 4 = 8 cross bins; the
// coverage-closure sequence (ntt_cov_seq) deterministically hits all 8.
// ============================================================================
class ntt_coverage extends uvm_subscriber #(ntt_transaction);
    `uvm_component_utils(ntt_coverage)

    ntt_transaction tx_sampled;

    covergroup cg_ntt;
        cp_op : coverpoint tx_sampled.op {
            bins ntt  = {OP_NTT};
            bins intt = {OP_INTT};
            bins pwm  = {OP_PWM};
        }
        cp_in_kind : coverpoint tx_sampled.in_kind {
            bins zero   = {IK_ZERO};
            bins max    = {IK_MAX};
            bins delta  = {IK_DELTA};
            bins random = {IK_RANDOM};
        }
        cross_op_kind : cross cp_op, cp_in_kind;
    endgroup

    function new(string name = "ntt_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_ntt = new();
    endfunction

    function void write(ntt_transaction t);
        tx_sampled = t;
        cg_ntt.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
                  $sformatf("Functional Coverage: %0.2f%%", cg_ntt.get_coverage()),
                  UVM_NONE)
    endfunction

endclass
