// =========================================================================
// keccak_if.sv  -  Protocol-neutral word interface for keccak_core (TB v2)
// No clocking blocks. Plain logic signals only. All DUT inputs are driven by
// the driver; active_lanes and debug_* are verification-only observations.
// =========================================================================
`timescale 1ns/1ps

import keccak_pkg::*;

interface keccak_if (input bit clk);

    // DUT Reset (driven by driver)
    logic                       rst;

    // DUT Control Signals (driven by driver)
    logic                       start;
    logic                       stop;
    keccak_mode                 mode;
    logic [MSG_LEN_WIDTH-1:0]   message_len;
    logic [XOF_LEN_WIDTH-1:0]   output_len;
    logic                       busy;
    logic                       done;
    logic [2:0]                 active_lanes;
    logic [2:0]                 debug_state;
    logic                       debug_perm_phase;
    logic [ROUND_INDEX_SIZE-1:0] debug_round_idx;
    logic                       debug_permutation_suite_passed;
    logic [2:0]                 reset_from_state;
    logic                       reset_from_perm_phase;
    logic                       peer_reset_active;
    logic                       peer_stall_active;
    logic                       peer_stop_active;

    // Input words (TB -> DUT) - driven by driver
    logic [DWIDTH-1:0]          input_data;
    logic                       input_valid;
    logic                       input_ready;

    // Output words (DUT -> TB) - output_ready driven by driver
    logic [DWIDTH-1:0]          output_data;
    logic                       output_valid;
    logic [BYTE_COUNT_WIDTH-1:0] output_bytes;
    logic                       output_ready;

endinterface
