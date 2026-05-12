/*
 * Module Name: keccak_engine_parallel
 * Description:
 * - Wraps N_LANES independent keccak_core instances behind a single module
 *   boundary. Each lane has its own AXI4-Stream sink + source and its own
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
    input  keccak_mode                                   keccak_mode_i [N_LANES],
    input  wire  [N_LANES-1:0][XOF_LEN_WIDTH-1:0]        xof_len_i,
    input  wire  [N_LANES-1:0]                           stop_i,

    // Per-lane AXI4-Stream Sink (TB/master -> DUT)
    input  wire  [N_LANES-1:0][DWIDTH-1:0]               s_axis_tdata,
    input  wire  [N_LANES-1:0]                           s_axis_tvalid,
    input  wire  [N_LANES-1:0]                           s_axis_tlast,
    input  wire  [N_LANES-1:0][KEEP_WIDTH-1:0]           s_axis_tkeep,
    output wire  [N_LANES-1:0]                           s_axis_tready,

    // Per-lane AXI4-Stream Source (DUT -> TB/slave)
    output wire  [N_LANES-1:0][DWIDTH-1:0]               m_axis_tdata,
    output wire  [N_LANES-1:0]                           m_axis_tvalid,
    output wire  [N_LANES-1:0]                           m_axis_tlast,
    output wire  [N_LANES-1:0][KEEP_WIDTH-1:0]           m_axis_tkeep,
    input  wire  [N_LANES-1:0]                           m_axis_tready
);

    genvar i;
    generate
        for (i = 0; i < N_LANES; i = i + 1) begin : g_lane
            keccak_core u_core (
                .clk            (clk),
                .rst            (rst[i]),

                .start_i        (start_i[i]),
                .keccak_mode_i  (keccak_mode_i[i]),
                .xof_len_i      (xof_len_i[i]),
                .stop_i         (stop_i[i]),

                .s_axis_tdata   (s_axis_tdata[i]),
                .s_axis_tvalid  (s_axis_tvalid[i]),
                .s_axis_tlast   (s_axis_tlast[i]),
                .s_axis_tkeep   (s_axis_tkeep[i]),
                .s_axis_tready  (s_axis_tready[i]),

                .m_axis_tdata   (m_axis_tdata[i]),
                .m_axis_tvalid  (m_axis_tvalid[i]),
                .m_axis_tlast   (m_axis_tlast[i]),
                .m_axis_tkeep   (m_axis_tkeep[i]),
                .m_axis_tready  (m_axis_tready[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
