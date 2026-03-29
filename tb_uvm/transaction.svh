class adder_txn extends uvm_sequence_item;

  rand logic [7:0] a, b;
       logic [8:0] sum;

  `uvm_object_utils(adder_txn)

  function new(string name="adder_txn");
    super.new(name);
  endfunction

endclass