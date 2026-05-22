// ============================================================================
// ntt_core.sv  --  Memory-based NTT / INTT core  (increment 2: correct-first)
// ----------------------------------------------------------------------------
// This is the FUNCTIONALLY-CORRECT core: it implements the exact CRYSTALS-
// Dilithium NTT / INTT schedule with a SINGLE butterfly, one butterfly at a
// time, against a flat 256-coefficient memory. It is deliberately not yet fast
// -- correctness is verified first (golden-compared against ntt_ref_pkg by
// tb_ntt_core.sv); the pipelined conflict-free 2x2 datapath is increment 3.
//
//   - 256 coefficients in a flat memory `mem`.
//   - ONE butterfly_unit. Per butterfly: present (a,b,zeta), hold for the
//     butterfly pipeline latency, write the two results back -- no in-place
//     hazard because the wait fully drains the pipeline.
//   - Forward NTT : Cooley-Tukey, len = 128,64,...,1, twiddle index k = 1..255.
//   - Inverse NTT : Gentleman-Sande, len = 1,2,...,128, k = 255..1, twiddle
//     negated (-zetas[k]); then a SCALE pass multiplies every coefficient by
//     N_INV (the 1/256 factor) reusing the butterfly in CT mode (a=0).
//
// Schedule is a direct mirror of ntt_ref_pkg::ntt_fwd / ntt_inv, so the golden
// model is the exact reference.
//
// OP_PWM is not handled here yet -- it needs a two-operand load interface and
// is a separate increment. tb_ntt_core.sv exercises OP_NTT and OP_INTT only.
// ============================================================================
import ntt_pkg::*;

