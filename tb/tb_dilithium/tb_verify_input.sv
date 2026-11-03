`timescale 1ns/1ps
module tb_verify_input #(parameter bit FRAMING_ONLY=0,CYCLE_REFERENCE=0);
  logic tr_write_valid_o;logic [1:0] tr_write_index_o;logic [127:0] tr_write_data_o;
  import dilithium_pkg::*;
  logic clk=0,clock_enable=0;always #5 if(clock_enable)clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o,busy_o,fault_o;
  logic [1:0] command_param_i=0;logic [15:0] command_id_i=0,command_signature_len_i=0;
  logic input_valid_i=0,input_ready_o;logic [63:0] input_data_i=0;logic [3:0] input_bytes_i=0;
  logic [15:0] input_index_i=0;logic input_last_i=0;
  logic [255:0] rho_o;logic [511:0] tr_o,ctilde_o;
  logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o;logic [15:0] done_id_o;
  request_t service_o;response_t service_i;logic physical_fault;
  verify_input controller(.*);
  generate if(CYCLE_REFERENCE)begin:cycle_reference
  logic old_command_ready,old_busy,old_fault,old_input_ready,old_done_valid;
  logic [255:0] old_rho;logic [511:0] old_tr,old_ctilde;
  logic [2:0] old_done_code;logic [15:0] old_done_id;request_t old_service;
  verify_input_c20_reference framing_reference(
    .clk(clk),.rst(rst),.command_valid_i(command_valid_i),.command_ready_o(old_command_ready),
    .busy_o(old_busy),.fault_o(old_fault),.command_param_i(command_param_i),
    .command_id_i(command_id_i),.command_signature_len_i(command_signature_len_i),
    .input_valid_i(input_valid_i),.input_ready_o(old_input_ready),.input_data_i(input_data_i),
    .input_bytes_i(input_bytes_i),.input_index_i(input_index_i),.input_last_i(input_last_i),
    .rho_o(old_rho),.tr_o(old_tr),.ctilde_o(old_ctilde),.done_valid_o(old_done_valid),
    .done_ready_i(done_ready_i),.done_code_o(old_done_code),.done_id_o(old_done_id),
    .service_o(old_service),.service_i(service_i));
    always @(negedge clk)if(!rst)begin
      if({command_ready_o,busy_o,fault_o,input_ready_o,done_valid_o,done_code_o,done_id_o,rho_o,tr_o,ctilde_o}!==
        {old_command_ready,old_busy,old_fault,old_input_ready,old_done_valid,old_done_code,old_done_id,old_rho,old_tr,old_ctilde} ||
        service_o!==old_service)
        $fatal(1,"Verify-input old/new cycle mismatch");
    end
  end endgenerate
  service_fixture banks(.clk(clk),.rst(rst),.request_i(service_o),.response_o(service_i),.fault_o(physical_fault));
  int input_file,output_file,n,serial,level,id,fault,abort_phase,declared,pk_len,sig_len;
  int current=-1,completed=0,resets=0,reads=0,cycles=0;string token,pk_hex,sig_hex;
  logic [7:0] pk[2600],signature[4700];logic [91:0] values[1024];bit reset_happened;
  logic [15:0] probe_word,probe_signature_length;
  logic [9:0] probe_pk_words;
  logic [1:0] probe_level;logic probe_signature;
  logic [3:0] reference_bytes;logic reference_last;
  logic [15:0] probe_pk_penultimate,probe_sig_penultimate,probe_next_word;
  logic [3:0] probe_tail_bytes,next_reference_bytes;logic next_reference_last;
  assign probe_next_word=probe_word+16'd1;
  assign next_reference_bytes=!probe_signature?4'd8:
    probe_signature_length-16'(probe_next_word)*16'd8>=8?4'd8:
    4'(probe_signature_length-16'(probe_next_word)*16'd8);
  assign next_reference_last=probe_signature?
    (16'(probe_next_word)*16'd8+16'(next_reference_bytes)==probe_signature_length):
    probe_next_word+1'b1==16'(probe_pk_words);
  // The previous qualified RTL expression preserves SystemVerilog widths.
  // Check every counter value,including overflow aliases and malformed fields.
  assign reference_bytes=!probe_signature?4'd8:
    probe_signature_length-16'(probe_word)*16'd8>=8?4'd8:
    4'(probe_signature_length-16'(probe_word)*16'd8);
  assign reference_last=probe_signature?
    (16'(probe_word)*16'd8+16'(reference_bytes)==probe_signature_length):
    probe_word+1'b1==16'(probe_pk_words);
  task automatic check_framing;
    int checked;checked=0;
    force controller.word_r=probe_word;
    force controller.signature_len_r=probe_signature_length;
    force controller.pk_words_r=probe_pk_words;
    force controller.level_r=probe_level;
    force controller.signature_r=probe_signature;
    force controller.frame_bytes_r=reference_bytes;
    force controller.frame_last_r=reference_last;
    force controller.pk_penultimate_r=probe_pk_penultimate;
    force controller.sig_penultimate_r=probe_sig_penultimate;
    force controller.sig_tail_bytes_r=probe_tail_bytes;
    for(int p=0;p<3;p++)begin
      probe_level=2'(p);probe_signature_length=p==0?2420:p==1?3309:4627;
      probe_pk_words=p==0?164:p==1?244:324;
      probe_pk_penultimate=16'(probe_pk_words)-16'd2;
      probe_sig_penultimate=p==0?301:p==1?412:577;
      probe_tail_bytes=p==0?4:p==1?5:3;
      for(int phase=0;phase<2;phase++)begin
        probe_signature=1'(phase);
        for(int w=0;w<65536;w++)begin
          probe_word=16'(w);#1;
          if(controller.next_frame_bytes!==next_reference_bytes || controller.next_frame_last!==next_reference_last)
            $fatal(1,"Next framing mismatch p%0d phase%0d word%0d",p,phase,w);
          input_index_i=probe_word;input_bytes_i=reference_bytes;input_last_i=reference_last;#1;
          if(controller.expected_bytes!==reference_bytes || controller.bad_frame!==0)
            $fatal(1,"Framing equivalence p%0d phase%0d word%0d",p,phase,w);
          input_bytes_i=reference_bytes^4'd1;#1;
          if(controller.bad_frame!==1)$fatal(1,"Framing missed byte-count error");
          input_bytes_i=reference_bytes;input_last_i=!reference_last;#1;
          if(controller.bad_frame!==1)$fatal(1,"Framing missed last error");
          input_last_i=reference_last;input_index_i=probe_word^16'd1;#1;
          if(controller.bad_frame!==1)$fatal(1,"Framing missed index error");
          checked++;
        end
      end
    end
    release controller.word_r;release controller.signature_len_r;
    release controller.pk_words_r;release controller.level_r;release controller.signature_r;
    release controller.frame_bytes_r;release controller.frame_last_r;
    release controller.pk_penultimate_r;release controller.sig_penultimate_r;release controller.sig_tail_bytes_r;
    input_index_i=0;input_bytes_i=0;input_last_i=0;
    $display("VERIFY_FRAMING_EQUIVALENCE_PASS:%0d counter/phase cases;byte,last,index corruptions;no clock cycles added",checked);
  endtask
  always @(negedge clk)cycles++;
  always @(posedge clk)if(!rst && (fault_o || physical_fault))$fatal(1,"Verify input physical fault case%0d state%0d",current,controller.state);
  // In the real stream,check cached state against the original expression on
  // every offered-word cycle,including backpressure and recovery after reset.
  always @(posedge clk)if(!rst && input_ready_o)begin
    if(controller.expected_bytes!==(!controller.signature_r?4'd8:
      controller.signature_len_r-16'(controller.word_r)*16'd8>=8?4'd8:
      4'(controller.signature_len_r-16'(controller.word_r)*16'd8)) ||
      controller.frame_last_r!==(controller.signature_r?
      (16'(controller.word_r)*16'd8+16'(controller.expected_bytes)==controller.signature_len_r):
      controller.word_r+1'b1==16'(controller.pk_words_r)))
      $fatal(1,"Cached framing state mismatch case%0d word%0d",current,controller.word_r);
  end
  function automatic bit reset_point;
    case(abort_phase)
      0:return controller.state==controller.PK_DATA && banks.datapath.hash_sampler.decoder.committed_r>=32 && banks.datapath.hash_sampler.decoder.committed_r<256;
      1:return controller.state==controller.Z_DATA && banks.datapath.hash_sampler.decoder.committed_r>=32 && banks.datapath.hash_sampler.decoder.committed_r<256;
      2:return controller.state==controller.HINT_RUN && controller.hint_words_sent_r>=8;
      default:return 0;
    endcase
  endfunction
  task automatic feed_frame(input int frame,length);
    int index,amount,watchdog,local_fault,payload_start;index=0;watchdog=0;
    local_fault=(fault>frame*6 && fault<=frame*6+6)?fault-frame*6:0;
    payload_start=frame==0?4:level==0?4:level==1?6:8;
    while(index*8<length && !done_valid_o)begin
      @(negedge clk);input_valid_i=1;input_data_i='1;amount=length-index*8>=8?8:length-index*8;
      for(int lane=0;lane<amount;lane++)input_data_i[8*lane+:8]=frame==0?pk[8*index+lane]:signature[8*index+lane];
      input_bytes_i=4'(amount);input_index_i=16'(index);input_last_i=index*8+amount==length;
      if(index==0)begin
        if(local_fault==1)input_index_i=1;
        if(local_fault==2)input_bytes_i=0;
        if(local_fault==3)input_last_i=1;
      end
      if(index==payload_start)begin
        if(local_fault==4)input_index_i=0;
        if(local_fault==5)input_bytes_i=0;
      end
      if(input_last_i && local_fault==6)input_last_i=0;
      @(posedge clk);while(!input_ready_o && !done_valid_o)begin
        @(posedge clk);if(watchdog++>30000)$fatal(1,"Verify input stream timeout case%0d state%0d loadActive%0d rawWords%0d",current,controller.state,controller.load_active_r,controller.hash_words_r);
      end
      if(input_ready_o)index++;
      @(negedge clk);input_valid_i=0;
    end
  endtask
  task automatic capture_context;
    int k,l,bank,base,count;k=level==0?4:level==1?6:8;l=level==0?4:level==1?5:7;
    if(!service_i.idle)$fatal(1,"Verify raw context published before physical retirement");
    $fdisplay(output_file,"T %064h %0128h %0128h",rho_o,tr_o,ctilde_o);
    for(int section=0;section<3;section++)begin
      bank=section==0?0:section==1?2:1;base=section==0?448:section==1?0:64;count=64*(section==1?l:k);
      banks.read_bank(bank,base,count,values);
      for(int word_index=0;word_index<count;word_index++)$fdisplay(output_file,"M %0d %0d %023h",bank,base+word_index,values[word_index]);
      reads+=count;
    end
  endtask
  initial begin
    int watchdog;logic [2:0] saved_code;
    check_framing();
    if(FRAMING_ONLY)$finish;
    clock_enable=1;
    input_file=$fopen("sim/dilithium/stage7c4_verify_input_inputs.txt","r");output_file=$fopen("sim/dilithium/stage7c4_verify_input_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare compact Verify input fixtures");
    $fdisplay(output_file,"%s %0d",token,n);repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %d %d %s %s",serial,level,id,fault,abort_phase,declared,pk_len,sig_len,pk_hex,sig_hex)!=10 || serial!=test)
        $fatal(1,"Verify input fixture schema");
      for(int i=0;i<pk_len;i++)pk[i]=8'(pk_hex.substr(2*i,2*i+1).atohex());
      for(int i=0;i<sig_len;i++)signature[i]=8'(sig_hex.substr(2*i,2*i+1).atohex());
      @(negedge clk);current=serial;command_param_i=2'(level);command_id_i=16'(id);command_signature_len_i=16'(declared);command_valid_i=1;
      #1;if(!command_ready_o)$fatal(1,"Verify input not ready");
      $fdisplay(output_file,"J %0d %0d %0d",serial,level,id);@(negedge clk);command_valid_i=0;reset_happened=0;
      fork:transaction
        begin
          feed_frame(0,pk_len);if(!done_valid_o)feed_frame(1,sig_len);watchdog=0;
          while(!done_valid_o)begin @(negedge clk);if(watchdog++>30000)$fatal(1,"Verify raw completion timeout case%0d state%0d",current,controller.state);end
        end
        begin
          if(abort_phase<0)wait(1'b0);
          else begin
            watchdog=0;while(!reset_point())begin @(negedge clk);if(watchdog++>30000)$fatal(1,"Verify input reset target unreachable");end
            @(negedge clk);rst=1;input_valid_i=0;reset_happened=1;
          end
        end
      join_any
      disable transaction;input_valid_i=0;
      if(reset_happened)begin
        $fdisplay(output_file,"A %0d",abort_phase);repeat(3)@(negedge clk);rst=0;abort_phase=-1;resets++;
        #1;if(!command_ready_o || done_valid_o || !service_i.idle)$fatal(1,"Verify input reset recovery");
      end else begin
        if(done_id_o!=command_id_i)$fatal(1,"Verify input completion identity");saved_code=done_code_o;
        if(done_code_o==0)capture_context();
        $fdisplay(output_file,"D %0d",done_code_o);
        repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=saved_code)$fatal(1,"Verify input completion unstable");end
        done_ready_i=1;@(negedge clk);done_ready_i=0;
      end
      completed++;
    end
    if(completed!=n || resets!=9)$fatal(1,"Incomplete Verify input campaign");
    if(CYCLE_REFERENCE)$display("VERIFY_INPUT_CYCLE_EQUIVALENCE_PASS:%0d commands;all control pins,service requests and raw contexts exact",completed);
    $fdisplay(output_file,"F %0d",completed);$fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_VERIFY_INPUT_CAPTURE_PASS:%0d commands/%0d physical bank words/9 resets;independent raw-input comparison required",completed,reads);$finish;
  end
  initial begin #100000000;$fatal(1,"Verify input global watchdog");end
endmodule
