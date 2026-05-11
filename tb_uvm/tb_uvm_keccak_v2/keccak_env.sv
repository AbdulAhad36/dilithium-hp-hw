// =========================================================================
// keccak_env.sv  -  TB v2 environment
// Hosts agent + scoreboard + coverage. Wires analysis ports:
//   driver.drv_ap  -> scoreboard.exp_fifo, coverage
//   monitor.mon_ap -> scoreboard.obs_fifo
// =========================================================================
class keccak_env extends uvm_env;
    `uvm_component_utils(keccak_env)

    keccak_agent       agent;
    keccak_scoreboard  scoreboard;
    keccak_coverage    coverage;

    function new(string name = "keccak_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = keccak_agent     ::type_id::create("agent",      this);
        scoreboard = keccak_scoreboard::type_id::create("scoreboard", this);
        coverage   = keccak_coverage  ::type_id::create("coverage",   this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.driver.drv_ap.connect(scoreboard.exp_fifo.analysis_export);
        agent.driver.drv_ap.connect(coverage.analysis_export);
        agent.monitor.mon_ap.connect(scoreboard.obs_fifo.analysis_export);
    endfunction

endclass
