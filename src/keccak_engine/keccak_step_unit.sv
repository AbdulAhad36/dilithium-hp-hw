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
    input   wire                                              clk,
    input   wire                                              rst,
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    // Enable for operand isolation (Power optimization)
    input   wire                                              perm_en_i,
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
    // OPERAND ISOLATION (Power Optimization)
    // ==========================================================
    // Zero out the input to the entire round function when the
    // permutation is inactive to prevent toggling in the chain.
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_in_gated;
    assign state_in_gated = perm_en_i ? state_array_i : '0;

    // ==========================================================
    // PIPELINED ROUND:  θ → ρ → π  ||  [REG]  ||  χ → ι
    // ==========================================================
    // Stage A (combinational): theta + rho + pi
    // Stage B (combinational): chi + iota
    // A pipeline register (pi_out_reg) splits the two stages so each
    // half meets a tighter clock period at the cost of +1 cycle latency
    // per round. The keccak_core FSM dwells 2 cycles per round.

    // Stage A
    theta_step u_theta (.state_array_i(state_in_gated), .state_array_o(theta_out));
    rho_step   u_rho   (.state_array_i(theta_out),      .state_array_o(rho_out));
    pi_step    u_pi    (.state_array_i(rho_out),        .state_array_o(pi_out));

    // Pipeline register between stages
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pi_out_reg <= '0;
        end else begin
            pi_out_reg <= pi_out;
        end
    end

    // Stage B
    chi_step   u_chi   (.state_array_i(pi_out_reg),     .state_array_o(chi_out));
    iota_step  u_iota  (.state_array_i(chi_out),
                        .round_index_i(round_index_i),
                        .state_array_o(iota_out));

    assign state_array_o = iota_out;

endmodule

`default_nettype wire
