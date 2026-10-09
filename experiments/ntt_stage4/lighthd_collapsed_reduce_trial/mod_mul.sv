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
//   Stage 3 : collapsed folds 2/3        (shift-add + 8-entry correction)
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

  // ---- Stage 3 : collapse folds 2/3 with a small high-part correction ----
  // t1 = L + 2^23*H; split H = 1024*H_hi + H_lo.
  // Since 1024*8191 = q + 7167, the congruent value is
  // T = L + (H_lo<<13) - H_lo + 7167*H_hi.
  // T <= 16,818,169 (can exceed 2*q). Subtract q here if needed;
  // the unchanged final stage performs the remaining canonical correction.
  // Stage-3 value <= 8,437,752, below the final stage's 8,454,135 bound.
  // Parallel carry-save raw/biased candidates avoid serial fold carry chains.
  logic [24:0] s3_low, s3_high_shift, s3_neg_high, s3_high_fix;
  logic [24:0] s3_save1, s3_carry1, s3_save2, s3_carry2;
  logic [24:0] s3_save_bias, s3_carry_bias, s3_raw, s3_biased;
  localparam logic [24:0] S3_BIAS = 25'(16777216-Q);
  logic [23:0] t3_q;
  always_comb begin
    s3_low = {2'b0,t1_q[22:0]};
    s3_high_shift = {2'b0,t1_q[32:23],13'b0};
    s3_neg_high = ~{15'b0,t1_q[32:23]};
    case (t1_q[35:33])
      3'd0: s3_high_fix = 25'd0;
      3'd1: s3_high_fix = 25'd7167;
      3'd2: s3_high_fix = 25'd14334;
      3'd3: s3_high_fix = 25'd21501;
      3'd4: s3_high_fix = 25'd28668;
      3'd5: s3_high_fix = 25'd35835;
      3'd6: s3_high_fix = 25'd43002;
      3'd7: s3_high_fix = 25'd50169;
      default: s3_high_fix = 'x;
    endcase
    s3_save1 = s3_low ^ s3_high_shift ^ s3_neg_high;
    s3_carry1 = ((s3_low & s3_high_shift) | (s3_low & s3_neg_high) |
                 (s3_high_shift & s3_neg_high)) << 1;
    s3_save2 = s3_save1 ^ s3_carry1 ^ s3_high_fix;
    s3_carry2 = ((s3_save1 & s3_carry1) | (s3_save1 & s3_high_fix) |
                 (s3_carry1 & s3_high_fix)) << 1;
    s3_raw = s3_save2 + {s3_carry2[24:1],1'b1};
    s3_save_bias = s3_save2 ^ s3_carry2 ^ S3_BIAS;
    s3_carry_bias = ((s3_save2 & s3_carry2) | (s3_save2 & S3_BIAS) |
                     (s3_carry2 & S3_BIAS)) << 1;
    s3_biased = s3_save_bias + {s3_carry_bias[24:1],1'b1};
  end
  always_ff @(posedge clk or posedge rst) begin
    if (rst) t3_q <= '0;
    else t3_q <= s3_biased[24] ? s3_biased[23:0] : s3_raw[23:0];
  end

  // ---- Stage 4 : specialized one-bit fold + canonical reduction --------
  // For any 23-bit a/b, fold 3 <= 8,454,135. If bit 23 is set, its low
  // part <= 65,527: adding 8191 folds it to <= 73,718, already below q.
  // Otherwise fold 4 is the low part itself. low+8191 carries at bit 23
  // exactly when low >= q, and its low bits then equal low-q.
  // Thus one 24-bit addition supplies both cases, eliminating the measured
  // serial final-fold -> comparison -> subtraction path. LAT stays four.
  logic [COEFF_W:0] biased_low;
  logic [COEFF_W-1:0] canonical;
  always_comb begin
    biased_low = {1'b0,t3_q[COEFF_W-1:0]} + (COEFF_W+1)'(8191);
    canonical = (t3_q[COEFF_W] || biased_low[COEFF_W])
              ? biased_low[COEFF_W-1:0] : t3_q[COEFF_W-1:0];
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) r_o <= '0;
    else     r_o <= canonical;
  end

endmodule : mod_mul
