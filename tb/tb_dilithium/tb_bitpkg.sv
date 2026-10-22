`timescale 1ps/1ps
module tb_bitpkg;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic command_valid_i=0,command_ready_o;logic [1:0] command_op_i=0,command_param_i=0;
  logic [15:0] command_id_i=0;logic input_valid_i=0,input_ready_o;
  logic [22:0] input_data_i=0;logic [7:0] input_index_i=0;logic input_last_i=0;
  logic output_valid_o,output_ready_i=0;logic [63:0] output_data_o;logic [3:0] output_bytes_o;
  logic [6:0] output_index_o;logic output_last_o;logic [15:0] output_id_o;
  logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o;logic [15:0] done_id_o;
  bitpkg dut(.*);
  int ops[97],params[97],ids[97],abort_at[97],codes[97],fault_index[97],fault_kind[97];
  logic [22:0] values[97][256];string directory,token;
  int fd,current=-1,cycle=0,opened=0,finished=0,aborts=0,inputs=0,outputs=0,errors=0,seen=0,words=0;
  bit test_passed=0,held_valid=0;logic [91:0] held_output;
  always @(negedge clk)output_ready_i<=!rst && abort_at[current<0?0:current]!=1 && cycle%17>4;
  always @(posedge clk)begin
    cycle++;
    if(rst)held_valid=0;
    else begin
      if(held_valid && (!output_valid_o || held_output!=={output_id_o,output_index_o,output_bytes_o,output_last_o,output_data_o}))
        $fatal(1,"Bitpkg changed a stalled output");
      held_valid=output_valid_o && !output_ready_i;
      held_output={output_id_o,output_index_o,output_bytes_o,output_last_o,output_data_o};
      if(command_valid_i && command_ready_o)begin
        $fdisplay(fd,"B %0d %0d %0d %0d",current,command_op_i,command_param_i,command_id_i);
        opened++;seen=0;words=0;
      end
      // Consume an old output before appending an accepted input in the ledger.
      if(output_valid_o && output_ready_i)begin
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %016h",current,output_id_o,output_index_o,output_bytes_o,output_last_o,output_data_o);
        outputs++;words++;
      end
      if(input_valid_i && input_ready_o)begin
        $fdisplay(fd,"I %0d %0d %0d %06h",current,input_index_i,input_last_i,input_data_i);seen++;inputs++;
      end
      if(done_valid_o && done_ready_i)begin
        $fdisplay(fd,"D %0d %0d %0d",current,done_id_o,done_code_o);finished++;
        if(done_code_o!=0)errors++;
      end
    end
  end
  task automatic reset_all();
    rst=1;command_valid_i=0;input_valid_i=0;done_ready_i=0;$fdisplay(fd,"X");
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(output_valid_o || done_valid_o || !command_ready_o)$fatal(1,"Bitpkg reset ownership");
  endtask
  task automatic abort_packet(input int c);
    $fdisplay(fd,"A %0d %0d %0d %0d",c,abort_at[c],seen,words);aborts++;reset_all();
  endtask
  task automatic run_case(input int c);
    @(negedge clk);current=c;command_op_i=2'(ops[c]);command_param_i=2'(params[c]);command_id_i=16'(ids[c]);command_valid_i=1;
    do @(posedge clk);while(!command_ready_o);@(negedge clk);command_valid_i=0;
    if(codes[c]!=1)begin
      for(int i=0;i<256;i++)begin
        if(done_valid_o)break;
        repeat(i%3==0?1:0)@(negedge clk);
        input_data_i=values[c][i];input_index_i=8'(i);input_last_i=i==255;
        if(i==fault_index[c])begin
          if(fault_kind[c]==1)input_index_i=8'(i+1);
          if(fault_kind[c]==2)input_last_i=1;
          if(fault_kind[c]==3)input_last_i=0;
        end
        input_valid_i=1;
        do @(posedge clk);while(!input_ready_o && !(abort_at[c]==1 && output_valid_o));
        @(negedge clk);input_valid_i=0;
        if(abort_at[c]==1 && output_valid_o)begin abort_packet(c);return;end
        if(abort_at[c]==0 && i==16)begin abort_packet(c);return;end
      end
    end
    do @(negedge clk);while(!done_valid_o);
    if(done_id_o!=ids[c] || done_code_o!=codes[c])$fatal(1,"Bitpkg completion case%0d code%0d expected%0d",c,done_code_o,codes[c]);
    repeat(4)begin
      @(negedge clk);
      if(!done_valid_o || command_ready_o || output_valid_o)$fatal(1,"Bitpkg held completion");
    end
    done_ready_i=1;@(posedge clk);@(negedge clk);done_ready_i=0;
  endtask
  initial begin
    int f,count,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    f=$fopen({directory,"/stage5_bitpkg_inputs.txt"},"r");
    if(!f || $fscanf(f,"%s %d",token,count)!=2 || count!=97)$fatal(1,"Prepare Bitpkg vectors");
    for(int c=0;c<count;c++)begin
      if($fscanf(f,"%d %d %d %d %d %d %d %d",index,ops[c],params[c],ids[c],abort_at[c],codes[c],fault_index[c],fault_kind[c])!=8 || index!=c)$fatal(1,"Bitpkg fixture");
      for(int i=0;i<256;i++)if($fscanf(f,"%h",values[c][i])!=1)$fatal(1,"Bitpkg coefficient");
    end
    $fclose(f);fd=$fopen({directory,"/stage5_bitpkg_outputs.txt"},"w");$fdisplay(fd,"H %s",token);reset_all();
    for(int c=0;c<count;c++)run_case(c);
    if(opened!=97 || finished!=91 || aborts!=6 || errors!=31)$fatal(1,"Bitpkg completion gate");
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d",opened,finished,aborts,inputs,outputs,errors);
    $fclose(fd);$display("DILITHIUM_STAGE5K_BITPKG_CAPTURE_PASS:97 commands,60 success,31 errors,6 resets;inputs%0d words%0d",inputs,outputs);
    test_passed=1;$finish;
  end
  initial begin #(64'd5000000000);if(!test_passed)$fatal(1,"Bitpkg watchdog case%0d state%0d",current,dut.state);end
endmodule
