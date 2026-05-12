// =========================================================================
// keccak_tests.sv  -  UVM tests (multi-lane)
//
// Each test forks N_LANES copies of a sequence onto the per-lane sequencers
// and joins before dropping the objection. With N_LANES=1 this behaves like
// the original single-lane regression.
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


// Directed only: 13 NIST vectors per lane, in parallel.
class keccak_directed_test extends keccak_base_test;
    `uvm_component_utils(keccak_directed_test)

    function new(string name = "keccak_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        keccak_directed_seq seq [keccak_env::N_LANES];
        phase.raise_objection(this);

        foreach (seq[i]) seq[i] = keccak_directed_seq::type_id::create($sformatf("seq_%0d", i));

        fork
            seq[0].start(env.agent[0].sequencer);
            seq[1].start(env.agent[1].sequencer);
            seq[2].start(env.agent[2].sequencer);
            seq[3].start(env.agent[3].sequencer);
        join

        #200;
        phase.drop_objection(this);
    endtask
endclass


// Full: directed + stress + coverage closure per lane, in parallel.
class keccak_full_test extends keccak_base_test;
    `uvm_component_utils(keccak_full_test)

    function new(string name = "keccak_full_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        keccak_full_seq seq [keccak_env::N_LANES];
        phase.raise_objection(this);

        foreach (seq[i]) seq[i] = keccak_full_seq::type_id::create($sformatf("seq_%0d", i));

        fork
            seq[0].start(env.agent[0].sequencer);
            seq[1].start(env.agent[1].sequencer);
            seq[2].start(env.agent[2].sequencer);
            seq[3].start(env.agent[3].sequencer);
        join

        #200;
        phase.drop_objection(this);
    endtask
endclass
