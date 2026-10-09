// ============================================================================
// ntt_driver.sv  --  UVM driver for ntt_engine  (negedge-handshake pattern)
// ----------------------------------------------------------------------------
// Per transaction:
//   1. reset by default, or retain state for a repeated-job item
//   2. pulse start with the requested op
//   3. stream 256 input coefficients over the AXI sink while s_tready is high
//   4. wait for the monitor to finish collecting (collection_done event)
//
// The expected transaction is published on drv_ap BEFORE stimulus is driven so
// the monitor / scoreboard / coverage can pair it in lockstep. The driver does
// NOT touch m_tready -- that is the monitor's signal.
// ============================================================================
class ntt_driver extends uvm_driver #(ntt_transaction);
    `uvm_component_utils(ntt_driver)

    virtual ntt_if vif;
    uvm_analysis_port #(ntt_transaction) drv_ap;
    uvm_event collection_done;

    function new(string name = "ntt_driver", uvm_component parent = null);
        super.new(name, parent);
        drv_ap = new("drv_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ntt_if)::get(this, "", "ntt_vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get ntt_vif from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        init_signals();
        forever begin
            ntt_transaction req;
            seq_item_port.get_next_item(req);
            drv_ap.write(req);                 // publish expected tx first
            if (req.reset_point>=0) drive_reset_abort(req);
            drive_transaction(req);
            collection_done.wait_ptrigger();   // monitor done collecting
            collection_done.reset();
            seq_item_port.item_done();
        end
    endtask

    task init_signals();
        vif.rst      = 1'b1;
        vif.start    = 1'b0;
        vif.op       = OP_NTT;
        vif.s_tdata  = '0;
        vif.s_tvalid = 1'b0;
        vif.s_tlast  = 1'b0;
        @(negedge vif.clk);
    endtask

    // Abort an earlier job, then leave reset low for the ordinary recovery job.
    // State constants mirror the documented DUT enums, observed via the interface.
    task wait_abort_state(int wrapper_state=-1, int core_state=-1);
        int clocks=0;
        while ((wrapper_state>=0 && vif.wrapper_state!=wrapper_state) ||
               (core_state>=0 && vif.core_state!=core_state)) begin
            @(negedge vif.clk);
            if (++clocks>2000) `uvm_fatal("RESET_TARGET", "Reset target state not reached")
        end
    endtask

    task drive_reset_abort(ntt_transaction req);
        @(negedge vif.clk);
        vif.start=0; vif.s_tvalid=0; vif.s_tlast=0; vif.rst=1;
        repeat (3) @(negedge vif.clk);
        vif.rst=0;
        @(negedge vif.clk);
        if (req.reset_point!=0) begin
            vif.op=(req.reset_point==5) ? OP_PWM :
                   ((req.reset_point==7) ? OP_PRE_NTT : OP_NTT);
            vif.start=1;
            @(negedge vif.clk); vif.start=0;
            while (!vif.s_tready) @(negedge vif.clk);
            for (int i=0; i<((req.reset_point==1) ? 17 : N); i++) begin
                vif.s_tvalid=1; vif.s_tlast=(i==N-1);
                vif.s_tdata=(req.reset_point==7) ? coeff_t'((i%9)-4+Q)%Q : req.abort_poly[i];
                @(negedge vif.clk);
            end
            vif.s_tvalid=0; vif.s_tlast=0;
            case (req.reset_point)
                2: begin wait_abort_state(-1,2); repeat (16) @(negedge vif.clk); end
                3: begin wait_abort_state(6); repeat (3) @(negedge vif.clk); end
                4: wait_abort_state(3);
                5: begin
                    wait_abort_state(2);
                    for (int i=0; i<17; i++) begin
                        vif.s_tvalid=1; vif.s_tdata=req.abort_poly[N-1-i];
                        @(negedge vif.clk);
                    end
                    vif.s_tvalid=0;
                end
                6: wait_abort_state(5);
                7: wait_abort_state(-1,1);
                8: wait_abort_state(-1,3);
                default: ;
            endcase
        end
        vif.rst=1; vif.start=0; vif.s_tvalid=0; vif.s_tlast=0;
        repeat (2) @(negedge vif.clk);
        vif.rst=0;
        repeat (4) @(negedge vif.clk);
    endtask

    task drive_transaction(ntt_transaction req);
        @(negedge vif.clk);
        // 1. Reset by default; selected repeated jobs retain DUT state.
        vif.start    = 1'b0;
        vif.s_tvalid = 1'b0;
        vif.s_tlast  = 1'b0;
        vif.s_tdata  = '0;
        if (req.reset_before) begin
            vif.rst = 1'b1;
            repeat (3) @(negedge vif.clk);
            vif.rst = 1'b0;
            @(negedge vif.clk);
        end

        // 2. issue the request (start is only sampled in E_IDLE)
        while (vif.busy) @(negedge vif.clk);
        vif.op    = req.op;
        vif.start = 1'b1;
        @(negedge vif.clk);
        vif.start = 1'b0;

        // 3. stream 256 coefficients of operand A
        while (!vif.s_tready) @(negedge vif.clk);
        for (int i = 0; i < N; i++) begin
            vif.s_tvalid = 1'b1;
            vif.s_tdata  = req.in_poly[i];
            vif.s_tlast  = (i == N-1);
            @(negedge vif.clk);
            if (req.input_gap_period>0 && i!=N-1 && i%req.input_gap_period==0) begin
                vif.s_tvalid=0; vif.s_tlast=0;
                repeat (2) @(negedge vif.clk);
            end
        end
        vif.s_tvalid = 1'b0;
        vif.s_tlast  = 1'b0;

        // 4. PWM only: stream 256 coefficients of operand B
        if (req.op == OP_PWM) begin
            if (req.input_gap_period>0) repeat (3) @(negedge vif.clk);
            while (!vif.s_tready) @(negedge vif.clk);
            for (int i = 0; i < N; i++) begin
                vif.s_tvalid = 1'b1;
                vif.s_tdata  = req.in_poly_b[i];
                vif.s_tlast  = (i == N-1);
                @(negedge vif.clk);
                if (req.input_gap_period>0 && i!=N-1 && i%req.input_gap_period==0) begin
                    vif.s_tvalid=0; vif.s_tlast=0;
                    repeat (2) @(negedge vif.clk);
                end
            end
            vif.s_tvalid = 1'b0;
            vif.s_tlast  = 1'b0;
        end
        vif.s_tdata  = '0;
    endtask

endclass
