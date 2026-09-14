/*
 * Module Name: keccak_core
 * Author: Kiet Le
 * Description:
 * - Fully compliant FIPS 202 Keccak Permutation Core.
 * - Supports SHAKE128 and SHAKE256 modes via 'keccak_mode_i' (SHAKE-only build).
 * - Uses a small protocol-neutral ready/valid word interface for data IO.
 * - Executes each round through a two-stage theta/rho/pi and chi/iota pipeline.
 * - Handles arbitrary message lengths including correct '10*1' padding logic.
 * - Supports infinite output generation (XOF) and hardware-bounded length limits for SHAKE modes.
 *
 * Performance & Latency:
 * - Architecture: 2-Cycle Round (fill then commit).
 * - Permutation Latency: 48 clock cycles per block.
 * - Squeeze Output: Combinational (Data is valid immediately upon entering Squeeze state).
 *
 * Interface Notes:
 * - Configuration (mode/rate) is latched only on the rising edge of 'start_i'.
 * - Message and output lengths are latched with start_i.
 * - Input data must remain stable while input_valid_i is asserted and
 *   input_ready_o is low.
 *
 * Usage Contract:
 * - start_i must be asserted for one cycle when IDLE.
 * - Exactly ceil(message_len_i/8) input words are accepted.
 * - stop_i is only sampled during SQUEEZE.
 * - keccak_mode_i must remain stable after start_i.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_core (
    input   wire                            clk,
    input   wire                            rst,

    input   wire                            start_i,
    input   wire [0:0]                      keccak_mode_i,
    input   wire  [MSG_LEN_WIDTH-1:0]       message_len_i,
    input   wire  [XOF_LEN_WIDTH-1:0]       output_len_i,  // 0 = continuous
    input   wire                            stop_i,
    output  wire                            busy_o,
    output  logic                           done_o,

    input   wire  [DWIDTH-1:0]              input_data_i,
    input   wire                            input_valid_i,
    output  logic                           input_ready_o,

    output  logic [DWIDTH-1:0]              output_data_o,
    output  logic                           output_valid_o,
    output  logic [BYTE_COUNT_WIDTH-1:0]    output_bytes_o,
    input   wire                            output_ready_i
);
    // Dataflow Summary:
    // Input words -> Absorb (KAU) -> State Array
    // Padding (SPU) -> Permutation (KSU)
    // State Array -> Squeeze (KOU) -> Output words

    // ==========================================================
    // 1. KECCAK LOGIC, WIRES, REGISTERS AND ENUMS
    // ==========================================================

    // 1A. Enum Instantiations
    // ----------------------------------------------------------

    // FSM States
    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_ABSORB,
        STATE_SUFFIX_PADDING,
        STATE_PERMUTE,
        STATE_SQUEEZE
    } state_t;
    state_t state, next_state;

    // State Array Write Selector Options
    typedef enum {
        KSU_SEL,
        ABSORB_SEL,
        PADDING_SEL
    } sa_in_sel_t;
    sa_in_sel_t state_array_in_sel;

    // 1B. Registers
    // ----------------------------------------------------------

    // 1600-bit State Array using to hold the state of keccak core.
    // See FIPS202 Section 3.1.1 for more information on state array.
    reg [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array;

    // KSU Permutation Registers
    reg [ROUND_INDEX_SIZE-1:0]      round_idx;
    // phase 0 fills the theta/rho/pi register; phase 1 commits chi/iota.

    // Keccak Parameter Setup Registers
    reg [RATE_WIDTH-1:0]            rate; // Rate in BITS (1344 for SHAKE128, 1088 for SHAKE256)
    reg [SUFFIX_WIDTH-1:0]          suffix;

    reg [XOF_LEN_WIDTH-1:0]         xof_bytes_remaining;
    reg                             is_xof_fixed_len;
    reg [MSG_LEN_WIDTH-1:0]         message_bytes_remaining;

    // Absorb Phase Registers
    reg                             absorb_done; // Absorb stage fully complete flag
    reg     [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed; // # of bytes absorbed in the current rate block
    reg                             absorb_block_full;
    reg                             msg_received; // Full message has been received

    // Squeeze Signals
    logic   [BYTE_ABSORB_WIDTH-1:0] bytes_squeezed;
    logic   [BYTE_COUNT_WIDTH-1:0]  input_bytes_this_word;
    logic   [DATA_BYTE_NUM-1:0]     input_byte_enable;
    logic                           input_last_word;

    // 1C. Enable Wires
    // ----------------------------------------------------------

    // Misc. FSM Enables
    logic state_array_wr_en;
    logic init_wr_en;
    logic rst_round_idx_en;
    logic inc_round_idx_en;

    // Absorb Enable Wires
    logic absorb_wr_en;
    logic msg_received_wr_en;
    logic complete_absorb_en;

    // Permutation Enable
    logic perm_en;

    // Squeeze Enable
    logic squeeze_wr_en;
    logic update_xof_remaining_en;

    // 1D. Module Wires and Registers
    // ----------------------------------------------------------

    // Keccak Parameter Unit (KPU) Module Wires
    wire [MODE_SEL_WIDTH-1:0]       KPU_MODE_I;

    wire [RATE_WIDTH-1:0]           KPU_RATE_O;
    wire [SUFFIX_WIDTH-1:0]         KPU_SUFFIX_O;

    // Keccak Step Unit (KSU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KSU_STATE_ARRAY_I;
    wire [ROUND_INDEX_SIZE-1:0]     KSU_ROUND_INDEX_I;

    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KSU_STATE_ARRAY_O;

    // Keccak Absorb Unit (KAU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KAU_STATE_ARRAY_I;
    wire [RATE_WIDTH-1:0]           KAU_RATE_I;
    wire [BYTE_ABSORB_WIDTH-1:0]    KAU_BYTES_ABSORBED_I;
    wire [DWIDTH-1:0]               KAU_MSG_I;
    wire [DATA_BYTE_NUM-1:0]        KAU_BYTE_ENABLE_I;
    wire                            KAU_PAD_EN_I;
    wire [SUFFIX_WIDTH-1:0]         KAU_SUFFIX_I;

    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KAU_STATE_ARRAY_O;
    wire [BYTE_ABSORB_WIDTH-1:0]    KAU_BYTES_ABSORBED_O;

    // Suffix Padder Unit (Collapsed into KAU)

    // Squeeze Output Unit (KOU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KOU_STATE_ARRAY_I;
    wire [RATE_WIDTH-1:0]           KOU_RATE_I;
    wire [BYTE_ABSORB_WIDTH-1:0]    KOU_BYTES_SQUEEZED_I;
    wire [XOF_LEN_WIDTH-1:0]        KOU_XOF_LEN_I;
    wire                            KOU_IS_XOF_FIXED_LEN_I;
    wire [BYTE_ABSORB_WIDTH-1:0]    KOU_BYTES_SQUEEZED_O;
    wire                            KOU_PERM_NEEDED_O;
    wire [DWIDTH-1:0]               KOU_DATA_O;
    wire [BYTE_COUNT_WIDTH-1:0]     KOU_VALID_BYTES_O;
    wire                            KOU_FINAL_O;

    // 1E. Wire Assignments
    // ----------------------------------------------------------

    // Calculate Ready
    // A completed non-full message leaves ABSORB on the same transfer, so the
    // wide state write path does not need the msg_received control bit.
    logic internal_ready;
    logic input_fills_rate;
    assign internal_ready = !absorb_block_full;
    assign input_fills_rate =
        (input_bytes_this_word == BYTE_COUNT_WIDTH'(DATA_BYTE_NUM)) &&
        (rate[8] ? (bytes_absorbed == BYTE_ABSORB_WIDTH'(160))
                 : (bytes_absorbed == BYTE_ABSORB_WIDTH'(128)));

    function automatic logic [BYTE_COUNT_WIDTH-1:0] word_byte_count(
        input logic [MSG_LEN_WIDTH-1:0] bytes_remaining
    );
        if (bytes_remaining >= DATA_BYTE_NUM)
            word_byte_count = BYTE_COUNT_WIDTH'(DATA_BYTE_NUM);
        else
            word_byte_count = bytes_remaining[BYTE_COUNT_WIDTH-1:0];
    endfunction

    function automatic logic [DATA_BYTE_NUM-1:0] word_byte_mask(
        input logic [MSG_LEN_WIDTH-1:0] bytes_remaining
    );
        logic [DATA_BYTE_NUM-1:0] mask;
        mask = '0;
        for (int i = 0; i < DATA_BYTE_NUM; i++) begin
            if (i < bytes_remaining)
                mask[i] = 1'b1;
        end
        return mask;
    endfunction

    assign busy_o = (state != STATE_IDLE);

    // ==========================================================
    // 2. HELPER MODULE INSTANTIATIONS
    // ==========================================================

    // 2A. KECCAK PARAMETER UNIT (KPU)
    // ----------------------------------------------------------
    // Module to get sha3 parameters during initializtion
    keccak_param_unit KPU (
        .keccak_mode_i  (KPU_MODE_I),
        // .keccak_mode_i  (2'b11),

        .rate_o         (KPU_RATE_O),
        .suffix_o       (KPU_SUFFIX_O)
    );
    assign KPU_MODE_I = keccak_mode_i;

    // 2B. KECCAK STEP UNIT (KSU)
    // ----------------------------------------------------------
    // Keccak Round Unit: all five FIPS 202 steps complete in one clock.
    keccak_step_unit KSU (
        .state_array_i  (KSU_STATE_ARRAY_I),
        .round_index_i  (KSU_ROUND_INDEX_I),

        .state_array_o  (KSU_STATE_ARRAY_O)
    );
    assign KSU_STATE_ARRAY_I    = state_array;
    assign KSU_ROUND_INDEX_I    = round_idx;

    // 2C. KECCAK ABSORB UNIT (KAU) (Now handles Optional Padding)
    // ----------------------------------------------------------
    // Module to handle absorbing of input message and padding
    keccak_absorb_unit KAU (
        .state_array_i      (KAU_STATE_ARRAY_I),
        .rate_i             (KAU_RATE_I),
        .bytes_absorbed_i   (KAU_BYTES_ABSORBED_I),
        .msg_i              (KAU_MSG_I),
        .byte_enable_i      (KAU_BYTE_ENABLE_I),
        .pad_en_i           (KAU_PAD_EN_I),
        .suffix_i           (KAU_SUFFIX_I),

        .state_array_o      (KAU_STATE_ARRAY_O),
        .bytes_absorbed_o   (KAU_BYTES_ABSORBED_O)
    );
    assign KAU_STATE_ARRAY_I    = state_array;
    assign KAU_RATE_I           = rate;
    assign KAU_BYTES_ABSORBED_I = bytes_absorbed;
    assign KAU_MSG_I            = input_data_i;
    assign KAU_BYTE_ENABLE_I    = input_byte_enable;
    assign KAU_PAD_EN_I         = (state == STATE_SUFFIX_PADDING);
    assign KAU_SUFFIX_I         = suffix;

    // 2D. SUFFIX PADDER UNIT (SPU)
    // ----------------------------------------------------------
    // Collapsed and merged into KAU logic to save Area payload!

    // 2E. SQUEEZE OUTPUT UNIT (KOU)
    // ----------------------------------------------------------
    keccak_output_unit KOU (
        .state_array_i          (KOU_STATE_ARRAY_I),
        .rate_i                 (KOU_RATE_I),
        .bytes_squeezed_i       (KOU_BYTES_SQUEEZED_I),
        .xof_len_i              (KOU_XOF_LEN_I),
        .is_xof_fixed_len_i     (KOU_IS_XOF_FIXED_LEN_I),

        .bytes_squeezed_o       (KOU_BYTES_SQUEEZED_O),
        .squeeze_perm_needed_o  (KOU_PERM_NEEDED_O),
        .data_o                 (KOU_DATA_O),
        .valid_bytes_o          (KOU_VALID_BYTES_O),
        .final_o                (KOU_FINAL_O)
    );
    assign KOU_STATE_ARRAY_I          = state_array;
    assign KOU_RATE_I                 = rate;
    assign KOU_BYTES_SQUEEZED_I       = bytes_squeezed;
    assign KOU_XOF_LEN_I              = xof_bytes_remaining;
    assign KOU_IS_XOF_FIXED_LEN_I     = is_xof_fixed_len;

    // ==========================================================
    // 3. 3-PROCESS CONTROL FSM
    // ==========================================================

    // 3A. FSM Control Process 1: State Register (Sequential)
    // ----------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 3B. FSM Control Process 2: Next State Decoder (Combinational)
    // ----------------------------------------------------------
    always_comb begin
        next_state = state;

        case(state)
            STATE_IDLE : begin
                if (start_i) begin
                    next_state = (message_len_i == 0) ?
                                 STATE_SUFFIX_PADDING : STATE_ABSORB;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_ABSORB : begin
                // PRIORITY 1: If current rate block is full, run permutation
                if (absorb_block_full) begin
                    next_state = STATE_PERMUTE;

                // A non-full last transfer can move directly to padding. A
                // last transfer that fills the rate remains here for one
                // cycle so absorb_block_full starts the required permutation.
                end else if (input_valid_i && input_last_word &&
                             !input_fills_rate) begin
                    next_state = STATE_SUFFIX_PADDING;
                end else begin
                    next_state = STATE_ABSORB;
                end
            end

            STATE_SUFFIX_PADDING : begin
                next_state = STATE_PERMUTE;
            end

            // ------------ PERMUTATION (1 Round Per Clock) ------------
            STATE_PERMUTE : begin
                if (round_idx == 'd23) begin
                    if (absorb_done) begin
                        next_state = STATE_SQUEEZE;
                    end else if (msg_received) begin
                        next_state = STATE_SUFFIX_PADDING;
                    end else begin
                        next_state = STATE_ABSORB;
                    end
                end else begin
                    next_state = STATE_PERMUTE;
                end
            end
            // ---------------------------------------------------------

            STATE_SQUEEZE : begin
                // PRIORITY 1: External Stop
                if (stop_i) begin
                    next_state = STATE_IDLE;

                // PRIORITY 2: Output Data
                end else if (output_ready_i) begin
                    // A. Bounded XOF target reached (final asserted by KOU)
                    if (KOU_FINAL_O) begin
                        next_state = STATE_IDLE;

                    // B. Check Rate Empty -> Re-Permute (SHAKE)
                    end else if (KOU_PERM_NEEDED_O) begin
                        next_state = STATE_PERMUTE;

                    // C. Continue Squeezing
                    end else begin
                        next_state = STATE_SQUEEZE;
                    end

                // PRIORITY 3: Receiver not ready? WAIT here.
                end else begin
                    next_state = STATE_SQUEEZE;
                end
            end

            default : begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    // 3C. FSM Control Process 3: Action Decoder (Combinational)
    // ----------------------------------------------------------
    always_comb begin
        // Defaults:

        // ----- Outputs -----
        input_ready_o  = 1'b0;
        output_data_o  = '0;
        output_valid_o = 1'b0;
        output_bytes_o = '0;
        done_o         = 1'b0;

        // ----- Internal Control Signals -----
        state_array_in_sel  = KSU_SEL;
        state_array_wr_en   = 1'b0;
        init_wr_en          = 1'b0;

        // Absorb Wires
        absorb_wr_en        = 1'b0;
        msg_received_wr_en  = 1'b0;
        complete_absorb_en  = 1'b0;

        // Permutation
        perm_en             = 1'b0;
        rst_round_idx_en    = 1'b0;
        inc_round_idx_en    = 1'b0;

        // Squeeze Signals
        squeeze_wr_en            = 1'b0;
        update_xof_remaining_en = 1'b0;

        case(state)
            STATE_IDLE : begin
                if (start_i) begin
                    init_wr_en = 1'b1;
                end
            end

            STATE_ABSORB : begin
                input_ready_o = internal_ready;

                // PRIORITY 1: If current rate block is full, run permutation
                if (absorb_block_full) begin
                    perm_en = 1'b1;

                end else if (input_valid_i) begin
                    absorb_wr_en = 1'b1;
                    state_array_wr_en = 1'b1;
                    state_array_in_sel = ABSORB_SEL;
                    if (input_last_word) begin
                        msg_received_wr_en = 1'b1;
                    end
                end
            end

            STATE_SUFFIX_PADDING : begin
                state_array_wr_en   = 1'b1;
                state_array_in_sel  = PADDING_SEL;
                perm_en             = 1'b1;
                complete_absorb_en  = 1'b1;
            end

            // ------------ PERMUTATION (1 Round Per Clock) -------------
            STATE_PERMUTE : begin
                state_array_in_sel = KSU_SEL;
                state_array_wr_en = 1'b1;
                if (round_idx == 'd23) begin
                    rst_round_idx_en = 1'b1;
                end else begin
                    inc_round_idx_en = 1'b1;
                end
            end
            // ---------------------------------------------------------

            STATE_SQUEEZE : begin
                output_data_o  = KOU_DATA_O;
                output_valid_o = !stop_i;
                output_bytes_o = KOU_VALID_BYTES_O;
                done_o = stop_i || (output_ready_i && KOU_FINAL_O);

                if (output_valid_o && output_ready_i) begin
                    update_xof_remaining_en = is_xof_fixed_len;
                end

                // SQUEEZE -> IDLE: no init_wr_en here. All counters/registers
                // (bytes_absorbed, xof_bytes_remaining, state_array, etc.)
                // will be reloaded on the next start_i in IDLE. Asserting
                // init_wr_en from SQUEEZE creates a long combinational path:
                //   XOF bookkeeping -> KOU.final_o -> init_wr_en ->
                //   ena/D of many wide registers, which was the design's
                //   critical path. Skipping it here is functionally
                //   equivalent and unblocks Fmax.
                if (!stop_i && output_ready_i) begin
                    // A. Bounded XOF target reached (final asserted by KOU):
                    //    just stay quiet — next_state goes to IDLE.
                    if (KOU_FINAL_O) begin
                        // (no action)

                    // B. Check Rate Empty -> Re-Permute (SHAKE)
                    end else if (KOU_PERM_NEEDED_O) begin
                        perm_en = 1'b1; // Reset bytes_absorbed/squeezed counters

                    // C. Continue Squeezing
                    end else begin
                        squeeze_wr_en = 1'b1;
                    end
                end
            end
            default : begin
                // Defaults
                input_ready_o  = 1'b0;
                output_data_o  = '0;
                output_valid_o = 1'b0;
                output_bytes_o = '0;
                done_o         = 1'b0;
            end
        endcase

    end

    // ==========================================================
    // 4. KECCAK DATAPATH UPDATING
    // ==========================================================
    // The state is initialized on every accepted start. Keeping it off the
    // asynchronous reset network removes a 1,600-register reset fanout while
    // preserving reset recovery: no state is consumed before the next start.
    always @(posedge clk) begin
        if (init_wr_en) begin
            state_array <= '0;
        end else if (state_array_wr_en) begin
            if (state_array_in_sel == KSU_SEL) begin
                state_array <= KSU_STATE_ARRAY_O;
            end else begin
                state_array <= KAU_STATE_ARRAY_O;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            round_idx           <= 'b0;
            msg_received        <= 1'b0;
            message_bytes_remaining <= '0;

            // Absorb Signals
            absorb_done         <= 'b0;
            bytes_absorbed      <= 'b0;
            absorb_block_full   <= 1'b0;

            // Squeeze Signals
            bytes_squeezed      <= 'b0;
            input_bytes_this_word <= '0;
            input_byte_enable     <= '0;
            input_last_word       <= 1'b0;
        end else begin
            // --- Initialization & Reset ---
            if (init_wr_en) begin
                // 1. Setup Parameters
                xof_bytes_remaining <= output_len_i;
                is_xof_fixed_len <= (output_len_i != 0);
                rate             <= KPU_RATE_O;
                suffix           <= KPU_SUFFIX_O;

                // 2. Wipe the state and all counters/flags. init_wr_en
                //    is only asserted in IDLE+start_i (SQUEEZE no longer
                //    triggers init), so this path is not in the Fmax
                //    critical path.
                bytes_absorbed   <= '0;
                absorb_block_full <= 1'b0;
                bytes_squeezed   <= '0;
                message_bytes_remaining <= message_len_i;
                msg_received     <= (message_len_i == 0);
                input_bytes_this_word <= word_byte_count(message_len_i);
                input_byte_enable <= word_byte_mask(message_len_i);
                input_last_word <= (message_len_i <= DATA_BYTE_NUM);
                absorb_done      <= '0;
                round_idx        <= '0;

            // Reset bytes absorbed after absorb permutation
            end else if (perm_en) begin
                bytes_absorbed  <= '0;
                absorb_block_full <= 1'b0;
                bytes_squeezed  <= '0;
            end

            // --- Absorb Counters & Flags ---
            if (absorb_wr_en) begin
                bytes_absorbed <= bytes_absorbed +
                    BYTE_ABSORB_WIDTH'(input_bytes_this_word);
                absorb_block_full <=
                    input_fills_rate;
                message_bytes_remaining <=
                    message_bytes_remaining - input_bytes_this_word;
                if (!input_last_word) begin
                    // The current transfer consumes eight bytes. For a next
                    // remainder of 1..7, the old remainder is 9..15 and its
                    // low three bits are already the next byte count. All
                    // old remainders >=16 produce another full word.
                    if (|message_bytes_remaining[MSG_LEN_WIDTH-1:4]) begin
                        input_bytes_this_word <=
                            BYTE_COUNT_WIDTH'(DATA_BYTE_NUM);
                        input_byte_enable <= '1;
                    end else begin
                        input_bytes_this_word <=
                            {1'b0, message_bytes_remaining[2:0]};
                        case (message_bytes_remaining[2:0])
                            3'd1: input_byte_enable <= 8'h01;
                            3'd2: input_byte_enable <= 8'h03;
                            3'd3: input_byte_enable <= 8'h07;
                            3'd4: input_byte_enable <= 8'h0f;
                            3'd5: input_byte_enable <= 8'h1f;
                            3'd6: input_byte_enable <= 8'h3f;
                            3'd7: input_byte_enable <= 8'h7f;
                            default: input_byte_enable <= 8'hff;
                        endcase
                    end
                    input_last_word <=
                        (message_bytes_remaining <= (2 * DATA_BYTE_NUM));
                end
            end
            // Set flag for absorb completion
            if (complete_absorb_en) begin
                absorb_done <= 1'b1;
            end
            if (msg_received_wr_en) begin
                msg_received <= 1'b1;
            end
            // --- Permutation Round Control ---
            if (rst_round_idx_en) begin
                round_idx <= 'b0;
            end else if (inc_round_idx_en) begin
                round_idx <= round_idx + 1'b1;
            end

            // --- Squeeze Counters ---
            if (squeeze_wr_en) begin
                bytes_squeezed <= bytes_squeezed +
                    BYTE_ABSORB_WIDTH'(DATA_BYTE_NUM);
            end

            if (update_xof_remaining_en) begin
                if (KOU_FINAL_O)
                    xof_bytes_remaining <= '0;
                else
                    xof_bytes_remaining <= xof_bytes_remaining -
                        XOF_LEN_WIDTH'(DATA_BYTE_NUM);
            end
        end
    end
endmodule

`default_nettype wire
