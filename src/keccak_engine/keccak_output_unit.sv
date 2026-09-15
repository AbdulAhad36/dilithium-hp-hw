/*
 * Module Name: keccak_output_unit
 * Description: Extracts ready/valid SHAKE output beats from the Keccak state.
 * The output width is independent from the 64-bit absorb interface.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_output_unit #(
    parameter int OUTPUT_DWIDTH = DWIDTH,
    parameter int OUTPUT_BYTES = OUTPUT_DWIDTH / 8,
    parameter int OUTPUT_BYTE_COUNT_WIDTH = $clog2(OUTPUT_BYTES + 1)
) (
    input  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input  wire  [RATE_WIDTH-1:0]            rate_i,
    input  wire  [BYTE_ABSORB_WIDTH-1:0]     bytes_squeezed_i,
    input  wire  [XOF_LEN_WIDTH-1:0]         xof_len_i,
    input  wire                               is_xof_fixed_len_i,

    output logic [BYTE_ABSORB_WIDTH-1:0]     bytes_squeezed_o,
    output logic                              squeeze_perm_needed_o,
    output logic [OUTPUT_DWIDTH-1:0]         data_o,
    output logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] valid_bytes_o,
    output logic                              final_o
);
    localparam int MAX_RATE_BITS = 1344;
    localparam int NUM_OUTPUT_WORDS =
        (MAX_RATE_BITS + OUTPUT_DWIDTH - 1) / OUTPUT_DWIDTH;
    localparam int OUTPUT_BYTE_SHIFT = $clog2(OUTPUT_BYTES);
    localparam logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] FULL_BEAT_BYTES =
        OUTPUT_BYTE_COUNT_WIDTH'(OUTPUT_BYTES);

    logic [1599:0] state_linear;
    logic [NUM_OUTPUT_WORDS-1:0][OUTPUT_DWIDTH-1:0] state_words;
    logic [$clog2(NUM_OUTPUT_WORDS)-1:0] current_word_idx;
    logic [BYTE_ABSORB_WIDTH-1:0] rate_bytes;
    logic [BYTE_ABSORB_WIDTH-1:0] rate_bytes_remaining;
    logic [OUTPUT_BYTE_COUNT_WIDTH-1:0] output_bytes_this_cycle;

    always_comb begin
        state_linear = '0;
        for (int y = 0; y < COL_SIZE; y++) begin
            for (int x = 0; x < ROW_SIZE; x++) begin
                state_linear[(x + COL_SIZE*y) * LANE_SIZE +: LANE_SIZE] =
                    state_array_i[x][y];
            end
        end

        for (int i = 0; i < NUM_OUTPUT_WORDS; i++)
            state_words[i] = state_linear[i * OUTPUT_DWIDTH +: OUTPUT_DWIDTH];
    end

    assign current_word_idx =
        bytes_squeezed_i[BYTE_ABSORB_WIDTH-1:OUTPUT_BYTE_SHIFT];
    assign data_o = state_words[current_word_idx];
    assign rate_bytes = BYTE_ABSORB_WIDTH'(rate_i >> 3);
    assign rate_bytes_remaining = rate_bytes - bytes_squeezed_i;

    always_comb begin
        output_bytes_this_cycle = FULL_BEAT_BYTES;
        if (rate_bytes_remaining < BYTE_ABSORB_WIDTH'(OUTPUT_BYTES))
            output_bytes_this_cycle =
                rate_bytes_remaining[OUTPUT_BYTE_COUNT_WIDTH-1:0];
        if (is_xof_fixed_len_i &&
            (xof_len_i < XOF_LEN_WIDTH'(output_bytes_this_cycle)))
            output_bytes_this_cycle =
                xof_len_i[OUTPUT_BYTE_COUNT_WIDTH-1:0];
    end

    assign valid_bytes_o = output_bytes_this_cycle;
    assign bytes_squeezed_o = bytes_squeezed_i +
        BYTE_ABSORB_WIDTH'(output_bytes_this_cycle);
    // Rate exhaustion is independent of the requested XOF length. Keeping
    // this path independent from output_bytes_this_cycle avoids feeding the
    // XOF comparator/adder chain into the core counter reset enables. The
    // core gives final_o priority, so a short final beat never re-permutes.
    assign squeeze_perm_needed_o =
        (rate_bytes_remaining <= BYTE_ABSORB_WIDTH'(OUTPUT_BYTES));
    assign final_o = is_xof_fixed_len_i &&
        (xof_len_i <= XOF_LEN_WIDTH'(output_bytes_this_cycle));
endmodule

`default_nettype wire
