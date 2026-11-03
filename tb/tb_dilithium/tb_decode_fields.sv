`timescale 1ns/1ps
// Field arithmetic only:force the already-selected80-bit window so every
// encoding is tested without regenerating a whole polynomial for each value.
// Actual ring/framing/ready/reset behavior is tested separately,unforced.
module tb_decode_fields;
  logic clk=0,rst=1,command_valid_i=0;logic [2:0] command_op_i=0;
  logic [1:0] command_param_i=0;logic [15:0] command_id_i=0;
  logic input_valid_i=0,input_last_i=0,output_ready_i=0,done_ready_i=0;
  logic [63:0] input_data_i=0;logic [6:0] input_index_i=0;logic [3:0] input_bytes_i=8;
  logic [79:0] window;
  logic [91:0] actual,reference_data,gold;
  int vectors=0,lanes=0;
  bitunpkg dut(.command_ready_o(),.input_ready_o(),.output_valid_o(),.output_data_o(actual),
    .output_count_o(),.output_index_o(),.output_last_o(),.output_id_o(),.done_valid_o(),.done_code_o(),.done_id_o(),.*);
  bitunpkg_c22_reference baseline(.command_ready_o(),.input_ready_o(),.output_valid_o(),.output_data_o(reference_data),
    .output_count_o(),.output_index_o(),.output_last_o(),.output_id_o(),.done_valid_o(),.done_code_o(),.done_id_o(),.*);
  task automatic tick;#2;clk=1;#2;clk=0;endtask
  initial begin
    window=0;
    force dut.bits_r=window;force baseline.bits_r=window;
    for(int op=0;op<6;op++)for(int level=0;level<3;level++)begin
      int width,bound,eta,limit,amount;
      rst=1;tick();rst=0;command_op_i=3'(op);command_param_i=2'(level);command_id_i++;
      command_valid_i=1;tick();command_valid_i=0;
      width=op==0 || op==5?10:op==1?13:op==2?(level==1?4:3):op==3?(level==0?6:4):(level==0?18:20);
      eta=level==1?4:2;bound=op==1?4096:level==0?131072:524288;limit=1<<width;amount=op==2?16:4;
      for(int encoded=0;encoded<limit;encoded++)begin
        bit invalid;invalid=0;window=0;gold=0;
        for(int lane=0;lane<amount;lane++)begin
          int value,raw;
          raw=(encoded+lane*37)&(limit-1);
          for(int b=0;b<width;b++)window[lane*width+b]=(raw>>b)&1;
          case(op)
            0:value=raw;
            5:value=raw*8192;
            1,4:begin value=bound-raw;if(value<0)value+=8380417;end
            2:begin value=eta-raw;invalid|=raw>2*eta;end
            3:begin value=raw;invalid|=raw>(level==0?43:15);end
          endcase
          if(op==2)gold[4*lane+:4]=4'(value);else gold[23*lane+:23]=23'(value);
          lanes++;
        end
        #1;
        if(actual!==gold || reference_data!==gold || dut.bad_value!==invalid || baseline.bad_value!==invalid)
          $fatal(1,"Decode field mismatch op%0d level%0d encoded%0d actual%h baseline%h want%h invalid%b/%b/%b",op,level,encoded,actual,reference_data,gold,dut.bad_value,baseline.bad_value,invalid);
        vectors++;
      end
      $display("LIGHTHD_DECODE_DOMAIN_PASS:op%0d/level%0d width%0d/%0d vectors",op,level,width,limit);
    end
    if(vectors!=2390144 || lanes!=9560960)$fatal(1,"Incomplete decode domain");
    $display("LIGHTHD_DECODE_FIELD_EXHAUSTIVE_PASS:%0d vectors/%0d lane results;all encodings/6 formats/3levels,integer oracle and C22 actual logic",vectors,lanes);
    $finish;
  end
endmodule
