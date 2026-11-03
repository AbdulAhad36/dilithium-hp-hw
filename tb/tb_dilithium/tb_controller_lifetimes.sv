`timescale 1ns/1ps
module tb_controller_lifetimes #(parameter bit DIAGNOSTIC=1,PROTOCOL=0);
  import dilithium_pkg::*;
  tb_main #(.DIAGNOSTIC(DIAGNOSTIC),.PROTOCOL(PROTOCOL)) mainbench();
  `define S mainbench.dut.core.sign_controller
  `define V mainbench.dut.core.verify_controller
  int cycles=0,sign_completions=0,verify_completions=0,digests=0,attempt_contexts=0;
  logic s_ready,s_busy,s_fault,s_input_ready,s_sig_valid,s_sig_last,s_done;
  logic [63:0] s_sig_data;logic [3:0] s_sig_bytes;logic [9:0] s_sig_index;
  logic [15:0] s_sig_id,s_done_id;logic [2:0] s_code,s_stage,s_detail;
  logic [16:0] s_attempts,s_rejections,s_nonce;request_t s_service;
  logic v_ready,v_busy,v_fault,v_input_ready,v_done,v_accept;
  logic [15:0] v_done_id;logic [2:0] v_code,v_stage,v_detail;request_t v_service;
  function automatic request_t qualified(input request_t a);
    request_t q;q='0;
    if(a.sample.valid)q.sample=a.sample;
    q.sample.input_valid=a.sample.input_valid;q.sample.input_data=a.sample.input_valid?a.sample.input_data:64'd0;
    q.sample.done_ready=a.sample.done_ready;
    if(a.raw.valid)q.raw=a.raw;
    q.raw.input_valid=a.raw.input_valid;q.raw.input_data=a.raw.input_valid?a.raw.input_data:64'd0;
    q.raw.output_ready=a.raw.output_ready;q.raw.done_ready=a.raw.done_ready;
    if(a.ntt.valid)q.ntt=a.ntt;q.ntt.done_ready=a.ntt.done_ready;
    if(a.poly_process.valid)q.poly_process=a.poly_process;
    q.poly_process.done_ready=a.poly_process.done_ready;q.poly_process.packed_ready=a.poly_process.packed_ready;q.poly_process.hint_ready=a.poly_process.hint_ready;
    q.bank.command_valid=a.bank.command_valid;q.bank.write_valid=a.bank.write_valid;
    q.bank.read_ready=a.bank.read_ready;q.bank.done_ready=a.bank.done_ready;
    for(int p=0;p<2;p++)begin
      if(a.bank.command_valid[p])begin
        q.bank.mask[p]=a.bank.mask[p];q.bank.write[p]=a.bank.write[p];
        for(int b=0;b<4;b++)if(a.bank.mask[p][b])begin
          q.bank.base[p][b]=a.bank.base[p][b];q.bank.words[p][b]=a.bank.words[p][b];q.bank.mode[p][b]=a.bank.mode[p][b];
        end
      end
      for(int b=0;b<4;b++)if(a.bank.write_valid[p][b])begin
        q.bank.write_data[p][b]=a.bank.write_data[p][b];q.bank.write_address[p][b]=a.bank.write_address[p][b];
      end
    end
    if(a.load.valid)q.load=a.load;
    q.load.input_valid=a.load.input_valid;
    q.load.input_data=a.load.input_valid?a.load.input_data:64'd0;
    q.load.input_index=a.load.input_valid?a.load.input_index:7'd0;
    q.load.input_bytes=a.load.input_valid?a.load.input_bytes:4'd0;
    q.load.input_last=a.load.input_valid && a.load.input_last;q.load.done_ready=a.load.done_ready;
    if(a.hint_encode.valid)q.hint_encode=a.hint_encode;
    q.hint_encode.cancel=a.hint_encode.cancel;q.hint_encode.feed_enable=a.hint_encode.feed_enable;
    if(a.hint_encode.feed_enable)q.hint_encode.row=a.hint_encode.row;
    q.hint_encode.output_ready=a.hint_encode.output_ready;q.hint_encode.done_ready=a.hint_encode.done_ready;
    if(a.hint_decode.valid)q.hint_decode=a.hint_decode;
    q.hint_decode.input_valid=a.hint_decode.input_valid;
    q.hint_decode.input_data=a.hint_decode.input_valid?a.hint_decode.input_data:64'd0;
    q.hint_decode.input_index=a.hint_decode.input_valid?a.hint_decode.input_index:4'd0;
    q.hint_decode.input_bytes=a.hint_decode.input_valid?a.hint_decode.input_bytes:4'd0;
    q.hint_decode.input_last=a.hint_decode.input_valid && a.hint_decode.input_last;
    q.hint_decode.output_ready=a.hint_decode.output_ready;q.hint_decode.done_ready=a.hint_decode.done_ready;
    return q;
  endfunction
  sign_c20_reference old_sign(.clk(`S.clk),
    .rst(`S.rst),
    .start_valid_i(`S.start_valid_i),
    .start_param_i(`S.start_param_i),
    .start_id_i(`S.start_id_i),
    .start_message_len_i(`S.start_message_len_i),
    .start_context_len_i(`S.start_context_len_i),
    .start_rnd_i(`S.start_rnd_i),
    .input_valid_i(`S.input_valid_i),
    .input_data_i(`S.input_data_i),
    .input_bytes_i(`S.input_bytes_i),
    .input_index_i(`S.input_index_i),
    .input_last_i(`S.input_last_i),
    .signature_ready_i(`S.signature_ready_i),
    .done_ready_i(`S.done_ready_i),
    .service_i(`S.service_i),
    .start_ready_o(s_ready),
    .busy_o(s_busy),
    .fault_o(s_fault),
    .input_ready_o(s_input_ready),
    .signature_valid_o(s_sig_valid),
    .signature_data_o(s_sig_data),
    .signature_bytes_o(s_sig_bytes),
    .signature_index_o(s_sig_index),
    .signature_last_o(s_sig_last),
    .signature_id_o(s_sig_id),
    .done_valid_o(s_done),
    .done_code_o(s_code),
    .done_stage_o(s_stage),
    .done_detail_o(s_detail),
    .done_id_o(s_done_id),
    .attempts_o(s_attempts),
    .rejections_o(s_rejections),
    .next_nonce_o(s_nonce),
    .service_o(s_service));
  verify_c20_reference old_verify(.clk(`V.clk),
    .rst(`V.rst),
    .start_valid_i(`V.start_valid_i),
    .start_param_i(`V.start_param_i),
    .start_id_i(`V.start_id_i),
    .start_message_len_i(`V.start_message_len_i),
    .start_signature_len_i(`V.start_signature_len_i),
    .start_context_len_i(`V.start_context_len_i),
    .input_valid_i(`V.input_valid_i),
    .input_data_i(`V.input_data_i),
    .input_bytes_i(`V.input_bytes_i),
    .input_index_i(`V.input_index_i),
    .input_last_i(`V.input_last_i),
    .done_ready_i(`V.done_ready_i),
    .service_i(`V.service_i),
    .start_ready_o(v_ready),
    .busy_o(v_busy),
    .fault_o(v_fault),
    .input_ready_o(v_input_ready),
    .done_valid_o(v_done),
    .done_id_o(v_done_id),
    .done_code_o(v_code),
    .done_stage_o(v_stage),
    .done_detail_o(v_detail),
    .done_accept_o(v_accept),
    .service_o(v_service));
  always @(negedge mainbench.clk)if(!mainbench.rst)begin
    cycles++;
    if({s_ready,s_busy,s_fault,s_input_ready,s_sig_valid,s_done,s_code,s_stage,s_detail,s_done_id,s_attempts,s_rejections,s_nonce}!==
       {`S.start_ready_o,`S.busy_o,`S.fault_o,`S.input_ready_o,`S.signature_valid_o,`S.done_valid_o,`S.done_code_o,`S.done_stage_o,`S.done_detail_o,`S.done_id_o,`S.attempts_o,`S.rejections_o,`S.next_nonce_o})
      $fatal(1,"Sign overlay changed control pins at cycle%0d",cycles);
    if(s_sig_valid && {s_sig_data,s_sig_bytes,s_sig_index,s_sig_last,s_sig_id}!==
       {`S.signature_data_o,`S.signature_bytes_o,`S.signature_index_o,`S.signature_last_o,`S.signature_id_o})
      $fatal(1,"Sign overlay changed a valid signature word");
    if({v_ready,v_busy,v_fault,v_input_ready,v_done,v_done_id,v_code,v_stage,v_detail,v_accept}!==
       {`V.start_ready_o,`V.busy_o,`V.fault_o,`V.input_ready_o,`V.done_valid_o,`V.done_id_o,`V.done_code_o,`V.done_stage_o,`V.done_detail_o,`V.done_accept_o})
      $fatal(1,"Verify overlay changed control pins at cycle%0d",cycles);
    if(qualified(s_service)!==qualified(`S.service_o))$fatal(1,"Sign overlay changed qualified engine requests at cycle%0d",cycles);
    if(qualified(v_service)!==qualified(`V.service_o))$fatal(1,"Verify overlay changed qualified engine requests at cycle%0d",cycles);
    if(`V.state==`V.CHASH_DRAIN && `V.format_finished_r && `V.raw_finished_r && `V.bank_finished_r)begin
      if(`V.digest_r!==old_verify.digest_r)$fatal(1,"Verify overlay changed completed512-bit digest");
      digests++;
    end
    if(`S.state==`S.ATTEMPT_BEGIN)begin
      if(`S.mu_r!==old_sign.mu_r || `S.mask_r!==old_sign.mask_r)$fatal(1,"Sign overlay changed retry hash context");
      attempt_contexts++;
    end
  end
  always @(posedge mainbench.clk)if(!mainbench.rst)begin
    if(s_done && `S.done_ready_i)sign_completions++;
    if(v_done && `V.done_ready_i)verify_completions++;
  end
  final begin
    if(sign_completions<3 || verify_completions<3 || digests<3 || attempt_contexts<3)$error("Incomplete lifetime probe");
    else $display("LIGHTHD_CONTROLLER_LIFETIME_CYCLE_PASS:%0dcycles/%0dSign/%0dVerify/%0dfull digests/%0dretry contexts;all controls/qualified requests/output exact",cycles,sign_completions,verify_completions,digests,attempt_contexts);
  end
endmodule
