// ============================================================================
// ntt_coverage.sv  --  UVM functional coverage for ntt_engine
// ----------------------------------------------------------------------------
// Subscribes to the scoreboard's checked-pass port. A transaction only hits
// coverage after all 256 observed coefficients and output framing pass.
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

`ifdef NTT_FIFO
    covergroup cg_pre;
        cp_pre_kind : coverpoint tx_sampled.in_kind {
            bins boundary = {IK_PRE_BOUNDARY};
            bins eta2 = {IK_ETA2};
            bins eta4 = {IK_ETA4};
        }
    endgroup
`endif

    function new(string name = "ntt_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_ntt = new();
`ifdef NTT_FIFO
        cg_pre = new();
`endif
    endfunction

    function void write(ntt_transaction t);
        tx_sampled = t;
`ifdef NTT_FIFO
        if (t.op == OP_PRE_NTT) cg_pre.sample();
        else cg_ntt.sample();
`else
        cg_ntt.sample();
`endif
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
                  $sformatf("Functional Coverage: %0.2f%%", cg_ntt.get_coverage()),
                  UVM_NONE)
`ifdef NTT_FIFO
        `uvm_info(get_type_name(),
                  $sformatf("Checked Pre-NTT Coverage: %0.2f%%", cg_pre.get_coverage()),
                  UVM_NONE)
`endif
    endfunction

endclass
