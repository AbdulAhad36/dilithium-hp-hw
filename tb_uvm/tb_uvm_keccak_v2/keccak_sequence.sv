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


// Abort sequence: covers FSM reset transitions from active states
// (ABSORB->IDLE, SUFFIX_PADDING->IDLE, PERMUTE->IDLE).
// Currently disabled (driver.drive_abort race causes deadlock).
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
        string long_msg;
        long_msg = "";
        for (int i = 0; i < 100; i++) long_msg = {long_msg, "ab"};

        send_abort("ABORT in ABSORB (3 beats)",  SHAKE128, long_msg, 3);
        send_abort("ABORT in ABSORB (8 beats)",  SHAKE256, long_msg, 8);
        send_abort("ABORT in PERMUTE (early)",   SHAKE128, "616263",  102);
        send_abort("ABORT in PERMUTE (mid)",     SHAKE256, "616263",  112);
        send_abort("ABORT in SUFFIX_PADDING",    SHAKE256, "616263",  100);
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


// Combined sequence: directed + stress + coverage closure
// (abort sequence currently disabled - see keccak_abort_seq comment).
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
