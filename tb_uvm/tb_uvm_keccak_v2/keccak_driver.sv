// =========================================================================
// keccak_driver.sv  -  TB v2 driver (negedge handshake pattern)
// Mirrors the working non-UVM driver: drives s_axis on negedge, polls
// for s_axis_tready on negedge before each beat. Drives reset + start
// pulse per transaction. Does NOT touch m_axis_tready or stop (monitor's job).
// =========================================================================
class keccak_driver extends uvm_driver #(keccak_transaction);
    `uvm_component_utils(keccak_driver)

    virtual keccak_if vif;
    uvm_analysis_port #(keccak_transaction) drv_ap;   // pushed BEFORE driving stimulus

    // Handshake event with monitor: monitor.trigger() when collection finishes.
    uvm_event collection_done;

    localparam int BYTES_PER_BEAT = DWIDTH / 8;

    function new(string name = "keccak_driver", uvm_component parent = null);
        super.new(name, parent);
        drv_ap = new("drv_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual keccak_if)::get(this, "", "keccak_vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get keccak_vif from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        // Initialize all driver-owned signals so they start at known 0.
        init_signals();

        forever begin
            keccak_transaction req;
            seq_item_port.get_next_item(req);

            // Publish expected transaction BEFORE driving — scoreboard/monitor
            // are gated on this so they can prepare.
            drv_ap.write(req);

            // Drive: reset + start + msg
            drive_transaction(req);

            // Wait until monitor has finished collecting output for THIS tx.
            // wait_ptrigger handles the race where monitor triggers before
            // driver gets here (e.g., very fast abort transactions).
            collection_done.wait_ptrigger();
            collection_done.reset();

            seq_item_port.item_done();
        end
    endtask

    task init_signals();
        vif.rst              = 1;
        vif.start            = 0;
        vif.stop             = 0;
        vif.mode             = SHAKE128;
        vif.xof_len          = 0;
        vif.s_axis_tdata     = '0;
        vif.s_axis_tvalid    = 0;
        vif.s_axis_tlast     = 0;
        vif.s_axis_tkeep     = '0;
        vif.m_axis_tready    = 0;
        @(posedge vif.clk);
    endtask

    task drive_transaction(keccak_transaction req);
        // 1. Per-transaction reset (puts FSM back to IDLE cleanly)
        reset_dut();

        // 2. Apply start pulse with mode + xof_len
        @(posedge vif.clk);
        vif.start         <= 1;
        vif.mode          <= req.mode;
        vif.xof_len       <= req.xof_len_val;
        @(posedge vif.clk);
        vif.start         <= 0;

        // 3a. Abort path: drive a few partial beats (no tlast) so DUT enters
        // ABSORB; then assert async reset to trigger ABSORB->IDLE.
        // For PERMUTE-state coverage, drive a complete short message with
        // tlast first (DUT then transitions ABSORB->SUFFIX_PADDING->PERMUTE)
        // and assert reset abort_after_cycles into PERMUTE.
        if (req.abort_after_cycles > 0) begin
            drive_abort(req);
            return;
        end

        // 3b. Normal path: drive message bytes onto s_axis
        drive_msg(req.msg_hex);
    endtask

    // Abort task: drives partial bytes then asserts reset. Does NOT use
    // fork — keeps semantics simple and avoids stuck wait-for-tready loops.
    // For req.abort_after_cycles == 1..n we drive partial beats and reset
    // while in ABSORB. For n >= 100 we drive a complete short message (tlast)
    // and then sit in PERMUTE before issuing reset.
    task drive_abort(keccak_transaction req);
        if (req.abort_after_cycles >= 100) begin
            // PERMUTE-state abort: drive a complete short message
            drive_msg(req.msg_hex);
            // DUT is now in SUFFIX_PADDING (1 cyc) -> PERMUTE (24 cyc)
            repeat (req.abort_after_cycles - 100) @(posedge vif.clk);
        end else begin
            // ABSORB-state abort: drive a few partial beats then reset
            logic [7:0] msg_bytes[];
            int total;
            int sent = 0;
            int k;
            str_to_byte_array(req.msg_hex, msg_bytes);
            total = msg_bytes.size();

            @(posedge vif.clk);
            for (int beat = 0; beat < req.abort_after_cycles && sent < total; beat++) begin
                int n = (total - sent > BYTES_PER_BEAT) ? BYTES_PER_BEAT : (total - sent);

                // Wait for tready (with internal timeout to avoid hang)
                begin : wait_ready
                    int timeout = 0;
                    forever begin
                        @(negedge vif.clk);
                        if (vif.s_axis_tready) break;
                        timeout++;
                        if (timeout > 500) disable wait_ready;
                    end
                end

                vif.s_axis_tvalid <= 1;
                vif.s_axis_tlast  <= 0;   // NEVER assert tlast in abort
                vif.s_axis_tkeep  <= '0;
                vif.s_axis_tdata  <= '0;
                for (k = 0; k < n; k++) begin
                    vif.s_axis_tdata[k*8 +: 8] <= msg_bytes[sent + k];
                    vif.s_axis_tkeep[k]        <= 1'b1;
                end
                @(posedge vif.clk);
                sent += n;
            end
            @(negedge vif.clk);
            vif.s_axis_tvalid <= 0;
            vif.s_axis_tlast  <= 0;
            vif.s_axis_tkeep  <= '0;
        end

        // Issue the reset pulse (covers <active state> -> IDLE)
        @(posedge vif.clk);
        vif.rst <= 1;
        @(posedge vif.clk);
        @(posedge vif.clk);
        vif.rst <= 0;
        @(posedge vif.clk);
    endtask

    task reset_dut();
        vif.rst              <= 1;
        vif.start            <= 0;
        vif.stop             <= 0;
        vif.xof_len          <= 0;
        vif.s_axis_tvalid    <= 0;
        vif.s_axis_tlast     <= 0;
        vif.s_axis_tkeep     <= '0;
        vif.s_axis_tdata     <= '0;
        repeat (3) @(posedge vif.clk);
        vif.rst              <= 0;
        @(posedge vif.clk);
    endtask

    task drive_msg(string msg_hex);
        logic [7:0] msg_bytes[];
        int total_bytes;
        int sent_bytes;
        int k;

        str_to_byte_array(msg_hex, msg_bytes);
        total_bytes = msg_bytes.size();
        sent_bytes  = 0;

        // Sync to clock before driving
        @(posedge vif.clk);

        // Empty message: single beat with tlast=1, tkeep=0, tdata=0
        if (total_bytes == 0) begin
            forever begin
                @(negedge vif.clk);
                if (vif.s_axis_tready) break;
            end
            vif.s_axis_tvalid <= 1;
            vif.s_axis_tlast  <= 1;
            vif.s_axis_tkeep  <= '0;
            vif.s_axis_tdata  <= '0;

            @(posedge vif.clk);

            @(negedge vif.clk);
            vif.s_axis_tvalid <= 0;
            vif.s_axis_tlast  <= 0;
            vif.s_axis_tkeep  <= '0;
            return;
        end

        // Multi-byte loop
        while (sent_bytes < total_bytes) begin
            int bytes_to_send;
            int bytes_remaining = total_bytes - sent_bytes;
            bytes_to_send = (bytes_remaining > BYTES_PER_BEAT) ? BYTES_PER_BEAT : bytes_remaining;

            forever begin
                @(negedge vif.clk);
                if (vif.s_axis_tready) break;
            end

            vif.s_axis_tvalid <= 1;
            vif.s_axis_tlast  <= (bytes_remaining <= BYTES_PER_BEAT) ? 1'b1 : 1'b0;
            vif.s_axis_tkeep  <= '0;
            vif.s_axis_tdata  <= '0;

            for (k = 0; k < bytes_to_send; k++) begin
                vif.s_axis_tdata[k*8 +: 8] <= msg_bytes[sent_bytes + k];
                vif.s_axis_tkeep[k]        <= 1'b1;
            end

            @(posedge vif.clk);
            sent_bytes += bytes_to_send;
        end

        // Drop all sink signals
        @(negedge vif.clk);
        vif.s_axis_tvalid <= 0;
        vif.s_axis_tlast  <= 0;
        vif.s_axis_tkeep  <= '0;
        vif.s_axis_tdata  <= '0;
    endtask

    // ---- Helpers ----
    function automatic logic [3:0] hex_char_to_val(byte c);
        if (c >= "0" && c <= "9") return c - "0";
        if (c >= "a" && c <= "f") return c - "a" + 10;
        if (c >= "A" && c <= "F") return c - "A" + 10;
        return 0;
    endfunction

    function automatic void str_to_byte_array(input string s, output logic [7:0] b_arr[]);
        int len = s.len();
        int byte_len = len / 2;
        b_arr = new[byte_len];
        for (int i = 0; i < byte_len; i++) begin
            b_arr[i] = {hex_char_to_val(s[i*2]), hex_char_to_val(s[i*2+1])};
        end
    endfunction

endclass
