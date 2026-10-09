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
// For any 23-bit operands the conservative successive fold bounds are
// 68,719,460,353 (36 bits), 75,481,088 (27 bits), 8,454,135 (24 bits).
// The third fold is already below 2q, so one subtraction makes it canonical.
//
// Latency: 4 clock cycles (LAT), accepting a new pair every cycle.
//   Stage 1 : prod = a*b                (the only multiply)
//   Stage 2 : fold 1                    (shift-add)
//   Stage 3 : fold 2                    (shift-add)
//   Stage 4 : fold 3 + canonical correction, parallel carry-save candidates
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

  // ---- Stage 3 : fold 2 (36 bits -> at most 27 bits) -------------------
  // Isolate one fold in this stage instead of two serial carry chains.
  logic [37:0] s3_t2;
  logic [26:0] t2_q;
  always_comb s3_t2 = fold(46'(t1_q));
  always_ff @(posedge clk or posedge rst) begin
    if (rst) t2_q <= '0;
    else     t2_q <= s3_t2[26:0];
  end

  // ---- Stage 4 : fold 3 + parallel canonical correction ---------------
  // H=t2>>23 <= 8; T=low+(H<<13)-H <= 8,454,135 < 2q.
  // T+8191 has bit 23 set exactly when T>=q; its low 23 bits then
  // equal T-q. T+8191 < 2^24, including the T>=2^23 case.
  // Compress low, H<<13 and ~H; the carry word's zero bit 0 holds +1.
  // Raw T and T+8191 propagate their carries in parallel, then select.
  // No extra register or latency; BF/core return alignment is unchanged.
  logic [23:0] s4_low, s4_high_shift, s4_neg_high;
  logic [23:0] s4_save, s4_carry, s4_bias_save, s4_bias_carry;
  logic [23:0] s4_raw, s4_biased;
  logic [COEFF_W-1:0] canonical;
  always_comb begin
    s4_low = {1'b0,t2_q[22:0]};
    s4_high_shift = {7'b0,t2_q[26:23],13'b0};
    s4_neg_high = ~{20'b0,t2_q[26:23]};
    s4_save = s4_low ^ s4_high_shift ^ s4_neg_high;
    s4_carry = ((s4_low & s4_high_shift) | (s4_low & s4_neg_high) |
                (s4_high_shift & s4_neg_high)) << 1;
    s4_raw = s4_save + {s4_carry[23:1],1'b1};
    s4_bias_save = s4_save ^ s4_carry ^ 24'd8191;
    s4_bias_carry = ((s4_save & s4_carry) | (s4_save & 24'd8191) |
                     (s4_carry & 24'd8191)) << 1;
    s4_biased = s4_bias_save + {s4_bias_carry[23:1],1'b1};
    canonical = s4_biased[23] ? s4_biased[22:0] : s4_raw[22:0];
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) r_o <= '0;
    else     r_o <= canonical;
  end

endmodule : mod_mul
