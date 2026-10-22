`timescale 1ps/1ps
module bank_store_protocol_test(output bit passed=0);
  logic clk=0,rst=1;always #2500 clk=~clk;
  logic alloc_valid_i=0,alloc_core_i=0,alloc_ready_o;
  logic [1:0] alloc_bank_i=2,alloc_mode_i=1,alloc_param_i=0;
  logic [3:0] alloc_region_i=5;logic [15:0] alloc_id_i=42;
  logic write_valid_i=0,write_core_i=0,write_last_i=0,write_ready_o;
  logic [15:0] write_id_i=42;logic [7:0] write_index_i=0;logic [22:0] write_data_i=0;
  logic finish_valid_i=0,finish_core_i=0,finish_ready_o;
  logic [15:0] finish_id_i=42;logic [2:0] finish_code_i=0;
  logic [63:0] reserved_o,complete_o;logic fault_o;
  memory dut(
    .clk(clk),.rst(rst),.alloc_valid_i(alloc_valid_i),.alloc_core_i(alloc_core_i),.alloc_bank_i(alloc_bank_i),
    .alloc_region_i(alloc_region_i),.alloc_mode_i(alloc_mode_i),.alloc_param_i(alloc_param_i),.alloc_id_i(alloc_id_i),.alloc_ready_o(alloc_ready_o),
    .alloc_compute_i(1'b0),.alloc_ntt_domain_i(1'b0),.alloc_rewrite_i(1'b0),
    .write_valid_i(write_valid_i),.write_core_i(write_core_i),.write_last_i(write_last_i),.write_ready_o(write_ready_o),
    .write_id_i(write_id_i),.write_index_i(write_index_i),.write_data_i(write_data_i),
    .finish_valid_i(finish_valid_i),.finish_core_i(finish_core_i),.finish_id_i(finish_id_i),.finish_code_i(finish_code_i),.finish_ready_o(finish_ready_o),
    .read_valid_i(1'b0),.read_bank_i(2'd0),.read_region_i(4'd0),.read_word_i(6'd0),.read_ready_o(),
    .response_valid_o(),.response_error_o(),.response_bank_o(),.response_region_o(),.response_word_o(),.response_data_o(),
    .response_id_o(),.response_mode_o(),.response_param_o(),.response_ntt_domain_o(),.response_small_o(),.response_ready_i(1'b0),
    .release_valid_i(1'b0),.release_bank_i(2'd0),.release_region_i(4'd0),.release_ready_o(),
    .reserved_o(reserved_o),.complete_o(complete_o),.fault_o(fault_o)
  );
  task automatic reset_and_allocate;
    @(negedge clk);rst=1;alloc_valid_i=0;write_valid_i=0;finish_valid_i=0;
    write_core_i=0;write_id_i=42;write_index_i=0;write_data_i=0;write_last_i=0;finish_id_i=42;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(fault_o || reserved_o!=0 || complete_o!=0)$fatal(1,"Protocol reset failed");
    alloc_valid_i=1;do @(posedge clk);while(!alloc_ready_o);@(negedge clk);alloc_valid_i=0;
  endtask
  initial begin
    for(int fault_kind=0;fault_kind<8;fault_kind++)begin
      reset_and_allocate();
      if(fault_kind==7)begin
        for(int k=0;k<256;k++)begin
          write_index_i=8'(k);write_last_i=k==255;write_valid_i=1;
          do @(posedge clk);while(!write_ready_o);@(negedge clk);write_valid_i=0;
        end
        do @(negedge clk);while(dut.acknowledged_r[0]!=64);
        write_index_i=0;write_last_i=0;
      end
      case(fault_kind)
        0:write_index_i=1;
        1:write_last_i=1;
        2:write_data_i=23'd8380417;
        3:write_id_i=43;
        4:write_core_i=1;
        5:finish_valid_i=1;
        6:begin finish_id_i=43;finish_valid_i=1;end
        default:;
      endcase
      if(fault_kind!=5 && fault_kind!=6)write_valid_i=1;
      repeat(3)@(negedge clk);
      if(!fault_o || complete_o!=0 || finish_ready_o || alloc_ready_o)$fatal(1,"Bank protocol fault%0d escaped",fault_kind);
    end
    $display("BANK_STORE_PROTOCOL_PASS:8 malformed-write/status fault kinds contained;no publication");passed=1;
  end
  initial begin #(64'd100_000_000);if(!passed)$fatal(1,"Bank protocol test timeout");end
endmodule
