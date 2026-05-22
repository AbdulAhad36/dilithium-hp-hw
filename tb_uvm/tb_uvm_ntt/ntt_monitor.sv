// ============================================================================
// ntt_monitor.sv  --  UVM monitor for ntt_engine
// ----------------------------------------------------------------------------
// No clocking blocks. Holds m_tready=1 for the whole test (the engine only
// consumes a beat in E_TX_VALID, so a permanently-high ready is correct and
// avoids stranding the final beat). For each transaction it gets the expected
// item from the driver, collects 256 output coefficients at posedge whenever
// m_tvalid && m_tready, then triggers collection_done to release the driver.
// ============================================================================
class ntt_monitor extends uvm_monitor;
    `uvm_component_utils(ntt_monitor)

    virtual ntt_if vif;
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
        if (!uvm_config_db#(virtual ntt_if)::get(this, "", "ntt_vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get ntt_vif from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        vif.m_tready = 1'b1;             // always ready to accept source beats
        forever begin
            ntt_transaction exp_tx;
            ntt_transaction obs_tx;
            exp_fifo.get(exp_tx);                  // blocks until driver publishes
            collect_output(exp_tx, obs_tx);
            mon_ap.write(obs_tx);                  // scoreboard consumes
            collection_done.trigger();             // release the driver
        end
    endtask

    task collect_output(input ntt_transaction exp_tx, output ntt_transaction obs_tx);
        int idx;
        int timeout;

        obs_tx           = ntt_transaction::type_id::create("obs_tx");
        obs_tx.test_name = exp_tx.test_name;
        obs_tx.op        = exp_tx.op;
        obs_tx.in_kind   = exp_tx.in_kind;
        obs_tx.in_poly   = exp_tx.in_poly;
        obs_tx.exp_poly  = exp_tx.exp_poly;

        idx     = 0;
        timeout = 0;
        while (idx < N) begin
            @(posedge vif.clk);
            timeout++;
            if (timeout > TIMEOUT_CYCLES) begin
                `uvm_error(get_type_name(),
                           $sformatf("[%s] TIMEOUT after %0d cycles (%0d/%0d coeffs)",
                                     exp_tx.test_name, timeout, idx, N))
                break;
            end
            if (vif.m_tvalid && vif.m_tready) begin
                obs_tx.obs_poly[idx] = vif.m_tdata;
                idx++;
            end
        end

        `uvm_info(get_type_name(),
                  $sformatf("[%s] collected %0d/%0d coefficients",
                            exp_tx.test_name, idx, N), UVM_HIGH)
    endtask

endclass
