class dilithium_regression_test extends uvm_test;
  `uvm_component_utils(dilithium_regression_test)
  dilithium_env env;
  dilithium_config cfg;
  virtual dilithium_if vif;

  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg=dilithium_config::type_id::create("cfg");
    cfg.load();
    uvm_config_db#(dilithium_config)::set(this,"*","cfg",cfg);
    if(!uvm_config_db#(virtual dilithium_if)::get(this,"","vif",vif))
      `uvm_fatal("VIF","Missing interface")
    env=dilithium_env::type_id::create("env",this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual function dilithium_sequence make_sequence();
    return dilithium_sequence::type_id::create("sequence0");
  endfunction

  task run_phase(uvm_phase phase);
    dilithium_sequence sequence0=make_sequence();
    phase.raise_objection(this);
    sequence0.cfg=cfg;
    sequence0.start(env.agent.sequencer);
    repeat(5)@(posedge vif.clk);
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server server=uvm_report_server::get_server();
    if(server.get_severity_count(UVM_ERROR)==0 &&
       server.get_severity_count(UVM_FATAL)==0 &&
       env.scoreboard.position==cfg.cases.size())begin
      vif.test_passed=1;
      `uvm_info("STAGE7C5_UVM_PASS",$sformatf(
        "%0d checked completions/%0d reset aborts; %0d coverage-qualified outcomes",
        env.scoreboard.checked,env.scoreboard.aborted,env.coverage.checked),UVM_NONE)
    end
  endfunction
endclass

// Identical NIST cases and expectations;constrained-random transport profiles.
class dilithium_random_stall_test extends dilithium_regression_test;
  `uvm_component_utils(dilithium_random_stall_test)
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  virtual function dilithium_sequence make_sequence();
    return dilithium_random_stall_sequence::type_id::create("random_sequence");
  endfunction
endclass

