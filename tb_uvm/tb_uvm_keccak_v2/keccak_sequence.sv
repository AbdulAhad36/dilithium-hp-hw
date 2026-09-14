// =========================================================================
// keccak_sequence.sv  -  Directed and random sequences (TB v2, SHAKE-only)
//
// All sequence items populate exp_hex with the expected SHAKE output. For
// the 13 NIST directed vectors exp_hex is the published value. For random
// stress and coverage-closure items, exp_hex is computed at sim time by the
// pure-SV reference model in keccak_ref_pkg::shake_hex(). The scoreboard
// golden-compares every transaction; no [NOCHK] skip path is used.
// =========================================================================

// Base sequence: helper to push one directed item
class keccak_base_seq extends uvm_sequence #(keccak_transaction);
    `uvm_object_utils(keccak_base_seq)

    function new(string name = "keccak_base_seq");
        super.new(name);
    endfunction

    task send_item(string test_name, keccak_mode mode, string msg_hex,
                   string exp_hex, int output_len_bits, int xof_len_val,
                   int input_gap_kind = 0,
                   int output_stall_kind = 0,
                   int stall_position = 0,
                   int expected_active_lanes = 0,
                   bit stop_during_stall = 0,
                   bit reset_before_start = 1,
                   int config_change_kind = 0,
                   int stop_position_target = 0,
                   int back_to_back_request = 0,
                   int stall_equivalence_request = 0,
                   bit equivalence_reference = 0,
                   int prefix_consistency_request = 0,
                   bit prefix_reference = 0,
                   int byte_order_case = 0,
                   int byte_order_case_count = 0,
                   int lane_isolation_request = 0,
                   bit mixed_lane_work_request = 0,
                   int reset_state_target = 0,
                   bit hold_valid_after_message = 0);
        keccak_transaction tx;
        tx = keccak_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name        = test_name;
        tx.mode             = mode;
        tx.msg_hex          = msg_hex;
        tx.exp_hex          = exp_hex;
        tx.output_len_bits  = output_len_bits;
        tx.xof_len_val      = xof_len_val;
        tx.input_gap_kind   = input_gap_kind;
        tx.output_stall_kind = output_stall_kind;
        tx.stall_position   = stall_position;
        tx.expected_active_lanes = expected_active_lanes;
        tx.stop_during_stall = stop_during_stall;
        tx.reset_before_start = reset_before_start;
        tx.config_change_kind = config_change_kind;
        tx.stop_position_target = stop_position_target;
        tx.back_to_back_request = back_to_back_request;
        tx.stall_equivalence_request = stall_equivalence_request;
        tx.equivalence_reference = equivalence_reference;
        tx.prefix_consistency_request = prefix_consistency_request;
        tx.prefix_reference = prefix_reference;
        tx.byte_order_case = byte_order_case;
        tx.byte_order_case_count = byte_order_case_count;
        tx.lane_isolation_request = lane_isolation_request;
        tx.mixed_lane_work_request = mixed_lane_work_request;
        tx.reset_state_target = reset_state_target;
        tx.hold_valid_after_message = hold_valid_after_message;
        finish_item(tx);
    endtask
endclass


// NIST directed test suite (SHAKE128, SHAKE256 only).
// Each vector runs once as Continuous (xof_len=0) and once as Bounded.
class keccak_directed_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_directed_seq)

    function new(string name = "keccak_directed_seq");
        super.new(name);
    endfunction

    task body();
        // -------------------- SHAKE128 (rate 168) --------------------
        // Continuous
        send_item("SHAKE128 Empty (Cont)",          SHAKE128, "",
                  "7f9c2ba4e88f827d616045507605853e", 128, 0);
        send_item("SHAKE128 Short (Cont)",          SHAKE128, "84f6cb3dc77b9bf856caf54e",
                  "56538d52b26f967bb9405e0f54fdf6e2", 128, 0);
        send_item("SHAKE128 Boundary Cross (Cont)", SHAKE128, "cc",
                  "4dd4b0004a7d9e613a0f488b4846f804015f0f8ccdba5f7c16810bbc5a1c6fb254efc81969c5eb49e682babae02238a31fd2708e418d7b754e21e4b75b65e7d39b5b42d739066e7c63595daf26c3a6a2f7001ee636c7cb2a6c69b1ec7314a21ff24833eab61258327517b684928c7444380a6eacd60a6e9400da37a61050e4cd1fbdd05dde0901ea2f3f67567f7c9bf7aa53590f29c94cb4226e77c68e1600e4765bea40b3644b4d1e93eda6fb0380377c12d5bb9df4728099e88b55d820c7f827034d809e756831",
                  1600, 0);

        // Bounded (xof_len = output bytes)
        send_item("SHAKE128 Empty (Bnd)",           SHAKE128, "",
                  "7f9c2ba4e88f827d616045507605853e", 128, 16);
        send_item("SHAKE128 Short (Bnd)",           SHAKE128, "84f6cb3dc77b9bf856caf54e",
                  "56538d52b26f967bb9405e0f54fdf6e2", 128, 16);
        send_item("SHAKE128 Boundary Cross (Bnd)",  SHAKE128, "cc",
                  "4dd4b0004a7d9e613a0f488b4846f804015f0f8ccdba5f7c16810bbc5a1c6fb254efc81969c5eb49e682babae02238a31fd2708e418d7b754e21e4b75b65e7d39b5b42d739066e7c63595daf26c3a6a2f7001ee636c7cb2a6c69b1ec7314a21ff24833eab61258327517b684928c7444380a6eacd60a6e9400da37a61050e4cd1fbdd05dde0901ea2f3f67567f7c9bf7aa53590f29c94cb4226e77c68e1600e4765bea40b3644b4d1e93eda6fb0380377c12d5bb9df4728099e88b55d820c7f827034d809e756831",
                  1600, 200);

        // -------------------- SHAKE256 (rate 136) --------------------
        send_item("SHAKE256 Empty (Cont)",  SHAKE256, "",
                  "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f", 256, 0);
        send_item("SHAKE256 Short (Cont)",  SHAKE256, "765db6ab3af389b8c775c8eb99fe72",
                  "ccb6564a655c94d714f80b9f8de9e2610c4478778eac1b9256237dbf90e50581", 256, 0);
        send_item("SHAKE256 Long (Cont)",   SHAKE256,
                  "dc5a100fa16df1583c79722a0d72833d3bf22c109b8889dbd35213c6bfce205813edae3242695cfd9f59b9a1c203c1b72ef1a5423147cb990b5316a85266675894e2644c3f9578cebe451a09e58c53788fe77a9e850943f8a275f830354b0593a762bac55e984db3e0661eca3cb83f67a6fb348e6177f7dee2df40c4322602f094953905681be3954fe44c4c902c8f6bba565a788b38f13411ba76ce0f9f6756a2a2687424c5435a51e62df7a8934b6e141f74c6ccf539e3782d22b5955d3baf1ab2cf7b5c3f74ec2f9447344e937957fd7f0bdfec56d5d25f61cde18c0986e244ecf780d6307e313117256948d4230ebb9ea62bb302cfe80d7dfebabc4a51d7687967ed5b416a139e974c005fff507a96",
                  "2bac5716803a9cda8f9e84365ab0a681327b5ba34fdedfb1c12e6e807f45284b", 256, 0);

        send_item("SHAKE256 Empty (Bnd)",   SHAKE256, "",
                  "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f", 256, 32);
        send_item("SHAKE256 Short (Bnd)",   SHAKE256, "765db6ab3af389b8c775c8eb99fe72",
                  "ccb6564a655c94d714f80b9f8de9e2610c4478778eac1b9256237dbf90e50581", 256, 32);
        send_item("SHAKE256 Long (Bnd)",    SHAKE256,
                  "dc5a100fa16df1583c79722a0d72833d3bf22c109b8889dbd35213c6bfce205813edae3242695cfd9f59b9a1c203c1b72ef1a5423147cb990b5316a85266675894e2644c3f9578cebe451a09e58c53788fe77a9e850943f8a275f830354b0593a762bac55e984db3e0661eca3cb83f67a6fb348e6177f7dee2df40c4322602f094953905681be3954fe44c4c902c8f6bba565a788b38f13411ba76ce0f9f6756a2a2687424c5435a51e62df7a8934b6e141f74c6ccf539e3782d22b5955d3baf1ab2cf7b5c3f74ec2f9447344e937957fd7f0bdfec56d5d25f61cde18c0986e244ecf780d6307e313117256948d4230ebb9ea62bb302cfe80d7dfebabc4a51d7687967ed5b416a139e974c005fff507a96",
                  "2bac5716803a9cda8f9e84365ab0a681327b5ba34fdedfb1c12e6e807f45284b", 256, 32);
    endtask
endclass


// Random/stress sequence: drives many random items through both SHAKE modes,
// random message lengths and random bounded xof_len. Expected output is
// computed at sim time via keccak_ref_pkg::shake_hex() so the scoreboard can
// golden-compare every item end-to-end.
class keccak_stress_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_stress_seq)

    int num_items = 20;

    function new(string name = "keccak_stress_seq");
        super.new(name);
    endfunction

    task body();
        keccak_mode m;
        int         msg_byte_len;
        int         xof_bytes;
        string      msg_hex;
        string      tn;
        bit [7:0]   b;
        int         out_bits;
        int         out_bytes;
        string      exp_hex;

        for (int i = 0; i < num_items; i++) begin
            m = (i % 2 == 0) ? SHAKE128 : SHAKE256;
            case (i % 5)
                0: msg_byte_len = 0;
                1: msg_byte_len = $urandom_range(1, 71);
                2: msg_byte_len = $urandom_range(72, 167);
                3: msg_byte_len = $urandom_range(168, 271);
                4: msg_byte_len = $urandom_range(272, 600);
            endcase
            if (i % 2 == 0) xof_bytes = 0;
            else            xof_bytes = $urandom_range(8, 400);

            msg_hex = "";
            for (int j = 0; j < msg_byte_len; j++) begin
                b = $urandom_range(0, 255);
                msg_hex = {msg_hex, $sformatf("%02x", b)};
            end

            out_bits  = (xof_bytes > 0) ? (xof_bytes * 8) : 256;
            out_bytes = out_bits / 8;
            exp_hex   = keccak_ref_pkg::shake_hex(m, msg_hex, out_bytes);

            tn = $sformatf("STRESS_%0d %s msglen=%0d xof_len=%0d",
                           i, m.name(), msg_byte_len, xof_bytes);
            send_item(tn, m, msg_hex, exp_hex, out_bits, xof_bytes);
        end
    endtask
endclass


// Reset-recovery sequence: covers reset from every observed FSM phase.
class keccak_abort_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_abort_seq)

    function new(string name = "keccak_abort_seq");
        super.new(name);
    endfunction

    task send_abort(string test_name, keccak_mode mode, string msg_hex,
                    int reset_target);
        keccak_transaction tx;
        tx = keccak_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name          = test_name;
        tx.mode               = mode;
        tx.msg_hex            = msg_hex;
        tx.exp_hex             = "";
        tx.output_len_bits     = 256;
        tx.xof_len_val         = 32;
        tx.reset_state_target  = reset_target;
        finish_item(tx);
    endtask

    task send_recovery(string state_name, keccak_mode mode,
                       int reset_target);
        string msg = "616263";
        string exp = keccak_ref_pkg::shake_hex(mode, msg, 32);
        send_item(
            $sformatf("%s RECOVERY after reset from %s",
                      mode.name(), state_name),
            mode, msg, exp, 256, 32,
            0, 0, 0, 0, 0, 0);
    endtask

    task body();
        keccak_mode modes[2] = '{SHAKE128, SHAKE256};
        string state_names[6] = '{"IDLE", "ABSORB", "SUFFIX_PADDING",
                                  "PERMUTE_A", "PERMUTE_B", "SQUEEZE"};

        foreach (modes[m]) begin
            for (int target = 1; target <= 6; target++) begin
                send_abort($sformatf("%s RESET from %s",
                                     modes[m].name(), state_names[target-1]),
                           modes[m], "616263", target);
                send_recovery(state_names[target-1], modes[m],
                              target);
            end
        end
    endtask
endclass


// Coverage-closure sequence: deterministically hits every cp_msg_len bin
// for both SHAKE modes (12 cross bins) AND every cp_xof_kind bin for both
// SHAKE modes (8 cross bins). Expected hex is computed at sim time via the
// pure-SV reference model so each item is golden-compared.
class keccak_cov_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_cov_seq)

    function new(string name = "keccak_cov_seq");
        super.new(name);
    endfunction

    function automatic string make_msg(int n_bytes);
        bit [7:0] b;
        string s = "";
        for (int j = 0; j < n_bytes; j++) begin
            b = $urandom_range(0, 255);
            s = {s, $sformatf("%02x", b)};
        end
        return s;
    endfunction

    task send_cov_item(string label, keccak_mode m, int n_bytes, int xof_bytes);
        string  msg;
        int     out_bits;
        int     out_bytes;
        string  exp;
        msg       = make_msg(n_bytes);
        out_bits  = (xof_bytes > 0) ? (xof_bytes * 8) : 256;
        out_bytes = out_bits / 8;
        exp       = keccak_ref_pkg::shake_hex(m, msg, out_bytes);
        send_item({"COV ", label}, m, msg, exp, out_bits, xof_bytes);
    endtask

    task body();
        keccak_mode modes [$] = '{SHAKE128, SHAKE256};

        // --- cross_mode_msg coverage: 2 modes x 6 msg_len bins = 12 bins ---
        foreach (modes[i]) begin
            send_cov_item($sformatf("%s msglen=0",   modes[i].name()), modes[i],   0, 0);
            send_cov_item($sformatf("%s msglen=40",  modes[i].name()), modes[i],  40, 0);
            send_cov_item($sformatf("%s msglen=100", modes[i].name()), modes[i], 100, 0);
            send_cov_item($sformatf("%s msglen=150", modes[i].name()), modes[i], 150, 0);
            send_cov_item($sformatf("%s msglen=200", modes[i].name()), modes[i], 200, 0);
            send_cov_item($sformatf("%s msglen=300", modes[i].name()), modes[i], 300, 0);
        end

        // --- cross_shake_xof coverage: each SHAKE mode x 4 xof_kind bins ---
        send_cov_item("SHAKE128 xof=continuous", SHAKE128, 16,   0);
        send_cov_item("SHAKE128 xof=small",      SHAKE128, 16,  16);
        send_cov_item("SHAKE128 xof=medium",     SHAKE128, 16, 100);
        send_cov_item("SHAKE128 xof=large",      SHAKE128, 16, 300);
        send_cov_item("SHAKE256 xof=continuous", SHAKE256, 16,   0);
        send_cov_item("SHAKE256 xof=small",      SHAKE256, 16,  20);
        send_cov_item("SHAKE256 xof=medium",     SHAKE256, 16, 120);
        send_cov_item("SHAKE256 xof=large",      SHAKE256, 16, 250);
    endtask
endclass


// Configuration-latching suite. The external mode/output-length pins are
// changed after start; the original configuration must still determine the
// complete golden-checked result.
class keccak_config_latch_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_config_latch_seq)

    function new(string name = "keccak_config_latch_seq");
        super.new(name);
    endfunction

    task body();
        keccak_mode modes[$] = '{SHAKE128, SHAKE256};
        string labels[3] = '{"mode pin", "length pin", "both pins"};

        foreach (modes[m]) begin
            for (int kind = 1; kind <= 3; kind++) begin
                string msg = "636f6e6669672d6c61746368";
                string exp = keccak_ref_pkg::shake_hex(modes[m], msg, 32);
                send_item(
                    $sformatf("CONFIG %s change %s",
                              modes[m].name(), labels[kind-1]),
                    modes[m], msg, exp, 256, 32,
                    0, 0, 0, 0, 0, 1, kind);
            end
        end
    endtask
endclass


class keccak_continuous_stop_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_continuous_stop_seq)

    function new(string name = "keccak_continuous_stop_seq");
        super.new(name);
    endfunction

    task send_continuous(string label, keccak_mode mode, int output_bytes,
                         int stop_target, int stall_kind = 0,
                         bit stop_in_stall = 0);
        string msg = "73746f702d706f736974696f6e";
        string exp = keccak_ref_pkg::shake_hex(mode, msg, output_bytes);
        send_item({"CONTINUOUS ", label}, mode, msg, exp,
                  output_bytes * 8, 0,
                  0, stall_kind, stop_in_stall ? 1 : 0,
                  0, stop_in_stall, 1, 0, stop_target);
    endtask

    task send_recovery(string label, keccak_mode mode);
        string msg = "73746f702d7265636f76657279";
        string exp = keccak_ref_pkg::shake_hex(mode, msg, 32);
        send_item({"STOP RECOVERY ", label}, mode, msg, exp,
                  256, 32, 0, 0, 0, 0, 0, 0);
    endtask

    task body();
        keccak_mode modes[$] = '{SHAKE128, SHAKE256};

        foreach (modes[m]) begin
            int rate = (modes[m] == SHAKE128) ? 168 : 136;

            send_continuous("stop first beat", modes[m], 8, 1);
            send_recovery("after first beat", modes[m]);

            send_continuous("stop mid-block", modes[m], 40, 2);
            send_recovery("after mid-block", modes[m]);

            send_continuous("stop at rate boundary", modes[m], rate, 3);
            send_recovery("after rate boundary", modes[m]);

            send_continuous("stop after repermute", modes[m], rate + 16, 4);
            send_recovery("after repermute", modes[m]);

            send_continuous("stop after three squeeze blocks",
                            modes[m], 3*rate, 4);
            send_recovery("after three squeeze blocks", modes[m]);

            send_continuous("stop after four-plus squeeze blocks",
                            modes[m], 4*rate + 8, 4);
            send_recovery("after four-plus squeeze blocks", modes[m]);

            send_continuous("stop while stalled", modes[m], 8, 5, 1, 1);
            send_recovery("after stalled stop", modes[m]);
        end
    endtask
endclass


class keccak_concurrency_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_concurrency_seq)

    int active_lanes = 1;

    function new(string name = "keccak_concurrency_seq");
        super.new(name);
    endfunction

    task body();
        string msg = "436f6e63757272656e6379";
        keccak_mode modes[$] = '{SHAKE128, SHAKE256};
        foreach (modes[i]) begin
            string exp = keccak_ref_pkg::shake_hex(modes[i], msg, 32);
            send_item(
                $sformatf("CONCURRENCY lanes=%0d %s",
                          active_lanes, modes[i].name()),
                modes[i], msg, exp, 256, 32,
                0, 0, 0, active_lanes);
        end
    endtask
endclass


// Directed protocol stress. Input gaps and output backpressure are checked
// end-to-end: a requested pause must be observed before coverage can sample it.
class keccak_protocol_stress_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_protocol_stress_seq)

    function new(string name = "keccak_protocol_stress_seq");
        super.new(name);
    endfunction

    function automatic string make_msg(int n_bytes);
        string s = "";
        for (int i = 0; i < n_bytes; i++)
            s = {s, $sformatf("%02x", (i * 17 + 8'h3d) & 8'hff)};
        return s;
    endfunction

    task send_stress_item(string label, keccak_mode mode,
                          int message_bytes, int output_bytes,
                          int gap_kind, int stall_kind,
                          int stall_position);
        string msg = make_msg(message_bytes);
        string exp = keccak_ref_pkg::shake_hex(mode, msg, output_bytes);
        send_item({"PROTOCOL ", label}, mode, msg, exp,
                  output_bytes * 8, output_bytes,
                  gap_kind, stall_kind, stall_position);
    endtask

    task body();
        // Exercise each input-gap category in both modes.
        for (int mode_index = 0; mode_index < 2; mode_index++) begin
            keccak_mode mode = (mode_index == 0) ? SHAKE128 : SHAKE256;
            for (int gap_kind = 1; gap_kind <= 3; gap_kind++) begin
                send_stress_item(
                    $sformatf("%s input-gap-kind=%0d", mode.name(), gap_kind),
                    mode, 40, 32, gap_kind, 0, 0);
            end

            // Keep valid asserted after the final accepted beat. The core
            // must lower ready and reject the extra word while it leaves
            // ABSORB; the normal golden comparison checks data integrity.
            begin
                string msg = make_msg(9 + mode_index);
                string exp = keccak_ref_pkg::shake_hex(mode, msg, 32);
                send_item(.test_name($sformatf(
                              "PROTOCOL %s valid held while not ready",
                              mode.name())),
                          .mode(mode), .msg_hex(msg), .exp_hex(exp),
                          .output_len_bits(256), .xof_len_val(32),
                          .hold_valid_after_message(1));
            end
        end

        // Cover all 3 pause kinds crossed with all 3 output positions.
        for (int stall_kind = 1; stall_kind <= 3; stall_kind++) begin
            for (int position = 1; position <= 3; position++) begin
                keccak_mode mode = ((stall_kind + position) % 2 == 0) ?
                                   SHAKE128 : SHAKE256;
                int rate = (mode == SHAKE128) ? 168 : 136;
                int output_bytes;
                case (position)
                    1: output_bytes = 40;
                    2: output_bytes = 19;
                    3: output_bytes = rate + 16;
                    default: output_bytes = 40;
                endcase
                send_stress_item(
                    $sformatf("%s stall-kind=%0d position=%0d",
                              mode.name(), stall_kind, position),
                    mode, 24, output_bytes, 0, stall_kind, position);
            end
        end
    endtask
endclass


// Requirement-directed message and output boundary suite. Every item is
// checked against the independent SystemVerilog SHAKE reference model.
class keccak_boundary_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_boundary_seq)

    function new(string name = "keccak_boundary_seq");
        super.new(name);
    endfunction

    function automatic string make_msg(int n_bytes);
        string s = "";
        for (int i = 0; i < n_bytes; i++)
            s = {s, $sformatf("%02x", (i * 29 + 8'h5a) & 8'hff)};
        return s;
    endfunction

    task send_boundary_item(string label, keccak_mode mode,
                            int message_bytes, int output_bytes);
        string msg = make_msg(message_bytes);
        string exp = keccak_ref_pkg::shake_hex(mode, msg, output_bytes);
        send_item({"BOUNDARY ", label}, mode, msg, exp,
                  output_bytes * 8, output_bytes);
    endtask

    task body();
        keccak_mode modes[$] = '{SHAKE128, SHAKE256};

        foreach (modes[m]) begin
            int rate = (modes[m] == SHAKE128) ? 168 : 136;
            int message_lengths[$] = '{
                0, 1, 7, 8, 9,
                rate - 1, rate, rate + 1,
                2*rate - 1, 2*rate, 2*rate + 1, 3*rate
            };
            int output_lengths[$] = '{
                1, 2, 3, 4, 5, 6, 7, 8,
                rate - 1, rate, rate + 1,
                2*rate - 1, 2*rate, 2*rate + 1, 600
            };

            foreach (message_lengths[i]) begin
                send_boundary_item(
                    $sformatf("%s message=%0d", modes[m].name(),
                              message_lengths[i]),
                    modes[m], message_lengths[i], 16);
            end

            foreach (output_lengths[i]) begin
                send_boundary_item(
                    $sformatf("%s output=%0d", modes[m].name(),
                              output_lengths[i]),
                    modes[m], 3, output_lengths[i]);
            end
        end
    endtask
endclass


// Cross-transaction closure suite. The sequence requests relationships, but
// only the scoreboard can award coverage after comparing observed results.
class keccak_deep_consistency_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_deep_consistency_seq)

    function new(string name = "keccak_deep_consistency_seq");
        super.new(name);
    endfunction

    function automatic string make_pattern(int n_bytes, int salt);
        string s = "";
        for (int i = 0; i < n_bytes; i++)
            s = {s, $sformatf("%02x", (i * 37 + salt) & 8'hff)};
        return s;
    endfunction

    task send_back_to_back_item(string label, keccak_mode mode,
                                int transition, bit reset_before_start);
        string msg = make_pattern(23, transition * 11);
        string exp = keccak_ref_pkg::shake_hex(mode, msg, 32);
        send_item(.test_name({"DEEP B2B ", label}), .mode(mode),
                  .msg_hex(msg), .exp_hex(exp), .output_len_bits(256),
                  .xof_len_val(32),
                  .reset_before_start(reset_before_start),
                  .back_to_back_request(transition));
    endtask

    task send_equivalence_pair(int kind, keccak_mode mode,
                               int output_bytes);
        string msg = make_pattern(41, 8'h40 + kind);
        string exp = keccak_ref_pkg::shake_hex(mode, msg, output_bytes);
        send_item(.test_name($sformatf("DEEP STALL REF kind=%0d", kind)),
                  .mode(mode), .msg_hex(msg), .exp_hex(exp),
                  .output_len_bits(output_bytes * 8),
                  .xof_len_val(output_bytes),
                  .stall_equivalence_request(kind),
                  .equivalence_reference(1));
        send_item(.test_name($sformatf("DEEP STALL CHECK kind=%0d", kind)),
                  .mode(mode), .msg_hex(msg), .exp_hex(exp),
                  .output_len_bits(output_bytes * 8),
                  .xof_len_val(output_bytes), .output_stall_kind(2),
                  .stall_position(kind),
                  .stall_equivalence_request(kind));
    endtask

    task send_prefix_pair(int kind, keccak_mode mode,
                          int short_bytes, int long_bytes);
        string msg = make_pattern(29, 8'h70 + kind);
        string short_exp = keccak_ref_pkg::shake_hex(mode, msg, short_bytes);
        string long_exp = keccak_ref_pkg::shake_hex(mode, msg, long_bytes);
        send_item(.test_name($sformatf("DEEP PREFIX REF kind=%0d", kind)),
                  .mode(mode), .msg_hex(msg), .exp_hex(short_exp),
                  .output_len_bits(short_bytes * 8),
                  .xof_len_val(short_bytes),
                  .prefix_consistency_request(kind), .prefix_reference(1));
        send_item(.test_name($sformatf("DEEP PREFIX CHECK kind=%0d", kind)),
                  .mode(mode), .msg_hex(msg), .exp_hex(long_exp),
                  .output_len_bits(long_bytes * 8),
                  .xof_len_val(long_bytes),
                  .prefix_consistency_request(kind));
    endtask

    task send_byte_order_item(int case_index, string msg);
        keccak_mode mode = (case_index % 2) ? SHAKE128 : SHAKE256;
        string exp = keccak_ref_pkg::shake_hex(mode, msg, 32);
        send_item(.test_name($sformatf("DEEP BYTE ORDER case=%0d",
                                      case_index)),
                  .mode(mode), .msg_hex(msg), .exp_hex(exp),
                  .output_len_bits(256), .xof_len_val(32),
                  .byte_order_case(case_index),
                  .byte_order_case_count(16));
    endtask

    task body();
        send_back_to_back_item("baseline SHAKE128", SHAKE128, 0, 1);
        send_back_to_back_item("128 to 128", SHAKE128, 1, 0);
        send_back_to_back_item("128 to 256", SHAKE256, 2, 0);
        send_back_to_back_item("256 to 128", SHAKE128, 3, 0);
        send_back_to_back_item("128 to 256 setup", SHAKE256, 2, 0);
        send_back_to_back_item("256 to 256", SHAKE256, 4, 0);

        send_equivalence_pair(1, SHAKE128, 40);
        send_equivalence_pair(2, SHAKE256, 19);
        send_equivalence_pair(3, SHAKE128, 184);

        send_prefix_pair(1, SHAKE128, 16, 64);
        send_prefix_pair(2, SHAKE256, 128, 144);
        send_prefix_pair(3, SHAKE128, 176, 344);

        for (int bit_index = 0; bit_index < 8; bit_index++)
            send_byte_order_item(bit_index + 1,
                                 $sformatf("%02x", 1 << bit_index));

        for (int byte_index = 0; byte_index < 8; byte_index++) begin
            string msg = "";
            for (int i = 0; i < 8; i++)
                msg = {msg, (i == byte_index) ? "a5" : "00"};
            send_byte_order_item(byte_index + 9, msg);
        end
    endtask
endclass


// Target lane runs long enough for a peer reset, stall, or stop to overlap.
class keccak_lane_isolation_target_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_lane_isolation_target_seq)
    int isolation_kind;
    keccak_mode target_mode;

    function new(string name = "keccak_lane_isolation_target_seq");
        super.new(name);
    endfunction

    task body();
        string msg = "00112233445566778899aabbccddeeff1021324354657687";
        string exp = keccak_ref_pkg::shake_hex(target_mode, msg, 600);
        send_item(.test_name($sformatf("ISOLATION target kind=%0d %s",
                                      isolation_kind, target_mode.name())),
                  .mode(target_mode), .msg_hex(msg), .exp_hex(exp),
                  .output_len_bits(4800), .xof_len_val(600),
                  .lane_isolation_request(isolation_kind));
    endtask
endclass


// The peer transaction is also checked normally; only the target gets
// isolation credit after its golden output survives the disturbance.
class keccak_lane_isolation_peer_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_lane_isolation_peer_seq)
    int isolation_kind;
    keccak_mode peer_mode;

    function new(string name = "keccak_lane_isolation_peer_seq");
        super.new(name);
    endfunction

    task body();
        string msg = "ffeeddccbbaa99887766554433221100";
        string exp;
        case (isolation_kind)
            1: begin
                exp = keccak_ref_pkg::shake_hex(peer_mode, msg, 64);
                send_item(.test_name("ISOLATION peer reset"),
                          .mode(peer_mode), .msg_hex(msg), .exp_hex(exp),
                          .output_len_bits(512), .xof_len_val(64),
                          .reset_state_target(4));
            end
            2: begin
                exp = keccak_ref_pkg::shake_hex(peer_mode, msg, 600);
                send_item(.test_name("ISOLATION peer stall"),
                          .mode(peer_mode), .msg_hex(msg), .exp_hex(exp),
                          .output_len_bits(4800), .xof_len_val(600),
                          .output_stall_kind(2), .stall_position(1));
            end
            3: begin
                exp = keccak_ref_pkg::shake_hex(peer_mode, msg, 200);
                send_item(.test_name("ISOLATION peer stop"),
                          .mode(peer_mode), .msg_hex(msg), .exp_hex(exp),
                          .output_len_bits(1600), .xof_len_val(0));
            end
            default:
                `uvm_fatal(get_type_name(), "Invalid isolation kind")
        endcase
    endtask
