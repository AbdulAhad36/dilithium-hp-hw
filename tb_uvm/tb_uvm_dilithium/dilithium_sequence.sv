  class dilithium_sequence extends uvm_sequence#(dilithium_transaction);
    `uvm_object_utils(dilithium_sequence)
    `uvm_declare_p_sequencer(dilithium_sequencer)
    dilithium_config cfg;
    function new(string name="dilithium_sequence");super.new(name);endfunction
    task body();
      if(cfg==null)cfg=p_sequencer.cfg;
      if(cfg==null)`uvm_fatal("CFG","Missing sequence configuration")
      foreach(cfg.cases[i])begin start_item(cfg.cases[i]);finish_item(cfg.cases[i]);end
    endtask
  endclass

// Keep NIST cryptographic inputs intact while varying transport pressure.
class dilithium_random_stall_sequence extends dilithium_sequence;
  `uvm_object_utils(dilithium_random_stall_sequence)
  function new(string name="dilithium_random_stall_sequence");
    super.new(name);
  endfunction
  task body();
    dilithium_transaction item;
    int stall_profile;
    if(cfg==null)cfg=p_sequencer.cfg;
    if(cfg==null)`uvm_fatal("CFG","Missing random sequence configuration")
    foreach(cfg.cases[i])begin
      item=dilithium_transaction::type_id::create($sformatf("random_case_%0d",i));
      item.copy(cfg.cases[i]);
      if(!std::randomize(stall_profile) with {stall_profile inside {[0:2]};})
        `uvm_fatal("RANDOMIZE","Cannot select bounded stall profile")
      item.profile=stall_profile;
      `uvm_info("RANDOM_PROFILE",$sformatf("case%0d profile%0d",i,stall_profile),UVM_LOW)
      start_item(item);finish_item(item);
    end
  endtask
endclass
