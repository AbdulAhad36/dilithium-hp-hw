// ============================================================================
// mod_mul.sv  --  Pipelined modular multiplier for q = 8380417
// ----------------------------------------------------------------------------
// Computes  (a * b) mod q  using Barrett reduction.
//
//   prod = a * b                              (46-bit, a,b < q)
//   est  = (prod * BARRETT_M) >> BARRETT_K     (Barrett estimate)
//   r    = prod - est*q                        -> r in [0, 2q)
//   out  = (r >= q) ? r - q : r                (one conditional subtract)
//
// Latency: 3 clock cycles (LAT). Fully pipelined: accepts a new pair every
// cycle. `out` is valid LAT cycles after the inputs are presented.
// ============================================================================
import ntt_pkg::*;

module mod_mul (
    input  logic                clk,
    input  logic                rst,
    input  logic [COEFF_W-1:0]  a_i,
    input  logic [COEFF_W-1:0]  b_i,
    output logic [COEFF_W-1:0]  r_o
);

  localparam int unsigned LAT = 3;

  // ---- Stage 1 : 23 x 23 -> 46-bit product --------------------------------
  logic [PROD_W-1:0] prod_s1;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) prod_s1 <= '0;
    else     prod_s1 <= a_i * b_i;
  end

  // ---- Stage 2 : Barrett estimate  est = (prod*M) >> K --------------------
  // prod_s1 (46-bit) * BARRETT_M (24-bit) needs the FULL 70-bit product width.
  // Both operands are cast to EST_W so the multiply is not truncated to the
  // context width before the >> BARRETT_K shift.
  localparam int unsigned EST_W = PROD_W + BM_W;   // 70

  logic [PROD_W-1:0]            prod_s2;
  logic [BM_W-1:0]              est_s2;
  logic [EST_W-1:0]             bm_prod;           // full-width prod_s1 * M

  always_comb
    bm_prod = EST_W'(prod_s1) * EST_W'(BARRETT_M);

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      prod_s2 <= '0;
      est_s2  <= '0;
    end else begin
      prod_s2 <= prod_s1;
      est_s2  <= (bm_prod >> BARRETT_K);
    end
  end

  // ---- Stage 3 : r = prod - est*q, then conditional subtract --------------
  logic [PROD_W:0]  r_wide;
  logic [COEFF_W:0] r_trim;   // r is < 2q, fits in COEFF_W+1 bits

  always_comb begin
    r_wide = $unsigned(prod_s2) - (est_s2 * Q);
    r_trim = r_wide[COEFF_W:0];
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) r_o <= '0;
    else     r_o <= (r_trim >= Q) ? (r_trim - Q) : r_trim[COEFF_W-1:0];
  end

endmodule : mod_mul
