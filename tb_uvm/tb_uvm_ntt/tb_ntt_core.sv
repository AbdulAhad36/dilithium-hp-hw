// ============================================================================
// tb_ntt_core.sv  --  Directed self-checking testbench for ntt_core
// ----------------------------------------------------------------------------
// Increment 2 verification: drives whole polynomials through the ntt_core DUT
// and golden-compares every result against ntt_ref_pkg (the model already
// proven by tb_ntt_ref.sv).
//
// Per transaction:  load 256 coeffs -> pulse start -> wait done -> read back.
//   * OP_NTT   : DUT output  ==  ntt_fwd(input)
//   * OP_INTT  : DUT output  ==  ntt_inv(input)
//   * round-trip through the DUT : INTT_dut(NTT_dut(a)) == a
//
// Covered: edge polynomials (all-zero, all-(q-1), all-ones, delta) + random.
// OP_PWM is out of scope for increment 2 (needs a 2-operand interface).
//
// Run:  cd sim ;  vsim -c -do "do ntt_core_check.do; quit -f"
// ============================================================================
module tb_ntt_core;

  import ntt_pkg::*;
  import ntt_ref_pkg::*;

  localparam int N_RANDOM = 8;

  // ---- DUT I/O -------------------------------------------------------------
  logic               clk, rst;
  logic               start;
  ntt_op_e            op;
  logic               busy, done;
  logic               wr_en;
  logic               wr_b_sel;
  logic [LOGN-1:0]    wr_addr;
  logic [COEFF_W-1:0] wr_data;
  logic               rd_en;
  logic [LOGN-1:0]    rd_addr;
  logic [COEFF_W-1:0] rd_data;

  ntt_core dut (
      .clk        (clk),
      .rst        (rst),
      .start_i    (start),
      .op_i       (op),
      .busy_o     (busy),
      .done_o     (done),
      .wr_en_i    (wr_en),
      .wr_b_sel_i (wr_b_sel),
      .wr_addr_i  (wr_addr),
      .wr_data_i  (wr_data),
      .rd_en_i    (rd_en),
      .rd_addr_i  (rd_addr),
      .rd_data_o  (rd_data)
  );

  // ---- 10 ns clock ---------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  int tests  = 0;
  int errors = 0;

  // ---- drive one NTT/INTT operation through the DUT -----------------------
  task automatic run_op(input ntt_op_e o, input poly_t din, output poly_t dout);
    // load 256 coefficients (the core accepts writes only while IDLE)
    @(negedge clk);
    for (int i = 0; i < N; i++) begin
      wr_en   = 1'b1;
      wr_addr = i[LOGN-1:0];
      wr_data = din[i];
      @(negedge clk);
    end
    wr_en = 1'b0;

    // start pulse
    op    = o;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    // wait for completion (done is a 1-cycle pulse)
    do @(negedge clk); while (!done);

    // read 256 coefficients back -- registered read, data lags addr 1 cycle
    rd_en   = 1'b1;
    rd_addr = '0;
    @(negedge clk);
    for (int i = 0; i < N; i++) begin
      @(negedge clk);
      dout[i] = rd_data;
      if (i + 1 < N) rd_addr = (i + 1);
    end
    rd_en = 1'b0;
  endtask

  // ---- check a single transform against the golden model ------------------
  task automatic check_op(input ntt_op_e o, input poly_t din, input string tag);
    poly_t dut_out, ref_out;
    run_op(o, din, dut_out);
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

  // ---- check a DUT-only round-trip  INTT(NTT(a)) == a ---------------------
  task automatic check_roundtrip(input poly_t din, input string tag);
    poly_t fwd, back;
    run_op(OP_NTT,  din, fwd);
    run_op(OP_INTT, fwd, back);
    tests++;
    if (poly_eq(back, din)) begin
      $display("  [PASS] round : %s", tag);
    end else begin
      errors++;
      $display("  [FAIL] round : %s", tag);
      for (int i = 0; i < N; i++)
        if (back[i] !== din[i]) begin
          $display("         first diff @%0d : expected %0d  got %0d",
                   i, din[i], back[i]);
          break;
        end
    end
  endtask

  // ---- polynomial generators ----------------------------------------------
  function automatic void fill_random(ref poly_t p);
    for (int i = 0; i < N; i++) p[i] = coeff_t'($urandom % Q);
  endfunction

  function automatic void fill_const(ref poly_t p, input coeff_t v);
    for (int i = 0; i < N; i++) p[i] = v;
  endfunction

  // ---- main ----------------------------------------------------------------
  poly_t a;

  initial begin
    $display("============================================================");
    $display(" ntt_core directed self-check  (golden model = ntt_ref_pkg)");
    $display("============================================================");

    // reset
    rst      = 1'b1;
    start    = 1'b0;
    op       = OP_NTT;
    wr_en    = 1'b0;
    wr_b_sel = 1'b0;
    wr_addr  = '0;
    wr_data  = '0;
    rd_en    = 1'b0;
    rd_addr  = '0;
    repeat (4) @(negedge clk);
    rst = 1'b0;
    repeat (2) @(negedge clk);

    // ---- edge-case polynomials -------------------------------------------
    fill_const(a, coeff_t'(0));
    check_op(OP_NTT,  a, "all-zero");
    check_op(OP_INTT, a, "all-zero");

    fill_const(a, coeff_t'(Q-1));
    check_op(OP_NTT,  a, "all-(q-1)");
    check_roundtrip(a, "all-(q-1)");

    fill_const(a, coeff_t'(1));
    check_op(OP_NTT,  a, "all-ones");
    check_roundtrip(a, "all-ones");

    fill_const(a, coeff_t'(0));  a[0] = coeff_t'(1);
    check_op(OP_NTT,  a, "delta @0");
    check_roundtrip(a, "delta @0");

    fill_const(a, coeff_t'(0));  a[255] = coeff_t'(123456);
    check_roundtrip(a, "delta @255");

    // ---- random stress ---------------------------------------------------
    for (int it = 0; it < N_RANDOM; it++) begin
      fill_random(a);
      check_op(OP_NTT,  a, $sformatf("random #%0d", it));
      check_op(OP_INTT, a, $sformatf("random #%0d", it));
      check_roundtrip(a, $sformatf("random #%0d", it));
    end

    // ---- verdict ---------------------------------------------------------
    $display("------------------------------------------------------------");
    if (errors == 0)
      $display(" RESULT:  ALL %0d CHECKS PASSED -- ntt_core verified correct.",
               tests);
    else
      $display(" RESULT:  %0d / %0d CHECKS FAILED.", errors, tests);
    $display("============================================================");
    $finish;
  end

endmodule : tb_ntt_core
