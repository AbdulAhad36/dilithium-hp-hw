`default_nettype none
`timescale 1ns/1ps

import keccak_pkg::*;

module mldsa_osh_keccak_parallel #(
    parameter int N_LANES = 4
) (
    input  wire                                       clk,
    input  wire [N_LANES-1:0]                         rst,
    input  wire [N_LANES-1:0]                         start_i,
    input  wire [0:0]                                 keccak_mode_i [N_LANES],
    input  wire [N_LANES-1:0][MSG_LEN_WIDTH-1:0]      message_len_i,
    input  wire [N_LANES-1:0][XOF_LEN_WIDTH-1:0]      output_len_i,
    input  wire [N_LANES-1:0]                         stop_i,
    output wire  [N_LANES-1:0]                        busy_o,
    output wire  [N_LANES-1:0]                        done_o,
    input  wire [N_LANES-1:0][DWIDTH-1:0]             input_data_i,
    input  wire [N_LANES-1:0]                         input_valid_i,
    output wire  [N_LANES-1:0]                        input_ready_o,
    output wire  [N_LANES-1:0][DWIDTH-1:0]            output_data_o,
    output wire  [N_LANES-1:0]                        output_valid_o,
    output wire  [N_LANES-1:0][BYTE_COUNT_WIDTH-1:0]  output_bytes_o,
    input  wire [N_LANES-1:0]                         output_ready_i
);
    for (genvar i = 0; i < N_LANES; i++) begin : g_lane

        mldsa_osh_keccak_adapter u_core (
            .clk(clk),
            .rst(rst[i]),
            .start_i(start_i[i]),
            .keccak_mode_i(keccak_mode_i[i]),
            .message_len_i(message_len_i[i]),
            .output_len_i(output_len_i[i]),
            .stop_i(stop_i[i]),
            .busy_o(busy_o[i]),
            .done_o(done_o[i]),
            .input_data_i(input_data_i[i]),
            .input_valid_i(input_valid_i[i]),
            .input_ready_o(input_ready_o[i]),
            .output_data_o(output_data_o[i]),
            .output_valid_o(output_valid_o[i]),
            .output_bytes_o(output_bytes_o[i]),
            .output_ready_i(output_ready_i[i])
        );
    end
endmodule

`default_nettype wire
