`timescale 1ps/1ps
module tb_keccak_sampler_banks;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i=0,job_ready_o,job_core_o;
  logic [1:0] job_bank_i=0,job_mode_i=0,job_param_i=0;
  logic [3:0] job_region_i=0;
  logic [15:0] job_id_i=0,message_len_i=0;
  logic [63:0] input_data_i=0;logic input_valid_i=0,input_ready_o;
  logic status_valid_o,status_core_o,status_ready_i=0;
  logic [15:0] status_id_o;logic [2:0] status_code_o;logic [1:0] active_o;
  logic read_valid_i=0,read_ready_o,response_valid_o,response_error_o;
  logic [1:0] read_bank_i=0,response_bank_o,response_mode_o,response_param_o;
  logic [3:0] read_region_i=0,response_region_o;
  logic [5:0] read_word_i=0,response_word_o;
  logic [91:0] response_data_o;logic [15:0] response_id_o;
  logic response_ntt_domain_o,response_small_o,response_ready_i=0;
  logic release_valid_i=0,release_ready_o;logic [1:0] release_bank_i=0;logic [3:0] release_region_i=0;
  logic [63:0] reserved_o,complete_o;logic fault_o;
  keccak_sampler_banks dut(.*);
  logic protocol_passed;
  bank_store_protocol_test protocol_checks(.passed(protocol_passed));
  localparam int JOBS=104;
  int ids[JOBS],modes[JOBS],params[JOBS],abort_expected[JOBS],lengths[JOBS],codes[JOBS],nvalues[JOBS];
  int seen[JOBS],read_seen[JOBS],packed_seen[JOBS],ack_seen[JOBS],slot_case[64],owner[2];
  int unsigned golden[JOBS][256];byte unsigned messages[JOBS][$];bit live[2];
  int cycles=0,fd,offered_case,accepted=0,completed=0,errors=0,aborts=0,values=0,reads=0,commits=0,acks=0;
  int invalid_reads=0,region_stalls=0,read_stalls=0,overlap=0,reset_held_reads=0;
  bit hold_status=0,test_passed=0,stalled_response=0;
  logic [126:0] old_response;
  string directory,token;
  function automatic int slot_for(input int i);
    case(i%64)1:return 16;16:return 1;3:return 17;17:return 3;default:return i%64;endcase
  endfunction
  function automatic bit bounded(input int i);
    for(int k=0;k<256;k++)if(golden[i][k]>4 && golden[i][k]<8380413)return 0;
    return 1;
  endfunction
  always @(negedge clk)status_ready_i<=!rst && !hold_status && cycles%37>=9;
  always @(posedge clk)begin
    int c,i,s,w;logic [91:0] expected;
    cycles<=cycles+1;
    if(!rst)begin
      if(fault_o)$fatal(1,"Unexpected bank store fault");
      if(stalled_response && (!response_valid_o || {response_error_o,response_bank_o,response_region_o,response_word_o,
         response_data_o,response_id_o,response_mode_o,response_param_o,response_ntt_domain_o,response_small_o}!==old_response))
        $fatal(1,"Bank word response changed under stall");
      stalled_response=response_valid_o && !response_ready_i;
      old_response={response_error_o,response_bank_o,response_region_o,response_word_o,response_data_o,response_id_o,
                    response_mode_o,response_param_o,response_ntt_domain_o,response_small_o};
      if(stalled_response)read_stalls++;
      if(read_valid_i && read_ready_o && dut.coeff_valid && dut.coeff_ready)overlap++;
      if(job_valid_i && !job_ready_o && reserved_o[{job_bank_i,job_region_i}])region_stalls++;
      if(job_valid_i && job_ready_o)begin
        c=int'(job_core_o);i=offered_case;s={job_bank_i,job_region_i};
        if(live[c] || slot_case[s]>=0)$fatal(1,"Region/context reused while owned");
        owner[c]=i;live[c]=1;slot_case[s]=i;accepted++;
        $fdisplay(fd,"J %0d %0d %0d %0d",i,c,s,ids[i]);
      end
      if(dut.coeff_valid && dut.coeff_ready)begin
        c=int'(dut.coeff_core);i=owner[c];
        if(!live[c] || dut.coeff_id!==16'(ids[i]) || dut.coeff_index!=seen[i] || seen[i]>=nvalues[i] ||
           dut.coeff_data!==23'(golden[i][seen[i]]) || dut.coeff_last!==(seen[i]==255))$fatal(1,"Bank store coefficient mismatch");
        $fdisplay(fd,"W %0d %0d %0d %06h %0d",i,c,seen[i],dut.coeff_data,dut.coeff_last);seen[i]++;values++;
      end
      for(int b=0;b<4;b++)begin
        if(dut.store.request_valid[0][b] && dut.store.request_ready[0][b])begin
          s=16*b+int'(dut.store.request_address[0][b][9:6]);w=int'(dut.store.request_address[0][b][5:0]);i=slot_case[s];
          if(i<0 || w!=packed_seen[i] || 4*w+3>=seen[i])$fatal(1,"Packed word owner/index");
          expected=0;for(int lane=0;lane<4;lane++)expected[23*lane+:23]=23'(golden[i][4*w+lane]);
          if(dut.store.request_data[0][b]!==expected)$fatal(1,"Packed lane mismatch");
          $fdisplay(fd,"K %0d %0d %0d %023h",i,s,w,dut.store.request_data[0][b]);packed_seen[i]++;commits++;
        end
        if(dut.store.response_valid[0][b] && dut.store.response_ready[0][b])begin
          s=16*b+int'(dut.store.response_address[0][b][9:6]);w=int'(dut.store.response_address[0][b][5:0]);i=slot_case[s];
          if(i<0 || w!=ack_seen[i])$fatal(1,"Packed ack owner/index");
          $fdisplay(fd,"B %0d %0d %0d",i,s,w);ack_seen[i]++;acks++;
        end
      end
      if(status_valid_o && status_ready_i)begin
        c=int'(status_core_o);i=owner[c];s=slot_for(i);
        if(!live[c] || abort_expected[i] || status_id_o!==16'(ids[i]) || status_code_o!==3'(codes[i]) ||
           seen[i]!=nvalues[i] || (status_code_o==0 && ack_seen[i]!=64))$fatal(1,"Premature bank publication");
        $fdisplay(fd,"S %0d %0d %0d",i,c,status_code_o);live[c]=0;
        if(status_code_o==0)completed++;else begin errors++;slot_case[s]=-1;end
      end
    end else stalled_response=0;
  end
  task automatic reset_all;
    @(negedge clk);
    for(int c=0;c<2;c++)if(live[c])begin
      if(!abort_expected[owner[c]])$fatal(1,"Unexpected reset abort");
      $fdisplay(fd,"A %0d %0d %0d",owner[c],c,seen[owner[c]]);aborts++;live[c]=0;
    end
    $fdisplay(fd,"X");rst=1;job_valid_i=0;input_valid_i=0;read_valid_i=0;response_ready_i=0;release_valid_i=0;
    for(int s=0;s<64;s++)slot_case[s]=-1;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved_o!=0 || complete_o!=0 || response_valid_o || fault_o)$fatal(1,"Reset retained bank validity");
  endtask
  task automatic set_job(input int i);
    int s;s=slot_for(i);offered_case=i;job_id_i=16'(ids[i]);job_mode_i=2'(modes[i]);job_param_i=2'(params[i]);
    message_len_i=16'(lengths[i]);job_bank_i=2'(s/16);job_region_i=4'(s%16);job_valid_i=1;
  endtask
  task automatic command_and_feed(input int i);
    int pos,n;logic [63:0] word_data;
    @(negedge clk);set_job(i);do @(posedge clk);while(!job_ready_o);@(negedge clk);job_valid_i=0;pos=0;
    while(pos<lengths[i])begin
      repeat((i+pos)%3)@(negedge clk);n=lengths[i]-pos;if(n>8)n=8;
      word_data='1;for(int b=0;b<n;b++)word_data[8*b+:8]=messages[i][pos+b];
      @(negedge clk);input_data_i=word_data;input_valid_i=1;do @(posedge clk);while(!input_ready_o);
      @(negedge clk);input_valid_i=0;pos+=n;
    end
  endtask
  task automatic wait_idle;
    do @(negedge clk);while(active_o!=0 || live[0] || live[1]);
  endtask
  task automatic read_one(input int s,w,i,stall=0);
    logic [91:0] expected;
    @(negedge clk);read_bank_i=2'(s/16);read_region_i=4'(s%16);read_word_i=6'(w);read_valid_i=1;response_ready_i=0;
    do @(posedge clk);while(!read_ready_o);@(negedge clk);read_valid_i=0;
    do @(negedge clk);while(!response_valid_o);
    if({response_bank_o,response_region_o}!==6'(s) || response_word_o!==6'(w))$fatal(1,"Word response address");
    if(i<0)begin if(!response_error_o)$fatal(1,"Read exposed uncommitted region");end
    else begin
      expected=0;for(int lane=0;lane<4;lane++)expected[23*lane+:23]=23'(golden[i][4*w+lane]);
      if(response_error_o || response_data_o!==expected || response_id_o!==16'(ids[i]) ||
         response_mode_o!==2'(modes[i]) || response_param_o!==2'(params[i]) ||
         response_ntt_domain_o!==(modes[i]==0) || response_small_o!==bounded(i))$fatal(1,"Bank read data/metadata");
    end
    release_bank_i=2'(s/16);release_region_i=4'(s%16);release_valid_i=stall>0 && i>=0;
    repeat(stall)begin @(negedge clk);if(release_ready_o && release_valid_i)$fatal(1,"Released held word response");end
    release_valid_i=0;response_ready_i=1;@(posedge clk);
    if(i<0)begin $fdisplay(fd,"E %0d %0d",s,w);invalid_reads++;end
    else begin
      $fdisplay(fd,"R %0d %0d %0d %023h %0d %0d %0d %0d %0d",i,s,w,response_data_o,
        response_id_o,response_mode_o,response_param_o,response_ntt_domain_o,response_small_o);reads++;read_seen[i]++;
    end
    @(negedge clk);response_ready_i=0;
  endtask
  task automatic release_region(input int s);
    @(negedge clk);release_bank_i=2'(s/16);release_region_i=4'(s%16);release_valid_i=1;
    do @(posedge clk);while(!release_ready_o);$fdisplay(fd,"L %0d",s);@(negedge clk);release_valid_i=0;slot_case[s]=-1;
    if(reserved_o[s])$fatal(1,"Region release failed");
  endtask
  task automatic read_poly(input int i);
    if(codes[i]==0)begin
      if(!complete_o[slot_for(i)])$fatal(1,"Status failed to publish region");
      for(int w=0;w<64;w++)read_one(slot_for(i),w,i,w%17==0?3:0);
    end else if(reserved_o[slot_for(i)])$fatal(1,"Error retained bank region");
  endtask
  initial begin
    int inf,expf,count,idx,flag,parsed;int unsigned v;string input_token,expected_token,hex_message;byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage2_inputs.txt"},"r");expf=$fopen({directory,"/stage2_expected.txt"},"r");
    if(!inf || !expf || $fscanf(inf,"%s %d",input_token,count)!=2 || count!=JOBS ||
       $fscanf(expf,"%s %d",expected_token,count)!=2 || count!=JOBS || input_token!=expected_token)$fatal(1,"Bank sampling vectors");
    token=input_token;
    for(int i=0;i<JOBS;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],abort_expected[i],lengths[i],hex_message)!=7 || idx!=i)
        $fatal(1,"Input row");
      for(int b=0;b<lengths[i];b++)begin parsed=$sscanf(hex_message.substr(2*b,2*b+1),"%h",octet);if(parsed!=1)$fatal(1,"Byte");messages[i].push_back(octet);end
      if($fscanf(expf,"%d %d %d %d",idx,codes[i],flag,nvalues[i])!=4 || idx!=i || flag!=abort_expected[i])$fatal(1,"Expected row");
      for(int k=0;k<nvalues[i];k++)begin if($fscanf(expf,"%h",v)!=1)$fatal(1,"Value");golden[i][k]=v;end
      seen[i]=0;read_seen[i]=0;packed_seen[i]=0;ack_seen[i]=0;
    end
    $fclose(inf);$fclose(expf);fd=$fopen({directory,"/stage5_store_outputs.txt"},"w");if(!fd)$fatal(1,"Capture");
    $fdisplay(fd,"H %s",token);live[0]=0;live[1]=0;reset_all();read_one(0,0,-1);
    hold_status=1;command_and_feed(0);command_and_feed(1);read_one(slot_for(0),0,-1);
    do @(negedge clk);while(seen[0]<256 || seen[1]<256);read_one(slot_for(0),63,-1);
    if(complete_o!=0)$fatal(1,"Published before successful status");hold_status=0;wait_idle();
    command_and_feed(2);command_and_feed(3);read_poly(0);wait_idle();for(int i=1;i<4;i++)read_poly(i);
    for(int i=4;i<64;i+=2)begin command_and_feed(i);command_and_feed(i+1);wait_idle();read_poly(i);read_poly(i+1);end
    if(reserved_o!='1 || complete_o!='1)$fatal(1,"Did not fill every bank region");
    @(negedge clk);set_job(64);repeat(8)begin @(posedge clk);if(job_ready_o)$fatal(1,"Reallocated occupied region");end
    @(negedge clk);job_valid_i=0;
    for(int i=64;i<88;i+=2)begin
      release_region(slot_for(i));release_region(slot_for(i+1));
      command_and_feed(i);command_and_feed(i+1);wait_idle();read_poly(i);read_poly(i+1);
    end
    for(int phase=0;phase<4;phase++)begin
      idx=88+4*phase;
      for(int j=0;j<2;j++)if(reserved_o[slot_for(idx+j)])release_region(slot_for(idx+j));
      hold_status=1;command_and_feed(idx);command_and_feed(idx+1);
      do @(negedge clk);while(seen[idx]<(phase==1?256:8) || seen[idx+1]<(phase==1?256:8));
      if(phase==0 || phase==2)begin
        read_bank_i=0;read_region_i=4;read_word_i=0;read_valid_i=1;response_ready_i=0;
        do @(posedge clk);while(!read_ready_o);@(negedge clk);read_valid_i=0;
        do @(negedge clk);while(!response_valid_o);
        if(response_error_o!==(phase==2))$fatal(1,"Reset response target");reset_held_reads++;
      end
      reset_all();hold_status=0;read_one(slot_for(idx),0,-1);read_one(slot_for(idx+1),0,-1);
      command_and_feed(idx+2);command_and_feed(idx+3);wait_idle();read_poly(idx+2);read_poly(idx+3);
      release_region(slot_for(idx+2));release_region(slot_for(idx+3));
    end
    if(accepted!=104 || completed!=88 || errors!=8 || aborts!=8 || reads!=5632 || region_stalls<8 ||
       read_stalls==0 || overlap==0 || reset_held_reads!=2 || !protocol_passed)$fatal(1,"Incomplete connected bank gate");
    for(int i=0;i<JOBS;i++)if(!abort_expected[i] && codes[i]==0 && (read_seen[i]!=64 || ack_seen[i]!=64))$fatal(1,"Missing word");
    $fdisplay(fd,"G 8");$fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d %0d",accepted,completed,errors,aborts,values,commits,acks,reads);$fclose(fd);
    $display("DILITHIUM_STAGE5_STORE_PASS:104 jobs,88 complete,8 errors,8 aborts,%0d coefficients,%0d packed writes,%0d acks,5632 read words",
      values,commits,acks);
    $display("STORE WITNESSES:region-stall%0d,read-stall%0d,read-write-overlap%0d,held-read-reset%0d,invalid-reads%0d",
      region_stalls,read_stalls,overlap,reset_held_reads,invalid_reads);test_passed=1;$finish;
  end
  initial begin #(64'd8_000_000_000);$fatal(1,"Connected bank timeout");end
endmodule
