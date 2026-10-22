`timescale 1ps/1ps
module tb_keccak_sampler_ntt_banks;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i=0,job_ready_o,job_core_o;logic [5:0] job_slot_o;logic [1:0] job_bank_i=0;logic [3:0] job_region_i=0;assign job_slot_o={job_bank_i,job_region_i};
  logic [15:0] job_id_i=0,message_len_i=0;logic [1:0] job_mode_i=0,job_param_i=0;
  logic [63:0] input_data_i=0;logic input_valid_i=0,input_ready_o;
  logic status_valid_o,status_core_o,status_ready_i=0;logic [15:0] status_id_o;logic [2:0] status_code_o;
  logic [1:0] active_o;logic read_valid_i=0,read_ready_o,response_valid_o,response_error_o;
  logic [5:0] read_slot_i=0,response_slot_o;logic [7:0] read_index_i=0,response_index_o;
  logic [1:0] read_bank_i,response_bank_o;logic [3:0] read_region_i,response_region_o;
  logic [5:0] read_word_i,response_word_o;logic [91:0] response_data_o;
  logic [15:0] response_id_o;logic [1:0] response_mode_o,response_param_o;
  logic response_ntt_domain_o,response_small_o,response_ready_i=0;
  logic release_valid_i=0,release_ready_o;logic [5:0] release_slot_i=0;
  logic [1:0] release_bank_i;logic [3:0] release_region_i;
  assign {read_bank_i,read_region_i}=read_slot_i;assign read_word_i=read_index_i[5:0];
  assign response_slot_o={response_bank_o,response_region_o};assign response_index_o={2'd0,response_word_o};
  assign {release_bank_i,release_region_i}=release_slot_i;
  logic [63:0] reserved_o,complete_o;logic fault_o;
  logic op_valid_i=0,op_ready_o,op_busy_o;logic [1:0] op_i=0;
  logic [5:0] op_a_slot_i=0,op_b_slot_i=0,op_dest_region_i=0;
  wire [5:0] op_a_region_i=op_a_slot_i,op_b_region_i=op_b_slot_i;
  logic [15:0] op_a_id_i=0,op_b_id_i=0,op_id_i=0;
  logic op_done_valid_o,op_done_ready_i=0;logic [2:0] op_done_code_o;
  logic [15:0] op_done_id_o;logic [5:0] op_done_region_o;
  wire [5:0] op_done_slot_o=op_done_region_o;
  keccak_sampler_ntt_banks dut(
    .sign_i('0),.sign_o(),
    .raw_valid_i(1'b0),.raw_ready_o(),.raw_core_o(),.raw_mode_i(1'b0),
        .raw_id_i(16'd0),.raw_message_len_i(16'd0),.raw_output_len_i(16'd0),
        .raw_input_data_i(64'd0),.raw_input_valid_i(1'b0),.raw_input_ready_o(),
        .raw_output_valid_o(),.raw_output_core_o(),.raw_output_id_o(),.raw_output_data_o(),.raw_output_bytes_o(),
        .raw_output_ready_i(1'b0),.raw_done_valid_o(),.raw_done_core_o(),.raw_done_id_o(),.raw_done_ready_i(1'b0),
    .process_valid_i(1'b0),.process_ready_o(),.process_busy_o(),.process_op_i(2'd0),.process_inplace_i(1'b0),
    .process_a_i(6'd0),.process_b_i(6'd0),.process_dest_i(6'd0),.process_high_i(6'd0),
    .process_a_id_i(16'd0),.process_b_id_i(16'd0),.process_id_i(16'd0),
    .process_done_valid_o(),.process_done_ready_i(1'b0),.process_done_code_o(),.process_done_id_o(),
    .process_done_dest_o(),.process_done_high_o(),.*);
  int layout=0;bit reservation_seen=0;
  function automatic int place(input int i);
    case(i) 0:return 0;1:return layout==0?1:17;2:return layout==0?2:32;default:return 63;endcase
  endfunction
  function automatic int free_region();
    for(int k=0;k<4;k++)if(!reserved_o[place(k)])return place(k);
    return place(3);
  endfunction
  function automatic bit full_pool();
    return reserved_o[place(0)] && reserved_o[place(1)] && reserved_o[place(2)] && reserved_o[place(3)];
  endfunction

  int ids[104],modes[104],params[104],lengths[104];byte unsigned messages[104][$];
  int unsigned sample_values[104][256],math_values[26][256],slot_values[64][256];
  int slot_id[64],slot_mode[64],slot_param[64],slot_domain[64];
  int owner[2],sample_case[32],sample_slot[32],sample_id[32],sample_seen[32];bit sample_live[2];
  int offered_case,offered_id,last_sample_slot;
  int samples=0,sample_complete=0,sample_writes=0,ops=0,good=0,rejected=0,aborted=0;
  int current_op=-1,current_math,expected_code,op_seen=0,op_dest=0,op_mode,op_param,op_domain;
  int current_result_id,loads=0,starts=0,reads=0,result_writes=0,fd,cycles=0;
  int pool_wait=0,done_stalls=0,response_stalls=0,source_lock_checks=0,read_lock_checks=0,result_lock_checks=0;
  bit op_live=0,test_passed=0,prev_response_stall=0,prev_done_stall=0;
  logic [129:0] old_response;logic [24:0] old_done;
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
      if(dut.state==3 && full_pool() && !dut.alloc_ready)pool_wait++;
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
        current_op=ops;ops++;op_live=1;reservation_seen=0;op_seen=0;loads=0;starts=0;current_result_id=int'(op_id_i);
        op_mode=slot_mode[op_a_slot_i];op_param=slot_param[op_a_slot_i];op_domain=(op_i!=1);
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %0d %0d %0d",current_op,op_i,
          op_a_slot_i,op_a_id_i,op_b_slot_i,op_b_id_i,op_id_i,op_dest_region_i);
      end
      if(op_live && !reservation_seen && (dut.state==4 || op_done_valid_o))begin
        reservation_seen=1;op_dest=int'(op_dest_region_i);
        if(dut.code_r!==3'(expected_code))$fatal(1,"Bank reservation code mismatch got%0d expected%0d",dut.code_r,expected_code);
        $fdisplay(fd,"V %0d %0d %0d",current_op,dut.code_r,op_dest);
        if(expected_code==0)begin
          if(complete_o[op_a_slot_i] || (op_i==2 && complete_o[op_b_slot_i]))$fatal(1,"Missing source lease");
          source_lock_checks++;
        end
      end
      for(int bank=0;bank<4;bank++)begin
        int who,region,wordidx,writer;region=0;wordidx=0;writer=0;who=0;
        if(dut.store.request_valid[0][bank] && dut.store.request_ready[0][bank])begin
          region=16*bank+int'(dut.store.request_address[0][bank][9:6]);
          wordidx=int'(dut.store.request_address[0][bank][5:0]);
          writer=(dut.store.context_valid_r[0] && dut.store.word_valid_r[0] && !dut.store.word_sent_r[0] &&
            dut.store.context_region_r[0][5:4]==2'(bank))?0:1;
          who=op_live?current_op:owner[writer];
          $fdisplay(fd,"P %s %0d %0d %0d %023h",op_live?"N":"S",who,region,wordidx,dut.store.request_data[0][bank]);
        end
        if(dut.store.response_valid[0][bank] && dut.store.response_ready[0][bank])begin
          region=16*bank+int'(dut.store.response_address[0][bank][9:6]);
          wordidx=int'(dut.store.response_address[0][bank][5:0]);writer=int'(dut.store.bank_owner_r[bank]);
          who=op_live?current_op:owner[writer];
          $fdisplay(fd,"Q %s %0d %0d %0d",op_live?"N":"S",who,region,wordidx);
        end
      end
      if(dut.ntt_start)starts++;
      if(dut.s_valid && dut.s_ready)begin
        $fdisplay(fd,"T %0d %0d %0d %0d %0d %06h",current_op,loads,
          dut.source_region,response_id_o,{dut.load_word_r,dut.lane_r},dut.s_data);
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
    {job_bank_i,job_region_i}=6'(free_region());job_id_i=16'(offered_id);job_mode_i=2'(modes[c]);job_param_i=2'(params[c]);
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
    bit expected_small;
    @(negedge clk);read_slot_i=6'(s);read_index_i=8'(k);read_valid_i=1;response_ready_i=0;
    do @(posedge clk);while(!read_ready_o);
    @(negedge clk);read_valid_i=0;
    if(reads==0 && !invalid)begin
      op_valid_i=1;
      repeat(4)begin @(negedge clk);if(op_ready_o)$fatal(1,"Compute stole an outstanding external read");read_lock_checks++;end
      op_valid_i=0;
    end
    do @(negedge clk);while(!response_valid_o);
    if(response_error_o!==invalid || response_slot_o!==6'(s) || response_index_o!==8'(k))$fatal(1,"Read tag/validity");
    if(invalid)$fdisplay(fd,"E %0d %0d",s,4*k);
    else begin
      expected_small=1;
      for(int n=0;n<256;n++)if(slot_values[s][n]>4 && slot_values[s][n]<8380413)expected_small=0;
      if(response_id_o!==16'(slot_id[s]) || response_mode_o!==2'(slot_mode[s]) || response_param_o!==2'(slot_param[s]) ||
         response_ntt_domain_o!==1'(slot_domain[s]) || response_small_o!==expected_small)$fatal(1,"Metadata mismatch");
      for(int lane=0;lane<4;lane++)begin
        if(response_data_o[23*lane+:23]!==23'(slot_values[s][4*k+lane]))$fatal(1,"Packed bank result mismatch");
        $fdisplay(fd,"R %0d %0d %06h %0d %0d %0d %0d %0d",s,4*k+lane,response_data_o[23*lane+:23],
          response_id_o,response_mode_o,response_param_o,response_ntt_domain_o,response_small_o);reads++;
      end
    end
    if(k%53==0)repeat(3)@(negedge clk);
    response_ready_i=1;@(posedge clk);@(negedge clk);response_ready_i=0;
  endtask
  task automatic read_poly(input int s);for(int k=0;k<64;k++)read_one(s,k);endtask
  task automatic release_slot(input int s);
    @(negedge clk);release_slot_i=6'(s);release_valid_i=1;
    do @(posedge clk);while(!release_ready_o);
    $fdisplay(fd,"L %0d",s);@(negedge clk);release_valid_i=0;
  endtask
  task automatic begin_op(input int operation,a,b,math_id,code=0,id_override=-1,wrong_a_id=0,dest_override=-1,wrong_b_id=0);
    @(negedge clk);op_i=2'(operation);op_a_slot_i=6'(a);op_b_slot_i=6'(b);op_dest_region_i=6'(free_region());
    op_a_id_i=16'(slot_id[a]+wrong_a_id);op_b_id_i=16'(slot_id[b]);
    if(dest_override>=0)op_dest_region_i=6'(dest_override);
    op_b_id_i=16'(slot_id[b]+wrong_b_id);
    op_id_i=16'(id_override<0?4000+ops:id_override);current_math=math_id;expected_code=code;
    op_valid_i=1;op_done_ready_i=0;
    do @(posedge clk);while(!op_ready_o);
    @(negedge clk);op_valid_i=0;
  endtask
  task automatic finish_op(output int dest);
    do @(negedge clk);while(!op_done_valid_o);
    if(expected_code==0)begin
      release_slot_i=op_done_slot_o;release_valid_i=1;
      repeat(4)begin @(negedge clk);if(release_ready_o)$fatal(1,"Held result released before retirement");result_lock_checks++;end
      release_valid_i=0;
    end else repeat(4)@(negedge clk);
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
    fd=$fopen({directory,"/stage5_ntt_banks_outputs.txt"},"w");if(!fd)$fatal(1,"Capture");
    $fdisplay(fd,"H %s",token);sample_live[0]=0;sample_live[1]=0;reset_all();
    for(int p=0;p<3;p++)begin
      layout=p; base=7*p;sample_job(2*p);a=last_sample_slot;sample_job(6+2*p);s=last_sample_slot;wait_samples();
      run_op(1,a,a,base);temp=op_dest;release_slot(temp); // A already transform-domain
      run_op(0,s,s,base+1);n=op_dest;
      run_op(1,n,n,base+2);temp=op_dest;release_slot(temp); // exact round trip
      run_op(2,n,n,base+4);temp=op_dest;release_slot(temp); // aliased read-only operands
      if(p==0)begin
        begin_op(0,s,s,0,3,-1,0,s);finish_op(temp); // destination aliases A
        begin_op(2,a,n,0,3,-1,0,n);finish_op(temp); // destination aliases B
        begin_op(2,a,n,0,1,-1,0,-1,1);finish_op(temp); // stale B
        run_op(2,a,62,0,1); // missing B
      end
      run_op(0,a,a,0,2);run_op(1,s,s,0,2);run_op(2,s,a,0,2);
      begin_op(0,s,s,0,1,-1,1);finish_op(temp); // stale source ID
      run_op(0,62,62,0,1); // free source slot
      run_op(3,s,s,base+3);temp=op_dest; // Pre equals NTT,retained to fill pool
      if(!full_pool())$fatal(1,"Expected four live polynomials");
      begin_op(2,a,n,base+5);
      release_slot_i=6'(a);
      do @(negedge clk);while(dut.state!=3);
      release_valid_i=1;
      repeat(6)begin
        @(negedge clk);
        if(dut.ntt_busy || reservation_seen)$fatal(1,"No free destination was ignored");
        if(release_ready_o)$fatal(1,"Accepted source could release while waiting for destination");
      end
      release_valid_i=0;
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
        1:do @(negedge clk);while(dut.engine.u_core.state!=2 || dut.state!=7);
        2:do @(negedge clk);while(op_seen<32);
      endcase
      $display("NTT_RESET_TARGET phase%0d loads%0d outputs%0d",phase,loads,op_seen);
      reset_all();read_one(a,0,1);read_one(1,63,1);
      sample_job(7,ids[6]);a=last_sample_slot;wait_samples();
      begin_op(0,a,a,25,0,9000+phase);finish_op(temp);read_poly(temp);read_poly(a);
      release_slot(a);release_slot(temp);
    end
    if(samples!=16 || sample_complete!=16 || sample_writes!=4096 || ops!=54 || good!=30 ||
       rejected!=21 || aborted!=3 || reads!=11776 || pool_wait<18 || done_stalls==0 ||
       response_stalls==0 || source_lock_checks<33 || read_lock_checks!=4 || result_lock_checks!=120 || reserved_o!=0)$fatal(1,"Stage5F completion gate samples%0d ops%0d good%0d rejected%0d aborted%0d reads%0d",samples,ops,good,rejected,aborted,reads);
    $fdisplay(fd,"G %0d %0d %0d %0d",pool_wait,source_lock_checks,read_lock_checks,result_lock_checks);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d %0d",samples,ops,good,rejected,aborted,sample_writes,result_writes,reads);
    $fclose(fd);$display("DILITHIUM_STAGE5F_CAPTURE_PASS:16 sampled jobs,54 commands,30 arithmetic results,21 rejections,3 reset aborts,11776 readbacks");
    $display("NTT_MEMORY_WITNESSES:pool_wait=%0d done_stalls=%0d response_stalls=%0d source_locks=%0d read_locks=%0d result_locks=%0d",pool_wait,done_stalls,response_stalls,source_lock_checks,read_lock_checks,result_lock_checks);
    test_passed=1;$finish;
  end
  initial begin #(64'd8000000000);$fatal(1,"Stage5F watchdog");end
endmodule
