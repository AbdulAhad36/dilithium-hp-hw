class adder_env extends uvm_env;

  `uvm_component_utils(adder_env)

  adder_driver drv;
  adder_monitor mon;
  adder_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    drv = adder_driver::type_id::create("drv", this);
    mon = adder_monitor::type_id::create("mon", this);
    sb  = adder_scoreboard::type_id::create("sb", this);
  endfunction

endclass