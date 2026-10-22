// =========================================================================
// keccak_transaction.sv  -  UVM sequence item for keccak_core (TB v2)
// Carries expected stimulus plus monitor-observed control, input, output, and
// interface status. Coverage is allowed to sample only a scoreboard-passed item.
// =========================================================================
class keccak_transaction extends uvm_sequence_item;
    `uvm_object_utils(keccak_transaction)

    string                          test_name;
    rand keccak_mode                mode;
    string                          msg_hex;          // input message in hex string ("84f6cb...")
    rand bit [XOF_LEN_WIDTH-1:0]    xof_len_val;      // 0 = continuous, else bounded bytes
    bit [MSG_LEN_WIDTH-1:0]         message_len_val;
    string                          exp_hex;          // expected output hex string
    int                             output_len_bits;  // bits of output to verify

    // Requested and observed pre-reset phase. Values are 1=IDLE, 2=ABSORB,
    // 3=SUFFIX_PADDING, 4=PERMUTE even round, 5=PERMUTE odd round, 6=SQUEEZE.
    int                             reset_state_target = 0;
    int                             reset_state_observed = 0;

    // Protocol-stress controls. Kind values are 0=none, 1=single-cycle,
    // 2=burst, and 3=randomized. Stall position is 1=ordinary beat,
    // 2=final beat, and 3=rate-boundary beat.
    int                             input_gap_kind = 0;
    int                             output_stall_kind = 0;
    int                             stall_position = 0;
    int                             expected_active_lanes = 0;
    bit                             stop_during_stall = 0;
    bit                             reset_before_start = 1;
    int                             config_change_kind = 0;
    int                             stop_position_target = 0;
    bit                             hold_valid_after_message = 0;

    // Cross-transaction verification requests. These describe the relation
    // the scoreboard must prove; coverage fields below are set only after the
    // individual transaction and the requested relation both pass.
    int                             back_to_back_request = 0;
    int                             stall_equivalence_request = 0;
    bit                             equivalence_reference = 0;
    int                             prefix_consistency_request = 0;
    bit                             prefix_reference = 0;
    int                             byte_order_case = 0;
    int                             byte_order_case_count = 0;
    int                             lane_isolation_request = 0;
    bit                             mixed_lane_work_request = 0;

    // Filled from accepted interface activity by the monitor
    string                          obs_msg_hex;
    logic [7:0]                     obs_bytes[$];
    bit                             start_seen = 0;
    bit                             pre_start_reset_seen = 0;
    bit                             input_complete = 0;
    bit                             reset_observed = 0;
    bit                             stop_issued = 0;
    bit                             stop_while_stalled = 0;
    bit                             protocol_ok = 1;
    bit                             data_ok = 0;
    bit                             passed = 0;
    int                             protocol_errors = 0;
    string                          protocol_error_text;
    string                          failure_reason;

    int                             accepted_input_beats = 0;
    int                             accepted_input_bytes = 0;
    int                             input_gap_cycles = 0;
    int                             accepted_output_beats = 0;
    int                             output_stall_cycles = 0;
    int                             stop_wait_cycles = 0;
    int                             final_input_bytes = 0;
    int                             final_output_bytes = 0;
    int                             max_active_lanes = 0;
    int                             stop_position_observed = 0;
    bit                             peer_reset_observed = 0;
    bit                             peer_stall_observed = 0;
    bit                             peer_stop_observed = 0;
    bit                             permutation_suite_observed = 0;

    // Observed P1 closure scenarios.
    // Zero means not observed. Coverage must not set these from a test name;
    // future monitors/checkers set them only after the behavior passes.
    int                             back_to_back_transition = 0;
    int                             config_latch_case = 0;
    int                             reset_recovery_state = 0;
    int                             stop_recovery_position = 0;
    int                             stall_equivalence_kind = 0;
    int                             lane_isolation_kind = 0;
    int                             mixed_lane_work_case = 0;
    int                             prefix_consistency_kind = 0;
    int                             byte_order_suite = 0;
    int                             permutation_suite = 0;

    function new(string name = "keccak_transaction");
        super.new(name);
    endfunction

    // Rate in bytes (used by monitor for output-boundary checking)
    function int get_rate_bytes();
        case (mode)
            SHAKE128: return 168;
            SHAKE256: return 136;
            default:  return 168;
        endcase
    endfunction

    function int get_expected_bytes();
        return output_len_bits / 8;
    endfunction

    function bit is_shake();
        return (mode == SHAKE128) || (mode == SHAKE256);
    endfunction

    function bit is_continuous();
        return is_shake() && (xof_len_val == 0);
    endfunction

    function string convert2string();
        return $sformatf("test_name=%s mode=%s xof_len=%0d msg=\"%s\" out_bits=%0d",
                         test_name, mode.name(), xof_len_val, msg_hex, output_len_bits);
    endfunction

endclass
