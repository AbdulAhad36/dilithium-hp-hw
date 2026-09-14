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
`ifdef KECCAK_EXTERNAL_DUT
`include "keccak_stage2_test.sv"
`elsif KECCAK_STAGE2_SUITE
`include "keccak_stage2_test.sv"
`endif

module tb_top;

    localparam int N_LANES = 4;

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    logic clk;
    initial begin
        clk = 0;
`ifdef KECCAK_EXTERNAL_DUT
        forever #10 clk = ~clk; // Stage 2 functional simulation: 50 MHz
`else
        forever #5 clk = ~clk;  // 100 MHz
`endif
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
    logic [N_LANES-1:0][MSG_LEN_WIDTH-1:0]  message_len_i;
    logic [N_LANES-1:0][XOF_LEN_WIDTH-1:0]  output_len_i;
    logic [N_LANES-1:0]                     stop_i;
    wire  [N_LANES-1:0]                     busy_o;
    wire  [N_LANES-1:0]                     done_o;

    logic [N_LANES-1:0][DWIDTH-1:0]         input_data_i;
    logic [N_LANES-1:0]                     input_valid_i;
    wire  [N_LANES-1:0]                     input_ready_o;

    wire  [N_LANES-1:0][DWIDTH-1:0]         output_data_o;
    wire  [N_LANES-1:0]                     output_valid_o;
    wire  [N_LANES-1:0][BYTE_COUNT_WIDTH-1:0] output_bytes_o;
    logic [N_LANES-1:0]                     output_ready_i;

    generate
        for (genvar i = 0; i < N_LANES; i++) begin : g_wire
            assign rst[i]            = vif[i].rst;
            assign start_i[i]        = vif[i].start;
            assign keccak_mode_i[i]  = vif[i].mode;
            assign message_len_i[i]  = vif[i].message_len;
            assign output_len_i[i]   = vif[i].output_len;
            assign stop_i[i]         = vif[i].stop;
            assign vif[i].busy        = busy_o[i];
            assign vif[i].done        = done_o[i];
            assign vif[i].active_lanes = $countones(busy_o);
`ifdef KECCAK_EXTERNAL_DUT
            // Unavailable in the gate-level netlist: do not claim FSM coverage.
            assign vif[i].debug_state = 'x;
            assign vif[i].debug_perm_phase = 1'bx;
            assign vif[i].debug_round_idx = 'x;
            assign vif[i].debug_permutation_suite_passed = 1'b0;
`elsif KECCAK_MLDSA_OSH_DUT
            // Adapter phases are visible, but the imported VHDL does not
            // expose round-step signals for the permutation checker.
            assign vif[i].debug_state = dut.g_lane[i].u_core.state;
            assign vif[i].debug_perm_phase =
                dut.g_lane[i].u_core.permute_phase;
            assign vif[i].debug_round_idx =
                dut.g_lane[i].u_core.round_idx;
            assign vif[i].debug_permutation_suite_passed = 1'b0;
`else
            assign vif[i].debug_state = dut.g_lane[i].u_core.state[2:0];
            assign vif[i].debug_perm_phase =
                dut.g_lane[i].u_core.permute_phase;
            assign vif[i].debug_round_idx =
                dut.g_lane[i].u_core.round_idx;
`endif
            assign input_data_i[i]    = vif[i].input_data;
            assign input_valid_i[i]   = vif[i].input_valid;
            assign vif[i].input_ready = input_ready_o[i];
            assign vif[i].output_data = output_data_o[i];
            assign vif[i].output_valid = output_valid_o[i];
            assign vif[i].output_bytes = output_bytes_o[i];
            assign output_ready_i[i]  = vif[i].output_ready;

            always_comb begin
                vif[i].peer_reset_active = 1'b0;
                vif[i].peer_stall_active = 1'b0;
                vif[i].peer_stop_active = 1'b0;
                for (int peer = 0; peer < N_LANES; peer++) begin
                    if (peer != i) begin
                        vif[i].peer_reset_active |= rst[peer];
                        vif[i].peer_stall_active |=
                            output_valid_o[peer] && !output_ready_i[peer];
                        vif[i].peer_stop_active |=
                            stop_i[peer] && busy_o[peer];
                    end
                end
            end

            // Capture the phase that existed immediately before async reset
            // clears the core. These signals are verification-only and do not
            // alter the synthesizable Keccak interface.
            always @(posedge vif[i].rst) begin
                vif[i].reset_from_state = vif[i].debug_state;
                vif[i].reset_from_perm_phase = vif[i].debug_perm_phase;
            end

            keccak_assertions lane_assertions (
                .clk             (clk),
                .rst             (rst[i]),
                .start_i         (start_i[i]),
                .stop_i          (stop_i[i]),
                .busy_o          (busy_o[i]),
                .done_o          (done_o[i]),
                .input_data_i    (input_data_i[i]),
                .input_valid_i   (input_valid_i[i]),
                .input_ready_o   (input_ready_o[i]),
                .output_data_o   (output_data_o[i]),
                .output_valid_o  (output_valid_o[i]),
                .output_bytes_o  (output_bytes_o[i]),
                .output_ready_i  (output_ready_i[i])
            );

