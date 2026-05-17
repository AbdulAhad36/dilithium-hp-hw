// ============================================================================
// ntt_pkg.sv  --  Parameters and constants for the Dilithium NTT engine
// ----------------------------------------------------------------------------
// Ring:      Z_q[x] / (x^256 + 1)   (negacyclic)
// n      = 256        polynomial degree
// q      = 8380417    NTT-friendly prime, q = 2^23 - 2^13 + 1
// zeta   = 1753       primitive 512-th (= 2n-th) root of unity mod q
//
// The negacyclic twist is folded into the twiddle factors using the standard
// Dilithium convention: twiddle[i] = zeta^( bitreverse8(i) ) mod q.
// ============================================================================
package ntt_pkg;

  // ---- Ring parameters --------------------------------------------------
  localparam int unsigned Q        = 8380417;   // modulus
  localparam int unsigned N        = 256;       // number of coefficients
  localparam int unsigned LOGN     = 8;         // log2(N) = number of radix-2 stages
  localparam int unsigned COEFF_W  = 23;        // bits to hold a coeff in [0, q-1]
  localparam int unsigned ZETA     = 1753;      // 2n-th root of unity
  localparam int unsigned N_INV    = 8347681;   // 256^-1 mod q  (INTT final scaling)

  // ---- Barrett reduction constants -------------------------------------
  // Reduces a 46-bit product P (= a*b, a,b < q) modulo q.
  //   est = (P * BARRETT_M) >> BARRETT_K
  //   r   = P - est*q          -> r in [0, 2q)
  //   result = (r >= q) ? r-q : r        (at most ONE conditional subtract)
  localparam int unsigned BARRETT_K = 46;
  localparam int unsigned BARRETT_M = 8396807;  // floor(2^46 / q), 24-bit

  localparam int unsigned PROD_W  = 2*COEFF_W;  // 46  - product width
  localparam int unsigned BM_W    = 24;         // BARRETT_M width

  // ---- Datapath parallelism --------------------------------------------
  // The NTT core uses a 2x2 butterfly tile: 4 coefficients in / 4 out per
  // cycle, advancing TWO radix-2 stages per pass -> N/2 stages collapse to
  // LOGN/2 = 4 passes over the coefficient memory.
  localparam int unsigned COEFFS_PER_CYCLE = 4;
  localparam int unsigned N_PASSES         = LOGN/2;  // = 4

  // ---- Butterfly mode ---------------------------------------------------
  typedef enum logic {
    BF_CT = 1'b0,   // Cooley-Tukey   : used for forward NTT
    BF_GS = 1'b1    // Gentleman-Sande: used for inverse NTT
  } bf_mode_e;

  // ---- Engine operation -------------------------------------------------
  typedef enum logic [1:0] {
    OP_NTT  = 2'd0,   // forward NTT
    OP_INTT = 2'd1,   // inverse NTT (includes 1/N scaling)
    OP_PWM  = 2'd2    // point-wise multiplication (NTT domain)
  } ntt_op_e;

endpackage : ntt_pkg
