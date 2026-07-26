// =========================================================================
// keccak_transaction.sv  -  UVM sequence item for keccak_core (TB v2)
// Carries expected stimulus plus monitor-observed control, input, output, and
// protocol status. Coverage is allowed to sample only a scoreboard-passed item.
// =========================================================================
class keccak_transaction extends uvm_sequence_item;
    `uvm_object_utils(keccak_transaction)

    string                          test_name;
    rand keccak_mode                mode;
    string                          msg_hex;          // input message in hex string ("84f6cb...")
    rand bit [XOF_LEN_WIDTH-1:0]    xof_len_val;      // 0 = continuous, else bounded bytes
    string                          exp_hex;          // expected output hex string
    int                             output_len_bits;  // bits of output to verify

    // If >0: driver aborts via async-reset after this many clk cycles of ABSORB.
    // Monitor skips output collection. Used for FSM reset-transition coverage.
    int                             abort_after_cycles = 0;

    // Filled from accepted interface activity by the monitor
    string                          obs_msg_hex;
    logic [7:0]                     obs_bytes[$];
    bit                             start_seen = 0;
    bit                             input_complete = 0;
    bit                             reset_observed = 0;
    bit                             stop_issued = 0;
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
    int                             final_input_bytes = 0;
    int                             final_output_bytes = 0;

    function new(string name = "keccak_transaction");
        super.new(name);
    endfunction

    // Rate in bytes (used by monitor to verify tkeep/tlast per beat)
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
