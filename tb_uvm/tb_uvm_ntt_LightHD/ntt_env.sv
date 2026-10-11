// ============================================================================
// ntt_env.sv  --  UVM environment for ntt_engine
// ----------------------------------------------------------------------------
// A single agent + scoreboard + coverage bundle. The ntt_engine is one engine
// (not a replicated parallel wrapper like keccak), so there is no per-lane
// fan-out -- one agent verifies the one DUT.
// ============================================================================
class ntt_env extends uvm_env;
    `uvm_component_utils(ntt_env)

    bit netlist_mode;
    ntt_agent      agent;
    ntt_scoreboard scoreboard;
    ntt_coverage   coverage;

    function new(string name = "ntt_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(bit)::get(this, "", "netlist_mode", netlist_mode));
        agent      = ntt_agent     ::type_id::create("agent",      this);
        scoreboard = ntt_scoreboard::type_id::create("scoreboard", this);
        if (!netlist_mode) coverage = ntt_coverage  ::type_id::create("coverage",   this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.driver.drv_ap.connect(scoreboard.exp_fifo.analysis_export);
        agent.monitor.mon_ap.connect(scoreboard.obs_fifo.analysis_export);
        if (!netlist_mode) scoreboard.checked_ap.connect(coverage.analysis_export);
    endfunction

endclass
