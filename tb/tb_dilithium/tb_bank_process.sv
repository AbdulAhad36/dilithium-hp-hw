`timescale 1ps/1ps
module tb_bank_process;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i=0,job_ready_o,job_core_o;logic [5:0] job_slot_o;logic [1:0] job_bank_i=0;logic [3:0] job_region_i=0;assign job_slot_o={job_bank_i,job_region_i};
  logic [15:0] job_id_i=0,message_len_i=0;logic [1:0] job_mode_i=0,job_param_i=0;
  logic [63:0] input_data_i=0;logic input_valid_i=0,input_ready_o;
  logic status_valid_o,status_core_o,status_ready_i=0;logic [15:0] status_id_o;logic [2:0] status_code_o;
  logic [1:0] active_o;logic read_valid_i=0,read_ready_o,response_valid_o,response_error_o;
  logic [5:0] read_slot_i=0,response_slot_o;logic [7:0] read_index_i=0,response_index_o;
  logic [1:0] read_bank_i=0,response_bank_o;logic [3:0] read_region_i=0,response_region_o;
  logic [5:0] read_word_i=0,response_word_o;logic [91:0] response_data_o;
  logic [15:0] response_id_o;logic [1:0] response_mode_o,response_param_o;
  logic response_ntt_domain_o,response_small_o,response_ready_i=0;
  logic release_valid_i=0,release_ready_o;logic [5:0] release_slot_i=0;
  logic [1:0] release_bank_i=0;logic [3:0] release_region_i=0;

  assign response_slot_o={response_bank_o,response_region_o};assign response_index_o={2'd0,response_word_o};

  logic [63:0] reserved_o,complete_o;logic fault_o;
  logic op_valid_i=0,op_ready_o,op_busy_o;logic [1:0] op_i=0;
  logic [5:0] op_a_slot_i=0,op_b_slot_i=0,op_dest_region_i=0;
  wire [5:0] op_a_region_i=op_a_slot_i,op_b_region_i=op_b_slot_i;
  logic [15:0] op_a_id_i=0,op_b_id_i=0,op_id_i=0;
  logic op_done_valid_o,op_done_ready_i=0;logic [2:0] op_done_code_o;
  logic [15:0] op_done_id_o;logic [5:0] op_done_region_o;
  wire [5:0] op_done_slot_o=op_done_region_o;

  logic process_valid_i=0,process_ready_o,process_busy_o;
  logic process_inplace_i=0;
  logic [1:0] process_op_i=0;logic [5:0] process_a_i=0,process_b_i=0,process_dest_i=0,process_high_i=0;
  logic [15:0] process_a_id_i=0,process_b_id_i=0,process_id_i=0;
  logic process_done_valid_o,process_done_ready_i=0;logic [2:0] process_done_code_o;
  logic [15:0] process_done_id_o;logic [5:0] process_done_dest_o,process_done_high_o;
  keccak_sampler_ntt_banks #(.PROCESS_SERVICE(1)) dut(
    .sign_i('0),.sign_o(),
    .raw_valid_i(1'b0),.raw_ready_o(),.raw_core_o(),.raw_mode_i(1'b0),
        .raw_id_i(16'd0),.raw_message_len_i(16'd0),.raw_output_len_i(16'd0),
        .raw_input_data_i(64'd0),.raw_input_valid_i(1'b0),.raw_input_ready_o(),
        .raw_output_valid_o(),.raw_output_core_o(),.raw_output_id_o(),.raw_output_data_o(),.raw_output_bytes_o(),
        .raw_output_ready_i(1'b0),.raw_done_valid_o(),.raw_done_core_o(),.raw_done_id_o(),.raw_done_ready_i(1'b0),
    .*);
  int ids[104],modes[104],params[104],lengths[104];byte unsigned messages[104][$];
  string directory,token,kind;int fd,step_no=-1,current_sample=0;
  int cycles=0,samples=0,ntts=0,processes=0,aborts=0,values=0,words=0,reads=0;
  int wait_checks=0,done_checks=0,atomic_checks=0,read_checks=0;
  int seen=0,ntt_seen=0;bit test_passed=0;
  always @(negedge clk)status_ready_i<=!rst && cycles%23>4;
  always @(posedge clk)begin
    cycles++;
    if(!rst)begin
      if(fault_o)$fatal(1,"Bank process fault NTTstate%0d processstate%0d",dut.state,dut.process_client.state);
      if(process_busy_o && (job_ready_o || op_ready_o || read_ready_o || process_ready_o))$fatal(1,"Process lost exclusive memory ownership");
      if(job_valid_i && job_ready_o)begin
        $fdisplay(fd,"J %0d %0d %0d %0d %0d",step_no,current_sample,job_core_o,{job_bank_i,job_region_i},job_id_i);samples++;
      end
      if(op_valid_i && op_ready_o)begin
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %0d %0d %0d",step_no,op_i,op_a_region_i,op_b_region_i,op_dest_region_i,op_a_id_i,op_b_id_i,op_id_i);ntts++;
      end
      if(process_valid_i && process_ready_o)begin
        $fdisplay(fd,"C %0d %0d %0d %0d %0d %0d %0d %0d %0d",step_no,process_op_i,process_a_i,process_b_i,process_dest_i,process_high_i,process_a_id_i,process_b_id_i,process_id_i);processes++;
      end
      if(dut.store.alloc_fire)$fdisplay(fd,"V %0d %0d %0d %0d %0d %0d %0d",step_no,dut.store.alloc_core_i,
        {dut.store.alloc_bank_i,dut.store.alloc_region_i},dut.store.alloc_id_i,dut.store.alloc_mode_i,dut.store.alloc_param_i,
        dut.store.alloc_compute_i?dut.store.alloc_ntt_domain_i:dut.store.alloc_mode_i==0);
      if(dut.store.write_fire)begin
        $fdisplay(fd,"W %0d %0d %0d %06h %0d",step_no,dut.store.write_core_i,dut.store.write_index_i,dut.store.write_data_i,dut.store.write_last_i);values++;
      end
      if(dut.store.finish_fire)$fdisplay(fd,"U %0d %0d",step_no,dut.store.finish_core_i);
      for(int bank=0;bank<4;bank++)begin
        if(dut.store.request_valid[0][bank] && dut.store.request_ready[0][bank])begin
          $fdisplay(fd,"P %0d %0d %0d %023h",step_no,16*bank+int'(dut.store.request_address[0][bank][9:6]),
            dut.store.request_address[0][bank][5:0],dut.store.request_data[0][bank]);words++;
        end
        if(dut.store.response_valid[0][bank] && dut.store.response_ready[0][bank])
          $fdisplay(fd,"Q %0d %0d %0d",step_no,16*bank+int'(dut.store.response_address[0][bank][9:6]),dut.store.response_address[0][bank][5:0]);
      end
      if(status_valid_o && status_ready_i)$fdisplay(fd,"S %0d %0d %0d",step_no,status_id_o,status_code_o);
      if(dut.s_valid && dut.s_ready)$fdisplay(fd,"T %0d %0d %0d %06h",step_no,dut.source_region,{dut.load_word_r,dut.lane_r},dut.s_data);
      if(dut.m_valid && dut.m_ready)begin $fdisplay(fd,"N %0d %0d %06h %0d",step_no,ntt_seen,dut.m_data,dut.m_last);ntt_seen++;end
      if(dut.process_client.state==8 && dut.process_client.pp_ready)begin
        $fdisplay(fd,"I %0d %0d %06h %06h",step_no,dut.process_client.index,
          dut.process_client.arithmetic.input_a_i,dut.process_client.arithmetic.input_b_i);seen++;
      end
      if(dut.process_client.pp_valid && dut.process_client.pp_accept)
        $fdisplay(fd,"K %0d %0d %0d %0d %0d %06h %0d %0d %0d %0d",step_no,dut.process_client.pp_index,
          dut.process_client.pp_error,dut.process_client.pp_op,dut.process_client.pp_id,dut.process_client.pp_residue,
          dut.process_client.pp_high,$signed(dut.process_client.pp_low),dut.process_client.pp_t0,dut.process_client.pp_last);
      if(op_done_valid_o && op_done_ready_i)$fdisplay(fd,"D %0d N %0d %0d %0d 0",step_no,op_done_code_o,op_done_id_o,op_done_region_o);
      if(process_done_valid_o && process_done_ready_i)$fdisplay(fd,"D %0d P %0d %0d %0d %0d",step_no,process_done_code_o,process_done_id_o,process_done_dest_o,process_done_high_o);
      if(process_busy_o && process_op_i==2 && dut.process_client.low_owned_r && dut.process_client.state!=13)begin
        if(complete_o[process_dest_i] || (dut.process_client.high_owned_r && complete_o[process_high_i]))$fatal(1,"Partial P2R pair became visible");
        if(dut.store_complete[process_dest_i])begin
          atomic_checks++;
          $fdisplay(fd,"Y %0d %0d %0d %0d %0d %0d %0d",step_no,process_dest_i,process_high_i,
            complete_o[process_dest_i],complete_o[process_high_i],dut.store_complete[process_dest_i],dut.store_complete[process_high_i]);
        end
      end
    end
  end
  task automatic reset_all();
    $fdisplay(fd,"X %0d",step_no);rst=1;job_valid_i=0;input_valid_i=0;op_valid_i=0;process_valid_i=0;
    read_valid_i=0;response_ready_i=0;release_valid_i=0;op_done_ready_i=0;process_done_ready_i=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved_o || complete_o || process_busy_o || op_busy_o || response_valid_o || process_done_valid_o || fault_o)$fatal(1,"Process reset retained ownership");
  endtask
  task automatic sample_job(input int c,region,jobid);
    int n,pos;logic [63:0] data;
    @(negedge clk);current_sample=c;job_mode_i=2'(modes[c]);job_param_i=2'(params[c]);job_id_i=16'(jobid);
    {job_bank_i,job_region_i}=6'(region);message_len_i=16'(lengths[c]);job_valid_i=1;
    do @(posedge clk);while(!job_ready_o);@(negedge clk);job_valid_i=0;pos=0;
    while(pos<lengths[c])begin
      n=lengths[c]-pos;if(n>8)n=8;data='1;
      for(int b=0;b<n;b++)data[8*b+:8]=messages[c][pos+b];
      input_data_i=data;input_valid_i=1;do @(posedge clk);while(!input_ready_o);
      @(negedge clk);input_valid_i=0;pos+=n;
    end
    do @(negedge clk);while(active_o!=0);
  endtask
  task automatic read_region(input int region,invalid);
    for(int wordno=0;wordno<(invalid?1:64);wordno++)begin
      @(negedge clk);{read_bank_i,read_region_i}=6'(region);read_word_i=6'(wordno);read_valid_i=1;
      do @(posedge clk);while(!read_ready_o);@(negedge clk);read_valid_i=0;
      // Offer and cancel a competing process command while the response owns the port.
      if(read_checks==0)begin
        process_valid_i=1;repeat(4)begin @(negedge clk);if(process_ready_o)$fatal(1,"Process stole pending public read");read_checks++;end
        process_valid_i=0;
      end
      do @(negedge clk);while(!response_valid_o);
      if(response_error_o!==1'(invalid) || {response_bank_o,response_region_o}!==6'(region) || response_word_o!==6'(wordno))$fatal(1,"Read response tag");
      if(invalid)$fdisplay(fd,"E %0d %0d",step_no,region);
      else begin
        $fdisplay(fd,"R %0d %0d %0d %023h %0d %0d %0d %0d %0d",step_no,region,wordno,response_data_o,
          response_id_o,response_mode_o,response_param_o,response_ntt_domain_o,response_small_o);reads++;
      end
      repeat(wordno%3)@(negedge clk);response_ready_i=1;@(posedge clk);@(negedge clk);response_ready_i=0;
    end
  endtask
  task automatic release_region(input int region);
    @(negedge clk);{release_bank_i,release_region_i}=6'(region);release_valid_i=1;
    do @(posedge clk);while(!release_ready_o);$fdisplay(fd,"L %0d %0d",step_no,region);
    @(negedge clk);release_valid_i=0;
  endtask
  initial begin
    int f,inf,count,idx,flag,parsed,op,a,b,dest,high,aid,bid,jobid,code,waitregion,abortphase;
    string input_token,hex_message,program_token;byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage2_inputs.txt"},"r");f=$fopen({directory,"/stage5_process_banks_inputs.txt"},"r");
    if(!inf || !f || $fscanf(inf,"%s %d",input_token,count)!=2 || count!=104)$fatal(1,"Prepare process-bank inputs");
    for(int i=0;i<104;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],flag,lengths[i],hex_message)!=7 || idx!=i)$fatal(1,"Sample row");
      for(int k=0;k<lengths[i];k++)begin parsed=$sscanf(hex_message.substr(2*k,2*k+1),"%h",octet);if(parsed!=1)$fatal(1,"Sample byte");messages[i].push_back(octet);end
    end
    $fclose(inf);
    if($fscanf(f,"%s %d",program_token,count)!=2 || program_token!=input_token)$fatal(1,"Program token");
    fd=$fopen({directory,"/stage5_process_banks_outputs.txt"},"w");if(!fd)$fatal(1,"Capture open");$fdisplay(fd,"H %s",input_token);
    for(int i=0;i<count;i++)begin
      step_no=i;
      if($fscanf(f,"%s %d %d %d %d %d %d %d %d %d %d %d",kind,op,a,b,dest,high,aid,bid,jobid,code,waitregion,abortphase)!=12)$fatal(1,"Program row%0d",i);
      case(kind)
        "X":begin @(negedge clk);reset_all();end
        "S":sample_job(op,a,jobid);
        "R":read_region(op,a);
        "P":begin
          @(negedge clk);process_op_i=2'(op);process_a_i=6'(a);process_b_i=6'(b);process_dest_i=6'(dest);process_high_i=6'(high);
          process_a_id_i=16'(aid);process_b_id_i=16'(bid);process_id_i=16'(jobid);process_valid_i=1;seen=0;
          do @(posedge clk);while(!process_ready_o);@(negedge clk);process_valid_i=0;
          if(waitregion>=0)begin
            do @(negedge clk);while(dut.process_client.state!=3);
            {release_bank_i,release_region_i}=6'(a);release_valid_i=1;
            repeat(6)begin @(negedge clk);if(release_ready_o || complete_o[a])$fatal(1,"Waiting process source released");wait_checks++;end
            release_valid_i=0;release_region(waitregion);
          end
          if(abortphase>=0)begin
            case(abortphase)
              0:do @(negedge clk);while(dut.process_client.state!=6);
              1:do @(negedge clk);while(seen<9);
              2:do @(negedge clk);while(dut.process_client.state!=10 || dut.process_client.index!=8);
              3:do @(negedge clk);while(dut.process_client.state!=12);
            endcase
            $fdisplay(fd,"A %0d %0d %0d",step_no,abortphase,seen);aborts++;reset_all();
          end else begin
            do @(negedge clk);while(!process_done_valid_o);
            if(process_done_code_o!==3'(code) || process_done_id_o!==16'(jobid) || process_done_dest_o!==6'(dest) || process_done_high_o!==6'(high))$fatal(1,"Process completion identity/code");
            if(code==0)begin
              if(!complete_o[dest] || (op==2 && !complete_o[high]))$fatal(1,"Incomplete process publication");
              {release_bank_i,release_region_i}=6'(dest);release_valid_i=1;
              repeat(4)begin @(negedge clk);if(release_ready_o)$fatal(1,"Held process result released");done_checks++;end
              if(op==2)begin
                {release_bank_i,release_region_i}=6'(high);
                repeat(4)begin @(negedge clk);if(release_ready_o)$fatal(1,"Held high result released");done_checks++;end
              end
              release_valid_i=0;
            end
            process_done_ready_i=1;@(posedge clk);@(negedge clk);process_done_ready_i=0;
          end
        end
        "N":begin
          @(negedge clk);op_i=2'(op);op_a_slot_i=6'(a);op_b_slot_i=6'(b);op_dest_region_i=6'(dest);
          op_a_id_i=16'(aid);op_b_id_i=16'(bid);op_id_i=16'(jobid);op_valid_i=1;ntt_seen=0;
          do @(posedge clk);while(!op_ready_o);@(negedge clk);op_valid_i=0;
          do @(negedge clk);while(!op_done_valid_o);
          if(op_done_code_o!=0 || op_done_id_o!==16'(jobid))$fatal(1,"NTT chain completion");
          op_done_ready_i=1;@(posedge clk);@(negedge clk);op_done_ready_i=0;
        end
        default:$fatal(1,"Unknown process program action");
      endcase
    end
    if(samples!=23 || ntts!=15 || processes!=71 || aborts!=4 || wait_checks!=36 || done_checks!=188 || read_checks!=4 || atomic_checks<6 || reserved_o!=0)$fatal(1,"Stage5G campaign totals S%0d N%0d P%0d abort%0d wait%0d hold%0d atomic%0d",samples,ntts,processes,aborts,wait_checks,done_checks,atomic_checks);
    $fdisplay(fd,"G %0d %0d %0d %0d",wait_checks,done_checks,read_checks,atomic_checks);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d",samples,ntts,processes,aborts,values,words,reads);
    $fclose(f);$fclose(fd);$display("DILITHIUM_STAGE5G_CAPTURE_PASS:23 sample jobs,15 NTT commands,71 process commands,4 reset aborts;values%0d words%0d reads%0d",values,words,reads);
    test_passed=1;$finish;
  end
  initial begin #(64'd12000000000);if(!test_passed)$fatal(1,"Bank process watchdog step%0d kind%s processstate%0d",step_no,kind,dut.process_client.state);end
endmodule
