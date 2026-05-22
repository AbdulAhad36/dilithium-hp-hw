// ============================================================================
// ntt_transaction.sv  --  UVM sequence item for ntt_engine
// ----------------------------------------------------------------------------
// Carries one transform request: a test name, the operation (NTT / INTT), the
// 256-coefficient input polynomial, and the golden-expected output polynomial
// (filled by the sequence from ntt_ref_pkg). The monitor fills obs_poly with
// what the DUT actually produced; the scoreboard compares obs_poly vs exp_poly.
//
// in_kind classifies the stimulus for functional coverage.
// ============================================================================

// Stimulus class -- used by the coverage model.
typedef enum { IK_ZERO, IK_MAX, IK_DELTA, IK_RANDOM } in_kind_e;

class ntt_transaction extends uvm_sequence_item;
    `uvm_object_utils(ntt_transaction)

    string      test_name;
    ntt_op_e    op;            // OP_NTT or OP_INTT
    in_kind_e   in_kind;       // stimulus class (coverage)

    poly_t      in_poly;       // input polynomial (driven into the sink)
    poly_t      exp_poly;      // golden output    (from ntt_ref_pkg)
    poly_t      obs_poly;      // observed output  (filled by the monitor)

    function new(string name = "ntt_transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("test_name=%s op=%s in_kind=%s",
                         test_name, op.name(), in_kind.name());
    endfunction

endclass
