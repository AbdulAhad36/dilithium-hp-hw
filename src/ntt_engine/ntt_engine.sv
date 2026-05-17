// ============================================================================
// ntt_engine.sv  --  Top-level NTT/INTT/PWM engine for CRYSTALS-Dilithium
// ----------------------------------------------------------------------------
// Wraps ntt_core with a streaming I/O front-end. Coefficients enter and leave
// over an AXI4-Stream-style handshake (one 23-bit coefficient per beat); the
// engine loads them into the core's coefficient memory, runs the requested
// operation, then streams the transformed polynomial back out.
//
//   op_i = OP_NTT  : forward NTT,  Z_q[x]/(x^256+1)
//   op_i = OP_INTT : inverse NTT, includes the 1/N scaling
//   op_i = OP_PWM  : point-wise multiply two NTT-domain polynomials
//
// A decoupling input FIFO (TODO) absorbs the bursty coefficient rate produced
// by the upstream rejection sampler so the fixed-rate core never stalls --
// see docs/ntt-design-and-verification.md (Keccak <-> NTT interface).
//
// STATUS: top-level skeleton. Port list and core instance are in place; the
// stream front-end FSM and decoupling FIFO are the next step on branch 2_ntt.
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
    input  logic                   s_tlast,
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

  ntt_core u_core (
      .clk       (clk),
      .rst       (rst),
      .start_i   (core_start),
      .op_i      (op_i),
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
  // Stream front-end FSM  --  TODO (next step on branch 2_ntt)
  //   IDLE -> RX (load 256 coeffs from s_axis) -> RUN (pulse core_start, wait
  //   core_done) -> TX (stream 256 coeffs to m_axis) -> IDLE
  // ==========================================================================
  assign core_start   = start_i;
  assign busy_o       = core_busy;
  assign done_o       = core_done;
  assign s_tready     = 1'b0;       // TODO: drive from RX state
  assign m_tdata      = core_rd_data;
  assign m_tvalid     = 1'b0;       // TODO: drive from TX state
  assign m_tlast      = 1'b0;       // TODO
  assign core_wr_en   = 1'b0;       // TODO
  assign core_wr_addr = '0;         // TODO
  assign core_wr_data = s_tdata;
  assign core_rd_en   = 1'b0;       // TODO
  assign core_rd_addr = '0;         // TODO

endmodule : ntt_engine
