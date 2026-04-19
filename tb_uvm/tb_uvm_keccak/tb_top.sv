// =========================================================================
// Keccak Core UVM Testbench Top
// =========================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// Import Keccak package
import keccak_pkg::*;

// Include all UVM components
`include "keccak_transaction.sv"
`include "keccak_sequence.sv"
`include "keccak_driver.sv"
`include "keccak_monitor.sv"
`include "keccak_scoreboard.sv"
// `include "keccak_coverage.sv"
// `include "keccak_reference_model.sv"
`include "keccak_agent.sv"
`include "keccak_env.sv"
`include "keccak_tests.sv"

module tb_top;

    // Clock and Reset
    logic clk;
    logic rst;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Interface instantiation
    keccak_if vif (clk, rst);
    
    // DUT Instantiation
    keccak_core dut (
        .clk            (clk),
        .rst            (rst),
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
    
    // Connect interface to DUT
    // assign vif.rst = rst;
    
    initial begin
        // Set the virtual interface in config DB
        uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top", "keccak_vif", vif);
        
        // Run the test
        run_test("keccak_base_test");
    end
    
    initial begin
        $fsdbDumpfile("tb_top.fsdb");
        $fsdbDumpvars(0, tb_top);
    end
    
endmodule