endclass


// Four different messages run together and remain independently checked.
class keccak_mixed_lane_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_mixed_lane_seq)
    int lane_index;

    function new(string name = "keccak_mixed_lane_seq");
        super.new(name);
    endfunction

    task body();
        string msg = "";
        string exp;
        keccak_mode mode;
        int output_bytes;

        for (int i = 0; i < (24 + lane_index); i++)
            msg = {msg, $sformatf("%02x", (i * 19 + lane_index * 41) & 8'hff)};
        mode = (lane_index % 2 == 0) ? SHAKE128 : SHAKE256;
        output_bytes = 96 + lane_index * 8;
        exp = keccak_ref_pkg::shake_hex(mode, msg, output_bytes);
        send_item(.test_name($sformatf("MIXED lane=%0d %s",
                                      lane_index, mode.name())),
                  .mode(mode), .msg_hex(msg), .exp_hex(exp),
                  .output_len_bits(output_bytes * 8),
                  .xof_len_val(output_bytes),
                  .expected_active_lanes(4),
                  .mixed_lane_work_request(1));
    endtask
endclass


// Combined sequence: directed + random stress + closure + requirement
// boundaries + explicit protocol stress + reset recovery.
class keccak_full_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_full_seq)

    function new(string name = "keccak_full_seq");
        super.new(name);
    endfunction

    task body();
        keccak_directed_seq d_seq;
        keccak_stress_seq   s_seq;
        keccak_cov_seq      c_seq;
        keccak_boundary_seq b_seq;
        keccak_protocol_stress_seq p_seq;
        keccak_config_latch_seq config_seq;
        keccak_continuous_stop_seq  stop_seq;
        keccak_abort_seq abort_seq;
        keccak_deep_consistency_seq deep_seq;
        d_seq = keccak_directed_seq::type_id::create("d_seq");
        s_seq = keccak_stress_seq::type_id::create("s_seq");
        c_seq = keccak_cov_seq::type_id::create("c_seq");
        b_seq = keccak_boundary_seq::type_id::create("b_seq");
        p_seq = keccak_protocol_stress_seq::type_id::create("p_seq");
        config_seq = keccak_config_latch_seq::type_id::create(
            "config_seq");
        stop_seq = keccak_continuous_stop_seq::type_id::create("stop_seq");
        abort_seq = keccak_abort_seq::type_id::create("abort_seq");
        deep_seq = keccak_deep_consistency_seq::type_id::create("deep_seq");
        d_seq.start(m_sequencer);
        s_seq.start(m_sequencer);
        c_seq.start(m_sequencer);
        b_seq.start(m_sequencer);
        p_seq.start(m_sequencer);
        config_seq.start(m_sequencer);
        stop_seq.start(m_sequencer);
        abort_seq.start(m_sequencer);
        deep_seq.start(m_sequencer);
    endtask
endclass
