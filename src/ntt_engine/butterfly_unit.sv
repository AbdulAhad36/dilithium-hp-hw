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
// Both modes share one pipelined modular multiplier. Fixed latency BF_LAT = 4
// cycles, fully pipelined (one butterfly per clock).
//
//   cycle 0 : mul fed with  (CT: b) / (GS: a-b)
//   cycle 3 : mul result `t` ready; combine with the 3-cycle-delayed operand
//   cycle 4 : a_o / b_o registered out
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

  localparam int unsigned BF_LAT  = 4;
  localparam int unsigned MUL_LAT = 3;   // mod_mul latency

  // ---- combinational modular add / sub helpers ----------------------------
  function automatic logic [COEFF_W-1:0] madd(input logic [COEFF_W-1:0] x,
                                              input logic [COEFF_W-1:0] y);
    logic [COEFF_W:0] s;
    s = x + y;
    return (s >= Q) ? (s - Q) : s[COEFF_W-1:0];
  endfunction

  function automatic logic [COEFF_W-1:0] msub(input logic [COEFF_W-1:0] x,
                                              input logic [COEFF_W-1:0] y);
    return (x >= y) ? (x - y) : (x + Q - y);
  endfunction

  // ---- multiplier operand select ------------------------------------------
  // CT multiplies b by zeta; GS multiplies (a-b) by zeta.
  logic [COEFF_W-1:0] mul_in;
  always_comb mul_in = (mode_i == BF_CT) ? b_i : msub(a_i, b_i);

  logic [COEFF_W-1:0] t;        // = mul_in * zeta  (mod q), ready after MUL_LAT
  mod_mul u_mul (
      .clk (clk),
      .rst (rst),
      .a_i (mul_in),
      .b_i (zeta_i),
      .r_o (t)
  );

  // ---- operand to be combined with `t` ------------------------------------
  // CT keeps `a`; GS keeps `a+b`. Delayed MUL_LAT cycles to align with `t`.
  logic [COEFF_W-1:0] keep_in;
  always_comb keep_in = (mode_i == BF_CT) ? a_i : madd(a_i, b_i);

  logic [COEFF_W-1:0] keep_dly [MUL_LAT];
  bf_mode_e            mode_dly [MUL_LAT];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < MUL_LAT; i++) begin
        keep_dly[i] <= '0;
        mode_dly[i] <= BF_CT;
      end
    end else begin
      keep_dly[0] <= keep_in;
      mode_dly[0] <= mode_i;
      for (int i = 1; i < MUL_LAT; i++) begin
        keep_dly[i] <= keep_dly[i-1];
        mode_dly[i] <= mode_dly[i-1];
      end
    end
  end

  // ---- final combine (cycle 3 -> registered at cycle 4) -------------------
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
