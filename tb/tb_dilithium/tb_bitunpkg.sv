`timescale 1ns/1ps
module tb_bitunpkg;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o,input_valid_i=0,input_ready_o,input_last_i=0;
  logic [2:0] command_op_i=0,done_code_o;
  logic [1:0] command_param_i=0;
  logic [15:0] command_id_i=0,output_id_o,done_id_o;
  logic [63:0] input_data_i=0;
  logic [6:0] input_index_i=0;
  logic [3:0] input_bytes_i=8;
  logic output_valid_o,output_ready_i,output_last_o,done_valid_o,done_ready_i=0;
  logic [91:0] output_data_o;
  logic [4:0] output_count_o;
  logic [7:0] output_index_o;
  bitunpkg dut(.*);
  int cycles=0,got=0,packets=0,coefficients=0,stalls=0,errors=0,resets=0;
  int decoded[256];logic [63:0] words[80];
  logic held=0;logic [91:0] held_data;logic [7:0] held_index;logic held_last;
  always @(negedge clk)cycles++;
  assign output_ready_i=!rst && cycles%11>3;
  always @(posedge clk)if(rst)begin got=0;held=0;end else begin
    if(held)begin
      if(!output_valid_o || {output_data_o,output_index_o,output_last_o}!=={held_data,held_index,held_last})
        $fatal(1,"Unstable shared unpacker output");
      stalls++;
    end
    held=output_valid_o && !output_ready_i;held_data=output_data_o;held_index=output_index_o;held_last=output_last_o;
    if(output_valid_o && output_ready_i)begin
      int amount,value;logic [3:0] nibble;
      amount=command_op_i==2?16:4;
      if(output_id_o!=command_id_i || output_index_o!=got || output_count_o!=amount || output_last_o!=(got+amount==256))
        $fatal(1,"Unpacker framing/index/count mismatch");
      if(command_op_i==2 && output_data_o[91:64]!=0)$fatal(1,"Unpacker compact secret padding");
      for(int lane=0;lane<amount;lane++)begin
        if(command_op_i==2)begin
          nibble=output_data_o[4*lane+:4];value=nibble[3]?int'(nibble)-16:int'(nibble);
          if(value<0)value+=8380417;
        end else value=int'(output_data_o[23*lane+:23]);
        if(value!=decoded[got])$fatal(1,"Unpacker value op%0d level%0d index%0d got%0d want%0d",command_op_i,command_param_i,got,value,decoded[got]);
        got++;coefficients++;
      end
    end
  end
  task automatic run_case(input int op,level,variant,fault=0,input bit abort_run=0);
    int width,eta,gamma,value,encoded,nbits,index,watchdog,expected_error;
    logic [63:0] word;
    width=(op==0 || op==5)?10:op==1?13:op==2?(level==1?4:3):op==3?(level==0?6:4):(level==0?18:20);
    eta=level==1?4:2;gamma=level==0?131072:524288;nbits=0;
    for(int i=0;i<80;i++)words[i]=0;
    for(int i=0;i<256;i++)begin
      case(op)
        0,5:encoded=(i*37+variant*19)%1024;
        1:encoded=(i*97+variant*29)%8192;
        2:encoded=(i+variant)%(2*eta+1);
        3:encoded=(i+variant)%(level==0?44:16);
        default:encoded=(i*7919+variant*31)%(2*gamma);
      endcase
      case(op)
        0:value=encoded;
        5:value=encoded*8192;
        1:value=4096-encoded;
        2:value=eta-encoded;
        3:value=encoded;
        default:value=gamma-encoded;
      endcase
      decoded[i]=value<0?value+8380417:value;
      if(fault==1 && i==19)encoded=op==2?2*eta+1:44;
      // Independent serial-bit construction,not the RTL slice equations.
      for(int bit_index=0;bit_index<width;bit_index++)begin
        words[nbits/64][nbits%64]=encoded[bit_index];nbits++;
      end
    end
    expected_error=fault==1?2:fault>=2?3:level==3 || op>5?1:0;
    @(negedge clk);got=0;command_op_i=3'(op);command_param_i=2'(level);command_id_i++;command_valid_i=1;
    #1;if(!command_ready_o)$fatal(1,"Unpacker not ready for new packet");
    @(negedge clk);command_valid_i=0;index=0;watchdog=0;
    while(!done_valid_o)begin
      if(index<nbits/64)begin
        input_valid_i=cycles%7!=0;input_data_i=words[index];input_index_i=7'(index);
        input_bytes_i=fault==2 && index==1?7:8;
        if(fault==3 && index==1)input_index_i=0;
        input_last_i=fault==4 && index==1?1:index+1==nbits/64;
        @(posedge clk);if(input_valid_i && input_ready_o)index++;
        @(negedge clk);
      end else begin input_valid_i=0;@(negedge clk);end
      if(abort_run && got!=0)begin
        rst=1;input_valid_i=0;repeat(3)@(negedge clk);rst=0;resets++;return;
      end
      if(watchdog++>2000)$fatal(1,"Unpacker timeout");
    end
    input_valid_i=0;
    if(done_code_o!=expected_error || done_id_o!=command_id_i || (expected_error==0 && got!=256))
      $fatal(1,"Unpacker completion op%0d level%0d gotcode%0d expected%0d coefficients%0d",op,level,done_code_o,expected_error,got);
    repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=expected_error)$fatal(1,"Unstable unpacker completion");end
    if(expected_error!=0)errors++;
    done_ready_i=1;@(negedge clk);done_ready_i=0;packets++;
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int op=0;op<6;op++)for(int level=0;level<3;level++)for(int variant=0;variant<3;variant++)
      run_case(op,level,variant);
    for(int level=0;level<3;level++)run_case(2,level,0,1);
    run_case(3,0,0,1);
    for(int op=0;op<6;op++)begin
      for(int fault=2;fault<=4;fault++)run_case(op,0,0,fault);
      run_case(op,3,0);run_case(op,0,1,0,1);run_case(op,0,2);
    end
    run_case(6,0,0);
    $display("LIGHTHD_BITUNPKG_PASS:packets%0d coefficients%0d invalid%0d reset_recoveries%0d held_output_checks%0d;6 formats/all levels/each invalid eta field and framing",packets,coefficients,errors,resets,stalls);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Unpacker global watchdog");end
endmodule
