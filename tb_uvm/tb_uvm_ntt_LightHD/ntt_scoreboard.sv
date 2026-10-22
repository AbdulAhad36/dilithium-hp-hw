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

    bit netlist_mode; // default0 retains strict source internal-trace checks
    int checked_coefficients;
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
        void'(uvm_config_db#(bit)::get(this, "", "netlist_mode", netlist_mode));
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

    // Independently derive the expected run counts from the requested profile.
    // This gate checks the observation counters before they can credit new bins.
    function bit flow_profile_ok(ntt_transaction request,ntt_trace observed);
        int gaps[3][6],stalls[3][6];
        int expected_gap,expected_stall,region;
        foreach(gaps[r,c]) gaps[r][c]=0;
        foreach(stalls[r,c]) stalls[r][c]=0;
        expected_gap=0;expected_stall=0;
        if(request.input_gap_period>0 && request.input_gap_cycles>0) begin
            expected_gap=request.input_gap_cycles;
            for(int operand=0;operand<((request.op==OP_PWM)?2:1);operand++)
                for(int i=0;i<N-1;i++) if(i%request.input_gap_period==0) begin
                    region=(i+1<16)?0:((i+1>=240)?2:1);
                    gaps[region][ntt_trace::duration_class(request.input_gap_cycles)]++;
                end
        end
        if(request.op==OP_PWM && request.input_gap_period>0 && request.pwm_boundary_gap_cycles>0) begin
            gaps[0][ntt_trace::duration_class(request.pwm_boundary_gap_cycles)]++;
            if(request.pwm_boundary_gap_cycles>expected_gap)expected_gap=request.pwm_boundary_gap_cycles;
        end
        if(request.stall_output && request.output_stall_cycles>0) begin
            expected_stall=request.output_stall_cycles;
            for(int i=0;i<N;i++)
                if(i==0 || i==N/2 || i==N-1 ||
                   (request.output_stall_period>0 && i%request.output_stall_period==0)) begin
                    region=(i==0)?0:((i==N-1)?2:1);
                    stalls[region][ntt_trace::duration_class(request.output_stall_cycles)]++;
                end
        end
        if(observed.max_gap!=expected_gap || observed.max_stall!=expected_stall ||
            observed.gap_run!=0 || observed.stall_run!=0) return 0;
        foreach(gaps[r,c]) if(observed.gap_lengths[r][c]!=gaps[r][c] ||
                              observed.stall_lengths[r][c]!=stalls[r][c]) return 0;
        return 1;
    endfunction

    function void compare_tx(ntt_transaction exp_tx, ntt_transaction obs_tx);
        bit pass;
        int first_diff;
        bit trace_ok;

        last_observed=obs_tx;
        total_tests++;
        pass       = 1'b1;
        first_diff = -1;
        trace_ok = netlist_mode;
        if (!netlist_mode && obs_tx.trace != null)
            trace_ok = obs_tx.trace.valid_job(exp_tx.op);
        if (!trace_ok) pass = 0;
        if (!netlist_mode && trace_ok && !flow_profile_ok(exp_tx,obs_tx.trace)) pass=0;
        if (exp_tx.reset_point>=0 && (!obs_tx.reset_checks_ok ||
            obs_tx.observed_reset_point!=exp_tx.reset_point)) pass=0;
        if (obs_tx.observed_count != N || !obs_tx.output_framing_ok ||
            !obs_tx.output_stability_ok)
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
        if (!netlist_mode && trace_ok && exp_tx.test_name=="ARITH GS sum/carry boundaries")
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
            checked_coefficients += N;
            if (!netlist_mode && exp_tx.test_name=="REDUCE product/carry boundaries")
                `uvm_info("CHECKED_REDUCTION_BOUNDARIES",
                    $sformatf("all four PWM lanes: outputs at 0/4/8/12/16 = %0d/%0d/%0d/%0d/%0d; independent golden and every physical write/output passed",
                        obs_tx.obs_poly[0],obs_tx.obs_poly[4],obs_tx.obs_poly[8],obs_tx.obs_poly[12],obs_tx.obs_poly[16]),UVM_NONE)
            if (!netlist_mode && exp_tx.test_name=="ARITH GS sum/carry boundaries")
                `uvm_info("CHECKED_GS_SUM_BOUNDARIES",
                    $sformatf("actual GS input masks by lane=%05b/%05b/%05b/%05b; sums 0/below_q/exact_q/above_q/2q-2; independent operands, every physical write and all 256 outputs passed",
                        obs_tx.trace.routing.gs_sum_classes[0],obs_tx.trace.routing.gs_sum_classes[1],
                        obs_tx.trace.routing.gs_sum_classes[2],obs_tx.trace.routing.gs_sum_classes[3]),UVM_NONE)
            // Publish the observed per-job trace only after BOTH independent
            // output comparison and the schedule/protocol checks pass.
            if (!netlist_mode) checked_ap.write(obs_tx);
            else `uvm_info("NETLIST_EXTERNAL_CHECKED",
                $sformatf("[%s] 256 coefficients, framing, stability and requested reset checks passed; no internal coverage credited", exp_tx.test_name),UVM_LOW)
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
