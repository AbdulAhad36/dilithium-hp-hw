// FIPS 204 KeyGen absorption-message builder. This is not a hash engine.
// Byte zero occupies bits[7:0]; the downstream service owns core/output routing.
`default_nettype none
module keygen_hash_message (
  input wire logic clk, rst,
  input wire logic command_valid_i, output logic command_ready_o,
  input wire logic [1:0] command_op_i, command_param_i,
  input wire logic [15:0] command_id_i, command_nonce_i,
  input wire logic [7:0] command_row_i, command_column_i,
  input wire logic [511:0] command_seed_i,
  output logic request_valid_o, input wire logic request_ready_i,
  output logic request_mode_o,
  output logic [15:0] request_message_len_o, request_output_len_o,
  output logic [63:0] input_data_o,
  output logic input_valid_o, input wire logic input_ready_i,
  output logic done_valid_o, input wire logic done_ready_i,
  output logic done_error_o, output logic [15:0] done_id_o
);
  // 0: xi[32] || K || L; 1: rho[32] || column || row;
  // 2: rho-prime[64] || nonce_le16. Op2 covers KeyGen s1/s2 only.
  typedef enum logic [1:0] {IDLE, REQUEST, INPUT_WORDS, DONE} state_t;
  state_t state;
  logic [511:0] seed_r;
  logic [15:0] suffix_r;
  logic [3:0] word_r, suffix_word_r;
  logic [3:0] k, l;
  logic bad_command;

  always_comb begin
    case (command_param_i)
      0: begin k=4; l=4; end // level2 = ML-DSA-44
      1: begin k=6; l=5; end // level3 = ML-DSA-65
      2: begin k=8; l=7; end // level5 = ML-DSA-87
      default: begin k=0; l=0; end
    endcase
    bad_command = command_param_i==3 || command_op_i==3;
    if (command_op_i==1)
      bad_command |= command_row_i >= {4'd0,k} || command_column_i >= {4'd0,l};
    if (command_op_i==2)
      bad_command |= command_nonce_i >= (16'(k)+16'(l));
  end

  assign command_ready_o = !rst && state==IDLE;
  assign request_valid_o = !rst && state==REQUEST;
  assign input_valid_o = !rst && state==INPUT_WORDS;
  assign done_valid_o = !rst && state==DONE;
  assign input_data_o = word_r==suffix_word_r ? {48'd0,suffix_r} :
                        seed_r[64*word_r +: 64];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE; word_r <= 0; suffix_word_r <= 0;
      seed_r <= 0; suffix_r <= 0; done_error_o <= 0; done_id_o <= 0;
      request_mode_o <= 0; request_message_len_o <= 0; request_output_len_o <= 0;
    end else case (state)
      IDLE: if (command_valid_i) begin
        seed_r <= command_seed_i; done_id_o <= command_id_i;
        done_error_o <= bad_command; word_r <= 0;
        request_mode_o <= command_op_i!=1;
        request_message_len_o <= command_op_i==2 ? 16'd66 : 16'd34;
        // Sampling is an open-ended XOF; only seed expansion is finite here.
        request_output_len_o <= command_op_i==0 ? 16'd128 : 16'd0;
        suffix_word_r <= command_op_i==2 ? 4'd8 : 4'd4;
        case (command_op_i)
          0: suffix_r <= {4'd0,l,4'd0,k};
          1: suffix_r <= {command_row_i,command_column_i};
          default: suffix_r <= command_nonce_i;
        endcase
        state <= bad_command ? DONE : REQUEST;
      end
      REQUEST: if (request_ready_i) state <= INPUT_WORDS;
      INPUT_WORDS: if (input_ready_i) begin
        if (word_r==suffix_word_r) state <= DONE;
        else word_r <= word_r+4'd1;
      end
      DONE: if (done_ready_i) state <= IDLE;
      default: state <= IDLE;
    endcase
  end
endmodule
`default_nettype wire
