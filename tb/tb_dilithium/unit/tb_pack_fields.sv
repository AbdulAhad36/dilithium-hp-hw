`timescale 1ns/1ps
module tb_pack_fields #(parameter bit EXHAUSTIVE=0,CAPACITY_ONLY=0);
  logic clk=0,rst=1,command_valid_i=0,input_valid_i=0,input_last_i=0,output_ready_i=0,done_ready_i=0;
  logic [2:0] command_op_i=0;logic [1:0] command_param_i=0;logic [15:0] command_id_i=0;
  logic [3:0][22:0] input_data_i='0;logic [5:0] input_index_i=0;
  logic  command_ready_o,ref_command_ready_o;
  logic  input_ready_o,ref_input_ready_o;
  logic  output_valid_o,ref_output_valid_o;
  logic [63:0] output_data_o,ref_output_data_o;
  logic [3:0] output_bytes_o,ref_output_bytes_o;
  logic [6:0] output_index_o,ref_output_index_o;
  logic  output_last_o,ref_output_last_o;
  logic [15:0] output_id_o,ref_output_id_o;
  logic  done_valid_o,ref_done_valid_o;
  logic [2:0] done_code_o,ref_done_code_o;
  logic [15:0] done_id_o,ref_done_id_o;
  bitpkg dut(.*);
  bitpkg_c22_reference old(
    .clk(clk),
    .rst(rst),
    .command_valid_i(command_valid_i),
    .command_op_i(command_op_i),
    .command_param_i(command_param_i),
    .command_id_i(command_id_i),
    .input_valid_i(input_valid_i),
    .input_data_i(input_data_i),
    .input_index_i(input_index_i),
    .input_last_i(input_last_i),
    .output_ready_i(output_ready_i),
    .done_ready_i(done_ready_i),
    .command_ready_o(ref_command_ready_o),
    .input_ready_o(ref_input_ready_o),
    .output_valid_o(ref_output_valid_o),
    .output_data_o(ref_output_data_o),
    .output_bytes_o(ref_output_bytes_o),
    .output_index_o(ref_output_index_o),
    .output_last_o(ref_output_last_o),
    .output_id_o(ref_output_id_o),
    .done_valid_o(ref_done_valid_o),
    .done_code_o(ref_done_code_o),
    .done_id_o(ref_done_id_o)
  );
  int op_cfg,width_cfg,eta_cfg,gamma_cfg;
  longint vectors=0,lanes=0,accepted_lanes=0,isolated=0;
  int capacity_count,capacity_checks=0;
  bit capacity_ended;
  function automatic bit invalid(input int value);
    int signed_value;
    if(value>=8380417)return 1;
    signed_value=value<=4190208?value:value-8380417;
    case(op_cfg)
      0:return value>1023;
      1:return signed_value< -4095 || signed_value>4096;
      2:return signed_value< -eta_cfg || signed_value>eta_cfg;
      3:return value>(width_cfg==6?43:15);
      default:return signed_value<= -gamma_cfg || signed_value>gamma_cfg;
    endcase
  endfunction
  task automatic check;
    bit bad;int value,signed_value,code;logic [79:0] gold;logic [23:0] mask;
    #1;bad=0;gold=0;mask=(24'd1<<width_cfg)-1;
    for(int lane=0;lane<4;lane++)begin
      value=int'(input_data_i[lane]);bad|=invalid(value);lanes++;
      if(!invalid(value))begin
        signed_value=value<=4190208?value:value-8380417;
        code=op_cfg==1?4096-signed_value:op_cfg==2?eta_cfg-signed_value:op_cfg==4?gamma_cfg-signed_value:value;
        if((dut.encoded[lane]&mask)!==24'(code) || (old.encoded[lane]&mask)!==24'(code))
          $fatal(1,"C24 field op%0d width%0d lane%0d value%0d expected%0d",op_cfg,width_cfg,lane,value,code);
        for(int b=0;b<width_cfg;b++)gold[lane*width_cfg+b]=1'(code>>b);
        accepted_lanes++;
      end
    end
    if(dut.bad_value!==bad || old.bad_value!==bad)$fatal(1,"C24 validity op%0d width%0d data%h",op_cfg,width_cfg,input_data_i);
    if(!bad && (dut.group_bits!==gold || old.group_bits!==gold))$fatal(1,"C24 ordered packed group");
    vectors++;
  endtask
  initial begin
    force dut.op_r=op_cfg;force old.op_r=op_cfg;
    force dut.width_r=width_cfg;force old.width_r=width_cfg;
    force dut.eta_r=eta_cfg;force old.eta_r=eta_cfg;force old.gamma_r=gamma_cfg;
    // Independent integer oracle and the actual C22 ready expression. Cover
    // every 8-bit occupancy,all supported widths,reset/end/ready combinations.
    // Above-capacity states are included to catch arithmetic-width mistakes.
    force dut.state=dut.FEED;force old.state=old.FEED;
    force dut.count_r=capacity_count;force old.count_r=capacity_count;
    force dut.ended_r=capacity_ended;force old.ended_r=capacity_ended;
    for(int op=0;op<5;op++)for(int level=0;level<3;level++)begin
      op_cfg=op;eta_cfg=level==1?4:2;gamma_cfg=level==0?131072:524288;
      width_cfg=op==0?10:op==1?13:op==2?(level==1?4:3):op==3?(level==0?6:4):(level==0?18:20);
      for(int count=0;count<256;count++)for(int ready=0;ready<2;ready++)
        for(int ended=0;ended<2;ended++)for(int reset=0;reset<2;reset++)begin
          bit want;int remaining;
          capacity_count=count;output_ready_i=1'(ready);capacity_ended=1'(ended);rst=1'(reset);
          remaining=count-(count>=64 && ready!=0 && reset==0?64:0);
          want=reset==0 && ended==0 && (count<64 || ready!=0) && remaining+4*width_cfg<=144;
          #1;
          if(input_ready_o!==want || ref_input_ready_o!==want)
            $fatal(1,"Packer capacity mismatch width%0d count%0d ready%0d ended%0d reset%0d",width_cfg,count,ready,ended,reset);
          capacity_checks++;
        end
    end
    $display("LIGHTHD_PACK_CAPACITY_PROOF_PASS:%0d reset/end/ready/width/occupancy combinations",capacity_checks);
    release dut.state;release old.state;release dut.count_r;release old.count_r;
    release dut.ended_r;release old.ended_r;rst=1;output_ready_i=0;
    if(CAPACITY_ONLY)$finish;
    for(int op=0;op<5;op++)for(int level=0;level<3;level++)begin
      op_cfg=op;eta_cfg=level==1?4:2;gamma_cfg=level==0?131072:524288;
      width_cfg=op==0?10:op==1?13:op==2?(level==1?4:3):op==3?(level==0?6:4):(level==0?18:20);
      for(int base=0;base<(EXHAUSTIVE?8388608:8192);base+=4)begin
        for(int lane=0;lane<4;lane++)input_data_i[lane]=23'(base+lane);
        check();
      end
      for(int lane=0;lane<4;lane++)for(int boundary=0;boundary<10;boundary++)for(int delta=-3;delta<=3;delta++)begin
        int value;
        value=boundary==0?0:boundary==1?1023:boundary==2?4096:boundary==3?eta_cfg:
          boundary==4?gamma_cfg:boundary==5?8380417-gamma_cfg:boundary==6?8380417-eta_cfg:
          boundary==7?8376322:boundary==8?8380417:8388607;
        value=(value+delta)&8388607;input_data_i='0;input_data_i[lane]=23'(value);check();isolated++;
      end
      $display("LIGHTHD_PACK_FIELDS_PROGRESS:op%0d level%0d vectors%0d",op,level,vectors);
    end
    $display("LIGHTHD_PACK_FIELD_PROOF_PASS:exhaustive%0d/%0d vectors/%0d lane checks/%0d valid-lane encodings/%0d isolated-boundary vectors;field-only,no transport/UVM credit",EXHAUSTIVE,vectors,lanes,accepted_lanes,isolated);
    $finish;
  end
endmodule
