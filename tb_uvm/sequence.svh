class adder_sequence extends uvm_sequence #(adder_txn);

  `uvm_object_utils(adder_sequence)

  function new(string name = "adder_sequence");
    super.new(name);
  endfunction

  task body();
    adder_txn tx;

    repeat (10) begin
      tx = adder_txn::type_id::create("tx");
      start_item(tx);
      tx.randomize();
      finish_item(tx);
    end
  endtask

endclass