  class dilithium_sequencer extends uvm_sequencer#(dilithium_transaction);
    `uvm_component_utils(dilithium_sequencer)
    dilithium_config cfg;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(dilithium_config)::get(this,"","cfg",cfg))
        `uvm_fatal("CFG","Missing sequencer configuration")
    endfunction
  endclass

