`timescale 1ns/1ps

import keccak_pkg::*;
import keccak_ref_pkg::*;

module tb_keccak_dual_coverage;
    localparam int OUTPUT_DWIDTH = 128;
    localparam int OUTPUT_BYTES_PER_BEAT = OUTPUT_DWIDTH / 8;
    localparam int OUTPUT_BYTE_COUNT_WIDTH = $clog2(OUTPUT_BYTES_PER_BEAT + 1);

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
    bit saw_rate_tail [2];

    covergroup core_functional_cg with function sample(
        int mode_v,
        int message_class,
        int output_class,
        int stall_class,
        int final_beat_class,
        bit rate_tail_seen,
        bit multi_absorb,
        bit multi_squeeze
    );
        option.per_instance = 1;

        cp_mode : coverpoint mode_v {
            bins shake128 = {0};
            bins shake256 = {1};
        }
        cp_message : coverpoint message_class {
            bins empty = {0};
            bins short_unaligned = {1};
            bins word_aligned = {2};
            bins rate_minus_one = {3};
            bins rate_exact = {4};
            bins rate_plus_one = {5};
            bins multi_rate = {6};
        }
        cp_output : coverpoint output_class {
            bins tiny = {0};
            bins full_beat = {1};
            bins partial_after_beat = {2};
            bins rate_minus_one = {3};
            bins rate_exact = {4};
            bins rate_plus_one = {5};
            bins multi_rate = {6};
        }
        cp_stall : coverpoint stall_class {
            bins none = {0};
            bins periodic = {1};
            bins burst = {2};
        }
        cp_final_beat : coverpoint final_beat_class {
            bins full = {0};
            bins eight_bytes = {1};
            bins other_partial = {2};
        }
        cp_rate_tail : coverpoint rate_tail_seen {
            bins absent = {0};
            bins observed = {1};
        }
        cp_multi_absorb : coverpoint multi_absorb {
            bins single_block = {0};
            bins multiple_blocks = {1};
        }
        cp_multi_squeeze : coverpoint multi_squeeze {
            bins single_block = {0};
            bins multiple_blocks = {1};
        }

        cross_mode_message : cross cp_mode, cp_message;
        cross_mode_output : cross cp_mode, cp_output;
        cross_mode_stall : cross cp_mode, cp_stall;
    endgroup

    covergroup interleaved_functional_cg with function sample(
        int mode_pair,
        int stall_class,
        int launch_gap_class,
        bit output_overlap,
        bit output_stall_seen,
        bit simultaneous_stall_seen,
        int source_switch_class,
        bit request_wait_seen,
        int first_core
    );
        cp_mode_pair : coverpoint mode_pair {
            bins both_shake128 = {0};
            bins both_shake256 = {1};
            bins mixed = {2};
        }
        cp_stall : coverpoint stall_class {
            bins none = {0};
            bins periodic = {1};
            bins burst = {2};
        }
        cp_launch_gap : coverpoint launch_gap_class {
            bins exact_offset = {0};
            bins ingress_delayed = {1};
        }
        cp_output_overlap : coverpoint output_overlap {
            bins absent = {0};
            bins observed = {1};
        }
        cp_output_stall : coverpoint output_stall_seen {
            bins absent = {0};
            bins observed = {1};
        }
        cp_simultaneous_stall : coverpoint simultaneous_stall_seen {
            bins absent = {0};
            bins observed = {1};
        }
        cp_source_switches : coverpoint source_switch_class {
            bins one = {1};
            bins multiple = {2};
        }
        cp_request_wait : coverpoint request_wait_seen {
            bins immediate = {0};
            bins backpressured = {1};
        }
        cp_first_core : coverpoint first_core {
            bins core0 = {0};
            bins core1 = {1};
        }

        cross_mode_stall : cross cp_mode_pair, cp_stall;
        cross_first_mode_pair : cross cp_first_core, cp_mode_pair;
    endgroup

    core_functional_cg core_cov [2];
    interleaved_functional_cg dual_cov;

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
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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
        if (!rst & (&dut.core_output_valid))
            pair_output_overlap <= 1'b1;
        if (!rst & output_valid & !output_ready) begin
            pair_output_stall <= 1'b1;
            if (&dut.core_output_valid)
                pair_simultaneous_stall <= 1'b1;
        end
        if (!rst & output_valid & output_ready) begin
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
        if (rst) begin
            output_ready <= 1'b0;
        end else begin
            case (stall_profile)
                0: output_ready <= 1'b1;
                1: output_ready <= ((cycle_count % 5) != 2);
                2: output_ready <= !((cycle_count - pair_start_cycle >= 28) &
                                     (cycle_count - pair_start_cycle < 68));
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
        for (int core = 0; core < 2; core++)
            core_cov[core] = new();
        dual_cov = new();
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
        rst = 1;
        for (int core = 0; core < 2; core++) begin
            output_position[core] = 0;
            core_rate[core] = 168;
            last_output_bytes[core] = 0;
            saw_rate_tail[core] = 0;
        end

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 0;

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

        repeat (3) @(posedge clk);
        if ((core_cov[0].get_inst_coverage() < 80.0) |
            (core_cov[1].get_inst_coverage() < 80.0) |
            (dual_cov.get_inst_coverage() < 80.0)) begin
            $error;
            errors++;
        end
        if (accepted_jobs != checked_jobs) begin
            $error;
            errors++;
        end
        if (errors != 0)
            $fatal;
        $display("DUAL_COVERAGE_PASS: jobs=%0d core0=%0.2f%% core1=%0.2f%% interleaved=%0.2f%%",
                 checked_jobs,
                 core_cov[0].get_inst_coverage(),
                 core_cov[1].get_inst_coverage(),
                 dual_cov.get_inst_coverage());
        $finish;
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
            core_cov[core_id].sample(
                int'(job_mode),
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

        wait (!busy);
        repeat (2) @(posedge clk);
        pair_start_cycle = cycle_count;
        stall_profile = profile;
        pair_source_switches = 0;
        pair_output_overlap = 1'b0;
        pair_output_stall = 1'b0;
        pair_simultaneous_stall = 1'b0;
        pair_request_wait = 1'b0;
        previous_source_valid = 1'b0;

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
        mode_pair = (mode0 == mode1) ?
                    ((mode0 == SHAKE128) ? 0 : 1) : 2;
        switch_class = (pair_source_switches <= 1) ? 1 : 2;
        dual_cov.sample(
            mode_pair,
            profile,
            (gap == 26) ? 0 : 1,
            pair_output_overlap,
            pair_output_stall,
            pair_simultaneous_stall,
            switch_class,
            pair_request_wait,
            assigned0
        );
    endtask
endmodule
