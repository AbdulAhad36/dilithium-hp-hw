// Flat, single-core boundary shared by source and post-synthesis simulation.
`timescale 1ns/1ps
module keccak_synth_top (
    input wire clk, rst, start_i, mode_i, stop_i,
    input wire [15:0] message_len_i, output_len_i,
    input wire [63:0] input_data_i,
    input wire input_valid_i, output_ready_i,
    output wire busy_o, done_o, input_ready_o,
    output wire [63:0] output_data_o,
    output wire output_valid_o,
    output wire [3:0] output_bytes_o
);
    import keccak_pkg::*;
    keccak_mode mode;
    assign mode = mode_i ? SHAKE256 : SHAKE128;
    keccak_core u_core (
        .clk(clk), .rst(rst), .start_i(start_i), .keccak_mode_i(mode),
        .message_len_i(message_len_i), .output_len_i(output_len_i),
        .stop_i(stop_i), .busy_o(busy_o), .done_o(done_o),
        .input_data_i(input_data_i), .input_valid_i(input_valid_i),
        .input_ready_o(input_ready_o), .output_data_o(output_data_o),
        .output_valid_o(output_valid_o), .output_bytes_o(output_bytes_o),
        .output_ready_i(output_ready_i)
    );
endmodule
