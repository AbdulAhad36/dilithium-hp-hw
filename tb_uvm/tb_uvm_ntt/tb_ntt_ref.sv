// ============================================================================
// tb_ntt_ref.sv  --  Self-check testbench for the NTT golden model
// ----------------------------------------------------------------------------
// This testbench has NO DUT. It exercises ntt_ref_pkg against itself to prove
// the golden model is internally consistent and therefore trustworthy as the
// reference for golden-comparing ntt_core later.
//
// Two mathematical properties must hold for ANY polynomial:
//   1. Round-trip :  ntt_inv(ntt_fwd(a))                  == a
//   2. Multiply   :  ntt_inv(pwm(ntt_fwd(a),ntt_fwd(b)))  == poly_mul(a,b)
//      i.e. the NTT-based multiply agrees with the independent O(N^2)
//      negacyclic schoolbook multiply.
//
// If both pass over random + edge-case vectors, the forward/inverse twiddle
// schedule, the modular arithmetic, and the N_INV scaling are all correct.
//
// Run:  cd sim ;  vsim -c -do "do ntt_ref_check.do; quit -f"
// ============================================================================
module tb_ntt_ref;

  import ntt_pkg::*;
  import ntt_ref_pkg::*;

  localparam int N_RANDOM = 100;

  poly_t a, b;
  poly_t fwd_a, fwd_b;
  poly_t roundtrip;
  poly_t prod_ntt, prod_ref;

  int tests  = 0;
  int errors = 0;

  // ---- random coefficient in [0, q-1] -------------------------------------
  function automatic coeff_t rnd_coeff();
    return coeff_t'($urandom % Q);
  endfunction

  function automatic void fill_random(ref poly_t p);
    for (int i = 0; i < N; i++) p[i] = rnd_coeff();
  endfunction

  function automatic void fill_const(ref poly_t p, input coeff_t v);
    for (int i = 0; i < N; i++) p[i] = v;
  endfunction

  // ---- one round-trip check ------------------------------------------------
  task automatic check_roundtrip(input poly_t p, input string tag);
    tests++;
    roundtrip = ntt_inv(ntt_fwd(p));
    if (poly_eq(roundtrip, p)) begin
      $display("  [PASS] round-trip  : %s", tag);
    end else begin
      errors++;
      $display("  [FAIL] round-trip  : %s", tag);
      for (int i = 0; i < N; i++)
        if (roundtrip[i] !== p[i]) begin
          $display("         first diff @%0d : expected %0d got %0d",
                   i, p[i], roundtrip[i]);
          break;
        end
    end
  endtask

  // ---- one multiply check (NTT path vs schoolbook) ------------------------
  task automatic check_multiply(input poly_t x, input poly_t y,
                                input string tag);
    tests++;
    fwd_a    = ntt_fwd(x);
    fwd_b    = ntt_fwd(y);
    prod_ntt = ntt_inv(pwm(fwd_a, fwd_b));
    prod_ref = poly_mul(x, y);
    if (poly_eq(prod_ntt, prod_ref)) begin
      $display("  [PASS] multiply    : %s", tag);
    end else begin
      errors++;
      $display("  [FAIL] multiply    : %s", tag);
      for (int i = 0; i < N; i++)
        if (prod_ntt[i] !== prod_ref[i]) begin
          $display("         first diff @%0d : schoolbook %0d ntt %0d",
                   i, prod_ref[i], prod_ntt[i]);
          break;
        end
    end
  endtask

  initial begin
    $display("============================================================");
    $display(" NTT golden-model self-check  (ntt_ref_pkg)");
    $display("   q = %0d   N = %0d   zeta = %0d   N_INV = %0d",
             Q, N, ZETA, N_INV);
    $display("============================================================");

    // ---- directed twiddle spot-checks (vs known twiddle_rom values) -------
    tests++;
    if (tw(0) === coeff_t'(1) && tw(1) === coeff_t'(4808194) &&
        tw(128) === coeff_t'(ZETA)) begin
      $display("  [PASS] twiddle spot : tw(0)=1, tw(1)=4808194, tw(128)=1753");
    end else begin
      errors++;
      $display("  [FAIL] twiddle spot : tw(0)=%0d tw(1)=%0d tw(128)=%0d",
               tw(0), tw(1), tw(128));
    end

    // ---- edge-case polynomials -------------------------------------------
    fill_const(a, coeff_t'(0));
    check_roundtrip(a, "all-zero");
    tests++;
    if (poly_eq(ntt_fwd(a), a)) $display("  [PASS] zero->zero  : NTT(0) = 0");
    else begin errors++; $display("  [FAIL] zero->zero"); end

    fill_const(a, coeff_t'(Q-1));
    check_roundtrip(a, "all-(q-1)");

    fill_const(a, coeff_t'(1));
    check_roundtrip(a, "all-ones");

    // delta polynomial: a[0]=1, rest 0
    fill_const(a, coeff_t'(0));  a[0] = coeff_t'(1);
    check_roundtrip(a, "delta @0");
    // multiplying by the delta-at-0 polynomial is the identity
    fill_random(b);
    check_multiply(b, a, "x * 1  (delta identity)");

    // delta @1 : multiplying by x  (negacyclic shift)
    fill_const(a, coeff_t'(0));  a[1] = coeff_t'(1);
    fill_random(b);
    check_multiply(b, a, "x * X  (negacyclic shift)");

    // ---- random stress ---------------------------------------------------
    for (int it = 0; it < N_RANDOM; it++) begin
      fill_random(a);
      fill_random(b);
      check_roundtrip(a, $sformatf("random #%0d", it));
      check_multiply (a, b, $sformatf("random #%0d", it));
    end

    // ---- verdict ---------------------------------------------------------
    $display("------------------------------------------------------------");
    if (errors == 0)
      $display(" RESULT:  ALL %0d CHECKS PASSED -- golden model is trusted.",
               tests);
    else
      $display(" RESULT:  %0d / %0d CHECKS FAILED.", errors, tests);
    $display("============================================================");
    $finish;
  end

endmodule : tb_ntt_ref
