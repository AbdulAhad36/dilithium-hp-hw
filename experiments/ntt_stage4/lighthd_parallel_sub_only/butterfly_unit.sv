// ============================================================================
// butterfly_unit.sv  --  Configurable radix-2 NTT butterfly (CT / GS)
// ----------------------------------------------------------------------------
// mode = BF_CT  (Cooley-Tukey, forward NTT):
//     t   = b * zeta            (mod q)
//     a'  = a + t               (mod q)
//     b'  = a - t               (mod q)
//
// mode = BF_GS  (Gentleman-Sande, inverse NTT):
//     a'  = a + b               (mod q)
//     b'  = (a - b) * zeta      (mod q)
//
// Both modes share one pipelined modular multiplier. Fixed latency BF_LAT = 6
// cycles, fully pipelined (one butterfly per clock).
//
//   cycle 1 : registered (CT: b) / (GS: a-b) and zeta feed multiplier
//   cycle 5 : mul result `t` ready; combine with delayed operand
//   cycle 6 : a_o / b_o registered out
// ============================================================================
import ntt_pkg::*;

module butterfly_unit (
    input  logic                clk,
    input  logic                rst,
    input  bf_mode_e             mode_i,
    input  logic [COEFF_W-1:0]  a_i,
    input  logic [COEFF_W-1:0]  b_i,
    input  logic [COEFF_W-1:0]  zeta_i,
    output logic [COEFF_W-1:0]  a_o,
    output logic [COEFF_W-1:0]  b_o
);

  localparam int unsigned BF_LAT  = 6;
  localparam int unsigned MUL_LAT = 4;   // mod_mul latency

  // ---- combinational modular add / sub helpers ----------------------------
  function automatic logic [COEFF_W-1:0] madd(input logic [COEFF_W-1:0] x,
                                              input logic [COEFF_W-1:0] y);
    logic [COEFF_W:0] raw_sum, biased_sum, save_bits, majority;
    logic [COEFF_W:0] x_ext, y_ext, bias;
    x_ext = {1'b0,x}; y_ext = {1'b0,y};
    bias = (COEFF_W+1)'((1<<COEFF_W)-Q); // 8191
    raw_sum = x_ext + y_ext;
    // For canonical x/y, x+y+8191 < 2^24. Bit 23 is set exactly when
    // x+y >= q. Its low 23 bits already equal x+y-q in that case.
    // Compute the biased candidate with a three-input compressor and
    // one carry chain, in parallel with the uncorrected sum.
    save_bits = x_ext ^ y_ext ^ bias;
    majority = (x_ext & y_ext) | (x_ext & bias) | (y_ext & bias);
    biased_sum = save_bits + {majority[COEFF_W-1:0],1'b0};
    return biased_sum[COEFF_W] ? biased_sum[COEFF_W-1:0]
                              : raw_sum[COEFF_W-1:0];
  endfunction

  function automatic logic [COEFF_W-1:0] msub(input logic [COEFF_W-1:0] x,
                                              input logic [COEFF_W-1:0] y);
    logic [COEFF_W:0] raw_diff, corrected_diff, save_bits, majority;
    logic [COEFF_W:0] x_ext, neg_y, modulus;
    x_ext = {1'b0,x};
    neg_y = ~{1'b0,y};
    modulus = (COEFF_W+1)'(Q);
    raw_diff = x_ext - {1'b0,y};
    // For canonical x/y, the 24-bit wrapped difference has bit 23 set
    // exactly when x<y. Compute x-y+q independently as x+~y+q+1;
    // compress the three operands and put +1 in the zero carry bit.
    // Both candidate carry chains run in parallel, then borrow selects.
    save_bits = x_ext ^ neg_y ^ modulus;
    majority = (x_ext & neg_y) | (x_ext & modulus) | (neg_y & modulus);
    corrected_diff = save_bits + {majority[COEFF_W-1:0],1'b1};
    return raw_diff[COEFF_W] ? corrected_diff[COEFF_W-1:0]
                            : raw_diff[COEFF_W-1:0];
  endfunction

  // ---- multiplier operand select ------------------------------------------
  // Register CT and GS candidates independently. Select the registered
  // candidate in the multiplier stage, separating GS subtraction from DSP.
  logic [COEFF_W-1:0] mul_ct_reg, mul_gs_reg;
  logic [COEFF_W-1:0] zeta_reg, keep_a_reg;
  logic [COEFF_W:0] keep_sum_reg;
  logic [COEFF_W-1:0] mul_after_reg;
  bf_mode_e mode_reg;
  always_comb mul_after_reg = (mode_reg == BF_CT) ? mul_ct_reg : mul_gs_reg;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      mul_ct_reg <= '0;
      mul_gs_reg <= '0;
      zeta_reg   <= '0;
      keep_a_reg <= '0;
      keep_sum_reg <= '0;
      mode_reg   <= BF_CT;
    end else begin
      mul_ct_reg <= b_i;
      mul_gs_reg <= msub(a_i, b_i);
      zeta_reg   <= zeta_i;
      keep_a_reg <= a_i;
      // Register the raw GS sum before reducing it in the next stage.
      // This replaces keep_b_reg; it does not add a pipeline cycle.
      keep_sum_reg <= {1'b0, a_i} + {1'b0, b_i};
      mode_reg   <= mode_i;
    end
  end

  logic [COEFF_W-1:0] t;        // = selected operand * zeta (mod q)
  mod_mul u_mul (
      .clk (clk),
      .rst (rst),
      .a_i (mul_after_reg),
      .b_i (zeta_reg),
      .r_o (t)
  );

  // ---- operand to be combined with `t` ------------------------------------
  // CT keeps `a`; GS reduces the sum registered in the input stage.
  // Addition and compare/subtract now occupy separate existing stages.
  logic [COEFF_W-1:0] keep_after_reg;
  always_comb keep_after_reg = (mode_reg == BF_CT)
                             ? keep_a_reg : ((keep_sum_reg >= Q)
                               ? COEFF_W'(keep_sum_reg - Q)
                               : keep_sum_reg[COEFF_W-1:0]);

  logic [COEFF_W-1:0] keep_dly [MUL_LAT];
  bf_mode_e            mode_dly [MUL_LAT];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < MUL_LAT; i++) begin
        keep_dly[i] <= '0;
        mode_dly[i] <= BF_CT;
      end
    end else begin
      keep_dly[0] <= keep_after_reg;
      mode_dly[0] <= mode_reg;
      for (int i = 1; i < MUL_LAT; i++) begin
        keep_dly[i] <= keep_dly[i-1];
        mode_dly[i] <= mode_dly[i-1];
      end
    end
  end

  // ---- final combine (cycle 5 -> registered at cycle 6) -------------------
  logic [COEFF_W-1:0] keep_al;
  bf_mode_e            mode_al;
  always_comb begin
    keep_al = keep_dly[MUL_LAT-1];
    mode_al = mode_dly[MUL_LAT-1];
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      a_o <= '0;
      b_o <= '0;
    end else if (mode_al == BF_CT) begin
      a_o <= madd(keep_al, t);   // a + t
      b_o <= msub(keep_al, t);   // a - t
    end else begin
      a_o <= keep_al;            // a + b
      b_o <= t;                  // (a-b)*zeta
    end
  end

endmodule : butterfly_unit
