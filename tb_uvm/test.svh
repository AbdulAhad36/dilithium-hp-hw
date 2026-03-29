class adder_test extends uvm_test;

  `uvm_component_utils(adder_test)

  adder_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    env = adder_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
  
    adder_sequence seq;
  
    super.run_phase(phase);
  
    phase.raise_objection(this);
  
    seq = adder_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);
  
    phase.drop_objection(this);
  
  endtask

endclass