// Environment wiring: passive observations -> checking -> checked coverage.
class dilithium_env extends uvm_env;
  `uvm_component_utils(dilithium_env)
  dilithium_agent agent;
  dilithium_scoreboard scoreboard;
  dilithium_coverage coverage;

  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent=dilithium_agent::type_id::create("agent",this);
    scoreboard=dilithium_scoreboard::type_id::create("scoreboard",this);
    coverage=dilithium_coverage::type_id::create("coverage",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.observed.connect(scoreboard.observed);
    scoreboard.accepted.connect(coverage.analysis_export);
  endfunction
endclass
