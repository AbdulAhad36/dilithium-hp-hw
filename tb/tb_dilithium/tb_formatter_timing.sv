`timescale 1ns/1ps
// Reusable pin/cycle comparison and independent absorption-byte oracle.
// Compile timing_screen/formatter_reference.sv (the saved pre-change RTL)
// alongside this bench. Exercise both snapshot and owner-held prefix modes.
module tb_formatter_timing #(parameter bit STABLE_PREFIX_INPUTS=0);
  logic clk=0,rst=1;always #5 clk=~clk;
  logic command_valid_i=0,command_ready_o,busy_o;
  logic [1:0] command_op_i=0,command_param_i=0;
  logic [15:0] command_id_i=0,command_message_len_i=0,command_nonce_i=0;
  logic [8:0] command_context_len_i=0;
  logic [511:0] command_tr_i=0,command_mu_i=0,command_mask_seed_i=0;
  logic [255:0] command_key_i=0,command_rnd_i=0;
  logic payload_valid_i=0,payload_ready_o,payload_last_i=0;
  logic [63:0] payload_data_i=0;logic [3:0] payload_bytes_i=0;logic [15:0] payload_index_i=0;
  logic request_valid_o,request_ready_i,request_sampling_o,request_mode_o;
  logic [1:0] request_param_o;logic [15:0] request_id_o,request_message_len_o,request_output_len_o;
  logic input_valid_o,input_ready_i,input_last_o;logic [63:0] input_data_o;
  logic [3:0] input_bytes_o;logic [15:0] input_index_o;
  logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o;logic [15:0] done_id_o;
  logic old_command_ready,old_busy,old_payload_ready,old_request_valid,old_sampling,old_mode;
  logic [1:0] old_param;logic [15:0] old_id,old_length,old_output_length;
  logic old_input_valid,old_input_last,old_done_valid;
  logic [63:0] old_data;logic [3:0] old_bytes;logic [15:0] old_index,old_done_id;logic [2:0] old_code;
  int cycles=0,jobs=0,completed=0,resets=0,bytes_checked=0,descriptor_count=0,absorbed=0;
  int body_length,prefix_length,total_length,job_fault,first_bad_word;
  bit hold_request=0,hold_input=0,job_active=0,command_bad;
  assign request_ready_i=!rst && !hold_request && cycles%7>=2;
  assign input_ready_i=!rst && !hold_input && cycles%11>=4;
  sign_hash_message #(.STABLE_PREFIX_INPUTS(STABLE_PREFIX_INPUTS)) dut(.*);
  sign_hash_message_timing_reference #(.STABLE_PREFIX_INPUTS(STABLE_PREFIX_INPUTS)) old(
    .clk(clk),.rst(rst),.command_valid_i(command_valid_i),.command_ready_o(old_command_ready),.busy_o(old_busy),
    .command_op_i(command_op_i),.command_param_i(command_param_i),.command_id_i(command_id_i),
    .command_message_len_i(command_message_len_i),.command_nonce_i(command_nonce_i),.command_context_len_i(command_context_len_i),
    .command_tr_i(command_tr_i),.command_mu_i(command_mu_i),.command_mask_seed_i(command_mask_seed_i),
    .command_key_i(command_key_i),.command_rnd_i(command_rnd_i),
    .payload_valid_i(payload_valid_i),.payload_ready_o(old_payload_ready),.payload_data_i(payload_data_i),
    .payload_bytes_i(payload_bytes_i),.payload_index_i(payload_index_i),.payload_last_i(payload_last_i),
    .request_valid_o(old_request_valid),.request_ready_i(request_ready_i),.request_sampling_o(old_sampling),
    .request_mode_o(old_mode),.request_param_o(old_param),.request_id_o(old_id),
    .request_message_len_o(old_length),.request_output_len_o(old_output_length),
    .input_valid_o(old_input_valid),.input_ready_i(input_ready_i),.input_data_o(old_data),
    .input_bytes_o(old_bytes),.input_index_o(old_index),.input_last_o(old_input_last),
    .done_valid_o(old_done_valid),.done_ready_i(done_ready_i),.done_code_o(old_code),.done_id_o(old_done_id));
  function automatic logic [7:0] body_byte(input int index);
    return 8'((jobs*13+index*7)^165);
  endfunction
  function automatic logic [7:0] expected_byte(input int index);
    case(command_op_i)
      0:begin
        if(index<64)return command_tr_i[8*index+:8];
        if(index==64)return 0;
        if(index==65)return command_context_len_i[7:0];
      end
      1:begin
        if(index<32)return command_key_i[8*index+:8];
        if(index<64)return command_rnd_i[8*(index-32)+:8];
        return command_mu_i[8*(index-64)+:8];
      end
      2:if(index<64)return command_mu_i[8*index+:8];
      3:begin
        if(index<64)return command_mask_seed_i[8*index+:8];
        return command_nonce_i[8*(index-64)+:8];
      end
    endcase
    if(job_fault!=0 && (index-prefix_length)>=first_bad_word*8)return 0;
    return body_byte(index-prefix_length);
  endfunction
  always @(posedge clk)begin
    cycles<=cycles+1;
    if(!rst && job_active)begin
      if(request_valid_o && request_ready_i)begin
        if(command_bad || descriptor_count!=0 || request_message_len_o!=total_length ||
          request_mode_o!=1 || request_sampling_o!=(command_op_i==3) || request_id_o!=command_id_i ||
          request_param_o!=command_param_i || request_output_len_o!=(command_op_i==3?0:
          command_op_i==2?(command_param_i==0?32:command_param_i==1?48:64):64))$fatal(1,"Formatter descriptor oracle job%0d",jobs);
        descriptor_count++;
      end
      if(input_valid_o && input_ready_i)begin
        int amount;logic [63:0] gold;amount=total_length-absorbed>=8?8:total_length-absorbed;gold=0;
        for(int lane=0;lane<amount;lane++)gold[8*lane+:8]=expected_byte(absorbed+lane);
        if(command_bad || input_index_o!=absorbed/8 || input_bytes_o!=amount ||
          input_last_o!=(absorbed+amount==total_length) || input_data_o!==gold)
          $fatal(1,"Formatter byte oracle job%0d offset%0d got%016h expected%016h",jobs,absorbed,input_data_o,gold);
        absorbed+=amount;bytes_checked+=amount;
      end
    end
    #1;if(!rst && {command_ready_o,busy_o,payload_ready_o,request_valid_o,request_sampling_o,request_mode_o,
      request_param_o,request_id_o,request_message_len_o,request_output_len_o,input_valid_o,input_data_o,
      input_bytes_o,input_index_o,input_last_o,done_valid_o,done_code_o,done_id_o}!==
      {old_command_ready,old_busy,old_payload_ready,old_request_valid,old_sampling,old_mode,old_param,old_id,
      old_length,old_output_length,old_input_valid,old_data,old_bytes,old_index,old_input_last,old_done_valid,old_code,old_done_id})
      $fatal(1,"Formatter old/new pin or cycle mismatch job%0d clock%0d",jobs,cycles);
  end
  task automatic reset_all;
    @(negedge clk);rst=1;command_valid_i=0;payload_valid_i=0;done_ready_i=0;
    repeat(2)@(negedge clk);rst=0;hold_request=0;hold_input=0;job_active=0;resets++;
    #1;if(!command_ready_o || input_valid_o || done_valid_o)$fatal(1,"Formatter reset recovery");
  endtask
  task automatic run_job(input int op,level,context_length,message_length,fault,abort_phase);
    int wordno,watchdog,amount;bit aborted;wordno=0;watchdog=0;aborted=0;
    @(negedge clk);jobs++;command_op_i=2'(op);command_param_i=2'(level);command_context_len_i=9'(context_length);
    command_message_len_i=16'(message_length);command_id_i=16'(65520+jobs);command_nonce_i=16'(jobs*59);
    command_tr_i={8{64'h6e3a74c86d1590ab}}^512'(jobs);command_mu_i=~command_tr_i;
    command_mask_seed_i=command_tr_i^{8{64'hf0e1d2c3b4a59687}};
    command_key_i=command_tr_i[255:0];command_rnd_i=command_mu_i[255:0];
    prefix_length=op==1?128:op==2?64:66;
    body_length=op==0?context_length+message_length:op==2?(level==2?1024:768):0;
    total_length=prefix_length+body_length;job_fault=fault;first_bad_word=body_length>16?1:0;
    command_bad=level==3 || total_length>65535 || (op==0 && context_length>255);
    descriptor_count=0;absorbed=0;job_active=1;hold_request=abort_phase==0;hold_input=abort_phase==1;
    command_valid_i=1;@(posedge clk);if(!command_ready_o)$fatal(1,"Formatter command not ready");
    @(negedge clk);command_valid_i=0;
    while(!done_valid_o)begin
      if(abort_phase==0 && dut.state==dut.REQUEST || abort_phase==1 && dut.count_r!=0 ||
        abort_phase==2 && dut.draining_r)begin aborted=1;break;end
      payload_valid_i=!command_bad && wordno*8<body_length && !dut.draining_r && cycles%5!=1;
      amount=body_length-wordno*8>=8?8:body_length-wordno*8;payload_data_i='1;
      for(int lane=0;lane<amount;lane++)payload_data_i[8*lane+:8]=body_byte(wordno*8+lane);
      payload_index_i=16'(wordno);payload_bytes_i=4'(amount);payload_last_i=wordno*8+amount==body_length;
      if(fault!=0 && wordno==first_bad_word)case(fault)
        1:payload_index_i=16'(wordno)^16'd1;
        2:payload_bytes_i=0;
        3:payload_last_i=!payload_last_i;
      endcase
      @(posedge clk);if(payload_valid_i && payload_ready_o)wordno++;
      @(negedge clk);if(watchdog++>100000)$fatal(1,"Formatter command timeout job%0d",jobs);
    end
    payload_valid_i=0;
    if(aborted)begin reset_all();return;end
    if(abort_phase>=0)$fatal(1,"Formatter reset target missed job%0d",jobs);
    if(done_code_o!=(command_bad?1:fault!=0?2:0) || done_id_o!=command_id_i ||
      (!command_bad && (absorbed!=total_length || descriptor_count!=1)) ||
      (command_bad && (descriptor_count!=0 || absorbed!=0)))$fatal(1,"Formatter completion oracle job%0d",jobs);
    repeat(4)@(negedge clk);done_ready_i=1;@(negedge clk);done_ready_i=0;job_active=0;completed++;
  endtask
  initial begin
    reset_all();
    for(int level=0;level<3;level++)begin
      for(int op=0;op<4;op++)begin
        for(int variant=0;variant<6;variant++)run_job(op,level,variant==4?255:variant%4,
          variant==0?0:variant==1?1:variant==2?7:variant==3?8:variant==4?135:1025,0,-1);
        run_job(op,3,0,13,0,-1);
        run_job(op,level,0,13,0,0);run_job(op,level,0,13,0,1);
      end
      for(int op=0;op<=2;op+=2)begin
        for(int fault=1;fault<=3;fault++)run_job(op,level,7,137,fault,-1);
        run_job(op,level,7,137,1,2);
      end
      run_job(0,level,0,65469,0,-1); // Largest legal 16-bit total length.
      run_job(0,level,255,65535,0,-1);run_job(0,level,256,0,0,-1);
    end
    if(jobs!=141 || completed!=111 || resets!=31)$fatal(1,"Formatter campaign accounting %0d/%0d/%0d",jobs,completed,resets);
    $display("FORMATTER_TIMING_EQUIVALENCE_PASS:mode%0d/%0d jobs/%0d completions/%0d resets/%0d independent bytes;all output pins and cycles exact oldRTL",STABLE_PREFIX_INPUTS,jobs,completed,resets,bytes_checked);
    $finish;
  end
endmodule
