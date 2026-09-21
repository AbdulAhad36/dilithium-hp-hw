// =========================================================================
// tb_top.sv  -  Unified top-level for keccak verification
//
// Per-core regression matching the two cores in keccak_dual_interleaved.
//
// To change lane count: edit N_LANES here AND in keccak_env::N_LANES so
// the env's per-lane component arrays match.
// =========================================================================
`timescale 1ns/1ps

import keccak_pkg::*;
import keccak_ref_pkg::*;
`ifndef KECCAK_DUAL_NETLIST
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "keccak_transaction.sv"
`include "keccak_sequence.sv"
`include "keccak_coverage.sv"
`include "keccak_scoreboard.sv"
`include "keccak_driver.sv"
`include "keccak_monitor.sv"
`include "keccak_agent.sv"
`include "keccak_env.sv"
`include "keccak_tests.sv"

module tb_keccak_uvm_core #(
    parameter bit AUTO_FINISH = 1'b1
) (
    output logic test_done
);

    logic uvm_done = 1'b0;
    logic dual_done = 1'b0;
    keccak_dual_coverage dual_coverage;

    localparam int N_LANES = 2;

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    logic clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // ----------------------------------------------------------------
    // Per-lane interfaces
    // ----------------------------------------------------------------
    keccak_if vif [N_LANES] (clk);

    // ----------------------------------------------------------------
    // Bundle wires connecting interfaces to the independent cores
    // ----------------------------------------------------------------
    logic [N_LANES-1:0]                     rst;
    logic [N_LANES-1:0]                     start_i;
    keccak_mode                             keccak_mode_i [N_LANES];
    logic [N_LANES-1:0][MSG_LEN_WIDTH-1:0]  message_len_i;
    logic [N_LANES-1:0][XOF_LEN_WIDTH-1:0]  output_len_i;
    logic [N_LANES-1:0]                     stop_i;
    wire  [N_LANES-1:0]                     busy_o;
    wire  [N_LANES-1:0]                     done_o;

    logic [N_LANES-1:0][DWIDTH-1:0]         input_data_i;
    logic [N_LANES-1:0]                     input_valid_i;
    wire  [N_LANES-1:0]                     input_ready_o;

    wire  [N_LANES-1:0][DWIDTH-1:0]         output_data_o;
    wire  [N_LANES-1:0]                     output_valid_o;
    wire  [N_LANES-1:0][BYTE_COUNT_WIDTH-1:0] output_bytes_o;
    logic [N_LANES-1:0]                     output_ready_i;

    generate
        for (genvar i = 0; i < N_LANES; i++) begin : g_wire
            assign rst[i]            = vif[i].rst;
            assign start_i[i]        = vif[i].start;
            assign keccak_mode_i[i]  = vif[i].mode;
            assign message_len_i[i]  = vif[i].message_len;
            assign output_len_i[i]   = vif[i].output_len;
            assign stop_i[i]         = vif[i].stop;
            assign vif[i].busy        = busy_o[i];
            assign vif[i].done        = done_o[i];
            assign vif[i].active_lanes = $countones(busy_o);
            assign vif[i].debug_state = g_lane[i].u_core.state[2:0];
            assign vif[i].debug_perm_phase =
                g_lane[i].u_core.permute_phase;
            assign vif[i].debug_round_idx =
                g_lane[i].u_core.round_idx;
            assign input_data_i[i]    = vif[i].input_data;
            assign input_valid_i[i]   = vif[i].input_valid;
            assign vif[i].input_ready = input_ready_o[i];
            assign vif[i].output_data = output_data_o[i];
            assign vif[i].output_valid = output_valid_o[i];
            assign vif[i].output_bytes = output_bytes_o[i];
            assign output_ready_i[i]  = vif[i].output_ready;

            always_comb begin
                vif[i].peer_reset_active = 1'b0;
                vif[i].peer_stall_active = 1'b0;
                vif[i].peer_stop_active = 1'b0;
                for (int peer = 0; peer < N_LANES; peer++) begin
                    if (peer != i) begin
                        vif[i].peer_reset_active |= rst[peer];
                        vif[i].peer_stall_active |=
                            output_valid_o[peer] && !output_ready_i[peer];
                        vif[i].peer_stop_active |=
                            stop_i[peer] && busy_o[peer];
                    end
                end
            end

            // Capture the phase that existed immediately before async reset
            // clears the core. These signals are verification-only and do not
            // alter the synthesizable Keccak interface.
            always @(posedge vif[i].rst) begin
                vif[i].reset_from_state = vif[i].debug_state;
                vif[i].reset_from_perm_phase = vif[i].debug_perm_phase;
            end

            keccak_assertions lane_assertions (
                .clk             (clk),
                .rst             (rst[i]),
                .start_i         (start_i[i]),
                .stop_i          (stop_i[i]),
                .busy_o          (busy_o[i]),
                .done_o          (done_o[i]),
                .input_data_i    (input_data_i[i]),
                .input_valid_i   (input_valid_i[i]),
                .input_ready_o   (input_ready_o[i]),
                .output_data_o   (output_data_o[i]),
                .output_valid_o  (output_valid_o[i]),
                .output_bytes_o  (output_bytes_o[i]),
                .output_ready_i  (output_ready_i[i])
            );

            keccak_permutation_checker permutation_checker (
                .clk             (clk),
                .rst             (rst[i]),
                .state           (g_lane[i].u_core.state[2:0]),
                .round_idx       (g_lane[i].u_core.round_idx),
                .state_array     (g_lane[i].u_core.state_array),
                .theta_out       (g_lane[i].u_core.KSU.theta_out),
                .rho_out         (g_lane[i].u_core.KSU.rho_out),
                .pi_out          (g_lane[i].u_core.KSU.pi_out),
                .chi_out         (g_lane[i].u_core.KSU.chi_out),
                .iota_out        (g_lane[i].u_core.KSU.iota_out),
                .suite_passed_o  (vif[i].debug_permutation_suite_passed)
            );
        end
    endgenerate

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    for (genvar lane = 0; lane < N_LANES; lane++) begin : g_lane
        keccak_core u_core (
            .clk            (clk),
            .rst            (rst[lane]),
            .start_i        (start_i[lane]),
            .keccak_mode_i  (keccak_mode_i[lane]),
            .message_len_i  (message_len_i[lane]),
            .output_len_i   (output_len_i[lane]),
            .stop_i         (stop_i[lane]),
            .busy_o         (busy_o[lane]),
            .done_o         (done_o[lane]),
            .input_data_i   (input_data_i[lane]),
            .input_valid_i  (input_valid_i[lane]),
            .input_ready_o  (input_ready_o[lane]),
            .output_data_o  (output_data_o[lane]),
            .output_valid_o (output_valid_o[lane]),
            .output_bytes_o (output_bytes_o[lane]),
            .output_ready_i (output_ready_i[lane])
        );
    end

    // ----------------------------------------------------------------
    // Register per-lane vif under each agent's hierarchy
    // ----------------------------------------------------------------
    initial begin
        test_done = 1'b0;
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_0.*", "keccak_vif", vif[0]);
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_1.*", "keccak_vif", vif[1]);
        uvm_top.finish_on_completion = AUTO_FINISH;
        fork
            run_test("keccak_full_test");
        join_none
    end

    initial begin
        uvm_event suite_done;
        suite_done = uvm_event_pool::get_global("keccak_uvm_suite_done");
        suite_done.wait_trigger();
        uvm_done = 1'b1;
    end


    initial begin
        dual_coverage = new();
        wait (uvm_done && dual_done);
        test_done = 1'b1;
    end

    localparam int OUTPUT_DWIDTH = 128;
    localparam int OUTPUT_BYTES_PER_BEAT = OUTPUT_DWIDTH / 8;
    localparam int OUTPUT_BYTE_COUNT_WIDTH = $clog2(OUTPUT_BYTES_PER_BEAT + 1);

    logic dual_rst;
    logic request_valid;
    logic request_ready;
    logic request_core;
    keccak_mode mode;
    logic [MSG_LEN_WIDTH-1:0] message_len;
    logic [XOF_LEN_WIDTH-1:0] output_len;
    logic [DWIDTH-1:0] input_data;
    logic input_valid;
    logic input_ready;
    logic input_core;
    logic [1:0] stop;
    wire [1:0] core_busy;
    wire [1:0] core_done;
    wire busy;
    logic [OUTPUT_DWIDTH-1:0] output_data;
    logic output_valid;
    logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] output_bytes;
    logic output_core;
    logic output_ready;

    byte unsigned expected [2][$];
    int cycle_count;
    int errors;
    int accepted_jobs;
    int checked_jobs;
    int stall_profile;
    int pair_start_cycle;
    int launch_cycle [2];
    int pair_source_switches;
    int output_position [2];
    int core_rate [2];
    int last_output_bytes [2];
    bit previous_source_valid;
    bit previous_source;
    bit pair_output_overlap;
    bit pair_output_stall;
    bit pair_simultaneous_stall;
    bit pair_request_wait;
    bit pair_dispatch_fallback;
    bit pair_wait_offset;
    bit pair_wait_ingress;
    bit pair_wait_all_busy;
    bit pair_output_only_core0;
    bit pair_output_only_core1;
    bit pair_both_select_core0;
    bit pair_both_select_core1;
    bit pair_locked_stall_core0;
    bit pair_locked_stall_core1;
    bit pair_reset_while_busy;
    bit pair_stop_core0;
    bit pair_stop_core1;
    bit saw_rate_tail [2];
    bit stalled_previous_cycle;
    logic [OUTPUT_DWIDTH-1:0] stalled_data;
    logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] stalled_bytes;
    bit stalled_core;
    bit forced_stall_started;
    int forced_stall_remaining;








    keccak_dual_interleaved #(
        .START_OFFSET_CYCLES(26),
        .OUTPUT_DWIDTH(OUTPUT_DWIDTH)
    ) dual_dut (
        .clk(clk),
        .rst(dual_rst),
        .request_valid_i(request_valid),
        .request_ready_o(request_ready),
        .request_core_o(request_core),
        .keccak_mode_i(mode),
        .message_len_i(message_len),
        .output_len_i(output_len),
        .input_data_i(input_data),
        .input_valid_i(input_valid),
        .input_ready_o(input_ready),
        .input_core_o(input_core),
        .stop_i(stop),
        .core_busy_o(core_busy),
        .core_done_o(core_done),
        .busy_o(busy),
        .output_data_o(output_data),
        .output_valid_o(output_valid),
        .output_bytes_o(output_bytes),
        .output_core_o(output_core),
        .output_ready_i(output_ready)
    );

