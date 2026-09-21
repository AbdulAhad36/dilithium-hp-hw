// =========================================================================
// keccak_scoreboard.sv  -  TB v2 scoreboard
// Pairs driver intent with monitor-observed activity. Only transactions that
// pass control, input, output, and protocol checks are published to coverage.
// =========================================================================
class keccak_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(keccak_scoreboard)

    uvm_tlm_analysis_fifo #(keccak_transaction) exp_fifo;
    uvm_tlm_analysis_fifo #(keccak_transaction) obs_fifo;
    uvm_analysis_port #(keccak_transaction) checked_ap;

    int total_tests;
    int passed_tests;
    int failed_tests;
    int pending_reset_state;
    int pending_stop_position;
    bit previous_pass_valid;
    keccak_mode previous_pass_mode;
    bit equivalence_reference_valid;
    int equivalence_reference_kind;
    keccak_mode equivalence_reference_mode;
    string equivalence_reference_msg;
    logic [7:0] equivalence_reference_bytes[$];
    bit prefix_reference_valid;
    int prefix_reference_kind;
    keccak_mode prefix_reference_mode;
    string prefix_reference_msg;
    logic [7:0] prefix_reference_bytes[$];
    bit [31:0] byte_order_seen;

    function new(string name = "keccak_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;
        pending_reset_state = 0;
        pending_stop_position = 0;
        previous_pass_valid = 0;
        equivalence_reference_valid = 0;
        prefix_reference_valid = 0;
        byte_order_seen = '0;
        checked_ap   = new("checked_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_fifo = new("exp_fifo", this);
        obs_fifo = new("obs_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            keccak_transaction exp_tx;
            keccak_transaction obs_tx;
            exp_fifo.get(exp_tx);
            obs_fifo.get(obs_tx);
            compare_tx(exp_tx, obs_tx);
        end
    endtask

    function void compare_tx(keccak_transaction exp_tx, keccak_transaction obs_tx);
        string obs_str = "";
        string exp_str;
        string exp_msg;
        string obs_msg;
        int    exp_bytes;
        bit    pass;
        bit    control_match;
        bit    input_match;
        bit    output_match;
        bit    stress_match;
        bit    concurrency_match;
        bit    reset_setup_match;
        bit    config_change_match;
        bit    stop_position_match;
        bit    relation_match;
        int    observed_transition;

        total_tests++;
        exp_bytes = exp_tx.output_len_bits / 8;
        exp_str   = exp_tx.exp_hex.tolower();
        exp_msg   = exp_tx.msg_hex.tolower();
        obs_msg   = obs_tx.obs_msg_hex.tolower();

        for (int i = 0; i < exp_bytes; i++) begin
            if (i < obs_tx.obs_bytes.size())
                obs_str = {obs_str, $sformatf("%02x", obs_tx.obs_bytes[i])};
            else
                obs_str = {obs_str, "XX"};
        end

        control_match = (obs_tx.mode === exp_tx.mode) &&
                        (obs_tx.xof_len_val === exp_tx.xof_len_val) &&
                        (obs_tx.message_len_val == (exp_msg.len() / 2));
        input_match   = (obs_msg == exp_msg);
        output_match  = (obs_tx.obs_bytes.size() == exp_bytes) &&
                        (obs_str == exp_str);
        stress_match  = ((exp_tx.input_gap_kind == 0) ||
                         (obs_tx.input_gap_cycles > 0)) &&
                        ((exp_tx.output_stall_kind == 0) ||
                         ((obs_tx.output_stall_cycles > 0) &&
                          (obs_tx.stall_position == exp_tx.stall_position)));
        concurrency_match =
            (exp_tx.expected_active_lanes == 0) ||
            (obs_tx.max_active_lanes == exp_tx.expected_active_lanes);
        reset_setup_match =
            (obs_tx.pre_start_reset_seen == exp_tx.reset_before_start);
        config_change_match =
            (obs_tx.config_latch_case == exp_tx.config_change_kind);
        stop_position_match =
            (exp_tx.xof_len_val != 0) ||
            (obs_tx.stop_issued &&
             ((exp_tx.stop_position_target == 0) ||
              (obs_tx.stop_position_observed ==
               exp_tx.stop_position_target)));
        relation_match = 1;
        observed_transition = 0;

        if (exp_tx.back_to_back_request > 0) begin
            case ({previous_pass_mode, obs_tx.mode})
                2'b00: observed_transition = 1;
                2'b01: observed_transition = 2;
                2'b10: observed_transition = 3;
                2'b11: observed_transition = 4;
            endcase
            relation_match &= previous_pass_valid &&
                              !obs_tx.pre_start_reset_seen &&
                              (observed_transition ==
                               exp_tx.back_to_back_request);
        end

        if ((exp_tx.stall_equivalence_request > 0) &&
            !exp_tx.equivalence_reference) begin
            relation_match &= equivalence_reference_valid &&
                              (equivalence_reference_kind ==
                               exp_tx.stall_equivalence_request) &&
                              (equivalence_reference_mode == obs_tx.mode) &&
                              (equivalence_reference_msg == obs_msg) &&
                              queues_equal(equivalence_reference_bytes,
                                           obs_tx.obs_bytes);
        end

        if ((exp_tx.prefix_consistency_request > 0) &&
            !exp_tx.prefix_reference) begin
            relation_match &= prefix_reference_valid &&
                              (prefix_reference_kind ==
                               exp_tx.prefix_consistency_request) &&
                              (prefix_reference_mode == obs_tx.mode) &&
                              (prefix_reference_msg == obs_msg) &&
                              queue_is_prefix(prefix_reference_bytes,
                                              obs_tx.obs_bytes);
        end

        if (exp_tx.byte_order_case > 0)
            relation_match &= (exp_tx.byte_order_case_count > 0) &&
                              (exp_tx.byte_order_case_count <= 32) &&
                              (exp_tx.byte_order_case <=
                               exp_tx.byte_order_case_count);

        case (exp_tx.lane_isolation_request)
            0: ;
            1: relation_match &= obs_tx.peer_reset_observed;
            2: relation_match &= obs_tx.peer_stall_observed;
            3: relation_match &= obs_tx.peer_stop_observed;
            default: relation_match = 0;
        endcase

        if (exp_tx.mixed_lane_work_request)
            relation_match &=
                (obs_tx.max_active_lanes == exp_tx.expected_active_lanes);

        if (exp_tx.reset_state_target > 0) begin
            obs_tx.data_ok = control_match && reset_setup_match &&
                             obs_tx.reset_observed &&
                             (obs_tx.reset_state_observed ==
                              exp_tx.reset_state_target) && relation_match;
            pass = obs_tx.start_seen && obs_tx.protocol_ok && obs_tx.data_ok;
        end else begin
            obs_tx.data_ok = control_match && input_match && output_match &&
                             stress_match && concurrency_match &&
                             reset_setup_match && config_change_match &&
                             stop_position_match && relation_match;
            pass = obs_tx.start_seen && obs_tx.input_complete &&
                   obs_tx.protocol_ok && obs_tx.data_ok;
        end

        obs_tx.passed = pass;

        if (pass) begin
            // Recovery credit belongs to the first checked transaction after
            // the abort/stop and only when no global reset occurred between
            // the two operations.
            if (!obs_tx.pre_start_reset_seen) begin
                obs_tx.reset_recovery_state = pending_reset_state;
                obs_tx.stop_recovery_position = pending_stop_position;
            end

            pending_reset_state = 0;
            pending_stop_position = 0;
            if (obs_tx.reset_observed)
                pending_reset_state = obs_tx.reset_state_observed;
            if (obs_tx.stop_issued)
                pending_stop_position = obs_tx.stop_position_observed;

            if (exp_tx.back_to_back_request > 0)
                obs_tx.back_to_back_transition = observed_transition;

            if ((exp_tx.stall_equivalence_request > 0) &&
                exp_tx.equivalence_reference) begin
                equivalence_reference_valid = 1;
                equivalence_reference_kind =
                    exp_tx.stall_equivalence_request;
                equivalence_reference_mode = obs_tx.mode;
                equivalence_reference_msg = obs_msg;
                equivalence_reference_bytes = obs_tx.obs_bytes;
            end else if (exp_tx.stall_equivalence_request > 0) begin
                obs_tx.stall_equivalence_kind =
                    exp_tx.stall_equivalence_request;
                equivalence_reference_valid = 0;
            end

            if ((exp_tx.prefix_consistency_request > 0) &&
                exp_tx.prefix_reference) begin
                prefix_reference_valid = 1;
                prefix_reference_kind =
                    exp_tx.prefix_consistency_request;
                prefix_reference_mode = obs_tx.mode;
                prefix_reference_msg = obs_msg;
                prefix_reference_bytes = obs_tx.obs_bytes;
            end else if (exp_tx.prefix_consistency_request > 0) begin
                obs_tx.prefix_consistency_kind =
                    exp_tx.prefix_consistency_request;
                prefix_reference_valid = 0;
            end

            if (exp_tx.byte_order_case > 0) begin
                bit [31:0] case_bit;
                bit [31:0] required_mask;
                case_bit = 32'b1 << (exp_tx.byte_order_case - 1);
                required_mask = (32'b1 << exp_tx.byte_order_case_count) - 1;
                byte_order_seen |= case_bit;
                if ((byte_order_seen & required_mask) == required_mask)
                    obs_tx.byte_order_suite = 1;
            end

            if (exp_tx.lane_isolation_request > 0)
                obs_tx.lane_isolation_kind =
                    exp_tx.lane_isolation_request;
            if (exp_tx.mixed_lane_work_request)
                obs_tx.mixed_lane_work_case = 1;
            if (obs_tx.permutation_suite_observed)
                obs_tx.permutation_suite = 1;

            previous_pass_valid = 1;
            previous_pass_mode = obs_tx.mode;

            passed_tests++;
            checked_ap.write(obs_tx);
            `uvm_info(get_type_name(),
                      $sformatf("[PASS] %s  (in=%0d bytes, out=%0d bytes, protocol_errors=0)",
                                exp_tx.test_name, obs_tx.accepted_input_bytes,
                                obs_tx.obs_bytes.size()),
                      UVM_LOW)
        end else begin
            pending_reset_state = 0;
            pending_stop_position = 0;
            previous_pass_valid = 0;
            equivalence_reference_valid = 0;
            prefix_reference_valid = 0;
            failed_tests++;
            obs_tx.failure_reason = $sformatf(
                "control=%0b input=%0b output=%0b protocol=%0b reset_setup=%0b config_change=%0b stop_position=%0b reset_target=%0d reset_observed=%0d errors=%0d",
                control_match, input_match, output_match, obs_tx.protocol_ok,
                reset_setup_match, config_change_match, stop_position_match,
                exp_tx.reset_state_target, obs_tx.reset_state_observed,
                obs_tx.protocol_errors);
            `uvm_error(get_type_name(),
                       $sformatf("[FAIL] %s  %s\n        Input bytes expected/observed: %0d/%0d\n        Expected output: %s\n        Observed output: %s\n        Protocol detail: %s",
                                 exp_tx.test_name, obs_tx.failure_reason,
                                 exp_msg.len() / 2, obs_tx.accepted_input_bytes,
                                 exp_str, obs_str, obs_tx.protocol_error_text))
        end
    endfunction

    function automatic bit queues_equal(input logic [7:0] lhs[$],
                                         input logic [7:0] rhs[$]);
        if (lhs.size() != rhs.size())
            return 0;
        foreach (lhs[i]) begin
            if (lhs[i] !== rhs[i])
                return 0;
        end
        return 1;
    endfunction

    function automatic bit queue_is_prefix(input logic [7:0] prefix[$],
                                            input logic [7:0] complete[$]);
        if ((prefix.size() == 0) || (prefix.size() >= complete.size()))
            return 0;
        foreach (prefix[i]) begin
            if (prefix[i] !== complete[i])
                return 0;
        end
        return 1;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
                  $sformatf("\n=================== SCOREBOARD SUMMARY ===================\n  Total:  %0d\n  Passed: %0d\n  Failed: %0d\n==========================================================",
                            total_tests, passed_tests, failed_tests),
                  UVM_NONE)
    endfunction

endclass
