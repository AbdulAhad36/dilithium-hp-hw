`timescale 1ns/1ps
// Full compact Sign protocol checks through the actual shared datapath.
// Expected signature bytes stay outside this bench, in the Python comparator.
module tb_sign_protocol;
  import dilithium_pkg::*;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,start_valid_i=0,start_ready_o,busy_o,fault_o;
  logic [1:0] start_param_i=0;logic [15:0] start_id_i=0,start_message_len_i=0;
  logic [8:0] start_context_len_i=0;logic [255:0] start_rnd_i=0;
  logic input_valid_i=0,input_ready_o;logic [63:0] input_data_i=0;
  logic [3:0] input_bytes_i=0;logic [15:0] input_index_i=0;logic input_last_i=0;
  logic signature_valid_o,signature_ready_i,signature_last_o;
  logic [63:0] signature_data_o;logic [3:0] signature_bytes_o;logic [9:0] signature_index_o;logic [15:0] signature_id_o;
  logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o,done_stage_o,done_detail_o;
  logic [15:0] done_id_o;logic [16:0] attempts_o,rejections_o,next_nonce_o;
  request_t service_o;response_t service_i;logic datapath_fault;
  sign controller(.start_internal_message_i(1'b0),.*);
  datapath datapath(.clk(clk),.rst(rst),.service_i(service_o),.service_o(service_i),.fault_o(datapath_fault));
  int cycles=0,current=-1,selected=0,action=-1,corruption=-1,got=0,completed=0,aborted=0,errors=0,valids=0,busy_probes=0;
  int output_file,input_file,n,serial,originals[3],levels[3],ids[3],context_lengths[3],message_lengths[3],sk_lengths[3],body_lengths[3];
  logic [255:0] randoms[3];logic [7:0] sk[3][6000],body[3][65535];
  string token,sk_hex,body_hex,case_label;
  bit invalid_command=0,reset_happened=0;
  logic held=0;logic [94:0] snapshot;
  always @(negedge clk)cycles++;
  assign signature_ready_i=!rst && cycles%13>3 && !(action==11 && signature_index_o>=10);
  function automatic bit reset_point;
    case(action)
      0:return controller.state==controller.KEY_WAIT && controller.key_input.word_r>=4;
      1:return controller.state==controller.KEY_WAIT && controller.key_input.state==controller.key_input.LOAD_DATA &&
        datapath.hash_sampler.decoder.committed_r>=32 && datapath.hash_sampler.decoder.committed_r<256;
      2:return controller.state==controller.PREP_RUN && datapath.polynomial.core_busy;
      3:return controller.state==controller.MU_RUN && service_o.raw.input_valid;
      4:return controller.producer==controller.P_FEED && controller.y_phase_r;
      5:return controller.state==controller.Y_NTT_RUN && datapath.polynomial.core_busy;
      6:return controller.state==controller.TERM_RUN && datapath.polynomial.core_busy;
      7:return controller.state==controller.DECOMP_RUN && datapath.process_path.produced_r>4;
      8:return controller.state==controller.CHASH_RUN && service_o.raw.input_valid;
      9:return controller.state==controller.Z_NORM_RUN && datapath.process_path.produced_r>4;
      10:return controller.state==controller.MHINT_RUN && service_i.poly_process.hint_valid && service_i.poly_process.hint_word>4;
      11:return controller.state==controller.SIG_Z_STREAM && signature_valid_o && !signature_ready_i;
      default:return 0;
    endcase
  endfunction
  always @(posedge clk)if(rst)held=0;else begin
    if(fault_o || datapath_fault)$fatal(1,"Compact Sign protocol fault case%0d state%0d",current,controller.state);
    if(invalid_command && (signature_valid_o || service_o.raw.valid || service_o.sample.valid || service_o.ntt.valid ||
      service_o.poly_process.valid || service_o.load.valid || |service_o.bank.command_valid))$fatal(1,"Invalid Sign command launched work");
    if(held && (!signature_valid_o || {signature_data_o,signature_bytes_o,signature_index_o,signature_last_o,signature_id_o}!==snapshot))
      $fatal(1,"Sign protocol stalled signature changed");
    held=signature_valid_o && !signature_ready_i;
    snapshot={signature_data_o,signature_bytes_o,signature_index_o,signature_last_o,signature_id_o};
    if(signature_valid_o && signature_ready_i)begin
      if(signature_id_o!=start_id_i || signature_index_o*8!=got)$fatal(1,"Protocol signature identity/order");
      $fdisplay(output_file,"S %0d %016h %0d %0d",signature_index_o,signature_data_o,signature_bytes_o,signature_last_o);
      got+=int'(signature_bytes_o);
    end
  end
  task automatic feed_frame(input bit secret_key,input int length);
    int amount,index,watchdog;index=0;watchdog=0;
    while(index*8<length && !done_valid_o)begin
      @(negedge clk);input_valid_i=1;input_data_i='1;
      amount=length-index*8>=8?8:length-index*8;
      input_bytes_i=4'(amount);input_index_i=16'(index);input_last_i=index*8+amount==length;
      for(int lane=0;lane<amount;lane++)input_data_i[8*lane+:8]=secret_key?sk[selected][8*index+lane]:body[selected][8*index+lane];
      if(secret_key)begin
        if(corruption==0 && index==0)input_index_i=1;
        if(corruption==1 && index==16)input_bytes_i=0;
        if(corruption==2 && index==16)input_data_i='1;
        if(corruption==3 && index*8+amount==length)input_last_i=0;
      end else if(index==0)begin
        if(corruption==4)input_index_i=1;
        if(corruption==5)input_bytes_i=0;
        if(corruption==6)input_last_i=~input_last_i;
      end
      @(posedge clk);
      while(!input_ready_o && !done_valid_o)begin
        @(posedge clk);if(watchdog++>500000)$fatal(1,"Sign protocol input timeout case%0d state%0d",current,controller.state);
      end
      if(input_ready_o)index++;
      @(negedge clk);input_valid_i=0;
      if(secret_key && index==4 && corruption<0 && action<0)begin
        if(start_ready_o)$fatal(1,"Busy Sign accepted a second command");
        start_valid_i=1;start_param_i=3;start_id_i=16'(ids[selected])^16'h55aa;
        @(negedge clk);start_valid_i=0;start_param_i=2'(levels[selected]);start_id_i=16'(ids[selected]);busy_probes++;
      end
    end
  endtask
  task automatic run_case(input int selection,reset_action,bad_input,bad_command);
    int watchdog,expected_code,expected_stage,expected_detail;
    selected=selection;action=reset_action;corruption=bad_input;reset_happened=0;
    @(negedge clk);start_param_i=2'(levels[selected]);start_id_i=16'(ids[selected]);
    start_context_len_i=9'(context_lengths[selected]);start_message_len_i=16'(message_lengths[selected]);start_rnd_i=randoms[selected];
    invalid_command=bad_command>=0;
    if(bad_command==0)start_param_i=3;
    if(bad_command==1)start_context_len_i=256;
    if(bad_command==2)start_message_len_i=65535;
    got=0;start_valid_i=1;#1;if(!start_ready_o)$fatal(1,"Sign protocol not ready case%0d",current);
    $fdisplay(output_file,"J %0d %0d %0d %0d %0d",current,originals[selected],reset_action,bad_input,bad_command);
    @(negedge clk);start_valid_i=0;
    fork:transaction
      begin
        if(bad_command<0)begin feed_frame(1,sk_lengths[selected]);if(!done_valid_o)feed_frame(0,body_lengths[selected]);end
        watchdog=0;
        while(!done_valid_o)begin @(negedge clk);if(watchdog++>500000)$fatal(1,"Sign protocol completion timeout case%0d state%0d",current,controller.state);end
      end
      begin
        if(reset_action<0)wait(1'b0);
        else begin
          watchdog=0;while(!reset_point())begin @(negedge clk);if(watchdog++>500000)$fatal(1,"Sign reset phase unreachable %0d",reset_action);end
          @(negedge clk);
          $fdisplay(output_file,"P %0d %0d %0d",action,controller.state,datapath.hash_sampler.decoder.committed_r);
          rst=1;reset_happened=1;input_valid_i=0;start_valid_i=0;
        end
      end
    join_any
    disable transaction;
    input_valid_i=0;
    if(reset_happened)begin
      $fdisplay(output_file,"A %0d",got);repeat(3)@(negedge clk);rst=0;action=-1;
      #1;if(done_valid_o || signature_valid_o || !start_ready_o || !service_i.idle)$fatal(1,"Sign reset did not clear work");
      aborted++;
    end else begin
      expected_code=bad_command>=0?1:bad_input>=0 && bad_input<4?3:bad_input>=4?4:0;
      expected_stage=expected_code==3?1:expected_code==4?2:0;
      expected_detail=expected_code==3?(bad_input==2?2:3):expected_code==4?2:0;
      if(done_code_o!=expected_code || done_stage_o!=expected_stage || done_detail_o!=expected_detail || done_id_o!=start_id_i || !service_i.idle)
        $fatal(1,"Sign protocol wrong completion case%0d got%0d/%0d/%0d expected%0d/%0d/%0d",current,done_code_o,done_stage_o,done_detail_o,expected_code,expected_stage,expected_detail);
      if(expected_code!=0 && (got!=0 || attempts_o!=0))$fatal(1,"Invalid Sign frame produced a signature/attempt");
      $fdisplay(output_file,"D %0d %0d %0d %0d",done_code_o,done_stage_o,done_detail_o,got);
      repeat(3)begin @(negedge clk);if(!done_valid_o || done_id_o!=start_id_i || done_code_o!=expected_code)$fatal(1,"Sign protocol completion changed");end
      done_ready_i=1;@(negedge clk);done_ready_i=0;
      if(expected_code==0)valids++;else errors++;
    end
    $display("COMPACT_SIGN_PROTOCOL_CASE_PASS:case%0d reset%0d corrupt%0d command%0d",current,reset_action,bad_input,bad_command);
    current++;completed++;
  endtask
  initial begin
    input_file=$fopen("sim/dilithium/sign_diagnostic_inputs.txt","r");
    output_file=$fopen("sim/dilithium/sign_protocol_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2 || n!=3)$fatal(1,"Prepare Sign protocol fixtures");
    for(int i=0;i<3;i++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %d %d %h %s %s %s",serial,originals[i],levels[i],ids[i],context_lengths[i],message_lengths[i],sk_lengths[i],body_lengths[i],randoms[i],sk_hex,body_hex,case_label)!=12 || serial!=i)
        $fatal(1,"Sign protocol fixture schema");
      for(int j=0;j<sk_lengths[i];j++)sk[i][j]=8'(sk_hex.substr(2*j,2*j+1).atohex());
      for(int j=0;j<body_lengths[i];j++)body[i][j]=8'(body_hex.substr(2*j,2*j+1).atohex());
      if(body_lengths[i]==0)$fatal(1,"Protocol fixtures require a nonempty body");
    end
    $fclose(input_file);$fdisplay(output_file,"%s 69",token);repeat(3)@(negedge clk);rst=0;current=0;
    for(int bad=0;bad<3;bad++)run_case(0,-1,-1,bad);
    for(int level=0;level<3;level++)for(int bad=0;bad<7;bad++)begin run_case(level,-1,bad,-1);run_case(level,-1,-1,-1);end
    for(int phase=0;phase<12;phase++)begin run_case(phase%3,phase,-1,-1);run_case(phase%3,-1,-1,-1);end
    if(completed!=69 || aborted!=12 || errors!=24 || valids!=33 || busy_probes!=33)$fatal(1,"Incomplete Sign protocol coverage");
    $fdisplay(output_file,"F %0d %0d %0d %0d",completed,aborted,errors,valids);$fclose(output_file);
    $display("LIGHTHD_SIGN_PROTOCOL_CAPTURE_PASS:69 commands/12 resets/24 errors/33 same-ID recoveries;independent comparison required");$finish;
  end
  initial begin #(64'd10000000000);$fatal(1,"Sign protocol global watchdog");end
endmodule
