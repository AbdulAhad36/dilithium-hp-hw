// ============================================================================
// tb_top.sv  --  UVM top-level for the ntt_engine verification environment
// ----------------------------------------------------------------------------
// Instantiates ntt_engine, wires one ntt_if bundle to it, registers the vif
// under the agent's hierarchy, and launches the default test (ntt_full_test).
//
// Run:  cd sim ;  vsim -do ntt_run.do
//                 vsim -c -do "do ntt_run.do; quit -f"   (headless)
//
// Every transform is golden-compared against ntt_ref_pkg by the scoreboard.
// ============================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import ntt_pkg::*;
import ntt_ref_pkg::*;

`include "ntt_transaction.sv"
`include "ntt_sequence.sv"
`include "ntt_coverage.sv"
`include "ntt_scoreboard.sv"
`include "ntt_driver.sv"
`include "ntt_monitor.sv"
`include "ntt_agent.sv"
`include "ntt_env.sv"
`include "ntt_tests.sv"

module tb_top;

    // ---- 100 MHz clock -------------------------------------------------------
    bit clk;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---- interface -----------------------------------------------------------
    ntt_if vif (clk);

    // ---- DUT -----------------------------------------------------------------
    ntt_engine dut (
        .clk      (clk),
        .rst      (vif.rst),
        .start_i  (vif.start),
        .op_i     (vif.op),
        .busy_o   (vif.busy),
        .done_o   (vif.done),
        .s_tdata  (vif.s_tdata),
        .s_tvalid (vif.s_tvalid),
        .s_tlast  (vif.s_tlast),
        .s_tready (vif.s_tready),
        .m_tdata  (vif.m_tdata),
        .m_tvalid (vif.m_tvalid),
        .m_tlast  (vif.m_tlast),
        .m_tready (vif.m_tready)
    );

    // ---- watchdog : fail fast instead of hanging forever ---------------------
    initial begin
        #100ms;
        $display(" RESULT:  TIMEOUT -- testbench watchdog fired.");
        $finish;
    end

    // ---- register vif + launch the test --------------------------------------
    initial begin
        uvm_config_db#(virtual ntt_if)::set(null, "uvm_test_top.env.agent.*",
                                            "ntt_vif", vif);
        run_test("ntt_full_test");
    end

endmodule