`ifndef KECCAK_EXTERNAL_DUT
`ifndef KECCAK_MLDSA_OSH_DUT
            keccak_permutation_checker permutation_checker (
                .clk             (clk),
                .rst             (rst[i]),
                .state           (dut.g_lane[i].u_core.state[2:0]),
                .round_idx       (dut.g_lane[i].u_core.round_idx),
                .state_array     (dut.g_lane[i].u_core.state_array),
                .theta_out       (dut.g_lane[i].u_core.KSU.theta_out),
                .rho_out         (dut.g_lane[i].u_core.KSU.rho_out),
                .pi_out          (dut.g_lane[i].u_core.KSU.pi_out),
                .chi_out         (dut.g_lane[i].u_core.KSU.chi_out),
                .iota_out        (dut.g_lane[i].u_core.KSU.iota_out),
                .suite_passed_o  (vif[i].debug_permutation_suite_passed)
            );
`endif
`endif
        end
    endgenerate

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
`ifdef KECCAK_EXTERNAL_DUT
    // Only lane 0 is driven in Stage 2; other UVM agents stay in reset.
    for (genvar lane = 0; lane < N_LANES; lane++) begin : g_external
        keccak_synth_top dut (
            .clk(clk), .rst(rst[lane]), .start_i(start_i[lane]),
            .mode_i(keccak_mode_i[lane] == SHAKE256),
            .message_len_i(message_len_i[lane]), .output_len_i(output_len_i[lane]),
            .stop_i(stop_i[lane]), .busy_o(busy_o[lane]), .done_o(done_o[lane]),
            .input_data_i(input_data_i[lane]), .input_valid_i(input_valid_i[lane]),
            .input_ready_o(input_ready_o[lane]), .output_data_o(output_data_o[lane]),
            .output_valid_o(output_valid_o[lane]), .output_bytes_o(output_bytes_o[lane]),
            .output_ready_i(output_ready_i[lane])
        );
    end
    initial begin
        #10000000;
        `uvm_fatal("STAGE2_TIMEOUT", "Stage 2 regression exceeded 10 ms")
    end
`elsif KECCAK_MLDSA_OSH_DUT
    mldsa_osh_keccak_parallel #(.N_LANES(N_LANES)) dut (
        .clk            (clk),
        .rst            (rst),
        .start_i        (start_i),
        .keccak_mode_i  (keccak_mode_i),
        .message_len_i  (message_len_i),
        .output_len_i   (output_len_i),
        .stop_i         (stop_i),
        .busy_o         (busy_o),
        .done_o         (done_o),
        .input_data_i   (input_data_i),
        .input_valid_i  (input_valid_i),
        .input_ready_o  (input_ready_o),
        .output_data_o  (output_data_o),
        .output_valid_o (output_valid_o),
        .output_bytes_o (output_bytes_o),
        .output_ready_i (output_ready_i)
    );
`else
    keccak_engine_parallel #(.N_LANES(N_LANES)) dut (
        .clk            (clk),
        .rst            (rst),
        .start_i        (start_i),
        .keccak_mode_i  (keccak_mode_i),
        .message_len_i  (message_len_i),
        .output_len_i   (output_len_i),
        .stop_i         (stop_i),
        .busy_o         (busy_o),
        .done_o         (done_o),

        .input_data_i   (input_data_i),
        .input_valid_i  (input_valid_i),
        .input_ready_o  (input_ready_o),

        .output_data_o  (output_data_o),
        .output_valid_o (output_valid_o),
        .output_bytes_o (output_bytes_o),
        .output_ready_i (output_ready_i)
    );
`endif

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
