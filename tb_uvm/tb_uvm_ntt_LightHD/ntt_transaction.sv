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
typedef enum { IK_ZERO, IK_MAX, IK_DELTA, IK_RANDOM,
               IK_PRE_BOUNDARY, IK_ETA2, IK_ETA4 } in_kind_e;

class ntt_transaction extends uvm_sequence_item;
    `uvm_object_utils(ntt_transaction)

    string      test_name;
    ntt_op_e    op;            // OP_NTT, OP_INTT, or OP_PWM
    in_kind_e   in_kind;       // stimulus class (coverage)
    bit         reset_before = 1'b1; // clear state unless a repeated job requests otherwise
    int         reset_point = -1; // -1 normal; 0..8 abort scenario followed by recovery
    int         equivalence_pair = -1;
    bit         equivalence_second; // compare this Pre output with prior observed NTT
    poly_t      abort_poly; // deliberately different from the fresh recovery input
    int         observed_reset_point = -1;
    bit         reset_checks_ok;
    int         input_gap_period; // zero=continuous; otherwise use input_gap_cycles
    int         input_gap_cycles = 2;
    int         pwm_boundary_gap_cycles = 3;
    int         output_stall_cycles = 2;
    int         output_stall_period; // zero selects first/middle/last
    bit         stall_output;     // stall selected accepted output positions

    poly_t      in_poly;       // input polynomial   A (driven into the sink)
    poly_t      in_poly_b;     // input polynomial   B (only used for OP_PWM)
    poly_t      exp_poly;      // golden output       (from ntt_ref_pkg)
    poly_t      obs_poly;      // observed output     (filled by the monitor)
    int         observed_count; // accepted output beats, not merely allocated entries
    bit         output_framing_ok; // m_tlast only on accepted coefficient 255
    bit         output_stability_ok = 1; // externally checked even without RTL trace
    ntt_trace   trace;         // monitor-owned per-job DUT events/checks

    function new(string name = "ntt_transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("test_name=%s op=%s in_kind=%s",
                         test_name, op.name(), in_kind.name());
    endfunction

endclass
