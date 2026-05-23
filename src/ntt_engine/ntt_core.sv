// ============================================================================
// ntt_core.sv  --  Memory-based NTT / INTT core  (increment 3b: 2x2 tile)
// ----------------------------------------------------------------------------
// 4-butterfly 2x2 tile + intra-tile stage forwarding. One TILE issued per
// clock cycle: 4 coefficients are processed by 4 butterfly units arranged as
// two ranks of two (rank-s does the coarse stage, rank-t does the fine stage
// fed directly from rank-s outputs, no mem hop between stages). 8 radix-2
// stages collapse to 4 memory passes of 64 tiles each.
//
//   compute cycles  ~=  N_PASSES x 64 + drain  ~=  ~290  (NTT)
//                  ~=  292 + 64-tile SCALE pass + drain  ~=  ~360  (INTT)
//
// Pipeline (one tile, T = issue cycle):
//   T    : address-gen issues (a0..a3, k_a/b/c, sc_flag) combinationally.
//          Flat mem read combinational; sync twiddle ROMs see addrs.
//   T+1  : mem regs (m_r0..3) + twiddle ROM outputs (tw_a/b/c) valid.
//          -> feed rank-s BFUs (BFU0/1) with m_r* and outer/inner twiddles
//             (NTT: outer tw_a to both; INTT: inner tw_b/c, negated).
//          -> for SCALE only: feed rank-t BFUs (BFU2/3) the same cycle with
//             m_r2/m_r3 x N_INV (4 multipliers used in parallel).
//   T+5  : BFU0/1 outputs (rank-s done). For RUN: feed BFU2/3 with rank-s
//          outputs + delayed inner twiddles (NTT) / delayed outer twiddle
//          (INTT, broadcast to both).
//   T+5  : (SCALE) BFU0..3 outputs are the scaled coefficients; write back
//          to mem at the 4 issue addresses.
//   T+9  : (RUN) BFU2/3 outputs (rank-t done); write back 4 coeffs to mem
//          at the 4 issue addresses, with the NTT- or INTT-specific
//          (rank-t output -> position) mapping.
//
// Memory model: flat 256x23 array with combinational 4R + 4W per cycle.
// In simulation this is direct; for synthesis-to-BRAM it will be refactored
// to 4 conflict-free banks (the address-resolver-ROM scheme of section 4.3a)
// in a follow-up increment. The compute schedule and cycle count are the
// same either way -- banking is purely about which RAM ports the 4 accesses
// land on.
//
// Verified by tb_ntt_core.sv and the full UVM env (tb_uvm/tb_uvm_ntt/).
// OP_PWM still needs a two-operand interface -- a later increment.
// ============================================================================
import ntt_pkg::*;

