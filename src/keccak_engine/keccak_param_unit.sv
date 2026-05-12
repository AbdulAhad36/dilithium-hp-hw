/*
 * Module Name: keccak_param_unit
 * Author: Kiet Le
 * Description:
 * - Acts as a Look-Up Table (LUT) for FIPS 202 standard parameters.
 * - decodes the input 'keccak_mode_i' to output the correct Rate (block size)
 * and Domain Separation Suffix bits.
 * - Supports the following configurations (SHAKE-only for Dilithium):
 * 1. SHAKE128 (Rate: 1344, Suffix: 1111)
 * 2. SHAKE256 (Rate: 1088, Suffix: 1111)
 * - Note: The suffix output includes the first '1' bit of the '10*1' padding rule
 * pre-appended for simplified padding logic downstream.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_param_unit (
    input  wire  [MODE_SEL_WIDTH-1:0]   keccak_mode_i,

    output logic [RATE_WIDTH-1:0]       rate_o,
    output logic [SUFFIX_WIDTH-1:0]     suffix_o
);

    // ==========================================================
    // 1. INTERNAL CONSTANTS
    // ==========================================================
    // Rates in bits
    localparam int R_SHAKE128 = 1344;
    localparam int R_SHAKE256 = 1088;

    // SHAKE suffix only: {Padding_Bit, Domain_Bits} = '1111' + '1' = 11111 (0x1F)
    localparam logic [7:0] S_SHAKE = 8'b0001_1111;

    // ==========================================================
    // 2. LOGIC
    // ==========================================================
    always_comb begin
        suffix_o = S_SHAKE;  // SHAKE-only: suffix is always 0x1F
        case (keccak_mode_i)
            SHAKE128: rate_o = R_SHAKE128;
            SHAKE256: rate_o = R_SHAKE256;
            // Safety Fallback: SHAKE128 (rate must be non-zero to avoid FSM deadlock)
            default:  rate_o = R_SHAKE128;
        endcase
    end

endmodule

`default_nettype wire
