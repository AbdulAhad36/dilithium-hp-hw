// ============================================================================
// ntt_driver.sv  --  UVM driver for ntt_engine  (negedge-handshake pattern)
// ----------------------------------------------------------------------------
// Per transaction:
//   1. per-tx async reset (FSM -> E_IDLE)
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

    task drive_transaction(ntt_transaction req);
        // 1. per-transaction reset
        vif.rst      = 1'b1;
        vif.start    = 1'b0;
        vif.s_tvalid = 1'b0;
        vif.s_tlast  = 1'b0;
        vif.s_tdata  = '0;
        repeat (3) @(negedge vif.clk);
        vif.rst = 1'b0;
        @(negedge vif.clk);

        // 2. issue the request (start is only sampled in E_IDLE)
        while (vif.busy) @(negedge vif.clk);
        vif.op    = req.op;
        vif.start = 1'b1;
        @(negedge vif.clk);
        vif.start = 1'b0;

        // 3. stream 256 coefficients into the sink
        while (!vif.s_tready) @(negedge vif.clk);
        for (int i = 0; i < N; i++) begin
            vif.s_tvalid = 1'b1;
            vif.s_tdata  = req.in_poly[i];
            vif.s_tlast  = (i == N-1);
            @(negedge vif.clk);
        end
        vif.s_tvalid = 1'b0;
        vif.s_tlast  = 1'b0;
        vif.s_tdata  = '0;
    endtask

endclass
