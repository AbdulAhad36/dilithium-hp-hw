`timescale 1ps/1ps
module tb_keccak_sampler_memory;
  logic clk=0,rst=1;
  always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i=0,job_ready_o,job_core_o;
  logic [1:0] job_slot_o;
  logic [15:0] job_id_i=0,message_len_i=0;
  logic [1:0] job_mode_i=0,job_param_i=0;
  logic [63:0] input_data_i=0;
  logic input_valid_i=0,input_ready_o;
  logic status_valid_o,status_core_o,status_ready_i=0;
  logic [15:0] status_id_o;
  logic [2:0] status_code_o;
  logic [1:0] active_o;
  logic read_valid_i=0,read_ready_o,response_valid_o,response_error_o;
  logic [1:0] read_slot_i=0,response_slot_o;
  logic [7:0] read_index_i=0,response_index_o;
  logic [22:0] response_data_o;
  logic [15:0] response_id_o;
  logic [1:0] response_mode_o,response_param_o;
  logic response_ntt_domain_o,response_ready_i=0;
  logic release_valid_i=0,release_ready_o;
  logic [1:0] release_slot_i=0;
  logic [3:0] reserved_o,complete_o;
  logic fault_o;
  keccak_sampler_memory dut(.*);
  logic protocol_passed;
  memory_protocol_test protocol_checks(.passed(protocol_passed));
  localparam int JOBS=104;
  int ids[JOBS],modes[JOBS],params[JOBS],abort_expected[JOBS],lengths[JOBS];
  int codes[JOBS],nvalues[JOBS],slots[JOBS],seen[JOBS],read_seen[JOBS];
  int unsigned golden[JOBS][256];
  byte unsigned messages[JOBS][$];
  int owner[2];bit live[2];
  int offered_case,accepted=0,completed=0,errors=0,aborts=0,values=0,reads=0;
  int fd,cycles=0,invalid_reads=0,pool_stalls=0,read_stalls=0,concurrent_rw=0;
  bit hold_status=0,test_passed=0;
  string directory,token;
  bit stalled_response=0;
  logic [54:0] old_response;

  always @(negedge clk) status_ready_i<=!rst && !hold_status && cycles%37>=9;
  always @(posedge clk)begin
    int c,i;
    cycles++;
    if(!rst)begin
      if(fault_o)$fatal(1,"Unexpected memory protocol fault");
      if(stalled_response && (!response_valid_o ||
         {response_error_o,response_slot_o,response_index_o,response_data_o,response_id_o,
          response_mode_o,response_param_o,response_ntt_domain_o}!==old_response))
        $fatal(1,"Memory response changed while stalled");
      stalled_response=response_valid_o && !response_ready_i;
      old_response={response_error_o,response_slot_o,response_index_o,response_data_o,response_id_o,
                    response_mode_o,response_param_o,response_ntt_domain_o};
      if(stalled_response)read_stalls++;
      if(read_valid_i && read_ready_o && dut.coeff_valid && dut.coeff_ready)concurrent_rw++;
      if(job_valid_i && !job_ready_o && reserved_o==15)pool_stalls++;
      if(job_valid_i && job_ready_o)begin
        c=int'(job_core_o);i=offered_case;
        if(live[c] || reserved_o[job_slot_o])$fatal(1,"Allocation reused owned context/slot");
        owner[c]=i;live[c]=1;slots[i]=int'(job_slot_o);seen[i]=0;accepted++;
        $fdisplay(fd,"J %0d %0d %0d %0d",i,c,job_slot_o,ids[i]);
      end
      if(dut.coeff_valid && dut.coeff_ready)begin
        c=int'(dut.coeff_core);i=owner[c];
        if(!live[c] || dut.coeff_id!==16'(ids[i]) || int'(dut.coeff_index)!=seen[i] ||
           seen[i]>=nvalues[i] || dut.coeff_data!==23'(golden[i][seen[i]]) ||
           dut.coeff_last!==(seen[i]==255))$fatal(1,"Store input mismatch case%0d",i);
        $fdisplay(fd,"W %0d %0d %0d %06h %0d",i,c,seen[i],dut.coeff_data,dut.coeff_last);
        seen[i]++;values++;
      end
      if(status_valid_o && status_ready_i)begin
        c=int'(status_core_o);i=owner[c];
        if(!live[c] || abort_expected[i] || status_id_o!==16'(ids[i]) ||
           status_code_o!==3'(codes[i]) || seen[i]!=nvalues[i])$fatal(1,"Retirement mismatch");
        $fdisplay(fd,"S %0d %0d %0d",i,c,status_code_o);
        if(status_code_o==0)completed++;else errors++;
        live[c]=0;
      end
    end else stalled_response=0;
  end

  task automatic reset_all();
    @(negedge clk);
    for(int c=0;c<2;c++)if(live[c])begin
      if(!abort_expected[owner[c]])$fatal(1,"Unexpected abort");
      $fdisplay(fd,"A %0d %0d %0d",owner[c],c,seen[owner[c]]);aborts++;live[c]=0;
    end
    $fdisplay(fd,"X");
    rst=1;job_valid_i=0;input_valid_i=0;read_valid_i=0;response_ready_i=0;release_valid_i=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;
    @(negedge clk);
    if(reserved_o!=0 || complete_o!=0 || response_valid_o || fault_o)$fatal(1,"Reset validity");
  endtask

  task automatic command_and_feed(input int i);
    logic [63:0] word_data;int n,pos;
    @(negedge clk);offered_case=i;job_id_i=16'(ids[i]);job_mode_i=2'(modes[i]);
    job_param_i=2'(params[i]);message_len_i=16'(lengths[i]);job_valid_i=1;
    do @(posedge clk);while(!job_ready_o);
    @(negedge clk);job_valid_i=0;pos=0;
    while(pos<lengths[i])begin
      repeat((i+pos)%3)@(negedge clk);
      n=lengths[i]-pos;if(n>8)n=8;
      word_data='1;for(int b=0;b<n;b++)word_data[8*b+:8]=messages[i][pos+b];
      @(negedge clk);input_data_i=word_data;input_valid_i=1;
      do @(posedge clk);while(!input_ready_o);
      @(negedge clk);input_valid_i=0;pos+=n;
    end
  endtask
  task automatic wait_idle();
    do @(negedge clk);while(active_o!=0 || live[0] || live[1]);
  endtask

  task automatic read_one(input int slot,index,case_id,stall_cycles=0);
    @(negedge clk);read_slot_i=2'(slot);read_index_i=8'(index);read_valid_i=1;response_ready_i=0;
    do @(posedge clk);while(!read_ready_o);
    @(negedge clk);read_valid_i=0;
    if(!response_valid_o || response_slot_o!==2'(slot) || response_index_o!==8'(index))
      $fatal(1,"Read handshake/tag");
    if(case_id<0)begin
      if(!response_error_o)$fatal(1,"Premature/stale read succeeded");
      $fdisplay(fd,"E %0d %0d",slot,index);invalid_reads++;
    end else begin
      if(response_error_o || response_data_o!==23'(golden[case_id][index]) ||
         response_id_o!==16'(ids[case_id]) || response_mode_o!==2'(modes[case_id]) ||
         response_param_o!==2'(params[case_id]) || response_ntt_domain_o!==(modes[case_id]==0))
        $fatal(1,"Readback mismatch case%0d slot%0d index%0d got%h expected%h",
          case_id,slot,index,response_data_o,golden[case_id][index]);
      $fdisplay(fd,"R %0d %0d %0d %06h %0d %0d %0d %0d",case_id,slot,index,response_data_o,
        response_id_o,response_mode_o,response_param_o,response_ntt_domain_o);
      reads++;read_seen[case_id]++;
    end
    // Release must wait for an outstanding response, even on its accept edge.
    release_slot_i=2'(slot);release_valid_i=stall_cycles>0 && case_id>=0;
    repeat(stall_cycles)begin
      @(negedge clk);if(release_valid_i && release_ready_o)$fatal(1,"Released stalled read");
    end
    release_valid_i=0;response_ready_i=1;
    @(posedge clk);@(negedge clk);response_ready_i=0;
  endtask
  task automatic release_slot(input int slot);
    @(negedge clk);release_slot_i=2'(slot);release_valid_i=1;
    do @(posedge clk);while(!release_ready_o);
    $fdisplay(fd,"L %0d",slot);
    @(negedge clk);release_valid_i=0;
    if(reserved_o[slot])$fatal(1,"Release failed");
  endtask
  task automatic read_and_release(input int i);
    if(codes[i]==0)begin
      if(!complete_o[slots[i]])$fatal(1,"Successful polynomial not complete");
      for(int k=0;k<256;k++)read_one(slots[i],k,i,k%61==0?3:0);
      release_slot(slots[i]);
      read_one(slots[i],255,-1);
    end else if(reserved_o[slots[i]])$fatal(1,"Failed polynomial retained");
  endtask

  initial begin
    int inf,expf,count,idx,flag,parsed;int unsigned v;
    string input_token,expected_token,hex_message;byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage2_inputs.txt"},"r");expf=$fopen({directory,"/stage2_expected.txt"},"r");
    if(!inf || !expf)$fatal(1,"Prepare vectors first");
    if($fscanf(inf,"%s %d",input_token,count)!=2 || count!=JOBS)$fatal(1,"Input header");
    if($fscanf(expf,"%s %d",expected_token,count)!=2 || count!=JOBS || input_token!=expected_token)
      $fatal(1,"Golden header");token=input_token;
    for(int i=0;i<JOBS;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],abort_expected[i],lengths[i],hex_message)!=7 || idx!=i)
        $fatal(1,"Input row");
      for(int b=0;b<lengths[i];b++)begin
        parsed=$sscanf(hex_message.substr(2*b,2*b+1),"%h",octet);
        if(parsed!=1)$fatal(1,"Byte parse");messages[i].push_back(octet);
      end
      if($fscanf(expf,"%d %d %d %d",idx,codes[i],flag,nvalues[i])!=4 || idx!=i || flag!=abort_expected[i])$fatal(1,"Expected row");
      for(int k=0;k<nvalues[i];k++)begin
        if($fscanf(expf,"%h",v)!=1)$fatal(1,"Expected value");golden[i][k]=v;
      end
      seen[i]=0;read_seen[i]=0;
    end
    $fclose(inf);$fclose(expf);
    fd=$fopen({directory,"/stage3_outputs.txt"},"w");if(!fd)$fatal(1,"Capture file");
    $fdisplay(fd,"H %s",token);live[0]=0;live[1]=0;reset_all();read_one(0,0,-1);
    hold_status=1;command_and_feed(0);command_and_feed(1);
    read_one(slots[0],0,-1);
    do @(negedge clk);while(seen[0]<256 || seen[1]<256);
    read_one(slots[0],255,-1); // Last coefficient is insufficient without status.
    if(complete_o!=0)$fatal(1,"Published before retirement");
    hold_status=0;wait_idle();command_and_feed(2);command_and_feed(3);
    // Read a completed polynomial while the live peer jobs write other slots.
    for(int k=0;k<256;k++)read_one(slots[0],k,0,k%61==0?3:0);
    wait_idle();
    if(reserved_o!=15 || complete_o!=15)$fatal(1,"Pool not full");
    @(negedge clk);job_valid_i=1;offered_case=4;job_id_i=16'(ids[4]);
    repeat(8)begin @(posedge clk);if(job_ready_o)$fatal(1,"Full pool accepted command");end
    @(negedge clk);job_valid_i=0;
    release_slot(slots[0]);read_one(slots[0],255,-1);
    for(int i=1;i<4;i++)read_and_release(i);
    for(int i=4;i<88;i+=2)begin
      command_and_feed(i);command_and_feed(i+1);wait_idle();
      read_and_release(i);read_and_release(i+1);
    end
    for(int phase=0;phase<4;phase++)begin
      idx=88+4*phase;hold_status=1;
      command_and_feed(idx);command_and_feed(idx+1);
      do @(negedge clk);while(seen[idx]<(phase==1?256:8) || seen[idx+1]<(phase==1?256:8));
      if(phase==2)begin
        read_slot_i=2'(slots[idx]);read_index_i=0;read_valid_i=1;response_ready_i=0;
        do @(posedge clk);while(!read_ready_o);
        @(negedge clk);read_valid_i=0;
        if(!response_valid_o || !response_error_o)$fatal(1,"Reset read target");
      end
      reset_all();hold_status=0;read_one(slots[idx],0,-1);read_one(slots[idx+1],0,-1);
      command_and_feed(idx+2);command_and_feed(idx+3);wait_idle();
      read_and_release(idx+2);read_and_release(idx+3);
    end
    // The companion protocol test also resets a stalled successful response.
    if(accepted!=104 || completed!=88 || errors!=8 || aborts!=8 || reads!=22528 ||
       pool_stalls<8 || read_stalls==0 || concurrent_rw==0 || invalid_reads<90 || !protocol_passed)
      $fatal(1,"Stage3 incomplete acceptance gate");
    for(int i=0;i<JOBS;i++)if(!abort_expected[i] && codes[i]==0 && read_seen[i]!=256)
      $fatal(1,"Missing polynomial readback");
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d",accepted,completed,errors,aborts,values,reads);
    $fclose(fd);
    $display("DILITHIUM_STAGE3_CAPTURE_PASS:104 jobs,88 complete,8 errors,8 aborts,%0d write checks,22528 readback checks",values);
    $display("MEMORY_WITNESSES:invalid_reads=%0d pool_stalls=%0d read_stalls=%0d concurrent_rw=%0d",invalid_reads,pool_stalls,read_stalls,concurrent_rw);
    test_passed=1;$finish;
  end
  initial begin #(64'd8000000000);$fatal(1,"Stage3 watchdog");end
endmodule
