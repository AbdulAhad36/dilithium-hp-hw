`timescale 1ns/1ps
// Exhaustive field encodings against the original wide arithmetic. Packet
// framing/range errors are independently tested by the existing packer bench.
module tb_area_arithmetic;
  import dilithium_pkg::*;
  logic clk=0,rst=1;
  logic [3:0] count_k,count_l;
  logic [1:0] count_level;
  longint checked=0;
  keygen keygen(.clk(clk),.rst(rst),.start_valid_i(1'b0),
    .start_param_i(2'd0),.start_id_i(16'd0),.start_seed_i(256'd0),
    .service_i('0),.key_ready_i(1'b0),.done_ready_i(1'b0));
  bitpkg packer(.clk(clk),.rst(rst),.command_valid_i(1'b0),
    .command_op_i(3'b0),.command_param_i(2'b0),.command_id_i(16'b0),
    .input_valid_i(1'b0),.input_data_i(92'b0),.input_index_i(6'b0),.input_last_i(1'b0),
    .output_ready_i(1'b0),.done_ready_i(1'b0));
  process_dma dma(.clk(clk),.rst(rst),.command_valid_i(1'b0),
    .command_op_i(PROC_ADD),.command_param_i(2'b0),.command_kind_i(2'b0),
    .command_a_bank_i(2'b0),.command_b_bank_i(2'b0),.command_d_bank_i(2'b0),.command_h_bank_i(2'b0),
    .command_a_base_i(10'b0),.command_b_base_i(10'b0),.command_d_base_i(10'b0),.command_h_base_i(10'b0),
    .command_a_compact_i(1'b0),.command_b_enable_i(1'b0),.command_b_compact_i(1'b0),
    .command_low_enable_i(1'b0),.command_pack_high_i(1'b0),.command_pack_store_i(1'b0),
    .command_pack_op_i(3'b0),.command_hint_enable_i(1'b0),.done_ready_i(1'b0),
    .packed_ready_i(1'b0),.hint_ready_i(1'b0),.memory_command_ready_i(2'b0),
    .memory_read_valid_i(8'b0),.memory_read_data_i(736'b0),.memory_write_ready_i(8'b0),
    .memory_done_valid_i(8'b0),.memory_done_error_i(8'b0));
  initial begin
    logic [23:0] original;
    logic [9:0] old_offset,new_offset;
    for(int value=0;value<(1<<23);value++)begin
      original=value<=4096?24'(4096-value):24'(8384513-value);
      if(packer.encode_t0(23'(value))!==original[12:0])$fatal(1,"t0 encoding mismatch %0d",value);
      checked++;
      for(int eta=2;eta<=4;eta+=2)begin
        original=value<=eta?24'(eta-value):24'(8380417+eta-value);
        if(packer.encode_secret(23'(value),3'(eta))!==original[3:0])$fatal(1,"eta encoding mismatch");
        checked++;
      end
      for(int level=0;level<2;level++)begin
        int gamma;gamma=level==0?131072:524288;
        original=value<=gamma?24'(gamma-value):24'(8380417+gamma-value);
        if(packer.encode_z(23'(value),20'(gamma))!==original[19:0])$fatal(1,"z encoding mismatch");
        checked++;
      end
      if(value%1048576==0)$display("AREA_ENCODING_PROGRESS:%0d coefficients",value);
    end
    for(int value=0;value<16;value++)begin
      original=value<8?24'(value):24'(8380401+value);
      if(dma.compact_coefficient(4'(value))!==original[22:0])$fatal(1,"Compact mapping mismatch");
    end
    for(int level=0;level<4;level++)for(int row=0;row<16;row++)begin
      old_offset=10'(row)*(level==0?10'd24:10'd16);
      new_offset=10'(row<<4)+(level==0?10'(row<<3):10'd0);
      if(old_offset!==new_offset)$fatal(1,"Row stride mismatch");
    end
    // Check the actual production length wires,including all inactive and
    // invalid parameter/count encodings,against the old wide expression.
    force keygen.k_r=count_k;force keygen.l_r=count_l;force keygen.level_r=count_level;
    for(int level=0;level<4;level++)for(int k=0;k<16;k++)for(int l=0;l<16;l++)begin
      count_level=2'(level);count_k=4'(k);count_l=4'(l);#1;
      if(keygen.pk_words!==10'(4+k*40) || keygen.sk_words!==10'(16+(k+l)*(level==1?16:12)+k*52))
        $fatal(1,"Production length arithmetic mismatch level%0d k%0d l%0d",level,k,l);
    end
    release keygen.k_r;release keygen.l_r;release keygen.level_r;
    if(checked!=41943040)$fatal(1,"Incomplete exhaustive encoding campaign");
    $display("LIGHTHD_AREA_ARITHMETIC_PASS:%0d field encodings/16 compact nibbles/64 row strides/1024 actual parameter-count lengths",checked);
    $finish;
  end
endmodule
