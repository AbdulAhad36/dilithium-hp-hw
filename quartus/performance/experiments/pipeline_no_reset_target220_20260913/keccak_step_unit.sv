/*
 * Module Name: keccak_step_unit
 * Author: Kiet Le
 * Description:
 * - Acts as the primary Combinational Logic block (ALU) for the Keccak Core.
 * - Splits the five Keccak permutation step mappings across two clock cycles:
 *     θ (Theta) → ρ (Rho) → π (Pi) → χ (Chi) → ι (Iota)
 * - Stage A contains theta/rho/pi; stage B contains chi/iota.
 * - Rho and pi are fixed wiring permutations.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_step_unit (
    input   wire                                              clk,
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    // Current round index (0-23)
    input   wire  [ROUND_INDEX_SIZE-1:0]                      round_index_i,

    output  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    // Intermediate wires between chained steps
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0]   theta_out,
                                                        rho_out,
                                                        pi_out,
                                                        pi_out_reg,
                                                        chi_out,
                                                        iota_out;

    // ==========================================================
    // PIPELINED ROUND:  θ → ρ → π  ||  [REG]  ||  χ → ι
    // ==========================================================
    // Stage A: linear diffusion and fixed lane routing.
    theta_step u_theta (.state_array_i(state_array_i),  .state_array_o(theta_out));
    rho_step   u_rho   (.state_array_i(theta_out),      .state_array_o(rho_out));
    pi_step    u_pi    (.state_array_i(rho_out),        .state_array_o(pi_out));

    // This register is intentionally not reset. The core always executes a
    // fill cycle before consuming it, avoiding a 1,600-bit reset network.
    always_ff @(posedge clk) begin
        pi_out_reg <= pi_out;
    end

    // Stage B: non-linear row mapping and round-constant injection.
    chi_step   u_chi   (.state_array_i(pi_out_reg),     .state_array_o(chi_out));
    iota_step  u_iota  (.state_array_i(chi_out),
                        .round_index_i(round_index_i),
                        .state_array_o(iota_out));

    assign state_array_o = iota_out;

endmodule

`default_nettype wire
