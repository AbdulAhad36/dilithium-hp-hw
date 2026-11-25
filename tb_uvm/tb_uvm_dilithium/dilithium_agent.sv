  class dilithium_agent extends uvm_agent;
    `uvm_component_utils(dilithium_agent)
    dilithium_sequencer sequencer;
    dilithium_driver driver;
    dilithium_monitor monitor;
    dilithium_config cfg;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(dilithium_config)::get(this,"","cfg",cfg))
        `uvm_fatal("CFG","Missing agent configuration")
      is_active=cfg.is_active;
      monitor=dilithium_monitor::type_id::create("monitor",this);
      if(get_is_active()==UVM_ACTIVE)begin
        sequencer=dilithium_sequencer::type_id::create("sequencer",this);
        driver=dilithium_driver::type_id::create("driver",this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if(get_is_active()==UVM_ACTIVE)driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

