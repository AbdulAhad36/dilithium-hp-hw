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
endclass
