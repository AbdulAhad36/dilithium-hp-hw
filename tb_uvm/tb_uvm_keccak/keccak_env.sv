// =========================================================================
// Keccak Environment - Top-level verification component container
// =========================================================================
class keccak_env extends uvm_env;
    `uvm_component_utils(keccak_env)

    keccak_agent               agent;
    keccak_scoreboard          scoreboard;
    // keccak_coverage            coverage;
    // keccak_reference_model     ref_model;  // To be implemented

    function new(string name = "keccak_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = keccak_agent::type_id::create("agent", this);
        scoreboard = keccak_scoreboard::type_id::create("scoreboard", this);
        // coverage = keccak_coverage::type_id::create("coverage", this);
        // ref_model = keccak_reference_model::type_id::create("ref_model", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.mon_ap.connect(scoreboard.analysis_imp);
        // agent.monitor.mon_ap.connect(coverage.analysis_imp);
        
        // Connect reference model to scoreboard
        // ref_model.ref_ap.connect(scoreboard.analysis_imp);
    endfunction

endclass