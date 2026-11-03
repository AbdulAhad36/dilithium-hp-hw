// Legacy CT/GS pin convention. Production ntt_core uses the published
// reducer-first order directly;standalone scalar callers keep (x,y).
import ntt_pkg::*;
module butterfly_unit (
  input logic clk,rst,input bf_mode_e mode_i,
  input logic [COEFF_W-1:0] a_i,b_i,zeta_i,
  output logic [COEFF_W-1:0] a_o,b_o
);
  butterfly_fused #(.PUBLISHED_ORDER(0)) published(
    .clk(clk),.rst(rst),.mode_i(mode_i),.a_i(a_i),.b_i(b_i),
    .zeta_i(zeta_i),.a_o(a_o),.b_o(b_o));
endmodule
