// ============================================================================
// ntt_engine.sv  --  Top-level NTT/INTT/PWM engine (stream front-end)
// ----------------------------------------------------------------------------
// Wraps the verified ntt_core with an AXI4-Stream-style I/O front-end. One
// 23-bit coefficient per beat enters over the sink, the requested operation
// runs on the core, and the result polynomial streams back out the source.
//
//   start_i pulse ->
//     OP_NTT  / OP_INTT : RX A (256)         -> RUN -> TX (256)
//     OP_PWM            : RX A (256) -> RX B (256) -> RUN -> TX (256)
//
//   op_i = OP_NTT  : forward NTT,  Z_q[x]/(x^256+1)
//   op_i = OP_INTT : inverse NTT, includes the 1/N scaling
//   op_i = OP_PWM  : pointwise multiply  c[i] = a[i] * b[i]  mod q
//
// A decoupling input FIFO -- to absorb the bursty coefficient rate of the
// upstream rejection sampler -- is deferred to the integration branch (see
// docs/ntt-design-and-verification.md S4.4). The AXI-Stream `s_tready`
// handshake already provides correct back-pressure for a standalone engine.
//
// STATUS: NTT/INTT verified by tb_ntt_engine + UVM env. PWM added by this
// increment.
// ============================================================================
import ntt_pkg::*;

module ntt_engine (
    input  logic                 clk,
    input  logic                 rst,

    // ---- operation request ------------------------------------------------
    input  logic                  start_i,
    input  ntt_op_e                op_i,
    output logic                   busy_o,
    output logic                   done_o,

    // ---- coefficient sink (input polynomial[ies]) -------------------------
    input  logic [COEFF_W-1:0]     s_tdata,
    input  logic                   s_tvalid,
    input  logic                   s_tlast,    // accepted but not required
    output logic                   s_tready,

    // ---- coefficient source (output polynomial) ---------------------------
    output logic [COEFF_W-1:0]     m_tdata,
    output logic                   m_tvalid,
    output logic                   m_tlast,
    input  logic                   m_tready
);

  // ---- core control / memory wires ----------------------------------------
  logic                  core_start;
  logic                  core_busy;
  logic                  core_done;
  logic                  core_wr_en;
  logic                  core_wr_b_sel;
  logic [LOGN-1:0]       core_wr_addr;
  logic [COEFF_W-1:0]    core_wr_data;
  logic                  core_rd_en;
  logic [LOGN-1:0]       core_rd_addr;
  logic [COEFF_W-1:0]    core_rd_data;
  ntt_op_e               op_r;            // operation latched at start

  ntt_core u_core (
      .clk        (clk),
      .rst        (rst),
      .start_i    (core_start),
      .op_i       (op_r),
      .busy_o     (core_busy),
      .done_o     (core_done),
      .wr_en_i    (core_wr_en),
      .wr_b_sel_i (core_wr_b_sel),
      .wr_addr_i  (core_wr_addr),
      .wr_data_i  (core_wr_data),
      .rd_en_i    (core_rd_en),
      .rd_addr_i  (core_rd_addr),
      .rd_data_o  (core_rd_data)
  );

  // ==========================================================================
  // Front-end FSM
  //   NTT/INTT : IDLE -> RX_A (256) -> RUN_START -> RUN_WAIT -> TX -> DONE
  //   PWM      : IDLE -> RX_A (256) -> RX_B (256) -> RUN_START -> ... -> DONE
  // ==========================================================================
  typedef enum logic [3:0] {
    E_IDLE, E_RX_A, E_RX_B, E_RUN_START, E_RUN_WAIT, E_TX_RD, E_TX_VALID, E_DONE
  } estate_e;

  estate_e        state;
  logic [LOGN:0]  rx_idx;          // 0..256 sink beat counter
  logic [LOGN:0]  tx_idx;          // 0..256 source beat counter

  // --------------------------------------------------------------------------
  // Combinational outputs
  // --------------------------------------------------------------------------
  always_comb begin
    s_tready      = 1'b0;
    m_tvalid      = 1'b0;
    m_tlast       = 1'b0;
    m_tdata       = core_rd_data;

    core_start    = 1'b0;
    core_wr_en    = 1'b0;
    core_wr_b_sel = 1'b0;
    core_wr_addr  = rx_idx[LOGN-1:0];
    core_wr_data  = s_tdata;
    core_rd_en    = 1'b0;
    core_rd_addr  = tx_idx[LOGN-1:0];

    unique case (state)
      E_RX_A: begin
        s_tready      = 1'b1;
        core_wr_en    = s_tvalid;
        core_wr_b_sel = 1'b0;          // operand A
      end
      E_RX_B: begin
        s_tready      = 1'b1;
        core_wr_en    = s_tvalid;
        core_wr_b_sel = 1'b1;          // operand B (PWM)
      end
      E_RUN_START: core_start = 1'b1;
      E_TX_RD:     core_rd_en = 1'b1;
      E_TX_VALID: begin
        m_tvalid = 1'b1;
        m_tlast  = (tx_idx == N-1);
      end
      default: ;
    endcase
  end

  // --------------------------------------------------------------------------
  // Sequential FSM
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state  <= E_IDLE;
      busy_o <= 1'b0;
      done_o <= 1'b0;
      rx_idx <= '0;
      tx_idx <= '0;
      op_r   <= OP_NTT;
    end else begin
      done_o <= 1'b0;
      unique case (state)

        // ---- wait for a request -------------------------------------------
        E_IDLE: begin
          if (start_i) begin
            op_r   <= op_i;
            busy_o <= 1'b1;
            rx_idx <= '0;
            state  <= E_RX_A;
          end
        end

        // ---- load 256 coefficients of operand A ---------------------------
        E_RX_A: begin
          if (s_tvalid) begin
            if (rx_idx == N-1) begin
              rx_idx <= '0;
              state  <= (op_r == OP_PWM) ? E_RX_B : E_RUN_START;
            end else begin
              rx_idx <= rx_idx + 1'b1;
            end
          end
        end

        // ---- (PWM only) load 256 coefficients of operand B ---------------
        E_RX_B: begin
          if (s_tvalid) begin
            if (rx_idx == N-1) state  <= E_RUN_START;
            else               rx_idx <= rx_idx + 1'b1;
          end
        end

        // ---- run the core -------------------------------------------------
        E_RUN_START: state <= E_RUN_WAIT;
        E_RUN_WAIT: begin
          if (core_done) begin
            tx_idx <= '0;
            state  <= E_TX_RD;
          end
        end

        // ---- emit 256 coefficients to the source --------------------------
        E_TX_RD: state <= E_TX_VALID;
        E_TX_VALID: begin
          if (m_tready) begin
            if (tx_idx == N-1) state  <= E_DONE;
            else begin
              tx_idx <= tx_idx + 1'b1;
              state  <= E_TX_RD;
            end
          end
        end

        // ---- done : single-cycle done pulse -------------------------------
        E_DONE: begin
          busy_o <= 1'b0;
          done_o <= 1'b1;
          state  <= E_IDLE;
        end

        default: state <= E_IDLE;
      endcase
    end
  end

endmodule : ntt_engine
