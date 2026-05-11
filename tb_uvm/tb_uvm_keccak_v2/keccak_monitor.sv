// =========================================================================
// keccak_monitor.sv  -  TB v2 monitor (direct posedge sampling)
// No clocking blocks. Reads vif.m_axis_* directly. Drives m_axis_tready=1
// during collection. For continuous SHAKE, asserts vif.stop when enough
// bytes collected to terminate output. Verifies tkeep + tlast per beat.
// =========================================================================
class keccak_monitor extends uvm_monitor;
    `uvm_component_utils(keccak_monitor)

    virtual keccak_if vif;
    uvm_analysis_port #(keccak_transaction) mon_ap;
    uvm_tlm_analysis_fifo #(keccak_transaction) exp_fifo;  // gets expected tx from driver
    uvm_event collection_done;

    localparam int BYTES_PER_BEAT = DWIDTH / 8;
    localparam int TIMEOUT_CYCLES = 200_000;

    int signal_errors;

    function new(string name = "keccak_monitor", uvm_component parent = null);
        super.new(name, parent);
        mon_ap   = new("mon_ap", this);
        exp_fifo = new("exp_fifo", this);
        signal_errors = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual keccak_if)::get(this, "", "keccak_vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get keccak_vif from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            keccak_transaction exp_tx;
            keccak_transaction obs_tx;

            exp_fifo.get(exp_tx);                  // blocks until driver pushes
            collect_output(exp_tx, obs_tx);        // does the work; populates obs_tx.obs_bytes
            mon_ap.write(obs_tx);                  // scoreboard consumes
            collection_done.trigger();             // unblock driver
        end
    endtask

    task collect_output(input keccak_transaction exp_tx, output keccak_transaction obs_tx);
        int rate_bytes;
        int bytes_total_expected;
        int bytes_collected_so_far = 0;
        int bytes_squeezed_total = 0;
        int timeout_counter = 0;
        bit is_shake;
        logic [KEEP_WIDTH-1:0] exp_keep;
        logic                  exp_last;
        int                    expected_bytes_this_beat;
        int                    bytes_in_current_rate_block;
        int                    bytes_remaining_in_rate_block;

        // Build observed transaction (mirrors expected)
        obs_tx           = keccak_transaction::type_id::create("obs_tx");
        obs_tx.test_name = exp_tx.test_name;
        obs_tx.mode      = exp_tx.mode;
        obs_tx.xof_len_val      = exp_tx.xof_len_val;
        obs_tx.msg_hex          = exp_tx.msg_hex;
        obs_tx.exp_hex          = exp_tx.exp_hex;
        obs_tx.output_len_bits  = exp_tx.output_len_bits;
        obs_tx.obs_bytes.delete();

        rate_bytes           = exp_tx.get_rate_bytes();
        bytes_total_expected = exp_tx.get_expected_bytes();
        is_shake             = exp_tx.is_shake();

        // Abort transactions: no output expected. Skip collection entirely.
        // Still return a valid (empty) obs_tx so the scoreboard pairing stays
        // in lockstep.
        if (exp_tx.abort_after_cycles > 0) begin
            `uvm_info(get_type_name(),
                      $sformatf("[%s] Monitor: ABORT tx, skipping output collection",
                                exp_tx.test_name),
                      UVM_MEDIUM)
            repeat (10) @(posedge vif.clk);
            return;
        end

        // Set tready BEFORE the DUT can enter SQUEEZE (well in advance since
        // ABSORB + PADDING + 24-cycle PERMUTE takes time).
        vif.m_axis_tready = 1;

        `uvm_info(get_type_name(),
                  $sformatf("[%s] Monitor: waiting for %0d bytes (rate=%0d, mode=%s, xof_len=%0d)",
                            exp_tx.test_name, bytes_total_expected, rate_bytes,
                            exp_tx.mode.name(), exp_tx.xof_len_val),
                  UVM_MEDIUM)

        // Wait + collect
        forever begin
            @(posedge vif.clk);
            timeout_counter++;
            if (timeout_counter > TIMEOUT_CYCLES) begin
                `uvm_error(get_type_name(),
                           $sformatf("[%s] TIMEOUT collecting output after %0d cycles (%0d/%0d bytes)",
                                     exp_tx.test_name, timeout_counter,
                                     bytes_collected_so_far, bytes_total_expected))
                break;
            end

            if (vif.m_axis_tvalid && vif.m_axis_tready) begin
                logic [DWIDTH-1:0]      current_word;
                logic [KEEP_WIDTH-1:0]  current_keep;
                current_word = vif.m_axis_tdata;
                current_keep = vif.m_axis_tkeep;

                // --- Compute expected tkeep / tlast for this beat ---
                bytes_in_current_rate_block   = bytes_squeezed_total % rate_bytes;
                bytes_remaining_in_rate_block = rate_bytes - bytes_in_current_rate_block;

                expected_bytes_this_beat = BYTES_PER_BEAT;
                if (bytes_remaining_in_rate_block < expected_bytes_this_beat)
                    expected_bytes_this_beat = bytes_remaining_in_rate_block;

                if (!is_shake || (is_shake && exp_tx.xof_len_val > 0)) begin
                    int bytes_remaining_total = bytes_total_expected - bytes_collected_so_far;
                    if (bytes_remaining_total < expected_bytes_this_beat)
                        expected_bytes_this_beat = bytes_remaining_total;
                end

                exp_keep = '0;
                for (int b = 0; b < expected_bytes_this_beat; b++) exp_keep[b] = 1'b1;

                if (current_keep !== exp_keep) begin
                    `uvm_error(get_type_name(),
                               $sformatf("[%s] tkeep mismatch at DUT byte %0d: got %b expected %b",
                                         exp_tx.test_name, bytes_squeezed_total,
                                         current_keep, exp_keep))
                    signal_errors++;
                end

                // tlast verification
                if (!is_shake || (is_shake && exp_tx.xof_len_val > 0)) begin
                    int bytes_rem = bytes_total_expected - bytes_collected_so_far;
                    int b2 = BYTES_PER_BEAT;
                    if (bytes_remaining_in_rate_block < b2) b2 = bytes_remaining_in_rate_block;
                    exp_last = (bytes_rem <= b2) ? 1'b1 : 1'b0;
                    if (vif.m_axis_tlast !== exp_last) begin
                        `uvm_error(get_type_name(),
                                   $sformatf("[%s] tlast mismatch at byte %0d: got %0b expected %0b",
                                             exp_tx.test_name, bytes_squeezed_total,
                                             vif.m_axis_tlast, exp_last))
                        signal_errors++;
                    end
                end else begin
                    // SHAKE continuous: tlast should be 0
                    if (vif.m_axis_tlast !== 1'b0) begin
                        `uvm_error(get_type_name(),
                                   $sformatf("[%s] SHAKE continuous tlast should be 0 at byte %0d",
                                             exp_tx.test_name, bytes_squeezed_total))
                        signal_errors++;
                    end
                end

                // --- Data collection ---
                for (int i = 0; i < BYTES_PER_BEAT; i++) begin
                    if (current_keep[i]) begin
                        bytes_squeezed_total++;
                        if (obs_tx.obs_bytes.size() < bytes_total_expected) begin
                            obs_tx.obs_bytes.push_back(current_word[i*8 +: 8]);
                            bytes_collected_so_far++;
                        end
                    end
                end

                // --- Termination ---
                if (obs_tx.obs_bytes.size() >= bytes_total_expected) begin
                    if (is_shake && exp_tx.xof_len_val == 0) begin
                        // Pulse stop_i to terminate continuous XOF
                        vif.stop = 1;
                        @(posedge vif.clk);
                        vif.stop = 0;
                    end
                    break;
                end
            end
        end

        // Drop tready after collection
        vif.m_axis_tready = 0;

        `uvm_info(get_type_name(),
                  $sformatf("[%s] Monitor: collected %0d/%0d bytes",
                            exp_tx.test_name, obs_tx.obs_bytes.size(), bytes_total_expected),
                  UVM_MEDIUM)
    endtask

endclass
