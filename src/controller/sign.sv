// Compact pure-ML-DSA Sign. Final FIPS204 bytes,LightHD fixed bank lifetimes,
// one shared engine set,one rejection loop,and no polynomial-handle contexts.
`default_nettype none
module sign #(parameter bit LOCAL_CONTROL=0,parameter bit PIPELINE_STORE=0) (
  input wire logic clk,rst,start_valid_i,output logic start_ready_o,busy_o,fault_o,
  input wire logic [1:0] start_param_i,input wire logic [15:0] start_id_i,start_message_len_i,
  input wire logic [8:0] start_context_len_i,input tri0 start_internal_message_i,input wire logic [255:0] start_rnd_i,
  input wire logic input_valid_i,output logic input_ready_o,input wire logic [63:0] input_data_i,
  input wire logic [3:0] input_bytes_i,input wire logic [15:0] input_index_i,input wire logic input_last_i,
  output logic signature_valid_o,input wire logic signature_ready_i,output logic [63:0] signature_data_o,
  output logic [3:0] signature_bytes_o,output logic [9:0] signature_index_o,output logic signature_last_o,
  output logic [15:0] signature_id_o,
  output logic done_valid_o,input wire logic done_ready_i,output logic [2:0] done_code_o,done_stage_o,done_detail_o,
  output logic [15:0] done_id_o,output logic [16:0] attempts_o,rejections_o,next_nonce_o,
  output dilithium_pkg::request_t service_o,input var dilithium_pkg::response_t service_i
);
  import dilithium_pkg::*;
  typedef enum logic [6:0] {IDLE,KEY_CMD,KEY_WAIT,KEY_RETIRE,PREP_CMD,PREP_RUN,
    MU_CMD,MU_RUN,MASK_CMD,MASK_RUN,ATTEMPT_BEGIN,Y_READY,Y_NTT_CMD,Y_NTT_RUN,
    TERM_READY,TERM_CMD,TERM_RUN,INV_ROW_CMD,INV_ROW_RUN,DECOMP_CMD,DECOMP_RUN,
    W1_READ_CMD,CHASH_CMD,CHASH_RUN,CHASH_DRAIN,
    CHAL_CMD,CHAL_FEED,CHAL_WAIT,CHAL_NTT_CMD,CHAL_NTT_RUN,
    Z_MUL_CMD,Z_MUL_RUN,Z_INV_CMD,Z_INV_RUN,Z_NORM_CMD,Z_NORM_RUN,
    R0_MUL_CMD,R0_MUL_RUN,R0_INV_CMD,R0_INV_RUN,R0_SUB_CMD,R0_SUB_RUN,R0_NORM_CMD,R0_NORM_RUN,
    HINT_CMD,CT0_MUL_CMD,CT0_MUL_RUN,CT0_INV_CMD,CT0_INV_RUN,CT0_NORM_CMD,CT0_NORM_RUN,
    R0_ADD_CMD,R0_ADD_RUN,W1_HINT_READ_CMD,W1_HINT_LOAD_CMD,W1_HINT_FEED,W1_HINT_DRAIN,
    MHINT_CMD,MHINT_RUN,HINT_RESULT,SIG_PREFIX,SIG_Z_CMD,SIG_Z_STREAM,SIG_HINT,SIG_DRAIN,
    RETRY,DRAIN_ERROR,REPORT,HALT} state_e;
  typedef enum logic [1:0] {P_IDLE,P_CMD,P_FEED,P_WAIT} producer_e;
  typedef struct packed {logic matrix;logic [3:0] index,row,column,slot;} descriptor_t;
  state_e state;producer_e producer;
  descriptor_t descriptor_r[2],current;
  logic [1:0] level_r,section_r,batch_size_r,batch_done_r;
  logic [3:0] k_r,l_r,poly_r,row_r,column_r,y_next_r,a_row_r,a_column_r,a_write_r,a_read_r;
  logic [3:0] sample_word_r,challenge_word_r,header_word_r;
  logic selected_r,y_phase_r,y_credit_r,released_prev_r;
  logic [6:0] y_ready_r;logic [15:0] a_reserved_r,a_ready_r;
  logic [15:0] id_r,message_r,nonce_base_r;
  logic [8:0] context_r;logic internal_message_r;logic [255:0] rnd_r;
  // Fixed register lifetimes:tr->mu,and key||rnd->mask seed.
  logic [255:0] rho_store_r;
  logic [511:0] tr_mu_store_r,entropy_mask_store_r;
  logic header_write_valid;logic [3:0] header_write_index;logic [63:0] header_write_data;
  logic raw_take,raw_metadata_bad,raw_done_take,raw_service_active;
  logic [127:0] raw_store_data;
  logic [3:0] mu_write,mask_write,challenge_write;
  logic bad_start,signature_drained,error_drained,scrub_entropy;
  assign rnd_r=entropy_mask_store_r[511:256];
  logic [511:0] mu_r,mask_r,ctilde_r;
  assign mu_r=tr_mu_store_r;assign mask_r=entropy_mask_store_r;
  logic [7:0] memory_word_r,w1_words;
  logic [3:0] raw_count_r;logic [2:0] raw_expected,format_code_r;
  logic format_finished_r,raw_finished_r,bank_finished_r,load_finished_r,raw_core_r;
  logic [2:0] ctilde_beats;logic [3:0] ctilde_words;logic [15:0] ctilde_bytes;
  logic [9:0] w0_base,r0_base;
  logic [9:0] packed_row_offset;
  logic [3:0] ctilde_read_word;
  logic [63:0] ctilde_word;
  logic producer_enabled,ntt_wait,process_wait,raw_phase;
  logic [17:0] message_total;
  logic key_command_ready,key_done,key_input_ready;
  logic [2:0] key_code;logic [15:0] key_done_id;
  logic [255:0] rho,key;logic [511:0] tr;
  assign rho=rho_store_r;assign key=entropy_mask_store_r[255:0];assign tr=tr_mu_store_r;
  logic key_load_valid,key_load_input_valid,key_load_last,key_load_done_ready;
  logic [2:0] key_load_op;logic [1:0] key_load_level,key_load_bank;
  logic [9:0] key_load_base;logic [15:0] key_load_id;
  logic [63:0] key_load_data;logic [6:0] key_load_index;logic [3:0] key_load_bytes;
  logic format_command,format_ready,format_done,format_payload_ready,format_payload_valid;
  logic [1:0] format_op;logic [2:0] format_done_code;logic [15:0] format_done_id;
  logic format_request,format_mode,format_sampling,format_input_valid;
  logic [1:0] format_param;logic [15:0] format_id,format_length,format_output_length;
  logic [63:0] format_input_data;logic [3:0] format_input_bytes;
  logic [15:0] format_input_index;logic format_input_last;
  logic hint_command_ready,hint_result,hint_reject,hint_output_valid,hint_output_last,hint_done,hint_input_ready;
  logic [63:0] hint_output_data;logic [3:0] hint_output_bytes,hint_output_index;
  logic [15:0] hint_output_id;logic [1:0] hint_code;
  function automatic logic [3:0] next_ring(input logic [3:0] p,input logic [1:0] level);
    return p==(level==2?4'd15:4'd8)?4'd0:p+1'b1;
  endfunction
  function automatic descriptor_t y_descriptor(input logic [3:0] index);
    descriptor_t d;d='0;d.index=index;return d;
  endfunction
  function automatic descriptor_t matrix_descriptor(input logic [3:0] row,column,slot);
    descriptor_t d;d='0;d.matrix=1;d.row=row;d.column=column;d.slot=slot;return d;
  endfunction
  function automatic logic [15:0] descriptor_id(input descriptor_t d,input logic [15:0] id);
    return id+(d.matrix?{8'd4,d.row,d.column}:{8'd1,4'd0,d.index});
  endfunction
  function automatic logic descriptor_matches(input descriptor_t d,
    input logic [15:0] id,response_id);
    return id_add_matches(id,d.matrix?{8'd4,d.row,d.column}:{8'd1,4'd0,d.index},response_id);
  endfunction
  function automatic logic id_add_matches(input logic [15:0] base,offset,result);
    logic [15:0] carry_in,carry_out;
    // Check result==base+offset modulo2^16 without propagating a carry.
    // The proposed result determines each carry-in by XOR;each bit's local
    // operands/result independently determine its carry-out. Adjacent carries
    // must agree,and bit0 has no incoming carry. The final overflow is ignored.
    carry_in=base^offset^result;
    carry_out=(base&offset)|((base|offset)&~result);
    return !carry_in[0] && carry_in[15:1]==carry_out[14:0];
  endfunction
  logic [1:0][15:0] expected_sample_id_r;
  logic [1:0] expected_sample_valid_r,sample_match,sample_event_mask_r;
  logic sample_take,sample_event_r,sample_bad;
  logic challenge_take,challenge_event_r,challenge_consumed_r,challenge_bad;
  logic [15:0] expected_challenge_id_r;
  assign challenge_take=state==CHAL_WAIT && service_i.sample.done_valid && service_o.sample.done_ready;
  assign challenge_bad=service_i.sample.done_code!=0 || service_i.sample.done_id!=expected_challenge_id_r;
  assign sample_take=producer!=P_IDLE && service_i.sample.done_valid && service_o.sample.done_ready && state!=CHAL_WAIT;
  assign sample_bad=service_i.sample.done_code!=0 || sample_match==0 || sample_match==3 ||
    |(sample_match & batch_done_r) || (sample_event_r && |(sample_match & sample_event_mask_r));
  genvar completion_slot;
  generate for(completion_slot=0;completion_slot<2;completion_slot=completion_slot+1)begin:g_completion_match
    assign sample_match[completion_slot]=expected_sample_valid_r[completion_slot] &&
      completion_slot<int'(batch_size_r) && service_i.sample.done_id==expected_sample_id_r[completion_slot];
  end endgenerate
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin expected_sample_id_r<=0;expected_sample_valid_r<=0;sample_event_r<=0;sample_event_mask_r<=0;
      challenge_event_r<=0;challenge_consumed_r<=0;expected_challenge_id_r<=0;end
    else begin
      sample_event_r<=LOCAL_CONTROL && sample_take && !sample_bad;
      challenge_event_r<=LOCAL_CONTROL && challenge_take && !challenge_bad;
      if(challenge_take)challenge_consumed_r<=1;
      if(state==CHAL_CMD && service_i.sample.ready)begin
        expected_challenge_id_r<=service_o.sample.id;challenge_consumed_r<=0;
      end
      if(sample_take)sample_event_mask_r<=sample_match;
      if(producer==P_IDLE)expected_sample_valid_r<=0;
      if(producer==P_CMD && service_i.sample.ready)begin
        expected_sample_id_r[selected_r]<=service_o.sample.id;expected_sample_valid_r[selected_r]<=1;
      end
    end
  end
  assign current=descriptor_r[selected_r];
  assign ctilde_beats=level_r==0?2:level_r==1?3:4;
  assign ctilde_words=level_r==0?4:level_r==1?6:8;
  assign ctilde_bytes=level_r==0?32:level_r==1?48:64;
  assign w1_words=level_r==2?128:96;
  assign w0_base=row_r==7?10'd0:10'd576+{row_r,6'd0};
  assign r0_base=10'd512+{row_r,6'd0};
  assign message_total=(start_internal_message_i?18'd64:18'd66+18'(start_context_len_i))+18'(start_message_len_i);
  assign producer_enabled=state>=Y_READY && state<=DECOMP_RUN;
  assign raw_phase=state==MU_RUN || state==MASK_RUN || state==CHASH_RUN || state==CHASH_DRAIN;
  assign packed_row_offset={2'b0,row_r,4'b0}+(level_r==0?{3'b0,row_r,3'b0}:10'd0);
  assign ctilde_read_word=state==SIG_PREFIX?header_word_r:challenge_word_r;
  assign ctilde_word=ctilde_r[64*ctilde_read_word+:64];
  assign ntt_wait=state==PREP_RUN || state==Y_NTT_RUN || state==TERM_RUN || state==INV_ROW_RUN ||
    state==CHAL_NTT_RUN || state==Z_MUL_RUN || state==Z_INV_RUN || state==R0_MUL_RUN ||
    state==R0_INV_RUN || state==CT0_MUL_RUN || state==CT0_INV_RUN;
  assign process_wait=state==DECOMP_RUN || state==Z_NORM_RUN || state==R0_SUB_RUN || state==R0_NORM_RUN ||
    state==CT0_NORM_RUN || state==R0_ADD_RUN || state==MHINT_RUN || state==SIG_Z_STREAM;
  assign start_ready_o=!rst && state==IDLE && !fault_o && service_i.idle && key_command_ready && format_ready && hint_command_ready;
  assign busy_o=state!=IDLE;assign done_valid_o=!rst && state==REPORT && !fault_o;assign done_id_o=id_r;
  assign signature_id_o=id_r;
  assign input_ready_o=!rst && !fault_o && ((state==KEY_WAIT && key_input_ready) || (state==MU_RUN && format_payload_ready));
  sign_input #(.EXTERNAL_HEADER(1)) key_input(
    .clk(clk),.rst(rst),.command_valid_i(state==KEY_CMD),.command_ready_o(key_command_ready),
    .command_param_i(level_r),.command_id_i(id_r),
    .input_valid_i(input_valid_i && state==KEY_WAIT),.input_ready_o(key_input_ready),.input_data_i(input_data_i),
    .input_bytes_i(input_bytes_i),.input_index_i(input_index_i),.input_last_i(input_last_i),
    .done_valid_o(key_done),.done_ready_i(state==KEY_WAIT),.done_code_o(key_code),.done_id_o(key_done_id),
    .rho_o(),.key_o(),.tr_o(),
    .header_write_valid_o(header_write_valid),.header_write_index_o(header_write_index),.header_write_data_o(header_write_data),.poly_valid_o(),.poly_section_o(),.poly_index_o(),
    .load_valid_o(key_load_valid),.load_ready_i(service_i.load.ready),.load_op_o(key_load_op),
    .load_param_o(key_load_level),.load_bank_o(key_load_bank),.load_base_o(key_load_base),.load_id_o(key_load_id),
    .load_input_valid_o(key_load_input_valid),.load_input_ready_i(service_i.load.input_ready),
    .load_input_data_o(key_load_data),.load_input_index_o(key_load_index),.load_input_bytes_o(key_load_bytes),.load_input_last_o(key_load_last),
    .load_done_valid_i(service_i.load.done_valid),.load_done_ready_o(key_load_done_ready),
    .load_done_code_i(service_i.load.done_code),.load_done_id_i(service_i.load.done_id));
  assign format_op=state==MU_CMD || state==MU_RUN?0:state==MASK_CMD || state==MASK_RUN?1:2;
  assign format_command=state==MU_CMD || state==MASK_CMD || state==CHASH_CMD;
  assign raw_take=service_i.raw.output_valid && service_o.raw.output_ready;
  assign raw_metadata_bad=service_i.raw.output_id!=format_id ||
    service_i.raw.output_core!=raw_core_r || service_i.raw.output_bytes!=16;
  assign raw_done_take=service_i.raw.done_valid && service_o.raw.done_ready;
  assign bad_start=start_param_i==3 || start_context_len_i>255 ||
    (start_internal_message_i && start_context_len_i!=0) || message_total>65535;
  assign signature_drained=service_i.idle && hint_command_ready;
  assign error_drained=signature_drained && key_command_ready && format_ready;

  generate if(PIPELINE_STORE)begin:g_sign_store
    logic active_r,report_scrub_r;
    logic [1:0] destination_r;
    logic [3:0] mu_write_r,mask_write_r,challenge_write_r;
    logic [127:0] data_r;
    assign raw_service_active=active_r;
    assign raw_store_data=data_r;
    assign mu_write=mu_write_r;
    assign mask_write=mask_write_r;
    assign challenge_write=challenge_write_r;
    assign scrub_entropy=report_scrub_r;

    // Each accepted beat carries a registered lane enable through to the
    // store. The raw-done handshake requires the final beat to have arrived.
    always_ff @(posedge clk or posedge rst)begin
      if(rst)begin
        active_r<=0;destination_r<=0;report_scrub_r<=0;
        mu_write_r<=0;mask_write_r<=0;challenge_write_r<=0;data_r<=0;
      end else begin
        if(fault_o || raw_done_take)active_r<=0;
        else if(format_command && format_ready)begin active_r<=1;destination_r<=format_op;end
        report_scrub_r<=(state==SIG_DRAIN && signature_drained) ||
          (state==DRAIN_ERROR && error_drained) ||
          (state==IDLE && start_valid_i && start_ready_o && bad_start);
        mu_write_r<=0;mask_write_r<=0;challenge_write_r<=0;data_r<=0;
        if(raw_take && !raw_metadata_bad)begin
          data_r<=service_i.raw.output_data;
          case(destination_r)
            0:mu_write_r<=4'b0001<<raw_count_r[1:0];
            1:mask_write_r<=4'b0001<<raw_count_r[1:0];
            2:challenge_write_r<=4'b0001<<raw_count_r[1:0];
            default:begin end
          endcase
        end
      end
    end
  end else begin:g_direct_sign_store
    assign raw_service_active=raw_phase;
    assign raw_store_data=service_i.raw.output_data;
    assign mu_write=raw_take && state==MU_RUN ? 4'b0001<<raw_count_r[1:0]:0;
    assign mask_write=raw_take && state==MASK_RUN ? 4'b0001<<raw_count_r[1:0]:0;
    assign challenge_write=raw_take && state!=MU_RUN && state!=MASK_RUN ? 4'b0001<<raw_count_r[1:0]:0;
    assign scrub_entropy=state==REPORT && done_ready_i;
  end endgenerate
  assign format_payload_valid=state==MU_RUN?input_valid_i:state==CHASH_RUN && service_i.bank.read_valid[0][2];
  sign_hash_message #(.STABLE_PREFIX_INPUTS(1)) formatter(
    .clk(clk),.rst(rst),.command_valid_i(format_command),.command_ready_o(format_ready),.busy_o(),
    .command_op_i(format_op),.command_param_i(level_r),.command_id_i(id_r+16'd128+16'(format_op)),
    .command_message_len_i(message_r),.command_nonce_i(16'd0),.command_context_len_i(context_r),
    .command_internal_message_i(internal_message_r),
    .command_tr_i(tr),.command_mu_i(mu_r),.command_mask_seed_i(mask_r),.command_key_i(key),.command_rnd_i(rnd_r),
    .payload_valid_i(format_payload_valid),.payload_ready_o(format_payload_ready),
    .payload_data_i(state==MU_RUN?input_data_i:service_i.bank.read_data[0][2][63:0]),
    .payload_bytes_i(state==MU_RUN?input_bytes_i:4'd8),
    .payload_index_i(state==MU_RUN?input_index_i:16'(memory_word_r)),
    .payload_last_i(state==MU_RUN?input_last_i:memory_word_r+1'b1==w1_words),
    .request_valid_o(format_request),.request_ready_i(service_i.raw.ready),
    .request_sampling_o(format_sampling),.request_mode_o(format_mode),.request_param_o(format_param),
    .request_id_o(format_id),.request_message_len_o(format_length),.request_output_len_o(format_output_length),
    .input_valid_o(format_input_valid),.input_ready_i(service_i.raw.input_ready),.input_data_o(format_input_data),
    .input_bytes_o(format_input_bytes),.input_index_o(format_input_index),.input_last_o(format_input_last),
    .done_valid_o(format_done),.done_ready_i(raw_phase),.done_code_o(format_done_code),.done_id_o(format_done_id));
  assign hint_command_ready=service_i.hint_encode.ready;
  assign hint_input_ready=service_i.hint_encode.input_ready;
  assign hint_result=service_i.hint_encode.result_valid;assign hint_reject=service_i.hint_encode.reject;
  assign hint_output_valid=service_i.hint_encode.output_valid;assign hint_output_data=service_i.hint_encode.output_data;
  assign hint_output_bytes=service_i.hint_encode.output_bytes;assign hint_output_index=service_i.hint_encode.output_index;
  assign hint_output_last=service_i.hint_encode.output_last;assign hint_output_id=service_i.hint_encode.output_id;
  assign hint_done=service_i.hint_encode.done_valid;assign hint_code=service_i.hint_encode.done_code;
  always_comb begin
    service_o='0;signature_valid_o=0;signature_data_o=0;signature_bytes_o=8;signature_last_o=0;
    service_o.hint_encode.valid=state==HINT_CMD;
    service_o.hint_encode.cancel=state==RETRY || state==DRAIN_ERROR;
    service_o.hint_encode.param=level_r;service_o.hint_encode.id=id_r;
    service_o.hint_encode.feed_enable=state==MHINT_RUN;service_o.hint_encode.row=row_r[2:0];
    service_o.hint_encode.output_ready=state==SIG_HINT && signature_ready_i;
    service_o.hint_encode.done_ready=state==SIG_DRAIN;
    service_o.load.valid=key_load_valid;service_o.load.op=key_load_op;service_o.load.param=key_load_level;
    service_o.load.bank=key_load_bank;service_o.load.base=key_load_base;service_o.load.id=key_load_id;
    service_o.load.input_valid=key_load_input_valid;service_o.load.input_data=key_load_data;
    service_o.load.input_index=key_load_index;service_o.load.input_bytes=key_load_bytes;service_o.load.input_last=key_load_last;
    service_o.load.done_ready=key_load_done_ready;
    service_o.raw.valid=format_request;service_o.raw.mode=format_mode;service_o.raw.id=format_id;
    service_o.raw.message_len=format_length;service_o.raw.output_len=format_output_length;
    service_o.raw.input_valid=format_input_valid;service_o.raw.input_data=format_input_data;
    service_o.raw.output_ready=raw_service_active && raw_count_r<raw_expected;
    service_o.raw.done_ready=raw_service_active && raw_count_r==raw_expected && format_finished_r && !raw_finished_r;
    service_o.sample.valid=producer==P_CMD;
    service_o.sample.batch_last=selected_r+2'd1==batch_size_r;
    service_o.sample.mode=current.matrix?0:2;service_o.sample.param=level_r;
    service_o.sample.bank=current.matrix?3:0;
    service_o.sample.base=current.matrix?{current.slot,6'd0}:{current.index,6'd0};
    service_o.sample.id=descriptor_id(current,id_r);service_o.sample.message_len=current.matrix?34:66;
    service_o.sample.input_valid=producer==P_FEED;
    service_o.sample.input_data=current.matrix?
      (sample_word_r==4?{48'd0,4'd0,current.row,4'd0,current.column}:rho[64*sample_word_r+:64]):
      (sample_word_r==8?{48'd0,16'(nonce_base_r+16'(current.index))}:mask_r[64*sample_word_r+:64]);
    service_o.sample.done_ready=producer!=P_IDLE;
    if(state==CHAL_CMD || state==CHAL_FEED || state==CHAL_WAIT)begin
      service_o.sample.valid=state==CHAL_CMD;service_o.sample.batch_last=1;
      service_o.sample.mode=3;service_o.sample.param=level_r;service_o.sample.bank=0;service_o.sample.base=960;
      service_o.sample.id=id_r+16'd512;service_o.sample.message_len=ctilde_bytes;
      service_o.sample.input_valid=state==CHAL_FEED;service_o.sample.input_data=ctilde_word;
      service_o.sample.done_ready=state==CHAL_WAIT && (!LOCAL_CONTROL || !challenge_consumed_r);
    end
    service_o.ntt.done_ready=ntt_wait;
    case(state)
      PREP_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=section_r==2?0:3;
        service_o.ntt.a_bank=section_r==2?1:0;
        service_o.ntt.a_base=section_r==0?{poly_r,6'd0}:section_r==1?10'd448+{poly_r,6'd0}:10'd64+{poly_r,6'd0};
        service_o.ntt.d_bank=section_r==0?2:section_r==1?0:1;service_o.ntt.d_base=service_o.ntt.a_base;
      end
      Y_NTT_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=0;service_o.ntt.a_bank=0;service_o.ntt.a_base={poly_r,6'd0};
        service_o.ntt.d_bank=2;service_o.ntt.d_base=10'd448+{poly_r,6'd0};
      end
      TERM_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=2;service_o.ntt.accumulate=column_r!=0;
        service_o.ntt.a_bank=3;service_o.ntt.a_base={a_read_r,6'd0};
        service_o.ntt.b_bank=2;service_o.ntt.b_base=10'd448+{column_r,6'd0};
        service_o.ntt.c_bank=1;service_o.ntt.d_bank=1;
      end
      INV_ROW_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=1;service_o.ntt.a_bank=1;
        service_o.ntt.d_bank=0;service_o.ntt.d_base=960;
      end
      CHAL_NTT_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=0;service_o.ntt.a_bank=0;service_o.ntt.a_base=960;
        service_o.ntt.d_bank=3;service_o.ntt.d_base=448;
      end
      Z_MUL_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=2;service_o.ntt.accumulate=1;
        service_o.ntt.a_bank=3;service_o.ntt.a_base=448;
        service_o.ntt.b_bank=2;service_o.ntt.b_base={poly_r,6'd0};
        service_o.ntt.c_bank=2;service_o.ntt.c_base=10'd448+{poly_r,6'd0};
        service_o.ntt.d_bank=3;service_o.ntt.d_base={poly_r,6'd0};
      end
      Z_INV_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=1;service_o.ntt.a_bank=3;service_o.ntt.a_base={poly_r,6'd0};
        service_o.ntt.d_bank=3;service_o.ntt.d_base=service_o.ntt.a_base;
      end
      R0_MUL_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=2;service_o.ntt.a_bank=3;service_o.ntt.a_base=448;
        service_o.ntt.b_bank=0;service_o.ntt.b_base=10'd448+{row_r,6'd0};
        service_o.ntt.d_bank=3;service_o.ntt.d_base=r0_base;
      end
      R0_INV_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=1;service_o.ntt.a_bank=3;service_o.ntt.a_base=r0_base;
        service_o.ntt.d_bank=0;service_o.ntt.d_base=960;
      end
      CT0_MUL_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=2;service_o.ntt.a_bank=3;service_o.ntt.a_base=448;
        service_o.ntt.b_bank=1;service_o.ntt.b_base=10'd64+{row_r,6'd0};
        service_o.ntt.d_bank=0;service_o.ntt.d_base=960;
      end
      CT0_INV_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=1;service_o.ntt.a_bank=0;service_o.ntt.a_base=960;
        service_o.ntt.d_bank=0;service_o.ntt.d_base=960;
      end
      default:begin end
    endcase
    service_o.poly_process.param=level_r;service_o.poly_process.done_ready=process_wait;
    service_o.poly_process.hint_ready=state==MHINT_RUN && hint_input_ready;
    service_o.poly_process.packed_ready=state==SIG_Z_STREAM && signature_ready_i;
    case(state)
      DECOMP_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_DECOMPOSE;
        service_o.poly_process.a_bank=0;service_o.poly_process.a_base=960;
        service_o.poly_process.low_enable=1;service_o.poly_process.d_bank=1;service_o.poly_process.d_base=w0_base;
        service_o.poly_process.pack_enable=1;service_o.poly_process.pack_store=1;
        service_o.poly_process.h_bank=2;service_o.poly_process.h_base=10'd896+packed_row_offset;
      end
      Z_NORM_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_CNB;service_o.poly_process.kind=0;
        service_o.poly_process.a_bank=3;service_o.poly_process.a_base={poly_r,6'd0};
      end
      R0_SUB_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_SUB;service_o.poly_process.a_bank=1;service_o.poly_process.a_base=w0_base;
        service_o.poly_process.b_enable=1;service_o.poly_process.b_bank=0;service_o.poly_process.b_base=960;
        service_o.poly_process.low_enable=1;service_o.poly_process.d_bank=3;service_o.poly_process.d_base=r0_base;
      end
      R0_NORM_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_CNB;service_o.poly_process.kind=1;
        service_o.poly_process.a_bank=3;service_o.poly_process.a_base=r0_base;
      end
      CT0_NORM_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_CNB;service_o.poly_process.kind=2;
        service_o.poly_process.a_bank=0;service_o.poly_process.a_base=960;
      end
      R0_ADD_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_ADD;service_o.poly_process.a_bank=3;service_o.poly_process.a_base=r0_base;
        service_o.poly_process.b_enable=1;service_o.poly_process.b_bank=0;service_o.poly_process.b_base=960;
        service_o.poly_process.low_enable=1;service_o.poly_process.d_bank=3;service_o.poly_process.d_base=r0_base;
      end
      MHINT_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_MHINT;service_o.poly_process.a_bank=3;service_o.poly_process.a_base=r0_base;
        service_o.poly_process.b_enable=1;service_o.poly_process.b_bank=1;service_o.poly_process.b_base=0;service_o.poly_process.hint_enable=1;
      end
      SIG_Z_CMD:begin
        service_o.poly_process.valid=1;service_o.poly_process.op=PROC_PACK;service_o.poly_process.a_bank=3;service_o.poly_process.a_base={poly_r,6'd0};
        service_o.poly_process.pack_enable=1;service_o.poly_process.pack_op=4;
      end
      default:begin end
    endcase
    if(state==W1_READ_CMD || state==W1_HINT_READ_CMD)begin
      service_o.bank.command_valid[0]=1;service_o.bank.mask[0]=4;
      service_o.bank.base[0][2]=state==W1_READ_CMD?10'd896:10'd896+packed_row_offset;
      service_o.bank.words[0][2]=state==W1_READ_CMD?11'(w1_words):level_r==0?11'd24:11'd16;
    end
    service_o.bank.read_ready[0][2]=state==CHASH_RUN?format_payload_ready:
      state==W1_HINT_FEED?service_i.load.input_ready:1'b0;
    service_o.bank.done_ready[0][2]=state==CHASH_RUN || state==CHASH_DRAIN || state==W1_HINT_FEED || state==W1_HINT_DRAIN;
    if(state==W1_HINT_LOAD_CMD || state==W1_HINT_FEED || state==W1_HINT_DRAIN)begin
      service_o.load.valid=state==W1_HINT_LOAD_CMD;service_o.load.op=3;service_o.load.param=level_r;
      service_o.load.bank=1;service_o.load.base=0;service_o.load.id=id_r+{4'd1,8'd0,row_r};
      service_o.load.input_valid=state==W1_HINT_FEED && service_i.bank.read_valid[0][2];
      service_o.load.input_data=service_i.bank.read_data[0][2][63:0];service_o.load.input_index=memory_word_r[6:0];
      service_o.load.input_bytes=8;service_o.load.input_last=memory_word_r+1'b1==(level_r==0?24:16);
      service_o.load.done_ready=state==W1_HINT_FEED || state==W1_HINT_DRAIN;
    end
    if(state==SIG_PREFIX)begin signature_valid_o=1;signature_data_o=ctilde_word;end
    if(state==SIG_Z_STREAM)begin signature_valid_o=service_i.poly_process.packed_valid;signature_data_o=service_i.poly_process.packed_data;end
    if(state==SIG_HINT)begin
      signature_valid_o=hint_output_valid;signature_data_o=hint_output_data;signature_bytes_o=hint_output_bytes;signature_last_o=hint_output_last;
    end
    if(fault_o)begin service_o='0;signature_valid_o=0;end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;producer<=P_IDLE;level_r<=0;section_r<=0;id_r<=0;message_r<=0;context_r<=0;internal_message_r<=0;rho_store_r<=0;tr_mu_store_r<=0;entropy_mask_store_r<=0;
      k_r<=0;l_r<=0;poly_r<=0;row_r<=0;column_r<=0;y_next_r<=0;a_row_r<=0;a_column_r<=0;a_write_r<=0;a_read_r<=0;
      descriptor_r[0]<='0;descriptor_r[1]<='0;batch_size_r<=0;batch_done_r<=0;selected_r<=0;
      sample_word_r<=0;challenge_word_r<=0;header_word_r<=0;y_phase_r<=0;y_credit_r<=0;released_prev_r<=0;
      y_ready_r<=0;a_reserved_r<=0;a_ready_r<=0;nonce_base_r<=0;ctilde_r<=0;
      memory_word_r<=0;raw_count_r<=0;raw_expected<=0;format_code_r<=0;format_finished_r<=0;
      raw_finished_r<=0;bank_finished_r<=0;load_finished_r<=0;raw_core_r<=0;
      signature_index_o<=0;done_code_o<=0;done_stage_o<=0;done_detail_o<=0;fault_o<=0;
      attempts_o<=0;rejections_o<=0;next_nonce_o<=0;
    end else begin
      if(LOCAL_CONTROL && state==IDLE)begin
        rho_store_r<=0;tr_mu_store_r<=0;entropy_mask_store_r<={start_rnd_i,256'd0};
      end
      if(header_write_valid)begin
        if(header_write_index<4)rho_store_r[64*header_write_index[1:0]+:64]<=header_write_data;
        else if(header_write_index<8)entropy_mask_store_r[64*header_write_index[1:0]+:64]<=header_write_data;
        else tr_mu_store_r[64*header_write_index[2:0]+:64]<=header_write_data;
      end
      released_prev_r<=service_i.ntt.source_released;
      if(y_phase_r && service_i.ntt.source_released && !released_prev_r)y_credit_r<=1;
      if(signature_valid_o && signature_ready_i)signature_index_o<=signature_index_o+1'b1;
      if(format_command && format_ready)begin
        raw_count_r<=0;raw_expected<=format_op==2?ctilde_beats:3'd4;raw_finished_r<=0;format_finished_r<=0;format_code_r<=0;
      end
      if(format_request && service_i.raw.ready)raw_core_r<=service_i.raw.core;
      if(format_done && raw_phase)begin format_finished_r<=1;format_code_r<=format_done_code;end
      if(raw_take)raw_count_r<=raw_count_r+1'b1;
      for(int i=0;i<4;i++)begin
        if(mu_write[i])tr_mu_store_r[128*i+:128]<=raw_store_data;
        if(mask_write[i])entropy_mask_store_r[128*i+:128]<=raw_store_data;
        if(challenge_write[i])ctilde_r[128*i+:128]<=raw_store_data;
      end
      // The upper half is dead after drain. Scrub locally even if the
      // public completion stalls, independent of main-controller ready.
      if(scrub_entropy)entropy_mask_store_r[511:256]<=0;
      if(raw_done_take)raw_finished_r<=1;
      if(service_i.bank.done_valid[0][2] && service_o.bank.done_ready[0][2])bank_finished_r<=1;
      if(service_i.bank.read_valid[0][2] && service_o.bank.read_ready[0][2])memory_word_r<=memory_word_r+1'b1;
      if(service_i.load.done_valid && service_o.load.done_ready && state!=KEY_WAIT)load_finished_r<=1;
      case(producer)
        P_IDLE:if(producer_enabled)begin
          if(y_phase_r && y_next_r<l_r && (y_next_r==0 || y_credit_r))begin
            descriptor_r[0]<=y_descriptor(y_next_r);
            if(y_next_r+1'b1<l_r)begin descriptor_r[1]<=y_descriptor(y_next_r+1'b1);batch_size_r<=2;y_next_r<=y_next_r+2;end
            else begin batch_size_r<=1;y_next_r<=y_next_r+1'b1;end
            y_credit_r<=0;selected_r<=0;sample_word_r<=0;batch_done_r<=0;producer<=P_CMD;
          end else if(!y_phase_r || (y_next_r==l_r && (y_ready_r&(7'h7f>>(7-l_r)))==(7'h7f>>(7-l_r))))begin
            if(a_row_r<k_r && !a_reserved_r[a_write_r])begin
              logic [3:0] next_row,next_column,next_slot;
              descriptor_r[0]<=matrix_descriptor(a_row_r,a_column_r,a_write_r);
              a_reserved_r[a_write_r]<=1;next_row=a_row_r;next_column=a_column_r+1'b1;next_slot=next_ring(a_write_r,level_r);
              if(next_column==l_r)begin next_column=0;next_row=a_row_r+1'b1;end
              if(next_row<k_r && !a_reserved_r[next_slot])begin
                descriptor_r[1]<=matrix_descriptor(next_row,next_column,next_slot);a_reserved_r[next_slot]<=1;batch_size_r<=2;
                a_write_r<=next_ring(next_slot,level_r);
                if(next_column+1'b1==l_r)begin a_column_r<=0;a_row_r<=next_row+1'b1;end
                else begin a_column_r<=next_column+1'b1;a_row_r<=next_row;end
              end else begin batch_size_r<=1;a_write_r<=next_slot;a_column_r<=next_column;a_row_r<=next_row;end
              selected_r<=0;sample_word_r<=0;batch_done_r<=0;producer<=P_CMD;
            end
          end
        end
        P_CMD:if(service_i.sample.ready)begin sample_word_r<=0;producer<=P_FEED;end
        P_FEED:if(service_i.sample.input_ready)begin
          if(sample_word_r==(current.matrix?4:8))begin
            if(selected_r+2'd1==batch_size_r)producer<=P_WAIT;else begin selected_r<=1;producer<=P_CMD;end
          end else sample_word_r<=sample_word_r+1'b1;
        end
        P_WAIT:if(batch_done_r==(batch_size_r==1?1:3))producer<=P_IDLE;
        default:producer<=P_IDLE;
      endcase
      if(LOCAL_CONTROL?sample_event_r:sample_take)begin
        logic matched;matched=0;
        for(int i=0;i<2;i++)if((LOCAL_CONTROL?sample_event_mask_r[i]:
          (i<int'(batch_size_r) && descriptor_matches(descriptor_r[i],id_r,service_i.sample.done_id))) && !batch_done_r[i])begin
          matched=1;batch_done_r[i]<=1;
          if(descriptor_r[i].matrix)a_ready_r[descriptor_r[i].slot]<=1;
          else y_ready_r[descriptor_r[i].index]<=1;
        end
        if(!matched || (!LOCAL_CONTROL && service_i.sample.done_code!=0))begin fault_o<=1;state<=HALT;end
      end
      case(state)
        IDLE:if(start_valid_i && start_ready_o)begin
          level_r<=start_param_i;id_r<=start_id_i;message_r<=start_message_len_i;context_r<=start_context_len_i;internal_message_r<=start_internal_message_i;
          if(!LOCAL_CONTROL)begin rho_store_r<=0;tr_mu_store_r<=0;entropy_mask_store_r<={start_rnd_i,256'd0};end
          k_r<=rows(start_param_i);l_r<=columns(start_param_i);section_r<=0;poly_r<=0;
          done_code_o<=0;done_stage_o<=0;done_detail_o<=0;attempts_o<=0;rejections_o<=0;next_nonce_o<=0;signature_index_o<=0;
          state<=KEY_CMD;
          if(bad_start)begin done_code_o<=1;state<=REPORT;end
        end
        KEY_CMD:if(key_command_ready)state<=KEY_WAIT;
        KEY_WAIT:if(key_done)begin
          if(key_done_id!=id_r)begin done_code_o<=6;done_stage_o<=1;end
          else if(key_code!=0)begin done_code_o<=3;done_stage_o<=1;done_detail_o<=key_code;end
          state<=KEY_RETIRE;
        end
        KEY_RETIRE:if(!key_done && key_command_ready)state<=done_code_o==0?PREP_CMD:DRAIN_ERROR;
        PREP_CMD:if(service_i.ntt.ready)state<=PREP_RUN;
        PREP_RUN:if(service_i.ntt.done_valid)begin
          if(poly_r+1'b1==(section_r==0?l_r:k_r))begin
            if(section_r==2)state<=MU_CMD;else begin section_r<=section_r+1'b1;poly_r<=0;state<=PREP_CMD;end
          end else begin poly_r<=poly_r+1'b1;state<=PREP_CMD;end
        end
        MU_CMD:if(format_ready)state<=MU_RUN;
        MU_RUN:if(raw_finished_r && format_finished_r)begin
          if(format_code_r!=0)begin done_code_o<=4;done_stage_o<=2;done_detail_o<=format_code_r;state<=DRAIN_ERROR;end
          else state<=MASK_CMD;
        end
        MASK_CMD:if(format_ready)state<=MASK_RUN;
        MASK_RUN:if(raw_finished_r && format_finished_r)state<=ATTEMPT_BEGIN;
        ATTEMPT_BEGIN:begin
          if(next_nonce_o+17'(l_r)>17'd65536)begin done_code_o<=4;done_stage_o<=2;done_detail_o<=2;state<=DRAIN_ERROR;end
          else begin
            nonce_base_r<=next_nonce_o[15:0];next_nonce_o<=next_nonce_o+17'(l_r);attempts_o<=attempts_o+1'b1;
            y_next_r<=0;y_ready_r<=0;y_phase_r<=1;y_credit_r<=0;poly_r<=0;row_r<=0;column_r<=0;
            a_row_r<=0;a_column_r<=0;a_write_r<=0;a_read_r<=0;a_reserved_r<=0;a_ready_r<=0;
            producer<=P_IDLE;selected_r<=0;batch_done_r<=0;batch_size_r<=0;sample_word_r<=0;state<=Y_READY;
          end
        end
        Y_READY:if(y_ready_r[poly_r])state<=Y_NTT_CMD;
        Y_NTT_CMD:if(service_i.ntt.ready)state<=Y_NTT_RUN;
        Y_NTT_RUN:if(service_i.ntt.done_valid)begin
          if(poly_r+1'b1==l_r)begin y_phase_r<=0;state<=TERM_READY;end
          else begin poly_r<=poly_r+1'b1;state<=Y_READY;end
        end
        TERM_READY:if(a_ready_r[a_read_r])state<=TERM_CMD;
        TERM_CMD:if(service_i.ntt.ready)state<=TERM_RUN;
        TERM_RUN:if(service_i.ntt.done_valid)begin
          a_reserved_r[a_read_r]<=0;a_ready_r[a_read_r]<=0;a_read_r<=next_ring(a_read_r,level_r);
          if(column_r+1'b1==l_r)begin column_r<=0;state<=INV_ROW_CMD;end
          else begin column_r<=column_r+1'b1;state<=TERM_READY;end
        end
        INV_ROW_CMD:if(service_i.ntt.ready)state<=INV_ROW_RUN;
        INV_ROW_RUN:if(service_i.ntt.done_valid)state<=DECOMP_CMD;
        DECOMP_CMD:if(service_i.poly_process.ready)state<=DECOMP_RUN;
        DECOMP_RUN:if(service_i.poly_process.done_valid)begin
          if(row_r+1'b1==k_r)begin state<=W1_READ_CMD;memory_word_r<=0;bank_finished_r<=0;end
          else begin row_r<=row_r+1'b1;state<=TERM_READY;end
        end
        W1_READ_CMD:if(service_i.bank.command_ready[0])state<=CHASH_CMD;
        CHASH_CMD:if(format_ready)state<=CHASH_RUN;
        CHASH_RUN:if(format_finished_r)state<=CHASH_DRAIN;
        CHASH_DRAIN:if(format_finished_r && raw_finished_r && bank_finished_r)begin state<=CHAL_CMD;challenge_word_r<=0;end
        CHAL_CMD:if(service_i.sample.ready)state<=CHAL_FEED;
        CHAL_FEED:if(service_i.sample.input_ready)begin
          if(challenge_word_r+1'b1==ctilde_words)state<=CHAL_WAIT;else challenge_word_r<=challenge_word_r+1'b1;
        end
        CHAL_WAIT:if(LOCAL_CONTROL?challenge_event_r:service_i.sample.done_valid)begin
          if(!LOCAL_CONTROL && (!id_add_matches(id_r,16'd512,service_i.sample.done_id) || service_i.sample.done_code!=0))begin fault_o<=1;state<=HALT;end
          else state<=CHAL_NTT_CMD;
        end
        CHAL_NTT_CMD:if(service_i.ntt.ready)state<=CHAL_NTT_RUN;
        CHAL_NTT_RUN:if(service_i.ntt.done_valid)begin poly_r<=0;state<=Z_MUL_CMD;end
        Z_MUL_CMD:if(service_i.ntt.ready)state<=Z_MUL_RUN;
        Z_MUL_RUN:if(service_i.ntt.done_valid)state<=Z_INV_CMD;
        Z_INV_CMD:if(service_i.ntt.ready)state<=Z_INV_RUN;
        Z_INV_RUN:if(service_i.ntt.done_valid)state<=Z_NORM_CMD;
        Z_NORM_CMD:if(service_i.poly_process.ready)state<=Z_NORM_RUN;
        Z_NORM_RUN:if(service_i.poly_process.done_valid)begin
          if(service_i.poly_process.reject)begin rejections_o<=rejections_o+1'b1;state<=RETRY;end
          else if(poly_r+1'b1==l_r)begin row_r<=0;state<=R0_MUL_CMD;end
          else begin poly_r<=poly_r+1'b1;state<=Z_MUL_CMD;end
        end
        R0_MUL_CMD:if(service_i.ntt.ready)state<=R0_MUL_RUN;
        R0_MUL_RUN:if(service_i.ntt.done_valid)state<=R0_INV_CMD;
        R0_INV_CMD:if(service_i.ntt.ready)state<=R0_INV_RUN;
        R0_INV_RUN:if(service_i.ntt.done_valid)state<=R0_SUB_CMD;
        R0_SUB_CMD:if(service_i.poly_process.ready)state<=R0_SUB_RUN;
        R0_SUB_RUN:if(service_i.poly_process.done_valid)state<=R0_NORM_CMD;
        R0_NORM_CMD:if(service_i.poly_process.ready)state<=R0_NORM_RUN;
        R0_NORM_RUN:if(service_i.poly_process.done_valid)begin
          if(service_i.poly_process.reject)begin rejections_o<=rejections_o+1'b1;state<=RETRY;end
          else if(row_r+1'b1==k_r)begin row_r<=0;state<=HINT_CMD;end
          else begin row_r<=row_r+1'b1;state<=R0_MUL_CMD;end
        end
        HINT_CMD:if(hint_command_ready)state<=CT0_MUL_CMD;
        CT0_MUL_CMD:if(service_i.ntt.ready)state<=CT0_MUL_RUN;
        CT0_MUL_RUN:if(service_i.ntt.done_valid)state<=CT0_INV_CMD;
        CT0_INV_CMD:if(service_i.ntt.ready)state<=CT0_INV_RUN;
        CT0_INV_RUN:if(service_i.ntt.done_valid)state<=CT0_NORM_CMD;
        CT0_NORM_CMD:if(service_i.poly_process.ready)state<=CT0_NORM_RUN;
        CT0_NORM_RUN:if(service_i.poly_process.done_valid)begin
          if(service_i.poly_process.reject)begin rejections_o<=rejections_o+1'b1;state<=RETRY;end else state<=R0_ADD_CMD;
        end
        R0_ADD_CMD:if(service_i.poly_process.ready)state<=R0_ADD_RUN;
        R0_ADD_RUN:if(service_i.poly_process.done_valid)begin memory_word_r<=0;bank_finished_r<=0;load_finished_r<=0;state<=W1_HINT_READ_CMD;end
        W1_HINT_READ_CMD:if(service_i.bank.command_ready[0])state<=W1_HINT_LOAD_CMD;
        W1_HINT_LOAD_CMD:if(service_i.load.ready)state<=W1_HINT_FEED;
        W1_HINT_FEED:if(load_finished_r)state<=W1_HINT_DRAIN;
        W1_HINT_DRAIN:if(load_finished_r && bank_finished_r)state<=MHINT_CMD;
        MHINT_CMD:if(service_i.poly_process.ready)state<=MHINT_RUN;
        MHINT_RUN:if(service_i.poly_process.done_valid)begin
          if(hint_reject)begin rejections_o<=rejections_o+1'b1;state<=RETRY;end
          else if(row_r+1'b1==k_r)state<=HINT_RESULT;
          else begin row_r<=row_r+1'b1;state<=CT0_MUL_CMD;end
        end
        HINT_RESULT:if(hint_result)begin
          if(hint_code!=0)begin done_code_o<=5;done_stage_o<=3;done_detail_o<=3'(hint_code);state<=DRAIN_ERROR;end
          else if(hint_reject)begin rejections_o<=rejections_o+1'b1;state<=RETRY;end
          else begin signature_index_o<=0;header_word_r<=0;poly_r<=0;state<=SIG_PREFIX;end
        end
        SIG_PREFIX:if(signature_ready_i)begin
          if(header_word_r+1'b1==ctilde_words)state<=SIG_Z_CMD;else header_word_r<=header_word_r+1'b1;
        end
        SIG_Z_CMD:if(service_i.poly_process.ready)state<=SIG_Z_STREAM;
        SIG_Z_STREAM:if(service_i.poly_process.done_valid)begin
          if(poly_r+1'b1==l_r)state<=SIG_HINT;else begin poly_r<=poly_r+1'b1;state<=SIG_Z_CMD;end
        end
        SIG_HINT:if(hint_output_valid && signature_ready_i && hint_output_last)state<=SIG_DRAIN;
        SIG_DRAIN:if(signature_drained)state<=REPORT;
        RETRY:if(service_i.idle && hint_command_ready)state<=ATTEMPT_BEGIN;
        DRAIN_ERROR:if(error_drained)state<=REPORT;
        REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:begin fault_o<=1;state<=HALT;end
      endcase
      if(LOCAL_CONTROL && sample_take && sample_bad)fault_o<=1;
      if(LOCAL_CONTROL && challenge_take && challenge_bad)fault_o<=1;
      if(fault_o)state<=HALT;
      if(state!=IDLE && state!=REPORT && (service_i.sample.fault ||
        (format_done && raw_phase && format_done_id!=format_id) ||
        (service_i.raw.done_valid && service_o.raw.done_ready &&
          (service_i.raw.done_id!=format_id || service_i.raw.done_core!=raw_core_r)) ||
        (format_finished_r && (state==MASK_RUN || state==CHASH_DRAIN) && format_code_r!=0) ||
        (ntt_wait && service_i.ntt.done_valid && service_i.ntt.done_code!=0) ||
        (process_wait && service_i.poly_process.done_valid && service_i.poly_process.done_code!=0) ||
        (raw_take && raw_metadata_bad) ||
        (service_i.load.done_valid && service_o.load.done_ready && state!=KEY_WAIT &&
          (!(state==W1_HINT_LOAD_CMD || state==W1_HINT_FEED || state==W1_HINT_DRAIN?
            id_add_matches(id_r,{4'd1,8'd0,row_r},service_i.load.done_id):service_i.load.done_id==key_load_id) ||
           service_i.load.done_code!=0))))begin fault_o<=1;state<=HALT;end
    end
  end
  // synthesis translate_off
  always @(posedge clk)if(!rst)begin
    if(service_i.raw.output_valid && service_o.raw.output_ready &&
       (state==MU_RUN || state==MASK_RUN) && formatter.prefix_left_r!=0)
      $fatal(1,"Sign register overlay overwrote an unconsumed hash prefix");
    if(header_write_valid && !(state==KEY_WAIT))$fatal(1,"Sign header write outside key input");
    if(PIPELINE_STORE && state==REPORT && !scrub_entropy && entropy_mask_store_r[511:256]!==256'd0)
      $fatal(1,"Sign entropy was not cleared while completion was held");
  end
  // synthesis translate_on
endmodule
`default_nettype wire
