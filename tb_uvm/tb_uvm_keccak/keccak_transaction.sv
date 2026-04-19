// =========================================================================
// Keccak Transaction - Complete test vector
// =========================================================================
class keccak_transaction extends uvm_sequence_item;
    `uvm_object_utils(keccak_transaction)

    // Input fields
    string                              test_name;
    keccak_mode                         mode;
    logic [7:0]                         msg_bytes[];    // Dynamic array of bytes
    int                                 output_len_bits; // Desired output length
    int                                 xof_len_val;     // Bounded length for SHAKE (0 = infinite)

    // Expected output
    logic [7:0]                         exp_bytes[];

    // Observed output (filled by monitor)
    logic [7:0]                         obs_bytes[$];

    // Status
    bit                                 pass;
    string                              fail_reason;

    // Local parameters
    localparam int BYTES_PER_BEAT = DWIDTH / 8;

    function new(string name = "keccak_transaction");
        super.new(name);
    endfunction

    // Convert hex string to byte array
    function void set_msg_from_hex(string hex_str);
        int len = hex_str.len();
        int byte_len = len / 2;
        msg_bytes = new[byte_len];
        for (int i = 0; i < byte_len; i++) begin
            msg_bytes[i] = {hex_char_to_val(hex_str[i*2]), 
                            hex_char_to_val(hex_str[i*2+1])};
        end
    endfunction

    // Convert hex string to expected byte array
    function void set_exp_from_hex(string hex_str);
        int len = hex_str.len();
        int byte_len = len / 2;
        exp_bytes = new[byte_len];
        for (int i = 0; i < byte_len; i++) begin
            exp_bytes[i] = {hex_char_to_val(hex_str[i*2]), 
                            hex_char_to_val(hex_str[i*2+1])};
        end
    endfunction

    // Helper: Char to 4-bit val
    local function logic [3:0] hex_char_to_val(byte c);
        if (c >= "0" && c <= "9") return c - "0";
        if (c >= "a" && c <= "f") return c - "a" + 10;
        if (c >= "A" && c <= "F") return c - "A" + 10;
        return 0;
    endfunction

    // Get rate bytes for current mode
    function int get_rate_bytes();
        case (mode)
            SHA3_256:  return 136;  // 1088 bits
            SHA3_512:  return 72;   // 576 bits
            SHAKE128:  return 168;  // 1344 bits
            SHAKE256:  return 136;  // 1088 bits
            default:   return 136;
        endcase
    endfunction

    // Check if this is a SHAKE (XOF) mode
    function bit is_shake();
        return (mode == SHAKE128 || mode == SHAKE256);
    endfunction

    // Get expected total bytes
    function int get_expected_total_bytes();
        return output_len_bits / 8;
    endfunction

    // Convert transaction to string
    virtual function string convert2string();
        string s;
        s = $sformatf("TEST: %s, Mode: %s, MsgLen: %0d bytes, OutBits: %0d",
                      test_name, mode.name(), msg_bytes.size(), output_len_bits);
        return s;
    endfunction

    // Compare observed vs expected
    function bit compare(keccak_transaction other);
        if (obs_bytes.size() != other.exp_bytes.size()) begin
            pass = 0;
            fail_reason = $sformatf("Size mismatch: got %0d, exp %0d",
                                     obs_bytes.size(), other.exp_bytes.size());
            return 0;
        end
        
        for (int i = 0; i < obs_bytes.size(); i++) begin
            if (obs_bytes[i] !== other.exp_bytes[i]) begin
                pass = 0;
                fail_reason = $sformatf("Byte %0d mismatch: got %02x, exp %02x",
                                         i, obs_bytes[i], other.exp_bytes[i]);
                return 0;
            end
        end
        
        pass = 1;
        return 1;
    endfunction

endclass