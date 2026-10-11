// ============================================================================
// ntt_monitor.sv  --  UVM monitor for ntt_engine
// ----------------------------------------------------------------------------
// Controls m_tready at negedge, including requested output stalls.
// Checks stalled output stability. For each transaction it gets the expected
// item from the driver, collects 256 output coefficients at posedge whenever
// m_tvalid && m_tready, then triggers collection_done to release the driver.
// ============================================================================
class ntt_monitor extends uvm_monitor;
    `uvm_component_utils(ntt_monitor)

    virtual ntt_if vif;
    bit netlist_mode;
    uvm_analysis_port #(ntt_transaction)        mon_ap;
    uvm_tlm_analysis_fifo #(ntt_transaction)    exp_fifo;   // expected from driver
    uvm_event collection_done;

    localparam int TIMEOUT_CYCLES = 200_000;

    function new(string name = "ntt_monitor", uvm_component parent = null);
        super.new(name, parent);
        mon_ap   = new("mon_ap", this);
        exp_fifo = new("exp_fifo", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(bit)::get(this, "", "netlist_mode", netlist_mode));
        if (!uvm_config_db#(virtual ntt_if)::get(this, "", "ntt_vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get ntt_vif from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        vif.m_tready = 1'b1;             // per-job stalls are driven below at negedge
        forever begin
            ntt_transaction exp_tx;
            ntt_transaction obs_tx;
            exp_fifo.get(exp_tx);                  // blocks until driver publishes
            begin
                int observed_reset_point;
                bit reset_ok;
                observed_reset_point=-1; reset_ok=0;
                if (exp_tx.reset_point>=0)
                    collect_reset_abort(exp_tx,observed_reset_point,reset_ok);
                collect_output(exp_tx, obs_tx);
                obs_tx.observed_reset_point=observed_reset_point;
                obs_tx.reset_checks_ok=reset_ok;
            end
            mon_ap.write(obs_tx);                  // scoreboard consumes
            collection_done.trigger();             // release the driver
        end
    endtask

    // Observe the targeted reset edge, then settled controls/counts/tag state
    // during reset and for three quiet clocks after deassertion. Aborted work
    // gets no normal trace bins; only the later golden-checked job may credit reset.
    virtual task collect_reset_abort(ntt_transaction exp_tx, output int observed_point,
                             output bit ok);
        int accepted_inputs;
        int wrapper_state, core_state;
        bit stalled_output;
        accepted_inputs=0; observed_point=-1; ok=1;
        vif.m_tready=0;
        wait (vif.rst===1'b1);
        wait (vif.rst===1'b0);
        fork
            begin
                forever begin
                    @(posedge vif.clk);
                    if (!vif.rst && vif.s_tvalid && vif.s_tready) accepted_inputs++;
                end
            end
            begin
                @(posedge vif.rst);
                wrapper_state=vif.wrapper_state; core_state=vif.core_state;
                stalled_output=vif.m_tvalid && !vif.m_tready;
            end
        join_any
        disable fork;
        case (exp_tx.reset_point)
            0: if (wrapper_state==0 && core_state==0 && accepted_inputs==0) observed_point=0;
            1: if (wrapper_state==1 && accepted_inputs==17) observed_point=1;
            2: if (wrapper_state==4 && core_state==2 && accepted_inputs==N) observed_point=2;
            3: if (wrapper_state==6 && stalled_output && accepted_inputs==N) observed_point=3;
            4: if (wrapper_state==3 && accepted_inputs==N) observed_point=4;
            5: if (wrapper_state==2 && accepted_inputs==N+17) observed_point=5;
            6: if (wrapper_state==5 && accepted_inputs==N) observed_point=6;
            7: if (wrapper_state==4 && core_state==1 && accepted_inputs==N) observed_point=7;
            8: if (wrapper_state==4 && core_state==3 && accepted_inputs==N) observed_point=8;
        endcase
        if (observed_point!=exp_tx.reset_point) ok=0;
        repeat (2) begin
            @(posedge vif.clk); #1ps;
            if ({vif.busy,vif.done,vif.m_tvalid,vif.s_tready,
                 vif.core_busy,vif.core_done,vif.pending_tags,
                 vif.fifo_count1,vif.fifo_count2,vif.fifo_count3} !== '0) ok=0;
        end
        wait (vif.rst===1'b0);
        repeat (3) begin
            @(posedge vif.clk); #1ps;
            if ({vif.busy,vif.done,vif.m_tvalid,vif.s_tready,
                 vif.core_busy,vif.core_done,vif.pending_tags,
                 vif.fifo_count1,vif.fifo_count2,vif.fifo_count3} !== '0) ok=0;
        end
        `uvm_info("RESET_OBSERVED", $sformatf("[%s] target=%0d observed=%0d wrapper=%0d core=%0d inputs=%0d clear=%0b",
            exp_tx.test_name,exp_tx.reset_point,observed_point,wrapper_state,core_state,accepted_inputs,ok),UVM_LOW)
    endtask

    task collect_output(input ntt_transaction exp_tx, output ntt_transaction obs_tx);
        int idx;
        int timeout;
        int last_stall_index, stall_remaining;
        bit previous_stall;
        coeff_t held_data;
        bit held_last;

        obs_tx           = ntt_transaction::type_id::create("obs_tx");
        obs_tx.test_name = exp_tx.test_name;
        obs_tx.op        = exp_tx.op;
        obs_tx.in_kind   = exp_tx.in_kind;
        obs_tx.reset_before = exp_tx.reset_before;
        obs_tx.equivalence_pair=exp_tx.equivalence_pair;
        obs_tx.equivalence_second=exp_tx.equivalence_second;
        obs_tx.in_poly   = exp_tx.in_poly;
        obs_tx.exp_poly  = exp_tx.exp_poly;
        obs_tx.observed_count = 0;
        obs_tx.output_framing_ok = 1'b1;
        if (!netlist_mode) obs_tx.trace = ntt_trace::type_id::create("trace");

        idx     = 0;
        timeout = 0;
        last_stall_index=-1; stall_remaining=0; previous_stall=0;
        while (idx < N) begin
            @(negedge vif.clk);
            if (exp_tx.stall_output && (idx==0 || idx==N/2 || idx==N-1 ||
                (exp_tx.output_stall_period>0 && idx%exp_tx.output_stall_period==0)) &&
                idx!=last_stall_index && vif.m_tvalid) begin
                last_stall_index=idx;
                stall_remaining=exp_tx.output_stall_cycles;
            end
            vif.m_tready=(stall_remaining==0);
            if (stall_remaining>0) stall_remaining--;
            @(posedge vif.clk);
            if (!netlist_mode) obs_tx.trace.sample(vif, exp_tx.op);
            if (previous_stall && (vif.m_tvalid!==1'b1 ||
                vif.m_tdata!==held_data || vif.m_tlast!==held_last))
            begin
                obs_tx.output_stability_ok=0;
                if (!netlist_mode) obs_tx.trace.errors++;
            end
            previous_stall=vif.m_tvalid && !vif.m_tready;
            if (previous_stall) begin
                held_data=vif.m_tdata; held_last=vif.m_tlast;
                if (!netlist_mode) obs_tx.trace.output_stalls[(idx==0) ? 0 : ((idx==N-1) ? 2 : 1)]=1;
            end
            timeout++;
            if (timeout > TIMEOUT_CYCLES) begin
                `uvm_error(get_type_name(),
                           $sformatf("[%s] TIMEOUT after %0d cycles (%0d/%0d coeffs)",
                                     exp_tx.test_name, timeout, idx, N))
                break;
            end
            if (vif.m_tvalid && vif.m_tready) begin
                if (vif.m_tlast !== (idx == N-1))
                    obs_tx.output_framing_ok = 1'b0;
                obs_tx.obs_poly[idx] = vif.m_tdata;
                idx++;
            end
        end
        obs_tx.observed_count = idx;

        `uvm_info(get_type_name(),
                  $sformatf("[%s] collected %0d/%0d coefficients",
                            exp_tx.test_name, idx, N), UVM_HIGH)
    endtask

endclass
