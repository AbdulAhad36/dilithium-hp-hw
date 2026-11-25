`timescale 1ns/1ps
module tb_pack_stream #(parameter bit ALLOW_REJECT_PAYLOAD_RESIDUE=0,parameter bit PROBE_FOUR_STATE=0);
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
  always #5 clk=~clk;
  int clocks=0,jobs=0,outputs=0,stalls=0,renewals=0,resets=0,errors=0,rejected_payload_checks=0;
  logic [31:0] rng=32'hc244b17;
  always @(posedge clk)begin
    clocks++;
    if(clocks>500000)$fatal(1,"C24 stream watchdog");
    if({command_ready_o,input_ready_o,output_valid_o,output_bytes_o,output_index_o,output_last_o,output_id_o,done_valid_o,done_code_o,done_id_o}!==
       {ref_command_ready_o,ref_input_ready_o,ref_output_valid_o,ref_output_bytes_o,ref_output_index_o,ref_output_last_o,ref_output_id_o,ref_done_valid_o,ref_done_code_o,ref_done_id_o})
      $fatal(1,"C24 stream pins clock%0d",clocks);
    if(output_valid_o && output_data_o!==ref_output_data_o)$fatal(1,"C24 stream payload");
    // Controls, counts and every live payload bit remain exact. The optional
    // profile permits ONLY discarded reservoir contents after code2/3 until
    // a new command clears it; published words are always compared above.
    if(dut.count_r!==old.count_r || dut.group_r!==old.group_r || dut.state!==old.state)
      $fatal(1,"C24 reservoir control/state clock%0d",clocks);
    if(dut.bits_r!==old.bits_r)begin
      if(!(ALLOW_REJECT_PAYLOAD_RESIDUE && dut.state!=dut.FEED &&
           done_code_o[2:1]===2'b01))
        $fatal(1,"C24 live reservoir payload clock%0d",clocks);
      if(output_valid_o || dut.count_r!=0)$fatal(1,"Rejected payload became visible");
      rejected_payload_checks++;
    end
    if(!rst)begin
      if(output_valid_o && output_ready_i)outputs++;
      if(output_valid_o && !output_ready_i)stalls++;
      if(dut.pop && dut.push)renewals++;
    end
  end
  function automatic int canonical(input int signed_value);
    return signed_value<0?signed_value+8380417:signed_value;
  endfunction
  task automatic sample(input int op,level,index,trial);
    int eta,gamma,span,value;
    eta=level==1?4:2;gamma=level==0?131072:524288;
    for(int lane=0;lane<4;lane++)begin
      value=(index*7919+trial*73+lane*37317);
      case(op)
        0:input_data_i[lane]=23'(value%1024);
        1:input_data_i[lane]=23'(canonical(value%8192-4095));
        2:input_data_i[lane]=23'(canonical(value%(2*eta+1)-eta));
        3:input_data_i[lane]=23'(value%(level==0?44:16));
        default:input_data_i[lane]=23'(canonical(value%(2*gamma)-gamma+1));
      endcase
    end
  endtask
  task automatic run_job(input int op,level,kind,trial);
    int index;bit active,finished,aborted;int start_clock;
    @(negedge clk);command_op_i=3'(op);command_param_i=2'(level);command_id_i=16'(trial);
    command_valid_i=1;output_ready_i=0;done_ready_i=0;input_valid_i=0;
    do @(posedge clk);while(!command_ready_o);
    @(negedge clk);command_valid_i=0;index=0;active=0;finished=0;aborted=0;start_clock=clocks;
    while(!finished)begin
      rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
      output_ready_i=kind==5?(clocks-start_clock>30):(|rng[2:0]);
      done_ready_i=clocks-start_clock>12 && (|rng[4:3]);
      if(!active && index<64 && (|rng[7:5]))begin
        sample(op,level,index,trial);input_index_i=6'(index);input_last_i=index==63;
        if(kind==1 && index==17)input_data_i[trial%4]=23'h7fffff;
        if(kind==2 && index==31)input_index_i=6'd30;
        if(kind==3 && index==15)input_last_i=1;
        if(kind==4 && index==63)input_last_i=0;
        input_valid_i=1;active=1;
      end
      @(posedge clk);
      if(input_valid_i && input_ready_o)begin index++;active=0;end
      if(done_valid_o && done_ready_i)begin
        if(kind==0 && done_code_o!=0)$fatal(1,"C24 valid stream rejected");
        if(kind>=1 && kind<=4 && done_code_o!=(kind==1?2:3))$fatal(1,"C24 malformed stream accepted/code");
        if(kind>=1 && kind<=4)errors++;
        finished=1;
      end
      @(negedge clk);
      if(!active)input_valid_i=0;
      if(kind==5 && dut.count_r!=0 && clocks-start_clock>=6)begin
        rst=1;input_valid_i=0;command_valid_i=0;output_ready_i=0;done_ready_i=0;
        repeat(2)@(negedge clk);rst=0;resets++;aborted=1;finished=1;
      end
    end
    input_valid_i=0;done_ready_i=0;jobs++;
  endtask
  // Four-state probes keep every control/count/public word exact to C22.
  // A definite rejection may have an unknown code bit when framing is X;
  // only its unpublished reservoir may differ,then reset clears both copies.
  task automatic unknown_probe(input int kind,lane);
    @(negedge clk);command_valid_i=1;command_op_i=0;command_param_i=0;
    command_id_i=16'hf040;input_valid_i=0;output_ready_i=0;done_ready_i=0;
    do @(posedge clk);while(!command_ready_o);
    @(negedge clk);command_valid_i=0;input_valid_i=1;input_data_i=0;input_index_i=0;input_last_i=0;
    do @(posedge clk);while(!input_ready_o);
    @(negedge clk);input_index_i=1;
    do @(posedge clk);while(!input_ready_o);
    @(negedge clk);input_index_i=2;output_ready_i=1;
    case(kind)
      0:input_data_i[lane]='x;
      1:input_index_i='x;
      2:begin input_data_i[lane]=23'd8380417;input_index_i='x;end
      3:begin input_data_i[lane]=23'd8380417;input_last_i='x;end
      4:input_last_i='x;
    endcase
    do @(posedge clk);while(!input_ready_o);
    @(negedge clk);input_valid_i=0;
    repeat(2)@(negedge clk);
    rst=1;repeat(2)@(negedge clk);rst=0;
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int trial=0;trial<4;trial++)for(int op=0;op<5;op++)for(int level=0;level<3;level++)
      for(int kind=0;kind<6;kind++)run_job(op,level,kind,trial*90+op*18+level*6+kind);
    if(ALLOW_REJECT_PAYLOAD_RESIDUE || PROBE_FOUR_STATE)begin
      for(int kind=0;kind<5;kind++)for(int lane=0;lane<4;lane++)unknown_probe(kind,lane);
      $display("PACK_FOUR_STATE_PROBES_PASS:20 accepted unknown value/index/last probes;all controls,counts and published words exact");
    end
    if(jobs!=360 || resets!=60 || errors!=240 || outputs==0 || stalls==0 || renewals==0)$fatal(1,"C24 missing stream scenario");
    if(ALLOW_REJECT_PAYLOAD_RESIDUE && rejected_payload_checks==0)$fatal(1,"Missing discarded payload probe");
    $display("PACK_REJECTED_PAYLOAD_ISOLATION_PASS:%0d checked invalid-payload clocks;strict profile%0d",rejected_payload_checks,!ALLOW_REJECT_PAYLOAD_RESIDUE);
    $display("LIGHTHD_PACK_STREAM_EQUIVALENCE_PASS:%0d jobs/%0d resets/%0d malformed/%0d words/%0d stalled/%0d pop-push renewals/%0d clocks;controls/live reservoir/published payload exact C22",jobs,resets,errors,outputs,stalls,renewals,clocks);
    $finish;
  end
endmodule
