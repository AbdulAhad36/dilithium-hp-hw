`timescale 1ps/1ps
module tb_keygen_hash_message;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic command_valid_i=0,command_ready_o;
  logic [1:0] command_op_i=0,command_param_i=0;
  logic [15:0] command_id_i=0,command_nonce_i=0;
  logic [7:0] command_row_i=0,command_column_i=0;
  logic [511:0] command_seed_i=0;
  logic request_valid_o,request_ready_i,request_mode_o;
  logic [15:0] request_message_len_o,request_output_len_o;
  logic [63:0] input_data_o;
  logic input_valid_o,input_ready_i;
  logic done_valid_o,done_ready_i=0,done_error_o;
  logic [15:0] done_id_o;
  keygen_hash_message dut(.*);

  logic hash_request_ready,hash_request_core,hash_input_ready;
  logic [127:0] hash_data;
  logic [4:0] hash_bytes;
  logic hash_valid,hash_ready,hash_core;
  logic [1:0] hash_busy;
  bit request_gate,input_gate,force_request=0,force_output=0,force_done=1;
  int cycles=0;
  // One real shared hash instance in this focused harness. The eventual main
  // controller must arbitrate this interface with sampling, not duplicate it.
  assign request_gate=!rst && !force_request && cycles%13>=5;
  assign input_gate=!rst && cycles%11>=3;
  assign request_ready_i=hash_request_ready && request_gate;
  assign input_ready_i=hash_input_ready && input_gate;
  assign hash_ready=!rst && !force_output && cycles%23>=9;
  always @(negedge clk)done_ready_i<=!rst && !force_done && cycles%17>=4;
  keccak_dual_interleaved hash (
    .clk(clk),.rst(rst),.request_valid_i(request_valid_o && request_gate),
    .request_ready_o(hash_request_ready),.request_core_o(hash_request_core),
    .keccak_mode_i(request_mode_o),.message_len_i(request_message_len_o),
    // Sampling descriptors say continuous0; use32 bytes to bound this hash-only
    // test. No sampler coefficient check or continuous-drain claim is made here.
    .output_len_i(request_output_len_o==0 ? 16'd32 : request_output_len_o),
    .input_data_i(input_data_o),.input_valid_i(input_valid_o && input_gate),
    .input_ready_o(hash_input_ready),.input_core_o(),.stop_i(2'd0),
    .core_busy_o(hash_busy),.core_done_o(),.busy_o(),
    .output_data_o(hash_data),.output_valid_o(hash_valid),.output_bytes_o(hash_bytes),
    .output_core_o(hash_core),.output_ready_i(hash_ready)
  );

  localparam int MAX_CASES=256;
  int ops[MAX_CASES],params[MAX_CASES],ids[MAX_CASES],rows[MAX_CASES],columns[MAX_CASES];
  int nonces[MAX_CASES],aborted[MAX_CASES],errors[MAX_CASES];
  logic [511:0] seeds[MAX_CASES];logic [527:0] messages[MAX_CASES];
  int count,fd,current=-1,accepted=0,completed=0,error_count=0,aborts=0;
  int words=0,beats=0,total_words=0,total_beats=0,descriptors=0;
  int request_stalls=0,input_stalls=0,done_stalls=0,hash_stalls=0;
  bit done_seen=0,test_passed=0;
  logic expected_core;
  bit prev_req=0,prev_input=0,prev_done=0,prev_hash=0;
  logic [32:0] saved_request;
  logic [63:0] saved_input;
  logic [16:0] saved_done;
  logic [133:0] saved_hash;
  string directory,token;
  always @(posedge clk)begin
    cycles<=cycles+1;
    if(!rst)begin
      if(prev_req && (!request_valid_o || {request_mode_o,request_message_len_o,request_output_len_o}!==saved_request))
        $fatal(1,"Hash descriptor changed while blocked");
      if(prev_input && (!input_valid_o || input_data_o!==saved_input))$fatal(1,"Hash message changed while blocked");
      if(prev_done && (!done_valid_o || {done_error_o,done_id_o}!==saved_done))$fatal(1,"Message completion changed while blocked");
      if(prev_hash && (!hash_valid || {hash_data,hash_bytes,hash_core}!==saved_hash))$fatal(1,"SHAKE output changed while blocked");
      prev_req=request_valid_o && !request_ready_i;
      prev_input=input_valid_o && !input_ready_i;
      prev_done=done_valid_o && !done_ready_i;
      prev_hash=hash_valid && !hash_ready;
      saved_request={request_mode_o,request_message_len_o,request_output_len_o};
      saved_input=input_data_o;saved_done={done_error_o,done_id_o};saved_hash={hash_data,hash_bytes,hash_core};
      request_stalls+=int'(prev_req);input_stalls+=int'(prev_input);
      done_stalls+=int'(prev_done);hash_stalls+=int'(prev_hash);
      if(command_valid_i && command_ready_o)begin
        accepted++;$fdisplay(fd,"J %0d",current);
      end
      if(request_valid_o && request_ready_i)begin
        if(errors[current] || descriptors!=0)$fatal(1,"Invalid/repeated request");
        expected_core=hash_request_core;descriptors++;
        $fdisplay(fd,"D %0d %0d %0d %0d",current,request_mode_o,request_message_len_o,request_output_len_o);
      end
      if(input_valid_o && input_ready_i)begin
        if(!descriptors || words >= (ops[current]==2 ? 9 : 5) ||
           input_data_o!==64'(messages[current]>>(64*words)))$fatal(1,"Absorption byte order case%0d word%0d",current,words);
        $fdisplay(fd,"W %0d %0d %016h",current,words,input_data_o);words++;total_words++;
      end
      if(hash_valid && hash_ready)begin
        if(hash_core!==expected_core || hash_bytes!=16)$fatal(1,"SHAKE core/byte count");
        $fdisplay(fd,"V %0d %0d %0d %0d %032h",current,beats,hash_bytes,hash_core,hash_data);
        beats++;total_beats++;
      end
      if(done_valid_o && done_ready_i)begin
        if(done_seen || done_error_o!==1'(errors[current]) || done_id_o!==16'(ids[current]))$fatal(1,"Message completion");
        $fdisplay(fd,"S %0d %0d %0d",current,done_id_o,done_error_o);
        done_seen=1;completed++;error_count+=int'(done_error_o);
      end
    end else begin prev_req=0;prev_input=0;prev_done=0;prev_hash=0;end
  end
  task automatic reset_all;
    rst=1;command_valid_i=0;$fdisplay(fd,"X");
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(request_valid_o || input_valid_o || done_valid_o || hash_valid || hash_busy!=0)
      $fatal(1,"Stale formatter/hash state after reset");
  endtask
  initial begin
    int inf,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    inf=$fopen({directory,"/stage5_hash_inputs.txt"},"r");
    if(!inf || $fscanf(inf,"%s %d",token,count)!=2 || count>MAX_CASES || count<150)$fatal(1,"Hash-format header");
    for(int i=0;i<count;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %d %d %d %h %h",index,ops[i],params[i],ids[i],rows[i],columns[i],
                 nonces[i],aborted[i],errors[i],seeds[i],messages[i])!=11 || index!=i)$fatal(1,"Hash-format row");
    end
    $fclose(inf);fd=$fopen({directory,"/stage5_hash_outputs.txt"},"w");
    if(!fd)$fatal(1,"Hash-format capture");$fdisplay(fd,"H %s",token);reset_all();
    for(int i=0;i<count;i++)begin
      current=i;words=0;beats=0;descriptors=0;done_seen=0;
      force_request=aborted[i]==1;force_output=aborted[i]!=0;force_done=1;
      command_op_i=2'(ops[i]);command_param_i=2'(params[i]);command_id_i=16'(ids[i]);
      command_seed_i=seeds[i];command_nonce_i=16'(nonces[i]);command_row_i=8'(rows[i]);command_column_i=8'(columns[i]);
      command_valid_i=1;do @(posedge clk);while(!command_ready_o);
      @(negedge clk);command_valid_i=0;
      // Change every unowned command field: an in-flight message must use its snapshot.
      command_seed_i=~seeds[i];command_nonce_i='1;command_row_i='1;command_column_i='1;
      command_param_i=3;command_op_i=3;command_id_i=0;
      if(aborted[i]!=0)begin
        case(aborted[i])
          1:repeat(5)@(negedge clk);
          2:do @(negedge clk);while(words<2);
          3:begin do @(negedge clk);while(!done_valid_o);repeat(5)@(negedge clk);end
        endcase
        $fdisplay(fd,"A %0d %0d",i,aborted[i]);aborts++;reset_all();
      end else begin
        do @(negedge clk);while(!done_valid_o);
        repeat(3)@(negedge clk);force_done=0;
        do @(negedge clk);while(!done_seen || beats!=(errors[i] ? 0 : ops[i]==0 ? 8 : 2) || hash_busy!=0);
        $fdisplay(fd,"E %0d",i);
      end
      force_request=0;force_output=0;
    end
    if(accepted!=count || aborts!=3 || completed!=count-3 || error_count==0 ||
       request_stalls==0 || input_stalls==0 || done_stalls==0 || hash_stalls==0)$fatal(1,"Incomplete hash-format gate");
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d",accepted,completed,error_count,aborts,total_words,total_beats);$fclose(fd);
    $display("DILITHIUM_STAGE5_HASH_FORMAT_PASS:%0d accepted,%0d done,%0d errors,3 aborts,%0d words,%0d SHAKE bytes",
      accepted,completed,error_count,total_words,16*total_beats);
    $display("STALL WITNESSES:descriptor%0d,input%0d,completion%0d,hash%0d",request_stalls,input_stalls,done_stalls,hash_stalls);
    test_passed=1;$finish;
  end
  initial begin #2_000_000_000;$fatal(1,"Hash-format timeout");end
endmodule
