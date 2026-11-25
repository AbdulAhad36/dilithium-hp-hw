`timescale 1ns/1ps
// Control/state and VALID-payload equivalence against frozen C12. Physical
// read data is now direct wiring even when invalid;verify that contract too.
module tb_memory_switch #(parameter bit ONEHOT_OWNERS=0);
  logic  clk;
  logic  rst;
  logic  idle_o;
  logic  ref_idle_o;
  logic [2:0][1:0] client_command_valid_i;
  logic [2:0][1:0] client_command_ready_o;
  logic [2:0][1:0] ref_client_command_ready_o;
  logic [2:0][1:0][3:0] client_command_mask_i;
  logic [2:0][1:0][3:0] client_command_write_i;
  logic [2:0][1:0][3:0][9:0] client_command_base_i;
  logic [2:0][1:0][3:0][10:0] client_command_words_i;
  logic [2:0][1:0][3:0][1:0] client_command_mode_i;
  logic [2:0][1:0][3:0] client_write_valid_i;
  logic [2:0][1:0][3:0] client_write_ready_o;
  logic [2:0][1:0][3:0] ref_client_write_ready_o;
  logic [2:0][1:0][3:0][91:0] client_write_data_i;
  logic [2:0][1:0][3:0][9:0] client_write_address_i;
  logic [2:0][1:0][3:0] client_read_valid_o;
  logic [2:0][1:0][3:0] ref_client_read_valid_o;
  logic [2:0][1:0][3:0] client_read_ready_i;
  logic [2:0][1:0][3:0][91:0] client_read_data_o;
  logic [2:0][1:0][3:0][91:0] ref_client_read_data_o;
  logic [2:0][1:0][3:0][9:0] client_read_address_o;
  logic [2:0][1:0][3:0][9:0] ref_client_read_address_o;
  logic [2:0][1:0][3:0] client_read_last_o;
  logic [2:0][1:0][3:0] ref_client_read_last_o;
  logic [2:0][1:0][3:0] client_done_valid_o;
  logic [2:0][1:0][3:0] ref_client_done_valid_o;
  logic [2:0][1:0][3:0] client_done_error_o;
  logic [2:0][1:0][3:0] ref_client_done_error_o;
  logic [2:0][1:0][3:0] client_done_ready_i;
  logic [1:0] memory_command_valid_o;
  logic [1:0] ref_memory_command_valid_o;
  logic [1:0] memory_command_ready_i;
  logic [1:0][3:0] memory_command_mask_o;
  logic [1:0][3:0] ref_memory_command_mask_o;
  logic [1:0][3:0] memory_command_write_o;
  logic [1:0][3:0] ref_memory_command_write_o;
  logic [1:0][3:0][9:0] memory_command_base_o;
  logic [1:0][3:0][9:0] ref_memory_command_base_o;
  logic [1:0][3:0][10:0] memory_command_words_o;
  logic [1:0][3:0][10:0] ref_memory_command_words_o;
  logic [1:0][3:0][1:0] memory_command_mode_o;
  logic [1:0][3:0][1:0] ref_memory_command_mode_o;
  logic [1:0][3:0] memory_write_valid_o;
  logic [1:0][3:0] ref_memory_write_valid_o;
  logic [1:0][3:0] memory_write_ready_i;
  logic [1:0][3:0][91:0] memory_write_data_o;
  logic [1:0][3:0][91:0] ref_memory_write_data_o;
  logic [1:0][3:0][9:0] memory_write_address_o;
  logic [1:0][3:0][9:0] ref_memory_write_address_o;
  logic [1:0][3:0] memory_read_valid_i;
  logic [1:0][3:0] memory_read_ready_o;
  logic [1:0][3:0] ref_memory_read_ready_o;
  logic [1:0][3:0][91:0] memory_read_data_i;
  logic [1:0][3:0][9:0] memory_read_address_i;
  logic [1:0][3:0] memory_read_last_i;
  logic [1:0][3:0] memory_done_valid_i;
  logic [1:0][3:0] memory_done_error_i;
  logic [1:0][3:0] memory_done_ready_o;
  logic [1:0][3:0] ref_memory_done_ready_o;
  initial clk=0;always #5 clk=~clk;
  memory_router #(.ONEHOT_OWNERS(ONEHOT_OWNERS)) dut(.*);
  memory_router_c12_reference reference_dut(
    .idle_o(ref_idle_o),
    .client_command_ready_o(ref_client_command_ready_o),
    .client_write_ready_o(ref_client_write_ready_o),
    .client_read_valid_o(ref_client_read_valid_o),
    .client_read_data_o(ref_client_read_data_o),
    .client_read_address_o(ref_client_read_address_o),
    .client_read_last_o(ref_client_read_last_o),
    .client_done_valid_o(ref_client_done_valid_o),
    .client_done_error_o(ref_client_done_error_o),
    .memory_command_valid_o(ref_memory_command_valid_o),
    .memory_command_mask_o(ref_memory_command_mask_o),
    .memory_command_write_o(ref_memory_command_write_o),
    .memory_command_base_o(ref_memory_command_base_o),
    .memory_command_words_o(ref_memory_command_words_o),
    .memory_command_mode_o(ref_memory_command_mode_o),
    .memory_write_valid_o(ref_memory_write_valid_o),
    .memory_write_data_o(ref_memory_write_data_o),
    .memory_write_address_o(ref_memory_write_address_o),
    .memory_read_ready_o(ref_memory_read_ready_o),
    .memory_done_ready_o(ref_memory_done_ready_o),.*);
  localparam int WIDTH=$bits({idle_o,client_command_ready_o,client_write_ready_o,client_read_valid_o,client_read_data_o,client_read_address_o,client_read_last_o,client_done_valid_o,client_done_error_o,memory_command_valid_o,memory_command_mask_o,memory_command_write_o,memory_command_base_o,memory_command_words_o,memory_command_mode_o,memory_write_valid_o,memory_write_data_o,memory_write_address_o,memory_read_ready_o,memory_done_ready_o});
  logic [2:0][1:0][3:0][91:0] qualified_read,ref_qualified_read;
  logic [1:0][3:0][91:0] qualified_write,ref_qualified_write;
  logic [1:0][2:0] monitored_eligible;
  always_comb begin
    for(int c=0;c<3;c++)for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
      qualified_read[c][p][b]=client_read_valid_o[c][p][b]?client_read_data_o[c][p][b]:92'd0;
      ref_qualified_read[c][p][b]=ref_client_read_valid_o[c][p][b]?ref_client_read_data_o[c][p][b]:92'd0;
    end
    for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
      qualified_write[p][b]=memory_write_valid_o[p][b]?memory_write_data_o[p][b]:92'd0;
      ref_qualified_write[p][b]=ref_memory_write_valid_o[p][b]?ref_memory_write_data_o[p][b]:92'd0;
    end
    for(int p=0;p<2;p++)for(int c=0;c<3;c++)begin
      logic available;logic [3:0] mask;
      available=!rst;mask=client_command_mask_i[c][p]==0?4'b1:client_command_mask_i[c][p];
      for(int b=0;b<4;b++)if(mask[b] && reference_dut.owner_r[p][b]!=3 &&
        !(reference_dut.owner_r[p][b]==c && memory_done_valid_i[p][b] &&
          (client_done_ready_i[c][p][b] || reference_dut.retire_pending_r[p][b])))available=0;
      monitored_eligible[p][c]=available && client_command_valid_i[c][p];
    end
  end
  wire [WIDTH-1:0] observed={idle_o,client_command_ready_o,client_write_ready_o,client_read_valid_o,qualified_read,client_read_address_o,client_read_last_o,client_done_valid_o,client_done_error_o,memory_command_valid_o,memory_command_mask_o,memory_command_write_o,memory_command_base_o,memory_command_words_o,memory_command_mode_o,memory_write_valid_o,qualified_write,memory_write_address_o,memory_read_ready_o,memory_done_ready_o};
  wire [WIDTH-1:0] wanted={ref_idle_o,ref_client_command_ready_o,ref_client_write_ready_o,ref_client_read_valid_o,ref_qualified_read,ref_client_read_address_o,ref_client_read_last_o,ref_client_done_valid_o,ref_client_done_error_o,ref_memory_command_valid_o,ref_memory_command_mask_o,ref_memory_command_write_o,ref_memory_command_base_o,ref_memory_command_words_o,ref_memory_command_mode_o,ref_memory_write_valid_o,ref_qualified_write,ref_memory_write_address_o,ref_memory_read_ready_o,ref_memory_done_ready_o};
  logic [31:0] rng=32'h139abc47;
  logic [1:0][2:0][7:0] eligibility_seen=0;
  logic [1:0][3:0][3:0] owner_seen=0;
  logic [1:0][3:0] pending_seen=0;
  int commands[3]='{default:0};int checks=0,resets=0;
  function automatic logic [31:0] next_random();
    rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;
  endfunction
  task automatic compare_outputs();
    // Verify all 24 read paths even on idle/reset clocks. Invalid payloads
    // intentionally differ from C12, but must equal the physical RAM wire.
    for(int c=0;c<3;c++)for(int p=0;p<2;p++)for(int b=0;b<4;b++)
      if(client_read_data_o[c][p][b]!==memory_read_data_i[p][b])
        $fatal(1,"Direct RAM data wiring mismatch:client%0d port%0d bank%0d",c,p,b);
    if(observed!==wanted)begin
      for(int bitno=0;bitno<WIDTH;bitno++)if(observed[bitno]!==wanted[bitno])
        $fatal(1,"C12 switch mismatch:clock%0d bit%0d observed%b expected%b",checks,bitno,observed[bitno],wanted[bitno]);
    end
    if(dut.owner_r!==reference_dut.owner_r || dut.turn_r!==reference_dut.turn_r ||
      dut.retire_pending_r!==reference_dut.retire_pending_r)$fatal(1,"C12 switch state mismatch");
    checks++;
  endtask
  initial begin
    rst=1;
    client_command_valid_i=0;
    client_command_mask_i=0;
    client_command_write_i=0;
    client_command_base_i=0;
    client_command_words_i=0;
    client_command_mode_i=0;
    client_write_valid_i=0;
    client_write_data_i=0;
    client_write_address_i=0;
    client_read_ready_i=0;
    client_done_ready_i=0;
    memory_command_ready_i=0;
    memory_write_ready_i=0;
    memory_read_valid_i=0;
    memory_read_data_i=0;
    memory_read_address_i=0;
    memory_read_last_i=0;
    memory_done_valid_i=0;
    memory_done_error_i=0;
    repeat(3)@(negedge clk);
    for(int step=0;step<200000;step++)begin
      @(negedge clk);rst=step%4096<2;if(step%4096==0)resets++;
      for(int bitno=0;bitno<$bits(client_command_valid_i);bitno+=32)
        client_command_valid_i=(client_command_valid_i<<32)|$bits(client_command_valid_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_command_mask_i);bitno+=32)
        client_command_mask_i=(client_command_mask_i<<32)|$bits(client_command_mask_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_command_write_i);bitno+=32)
        client_command_write_i=(client_command_write_i<<32)|$bits(client_command_write_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_command_base_i);bitno+=32)
        client_command_base_i=(client_command_base_i<<32)|$bits(client_command_base_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_command_words_i);bitno+=32)
        client_command_words_i=(client_command_words_i<<32)|$bits(client_command_words_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_command_mode_i);bitno+=32)
        client_command_mode_i=(client_command_mode_i<<32)|$bits(client_command_mode_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_write_valid_i);bitno+=32)
        client_write_valid_i=(client_write_valid_i<<32)|$bits(client_write_valid_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_write_data_i);bitno+=32)
        client_write_data_i=(client_write_data_i<<32)|$bits(client_write_data_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_write_address_i);bitno+=32)
        client_write_address_i=(client_write_address_i<<32)|$bits(client_write_address_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_read_ready_i);bitno+=32)
        client_read_ready_i=(client_read_ready_i<<32)|$bits(client_read_ready_i)'(next_random());
      for(int bitno=0;bitno<$bits(client_done_ready_i);bitno+=32)
        client_done_ready_i=(client_done_ready_i<<32)|$bits(client_done_ready_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_command_ready_i);bitno+=32)
        memory_command_ready_i=(memory_command_ready_i<<32)|$bits(memory_command_ready_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_write_ready_i);bitno+=32)
        memory_write_ready_i=(memory_write_ready_i<<32)|$bits(memory_write_ready_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_read_valid_i);bitno+=32)
        memory_read_valid_i=(memory_read_valid_i<<32)|$bits(memory_read_valid_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_read_data_i);bitno+=32)
        memory_read_data_i=(memory_read_data_i<<32)|$bits(memory_read_data_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_read_address_i);bitno+=32)
        memory_read_address_i=(memory_read_address_i<<32)|$bits(memory_read_address_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_read_last_i);bitno+=32)
        memory_read_last_i=(memory_read_last_i<<32)|$bits(memory_read_last_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_done_valid_i);bitno+=32)
        memory_done_valid_i=(memory_done_valid_i<<32)|$bits(memory_done_valid_i)'(next_random());
      for(int bitno=0;bitno<$bits(memory_done_error_i);bitno+=32)
        memory_done_error_i=(memory_done_error_i<<32)|$bits(memory_done_error_i)'(next_random());
      // A deferred physical REPORT stays asserted until the switch retires it.
      memory_done_valid_i|=dut.retire_pending_r;
      #1;compare_outputs();
      if(!rst)begin
        for(int p=0;p<2;p++)begin
          if(dut.turn_r[p]>2)$fatal(1,"Illegal arbitration phase");
          eligibility_seen[p][dut.turn_r[p]][monitored_eligible[p]]=1;
          for(int b=0;b<4;b++)owner_seen[p][b][dut.owner_r[p][b]]=1;
          for(int c=0;c<3;c++)if(client_command_valid_i[c][p] && client_command_ready_o[c][p])commands[c]++;
        end
        pending_seen|=dut.retire_pending_r;
      end
      @(posedge clk);#1;compare_outputs();
    end
    if(eligibility_seen!=='1 || owner_seen!=='1 || pending_seen!=='1)
      $fatal(1,"Missing switch scenarios:eligible%h owners%h pending%h",eligibility_seen,owner_seen,pending_seen);
    for(int c=0;c<3;c++)if(commands[c]==0)$fatal(1,"Client never admitted");
    $display("LIGHTHD_MEMORY_DIRECT_DATA_PASS:%0d control-state/valid-payload/direct-wire checks/%0d resets/all eligibility sets,owners,deferred lanes;admissions%0d/%0d/%0d",checks,resets,commands[0],commands[1],commands[2]);
    $finish;
  end
endmodule
