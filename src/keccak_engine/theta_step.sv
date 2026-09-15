/*
 * Module Name: theta_step
 * Description: Implements the FIPS 202 Theta diffusion step.
 *
 * A local copy of each column parity is generated for every destination row.
 * The replicated logic trades area for shorter local routing on Cyclone V.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module theta_step (
    input  wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    (* keep = 1 *)
    wire [COL_SIZE-1:0][ROW_SIZE-1:0][LANE_SIZE-1:0] local_parity;

    genvar x;
    genvar y;
    generate
        for (y = 0; y < COL_SIZE; y = y + 1) begin : g_parity_copy
            for (x = 0; x < ROW_SIZE; x = x + 1) begin : g_parity
                assign local_parity[y][x] = state_array_i[x][0] ^
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
                assign state_array_o[x][y] = state_array_i[x][y] ^
                    local_parity[y][XM1] ^
                    {local_parity[y][XP1][LANE_SIZE-2:0],
                     local_parity[y][XP1][LANE_SIZE-1]};
            end
        end
    endgenerate
endmodule

`default_nettype wire