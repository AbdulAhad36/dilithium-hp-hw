module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  adder_if vif();

  // DUT
  adder dut (
    .a(vif.a),
    .b(vif.b),
    .sum(vif.sum)
  );

  initial begin
    uvm_config_db#(virtual adder_if)::set(null, "*", "vif", vif);
    run_test("adder_test");
  end

endmodule