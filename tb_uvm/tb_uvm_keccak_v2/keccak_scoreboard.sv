// =========================================================================
// keccak_scoreboard.sv  -  TB v2 scoreboard
// Pairs driver intent with monitor-observed activity. Only transactions that
// pass control, input, output, and protocol checks are published to coverage.
// =========================================================================
class keccak_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(keccak_scoreboard)

    uvm_tlm_analysis_fifo #(keccak_transaction) exp_fifo;
    uvm_tlm_analysis_fifo #(keccak_transaction) obs_fifo;
    uvm_analysis_port #(keccak_transaction) checked_ap;

    int total_tests;
    int passed_tests;
    int failed_tests;

    function new(string name = "keccak_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;
        checked_ap   = new("checked_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_fifo = new("exp_fifo", this);
        obs_fifo = new("obs_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            keccak_transaction exp_tx;
            keccak_transaction obs_tx;
            exp_fifo.get(exp_tx);
            obs_fifo.get(obs_tx);
            compare_tx(exp_tx, obs_tx);
        end
    endtask

    function void compare_tx(keccak_transaction exp_tx, keccak_transaction obs_tx);
        string obs_str = "";
        string exp_str;
        string exp_msg;
        string obs_msg;
        int    exp_bytes;
        bit    pass;
        bit    control_match;
        bit    input_match;
        bit    output_match;

        total_tests++;
        exp_bytes = exp_tx.output_len_bits / 8;
        exp_str   = exp_tx.exp_hex.tolower();
        exp_msg   = exp_tx.msg_hex.tolower();
        obs_msg   = obs_tx.obs_msg_hex.tolower();

        for (int i = 0; i < exp_bytes; i++) begin
            if (i < obs_tx.obs_bytes.size())
                obs_str = {obs_str, $sformatf("%02x", obs_tx.obs_bytes[i])};
            else
                obs_str = {obs_str, "XX"};
        end

        control_match = (obs_tx.mode === exp_tx.mode) &&
                        (obs_tx.xof_len_val === exp_tx.xof_len_val);
        input_match   = (obs_msg == exp_msg);
        output_match  = (obs_tx.obs_bytes.size() == exp_bytes) &&
                        (obs_str == exp_str);

        if (exp_tx.abort_after_cycles > 0) begin
            obs_tx.data_ok = control_match && obs_tx.reset_observed;
            pass = obs_tx.start_seen && obs_tx.protocol_ok && obs_tx.data_ok;
        end else begin
            obs_tx.data_ok = control_match && input_match && output_match;
            pass = obs_tx.start_seen && obs_tx.input_complete &&
                   obs_tx.protocol_ok && obs_tx.data_ok;
        end

        obs_tx.passed = pass;

        if (pass) begin
            passed_tests++;
            checked_ap.write(obs_tx);
            `uvm_info(get_type_name(),
                      $sformatf("[PASS] %s  (in=%0d bytes, out=%0d bytes, protocol_errors=0)",
                                exp_tx.test_name, obs_tx.accepted_input_bytes,
                                obs_tx.obs_bytes.size()),
                      UVM_LOW)
        end else begin
            failed_tests++;
            obs_tx.failure_reason = $sformatf(
                "control=%0b input=%0b output=%0b protocol=%0b errors=%0d",
                control_match, input_match, output_match, obs_tx.protocol_ok,
                obs_tx.protocol_errors);
            `uvm_error(get_type_name(),
                       $sformatf("[FAIL] %s  %s\n        Input bytes expected/observed: %0d/%0d\n        Expected output: %s\n        Observed output: %s\n        Protocol detail: %s",
                                 exp_tx.test_name, obs_tx.failure_reason,
                                 exp_msg.len() / 2, obs_tx.accepted_input_bytes,
                                 exp_str, obs_str, obs_tx.protocol_error_text))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
                  $sformatf("\n=================== SCOREBOARD SUMMARY ===================\n  Total:  %0d\n  Passed: %0d\n  Failed: %0d\n==========================================================",
                            total_tests, passed_tests, failed_tests),
                  UVM_NONE)
    endfunction

endclass
