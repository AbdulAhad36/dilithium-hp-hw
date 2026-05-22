// ============================================================================
// ntt_engine.sv  --  Top-level NTT/INTT engine  (increment 4: stream front-end)
// ----------------------------------------------------------------------------
// Wraps the verified ntt_core with an AXI4-Stream-style I/O front-end. One
// 23-bit coefficient per beat enters over the sink, the requested operation
// runs on the core, and the transformed polynomial streams back out the source.
//
//   start_i pulse  ->  RX (load 256 coeffs)  ->  RUN (core)  ->  TX (emit 256)
//
//   op_i = OP_NTT  : forward NTT,  Z_q[x]/(x^256+1)
//   op_i = OP_INTT : inverse NTT, includes the 1/N scaling
//   (OP_PWM needs a two-operand interface -- a later increment.)
//
// A decoupling input FIFO -- to absorb the bursty coefficient rate of the
// upstream rejection sampler -- is deferred to the integration branch (see
// docs/ntt-design-and-verification.md S4.4). The AXI-Stream `s_tready`
// handshake already provides correct back-pressure for a standalone engine.
//
// STATUS: increment 4 -- stream front-end complete, verified by tb_ntt_engine.
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

    // ---- coefficient sink (input polynomial) ------------------------------
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
  logic [LOGN-1:0]       core_wr_addr;
  logic [COEFF_W-1:0]    core_wr_data;
  logic                  core_rd_en;
  logic [LOGN-1:0]       core_rd_addr;
  logic [COEFF_W-1:0]    core_rd_data;
  ntt_op_e               op_r;            // operation latched at start

  ntt_core u_core (
      .clk       (clk),
      .rst       (rst),
      .start_i   (core_start),
      .op_i      (op_r),
      .busy_o    (core_busy),
      .done_o    (core_done),
      .wr_en_i   (core_wr_en),
      .wr_addr_i (core_wr_addr),
      .wr_data_i (core_wr_data),
      .rd_en_i   (core_rd_en),
      .rd_addr_i (core_rd_addr),
      .rd_data_o (core_rd_data)
  );

  // ==========================================================================
  // Front-end FSM
  //   IDLE -> RX (256 sink beats -> core memory)
  //        -> RUN_START -> RUN_WAIT (pulse + wait core)
  //        -> [per coeff: TX_RD -> TX_VALID] x 256
  //        -> DONE -> IDLE
  // ==========================================================================
  typedef enum logic [2:0] {
    E_IDLE, E_RX, E_RUN_START, E_RUN_WAIT, E_TX_RD, E_TX_VALID, E_DONE
  } estate_e;

  estate_e        state;
  logic [LOGN:0]  rx_idx;          // 0..256 sink beat counter
  logic [LOGN:0]  tx_idx;          // 0..256 source beat counter

  // --------------------------------------------------------------------------
  // Combinational outputs
  // --------------------------------------------------------------------------
  always_comb begin
    s_tready     = 1'b0;
    m_tvalid     = 1'b0;
    m_tlast      = 1'b0;
    m_tdata      = core_rd_data;

    core_start   = 1'b0;
    core_wr_en   = 1'b0;
    core_wr_addr = rx_idx[LOGN-1:0];
    core_wr_data = s_tdata;
    core_rd_en   = 1'b0;
    core_rd_addr = tx_idx[LOGN-1:0];

    unique case (state)
      E_RX: begin
        s_tready   = 1'b1;             // ready throughout the load phase
        core_wr_en = s_tvalid;         // write the core memory on each beat
      end
      E_RUN_START: core_start = 1'b1;  // single-cycle start pulse to the core
      E_TX_RD:     core_rd_en  = 1'b1; // present read address to the core
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
            state  <= E_RX;
          end
        end

        // ---- load 256 coefficients from the sink --------------------------
        E_RX: begin
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