function automatic int rate_bytes(input keccak_mode job_mode);
        return (job_mode == SHAKE256) ? 136 : 168;
    endfunction

    function automatic int classify_message(input int length, input int rate);
        if (length == 0) return 0;
        if ((length < 8) || (((length % 8) != 0) && (length < rate-1))) return 1;
        if (((length % 8) == 0) && (length < rate-1)) return 2;
        if (length == rate-1) return 3;
        if (length == rate) return 4;
        if (length == rate+1) return 5;
        return 6;
    endfunction

    function automatic int classify_output(input int length, input int rate);
        if (length < OUTPUT_BYTES_PER_BEAT) return 0;
        if (length == OUTPUT_BYTES_PER_BEAT) return 1;
        if (length < rate-1) return 2;
        if (length == rate-1) return 3;
        if (length == rate) return 4;
        if (length == rate+1) return 5;
        return 6;
    endfunction

    function automatic int classify_final_beat(input int byte_count);
        if (byte_count == OUTPUT_BYTES_PER_BEAT) return 0;
        if (byte_count == 8) return 1;
        return 2;
    endfunction

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (!dual_rst && stalled_previous_cycle &&
            (!output_valid || output_data !== stalled_data ||
             output_bytes !== stalled_bytes || output_core !== stalled_core)) begin
            $error;
            errors++;
        end
        stalled_previous_cycle <= !dual_rst && output_valid && !output_ready;
        if (!dual_rst && output_valid && !output_ready) begin
            stalled_data <= output_data;
            stalled_bytes <= output_bytes;
            stalled_core <= output_core;
        end
        if (!dual_rst && request_valid && !request_ready) begin
            if (dual_dut.offset_count != '0)
                pair_wait_offset <= 1'b1;
            if (dual_dut.ingress_active)
                pair_wait_ingress <= 1'b1;
            if (&core_busy)
                pair_wait_all_busy <= 1'b1;
        end
        if (!dual_rst && request_valid && request_ready &&
            (dual_dut.dispatch_core != dual_dut.dispatch_preference))
            pair_dispatch_fallback <= 1'b1;
        if (!dual_rst && !dual_dut.arbiter_locked) begin
            case (dual_dut.core_output_valid)
                2'b01: pair_output_only_core0 <= 1'b1;
                2'b10: pair_output_only_core1 <= 1'b1;
                2'b11: begin
                    if (dual_dut.selected_output_core)
                        pair_both_select_core1 <= 1'b1;
                    else
                        pair_both_select_core0 <= 1'b1;
                end
                default: ;
            endcase
        end
        if (!dual_rst && dual_dut.arbiter_locked && output_valid && !output_ready) begin
            if (dual_dut.selected_output_core)
                pair_locked_stall_core1 <= 1'b1;
            else
                pair_locked_stall_core0 <= 1'b1;
        end
        if (dual_rst && busy)
            pair_reset_while_busy <= 1'b1;
        if (!dual_rst && stop[0])
            pair_stop_core0 <= 1'b1;
        if (!dual_rst && stop[1])
            pair_stop_core1 <= 1'b1;
        if (!dual_rst & (&dual_dut.core_output_valid))
            pair_output_overlap <= 1'b1;
        if (!dual_rst & output_valid & !output_ready) begin
            pair_output_stall <= 1'b1;
            if (&dual_dut.core_output_valid)
                pair_simultaneous_stall <= 1'b1;
        end
        if (!dual_rst & output_valid & output_ready) begin
            if ((output_bytes == 0) |
                (output_bytes > OUTPUT_BYTES_PER_BEAT)) begin
                $error;
                errors++;
            end
            for (int b = 0; b < output_bytes; b++) begin
                byte unsigned expected_byte;
                if (expected[output_core].size() == 0) begin
                    $error;
                    errors++;
                end else begin
                    expected_byte = expected[output_core].pop_front();
                    if (output_data[b*8 +: 8] !== expected_byte) begin
                        $error;
                        errors++;
                    end
                end
            end
            if ((output_position[output_core] + output_bytes) ==
                core_rate[output_core])
                saw_rate_tail[output_core] <=
                    (output_bytes < OUTPUT_BYTES_PER_BEAT);
            output_position[output_core] <=
                (output_position[output_core] + output_bytes) %
                core_rate[output_core];
            last_output_bytes[output_core] <= output_bytes;
            if (previous_source_valid & (previous_source != output_core))
                pair_source_switches <= pair_source_switches + 1;
            previous_source <= output_core;
            previous_source_valid <= 1'b1;
        end
    end

    always @(negedge clk) begin
        if (dual_rst) begin
            output_ready <= 1'b0;
            forced_stall_started <= 1'b0;
            forced_stall_remaining <= 0;
        end else begin
            case (stall_profile)
                0: output_ready <= 1'b1;
                1: output_ready <= ((cycle_count % 5) != 2);
                2: output_ready <= !((cycle_count - pair_start_cycle >= 28) &
                                     (cycle_count - pair_start_cycle < 68));
                3: begin
                    if (!forced_stall_started && output_valid) begin
                        output_ready <= 1'b0;
                        forced_stall_started <= 1'b1;
                        forced_stall_remaining <= 40;
                    end else if (forced_stall_remaining > 0) begin
                        output_ready <= 1'b0;
                        forced_stall_remaining <= forced_stall_remaining - 1;
                    end else begin
                        output_ready <= ((cycle_count % 7) != 3);
                    end
                end
                default: output_ready <= 1'b1;
            endcase
        end
    end

    task automatic send_job(
        input keccak_mode job_mode,
        input int msg_bytes,
        input int requested_bytes,
        input int pattern_seed,
        output bit assigned_core
    );
        byte unsigned message[];
        byte unsigned golden[$];
        int sent;
        int beat_bytes;
        int wait_cycles;

        message = new[msg_bytes];
        for (int i = 0; i < msg_bytes; i++)
            message[i] = byte'(pattern_seed + i*13);

        @(negedge clk);
        request_valid <= 1'b1;
        mode <= job_mode;
        message_len <= msg_bytes;
        output_len <= requested_bytes;
        wait_cycles = 0;
        forever begin
            @(posedge clk);
            if (request_ready) begin
                assigned_core = request_core;
                launch_cycle[assigned_core] = cycle_count;
                accepted_jobs++;
                break;
            end
            wait_cycles++;
        end
        if (wait_cycles != 0)
            pair_request_wait = 1'b1;

        shake_compute(job_mode, message, requested_bytes, golden);
        while (golden.size() != 0)
            expected[assigned_core].push_back(golden.pop_front());
        core_rate[assigned_core] = rate_bytes(job_mode);
        output_position[assigned_core] = 0;
        last_output_bytes[assigned_core] = 0;
        saw_rate_tail[assigned_core] = 1'b0;

        @(negedge clk);
        request_valid <= 1'b0;
        sent = 0;
        while (sent < msg_bytes) begin
            beat_bytes = msg_bytes - sent;
            if (beat_bytes > DATA_BYTE_NUM)
                beat_bytes = DATA_BYTE_NUM;
            input_data <= '0;
            for (int b = 0; b < beat_bytes; b++)
                input_data[b*8 +: 8] <= message[sent+b];
            input_valid <= 1'b1;
            forever begin
                @(posedge clk);
                if (input_ready) begin
                    if (input_core != assigned_core) begin
                        $error;
                        errors++;
                    end
                    break;
                end
            end
            sent += beat_bytes;
            @(negedge clk);
            input_valid <= 1'b0;
            input_data <= '0;
        end
    endtask

    initial begin
        `uvm_info("DUAL_REGRESSION",
                  "Starting dual-interleaved SHAKE128/SHAKE256 regression",
                  UVM_LOW)
        cycle_count = 0;
        errors = 0;
        accepted_jobs = 0;
        checked_jobs = 0;
        stall_profile = 0;
        pair_start_cycle = 0;
        request_valid = 0;
        mode = SHAKE128;
        message_len = 0;
        output_len = 0;
        input_data = '0;
        input_valid = 0;
        output_ready = 0;
        stop = '0;
        dual_rst = 1;
        for (int core = 0; core < 2; core++) begin
            output_position[core] = 0;
            core_rate[core] = 168;
            last_output_bytes[core] = 0;
            saw_rate_tail[core] = 0;
        end

        repeat (4) @(posedge clk);
        @(negedge clk);
        dual_rst = 0;

        // Coverage is sampled only after the job pair passes byte checking.
        run_pair(SHAKE128,   0,   1, SHAKE128,   0,   1, 0,  0, 0);
        run_pair(SHAKE256,   1,   8, SHAKE256,   1,   8, 1,  1, 0);
        run_pair(SHAKE128,   8,  16, SHAKE128,   8,  16, 2,  2, 0);
        run_pair(SHAKE256,   9,  17, SHAKE256,   9,  17, 0,  3, 0);
        run_pair(SHAKE128, 167, 167, SHAKE128, 167, 167, 1,  4, 0);
        run_pair(SHAKE256, 135, 135, SHAKE256, 135, 135, 2,  5, 0);
        run_pair(SHAKE128, 168, 168, SHAKE128, 168, 168, 0,  6, 0);
        run_pair(SHAKE256, 136, 136, SHAKE256, 136, 136, 1,  7, 0);
        run_pair(SHAKE128, 169, 169, SHAKE128, 169, 169, 2,  8, 0);
        run_pair(SHAKE256, 137, 137, SHAKE256, 137, 137, 0,  9, 0);
        run_pair(SHAKE128, 337, 337, SHAKE256, 273, 273, 1, 10, 0);
        run_pair(SHAKE256, 273, 600, SHAKE128, 337, 600, 2, 11, 32);
        run_pair(SHAKE128,   7,  17, SHAKE128,   7,  17, 1, 12, 32);
        run_pair(SHAKE128, 337, 600, SHAKE128, 337, 600, 0, 13, 0);
        run_pair(SHAKE256,   8,  16, SHAKE256,   8,  16, 2, 14, 0);
        run_pair(SHAKE256, 273, 600, SHAKE256, 273, 600, 1, 15, 0);
        run_pair(SHAKE128,   7, 169, SHAKE256,   7, 137, 0, 16, 32);
        run_pair(SHAKE256,   8, 136, SHAKE128,   8, 168, 1, 17, 0);
        run_pair(SHAKE128,   9, 600, SHAKE256,   9, 600, 2, 18, 0);
        run_pair(SHAKE128,   8, 199, SHAKE256,  16, 197, 3, 19, 0);

        repeat (3) @(posedge clk);
        // Coverage closure is evaluated from the UCDB; only functional and
        // protocol failures contribute to the regression error count.
        if (accepted_jobs != checked_jobs) begin
            $error;
            errors++;
        end
        if (errors != 0)
            $fatal;
        `uvm_info("DUAL_REGRESSION",
                  $sformatf("PASS: jobs=%0d core0=%0.2f%% core1=%0.2f%% interleaver=%0.2f%%",
                            checked_jobs,
                            dual_coverage.core_cov0.get_inst_coverage(),
                            dual_coverage.core_cov1.get_inst_coverage(),
                            dual_coverage.dual_cov.get_inst_coverage()),
                  UVM_LOW)
        dual_done = 1'b1;
end

    task automatic sample_core_result(
        input bit core_id,
        input keccak_mode job_mode,
        input int msg_bytes,
        input int requested_bytes,
        input int profile
    );
        int rate;
        rate = rate_bytes(job_mode);
        if (expected[core_id].size() != 0) begin
            $error;
            errors++;
        end else begin
            dual_coverage.sample_core(
                core_id, int'(job_mode),
                classify_message(msg_bytes, rate),
                classify_output(requested_bytes, rate),
                profile,
                classify_final_beat(last_output_bytes[core_id]),
                saw_rate_tail[core_id],
                (msg_bytes >= rate),
                (requested_bytes > rate)
            );
            checked_jobs++;
        end
    endtask

    task automatic run_pair(
        input keccak_mode mode0,
        input int msg0,
        input int out0,
        input keccak_mode mode1,
        input int msg1,
        input int out1,
        input int profile,
        input int pair_id,
        input int pre_second_delay
    );
        bit assigned0;
        bit assigned1;
        int timeout;
        int gap;
        int mode_pair;
        int switch_class;

        `uvm_info("DUAL_PAIR",
                  $sformatf("pair=%0d mode0=%s msg0=%0d out0=%0d mode1=%s msg1=%0d out1=%0d stall_profile=%0d",
                            pair_id,
                            (mode0 == SHAKE128) ? "SHAKE128" : "SHAKE256",
                            msg0, out0,
                            (mode1 == SHAKE128) ? "SHAKE128" : "SHAKE256",
                            msg1, out1, profile),
                  UVM_MEDIUM)
        wait (!busy);
        repeat (2) @(posedge clk);
        pair_start_cycle = cycle_count;
        stall_profile = profile;
        pair_source_switches = 0;
        pair_output_overlap = 1'b0;
        pair_output_stall = 1'b0;
        pair_simultaneous_stall = 1'b0;
        pair_request_wait = 1'b0;
        pair_dispatch_fallback = 1'b0;
        pair_wait_offset = 1'b0;
        pair_wait_ingress = 1'b0;
        pair_wait_all_busy = 1'b0;
        pair_output_only_core0 = 1'b0;
        pair_output_only_core1 = 1'b0;
        pair_both_select_core0 = 1'b0;
        pair_both_select_core1 = 1'b0;
        pair_locked_stall_core0 = 1'b0;
        pair_locked_stall_core1 = 1'b0;
        pair_reset_while_busy = 1'b0;
        pair_stop_core0 = 1'b0;
        pair_stop_core1 = 1'b0;
        previous_source_valid = 1'b0;
        forced_stall_started = 1'b0;
        forced_stall_remaining = 0;

        send_job(mode0, msg0, out0, pair_id*17 + 1, assigned0);
        repeat (pre_second_delay) @(posedge clk);
        send_job(mode1, msg1, out1, pair_id*17 + 9, assigned1);
        if (assigned0 == assigned1) begin
            $error;
            errors++;
        end

        timeout = 0;
        while ((busy | (expected[0].size() != 0) |
                (expected[1].size() != 0)) & (timeout < 10000)) begin
            @(posedge clk);
            timeout++;
        end
        if (timeout == 10000) begin
            $error;
            errors++;
        end
        @(negedge clk);

        sample_core_result(assigned0, mode0, msg0, out0, profile);
        sample_core_result(assigned1, mode1, msg1, out1, profile);
        gap = launch_cycle[assigned1] - launch_cycle[assigned0];
        if (pair_id == 19 &&
            (gap != 26 || !pair_simultaneous_stall ||
             pair_source_switches < 2)) begin
            $error;
            errors++;
        end
        mode_pair = (mode0 == mode1) ?
                    ((mode0 == SHAKE128) ? 0 : 1) : 2;
        switch_class = (pair_source_switches <= 1) ? 1 : 2;
        dual_coverage.dual_cov.sample(
            mode_pair,
            profile,
            (gap == 26) ? 0 : 1,
            pair_output_overlap,
            pair_output_stall,
            pair_simultaneous_stall,
            switch_class,
            pair_request_wait,
            assigned0,
            pair_dispatch_fallback,
            pair_wait_offset,
            pair_wait_ingress,
            pair_wait_all_busy,
            pair_output_only_core0,
            pair_output_only_core1,
            pair_both_select_core0,
            pair_both_select_core1,
            pair_locked_stall_core0,
            pair_locked_stall_core1,
            pair_reset_while_busy,
            pair_stop_core0,
            pair_stop_core1
        );
        `uvm_info("DUAL_PAIR",
                  $sformatf("pair=%0d PASS first_core=%0d launch_gap=%0d source_switches=%0d",
                            pair_id, assigned0, gap, pair_source_switches),
                  UVM_MEDIUM)
    endtask

endmodule
`endif

module tb_keccak_dual_throughput #(
    parameter bit AUTO_FINISH = 1'b1
) (
    output logic test_done
);
    localparam int OUTPUT_DWIDTH = 128;
    localparam int OUTPUT_BYTES_PER_BEAT = OUTPUT_DWIDTH / 8;
    localparam int OUTPUT_BYTE_COUNT_WIDTH = $clog2(OUTPUT_BYTES_PER_BEAT + 1);
    localparam real TARGET_CLOCK_MHZ = 148.0;

    logic clk;
    logic rst;
    logic request_valid;
    logic request_ready;
    logic request_core;
    keccak_mode mode;
    logic [MSG_LEN_WIDTH-1:0] message_len;
    logic [XOF_LEN_WIDTH-1:0] output_len;
    logic [DWIDTH-1:0] input_data;
    logic input_valid;
    logic input_ready;
    logic input_core;
    logic [1:0] stop;
    wire [1:0] core_busy;
    wire [1:0] core_done;
    wire busy;
    logic [OUTPUT_DWIDTH-1:0] output_data;
    logic output_valid;
    logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] output_bytes;
    logic output_core;
    logic output_ready;

    byte unsigned expected [2][$];
    int cycle_count;
    int first_accept_cycle;
    int final_output_cycle;
    int total_observed_bytes;
    int expected_total_bytes;
    int errors;

    keccak_dual_interleaved #(
        .START_OFFSET_CYCLES(26),
        .OUTPUT_DWIDTH(OUTPUT_DWIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .request_valid_i(request_valid),
        .request_ready_o(request_ready),
        .request_core_o(request_core),
        .keccak_mode_i(mode),
        .message_len_i(message_len),
        .output_len_i(output_len),
        .input_data_i(input_data),
        .input_valid_i(input_valid),
        .input_ready_o(input_ready),
        .input_core_o(input_core),
        .stop_i(stop),
        .core_busy_o(core_busy),
        .core_done_o(core_done),
        .busy_o(busy),
        .output_data_o(output_data),
        .output_valid_o(output_valid),
        .output_bytes_o(output_bytes),
        .output_core_o(output_core),
        .output_ready_i(output_ready)
    );

    initial begin
        test_done = 1'b0;
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (!rst && output_valid && output_ready) begin
            if ((output_bytes == 0) ||
                (output_bytes > OUTPUT_BYTES_PER_BEAT)) begin
                $error("Illegal output byte count %0d", output_bytes);
                errors++;
            end

            for (int b = 0; b < output_bytes; b++) begin
                byte unsigned expected_byte;
                if (expected[output_core].size() == 0) begin
                    $error("Unexpected output byte from core %0d", output_core);
                    errors++;
                end else begin
                    expected_byte = expected[output_core].pop_front();
                    if (output_data[b*8 +: 8] !== expected_byte) begin
                        $error("Core %0d output mismatch at aggregate byte %0d",
                               output_core, total_observed_bytes + b);
                        errors++;
                    end
                end
            end

            total_observed_bytes <= total_observed_bytes + output_bytes;
            if ((total_observed_bytes + output_bytes) == expected_total_bytes)
                final_output_cycle <= cycle_count;
        end
    end

    task automatic initialize_signals;
        request_valid = 1'b0;
        mode = SHAKE128;
        message_len = '0;
        output_len = '0;
        input_data = '0;
        input_valid = 1'b0;
        stop = '0;
        output_ready = 1'b1;
    endtask

    task automatic reset_dut;
        rst = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
    endtask

    task automatic send_job(
        input keccak_mode job_mode,
        input byte unsigned message[],
        input int requested_bytes,
        input int job_number
    );
        bit assigned_core;
        int sent;
        int beat_bytes;
        byte unsigned golden[$];

        @(negedge clk);
        request_valid <= 1'b1;
        mode <= job_mode;
        message_len <= message.size();
        output_len <= requested_bytes;

        forever begin
            @(posedge clk);
            if (request_ready) begin
                assigned_core = request_core;
                if (job_number == 0)
                    first_accept_cycle = cycle_count;
                break;
            end
        end

        shake_compute(job_mode, message, requested_bytes, golden);
        while (golden.size() != 0)
            expected[assigned_core].push_back(golden.pop_front());

        @(negedge clk);
        request_valid <= 1'b0;

        sent = 0;
        while (sent < message.size()) begin
            beat_bytes = message.size() - sent;
            if (beat_bytes > DATA_BYTE_NUM)
                beat_bytes = DATA_BYTE_NUM;

            input_data <= '0;
            for (int b = 0; b < beat_bytes; b++)
                input_data[b*8 +: 8] <= message[sent + b];
            input_valid <= 1'b1;

            forever begin
                @(posedge clk);
                if (input_ready) begin
                    if (input_core != assigned_core) begin
                        $error("Input routed to core %0d, expected %0d",
                               input_core, assigned_core);
                        errors++;
                    end
                    break;
                end
            end

            sent += beat_bytes;
            @(negedge clk);
            input_valid <= 1'b0;
            input_data <= '0;
        end
    endtask

    task automatic run_benchmark(
        input keccak_mode benchmark_mode,
        input int bytes_per_job,
        input string mode_name
    );
        byte unsigned msg0[];
        byte unsigned msg1[];
        int elapsed_cycles;
        real bytes_per_cycle;
        real throughput_gbps;
        int timeout;

        expected[0].delete();
        expected[1].delete();
        total_observed_bytes = 0;
        expected_total_bytes = 2 * bytes_per_job;
        first_accept_cycle = -1;
        final_output_cycle = -1;

        msg0 = new[32];
        msg1 = new[32];
        for (int i = 0; i < 32; i++) begin
            msg0[i] = byte'(i);
            msg1[i] = byte'(8'h80 + i);
        end

        reset_dut();
        send_job(benchmark_mode, msg0, bytes_per_job, 0);
        send_job(benchmark_mode, msg1, bytes_per_job, 1);

        timeout = 0;
        while ((total_observed_bytes < expected_total_bytes) &&
               (timeout < 100000)) begin
            @(posedge clk);
            timeout++;
        end

        if (timeout == 100000) begin
            $error("%s benchmark timeout", mode_name);
            errors++;
        end
        if ((expected[0].size() != 0) || (expected[1].size() != 0)) begin
            $error("%s expected queues not empty: core0=%0d core1=%0d",
                   mode_name, expected[0].size(), expected[1].size());
            errors++;
        end

        elapsed_cycles = final_output_cycle - first_accept_cycle + 1;
        bytes_per_cycle = real'(expected_total_bytes) / real'(elapsed_cycles);
        throughput_gbps = bytes_per_cycle * TARGET_CLOCK_MHZ / 1000.0;
        $display("THROUGHPUT_RESULT mode=%s bytes=%0d cycles=%0d bytes_per_cycle=%0.6f GBps_at_%0.2fMHz=%0.6f",
                 mode_name, expected_total_bytes, elapsed_cycles,
                 bytes_per_cycle, TARGET_CLOCK_MHZ, throughput_gbps);
        if (throughput_gbps < 1.0) begin
            $error("%s throughput target missed: %0.6f GB/s", mode_name,
                   throughput_gbps);
            errors++;
        end
    endtask

    initial begin
        cycle_count = 0;
        errors = 0;
        rst = 1'b1;
        initialize_signals();

        run_benchmark(SHAKE128, 65520, "SHAKE128");
        run_benchmark(SHAKE256, 65416, "SHAKE256");

        if (errors == 0)
            $display("DUAL_THROUGHPUT_PASS: both modes exceed 1 GB/s at %0.2f MHz with byte-exact outputs",
                     TARGET_CLOCK_MHZ);
        else
            $fatal(1, "DUAL_THROUGHPUT_FAIL: %0d errors", errors);
        test_done = 1'b1;
        if (AUTO_FINISH)
            $finish;
    end
endmodule

// Only elaborated simulation top. Netlist runs use the throughput checker;
// source-RTL runs also execute the direct-core and dual-wrapper regressions.
module tb_top;
`ifdef KECCAK_DUAL_NETLIST
    wire dual_throughput_done;
    tb_keccak_dual_throughput #(.AUTO_FINISH(1'b0)) u_dual_throughput (
        .test_done(dual_throughput_done)
    );
    initial begin
        wait (dual_throughput_done);
        $display("COMPLETE_KECCAK_NETLIST_PASS");
        $finish;
    end
`else
    wire uvm_core_done;
    wire dual_throughput_done;

    tb_keccak_uvm_core #(.AUTO_FINISH(1'b0)) u_uvm_core (
        .test_done(uvm_core_done)
    );
    tb_keccak_dual_throughput #(.AUTO_FINISH(1'b0)) u_dual_throughput (
        .test_done(dual_throughput_done)
    );

    initial begin
        uvm_report_server report_server;
        wait (uvm_core_done && dual_throughput_done);
        #1ns;
        report_server = uvm_report_server::get_server();
        if ((report_server.get_severity_count(UVM_ERROR) != 0) ||
            (report_server.get_severity_count(UVM_FATAL) != 0))
            $fatal(1, "COMPLETE_KECCAK_SUITE_FAIL: UVM reported errors");
        $display("COMPLETE_KECCAK_SUITE_PASS: 880 two-core UVM transactions plus all dual-interleaved regressions completed");
        $finish;
    end
`endif
endmodule
