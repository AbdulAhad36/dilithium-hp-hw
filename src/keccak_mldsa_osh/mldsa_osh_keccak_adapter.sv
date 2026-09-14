`default_nettype none
`timescale 1ns/1ps

import keccak_pkg::*;

// Converts the ML-DSA-OSH FIFO protocol to the project's protocol-neutral
// Keccak stream interface. The imported VHDL remains unmodified.
module mldsa_osh_keccak_adapter (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          start_i,
    input  wire                          keccak_mode_i,
    input  wire [MSG_LEN_WIDTH-1:0]      message_len_i,
    input  wire [XOF_LEN_WIDTH-1:0]      output_len_i,
    input  wire                          stop_i,
    output logic                         busy_o,
    output logic                         done_o,
    input  wire [DWIDTH-1:0]             input_data_i,
    input  wire                          input_valid_i,
    output logic                         input_ready_o,
    output logic [DWIDTH-1:0]            output_data_o,
    output logic                         output_valid_o,
    output logic [BYTE_COUNT_WIDTH-1:0]  output_bytes_o,
    input  wire                          output_ready_i
);
    localparam logic [2:0] IDLE       = 3'd0;
    localparam logic [2:0] ABSORB     = 3'd1;
    localparam logic [2:0] PAD_WAIT   = 3'd2;
    localparam logic [2:0] PERMUTE    = 3'd3;
    localparam logic [2:0] SQUEEZE    = 3'd4;
    localparam int CONTINUOUS_LIMIT_BYTES = 2040;

    logic [2:0] state;
    logic       permute_phase;
    logic [ROUND_INDEX_SIZE-1:0] round_idx;

    logic       mode_q;
    logic [MSG_LEN_WIDTH-1:0] message_bytes_q;
    logic [XOF_LEN_WIDTH-1:0] requested_output_bytes_q;
    logic [XOF_LEN_WIDTH-1:0] effective_output_bytes_q;
    logic [XOF_LEN_WIDTH-1:0] output_bytes_remaining_q;
    logic       finite_output_q;
    logic       header_pending_q;
    logic       input_buffer_valid_q;
    logic [63:0] input_buffer_data_q;

    logic       osh_rst;
    logic       osh_src_ready;
    wire        osh_src_read;
    logic       osh_dst_ready;
    wire        osh_dst_write;
    logic [63:0] osh_din;
    wire  [63:0] osh_dout;

    logic        output_buffer_valid_q;
    logic [63:0] output_buffer_data_q;

    logic [31:0] message_bits;
    logic [28:0] output_bits;
    logic [63:0] header_word;
    logic        take_output;
    logic        capture_output;

    function automatic logic [63:0] reverse_bytes(input logic [63:0] value);
        for (int byte_index = 0; byte_index < 8; byte_index++)
            reverse_bytes[byte_index*8 +: 8] =
                value[(7-byte_index)*8 +: 8];
    endfunction

    assign message_bits = {{(32-MSG_LEN_WIDTH){1'b0}}, message_bytes_q} << 3;
    assign output_bits =
        {{(29-XOF_LEN_WIDTH){1'b0}}, effective_output_bytes_q} << 3;
    assign header_word = {
        1'b1,
        mode_q ? 2'b11 : 2'b10,
        output_bits,
        message_bits
    };

    assign osh_rst = rst || (state == IDLE);

    // ML-DSA-OSH names this input src_ready, but low means data is present.
    always_comb begin
        osh_src_ready = 1'b1;
        osh_din = 64'b0;
        if (state == ABSORB) begin
            if (header_pending_q) begin
                osh_src_ready = 1'b0;
                osh_din = header_word;
            end else if ((message_bytes_q != 0) &&
                         input_buffer_valid_q) begin
                osh_src_ready = 1'b0;
                osh_din = reverse_bytes(input_buffer_data_q);
            end
        end
    end

    // Low means the output consumer can accept a word. Allow replacement of
    // a consumed buffered word on the same clock to avoid losing upstream data.
    assign osh_dst_ready = output_buffer_valid_q && !output_ready_i;
    assign capture_output = osh_dst_write;
    assign take_output = output_buffer_valid_q && output_ready_i;

    assign busy_o = (state != IDLE);
    assign input_ready_o =
        (state == ABSORB) && !header_pending_q &&
        (message_bytes_q != 0) &&
        (!input_buffer_valid_q ||
         (osh_src_read && (message_bytes_q > 8)));
    assign output_valid_o = output_buffer_valid_q && (state != IDLE) && !rst;
    assign output_data_o = output_buffer_data_q;
    assign output_bytes_o =
        (output_bytes_remaining_q >= 8) ? 4'd8 :
        output_bytes_remaining_q[BYTE_COUNT_WIDTH-1:0];

    // The existing monitor requires done on the same edge as the final transfer
    // or stop request, rather than one cycle later.
    assign done_o =
        ((state != IDLE) && stop_i) ||
        (finite_output_q && take_output &&
         (output_bytes_remaining_q <= 8));

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            permute_phase <= 1'b0;
            round_idx <= '0;
            mode_q <= 1'b0;
            message_bytes_q <= '0;
            requested_output_bytes_q <= '0;
            effective_output_bytes_q <= '0;
            output_bytes_remaining_q <= '0;
            finite_output_q <= 1'b0;
            header_pending_q <= 1'b0;
            input_buffer_valid_q <= 1'b0;
            input_buffer_data_q <= '0;
            output_buffer_valid_q <= 1'b0;
            output_buffer_data_q <= '0;
        end else begin
            case (state)
                IDLE: begin
                    input_buffer_valid_q <= 1'b0;
                    output_buffer_valid_q <= 1'b0;
                    permute_phase <= 1'b0;
                    round_idx <= '0;
                    if (start_i) begin
                        state <= ABSORB;
                        mode_q <= keccak_mode_i;
                        message_bytes_q <= message_len_i;
                        requested_output_bytes_q <= output_len_i;
                        effective_output_bytes_q <=
                            (output_len_i == 0) ?
                            CONTINUOUS_LIMIT_BYTES : output_len_i;
                        output_bytes_remaining_q <=
                            (output_len_i == 0) ?
                            CONTINUOUS_LIMIT_BYTES : output_len_i;
                        finite_output_q <= (output_len_i != 0);
                        header_pending_q <= 1'b1;
                    end
                end

                ABSORB: begin
                    if (stop_i) begin
                        state <= IDLE;
                        input_buffer_valid_q <= 1'b0;
                        output_buffer_valid_q <= 1'b0;
                    end else if (osh_src_read) begin
                        if (header_pending_q) begin
                            header_pending_q <= 1'b0;
                            if (message_bytes_q == 0)
                                state <= PAD_WAIT;
                        end else if (input_buffer_valid_q &&
                                     (message_bytes_q != 0)) begin
                            input_buffer_valid_q <= 1'b0;
                            if (message_bytes_q <= 8) begin
                                message_bytes_q <= '0;
                                state <= PAD_WAIT;
                            end else begin
                                message_bytes_q <= message_bytes_q - 8;
                            end
                        end
                    end

                    // Capture after dequeue handling so a simultaneous
                    // upstream consume and interface transfer refills rather
                    // than clears the one-word buffer.
                    if (!stop_i && input_valid_i && input_ready_o) begin
                        input_buffer_valid_q <= 1'b1;
                        input_buffer_data_q <= input_data_i;
                    end
                end

                PAD_WAIT: begin
                    if (stop_i) begin
                        state <= IDLE;
                    end else begin
                        state <= PERMUTE;
                        permute_phase <= 1'b0;
                        round_idx <= '0;
                    end
                end

                PERMUTE, SQUEEZE: begin
                    if (state == PERMUTE) begin
                        permute_phase <= ~permute_phase;
                        if (round_idx == MAX_ROUNDS-1)
                            round_idx <= '0;
                        else
                            round_idx <= round_idx + 1'b1;
                    end

                    case ({capture_output, take_output})
                        2'b10: begin
                            output_buffer_valid_q <= 1'b1;
                            output_buffer_data_q <= reverse_bytes(osh_dout);
                        end
                        2'b01: output_buffer_valid_q <= 1'b0;
                        2'b11: begin
                            output_buffer_valid_q <= 1'b1;
                            output_buffer_data_q <= reverse_bytes(osh_dout);
                        end
                        default: ;
                    endcase

                    if (capture_output)
                        state <= SQUEEZE;

                    if (take_output) begin
                        if (output_bytes_remaining_q <= 8)
                            output_bytes_remaining_q <= '0;
                        else
                            output_bytes_remaining_q <=
                                output_bytes_remaining_q - 8;
                    end

                    if (stop_i ||
                        (finite_output_q && take_output &&
                         (output_bytes_remaining_q <= 8))) begin
                        state <= IDLE;
                        output_buffer_valid_q <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    keccak_top u_osh (
        .rst       (osh_rst),
        .clk       (clk),
        .src_ready (osh_src_ready),
        .src_read  (osh_src_read),
        .dst_ready (osh_dst_ready),
        .dst_write (osh_dst_write),
        .din       (osh_din),
        .dout      (osh_dout)
    );
endmodule

`default_nettype wire
