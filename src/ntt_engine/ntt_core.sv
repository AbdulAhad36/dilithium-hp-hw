// ============================================================================
// ntt_core.sv  --  Memory-based NTT / INTT core  (increment 3a: pipelined)
// ----------------------------------------------------------------------------
// Pipelined single-butterfly core. Same proven NTT/INTT schedule as increment
// 2, but instead of holding each butterfly's inputs for its full latency, one
// butterfly is *issued every clock cycle*: within a stage all 128 butterflies
// touch disjoint index pairs, so they are independent and can be pipelined.
//
//   issue (cycle t)  : address generator emits (ra, rb, k) for butterfly t
//   feed  (cycle t+1): mem read + twiddle ready -> butterfly fed
//   write (cycle t+1+BF_LAT): butterfly result written back to mem
//
// A BF_LAT-deep write-delay line carries each butterfly's write addresses
// alongside the pipeline so results land at the right place. Between stages a
// short DRAIN lets all in-flight writes settle before the next stage reads
// (the only inter-stage hazard). The INTT SCALE pass (x N_INV) is pipelined
// the same way, reusing the butterfly in CT mode with a = 0.
//
// ~10x faster than increment 2 (~1.1k cycles/transform). Increment 3b widens
// this to the 4-butterfly 2x2 tile with conflict-free banking.
//
// Verified by tb_ntt_core.sv (golden-compared against ntt_ref_pkg).
// OP_PWM still needs a two-operand interface -- a later increment.
// ============================================================================
import ntt_pkg::*;

