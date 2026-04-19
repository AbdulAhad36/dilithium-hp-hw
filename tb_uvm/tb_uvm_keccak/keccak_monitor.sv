// =========================================================================
// Keccak Monitor - Observes DUT outputs and reconstructs hash
// =========================================================================
class keccak_monitor extends uvm_monitor;
    `uvm_component_utils(keccak_monitor)

    virtual keccak_if vif;
    uvm_analysis_port #(keccak_transaction) mon_ap;
    
    localparam int BYTES_PER_BEAT = DWIDTH / 8;

    function new(string name = "keccak_monitor", uvm_component parent = null);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual keccak_if)::get(this, "", "keccak_vif", vif))
            `uvm_fatal("MON", "Failed to get keccak_vif from config DB")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            keccak_transaction tx;
            monitor_transaction(tx);
            mon_ap.write(tx);
        end
    endtask

    virtual task monitor_transaction(ref keccak_transaction tx);
        keccak_transaction collected_tx;
        int bytes_collected = 0;
        int bytes_total_expected;
        int rate_bytes;
        int bytes_squeezed_total = 0;
        bit is_shake;
        int xof_len_val;

        // Wait for start of transaction (monitor when start is asserted)
        @(vif.mon_cb);
        while (!vif.mon_cb.start) @(vif.mon_cb);
        
        // Capture mode and xof_len
        collected_tx = keccak_transaction::type_id::create("collected_tx");
        collected_tx.mode = keccak_mode'(vif.mon_cb.mode);
        collected_tx.xof_len_val = vif.mon_cb.xof_len;
        
        `uvm_info(get_type_name(), $sformatf("Monitoring transaction: mode=%s, xof_len=%0d",
                   collected_tx.mode.name(), collected_tx.xof_len_val), UVM_MEDIUM)

        is_shake = collected_tx.is_shake();
        rate_bytes = collected_tx.get_rate_bytes();
        
        // We need to know expected length from somewhere
        // This will be set via config DB or transaction handle
        bytes_total_expected = 0; // Will be updated by scoreboard

        // Wait for DUT to start outputting data
        vif.drv_cb.m_axis_tready <= 1;
        
        // Collect output bytes
        forever begin
            @(vif.mon_cb);
            
            if (vif.mon_cb.m_axis_tvalid && vif.mon_cb.m_axis_tready) begin
                logic [DWIDTH-1:0] current_word = vif.mon_cb.m_axis_tdata;
                logic [KEEP_WIDTH-1:0] current_keep = vif.mon_cb.m_axis_tkeep;
                
                for (int i = 0; i < BYTES_PER_BEAT; i++) begin
                    if (current_keep[i]) begin
                        bytes_squeezed_total++;
                        collected_tx.obs_bytes.push_back(current_word[i*8 +: 8]);
                        bytes_collected++;
                    end
                end
                
                // Check for last (for bounded modes)
                if (vif.mon_cb.m_axis_tlast) begin
                    break;
                end
            end
        end
        
        vif.drv_cb.m_axis_tready <= 0;
        
        // Set the collected transaction
        tx = collected_tx;
        
        `uvm_info(get_type_name(), $sformatf("Collected %0d bytes", bytes_collected), UVM_MEDIUM)
    endtask

endclass