/*
 * Module Name: theta_step
 * Description: Implements the FIPS 202 Theta diffusion step.
 *
 * Three local copies of each column parity serve the five destination rows.
 * This limits parity fanout while allowing denser packing than full per-row
 * replication on Cyclone V.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module theta_step (
    input  wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    localparam int PARITY_COPIES = 3;

    (* keep = 1 *)
    wire [PARITY_COPIES-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] local_parity;

    genvar x;
    genvar y;
    genvar copy;
    generate
        for (copy = 0; copy < PARITY_COPIES; copy = copy + 1) begin : g_parity_copy
            for (x = 0; x < ROW_SIZE; x = x + 1) begin : g_parity
                assign local_parity[copy][x] = state_array_i[x][0] ^
                                               state_array_i[x][1] ^
                                               state_array_i[x][2] ^
                                               state_array_i[x][3] ^
                                               state_array_i[x][4];
            end
        end
    endgenerate

    generate
        for (x = 0; x < ROW_SIZE; x = x + 1) begin : g_theta_x
            localparam int XM1 = (x == 0) ? 4 : x - 1;
            localparam int XP1 = (x == 4) ? 0 : x + 1;
            for (y = 0; y < COL_SIZE; y = y + 1) begin : g_theta_y
                localparam int PARITY_COPY = y % PARITY_COPIES;
                assign state_array_o[x][y] = state_array_i[x][y] ^
                    local_parity[PARITY_COPY][XM1] ^
                    {local_parity[PARITY_COPY][XP1][LANE_SIZE-2:0],
                     local_parity[PARITY_COPY][XP1][LANE_SIZE-1]};
            end
        end
    endgenerate
endmodule

`default_nettype wire
