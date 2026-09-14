/*
 * Module Name: theta_step
 * Author: Kiet Le
 * Description:
 * - Implements the θ (Theta) step mapping, the primary linear diffusion layer.
 * - Purpose: Mixes bits across the entire state array to propagate changes quickly.
 * - Operation (3 Stages):
 * 1. Column Parity (C): XORs all 5 lanes in each column (x) to verify parity.
 * 2. Mixing Delta (D): Computes a 'mask' by XORing the parity of the Left Neighbor (x-1)
 * with the Rotated Parity of the Right Neighbor (x+1).
 * 3. Application: XORs this mask (D) into every lane of the original column.
 * - Reference: FIPS 202 Section 3.2.1
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module theta_step (
    input   wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output  wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    // Column parity for each x coordinate.
    wire [4:0][LANE_SIZE-1:0] C;

    // Get Parities of each column
    // - From FIPS202: C[x, z] = A[x, 0, z] ⊕ A[x, 1, z] ⊕ A[x, 2, z] ⊕ A[x, 3, z] ⊕ A[x, 4, z]
    // - 5x64 grid array (each entry is a parity of the corresponding column)
    genvar x;
    generate
        for (x = 0; x<ROW_SIZE; x = x + 1) begin : compute_C
            assign C[x] = state_array_i[x][0] ^
                          state_array_i[x][1] ^
                          state_array_i[x][2] ^
                          state_array_i[x][3] ^
                          state_array_i[x][4];
        end
    endgenerate

    /* Calculate D[x] to mix neighboring column parities with rotation
     * - From FIPS202: D[x, z] = C[(x-1) mod 5, z] ⊕ C[(x+1) mod 5, (z – 1) mod w]
     * - For each column, compute a “delta” by XORing the parity of the previous ...
     *   column (mod 5) with a rotated parity of the next column.
     */
    /*
     * Compute final state array for theta step
     * - From FIPS202: A′[x, y, z] = A[x, y, z] ⊕ D[x, z]
     * - XOR this delta into each bit of the column
     */
    genvar y;
    generate
        for (x = 0; x<ROW_SIZE; x = x + 1) begin : gen_theta_x
            localparam int XM1 = (x == 0) ? 4 : x - 1;
            localparam int XP1 = (x == 4) ? 0 : x + 1;
            for (y = 0; y<COL_SIZE; y = y + 1) begin : gen_theta_y
                // Folding D into this expression removes a shared logic level.
                assign state_array_o[x][y] = state_array_i[x][y] ^
                    C[XM1] ^
                    {C[XP1][LANE_SIZE-2:0], C[XP1][LANE_SIZE-1]};
            end
        end
    endgenerate

endmodule

`default_nettype wire
