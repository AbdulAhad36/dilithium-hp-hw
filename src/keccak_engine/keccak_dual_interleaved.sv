/*
 * Two-core interleaved SHAKE engine.
 *
 * Jobs arrive on one command/input stream and are dispatched alternately to
 * two independent keccak_core instances. Consecutive launches are separated
 * by START_OFFSET_CYCLES so that one core can absorb while the other is in its
 * permutation phase. Output words share one tagged, round-robin stream.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_dual_interleaved #(
    parameter int START_OFFSET_CYCLES = 26,
    parameter int OUTPUT_DWIDTH = 128,
    parameter int OUTPUT_BYTES = OUTPUT_DWIDTH / 8,
    parameter int OUTPUT_BYTE_COUNT_WIDTH = $clog2(OUTPUT_BYTES + 1)
) (
    input  wire                             clk,
    input  wire                             rst,

    input  wire                             request_valid_i,
    output logic                            request_ready_o,
    output logic                            request_core_o,
    input  wire [0:0]                       keccak_mode_i,
    input  wire [MSG_LEN_WIDTH-1:0]         message_len_i,
    input  wire [XOF_LEN_WIDTH-1:0]         output_len_i,

    input  wire [DWIDTH-1:0]                input_data_i,
    input  wire                             input_valid_i,
    output logic                            input_ready_o,
    output logic                            input_core_o,

    input  wire [1:0]                       stop_i,
    output wire [1:0]                       core_busy_o,
    output wire [1:0]                       core_done_o,
    output wire                             busy_o,

    output logic [OUTPUT_DWIDTH-1:0]        output_data_o,
    output logic                            output_valid_o,
    output logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] output_bytes_o,
    output logic                            output_core_o,
    input  wire                             output_ready_i
);
    localparam int OFFSET_COUNT_WIDTH =
        (START_OFFSET_CYCLES <= 1) ? 1 : $clog2(START_OFFSET_CYCLES);

    logic [1:0] core_start;
    logic [1:0] core_input_ready;
    logic [1:0] core_input_valid;
    logic [1:0][DWIDTH-1:0] core_input_data;
    logic [1:0] core_output_valid;
    logic [1:0][OUTPUT_DWIDTH-1:0] core_output_data;
    logic [1:0][OUTPUT_BYTE_COUNT_WIDTH-1:0] core_output_bytes;
    logic [1:0] core_output_ready;

    logic dispatch_preference;
    logic dispatch_core;
    logic ingress_active;
    logic ingress_core;
    logic [MSG_LEN_WIDTH-1:0] ingress_bytes_remaining;
    logic arbiter_turn;
    logic arbiter_locked;
    logic locked_output_core;
    logic selected_output_core;
    logic [OFFSET_COUNT_WIDTH-1:0] offset_count;

    wire request_accept = request_valid_i && request_ready_o;
    wire input_accept = input_valid_i && input_ready_o;

    assign busy_o = |core_busy_o;

    always_comb begin
        if (!core_busy_o[dispatch_preference])
            dispatch_core = dispatch_preference;
        else
            dispatch_core = ~dispatch_preference;

        request_core_o = dispatch_core;
        request_ready_o = !ingress_active && (offset_count == '0) &&
                          (!core_busy_o[0] || !core_busy_o[1]);

        core_start = '0;
        if (request_accept)
            core_start[dispatch_core] = 1'b1;
    end

    always_comb begin
        input_ready_o = 1'b0;
        input_core_o = ingress_core;
        if (ingress_active)
            input_ready_o = !core_input_valid[ingress_core] |
                            core_input_ready[ingress_core];
    end

    always_comb begin
        if (arbiter_locked)
            selected_output_core = locked_output_core;
        else if (core_output_valid == 2'b01)
            selected_output_core = 1'b0;
        else if (core_output_valid == 2'b10)
            selected_output_core = 1'b1;
        else
            selected_output_core = arbiter_turn;

        output_core_o = selected_output_core;
        output_data_o = core_output_data[selected_output_core];
        output_bytes_o = core_output_bytes[selected_output_core];
        output_valid_o = core_output_valid[selected_output_core];

        core_output_ready = '0;
        if (output_valid_o)
            core_output_ready[selected_output_core] = output_ready_i;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dispatch_preference <= 1'b0;
            ingress_active <= 1'b0;
            ingress_core <= 1'b0;
            ingress_bytes_remaining <= '0;
            core_input_valid <= '0;
            core_input_data <= '0;
            arbiter_turn <= 1'b0;
            arbiter_locked <= 1'b0;
            locked_output_core <= 1'b0;
            offset_count <= '0;
        end else begin
            for (int input_core = 0; input_core < 2; input_core++) begin
                if (core_input_valid[input_core] &
                    core_input_ready[input_core])
                    core_input_valid[input_core] <= 1'b0;
            end

            if (request_accept) begin
                dispatch_preference <= ~dispatch_core;
                ingress_core <= dispatch_core;
                ingress_bytes_remaining <= message_len_i;
                ingress_active <= (message_len_i != 0);
                if (START_OFFSET_CYCLES > 1)
                    offset_count <= OFFSET_COUNT_WIDTH'(START_OFFSET_CYCLES - 1);
                else
                    offset_count <= '0;
            end else if (offset_count != '0) begin
                offset_count <= offset_count - 1'b1;
            end

            if (input_accept) begin
                core_input_valid[ingress_core] <= 1'b1;
                core_input_data[ingress_core] <= input_data_i;
                if (ingress_bytes_remaining <= DATA_BYTE_NUM) begin
                    ingress_bytes_remaining <= '0;
                    ingress_active <= 1'b0;
                end else begin
                    ingress_bytes_remaining <= ingress_bytes_remaining -
                                               MSG_LEN_WIDTH'(DATA_BYTE_NUM);
                end
            end

            if (output_valid_o && output_ready_i) begin
                arbiter_turn <= ~selected_output_core;
                arbiter_locked <= 1'b0;
            end else if (output_valid_o) begin
                arbiter_locked <= 1'b1;
                locked_output_core <= selected_output_core;
            end
        end
    end

    genvar core;
    generate
        for (core = 0; core < 2; core = core + 1) begin : g_core
            keccak_core #(
                .OUTPUT_DWIDTH          (OUTPUT_DWIDTH),
                .OUTPUT_BYTES           (OUTPUT_BYTES),
                .OUTPUT_BYTE_COUNT_WIDTH(OUTPUT_BYTE_COUNT_WIDTH)
            ) u_core (
                .clk            (clk),
                .rst            (rst),
                .start_i        (core_start[core]),
                .keccak_mode_i  (keccak_mode_i),
                .message_len_i  (message_len_i),
                .output_len_i   (output_len_i),
                .stop_i         (stop_i[core]),
                .busy_o         (core_busy_o[core]),
                .done_o         (core_done_o[core]),
                .input_data_i   (core_input_data[core]),
                .input_valid_i  (core_input_valid[core]),
                .input_ready_o  (core_input_ready[core]),
                .output_data_o  (core_output_data[core]),
                .output_valid_o (core_output_valid[core]),
                .output_bytes_o (core_output_bytes[core]),
                .output_ready_i (core_output_ready[core])
                );
        end
    endgenerate
endmodule

`default_nettype wire
