class adder_monitor extends uvm_component;

  `uvm_component_utils(adder_monitor)

  virtual adder_if vif;
  uvm_analysis_port #(adder_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      adder_txn txn = new();

      txn.a   = vif.a;
      txn.b   = vif.b;
      txn.sum = vif.sum;

      ap.write(txn);

      #10;
    end
  endtask

endclass