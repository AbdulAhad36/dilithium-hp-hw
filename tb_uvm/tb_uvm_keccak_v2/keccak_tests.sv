// =========================================================================
// keccak_tests.sv  -  TB v2 tests (base + directed)
// =========================================================================
class keccak_base_test extends uvm_test;
    `uvm_component_utils(keccak_base_test)

    keccak_env env;

    function new(string name = "keccak_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = keccak_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass


class keccak_directed_test extends keccak_base_test;
    `uvm_component_utils(keccak_directed_test)

    function new(string name = "keccak_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        keccak_directed_seq seq;
        phase.raise_objection(this);

        seq = keccak_directed_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);

        #200;
        phase.drop_objection(this);
    endtask
endclass


class keccak_full_test extends keccak_base_test;
    `uvm_component_utils(keccak_full_test)

    function new(string name = "keccak_full_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        keccak_full_seq seq;
        phase.raise_objection(this);

        seq = keccak_full_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);

        #200;
        phase.drop_objection(this);
    endtask
endclass
