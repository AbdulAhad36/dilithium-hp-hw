// Protocol-neutral interface assertions for one Keccak lane.
import keccak_pkg::*;

module keccak_assertions (
    input logic                          clk,
    input logic                          rst,
    input logic                          start_i,
    input logic                          stop_i,
    input logic                          busy_o,
    input logic                          done_o,
    input logic [DWIDTH-1:0]             input_data_i,
    input logic                          input_valid_i,
    input logic                          input_ready_o,
    input logic [DWIDTH-1:0]             output_data_o,
    input logic                          output_valid_o,
    input logic [BYTE_COUNT_WIDTH-1:0]   output_bytes_o,
    input logic                          output_ready_i
);
    logic reset_recovery_q;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) reset_recovery_q <= 1'b1;
        else     reset_recovery_q <= 1'b0;
    end

    default clocking cb @(posedge clk); endclocking
    default disable iff (rst || reset_recovery_q);

    a_start_only_when_idle: assert property (
        start_i |-> !busy_o
    );

    a_start_enters_busy: assert property (
        start_i |=> busy_o
    );

    a_input_stable_while_waiting: assert property (
        busy_o && input_valid_i && !input_ready_o
        |=> !busy_o ||
            (input_valid_i && $stable(input_data_i))
    );

    a_output_stable_while_waiting: assert property (
        output_valid_o && !output_ready_i && !stop_i && !done_o
        |=> output_valid_o &&
            $stable(output_data_o) &&
            $stable(output_bytes_o)
    );

    a_output_byte_count_legal: assert property (
        output_valid_o |->
        (output_bytes_o inside {[1:DATA_BYTE_NUM]})
    );

    a_done_has_cause: assert property (
        done_o && !stop_i |-> output_valid_o && output_ready_i
    );

    a_idle_has_no_output: assert property (
        !busy_o |-> !output_valid_o
    );

    a_reset_clears_interface: assert property (
        @(posedge clk) disable iff ($isunknown(rst))
        rst |=> !busy_o && !output_valid_o
    );

    c_start: cover property (start_i);
    c_input_wait: cover property (input_valid_i && !input_ready_o);
    c_output_wait: cover property (output_valid_o && !output_ready_i);
    c_fixed_done: cover property (done_o && !stop_i);
    c_continuous_stop: cover property (stop_i && done_o);
    c_reset_while_busy: cover property (@(posedge clk) busy_o ##1 rst);
endmodule


typedef logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0]
    keccak_checker_state_t;

// Independent FIPS 202 step checker for the source-RTL stage. It observes the
// datapath without driving it and requires every step in every round to match.
module keccak_permutation_checker (
    input logic clk,
    input logic rst,
    input logic [2:0] state,
    input logic [ROUND_INDEX_SIZE-1:0] round_idx,
    input keccak_checker_state_t state_array,
    input keccak_checker_state_t theta_out,
    input keccak_checker_state_t rho_out,
    input keccak_checker_state_t pi_out,
    input keccak_checker_state_t chi_out,
    input keccak_checker_state_t iota_out,
    output logic suite_passed_o
);
    logic [23:0] rounds_seen;
    logic checker_failed;

    function automatic logic [63:0] rol64(input logic [63:0] value,
                                           input int shift);
        if (shift == 0)
            return value;
        return (value << shift) | (value >> (64 - shift));
    endfunction

    function automatic keccak_checker_state_t ref_theta(
        input keccak_checker_state_t value);
        logic [4:0][63:0] c;
        logic [4:0][63:0] d;
        keccak_checker_state_t result;
        for (int x = 0; x < 5; x++)
            c[x] = value[x][0] ^ value[x][1] ^ value[x][2] ^
                   value[x][3] ^ value[x][4];
        for (int x = 0; x < 5; x++)
            d[x] = c[(x + 4) % 5] ^ rol64(c[(x + 1) % 5], 1);
        for (int x = 0; x < 5; x++)
            for (int y = 0; y < 5; y++)
                result[x][y] = value[x][y] ^ d[x];
        return result;
    endfunction

    function automatic keccak_checker_state_t ref_rho(
        input keccak_checker_state_t value);
        int offsets [5][5] = '{
            '{0,36,3,41,18}, '{1,44,10,45,2}, '{62,6,43,15,61},
            '{28,55,25,21,56}, '{27,20,39,8,14}
        };
        keccak_checker_state_t result;
        for (int x = 0; x < 5; x++)
            for (int y = 0; y < 5; y++)
                result[x][y] = rol64(value[x][y], offsets[x][y]);
        return result;
    endfunction

    function automatic keccak_checker_state_t ref_pi(
        input keccak_checker_state_t value);
        keccak_checker_state_t result;
        for (int x = 0; x < 5; x++)
            for (int y = 0; y < 5; y++)
                result[x][y] = value[(x + 3*y) % 5][x];
        return result;
    endfunction

    function automatic keccak_checker_state_t ref_chi(
        input keccak_checker_state_t value);
        keccak_checker_state_t result;
        for (int x = 0; x < 5; x++)
            for (int y = 0; y < 5; y++)
                result[x][y] = value[x][y] ^
                    ((~value[(x + 1) % 5][y]) &
                     value[(x + 2) % 5][y]);
        return result;
    endfunction

    function automatic logic [63:0] round_constant(input int round);
        logic [63:0] rc [24] = '{
            64'h0000000000000001, 64'h0000000000008082,
            64'h800000000000808a, 64'h8000000080008000,
            64'h000000000000808b, 64'h0000000080000001,
            64'h8000000080008081, 64'h8000000000008009,
            64'h000000000000008a, 64'h0000000000000088,
            64'h0000000080008009, 64'h000000008000000a,
            64'h000000008000808b, 64'h800000000000008b,
            64'h8000000000008089, 64'h8000000000008003,
            64'h8000000000008002, 64'h8000000000000080,
            64'h000000000000800a, 64'h800000008000000a,
            64'h8000000080008081, 64'h8000000000008080,
            64'h0000000080000001, 64'h8000000080008008
        };
        return rc[round];
    endfunction

    function automatic keccak_checker_state_t ref_iota(
        input keccak_checker_state_t value, input int round);
        keccak_checker_state_t result;
        result = value;
        result[0][0] ^= round_constant(round);
        return result;
    endfunction

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rounds_seen <= '0;
            checker_failed <= 1'b0;
            suite_passed_o <= 1'b0;
        end else if ((state == 3) && !suite_passed_o) begin
            logic step_ok;
            logic [23:0] next_rounds;
            next_rounds = rounds_seen;
            step_ok = (theta_out === ref_theta(state_array));
            step_ok &= (rho_out === ref_rho(ref_theta(state_array)));
            step_ok &= (pi_out === ref_pi(ref_rho(ref_theta(state_array))));
            step_ok &= (chi_out ===
                        ref_chi(ref_pi(ref_rho(ref_theta(state_array)))));
            step_ok &= (iota_out === ref_iota(
                        ref_chi(ref_pi(ref_rho(ref_theta(state_array)))),
                        round_idx));

            if (step_ok)
                next_rounds[round_idx] = 1'b1;

            rounds_seen <= next_rounds;
            if (!step_ok) begin
                checker_failed <= 1'b1;
                $error("Keccak permutation step mismatch at round %0d",
                       round_idx);
            end
            if (!checker_failed && step_ok && (&next_rounds))
                suite_passed_o <= 1'b1;
        end
    end
endmodule