module ntt_core (
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  start_i,
    input  ntt_op_e               op_i,
    output logic                  busy_o,
    output logic                  done_o,

    input  logic                  wr_en_i,
    input  logic [LOGN-1:0]       wr_addr_i,
    input  logic [COEFF_W-1:0]    wr_data_i,
    input  logic                  rd_en_i,
    input  logic [LOGN-1:0]       rd_addr_i,
    output logic [COEFF_W-1:0]    rd_data_o
);

  // ===========================================================================
  // Pipeline / timing constants
  // ===========================================================================
  localparam int unsigned BF_LAT     = 4;                // butterfly_unit latency
  localparam int unsigned MEM_LAT    = 1;                // mem-read register
  localparam int unsigned RUN_LAT    = MEM_LAT + 2*BF_LAT; // = 9, RUN issue -> writeback
  localparam int unsigned SCL_LAT    = MEM_LAT + BF_LAT;   // = 5, SCALE issue -> writeback
  localparam int unsigned WB_DEPTH   = RUN_LAT;          // shift-reg length (deepest path)
  localparam int unsigned DRAIN_LEN  = RUN_LAT + 1;      // 10 cycles between passes

  // ===========================================================================
  // Coefficient memory  : flat 256 x 23
  // ===========================================================================
  logic [COEFF_W-1:0] mem [N];

  // ===========================================================================
  // Three twiddle ROMs (synchronous read, 1-cycle latency)
  // ===========================================================================
  logic [LOGN-1:0]    tw_a_addr, tw_b_addr, tw_c_addr;
  logic [COEFF_W-1:0] tw_a, tw_b, tw_c;
  twiddle_rom u_tw_a (.clk(clk), .addr_i(tw_a_addr), .tw_o(tw_a));
  twiddle_rom u_tw_b (.clk(clk), .addr_i(tw_b_addr), .tw_o(tw_b));
  twiddle_rom u_tw_c (.clk(clk), .addr_i(tw_c_addr), .tw_o(tw_c));

  // ===========================================================================
  // 4 butterfly units: rank-s (BFU0, BFU1)  ->  rank-t (BFU2, BFU3)
  // ===========================================================================
  bf_mode_e            bf0_mode, bf1_mode, bf2_mode, bf3_mode;
  logic [COEFF_W-1:0]  bf0_a_i, bf0_b_i, bf0_z, bf0_a_o, bf0_b_o;
  logic [COEFF_W-1:0]  bf1_a_i, bf1_b_i, bf1_z, bf1_a_o, bf1_b_o;
  logic [COEFF_W-1:0]  bf2_a_i, bf2_b_i, bf2_z, bf2_a_o, bf2_b_o;
  logic [COEFF_W-1:0]  bf3_a_i, bf3_b_i, bf3_z, bf3_a_o, bf3_b_o;

  butterfly_unit u_bf0 (.clk(clk), .rst(rst), .mode_i(bf0_mode),
                        .a_i(bf0_a_i), .b_i(bf0_b_i), .zeta_i(bf0_z),
                        .a_o(bf0_a_o), .b_o(bf0_b_o));
  butterfly_unit u_bf1 (.clk(clk), .rst(rst), .mode_i(bf1_mode),
                        .a_i(bf1_a_i), .b_i(bf1_b_i), .zeta_i(bf1_z),
                        .a_o(bf1_a_o), .b_o(bf1_b_o));
  butterfly_unit u_bf2 (.clk(clk), .rst(rst), .mode_i(bf2_mode),
                        .a_i(bf2_a_i), .b_i(bf2_b_i), .zeta_i(bf2_z),
                        .a_o(bf2_a_o), .b_o(bf2_b_o));
  butterfly_unit u_bf3 (.clk(clk), .rst(rst), .mode_i(bf3_mode),
                        .a_i(bf3_a_i), .b_i(bf3_b_i), .zeta_i(bf3_z),
                        .a_o(bf3_a_o), .b_o(bf3_b_o));

  function automatic logic [COEFF_W-1:0] modneg(input logic [COEFF_W-1:0] x);
    return (x == '0) ? '0 : (COEFF_W'(Q) - x);
  endfunction

  // ===========================================================================
  // FSM  :  IDLE -> [RUN -> RDRAIN] x 4 -> (INTT: SCALE -> SDRAIN) -> DONE
  // ===========================================================================
  typedef enum logic [2:0] {
    S_IDLE, S_RUN, S_RDRAIN, S_SCALE, S_SDRAIN, S_DONE
  } state_e;
  state_e       state;
  ntt_op_e      op_r;
  logic         fwd;
  logic [1:0]   pass_r;        // 0..3
  logic [6:0]   g_outer_r;     // outer-group counter (0..63)
  logic [6:0]   off_r;         // intra-group offset
  logic [6:0]   sc_r;          // SCALE tile counter (0..63)
  logic [3:0]   drain_cnt;
  logic         last_pass;     // marks the final pass before SCALE/DONE

  // Per-pass schedule limits (combinational from pass_r and fwd):
  //   NTT  pass p: L = 128 >> 2p, off_max = L/2,   g_max = 2^(2p)
  //   INTT pass p: L = 1   << 2p, off_max = L,     g_max = 64 >> 2p
  //
  // NB: pass_r is 2 bits but `pass_r << 1` is taken in 2-bit context too --
  // for pass_r=2,3 the shift overflows and gives the wrong amount. Widen the
  // shift amounts explicitly via 4-bit signals.
  logic [3:0] sh2p;    // 0, 2, 4, 6  (= 2 * pass_r)
  logic [3:0] sh2p1;   // 1, 3, 5, 7  (= 2 * pass_r + 1)
  assign sh2p  = {2'b0, pass_r} << 1;
  assign sh2p1 = sh2p + 4'd1;

  logic [8:0] L;
  logic [6:0] off_max;
  logic [6:0] g_max;
  always_comb begin
    if (fwd) begin
      L       = 9'd128 >> sh2p;
      off_max = 7'(L >> 1);
      g_max   = 7'((9'd1) << sh2p);
    end else begin
      L       = (9'd1) << sh2p;
      off_max = 7'(L);
      g_max   = 7'(9'd64 >> sh2p);
    end
  end

  // ===========================================================================
  // Address generation  (combinational from pass_r, g_outer_r, off_r, fwd)
  //
  // Tile coverage:
  //   NTT  tile {b, b+L/2, b+L, b+3L/2}   with b = g_outer*2L + off
  //   INTT tile {b, b+L,   b+2L, b+3L}    with b = g_outer*4L + off
  //
  // Twiddle indices (k):
  //   NTT  k_outer = 2^(2p) + g_outer  (stage 2p, fed to BFU0/1)
  //        k_inner_l = 2^(2p+1) + 2*g_outer  (stage 2p+1, fed to BFU2)
  //        k_inner_r = k_inner_l + 1         (stage 2p+1, fed to BFU3)
  //   INTT k_outer = 256/(2L) - 1 - g_outer  (stage 2p+1, fed to BFU2/3, broadcast)
  //        k_inner_l = 256/L    - 1 - 2*g_outer  (stage 2p, fed to BFU0)
  //        k_inner_r = k_inner_l - 1             (stage 2p, fed to BFU1)
  // ===========================================================================
  logic [8:0]  a0_idx, a1_idx, a2_idx, a3_idx;
  logic [8:0]  base_b;
  logic [LOGN-1:0] k_a, k_b, k_c;
  logic        issue_run;
  logic        issue_scale;

  always_comb begin
    issue_run   = (state == S_RUN);
    issue_scale = (state == S_SCALE);

    if (issue_scale) begin
      // SCALE: pack 4 coefficients per cycle at {4*sc_r .. 4*sc_r+3}
      a0_idx = {sc_r, 2'b00};
      a1_idx = {sc_r, 2'b01};
      a2_idx = {sc_r, 2'b10};
      a3_idx = {sc_r, 2'b11};
      k_a    = '0; k_b = '0; k_c = '0;   // twiddles unused in SCALE
      base_b = '0;
    end else if (fwd) begin
      base_b = (9'(g_outer_r) * (L << 1)) + 9'(off_r);
      a0_idx = base_b;
      a1_idx = base_b + (L >> 1);
      a2_idx = base_b + L;
      a3_idx = base_b + L + (L >> 1);
      k_a    = LOGN'((9'd1 << sh2p)  + 9'(g_outer_r));
      k_b    = LOGN'((9'd1 << sh2p1) + (9'(g_outer_r) << 1));
      k_c    = k_b + LOGN'(1);
    end else begin
      base_b = (9'(g_outer_r) * (L << 2)) + 9'(off_r);
      a0_idx = base_b;
      a1_idx = base_b + L;
      a2_idx = base_b + (L << 1);
      a3_idx = base_b + (L << 1) + L;
      k_b    = LOGN'((9'd256 >> sh2p)  - 9'd1 - (9'(g_outer_r) << 1));
      k_c    = k_b - LOGN'(1);
      k_a    = LOGN'((9'd256 >> sh2p1) - 9'd1 - 9'(g_outer_r));
    end

    tw_a_addr = k_a;
    tw_b_addr = k_b;
    tw_c_addr = k_c;
  end

  // ===========================================================================
  // Stage-1 registers : capture mem reads + flags (issue@T -> available@T+1)
  // (tw_a/b/c become valid at T+1 directly from the sync ROMs.)
  // ===========================================================================
  logic [COEFF_W-1:0] m_r0, m_r1, m_r2, m_r3;
  logic               v_s1, sc_s1;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      m_r0  <= '0; m_r1 <= '0; m_r2 <= '0; m_r3 <= '0;
      v_s1  <= 1'b0;
      sc_s1 <= 1'b0;
    end else begin
      m_r0  <= mem[a0_idx[LOGN-1:0]];
      m_r1  <= mem[a1_idx[LOGN-1:0]];
      m_r2  <= mem[a2_idx[LOGN-1:0]];
      m_r3  <= mem[a3_idx[LOGN-1:0]];
      v_s1  <= issue_run || issue_scale;
      sc_s1 <= issue_scale;
    end
  end

  // ===========================================================================
  // BF_LAT-deep delay line for the 3 twiddles + valid + sc flag.
  // These are needed BF_LAT cycles after stage-s feed to drive the rank-t
  // inputs (only relevant for RUN; SCALE feeds rank-t directly at T+1).
  // ===========================================================================
  logic [COEFF_W-1:0] twa_dly [BF_LAT];
  logic [COEFF_W-1:0] twb_dly [BF_LAT];
  logic [COEFF_W-1:0] twc_dly [BF_LAT];
  logic               vt_dly  [BF_LAT];
  logic               sct_dly [BF_LAT];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < BF_LAT; i++) begin
        twa_dly[i] <= '0; twb_dly[i] <= '0; twc_dly[i] <= '0;
        vt_dly[i]  <= 1'b0; sct_dly[i] <= 1'b0;
      end
    end else begin
      twa_dly[0] <= tw_a;
      twb_dly[0] <= tw_b;
      twc_dly[0] <= tw_c;
      vt_dly [0] <= v_s1;
      sct_dly[0] <= sc_s1;
      for (int i = 1; i < BF_LAT; i++) begin
        twa_dly[i] <= twa_dly[i-1];
        twb_dly[i] <= twb_dly[i-1];
        twc_dly[i] <= twc_dly[i-1];
        vt_dly [i] <= vt_dly [i-1];
        sct_dly[i] <= sct_dly[i-1];
      end
    end
  end

  // ===========================================================================
  // BFU input mux (combinational)
  //   BFU0/1 fed at stage-1 cycle (T+1) -- RUN or SCALE
  //   BFU2/3 fed at SCALE: same cycle (T+1) with m_r2/m_r3, N_INV
  //          fed at RUN  : T+5, with BFU0/1 outputs + delayed inner/outer tw
  // ===========================================================================
  logic vt_tail, sct_tail;
  assign vt_tail  = vt_dly [BF_LAT-1];
  assign sct_tail = sct_dly[BF_LAT-1];

  always_comb begin
    // ---- rank-s (BFU0, BFU1) -------------------------------------------------
    if (sc_s1) begin
      // SCALE: multiply each mem coeff by N_INV (CT with a=0 -> a_o = b*z)
      bf0_mode = BF_CT;   bf1_mode = BF_CT;
      bf0_a_i  = '0;      bf0_b_i  = m_r0; bf0_z = COEFF_W'(N_INV);
      bf1_a_i  = '0;      bf1_b_i  = m_r1; bf1_z = COEFF_W'(N_INV);
    end else if (fwd) begin
      // NTT stage 2p (CT): pairs (b,b+L) and (b+L/2, b+3L/2); same outer tw
      bf0_mode = BF_CT;   bf1_mode = BF_CT;
      bf0_a_i  = m_r0;    bf0_b_i  = m_r2; bf0_z = tw_a;
      bf1_a_i  = m_r1;    bf1_b_i  = m_r3; bf1_z = tw_a;
    end else begin
      // INTT stage 2p (GS): pairs (b,b+L) and (b+2L,b+3L); two inner tw
      bf0_mode = BF_GS;   bf1_mode = BF_GS;
      bf0_a_i  = m_r0;    bf0_b_i  = m_r1; bf0_z = modneg(tw_b);
      bf1_a_i  = m_r2;    bf1_b_i  = m_r3; bf1_z = modneg(tw_c);
    end

    // ---- rank-t (BFU2, BFU3) -------------------------------------------------
    if (sc_s1) begin
      // SCALE: BFU2/3 also do multiply-by-N_INV on m_r2/m_r3
      bf2_mode = BF_CT;   bf3_mode = BF_CT;
      bf2_a_i  = '0;      bf2_b_i  = m_r2; bf2_z = COEFF_W'(N_INV);
      bf3_a_i  = '0;      bf3_b_i  = m_r3; bf3_z = COEFF_W'(N_INV);
    end else if (vt_tail && !sct_tail) begin
      // RUN stage 2p+1 : rank-s outputs feed rank-s+1 (intra-tile forwarding)
      bf2_mode = fwd ? BF_CT : BF_GS;
      bf3_mode = fwd ? BF_CT : BF_GS;
      bf2_a_i  = bf0_a_o; bf2_b_i = bf1_a_o;
      bf3_a_i  = bf0_b_o; bf3_b_i = bf1_b_o;
      if (fwd) begin
        bf2_z = twb_dly[BF_LAT-1];        // inner left tw
        bf3_z = twc_dly[BF_LAT-1];        // inner right tw
      end else begin
        bf2_z = modneg(twa_dly[BF_LAT-1]);// outer tw, broadcast (negated for GS)
        bf3_z = modneg(twa_dly[BF_LAT-1]);
      end
    end else begin
      bf2_mode = BF_CT;   bf3_mode = BF_CT;
      bf2_a_i  = '0;      bf2_b_i = '0;   bf2_z = '0;
      bf3_a_i  = '0;      bf3_b_i = '0;   bf3_z = '0;
    end
  end

  // ===========================================================================
  // Writeback shift register : addresses + flags travel alongside the pipeline
  // so the BFU outputs land at the correct mem indices.
  //   stage 0 = stage-1 feed (issue+1)
  //   stage 4 = SCALE writeback  (issue+5)
  //   stage 8 = RUN   writeback  (issue+9)
  // ===========================================================================
  typedef struct packed {
    logic [8:0]   a0, a1, a2, a3;
    logic         v;
    logic         sc;
    logic         fwd;
  } wb_entry_t;

  wb_entry_t wb [WB_DEPTH];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < WB_DEPTH; i++) begin
        wb[i] <= '{default:'0};
      end
    end else begin
      wb[0].a0  <= a0_idx; wb[0].a1 <= a1_idx;
      wb[0].a2  <= a2_idx; wb[0].a3 <= a3_idx;
      wb[0].v   <= issue_run || issue_scale;
      wb[0].sc  <= issue_scale;
      wb[0].fwd <= fwd;
      for (int i = 1; i < WB_DEPTH; i++) wb[i] <= wb[i-1];
    end
  end

  // ===========================================================================
  // Memory write
  //   - external load (S_IDLE only): single coefficient via wr_en_i
  //   - SCALE writeback  : 4 coeffs from {bf0_a_o..bf3_a_o} at wb[SCL_LAT-1]
  //   - RUN   writeback  : 4 coeffs from rank-t outputs at wb[RUN_LAT-1]
  //                        position mapping differs NTT vs INTT (see tile docs)
  // ===========================================================================
  wb_entry_t scl_tail, run_tail;
  assign scl_tail = wb[SCL_LAT-1];
  assign run_tail = wb[RUN_LAT-1];

  always_ff @(posedge clk) begin
    if (wr_en_i && state == S_IDLE) begin
      mem[wr_addr_i] <= wr_data_i;
    end
    if (scl_tail.v && scl_tail.sc) begin
      mem[scl_tail.a0[LOGN-1:0]] <= bf0_a_o;
      mem[scl_tail.a1[LOGN-1:0]] <= bf1_a_o;
      mem[scl_tail.a2[LOGN-1:0]] <= bf2_a_o;
      mem[scl_tail.a3[LOGN-1:0]] <= bf3_a_o;
    end
    if (run_tail.v && !run_tail.sc) begin
      if (run_tail.fwd) begin
        // NTT writeback : {b, b+L/2, b+L, b+3L/2}  <-  {bf2.a, bf2.b, bf3.a, bf3.b}
        mem[run_tail.a0[LOGN-1:0]] <= bf2_a_o;
        mem[run_tail.a1[LOGN-1:0]] <= bf2_b_o;
        mem[run_tail.a2[LOGN-1:0]] <= bf3_a_o;
        mem[run_tail.a3[LOGN-1:0]] <= bf3_b_o;
      end else begin
        // INTT writeback : {b, b+L, b+2L, b+3L}  <-  {bf2.a, bf3.a, bf2.b, bf3.b}
        mem[run_tail.a0[LOGN-1:0]] <= bf2_a_o;
        mem[run_tail.a1[LOGN-1:0]] <= bf3_a_o;
        mem[run_tail.a2[LOGN-1:0]] <= bf2_b_o;
        mem[run_tail.a3[LOGN-1:0]] <= bf3_b_o;
      end
    end
  end

  // ===========================================================================
  // External read port (1-cycle registered)
  // ===========================================================================
  always_ff @(posedge clk) begin
    if (rd_en_i) rd_data_o <= mem[rd_addr_i];
  end


  // ===========================================================================
  // FSM
  // ===========================================================================
  logic last_in_pass;
  always_comb begin
    last_in_pass = (off_r == off_max - 7'd1) && (g_outer_r == g_max - 7'd1);
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state     <= S_IDLE;
      busy_o    <= 1'b0;
      done_o    <= 1'b0;
      op_r      <= OP_NTT;
      fwd       <= 1'b1;
      pass_r    <= '0;
      g_outer_r <= '0;
      off_r     <= '0;
      sc_r      <= '0;
      drain_cnt <= '0;
      last_pass <= 1'b0;
    end else begin
      done_o <= 1'b0;
      case (state)

        // ----- wait for a start pulse --------------------------------------
        S_IDLE: begin
          if (start_i) begin
            op_r      <= op_i;
            busy_o    <= 1'b1;
            fwd       <= (op_i != OP_INTT);
            pass_r    <= '0;
            g_outer_r <= '0;
            off_r     <= '0;
            sc_r      <= '0;
            last_pass <= 1'b0;
            state     <= S_RUN;
          end
        end

        // ----- issue one tile per cycle ------------------------------------
        S_RUN: begin
          if (!last_in_pass) begin
            if (off_r == off_max - 7'd1) begin
              off_r     <= '0;
              g_outer_r <= g_outer_r + 7'd1;
            end else begin
              off_r <= off_r + 7'd1;
            end
          end else begin
            // last tile of this pass issued -- go to drain
            off_r     <= '0;
            g_outer_r <= '0;
            drain_cnt <= '0;
            if (pass_r == 2'd3) last_pass <= 1'b1;
            state     <= S_RDRAIN;
          end
        end

        // ----- let RUN pipeline drain (writes settle before next pass) -----
        S_RDRAIN: begin
          if (drain_cnt == DRAIN_LEN[3:0] - 4'd1) begin
            if (!last_pass) begin
              pass_r <= pass_r + 2'd1;
              state  <= S_RUN;
            end else if (op_r == OP_INTT) begin
              sc_r  <= '0;
              state <= S_SCALE;
            end else begin
              state <= S_DONE;
            end
          end else begin
            drain_cnt <= drain_cnt + 4'd1;
          end
        end

        // ----- INTT SCALE pass : 4 coeffs/cycle x N_INV --------------------
        S_SCALE: begin
          if (sc_r == 7'd63) begin
            drain_cnt <= '0;
            state     <= S_SDRAIN;
          end else begin
            sc_r <= sc_r + 7'd1;
          end
        end

        S_SDRAIN: begin
          if (drain_cnt == DRAIN_LEN[3:0] - 4'd1) state <= S_DONE;
          else                                    drain_cnt <= drain_cnt + 4'd1;
        end

        // ----- done : single-cycle pulse, then back to IDLE ----------------
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
