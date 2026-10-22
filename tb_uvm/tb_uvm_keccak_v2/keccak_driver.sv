// =========================================================================
// keccak_driver.sv  -  TB v2 protocol-neutral word driver
// Drives input words on negedge and waits for input_ready before each word.
// Reset, configuration, message length, and start are explicit controls.
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

            // Start waiting before stimulus begins so the monitor completion
            // event cannot be missed by a concurrently finishing control task.
            fork
                drive_transaction(req);
                collection_done.wait_trigger();
            join
            collection_done.reset();

            seq_item_port.item_done();
        end
    endtask

    task init_signals();
        vif.rst              = 1;
        vif.start            = 0;
        vif.stop             = 0;
        vif.mode             = SHAKE128;
        vif.message_len      = 0;
        vif.output_len       = 0;
        vif.input_data       = '0;
        vif.input_valid      = 0;
        vif.output_ready     = 0;
        @(posedge vif.clk);
    endtask

    task drive_transaction(keccak_transaction req);
        // Most independent tests begin from reset. Recovery and back-to-back
        // tests explicitly suppress it so the previous operation's cleanup is
        // part of what the scoreboard verifies.
        if (req.reset_before_start)
            reset_dut();
        else begin
            @(negedge vif.clk);
            vif.rst          <= 0;
            vif.start        <= 0;
            vif.stop         <= 0;
            vif.input_valid  <= 0;
            vif.input_data   <= '0;
            vif.output_ready <= 0;
        end

        // 2. Apply start pulse with explicit message and output lengths.
        @(posedge vif.clk);
        vif.start         <= 1;
        vif.mode          <= req.mode;
        vif.message_len   <= req.msg_hex.len() / 2;
        vif.output_len    <= req.xof_len_val;
        @(posedge vif.clk);
        vif.start         <= 0;
        drive_post_start_config_change(req);

        // 3a. Reset path: wait for the requested observed FSM phase, then
        // assert async reset. No cycle-delay guesses are used.
        if (req.reset_state_target > 0) begin
            drive_abort(req);
            return;
        end

        // 3b. Normal path: input and output-side flow control run concurrently.
        // The driver owns every DUT input; the monitor remains passive.
        fork
            drive_msg(req);
            drive_output_control(req);
        join
    endtask

    task drive_post_start_config_change(keccak_transaction req);
        if (req.config_change_kind == 0)
            return;

        @(negedge vif.clk);
        if ((req.config_change_kind == 1) ||
            (req.config_change_kind == 3))
            vif.mode <= (req.mode == SHAKE128) ? SHAKE256 : SHAKE128;

        if ((req.config_change_kind == 2) ||
            (req.config_change_kind == 3)) begin
            if (req.xof_len_val == {XOF_LEN_WIDTH{1'b1}})
                vif.output_len <= req.xof_len_val - 1'b1;
            else
                vif.output_len <= req.xof_len_val + 1'b1;
        end
    endtask

    // Run lane-local input, optional output, and state-targeted reset workers
    // together. Reset-aware input waits terminate cleanly after an abort.
    task drive_abort(keccak_transaction req);
        vif.output_ready <= 0;

        fork
            drive_msg(req);
            begin
                if (req.reset_state_target == 1)
                    drive_output_control(req);
            end
            begin
                wait_for_reset_target(req.reset_state_target);

                // Assert immediately after the target was observed at a
                // negedge. This is essential for one-cycle SUFFIX_PADDING.
                vif.rst = 1;
                vif.input_valid <= 0;
                vif.input_data <= '0;
                vif.output_ready <= 0;
                vif.stop <= 0;
                repeat (2) @(posedge vif.clk);
                @(negedge vif.clk);
                vif.rst <= 0;
                @(posedge vif.clk);
            end
        join

        // Both workers can schedule nonblocking assignments on the target
        // edge. Reassert the aborted-source idle values after they have joined
        // so no stale valid/data survives into a no-reset recovery operation.
        @(negedge vif.clk);
        vif.input_valid  <= 0;
        vif.input_data   <= '0;
        vif.output_ready <= 0;
        vif.stop         <= 0;
    endtask

    task wait_for_reset_target(input int target);
        int timeout = 0;
        bit busy_seen = 0;
        bit target_seen;

        forever begin
            @(negedge vif.clk);
            timeout++;
            if (vif.busy === 1'b1)
                busy_seen = 1;

            case (target)
                1: target_seen = busy_seen && (vif.debug_state == 0);
                2: target_seen = (vif.debug_state == 1);
                3: target_seen = (vif.debug_state == 2);
                4: target_seen = (vif.debug_state == 3) &&
                                 (vif.debug_perm_phase == 0);
                5: target_seen = (vif.debug_state == 3) &&
                                 (vif.debug_perm_phase == 1);
                6: target_seen = (vif.debug_state == 4);
                default: target_seen = 0;
            endcase

            if (target_seen)
                return;
            if (timeout > 200_000)
                `uvm_fatal(get_type_name(),
                           $sformatf("reset target %0d was not reached", target))
        end
    endtask

    task reset_dut();
        vif.rst              <= 1;
        vif.start            <= 0;
        vif.stop             <= 0;
        vif.message_len      <= 0;
        vif.output_len       <= 0;
        vif.input_valid      <= 1'b0;
        vif.input_data       <= '0;
        repeat (3) @(posedge vif.clk);
        vif.rst              <= 0;
        @(posedge vif.clk);
    endtask

    task drive_msg(keccak_transaction req);
        logic [7:0] msg_bytes[];
        int total_bytes;
        int sent_bytes;
        int k;

        str_to_byte_array(req.msg_hex, msg_bytes);
        total_bytes = msg_bytes.size();
        sent_bytes  = 0;

        // Sync to clock before driving
        @(posedge vif.clk);

        // Empty messages require no data word; message_len=0 is explicit.
        if (total_bytes == 0) begin
            return;
        end

        // Multi-byte loop
        while (sent_bytes < total_bytes) begin
            int bytes_to_send;
            int bytes_remaining = total_bytes - sent_bytes;
            bytes_to_send = (bytes_remaining > BYTES_PER_BEAT) ? BYTES_PER_BEAT : bytes_remaining;

            @(negedge vif.clk);
            vif.input_valid <= 1;
            vif.input_data  <= '0;

            for (k = 0; k < bytes_to_send; k++) begin
                vif.input_data[k*8 +: 8] <= msg_bytes[sent_bytes + k];
            end

            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1)
                    return;
                if (vif.input_ready) break;
            end
            sent_bytes += bytes_to_send;

            if ((sent_bytes < total_bytes) && (req.input_gap_kind != 0)) begin
                int gap_cycles;
                case (req.input_gap_kind)
                    1: gap_cycles = 1;
                    2: gap_cycles = 3;
                    3: gap_cycles = $urandom_range(1, 4);
                    default: gap_cycles = 0;
                endcase
                @(negedge vif.clk);
                vif.input_valid <= 0;
                vif.input_data  <= '0;
                repeat (gap_cycles) @(posedge vif.clk);
            end
        end

        if (req.hold_valid_after_message) begin
            // The producer may keep valid high while the consumer applies
            // backpressure. Reassert valid after the final legal transfer and
            // keep both valid and data stable until the operation completes.
            @(negedge vif.clk);
            vif.input_valid <= 1'b0;
            #1ns;
            vif.input_valid <= 1'b1;
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1)
                    return;
                if (vif.input_ready === 1'b1)
                    `uvm_error("INPUT_BACKPRESSURE",
                               "DUT accepted an input beat after message end")
                if (vif.busy === 1'b0)
                    break;
            end
        end

        // Drop the input word signals.
        @(negedge vif.clk);
        vif.input_valid <= 0;
        vif.input_data  <= '0;
    endtask

    task drive_output_control(keccak_transaction req);
        int expected_bytes = req.get_expected_bytes();
        int accepted_bytes = 0;
        int accepted_beats = 0;
        int stall_remaining = 0;
        bit stall_injected = 0;

        vif.output_ready <= 1;

        forever begin
            @(negedge vif.clk);

            if (stall_remaining > 0) begin
                vif.output_ready <= 0;
                stall_remaining--;
            end else if (!stall_injected &&
                         should_stall_now(req, accepted_bytes,
                                          accepted_beats)) begin
                case (req.output_stall_kind)
                    1: stall_remaining = 0;
                    2: stall_remaining = 2;
                    3: stall_remaining = $urandom_range(1, 3);
                    default: stall_remaining = 0;
                endcase
                vif.output_ready <= 0;
                stall_injected = 1;
                if (req.stop_during_stall) begin
                    vif.stop <= 1;
                    @(posedge vif.clk);
                    @(negedge vif.clk);
                    vif.stop <= 0;
                    return;
                end
            end else begin
                vif.output_ready <= 1;
            end

            @(posedge vif.clk);
            if (vif.output_valid && vif.output_ready) begin
                accepted_bytes += vif.output_bytes;
                accepted_beats++;

                if ((req.xof_len_val > 0) &&
                    (accepted_bytes >= expected_bytes)) begin
                    @(negedge vif.clk);
                    vif.output_ready <= 0;
                    return;
                end

                if ((req.xof_len_val == 0) && !req.stop_during_stall &&
                    (accepted_bytes >= expected_bytes)) begin
                    @(negedge vif.clk);
                    vif.output_ready <= 0;
                    // A transfer that empties the rate moves directly into
                    // re-permutation. stop_i is only legal in SQUEEZE, so wait
                    // for output_valid to return before requesting stop.
                    while (vif.output_valid !== 1'b1)
                        @(negedge vif.clk);
                    vif.stop <= 1;
                    @(posedge vif.clk);
                    @(negedge vif.clk);
                    vif.stop <= 0;
                    return;
                end
            end
        end
    endtask

    function automatic bit should_stall_now(
        input keccak_transaction req,
        input int accepted_bytes,
        input int accepted_beats
    );
        int next_bytes;
        int rate_bytes;

        if ((req.output_stall_kind == 0) ||
            (vif.output_valid !== 1'b1))
            return 0;

        next_bytes = vif.output_bytes;
        rate_bytes = req.get_rate_bytes();

        case (req.stall_position)
            1: return (accepted_beats >= 1) &&
                      (req.stop_during_stall ||
                      ((accepted_bytes + next_bytes) < req.get_expected_bytes()) &&
                      (((accepted_bytes + next_bytes) % rate_bytes) != 0));
            2: return (req.xof_len_val > 0) &&
                      ((accepted_bytes + next_bytes) >= req.get_expected_bytes());
            3: return ((accepted_bytes + next_bytes) % rate_bytes) == 0;
            default: return 0;
        endcase
    endfunction

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
