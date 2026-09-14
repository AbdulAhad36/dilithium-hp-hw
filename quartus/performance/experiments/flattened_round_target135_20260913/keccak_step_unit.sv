/*
 * Module Name: keccak_step_unit
 * Author: Kiet Le
 * Description:
 * - Acts as the primary Combinational Logic block (ALU) for the Keccak Core.
 * - Chains all five Keccak permutation step mappings in series to execute
 *   one complete round per clock cycle:
 *     θ (Theta) → ρ (Rho) → π (Pi) → χ (Chi) → ι (Iota)
 * - Critical Path: Theta (~5 gate levels) + Chi (~2 gate levels) = ~7 gate levels.
 *   Rho, Pi are pure wire routing (0 gates). Iota merges into Chi for lane[0][0].
 * - This architecture is the industry standard for Keccak-f[1600] accelerators
 *   and comfortably meets timing on modern FPGAs (3 LUT levels) and ASICs.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_step_unit (
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    // Current round index (0-23)
    input   wire  [ROUND_INDEX_SIZE-1:0]                      round_index_i,

    output  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    // Keep the named intermediate states visible to the assertion checker while
    // describing the round in one synthesis boundary.
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0]   theta_out,
                                                        rho_out,
                                                        pi_out,
                                                        chi_out,
                                                        iota_out;

    // ==========================================================
    // PIPELINED ROUND:  θ → ρ → π  ||  [REG]  ||  χ → ι
    // ==========================================================
    // All five FIPS 202 steps form one combinational round.
    logic [ROW_SIZE-1:0][LANE_SIZE-1:0] column_parity;

    localparam int RHO_OFFSETS [ROW_SIZE][COL_SIZE] = '{
        '{  0, 36,  3, 41, 18 },
        '{  1, 44, 10, 45,  2 },
        '{ 62,  6, 43, 15, 61 },
        '{ 28, 55, 25, 21, 56 },
        '{ 27, 20, 39,  8, 14 }
    };

    function automatic logic [LANE_SIZE-1:0] round_constant(
        input logic [ROUND_INDEX_SIZE-1:0] round_index
    );
        case (round_index)
            5'd0:  round_constant = 64'h0000000000000001;
            5'd1:  round_constant = 64'h0000000000008082;
            5'd2:  round_constant = 64'h800000000000808a;
            5'd3:  round_constant = 64'h8000000080008000;
            5'd4:  round_constant = 64'h000000000000808b;
            5'd5:  round_constant = 64'h0000000080000001;
            5'd6:  round_constant = 64'h8000000080008081;
            5'd7:  round_constant = 64'h8000000000008009;
            5'd8:  round_constant = 64'h000000000000008a;
            5'd9:  round_constant = 64'h0000000000000088;
            5'd10: round_constant = 64'h0000000080008009;
            5'd11: round_constant = 64'h000000008000000a;
            5'd12: round_constant = 64'h000000008000808b;
            5'd13: round_constant = 64'h800000000000008b;
            5'd14: round_constant = 64'h8000000000008089;
            5'd15: round_constant = 64'h8000000000008003;
            5'd16: round_constant = 64'h8000000000008002;
            5'd17: round_constant = 64'h8000000000000080;
            5'd18: round_constant = 64'h000000000000800a;
            5'd19: round_constant = 64'h800000008000000a;
            5'd20: round_constant = 64'h8000000080008081;
            5'd21: round_constant = 64'h8000000000008080;
            5'd22: round_constant = 64'h0000000080000001;
            5'd23: round_constant = 64'h8000000080008008;
            default: round_constant = '0;
        endcase
    endfunction

    genvar x, y;
    generate
        for (x = 0; x < ROW_SIZE; x = x + 1) begin : g_parity
            assign column_parity[x] = state_array_i[x][0] ^
                                      state_array_i[x][1] ^
                                      state_array_i[x][2] ^
                                      state_array_i[x][3] ^
                                      state_array_i[x][4];
        end

        for (x = 0; x < ROW_SIZE; x = x + 1) begin : g_round_x
            localparam int XM1 = (x == 0) ? 4 : x - 1;
            localparam int XP1 = (x == 4) ? 0 : x + 1;
            for (y = 0; y < COL_SIZE; y = y + 1) begin : g_round_y
                localparam int SHIFT = RHO_OFFSETS[x][y];
                localparam int PI_SRC_X = (x + 3*y) % 5;
                localparam int PI_SRC_Y = x;
                localparam int CHI_XP1 = (x + 1) % 5;
                localparam int CHI_XP2 = (x + 2) % 5;

                assign theta_out[x][y] = state_array_i[x][y] ^
                    column_parity[XM1] ^
                    {column_parity[XP1][LANE_SIZE-2:0],
                     column_parity[XP1][LANE_SIZE-1]};

                if (SHIFT == 0) begin : g_no_rotate
                    assign rho_out[x][y] = theta_out[x][y];
                end else begin : g_rotate
                    assign rho_out[x][y] =
                        {theta_out[x][y][LANE_SIZE-SHIFT-1:0],
                         theta_out[x][y][LANE_SIZE-1:LANE_SIZE-SHIFT]};
                end

                assign pi_out[x][y] = rho_out[PI_SRC_X][PI_SRC_Y];
                assign chi_out[x][y] = pi_out[x][y] ^
                    (~pi_out[CHI_XP1][y] & pi_out[CHI_XP2][y]);
                assign iota_out[x][y] = ((x == 0) && (y == 0)) ?
                    (chi_out[x][y] ^ round_constant(round_index_i)) :
                    chi_out[x][y];
            end
        end
    endgenerate

    assign state_array_o = iota_out;

endmodule

`default_nettype wire
