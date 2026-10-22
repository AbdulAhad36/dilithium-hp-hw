`timescale 1ps/1ps
module tb_poly_process;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic input_valid_i=0,input_ready_o,output_valid_o,output_ready_i=0;
  logic [1:0] input_op_i=0,output_op_o;
  logic [22:0] input_a_i=0,input_b_i=0,output_residue_o;
  logic [15:0] input_id_i=0,output_id_o;
  logic [7:0] input_index_i=0,output_index_o;
  logic input_last_i=0,output_last_o,output_error_o;
  logic [9:0] output_high_o;
  logic signed [13:0] output_low_o;
  logic [12:0] output_t0_o;
  poly_process dut(.*);
  localparam int MAX_CASES=16000;
  int operation[MAX_CASES],a[MAX_CASES],b[MAX_CASES],ids[MAX_CASES],indices[MAX_CASES],lasts[MAX_CASES];
  int aborted[MAX_CASES],errors[MAX_CASES],residue[MAX_CASES],high[MAX_CASES],low[MAX_CASES],packed_low[MAX_CASES];
  int pending[$];int offered,count,fd,cycles=0,accepted=0,completed=0,abort_count=0,error_count=0;
  int simultaneous=0,output_stalls=0,input_stalls=0;
  bit force_stall=0,test_passed=0,was_output_stalled=0,was_input_stalled=0;
  logic [87:0] previous_output;
  logic [72:0] previous_input;
  string directory,token;
  always @(negedge clk)output_ready_i<=!rst && !force_stall && cycles%29>=7;
  always @(posedge clk)begin
    int i;
    cycles++;
    if(!rst)begin
      if(was_output_stalled && (!output_valid_o ||
        {output_error_o,output_op_o,output_residue_o,output_high_o,output_low_o,output_t0_o,
         output_id_o,output_index_o,output_last_o}!==previous_output))$fatal(1,"Process output changed under stall");
      if(was_input_stalled && (!input_valid_i ||
        {input_op_i,input_a_i,input_b_i,input_id_i,input_index_i,input_last_i}!==previous_input))
        $fatal(1,"Test producer changed blocked input");
      was_output_stalled=output_valid_o && !output_ready_i;
      previous_output={output_error_o,output_op_o,output_residue_o,output_high_o,output_low_o,output_t0_o,
                       output_id_o,output_index_o,output_last_o};
      was_input_stalled=input_valid_i && !input_ready_o;
      previous_input={input_op_i,input_a_i,input_b_i,input_id_i,input_index_i,input_last_i};
      if(was_output_stalled)output_stalls++;
      if(was_input_stalled)input_stalls++;
      if(input_valid_i && input_ready_o && output_valid_o && output_ready_i)simultaneous++;
      if(output_valid_o && output_ready_i)begin
        if(pending.size()==0)$fatal(1,"Output without accepted input");
        i=pending.pop_front();
        if(aborted[i] || output_error_o!==1'(errors[i]) || output_op_o!==2'(operation[i]) ||
           output_residue_o!==23'(residue[i]) || output_high_o!==10'(high[i]) ||
           $signed(output_low_o)!=low[i] || output_t0_o!==13'(packed_low[i]) ||
           output_id_o!==16'(ids[i]) || output_index_o!==8'(indices[i]) || output_last_o!==1'(lasts[i]))
          $fatal(1,"Process mismatch case%0d operation%0d",i,operation[i]);
        $fdisplay(fd,"P %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",i,output_error_o,
          output_residue_o,output_high_o,$signed(output_low_o),output_t0_o,
          output_id_o,output_index_o,output_last_o,output_op_o);
        completed++;if(output_error_o)error_count++;
      end
      if(input_valid_i && input_ready_o)begin
        pending.push_back(offered);accepted++;$fdisplay(fd,"J %0d",offered);
      end
    end else begin was_output_stalled=0;was_input_stalled=0;end
  end
  task automatic reset_pipe();
    int i;
    @(negedge clk);
    while(pending.size()!=0)begin
      i=pending.pop_front();if(!aborted[i])$fatal(1,"Unexpected process reset abort");
      $fdisplay(fd,"A %0d",i);abort_count++;
    end
    $fdisplay(fd,"X");rst=1;input_valid_i=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(output_valid_o)$fatal(1,"Process output survived reset");
  endtask
  task automatic drive(input int i);
    offered=i;input_op_i=2'(operation[i]);input_a_i=23'(a[i]);input_b_i=23'(b[i]);
    input_id_i=16'(ids[i]);input_index_i=8'(indices[i]);input_last_i=1'(lasts[i]);input_valid_i=1;
  endtask
  task automatic send(input int i);
    drive(i);do @(posedge clk);while(!input_ready_o);
    @(negedge clk);input_valid_i=0;
  endtask
  task automatic wait_empty();
    do @(negedge clk);while(pending.size()!=0 || output_valid_o);
  endtask
  initial begin
    int inf,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage5_process_inputs.txt"},"r");
    if(!inf || $fscanf(inf,"%s %d",token,count)!=2 || count>MAX_CASES || count<9000)$fatal(1,"Process vectors header");
    for(int i=0;i<count;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %d %d %d %d %d %d %d",index,operation[i],a[i],b[i],
         ids[i],indices[i],lasts[i],aborted[i],errors[i],residue[i],high[i],low[i],packed_low[i])!=13 || index!=i)
        $fatal(1,"Process vector row");
    end
    $fclose(inf);fd=$fopen({directory,"/stage5_outputs.txt"},"w");if(!fd)$fatal(1,"Process capture");
    $fdisplay(fd,"H %s",token);reset_pipe();
    for(int phase=0;phase<3;phase++)begin
      force_stall=1;send(2*phase);
      if(phase==1)begin
        drive(2*phase+1);
        repeat(5)begin @(posedge clk);if(input_ready_o)$fatal(1,"Blocked producer accepted over full stage");end
      end else repeat(3)@(posedge clk);
      reset_pipe();force_stall=0;send(2*phase+1);wait_empty();
    end
    for(int i=6;i<count;i++)begin
      if(i%31==0)repeat(2)@(negedge clk);
      send(i);
    end
    wait_empty();
    if(accepted!=count || completed!=count-3 || abort_count!=3 || error_count==0 ||
       simultaneous<1000 || input_stalls==0 || output_stalls==0)$fatal(1,"Incomplete process gate");
    $fdisplay(fd,"F %0d %0d %0d %0d",accepted,completed,abort_count,error_count);$fclose(fd);
    $display("DILITHIUM_STAGE5_PROCESS_PASS:%0d accepted,%0d compared,3 reset aborts,%0d expected errors",accepted,completed,error_count);
    $display("PROCESS_WITNESSES:replacement=%0d input_stalls=%0d output_stalls=%0d",simultaneous,input_stalls,output_stalls);
    test_passed=1;$finish;
  end
  initial begin #(64'd4000000000);$fatal(1,"Process watchdog");end
endmodule
