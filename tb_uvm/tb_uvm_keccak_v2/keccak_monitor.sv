// =========================================================================
// keccak_monitor.sv  -  TB v2 monitor (direct posedge sampling)
// Reconstructs control, accepted input, and accepted output from the interface.
// Drives m_axis_tready=1 during collection. For continuous SHAKE, asserts stop
// when enough bytes have been observed. Records protocol failures on the item.
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
            collect_transaction(exp_tx, obs_tx);
            mon_ap.write(obs_tx);                  // scoreboard consumes
            collection_done.trigger();             // unblock driver
        end
    endtask

    task collect_transaction(input keccak_transaction exp_tx,
                             output keccak_transaction obs_tx);
        obs_tx                 = keccak_transaction::type_id::create("obs_tx");
        obs_tx.test_name       = exp_tx.test_name;
        obs_tx.exp_hex         = exp_tx.exp_hex;
        obs_tx.output_len_bits = exp_tx.output_len_bits;
        obs_tx.obs_msg_hex     = "";
        obs_tx.obs_bytes.delete();

        // Ready is asserted before start so output cannot be missed while the
        // monitor is reconstructing the input side of the transaction.
        vif.m_axis_tready = 1;

        observe_start(exp_tx, obs_tx);
        if (obs_tx.start_seen)
            observe_input(exp_tx, obs_tx);

        if (exp_tx.abort_after_cycles > 0) begin
            observe_abort_reset(exp_tx, obs_tx);
            obs_tx.protocol_ok = obs_tx.start_seen &&
                                 obs_tx.reset_observed &&
                                 (obs_tx.protocol_errors == 0);
            vif.m_axis_tready = 0;
            return;
        end

        if (obs_tx.input_complete)
            collect_output(exp_tx, obs_tx);

        obs_tx.protocol_ok = obs_tx.start_seen &&
                             obs_tx.input_complete &&
                             (obs_tx.protocol_errors == 0);
        vif.m_axis_tready = 0;
    endtask

    task observe_start(input keccak_transaction exp_tx,
                       input keccak_transaction obs_tx);
        int timeout_counter = 0;

        forever begin
            @(posedge vif.clk);
            timeout_counter++;

            if (vif.start === 1'b1) begin
                obs_tx.start_seen  = 1;
                obs_tx.mode        = vif.mode;
                obs_tx.xof_len_val = vif.xof_len;
                return;
            end

            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("start was not observed within %0d cycles", TIMEOUT_CYCLES));
                return;
            end
        end
    endtask

    task observe_input(input keccak_transaction exp_tx,
                       input keccak_transaction obs_tx);
        int timeout_counter = 0;
        bit first_beat_seen = 0;

        forever begin
            logic [DWIDTH-1:0] current_word;
            logic [KEEP_WIDTH-1:0] current_keep;
            int beat_bytes;

            @(posedge vif.clk);
            timeout_counter++;

            if (vif.rst === 1'b1) begin
                obs_tx.reset_observed = 1;
                if (exp_tx.abort_after_cycles == 0)
                    record_protocol_error(obs_tx, "reset asserted before input completed");
                return;
            end

            if (first_beat_seen && !obs_tx.input_complete &&
                (vif.s_axis_tready === 1'b1) &&
                (vif.s_axis_tvalid === 1'b0))
                obs_tx.input_gap_cycles++;

            if ((vif.s_axis_tvalid === 1'b1) &&
                (vif.s_axis_tready === 1'b1)) begin
                first_beat_seen = 1;
                current_word = vif.s_axis_tdata;
                current_keep = vif.s_axis_tkeep;
                beat_bytes = 0;
                obs_tx.accepted_input_beats++;

                if (vif.s_axis_tlast === 1'b0) begin
                    if (current_keep !== {KEEP_WIDTH{1'b1}})
                        record_protocol_error(obs_tx,
                            $sformatf("non-final input beat used tkeep=%b", current_keep));
                end else if (vif.s_axis_tlast === 1'b1) begin
                    if (!keep_is_low_contiguous(current_keep))
                        record_protocol_error(obs_tx,
                            $sformatf("final input beat used non-contiguous tkeep=%b", current_keep));
                end else begin
                    record_protocol_error(obs_tx, "input tlast contained X/Z");
                end

                for (int i = 0; i < BYTES_PER_BEAT; i++) begin
                    if (current_keep[i] === 1'b1) begin
                        obs_tx.obs_msg_hex = {
                            obs_tx.obs_msg_hex,
                            $sformatf("%02x", current_word[i*8 +: 8])
                        };
                        beat_bytes++;
                        obs_tx.accepted_input_bytes++;
                    end else if (current_keep[i] !== 1'b0) begin
                        record_protocol_error(obs_tx,
                            $sformatf("input tkeep[%0d] contained X/Z", i));
                    end
                end

                if (vif.s_axis_tlast === 1'b1) begin
                    obs_tx.final_input_bytes = beat_bytes;
                    if ((beat_bytes == 0) && (obs_tx.accepted_input_bytes != 0))
                        record_protocol_error(obs_tx,
                            "zero-byte final beat followed non-empty input");
                    obs_tx.input_complete = 1;
                    return;
                end
            end

            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("input did not complete within %0d cycles", TIMEOUT_CYCLES));
                return;
            end
        end
    endtask

    task observe_abort_reset(input keccak_transaction exp_tx,
                             input keccak_transaction obs_tx);
        int timeout_counter = 0;

        while (!obs_tx.reset_observed) begin
            @(posedge vif.clk);
            timeout_counter++;
            if (vif.rst === 1'b1)
                obs_tx.reset_observed = 1;
            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("abort reset was not observed within %0d cycles", TIMEOUT_CYCLES));
                return;
            end
        end

        // Let the driver's reset sequence finish before releasing its event.
        while (vif.rst !== 1'b0)
            @(posedge vif.clk);
        repeat (2) @(posedge vif.clk);

        if (vif.m_axis_tvalid === 1'b1)
            record_protocol_error(obs_tx, "output remained valid after abort reset");
    endtask

    task collect_output(input keccak_transaction exp_tx,
                        input keccak_transaction obs_tx);
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

        rate_bytes           = exp_tx.get_rate_bytes();
        bytes_total_expected = exp_tx.get_expected_bytes();
        is_shake             = exp_tx.is_shake();

        `uvm_info(get_type_name(),
                  $sformatf("[%s] Monitor: waiting for %0d bytes (rate=%0d, mode=%s, xof_len=%0d)",
                            exp_tx.test_name, bytes_total_expected, rate_bytes,
                            exp_tx.mode.name(), exp_tx.xof_len_val),
                  UVM_MEDIUM)

        // Wait + collect
        forever begin
            @(posedge vif.clk);
            timeout_counter++;
            if ((vif.m_axis_tvalid === 1'b1) &&
                (vif.m_axis_tready === 1'b0))
                obs_tx.output_stall_cycles++;

            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("output timed out after %0d cycles (%0d/%0d bytes)",
                              timeout_counter, bytes_collected_so_far,
                              bytes_total_expected));
                break;
            end

            if ((vif.m_axis_tvalid === 1'b1) &&
                (vif.m_axis_tready === 1'b1)) begin
                logic [DWIDTH-1:0]      current_word;
                logic [KEEP_WIDTH-1:0]  current_keep;
                int                    beat_bytes;
                current_word = vif.m_axis_tdata;
                current_keep = vif.m_axis_tkeep;
                beat_bytes = 0;
                obs_tx.accepted_output_beats++;

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
                    record_protocol_error(obs_tx,
                        $sformatf("output tkeep mismatch at byte %0d: got %b expected %b",
                                  bytes_squeezed_total, current_keep, exp_keep));
                end

                // tlast verification
                if (!is_shake || (is_shake && exp_tx.xof_len_val > 0)) begin
                    int bytes_rem = bytes_total_expected - bytes_collected_so_far;
                    int b2 = BYTES_PER_BEAT;
                    if (bytes_remaining_in_rate_block < b2) b2 = bytes_remaining_in_rate_block;
                    exp_last = (bytes_rem <= b2) ? 1'b1 : 1'b0;
                    if (vif.m_axis_tlast !== exp_last) begin
                        record_protocol_error(obs_tx,
                            $sformatf("output tlast mismatch at byte %0d: got %0b expected %0b",
                                      bytes_squeezed_total, vif.m_axis_tlast, exp_last));
                    end
                end else begin
                    // SHAKE continuous: tlast should be 0
                    if (vif.m_axis_tlast !== 1'b0) begin
                        record_protocol_error(obs_tx,
                            $sformatf("continuous SHAKE asserted tlast at byte %0d",
                                      bytes_squeezed_total));
                    end
                end

                // --- Data collection ---
                for (int i = 0; i < BYTES_PER_BEAT; i++) begin
                    if (current_keep[i]) begin
                        bytes_squeezed_total++;
                        beat_bytes++;
                        if (obs_tx.obs_bytes.size() < bytes_total_expected) begin
                            obs_tx.obs_bytes.push_back(current_word[i*8 +: 8]);
                            bytes_collected_so_far++;
                        end
                    end
                end
                obs_tx.final_output_bytes = beat_bytes;

                // --- Termination ---
                if (obs_tx.obs_bytes.size() >= bytes_total_expected) begin
                    if (is_shake && exp_tx.xof_len_val == 0) begin
                        // Pulse stop_i to terminate continuous XOF
                        vif.stop = 1;
                        obs_tx.stop_issued = 1;
                        @(posedge vif.clk);
                        vif.stop = 0;
                    end
                    break;
                end
            end
        end

        `uvm_info(get_type_name(),
                  $sformatf("[%s] Monitor: collected %0d/%0d bytes",
                            exp_tx.test_name, obs_tx.obs_bytes.size(), bytes_total_expected),
                  UVM_MEDIUM)
    endtask

    function automatic bit keep_is_low_contiguous(
        input logic [KEEP_WIDTH-1:0] keep);
        bit zero_seen = 0;

        for (int i = 0; i < KEEP_WIDTH; i++) begin
            if (keep[i] === 1'b0)
                zero_seen = 1;
            else if ((keep[i] !== 1'b1) || zero_seen)
                return 0;
        end
        return 1;
    endfunction

    function void record_protocol_error(input keccak_transaction obs_tx,
                                        input string message);
        obs_tx.protocol_errors++;
        obs_tx.protocol_ok = 0;
        if (obs_tx.protocol_error_text.len() == 0)
            obs_tx.protocol_error_text = message;
        else
            obs_tx.protocol_error_text = {obs_tx.protocol_error_text, "; ", message};
        signal_errors++;
        `uvm_error(get_type_name(),
                   $sformatf("[%s] %s", obs_tx.test_name, message))
    endfunction

endclass
