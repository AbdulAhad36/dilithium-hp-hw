// =========================================================================
// Keccak Driver - Drives AXI4-Stream data to DUT
// =========================================================================
class keccak_driver extends uvm_driver #(keccak_transaction);
    `uvm_component_utils(keccak_driver)

    virtual keccak_if vif;
    localparam int BYTES_PER_BEAT = DWIDTH / 8;

    function new(string name = "keccak_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual keccak_if)::get(this, "", "keccak_vif", vif))
            `uvm_fatal("DRV", "Failed to get keccak_vif from config DB")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            keccak_transaction tx;
            seq_item_port.get_next_item(tx);
            drive_transaction(tx);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transaction(keccak_transaction tx);
        int total_bytes = tx.msg_bytes.size();
        int sent_bytes = 0;

        `uvm_info(get_type_name(), $sformatf("Driving: %s", tx.convert2string()), UVM_MEDIUM)

        // Setup DUT control signals
        @(vif.drv_cb);
        vif.drv_cb.start <= 1;
        vif.drv_cb.mode <= tx.mode;
        vif.drv_cb.xof_len <= tx.xof_len_val;
        vif.drv_cb.stop <= 0;
        @(vif.drv_cb);
        vif.drv_cb.start <= 0;

        // Handle empty message case
        if (total_bytes == 0) begin
            wait_for_ready();
            vif.drv_cb.s_axis_tvalid <= 1;
            vif.drv_cb.s_axis_tlast <= 1;
            vif.drv_cb.s_axis_tkeep <= '0;
            vif.drv_cb.s_axis_tdata <= '0;
            @(vif.drv_cb);
            vif.drv_cb.s_axis_tvalid <= 0;
            vif.drv_cb.s_axis_tlast <= 0;
            vif.drv_cb.s_axis_tkeep <= 0;
            return;
        end

        // Drive data beats
        while (sent_bytes < total_bytes) begin
            int bytes_to_send = (total_bytes - sent_bytes) > BYTES_PER_BEAT ? 
                                 BYTES_PER_BEAT : (total_bytes - sent_bytes);
            
            wait_for_ready();
            
            vif.drv_cb.s_axis_tvalid <= 1;
            vif.drv_cb.s_axis_tlast <= (bytes_to_send == (total_bytes - sent_bytes)) ? 1 : 0;
            vif.drv_cb.s_axis_tkeep <= '0;
            vif.drv_cb.s_axis_tdata <= '0;
            
            for (int k = 0; k < bytes_to_send; k++) begin
                vif.drv_cb.s_axis_tdata[k*8 +: 8] <= tx.msg_bytes[sent_bytes + k];
                vif.drv_cb.s_axis_tkeep[k] <= 1'b1;
            end
            
            @(vif.drv_cb);
            sent_bytes += bytes_to_send;
        end

        // Drop signals
        @(negedge vif.clk);
        vif.drv_cb.s_axis_tvalid <= 0;
        vif.drv_cb.s_axis_tlast <= 0;
        vif.drv_cb.s_axis_tkeep <= 0;
    endtask

    task automatic wait_for_ready();
        forever begin
            @(negedge vif.clk);
            if (vif.drv_cb.s_axis_tready) break;
        end
    endtask

endclass