// =========================================================================
// Keccak Sequences
// =========================================================================

// Base sequence
class keccak_base_seq extends uvm_sequence #(keccak_transaction);
    `uvm_object_utils(keccak_base_seq)

    function new(string name = "keccak_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Override in derived classes
    endtask

    // Create a transaction from test vector
    virtual function keccak_transaction create_tx_from_vector(
        string name,
        keccak_mode mode,
        string msg_hex_str,
        string exp_md_hex_str,
        int output_len_bits,
        int xof_len_val
    );
        keccak_transaction tx = keccak_transaction::type_id::create("tx");
        tx.test_name = name;
        tx.mode = mode;
        tx.output_len_bits = output_len_bits;
        tx.xof_len_val = xof_len_val;
        tx.set_msg_from_hex(msg_hex_str);
        tx.set_exp_from_hex(exp_md_hex_str);
        return tx;
    endfunction

endclass

// Single test vector sequence
class keccak_test_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_test_seq)

    string      test_name;
    keccak_mode mode;
    string      msg_hex_str;
    string      exp_md_hex_str;
    int         output_len_bits;
    int         xof_len_val;

    function new(string name = "keccak_test_seq");
        super.new(name);
    endfunction

    virtual task body();
        keccak_transaction tx;
        
        tx = create_tx_from_vector(test_name, mode, msg_hex_str, 
                                    exp_md_hex_str, output_len_bits, xof_len_val);
        
        start_item(tx);
        finish_item(tx);
        
        `uvm_info(get_type_name(), $sformatf("Sent: %s", tx.convert2string()), UVM_LOW)
    endtask

endclass

// Multiple test vectors sequence
class keccak_suite_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_suite_seq)

    keccak_test_seq test_seq;
    int seq_count = 0;

    function new(string name = "keccak_suite_seq");
        super.new(name);
    endfunction

    virtual task body();
        // SHA3-256 Vectors
        run_vector("SHA3-256 Empty", SHA3_256, "", 
                   "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", 256, 0);
        
        run_vector("SHA3-256 Short", SHA3_256, "616263",
                   "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", 256, 0);
        
        // SHA3-512 Vectors
        run_vector("SHA3-512 Empty", SHA3_512, "",
                   "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26", 512, 0);
        
        // SHAKE128 Vectors
        run_vector("SHAKE128 Empty", SHAKE128, "",
                   "7f9c2ba4e88f827d616045507605853e", 128, 0);
        run_vector("SHAKE128 Empty (Bounded)", SHAKE128, "",
                   "7f9c2ba4e88f827d616045507605853e", 128, 16);
        
        // SHAKE256 Vectors
        run_vector("SHAKE256 Empty", SHAKE256, "",
                   "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f", 256, 0);
    endtask

    virtual task run_vector(string name, keccak_mode mode, string msg, 
                            string exp, int out_bits, int xof_len);
        test_seq = keccak_test_seq::type_id::create($sformatf("test_seq_%0d", seq_count++));
        test_seq.test_name = name;
        test_seq.mode = mode;
        test_seq.msg_hex_str = msg;
        test_seq.exp_md_hex_str = exp;
        test_seq.output_len_bits = out_bits;
        test_seq.xof_len_val = xof_len;
        test_seq.start(m_sequencer);
    endtask

endclass

// Random test sequence
class keccak_random_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_random_seq)

    rand int num_transactions = 10;
    rand keccak_mode modes[$];
    rand int msg_len_range[2];
    rand int output_len_range[2];

    constraint valid_modes {
        modes.size() inside {[1:4]};
        foreach (modes[i]) modes[i] inside {SHA3_256, SHA3_512, SHAKE128, SHAKE256};
    }

    constraint msg_len_range_valid {
        msg_len_range[0] >= 0;
        msg_len_range[1] <= 8192;
        msg_len_range[0] < msg_len_range[1];
    }

    constraint output_len_valid {
        output_len_range[0] >= 8;
        output_len_range[1] <= 8192;
        output_len_range[0] < output_len_range[1];
        output_len_range[0] % 8 == 0;
        output_len_range[1] % 8 == 0;
    }

    function new(string name = "keccak_random_seq");
        super.new(name);
        msg_len_range = '{0, 1024};
        output_len_range = '{128, 512};
    endfunction

    virtual task body();
        keccak_transaction tx;
        
        for (int i = 0; i < num_transactions; i++) begin
            tx = keccak_transaction::type_id::create($sformatf("tx_%0d", i));
            randomize_transaction(tx);
            start_item(tx);
            finish_item(tx);
        end
    endtask

    virtual function void randomize_transaction(keccak_transaction tx);
        int mode_idx = $urandom_range(0, modes.size() - 1);
        int msg_len = $urandom_range(msg_len_range[0], msg_len_range[1]);
        
        tx.mode = modes[mode_idx];
        tx.output_len_bits = $urandom_range(output_len_range[0], output_len_range[1]);
        tx.output_len_bits = (tx.output_len_bits / 8) * 8;  // Align to bytes
        
        if (tx.is_shake()) begin
            tx.xof_len_val = $urandom_range(0, tx.output_len_bits / 8);
        end else begin
            tx.xof_len_val = 0;
        end
        
        // Generate random message bytes
        tx.msg_bytes = new[msg_len];
        for (int j = 0; j < msg_len; j++) begin
            tx.msg_bytes[j] = $urandom();
        end
        
        tx.test_name = $sformatf("RANDOM_%s_LEN%d", tx.mode.name(), msg_len);
        
        // Note: Expected output would need to be calculated by reference model
        // For now, we rely on the scoreboard to compare with reference model output
    endfunction

endclass