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

    // Read-only DUT observations for the UVM monitor (wired in tb_top).
    logic [3:0] wrapper_state;
    logic [2:0] core_state;
    logic core_busy, core_done, pending_tags;
    logic run_issue, pwm_issue, return_valid, return_pwm, half_valid;
    logic [2:0] stage, pair_layout;
    logic [4:0] issue;
    logic [7:0] tick;
    logic [1:0] source_a, source_b, dest_a, dest_b;
    logic [1:0] return_dest_a, return_dest_b;
    logic [5:0] fifo_count1, fifo_count2;
    logic [4:0] fifo_count3;
    logic [7:0] tw_addr[4];
    logic [COEFF_W-1:0] tw_value[4], bf_a[4], bf_b[4];
    logic [4*COEFF_W-1:0] result_a, result_b;
    logic [2:0] fifo_pop, fifo_push;
    logic [4:0] fifo_head[3], fifo_tail[3];
    logic [4*COEFF_W-1:0] fifo_memory[3][32], fifo_push_word[3];
    logic [COEFF_W-1:0] bf_input_a[4], bf_input_b[4], bf_input_z[4];
    bf_mode_e bf_input_mode[4];
    logic output_read;
    logic [7:0] output_address;

endinterface
