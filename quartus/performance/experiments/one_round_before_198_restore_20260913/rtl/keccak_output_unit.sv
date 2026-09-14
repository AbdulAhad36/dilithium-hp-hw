/*
 * Module Name: keccak_output_unit
 * Author: Kiet Le
 * Description:
 * - Implements the "Squeeze" phase of the sponge construction.
 * - Extracts data from the State Array in chunks of 'DWIDTH' (e.g., 64 bits).
 * - Linearizes the 3D State Array (Lane[x][y]) into a bitstream for output.
 * - Manages Flow Control (SHAKE-only):
 * 1. Continuous XOF (xof_len_i==0): Runs indefinitely until externally stopped.
 * 2. Bounded XOF  (xof_len_i!=0):  Auto-terminates when xof_len_i bytes are emitted.
 * 3. Rate Boundaries: Detects when the Rate block is exhausted via 'squeeze_perm_needed_o'
 * to trigger the FSM to permute the state again (for multi-block XOF output).
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_output_unit (
    input  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input  wire  [RATE_WIDTH-1:0]           rate_i,
    input  wire  [BYTE_ABSORB_WIDTH-1:0]    bytes_squeezed_i,      // Counter from FSM
    input  wire  [XOF_LEN_WIDTH-1:0]        xof_len_i,             // XOF bytes remaining
    input  wire                             is_xof_fixed_len_i,    // Flag for fixed-length XOF (0 = continuous)

    output logic [BYTE_ABSORB_WIDTH-1:0]    bytes_squeezed_o,      // Next counter value
    output logic                            squeeze_perm_needed_o, // Flag: Rate is empty!
    output logic [DWIDTH-1:0]               data_o,                // 64 Bits
    output logic [BYTE_COUNT_WIDTH-1:0]     valid_bytes_o,
    output logic                            final_o
);
    // ==========================================================
    // 1. CALCULATE NEXT COUNTER VALUE
    // ==========================================================
    // ==========================================================
    // 2. FLATTEN STATE ARRAY AND CAST TO WORD-ALIGNED ARRAY
    // ==========================================================
    localparam int NUM_OUTPUT_WORDS = 1600 / DWIDTH;
    localparam logic [BYTE_COUNT_WIDTH-1:0] BYTES_PER_WORD =
        BYTE_COUNT_WIDTH'(DWIDTH/8);
    logic [1599:0] state_linear;
    logic [NUM_OUTPUT_WORDS-1:0][DWIDTH-1:0] state_words;

    always_comb begin
        // 1. Flatten 3D to 1D
        for (int y = 0; y < 5; y++) begin
            for (int x = 0; x < 5; x++) begin
                // Calculate linear lane index: i = 5*y + x
                state_linear[(x + 5*y) * 64 +: 64] = state_array_i[x][y];
            end
        end
        // 2. Cast 1D array into Word-Aligned Boundaries
        for (int i = 0; i < NUM_OUTPUT_WORDS; i++) begin
            state_words[i] = state_linear[i * DWIDTH +: DWIDTH];
        end
    end

    // ==========================================================
    // 3. EXTRACT OUTPUT WORD (High-Fmax Multiplexer)
    // ==========================================================
    // Instead of a dynamic bit-slice, select exactly which word block to output.
    logic [$clog2(NUM_OUTPUT_WORDS)-1:0] current_word_idx;
    assign current_word_idx =
        bytes_squeezed_i[BYTE_ABSORB_WIDTH-1:$clog2(DWIDTH / 8)];

    always_comb begin
        data_o = state_words[current_word_idx];
    end

    // ==========================================================
    // 4. VALID BYTE CALCULATION
    // ==========================================================
    logic [BYTE_COUNT_WIDTH-1:0] output_bytes_this_cycle;

    always_comb begin
        output_bytes_this_cycle = BYTES_PER_WORD;
        if (is_xof_fixed_len_i &&
            (xof_len_i < XOF_LEN_WIDTH'(BYTES_PER_WORD))) begin
            output_bytes_this_cycle = xof_len_i[BYTE_COUNT_WIDTH-1:0];
        end
    end

    assign valid_bytes_o = output_bytes_this_cycle;
    assign bytes_squeezed_o = bytes_squeezed_i + BYTES_PER_WORD;

    // ==========================================================
    // 5. SHAKE PERMUTATION TRIGGER
    // ==========================================================
    // Both supported SHAKE rates are exact multiples of the 8-byte data word.
    // rate_i[8] distinguishes SHAKE128 (168 bytes) from SHAKE256 (136 bytes).
    assign squeeze_perm_needed_o =
        rate_i[8] ? (bytes_squeezed_i == BYTE_ABSORB_WIDTH'(160))
                  : (bytes_squeezed_i == BYTE_ABSORB_WIDTH'(128));

    // ==========================================================
    // 6. LAST SIGNAL LOGIC (SHAKE-only)
    // ==========================================================
    // Continuous output never marks a final word; the FSM relies on stop_i.
    // xof_len_i is a registered remaining-byte count. Comparing it with
    // this rate beat avoids a subtract/add/compare chain in the squeeze FSM.
    assign final_o = is_xof_fixed_len_i &&
                     (xof_len_i <= XOF_LEN_WIDTH'(BYTES_PER_WORD));

endmodule

`default_nettype wire