module ntt_core (
    input  logic                 clk,
    input  logic                 rst,

    input  logic                 start_i,
    input  ntt_op_e               op_i,
    output logic                  busy_o,
    output logic                  done_o,

    input  logic                  wr_en_i,
    input  logic [LOGN-1:0]        wr_addr_i,
    input  logic [COEFF_W-1:0]     wr_data_i,
    input  logic                   rd_en_i,
    input  logic [LOGN-1:0]        rd_addr_i,
    output logic [COEFF_W-1:0]     rd_data_o
);

  localparam int unsigned BF_LAT    = 4;   // butterfly_unit latency
  localparam int unsigned DRAIN_LEN = 6;   // >= BF_LAT+1, lets writes settle

  // ==========================================================================
  // Coefficient memory : flat 256 x 23-bit
  // ==========================================================================
  logic [COEFF_W-1:0] mem [N];

  // ==========================================================================
  // Twiddle ROM (synchronous: tw_data valid 1 cycle after tw_addr)
  // ==========================================================================
  logic [LOGN-1:0]    tw_addr;
  logic [COEFF_W-1:0] tw_data;

  twiddle_rom u_tw (.clk(clk), .addr_i(tw_addr), .tw_o(tw_data));

  // ==========================================================================
  // Single butterfly unit
  // ==========================================================================
  bf_mode_e            bf_mode;
  logic [COEFF_W-1:0]  bf_a_i, bf_b_i, bf_zeta;
  logic [COEFF_W-1:0]  bf_a_o, bf_b_o;

  butterfly_unit u_bf (
      .clk(clk), .rst(rst), .mode_i(bf_mode),
      .a_i(bf_a_i), .b_i(bf_b_i), .zeta_i(bf_zeta),
      .a_o(bf_a_o), .b_o(bf_b_o)
  );

  function automatic logic [COEFF_W-1:0] modneg(input logic [COEFF_W-1:0] x);
    return (x == '0) ? '0 : (COEFF_W'(Q) - x);
  endfunction

  // ==========================================================================
  // Control FSM
  //   IDLE -> [RUN stage -> DRAIN] x8 -> [INTT: SCALE -> SDRAIN] -> DONE
  // ==========================================================================
  typedef enum logic [2:0] {
    S_IDLE, S_RUN, S_DRAIN, S_SCALE, S_SDRAIN, S_DONE
  } state_e;

  state_e      state;
  ntt_op_e     op_r;
  logic        fwd;
  logic [8:0]  len_r;          // butterfly half-distance
  logic [8:0]  start_r;        // group base index
  logic [8:0]  jg_r;           // index within group
  logic [8:0]  k_r;            // twiddle index
  logic [8:0]  sc_r;           // SCALE-pass coefficient index
  logic [3:0]  drain_cnt;
  logic        post_run;       // last DRAIN before SCALE/DONE

  // --------------------------------------------------------------------------
  // Address generator (combinational, over the loop counters)
  // --------------------------------------------------------------------------
  logic        issue_valid;
  logic        issue_scale;
  logic [8:0]  issue_ra, issue_rb;
  bf_mode_e    issue_mode;

  always_comb begin
    issue_valid = (state == S_RUN) || (state == S_SCALE);
    issue_scale = (state == S_SCALE);
    if (issue_scale) begin
      issue_ra = '0;
      issue_rb = sc_r;                       // scale: read & write mem[sc_r]
    end else begin
      issue_ra = start_r + jg_r;             // butterfly pair
      issue_rb = (start_r + jg_r) + len_r;
    end
    issue_mode = (op_r == OP_INTT && !issue_scale) ? BF_GS : BF_CT;
    tw_addr    = k_r[LOGN-1:0];
  end

  // --------------------------------------------------------------------------
  // Feed stage : registered one cycle after issue (twiddle ROM now valid)
  // --------------------------------------------------------------------------
  logic [8:0]  feed_ra, feed_rb;
  logic        feed_valid, feed_scale;
  bf_mode_e    feed_mode;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      feed_ra <= '0; feed_rb <= '0;
      feed_valid <= 1'b0; feed_scale <= 1'b0; feed_mode <= BF_CT;
    end else begin
      feed_ra    <= issue_ra;
      feed_rb    <= issue_rb;
      feed_valid <= issue_valid;
      feed_scale <= issue_scale;
      feed_mode  <= issue_mode;
    end
  end

  // butterfly inputs at the feed cycle
  always_comb begin
    bf_mode = feed_mode;
    bf_a_i  = feed_scale ? '0 : mem[feed_ra[LOGN-1:0]];
    bf_b_i  = mem[feed_rb[LOGN-1:0]];
    bf_zeta = feed_scale ? COEFF_W'(N_INV)
                         : (fwd ? tw_data : modneg(tw_data));
  end

  // --------------------------------------------------------------------------
  // Write-delay line : carry write addresses BF_LAT cycles to meet bf outputs
  // --------------------------------------------------------------------------
  logic [8:0]  w_ra  [BF_LAT];
  logic [8:0]  w_rb  [BF_LAT];
  logic        w_vld [BF_LAT];
  logic        w_scl [BF_LAT];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < BF_LAT; i++) begin
        w_ra[i] <= '0; w_rb[i] <= '0; w_vld[i] <= 1'b0; w_scl[i] <= 1'b0;
      end
    end else begin
      w_ra[0] <= feed_ra;  w_rb[0] <= feed_rb;
      w_vld[0] <= feed_valid;  w_scl[0] <= feed_scale;
      for (int i = 1; i < BF_LAT; i++) begin
        w_ra[i] <= w_ra[i-1];  w_rb[i] <= w_rb[i-1];
        w_vld[i] <= w_vld[i-1];  w_scl[i] <= w_scl[i-1];
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory write : pipelined butterfly/scale results, else external load
  // --------------------------------------------------------------------------
  logic        wb_valid;
  logic [8:0]  wb_ra, wb_rb;
  logic        wb_scale;
  assign wb_valid = w_vld[BF_LAT-1];
  assign wb_ra    = w_ra [BF_LAT-1];
  assign wb_rb    = w_rb [BF_LAT-1];
  assign wb_scale = w_scl[BF_LAT-1];

  always_ff @(posedge clk) begin
    if (wb_valid) begin
      if (wb_scale) begin
        mem[wb_rb[LOGN-1:0]] <= bf_a_o;           // scaled coefficient
      end else begin
        mem[wb_ra[LOGN-1:0]] <= bf_a_o;
        mem[wb_rb[LOGN-1:0]] <= bf_b_o;
      end
    end else if (wr_en_i && state == S_IDLE) begin
      mem[wr_addr_i] <= wr_data_i;                // external load
    end
  end

  // --------------------------------------------------------------------------
  // Memory read port (registered)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rd_en_i) rd_data_o <= mem[rd_addr_i];
  end

  // --------------------------------------------------------------------------
  // Control FSM
  // --------------------------------------------------------------------------
  logic last_in_group, last_group, last_stage;
  always_comb begin
    last_in_group = (jg_r == len_r - 1'b1);
    last_group    = ((start_r + (len_r << 1)) == N);
    last_stage    = (fwd && len_r == 9'd1) || (!fwd && len_r == 9'd128);
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state    <= S_IDLE;
      busy_o   <= 1'b0;
      done_o   <= 1'b0;
      op_r     <= OP_NTT;
      fwd      <= 1'b1;
      len_r    <= 9'd128;
      start_r  <= '0;
      jg_r     <= '0;
      k_r      <= 9'd1;
      sc_r     <= '0;
      drain_cnt<= '0;
      post_run <= 1'b0;
    end else begin
      done_o <= 1'b0;
      case (state)

        // ---- wait for a start pulse ---------------------------------------
        S_IDLE: begin
          if (start_i) begin
            op_r    <= op_i;
            busy_o  <= 1'b1;
            fwd     <= (op_i != OP_INTT);
            len_r   <= (op_i != OP_INTT) ? 9'd128 : 9'd1;
            start_r <= '0;
            jg_r    <= '0;
            k_r     <= (op_i != OP_INTT) ? 9'd1 : 9'd255;
            post_run<= 1'b0;
            state   <= S_RUN;
          end
        end

        // ---- issue one butterfly per cycle --------------------------------
        S_RUN: begin
          if (!last_in_group) begin
            jg_r <= jg_r + 1'b1;
          end else begin
            jg_r <= '0;
            if (!last_group) begin
              start_r <= start_r + (len_r << 1);
              k_r     <= fwd ? k_r + 1'b1 : k_r - 1'b1;
            end else begin
              // stage complete -> drain
              if (last_stage) begin
                post_run <= 1'b1;
              end else begin
                start_r <= '0;
                len_r   <= fwd ? (len_r >> 1) : (len_r << 1);
                k_r     <= fwd ? k_r + 1'b1 : k_r - 1'b1;
              end
              drain_cnt <= '0;
              state     <= S_DRAIN;
            end
          end
        end

        // ---- let in-flight writes settle ----------------------------------
        S_DRAIN: begin
          if (drain_cnt == DRAIN_LEN[3:0]) begin
            if (post_run) begin
              if (op_r == OP_INTT) begin
                sc_r  <= '0;
                state <= S_SCALE;
              end else begin
                state <= S_DONE;
              end
            end else begin
              state <= S_RUN;
            end
          end else begin
            drain_cnt <= drain_cnt + 1'b1;
          end
        end

        // ---- INTT SCALE pass : coeff <- coeff * N_INV ---------------------
        S_SCALE: begin
          if (sc_r == 9'd255) begin
            drain_cnt <= '0;
            state     <= S_SDRAIN;
          end else begin
            sc_r <= sc_r + 1'b1;
          end
        end
        S_SDRAIN: begin
          if (drain_cnt == DRAIN_LEN[3:0]) state <= S_DONE;
          else                             drain_cnt <= drain_cnt + 1'b1;
        end

        // ---- done : single-cycle pulse ------------------------------------
        S_DONE: begin
          busy_o <= 1'b0;
          done_o <= 1'b1;
          state  <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule : ntt_core