module ntt_core (
    input  logic                 clk,
    input  logic                 rst,

    // ---- control ----------------------------------------------------------
    input  logic                 start_i,     // pulse: begin an operation
    input  ntt_op_e               op_i,        // OP_NTT / OP_INTT / OP_PWM
    output logic                  busy_o,
    output logic                  done_o,

    // ---- coefficient memory load / unload (one coeff per cycle) -----------
    input  logic                  wr_en_i,
    input  logic [LOGN-1:0]        wr_addr_i,
    input  logic [COEFF_W-1:0]     wr_data_i,
    input  logic                   rd_en_i,
    input  logic [LOGN-1:0]        rd_addr_i,
    output logic [COEFF_W-1:0]     rd_data_o
);

  // Cycles to hold a butterfly's inputs stable before capturing its output.
  // butterfly_unit latency is 4; 6 gives margin (incl. the 1-cycle twiddle ROM
  // read). Generous on purpose -- increment 3 replaces this with true
  // pipelining.
  localparam int unsigned BF_PIPE = 6;

  // ==========================================================================
  // Coefficient memory : flat 256 x 23-bit.
  // ==========================================================================
  logic [COEFF_W-1:0] mem [N];

  // ==========================================================================
  // Twiddle ROM  (synchronous read: tw_data valid 1 cycle after tw_addr)
  // ==========================================================================
  logic [LOGN-1:0]    tw_addr;
  logic [COEFF_W-1:0] tw_data;

  twiddle_rom u_tw (
      .clk    (clk),
      .addr_i (tw_addr),
      .tw_o   (tw_data)
  );

  // ==========================================================================
  // Single butterfly unit  (increment 3 widens this to the 2x2 tile)
  // ==========================================================================
  bf_mode_e            bf_mode;
  logic [COEFF_W-1:0]  bf_a_i, bf_b_i, bf_zeta;
  logic [COEFF_W-1:0]  bf_a_o, bf_b_o;

  butterfly_unit u_bf (
      .clk    (clk),
      .rst    (rst),
      .mode_i (bf_mode),
      .a_i    (bf_a_i),
      .b_i    (bf_b_i),
      .zeta_i (bf_zeta),
      .a_o    (bf_a_o),
      .b_o    (bf_b_o)
  );

  // ==========================================================================
  // Control FSM
  //   IDLE -> (per butterfly: SETUP -> WAIT -> WRITE -> NEXT) x 1024
  //        -> [INTT only: (SC_SETUP -> SC_WAIT -> SC_WRITE -> SC_NEXT) x 256]
  //        -> DONE -> IDLE
  // ==========================================================================
  typedef enum logic [3:0] {
    S_IDLE, S_SETUP, S_WAIT, S_WRITE, S_NEXT,
    S_SC_SETUP, S_SC_WAIT, S_SC_WRITE, S_SC_NEXT, S_DONE
  } state_e;

  state_e      state;

  ntt_op_e     op_r;                 // latched operation
  logic        fwd;                  // 1 = forward NTT, 0 = inverse
  logic [8:0]  len_r;                // butterfly half-distance
  logic [8:0]  start_r;              // current group base index
  logic [7:0]  jg_r;                 // index within group (0..len_r-1)
  logic [8:0]  k_r;                  // twiddle index
  logic [3:0]  wait_cnt;             // butterfly-latency wait counter
  logic [7:0]  sc_i;                 // SCALE-pass coefficient index

  // current coefficient pair (combinational from the loop counters)
  logic [8:0]  idx0_c, idx1_c;
  assign idx0_c = start_r + {1'b0, jg_r};
  assign idx1_c = idx0_c + len_r;

  // -zeta mod q  (inverse-NTT twiddle = modular negation of the forward one)
  function automatic logic [COEFF_W-1:0] modneg(input logic [COEFF_W-1:0] x);
    return (x == '0) ? '0 : (COEFF_W'(Q) - x);
  endfunction

  // is the datapath currently in the SCALE pass?
  logic scaling;
  assign scaling = (state == S_SC_SETUP) ||
                   (state == S_SC_WAIT)  ||
                   (state == S_SC_WRITE);

  // --------------------------------------------------------------------------
  // Datapath wiring (combinational)
  // --------------------------------------------------------------------------
  always_comb begin
    tw_addr = k_r[LOGN-1:0];
    bf_mode = (op_r == OP_INTT && !scaling) ? BF_GS : BF_CT;

    bf_a_i  = '0;
    bf_b_i  = '0;
    bf_zeta = '0;

    if (state == S_SETUP || state == S_WAIT || state == S_WRITE) begin
      // butterfly on the coefficient pair
      bf_a_i  = mem[idx0_c[LOGN-1:0]];
      bf_b_i  = mem[idx1_c[LOGN-1:0]];
      bf_zeta = fwd ? tw_data : modneg(tw_data);
    end else if (scaling) begin
      // SCALE: a_o = 0 + mem[sc_i] * N_INV   (CT butterfly with a = 0)
      bf_a_i  = '0;
      bf_b_i  = mem[sc_i];
      bf_zeta = COEFF_W'(N_INV);
    end
  end

  // --------------------------------------------------------------------------
  // Memory write port : RUN/SCALE results, else external load (when IDLE)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (state == S_WRITE) begin
      mem[idx0_c[LOGN-1:0]] <= bf_a_o;
      mem[idx1_c[LOGN-1:0]] <= bf_b_o;
    end else if (state == S_SC_WRITE) begin
      mem[sc_i]             <= bf_a_o;
    end else if (wr_en_i && state == S_IDLE) begin
      mem[wr_addr_i]        <= wr_data_i;
    end
  end

  // --------------------------------------------------------------------------
  // Memory read port (registered, one-cycle latency)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rd_en_i) rd_data_o <= mem[rd_addr_i];
  end

  // --------------------------------------------------------------------------
  // Control FSM
  // --------------------------------------------------------------------------
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
      wait_cnt <= '0;
      sc_i     <= '0;
    end else begin
      done_o <= 1'b0;
      case (state)

        // ---- idle : wait for a start pulse --------------------------------
        S_IDLE: begin
          if (start_i) begin
            op_r    <= op_i;
            busy_o  <= 1'b1;
            fwd     <= (op_i != OP_INTT);
            len_r   <= (op_i != OP_INTT) ? 9'd128 : 9'd1;
            start_r <= '0;
            jg_r    <= '0;
            k_r     <= (op_i != OP_INTT) ? 9'd1 : 9'd255;
            state   <= S_SETUP;
          end
        end

        // ---- per-butterfly : settle twiddle ROM ---------------------------
        S_SETUP: begin
          wait_cnt <= '0;
          state    <= S_WAIT;
        end

        // ---- per-butterfly : hold inputs through the BF pipeline ----------
        S_WAIT: begin
          if (wait_cnt == BF_PIPE[3:0]) state <= S_WRITE;
          else                          wait_cnt <= wait_cnt + 1'b1;
        end

        // ---- per-butterfly : results written by the memory port -----------
        S_WRITE: state <= S_NEXT;

        // ---- advance the (stage, group, j) loop counters ------------------
        S_NEXT: begin
          if (jg_r != len_r[7:0] - 1'b1) begin
            // next butterfly in the same group
            jg_r  <= jg_r + 1'b1;
            state <= S_SETUP;
          end else begin
            jg_r <= '0;
            if (start_r + 2*len_r != N) begin
              // next group of the same stage
              start_r <= start_r + (len_r << 1);
              k_r     <= fwd ? k_r + 1'b1 : k_r - 1'b1;
              state   <= S_SETUP;
            end else if ((fwd && len_r == 9'd1) ||
                         (!fwd && len_r == 9'd128)) begin
              // all 8 stages done
              if (op_r == OP_INTT) begin
                sc_i  <= '0;
                state <= S_SC_SETUP;
              end else begin
                state <= S_DONE;
              end
            end else begin
              // next stage
              start_r <= '0;
              len_r   <= fwd ? (len_r >> 1) : (len_r << 1);
              k_r     <= fwd ? k_r + 1'b1 : k_r - 1'b1;
              state   <= S_SETUP;
            end
          end
        end

        // ---- SCALE pass (INTT only) : coeff <- coeff * N_INV --------------
        S_SC_SETUP: begin
          wait_cnt <= '0;
          state    <= S_SC_WAIT;
        end
        S_SC_WAIT: begin
          if (wait_cnt == BF_PIPE[3:0]) state <= S_SC_WRITE;
          else                          wait_cnt <= wait_cnt + 1'b1;
        end
        S_SC_WRITE: state <= S_SC_NEXT;
        S_SC_NEXT: begin
          if (sc_i == 8'd255) begin
            state <= S_DONE;
          end else begin
            sc_i  <= sc_i + 1'b1;
            state <= S_SC_SETUP;
          end
        end

        // ---- done : single-cycle done pulse -------------------------------
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
