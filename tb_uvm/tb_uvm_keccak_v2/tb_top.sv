// =========================================================================
// tb_top.sv  -  Unified top-level for keccak verification
//
// Always targets keccak_engine_parallel. With N_LANES=1 this behaves like a
// single-core verification; with N_LANES=4 (default) it exercises the
// parallel wrapper. The wrapper is transparent at N_LANES=1 (single
// generate iteration around one keccak_core), so a single TB covers both
// cases.
//
// To change lane count: edit N_LANES here AND in keccak_env::N_LANES so
// the env's per-lane component arrays match.
// =========================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import keccak_pkg::*;
import keccak_ref_pkg::*;

`include "keccak_transaction.sv"
`include "keccak_sequence.sv"
`include "keccak_coverage.sv"
`include "keccak_scoreboard.sv"
`include "keccak_driver.sv"
`include "keccak_monitor.sv"
`include "keccak_agent.sv"
`include "keccak_env.sv"
`include "keccak_tests.sv"

module tb_top;

    localparam int N_LANES = 4;

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    logic clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // ----------------------------------------------------------------
    // Per-lane interfaces
    // ----------------------------------------------------------------
    keccak_if vif [N_LANES] (clk);

    // ----------------------------------------------------------------
    // Bundle wires connecting interfaces to keccak_engine_parallel
    // ----------------------------------------------------------------
    logic [N_LANES-1:0]                     rst;
    logic [N_LANES-1:0]                     start_i;
    keccak_mode                             keccak_mode_i [N_LANES];
    logic [N_LANES-1:0][XOF_LEN_WIDTH-1:0]  xof_len_i;
    logic [N_LANES-1:0]                     stop_i;

    logic [N_LANES-1:0][DWIDTH-1:0]         s_axis_tdata;
    logic [N_LANES-1:0]                     s_axis_tvalid;
    logic [N_LANES-1:0]                     s_axis_tlast;
    logic [N_LANES-1:0][KEEP_WIDTH-1:0]     s_axis_tkeep;
    wire  [N_LANES-1:0]                     s_axis_tready;

    wire  [N_LANES-1:0][DWIDTH-1:0]         m_axis_tdata;
    wire  [N_LANES-1:0]                     m_axis_tvalid;
    wire  [N_LANES-1:0]                     m_axis_tlast;
    wire  [N_LANES-1:0][KEEP_WIDTH-1:0]     m_axis_tkeep;
    logic [N_LANES-1:0]                     m_axis_tready;

    generate
        for (genvar i = 0; i < N_LANES; i++) begin : g_wire
            assign rst[i]            = vif[i].rst;
            assign start_i[i]        = vif[i].start;
            assign keccak_mode_i[i]  = vif[i].mode;
            assign xof_len_i[i]      = vif[i].xof_len;
            assign stop_i[i]         = vif[i].stop;
            assign s_axis_tdata[i]   = vif[i].s_axis_tdata;
            assign s_axis_tvalid[i]  = vif[i].s_axis_tvalid;
            assign s_axis_tlast[i]   = vif[i].s_axis_tlast;
            assign s_axis_tkeep[i]   = vif[i].s_axis_tkeep;
            assign vif[i].s_axis_tready = s_axis_tready[i];
            assign vif[i].m_axis_tdata  = m_axis_tdata[i];
            assign vif[i].m_axis_tvalid = m_axis_tvalid[i];
            assign vif[i].m_axis_tlast  = m_axis_tlast[i];
            assign vif[i].m_axis_tkeep  = m_axis_tkeep[i];
            assign m_axis_tready[i]     = vif[i].m_axis_tready;
        end
    endgenerate

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    keccak_engine_parallel #(.N_LANES(N_LANES)) dut (
        .clk            (clk),
        .rst            (rst),
        .start_i        (start_i),
        .keccak_mode_i  (keccak_mode_i),
        .xof_len_i      (xof_len_i),
        .stop_i         (stop_i),

        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tkeep   (s_axis_tkeep),
        .s_axis_tready  (s_axis_tready),

        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tready  (m_axis_tready)
    );

    // ----------------------------------------------------------------
    // Register per-lane vif under each agent's hierarchy
    // ----------------------------------------------------------------
    initial begin
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_0.*", "keccak_vif", vif[0]);
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_1.*", "keccak_vif", vif[1]);
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_2.*", "keccak_vif", vif[2]);
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_3.*", "keccak_vif", vif[3]);
        run_test("keccak_full_test");
    end

endmodule
