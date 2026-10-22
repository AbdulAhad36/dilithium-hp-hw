// Fault-injection companion to the connected subsystem test. Uses three slots
// to exercise non-power-of-two slot validation as well as the default four.
`timescale 1ps/1ps
module memory_protocol_test(output logic passed=0);
  logic clk=0,rst=1;always #5000 clk=~clk;
  logic alloc_valid_i=0,alloc_core_i=0,alloc_ready_o;
  logic [15:0] alloc_id_i=17;
  logic [1:0] alloc_mode_i=0,alloc_param_i=0,alloc_slot_o;
  logic write_valid_i=0,write_core_i=0,write_last_i=0,write_ready_o;
  logic [15:0] write_id_i=17;
  logic [7:0] write_index_i=0;
  logic [22:0] write_data_i=1;
  logic finish_valid_i=0,finish_core_i=0,finish_ready_o;
  logic [15:0] finish_id_i=17;
  logic [2:0] finish_code_i=0;
  logic read_valid_i=0,read_ready_o;
  logic [1:0] read_slot_i=0,response_slot_o;
  logic [7:0] read_index_i=0,response_index_o;
  logic response_valid_o,response_error_o,response_ntt_domain_o,response_ready_i=0;
  logic [22:0] response_data_o;
  logic [15:0] response_id_o;
  logic [1:0] response_mode_o,response_param_o;
  logic release_valid_i=0,release_ready_o;
  logic [1:0] release_slot_i=0;
  logic [2:0] reserved_o,complete_o;
  logic fault_o;
  slot_memory #(.SLOTS(3)) dut(.*,
    .exec_valid_i(1'b0),.exec_ready_o(),.exec_op_i(2'd0),.exec_a_slot_i(2'd0),.exec_b_slot_i(2'd0),
    .exec_a_id_i(16'd0),.exec_b_id_i(16'd0),.exec_id_i(16'd0),
    .exec_response_valid_o(),.exec_response_ready_i(1'b0),.exec_code_o(),.exec_slot_o(),
    .result_valid_i(1'b0),.result_last_i(1'b0),.result_ready_o(),
    .result_index_i(8'd0),.result_data_i(23'd0),.exec_done_i(1'b0));
  task automatic reset_allocate();
    @(negedge clk);rst=1;alloc_valid_i=0;write_valid_i=0;finish_valid_i=0;
    read_valid_i=0;response_ready_i=0;release_valid_i=0;
    write_id_i=17;finish_id_i=17;write_index_i=0;write_last_i=0;write_data_i=1;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;alloc_valid_i=1;
    @(posedge clk);if(!alloc_ready_o || alloc_slot_o!=0)$fatal(1,"Protocol allocation");
    @(negedge clk);alloc_valid_i=0;
  endtask
  initial begin
    for(int kind=0;kind<8;kind++)begin
      reset_allocate();
      if(kind==6)begin
        for(int k=0;k<256;k++)begin
          write_valid_i=1;write_index_i=8'(k);write_last_i=(k==255);
          @(posedge clk);if(!write_ready_o)$fatal(1,"Protocol write ready");@(negedge clk);
        end
        write_index_i=0;write_last_i=0; // extra257th beat
      end else case(kind)
        0:begin write_valid_i=1;write_index_i=1;end
        1:begin write_valid_i=1;write_last_i=1;end
        2:begin write_valid_i=1;write_data_i=8380417;end
        3:begin write_valid_i=1;write_id_i=18;end
        4:finish_valid_i=1;
        5:begin write_valid_i=1;finish_valid_i=1;end
        7:begin finish_valid_i=1;finish_id_i=18;end
      endcase
      @(posedge clk);@(negedge clk);write_valid_i=0;finish_valid_i=0;
      if(!fault_o || complete_o!=0)$fatal(1,"Fault kind%0d not contained",kind);
      finish_id_i=17;finish_code_i=0;finish_valid_i=1;
      @(posedge clk);@(negedge clk);finish_valid_i=0;
      if(complete_o!=0)$fatal(1,"Faulted job published");
      $display("MEMORY_FAULT_REJECTED kind=%0d",kind);
    end
    reset_allocate();read_slot_i=3;read_valid_i=1;
    @(posedge clk);@(negedge clk);read_valid_i=0;
    if(!response_valid_o || !response_error_o)$fatal(1,"Out-of-range read");
    reset_allocate();
    for(int k=0;k<256;k++)begin
      write_valid_i=1;write_index_i=8'(k);write_last_i=(k==255);write_data_i=23'(k);
      @(posedge clk);@(negedge clk);
    end
    write_valid_i=0;finish_valid_i=1;
    @(posedge clk);@(negedge clk);finish_valid_i=0;
    if(complete_o!=1 || fault_o)$fatal(1,"Valid protocol completion");
    read_slot_i=0;read_index_i=17;read_valid_i=1;response_ready_i=1;
    release_valid_i=1;release_slot_i=0;
    @(posedge clk);if(release_ready_o)$fatal(1,"Release beat simultaneous read");
    @(negedge clk);release_valid_i=0;
    if(!response_valid_o || response_error_o || response_data_o!=17)$fatal(1,"Read pipeline first");
    read_index_i=18;
    @(posedge clk);@(negedge clk);
    if(!response_valid_o || response_error_o || response_data_o!=18)$fatal(1,"Read pipeline replacement");
    read_valid_i=0;response_ready_i=0;release_valid_i=1;release_slot_i=0;
    repeat(3)begin
      @(negedge clk);
      if(!response_valid_o || response_data_o!=18 || release_ready_o)$fatal(1,"Stalled valid read/release");
    end
    rst=1;release_valid_i=0;repeat(3)@(posedge clk);@(negedge clk);rst=0;
    @(negedge clk);
    if(response_valid_o || reserved_o!=0 || complete_o!=0 || fault_o)$fatal(1,"Stalled valid read survived reset");
    // Simultaneous read/release gives the read priority and leaves ownership.
    passed=1;$display("MEMORY_PROTOCOL_PASS:8 fault kinds,bounds,pipelined reads,stalled-response reset");
  end
endmodule
