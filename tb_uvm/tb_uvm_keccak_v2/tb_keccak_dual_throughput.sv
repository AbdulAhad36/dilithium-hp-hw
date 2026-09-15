`timescale 1ns/1ps

import keccak_pkg::*;
import keccak_ref_pkg::*;

module tb_keccak_dual_throughput;
    localparam int OUTPUT_DWIDTH = 128;
    localparam int OUTPUT_BYTES_PER_BEAT = OUTPUT_DWIDTH / 8;
    localparam int OUTPUT_BYTE_COUNT_WIDTH = $clog2(OUTPUT_BYTES_PER_BEAT + 1);
    localparam real TARGET_CLOCK_MHZ = 145.0;

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
        $display("THROUGHPUT_RESULT mode=%s bytes=%0d cycles=%0d bytes_per_cycle=%0.6f GBps_at_145MHz=%0.6f",
                 mode_name, expected_total_bytes, elapsed_cycles,
                 bytes_per_cycle, throughput_gbps);
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
            $display("DUAL_THROUGHPUT_PASS: both modes exceed 1 GB/s at 145 MHz with byte-exact outputs");
        else
            $fatal(1, "DUAL_THROUGHPUT_FAIL: %0d errors", errors);
        $finish;
    end
endmodule