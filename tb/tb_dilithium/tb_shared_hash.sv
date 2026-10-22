`timescale 1ps/1ps
module tb_shared_hash;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic job_valid_i,job_ready_o,job_core_o;
  logic [15:0] job_id_i,message_len_i;
  logic [1:0] job_mode_i=0,job_param_i=0;
  logic [63:0] input_data_i;logic input_valid_i,input_ready_o;
  logic [22:0] output_data_o;logic output_core_o,output_last_o,output_valid_o,output_ready_i;
  logic [15:0] output_id_o;logic [7:0] output_index_o;
  logic status_valid_o,status_core_o,status_ready_i;logic [15:0] status_id_o;
  logic [2:0] status_code_o;logic [1:0] active_o;
  logic raw_valid_i,raw_ready_o,raw_core_o,raw_mode_i;
  logic [15:0] raw_id_i,raw_message_len_i,raw_output_len_i;
  logic [63:0] raw_input_data_i;logic raw_input_valid_i,raw_input_ready_o;
  logic raw_output_valid_o,raw_output_core_o;logic [15:0] raw_output_id_o;
  logic [127:0] raw_output_data_o;logic [4:0] raw_output_bytes_o;logic raw_output_ready_i;
  logic raw_done_valid_o,raw_done_core_o;logic [15:0] raw_done_id_o;logic raw_done_ready_i;
  keccak_sampler #(.RAW_SERVICE(1)) dut(.*);

  logic start_valid_i=0,start_ready_o;logic [1:0] start_param_i=0;
  logic [15:0] start_id_i=0;logic [255:0] start_seed_i=0;
  logic result_valid_o,result_ready_i,result_error_o;logic [15:0] result_id_o;
  logic [1:0] result_param_o;logic [255:0] result_rho_o,result_key_o;
  logic [511:0] result_rhoprime_o;
  logic seed_request,seed_ready,seed_mode,seed_input_valid,seed_input_ready,seed_output_ready,seed_done_ready;
  logic [15:0] seed_id,seed_length,seed_output_length;logic [63:0] seed_input_data;
  bit use_seed=1;
  int cycles=0;bit force_raw_output=0,force_raw_done=0,force_result=0;
  wire raw_output_gate=!rst && !force_raw_output && cycles%23>=7;
  wire raw_done_gate=!rst && !force_raw_done && cycles%19>=5;
  assign result_ready_i=!rst && !force_result && cycles%17>=4;
  keygen_seed_collect collector(
    .clk(clk),.rst(rst),.start_valid_i(start_valid_i),.start_ready_o(start_ready_o),
    .start_param_i(start_param_i),.start_id_i(start_id_i),.start_seed_i(start_seed_i),
    .result_valid_o(result_valid_o),.result_ready_i(result_ready_i),.result_error_o(result_error_o),
    .result_id_o(result_id_o),.result_param_o(result_param_o),.result_rho_o(result_rho_o),
    .result_rhoprime_o(result_rhoprime_o),.result_key_o(result_key_o),
    .raw_valid_o(seed_request),.raw_ready_i(seed_ready),.raw_core_i(raw_core_o),.raw_mode_o(seed_mode),
    .raw_id_o(seed_id),.raw_message_len_o(seed_length),.raw_output_len_o(seed_output_length),
    .raw_input_data_o(seed_input_data),.raw_input_valid_o(seed_input_valid),.raw_input_ready_i(seed_input_ready),
    .raw_output_valid_i(raw_output_valid_o && use_seed && raw_output_gate),.raw_output_core_i(raw_output_core_o),
    .raw_output_id_i(raw_output_id_o),.raw_output_data_i(raw_output_data_o),.raw_output_bytes_i(raw_output_bytes_o),
    .raw_output_ready_o(seed_output_ready),.raw_done_valid_i(raw_done_valid_o && use_seed && raw_done_gate),
    .raw_done_core_i(raw_done_core_o),.raw_done_id_i(raw_done_id_o),.raw_done_ready_o(seed_done_ready)
  );
  logic manual_valid=0,manual_mode=0,manual_input_valid=0;
  logic [15:0] manual_id=0,manual_length=0,manual_output_length=0;
  logic [63:0] manual_data=0;
  assign raw_valid_i=use_seed ? seed_request : manual_valid;
  assign raw_mode_i=use_seed ? seed_mode : manual_mode;
  assign raw_id_i=use_seed ? seed_id : manual_id;
  assign raw_message_len_i=use_seed ? seed_length : manual_length;
  assign raw_output_len_i=use_seed ? seed_output_length : manual_output_length;
  assign raw_input_data_i=use_seed ? seed_input_data : manual_data;
  assign raw_input_valid_i=use_seed ? seed_input_valid : manual_input_valid;
  assign seed_ready=use_seed && raw_ready_o;
  assign seed_input_ready=use_seed && raw_input_ready_o;
  assign raw_output_ready_i=raw_output_gate && (!use_seed || seed_output_ready);
  assign raw_done_ready_i=raw_done_gate && (!use_seed || seed_done_ready);
  assign output_ready_i=!rst && cycles%29>=8;
  assign status_ready_i=!rst && cycles%31>=9;

  logic sample_start=0,sample_command_ready,sample_request,sample_mode;
  logic [1:0] sample_op=1,sample_param=0;
  logic [15:0] sample_id=0,sample_nonce=0,sample_done_id,sample_length,sample_output_length;
  logic [7:0] sample_row=0,sample_column=0;
  logic [511:0] sample_seed=0;
  logic sample_done,sample_error;
  logic [255:0] rho_cache[3];logic [511:0] rhoprime_cache[3];
  keygen_hash_message sample_format(
    .clk(clk),.rst(rst),.command_valid_i(sample_start),.command_ready_o(sample_command_ready),
    .command_op_i(sample_op),.command_param_i(sample_param),.command_id_i(sample_id),
    .command_nonce_i(sample_nonce),.command_row_i(sample_row),.command_column_i(sample_column),
    .command_seed_i(sample_seed),.request_valid_o(sample_request),.request_ready_i(job_ready_o),
    .request_mode_o(sample_mode),.request_message_len_o(sample_length),.request_output_len_o(sample_output_length),
    .input_data_o(input_data_i),.input_valid_o(input_valid_i),.input_ready_i(input_ready_o),
    .done_valid_o(sample_done),.done_ready_i(1'b1),.done_error_o(sample_error),.done_id_o(sample_done_id)
  );
  assign job_valid_i=sample_request;assign job_id_i=sample_done_id;assign message_len_i=sample_length;

  localparam int MAX_CASES=40;
  int kinds[MAX_CASES],params[MAX_CASES],ids[MAX_CASES],modes[MAX_CASES],aborted[MAX_CASES];
  int lengths[MAX_CASES],outlengths[MAX_CASES],nonces[MAX_CASES],rows[MAX_CASES],columns[MAX_CASES];
  logic [255:0] seeds[MAX_CASES];logic [3199:0] messages[MAX_CASES];
  int owner[2],word_count[MAX_CASES],byte_count[MAX_CASES],coeff_count[MAX_CASES];
  bit finished[MAX_CASES];int direct_case=-1,seed_case=-1,sample_case=-1;
  int count,fd,accepted=0,raw_jobs=0,sample_jobs=0,seed_results=0,aborts=0,raw_bytes=0,coefficients=0;
  int mixed_cycles=0,raw_peer_cycles=0,raw_output_stalls=0,raw_done_stalls=0,result_stalls=0,arbitration_cycles=0;
  bit test_passed=0,prev_raw=0,prev_done=0,prev_result=0;
  logic [149:0] saved_raw;logic [16:0] saved_done;logic [1042:0] saved_result;
  string directory,token;
  always @(posedge clk)begin
    int i;
    cycles<=cycles+1;
    if(!rst)begin
      if(prev_raw && (!raw_output_valid_o || {raw_output_data_o,raw_output_bytes_o,raw_output_core_o,raw_output_id_o}!==saved_raw))
        $fatal(1,"Raw output changed while stalled");
      if(prev_done && (!raw_done_valid_o || {raw_done_core_o,raw_done_id_o}!==saved_done))$fatal(1,"Raw status changed while stalled");
      if(prev_result && (!result_valid_o || {result_error_o,result_id_o,result_param_o,result_rho_o,result_rhoprime_o,result_key_o}!==saved_result))
        $fatal(1,"Seed result changed while stalled");
      prev_raw=raw_output_valid_o && !raw_output_ready_i;raw_output_stalls+=int'(prev_raw);
      prev_done=raw_done_valid_o && !raw_done_ready_i;raw_done_stalls+=int'(prev_done);
      prev_result=result_valid_o && !result_ready_i;result_stalls+=int'(prev_result);
      saved_raw={raw_output_data_o,raw_output_bytes_o,raw_output_core_o,raw_output_id_o};
      saved_done={raw_done_core_o,raw_done_id_o};
      saved_result={result_error_o,result_id_o,result_param_o,result_rho_o,result_rhoprime_o,result_key_o};
      if(active_o==3)begin
        if(dut.raw_r==3)raw_peer_cycles++;
        else if(dut.raw_r!=0)mixed_cycles++;
      end
      if(raw_valid_i && job_valid_i)begin
        arbitration_cycles++;if(job_ready_o)$fatal(1,"Raw priority accepted sampling simultaneously");
      end
      if(start_valid_i && start_ready_o)begin $fdisplay(fd,"J %0d",seed_case);accepted++;end
      if(raw_valid_i && raw_ready_o)begin
        i=use_seed?seed_case:direct_case;if(owner[raw_core_o]!=-1)$fatal(1,"Raw descriptor overwrote owner");
        if(!use_seed)begin $fdisplay(fd,"J %0d",i);accepted++;end
        owner[raw_core_o]=i;raw_jobs++;
        $fdisplay(fd,"R %0d %0d %0d %0d %0d %0d",i,raw_core_o,raw_id_i,raw_mode_i,raw_message_len_i,raw_output_len_i);
      end
      if(raw_input_valid_i && raw_input_ready_o)begin
        i=use_seed?seed_case:direct_case;
        $fdisplay(fd,"W %0d %0d %016h",i,word_count[i],raw_input_data_i);word_count[i]++;
      end
      if(raw_output_valid_o && raw_output_ready_i)begin
        i=owner[raw_output_core_o];if(i<0 || ids[i]!=raw_output_id_o)$fatal(1,"Raw output owner mismatch");
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %032h",i,raw_output_core_o,raw_output_id_o,byte_count[i],raw_output_bytes_o,raw_output_data_o);
        byte_count[i]+=int'(raw_output_bytes_o);raw_bytes+=int'(raw_output_bytes_o);
      end
      if(raw_done_valid_o && raw_done_ready_i)begin
        i=owner[raw_done_core_o];if(i<0 || ids[i]!=raw_done_id_o)$fatal(1,"Raw done owner mismatch");
        $fdisplay(fd,"D %0d %0d %0d",i,raw_done_core_o,raw_done_id_o);owner[raw_done_core_o]=-1;
        if(kinds[i]==0)finished[i]=1;
      end
      if(result_valid_o && result_ready_i)begin
        i=seed_case;if(result_id_o!==16'(ids[i]) || result_param_o!==2'(params[i]))$fatal(1,"Seed result tag");
        $fdisplay(fd,"Z %0d %0d %0d %0d %064h %0128h %064h",i,result_error_o,result_id_o,result_param_o,
          result_rho_o,result_rhoprime_o,result_key_o);
        seed_results++;finished[i]=1;
        if(!result_error_o)begin rho_cache[result_param_o]=result_rho_o;rhoprime_cache[result_param_o]=result_rhoprime_o;end
      end
      if(job_valid_i && job_ready_o)begin
        i=sample_case;if(owner[job_core_o]!=-1)$fatal(1,"Sampling descriptor overwrote owner");
        owner[job_core_o]=i;accepted++;sample_jobs++;
        $fdisplay(fd,"J %0d",i);$fdisplay(fd,"S %0d %0d %0d %0d %0d %0d",i,job_core_o,job_id_i,job_mode_i,job_param_i,message_len_i);
      end
      if(input_valid_i && input_ready_o)begin
        i=sample_case;$fdisplay(fd,"P %0d %0d %016h",i,word_count[i],input_data_i);word_count[i]++;
      end
      if(output_valid_o && output_ready_i)begin
        i=owner[output_core_o];if(i<0 || ids[i]!=output_id_o || output_index_o!=coeff_count[i] || output_last_o!=(output_index_o==255))
          $fatal(1,"Sample output ownership/order");
        $fdisplay(fd,"C %0d %0d %0d %0d %06h %0d",i,output_core_o,output_id_o,output_index_o,output_data_o,output_last_o);
        coeff_count[i]++;coefficients++;
      end
      if(status_valid_o && status_ready_i)begin
        i=owner[status_core_o];if(i<0 || ids[i]!=status_id_o || status_code_o!=0 || coeff_count[i]!=256)$fatal(1,"Sample status");
        $fdisplay(fd,"T %0d %0d %0d",i,status_core_o,status_code_o);finished[i]=1;owner[status_core_o]=-1;
      end
      if(sample_done && sample_error)$fatal(1,"Unexpected sample formatter rejection");
    end else begin prev_raw=0;prev_done=0;prev_result=0;end
  end
  task automatic reset_all;
    rst=1;start_valid_i=0;manual_valid=0;manual_input_valid=0;sample_start=0;
    owner[0]=-1;owner[1]=-1;$fdisplay(fd,"X");
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(active_o!=0 || raw_done_valid_o || raw_output_valid_o || result_valid_o || output_valid_o || status_valid_o)
      $fatal(1,"Stale shared hash state after reset");
  endtask
  task automatic run_seed(input int i);
    use_seed=1;seed_case=i;force_result=1;
    start_param_i=2'(params[i]);start_id_i=16'(ids[i]);start_seed_i=seeds[i];start_valid_i=1;
    do @(posedge clk);while(!start_ready_o);@(negedge clk);start_valid_i=0;
    start_param_i=3;start_id_i=0;start_seed_i=~seeds[i];
    case(aborted[i])
      1:do @(negedge clk);while(word_count[i]<2);
      2:do @(negedge clk);while(byte_count[i]<16);
      default:begin do @(negedge clk);while(!result_valid_o);repeat(5)@(negedge clk);end
    endcase
    if(aborted[i]!=0)begin
      $fdisplay(fd,"A %0d %0d",i,aborted[i]);aborts++;finished[i]=1;reset_all();
    end else begin force_result=0;do @(negedge clk);while(!finished[i]);end
  endtask
  task automatic start_sample(input int i);
    sample_case=i;job_mode_i=2'(modes[i]);job_param_i=2'(params[i]);
    sample_param=2'(params[i]);sample_op=modes[i]==0?2'd1:2'd2;sample_id=16'(ids[i]);
    sample_nonce=16'(nonces[i]);sample_row=8'(rows[i]);sample_column=8'(columns[i]);
    sample_seed=modes[i]==0?{256'd0,rho_cache[params[i]]}:rhoprime_cache[params[i]];
    sample_start=1;do @(posedge clk);while(!sample_command_ready);@(negedge clk);sample_start=0;
    do @(negedge clk);while(!sample_done);@(negedge clk);
  endtask
  task automatic start_raw(input int i);
    direct_case=i;manual_mode=1'(modes[i]);manual_id=16'(ids[i]);manual_length=16'(lengths[i]);
    manual_output_length=16'(outlengths[i]);manual_valid=1;
    do @(posedge clk);while(!raw_ready_o);@(negedge clk);manual_valid=0;
    for(int w=0;w<(lengths[i]+7)/8;w++)begin
      manual_data=64'(messages[i]>>(64*w));manual_input_valid=1;
      do @(posedge clk);while(!raw_input_ready_o);@(negedge clk);manual_input_valid=0;
      if(w%3==0)repeat(2)@(negedge clk);
    end
  endtask
  initial begin
    int inf,index,i;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage5_shared_inputs.txt"},"r");
    if(!inf || $fscanf(inf,"%s %d",token,count)!=2 || count>MAX_CASES || count<20)$fatal(1,"Shared input header");
    for(int j=0;j<count;j++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %d %d %d %d %d %h %h",index,kinds[j],params[j],ids[j],modes[j],aborted[j],
                 lengths[j],outlengths[j],nonces[j],rows[j],columns[j],seeds[j],messages[j])!=13 || index!=j)$fatal(1,"Shared row");
      finished[j]=0;word_count[j]=0;byte_count[j]=0;coeff_count[j]=0;
    end
    $fclose(inf);fd=$fopen({directory,"/stage5_shared_outputs.txt"},"w");if(!fd)$fatal(1,"Shared capture");
    $fdisplay(fd,"H %s",token);reset_all();
    for(i=0;i<6;i++)run_seed(i);
    for(i=6;i<15;i+=3)begin
      run_seed(i);start_sample(i+1);start_sample(i+2);
      do @(negedge clk);while(!finished[i+1] || !finished[i+2]);
    end
    run_seed(15);use_seed=0;
    // Two raw jobs: finish both hashes while the first status is held. This
    // checks completion selection stays stable when a peer becomes eligible.
    for(i=16;i<24;i+=2)begin
      force_raw_done=1;start_raw(i);start_raw(i+1);
      do @(negedge clk);while(byte_count[i]!=outlengths[i] || byte_count[i+1]!=outlengths[i+1]);
      repeat(12)@(negedge clk);force_raw_done=0;
      do @(negedge clk);while(!finished[i] || !finished[i+1]);
    end
    force_raw_done=1;
    fork
      start_sample(25);
      begin @(negedge clk);start_raw(24);end
    join
    repeat(60)@(negedge clk);force_raw_done=0;
    do @(negedge clk);while(!finished[24] || !finished[25]);
    if(accepted!=count || aborts!=3 || active_o!=0 || mixed_cycles==0 || raw_peer_cycles==0 ||
       raw_output_stalls==0 || raw_done_stalls==0 || result_stalls==0 || arbitration_cycles==0)$fatal(1,"Incomplete shared gate");
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d",accepted,raw_jobs,sample_jobs,seed_results,aborts,raw_bytes,coefficients);$fclose(fd);
    $display("DILITHIUM_STAGE5_SHARED_HASH_PASS:%0d commands,%0d raw,%0d sampling,%0d seed results,3 aborts,%0d hash bytes,%0d coefficients",
      accepted,raw_jobs,sample_jobs,seed_results,raw_bytes,coefficients);
    $display("SHARED WITNESSES:mixed%0d,raw-peer%0d,raw-output-stall%0d,raw-done-stall%0d,seed-result-stall%0d,arbitration%0d",
      mixed_cycles,raw_peer_cycles,raw_output_stalls,raw_done_stalls,result_stalls,arbitration_cycles);test_passed=1;$finish;
  end
  initial begin #(64'd4_000_000_000);$fatal(1,"Shared hash timeout");end
endmodule
