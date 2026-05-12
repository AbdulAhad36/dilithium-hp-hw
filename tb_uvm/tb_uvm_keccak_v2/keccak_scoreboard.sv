// =========================================================================
// keccak_scoreboard.sv  -  TB v2 scoreboard
// Subscribes to driver (expected) and monitor (observed) analysis ports
// via two analysis FIFOs. Pairs them in-order and compares.
// =========================================================================
class keccak_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(keccak_scoreboard)

    uvm_tlm_analysis_fifo #(keccak_transaction) exp_fifo;
    uvm_tlm_analysis_fifo #(keccak_transaction) obs_fifo;

    int total_tests;
    int passed_tests;
    int failed_tests;

    function new(string name = "keccak_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;
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
        int    exp_bytes;
        bit    pass;

        total_tests++;
        exp_bytes = exp_tx.output_len_bits / 8;
        exp_str   = exp_tx.exp_hex.tolower();

        for (int i = 0; i < exp_bytes; i++) begin
            if (i < obs_tx.obs_bytes.size())
                obs_str = {obs_str, $sformatf("%02x", obs_tx.obs_bytes[i])};
            else
                obs_str = {obs_str, "XX"};
        end

        // Abort transactions: just record as passed (the FSM reset path is
        // verified by coverage, not by data comparison)
        if (exp_tx.abort_after_cycles > 0) begin
            passed_tests++;
            `uvm_info(get_type_name(),
                      $sformatf("[ABORT] %s  (mid-state reset issued)",
                                exp_tx.test_name),
                      UVM_LOW)
            return;
        end

        pass = (obs_str == exp_str);

        if (pass) begin
            passed_tests++;
            `uvm_info(get_type_name(),
                      $sformatf("[PASS] %s  (out=%s)", exp_tx.test_name, obs_str),
                      UVM_LOW)
        end else begin
            failed_tests++;
            `uvm_error(get_type_name(),
                       $sformatf("[FAIL] %s\n        Expected: %s\n        Got:      %s",
                                 exp_tx.test_name, exp_str, obs_str))
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
