// =========================================================================
// Keccak Core Interface - AXI4-Stream Style
// Supports: DWIDTH=256, Little Endian Byte Packing
// =========================================================================
`timescale 1ns/1ps

import keccak_pkg::*;

interface keccak_if (
    input bit clk,
    input bit rst
);

    // DUT Control Signals
    logic                               start;
    logic                               stop;
    keccak_mode                         mode;
    logic [XOF_LEN_WIDTH-1:0]           xof_len;

    // Sink Interface (Input to Core)
    logic [DWIDTH-1:0]                  s_axis_tdata;
    logic                               s_axis_tvalid;
    logic                               s_axis_tlast;
    logic [KEEP_WIDTH-1:0]              s_axis_tkeep;
    logic                               s_axis_tready;

    // Source Interface (Output from Core)
    logic [DWIDTH-1:0]                  m_axis_tdata;
    logic                               m_axis_tvalid;
    logic                               m_axis_tlast;
    logic [KEEP_WIDTH-1:0]              m_axis_tkeep;
    logic                               m_axis_tready;

    // Clocking block for Driver (Drives DUT inputs)
    clocking drv_cb @(posedge clk);
        default input #1step output #2;
        output start;
        output stop;
        output mode;
        output xof_len;
        output s_axis_tdata;
        output s_axis_tvalid;
        output s_axis_tlast;
        output s_axis_tkeep;
        input  s_axis_tready;
        output m_axis_tready;
    endclocking

    // Clocking block for Monitor (Observes DUT outputs)
    clocking mon_cb @(posedge clk);
        default input #1step output #2;
        input start;
        input stop;
        input mode;
        input xof_len;
        input s_axis_tdata;
        input s_axis_tvalid;
        input s_axis_tlast;
        input s_axis_tkeep;
        input s_axis_tready;
        input m_axis_tdata;
        input m_axis_tvalid;
        input m_axis_tlast;
        input m_axis_tkeep;
        input m_axis_tready;
    endclocking

    // Modports
    modport DRIVER (clocking drv_cb, input clk, input rst);
    modport MONITOR (clocking mon_cb, input clk, input rst);
    modport DUT (
        input  clk, rst,
        input  start, stop, mode, xof_len,
        input  s_axis_tdata, s_axis_tvalid, s_axis_tlast, s_axis_tkeep,
        output s_axis_tready,
        output m_axis_tdata, m_axis_tvalid, m_axis_tlast, m_axis_tkeep,
        input  m_axis_tready
    );

endinterface