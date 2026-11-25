`timescale 1ns/1ps
module tb_main;
  logic key_valid_o;
  logic key_ready_i;
  logic [63:0] key_data_o;
  logic [3:0] key_bytes_o;
  logic key_type_o;
  logic key_last_o;
  logic [9:0] key_index_o;
  logic [15:0] key_id_o;
  logic clk;
  logic rst;
  logic start_valid_i;
  logic start_ready_o;
  logic busy_o;
  logic [1:0] start_op_i;
  logic [1:0] start_param_i;
  logic [15:0] start_id_i;
  logic [255:0] start_seed_i;
  logic [15:0] start_message_len_i;
  logic [8:0] start_context_len_i;
  logic start_internal_message_i;
  logic [255:0] start_rnd_i;
  logic sign_input_valid_i;
  logic sign_input_ready_o;
  logic [63:0] sign_input_data_i;
  logic [3:0] sign_input_bytes_i;
  logic [15:0] sign_input_index_i;
  logic sign_input_last_i;
  logic [15:0] start_signature_len_i;
  logic verify_input_valid_i;
  logic verify_input_ready_o;
  logic [63:0] verify_input_data_i;
  logic [3:0] verify_input_bytes_i;
  logic [15:0] verify_input_index_i;
  logic verify_input_last_i;
  logic verify_accept_o;
  logic signature_valid_o;
  logic signature_ready_i;
  logic [63:0] signature_data_o;
  logic [3:0] signature_bytes_o;
  logic [9:0] signature_index_o;
  logic signature_last_o;
  logic [15:0] signature_id_o;
  logic [2:0] done_stage_o;
  logic [2:0] done_detail_o;
  logic [16:0] sign_attempts_o;
  logic [16:0] sign_rejections_o;
  logic [16:0] sign_next_nonce_o;
  logic done_valid_o;
  logic done_ready_i;
  logic [2:0] done_code_o;
  logic [15:0] done_id_o;
  logic fault_o;

  parameter bit DIAGNOSTIC=1;
  parameter bit PROTOCOL=0;
  parameter bit CYCLE_REFERENCE=0;
  parameter bit MUX_PROOF_ONLY=0;
  parameter bit ALLOW_FATAL_PACK_DRAIN=0;
  parameter bit FATAL_DRAIN_PROBE=0;
  parameter int FATAL_DRAIN_PHASE=0;
  int fatal_drain_checks=0;
  bit fatal_drain_active=0;
  import dilithium_pkg::*;
  dilithium_fpga dut(.*);
  generate if(CYCLE_REFERENCE)begin:mux_reference
    int checked_clocks=0;
    logic reference_key_valid_o;
    logic [63:0] reference_key_data_o;
    logic [3:0] reference_key_bytes_o;
    logic reference_key_type_o;
    logic reference_key_last_o;
    logic [9:0] reference_key_index_o;
    logic [15:0] reference_key_id_o;
    logic reference_start_ready_o;
    logic reference_busy_o;
    logic reference_sign_input_ready_o;
    logic reference_verify_input_ready_o;
    logic reference_verify_accept_o;
    logic reference_signature_valid_o;
    logic [63:0] reference_signature_data_o;
    logic [3:0] reference_signature_bytes_o;
    logic [9:0] reference_signature_index_o;
    logic reference_signature_last_o;
    logic [15:0] reference_signature_id_o;
    logic [2:0] reference_done_stage_o;
    logic [2:0] reference_done_detail_o;
    logic [16:0] reference_sign_attempts_o;
    logic [16:0] reference_sign_rejections_o;
    logic [16:0] reference_sign_next_nonce_o;
    logic reference_done_valid_o;
    logic [2:0] reference_done_code_o;
    logic [15:0] reference_done_id_o;
    logic reference_fault_o;
    dilithium_fpga_mux_reference reference_dut(
    .key_valid_o(reference_key_valid_o),
    .key_ready_i(key_ready_i),
    .key_data_o(reference_key_data_o),
    .key_bytes_o(reference_key_bytes_o),
    .key_type_o(reference_key_type_o),
    .key_last_o(reference_key_last_o),
    .key_index_o(reference_key_index_o),
    .key_id_o(reference_key_id_o),
    .clk(clk),
    .rst(rst),
    .start_valid_i(start_valid_i),
    .start_ready_o(reference_start_ready_o),
    .busy_o(reference_busy_o),
    .start_op_i(start_op_i),
    .start_param_i(start_param_i),
    .start_id_i(start_id_i),
    .start_seed_i(start_seed_i),
    .start_message_len_i(start_message_len_i),
    .start_context_len_i(start_context_len_i),
    .start_rnd_i(start_rnd_i),
    .sign_input_valid_i(sign_input_valid_i),
    .sign_input_ready_o(reference_sign_input_ready_o),
    .sign_input_data_i(sign_input_data_i),
    .sign_input_bytes_i(sign_input_bytes_i),
    .sign_input_index_i(sign_input_index_i),
    .sign_input_last_i(sign_input_last_i),
    .start_signature_len_i(start_signature_len_i),
    .verify_input_valid_i(verify_input_valid_i),
    .verify_input_ready_o(reference_verify_input_ready_o),
    .verify_input_data_i(verify_input_data_i),
    .verify_input_bytes_i(verify_input_bytes_i),
    .verify_input_index_i(verify_input_index_i),
    .verify_input_last_i(verify_input_last_i),
    .verify_accept_o(reference_verify_accept_o),
    .signature_valid_o(reference_signature_valid_o),
    .signature_ready_i(signature_ready_i),
    .signature_data_o(reference_signature_data_o),
    .signature_bytes_o(reference_signature_bytes_o),
    .signature_index_o(reference_signature_index_o),
    .signature_last_o(reference_signature_last_o),
    .signature_id_o(reference_signature_id_o),
    .done_stage_o(reference_done_stage_o),
    .done_detail_o(reference_done_detail_o),
    .sign_attempts_o(reference_sign_attempts_o),
    .sign_rejections_o(reference_sign_rejections_o),
    .sign_next_nonce_o(reference_sign_next_nonce_o),
    .done_valid_o(reference_done_valid_o),
    .done_ready_i(done_ready_i),
    .done_code_o(reference_done_code_o),
    .done_id_o(reference_done_id_o),
    .fault_o(reference_fault_o)
    );
    always @(posedge clk)if(!rst)begin
      if(key_valid_o !== reference_key_valid_o ||
         key_data_o !== reference_key_data_o ||
         key_bytes_o !== reference_key_bytes_o ||
         key_type_o !== reference_key_type_o ||
         key_last_o !== reference_key_last_o ||
         key_index_o !== reference_key_index_o ||
         key_id_o !== reference_key_id_o ||
         start_ready_o !== reference_start_ready_o ||
         busy_o !== reference_busy_o ||
         sign_input_ready_o !== reference_sign_input_ready_o ||
         verify_input_ready_o !== reference_verify_input_ready_o ||
         verify_accept_o !== reference_verify_accept_o ||
         signature_valid_o !== reference_signature_valid_o ||
         signature_data_o !== reference_signature_data_o ||
         signature_bytes_o !== reference_signature_bytes_o ||
         signature_index_o !== reference_signature_index_o ||
         signature_last_o !== reference_signature_last_o ||
         signature_id_o !== reference_signature_id_o ||
         done_stage_o !== reference_done_stage_o ||
         done_detail_o !== reference_done_detail_o ||
         sign_attempts_o !== reference_sign_attempts_o ||
         sign_rejections_o !== reference_sign_rejections_o ||
         sign_next_nonce_o !== reference_sign_next_nonce_o ||
         done_valid_o !== reference_done_valid_o ||
         done_code_o !== reference_done_code_o ||
         done_id_o !== reference_done_id_o ||
         fault_o !== reference_fault_o)$fatal(1,"Root mux rewrite changed a public pin/cycle");
      if(dut.core.request !== reference_dut.core.request)$fatal(1,"Root request mux differs,including inactive payload");
      checked_clocks++;
    end
    final $display("ROOT_MUX_CYCLE_REFERENCE_PASS:%0d clocks/all public pins/full request record",checked_clocks);
  end endgenerate

  always #5 clk=~clk;
  int cycles=0,current=-1,completed=0,op,serial,original,level,id,context_len,message_len,sig_len,frame_count,lengths[3],internal_message;
  int text_file, input_file,output_file,n,start_cycle,input_words=0,key_words=0,signature_words=0;
  int scenario=0,abort_phase=-1,busy_probe=0,resets=0,busy_checks=0,case_input_start,case_key_start,case_signature_start;
  bit reset_happened;
  string capture_dir="sim/dilithium";
  string case_label,plain_operation,plain_pk,plain_sk,plain_sig;
  string token,hex0,hex1,hex2;logic [7:0] frame0[6000],frame1[65535],frame2[65535];
  logic key_held=0,signature_held=0;logic [95:0] key_snapshot;logic [94:0] signature_snapshot;
  always @(negedge clk)cycles++;
  // Optional scheduling audit: observations only; capture schema is unchanged.
  // Enable with +SCHEDULE_AUDIT on the existing main bench.
  bit schedule_audit;
  int schedule_states[64],schedule_ntt_states[16],schedule_core_busy[4];
  int schedule_input_beats,schedule_chunks,schedule_prepare_wait,schedule_capacity_wait,schedule_writer_stall,schedule_packets;
  int schedule_ntt_busy,schedule_overlap,schedule_hash_stall,schedule_sample_cmds;
  int schedule_producer_wait,schedule_one_core_wait,schedule_no_engines;
  initial schedule_audit=$test$plusargs("SCHEDULE_AUDIT");
  always @(posedge clk) if(schedule_audit)begin
    if(rst || (start_valid_i && start_ready_o))begin
      foreach(schedule_states[i])schedule_states[i]=0;
      foreach(schedule_ntt_states[i])schedule_ntt_states[i]=0;
      foreach(schedule_core_busy[i])schedule_core_busy[i]=0;
      schedule_input_beats=0;schedule_chunks=0;schedule_prepare_wait=0;schedule_capacity_wait=0;schedule_writer_stall=0;schedule_packets=0;
      schedule_ntt_busy=0;schedule_overlap=0;schedule_hash_stall=0;schedule_sample_cmds=0;
      schedule_producer_wait=0;schedule_one_core_wait=0;schedule_no_engines=0;
    end else if(busy_o && !done_valid_o && start_op_i==0)begin
      schedule_states[int'(dut.core.keygen_controller.state)]++;
      schedule_ntt_states[int'(dut.core.datapath.polynomial.state)]++;
      schedule_core_busy[int'(dut.core.datapath.hash_sampler.engine.hash_busy)]++;
      if(dut.core.datapath.polynomial.core_busy)schedule_ntt_busy++;
      if(dut.core.datapath.polynomial.core_busy && |dut.core.datapath.hash_sampler.engine.hash_busy)schedule_overlap++;
      if(dut.core.datapath.hash_sampler.engine.hash_valid && !dut.core.datapath.hash_sampler.engine.hash_ready)schedule_hash_stall++;
      if(dut.core.request.sample.valid && dut.core.response.sample.ready)schedule_sample_cmds++;
      if(dut.core.datapath.hash_sampler.engine.sampler_input_valid && dut.core.datapath.hash_sampler.engine.sampler_input_ready)schedule_input_beats++;
      if(dut.core.datapath.hash_sampler.engine.sample.chunk_fire)schedule_chunks++;
      if(dut.core.datapath.hash_sampler.engine.sample.hold_r && !dut.core.datapath.hash_sampler.engine.sample.prepare_ready)schedule_prepare_wait++;
      if(dut.core.datapath.hash_sampler.engine.sample.hold_r && dut.core.datapath.hash_sampler.engine.sample.prepare_ready && !dut.core.datapath.hash_sampler.engine.sample.chunk_capacity[dut.core.datapath.hash_sampler.engine.sample.hold_core_r])schedule_capacity_wait++;
      if(dut.core.datapath.hash_sampler.packet_valid && !dut.core.datapath.hash_sampler.packet_ready)schedule_writer_stall++;
      if(dut.core.datapath.hash_sampler.packet_valid && dut.core.datapath.hash_sampler.packet_ready)schedule_packets++;
      if(dut.core.keygen_controller.producer==dut.core.keygen_controller.P_WAIT)begin
        schedule_producer_wait++;
        if($countones(dut.core.datapath.hash_sampler.engine.hash_busy)==1)schedule_one_core_wait++;
      end
      if(!dut.core.datapath.polynomial.core_busy && !(|dut.core.datapath.hash_sampler.engine.hash_busy))schedule_no_engines++;
    end
  end
  task automatic report_keygen_schedule;
    if(schedule_audit && op==0)begin
      $display("SCHEDULE_KEYGEN case=%0d level=%0d cycles=%0d cores_idle=%0d core0_only=%0d core1_only=%0d both=%0d ntt_busy=%0d overlap=%0d hash_output_stall=%0d sample_commands=%0d batch_wait=%0d batch_wait_one_core=%0d no_hash_or_ntt=%0d",
        serial,level,cycles-start_cycle,schedule_core_busy[0],schedule_core_busy[1],schedule_core_busy[2],schedule_core_busy[3],
        schedule_ntt_busy,schedule_overlap,schedule_hash_stall,schedule_sample_cmds,schedule_producer_wait,schedule_one_core_wait,schedule_no_engines);
      $display("SCHEDULE_SAMPLER beats=%0d chunks=%0d prepare_wait=%0d capacity_wait=%0d writer_stall=%0d packets=%0d",schedule_input_beats,schedule_chunks,schedule_prepare_wait,schedule_capacity_wait,schedule_writer_stall,schedule_packets);
      foreach(schedule_states[i])if(schedule_states[i])$display("SCHEDULE_KEYGEN_STATE state=%0d clocks=%0d",i,schedule_states[i]);
      foreach(schedule_ntt_states[i])if(schedule_ntt_states[i])$display("SCHEDULE_NTT_DMA_STATE state=%0d clocks=%0d",i,schedule_ntt_states[i]);
    end
  endtask

  assign key_ready_i=!rst && cycles%13>3 && !(PROTOCOL && abort_phase==3 && key_type_o==0 && key_index_o>=20);
  assign signature_ready_i=!rst && cycles%11>2 && !(PROTOCOL && abort_phase==7 && signature_index_o>=10);
  function automatic bit reset_point;
    case(abort_phase)
      0:return dut.core.keygen_controller.state==dut.core.keygen_controller.SEED_WAIT && dut.core.response.raw.output_valid;
      1:return dut.core.keygen_controller.state==dut.core.keygen_controller.S1_RUN && dut.core.datapath.polynomial.core_busy;
      2:return dut.core.keygen_controller.state==dut.core.keygen_controller.ROUND_RUN && dut.core.datapath.process_path.produced_r>4;
      3:return key_valid_o && key_type_o==0 && key_index_o>=20 && !key_ready_i;
      4:return dut.core.sign_controller.state==dut.core.sign_controller.KEY_WAIT && dut.core.datapath.hash_sampler.decoder.committed_r>=32 && dut.core.datapath.hash_sampler.decoder.committed_r<256;
      5:return dut.core.sign_controller.state==dut.core.sign_controller.Y_NTT_RUN && dut.core.datapath.polynomial.core_busy;
      6:return dut.core.sign_controller.state==dut.core.sign_controller.TERM_RUN && dut.core.datapath.polynomial.core_busy;
      7:return dut.core.sign_controller.state==dut.core.sign_controller.SIG_Z_STREAM && signature_valid_o && signature_index_o>=10 && !signature_ready_i;
      8:return dut.core.verify_controller.state==dut.core.verify_controller.INPUT_WAIT && dut.core.verify_controller.inputs.state==dut.core.verify_controller.inputs.PK_DATA && dut.core.datapath.hash_sampler.decoder.committed_r>=32 && dut.core.datapath.hash_sampler.decoder.committed_r<256;
      9:return dut.core.verify_controller.state==dut.core.verify_controller.PREP_RUN && dut.core.datapath.polynomial.core_busy;
      10:return dut.core.verify_controller.state==dut.core.verify_controller.PACK_RUN && dut.core.datapath.process_path.produced_r>4;
      11:return dut.core.verify_controller.state==dut.core.verify_controller.CHASH_RUN && dut.core.v_request.raw.input_valid;
      default:return 0;
    endcase
  endfunction
  function automatic bit command_pending(input request_t request);
    return request.raw.valid || request.sample.valid || request.load.valid || request.ntt.valid ||
      request.poly_process.valid || |request.bank.command_valid;
  endfunction
  always @(posedge clk)if(rst)begin key_held=0;signature_held=0;end else begin
    if(fault_o && !fatal_drain_active)$fatal(1,"Compact main fault case%0d state%0d KG%0d Sign%0d Verify%0d",current,dut.core.state,
      dut.core.keygen_controller.state,dut.core.sign_controller.state,dut.core.verify_controller.state);
    if(key_valid_o && signature_valid_o)$fatal(1,"Two output operation owners");
    if(key_held && !fatal_drain_active && (!key_valid_o || {key_data_o,key_bytes_o,key_type_o,key_last_o,key_index_o,key_id_o}!==key_snapshot))
      $fatal(1,"Main key changed under backpressure");
    if(signature_held && !fatal_drain_active && (!signature_valid_o || {signature_data_o,signature_bytes_o,signature_index_o,signature_last_o,signature_id_o}!==signature_snapshot))
      $fatal(1,"Main signature changed under backpressure");
    key_held=key_valid_o && !key_ready_i;signature_held=signature_valid_o && !signature_ready_i;
    key_snapshot={key_data_o,key_bytes_o,key_type_o,key_last_o,key_index_o,key_id_o};
    signature_snapshot={signature_data_o,signature_bytes_o,signature_index_o,signature_last_o,signature_id_o};
    if(dut.core.state==dut.core.EXECUTE)begin
      if(dut.core.op_r!=0 && command_pending(dut.core.k_request))$fatal(1,"Inactive KeyGen launched work");
      if(dut.core.op_r!=1 && (command_pending(dut.core.s_request) || sign_input_ready_o))$fatal(1,"Inactive Sign consumed/launched work");
      if(dut.core.op_r!=2 && (command_pending(dut.core.v_request) || verify_input_ready_o))$fatal(1,"Inactive Verify consumed/launched work");
    end
    if((sign_input_valid_i && sign_input_ready_o) || (verify_input_valid_i && verify_input_ready_o))input_words++;
    if(key_valid_o && key_ready_i)begin
      if(op!=0 || key_id_o!=start_id_i)$fatal(1,"Main key owner/ID");
      $fdisplay(output_file,"K %0d %0d %016h %0d %0d",key_type_o,key_index_o,key_data_o,key_bytes_o,key_last_o);key_words++;
      if(!PROTOCOL)for(int lane=0;lane<int'(key_bytes_o);lane++)begin
        if(key_type_o)plain_sk={plain_sk,$sformatf("%02h",key_data_o[8*lane+:8])};
        else plain_pk={plain_pk,$sformatf("%02h",key_data_o[8*lane+:8])};
      end
    end
    if(signature_valid_o && signature_ready_i)begin
      if(op!=1 || signature_id_o!=start_id_i)$fatal(1,"Main signature owner/ID");
      $fdisplay(output_file,"S %0d %016h %0d %0d",signature_index_o,signature_data_o,signature_bytes_o,signature_last_o);signature_words++;
      if(!PROTOCOL)for(int lane=0;lane<int'(signature_bytes_o);lane++)
        plain_sig={plain_sig,$sformatf("%02h",signature_data_o[8*lane+:8])};
    end
    if(dut.core.state==dut.core.EXECUTE && dut.core.op_r==1)begin
      if(dut.core.sign_controller.state==dut.core.sign_controller.CHASH_DRAIN && dut.core.sign_controller.format_finished_r &&
        dut.core.sign_controller.raw_finished_r && dut.core.sign_controller.bank_finished_r)
        $fdisplay(output_file,"A %0d %0d %0d %0128h",sign_attempts_o,dut.core.sign_controller.nonce_base_r,dut.core.sign_controller.ctilde_bytes,dut.core.sign_controller.ctilde_r);
      if(dut.core.s_request.poly_process.done_ready && dut.core.response.poly_process.done_valid && dut.core.response.poly_process.reject)begin
        if(dut.core.sign_controller.state==dut.core.sign_controller.Z_NORM_RUN)$fdisplay(output_file,"R %0d 1 %0d",sign_attempts_o,dut.core.sign_controller.poly_r);
        if(dut.core.sign_controller.state==dut.core.sign_controller.R0_NORM_RUN)$fdisplay(output_file,"R %0d 2 %0d",sign_attempts_o,dut.core.sign_controller.row_r);
        if(dut.core.sign_controller.state==dut.core.sign_controller.CT0_NORM_RUN)$fdisplay(output_file,"R %0d 3 %0d",sign_attempts_o,dut.core.sign_controller.row_r);
      end
      if((dut.core.sign_controller.state==dut.core.sign_controller.MHINT_RUN && dut.core.response.poly_process.done_valid && dut.core.sign_controller.hint_reject) ||
        (dut.core.sign_controller.state==dut.core.sign_controller.HINT_RESULT && dut.core.sign_controller.hint_result && dut.core.sign_controller.hint_reject))
        $fdisplay(output_file,"R %0d 4 %0d",sign_attempts_o,dut.core.sign_controller.row_r);
    end
    if(dut.core.state==dut.core.EXECUTE && dut.core.op_r==2 && dut.core.verify_controller.state==dut.core.verify_controller.CHASH_DRAIN &&
      dut.core.verify_controller.format_finished_r && dut.core.verify_controller.raw_finished_r && dut.core.verify_controller.bank_finished_r)
      $fdisplay(output_file,"C %0128h",dut.core.verify_controller.digest_r);
    if(busy_o && cycles%100000==0)$display("COMPACT_MAIN_PROGRESS:case%0d op%0d clock%0d Sign%0d Verify%0d",
      current,op,cycles,dut.core.sign_controller.state,dut.core.verify_controller.state);
  end
  task automatic feed_frame(input int frame,length);
    int index,amount,watchdog;logic [63:0] data;index=0;watchdog=0;
    while(index*8<length && !done_valid_o)begin
      @(negedge clk);data='1;amount=length-index*8>=8?8:length-index*8;
      for(int lane=0;lane<amount;lane++)data[8*lane+:8]=frame==0?frame0[8*index+lane]:frame==1?frame1[8*index+lane]:frame2[8*index+lane];
      if(op==1)begin sign_input_valid_i=1;sign_input_data_i=data;sign_input_index_i=16'(index);sign_input_bytes_i=4'(amount);sign_input_last_i=index*8+amount==length;end
      else begin verify_input_valid_i=1;verify_input_data_i=data;verify_input_index_i=16'(index);verify_input_bytes_i=4'(amount);verify_input_last_i=index*8+amount==length;end
      if(PROTOCOL && index==0)begin
        if(scenario==6 && frame==0)sign_input_bytes_i=0;
        if(scenario==7 && frame==1)sign_input_index_i=1;
        if(scenario==8 && frame==0)verify_input_bytes_i=0;
        if(scenario==9 && frame==1)verify_input_index_i=1;
        if(scenario==10 && frame==2)verify_input_index_i=1;
      end
      @(posedge clk);while(!(op==1?sign_input_ready_o:verify_input_ready_o) && !done_valid_o)begin
        @(posedge clk);if(watchdog++>100000)$fatal(1,"Main input timeout case%0d op%0d frame%0d",current,op,frame);
      end
      if(op==1?sign_input_ready_o:verify_input_ready_o)index++;
      @(negedge clk);if(op==1)sign_input_valid_i=0;else verify_input_valid_i=0;
    end
  endtask
  initial begin:main_capture
    int watchdog;logic [76:0] saved_completion;logic [573:0] command_snapshot;
    if(MUX_PROOF_ONLY)disable main_capture;
    clk=0;rst=1;start_valid_i=0;start_op_i=0;start_param_i=0;start_id_i=0;start_seed_i=0;
    start_message_len_i=0;start_context_len_i=0;start_internal_message_i=0;start_rnd_i=0;start_signature_len_i=0;done_ready_i=0;
    sign_input_valid_i=0;sign_input_data_i='1;sign_input_bytes_i=0;sign_input_index_i='1;sign_input_last_i=1;
    verify_input_valid_i=0;verify_input_data_i='1;verify_input_bytes_i=0;verify_input_index_i='1;verify_input_last_i=1;
    if($value$plusargs("DILITHIUM_DATA_DIR=%s",capture_dir))begin end
    input_file=$fopen({capture_dir,"/",PROTOCOL?"main_protocol_inputs.txt":DIAGNOSTIC?"main_diagnostic_inputs.txt":"main_inputs.txt"},"r");
    output_file=$fopen({capture_dir,"/",PROTOCOL?"main_protocol_outputs.txt":DIAGNOSTIC?"main_diagnostic_outputs.txt":"main_outputs.txt"},"w");
    text_file=0;
    if(!PROTOCOL)begin
      text_file=$fopen({capture_dir,"/outputs_hw.txt"},"w");
      if(!text_file)$fatal(1,"Cannot open plain RTL outputs_hw.txt");
    end
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare compact main fixtures");
    $fdisplay(output_file,"%s %0d",token,n);repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %d %d %d %d %d %d %h %h %s %s %s %s %d",
        serial,op,original,level,id,context_len,message_len,sig_len,frame_count,lengths[0],lengths[1],lengths[2],start_seed_i,start_rnd_i,hex0,hex1,hex2,case_label,internal_message)!=19 || serial!=test)
        $fatal(1,"Main fixture schema");
      plain_pk="";plain_sk="";plain_sig="";
      if(PROTOCOL && $fscanf(input_file,"%d %d %d",scenario,abort_phase,busy_probe)!=3)$fatal(1,"Main protocol fixture schema");
      for(int i=0;i<lengths[0];i++)frame0[i]=8'(hex0.substr(2*i,2*i+1).atohex());
      for(int i=0;i<lengths[1];i++)frame1[i]=8'(hex1.substr(2*i,2*i+1).atohex());
      for(int i=0;i<lengths[2];i++)frame2[i]=8'(hex2.substr(2*i,2*i+1).atohex());
      watchdog=0;while(!start_ready_o)begin @(negedge clk);if(watchdog++>1000)$fatal(1,"Main failed to retire previous owner");end
      @(negedge clk);current=serial;start_op_i=2'(op);start_param_i=2'(level);start_id_i=16'(id);
      start_context_len_i=9'(context_len);start_internal_message_i=1'(internal_message);start_message_len_i=16'(message_len);start_signature_len_i=16'(sig_len);
      if(PROTOCOL)begin
        if(scenario==1)start_op_i=3;
        if(scenario==2)start_param_i=3;
        if(scenario==3)start_context_len_i=256;
        if(scenario==4)start_message_len_i=65535;
        if(scenario==5)start_signature_len_i=16'(sig_len-1);
      end
      start_valid_i=1;start_cycle=cycles;
      case_input_start=input_words;case_key_start=key_words;case_signature_start=signature_words;reset_happened=0;
      #1;if(!start_ready_o)$fatal(1,"Main not ready");
      $fdisplay(output_file,"J %0d %0d %0d %0d %0d",serial,op,original,level,id);
      @(negedge clk);start_valid_i=0;
      // Deliberate garbage on the nonselected stream must never gain credit.
      sign_input_valid_i=op!=1;verify_input_valid_i=op!=2;
      fork:transaction
        begin
          for(int frame=0;frame<frame_count;frame++)if(!done_valid_o)feed_frame(frame,lengths[frame]);
          watchdog=0;while(!done_valid_o)begin
            @(negedge clk);if(watchdog++>5000000)$fatal(1,"Main timeout case%0d op%0d state%0d",current,op,dut.core.state);
          end
        end
        begin
          if(!PROTOCOL || abort_phase<0)wait(1'b0);
          else begin
            while(!reset_point())@(negedge clk);
            @(negedge clk);$fdisplay(output_file,"X %0d",abort_phase);
            rst=1;start_valid_i=0;sign_input_valid_i=0;verify_input_valid_i=0;reset_happened=1;
          end
        end
        begin:fatal_drain_injection
          if(!FATAL_DRAIN_PROBE || op!=0)wait(1'b0);
          else begin
            case(FATAL_DRAIN_PHASE)
              0:wait(dut.core.keygen_controller.state==dut.core.keygen_controller.SK_FIELD_STREAM &&
                dut.core.datapath.process_path.pack_output_valid && key_valid_o);
              1:wait(dut.core.keygen_controller.state==dut.core.keygen_controller.SEED_WAIT && dut.core.response.raw.output_valid);
              2:wait(dut.core.keygen_controller.state==dut.core.keygen_controller.S1_RUN && dut.core.datapath.polynomial.core_busy);
              3:wait(dut.core.keygen_controller.state==dut.core.keygen_controller.ROUND_RUN && dut.core.datapath.process_path.produced_r>4);
              4:wait(dut.core.keygen_controller.input_stage_valid_r && !dut.core.keygen_controller.input_stage_pop);
              5:wait(dut.core.datapath.process_path.packer.format_count_r==2 &&
                dut.core.datapath.process_path.pack_output_valid && !dut.core.datapath.process_path.pack_output_ready);
              default:$fatal(1,"Invalid fatal-drain phase");
            endcase
            @(negedge clk);
            fatal_drain_active=1;
            force dut.core.datapath.hash_sampler.decoder.fault_o=1'b1;
            #1;
            if(!fault_o || key_valid_o || signature_valid_o || done_valid_o || start_ready_o)
              $fatal(1,"Injected fatal fault failed immediate public quarantine");
            if(dut.core.request.poly_process.packed_ready !== dut.core.k_request.poly_process.packed_ready)
              $fatal(1,"Fatal packer lost selected internal drain credit");
            begin
              request_t canceled;
              canceled=dut.core.request;
              if(canceled.sample.valid!==0 || canceled.sample.input_valid!==0 ||
                 canceled.raw.valid!==0 || canceled.raw.input_valid!==0 || canceled.ntt.valid!==0 ||
                 canceled.poly_process.valid!==0 || canceled.bank.command_valid!==0 || canceled.bank.write_valid!==0 ||
                 canceled.load.valid!==0 || canceled.load.input_valid!==0 || canceled.hint_encode.valid!==0 ||
                 canceled.hint_encode.feed_enable!==0 || canceled.hint_encode.cancel!==0 ||
                 canceled.hint_decode.valid!==0 || canceled.hint_decode.input_valid!==0)
                $fatal(1,"Fatal drain admitted another command/data request");
            end
            @(posedge clk);#1;
            if(dut.core.state!=dut.core.HALT || dut.core.owner_select_r!=0 || dut.core.request!=='0 ||
               key_valid_o || signature_valid_o || done_valid_o || start_ready_o)
              $fatal(1,"Fatal drain did not end at next-edge HALT");
            fatal_drain_checks++;
            @(negedge clk);rst=1;fatal_drain_active=0;release dut.core.datapath.hash_sampler.decoder.fault_o;
            reset_happened=1;
          end
        end
        begin
          if(!PROTOCOL || !busy_probe)wait(1'b0);
          else begin
            repeat(10)@(negedge clk);if(start_ready_o)$fatal(1,"Busy main accepted a new command");
            command_snapshot={start_op_i,start_param_i,start_id_i,start_seed_i,start_message_len_i,start_context_len_i,start_rnd_i,start_signature_len_i,start_internal_message_i};
            start_valid_i=1;start_op_i=3;start_param_i=3;start_id_i=~start_id_i;start_seed_i=~start_seed_i;start_rnd_i=~start_rnd_i;
            start_message_len_i=65535;start_context_len_i=256;start_signature_len_i=0;start_internal_message_i=~start_internal_message_i;
            @(negedge clk);if(start_ready_o)$fatal(1,"Main became ready during busy probe");start_valid_i=0;
            {start_op_i,start_param_i,start_id_i,start_seed_i,start_message_len_i,start_context_len_i,start_rnd_i,start_signature_len_i,start_internal_message_i}=command_snapshot;
            busy_checks++;wait(1'b0);
          end
        end
      join_any
      disable transaction;
      if(reset_happened)begin
        repeat(3)@(negedge clk);rst=0;abort_phase=-1;resets++;completed++;
        #1;if(!start_ready_o || busy_o || done_valid_o || !dut.core.response.idle)$fatal(1,"Main reset did not retire all owners");
        continue;
      end
      if(PROTOCOL && scenario>0 && (key_words!=case_key_start || signature_words!=case_signature_start ||
        sign_attempts_o!=0 || (scenario<=5 && input_words!=case_input_start)))$fatal(1,"Invalid main command/frame produced crypto output or input credit");
      if(done_id_o!=start_id_i || !dut.core.response.idle || start_ready_o || !busy_o)$fatal(1,"Main completion owner/retirement gate");
      $fdisplay(output_file,"D %0d %0d %0d %0d %0d %0d %0d %0d",done_code_o,done_stage_o,done_detail_o,verify_accept_o,sign_attempts_o,sign_rejections_o,sign_next_nonce_o,cycles-start_cycle);
      if(!PROTOCOL)begin
        if(done_code_o!=0 || done_stage_o!=0 || done_detail_o!=0)$fatal(1,"Cannot publish errored crypto output");
        if(op==0 && (plain_pk.len()!=2*(level==0?1312:level==1?1952:2592) ||
          plain_sk.len()!=2*(level==0?2560:level==1?4032:4896)))$fatal(1,"Incomplete plain key output");
        if(op==1 && plain_sig.len()!=2*(level==0?2420:level==1?3309:4627))$fatal(1,"Incomplete plain signature output");
        case(op)0:plain_operation="keygen";1:plain_operation="sign";default:plain_operation="verify";endcase
        if(completed>0)$fdisplay(text_file,"");
        $fdisplay(text_file,"[%s] level=%0d operation=%s",case_label,level==0?2:level==1?3:5,plain_operation);
        if(op==0)begin $fdisplay(text_file,"pk = %s",plain_pk);$fdisplay(text_file,"sk = %s",plain_sk);end
        else if(op==1)$fdisplay(text_file,"signature = %s",plain_sig);
        else if(verify_accept_o)$fdisplay(text_file,"valid = true");
        else $fdisplay(text_file,"valid = false");
        $fflush(text_file);
      end
      report_keygen_schedule();
      saved_completion={done_code_o,done_stage_o,done_detail_o,verify_accept_o,done_id_o,sign_attempts_o,sign_rejections_o,sign_next_nonce_o};
      repeat(3)begin
        @(negedge clk);if(!done_valid_o || {done_code_o,done_stage_o,done_detail_o,verify_accept_o,done_id_o,sign_attempts_o,sign_rejections_o,sign_next_nonce_o}!==saved_completion)
          $fatal(1,"Main completion changed under backpressure");
      end
      sign_input_valid_i=0;verify_input_valid_i=0;done_ready_i=1;@(negedge clk);done_ready_i=0;completed++;
      $display("COMPACT_MAIN_CASE_PASS:case%0d op%0d level%0d cycles%0d",serial,op,level,cycles-start_cycle-4);
    end
    if(PROTOCOL && (resets!=12 || busy_checks!=44 || completed!=88))$fatal(1,"Incomplete main protocol campaign");
    if(FATAL_DRAIN_PROBE)begin
      if(fatal_drain_checks!=3)$fatal(1,"Incomplete fatal packer injection campaign");
      $display("FATAL_DRAIN_INJECTION_PASS:phase%0d/%0d hard faults;instant quarantine,next-edge HALT,canceled commands and reset recovery",FATAL_DRAIN_PHASE,fatal_drain_checks);
    end
    $fdisplay(output_file,"F %0d",completed);$fclose(input_file);$fclose(output_file);
    if(text_file)$fclose(text_file);
    $display("LIGHTHD_MAIN_CAPTURE_PASS:%0d commands/%0d input words/%0d key words/%0d signature words;independent full comparison required",completed,input_words,key_words,signature_words);$finish;
  end
  generate if(MUX_PROOF_ONLY && CYCLE_REFERENCE)begin:mux_control_proof
    request_t probe_k,probe_s,probe_v;
    logic [2:0] probe_owner;
    logic probe_fault;
    logic [5:0] probe_verify_state;
    logic [6:0] probe_sign_state;
    logic [5:0] probe_keygen_state;
    logic [3:0] probe_raw_count;logic [2:0] probe_tr_count;
    int checked=0;
    request_t candidate_record,reference_record,selected_record;
    function automatic logic control_value(input int value);
      case(value)0:return 1'b0;1:return 1'b1;2:return 1'bx;default:return 1'bz;endcase
    endfunction
    initial begin
      clk=0;rst=1;
      for(int owner=0;owner<64;owner++)for(int f=0;f<4;f++)for(int pattern=0;pattern<4;pattern++)begin
        for(int bitnum=0;bitnum<3;bitnum++)probe_owner[bitnum]=control_value((owner>>(2*bitnum))&3);
        probe_fault=control_value(f);
        case(pattern)
          0:begin probe_k='0;probe_s='1;probe_v='x;end
          1:begin probe_k='x;probe_s='0;probe_v='1;end
          2:begin probe_k='1;probe_s='x;probe_v='0;end
          default:for(int b=0;b<$bits(request_t);b++)begin
            probe_k[b]=b%19==0?1'bx:1'($urandom);
            probe_s[b]=b%23==0?1'bx:1'($urandom);
            probe_v[b]=b%29==0?1'bx:1'($urandom);
          end
        endcase
        force dut.core.owner_select_r=probe_owner;
        force mux_reference.reference_dut.core.owner_select_r=probe_owner;
        force dut.core.fault_o=probe_fault;
        force mux_reference.reference_dut.core.fault_o=probe_fault;
        force dut.core.k_request=probe_k;force mux_reference.reference_dut.core.k_request=probe_k;
        force dut.core.s_request=probe_s;force mux_reference.reference_dut.core.s_request=probe_s;
        force dut.core.v_request=probe_v;force mux_reference.reference_dut.core.v_request=probe_v;
        #1ps;
        candidate_record=dut.core.request;reference_record=mux_reference.reference_dut.core.request;
        selected_record='0;
        if(probe_owner[0])selected_record=probe_k;
        else if(probe_owner[1])selected_record=probe_s;
        else if(probe_owner[2])selected_record=probe_v;
        if(ALLOW_FATAL_PACK_DRAIN)begin
          if(dut.core.request.poly_process.packed_ready !== selected_record.poly_process.packed_ready)
            $fatal(1,"Packer drain credit changed selected-owner priority");
          // On a known fatal fault,all data/credits retain selected ownership;
          // every admission valid and hint feed/cancel must instead be zero.
          if(probe_fault===1'b1)begin
            reference_record=selected_record;
            reference_record.sample.valid=0;reference_record.sample.input_valid=0;
            reference_record.raw.valid=0;reference_record.raw.input_valid=0;
            reference_record.ntt.valid=0;reference_record.poly_process.valid=0;
            reference_record.bank.command_valid=0;reference_record.bank.write_valid=0;
            reference_record.load.valid=0;reference_record.load.input_valid=0;
            reference_record.hint_encode.valid=0;reference_record.hint_encode.feed_enable=0;reference_record.hint_encode.cancel=0;
            reference_record.hint_decode.valid=0;reference_record.hint_decode.input_valid=0;
          end
        end
        if(candidate_record !== reference_record)
          $fatal(1,"Priority/quarantine/payload mismatch owner%h fault%b pattern%0d",probe_owner,probe_fault,pattern);
        if(probe_fault===1'b1 && (key_valid_o!==0 || signature_valid_o!==0 || done_valid_o!==0 || start_ready_o!==0))
          $fatal(1,"Fatal fault exposed a public output or command credit");
        checked++;
      end
      $display("ROOT_MUX_CONTROL_PROOF_PASS:%0d full-record comparisons;all4-state owner/fault patterns,priority and X-payload masking",checked);
      // Compare ACTUAL old/new producer activation for every four-state
      // encoding. The only consumer is a procedural if: X never activates it.
      for(int encoding=0;encoding<4096;encoding++)begin
        for(int b=0;b<6;b++)probe_verify_state[b]=control_value((encoding>>(2*b))&3);
        force dut.core.verify_controller.state=probe_verify_state;
        force mux_reference.reference_dut.core.verify_controller.state=probe_verify_state;
        #1ps;
        if((dut.core.verify_controller.producer_enabled===1'b1) !==
           (mux_reference.reference_dut.core.verify_controller.producer_enabled===1'b1))
          $fatal(1,"Verify producer activation changed state%b",probe_verify_state);
      end
      $display("VERIFY_PHASE_ACTIVATION_PROOF_PASS:4096 actual old/new four-state encodings");
      for(int encoding=0;encoding<16384;encoding++)begin
        for(int b=0;b<7;b++)probe_sign_state[b]=control_value((encoding>>(2*b))&3);
        force dut.core.sign_controller.state=probe_sign_state;
        force mux_reference.reference_dut.core.sign_controller.state=probe_sign_state;
        #1ps;
        if((dut.core.sign_controller.producer_enabled===1'b1) !==
           (mux_reference.reference_dut.core.sign_controller.producer_enabled===1'b1))
          $fatal(1,"Sign producer activation changed state%b",probe_sign_state);
      end
      $display("SIGN_PHASE_ACTIVATION_PROOF_PASS:16384 actual old/new four-state encodings");
      release dut.core.k_request;release mux_reference.reference_dut.core.k_request;
      release dut.core.s_request;release mux_reference.reference_dut.core.s_request;
      release dut.core.v_request;release mux_reference.reference_dut.core.v_request;
      force dut.core.owner_select_r=3'd0;force mux_reference.reference_dut.core.owner_select_r=3'd0;
      force dut.core.fault_o=1'b0;force mux_reference.reference_dut.core.fault_o=1'b0;
      force dut.core.keygen_controller.state=probe_keygen_state;
      force mux_reference.reference_dut.core.keygen_controller.state=probe_keygen_state;
      force dut.core.keygen_controller.raw_count_r=probe_raw_count;
      force mux_reference.reference_dut.core.keygen_controller.raw_count_r=probe_raw_count;
      force dut.core.keygen_controller.tr_count_r=probe_tr_count;
      force mux_reference.reference_dut.core.keygen_controller.tr_count_r=probe_tr_count;
      for(int encoding=0;encoding<4096;encoding++)begin
        for(int b=0;b<6;b++)probe_keygen_state[b]=control_value((encoding>>(2*b))&3);
        for(int pattern=0;pattern<128;pattern++)begin
          probe_raw_count=4'(pattern&15);probe_tr_count=3'(pattern>>4);
          #1ps;
          if(dut.core.keygen_controller.producer_enabled !== mux_reference.reference_dut.core.keygen_controller.producer_enabled)
            $fatal(1,"KeyGen producer phase changed state%b",probe_keygen_state);
          if(dut.core.keygen_controller.material_write_word !== mux_reference.reference_dut.core.keygen_controller.material_write_word)
            $fatal(1,"KeyGen material write address changed state%b",probe_keygen_state);
          if(dut.core.keygen_controller.service_o !== mux_reference.reference_dut.core.keygen_controller.service_o)
            $fatal(1,"KeyGen request metadata changed state%b counters%0d",probe_keygen_state,pattern);
        end
      end
      $display("KEYGEN_PHASE_ACTIVATION_PROOF_PASS:524288 actual old/new four-state phase/address/full-request cases");
      $finish;
    end
  end endgenerate
  initial begin #(64'd10000000000);$fatal(1,"Main global watchdog");end
endmodule


// Focused timing-independent equivalence against the checkpoint preparer.
module tb_sampler_prepare_timing;
  logic clk=0,rst=1,accept=0,mode_a=0,wide=0;
  logic [127:0] word_data;logic [4:0] bytes_count,mask_bits;
  logic [18:0] mask_carry;logic [15:0] a_carry;logic [1:0] a_bytes;
  wire [1:0] ready;
  typedef struct packed {
    logic [1:0][3:0][19:0] mf;logic [1:0][3:0] mv;
    logic [1:0][18:0] mc;logic [1:0][4:0] mb;
    logic [1:0][2:0][22:0] af;logic [1:0][1:0] al;
    logic [1:0][15:0] ac;logic [1:0][1:0] ab;
  } prepared_t;
  wire prepared_t out_value[2];
  sampler_input_prepare candidate(.clk(clk),.rst(rst),.accept_i(accept),.word_i(word_data),.bytes_i(bytes_count),
    .mask_carry_i(mask_carry),.mask_bits_i(mask_bits),.wide_i(wide),.mode_a_i(mode_a),.a_carry_i(a_carry),.a_bytes_i(a_bytes),
    .ready_o(ready[0]),.mask_fields_o(out_value[0].mf),.mask_valid_o(out_value[0].mv),.mask_carry_o(out_value[0].mc),.mask_bits_o(out_value[0].mb),
    .a_fields_o(out_value[0].af),.a_lanes_o(out_value[0].al),.a_carry_o(out_value[0].ac),.a_bytes_o(out_value[0].ab));
  sampler_input_prepare_reference reference_unit(.clk(clk),.rst(rst),.accept_i(accept),.word_i(word_data),.bytes_i(bytes_count),
    .mask_carry_i(mask_carry),.mask_bits_i(mask_bits),.wide_i(wide),.mode_a_i(mode_a),.a_carry_i(a_carry),.a_bytes_i(a_bytes),
    .ready_o(ready[1]),.mask_fields_o(out_value[1].mf),.mask_valid_o(out_value[1].mv),.mask_carry_o(out_value[1].mc),.mask_bits_o(out_value[1].mb),
    .a_fields_o(out_value[1].af),.a_lanes_o(out_value[1].al),.a_carry_o(out_value[1].ac),.a_bytes_o(out_value[1].ab));
  always #5 clk=~clk;
  int checks=0,early=0;
  task automatic check_word;
    prepared_t captured;bit seen;int wait_clocks;
    accept=1;@(negedge clk);accept=0;seen=0;wait_clocks=0;
    while(!ready[1])begin
      if(ready[0] && !seen)begin captured=out_value[0];seen=1;early++;end
      @(negedge clk);if(wait_clocks++>8)$fatal(1,"Preparation timeout");
    end
    if(!ready[0])$fatal(1,"Candidate slower than checkpoint");
    if(mode_a)begin
      if({out_value[0].af,out_value[0].al,out_value[0].ac,out_value[0].ab}!=={out_value[1].af,out_value[1].al,out_value[1].ac,out_value[1].ab})
        $fatal(1,"Matrix preparation mismatch bytes%0d carry%0d",bytes_count,a_bytes);
      if(seen && {captured.af,captured.al,captured.ac,captured.ab}!=={out_value[1].af,out_value[1].al,out_value[1].ac,out_value[1].ab})
        $fatal(1,"Early matrix fields were stale");
    end else if({out_value[0].mf,out_value[0].mv,out_value[0].mc,out_value[0].mb}!=={out_value[1].mf,out_value[1].mv,out_value[1].mc,out_value[1].mb})
      $fatal(1,"Mask preparation mismatch");
    checks++;@(negedge clk);
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<32768;test++)begin
      mode_a=1;bytes_count=5'(1+test%16);a_bytes=2'((test/16)%3);
      word_data={$urandom,$urandom,$urandom,$urandom};a_carry=16'($urandom);mask_bits=0;mask_carry=0;wide=test%2;
      check_word();
    end
    for(int test=0;test<16384;test++)begin
      mode_a=0;bytes_count=5'(1+test%16);wide=(test/16)%2;mask_bits=5'((test/32)%(wide?20:18));
      mask_carry=19'($urandom)&((19'd1<<mask_bits)-1);word_data={$urandom,$urandom,$urandom,$urandom};a_bytes=0;a_carry=0;
      check_word();
    end
    // Restart each in-flight phase with the other mode; reset also cancels ready.
    for(int delay_cycles=0;delay_cycles<4;delay_cycles++)begin
      mode_a=1;accept=1;@(negedge clk);accept=0;repeat(delay_cycles)@(negedge clk);
      mode_a=0;check_word();rst=1;@(negedge clk);rst=0;
      if(ready!==0)$fatal(1,"Reset retained preparation ready");
    end
    $display("SAMPLER_PREPARE_EQUIVALENCE_PASS checks=%0d early=%0d",checks,early);$finish;
  end
endmodule
