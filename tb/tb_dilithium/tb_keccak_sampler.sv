`timescale 1ps/1ps
module tb_keccak_sampler;
  logic clk=0,rst=1;
  // Exactly6757ps between rising edges;the FPGA constraint is6.757ns.
  always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i=0,job_ready_o,job_core_o;
  logic [15:0] job_id_i=0,message_len_i=0;
  logic [1:0] job_mode_i=0,job_param_i=0;
  logic [63:0] input_data_i=0;
  logic input_valid_i=0,input_ready_o;
  logic [22:0] output_data_o;
  logic output_core_o,output_last_o,output_valid_o,output_ready_i=0;
  logic [15:0] output_id_o;
  logic [7:0] output_index_o;
  logic status_valid_o,status_core_o,status_ready_i=0;
  logic [15:0] status_id_o;
  logic [2:0] status_code_o;
  logic [1:0] active_o;
  keccak_sampler dut(
    .raw_valid_i(1'b0),.raw_ready_o(),.raw_core_o(),.raw_mode_i(1'b0),
    .raw_id_i(16'd0),.raw_message_len_i(16'd0),.raw_output_len_i(16'd0),
    .raw_input_data_i(64'd0),.raw_input_valid_i(1'b0),.raw_input_ready_o(),
    .raw_output_valid_o(),.raw_output_core_o(),.raw_output_id_o(),
    .raw_output_data_o(),.raw_output_bytes_o(),.raw_output_ready_i(1'b0),
    .raw_done_valid_o(),.raw_done_core_o(),.raw_done_id_o(),.raw_done_ready_i(1'b0),.*);

  localparam int JOBS=104;
  int ids[JOBS],modes[JOBS],params[JOBS],abort_expected[JOBS],lengths[JOBS];
  int codes[JOBS],nvalues[JOBS];
  int unsigned golden[JOBS][256];
  byte unsigned messages[JOBS][$];
  int owner[2],seen[JOBS];
  bit live[2];
  int offered_case,accepted=0,complete=0,errors=0,aborts=0,values=0;
  int cycles=0,drops=0,cancellations=0,hash_stalls=0,overlap=0,retirement_wait=0;
  int bridge_full_cycles=0,bridge_push_pop=0;
  bit force_output_stall=0,force_status_stall=0;
  bit prev_out_stall=0,prev_status_stall=0,prev_hash_stall=0;
  logic [48:0] prev_out;
  logic [19:0] prev_status;
  logic [133:0] prev_hash;
  logic [1:0] prev_stop=0,prev_discard=0;
  int fd,perf_fd;
  int start_c[JOBS],first_hash_c[JOBS],first_sample_c[JOBS];
  int first_out_c[JOBS],last_out_c[JOBS],stop_c[JOBS];
  bit test_passed=0;
  string directory,token;

  always @(negedge clk) begin
    output_ready_i <= !rst && !force_output_stall && cycles%127>=40;
    status_ready_i <= !rst && !force_status_stall && cycles%193>=80;
  end

  always @(posedge rst) begin
    for(int core=0;core<2;core++)if(live[core])begin
      if(!abort_expected[owner[core]])$fatal(1,"Unexpected reset abort");
      $fdisplay(fd,"A %0d %0d %0d",owner[core],core,seen[owner[core]]);
      $fdisplay(perf_fd,"%0d,%0d,%0d,%0d,%0d,1,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
        owner[core],ids[owner[core]],core,modes[owner[core]],params[owner[core]],
        start_c[owner[core]],first_hash_c[owner[core]],first_sample_c[owner[core]],
        first_out_c[owner[core]],last_out_c[owner[core]],stop_c[owner[core]],cycles);
      aborts++;live[core]=0;
    end
    prev_out_stall=0;prev_status_stall=0;prev_hash_stall=0;
    prev_stop=0;prev_discard=0;
  end

  always @(posedge clk)begin
    int c,i;
    cycles++;
    if(!rst)begin
      if(prev_out_stall && (!output_valid_o ||
         {output_data_o,output_core_o,output_id_o,output_index_o,output_last_o} !== prev_out))
        $fatal(1,"Coefficient offer changed under stall");
      if(prev_status_stall && (!status_valid_o ||
         {status_core_o,status_id_o,status_code_o} !== prev_status))
        $fatal(1,"Status offer changed under stall");
      if(prev_hash_stall && (!dut.hash_valid ||
         {dut.hash_data,dut.hash_bytes,dut.hash_core} !== prev_hash))
        $fatal(1,"Keccak offer withdrawn/changed before drain handshake");
      if(((dut.stop_r & ~prev_stop) & ~prev_discard)!=0)
        $fatal(1,"Keccak stop did not follow a discarded release handshake");
      prev_out_stall=output_valid_o && !output_ready_i;
      prev_out={output_data_o,output_core_o,output_id_o,output_index_o,output_last_o};
      prev_status_stall=status_valid_o && !status_ready_i;
      prev_status={status_core_o,status_id_o,status_code_o};
      prev_hash_stall=dut.hash_valid && !dut.hash_ready;
      prev_hash={dut.hash_data,dut.hash_bytes,dut.hash_core};
      prev_stop=dut.stop_r;prev_discard=0;
      if(dut.hash_fire && dut.discard)begin prev_discard[dut.hash_core]=1;drops++;end
      if(dut.bridge_cancel)cancellations++;
      if(dut.bridge_count_r==2)bridge_full_cycles++;
      if(dut.bridge_push && dut.bridge_pop)bridge_push_pop++;
      if(dut.hash_valid && !dut.hash_ready)hash_stalls++;
      if(active_o==3)overlap++;
      if(dut.sampler_status_valid && !dut.quiesced)retirement_wait++;
      if(job_valid_i && job_ready_o)begin
        c=int'(job_core_o);i=offered_case;
        if(live[c])$fatal(1,"Reused live context");
        owner[c]=i;live[c]=1;seen[i]=0;accepted++;
        start_c[i]=cycles;first_hash_c[i]=-1;first_sample_c[i]=-1;
        first_out_c[i]=-1;last_out_c[i]=-1;stop_c[i]=-1;
        $fdisplay(fd,"J %0d %0d %0d",i,c,ids[i]);
      end
      for(int core=0;core<2;core++)if(live[core])begin
        i=owner[core];
        if(dut.hash_fire && dut.hash_core==core && first_hash_c[i]<0)first_hash_c[i]=cycles;
        if(dut.sampler_input_valid && dut.sampler_input_ready && dut.bridge_core_r==core && first_sample_c[i]<0)
          first_sample_c[i]=cycles;
        if(dut.sampler_stop[core] && stop_c[i]<0)stop_c[i]=cycles;
      end
      if(output_valid_o && output_ready_i)begin
        c=int'(output_core_o);i=owner[c];
        if(!live[c] || output_id_o!==16'(ids[i]) || int'(output_index_o)!=seen[i] ||
           seen[i]>=nvalues[i] || output_data_o!==23'(golden[i][seen[i]]) ||
           output_last_o !== (seen[i]==255))
          $fatal(1,"Coefficient mismatch case%0d core%0d index%0d observed%h",i,c,seen[i],output_data_o);
        $fdisplay(fd,"C %0d %0d %0d %06h %0d",i,c,seen[i],output_data_o,output_last_o);
        if(first_out_c[i]<0)first_out_c[i]=cycles;last_out_c[i]=cycles;
        seen[i]++;values++;
      end
      if(status_valid_o && status_ready_i)begin
        c=int'(status_core_o);i=owner[c];
        if(!live[c] || abort_expected[i] || status_id_o!==16'(ids[i]) ||
           status_code_o!==3'(codes[i]) || seen[i]!=nvalues[i] ||
           dut.hash_busy[c] || dut.bridge_pending_for_status)
          $fatal(1,"Status/retirement mismatch case%0d",i);
        $fdisplay(fd,"S %0d %0d %0d",i,c,status_code_o);
        $fdisplay(perf_fd,"%0d,%0d,%0d,%0d,%0d,0,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
          i,ids[i],c,modes[i],params[i],start_c[i],first_hash_c[i],first_sample_c[i],
          first_out_c[i],last_out_c[i],stop_c[i],cycles);
        if(status_code_o==0)complete++;else errors++;
        live[c]=0;
      end
    end
  end

  task automatic command_and_feed(input int i);
    logic [63:0] word_data;
    int n,pos;
    @(negedge clk);
    offered_case=i;job_id_i=16'(ids[i]);job_mode_i=2'(modes[i]);
    job_param_i=2'(params[i]);message_len_i=16'(lengths[i]);job_valid_i=1;
    do @(posedge clk);while(!job_ready_o);
    @(negedge clk);job_valid_i=0;
    pos=0;
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

  task automatic reset_both();
    @(negedge clk);job_valid_i=0;input_valid_i=0;rst=1;
    repeat(3)@(posedge clk);
    @(negedge clk);rst=0;
    repeat(2)@(negedge clk);
  endtask

  initial begin
    int inf,expf,count,idx,flag,len,status,aborted,size,parsed;
    int unsigned v;
    string input_token,expected_token,hex_message;
    byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage2_inputs.txt"},"r");
    expf=$fopen({directory,"/stage2_expected.txt"},"r");
    if(!inf || !expf)$fatal(1,"Run dilithium_vectors.py prepare first");
    if($fscanf(inf,"%s %d",input_token,count)!=2 || count!=JOBS)$fatal(1,"Input header");
    if($fscanf(expf,"%s %d",expected_token,count)!=2 || count!=JOBS || input_token!=expected_token)
      $fatal(1,"Golden header");
    token=input_token;
    for(int i=0;i<JOBS;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],abort_expected[i],lengths[i],hex_message)!=7 || idx!=i)
        $fatal(1,"Input row%0d",i);
      for(int b=0;b<lengths[i];b++)begin
        parsed=$sscanf(hex_message.substr(2*b,2*b+1),"%h",octet);
        if(parsed!=1)$fatal(1,"Message byte parse");messages[i].push_back(octet);
      end
      if($fscanf(expf,"%d %d %d %d",idx,codes[i],flag,nvalues[i])!=4 || idx!=i || flag!=abort_expected[i])
        $fatal(1,"Golden row%0d",i);
      for(int j=0;j<nvalues[i];j++)begin
        if($fscanf(expf,"%h",v)!=1)$fatal(1,"Golden coefficient parse");golden[i][j]=v;
      end
      seen[i]=0;
    end
    $fclose(inf);$fclose(expf);
    fd=$fopen({directory,"/stage2_outputs.txt"},"w");
    perf_fd=$fopen({directory,"/stage2_jobs.csv"},"w");
    if(!perf_fd)$fatal(1,"Cycle witness file");
    $fdisplay(perf_fd,"case,id,core,mode,param,abort,start,first_hash,first_sample,first_output,last_output,source_stop,retired");
    if(!fd)$fatal(1,"Capture file");$fdisplay(fd,"H %s",token);
    live[0]=0;live[1]=0;
    reset_both();
    for(int i=0;i<88;i+=2)begin
      command_and_feed(i);command_and_feed(i+1);wait_idle();
    end
    for(int phase=0;phase<4;phase++)begin
      idx=88+4*phase;
      force_status_stall=1;force_output_stall=phase<2;
      command_and_feed(idx);command_and_feed(idx+1);
      case(phase)
        0:do @(posedge clk);while(!(dut.bridge_count_r==2 && !dut.sampler_input_ready));
        1:begin
          do @(posedge clk);while(!(dut.hash_valid && !dut.hash_ready));
          repeat(2)@(posedge clk);
        end
        2:do @(posedge clk);while(dut.drain_r==0);
        3:do @(posedge clk);while(!(status_valid_o && !status_ready_i));
      endcase
      $display("RESET_TARGET_REACHED phase%0d active%02b",phase,active_o);
      if(active_o!=3)$fatal(1,"Reset did not target both owned jobs");
      reset_both();force_output_stall=0;force_status_stall=0;
      command_and_feed(idx+2);command_and_feed(idx+3);wait_idle();
    end
    repeat(10)@(posedge clk);
    if(accepted!=104 || complete!=88 || errors!=8 || aborts!=8 ||
       drops<96 || cancellations==0 || hash_stalls==0 || overlap==0 || retirement_wait==0 ||
       bridge_full_cycles==0 || bridge_push_pop==0)
      $fatal(1,"Incomplete gate:jobs%0d success%0d errors%0d aborts%0d drops%0d cancel%0d stalls%0d overlap%0d retirewait%0d",
        accepted,complete,errors,aborts,drops,cancellations,hash_stalls,overlap,retirement_wait);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d",accepted,complete,errors,aborts,values);$fclose(fd);$fclose(perf_fd);
    $display("DILITHIUM_STAGE2_CAPTURE_PASS:104 jobs,88 complete,8 expected errors,8 reset aborts,%0d exact coefficient checks",values);
    $display("BRIDGE_WITNESSES drops=%0d cancellations=%0d hash_stalls=%0d overlap_cycles=%0d retirement_wait=%0d",
      drops,cancellations,hash_stalls,overlap,retirement_wait);
    $display("REGISTERED_BRIDGE_PASS:full_cycles=%0d simultaneous_push_pop=%0d",bridge_full_cycles,bridge_push_pop);
    test_passed=1;
    $finish;
  end
  initial begin #(64'd5000000000);$fatal(1,"Stage2 watchdog");end
endmodule
