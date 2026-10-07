// Standalone file-driven NTT output capture. No SV golden model or UVM used.
module tb_ntt_vectors;
  import ntt_pkg::*;

  typedef logic [COEFF_W-1:0] coeff_t;
  typedef coeff_t poly_t [N];

  logic clk = 1'b0;
  always #5 clk = ~clk;
  logic rst, start, busy, done;
  ntt_op_e op;
  logic [COEFF_W-1:0] s_tdata, m_tdata;
  logic s_tvalid, s_tlast, s_tready, m_tvalid, m_tlast, m_tready;
  longint unsigned cycles = 0;
  always @(posedge clk) cycles <= cycles + 1;
  longint unsigned core_launch_cycle;
  int run_cycles, run_drain_cycles, scale_cycles, scale_drain_cycles;
  int pwm_cycles, pwm_drain_cycles, other_cycles;
  longint unsigned fifo_core_launch;
  always @(posedge clk) if (!rst) begin
    if (dut.core_start) fifo_core_launch = cycles;
    if (dut.core_done) $display("NTT_VECTOR_CORE_LATENCY operation=%s cycles=%0d", dut.op_r.name(), cycles - fifo_core_launch);
  end
  ntt_engine dut (
    .clk(clk), .rst(rst), .start_i(start), .op_i(op), .busy_o(busy), .done_o(done),
    .s_tdata(s_tdata), .s_tvalid(s_tvalid), .s_tlast(s_tlast), .s_tready(s_tready),
    .m_tdata(m_tdata), .m_tvalid(m_tvalid), .m_tlast(m_tlast), .m_tready(m_tready)
  );

  task automatic run_engine(input ntt_op_e operation, input poly_t source,
                            output poly_t result);
    longint unsigned launch_cycle;
    @(negedge clk);
    while (busy) @(negedge clk);
    launch_cycle = cycles;
    op = operation;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    while (!s_tready) @(negedge clk);
    for (int i = 0; i < N; i++) begin
      s_tvalid = 1'b1;
      s_tdata = source[i];
      s_tlast = (i == N - 1);
      @(negedge clk);
    end
    s_tvalid = 1'b0;
    s_tlast = 1'b0;
    for (int i = 0; i < N; i++) begin
      do @(negedge clk); while (!m_tvalid);
      result[i] = m_tdata;
    end
    $display("NTT_VECTOR_LATENCY operation=%s launch_to_last_output_cycles=%0d",
             operation.name(), cycles - launch_cycle);
  endtask

  // PWM has two input polynomials, so it has a separate load sequence.
  task automatic run_pwm(input poly_t a, input poly_t b, output poly_t result);
    longint unsigned launch_cycle;
    @(negedge clk);
    while (busy) @(negedge clk);
    launch_cycle = cycles;
    op = OP_PWM;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    while (!s_tready) @(negedge clk);
    for (int i = 0; i < N; i++) begin
      s_tvalid = 1'b1;
      s_tdata = a[i];
      s_tlast = (i == N - 1);
      @(negedge clk);
    end
    for (int i = 0; i < N; i++) begin
      s_tdata = b[i];
      s_tlast = (i == N - 1);
      @(negedge clk);
    end
    s_tvalid = 1'b0;
    s_tlast = 1'b0;
    for (int i = 0; i < N; i++) begin
      do @(negedge clk); while (!m_tvalid);
      result[i] = m_tdata;
    end
    $display("NTT_VECTOR_LATENCY operation=OP_PWM launch_to_last_output_cycles=%0d",
             cycles - launch_cycle);
  endtask

  initial begin
    #100ms;
    $fatal(1, "NTT vector capture timed out");
  end

  string input_path, output_path, marker, case_id, operation;
  int input_fd, output_fd, count, status;
  poly_t a, b, output_poly, first, second, product;

  initial begin
    if (!$value$plusargs("NTT_INPUT_FILE=%s", input_path))
      input_path = "../FIPS204_NTT/ntt_inputs.txt";
    if (!$value$plusargs("NTT_OUTPUT_FILE=%s", output_path))
      output_path = "ntt_dut_outputs.txt";
    input_fd = $fopen(input_path, "r");
    if (input_fd == 0) $fatal(1, "Cannot open NTT inputs: %s", input_path);
    output_fd = $fopen(output_path, "w");
    if (output_fd == 0) $fatal(1, "Cannot create NTT DUT outputs: %s", output_path);

    status = $fscanf(input_fd, "%s %d", marker, count);
    if (status != 2 || marker != "COUNT" || count <= 0)
      $fatal(1, "Invalid NTT input header");
    $fdisplay(output_fd, "COUNT %0d", count);

    rst = 1'b1;
    start = 1'b0;
    op = OP_NTT;
    s_tdata = '0;
    s_tvalid = 1'b0;
    s_tlast = 1'b0;
    m_tready = 1'b1;
    repeat (4) @(negedge clk);
    rst = 1'b0;
    repeat (2) @(negedge clk);

    for (int case_number = 0; case_number < count; case_number++) begin
      status = $fscanf(input_fd, "%s %s %s", marker, case_id, operation);
      if (status != 3 || marker != "CASE")
        $fatal(1, "Bad CASE header at case %0d", case_number);
      status = $fscanf(input_fd, "%s", marker);
      if (status != 1 || marker != "A") $fatal(1, "Missing A for %s", case_id);
      for (int i = 0; i < N; i++) begin
        status = $fscanf(input_fd, "%h", a[i]);
        if (status != 1 || a[i] >= Q) $fatal(1, "Bad A[%0d] for %s", i, case_id);
      end
      if (operation == "PWM" || operation == "MUL") begin
        status = $fscanf(input_fd, "%s", marker);
        if (status != 1 || marker != "B") $fatal(1, "Missing B for %s", case_id);
        for (int i = 0; i < N; i++) begin
          status = $fscanf(input_fd, "%h", b[i]);
          if (status != 1 || b[i] >= Q) $fatal(1, "Bad B[%0d] for %s", i, case_id);
        end
      end

      if (operation == "NTT")
        run_engine((case_id == "ntt_bounded") ? OP_PRE_NTT : OP_NTT,
                   a, output_poly);
      else if (operation == "INTT") run_engine(OP_INTT, a, output_poly);
      else if (operation == "PWM") run_pwm(a, b, output_poly);
      else if (operation == "ROUNDTRIP") begin
        run_engine(OP_NTT, a, first);
        run_engine(OP_INTT, first, output_poly);
      end else if (operation == "MUL") begin
        run_engine(OP_NTT, a, first);
        run_engine(OP_NTT, b, second);
        run_pwm(first, second, product);
        run_engine(OP_INTT, product, output_poly);
      end else $fatal(1, "Unknown NTT operation %s", operation);

      $fdisplay(output_fd, "CASE %s %s", case_id, operation);
      $fwrite(output_fd, "OUT");
      for (int i = 0; i < N; i++) $fwrite(output_fd, " %06h", output_poly[i]);
      $fwrite(output_fd, "\n");
      $display("NTT_VECTOR_CAPTURE case=%s operation=%s coefficients=%0d", case_id, operation, N);
    end
    $fclose(input_fd);
    $fclose(output_fd);
    $display("NTT VECTOR CAPTURE COMPLETE: %0d cases; run py FIPS204_NTT/ntt_vectors.py compare", count);
    $finish;
  end
endmodule
