`timescale 1ns/1ps
module tb_hintunpkg;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o;logic [1:0] command_param_i=0;logic [15:0] command_id_i=0;
  logic input_valid_i=0,input_ready_o;logic [63:0] input_data_i=0;logic [3:0] input_index_i=0,input_bytes_i=0;logic input_last_i=0;
  logic output_valid_o,output_ready_i,output_last_o;logic [3:0] output_hints_o;logic [2:0] output_row_o;logic [5:0] output_word_o;
  logic [15:0] output_id_o,done_id_o;logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o;
  hintunpkg dut(.*);
  int cycles=0,current=-1,fault=0,abort_phase=-1,completed=0,resets=0,words=0,stalls=0;
  int input_file,output_file,n,serial,level,id,length;string token,hex_data;logic [7:0] data[88];
  logic held=0;logic [29:0] snapshot;bit reset_happened;
  always @(negedge clk)cycles++;
  assign output_ready_i=!rst && cycles%7>=3 && !(abort_phase==2 && output_word_o>=2);
  function automatic bit reset_point;
    case(abort_phase)
      0:return dut.state==dut.FEED && dut.input_word_r>=3;
      1:return dut.state==dut.ORDER && dut.position_r>3;
      2:return output_valid_o && output_word_o>=2 && !output_ready_i;
      default:return 0;
    endcase
  endfunction
  always @(posedge clk)if(rst)held=0;else begin
    if(held && (!output_valid_o || {output_hints_o,output_row_o,output_word_o,output_last_o,output_id_o}!==snapshot))
      $fatal(1,"Hint decoder changed a stalled output");
    held=output_valid_o && !output_ready_i;
    snapshot={output_hints_o,output_row_o,output_word_o,output_last_o,output_id_o};
    if(held)stalls++;
    if(output_valid_o && output_ready_i)begin
      if(output_id_o!=command_id_i || output_last_o!=(output_word_o==63))$fatal(1,"Hint decoder output identity/last");
      $fdisplay(output_file,"H %0d %0d %01h",output_row_o,output_word_o,output_hints_o);words++;
    end
    if(done_valid_o && output_valid_o)$fatal(1,"Hint decoder completed with pending output");
  end
  task automatic feed;
    int word_index,amount,watchdog;word_index=0;watchdog=0;
    while(word_index*8<length && !done_valid_o)begin
      @(negedge clk);input_valid_i=cycles%5!=0;
      if(!input_valid_i)continue;
      input_data_i='1;amount=length-word_index*8>=8?8:length-word_index*8;
      for(int lane=0;lane<amount;lane++)input_data_i[8*lane+:8]=data[word_index*8+lane];
      input_index_i=4'(word_index);input_bytes_i=4'(amount);input_last_i=word_index*8+amount==length;
      if(word_index==0)begin
        if(fault==1)input_bytes_i=0;
        if(fault==2)input_index_i=1;
        if(fault==3)input_last_i=1;
      end
      if(input_last_i && fault==4)input_last_i=0;
      if(word_index*8+amount==length && fault==5)input_bytes_i=4'(amount+1);
      @(posedge clk);while(!input_ready_o && !done_valid_o)begin
        @(posedge clk);if(watchdog++>10000)$fatal(1,"Hint input timeout");
      end
      if(input_ready_o)word_index++;
      @(negedge clk);input_valid_i=0;
    end
  endtask
  initial begin
    int watchdog;logic [2:0] saved_code;
    input_file=$fopen("sim/dilithium/hint_inputs.txt","r");output_file=$fopen("sim/dilithium/hint_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare sparse hint fixtures");
    $fdisplay(output_file,"%s %0d",token,n);repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %s",serial,level,id,fault,abort_phase,length,hex_data)!=7 || serial!=test || length>88)
        $fatal(1,"Hint fixture schema");
      for(int i=0;i<length;i++)data[i]=8'(hex_data.substr(2*i,2*i+1).atohex());
      @(negedge clk);current=serial;command_param_i=2'(level);command_id_i=16'(id);command_valid_i=1;
      #1;if(!command_ready_o)$fatal(1,"Hint decoder not ready");
      $fdisplay(output_file,"J %0d %0d %0d",serial,level,id);
      @(negedge clk);command_valid_i=0;reset_happened=0;
      fork:transaction
        begin
          feed();watchdog=0;
          while(!done_valid_o)begin @(negedge clk);if(watchdog++>10000)$fatal(1,"Hint completion timeout case%0d state%0d",current,dut.state);end
        end
        begin
          if(abort_phase<0)wait(1'b0);
          else begin
            watchdog=0;while(!reset_point())begin @(negedge clk);if(watchdog++>10000)$fatal(1,"Hint reset target unreachable");end
            @(negedge clk);rst=1;input_valid_i=0;reset_happened=1;
          end
        end
      join_any
      disable transaction;input_valid_i=0;
      if(reset_happened)begin
        $fdisplay(output_file,"A %0d",abort_phase);repeat(3)@(negedge clk);rst=0;abort_phase=-1;resets++;
        #1;if(!command_ready_o || output_valid_o || done_valid_o)$fatal(1,"Hint reset did not clear control state");
      end else begin
        if(done_id_o!=command_id_i)$fatal(1,"Hint completion identity");saved_code=done_code_o;
        $fdisplay(output_file,"D %0d",done_code_o);
        repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=saved_code || done_id_o!=command_id_i)$fatal(1,"Hint completion changed under backpressure");end
        done_ready_i=1;@(negedge clk);done_ready_i=0;
      end
      completed++;
    end
    if(resets!=9 || completed!=n || stalls==0)$fatal(1,"Incomplete hint decoder campaign");
    $fdisplay(output_file,"F %0d",completed);$fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_HINT_CAPTURE_PASS:%0d commands/%0d x4 words/9 resets/%0d stalls;independent suffix comparison required",completed,words,stalls);$finish;
  end
  initial begin #100000000;$fatal(1,"Hint decoder global watchdog");end
endmodule
