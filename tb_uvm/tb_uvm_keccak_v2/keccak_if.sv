// =========================================================================
// keccak_if.sv  -  AXI4-Stream-style interface for keccak_core (TB v2)
// No clocking blocks. Plain logic signals only. Reset is driven by driver.
// m_axis_tready is driven by the monitor.
// =========================================================================
`timescale 1ns/1ps

import keccak_pkg::*;

interface keccak_if (input bit clk);

    // DUT Reset (driven by driver)
    logic                       rst;

    // DUT Control Signals (driven by driver, except 'stop' which is driven
    // by the monitor at end-of-collection for continuous SHAKE)
    logic                       start;
    logic                       stop;
    keccak_mode                 mode;
    logic [XOF_LEN_WIDTH-1:0]   xof_len;

    // Sink (TB -> DUT) - driven by driver
    logic [DWIDTH-1:0]          s_axis_tdata;
    logic                       s_axis_tvalid;
    logic                       s_axis_tlast;
    logic [KEEP_WIDTH-1:0]      s_axis_tkeep;
    logic                       s_axis_tready;

    // Source (DUT -> TB) - m_axis_tready driven by monitor
    logic [DWIDTH-1:0]          m_axis_tdata;
    logic                       m_axis_tvalid;
    logic                       m_axis_tlast;
    logic [KEEP_WIDTH-1:0]      m_axis_tkeep;
    logic                       m_axis_tready;

endinterface
