// ============================================================================
// mod_mul.sv  --  Pipelined modular multiplier for q = 8380417 = 2^23-2^13+1
// ----------------------------------------------------------------------------
// Computes  (a * b) mod q  using a q-SPECIFIC SHIFT-ADD reduction -- NO Barrett
// multipliers. Only ONE multiplier per call (the a*b product); the reduction
// is pure shift + add.
//
// Reduction principle.  q = 2^23 - 2^13 + 1  =>  2^23 ≡ 2^13 - 1  (mod q).
// So the high part of any value (bit 23 and above) folds down:
//
//   fold(x):  hi = x >> 23,  lo = x[22:0]
//             x ≡ hi*(2^13 - 1) + lo  =  (hi<<13) - hi + lo   (mod q)
//
// fold() is monotone-shrinking and its result is always >= 0 (since
// (hi<<13) >= hi). Applied to the 46-bit product a*b, four folds bring the
// value below 2q; one conditional subtract finishes into [0, q):
//
//   product (46-bit)
//     --fold-->  < 2^37   (hi up to 2^23)
//     --fold-->  < 2^28   (hi up to 2^14)
//     --fold-->  < 2^24   (hi up to 2^5)
//     --fold-->  < 2q     (hi is a single bit)
//     --(>=q ? -q)-->  [0, q)
//
// Latency: 3 clock cycles (LAT) -- UNCHANGED from the Barrett version, so the
// butterfly_unit / ntt_core pipeline constants are untouched. Fully pipelined:
// accepts a new pair every cycle, `r_o` valid LAT cycles after the inputs.
//   Stage 1 : prod = a*b                (the only multiply)
//   Stage 2 : folds 1 and 2             (shift-add)
//   Stage 3 : folds 3 and 4 + cond. sub (shift-add)
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

  // ---- Stage 1 : 23 x 23 -> 46-bit product (the ONLY multiply) ------------
  logic [PROD_W-1:0] prod_s1;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) prod_s1 <= '0;
    else     prod_s1 <= a_i * b_i;
  end

  // ---- q-specific fold:  x -> (hi<<13) - hi + lo  (mod q preserved) -------
  //   hi = x>>23, lo = x[22:0]. Input <= 46 bits; output <= 38 bits.
  //   Always >= 0 because (hi<<13) >= hi for hi >= 0.
  function automatic logic [37:0] fold(input logic [45:0] x);
    logic [22:0] hi, lo;
    logic [37:0] hs;
    hi = x[45:23];
    lo = x[22:0];
    hs = {2'b00, hi, 13'b0};            // hi << 13  (36-bit value in 38 bits)
    return hs - 38'(hi) + 38'(lo);      // (hi<<13) - hi + lo  (>= 0)
  endfunction

  // ---- Stage 2 : folds 1 + 2  (46-bit product -> < 2^28) ------------------
  logic [37:0] s2_t1, s2_t2;
  logic [27:0] t2_q;

  always_comb begin
    s2_t1 = fold(prod_s1);              // < 2^37
    s2_t2 = fold(46'(s2_t1));           // < 2^28
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) t2_q <= '0;
    else     t2_q <= s2_t2[27:0];
  end

  // ---- Stage 3 : folds 3 + 4, then one conditional subtract -> [0, q) -----
  logic [37:0] s3_t3, s3_t4;
  logic [23:0] t4;

  always_comb begin
    s3_t3 = fold(46'(t2_q));            // < 2^24
    s3_t4 = fold(46'(s3_t3));           // < 2q  (hi is a single bit)
    t4    = s3_t4[23:0];
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) r_o <= '0;
    else     r_o <= (t4 >= Q) ? COEFF_W'(t4 - Q) : t4[COEFF_W-1:0];
  end

endmodule : mod_mul
