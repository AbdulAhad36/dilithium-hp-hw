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
// Latency: 4 clock cycles (LAT). Fully pipelined:
// accepts a new pair every cycle, `r_o` valid LAT cycles after the inputs.
//   Stage 1 : prod = a*b                (the only multiply)
//   Stage 2 : fold 1                    (shift-add)
//   Stage 3 : folds 2 and 3             (shift-add)
//   Stage 4 : fold 4 + cond. sub        (shift-add)
// ============================================================================
import ntt_pkg::*;

module mod_mul (
    input  logic                clk,
    input  logic                rst,
    input  logic [COEFF_W-1:0]  a_i,
    input  logic [COEFF_W-1:0]  b_i,
    output logic [COEFF_W-1:0]  r_o
);

  localparam int unsigned LAT = 4;

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
    logic [37:0] hs, lo_ext, neg_hi;
    logic [37:0] save_bits, majority;
    hi = x[45:23];
    lo = x[22:0];
    hs = {2'b00, hi, 13'b0};            // hi << 13  (36-bit value in 38 bits)
    lo_ext = 38'(lo);
    neg_hi = ~{15'b0, hi};
    // hs + lo - hi = hs + lo + ~hi + 1 (modulo 2^38).
    // Compress the three operands without propagating a carry. Inject the
    // subtraction's +1 into the otherwise-zero carry bit 0, then use ONE
    // carry-propagate adder. The exact nonnegative result fits 38 bits.
    save_bits = hs ^ lo_ext ^ neg_hi;
    majority = (hs & lo_ext) | (hs & neg_hi) | (lo_ext & neg_hi);
    return save_bits + {majority[36:0], 1'b1};
  endfunction

  // ---- Stage 2 : fold 1 (46-bit product -> at most 36 bits) ------------
  // The former two-fold stage was the measured routed critical path.
  // Rebalance the same four-cycle pipeline; do not change BF/core latency.
  logic [37:0] s2_t1;
  logic [35:0] t1_q;
  always_comb s2_t1 = fold(prod_s1);
  always_ff @(posedge clk or posedge rst) begin
    if (rst) t1_q <= '0;
    else     t1_q <= s2_t1[35:0];
  end

  // ---- Stage 3 : folds 2 + 3 (36 bits -> at most 24 bits) ---------------
  // Their narrower carry chains fit here better than folding the 46-bit
  // product twice in Stage 2. The exact congruence and final result are unchanged.
  logic [37:0] s3_t2, s3_t3;
  logic [23:0] t3_q;
  always_comb begin
    s3_t2 = fold(46'(t1_q));
    s3_t3 = fold(46'(s3_t2));
  end
  always_ff @(posedge clk or posedge rst) begin
    if (rst) t3_q <= '0;
    else     t3_q <= s3_t3[23:0];
  end

  // ---- Stage 4 : fold 4 + conditional subtract -> [0, q) ------------------
  logic [37:0] s4_t4;
  logic [23:0] t4;

  always_comb begin
    s4_t4 = fold(46'(t3_q));            // < 2q  (hi is a single bit)
    t4    = s4_t4[23:0];
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) r_o <= '0;
    else     r_o <= (t4 >= Q) ? COEFF_W'(t4 - Q) : t4[COEFF_W-1:0];
  end

endmodule : mod_mul
