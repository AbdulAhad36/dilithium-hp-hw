// =========================================================================
// Keccak Scoreboard - Compares expected vs observed results
// =========================================================================
class keccak_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(keccak_scoreboard)

    uvm_analysis_imp #(keccak_transaction, keccak_scoreboard) analysis_imp;
    
    // Expected transactions queue (from reference model)
    keccak_transaction expected_tx_queue[$];
    
    // Observed transactions queue (from monitor)
    keccak_transaction observed_tx_queue[$];
    
    int passes = 0;
    int failures = 0;

    function new(string name = "keccak_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        analysis_imp = new("analysis_imp", this);
    endfunction

    virtual function void write(keccak_transaction tx);
        // This is called by monitor - observed transaction
        observed_tx_queue.push_back(tx);
        check_transaction();
    endfunction

    // Called by reference model to add expected transaction
    virtual function void add_expected(keccak_transaction tx);
        expected_tx_queue.push_back(tx);
        check_transaction();
    endfunction

    virtual function void check_transaction();
        if (expected_tx_queue.size() > 0 && observed_tx_queue.size() > 0) begin
            keccak_transaction exp_tx = expected_tx_queue.pop_front();
            keccak_transaction obs_tx = observed_tx_queue.pop_front();
            
            // Compare observed vs expected
            if (obs_tx.compare(exp_tx)) begin
                passes++;
                `uvm_info(get_type_name(), 
                          $sformatf("PASS: %s", exp_tx.test_name), UVM_LOW)
            end else begin
                failures++;
                `uvm_error(get_type_name(), 
                           $sformatf("FAIL: %s - %s", exp_tx.test_name, obs_tx.fail_reason))
                `uvm_info(get_type_name(), 
                          $sformatf("Expected: %s", bytes_to_hex(exp_tx.exp_bytes)), UVM_HIGH)
                `uvm_info(get_type_name(), 
                          $sformatf("Observed: %s", bytes_to_hex_queue(obs_tx.obs_bytes)), UVM_HIGH)
            end
        end
    endfunction

    virtual function string bytes_to_hex(logic [7:0] bytes[]);
        string s = "";
        for (int i = 0; i < bytes.size(); i++) begin
            s = {s, $sformatf("%02x", bytes[i])};
        end
        return s;
    endfunction

    virtual function string bytes_to_hex_queue(logic [7:0] bytes[$]);
        string s = "";
        foreach (bytes[i]) begin
            s = {s, $sformatf("%02x", bytes[i])};
        end
        return s;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), 
                  $sformatf("Scoreboard Report: PASSES=%0d, FAILURES=%0d", passes, failures), 
                  UVM_LOW)
    endfunction

endclass