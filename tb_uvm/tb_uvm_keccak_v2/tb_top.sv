// =========================================================================
// tb_top.sv  -  TB v2 top-level for keccak_core
// Includes UVM components and instantiates the DUT against keccak_if.
// =========================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import keccak_pkg::*;

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

    logic clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // Interface (rst is driven by driver via vif.rst)
    keccak_if vif (clk);

    // DUT
    keccak_core dut (
        .clk            (clk),
        .rst            (vif.rst),
        .start_i        (vif.start),
        .keccak_mode_i  (vif.mode),
        .xof_len_i      (vif.xof_len),
        .stop_i         (vif.stop),

        .s_axis_tdata   (vif.s_axis_tdata),
        .s_axis_tvalid  (vif.s_axis_tvalid),
        .s_axis_tlast   (vif.s_axis_tlast),
        .s_axis_tkeep   (vif.s_axis_tkeep),
        .s_axis_tready  (vif.s_axis_tready),

        .m_axis_tdata   (vif.m_axis_tdata),
        .m_axis_tvalid  (vif.m_axis_tvalid),
        .m_axis_tlast   (vif.m_axis_tlast),
        .m_axis_tkeep   (vif.m_axis_tkeep),
        .m_axis_tready  (vif.m_axis_tready)
    );

    initial begin
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent.*", "keccak_vif", vif);
        run_test("keccak_full_test");
    end

endmodule
