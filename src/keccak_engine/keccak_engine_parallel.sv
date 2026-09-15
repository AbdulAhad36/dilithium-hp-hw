/*
 * Module Name: keccak_engine_parallel
 * Description:
 * DEPRECATED: retained for historical regression compatibility.
 * The active architecture is keccak_dual_interleaved.
 *
 * - Wraps N_LANES independent keccak_core instances behind a single module
 *   boundary. Each lane has its own protocol-neutral word input/output and
 *   reset/start/stop control, so all lanes run fully in parallel.
 * - Targets Dilithium use cases where many independent SHAKE streams are
 *   needed:
 *     * ExpandA  - k*l = up to 56 independent SHAKE128 streams (Dilithium-5)
 *     * ExpandS  - L + K independent SHAKE256 streams
 *     * ExpandMask, H - additional SHAKE256 streams
 * - The wrapper is intentionally thin: no arbitration, no scheduler. A higher
 *   level controller (or testbench) dispatches work to each lane and collects
 *   the output streams. This keeps the wrapper synthesis-friendly and lets
 *   the user trade area vs throughput by changing N_LANES.
 *
 * Throughput (rough, vs single-core baseline):
 *   N_LANES=1  -> 1x (equivalent to instantiating keccak_core directly)
 *   N_LANES=4  -> 4x peak SHAKE throughput (when all lanes busy)
 *   N_LANES=8  -> 8x peak SHAKE throughput
 *
 * Area cost is approximately linear in N_LANES (each lane replicates the full
 * 1600-bit state + datapath). Critical path is unchanged from keccak_core, so
 * Fmax should not regress.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_engine_parallel #(
    parameter int N_LANES = 4
) (
    input  wire                                          clk,

    // Per-lane control (one bit per lane)
    input  wire  [N_LANES-1:0]                           rst,
    input  wire  [N_LANES-1:0]                           start_i,
    input  wire [0:0]                                    keccak_mode_i [N_LANES],
    input  wire  [N_LANES-1:0][MSG_LEN_WIDTH-1:0]        message_len_i,
    input  wire  [N_LANES-1:0][XOF_LEN_WIDTH-1:0]        output_len_i,
    input  wire  [N_LANES-1:0]                           stop_i,
    output wire  [N_LANES-1:0]                           busy_o,
    output wire  [N_LANES-1:0]                           done_o,

    input  wire  [N_LANES-1:0][DWIDTH-1:0]               input_data_i,
    input  wire  [N_LANES-1:0]                           input_valid_i,
    output wire  [N_LANES-1:0]                           input_ready_o,

    output wire  [N_LANES-1:0][DWIDTH-1:0]               output_data_o,
    output wire  [N_LANES-1:0]                           output_valid_o,
    output wire  [N_LANES-1:0][BYTE_COUNT_WIDTH-1:0]     output_bytes_o,
    input  wire  [N_LANES-1:0]                           output_ready_i
);

    genvar i;
    generate
        for (i = 0; i < N_LANES; i = i + 1) begin : g_lane
            keccak_core u_core (
                .clk            (clk),
                .rst            (rst[i]),

                .start_i        (start_i[i]),
                .keccak_mode_i  (keccak_mode_i[i]),
                .message_len_i  (message_len_i[i]),
                .output_len_i   (output_len_i[i]),
                .stop_i         (stop_i[i]),
                .busy_o         (busy_o[i]),
                .done_o         (done_o[i]),

                .input_data_i   (input_data_i[i]),
                .input_valid_i  (input_valid_i[i]),
                .input_ready_o  (input_ready_o[i]),

                .output_data_o  (output_data_o[i]),
                .output_valid_o (output_valid_o[i]),
                .output_bytes_o (output_bytes_o[i]),
                .output_ready_i (output_ready_i[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
