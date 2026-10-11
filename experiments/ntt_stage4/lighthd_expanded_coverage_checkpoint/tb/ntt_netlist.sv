// Same main UVM agent/monitor/scoreboard and independent reference model.
// No synthesized hierarchy is reconstructed and no internal bins are credited.
class ntt_netlist_driver extends ntt_driver;
    `uvm_component_utils(ntt_netlist_driver)
    function new(string name="ntt_netlist_driver",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    // Last output is accepted one clock before done. Observe that pulse before
    // allowing the next sequence item to reset or restart the implementation.
    virtual task finish_transaction();
        int clocks=0;
        do begin
            @(negedge vif.clk);
            if (++clocks>20) `uvm_fatal("NETLIST_DONE","No done after final output")
        end while (vif.done!==1'b1);
        if (vif.busy!==1'b0 || vif.m_tvalid!==1'b0)
            `uvm_fatal("NETLIST_DONE","Busy/output valid still asserted at done")
        // Let the public monitor sample done at the next positive edge.
        @(negedge vif.clk);
    endtask

    task abort_operand(poly_t p,int beats);
        for (int i=0;i<beats;i++) begin
            vif.s_tvalid=1; vif.s_tdata=p[i]; vif.s_tlast=(i==N-1);
            do @(posedge vif.clk); while (vif.s_tready!==1'b1);
            @(negedge vif.clk);
        end
        vif.s_tvalid=0; vif.s_tlast=0;
    endtask

    virtual task drive_reset_abort(ntt_transaction req);
        ntt_op_e abort_op;
        poly_t secret;
        int clocks;
        abort_op=(req.reset_point==2 || req.reset_point==5) ? OP_PWM :
                 ((req.reset_point==4) ? OP_INTT :
                 ((req.reset_point==6) ? OP_PRE_NTT : OP_NTT));
        for (int i=0;i<N;i++) secret[i]=coeff_t'((i%9)-4+Q)%Q;
        @(negedge vif.clk);
        vif.rst=1; vif.start=0; vif.s_tvalid=0; vif.s_tlast=0;
        repeat (3) @(negedge vif.clk);
        vif.rst=0;
        @(negedge vif.clk);
        if (req.reset_point!=0) begin
            vif.op=abort_op; vif.start=1;
            @(negedge vif.clk); vif.start=0;
            abort_operand((abort_op==OP_PRE_NTT) ? secret : req.abort_poly,
                          (req.reset_point==1) ? 17 : N);
            if (req.reset_point==2 || req.reset_point==5)
                abort_operand(req.abort_poly,(req.reset_point==2) ? 17 : N);
            if (req.reset_point>=3 && req.reset_point<=6)
                repeat (16) @(negedge vif.clk);
            if (req.reset_point==7) begin
                clocks=0;
                while (vif.m_tvalid!==1'b1) begin
                    @(negedge vif.clk);
                    if (++clocks>2000) `uvm_fatal("NETLIST_RESET_TARGET","No stalled output")
                end
                repeat (3) @(negedge vif.clk);
            end
        end
        vif.rst=1; vif.start=0; vif.s_tvalid=0; vif.s_tlast=0;
        repeat (2) @(negedge vif.clk);
        vif.rst=0;
        repeat (4) @(negedge vif.clk);
    endtask
endclass

class ntt_netlist_monitor extends ntt_monitor;
    `uvm_component_utils(ntt_netlist_monitor)
    int completed_jobs, aborted_jobs, reset_witnesses, protocol_errors;
    function new(string name="ntt_netlist_monitor",uvm_component parent=null);
        super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
        fork
            super.run_phase(phase);
            check_public_protocol();
        join
    endtask
    task check_public_protocol();
        int inputs,outputs,expected_inputs;
        bit active,previous_done,previous_reset;
        forever begin
            @(posedge vif.clk);
            if (vif.rst) begin
                if (!previous_reset && active) aborted_jobs++;
                active=0; inputs=0; outputs=0; previous_done=0;
            end else begin
                if ($isunknown({vif.busy,vif.done,vif.s_tready,vif.m_tvalid,vif.m_tlast})) begin
                    protocol_errors++;
                    `uvm_error("NETLIST_PROTOCOL","Unknown public control signal")
                end
                if (vif.done) begin
                    if (previous_done || !active || outputs!=N || inputs!=expected_inputs) begin
                        protocol_errors++;
                        `uvm_error("NETLIST_PROTOCOL",$sformatf("Invalid done: active=%0b inputs=%0d/%0d outputs=%0d",active,inputs,expected_inputs,outputs))
                    end
                    completed_jobs++; active=0;
                end
                if (vif.start && !vif.busy) begin
                    if (active) begin
                        protocol_errors++;
                        `uvm_error("NETLIST_PROTOCOL","New job before prior done")
                    end
                    active=1; inputs=0; outputs=0;
                    expected_inputs=(vif.op==OP_PWM) ? 2*N : N;
                end
                if (vif.s_tvalid && vif.s_tready) begin
                    inputs++;
                    if (!active || inputs>expected_inputs) begin
                        protocol_errors++;
                        `uvm_error("NETLIST_PROTOCOL","Unexpected input acceptance")
                    end
                end
                if (vif.m_tvalid && vif.m_tready) begin
                    outputs++;
                    if (!active || !vif.busy || outputs>N ||
                        vif.m_tlast!==(outputs==N) || $isunknown(vif.m_tdata)) begin
                        protocol_errors++;
                        `uvm_error("NETLIST_PROTOCOL","Unexpected output/framing/data/busy")
                    end
                end
                previous_done=vif.done;
            end
            previous_reset=vif.rst;
        end
    endtask

    virtual task collect_reset_abort(ntt_transaction exp_tx,output int observed_point,output bit ok);
        int inputs;
        bit at_target;
        inputs=0; observed_point=-1; ok=1;
        vif.m_tready=0;
        wait(vif.rst===1'b1); wait(vif.rst===1'b0);
        fork
            begin
                forever begin
                    @(posedge vif.clk);
                    if (!vif.rst && vif.s_tvalid && vif.s_tready) inputs++;
                end
            end
            begin
                @(posedge vif.rst);
                case(exp_tx.reset_point)
                    0: at_target=!vif.busy && inputs==0;
                    1: at_target=vif.busy && inputs==17;
                    2: at_target=vif.busy && vif.op==OP_PWM && inputs==N+17;
                    3: at_target=vif.busy && !vif.s_tready && !vif.m_tvalid && vif.op==OP_NTT && inputs==N;
                    4: at_target=vif.busy && !vif.s_tready && !vif.m_tvalid && vif.op==OP_INTT && inputs==N;
                    5: at_target=vif.busy && !vif.s_tready && !vif.m_tvalid && vif.op==OP_PWM && inputs==2*N;
                    6: at_target=vif.busy && !vif.s_tready && !vif.m_tvalid && vif.op==OP_PRE_NTT && inputs==N;
                    7: at_target=vif.m_tvalid && !vif.m_tready && inputs==N;
                endcase
            end
        join_any
        disable fork;
        if(at_target) observed_point=exp_tx.reset_point;
        else ok=0;
        repeat(2) begin
            @(posedge vif.clk); #1ps;
            if ({vif.busy,vif.done,vif.m_tvalid,vif.s_tready} !== '0) ok=0;
        end
        wait(vif.rst===1'b0);
        repeat(3) begin
            @(posedge vif.clk); #1ps;
            if ({vif.busy,vif.done,vif.m_tvalid,vif.s_tready} !== '0) ok=0;
        end
        if (ok) reset_witnesses++;
        `uvm_info("NETLIST_RESET_OBSERVED",$sformatf("target=%0d observed=%0d accepted_inputs=%0d cleared=%0b",exp_tx.reset_point,observed_point,inputs,ok),UVM_LOW)
    endtask
endclass

class ntt_netlist_reset_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_netlist_reset_seq)
    function new(string name="ntt_netlist_reset_seq");super.new(name);endfunction
    task body();
        string names[8]='{"idle","partial operand A","partial operand B","NTT busy",
                          "INTT busy","PWM busy","Pre busy","stalled output"};
        for(int point=0;point<8;point++) begin
            ntt_transaction tx=ntt_transaction::type_id::create("tx");
            start_item(tx);
            tx.test_name={"NETLIST RESET recovery after ",names[point]};
            tx.op=OP_NTT; tx.in_kind=IK_RANDOM; tx.reset_before=0; tx.reset_point=point;
            tx.abort_poly=make_random();
            for(int i=0;i<N;i++)tx.in_poly[i]=coeff_t'((i*12345+point+1)%Q);
            tx.exp_poly=ntt_fwd(tx.in_poly);
            finish_item(tx);
        end
    endtask
endclass

// Reuse all109 non-reset jobs from the source regression, replacing9 source
// state-specific resets with8 resets witnessed only through external pins.
class ntt_netlist_seq extends ntt_base_seq;
    `uvm_object_utils(ntt_netlist_seq)
    function new(string name="ntt_netlist_seq");super.new(name);endfunction
    task body();
        ntt_directed_seq d=ntt_directed_seq::type_id::create("directed");
        ntt_stress_seq s=ntt_stress_seq::type_id::create("stress");
        ntt_cov_seq c=ntt_cov_seq::type_id::create("standard_cases");
        ntt_pre_seq p=ntt_pre_seq::type_id::create("pre");
        ntt_repeat_seq r=ntt_repeat_seq::type_id::create("repeat_jobs");
        ntt_flow_seq f=ntt_flow_seq::type_id::create("flow");
        ntt_pre_equivalence_seq e=ntt_pre_equivalence_seq::type_id::create("equivalence");
        ntt_arithmetic_boundary_seq a=ntt_arithmetic_boundary_seq::type_id::create("ct_boundaries");
        ntt_reduction_boundary_seq b=ntt_reduction_boundary_seq::type_id::create("product_boundaries");
        ntt_inverse_sum_boundary_seq g=ntt_inverse_sum_boundary_seq::type_id::create("gs_boundaries");
        ntt_netlist_reset_seq reset_seq=ntt_netlist_reset_seq::type_id::create("resets");
        d.start(m_sequencer);s.start(m_sequencer);c.start(m_sequencer);
        p.start(m_sequencer);r.start(m_sequencer);f.start(m_sequencer);
        reset_seq.start(m_sequencer);e.start(m_sequencer);
        a.start(m_sequencer);b.start(m_sequencer);g.start(m_sequencer);
    endtask
endclass

class ntt_netlist_test extends ntt_base_test;
    `uvm_component_utils(ntt_netlist_test)
    string representation="unspecified";
    function new(string name="ntt_netlist_test",uvm_component parent=null);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);
        ntt_driver::type_id::set_type_override(ntt_netlist_driver::get_type());
        ntt_monitor::type_id::set_type_override(ntt_netlist_monitor::get_type());
        uvm_config_db#(bit)::set(this,"env*","netlist_mode",1);
        void'($value$plusargs("NTT_REPRESENTATION=%s",representation));
        super.build_phase(phase);
    endfunction
    task run_phase(uvm_phase phase);
        ntt_netlist_seq seq=ntt_netlist_seq::type_id::create("seq");
        phase.raise_objection(this); seq.start(env.agent.sequencer);
        #200; phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
        ntt_netlist_monitor monitor;
        super.check_phase(phase);
        if (!$cast(monitor,env.agent.monitor)) `uvm_fatal("NETLIST_GATE","Wrong monitor type")
        if (env.scoreboard.total_tests!=117 || env.scoreboard.passed_tests!=117 ||
            env.scoreboard.failed_tests!=0 || env.scoreboard.checked_coefficients!=29952 ||
            env.scoreboard.equivalence_passed!=16 || env.scoreboard.pending_pair!=-1 ||
            monitor.completed_jobs!=117 || monitor.aborted_jobs!=7 ||
            monitor.reset_witnesses!=8 || monitor.protocol_errors!=0 || env.coverage!=null)
            `uvm_fatal("NETLIST_GATE",$sformatf("Expected117 passing jobs/29952 coefficients/16pairs/8resets/7aborts: jobs=%0d pass=%0d done=%0d aborted=%0d resets=%0d errors=%0d",env.scoreboard.total_tests,env.scoreboard.passed_tests,monitor.completed_jobs,monitor.aborted_jobs,monitor.reset_witnesses,monitor.protocol_errors))
        `uvm_info("NETLIST_GATE",$sformatf("NTT NETLIST REGRESSION PASS: %s 117/117 jobs, 29952/29952 coefficients, 16 equivalence pairs, 8 reset witnesses; no internal coverage credited",representation),UVM_NONE)
    endfunction
endclass

// Check the external-mode scoreboard with five intentional rejected items.
// Kept separate from the117-job passing netlist regressions.
class ntt_netlist_gate_test extends ntt_netlist_test;
    `uvm_component_utils(ntt_netlist_gate_test)
    function new(string name="ntt_netlist_gate_test",uvm_component parent=null);super.new(name,parent);endfunction
    task run_phase(uvm_phase phase);
        ntt_gate_seq seq=ntt_gate_seq::type_id::create("seq");
        ntt_gate_error_catcher catcher=new();
        ntt_transaction good,expected,bad;
        phase.raise_objection(this);seq.start(env.agent.sequencer);#200;
        good=env.scoreboard.last_pass;
        if (good==null || env.scoreboard.passed_tests!=1 || good.trace!=null)
            `uvm_fatal("NETLIST_CHECKER_GATE","Missing real externally checked netlist result")
        expected=ntt_transaction::type_id::create("expected");
        expected.exp_poly=good.exp_poly; expected.test_name="intentional external checker corruption";
        catcher.target=env.scoreboard;catcher.armed=1;uvm_report_cb::add(env.scoreboard,catcher);
        for(int fault=0;fault<5;fault++)begin
            bad=ntt_transaction::type_id::create("bad");
            bad.obs_poly=good.obs_poly;bad.observed_count=N;
            bad.output_framing_ok=1;bad.output_stability_ok=1;
            case(fault)
                0: bad.obs_poly[17]=coeff_t'(1);
                1: bad.observed_count=N-1;
                2: bad.output_framing_ok=0;
                3: bad.output_stability_ok=0;
                4: begin expected.reset_point=0;bad.observed_reset_point=0;bad.reset_checks_ok=0;end
            endcase
            env.scoreboard.compare_tx(expected,bad);
            if (env.scoreboard.failed_tests!=fault+1 || env.scoreboard.passed_tests!=1 ||
                env.scoreboard.checked_coefficients!=N || env.coverage!=null)
                `uvm_fatal("NETLIST_CHECKER_GATE","Corrupted item escaped external checker")
        end
        catcher.armed=0;uvm_report_cb::delete(env.scoreboard,catcher);
        if(catcher.expected_errors!=5) `uvm_fatal("NETLIST_CHECKER_GATE","Expected five caught errors")
        phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
        if(env.scoreboard.passed_tests!=1 || env.scoreboard.failed_tests!=5)
            `uvm_fatal("NETLIST_CHECKER_GATE","Wrong external checker self-test totals")
        `uvm_info("NETLIST_CHECKER_GATE","NTT NETLIST CHECKER GATE PASS: five external corruptions rejected",UVM_NONE)
    endfunction
endclass
