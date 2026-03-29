class adder_driver extends uvm_driver #(adder_txn);

  `uvm_component_utils(adder_driver)

  virtual adder_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      adder_txn txn;
      seq_item_port.get_next_item(txn);

      vif.a = txn.a;
      vif.b = txn.b;

      #10;

      seq_item_port.item_done();
    end
  endtask

endclass