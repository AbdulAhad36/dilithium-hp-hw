// ============================================================================
// ntt_ref_pkg.sv  --  Pure-SystemVerilog golden reference for the Dilithium NTT
// ----------------------------------------------------------------------------
// This package is the TRUSTED reference model against which the ntt_core RTL
// is golden-compared. It implements, in plain SystemVerilog (no DUT, no clock):
//
//   ntt_fwd   forward NTT      (Cooley-Tukey, in-place, 8 radix-2 stages)
//   ntt_inv   inverse NTT      (Gentleman-Sande, in-place) + 1/N scaling
//   pwm       point-wise multiply of two NTT-domain polynomials
//   poly_mul  negacyclic schoolbook multiply  c = a*b mod (x^256+1, q)
//
// The forward/inverse routines are a direct port of the CRYSTALS-Dilithium
// reference C (`ntt()` / `invntt_tomont()`), kept in the NORMAL integer domain
// (no Montgomery): the reference's Montgomery `fqmul` becomes a plain modular
// multiply, and the final `f = mont^2/256` scaling becomes a plain x N_INV.
//
// Twiddle factors are computed here independently  (tw(k) = zeta^brv8(k) mod q)
// rather than read from twiddle_rom.sv -- so this model also cross-checks the
// ROM table.
//
// Self-consistency is proven by tb_ntt_ref.sv:
//   * round-trip      ntt_inv(ntt_fwd(a))                 == a
//   * multiply        ntt_inv(pwm(ntt_fwd(a),ntt_fwd(b))) == poly_mul(a,b)
// ============================================================================
package ntt_ref_pkg;

  import ntt_pkg::*;

  // A coefficient in [0, q-1] and a degree-256 polynomial.
  typedef logic [COEFF_W-1:0] coeff_t;
  typedef coeff_t             poly_t [N];

  // --------------------------------------------------------------------------
  // Modular arithmetic mod q = 8380417
  // --------------------------------------------------------------------------
  function automatic coeff_t addm(input coeff_t x, input coeff_t y);
    logic [COEFF_W:0] s;
    s = x + y;
    return (s >= Q) ? coeff_t'(s - Q) : coeff_t'(s);
  endfunction

  function automatic coeff_t subm(input coeff_t x, input coeff_t y);
    return (x >= y) ? coeff_t'(x - y) : coeff_t'(x + Q - y);
  endfunction

  function automatic coeff_t mulm(input coeff_t x, input coeff_t y);
    longint unsigned p;
    p = longint'(x) * longint'(y);     // <= (2^23)^2, fits in 64 bits
    return coeff_t'(p % Q);
  endfunction

  // x ^ e  mod q  (square-and-multiply)
  function automatic coeff_t powm(input coeff_t x, input int unsigned e);
    coeff_t       r;
    coeff_t       b;
    int unsigned  ee;
    r  = coeff_t'(1);
    b  = x;
    ee = e;
    while (ee > 0) begin
      if (ee[0]) r = mulm(r, b);
      b  = mulm(b, b);
      ee = ee >> 1;
    end
    return r;
  endfunction

  // --------------------------------------------------------------------------
  // Twiddle factor  tw(k) = zeta ^ bitreverse8(k)  mod q   (zeta = 1753)
  // Matches the standard Dilithium `zetas[]` ordering (normal domain).
  // --------------------------------------------------------------------------
  function automatic int unsigned brv8(input int unsigned x);
    int unsigned r;
    r = 0;
    for (int i = 0; i < LOGN; i++) r[i] = x[LOGN-1-i];
    return r;
  endfunction

  function automatic coeff_t tw(input int unsigned k);
    return powm(coeff_t'(ZETA), brv8(k));
  endfunction

  // --------------------------------------------------------------------------
  // Forward NTT  -- Cooley-Tukey, in-place, 8 radix-2 stages.
  // Port of Dilithium reference ntt():
  //   k = 0
  //   for len = 128,64,...,1:
  //     for start = 0; start < N; start += 2*len:
  //       zeta = zetas[++k]
  //       for j = start..start+len-1:
  //         t = zeta * a[j+len];  a[j+len] = a[j]-t;  a[j] = a[j]+t
  // --------------------------------------------------------------------------
  function automatic poly_t ntt_fwd(input poly_t a);
    poly_t        r;
    int unsigned  k;
    coeff_t       z, t;
    r = a;
    k = 0;
    for (int len = N/2; len >= 1; len = len >> 1) begin
      for (int start = 0; start < N; start = start + 2*len) begin
        k = k + 1;
        z = tw(k);
        for (int j = start; j < start + len; j++) begin
          t          = mulm(z, r[j+len]);
          r[j+len]   = subm(r[j], t);
          r[j]       = addm(r[j], t);
        end
      end
    end
    return r;
  endfunction

  // --------------------------------------------------------------------------
  // Inverse NTT  -- Gentleman-Sande, in-place, then x N_INV (the 1/256 scale).
  // Port of Dilithium reference invntt_tomont():
  //   k = 256
  //   for len = 1,2,...,128:
  //     for start = 0; start < N; start += 2*len:
  //       zeta = -zetas[--k]
  //       for j = start..start+len-1:
  //         t = a[j];  a[j] = t+a[j+len];  a[j+len] = zeta*(t-a[j+len])
  //   for j: a[j] = a[j] * N_INV
  // --------------------------------------------------------------------------
  function automatic poly_t ntt_inv(input poly_t a);
    poly_t        r;
    int unsigned  k;
    coeff_t       z, t;
    r = a;
    k = N;
    for (int len = 1; len < N; len = len << 1) begin
      for (int start = 0; start < N; start = start + 2*len) begin
        k = k - 1;
        z = subm(coeff_t'(0), tw(k));            // -zetas[k]  mod q
        for (int j = start; j < start + len; j++) begin
          t          = r[j];
          r[j]       = addm(t, r[j+len]);
          r[j+len]   = mulm(z, subm(t, r[j+len]));
        end
      end
    end
    for (int j = 0; j < N; j++)
      r[j] = mulm(r[j], coeff_t'(N_INV));        // 1/N scaling
    return r;
  endfunction

  // --------------------------------------------------------------------------
  // Point-wise multiply of two NTT-domain polynomials.
  // --------------------------------------------------------------------------
  function automatic poly_t pwm(input poly_t a, input poly_t b);
    poly_t r;
    for (int i = 0; i < N; i++) r[i] = mulm(a[i], b[i]);
    return r;
  endfunction

  // --------------------------------------------------------------------------
  // Negacyclic schoolbook multiply:  c = a * b  mod (x^256 + 1, q).
  // Independent O(N^2) reference -- terms that overshoot degree 256 wrap back
  // NEGATED (x^256 = -1). Used to cross-check the NTT-based multiply.
  // --------------------------------------------------------------------------
  function automatic poly_t poly_mul(input poly_t a, input poly_t b);
    poly_t  r;
    coeff_t p;
    int     idx;
    for (int i = 0; i < N; i++) r[i] = coeff_t'(0);
    for (int i = 0; i < N; i++)
      for (int j = 0; j < N; j++) begin
        p   = mulm(a[i], b[j]);
        idx = i + j;
        if (idx < N) r[idx]     = addm(r[idx],     p);
        else         r[idx-N]   = subm(r[idx-N],   p);   // x^256 = -1
      end
    return r;
  endfunction

  // Full NTT-based polynomial multiply: INTT( NTT(a) o NTT(b) ).
  function automatic poly_t poly_mul_ntt(input poly_t a, input poly_t b);
    return ntt_inv(pwm(ntt_fwd(a), ntt_fwd(b)));
  endfunction

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  // Element-wise equality of two polynomials.
  function automatic bit poly_eq(input poly_t x, input poly_t y);
    for (int i = 0; i < N; i++)
      if (x[i] !== y[i]) return 1'b0;
    return 1'b1;
  endfunction

endpackage : ntt_ref_pkg
