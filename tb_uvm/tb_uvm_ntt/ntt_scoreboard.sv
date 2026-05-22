// ============================================================================
// ntt_scoreboard.sv  --  UVM scoreboard for ntt_engine
// ----------------------------------------------------------------------------
// Subscribes to the driver (expected) and the monitor (observed) via two
// analysis FIFOs, pairs them in-order and golden-compares the 256-coefficient
// output polynomial element by element.
// ============================================================================
class ntt_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ntt_scoreboard)

    uvm_tlm_analysis_fifo #(ntt_transaction) exp_fifo;
    uvm_tlm_analysis_fifo #(ntt_transaction) obs_fifo;

    int total_tests;
    int passed_tests;
    int failed_tests;

    function new(string name = "ntt_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_fifo = new("exp_fifo", this);
        obs_fifo = new("obs_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            ntt_transaction exp_tx;
            ntt_transaction obs_tx;
            exp_fifo.get(exp_tx);
            obs_fifo.get(obs_tx);
            compare_tx(exp_tx, obs_tx);
        end
    endtask

    function void compare_tx(ntt_transaction exp_tx, ntt_transaction obs_tx);
        bit pass;
        int first_diff;

        total_tests++;
        pass       = 1'b1;
        first_diff = -1;
        for (int i = 0; i < N; i++) begin
            if (obs_tx.obs_poly[i] !== exp_tx.exp_poly[i]) begin
                pass = 1'b0;
                if (first_diff < 0) first_diff = i;
            end
        end

        if (pass) begin
            passed_tests++;
            `uvm_info(get_type_name(),
                      $sformatf("[PASS] %s", exp_tx.test_name), UVM_LOW)
        end else begin
            failed_tests++;
            `uvm_error(get_type_name(),
                       $sformatf("[FAIL] %s\n        first diff @%0d : golden %0d  dut %0d",
                                 exp_tx.test_name, first_diff,
                                 exp_tx.exp_poly[first_diff],
                                 obs_tx.obs_poly[first_diff]))
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
