// =========================================================================
// keccak_sequence.sv  -  Directed and random sequences (TB v2)
// =========================================================================

// Base sequence: helper to push one directed item
class keccak_base_seq extends uvm_sequence #(keccak_transaction);
    `uvm_object_utils(keccak_base_seq)

    function new(string name = "keccak_base_seq");
        super.new(name);
    endfunction

    task send_item(string test_name, keccak_mode mode, string msg_hex,
                   string exp_hex, int output_len_bits, int xof_len_val);
        keccak_transaction tx;
        tx = keccak_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name        = test_name;
        tx.mode             = mode;
        tx.msg_hex          = msg_hex;
        tx.exp_hex          = exp_hex;
        tx.output_len_bits  = output_len_bits;
        tx.xof_len_val      = xof_len_val;
        finish_item(tx);
    endtask
endclass


// Full NIST directed test suite (SHA3-256, SHA3-512, SHAKE128, SHAKE256)
// For SHAKE: each vector runs once as Continuous (xof_len=0) and once as Bounded
class keccak_directed_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_directed_seq)

    function new(string name = "keccak_directed_seq");
        super.new(name);
    endfunction

    task body();
        // -------------------- SHA3-256 (rate 136) --------------------
        send_item("SHA3-256 Empty",      SHA3_256, "",
                  "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", 256, 0);

        send_item("SHA3-256 Short",      SHA3_256, "616263",
                  "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", 256, 0);

        send_item("SHA3-256 Full Rate",  SHA3_256,
                  "56ea14d7fcb0db748ff649aaa5d0afdc2357528a9aad6076d73b2805b53d89e73681abfad26bee6c0f3d20215295f354f538ae80990d2281be6de0f6919aa9eb048c26b524f4d91ca87b54c0c54aa9b54ad02171e8bf31e8d158a9f586e92ffce994ecce9a5185cc80364d50a6f7b94849a914242fcb73f33a86ecc83c3403630d20650ddb8cd9c4",
                  "4beae3515ba35ec8cbd1d94567e22b0d7809c466abfbafe9610349597ba15b45", 256, 0);

        send_item("SHA3-256 Long",       SHA3_256,
                  "b1caa396771a09a1db9bc20543e988e359d47c2a616417bbca1b62cb02796a888fc6eeff5c0b5c3d5062fcb4256f6ae1782f492c1cf03610b4a1fb7b814c057878e1190b9835425c7a4a0e182ad1f91535ed2a35033a5d8c670e21c575ff43c194a58a82d4a1a44881dd61f9f8161fc6b998860cbe4975780be93b6f87980bad0a99aa2cb7556b478ca35d1f3746c33e2bb7c47af426641cc7bbb3425e2144820345e1d0ea5b7da2c3236a52906acdc3b4d34e474dd714c0c40bf006a3a1d889a632983814bbc4a14fe5f159aa89249e7c738b3b73666bac2a615a83fd21ae0a1ce7352ade7b278b587158fd2fabb217aa1fe31d0bda53272045598015a8ae4d8cec226fefa58daa05500906c4d85e7567",
                  "cb5648a1d61c6c5bdacd96f81c9591debc3950dcf658145b8d996570ba881a05", 256, 0);

        // -------------------- SHA3-512 (rate 72) ---------------------
        send_item("SHA3-512 Empty",      SHA3_512, "",
                  "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26", 512, 0);

        send_item("SHA3-512 Short",      SHA3_512, "54746a7ba28b5f263d2496bd0080d83520cd2dc503",
                  "d77048df60e20d03d336bfa634bc9931c2d3c1e1065d3a07f14ae01a085fe7e7fe6a89dc4c7880f1038938aa8fcd99d2a782d1bbe5eec790858173c7830c87a2", 512, 0);

        send_item("SHA3-512 Long",       SHA3_512,
                  "22e1df25c30d6e7806cae35cd4317e5f94db028741a76838bfb7d5576fbccab001749a95897122c8d51bb49cfef854563e2b27d9013b28833f161d520856ca4b61c2641c4e184800300aede3518617c7be3a4e6655588f181e9641f8df7a6a42ead423003a8c4ae6be9d767af5623078bb116074638505c10540299219b0155f45b1c18a74548e4328de37a911140531deb6434c534af2449c1abe67e18030681a61240225f87ede15d519b7ce2500bccf33e1364e2fbe6a8a2fe6c15d73242610ed36b0740080812e8902ee531c88e0359020797cbdd1fb78848ae6b5105961d05cdddb8af5fef21b02db94c9810464b8d3ea5f047b94bf0d23931f12df37e102b603cd8e5f5ffa83488df257ddde110106262e0ef16d7ef213e7b49c69276d4d048f",
                  "a6375ff04af0a18fb4c8175f671181b4cf79653a3d70847c6d99694b3f5d41601f1dbef809675c63cac4ec83153b1c78131a7b61024ce36244f320ab8740cb7e", 512, 0);

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


// Random/stress sequence: drives many random items through all 4 modes,
// random message lengths and random bounded xof_len. The scoreboard cannot
// check correctness without a software reference, so these are run for
// coverage closure (toggles, branches, FSM transitions). The scoreboard
// will be told to skip comparison via test_name prefix "[NOCHK]".
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

        for (int i = 0; i < num_items; i++) begin
            // Randomize mode (round-robin to ensure all modes are covered)
            case (i % 4)
                0: m = SHAKE128;
                1: m = SHAKE256;
                2: m = SHA3_256;
                3: m = SHA3_512;
            endcase
            // Mix of small / rate-boundary / multi-block lengths
            case (i % 5)
                0: msg_byte_len = 0;
                1: msg_byte_len = $urandom_range(1, 71);
                2: msg_byte_len = $urandom_range(72, 167);
                3: msg_byte_len = $urandom_range(168, 271);
                4: msg_byte_len = $urandom_range(272, 600);
            endcase
            // Random xof_len for SHAKE modes (mix of bounded sizes)
            if (m == SHAKE128 || m == SHAKE256) begin
                if (i % 2 == 0) xof_bytes = 0;
                else            xof_bytes = $urandom_range(8, 400);
            end else begin
                xof_bytes = 0;
            end

            msg_hex = "";
            for (int j = 0; j < msg_byte_len; j++) begin
                b = $urandom_range(0, 255);
                msg_hex = {msg_hex, $sformatf("%02x", b)};
            end

            tn = $sformatf("[NOCHK] STRESS_%0d %s msglen=%0d xof_len=%0d",
                           i, m.name(), msg_byte_len, xof_bytes);

            // For NOCHK items we just need *some* expected output length so the
            // monitor knows how many bytes to collect. Use:
            //   SHA3-256 -> 32, SHA3-512 -> 64
            //   SHAKE bounded -> xof_bytes, SHAKE continuous -> 32 (arbitrary)
            begin
                int out_bits;
                case (m)
                    SHA3_256: out_bits = 256;
                    SHA3_512: out_bits = 512;
                    SHAKE128, SHAKE256: out_bits = (xof_bytes > 0) ? (xof_bytes * 8) : 256;
                endcase
                send_item(tn, m, msg_hex, "", out_bits, xof_bytes);
            end
        end
    endtask
endclass


// Abort sequence: covers FSM reset transitions from active states
// (ABSORB->IDLE, SUFFIX_PADDING->IDLE, PERMUTE->IDLE).
class keccak_abort_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_abort_seq)

    function new(string name = "keccak_abort_seq");
        super.new(name);
    endfunction

    task send_abort(string test_name, keccak_mode mode, string msg_hex,
                    int abort_after);
        keccak_transaction tx;
        tx = keccak_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name          = test_name;
        tx.mode               = mode;
        tx.msg_hex            = msg_hex;
        tx.exp_hex            = "";
        tx.output_len_bits    = 0;
        tx.xof_len_val        = 0;
        tx.abort_after_cycles = abort_after;
        finish_item(tx);
    endtask

    task body();
        // Long msg so we have something to drive partial beats from.
        string long_msg;
        long_msg = "";
        for (int i = 0; i < 100; i++) long_msg = {long_msg, "ab"};

        // ABSORB-state abort: drive 3 partial beats then reset
        send_abort("ABORT in ABSORB (3 beats)",  SHAKE128, long_msg, 3);

        // ABSORB-state abort: drive 8 partial beats then reset
        send_abort("ABORT in ABSORB (8 beats)",  SHA3_256, long_msg, 8);

        // PERMUTE-state abort: short msg (tlast=1) so DUT goes through
        // ABSORB(1)->SUFFIX_PADDING(1)->PERMUTE(24). Reset at PERMUTE+2
        // (abort_after_cycles=102 = 100 marker + 2 extra cycles).
        send_abort("ABORT in PERMUTE (early)",   SHAKE128, "616263",  102);

        // PERMUTE-state abort, later in the 24-cycle permutation
        send_abort("ABORT in PERMUTE (mid)",     SHA3_512, "616263",  112);

        // Reset right at SUFFIX_PADDING boundary (1-cycle window: hits either
        // SUFFIX_PADDING or PERMUTE depending on exact timing)
        send_abort("ABORT in SUFFIX_PADDING",    SHA3_512, "616263",  100);
    endtask
endclass


// Coverage-closure sequence: deterministically hits every cp_msg_len bin
// for every mode (24 cross bins) AND every cp_xof_kind bin for every SHAKE
// mode (8 cross bins). Each item is marked [NOCHK] (scoreboard skips data
// compare; this sequence is only for coverage closure).
class keccak_cov_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_cov_seq)

    function new(string name = "keccak_cov_seq");
        super.new(name);
    endfunction

    // Build a random hex string of N bytes
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
        msg = make_msg(n_bytes);
        case (m)
            SHA3_256: out_bits = 256;
            SHA3_512: out_bits = 512;
            SHAKE128, SHAKE256: out_bits = (xof_bytes > 0) ? (xof_bytes * 8) : 256;
        endcase
        send_item({"[NOCHK] COV ", label}, m, msg, "", out_bits, xof_bytes);
    endtask

    task body();
        keccak_mode modes [$] = '{SHAKE128, SHAKE256, SHA3_256, SHA3_512};

        // --- cross_mode_msg coverage: 4 modes x 6 msg_len bins = 24 bins ---
        // msg_len bins: empty(0), short(1-71), around_576(72-135),
        //               around_1088(136-167), around_1344(168-271),
        //               multi_block(272+)
        foreach (modes[i]) begin
            send_cov_item($sformatf("%s msglen=0",   modes[i].name()), modes[i],   0, 0);
            send_cov_item($sformatf("%s msglen=40",  modes[i].name()), modes[i],  40, 0);
            send_cov_item($sformatf("%s msglen=100", modes[i].name()), modes[i], 100, 0);
            send_cov_item($sformatf("%s msglen=150", modes[i].name()), modes[i], 150, 0);
            send_cov_item($sformatf("%s msglen=200", modes[i].name()), modes[i], 200, 0);
            send_cov_item($sformatf("%s msglen=300", modes[i].name()), modes[i], 300, 0);
        end

        // --- cross_shake_xof coverage: each SHAKE mode x 4 xof_kind bins ---
        // (SHA3 modes are auto-ignored by ignore_bins in the cg.)
        // xof_kind bins: continuous(0), small(1-32), medium(33-168), large(169+)
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


// Combined sequence: directed + stress + coverage closure
// (abort sequence currently disabled — see keccak_abort_seq comment).
class keccak_full_seq extends keccak_base_seq;
    `uvm_object_utils(keccak_full_seq)

    function new(string name = "keccak_full_seq");
        super.new(name);
    endfunction

    task body();
        keccak_directed_seq d_seq;
        keccak_stress_seq   s_seq;
        keccak_cov_seq      c_seq;
        d_seq = keccak_directed_seq::type_id::create("d_seq");
        s_seq = keccak_stress_seq::type_id::create("s_seq");
        c_seq = keccak_cov_seq::type_id::create("c_seq");
        d_seq.start(m_sequencer);
        s_seq.start(m_sequencer);
        c_seq.start(m_sequencer);
    endtask
endclass
