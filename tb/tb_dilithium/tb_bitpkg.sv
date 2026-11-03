`timescale 1ns/1ps
module tb_bitpkg;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i,command_ready_o,input_valid_i,input_ready_o,input_last_i;
  logic [2:0] command_op_i,done_code_o;
  logic [1:0] command_param_i;
  logic [15:0] command_id_i,output_id_o,done_id_o;
  logic [3:0][22:0] input_data_i;
  logic [5:0] input_index_i;
  logic output_valid_o,output_ready_i,output_last_o,done_valid_o,done_ready_i;
  logic [63:0] output_data_o;
  logic [3:0] output_bytes_o;
  logic [6:0] output_index_o;
  bitpkg dut(.*);
  logic [63:0] expected[$],gold,held_data;
  logic [6:0] held_index;logic held_last,held;
  int gold_count,got,packet_width,expected_error;
  int cycles=0,packets=0,words=0,coefficients=0,stalls=0;
  bit gaps=1;
  function automatic int width_for(input int op,level);
    case(op)
      0:return 10;1:return 13;2:return level==1?4:3;
      3:return level==0?6:4;4:return level==0?18:20;default:return 0;
    endcase
  endfunction
  function automatic int encode(input int op,level,a);
    int signed_value,eta,gamma;
    signed_value=a<=4190208?a:a-8380417;
    eta=level==1?4:2;gamma=level==0?131072:524288;
    case(op)
      0,3:return a;
      1:return 4096-signed_value;
      2:return eta-signed_value;
      4:return gamma-signed_value;
      default:return 0;
    endcase
  endfunction
  function automatic logic [22:0] sample(input int op,level,index,variant);
    int value,eta,gamma;
    eta=level==1?4:2;gamma=level==0?131072:524288;
    case(op)
      0:value=(index*37+variant*19)%1024;
      1:value=(index*61+variant*7)%8192-4095;
      2:value=(index+variant)%(2*eta+1)-eta;
      3:value=(index+variant)%(level==0?44:16);
      4:value=(index*7919+variant*31)%(2*gamma)-gamma+1;
      default:value=0;
    endcase
    return 23'(value<0?value+8380417:value);
  endfunction
  always @(negedge clk)output_ready_i=!rst && (!gaps || cycles%11>3);
  always @(posedge clk)begin
    logic [63:0] want;int value;
    cycles++;
    if(rst)begin expected.delete();gold=0;gold_count=0;got=0;held=0;end
    else begin
      if(held)begin
        if(!output_valid_o || output_data_o!==held_data || output_index_o!==held_index || output_last_o!==held_last)
          $fatal(1,"Unstable x4 BitPkg output");
        stalls++;
      end
      held=output_valid_o && !output_ready_i;held_data=output_data_o;held_index=output_index_o;held_last=output_last_o;
      if(output_valid_o && output_ready_i)begin
        if(expected.size()==0)$fatal(1,"Unexpected packed output");
        want=expected.pop_front();
        if(output_data_o!==want || output_bytes_o!=8 || output_id_o!=command_id_i ||
          output_index_o!=got || output_last_o!=(got+1==256*packet_width/64))
          $fatal(1,"BitPkg byte/framing mismatch op%0d level%0d word%0d got%h want%h",command_op_i,command_param_i,got,output_data_o,want);
        got++;words++;
      end
      if(input_valid_i && input_ready_o && expected_error==0)begin
        for(int i=0;i<4;i++)begin
          value=encode(int'(command_op_i),int'(command_param_i),int'(input_data_i[i]));
          // Independent bit-by-bit serialization:the RTL uses fixed lane
          // concatenations and a144-bit variable-offset reservoir.
          for(int bit_index=0;bit_index<packet_width;bit_index++)begin
            gold[gold_count]=value[bit_index];gold_count++;
            if(gold_count==64)begin expected.push_back(gold);gold=0;gold_count=0;end
          end
          coefficients++;
        end
      end
    end
  end
  task automatic start(input int op,level,id,error=0);
    @(negedge clk);if(!command_ready_o)$fatal(1,"BitPkg command not ready");
    command_op_i=3'(op);command_param_i=2'(level);command_id_i=16'(id);
    packet_width=width_for(op,level);expected_error=error;got=0;gold=0;gold_count=0;expected.delete();
    command_valid_i=1;@(negedge clk);command_valid_i=0;
  endtask
  task automatic send(input int index,input logic [3:0][22:0] data,input bit last);
    @(negedge clk);input_valid_i=1;input_index_i=6'(index);input_data_i=data;input_last_i=last;
    @(posedge clk);while(!input_ready_o)@(posedge clk);
  endtask
  task automatic finish;
    int watchdog;@(negedge clk);input_valid_i=0;watchdog=0;
    while(!done_valid_o)begin @(negedge clk);if(watchdog++>1000)$fatal(1,"BitPkg packet timeout");end
    if(done_code_o!=expected_error || done_id_o!=command_id_i)$fatal(1,"BitPkg unexpected done status");
    if(expected_error==0 && (expected.size()!=0 || gold_count!=0 || got!=packet_width*4))$fatal(1,"BitPkg incomplete packet");
    repeat(4)begin @(negedge clk);if(!done_valid_o || done_code_o!=expected_error)$fatal(1,"BitPkg unstable completion");end
    done_ready_i=1;@(negedge clk);done_ready_i=0;packets++;expected.delete();
  endtask
  initial begin
    logic [3:0][22:0] data;int id;
    command_valid_i=0;command_op_i=0;command_param_i=0;command_id_i=0;input_valid_i=0;
    input_data_i=0;input_index_i=0;input_last_i=0;output_ready_i=0;done_ready_i=0;
    gold=0;gold_count=0;got=0;packet_width=0;expected_error=0;held=0;id=1;
    repeat(3)@(negedge clk);rst=0;
    for(int level=0;level<3;level++)for(int op=0;op<5;op++)for(int variant=0;variant<4;variant++)begin
      start(op,level,id++);
      for(int word_index=0;word_index<64;word_index++)begin
        for(int i=0;i<4;i++)data[i]=sample(op,level,4*word_index+i,variant);
        send(word_index,data,word_index==63);
      end
      finish();
    end
    for(int level=0;level<3;level++)for(int op=0;op<5;op++)for(int lane=0;lane<4;lane++)begin
      start(op,level,id++,2);
      for(int i=0;i<4;i++)data[i]=sample(op,level,i,0);
      case(op)
        0:data[lane]=1024;
        1:data[lane]=23'd8376321; // centered-4096
        2:data[lane]=level==1?5:3;
        3:data[lane]=level==0?44:16;
        4:data[lane]=level==0?23'd131073:23'd524289;
      endcase
      send(0,data,0);finish();
    end
    start(0,3,id++,1);finish();start(7,0,id++,1);finish();
    start(0,0,id++,3);send(1,0,0);finish();
    start(0,0,id++,3);send(0,0,1);finish();
    start(4,2,id++);send(0,0,0);send(1,0,0);
    @(negedge clk);rst=1;input_valid_i=0;repeat(3)@(negedge clk);rst=0;
    start(4,2,id);for(int w=0;w<64;w++)begin
      for(int i=0;i<4;i++)data[i]=sample(4,2,w*4+i,3);
      send(w,data,w==63);
    end
    finish();
    if(stalls==0)$fatal(1,"No packed output stalls checked");
    $display("LIGHTHD_X4_BITPKG_PASS:packets%0d coefficients%0d checked_words%0d stalled_checks%0d;all5formats/all3levels/invalidlanes/framing/reset checked",
      packets,coefficients,words,stalls);
    $finish;
  end
  initial begin #1000000;$fatal(1,"Global BitPkg watchdog");end
endmodule
