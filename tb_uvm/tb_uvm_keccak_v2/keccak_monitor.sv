// =========================================================================
// keccak_monitor.sv - protocol-neutral Keccak monitor
// Reconstructs accepted input/output words from the DUT interface. The
// monitor is passive; ready and stop are driven by the driver.
// =========================================================================
class keccak_monitor extends uvm_monitor;
    `uvm_component_utils(keccak_monitor)

    virtual keccak_if vif;
    uvm_analysis_port #(keccak_transaction) mon_ap;
    uvm_tlm_analysis_fifo #(keccak_transaction) exp_fifo;
    uvm_event collection_done;

    localparam int BYTES_PER_WORD = DWIDTH / 8;
    localparam int TIMEOUT_CYCLES = 200_000;

    int signal_errors;

    function new(string name = "keccak_monitor", uvm_component parent = null);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
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

            exp_fifo.get(exp_tx);
            collect_transaction(exp_tx, obs_tx);
            mon_ap.write(obs_tx);
            collection_done.trigger();
        end
    endtask

    task collect_transaction(input keccak_transaction exp_tx,
                             output keccak_transaction obs_tx);
        obs_tx = keccak_transaction::type_id::create("obs_tx");
        obs_tx.test_name = exp_tx.test_name;
        obs_tx.exp_hex = exp_tx.exp_hex;
        obs_tx.output_len_bits = exp_tx.output_len_bits;
        obs_tx.input_gap_kind = exp_tx.input_gap_kind;
        obs_tx.output_stall_kind = exp_tx.output_stall_kind;
        obs_tx.expected_active_lanes = exp_tx.expected_active_lanes;
        obs_tx.stop_during_stall = exp_tx.stop_during_stall;
        obs_tx.reset_before_start = exp_tx.reset_before_start;
        obs_tx.config_change_kind = exp_tx.config_change_kind;
        obs_tx.stop_position_target = exp_tx.stop_position_target;
        obs_tx.reset_state_target = exp_tx.reset_state_target;
        obs_tx.back_to_back_request = exp_tx.back_to_back_request;
        obs_tx.stall_equivalence_request = exp_tx.stall_equivalence_request;
        obs_tx.equivalence_reference = exp_tx.equivalence_reference;
        obs_tx.prefix_consistency_request = exp_tx.prefix_consistency_request;
        obs_tx.prefix_reference = exp_tx.prefix_reference;
        obs_tx.byte_order_case = exp_tx.byte_order_case;
        obs_tx.byte_order_case_count = exp_tx.byte_order_case_count;
        obs_tx.lane_isolation_request = exp_tx.lane_isolation_request;
        obs_tx.mixed_lane_work_request = exp_tx.mixed_lane_work_request;
        obs_tx.obs_msg_hex = "";
        obs_tx.obs_bytes.delete();

        observe_start(obs_tx);
        if (obs_tx.start_seen)
            observe_input(exp_tx, obs_tx);

        if (exp_tx.reset_state_target > 0) begin
            observe_abort_reset(obs_tx);
            obs_tx.protocol_ok = obs_tx.start_seen &&
                                 obs_tx.reset_observed &&
                                 (obs_tx.protocol_errors == 0);
            return;
        end

        if (obs_tx.input_complete)
            collect_output(exp_tx, obs_tx);

        obs_tx.protocol_ok = obs_tx.start_seen &&
                             obs_tx.input_complete &&
                             (obs_tx.protocol_errors == 0);
    endtask

    task observe_start(input keccak_transaction obs_tx);
        int timeout_counter = 0;

        forever begin
            @(posedge vif.clk);
            sample_active_lanes(obs_tx);
            timeout_counter++;

            if (vif.rst === 1'b1)
                obs_tx.pre_start_reset_seen = 1;

            if (vif.start === 1'b1) begin
                obs_tx.start_seen = 1;
                obs_tx.mode = vif.mode;
                obs_tx.message_len_val = vif.message_len;
                obs_tx.xof_len_val = vif.output_len;
                return;
            end

            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("start was not observed within %0d cycles",
                              TIMEOUT_CYCLES));
                return;
            end
        end
    endtask

    task observe_input(input keccak_transaction exp_tx,
                       input keccak_transaction obs_tx);
        int timeout_counter = 0;
        int expected_input_bytes = obs_tx.message_len_val;
        bit first_word_seen = 0;

        if (expected_input_bytes == 0) begin
            obs_tx.input_complete = 1;
            obs_tx.final_input_bytes = 0;
            return;
        end

        forever begin
            logic [DWIDTH-1:0] current_word;
            int word_bytes;

            @(posedge vif.clk);
            sample_active_lanes(obs_tx);
            sample_config_change(obs_tx);
            timeout_counter++;

            if (vif.rst === 1'b1) begin
                obs_tx.reset_observed = 1;
                capture_reset_state(obs_tx);
                if (exp_tx.reset_state_target == 0)
                    record_protocol_error(obs_tx,
                        "reset asserted before input completed");
                return;
            end

            if (first_word_seen && !obs_tx.input_complete &&
                (vif.input_ready === 1'b1) &&
                (vif.input_valid === 1'b0))
                obs_tx.input_gap_cycles++;

            if ((vif.input_valid === 1'b1) &&
                (vif.input_ready === 1'b1)) begin
                first_word_seen = 1;
                current_word = vif.input_data;
                word_bytes = expected_input_bytes -
                             obs_tx.accepted_input_bytes;
                if (word_bytes > BYTES_PER_WORD)
                    word_bytes = BYTES_PER_WORD;

                obs_tx.accepted_input_beats++;
                for (int i = 0; i < word_bytes; i++) begin
                    obs_tx.obs_msg_hex = {
                        obs_tx.obs_msg_hex,
                        $sformatf("%02x", current_word[i*8 +: 8])
                    };
                    obs_tx.accepted_input_bytes++;
                end

                if (obs_tx.accepted_input_bytes == expected_input_bytes) begin
                    obs_tx.final_input_bytes = word_bytes;
                    obs_tx.input_complete = 1;
                    return;
                end
            end

            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("input did not complete within %0d cycles",
                              TIMEOUT_CYCLES));
                return;
            end
        end
    endtask

    task observe_abort_reset(input keccak_transaction obs_tx);
        int timeout_counter = 0;

        while (!obs_tx.reset_observed) begin
            @(posedge vif.clk);
            sample_active_lanes(obs_tx);
            timeout_counter++;
            if (vif.rst === 1'b1) begin
                obs_tx.reset_observed = 1;
                capture_reset_state(obs_tx);
            end
            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("abort reset was not observed within %0d cycles",
                              TIMEOUT_CYCLES));
                return;
            end
        end

        while (vif.rst !== 1'b0)
            @(posedge vif.clk);
        repeat (2) @(posedge vif.clk);

        if (vif.busy !== 1'b0)
            record_protocol_error(obs_tx,
                "busy remained asserted after abort reset");
        if (vif.output_valid === 1'b1)
            record_protocol_error(obs_tx,
                "output remained valid after abort reset");
    endtask

    function void capture_reset_state(input keccak_transaction obs_tx);
        case (vif.reset_from_state)
            0: obs_tx.reset_state_observed = 1;
            1: obs_tx.reset_state_observed = 2;
            2: obs_tx.reset_state_observed = 3;
            3: obs_tx.reset_state_observed =
                   vif.reset_from_perm_phase ? 5 : 4;
            4: obs_tx.reset_state_observed = 6;
            default: begin
                obs_tx.reset_state_observed = 0;
                record_protocol_error(obs_tx,
                    "pre-reset FSM state was unknown or invalid");
            end
        endcase
    endfunction

    task collect_output(input keccak_transaction exp_tx,
                        input keccak_transaction obs_tx);
        int rate_bytes = exp_tx.get_rate_bytes();
        int bytes_total_expected = exp_tx.get_expected_bytes();
        int bytes_collected = 0;
        int bytes_squeezed_total = 0;
        int timeout_counter = 0;

        `uvm_info(get_type_name(),
                  $sformatf("[%s] waiting for %0d bytes (rate=%0d, mode=%s, output_len=%0d)",
                            exp_tx.test_name, bytes_total_expected, rate_bytes,
                            exp_tx.mode.name(), exp_tx.xof_len_val),
                  UVM_MEDIUM)

        forever begin
            @(posedge vif.clk);
            sample_active_lanes(obs_tx);
            sample_config_change(obs_tx);
            timeout_counter++;

            if ((vif.output_valid === 1'b1) &&
                (vif.output_ready === 1'b0)) begin
                obs_tx.output_stall_cycles++;
                if (((bytes_collected + vif.output_bytes) >=
                     bytes_total_expected) && (exp_tx.xof_len_val > 0))
                    obs_tx.stall_position = 2;
                else if (((bytes_squeezed_total + vif.output_bytes) %
                          rate_bytes) == 0)
                    obs_tx.stall_position = 3;
                else
                    obs_tx.stall_position = 1;
            end

            if (timeout_counter > TIMEOUT_CYCLES) begin
                record_protocol_error(obs_tx,
                    $sformatf("output timed out after %0d cycles (%0d/%0d bytes)",
                              timeout_counter, bytes_collected,
                              bytes_total_expected));
                break;
            end

            if ((vif.output_valid === 1'b1) &&
                (vif.output_ready === 1'b1)) begin
                logic [DWIDTH-1:0] current_word;
                int current_bytes;
                int bytes_in_rate;
                int bytes_remaining_in_rate;
                int expected_bytes;
                bit expected_done;

                current_word = vif.output_data;
                current_bytes = vif.output_bytes;
                bytes_in_rate = bytes_squeezed_total % rate_bytes;
                bytes_remaining_in_rate = rate_bytes - bytes_in_rate;
                expected_bytes = BYTES_PER_WORD;

                if (bytes_remaining_in_rate < expected_bytes)
                    expected_bytes = bytes_remaining_in_rate;
                if (exp_tx.xof_len_val > 0) begin
                    int bytes_remaining_total =
                        bytes_total_expected - bytes_collected;
                    if (bytes_remaining_total < expected_bytes)
                        expected_bytes = bytes_remaining_total;
                end

                obs_tx.accepted_output_beats++;

                if ($isunknown(vif.output_bytes)) begin
                    record_protocol_error(obs_tx,
                        "output byte count contained X/Z");
                    current_bytes = 0;
                end else if ((current_bytes < 1) ||
                             (current_bytes > BYTES_PER_WORD)) begin
                    record_protocol_error(obs_tx,
                        $sformatf("invalid output byte count %0d",
                                  current_bytes));
                end else if (current_bytes != expected_bytes) begin
                    record_protocol_error(obs_tx,
                        $sformatf("output byte-count mismatch at byte %0d: got %0d expected %0d",
                                  bytes_squeezed_total, current_bytes,
                                  expected_bytes));
                end

                expected_done = (exp_tx.xof_len_val > 0) &&
                                ((bytes_collected + expected_bytes) >=
                                 bytes_total_expected);
                if (vif.done !== expected_done) begin
                    record_protocol_error(obs_tx,
                        $sformatf("done mismatch at byte %0d: got %0b expected %0b",
                                  bytes_squeezed_total, vif.done,
                                  expected_done));
                end

                for (int i = 0; i < current_bytes; i++) begin
                    bytes_squeezed_total++;
                    if (obs_tx.obs_bytes.size() < bytes_total_expected) begin
                        obs_tx.obs_bytes.push_back(
                            current_word[i*8 +: 8]);
                        bytes_collected++;
                    end
                end
                obs_tx.final_output_bytes = current_bytes;

                if (obs_tx.obs_bytes.size() >= bytes_total_expected) begin
                    if (exp_tx.xof_len_val == 0) begin
                        do begin
                            @(posedge vif.clk);
                            sample_active_lanes(obs_tx);
                            obs_tx.stop_wait_cycles++;
                        end while (vif.stop !== 1'b1);
                        obs_tx.stop_issued = 1;
                        if (exp_tx.stop_during_stall &&
                            (vif.output_ready === 1'b0)) begin
                            obs_tx.stop_while_stalled = 1;
                            obs_tx.output_stall_cycles++;
                            obs_tx.stall_position = exp_tx.stall_position;
                        end
                        obs_tx.stop_position_observed =
                            classify_stop_position(
                                obs_tx, bytes_squeezed_total, rate_bytes);
                        if (vif.done !== 1'b1)
                            record_protocol_error(obs_tx,
                                "continuous SHAKE did not assert done with stop");
                    end
                    break;
                end
            end
        end

        `uvm_info(get_type_name(),
                  $sformatf("[%s] collected %0d/%0d bytes",
                            exp_tx.test_name, obs_tx.obs_bytes.size(),
                            bytes_total_expected),
                  UVM_MEDIUM)
    endtask

    function void record_protocol_error(input keccak_transaction obs_tx,
                                        input string message);
        obs_tx.protocol_errors++;
        obs_tx.protocol_ok = 0;
        if (obs_tx.protocol_error_text.len() == 0)
            obs_tx.protocol_error_text = message;
        else
            obs_tx.protocol_error_text = {
                obs_tx.protocol_error_text, "; ", message
            };
        signal_errors++;
        `uvm_error(get_type_name(),
                   $sformatf("[%s] %s", obs_tx.test_name, message))
    endfunction

    function void sample_active_lanes(input keccak_transaction obs_tx);
        if (!$isunknown(vif.active_lanes) &&
            (vif.active_lanes > obs_tx.max_active_lanes))
            obs_tx.max_active_lanes = vif.active_lanes;
        if (vif.peer_reset_active === 1'b1)
            obs_tx.peer_reset_observed = 1;
        if (vif.peer_stall_active === 1'b1)
            obs_tx.peer_stall_observed = 1;
        if (vif.peer_stop_active === 1'b1)
            obs_tx.peer_stop_observed = 1;
        if (vif.debug_permutation_suite_passed === 1'b1)
            obs_tx.permutation_suite_observed = 1;
    endfunction

    function void sample_config_change(input keccak_transaction obs_tx);
        bit mode_changed;
        bit length_changed;

        mode_changed = (vif.mode !== obs_tx.mode);
        length_changed = (vif.output_len !== obs_tx.xof_len_val);

        case ({mode_changed, length_changed})
            2'b10: obs_tx.config_latch_case = 1;
            2'b01: obs_tx.config_latch_case = 2;
            2'b11: obs_tx.config_latch_case = 3;
            default: obs_tx.config_latch_case = 0;
        endcase
    endfunction

    function automatic int classify_stop_position(
        input keccak_transaction obs_tx,
        input int bytes_squeezed,
        input int rate_bytes
    );
        if (obs_tx.stop_while_stalled) return 5;
        if (bytes_squeezed <= BYTES_PER_WORD) return 1;
        if (bytes_squeezed == rate_bytes) return 3;
        if (bytes_squeezed > rate_bytes) return 4;
        return 2;
    endfunction

endclass
