// ============================================================================
// ntt_if.sv  --  AXI4-Stream-style interface for ntt_engine (UVM TB)
// ----------------------------------------------------------------------------
// No clocking blocks. Plain logic signals only -- all sampling in the driver
// and monitor is `@(edge vif.clk)` + direct signal reads (the keccak_v2
// pattern). Reset, start, op and the sink are driven by the driver; the
// source's m_tready is driven by the monitor.
// ============================================================================
`timescale 1ns/1ps

import ntt_pkg::*;

interface ntt_if (input bit clk);

    // ---- reset + operation request (driven by driver) --------------------
    logic                  rst;
    logic                  start;
    ntt_op_e               op;
    logic                  busy;
    logic                  done;

    // ---- coefficient sink  (TB -> DUT, driven by driver) -----------------
    logic [COEFF_W-1:0]    s_tdata;
    logic                  s_tvalid;
    logic                  s_tlast;
    logic                  s_tready;

    // ---- coefficient source (DUT -> TB, m_tready driven by monitor) ------
    logic [COEFF_W-1:0]    m_tdata;
    logic                  m_tvalid;
    logic                  m_tlast;
    logic                  m_tready;

endinterface
