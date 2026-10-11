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

    task send_item(string nm, ntt_op_e o, in_kind_e ik, poly_t pin,
                   bit reset_before = 1'b1, int input_gap_period=0, bit stall_output=0,
                   int equivalence_pair=-1, bit equivalence_second=0);
        ntt_transaction tx;
        tx = ntt_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name = nm;
        tx.op        = o;
        tx.in_kind   = ik;
        tx.in_poly   = pin;
        tx.reset_before = reset_before;
        tx.input_gap_period = input_gap_period;
        tx.stall_output = stall_output;
        tx.equivalence_pair=equivalence_pair;
        tx.equivalence_second=equivalence_second;
        tx.exp_poly  = (o == OP_INTT) ? ntt_inv(pin) : ntt_fwd(pin);
        finish_item(tx);
    endtask

    // PWM-specific item: two operand polynomials, exp = pointwise A o B.
    task send_pwm(string nm, in_kind_e ik, poly_t pa, poly_t pb,
                  bit reset_before = 1'b1, int input_gap_period=0, bit stall_output=0,
                   int equivalence_pair=-1, bit equivalence_second=0);
        ntt_transaction tx;
        tx = ntt_transaction::type_id::create("tx");
        start_item(tx);
        tx.test_name = nm;
        tx.op        = OP_PWM;
        tx.in_kind   = ik;
        tx.in_poly   = pa;
        tx.in_poly_b = pb;
        tx.reset_before = reset_before;
        tx.input_gap_period = input_gap_period;
        tx.stall_output = stall_output;
        tx.equivalence_pair=equivalence_pair;
        tx.equivalence_second=equivalence_second;
        tx.exp_poly  = pwm(pa, pb);
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
        // PWM directed: zero, max, delta, identity.
        send_pwm("DIR PWM zero o zero",    IK_ZERO,  zero,  zero);
        send_pwm("DIR PWM max  o max",     IK_MAX,   maxv,  maxv);
        send_pwm("DIR PWM delta o delta",  IK_DELTA, delta, delta);
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
        poly_t p, q;
        for (int i = 0; i < num_items; i++) begin
            p = make_random();
            q = make_random();
            send_item($sformatf("STRESS %0d NTT",   i), OP_NTT,  IK_RANDOM, p);
            send_item($sformatf("STRESS %0d INTT",  i), OP_INTT, IK_RANDOM, p);
            // round-trip: feed the golden forward transform back through INTT.
            // exp_poly = ntt_inv(ntt_fwd(p)) == p.
            send_item($sformatf("STRESS %0d round", i), OP_INTT, IK_RANDOM,
                      ntt_fwd(p));
            send_pwm ($sformatf("STRESS %0d PWM",   i), IK_RANDOM, p, q);
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
        // PWM coverage closure: 4 in_kinds.
        send_pwm("COV PWM zero",   IK_ZERO,   make_const(coeff_t'(0)),
                                              make_const(coeff_t'(0)));
        send_pwm("COV PWM max",    IK_MAX,    make_const(coeff_t'(Q-1)),
                                              make_const(coeff_t'(Q-1)));
        send_pwm("COV PWM delta",  IK_DELTA,  make_delta(), make_delta());
        send_pwm("COV PWM random", IK_RANDOM, make_random(), make_random());
    endtask
endclass


`ifdef NTT_FIFO
// Candidate-only bounded-secret checks. The ordinary UVM build never names
// OP_PRE_NTT, which is not present in the saved four-bank package.
class ntt_pre_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_pre_seq)

    function new(string name = "ntt_pre_seq");
        super.new(name);
    endfunction

    function automatic coeff_t residue(int signed v);
        return coeff_t'((v < 0) ? (Q + v) : v);
    endfunction

    task body();
        poly_t p;
        for (int signed v = -4; v <= 4; v++) begin
            for (int i = 0; i < N; i++) p[i] = residue(v);
            send_item($sformatf("PRE uniform %0d", v), OP_PRE_NTT,
                      IK_PRE_BOUNDARY, p);
        end
        for (int i = 0; i < N; i++) p[i] = residue((i % 5) - 2);
        send_item("PRE eta2 mixed", OP_PRE_NTT, IK_ETA2, p);
        for (int i = 0; i < N; i++) p[i] = residue((i % 9) - 4);
        send_item("PRE eta4 mixed", OP_PRE_NTT, IK_ETA4, p);
        for (int i = 0; i < N; i++) p[i] = residue(0);
        p[0] = residue(-4);
        send_item("PRE negative at first", OP_PRE_NTT, IK_PRE_BOUNDARY, p);
        p[0] = residue(0);
        p[N-1] = residue(4);
        send_item("PRE positive at last", OP_PRE_NTT, IK_PRE_BOUNDARY, p);
    endtask
endclass
`endif

`ifdef NTT_FIFO
// Change operation on consecutive completed jobs without resetting the DUT.
class ntt_repeat_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_repeat_seq)

    function new(string name = "ntt_repeat_seq");
        super.new(name);
    endfunction

    task body();
        poly_t secret;
        send_item("REPEAT NTT no reset", OP_NTT, IK_RANDOM, make_random(), 0);
        send_item("REPEAT INTT no reset", OP_INTT, IK_RANDOM, make_random(), 0);
        send_pwm("REPEAT PWM no reset", IK_RANDOM, make_random(),
                 make_random(), 0);
        for (int i = 0; i < N; i++)
            secret[i] = coeff_t'((i % 9) - 4 + Q) % Q;
        send_item("REPEAT PRE no reset", OP_PRE_NTT, IK_ETA4, secret, 0);
    endtask
endclass
`endif


`ifdef NTT_FIFO
// Exercise source gaps and stalled first/middle/last output on every operation.
class ntt_flow_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_flow_seq)
    function new(string name="ntt_flow_seq"); super.new(name); endfunction
    task body();
        poly_t secret;
        send_item("FLOW NTT gaps/stalls", OP_NTT, IK_RANDOM, make_random(), 1,13,1);
        send_item("FLOW INTT gaps/stalls", OP_INTT, IK_RANDOM, make_random(), 1,13,1);
        send_pwm("FLOW PWM gaps/stalls", IK_RANDOM, make_random(), make_random(), 1,13,1);
        for (int i=0; i<N; i++) secret[i]=coeff_t'((i%9)-4+Q)%Q;
        send_item("FLOW PRE gaps/stalls", OP_PRE_NTT, IK_ETA4, secret, 1,13,1);
    endtask
endclass
`endif

// Each item cancels one earlier job and checks a different fresh polynomial.
class ntt_reset_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_reset_seq)
    function new(string name="ntt_reset_seq"); super.new(name); endfunction
    task body();
        string labels[9]='{"idle","input load","compute","stalled output",
                            "run start","PWM B load","output prefetch",
                            "Pre drain","pipeline drain"};
        for (int point=0; point<9; point++) begin
            ntt_transaction tx;
            tx=ntt_transaction::type_id::create("tx");
            start_item(tx);
            tx.test_name={"RESET recovery after ",labels[point]};
            tx.op=OP_NTT; tx.in_kind=IK_RANDOM; tx.reset_before=0;
            tx.reset_point=point;
            tx.abort_poly=make_random();
            for (int i=0; i<N; i++) tx.in_poly[i]=coeff_t'((i*12345+point+1)%Q);
            tx.exp_poly=ntt_fwd(tx.in_poly);
            finish_item(tx);
        end
    endtask
endclass

// Paired bounded-random jobs: compare real Pre output with real general NTT
// output in addition to comparing both independently against the golden model.
class ntt_pre_equivalence_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_pre_equivalence_seq)
    function new(string name="ntt_pre_equivalence_seq"); super.new(name); endfunction
    task body();
        for (int pair_id=0; pair_id<16; pair_id++) begin
            poly_t secret;
            int eta;
            in_kind_e kind;
            eta=(pair_id<8) ? 2 : 4;
            kind=(eta==2) ? IK_ETA2 : IK_ETA4;
            for (int i=0; i<N; i++) begin
                int value;
                value=int'($urandom%(2*eta+1))-eta;
                secret[i]=coeff_t'((value<0) ? Q+value : value);
            end
            send_item($sformatf("EQUIV %0d eta%0d general",pair_id,eta),OP_NTT,kind,secret,0,0,0,pair_id,0);
            send_item($sformatf("EQUIV %0d eta%0d Pre",pair_id,eta),OP_PRE_NTT,kind,secret,0,0,0,pair_id,1);
        end
    endtask
endclass

// Force CT sum boundaries and subtraction extrema at first-stage pairs (i,i+128).
// b is chosen independently with the reference inverse twiddle so b*zeta=t.
class ntt_arithmetic_boundary_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_arithmetic_boundary_seq)
    function new(string name="ntt_arithmetic_boundary_seq"); super.new(name); endfunction
    task body();
        poly_t p;
        coeff_t inverse_twiddle;
        int unsigned a_values[10]='{0,Q-2,Q-1,Q-1,Q-1,1,1,1,0,Q-1};
        int unsigned t_values[10]='{0,1,1,2,Q-1,0,1,2,Q-1,0};
        p=make_random();
        inverse_twiddle=powm(tw(1),Q-2);
        for (int i=0;i<10;i++) begin
            p[i]=coeff_t'(a_values[i]);
            p[i+128]=mulm(coeff_t'(t_values[i]),inverse_twiddle);
        end
        send_item("ARITH CT addition/subtraction boundaries",OP_NTT,IK_RANDOM,p);
    endtask
endclass

// Real product/carry boundary operands, also used in the collapsed-stage trial.
// Proposed collapsed T reaches 2*q+1; the retained fold design must match too.
// Expected coefficients still come from the independent pure-SV pwm() model.
class ntt_reduction_boundary_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_reduction_boundary_seq)
    function new(string name="ntt_reduction_boundary_seq"); super.new(name); endfunction
    task body();
        poly_t pa, pb;
        pa=make_random(); pb=make_random();
        // Repeat each pair across all four physical multiplier lanes.
        for (int lane=0;lane<4;lane++) begin
            pa[lane]=coeff_t'(0); pb[lane]=coeff_t'(0);
            pa[4+lane]=coeff_t'(Q-1); pb[4+lane]=coeff_t'(Q-1);
            pa[8+lane]=coeff_t'(4643571); pb[8+lane]=coeff_t'(5678082);
            // Collapsed trial: T=2*q+10000 leaves stage3 above 2^23.
            pa[12+lane]=coeff_t'(7083480); pb[12+lane]=coeff_t'(6206081);
            // Collapsed trial: T=2*q+30000 also exercises raw T bit 24.
            pa[16+lane]=coeff_t'(6777144); pb[16+lane]=coeff_t'(6489384);
        end
        send_pwm("REDUCE product/carry boundaries",IK_RANDOM,pa,pb);
    endtask
endclass

// Force all inverse GS raw-sum thresholds on every physical butterfly lane.
// INTT stage0 pairs adjacent coefficients; repeat each pair over four lanes.
class ntt_inverse_sum_boundary_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_inverse_sum_boundary_seq)
    function new(string name="ntt_inverse_sum_boundary_seq"); super.new(name); endfunction
    task body();
        poly_t p;
        int unsigned av[5]='{0,0,1,2,Q-1};
        int unsigned bv[5]='{0,Q-1,Q-1,Q-1,Q-1};
        p=make_random();
        for (int c=0;c<5;c++)
            for (int lane=0;lane<4;lane++) begin
                p[8*c+2*lane]=coeff_t'(av[c]);
                p[8*c+2*lane+1]=coeff_t'(bv[c]);
            end
        send_item("ARITH GS sum/carry boundaries",OP_INTT,IK_RANDOM,p);
    endtask
endclass

// Combined regression: directed + stress + coverage closure.
// Broad regression with reproducible independent flow profiles, not bin chasing.
class ntt_extended_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_extended_seq)
    int unsigned rng=32'h1a2b3c4d;
    function new(string name="ntt_extended_seq");super.new(name);endfunction
    function int unsigned next_random();
        rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;
    endfunction
    function int duration(int category);
        case(category)
            0:return 0;1:return 1;2:return 2;
            3:return 3+next_random()%5;
            4:return 8+next_random()%8;
            default:return 16+next_random()%48;
        endcase
    endfunction
    function poly_t pattern(int shape,bit bounded);
        poly_t p;
        coeff_t secrets[9]='{0,1,2,3,4,Q-4,Q-3,Q-2,Q-1};
        for(int i=0;i<N;i++) begin
            case(shape)
                0:p[i]=0;
                1:p[i]=Q-1;
                2:p[i]=(i==0)?1:0;
                3:p[i]=(i%2)?Q-1:1;
                4:p[i]=bounded?secrets[(i*9)/N]:coeff_t'(i*30000);
                5:p[i]=bounded?secrets[((N-1-i)*9)/N]:coeff_t'((N-1-i)*30000);
                6:p[i]=coeff_t'((i%5+Q-2)%Q);
                default:p[i]=bounded?secrets[next_random()%9]:coeff_t'(next_random()%Q);
            endcase
        end
        if(shape==7 && bounded) begin p[0]=3;p[1]=Q-4;p[2]=1;end
        return p;
    endfunction
    task job(string name,ntt_op_e operation,poly_t a,poly_t b,bit do_reset,
             int gap=0,int stall=0,int stride=0);
        ntt_transaction tx=ntt_transaction::type_id::create("extended_tx");
        start_item(tx);
        tx.test_name=name;tx.op=operation;tx.in_kind=(operation==OP_PRE_NTT)?IK_ETA4:IK_RANDOM;
        tx.in_poly=a;tx.in_poly_b=b;tx.reset_before=do_reset;
        tx.input_gap_period=(gap>0)?13:0;tx.input_gap_cycles=gap;
        tx.pwm_boundary_gap_cycles=gap;
        tx.stall_output=(stall>0);tx.output_stall_cycles=stall;tx.output_stall_period=stride;
        tx.exp_poly=(operation==OP_PWM)?pwm(a,b):((operation==OP_INTT)?ntt_inv(a):ntt_fwd(a));
        finish_item(tx);
    endtask
    task body();
        ntt_op_e ops[4]='{OP_NTT,OP_INTT,OP_PWM,OP_PRE_NTT};
        coeff_t representatives[8]='{0,1,3,2048,100000,Q/2+100,Q-3,Q-1};
        poly_t a,b,target;
        void'($value$plusargs("NTT_EXT_SEED=%d",rng));
        if(rng==0) `uvm_fatal("EXT_SEED","Nonzero xorshift seed required")
        `uvm_info("EXT_SEED",$sformatf("502 additional jobs, flow RNG seed=%0d",rng),UVM_NONE)
        // 32 actual input shapes, across all four modes.
        for(int mode=0;mode<4;mode++) for(int shape=0;shape<8;shape++)
            job($sformatf("EXT SHAPE mode%0d shape%0d",mode,shape),ops[mode],
                pattern(shape,ops[mode]==OP_PRE_NTT),pattern(7,0),1);
        // Three prescribed result polynomials, each with all eight value ranges.
        for(int i=0;i<N;i++)target[i]=representatives[i%8];
        job("EXT OUTPUT ranges NTT",OP_NTT,ntt_inv(target),pattern(0,0),1);
        job("EXT OUTPUT ranges INTT",OP_INTT,ntt_fwd(target),pattern(0,0),1);
        job("EXT OUTPUT ranges PWM",OP_PWM,target,make_const(coeff_t'(1)),1);
        // Bounded impulses make exact bounded positive/negative Pre outputs.
        a=make_const(coeff_t'(0));a[0]=2;
        job("EXT OUTPUT Pre positive",OP_PRE_NTT,a,pattern(0,0),1);
        a[0]=Q-2;
        job("EXT OUTPUT Pre negative",OP_PRE_NTT,a,pattern(0,0),1);
        // All 8*8 A/B range combinations on every one of four lanes.
        for(int x=0;x<8;x++)for(int y=0;y<8;y++)for(int lane=0;lane<4;lane++)begin
            a[(x*8+y)*4+lane]=representatives[x];
            b[(x*8+y)*4+lane]=representatives[y];
        end
        job("EXT PWM range Cartesian",OP_PWM,a,b,1);
        // 400 flow jobs: profile classes selected independently, without querying coverage.
        for(int test_id=0;test_id<400;test_id++)begin
            int mode,gap,stall,stride;
            bit reset_job;
            mode=test_id%4;gap=duration(next_random()%6);stall=duration(next_random()%6);
            stride=(next_random()%2)?17:0;reset_job=next_random()%2;
            a=pattern(7,ops[mode]==OP_PRE_NTT);b=pattern(7,0);
            job($sformatf("EXT FLOW %0d mode%0d gap%0d stall%0d",test_id,mode,gap,stall),
                ops[mode],a,b,reset_job,gap,stall,stride);
        end
        // 32 transitions (4*4*2), two golden-checked jobs per transition.
        for(int prior=0;prior<4;prior++)for(int current=0;current<4;current++)
            for(int reset_bit=0;reset_bit<2;reset_bit++)begin
                job($sformatf("EXT TRANSITION prepare %0d",prior),ops[prior],
                    pattern(7,ops[prior]==OP_PRE_NTT),pattern(7,0),1);
                job($sformatf("EXT TRANSITION %0d to%0d reset%0d",prior,current,reset_bit),ops[current],
                    pattern(7,ops[current]==OP_PRE_NTT),pattern(7,0),bit'(reset_bit));
            end
    endtask
endclass

class ntt_full_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_full_seq)

    function new(string name = "ntt_full_seq");
        super.new(name);
    endfunction

    task body();
        ntt_directed_seq d_seq;
        ntt_stress_seq   s_seq;
        ntt_cov_seq      c_seq;
        ntt_reset_seq    reset_seq;
        ntt_pre_equivalence_seq equiv_seq;
        ntt_arithmetic_boundary_seq arithmetic_seq;
        ntt_reduction_boundary_seq reduction_seq;
        ntt_inverse_sum_boundary_seq inverse_sum_seq;
        ntt_extended_seq extended_seq;
`ifdef NTT_FIFO
        ntt_pre_seq      p_seq;
        ntt_repeat_seq   r_seq;
        ntt_flow_seq     f_seq;
`endif
        d_seq = ntt_directed_seq::type_id::create("d_seq");
        s_seq = ntt_stress_seq  ::type_id::create("s_seq");
        c_seq = ntt_cov_seq     ::type_id::create("c_seq");
`ifdef NTT_FIFO
        p_seq = ntt_pre_seq     ::type_id::create("p_seq");
        r_seq = ntt_repeat_seq  ::type_id::create("r_seq");
        f_seq = ntt_flow_seq    ::type_id::create("f_seq");
`endif
        reset_seq = ntt_reset_seq::type_id::create("reset_seq");
        equiv_seq = ntt_pre_equivalence_seq::type_id::create("equiv_seq");
        d_seq.start(m_sequencer);
        s_seq.start(m_sequencer);
        c_seq.start(m_sequencer);
`ifdef NTT_FIFO
        p_seq.start(m_sequencer);
        r_seq.start(m_sequencer);
        f_seq.start(m_sequencer);
        reset_seq.start(m_sequencer);
        equiv_seq.start(m_sequencer);
        arithmetic_seq=ntt_arithmetic_boundary_seq::type_id::create("arithmetic_seq");
        arithmetic_seq.start(m_sequencer);
        reduction_seq=ntt_reduction_boundary_seq::type_id::create("reduction_seq");
        reduction_seq.start(m_sequencer);
        inverse_sum_seq=ntt_inverse_sum_boundary_seq::type_id::create("inverse_sum_seq");
        inverse_sum_seq.start(m_sequencer);
        extended_seq=ntt_extended_seq::type_id::create("extended_seq");
        extended_seq.start(m_sequencer);
`endif
    endtask
endclass
