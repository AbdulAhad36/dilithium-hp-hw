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
    uvm_analysis_port #(ntt_transaction) checked_ap;

    int total_tests;
    int passed_tests;
    int failed_tests;
    int equivalence_passed;
    int pending_pair=-1;
    poly_t pending_output;
    ntt_transaction last_observed;
    ntt_transaction last_pass; // checked observed item, also used by the UVM gate self-test

    function new(string name = "ntt_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        checked_ap = new("checked_ap", this);
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
        bit trace_ok;

        last_observed=obs_tx;
        total_tests++;
        pass       = 1'b1;
        first_diff = -1;
        trace_ok = (obs_tx.trace != null);
        if (trace_ok) trace_ok = obs_tx.trace.valid_job(exp_tx.op);
        if (!trace_ok) pass = 0;
        if (exp_tx.reset_point>=0 && (!obs_tx.reset_checks_ok ||
            obs_tx.observed_reset_point!=exp_tx.reset_point)) pass=0;
        if (obs_tx.observed_count != N || !obs_tx.output_framing_ok)
            pass = 1'b0;
        for (int i = 0; i < N; i++) begin
            if (obs_tx.obs_poly[i] !== exp_tx.exp_poly[i]) begin
                pass = 1'b0;
                if (first_diff < 0) first_diff = i;
            end
        end

        if (exp_tx.equivalence_pair>=0 && exp_tx.equivalence_second) begin
            if (pending_pair!=exp_tx.equivalence_pair) pass=0;
            for (int i=0; i<N; i++)
                if (obs_tx.obs_poly[i] !== pending_output[i]) pass=0;
        end
        if (trace_ok && exp_tx.test_name=="ARITH GS sum/carry boundaries")
            for (int lane=0;lane<4;lane++)
                if (obs_tx.trace.routing.gs_sum_classes[lane] != 5'b11111) pass=0;
        if (pass) begin
            if (exp_tx.equivalence_pair>=0) begin
                if (exp_tx.equivalence_second) begin
                    equivalence_passed++; pending_pair=-1;
                    `uvm_info("PRE_EQUIVALENCE", $sformatf("pair=%0d observed Pre/general outputs match all 256 coefficients",exp_tx.equivalence_pair),UVM_LOW)
                end else begin
                    pending_pair=exp_tx.equivalence_pair;
                    pending_output=obs_tx.obs_poly;
                end
            end
            passed_tests++;
            if (exp_tx.test_name=="REDUCE product/carry boundaries")
                `uvm_info("CHECKED_REDUCTION_BOUNDARIES",
                    $sformatf("all four PWM lanes: outputs at 0/4/8/12/16 = %0d/%0d/%0d/%0d/%0d; independent golden and every physical write/output passed",
                        obs_tx.obs_poly[0],obs_tx.obs_poly[4],obs_tx.obs_poly[8],obs_tx.obs_poly[12],obs_tx.obs_poly[16]),UVM_NONE)
            if (exp_tx.test_name=="ARITH GS sum/carry boundaries")
                `uvm_info("CHECKED_GS_SUM_BOUNDARIES",
                    $sformatf("actual GS input masks by lane=%05b/%05b/%05b/%05b; sums 0/below_q/exact_q/above_q/2q-2; independent operands, every physical write and all 256 outputs passed",
                        obs_tx.trace.routing.gs_sum_classes[0],obs_tx.trace.routing.gs_sum_classes[1],
                        obs_tx.trace.routing.gs_sum_classes[2],obs_tx.trace.routing.gs_sum_classes[3]),UVM_NONE)
            // Publish the observed per-job trace only after BOTH independent
            // output comparison and the schedule/protocol checks pass.
            checked_ap.write(obs_tx);
            last_pass=obs_tx;
            `uvm_info(get_type_name(),
                      $sformatf("[PASS] %s", exp_tx.test_name), UVM_LOW)
        end else begin
            failed_tests++;
            `uvm_error(get_type_name(),
                       $sformatf("[FAIL] %s: observed %0d/%0d beats, framing_ok=%0b, first_diff=%0d trace_ok=%0b trace_errors=%0d routing_errors=%0d reset_ok=%0b reset_point=%0d",
                                 exp_tx.test_name, obs_tx.observed_count, N,
                                 obs_tx.output_framing_ok, first_diff, trace_ok,
                                 (obs_tx.trace==null) ? -1 : obs_tx.trace.errors,
                                 (obs_tx.trace==null) ? -1 : obs_tx.trace.routing.errors,
                                 obs_tx.reset_checks_ok,obs_tx.observed_reset_point))
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
