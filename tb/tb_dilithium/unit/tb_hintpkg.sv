`timescale 1ns/1ps
module tb_hintpkg;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,cancel_i=0,command_valid_i=0,command_ready_o;
  logic [1:0] command_param_i=0;logic [15:0] command_id_i=0;
  logic input_valid_i=0,input_ready_o,input_last_i=0;logic [3:0] input_hints_i=0;
  logic [2:0] input_row_i=0;logic [5:0] input_word_i=0;
  logic result_valid_o,result_reject_o,output_valid_o,output_ready_i,output_last_o;
  logic [63:0] output_data_o;logic [3:0] output_bytes_o,output_index_o;logic [15:0] output_id_o;
  logic done_valid_o,done_ready_i=0;logic [1:0] done_code_o;
  hintpkg dut(.*);
  int cycles=0,expected_size=0,got=0,packets=0,rejections=0,errors=0,cancels=0,reset_checks=0,stalls=0;
  logic [7:0] expected[88];bit masks[8][256];
  bit allow_output=0,held=0;logic [88:0] snapshot;
  always @(negedge clk)cycles++;
  assign output_ready_i=!rst && allow_output && cycles%11>3;
  always @(posedge clk)if(rst || cancel_i)held=0;else begin
    if(held)begin
      if(!output_valid_o || {output_data_o,output_bytes_o,output_index_o,output_last_o,output_id_o}!==snapshot)
        $fatal(1,"Hint suffix changed while stalled");
      stalls++;
    end
    held=output_valid_o && !output_ready_i;snapshot={output_data_o,output_bytes_o,output_index_o,output_last_o,output_id_o};
    if(output_valid_o && output_ready_i)begin
      logic [63:0] want;int amount;
      want=0;amount=expected_size-got>=8?8:expected_size-got;
      for(int lane=0;lane<amount;lane++)want[8*lane+:8]=expected[got+lane];
      if(amount<=0 || output_data_o!==want || output_bytes_o!=amount || output_index_o!=got/8 ||
        output_last_o!=(got+amount==expected_size) || output_id_o!=command_id_i)$fatal(1,"FIPS hint suffix byte/framing mismatch");
      got+=amount;
    end
  end
  task automatic run_case(input int level,target,fault=0,input int abort_kind=0);
    int k,omega,total,watchdog;bit bad,aborted;
    k=level==0?4:level==1?6:8;omega=level==0?80:level==1?55:75;
    for(int i=0;i<88;i++)expected[i]=0;
    total=0;
    for(int row=0;row<k;row++)begin
      for(int i=0;i<256;i++)begin
        masks[row][i]=((row*256+i)*73+17)%(k*256)<target;
        if(masks[row][i])begin if(total<omega)expected[total]=8'(i);total++;end
      end
      expected[omega+row]=8'(total);
    end
    bad=total>omega;expected_size=omega+k;
    @(negedge clk);got=0;command_param_i=2'(level);command_id_i++;command_valid_i=1;allow_output=0;
    #1;if(!command_ready_o)$fatal(1,"Hint packer not ready");
    @(negedge clk);command_valid_i=0;aborted=0;
    if(level!=3)for(int row=0;row<k;row++)begin
      for(int word=0;word<64;word++)begin
        if(done_valid_o || aborted)break;
        input_valid_i=1;input_row_i=3'(row);input_word_i=6'(word);input_last_i=word==63;
        for(int lane=0;lane<4;lane++)input_hints_i[lane]=masks[row][4*word+lane];
        if(fault==1 && row==0 && word==2)input_row_i=1;
        if(fault==2 && row==0 && word==2)input_word_i=1;
        if(fault==3 && row==0 && word==2)input_last_i=1;
        @(posedge clk);while(!input_ready_o && !done_valid_o)@(posedge clk);
        @(negedge clk);input_valid_i=0;
        if(abort_kind!=0 && row==0 && word==5)begin
          if(abort_kind==1)begin cancel_i=1;@(negedge clk);cancel_i=0;cancels++;end
          else begin rst=1;repeat(3)@(negedge clk);rst=0;reset_checks++;end
          aborted=1;break;
        end
        if(word%7==0)@(negedge clk);
      end
      if(done_valid_o || aborted)break;
    end
    input_valid_i=0;if(aborted)return;
    watchdog=0;
    while(!result_valid_o)begin @(negedge clk);if(watchdog++>100)$fatal(1,"Hint result timeout");end
    if(fault==0 && level!=3 && result_reject_o!=bad)$fatal(1,"Hint weight bound mismatch");
    repeat(5)@(negedge clk);allow_output=1;watchdog=0;
    while(!done_valid_o)begin @(negedge clk);if(watchdog++>100)$fatal(1,"Hint suffix drain timeout");end
    if(done_code_o!=(level==3?1:fault!=0?2:0) || (fault==0 && !bad && level!=3 && got!=expected_size) ||
      ((bad || fault!=0 || level==3) && got!=0))$fatal(1,"Hint suffix completion mismatch");
    repeat(3)begin @(negedge clk);if(!done_valid_o)$fatal(1,"Hint completion unstable");end
    done_ready_i=1;@(negedge clk);done_ready_i=0;packets++;
    if(fault!=0 || level==3)errors++;else if(bad)rejections++;
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int level=0;level<3;level++)begin
      int omega;omega=level==0?80:level==1?55:75;
      run_case(level,0);run_case(level,1);run_case(level,7);run_case(level,8);run_case(level,9);
      run_case(level,omega-1);run_case(level,omega);run_case(level,omega+1);run_case(level,256*(level==0?4:level==1?6:8));
      for(int fault=1;fault<=3;fault++)run_case(level,9,fault);
      run_case(level,omega,0,1);run_case(level,0);
      run_case(level,omega,0,2);run_case(level,0);
    end
    run_case(3,0);
    if(stalls==0 || rejections!=6 || reset_checks!=3 || cancels!=3)$fatal(1,"Missing hint boundary/reset/cancel/stall cases");
    $display("LIGHTHD_HINTPKG_PASS:packets%0d algorithmic_reject%0d format_errors%0d cancels%0d resets%0d held_output_checks%0d;exact FIPS suffix order/counts/padding checked",packets,rejections,errors,cancels,reset_checks,stalls);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Hint packer global watchdog");end
endmodule
