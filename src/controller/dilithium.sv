// Compact main controller:one operation owner and ONE physical datapath.
// Command data is latched directly by the selected child;no seed/context copies.
`default_nettype none
module dilithium (
  output logic  key_valid_o,
  input wire logic  key_ready_i,
  output logic [63:0] key_data_o,
  output logic [3:0] key_bytes_o,
  output logic  key_type_o,
  output logic  key_last_o,
  output logic [9:0] key_index_o,
  output logic [15:0] key_id_o,
  input wire logic  clk,
  input wire logic  rst,
  input wire logic  start_valid_i,
  output logic  start_ready_o,
  output logic  busy_o,
  input wire logic [1:0] start_op_i,
  input wire logic [1:0] start_param_i,
  input wire logic [15:0] start_id_i,
  input wire logic [255:0] start_seed_i,
  input wire logic [15:0] start_message_len_i,
  input wire logic [8:0] start_context_len_i,
  input tri0 start_internal_message_i, // 0:message+context; 1:already formatted message
  input wire logic [255:0] start_rnd_i,
  input wire logic  sign_input_valid_i,
  output logic  sign_input_ready_o,
  input wire logic [63:0] sign_input_data_i,
  input wire logic [3:0] sign_input_bytes_i,
  input wire logic [15:0] sign_input_index_i,
  input wire logic  sign_input_last_i,
  input wire logic [15:0] start_signature_len_i,
  input wire logic  verify_input_valid_i,
  output logic  verify_input_ready_o,
  input wire logic [63:0] verify_input_data_i,
  input wire logic [3:0] verify_input_bytes_i,
  input wire logic [15:0] verify_input_index_i,
  input wire logic  verify_input_last_i,
  output logic  verify_accept_o,
  output logic  signature_valid_o,
  input wire logic  signature_ready_i,
  output logic [63:0] signature_data_o,
  output logic [3:0] signature_bytes_o,
  output logic [9:0] signature_index_o,
  output logic  signature_last_o,
  output logic [15:0] signature_id_o,
  output logic [2:0] done_stage_o,
  output logic [2:0] done_detail_o,
  output logic [16:0] sign_attempts_o,
  output logic [16:0] sign_rejections_o,
  output logic [16:0] sign_next_nonce_o,
  output logic  done_valid_o,
  input wire logic  done_ready_i,
  output logic [2:0] done_code_o,
  output logic [15:0] done_id_o,
  output logic  fault_o
);

  import dilithium_pkg::*;
  typedef enum logic [2:0] {IDLE,EXECUTE,RETIRE,ERROR_REPORT,HALT} state_e;
  state_e state;
  logic [1:0] op_r;logic [15:0] id_r;logic [2:0] error_code_r;
  logic k_ready,s_ready,v_ready,k_done,s_done,v_done,k_fault,s_fault,v_fault,physical_fault;
  logic k_key_valid,s_signature_valid,v_accept,k_take,s_take,v_take;
  logic [2:0] k_code,s_code,v_code,s_stage,s_detail,v_stage,v_detail,child_code,child_stage,child_detail;
  logic [15:0] k_id,s_id,v_id,child_id;logic child_done,child_ready,command_fire,bad_opcode,bad_command;
  logic selected_k,selected_s,selected_v;logic [17:0] message_total;
  logic [16:0] attempts,rejections,next_nonce;
  request_t k_request,s_request,v_request,request;response_t response;
  logic [2:0] owner_select_r,owner_select_next;
  assign selected_k=owner_select_r[0];assign selected_s=owner_select_r[1];assign selected_v=owner_select_r[2];
  // Anticipate the same next-state decode,avoiding a wide live RETIRE fanout.
  // This adds no public or engine cycle;fault quarantine remains unchanged.
  always_comb begin
    owner_select_next=0;
    if(state==IDLE && command_fire && !bad_opcode && !bad_command)
      case(start_op_i) 0:owner_select_next=1;1:owner_select_next=2;2:owner_select_next=4;default:begin end endcase
    else if(state==EXECUTE || (state==RETIRE && !(child_ready && response.idle)))
      case(op_r) 0:owner_select_next=1;1:owner_select_next=2;2:owner_select_next=4;default:begin end endcase
    if(fault_o || (state==EXECUTE && child_done && child_id!=id_r))owner_select_next=0;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)owner_select_r<=0;else owner_select_r<=owner_select_next;
  end
  // synthesis translate_off
  always @(posedge clk)if(!rst && owner_select_r!=={
    ((state==EXECUTE || state==RETIRE) && op_r==2),
    ((state==EXECUTE || state==RETIRE) && op_r==1),
    ((state==EXECUTE || state==RETIRE) && op_r==0)})
      $fatal(1,"Registered main owner differs from original state decode");
  // synthesis translate_on
  assign message_total=(start_internal_message_i?18'd64:18'd66+18'(start_context_len_i))+18'(start_message_len_i);
  assign bad_opcode=start_op_i==3;
  assign bad_command=start_param_i==3 || (start_op_i!=0 && (start_context_len_i>255 || (start_internal_message_i && start_context_len_i!=0) || message_total>65535));
  assign command_fire=start_valid_i && start_ready_o;
  assign fault_o=physical_fault || k_fault || s_fault || v_fault || state==HALT;
  assign start_ready_o=!rst && !fault_o && state==IDLE && response.idle && k_ready && s_ready && v_ready;
  assign busy_o=state!=IDLE;
  assign done_valid_o=!rst && !fault_o && (state==ERROR_REPORT || (state==EXECUTE && child_done && child_id==id_r && response.idle));
  assign done_id_o=id_r;
  assign done_code_o=state==ERROR_REPORT?error_code_r:state==EXECUTE?child_code:3'd0;
  assign done_stage_o=state==EXECUTE?child_stage:3'd0;
  assign done_detail_o=state==EXECUTE?child_detail:3'd0;
  assign verify_accept_o=selected_v && done_valid_o && done_code_o==0 && v_accept;
  assign key_valid_o=!rst && !fault_o && state==EXECUTE && selected_k && k_key_valid;
  assign signature_valid_o=!rst && !fault_o && state==EXECUTE && selected_s && s_signature_valid;
  assign sign_attempts_o=selected_s?attempts:17'd0;
  assign sign_rejections_o=selected_s?rejections:17'd0;
  assign sign_next_nonce_o=selected_s?next_nonce:17'd0;
  assign k_take=selected_k && state==EXECUTE && done_valid_o && done_ready_i;
  assign s_take=selected_s && state==EXECUTE && done_valid_o && done_ready_i;
  assign v_take=selected_v && state==EXECUTE && done_valid_o && done_ready_i;
  keygen #(.PIPELINE_INPUT(1),.LOCAL_CONTROL(1)) keygen_controller(
    .clk(clk),.rst(rst),.start_valid_i(command_fire && !bad_opcode && !bad_command && start_op_i==0),
    .start_ready_o(k_ready),.start_param_i(start_param_i),.start_id_i(start_id_i),.start_seed_i(start_seed_i),
    .key_valid_o(k_key_valid),.key_ready_i(selected_k && state==EXECUTE && key_ready_i),.key_data_o(key_data_o),
    .key_bytes_o(key_bytes_o),.key_type_o(key_type_o),.key_last_o(key_last_o),.key_index_o(key_index_o),.key_id_o(key_id_o),
    .done_valid_o(k_done),.done_ready_i(k_take),.done_code_o(k_code),.done_id_o(k_id),.fault_o(k_fault),
    .service_o(k_request),.service_i(response));
  sign #(.LOCAL_CONTROL(1),.PIPELINE_STORE(1)) sign_controller(
    .clk(clk),.rst(rst),.start_valid_i(command_fire && !bad_opcode && !bad_command && start_op_i==1),
    .start_ready_o(s_ready),.busy_o(),.fault_o(s_fault),.start_param_i(start_param_i),.start_id_i(start_id_i),
    .start_message_len_i(start_message_len_i),.start_context_len_i(start_context_len_i),.start_internal_message_i(start_internal_message_i),.start_rnd_i(start_rnd_i),
    .input_valid_i(state==EXECUTE && selected_s && sign_input_valid_i),.input_ready_o(sign_input_ready_o),
    .input_data_i(sign_input_data_i),.input_bytes_i(sign_input_bytes_i),.input_index_i(sign_input_index_i),.input_last_i(sign_input_last_i),
    .signature_valid_o(s_signature_valid),.signature_ready_i(selected_s && state==EXECUTE && signature_ready_i),
    .signature_data_o(signature_data_o),.signature_bytes_o(signature_bytes_o),.signature_index_o(signature_index_o),
    .signature_last_o(signature_last_o),.signature_id_o(signature_id_o),
    .done_valid_o(s_done),.done_ready_i(s_take),.done_code_o(s_code),.done_stage_o(s_stage),.done_detail_o(s_detail),.done_id_o(s_id),
    .attempts_o(attempts),.rejections_o(rejections),.next_nonce_o(next_nonce),.service_o(s_request),.service_i(response));
  verify #(.LOCAL_CONTROL(1)) verify_controller(
    .clk(clk),.rst(rst),.start_valid_i(command_fire && !bad_opcode && !bad_command && start_op_i==2),
    .start_ready_o(v_ready),.busy_o(),.fault_o(v_fault),.start_param_i(start_param_i),.start_id_i(start_id_i),
    .start_message_len_i(start_message_len_i),.start_context_len_i(start_context_len_i),.start_internal_message_i(start_internal_message_i),.start_signature_len_i(start_signature_len_i),
    .input_valid_i(state==EXECUTE && selected_v && verify_input_valid_i),.input_ready_o(verify_input_ready_o),
    .input_data_i(verify_input_data_i),.input_bytes_i(verify_input_bytes_i),.input_index_i(verify_input_index_i),.input_last_i(verify_input_last_i),
    .done_valid_o(v_done),.done_ready_i(v_take),.done_code_o(v_code),.done_stage_o(v_stage),.done_detail_o(v_detail),
    .done_id_o(v_id),.done_accept_o(v_accept),.service_o(v_request),.service_i(response));
  datapath datapath(.clk(clk),.rst(rst),.service_i(request),.service_o(response),.fault_o(physical_fault));
  always_comb begin
    request='0;child_done=0;child_ready=0;child_code=0;child_stage=0;child_detail=0;child_id=id_r;
    case(op_r)
      0:begin child_done=k_done;child_ready=k_ready;child_code=k_code;child_id=k_id;end
      1:begin child_done=s_done;child_ready=s_ready;child_code=s_code;child_stage=s_stage;child_detail=s_detail;child_id=s_id;end
      2:begin child_done=v_done;child_ready=v_ready;child_code=v_code;child_stage=v_stage;child_detail=v_detail;child_id=v_id;end
      default:begin end
    endcase
    if(selected_k)request=k_request;else if(selected_s)request=s_request;else if(selected_v)request=v_request;
    // Quarantine gates admission,not the wide inactive payload/retirement bus.
    // Existing operations may retire internally on the fatal edge;public
    // outputs suppress immediately and owner_select_r clears at next-edge HALT.
    // No command,input beat or host RAM write can be admitted after a fault.
    if(fault_o)begin
      request.sample.valid=0;request.sample.input_valid=0;
      request.raw.valid=0;request.raw.input_valid=0;
      request.ntt.valid=0;request.poly_process.valid=0;
      request.bank.command_valid=0;request.bank.write_valid=0;
      request.load.valid=0;request.load.input_valid=0;
      request.hint_encode.valid=0;request.hint_encode.feed_enable=0;request.hint_encode.cancel=0;
      request.hint_decode.valid=0;request.hint_decode.input_valid=0;
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin state<=IDLE;op_r<=0;id_r<=0;error_code_r<=0;end
    else begin
      case(state)
        IDLE:if(command_fire)begin
          op_r<=start_op_i;id_r<=start_id_i;error_code_r<=bad_opcode?3'd2:3'd1;
          state<=bad_opcode || bad_command?ERROR_REPORT:EXECUTE;
        end
        EXECUTE:if(done_valid_o && done_ready_i)state<=RETIRE;
        RETIRE:if(child_ready && response.idle)state<=IDLE;
        ERROR_REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:state<=HALT;
      endcase
      if(fault_o || (state==EXECUTE && child_done && child_id!=id_r))state<=HALT;
    end
  end
endmodule
`default_nettype wire

