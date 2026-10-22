`timescale 1ps/1ps
module tb_sign_process;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic input_valid_i=0,input_ready_o,output_valid_o,output_ready_i=0;
  logic [1:0] input_op_i=0,input_param_i=0,input_kind_i=0,output_op_o,output_param_o,output_kind_o;
  logic [15:0] input_id_i=0,output_id_o;
  logic [5:0] input_index_i=0,output_index_o;
  logic input_last_i=0,output_last_o,output_error_o,output_reject_o;
  logic [3:0][22:0] input_data_i=0;
  logic [3:0][5:0] input_high_i=0,output_high_o;
  logic [3:0][18:0] output_low_o;
  logic [3:0] output_hint_o,output_lane_reject_o;
  logic [8:0] output_weight_o;
  sign_process dut(.*);
  localparam int MAX_CASES=20000;
  int ops[MAX_CASES],params[MAX_CASES],kinds[MAX_CASES],ids[MAX_CASES],indices[MAX_CASES],lasts[MAX_CASES],aborted[MAX_CASES];
  logic [91:0] data[MAX_CASES];logic [23:0] input_high[MAX_CASES],gold_high[MAX_CASES];
  logic [75:0] gold_low[MAX_CASES];
  int errors[MAX_CASES],hints[MAX_CASES],lanes[MAX_CASES],rejects[MAX_CASES],weights[MAX_CASES];
  int pending[$];int offered,count,fd,cycles=0,accepted=0,completed=0,abort_count=0,error_count=0,packets=0;
  int simultaneous=0,input_stalls=0,output_stalls=0;
  bit force_stall=0,test_passed=0,output_held=0,input_held=0;
  logic [147:0] previous_output;logic [144:0] previous_input;
  wire [147:0] observed_output={output_error_o,output_op_o,output_param_o,output_kind_o,output_id_o,
    output_index_o,output_last_o,output_high_o,output_low_o,output_hint_o,output_lane_reject_o,output_reject_o,output_weight_o};
  wire [144:0] observed_input={input_op_i,input_param_i,input_kind_i,input_id_i,input_index_i,input_last_i,input_data_i,input_high_i};
  string directory,token,golden_token;
  always @(negedge clk)output_ready_i<=!rst && !force_stall && cycles%23>5;
  always @(posedge clk)begin
    int i;
    cycles++;
    if(rst)begin input_held=0;output_held=0;end
    else begin
      if(output_held && (!output_valid_o || observed_output!==previous_output))$fatal(1,"Signing-process output changed under stall");
      if(input_held && (!input_valid_i || observed_input!==previous_input))$fatal(1,"Blocked test input changed");
      output_held=output_valid_o && !output_ready_i;previous_output=observed_output;
      input_held=input_valid_i && !input_ready_o;previous_input=observed_input;
      if(output_held)output_stalls++;
      if(input_held)input_stalls++;
      if(input_valid_i && input_ready_o && output_valid_o && output_ready_i)simultaneous++;
      if(output_valid_o && output_ready_i)begin
        if(pending.size()==0)$fatal(1,"Unowned signing-process output");
        i=pending.pop_front();
        if(aborted[i] || output_error_o!==1'(errors[i]) || output_op_o!==2'(ops[i]) ||
          output_param_o!==2'(params[i]) || output_kind_o!==2'(kinds[i]) || output_id_o!==16'(ids[i]) ||
          output_index_o!==6'(indices[i]) || output_last_o!==1'(lasts[i]) ||
          output_high_o!==gold_high[i] || output_low_o!==gold_low[i] || output_hint_o!==4'(hints[i]) ||
          output_lane_reject_o!==4'(lanes[i]) || output_reject_o!==1'(rejects[i]) || output_weight_o!==9'(weights[i]))
          $fatal(1,"Signing-process mismatch case%0d op%0d group%0d actualerr%0d expected%0d",i,ops[i],indices[i],output_error_o,errors[i]);
        $fdisplay(fd,"P %0d %0d %0d %0d %0d %0d %0d %0d %06h %019h %0d %0d %0d %0d",i,
          output_error_o,output_op_o,output_param_o,output_kind_o,output_id_o,output_index_o,output_last_o,
          output_high_o,output_low_o,output_hint_o,output_lane_reject_o,output_reject_o,output_weight_o);
        completed++;if(output_error_o)error_count++;else if(output_last_o)packets++;
      end
      if(input_valid_i && input_ready_o)begin pending.push_back(offered);accepted++;$fdisplay(fd,"J %0d",offered);end
    end
  end
  task automatic reset_pipe();
    int i;
    @(negedge clk);
    while(pending.size()!=0)begin
      i=pending.pop_front();if(!aborted[i])$fatal(1,"Unexpected signing-process abort");
      $fdisplay(fd,"A %0d",i);abort_count++;
    end
    $fdisplay(fd,"X");rst=1;input_valid_i=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(output_valid_o || dut.active_r || dut.reject_r || dut.weight_r)$fatal(1,"Signing-process reset state");
  endtask
  task automatic drive(input int i);
    offered=i;input_op_i=2'(ops[i]);input_param_i=2'(params[i]);input_kind_i=2'(kinds[i]);
    input_id_i=16'(ids[i]);input_index_i=6'(indices[i]);input_last_i=1'(lasts[i]);
    input_data_i=data[i];input_high_i=input_high[i];input_valid_i=1;
  endtask
  task automatic send(input int i);
    drive(i);do @(posedge clk);while(!input_ready_o);@(negedge clk);input_valid_i=0;
  endtask
  task automatic wait_empty();do @(negedge clk);while(pending.size()!=0 || output_valid_o);endtask
  initial begin
    int f,g,n,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    f=$fopen({directory,"/stage5_sign_process_inputs.txt"},"r");g=$fopen({directory,"/stage5_sign_process_expected.txt"},"r");
    if(!f || !g || $fscanf(f,"%s %d",token,count)!=2 || $fscanf(g,"%s %d",golden_token,n)!=2 ||
      n!=count || token!=golden_token || count>MAX_CASES || count<4000)$fatal(1,"Prepare signing-process vectors");
    for(int i=0;i<count;i++)begin
      if($fscanf(f,"%d %d %d %d %d %d %d %d %h %h",index,ops[i],params[i],kinds[i],ids[i],indices[i],lasts[i],aborted[i],data[i],input_high[i])!=10 || index!=i)$fatal(1,"Signing input row");
      if($fscanf(g,"%d %d %h %h %d %d %d %d",index,errors[i],gold_high[i],gold_low[i],hints[i],lanes[i],rejects[i],weights[i])!=8 || index!=i)$fatal(1,"Signing expected row");
    end
    $fclose(f);$fclose(g);fd=$fopen({directory,"/stage5_sign_process_outputs.txt"},"w");
    if(!fd)$fatal(1,"Signing capture open");$fdisplay(fd,"H %s",token);reset_pipe();
    for(int i=0;i<count;i++)begin
      if(aborted[i])begin
        wait_empty();force_stall=1;send(i);drive(i+1);
        repeat(5)begin @(posedge clk);if(input_ready_o)$fatal(1,"Accepted input over held result");end
        reset_pipe();force_stall=0;
      end else begin
        if(i%31==0)repeat(2)@(negedge clk);
        send(i);
      end
    end
    wait_empty();
    if(accepted!=count || completed!=count-6 || abort_count!=6 || error_count==0 ||
      simultaneous<1000 || input_stalls==0 || output_stalls==0 || packets<60)$fatal(1,"Incomplete signing-process campaign");
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d %0d",accepted,completed,abort_count,error_count,simultaneous,input_stalls,output_stalls,packets);
    $fclose(fd);$display("DILITHIUM_STAGE5N2_SIGN_PROCESS_CAPTURE_PASS:%0d groups,%0d exact outputs,%0d errors,6 aborts,%0d complete packets",accepted,completed,error_count,packets);
    test_passed=1;$finish;
  end
  initial begin #(64'd10000000000);$fatal(1,"Signing-process watchdog");end
endmodule
