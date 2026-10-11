// ============================================================================
// ntt_tests.sv  --  UVM tests for ntt_engine
// ----------------------------------------------------------------------------
//   ntt_directed_test : the 6 directed edge-case transforms only
//   ntt_full_test     : directed + random stress + coverage closure (default)
// ============================================================================
class ntt_base_test extends uvm_test;
    `uvm_component_utils(ntt_base_test)

    ntt_env env;

    function new(string name = "ntt_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ntt_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass


// Directed only.
class ntt_directed_test extends ntt_base_test;
    `uvm_component_utils(ntt_directed_test)

    function new(string name = "ntt_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ntt_directed_seq seq;
        phase.raise_objection(this);
        seq = ntt_directed_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #200;
        phase.drop_objection(this);
    endtask
endclass


// Full regression: directed + stress + coverage closure.
class ntt_full_test extends ntt_base_test;
    `uvm_component_utils(ntt_full_test)

    function new(string name = "ntt_full_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ntt_full_seq seq;
        phase.raise_objection(this);
        seq = ntt_full_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #200;
        phase.drop_objection(this);
    endtask

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (env.scoreboard.total_tests!=620 || env.scoreboard.failed_tests!=0 ||
            env.scoreboard.passed_tests!=620 || env.coverage.checked_jobs!=620 ||
            env.scoreboard.checked_coefficients!=158720 || env.scoreboard.equivalence_passed!=16)
            `uvm_fatal("UVM_REGRESSION_GATE", "Expected 620 checked passing jobs / 158720 coefficients")
        if (env.coverage.minimum_group_coverage()<90.0)
            `uvm_fatal("UVM_REGRESSION_GATE", "A checked functional group is below the 90 percent review target")
        `uvm_info("UVM_REGRESSION_GATE","NTT EXPANDED UVM PASS: 620/620 jobs, 158720/158720 coefficients, 22 checked covergroup types each >=90 percent",UVM_NONE)
    endfunction
endclass

// Uses one real passing DUT job, then corrupts its observed scoreboard item.
// Only those expected scoreboard errors are caught, scoped to this self-test.
class ntt_gate_error_catcher extends uvm_report_catcher;
    int expected_errors;
    uvm_report_object target;
    bit armed;
    function new(string name="ntt_gate_error_catcher"); super.new(name); endfunction
    virtual function action_e catch();
        if (armed && get_client()==target && get_severity()==UVM_ERROR &&
            get_id()=="ntt_scoreboard") begin
            expected_errors++;
            return CAUGHT;
        end
        return THROW;
    endfunction
endclass

class ntt_gate_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_gate_seq)
    function new(string name="ntt_gate_seq"); super.new(name); endfunction
    task body();
        send_item("GATE real zero NTT", OP_NTT, IK_ZERO, make_const(coeff_t'(0)));
    endtask
endclass

class ntt_coverage_gate_test extends ntt_base_test;
    `uvm_component_utils(ntt_coverage_gate_test)
    function new(string name="ntt_coverage_gate_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
        ntt_gate_seq seq;
        ntt_gate_error_catcher catcher;
        ntt_transaction good, expected, bad;
        int saved_jobs,saved_gap,saved_stall;
        real saved_coverage, saved_arithmetic_coverage, saved_expanded_coverage;
        bit [4:0] saved_sum_classes;
        bit [4:0] saved_sub_classes;
        phase.raise_objection(this);
        seq=ntt_gate_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #20;
        good=env.scoreboard.last_pass;
        if (good==null || env.coverage.checked_jobs!=1)
            `uvm_fatal("COVERAGE_GATE_TEST", "Missing real passing DUT witness")
        saved_jobs=env.coverage.checked_jobs;
        saved_gap=good.trace.max_gap;saved_stall=good.trace.max_stall;
        saved_expanded_coverage=env.coverage.expanded_mean_coverage();
        saved_coverage=env.coverage.cg_schedule.get_coverage();
        saved_arithmetic_coverage=env.coverage.cg_butterfly_arithmetic.get_coverage();
        saved_sum_classes=good.trace.routing.ct_sum_classes;
        saved_sub_classes=good.trace.routing.ct_sub_classes;
        expected=ntt_transaction::type_id::create("expected");
        expected.test_name="GATE deliberate corruption";
        expected.op=good.op; expected.exp_poly=good.exp_poly;
        catcher=new(); catcher.target=env.scoreboard; catcher.armed=1;
        uvm_report_cb::add(env.scoreboard,catcher);
        for (int fault=0; fault<7; fault++) begin
            expected.reset_point=-1;
            bad=ntt_transaction::type_id::create("bad");
            bad.op=good.op; bad.obs_poly=good.obs_poly;
            bad.observed_count=good.observed_count;
            bad.output_framing_ok=good.output_framing_ok;
            bad.trace=good.trace;
            case (fault)
                0: bad.obs_poly[17]=coeff_t'(1);
                1: bad.observed_count=N-1;
                2: bad.output_framing_ok=0;
                3: bad.trace=null;
                4: begin
                    expected.reset_point=0;
                    bad.observed_reset_point=0;
                    bad.reset_checks_ok=0;
                end
                5: bad.trace.max_gap=63;
                6: bad.trace.max_stall=63;
            endcase
            // Poison only the rejected item's arithmetic metadata with
            // all boundary classes. If a failed item escaped to coverage,
            // it would add bins beyond the real zero-polynomial witness.
            if (bad.trace!=null) begin
                bad.trace.routing.ct_sum_classes=5'b11111;
                bad.trace.routing.ct_sub_classes=5'b11111;
            end
            env.scoreboard.compare_tx(expected,bad);
            good.trace.max_gap=saved_gap;good.trace.max_stall=saved_stall;
            good.trace.routing.ct_sum_classes=saved_sum_classes;
            good.trace.routing.ct_sub_classes=saved_sub_classes;
            if (catcher.expected_errors!=fault+1 ||
                env.coverage.checked_jobs!=saved_jobs ||
                env.coverage.cg_schedule.get_coverage()!=saved_coverage ||
                env.coverage.expanded_mean_coverage()!=saved_expanded_coverage ||
                env.coverage.cg_butterfly_arithmetic.get_coverage()!=saved_arithmetic_coverage)
                `uvm_fatal("COVERAGE_GATE_TEST", "Failed item changed checked coverage or escaped rejection")
            `uvm_info("COVERAGE_GATE_TEST",
                      $sformatf("fault=%0d rejected; checked_jobs=%0d unchanged",fault,saved_jobs),UVM_NONE)
        end
        catcher.armed=0;
        uvm_report_cb::delete(env.scoreboard,catcher);
        if (env.scoreboard.passed_tests!=1 || env.scoreboard.failed_tests!=7)
            `uvm_fatal("COVERAGE_GATE_TEST", "Unexpected checker counts")
        `uvm_info("COVERAGE_GATE_TEST", "UVM COVERAGE GATE PASS: seven deliberate failures rejected (including gap/stall observations), no checked coverage added",UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass

// Expected-illegal-input UVM runs, separate from the passing regression.
// The DUT must stop with its specific bounded-secret $fatal, before output.
class ntt_pre_invalid_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_pre_invalid_seq)
    int position;
    int bad_value=-1;
    function new(string name="ntt_pre_invalid_seq"); super.new(name); endfunction
    task body();
        poly_t p=make_const(coeff_t'(0));
        p[position]=coeff_t'((bad_value>=0) ? bad_value : ((position==128) ? Q-5 : 5));
        send_item($sformatf("ILLEGAL Pre index %0d",position),OP_PRE_NTT,IK_PRE_BOUNDARY,p);
        `uvm_fatal("ELIGIBILITY_TEST", "Ineligible Pre input was not rejected by DUT")
    endtask
endclass

class ntt_pre_invalid_first_test extends ntt_base_test;
    `uvm_component_utils(ntt_pre_invalid_first_test)
    int position=0;
    int bad_value=-1;
    function new(string name="ntt_pre_invalid_first_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
        ntt_pre_invalid_seq seq;
        phase.raise_objection(this);
        seq=ntt_pre_invalid_seq::type_id::create("seq"); seq.position=position; seq.bad_value=bad_value;
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass
class ntt_pre_invalid_middle_test extends ntt_pre_invalid_first_test;
    `uvm_component_utils(ntt_pre_invalid_middle_test)
    function new(string name="ntt_pre_invalid_middle_test",uvm_component parent=null);
        super.new(name,parent); position=128;
    endfunction
endclass
class ntt_pre_invalid_last_test extends ntt_pre_invalid_first_test;
    `uvm_component_utils(ntt_pre_invalid_last_test)
    function new(string name="ntt_pre_invalid_last_test",uvm_component parent=null);
        super.new(name,parent); position=255;
    endfunction
endclass

// +8 shares the narrow lookup key of legal zero, but must be rejected
// by the unchanged full-width Pre eligibility check at the input handshake.
class ntt_pre_invalid_alias_test extends ntt_pre_invalid_first_test;
    `uvm_component_utils(ntt_pre_invalid_alias_test)
    function new(string name="ntt_pre_invalid_alias_test",uvm_component parent=null);
        super.new(name,parent); position=0; bad_value=8;
    endfunction
endclass

// Deliberately alter ONE observed datum inside the routing checker only.
// The actual DUT and output oracle remain correct. Check that the routing
// error is detected and prevents all checked functional coverage publication.
class ntt_routing_error_catcher extends uvm_report_catcher;
    bit armed;
    int routing_errors,scoreboard_errors;
    uvm_report_object scoreboard;
    function new(string name="ntt_routing_error_catcher"); super.new(name); endfunction
    virtual function action_e catch();
        if (armed && get_severity()==UVM_ERROR) begin
            if (get_id()=="ROUTING_TRACE") begin routing_errors++; return CAUGHT; end
            if (get_id()=="ntt_scoreboard" && get_client()==scoreboard) begin
                scoreboard_errors++; return CAUGHT;
            end
        end
        return THROW;
    endfunction
endclass
class ntt_routing_probe_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_routing_probe_seq)
    function new(string name="ntt_routing_probe_seq"); super.new(name); endfunction
    task body();
        poly_t p;
        for (int i=0; i<N; i++) p[i]=coeff_t'((i*12345+7)%Q);
        send_item("ROUTING checker probe",OP_NTT,IK_RANDOM,p);
    endtask
endclass
class ntt_routing_operand_fault_test extends ntt_base_test;
    `uvm_component_utils(ntt_routing_operand_fault_test)
    int fault=1;
    function new(string name="ntt_routing_operand_fault_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(int)::set(null,"uvm_test_top","routing_observation_fault",fault);
    endfunction
    task run_phase(uvm_phase phase);
        ntt_routing_error_catcher catcher;
        ntt_routing_probe_seq seq;
        ntt_transaction observed;
        phase.raise_objection(this);
        catcher=new(); catcher.armed=1; catcher.scoreboard=env.scoreboard;
        uvm_report_cb::add(null,catcher);
        seq=ntt_routing_probe_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #20;
        catcher.armed=0;
        uvm_report_cb::delete(null,catcher);
        observed=env.scoreboard.last_observed;
        if (observed==null || !observed.trace.routing.fault_injected ||
            observed.trace.routing.errors!=1 || catcher.routing_errors!=1 ||
            catcher.scoreboard_errors!=1 || env.scoreboard.failed_tests!=1 ||
            env.scoreboard.passed_tests!=0 || env.coverage.checked_jobs!=0 ||
            env.coverage.cg_coefficient_routing.get_coverage()!=0)
            `uvm_fatal("ROUTING_CHECKER_TEST", "Injected observation was not detected/gated exactly once")
        for (int i=0; i<N; i++)
            if (observed.obs_poly[i]!==observed.exp_poly[i])
                `uvm_fatal("ROUTING_CHECKER_TEST", "Unexpected actual DUT output mismatch")
        `uvm_info("ROUTING_CHECKER_TEST",
            $sformatf("UVM ROUTING CHECKER PASS: fault=%0d detected, real DUT output correct, checked_jobs=0",fault),UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass
class ntt_routing_writeback_fault_test extends ntt_routing_operand_fault_test;
    `uvm_component_utils(ntt_routing_writeback_fault_test)
    function new(string name="ntt_routing_writeback_fault_test",uvm_component parent=null);
        super.new(name,parent); fault=2;
    endfunction
endclass

// Separate sensitivity test: a real passing GS-boundary job, then one missing
// observed class. This expected failure must not reach checked coverage.
class ntt_gs_sum_gate_test extends ntt_base_test;
    `uvm_component_utils(ntt_gs_sum_gate_test)
    function new(string name="ntt_gs_sum_gate_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
        ntt_inverse_sum_boundary_seq seq;
        ntt_gate_error_catcher catcher;
        ntt_transaction good,expected,bad;
        bit [4:0] saved_mask;
        int saved_jobs;
        phase.raise_objection(this);
        seq=ntt_inverse_sum_boundary_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #20;
        good=env.scoreboard.last_pass;
        if (good==null || env.coverage.checked_jobs!=1)
            `uvm_fatal("GS_SUM_GATE_TEST","Missing real passing GS boundary job")
        saved_jobs=env.coverage.checked_jobs;
        saved_mask=good.trace.routing.gs_sum_classes[2];
        expected=ntt_transaction::type_id::create("expected");
        expected.test_name="ARITH GS sum/carry boundaries";
        expected.op=OP_INTT;
        expected.exp_poly=ntt_inv(good.trace.routing.operand_a);
        bad=ntt_transaction::type_id::create("bad");
        bad.op=OP_INTT;bad.obs_poly=good.obs_poly;
        bad.observed_count=good.observed_count;bad.output_framing_ok=good.output_framing_ok;
        bad.trace=good.trace;
        bad.trace.routing.gs_sum_classes[2][2]=0; // hide exact-q on lane2 only
        catcher=new();catcher.target=env.scoreboard;catcher.armed=1;
        uvm_report_cb::add(env.scoreboard,catcher);
        env.scoreboard.compare_tx(expected,bad);
        good.trace.routing.gs_sum_classes[2]=saved_mask;
        catcher.armed=0;uvm_report_cb::delete(env.scoreboard,catcher);
        if (catcher.expected_errors!=1 || env.scoreboard.passed_tests!=1 ||
            env.scoreboard.failed_tests!=1 || env.coverage.checked_jobs!=saved_jobs)
            `uvm_fatal("GS_SUM_GATE_TEST","Missing GS class escaped rejection or added credit")
        `uvm_info("GS_SUM_GATE_TEST","UVM GS SUM GATE PASS: missing lane2 exact-q witness rejected, real outputs correct, checked_jobs=1 unchanged",UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass
