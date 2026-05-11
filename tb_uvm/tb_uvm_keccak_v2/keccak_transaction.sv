// =========================================================================
// keccak_transaction.sv  -  UVM sequence item for keccak_core (TB v2)
// Carries: test_name, mode, msg (hex string), xof_len, expected output (hex),
//          output_len_bits, and (filled by monitor) observed bytes.
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

    // Filled by monitor
    logic [7:0]                     obs_bytes[$];

    function new(string name = "keccak_transaction");
        super.new(name);
    endfunction

    // Rate in bytes (used by monitor to verify tkeep/tlast per beat)
    function int get_rate_bytes();
        case (mode)
            SHAKE128: return 168;
            SHAKE256: return 136;
            SHA3_256: return 136;
            SHA3_512: return 72;
            default:  return 136;
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
