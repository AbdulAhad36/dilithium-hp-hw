`timescale 1ps/1ps
module tb_keccak_sampler_ntt;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i=0,job_ready_o,job_core_o;logic [1:0] job_slot_o;
  logic [15:0] job_id_i=0,message_len_i=0;logic [1:0] job_mode_i=0,job_param_i=0;
  logic [63:0] input_data_i=0;logic input_valid_i=0,input_ready_o;
  logic status_valid_o,status_core_o,status_ready_i=0;logic [15:0] status_id_o;logic [2:0] status_code_o;
  logic [1:0] active_o;logic read_valid_i=0,read_ready_o,response_valid_o,response_error_o;
  logic [1:0] read_slot_i=0,response_slot_o;logic [7:0] read_index_i=0,response_index_o;
  logic [22:0] response_data_o;logic [15:0] response_id_o;
  logic [1:0] response_mode_o,response_param_o;logic response_ntt_domain_o,response_ready_i=0;
  logic release_valid_i=0,release_ready_o;logic [1:0] release_slot_i=0;
  logic [3:0] reserved_o,complete_o;logic fault_o;
  logic op_valid_i=0,op_ready_o,op_busy_o;logic [1:0] op_i=0,op_a_slot_i=0,op_b_slot_i=0;
  logic [15:0] op_a_id_i=0,op_b_id_i=0,op_id_i=0;
  logic op_done_valid_o,op_done_ready_i=0;logic [2:0] op_done_code_o;
  logic [15:0] op_done_id_o;logic [1:0] op_done_slot_o;
  keccak_sampler_ntt dut(.*);

  int ids[104],modes[104],params[104],lengths[104];byte unsigned messages[104][$];
  int unsigned sample_values[104][256],math_values[26][256],slot_values[4][256];
  int slot_id[4],slot_mode[4],slot_param[4],slot_domain[4];
  int owner[2],sample_case[32],sample_slot[32],sample_id[32],sample_seen[32];bit sample_live[2];
  int offered_case,offered_id,last_sample_slot;
  int samples=0,sample_complete=0,sample_writes=0,ops=0,good=0,rejected=0,aborted=0;
  int current_op=-1,current_math,expected_code,op_seen=0,op_dest=0,op_mode,op_param,op_domain;
  int current_result_id,loads=0,starts=0,reads=0,result_writes=0,fd,cycles=0;
  int pool_wait=0,done_stalls=0,response_stalls=0,source_lock_checks=0;
  bit op_live=0,test_passed=0,prev_response_stall=0,prev_done_stall=0;
  logic [54:0] old_response;logic [20:0] old_done;
  string directory,token;

  always @(negedge clk)status_ready_i<=!rst && cycles%29>5;
  always @(posedge clk)begin
    int c,j,s;
    cycles++;
    if(!rst)begin
      if(fault_o)$fatal(1,"Stage4 internal protocol fault state%0d",dut.state);
      if(prev_response_stall && (!response_valid_o ||
         {response_error_o,response_slot_o,response_index_o,response_data_o,response_id_o,
          response_mode_o,response_param_o,response_ntt_domain_o}!==old_response))$fatal(1,"Read changed under stall");
      prev_response_stall=response_valid_o && !response_ready_i;
      old_response={response_error_o,response_slot_o,response_index_o,response_data_o,response_id_o,
                    response_mode_o,response_param_o,response_ntt_domain_o};
      if(prev_response_stall)response_stalls++;
      if(prev_done_stall && (!op_done_valid_o || {op_done_code_o,op_done_id_o,op_done_slot_o}!==old_done))
        $fatal(1,"Operation completion changed while stalled");
      prev_done_stall=op_done_valid_o && !op_done_ready_i;
      old_done={op_done_code_o,op_done_id_o,op_done_slot_o};
      if(prev_done_stall)done_stalls++;
      if(op_busy_o && job_ready_o)$fatal(1,"Sampling command accepted during sequential NTT ownership");
      if(op_busy_o && op_ready_o)$fatal(1,"Compute command accepted while busy");
      if(dut.state==1 && reserved_o==15 && !dut.exec_ready)pool_wait++;
      if(job_valid_i && job_ready_o)begin
        c=int'(job_core_o);j=samples;
        if(sample_live[c])$fatal(1,"Live sampler reused");
        owner[c]=j;sample_live[c]=1;sample_case[j]=offered_case;sample_id[j]=offered_id;
        sample_slot[j]=int'(job_slot_o);sample_seen[j]=0;last_sample_slot=int'(job_slot_o);
        $fdisplay(fd,"J %0d %0d %0d %0d %0d",j,offered_case,c,job_slot_o,offered_id);samples++;
      end
      if(dut.coeff_valid && dut.coeff_ready)begin
        c=int'(dut.coeff_core);j=owner[c];
        if(!sample_live[c] || dut.coeff_id!==16'(sample_id[j]) ||
           int'(dut.coeff_index)!=sample_seen[j] || sample_seen[j]>=256 ||
           dut.coeff_data!==23'(sample_values[sample_case[j]][sample_seen[j]]) ||
           dut.coeff_last!==(sample_seen[j]==255))$fatal(1,"Sample store mismatch");
        $fdisplay(fd,"W %0d %0d %06h %0d",j,sample_seen[j],dut.coeff_data,dut.coeff_last);
        sample_seen[j]++;sample_writes++;
      end
      if(status_valid_o && status_ready_i)begin
        c=int'(status_core_o);j=owner[c];s=sample_slot[j];
        if(!sample_live[c] || status_code_o!=0 || status_id_o!==16'(sample_id[j]) || sample_seen[j]!=256)
          $fatal(1,"Sample status mismatch");
        $fdisplay(fd,"S %0d %0d %0d",j,status_id_o,status_code_o);sample_live[c]=0;sample_complete++;
        slot_id[s]=sample_id[j];slot_mode[s]=modes[sample_case[j]];slot_param[s]=params[sample_case[j]];
        slot_domain[s]=(slot_mode[s]==0);
        for(int k=0;k<256;k++)slot_values[s][k]=sample_values[sample_case[j]][k];
      end
      if(op_valid_i && op_ready_o)begin
        if(op_live)$fatal(1,"Reused live operation");
        current_op=ops;ops++;op_live=1;op_seen=0;loads=0;starts=0;current_result_id=int'(op_id_i);
        op_mode=slot_mode[op_a_slot_i];op_param=slot_param[op_a_slot_i];op_domain=(op_i!=1);
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %0d %0d",current_op,op_i,
          op_a_slot_i,op_a_id_i,op_b_slot_i,op_b_id_i,op_id_i);
      end
      if(dut.exec_response_valid && dut.state==2)begin
        if(dut.exec_code!==3'(expected_code))$fatal(1,"Reservation rejected incorrectly:got%0d expected%0d",dut.exec_code,expected_code);
        op_dest=int'(dut.exec_slot);
        $fdisplay(fd,"V %0d %0d %0d",current_op,dut.exec_code,op_dest);
        if(expected_code==0)begin
          if(complete_o[op_a_slot_i] || (op_i==2 && complete_o[op_b_slot_i]))$fatal(1,"Sources not locked");
          source_lock_checks++;
        end
      end
      if(dut.ntt_start)starts++;
      if(dut.s_valid && dut.s_ready)begin
        $fdisplay(fd,"T %0d %0d %0d %0d %0d %06h",current_op,loads,
          dut.mem_response_slot,dut.mem_response_id,dut.mem_response_index,dut.mem_response_data);
        loads++;
      end
      if(dut.m_valid && dut.m_ready)begin
        if(!op_live || expected_code!=0 || op_seen>=256 ||
           dut.m_data!==23'(math_values[current_math][op_seen]) || dut.m_last!==(op_seen==255))
          $fatal(1,"NTT result mismatch op%0d index%0d got%h",current_op,op_seen,dut.m_data);
        $fdisplay(fd,"K %0d %0d %06h %0d",current_op,op_seen,dut.m_data,dut.m_last);
        op_seen++;result_writes++;
      end
      if(op_done_valid_o && op_done_ready_i)begin
        if(!op_live || op_done_code_o!==3'(expected_code) || op_done_id_o!==16'(current_result_id) ||
           int'(op_done_slot_o)!=op_dest)$fatal(1,"Operation completion mismatch");
        if(expected_code==0)begin
          if(op_seen!=256 || starts!=1 || loads!=(op_i==2?512:256) ||
             !complete_o[op_dest] || dut.ntt_busy)$fatal(1,"Premature arithmetic commit");
          slot_id[op_dest]=current_result_id;slot_mode[op_dest]=op_mode;
          slot_param[op_dest]=op_param;slot_domain[op_dest]=op_domain;
          for(int k=0;k<256;k++)slot_values[op_dest][k]=math_values[current_math][k];
          good++;
        end else begin
          if(starts!=0 || loads!=0 || op_seen!=0)$fatal(1,"Rejected command touched NTT");rejected++;
        end
        $fdisplay(fd,"D %0d %0d %0d %0d",current_op,op_done_code_o,op_dest,current_result_id);op_live=0;
      end
    end else begin prev_response_stall=0;prev_done_stall=0;end
  end

  task automatic reset_all();
    @(negedge clk);
    if(op_live)begin $fdisplay(fd,"B %0d %0d",current_op,op_seen);op_live=0;aborted++;end
    if(sample_live[0] || sample_live[1])$fatal(1,"Unexpected sampler abort in Stage4");
    $fdisplay(fd,"X");rst=1;job_valid_i=0;input_valid_i=0;op_valid_i=0;
    read_valid_i=0;response_ready_i=0;release_valid_i=0;op_done_ready_i=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved_o || complete_o || response_valid_o || op_done_valid_o || op_busy_o || fault_o)
      $fatal(1,"Old state survived reset");
  endtask
  task automatic sample_job(input int c,input int override_id=-1);
    int n,pos;logic [63:0] word_data;
    @(negedge clk);offered_case=c;offered_id=(override_id<0)?ids[c]:override_id;
    job_id_i=16'(offered_id);job_mode_i=2'(modes[c]);job_param_i=2'(params[c]);
    message_len_i=16'(lengths[c]);job_valid_i=1;
    do @(posedge clk);while(!job_ready_o);
    @(negedge clk);job_valid_i=0;pos=0;
    while(pos<lengths[c])begin
      n=lengths[c]-pos;if(n>8)n=8;word_data='1;
      for(int b=0;b<n;b++)word_data[8*b+:8]=messages[c][pos+b];
      input_data_i=word_data;input_valid_i=1;
      do @(posedge clk);while(!input_ready_o);
      @(negedge clk);input_valid_i=0;pos+=n;
      repeat(pos%3)@(negedge clk);
    end
  endtask
  task automatic wait_samples();do @(negedge clk);while(active_o!=0 || sample_live[0] || sample_live[1]);endtask
  task automatic read_one(input int s,k,input bit invalid=0);
    @(negedge clk);read_slot_i=2'(s);read_index_i=8'(k);read_valid_i=1;response_ready_i=0;
    do @(posedge clk);while(!read_ready_o);
    @(negedge clk);read_valid_i=0;
    if(!response_valid_o || response_error_o!==invalid || response_slot_o!==2'(s) || response_index_o!==8'(k))
      $fatal(1,"Read tag/validity");
    if(invalid)$fdisplay(fd,"E %0d %0d",s,k);
    else begin
      if(response_data_o!==23'(slot_values[s][k]) || response_id_o!==16'(slot_id[s]) ||
         response_mode_o!==2'(slot_mode[s]) || response_param_o!==2'(slot_param[s]) ||
         response_ntt_domain_o!==1'(slot_domain[s]))$fatal(1,"Stored arithmetic/metadata mismatch");
      $fdisplay(fd,"R %0d %0d %06h %0d %0d %0d %0d",s,k,response_data_o,
        response_id_o,response_mode_o,response_param_o,response_ntt_domain_o);reads++;
    end
    if(k%53==0)repeat(3)@(negedge clk);
    response_ready_i=1;@(posedge clk);@(negedge clk);response_ready_i=0;
  endtask
  task automatic read_poly(input int s);for(int k=0;k<256;k++)read_one(s,k);endtask
  task automatic release_slot(input int s);
    @(negedge clk);release_slot_i=2'(s);release_valid_i=1;
    do @(posedge clk);while(!release_ready_o);
    $fdisplay(fd,"L %0d",s);@(negedge clk);release_valid_i=0;
  endtask
  task automatic begin_op(input int operation,a,b,math_id,code=0,id_override=-1,wrong_a_id=0);
    @(negedge clk);op_i=2'(operation);op_a_slot_i=2'(a);op_b_slot_i=2'(b);
    op_a_id_i=16'(slot_id[a]+wrong_a_id);op_b_id_i=16'(slot_id[b]);
    op_id_i=16'(id_override<0?4000+ops:id_override);current_math=math_id;expected_code=code;
    op_valid_i=1;op_done_ready_i=0;
    do @(posedge clk);while(!op_ready_o);
    @(negedge clk);op_valid_i=0;
  endtask
  task automatic finish_op(output int dest);
    do @(negedge clk);while(!op_done_valid_o);
    repeat(4)@(negedge clk);
    dest=int'(op_done_slot_o);op_done_ready_i=1;
    @(posedge clk);@(negedge clk);op_done_ready_i=0;
  endtask
  task automatic run_op(input int operation,a,b,math_id,code=0);
    int dest;begin_op(operation,a,b,math_id,code);finish_op(dest);
    if(code==0)read_poly(dest);
  endtask

  initial begin
    int inf,expf,mathf,count,idx,flag,nvalues,code,parsed;
    int a,s,n,temp,product,coefficient,base;int unsigned v;
    string in_token,ex_token,math_token,hex_message;byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage2_inputs.txt"},"r");expf=$fopen({directory,"/stage2_expected.txt"},"r");
    mathf=$fopen({directory,"/stage4_expected.txt"},"r");
    if(!inf || !expf || !mathf)$fatal(1,"Prepare vectors first");
    if($fscanf(inf,"%s %d",in_token,count)!=2 || count!=104)$fatal(1,"Inputs header");
    if($fscanf(expf,"%s %d",ex_token,count)!=2 || count!=104 || in_token!=ex_token)$fatal(1,"Expected header");
    if($fscanf(mathf,"%s %d",math_token,count)!=2 || count!=26 || in_token!=math_token)$fatal(1,"Arithmetic header");
    token=in_token;
    for(int i=0;i<104;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],flag,lengths[i],hex_message)!=7 || idx!=i)$fatal(1,"Input row");
      for(int k=0;k<lengths[i];k++)begin
        parsed=$sscanf(hex_message.substr(2*k,2*k+1),"%h",octet);
        if(parsed!=1)$fatal(1,"Byte parse");messages[i].push_back(octet);
      end
      if($fscanf(expf,"%d %d %d %d",idx,code,flag,nvalues)!=4 || idx!=i)$fatal(1,"Expected row");
      for(int k=0;k<nvalues;k++)begin
        if($fscanf(expf,"%h",v)!=1)$fatal(1,"Expected value");sample_values[i][k]=v;
      end
    end
    for(int i=0;i<26;i++)begin
      if($fscanf(mathf,"%d",idx)!=1 || idx!=i)$fatal(1,"Math row");
      for(int k=0;k<256;k++)begin
        if($fscanf(mathf,"%h",v)!=1)$fatal(1,"Math value");math_values[i][k]=v;
      end
    end
    $fclose(inf);$fclose(expf);$fclose(mathf);
    fd=$fopen({directory,"/stage4_outputs.txt"},"w");if(!fd)$fatal(1,"Capture");
    $fdisplay(fd,"H %s",token);sample_live[0]=0;sample_live[1]=0;reset_all();
    for(int p=0;p<3;p++)begin
      base=7*p;sample_job(2*p);a=last_sample_slot;sample_job(6+2*p);s=last_sample_slot;wait_samples();
      run_op(1,a,a,base);temp=op_dest;release_slot(temp); // A already transform-domain
      run_op(0,s,s,base+1);n=op_dest;
      run_op(1,n,n,base+2);temp=op_dest;release_slot(temp); // exact round trip
      run_op(2,n,n,base+4);temp=op_dest;release_slot(temp); // aliased read-only operands
      run_op(0,a,a,0,2);run_op(1,s,s,0,2);run_op(2,s,a,0,2);
      begin_op(0,s,s,0,1,-1,1);finish_op(temp); // stale source ID
      run_op(0,3,3,0,1); // free source slot
      run_op(3,s,s,base+3);temp=op_dest; // Pre equals NTT,retained to fill pool
      if(reserved_o!=15)$fatal(1,"Expected four live polynomials");
      begin_op(2,a,n,base+5);
      release_slot_i=2'(a);
      repeat(6)begin
        @(negedge clk);
        if(dut.ntt_busy || dut.exec_response_valid)$fatal(1,"No free destination was ignored");
        if(release_ready_o)$fatal(1,"Accepted source could release while waiting for destination");
      end
      release_slot(temp);finish_op(product);read_poly(product);
      read_poly(a);read_poly(s); // prove arithmetic did not overwrite original inputs
      release_slot(n);run_op(1,product,product,base+6);coefficient=op_dest;
      release_slot(a);release_slot(s);release_slot(product);release_slot(coefficient);
    end
    sample_job(12);a=last_sample_slot;sample_job(18);s=last_sample_slot;wait_samples();
    run_op(3,a,a,0,2); // mask is not a bounded secret
    run_op(0,a,a,21);n=op_dest;run_op(1,n,n,22);temp=op_dest;release_slot(temp);release_slot(n);
    run_op(0,s,s,23);n=op_dest;run_op(1,n,n,24);temp=op_dest;release_slot(temp);release_slot(n);
    run_op(3,s,s,23);temp=op_dest;release_slot(temp); // bounded challenge is eligible too
    read_poly(a);read_poly(s);release_slot(a);release_slot(s);
    sample_job(0);a=last_sample_slot;sample_job(8);s=last_sample_slot;wait_samples();
    run_op(0,s,s,8);n=op_dest;run_op(2,a,n,0,2); // parameter mismatch
    read_poly(a);read_poly(s);release_slot(a);release_slot(s);release_slot(n);
    for(int phase=0;phase<3;phase++)begin
      sample_job(6);a=last_sample_slot;wait_samples();read_poly(a);
      begin_op(0,a,a,1,0,9000+phase);
      case(phase)
        0:do @(negedge clk);while(loads<17);
        1:do @(negedge clk);while(dut.engine.u_core.state!=2 || dut.state!=6);
        2:do @(negedge clk);while(op_seen<32);
      endcase
      $display("NTT_RESET_TARGET phase%0d loads%0d outputs%0d",phase,loads,op_seen);
      reset_all();read_one(a,0,1);read_one(1,255,1);
      sample_job(7,ids[6]);a=last_sample_slot;wait_samples();
      begin_op(0,a,a,25,0,9000+phase);finish_op(temp);read_poly(temp);read_poly(a);
      release_slot(a);release_slot(temp);
    end
    if(samples!=16 || sample_complete!=16 || sample_writes!=4096 || ops!=50 || good!=30 ||
       rejected!=17 || aborted!=3 || reads!=11776 || pool_wait<18 || done_stalls==0 ||
       response_stalls==0 || source_lock_checks<33 || reserved_o!=0)$fatal(1,"Stage4 completion gate samples%0d ops%0d good%0d rejected%0d aborted%0d reads%0d",samples,ops,good,rejected,aborted,reads);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d %0d",samples,ops,good,rejected,aborted,sample_writes,result_writes,reads);
    $fclose(fd);$display("DILITHIUM_STAGE4_CAPTURE_PASS:16 sampled jobs,50 commands,30 arithmetic results,17 rejections,3 reset aborts,11776 readbacks");
    $display("NTT_MEMORY_WITNESSES:pool_wait=%0d done_stalls=%0d response_stalls=%0d source_locks=%0d",pool_wait,done_stalls,response_stalls,source_lock_checks);
    test_passed=1;$finish;
  end
  initial begin #(64'd8000000000);$fatal(1,"Stage4 watchdog");end
endmodule
