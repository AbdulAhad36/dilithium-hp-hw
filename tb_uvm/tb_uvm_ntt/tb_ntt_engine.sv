// ============================================================================
// tb_ntt_engine.sv  --  Directed self-checking testbench for ntt_engine
// ----------------------------------------------------------------------------
// Increment 4 verification: streams whole polynomials through the ntt_engine
// over its AXI4-Stream sink/source and golden-compares every result against
// ntt_ref_pkg.
//
// Per transaction:  start -> stream 256 coeffs in -> stream 256 coeffs out.
//   * OP_NTT   : engine output  ==  ntt_fwd(input)
//   * OP_INTT  : engine output  ==  ntt_inv(input)
//   * round-trip through the engine : INTT(NTT(a)) == a
//
// Run:  cd sim ;  vsim -c -do "do ntt_engine_check.do; quit -f"
// ============================================================================
module tb_ntt_engine;

  import ntt_pkg::*;
  import ntt_ref_pkg::*;

  localparam int N_RANDOM = 6;

  // ---- DUT I/O -------------------------------------------------------------
  logic               clk, rst;
  logic               start;
  ntt_op_e            op;
  logic               busy, done;

  logic [COEFF_W-1:0] s_tdata;
  logic               s_tvalid, s_tlast, s_tready;
  logic [COEFF_W-1:0] m_tdata;
  logic               m_tvalid, m_tlast;
  logic               m_tready;

  ntt_engine dut (
      .clk      (clk),
      .rst      (rst),
      .start_i  (start),
      .op_i     (op),
      .busy_o   (busy),
      .done_o   (done),
      .s_tdata  (s_tdata),
      .s_tvalid (s_tvalid),
      .s_tlast  (s_tlast),
      .s_tready (s_tready),
      .m_tdata  (m_tdata),
      .m_tvalid (m_tvalid),
      .m_tlast  (m_tlast),
      .m_tready (m_tready)
  );

  // ---- 10 ns clock ---------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  int tests  = 0;
  int errors = 0;

  // ---- drive one operation through the engine -----------------------------
  task automatic run_engine(input ntt_op_e o, input poly_t din,
                            output poly_t dout);
    // wait for the engine to be idle, then issue the request.
    // (start is only sampled in E_IDLE -- pulsing it during the 1-cycle
    //  E_DONE state would be missed.)
    @(negedge clk);
    while (busy) @(negedge clk);
    op    = o;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    // wait until the engine is ready to receive
    while (!s_tready) @(negedge clk);

    // stream 256 coefficients into the sink
    for (int i = 0; i < N; i++) begin
      s_tvalid = 1'b1;
      s_tdata  = din[i];
      s_tlast  = (i == N-1);
      @(negedge clk);
    end
    s_tvalid = 1'b0;
    s_tlast  = 1'b0;

    // collect 256 coefficients from the source.
    // m_tready is held high for the whole test (set in the init block) so the
    // engine always accepts a beat at the clock edge after we sample it --
    // dropping m_tready here would strand the final beat in TX_VALID.
    for (int i = 0; i < N; i++) begin
      do @(negedge clk); while (!m_tvalid);
      dout[i] = m_tdata;
    end
  endtask

  // ---- check a single transform against the golden model ------------------
  task automatic check_op(input ntt_op_e o, input poly_t din, input string tag);
    poly_t dut_out, ref_out;
    run_engine(o, din, dut_out);
    ref_out = (o == OP_NTT) ? ntt_fwd(din) : ntt_inv(din);
    tests++;
    if (poly_eq(dut_out, ref_out)) begin
      $display("  [PASS] %-5s : %s", (o == OP_NTT) ? "NTT" : "INTT", tag);
    end else begin
      errors++;
      $display("  [FAIL] %-5s : %s", (o == OP_NTT) ? "NTT" : "INTT", tag);
      for (int i = 0; i < N; i++)
        if (dut_out[i] !== ref_out[i]) begin
          $display("         first diff @%0d : golden %0d  dut %0d",
                   i, ref_out[i], dut_out[i]);
          break;
        end
    end
  endtask

  // ---- check an engine round-trip  INTT(NTT(a)) == a ----------------------
  task automatic check_roundtrip(input poly_t din, input string tag);
    poly_t fwd, back;
    run_engine(OP_NTT,  din, fwd);
    run_engine(OP_INTT, fwd, back);
    tests++;
    if (poly_eq(back, din)) begin
      $display("  [PASS] round : %s", tag);
    end else begin
      errors++;
      $display("  [FAIL] round : %s", tag);
    end
  endtask

  function automatic void fill_random(ref poly_t p);
    for (int i = 0; i < N; i++) p[i] = coeff_t'($urandom % Q);
  endfunction

  function automatic void fill_const(ref poly_t p, input coeff_t v);
    for (int i = 0; i < N; i++) p[i] = v;
  endfunction

  // ---- watchdog : fail fast instead of hanging forever --------------------
  initial begin
    #50ms;
    $display(" RESULT:  TIMEOUT -- testbench watchdog fired.");
    $finish;
  end

  // ---- main ----------------------------------------------------------------
  poly_t a;

  initial begin
    $display("============================================================");
    $display(" ntt_engine directed self-check  (golden model = ntt_ref_pkg)");
    $display("============================================================");

    rst      = 1'b1;
    start    = 1'b0;
    op       = OP_NTT;
    s_tvalid = 1'b0;
    s_tdata  = '0;
    s_tlast  = 1'b0;
    m_tready = 1'b1;             // always ready to accept source beats
    repeat (4) @(negedge clk);
    rst = 1'b0;
    repeat (2) @(negedge clk);

    // edge cases
    fill_const(a, coeff_t'(0));
    check_op(OP_NTT,  a, "all-zero");
    fill_const(a, coeff_t'(Q-1));
    check_op(OP_NTT,  a, "all-(q-1)");
    check_roundtrip(a, "all-(q-1)");
    fill_const(a, coeff_t'(0));  a[0] = coeff_t'(1);
    check_op(OP_NTT,  a, "delta @0");
    check_roundtrip(a, "delta @0");

    // random stress
    for (int it = 0; it < N_RANDOM; it++) begin
      fill_random(a);
      check_op(OP_NTT,  a, $sformatf("random #%0d", it));
      check_op(OP_INTT, a, $sformatf("random #%0d", it));
      check_roundtrip(a, $sformatf("random #%0d", it));
    end

    $display("------------------------------------------------------------");
    if (errors == 0)
      $display(" RESULT:  ALL %0d CHECKS PASSED -- ntt_engine verified.", tests);
    else
      $display(" RESULT:  %0d / %0d CHECKS FAILED.", errors, tests);
    $display("============================================================");
    $finish;
  end

endmodule : tb_ntt_engine
