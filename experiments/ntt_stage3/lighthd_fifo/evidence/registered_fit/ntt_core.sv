// Four-butterfly, three-FIFO reconstruction from Ni et al. LightHD (2026).
// The published paper specifies the structure and dimensions, but does not
// release its RTL or decoder truth tables. FIFO control here is independently
// derived and checked by ../lighthd_fifo_schedule.py.
import ntt_pkg::*;

module ntt_core (
    input logic clk, rst,
    input logic start_i,
    input ntt_op_e op_i,
    output logic busy_o, done_o,
    input logic wr_en_i, wr_b_sel_i,
    input logic [LOGN-1:0] wr_addr_i,
    input logic [COEFF_W-1:0] wr_data_i,
    input logic rd_en_i,
    input logic [LOGN-1:0] rd_addr_i,
    output logic [COEFF_W-1:0] rd_data_o
);
  localparam int W = 4*COEFF_W;           // 92 bits per FIFO word
  localparam int PIPE = 9;                // 1 FIFO + 1 input + 6 BF + 1 result
  typedef enum logic [2:0] {IDLE, RUN, DRAIN, DONE} state_e;
  state_e state;
  ntt_op_e op_r;
  logic [7:0] tick;
  logic [3:0] drain;
  logic [W-1:0] fifo1 [32], fifo2 [32], fifo3 [16];
  logic [W-1:0] b_words [64]; // second PWM operand supplied by the wrapper
  logic [4:0] head1, tail1, head2, tail2;
  logic [3:0] head3, tail3;
  logic [5:0] count1, count2;
  logic [4:0] count3;
  logic [W-1:0] load_pack;

  logic pop1, pop2, pop3, push1, push2, push3;
  logic [W-1:0] push_word1, push_word2, push_word3;
  logic [W-1:0] fifo_q1, fifo_q2, fifo_q3;
  logic read_sel_q;
  logic [1:0] read_lane_q;
  logic [W-1:0] read_word;
  logic [W-1:0] word_a, word_b;
  logic [1:0] source_a, source_b;
  logic [1:0] source_a_q, source_b_q;
  logic [1:0] dest_a, dest_b;
  logic [4:0] issue;
  logic [2:0] stage, p;
  logic [8:0] length;
  logic run_issue, pwm_issue;
  logic [W-1:0] b_q;

  typedef struct packed {
    logic valid;
    logic pwm;
    logic inverse;
    logic [2:0] p;
    logic [1:0] dest_a, dest_b;
  } tag_t;
  tag_t tag [PIPE];
  logic [COEFF_W-1:0] bf_ai [4], bf_bi [4], bf_zi [4];
  logic [COEFF_W-1:0] bf_ai_q [4], bf_bi_q [4], bf_zi_q [4];
  logic [COEFF_W-1:0] bf_ao [4], bf_bo [4];
  logic [COEFF_W-1:0] tw [4];
  logic [7:0] tw_addr [4];
  bf_mode_e bf_mode [4];
  bf_mode_e bf_mode_q [4];
  logic [W-1:0] result_a, result_b;

  function automatic logic [COEFF_W-1:0] half_mod(input logic [COEFF_W-1:0] x);
    logic [COEFF_W:0] adjusted;
    adjusted = {1'b0,x} + (x[0] ? (COEFF_W+1)'(Q) : '0);
    return adjusted[COEFF_W:1];
  endfunction

  // The stream supplies a whole polynomial before start_i. For INTT the
  // 4-coefficient words must alternate between FIFO1 and FIFO2, whereas NTT
  // loads the first 128 coefficients into FIFO1 and the next 128 into FIFO2.
  // The top wrapper holds op_i stable throughout loading.
  logic load_word, load_b, load_a;
  logic [1:0] load_dest;
  logic [W-1:0] completed_word;
  always_comb begin
    load_word = state == IDLE && wr_en_i && wr_addr_i[1:0] == 2'd3;
    load_b = load_word && wr_b_sel_i;
    load_a = load_word && !wr_b_sel_i;
    load_dest = (op_i == OP_INTT) ?
                (wr_addr_i[2] ? 2'd1 : 2'd0) :
                (wr_addr_i[7] ? 2'd1 : 2'd0);
    completed_word = load_pack;
    completed_word[3*COEFF_W +: COEFF_W] = wr_data_i;
  end
  always_ff @(posedge clk or posedge rst) begin
    if (rst) load_pack <= '0;
    else if (state == IDLE && wr_en_i)
      load_pack[wr_addr_i[1:0]*COEFF_W +: COEFF_W] <= wr_data_i;
  end
  always_ff @(posedge clk) begin
    if (load_b) b_words[wr_addr_i[7:2]] <= completed_word;
  end

  // Signal generator and the FIFO/BU/twiddle decoder functions. Each cycle
  // processes eight coefficients (four butterflies) or one PWM word.
  always_comb begin
    stage = tick[7:5];
    issue = tick[4:0];
    p = (op_r == OP_INTT) ? stage : (3'd7-stage);
    length = 9'd1 << p;
    run_issue = (state == RUN && op_r != OP_PWM);
    pwm_issue = (state == RUN && op_r == OP_PWM);
    source_a = 0; source_b = 1;
    dest_a = 0; dest_b = 1;
    if (run_issue) begin
      if (op_r == OP_NTT) begin
        if (stage >= 1 && stage <= 5) begin
          if ((issue >> (5-stage)) & 1) begin
            source_a = 1; source_b = 0;
          end else begin
            source_a = 0; source_b = 2;
          end
        end
        if (stage <= 4 && ((issue >> (4-stage)) & 1)) begin
          dest_a = 2; dest_b = 0;
        end
      end else begin
        if (stage >= 3) begin
          if ((issue >> (stage-3)) & 1) begin
            source_a = 1; source_b = 0;
          end else begin
            source_a = 0; source_b = 2;
          end
        end
        if (stage >= 2 && stage <= 6 && ((issue >> (stage-2)) & 1)) begin
          dest_a = 2; dest_b = 0;
        end
      end
    end else if (pwm_issue) begin
      source_a = tick[5] ? 2'd1 : 2'd0;
      dest_a = source_a;
    end
  end

  always_comb begin
    word_a = (source_a_q == 0) ? fifo_q1 :
             (source_a_q == 1) ? fifo_q2 : fifo_q3;
    word_b = (source_b_q == 0) ? fifo_q1 :
             (source_b_q == 1) ? fifo_q2 : fifo_q3;
    for (int lane = 0; lane < 4; lane++) begin
      bf_mode[lane] = (op_r == OP_INTT && !tag[0].pwm) ? BF_GS : BF_CT;
      bf_ai[lane] = '0;
      bf_bi[lane] = '0;
      bf_zi[lane] = tw[lane];
      if (tag[0].pwm) begin
        bf_bi[lane] = word_a[lane*COEFF_W +: COEFF_W];
        bf_zi[lane] = b_q[lane*COEFF_W +: COEFF_W];
      end else if (tag[0].p >= 3'd2) begin
        bf_ai[lane] = word_a[lane*COEFF_W +: COEFF_W];
        bf_bi[lane] = word_b[lane*COEFF_W +: COEFF_W];
      end else if (tag[0].p == 3'd1) begin
        bf_ai[lane] = (lane < 2) ? word_a[lane*COEFF_W +: COEFF_W]
                                  : word_b[(lane-2)*COEFF_W +: COEFF_W];
        bf_bi[lane] = (lane < 2) ? word_a[(lane+2)*COEFF_W +: COEFF_W]
                                  : word_b[lane*COEFF_W +: COEFF_W];
      end else begin
        bf_ai[lane] = (lane < 2) ? word_a[(lane*2)*COEFF_W +: COEFF_W]
                                  : word_b[((lane-2)*2)*COEFF_W +: COEFF_W];
        bf_bi[lane] = (lane < 2) ? word_a[(lane*2+1)*COEFF_W +: COEFF_W]
                                  : word_b[((lane-2)*2+1)*COEFF_W +: COEFF_W];
      end
      if (op_r == OP_INTT && !tag[0].pwm && tw[lane] != 0)
        bf_zi[lane] = COEFF_W'(Q) - tw[lane];
    end
  end

  // Twiddle addresses are generated from the same logical coefficient pairs
  // checked by the Python index model. For len < 4, several groups occupy one
  // cycle, so each lane receives its own twiddle ROM read.
  always_comb begin
    for (int lane = 0; lane < 4; lane++) begin
      logic [8:0] a_index;
      logic [8:0] group_index;
      if (p >= 3'd2) begin
        group_index = 9'(issue) >> (p-2);
        a_index = (group_index << (p+1)) +
                  ((9'(issue) & ((9'd1 << (p-2))-1)) << 2) + 9'(lane);
      end else if (p == 3'd1) begin
        a_index = (9'(issue) << 3) + 9'((lane/2)*4 + (lane%2));
      end else begin
        a_index = (9'(issue) << 3) + 9'(lane*2);
      end
      group_index = a_index >> (p+1);
      tw_addr[lane] = (op_r == OP_NTT) ?
                      (8'd1 << stage) + 8'(group_index) :
                      (8'd255 >> p) - 8'(group_index);
    end
  end

  // Isolate the FIFO read/mux path from the GS modular subtractor. The tag
  // pipeline below grows by the same cycle so destination routing stays exact.
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < 4; i++) begin
        bf_ai_q[i] <= '0;
        bf_bi_q[i] <= '0;
        bf_zi_q[i] <= '0;
        bf_mode_q[i] <= BF_CT;
      end
    end else begin
      for (int i = 0; i < 4; i++) begin
        bf_ai_q[i] <= bf_ai[i];
        bf_bi_q[i] <= bf_bi[i];
        bf_zi_q[i] <= bf_zi[i];
        bf_mode_q[i] <= bf_mode[i];
      end
    end
  end
  genvar lane;
  generate for (lane = 0; lane < 4; lane = lane + 1) begin: g_bf
    twiddle_rom u_tw (.clk(clk), .addr_i(tw_addr[lane]), .tw_o(tw[lane]));
    butterfly_unit u_bf (.clk(clk), .rst(rst), .mode_i(bf_mode_q[lane]),
                         .a_i(bf_ai_q[lane]), .b_i(bf_bi_q[lane]),
                         .zeta_i(bf_zi_q[lane]),
                         .a_o(bf_ao[lane]), .b_o(bf_bo[lane]));
  end endgenerate

  // Result reassembly. INTT divides each stage output by two, so eight GS
  // stages incorporate the 1/256 scale without a separate scaling pass.
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin result_a <= '0; result_b <= '0; end
    else begin
      for (int lane = 0; lane < 4; lane++) begin
        logic [COEFF_W-1:0] x, y;
        x = (tag[PIPE-2].inverse) ? half_mod(bf_ao[lane]) : bf_ao[lane];
        y = (tag[PIPE-2].inverse) ? half_mod(bf_bo[lane]) : bf_bo[lane];
        if (tag[PIPE-2].pwm) begin
          result_a[lane*COEFF_W +: COEFF_W] <= x;
        end else if (tag[PIPE-2].p >= 3'd2) begin
          result_a[lane*COEFF_W +: COEFF_W] <= x;
          result_b[lane*COEFF_W +: COEFF_W] <= y;
        end else if (tag[PIPE-2].p == 3'd1) begin
          if (lane < 2) begin
            result_a[lane*COEFF_W +: COEFF_W] <= x;
            result_a[(lane+2)*COEFF_W +: COEFF_W] <= y;
          end else begin
            result_b[(lane-2)*COEFF_W +: COEFF_W] <= x;
            result_b[lane*COEFF_W +: COEFF_W] <= y;
          end
        end else begin
          if (lane < 2) begin
            result_a[(lane*2)*COEFF_W +: COEFF_W] <= x;
            result_a[(lane*2+1)*COEFF_W +: COEFF_W] <= y;
          end else begin
            result_b[((lane-2)*2)*COEFF_W +: COEFF_W] <= x;
            result_b[((lane-2)*2+1)*COEFF_W +: COEFF_W] <= y;
          end
        end
      end
    end
  end

  // The FIFO controls below allow one read and one write to each store on the
  // same edge. Write destinations travel with the eight-cycle BF pipeline.
  always_comb begin
    pop1 = 0; pop2 = 0; pop3 = 0;
    push1 = 0; push2 = 0; push3 = 0;
    push_word1 = '0; push_word2 = '0; push_word3 = '0;
    if (run_issue) begin
      if (source_a == 0 || source_b == 0) pop1 = 1;
      if (source_a == 1 || source_b == 1) pop2 = 1;
      if (source_a == 2 || source_b == 2) pop3 = 1;
    end else if (pwm_issue) begin
      if (source_a == 0) pop1 = 1;
      else pop2 = 1;
    end
    if (state == IDLE && rd_en_i && rd_addr_i[1:0] == 2'd3) begin
      if ((op_r == OP_NTT && !rd_addr_i[2]) ||
          (op_r != OP_NTT && !rd_addr_i[7])) pop1 = 1;
      else pop2 = 1;
    end
    if (load_a) begin
      if (load_dest == 0) begin push1 = 1; push_word1 = completed_word; end
      else begin push2 = 1; push_word2 = completed_word; end
    end else if (tag[PIPE-1].valid) begin
      if (tag[PIPE-1].dest_a == 0) begin push1 = 1; push_word1 = result_a; end
      else if (tag[PIPE-1].dest_a == 1) begin push2 = 1; push_word2 = result_a; end
      else begin push3 = 1; push_word3 = result_a; end
      if (!tag[PIPE-1].pwm) begin
        if (tag[PIPE-1].dest_b == 0) begin push1 = 1; push_word1 = result_b; end
        else if (tag[PIPE-1].dest_b == 1) begin push2 = 1; push_word2 = result_b; end
        else begin push3 = 1; push_word3 = result_b; end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (push1) fifo1[tail1] <= push_word1;
    if (push2) fifo2[tail2] <= push_word2;
    if (push3) fifo3[tail3] <= push_word3;
    if ((pop1 && state == RUN) || (rd_en_i && state == IDLE))
      fifo_q1 <= fifo1[head1];
    if ((pop2 && state == RUN) || (rd_en_i && state == IDLE))
      fifo_q2 <= fifo2[head2];
    if (pop3 && state == RUN) fifo_q3 <= fifo3[head3];
    if (pwm_issue) b_q <= b_words[tick[5:0]];
  end
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      head1 <= 0; tail1 <= 0; head2 <= 0; tail2 <= 0;
      head3 <= 0; tail3 <= 0;
      count1 <= 0; count2 <= 0; count3 <= 0;
      source_a_q <= 0; source_b_q <= 1;
      for (int i = 0; i < PIPE; i++) tag[i] <= '0;
    end else begin
      if (pop1) head1 <= head1 + 1'b1;
      if (pop2) head2 <= head2 + 1'b1;
      if (pop3) head3 <= head3 + 1'b1;
      if (push1) tail1 <= tail1 + 1'b1;
      if (push2) tail2 <= tail2 + 1'b1;
      if (push3) tail3 <= tail3 + 1'b1;
      count1 <= count1 + 6'(push1) - 6'(pop1);
      count2 <= count2 + 6'(push2) - 6'(pop2);
      count3 <= count3 + 5'(push3) - 5'(pop3);
      source_a_q <= source_a; source_b_q <= source_b;
      tag[0].valid <= run_issue || pwm_issue;
      tag[0].pwm <= pwm_issue;
      tag[0].inverse <= op_r == OP_INTT;
      tag[0].p <= p;
      tag[0].dest_a <= dest_a;
      tag[0].dest_b <= dest_b;
      for (int i = 1; i < PIPE; i++) tag[i] <= tag[i-1];
    end
  end

  // Share the synchronous FIFO read ports with the output stream. The read
  // selector is registered on the same edge as fifo_q1/fifo_q2, so the
  // wrapper still observes a one-cycle read without an asynchronous RAM tap.
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      read_sel_q <= 0;
      read_lane_q <= 0;
    end else if (state == IDLE && rd_en_i) begin
      read_sel_q <= (op_r == OP_NTT) ? rd_addr_i[2] : rd_addr_i[7];
      read_lane_q <= rd_addr_i[1:0];
    end
  end
  always_comb begin
    read_word = read_sel_q ? fifo_q2 : fifo_q1;
    rd_data_o = read_word[read_lane_q*COEFF_W +: COEFF_W];
  end

  assign busy_o = state != IDLE;
  assign done_o = state == DONE;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE; op_r <= OP_NTT; tick <= 0; drain <= 0;
    end else begin
      case (state)
        IDLE: if (start_i) begin
          op_r <= op_i; tick <= 0; drain <= 0; state <= RUN;
        end
        RUN: if ((op_r == OP_PWM && tick == 8'd63) ||
                 (op_r != OP_PWM && tick == 8'd255)) begin
          tick <= tick + 1'b1; drain <= 0; state <= DRAIN;
        end else tick <= tick + 1'b1;
        DRAIN: if (drain == PIPE-1) state <= DONE;
               else drain <= drain + 1'b1;
        DONE: state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk) if (!rst) begin
    if (pop1 && count1 == 0) $fatal(1, "FIFO1 underflow");
    if (pop2 && count2 == 0) $fatal(1, "FIFO2 underflow");
    if (pop3 && count3 == 0) $fatal(1, "FIFO3 underflow");
    if (push1 && !pop1 && count1 == 32) $fatal(1, "FIFO1 overflow");
    if (push2 && !pop2 && count2 == 32) $fatal(1, "FIFO2 overflow");
    if (push3 && !pop3 && count3 == 16) $fatal(1, "FIFO3 overflow");
  end
`endif
endmodule
