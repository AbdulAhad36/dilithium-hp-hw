// ============================================================================
// tb_top.sv  --  UVM top-level for the ntt_engine verification environment
// ----------------------------------------------------------------------------
// Instantiates ntt_engine, wires one ntt_if bundle to it, registers the vif
// under the agent's hierarchy, and launches the default test (ntt_full_test).
//
// Run:  cd sim ;  vsim -c -do "do ntt_LightHD/run_uvm.do; quit -f"
//
// Every transform is golden-compared against ntt_ref_pkg by the scoreboard.
// ============================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import ntt_pkg::*;
import ntt_ref_pkg::*;

`include "ntt_routing_trace.sv"
`include "ntt_trace.sv"
`include "ntt_transaction.sv"
`include "ntt_sequence.sv"
`include "ntt_coverage.sv"
`include "ntt_scoreboard.sv"
`include "ntt_driver.sv"
`include "ntt_monitor.sv"
`include "ntt_agent.sv"
`include "ntt_env.sv"
`include "ntt_tests.sv"
`ifdef NTT_NETLIST
`include "ntt_netlist.sv"
`endif

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

    // RTL-only observations are absent in technology-mapped netlists.
`ifndef NTT_NETLIST
    assign vif.wrapper_state = dut.state;
    assign vif.core_state = dut.u_core.state;
    assign vif.core_busy = dut.core_busy;
    assign vif.core_done = dut.core_done;
    logic [9:0] tag_valid;
    for (genvar d=0; d<10; d++) assign tag_valid[d]=dut.u_core.tag[d].valid;
    assign vif.pending_tags=|tag_valid;
    assign vif.run_issue = dut.u_core.run_issue;
    assign vif.pwm_issue = dut.u_core.pwm_issue;
    assign vif.stage = dut.u_core.stage;
    assign vif.issue = dut.u_core.issue;
    assign vif.tick = dut.u_core.tick;
    assign vif.source_a = dut.u_core.source_a;
    assign vif.source_b = dut.u_core.source_b;
    assign vif.dest_a = dut.u_core.dest_a;
    assign vif.dest_b = dut.u_core.dest_b;
    assign vif.return_valid = dut.u_core.tag[9].valid;
    assign vif.return_pwm = dut.u_core.tag[9].pwm;
    assign vif.return_dest_a = dut.u_core.tag[9].dest_a;
    assign vif.return_dest_b = dut.u_core.tag[9].dest_b;
    assign vif.half_valid = dut.u_core.tag[8].valid && dut.u_core.tag[8].inverse;
    assign vif.pair_layout = dut.u_core.tag[8].p;
    assign vif.fifo_count1 = dut.u_core.count1;
    assign vif.fifo_count2 = dut.u_core.count2;
    assign vif.fifo_count3 = dut.u_core.count3;
    assign vif.fifo_pop={dut.u_core.pop3,dut.u_core.pop2,dut.u_core.pop1};
    assign vif.fifo_push={dut.u_core.push3,dut.u_core.push2,dut.u_core.push1};
    assign vif.fifo_push_word[0]=dut.u_core.push_word1;
    assign vif.fifo_push_word[1]=dut.u_core.push_word2;
    assign vif.fifo_push_word[2]=dut.u_core.push_word3;
    assign vif.fifo_head[0]=dut.u_core.head1;
    assign vif.fifo_head[1]=dut.u_core.head2;
    assign vif.fifo_head[2]={1'b0,dut.u_core.head3};
    assign vif.fifo_tail[0]=dut.u_core.tail1;
    assign vif.fifo_tail[1]=dut.u_core.tail2;
    assign vif.fifo_tail[2]={1'b0,dut.u_core.tail3};
    assign vif.output_read=dut.core_rd_en;
    assign vif.output_address=dut.core_rd_addr;
    for (genvar word_index=0; word_index<32; word_index++) begin
        assign vif.fifo_memory[0][word_index]=dut.u_core.fifo1[word_index];
        assign vif.fifo_memory[1][word_index]=dut.u_core.fifo2[word_index];
        if (word_index<16) assign vif.fifo_memory[2][word_index]=dut.u_core.fifo3[word_index];
        else assign vif.fifo_memory[2][word_index]='0;
    end
    assign vif.result_a = dut.u_core.result_a;
    assign vif.result_b = dut.u_core.result_b;
    for (genvar lane = 0; lane < 4; lane++) begin
        assign vif.bf_input_a[lane]=dut.u_core.bf_ai_q[lane];
        assign vif.bf_input_b[lane]=dut.u_core.bf_bi_q[lane];
        assign vif.bf_input_z[lane]=dut.u_core.bf_zi_q[lane];
        assign vif.bf_input_mode[lane]=dut.u_core.bf_mode_q[lane];
        assign vif.tw_addr[lane] = dut.u_core.tw_addr[lane];
        assign vif.tw_value[lane] = dut.u_core.tw[lane];
        assign vif.bf_a[lane] = dut.u_core.bf_ao[lane];
        assign vif.bf_b[lane] = dut.u_core.bf_bo[lane];
    end

`endif

    // ---- watchdog : fail fast instead of hanging forever ---------------------
    initial begin
        #100ms;
        `uvm_fatal("WATCHDOG", "TIMEOUT -- testbench watchdog fired")
    end

    // ---- register vif + launch the test --------------------------------------
    initial begin
        uvm_config_db#(virtual ntt_if)::set(null, "uvm_test_top.env.agent.*",
                                            "ntt_vif", vif);
`ifdef NTT_NETLIST
        run_test("ntt_netlist_test");
`else
        run_test("ntt_full_test");
`endif
    end

endmodule
