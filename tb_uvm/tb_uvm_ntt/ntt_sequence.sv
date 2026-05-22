// ============================================================================
// ntt_sequence.sv  --  Directed, stress and coverage-closure sequences
// ----------------------------------------------------------------------------
// Every item's exp_poly is computed at sequence time by the pure-SV golden
// model in ntt_ref_pkg (ntt_fwd / ntt_inv) -- so the scoreboard golden-compares
// every transaction end-to-end; there is no skip path.
// ============================================================================

// Base sequence: helper to build + send one transform item.
class ntt_base_seq extends uvm_sequence #(ntt_transaction);
    `uvm_object_utils(ntt_base_seq)

    function new(string name = "ntt_base_seq");
        super.new(name);
    endfunction

    task send_item(string nm, ntt_op_e o, in_kind_e ik, poly_t pin);
        ntt_transaction tx;
        tx = ntt_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name = nm;
        tx.op        = o;
        tx.in_kind   = ik;
        tx.in_poly   = pin;
        tx.exp_poly  = (o == OP_NTT) ? ntt_fwd(pin) : ntt_inv(pin);
        finish_item(tx);
    endtask

    // ---- stimulus builders ----
    function automatic poly_t make_const(coeff_t v);
        poly_t p;
        for (int i = 0; i < N; i++) p[i] = v;
        return p;
    endfunction

    function automatic poly_t make_delta();
        poly_t p;
        for (int i = 0; i < N; i++) p[i] = coeff_t'(0);
        p[0] = coeff_t'(1);
        return p;
    endfunction

    function automatic poly_t make_random();
        poly_t p;
        for (int i = 0; i < N; i++) p[i] = coeff_t'($urandom % Q);
        return p;
    endfunction
endclass


// Directed: deterministic edge-case polynomials.
class ntt_directed_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_directed_seq)

    function new(string name = "ntt_directed_seq");
        super.new(name);
    endfunction

    task body();
        poly_t zero  = make_const(coeff_t'(0));
        poly_t maxv  = make_const(coeff_t'(Q-1));
        poly_t delta = make_delta();

        send_item("DIR all-zero NTT",      OP_NTT,  IK_ZERO,  zero);
        send_item("DIR all-zero INTT",     OP_INTT, IK_ZERO,  zero);
        send_item("DIR all-(q-1) NTT",     OP_NTT,  IK_MAX,   maxv);
        send_item("DIR all-(q-1) INTT",    OP_INTT, IK_MAX,   maxv);
        send_item("DIR delta@0 NTT",       OP_NTT,  IK_DELTA, delta);
        send_item("DIR delta@0 INTT",      OP_INTT, IK_DELTA, delta);
    endtask
endclass


// Stress: random polynomials through both transforms, plus a round-trip leg
// (INTT of the golden forward NTT -- exp_poly then equals the original input).
class ntt_stress_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_stress_seq)

    int num_items = 8;

    function new(string name = "ntt_stress_seq");
        super.new(name);
    endfunction

    task body();
        poly_t p;
        for (int i = 0; i < num_items; i++) begin
            p = make_random();
            send_item($sformatf("STRESS %0d NTT",   i), OP_NTT,  IK_RANDOM, p);
            send_item($sformatf("STRESS %0d INTT",  i), OP_INTT, IK_RANDOM, p);
            // round-trip: feed the golden forward transform back through INTT.
            // exp_poly = ntt_inv(ntt_fwd(p)) == p.
            send_item($sformatf("STRESS %0d round", i), OP_INTT, IK_RANDOM,
                      ntt_fwd(p));
        end
    endtask
endclass


// Coverage closure: deterministically hits every (op x in_kind) cross bin.
class ntt_cov_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_cov_seq)

    function new(string name = "ntt_cov_seq");
        super.new(name);
    endfunction

    task body();
        ntt_op_e ops [2] = '{OP_NTT, OP_INTT};
        foreach (ops[i]) begin
            send_item($sformatf("COV %s zero",   ops[i].name()),
                      ops[i], IK_ZERO,   make_const(coeff_t'(0)));
            send_item($sformatf("COV %s max",    ops[i].name()),
                      ops[i], IK_MAX,    make_const(coeff_t'(Q-1)));
            send_item($sformatf("COV %s delta",  ops[i].name()),
                      ops[i], IK_DELTA,  make_delta());
            send_item($sformatf("COV %s random", ops[i].name()),
                      ops[i], IK_RANDOM, make_random());
        end
    endtask
endclass


// Combined regression: directed + stress + coverage closure.
class ntt_full_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_full_seq)

    function new(string name = "ntt_full_seq");
        super.new(name);
    endfunction

    task body();
        ntt_directed_seq d_seq;
        ntt_stress_seq   s_seq;
        ntt_cov_seq      c_seq;
        d_seq = ntt_directed_seq::type_id::create("d_seq");
        s_seq = ntt_stress_seq  ::type_id::create("s_seq");
        c_seq = ntt_cov_seq     ::type_id::create("c_seq");
        d_seq.start(m_sequencer);
        s_seq.start(m_sequencer);
        c_seq.start(m_sequencer);
    endtask
endclass
