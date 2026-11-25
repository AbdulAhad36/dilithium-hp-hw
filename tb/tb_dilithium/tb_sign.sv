`timescale 1ns/1ps
module tb_sign;
  import dilithium_pkg::*;
  parameter bit DIAGNOSTIC=1;
  parameter bit CYCLE_REFERENCE=0,ID_PROOF_ONLY=0,FORCE_RETRY=0;
  parameter int ID_FAULT_PROBE=0;
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
  generate if(CYCLE_REFERENCE || ID_PROOF_ONLY || ID_FAULT_PROBE!=0 || FORCE_RETRY)begin:timing_reference
    request_t reference_service;
    logic reference_start_ready,reference_busy,reference_fault,reference_input_ready;
    logic reference_signature_valid,reference_signature_last,reference_done_valid;
    logic [63:0] reference_signature_data;
    logic [3:0] reference_signature_bytes;
    logic [9:0] reference_signature_index;
    logic [15:0] reference_signature_id,reference_done_id;
    logic [2:0] reference_done_code,reference_done_stage,reference_done_detail;
    logic [16:0] reference_attempts,reference_rejections,reference_nonce;
    int compared=0;
    lighthd_sign_timing_reference reference_controller(
      .clk(clk),.rst(rst),.start_valid_i(start_valid_i),.start_ready_o(reference_start_ready),
      .busy_o(reference_busy),.fault_o(reference_fault),.start_param_i(start_param_i),.start_id_i(start_id_i),
      .start_message_len_i(start_message_len_i),.start_context_len_i(start_context_len_i),.start_rnd_i(start_rnd_i),
      .input_valid_i(input_valid_i),.input_ready_o(reference_input_ready),.input_data_i(input_data_i),
      .input_bytes_i(input_bytes_i),.input_index_i(input_index_i),.input_last_i(input_last_i),
      .signature_valid_o(reference_signature_valid),.signature_ready_i(signature_ready_i),
      .signature_data_o(reference_signature_data),.signature_bytes_o(reference_signature_bytes),
      .signature_index_o(reference_signature_index),.signature_last_o(reference_signature_last),
      .signature_id_o(reference_signature_id),.done_valid_o(reference_done_valid),.done_ready_i(done_ready_i),
      .done_code_o(reference_done_code),.done_stage_o(reference_done_stage),.done_detail_o(reference_done_detail),
      .done_id_o(reference_done_id),.attempts_o(reference_attempts),.rejections_o(reference_rejections),
      .next_nonce_o(reference_nonce),.service_o(reference_service),.service_i(service_i));
    always @(posedge clk)if(!rst && !ID_PROOF_ONLY)begin
      if({service_o,start_ready_o,busy_o,fault_o,input_ready_o,signature_valid_o,signature_data_o,
          signature_bytes_o,signature_index_o,signature_last_o,signature_id_o,done_valid_o,
          done_code_o,done_stage_o,done_detail_o,done_id_o,attempts_o,rejections_o,next_nonce_o} !==
         {reference_service,reference_start_ready,reference_busy,reference_fault,reference_input_ready,
          reference_signature_valid,reference_signature_data,reference_signature_bytes,reference_signature_index,
          reference_signature_last,reference_signature_id,reference_done_valid,reference_done_code,
          reference_done_stage,reference_done_detail,reference_done_id,reference_attempts,reference_rejections,reference_nonce})
        $fatal(1,"Sign ID timing change altered a pin/cycle state%0d",controller.state);
      compared++;
    end
    final if(!ID_PROOF_ONLY)$display("SIGN_CYCLE_REFERENCE_PASS:%0d cycles compared",compared);
  end endgenerate
  generate if(FORCE_RETRY)begin:retry_probe
    int retry_clocks=0;bit injected=0;
    always @(posedge clk)if(!rst && controller.state==controller.RETRY)retry_clocks++;
    initial begin
      do @(negedge clk);while(rst || controller.state!=controller.Z_NORM_RUN ||
        !service_i.poly_process.done_valid || service_i.poly_process.reject);
      force service_i.poly_process.reject=1'b1;
      @(posedge clk);#1;injected=1;
      @(negedge clk);release service_i.poly_process.reject;
    end
    final begin
      if(!injected || retry_clocks==0)$error("Missing controlled Sign retry");
      else $display("SIGN_FORCED_RETRY_PROOF_PASS:%0d retry clocks;all pins/cycles checked against actual old RTL",retry_clocks);
    end
  end endgenerate
  generate if(ID_PROOF_ONLY)begin:descriptor_proof
    initial begin
      logic [16:0] d;logic [15:0] want;
      int checked=0;
      for(int id=0;id<65536;id++)begin
        for(int rc=0;rc<256;rc++)begin
          d={1'b1,4'b0,8'(rc),4'b0};want=16'((id+1024+rc)&65535);
          if(controller.descriptor_id(d,16'(id))!==want ||
             timing_reference.reference_controller.descriptor_id(d,16'(id))!==want)
            $fatal(1,"Matrix sampler ID modular arithmetic id%0d suffix%0d",id,rc);
          if(!controller.descriptor_matches(d,16'(id),want) ||
             controller.descriptor_matches(d,16'(id),want^16'h0001) ||
             controller.descriptor_matches(d,16'(id),want^16'h0100) ||
             controller.descriptor_matches(d,16'(id),want^16'h8000))
            $fatal(1,"Matrix completion-ID positive/negative match id%0d suffix%0d",id,rc);
          checked++;
        end
        for(int index=0;index<16;index++)begin
          d={1'b0,4'(index),12'b0};want=16'((id+256+index)&65535);
          if(controller.descriptor_id(d,16'(id))!==want ||
             timing_reference.reference_controller.descriptor_id(d,16'(id))!==want)
            $fatal(1,"Mask sampler ID modular arithmetic id%0d index%0d",id,index);
          if(!controller.descriptor_matches(d,16'(id),want) ||
             controller.descriptor_matches(d,16'(id),want^16'h0001) ||
             controller.descriptor_matches(d,16'(id),want^16'h0100) ||
             controller.descriptor_matches(d,16'(id),want^16'h8000))
            $fatal(1,"Mask completion-ID positive/negative match id%0d index%0d",id,index);
          checked++;
        end
      end
      $display("SIGN_DESCRIPTOR_ID_PROOF_PASS:%0d combinations/%0d positive and negative matcher checks/all65536 IDs/all256 matrix suffixes/all16 mask suffixes",checked,4*checked);
      begin
        logic [31:0] rng=32'h6a09e667;
        logic [15:0] base,offset,result;
        for(int trial=0;trial<1000000;trial++)begin
          rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};base=rng[15:0];offset=rng[31:16];
          result=16'(int'(base)+int'(offset));
          if(!controller.id_add_matches(base,offset,result))$fatal(1,"Generic ID sum rejected");
          rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};result=rng[15:0];
          if(controller.id_add_matches(base,offset,result)!==(result==16'(int'(base)+int'(offset))))
            $fatal(1,"Generic ID multi-bit mismatch admitted");
        end
        $display("SIGN_CARRY_CONSISTENCY_PROOF_PASS:2000000 arbitrary-offset positive/multi-bit candidate checks");
      end
      $finish;
    end
  end endgenerate
  generate if(ID_FAULT_PROBE!=0)begin:id_fault_probe
    logic [15:0] poisoned_id;
    initial begin
      if(ID_FAULT_PROBE==3)begin
        do @(negedge clk);while(rst || controller.producer==controller.P_IDLE ||
          !service_i.sample.done_valid || !service_o.sample.done_ready || controller.state==controller.CHAL_WAIT);
        poisoned_id=service_i.sample.done_id;
        @(posedge clk);#1;
      end
      if(ID_FAULT_PROBE<=3)begin
        do @(negedge clk);while(rst || controller.producer==controller.P_IDLE ||
          !service_i.sample.done_valid || !service_o.sample.done_ready || controller.state==controller.CHAL_WAIT);
      end else if(ID_FAULT_PROBE==4)begin
        do @(negedge clk);while(rst || controller.state!=controller.CHAL_WAIT || !service_i.sample.done_valid);
      end else begin
        do @(negedge clk);while(rst || controller.state==controller.KEY_WAIT ||
          !service_i.load.done_valid || !service_o.load.done_ready);
      end
      if(ID_FAULT_PROBE==1 || ID_FAULT_PROBE==4)poisoned_id=service_i.sample.done_id^16'h8000;
      if(ID_FAULT_PROBE==5)begin
        poisoned_id=service_i.load.done_id^16'h8000;
        force service_i.load.done_id=poisoned_id;
      end else if(ID_FAULT_PROBE==2)force service_i.sample.done_code=3'd2;
      else force service_i.sample.done_id=poisoned_id;
      @(posedge clk);#1;
      if(!fault_o || controller.state!=controller.HALT ||
         !timing_reference.reference_fault || timing_reference.reference_controller.state!=timing_reference.reference_controller.HALT)
        $fatal(1,"Sign failed to reject sampler completion fault kind%0d",ID_FAULT_PROBE);
      $display("SIGN_ID_FAULT_PROOF_PASS:kind%0d rejected on exact old-RTL cycle",ID_FAULT_PROBE);
      $finish;
    end
  end endgenerate
  datapath datapath(.clk(clk),.rst(rst),.service_i(service_o),.service_o(service_i),.fault_o(datapath_fault));
  int text_file,input_file,output_file,ledger_file,n,serial,original,level,id,context_len,message_len,sk_len,body_len;
  int phase_cycles[16];
  string token,sk_hex,body_hex,case_label,plain_sig;
  logic [7:0] sk[6000],body[65535];
  int cycles=0,current=-1,got=0,total_words=0,completed=0,start_cycle,prep_count=0,pre_count=0,overlap=0,max_ring=0;
  logic held=0;logic [94:0] snapshot;
  function automatic int phase_category;
    case(controller.state)
      controller.KEY_CMD,controller.KEY_WAIT,controller.KEY_RETIRE:return 0;
      controller.PREP_CMD,controller.PREP_RUN:return 1;
      controller.MU_CMD,controller.MU_RUN,controller.MASK_CMD,controller.MASK_RUN:return 2;
      controller.ATTEMPT_BEGIN,controller.Y_READY,controller.Y_NTT_CMD,controller.Y_NTT_RUN:return 3;
      controller.TERM_READY:return 4;
      controller.TERM_CMD,controller.TERM_RUN:return 5;
      controller.INV_ROW_CMD,controller.INV_ROW_RUN:return 6;
      controller.DECOMP_CMD,controller.DECOMP_RUN:return 7;
      controller.W1_READ_CMD,controller.CHASH_CMD,controller.CHASH_RUN,controller.CHASH_DRAIN:return 8;
      controller.CHAL_CMD,controller.CHAL_FEED,controller.CHAL_WAIT,controller.CHAL_NTT_CMD,controller.CHAL_NTT_RUN:return 9;
      controller.Z_MUL_CMD,controller.Z_MUL_RUN,controller.Z_INV_CMD,controller.Z_INV_RUN,controller.Z_NORM_CMD,controller.Z_NORM_RUN:return 10;
      controller.R0_MUL_CMD,controller.R0_MUL_RUN,controller.R0_INV_CMD,controller.R0_INV_RUN,controller.R0_SUB_CMD,
        controller.R0_SUB_RUN,controller.R0_NORM_CMD,controller.R0_NORM_RUN:return 11;
      controller.HINT_CMD,controller.CT0_MUL_CMD,controller.CT0_MUL_RUN,controller.CT0_INV_CMD,controller.CT0_INV_RUN,
        controller.CT0_NORM_CMD,controller.CT0_NORM_RUN,controller.R0_ADD_CMD,controller.R0_ADD_RUN:return 12;
      controller.W1_HINT_READ_CMD,controller.W1_HINT_LOAD_CMD,controller.W1_HINT_FEED,controller.W1_HINT_DRAIN,
        controller.MHINT_CMD,controller.MHINT_RUN,controller.HINT_RESULT:return 13;
      controller.SIG_PREFIX,controller.SIG_Z_CMD,controller.SIG_Z_STREAM,controller.SIG_HINT,controller.SIG_DRAIN:return 14;
      default:return 15;
    endcase
  endfunction
  always @(negedge clk)cycles++;
  assign signature_ready_i=!rst && cycles%13>3;
  always @(posedge clk)if(rst)held=0;else begin
    int occupied;
    if(busy_o && controller.state!=controller.REPORT)phase_cycles[phase_category()]++;
    occupied=$countones(controller.a_reserved_r);if(occupied>max_ring)max_ring=occupied;
    if(occupied>(start_param_i==2?16:9))$fatal(1,"Signing A ring exceeded its fixed capacity");
    if(datapath.polynomial.core_busy && |service_i.sample.active)overlap++;
    if(held && (!signature_valid_o || {signature_data_o,signature_bytes_o,signature_index_o,signature_last_o,signature_id_o}!==snapshot))
      $fatal(1,"Compact signature changed under backpressure");
    held=signature_valid_o && !signature_ready_i;
    snapshot={signature_data_o,signature_bytes_o,signature_index_o,signature_last_o,signature_id_o};
    if(service_o.ntt.valid && service_i.ntt.ready && controller.state==controller.PREP_CMD)begin
      prep_count++;if(service_o.ntt.op==3)pre_count++;
    end
    if(controller.state==controller.CHASH_DRAIN && controller.format_finished_r && controller.raw_finished_r && controller.bank_finished_r)
      $fdisplay(output_file,"C %0d %0d %0d %0128h",attempts_o,controller.nonce_base_r,controller.ctilde_bytes,controller.ctilde_r);
    if(service_i.poly_process.done_valid && service_o.poly_process.done_ready && service_i.poly_process.reject)begin
      if(controller.state==controller.Z_NORM_RUN)$fdisplay(output_file,"R %0d 1 %0d",attempts_o,controller.poly_r);
      if(controller.state==controller.R0_NORM_RUN)$fdisplay(output_file,"R %0d 2 %0d",attempts_o,controller.row_r);
      if(controller.state==controller.CT0_NORM_RUN)$fdisplay(output_file,"R %0d 3 %0d",attempts_o,controller.row_r);
    end
    if(controller.state==controller.MHINT_RUN && service_i.poly_process.done_valid && controller.hint_reject)
      $fdisplay(output_file,"R %0d 4 %0d",attempts_o,controller.row_r);
    if(controller.state==controller.HINT_RESULT && controller.hint_result && controller.hint_reject)
      $fdisplay(output_file,"R %0d 4 %0d",attempts_o,controller.row_r);
    if(signature_valid_o && signature_ready_i)begin
      int length;length=start_param_i==0?2420:start_param_i==1?3309:4627;
      if(signature_id_o!=start_id_i || signature_index_o*8!=got || signature_bytes_o<1 || signature_bytes_o>8 ||
        signature_last_o!=(got+signature_bytes_o==length) || (signature_data_o>>(8*int'(signature_bytes_o)))!=0)
        $fatal(1,"Compact signature identity/order/byte count/padding");
      $fdisplay(output_file,"S %0d %016h %0d %0d",signature_index_o,signature_data_o,signature_bytes_o,signature_last_o);
      for(int lane=0;lane<int'(signature_bytes_o);lane++)plain_sig={plain_sig,$sformatf("%02h",signature_data_o[8*lane+:8])};
      got+=int'(signature_bytes_o);total_words++;
    end
    if(fault_o || datapath_fault)$fatal(1,"Compact Sign fault case%0d state%0d ntterror%0d procerror%0d loaderror%0d",current,controller.state,
      service_i.ntt.done_code,service_i.poly_process.done_code,service_i.load.done_code);
    if(busy_o && cycles%100000==0)$display("COMPACT_SIGN_PROGRESS:case%0d clock%0d state%0d attempts%0d rejections%0d",current,cycles,controller.state,attempts_o,rejections_o);
  end
  task automatic feed_frame(input bit secret_key,input int length);
    int amount,index,watchdog;index=0;watchdog=0;
    while(index*8<length && !done_valid_o)begin
      @(negedge clk);input_valid_i=1;input_data_i='1;
      amount=length-index*8>=8?8:length-index*8;
      input_bytes_i=4'(amount);input_index_i=16'(index);input_last_i=index*8+amount==length;
      for(int lane=0;lane<amount;lane++)input_data_i[8*lane+:8]=secret_key?sk[8*index+lane]:body[8*index+lane];
      @(posedge clk);
      while(!input_ready_o && !done_valid_o)begin
        @(posedge clk);if(watchdog++>500000)$fatal(1,"Compact Sign input timeout state%0d",controller.state);
      end
      if(input_ready_o)index++;
      @(negedge clk);input_valid_i=0;
    end
    if(index*8<length)$fatal(1,"Signing completed before required input frame");
  endtask
  initial if(!ID_PROOF_ONLY)begin
    int watchdog,k,l,phase_sum;
    input_file=$fopen(DIAGNOSTIC?"sim/dilithium/sign_diagnostic_inputs.txt":"sim/dilithium/sign_inputs.txt","r");
    output_file=$fopen(DIAGNOSTIC?"sim/dilithium/sign_diagnostic_outputs.txt":"sim/dilithium/sign_outputs.txt","w");
    ledger_file=$fopen(DIAGNOSTIC?"sim/dilithium/sign_diagnostic_cycles.csv":"sim/dilithium/sign_cycles.csv","w");
    if(!input_file || !output_file || !ledger_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare compact signing fixtures");
    text_file=$fopen("sim/dilithium/outputs_hw.txt","w");if(!text_file)$fatal(1,"Cannot open plain RTL outputs_hw.txt");
    $fdisplay(ledger_file,"case,original,level,total,attempts,key_load,secret_transforms,mu_and_seed,y_prepare,matrix_wait,mac,row_inverse,decompose,challenge_hash,challenge_poly,z_products_and_norm,r0_products_and_norm,ct0_products_and_norm,hints,signature_output,retry");
    $fdisplay(output_file,"%s %0d",token,n);repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %d %d %h %s %s %s",serial,original,level,id,context_len,message_len,sk_len,body_len,start_rnd_i,sk_hex,body_hex,case_label)!=12 || serial!=test)
        $fatal(1,"Compact Sign fixture schema");
      plain_sig="";
      for(int i=0;i<sk_len;i++)sk[i]=8'(sk_hex.substr(2*i,2*i+1).atohex());
      for(int i=0;i<body_len;i++)body[i]=8'(body_hex.substr(2*i,2*i+1).atohex());
      @(negedge clk);current=serial;start_param_i=2'(level);start_id_i=16'(id);
      start_context_len_i=9'(context_len);start_message_len_i=16'(message_len);
      start_valid_i=1;got=0;prep_count=0;pre_count=0;start_cycle=cycles;
      for(int phase=0;phase<16;phase++)phase_cycles[phase]=0;
      #1;if(!start_ready_o)$fatal(1,"Compact Sign not ready for command");
      $fdisplay(output_file,"J %0d %0d %0d %0d",serial,original,level,id);
      @(negedge clk);start_valid_i=0;
      feed_frame(1,sk_len);feed_frame(0,body_len);watchdog=0;
      while(!done_valid_o)begin
        @(negedge clk);
        if(watchdog++>5000000)$fatal(1,"Compact Sign command timeout case%0d state%0d producer%0d attempts%0d",serial,controller.state,controller.producer,attempts_o);
      end
      k=level==0?4:level==1?6:8;l=level==0?4:level==1?5:7;
      if(done_code_o!=0 || done_stage_o!=0 || done_detail_o!=0 || done_id_o!=start_id_i ||
        prep_count!=l+2*k || pre_count!=l+k || !service_i.idle)$fatal(1,"Compact Sign completion/cache/retirement gate");
      $fdisplay(output_file,"D %0d %0d %0d %0d %0d %0d %0d",done_code_o,done_stage_o,done_detail_o,attempts_o,rejections_o,next_nonce_o,cycles-start_cycle);
      if(done_code_o!=0 || plain_sig.len()!=2*(level==0?2420:level==1?3309:4627))$fatal(1,"Incomplete plain Sign output");
      if(completed>0)$fdisplay(text_file,"");
        $fdisplay(text_file,"[%s] level=%0d operation=sign",case_label,level==0?2:level==1?3:5);
      $fdisplay(text_file,"signature = %s",plain_sig);$fflush(text_file);
      $display("COMPACT_SIGN_CASE_PASS:serial%0d original%0d level%0d cycles%0d attempts%0d",serial,original,level,cycles-start_cycle,attempts_o);
      phase_sum=0;for(int phase=0;phase<16;phase++)phase_sum+=phase_cycles[phase];
      if(phase_sum+1!=cycles-start_cycle)$fatal(1,"Signing cycle ledger does not sum");
      $fwrite(ledger_file,"%0d,%0d,%0d,%0d,%0d",serial,original,level,cycles-start_cycle,attempts_o);
      for(int phase=0;phase<16;phase++)$fwrite(ledger_file,",%0d",phase_cycles[phase]);$fwrite(ledger_file,"\n");
      repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=0)$fatal(1,"Compact Sign completion unstable");end
      done_ready_i=1;@(negedge clk);done_ready_i=0;completed++;
    end
    $fdisplay(output_file,"F %0d",completed);$fclose(input_file);$fclose(output_file);$fclose(ledger_file);$fclose(text_file);
    $display("LIGHTHD_SIGN_CAPTURE_PASS:%0d signatures/%0d words/overlap%0d/peak_A_ring%0d;independent published-signature comparison required",completed,total_words,overlap,max_ring);
    $finish;
  end
  initial begin #(64'd10000000000);$fatal(1,"Compact Sign global watchdog");end
endmodule
