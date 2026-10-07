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
  longint unsigned tb_cycles = 0;
  always @(posedge clk) tb_cycles <= tb_cycles + 1;

  // ---- drive one operation through the engine -----------------------------
  task automatic run_engine(input ntt_op_e o, input poly_t din,
                            output poly_t dout, input bit stall_output = 0,
                            input int input_gap = 0,
                            input bit report_latency = 0);
    int got, cycles;
    longint unsigned launch_cycle;
    bit stalled;
    logic [COEFF_W-1:0] held_data;
    logic held_last;
    // wait for the engine to be idle, then issue the request.
    // (start is only sampled in E_IDLE -- pulsing it during the 1-cycle
    //  E_DONE state would be missed.)
    @(negedge clk);
    while (busy) @(negedge clk);
    launch_cycle = tb_cycles;
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
      if (i != N-1) begin
        for (int gap = 0; gap < input_gap; gap++) begin
          s_tvalid = 1'b0;
          s_tlast = 1'b0;
          @(negedge clk);
        end
      end
    end
    s_tvalid = 1'b0;
    s_tlast  = 1'b0;

    // Collect accepted beats. The optional stall pattern checks that the
    // current output remains stable until ready rises again.
    got = 0;
    cycles = 0;
    stalled = 0;
    while (got < N) begin
      @(negedge clk);
      m_tready = !stall_output || ((cycles % 7) >= 2);
      @(posedge clk);
      if (stalled && (!m_tvalid || m_tdata !== held_data || m_tlast !== held_last)) begin
        errors++;
        $display("  [FAIL] output changed while stalled at coefficient %0d held=%0d current=%0d last=%0b/%0b ready=%0b tx_idx=%0d core_rd_en=%0b",
                 got, held_data, m_tdata, held_last, m_tlast, m_tready,
                 dut.tx_idx, dut.core_rd_en);
      end
      stalled = m_tvalid && !m_tready;
      if (stalled) begin
        held_data = m_tdata;
        held_last = m_tlast;
      end
      if (m_tvalid && m_tready) begin
        if (m_tlast !== (got == N-1)) begin
          errors++;
          $display("  [FAIL] wrong m_tlast at coefficient %0d", got);
        end
        dout[got] = m_tdata;
        got++;
      end
      cycles++;
    end
    m_tready = 1'b1;
    if (report_latency)
      $display("NTT_ENGINE_PACED_LATENCY operation=%s input_gap=%0d output_stalls=%0d launch_to_last_output_cycles=%0d",
               o.name(), input_gap, stall_output, tb_cycles - launch_cycle);
  endtask

  // ---- check a single transform against the golden model ------------------
  task automatic check_op(input ntt_op_e o, input poly_t din, input string tag,
                          input bit stall_output = 0, input int input_gap = 0,
                          input bit report_latency = 0);
    poly_t dut_out, ref_out;
    run_engine(o, din, dut_out, stall_output, input_gap, report_latency);
    ref_out = (o == OP_INTT) ? ntt_inv(din) : ntt_fwd(din);
    tests++;
    if (poly_eq(dut_out, ref_out)) begin
      $display("  [PASS] %-7s : %s", o.name(), tag);
    end else begin
      errors++;
      $display("  [FAIL] %-7s : %s", o.name(), tag);
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
    check_op(OP_NTT,  a, "delta @0", 0, 0, 1);
    check_op(OP_INTT, a, "delta @0", 0, 0, 1);
    check_roundtrip(a, "delta @0");
    check_op(OP_NTT, a, "delta @0 with output stalls", 1);
    check_op(OP_NTT, a, "delta @0 with one input gap per coefficient", 0, 1, 1);
    check_op(OP_INTT, a, "delta @0 with output stalls", 1, 0, 1);
    check_op(OP_INTT, a, "delta @0 with input gaps and output stalls", 1, 1, 1);

    // random stress
    for (int it = 0; it < N_RANDOM; it++) begin
      fill_random(a);
      check_op(OP_NTT,  a, $sformatf("random #%0d", it));
      check_op(OP_INTT, a, $sformatf("random #%0d", it));
      check_roundtrip(a, $sformatf("random #%0d", it));
      if (it == 0) begin
        check_op(OP_NTT, a, "random #0 with input gaps and output stalls", 1, 1);
        check_op(OP_INTT, a, "random #0 with output stalls", 1);
      end
    end

    for (int i = 0; i < N; i++) a[i] = coeff_t'((i % 9) - 4 + Q) % Q;
    check_op(OP_PRE_NTT, a, "secret eta4 no stalls", 0, 0, 1);
    check_op(OP_PRE_NTT, a, "secret eta4 input gaps", 0, 1, 1);
    check_op(OP_PRE_NTT, a, "secret eta4 output stalls", 1, 0, 1);
    check_op(OP_PRE_NTT, a, "secret eta4 gaps and stalls", 1, 1, 1);

    $display("------------------------------------------------------------");
    if (errors == 0)
      $display(" RESULT:  ALL %0d CHECKS PASSED -- ntt_engine verified.", tests);
    else
      $display(" RESULT:  %0d / %0d CHECKS FAILED.", errors, tests);
    $display("============================================================");
    $finish;
  end

endmodule : tb_ntt_engine
