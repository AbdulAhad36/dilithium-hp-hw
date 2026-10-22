/*
 * Module Name: keccak_step_unit
 * Description:
 * - Implements one complete Keccak-f[1600] round combinationally.
 * - Chains theta, rho, pi, chi, and iota in specification order.
 * - Rho and pi are fixed wiring permutations.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_step_unit (
    input logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input wire [ROUND_INDEX_SIZE-1:0] round_index_i,
    output logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] theta_out;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] rho_out;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] pi_out;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] chi_out;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] iota_out;

    theta_step u_theta (.state_array_i(state_array_i), .state_array_o(theta_out));
    rho_step   u_rho   (.state_array_i(theta_out),     .state_array_o(rho_out));
    pi_step    u_pi    (.state_array_i(rho_out),       .state_array_o(pi_out));
    chi_step   u_chi   (.state_array_i(pi_out),        .state_array_o(chi_out));
    iota_step  u_iota  (.state_array_i(chi_out),
                        .round_index_i(round_index_i),
                        .state_array_o(iota_out));

    assign state_array_o = iota_out;
endmodule

`default_nettype wire
