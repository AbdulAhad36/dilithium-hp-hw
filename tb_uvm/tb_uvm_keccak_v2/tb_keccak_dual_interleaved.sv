`timescale 1ns/1ps

import keccak_pkg::*;
import keccak_ref_pkg::*;

module tb_keccak_dual_interleaved;
    localparam int OUTPUT0_BYTES = 199;
    localparam int OUTPUT1_BYTES = 197;
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

    byte unsigned msg0[];
    byte unsigned msg1[];
    byte unsigned expected [2][$];
    byte unsigned observed [2][$];

    int cycle_count;
    int launch_cycle [2];
    int source_switches;
    int errors;
    bit previous_source_valid;
    bit previous_source;
    bit stalled_previous_cycle;
    bit forced_stall_started;
    bit simultaneous_stall_seen;
    int forced_stall_remaining;
    logic [OUTPUT_DWIDTH-1:0] stalled_data;
    logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] stalled_bytes;
    logic stalled_core;

    keccak_dual_interleaved #(
        .START_OFFSET_CYCLES(26),
        .OUTPUT_DWIDTH(OUTPUT_DWIDTH)
    ) dut (
        .clk                (clk),
        .rst                (rst),
        .request_valid_i    (request_valid),
        .request_ready_o    (request_ready),
        .request_core_o     (request_core),
        .keccak_mode_i      (mode),
        .message_len_i      (message_len),
        .output_len_i       (output_len),
        .input_data_i       (input_data),
        .input_valid_i      (input_valid),
        .input_ready_o      (input_ready),
        .input_core_o       (input_core),
        .stop_i             (stop),
        .core_busy_o        (core_busy),
        .core_done_o        (core_done),
        .busy_o             (busy),
        .output_data_o      (output_data),
        .output_valid_o     (output_valid),
        .output_bytes_o     (output_bytes),
        .output_core_o      (output_core),
        .output_ready_i     (output_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (!rst && stalled_previous_cycle) begin
            if (!output_valid || (output_data !== stalled_data) ||
                (output_bytes !== stalled_bytes) ||
                (output_core !== stalled_core)) begin
                $error("Output changed while backpressured");
                errors++;
            end
        end

        if (!rst && !output_ready && (&dut.core_output_valid))
            simultaneous_stall_seen <= 1'b1;

        if (!rst && output_valid && !output_ready) begin
            stalled_previous_cycle <= 1'b1;
            stalled_data <= output_data;
            stalled_bytes <= output_bytes;
            stalled_core <= output_core;
        end else begin
            stalled_previous_cycle <= 1'b0;
        end

        if (!rst && output_valid && output_ready) begin
            if (output_bytes == 0 || output_bytes > OUTPUT_BYTES_PER_BEAT) begin
                $error("Illegal output byte count %0d", output_bytes);
                errors++;
            end
            for (int b = 0; b < output_bytes; b++)
                observed[output_core].push_back(output_data[b*8 +: 8]);

            if (previous_source_valid && (previous_source != output_core))
                source_switches++;
            previous_source <= output_core;
            previous_source_valid <= 1'b1;
        end
    end

    always @(negedge clk) begin
        if (rst) begin
            output_ready <= 1'b0;
            forced_stall_started <= 1'b0;
            forced_stall_remaining <= 0;
        end else if (!forced_stall_started && output_valid) begin
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

    task automatic send_job(
        input keccak_mode job_mode,
        input byte unsigned message[],
        input int requested_bytes,
        output bit assigned_core
    );
        int sent;
        int beat_bytes;

        @(negedge clk);
        request_valid <= 1'b1;
        mode <= job_mode;
        message_len <= message.size();
        output_len <= requested_bytes;

        forever begin
            @(posedge clk);
            if (request_ready) begin
                assigned_core = request_core;
                launch_cycle[assigned_core] = cycle_count;
                break;
            end
        end

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
                        $error("Input routed to core %0d, expected core %0d",
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

    initial begin
        bit assigned0;
        bit assigned1;
        int timeout;

        cycle_count = 0;
        errors = 0;
        source_switches = 0;
        previous_source_valid = 0;
        stalled_previous_cycle = 0;
        forced_stall_started = 0;
        simultaneous_stall_seen = 0;
        forced_stall_remaining = 0;
        request_valid = 0;
        mode = SHAKE128;
        message_len = 0;
        output_len = 0;
        input_data = '0;
        input_valid = 0;
        output_ready = 0;
        stop = '0;
        rst = 1;

        msg0 = new[8];
        msg1 = new[16];
        for (int i = 0; i < msg0.size(); i++)
            msg0[i] = byte'(8'h10 + i);
        for (int i = 0; i < msg1.size(); i++)
            msg1[i] = byte'(8'h80 + i);

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 0;

        send_job(SHAKE128, msg0, OUTPUT0_BYTES, assigned0);
        send_job(SHAKE256, msg1, OUTPUT1_BYTES, assigned1);

        if (assigned0 == assigned1) begin
            $error("Consecutive jobs were not dispatched to different cores");
            errors++;
        end
        if ((launch_cycle[assigned1] - launch_cycle[assigned0]) != 26) begin
            $error("Launch offset was %0d cycles, expected 26",
                   launch_cycle[assigned1] - launch_cycle[assigned0]);
            errors++;
        end

        shake_compute(SHAKE128, msg0, OUTPUT0_BYTES, expected[assigned0]);
        shake_compute(SHAKE256, msg1, OUTPUT1_BYTES, expected[assigned1]);

        timeout = 0;
        while (((observed[assigned0].size() < OUTPUT0_BYTES) ||
                (observed[assigned1].size() < OUTPUT1_BYTES)) &&
               (timeout < 2000)) begin
            @(posedge clk);
            timeout++;
        end

        if (timeout == 2000) begin
            $error("Timed out waiting for both interleaved output streams");
            errors++;
        end

        for (int core = 0; core < 2; core++) begin
            if (observed[core].size() != expected[core].size()) begin
                $error("Core %0d output size: got %0d expected %0d", core,
                       observed[core].size(), expected[core].size());
                errors++;
            end else begin
                for (int i = 0; i < expected[core].size(); i++) begin
                    if (observed[core][i] !== expected[core][i]) begin
                        $error("Core %0d byte %0d: got %02x expected %02x",
                               core, i, observed[core][i], expected[core][i]);
                        errors++;
                        break;
                    end
                end
            end
        end

        if (!simultaneous_stall_seen) begin
            $error("Did not exercise simultaneous valid outputs under backpressure");
            errors++;
        end

        if (source_switches < 2) begin
            $error("Output did not interleave sufficiently; switches=%0d",
                   source_switches);
            errors++;
        end

        wait (!busy);
        repeat (3) @(posedge clk);
        if (errors == 0)
            $display("DUAL_INTERLEAVED_PASS: SHAKE128/SHAKE256, 26-cycle offset, tagged output, and backpressure verified");
        else
            $fatal(1, "DUAL_INTERLEAVED_FAIL: %0d errors", errors);
        $finish;
    end

endmodule
