class adder_scoreboard extends uvm_component;

  `uvm_component_utils(adder_scoreboard)

  uvm_analysis_imp #(adder_txn, adder_scoreboard) imp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
  endfunction

  function void write(adder_txn txn);

    if (txn.sum !== (txn.a + txn.b)) begin
      `uvm_error("SB", "Mismatch detected!")
    end else begin
      `uvm_info("SB", "Correct result", UVM_LOW)
    end

  endfunction

endclass