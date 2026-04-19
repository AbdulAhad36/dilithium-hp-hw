// =========================================================================
// Keccak Tests
// =========================================================================

// Base Test
class keccak_base_test extends uvm_test;
    `uvm_component_utils(keccak_base_test)

    keccak_env              env;
    keccak_suite_seq        suite_seq;
    keccak_random_seq       random_seq;
    virtual keccak_if       vif;

    function new(string name = "keccak_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = keccak_env::type_id::create("env", this);
        
        if (!uvm_config_db#(virtual keccak_if)::get(this, "", "keccak_vif", vif))
            `uvm_fatal("TEST", "Failed to get keccak_vif from config DB")
        
        uvm_config_db#(virtual keccak_if)::set(this, "env.agent.*", "keccak_vif", vif);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        apply_reset();
        run_test_sequence();
        #1000;
        phase.drop_objection(this);
    endtask

    virtual task apply_reset();
        vif.rst <= 1;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 0;
        repeat(10) @(posedge vif.clk);
    endtask

    virtual task run_test_sequence();
        // suite_seq = keccak_suite_seq::type_id::create("suite_seq");
        // suite_seq.start(env.agent.sequencer);
        random_seq = keccak_random_seq::type_id::create("keccak_random_seq");
        random_seq.start(env.agent.sequencer);

    endtask

endclass