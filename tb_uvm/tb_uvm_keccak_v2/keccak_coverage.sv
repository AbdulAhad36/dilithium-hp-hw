// =========================================================================
// keccak_coverage.sv  -  TB v2 functional coverage (SHAKE-only)
// Samples monitor-observed transactions only after the scoreboard passes them.
// =========================================================================
class keccak_coverage extends uvm_subscriber #(keccak_transaction);
    `uvm_component_utils(keccak_coverage)

    localparam int N_LANES = 4;

    keccak_transaction tx_sampled;
    int lane_id = -1;
    static int total_passed_samples = 0;

    // Derived requirement categories. Zero means that the requirement was not
    // exercised or is not yet observable with the current transaction fields.
    int sample_msg_boundary;
    int sample_absorb_blocks;
    int sample_output_kind;
    int sample_output_boundary;
    int sample_squeeze_blocks;
    int sample_input_gap;
    int sample_output_stall;
    int sample_stall_position;
    int sample_reset_state;
    int sample_stop_position;
    int sample_active_lanes;
    int sample_latency_class;
    int sample_back_to_back;
    int sample_config_latch;
    int sample_reset_recovery;
    int sample_stop_recovery;
    int sample_stall_equivalence;
    int sample_lane_isolation;
    int sample_mixed_lane_work;
    int sample_prefix_consistency;
    int sample_byte_order_suite;
    int sample_permutation_suite;

    covergroup cg_keccak;
        option.per_instance = 1;

        cp_mode : coverpoint tx_sampled.mode {
            type_option.weight = 2;
            bins shake128 = {SHAKE128};
            bins shake256 = {SHAKE256};
        }

        cp_msg_boundary : coverpoint sample_msg_boundary {
            type_option.weight = 12;
            bins empty       = {1};
            bins one_byte    = {2};
            bins beat_m1     = {3};
            bins beat_exact  = {4};
            bins beat_p1     = {5};
            bins rate_m1     = {6};
            bins rate_exact  = {7};
            bins rate_p1     = {8};
            bins rate2_m1    = {9};
            bins rate2_exact = {10};
            bins rate2_p1    = {11};
            bins blocks_3p   = {12};
        }

        cp_final_input_bytes : coverpoint tx_sampled.final_input_bytes
            iff (sample_reset_state == 0) {
            type_option.weight = 9;
            bins empty = {0};
            bins bytes_1_to_8[] = {[1:8]};
        }

        cp_absorb_blocks : coverpoint sample_absorb_blocks {
            type_option.weight = 4;
            bins one   = {1};
            bins two   = {2};
            bins three = {3};
            bins four_plus = {4};
        }

        cp_output_kind : coverpoint sample_output_kind {
            type_option.weight = 2;
            bins bounded   = {1};
            bins continuous = {2};
        }

        cp_output_boundary : coverpoint sample_output_boundary {
            type_option.weight = 15;
            bins bytes_1_to_8[] = {[1:8]};
            bins rate_m1        = {9};
            bins rate_exact     = {10};
            bins rate_p1        = {11};
            bins rate2_m1       = {12};
            bins rate2_exact    = {13};
            bins rate2_p1       = {14};
            bins maximum_tested = {15};
        }

        cp_final_output_bytes : coverpoint tx_sampled.final_output_bytes
            iff (sample_reset_state == 0) {
            type_option.weight = 8;
            bins bytes_1_to_8[] = {[1:8]};
        }

        cp_squeeze_blocks : coverpoint sample_squeeze_blocks {
            type_option.weight = 4;
            bins one   = {1};
            bins two   = {2};
            bins three = {3};
            bins four_plus = {4};
        }

        cp_input_gap : coverpoint sample_input_gap {
            type_option.weight = 4;
            bins none         = {1};
            bins single_cycle = {2};
            bins burst        = {3};
            bins random       = {4};
        }

        cp_output_stall : coverpoint sample_output_stall {
            type_option.weight = 4;
            bins none         = {1};
            bins single_cycle = {2};
            bins burst        = {3};
            bins random       = {4};
        }

        cp_stall_position : coverpoint sample_stall_position {
            type_option.weight = 3;
            bins ordinary_beat    = {1};
            bins final_beat       = {2};
            bins rate_boundary    = {3};
        }

        cp_reset_state : coverpoint sample_reset_state {
            type_option.weight = 6;
            bins idle             = {1};
            bins absorb           = {2};
            bins suffix_padding   = {3};
            bins permute_even_round = {4};
            bins permute_odd_round  = {5};
            bins squeeze          = {6};
        }

        cp_stop_position : coverpoint sample_stop_position {
            type_option.weight = 5;
            bins first_beat       = {1};
            bins mid_block        = {2};
            bins rate_boundary    = {3};
            bins after_repermute  = {4};
            bins while_stalled    = {5};
        }

        cp_lane_id : coverpoint lane_id {
            type_option.weight = 4;
            bins lanes[] = {[0:N_LANES-1]};
        }

        cp_active_lanes : coverpoint sample_active_lanes {
            type_option.weight = 4;
            bins one   = {1};
            bins two   = {2};
            bins three = {3};
            bins all   = {4};
        }

        cp_latency_class : coverpoint sample_latency_class {
            type_option.weight = 4;
            bins expected_no_stall = {1};
            bins input_stalled     = {2};
            bins output_stalled    = {3};
            bins multi_block       = {4};
        }

        // Planned P1 scenarios. These bins intentionally remain open until a
        // monitor and checker prove the behavior; requested stimulus alone is
        // never enough to close them.
        cp_back_to_back : coverpoint sample_back_to_back {
            type_option.weight = 4;
            bins shake128_to_shake128 = {1};
            bins shake128_to_shake256 = {2};
            bins shake256_to_shake128 = {3};
            bins shake256_to_shake256 = {4};
        }

        cp_config_latch : coverpoint sample_config_latch {
            type_option.weight = 3;
            bins mode_pin_changed   = {1};
            bins length_pin_changed = {2};
            bins both_changed       = {3};
        }

        cp_reset_recovery : coverpoint sample_reset_recovery {
            type_option.weight = 6;
            bins idle            = {1};
            bins absorb          = {2};
            bins suffix_padding  = {3};
            bins permute_even_round = {4};
            bins permute_odd_round  = {5};
            bins squeeze         = {6};
        }

        cp_stop_recovery : coverpoint sample_stop_recovery {
            type_option.weight = 5;
            bins first_beat      = {1};
            bins mid_block       = {2};
            bins rate_boundary   = {3};
            bins after_repermute = {4};
            bins while_stalled   = {5};
        }

        cp_stall_equivalence : coverpoint sample_stall_equivalence {
            type_option.weight = 3;
            bins ordinary_beat = {1};
            bins final_beat    = {2};
            bins rate_boundary = {3};
        }

        cp_lane_isolation : coverpoint sample_lane_isolation {
            type_option.weight = 3;
            bins peer_reset = {1};
            bins peer_stall = {2};
            bins peer_stop  = {3};
        }

        cp_mixed_lane_work : coverpoint sample_mixed_lane_work {
            type_option.weight = 1;
            bins independently_checked = {1};
        }

        cp_prefix_consistency : coverpoint sample_prefix_consistency {
            type_option.weight = 3;
            bins within_rate = {1};
            bins cross_rate  = {2};
            bins multi_rate  = {3};
        }

        cp_byte_order_suite : coverpoint sample_byte_order_suite {
            type_option.weight = 1;
            bins walking_byte_and_bit_passed = {1};
        }

        cp_permutation_suite : coverpoint sample_permutation_suite {
            type_option.weight = 1;
            bins all_steps_and_rounds_passed = {1};
        }

        cross_mode_msg : cross cp_mode, cp_msg_boundary {
            type_option.weight = 24;
        }
        cross_mode_output : cross cp_mode, cp_output_boundary {
            type_option.weight = 30;
        }
        cross_mode_final_input : cross cp_mode, cp_final_input_bytes {
            type_option.weight = 18;
        }
        cross_mode_final_output : cross cp_mode, cp_final_output_bytes {
            type_option.weight = 16;
        }
        cross_kind_squeeze : cross cp_output_kind, cp_squeeze_blocks {
            type_option.weight = 8;
        }

        cross_stall_position : cross cp_output_stall, cp_stall_position {
            type_option.weight = 9;
            ignore_bins no_stall = binsof(cp_output_stall) intersect {1};
        }

        cross_reset_mode : cross cp_reset_state, cp_mode {
            type_option.weight = 12;
        }
        cross_lane_mode : cross cp_lane_id, cp_mode {
            type_option.weight = 8;
        }
        cross_active_lane_mode : cross cp_active_lanes, cp_mode {
            type_option.weight = 8;
        }
        cross_reset_recovery_mode : cross cp_reset_recovery, cp_mode {
            type_option.weight = 12;
        }
        cross_stop_recovery_mode : cross cp_stop_recovery, cp_mode {
            type_option.weight = 10;
        }
        cross_lane_isolation_mode : cross cp_lane_isolation, cp_mode {
            type_option.weight = 6;
        }
    endgroup

    function new(string name = "keccak_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_keccak = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(int)::get(this, "", "lane_id", lane_id))
            `uvm_fatal(get_type_name(), "Coverage lane_id was not configured")
    endfunction

    function void write(keccak_transaction t);
        if (!t.passed || !t.protocol_ok || !t.data_ok) begin
            `uvm_error(get_type_name(),
                       $sformatf("Coverage rejected unchecked transaction %s", t.test_name))
            return;
        end
        tx_sampled = t;
        derive_categories(t);
        total_passed_samples++;
        cg_keccak.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (lane_id == 0)
            `uvm_info(get_type_name(),
                      $sformatf("Expanded P1 functional covergroup coverage: %0.2f%% (%0d passed samples)",
                                cg_keccak.get_coverage(), total_passed_samples),
                      UVM_NONE)
    endfunction

    function void derive_categories(input keccak_transaction t);
        int msg_bytes = t.obs_msg_hex.len() / 2;
        int out_bytes = t.obs_bytes.size();
        int rate_bytes = get_rate_bytes(t.mode);

        sample_msg_boundary = 0;
        sample_absorb_blocks = 0;
        sample_output_kind = 0;
        sample_output_boundary = 0;
        sample_squeeze_blocks = 0;
        sample_input_gap = 0;
        sample_output_stall = 0;
        sample_stall_position = 0;
        sample_reset_state = t.reset_state_observed;
        sample_stop_position = 0;
        sample_active_lanes = t.max_active_lanes;
        sample_latency_class = 0;
        sample_back_to_back = t.back_to_back_transition;
        sample_config_latch = t.config_latch_case;
        sample_reset_recovery = t.reset_recovery_state;
        sample_stop_recovery = t.stop_recovery_position;
        sample_stall_equivalence = t.stall_equivalence_kind;
        sample_lane_isolation = t.lane_isolation_kind;
        sample_mixed_lane_work = t.mixed_lane_work_case;
        sample_prefix_consistency = t.prefix_consistency_kind;
        sample_byte_order_suite = t.byte_order_suite;
        sample_permutation_suite = t.permutation_suite;

        if (t.reset_observed)
            return;

        sample_msg_boundary   = classify_msg_boundary(msg_bytes, rate_bytes);
        sample_absorb_blocks  = clamp_blocks((msg_bytes / rate_bytes) + 1);
        sample_output_kind    = (t.xof_len_val == 0) ? 2 : 1;
        sample_output_boundary = classify_output_boundary(out_bytes, rate_bytes);
        sample_squeeze_blocks = clamp_blocks((out_bytes + rate_bytes - 1) / rate_bytes);
        sample_input_gap      = classify_pause(t.input_gap_kind,
                                                t.input_gap_cycles);
        sample_output_stall   = classify_pause(t.output_stall_kind,
                                                t.output_stall_cycles);

        // Position/state fields remain zero until a test observes that event.
        // Zero is outside the required bins, so missing instrumentation cannot
        // accidentally improve the reported percentage.
        sample_stall_position = (t.output_stall_cycles > 0) ?
                                t.stall_position : 0;
        sample_stop_position  = t.stop_position_observed;

        if (t.input_gap_cycles > 0)
            sample_latency_class = 2;
        else if (t.output_stall_cycles > 0)
            sample_latency_class = 3;
        else if ((sample_absorb_blocks > 1) || (sample_squeeze_blocks > 1))
            sample_latency_class = 4;
        else
            sample_latency_class = 1;
    endfunction

    function automatic int get_rate_bytes(input keccak_mode mode);
        return (mode == SHAKE256) ? 136 : 168;
    endfunction

    function automatic int clamp_blocks(input int blocks);
        if (blocks >= 4) return 4;
        if (blocks <= 1) return 1;
        return blocks;
    endfunction

    function automatic int classify_msg_boundary(input int length,
                                                   input int rate);
        if (length == 0)          return 1;
        if (length == 1)          return 2;
        if (length == 7)          return 3;
        if (length == 8)          return 4;
        if (length == 9)          return 5;
        if (length == rate - 1)   return 6;
        if (length == rate)       return 7;
        if (length == rate + 1)   return 8;
        if (length == 2*rate - 1) return 9;
        if (length == 2*rate)     return 10;
        if (length == 2*rate + 1) return 11;
        if (length >= 3*rate)     return 12;
        return 0;
    endfunction

    function automatic int classify_output_boundary(input int length,
                                                      input int rate);
        if ((length >= 1) && (length <= 8)) return length;
        if (length == rate - 1)             return 9;
        if (length == rate)                 return 10;
        if (length == rate + 1)             return 11;
        if (length == 2*rate - 1)           return 12;
        if (length == 2*rate)               return 13;
        if (length == 2*rate + 1)           return 14;
        if (length == 600)                  return 15;
        return 0;
    endfunction

    function automatic int classify_pause(input int kind, input int cycles);
        if (cycles == 0) return 1;
        if ((kind >= 1) && (kind <= 3)) return kind + 1;
        return 0;
    endfunction

endclass
