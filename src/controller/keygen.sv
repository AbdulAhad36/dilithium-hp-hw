// Autonomous KeyGen polynomial phase,with optional complete key encoding/hash.
// Produces t_i = inverseNTT(sum_j(A_hat[i,j]*NTT(s1[j]))) + s2[i].
// FULL_KEYGEN retains fields through PK/SK streaming and overall completion.
`default_nettype none
module keygen #(parameter bit ROUND_OUTPUTS=0, FULL_KEYGEN=0) (
  output dilithium_service_pkg::request_t service_o,
  input dilithium_service_pkg::response_t service_i,
  output logic key_valid_o,input wire logic key_ready_i,output logic [63:0] key_data_o,
  output logic [3:0] key_bytes_o,output logic key_type_o,key_last_o,
  output logic [9:0] key_index_o,output logic [15:0] key_id_o,
  input wire logic clk,rst,start_valid_i,output logic start_ready_o,busy_o,
  input wire logic [1:0] start_param_i,input wire logic [15:0] start_id_i,
  input wire logic [255:0] start_seed_i,
  output logic row_result_valid_o,input wire logic row_result_ready_i,
  output logic [3:0] row_result_index_o,output logic [5:0] row_result_region_o,
  output logic [15:0] row_result_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic seed_valid_o,output logic [255:0] rho_o,key_o,output logic [511:0] rhoprime_o,
  input wire logic read_valid_i,input wire logic [1:0] read_bank_i,
  input wire logic [3:0] read_region_i,input wire logic [5:0] read_word_i,
  output logic read_ready_o,response_valid_o,response_error_o,
  output logic [1:0] response_bank_o,response_mode_o,response_param_o,
  output logic [3:0] response_region_o,output logic [5:0] response_word_o,
  output logic [91:0] response_data_o,output logic [15:0] response_id_o,
  output logic response_ntt_domain_o,response_small_o,input wire logic response_ready_i,
  output logic [63:0] reserved_o,complete_o,output logic fault_o
);
  localparam bit ROUNDED=ROUND_OUTPUTS || FULL_KEYGEN;
  logic base_fault,base_response_valid,encode_active,encode_started_r,encode_start_ready,encode_done,encode_fault;
  logic encode_read_valid,encode_response_ready;logic [5:0] encode_read_region,encode_read_word;
  logic seed_raw_valid,seed_raw_mode,seed_raw_input_valid,seed_raw_output_ready,seed_raw_done_ready;
  logic [15:0] seed_raw_id,seed_raw_message_len,seed_raw_output_len;logic [63:0] seed_raw_input_data;
  logic encode_raw_valid,encode_raw_mode,encode_raw_input_valid,encode_raw_output_ready,encode_raw_done_ready;
  logic [15:0] encode_raw_id,encode_raw_message_len,encode_raw_output_len;logic [63:0] encode_raw_input_data;
  logic raw_valid_i;
  logic raw_ready_o,raw_core_o;
  logic raw_mode_i;
  logic [15:0] raw_id_i,raw_message_len_i,raw_output_len_i;
  logic [63:0] raw_input_data_i;
  logic raw_input_valid_i;
  logic raw_input_ready_o;
  logic raw_output_valid_o,raw_output_core_o;
  logic [15:0] raw_output_id_o;
  logic [127:0] raw_output_data_o;
  logic [4:0] raw_output_bytes_o;
  logic raw_output_ready_i;
  logic raw_done_valid_o,raw_done_core_o;
  logic [15:0] raw_done_id_o;
  logic raw_done_ready_i;
  logic job_valid_i;
  logic job_ready_o,job_core_o;
  logic [1:0] job_bank_i,job_mode_i,job_param_i;
  logic [3:0] job_region_i;
  logic [15:0] job_id_i,message_len_i;
  logic [63:0] input_data_i;
  logic input_valid_i;
  logic input_ready_o;
  logic status_valid_o,status_core_o;
  logic [15:0] status_id_o;
  logic [2:0] status_code_o;
  logic status_ready_i;
  logic [1:0] active_o;
  logic release_valid_i;
  logic [1:0] release_bank_i;
  logic [3:0] release_region_i;
  logic release_ready_o;
  logic op_valid_i;
  logic op_ready_o,op_busy_o;
  logic [1:0] op_i;
  logic [5:0] op_a_region_i,op_b_region_i,op_dest_region_i;
  logic [15:0] op_a_id_i,op_b_id_i,op_id_i;
  logic op_done_valid_o;
  logic op_done_ready_i;
  logic [2:0] op_done_code_o;
  logic [15:0] op_done_id_o;
  logic [5:0] op_done_region_o;
  logic process_valid_i;
  logic process_ready_o,process_busy_o;
  logic [1:0] process_op_i;
  logic process_inplace_i;
  logic [5:0] process_a_i,process_b_i,process_dest_i,process_high_i;
  logic [15:0] process_a_id_i,process_b_id_i,process_id_i;
  logic process_done_valid_o;
  logic process_done_ready_i;
  logic [2:0] process_done_code_o;
  logic [15:0] process_done_id_o;
  logic [5:0] process_done_dest_o,process_done_high_o;
  logic row_valid_i;
  logic row_ready_o,row_busy_o;
  logic [1:0] row_param_i;
  logic [3:0] row_index_i;
  logic [15:0] row_id_i;
  logic [5:0] row_acc_i,row_scratch_i,row_result_i;
  logic [6:0][5:0] row_a_i,row_s_i;
  logic [6:0][15:0] row_a_id_i,row_s_id_i;
  logic row_done_valid_o;
  logic row_done_ready_i;
  logic [2:0] row_done_code_o,row_completed_terms_o;
  logic [15:0] row_done_id_o;
  logic [5:0] row_done_region_o;

  typedef enum logic [4:0] {IDLE,SEED_CMD,SEED_REPLY,SECRET_CMD,SECRET_REPLY,
    TRANSFORM_CMD,TRANSFORM_REPLY,MATRIX_CMD,MATRIX_REPLY,ROW_CMD,ROW_REPLY,
    SUM_CMD,SUM_REPLY,ROW_OUTPUT,WAIT_ROW_READ,FREE_T,FREE_U,FREE_MATRIX,
    REPORT,WAIT_FINAL_READ,FREE_RAW,FREE_HAT,FREE_S2,HALT,
    ROUND_CMD,ROUND_REPLY,FREE_LOW,FREE_HIGH} state_e;
  state_e state;
  logic [1:0] param_r;logic [3:0] rows_r,columns_r,nonce_r,column_r,index_r,cleanup_r;
  logic [255:0] xi_r;logic owned_r,controller_fault_r,public_pending_r,base_read_ready,inspect_allowed;
  logic source_valid,source_ready,source_done,source_done_ready;
  logic [1:0] source_op,seed_param;logic [15:0] source_id,source_nonce,source_done_id;
  logic [7:0] source_row,source_column;logic [5:0] source_region;
  logic [2:0] source_code;

  keygen_sample_source source(
    .clk(clk),.rst(rst),.command_valid_i(source_valid),.command_ready_o(source_ready),
    .command_op_i(source_op),.command_param_i(param_r),.command_id_i(source_id),.command_nonce_i(source_nonce),
    .command_row_i(source_row),.command_column_i(source_column),.command_seed_i(xi_r),.command_region_i(source_region),
    .done_valid_o(source_done),.done_ready_i(source_done_ready),.done_code_o(source_code),.done_id_o(source_done_id),
    .seed_valid_o(seed_valid_o),.seed_param_o(seed_param),.rho_o(rho_o),.key_o(key_o),.rhoprime_o(rhoprime_o),
    .job_valid_o(job_valid_i),.job_ready_i(job_ready_o),.job_core_i(job_core_o),
    .job_bank_o(job_bank_i),.job_region_o(job_region_i),.job_mode_o(job_mode_i),.job_param_o(job_param_i),
    .job_id_o(job_id_i),.message_len_o(message_len_i),.input_data_o(input_data_i),.input_valid_o(input_valid_i),.input_ready_i(input_ready_o),
    .status_valid_i(status_valid_o),.status_core_i(status_core_o),.status_id_i(status_id_o),.status_code_i(status_code_o),
    .status_ready_o(status_ready_i),.raw_valid_o(seed_raw_valid),.raw_ready_i(raw_ready_o && !encode_active),.raw_core_i(raw_core_o),
    .raw_mode_o(seed_raw_mode),.raw_id_o(seed_raw_id),.raw_message_len_o(seed_raw_message_len),.raw_output_len_o(seed_raw_output_len),
    .raw_input_data_o(seed_raw_input_data),.raw_input_valid_o(seed_raw_input_valid),.raw_input_ready_i(raw_input_ready_o && !encode_active),
    .raw_output_valid_i(raw_output_valid_o && !encode_active),.raw_output_core_i(raw_output_core_o),.raw_output_id_i(raw_output_id_o),
    .raw_output_data_i(raw_output_data_o),.raw_output_bytes_i(raw_output_bytes_o),.raw_output_ready_o(seed_raw_output_ready),
    .raw_done_valid_i(raw_done_valid_o && !encode_active),.raw_done_core_i(raw_done_core_o),.raw_done_id_i(raw_done_id_o),.raw_done_ready_o(seed_raw_done_ready)
  );
  // KeyGen is a client;the main controller owns physical engine instances.
  assign service_o.sign='0;
  assign service_o.raw_valid=raw_valid_i;
  assign raw_ready_o=service_i.raw_ready;
  assign raw_core_o=service_i.raw_core;
  assign service_o.raw_mode=raw_mode_i;
  assign service_o.raw_id=raw_id_i;
  assign service_o.raw_message_len=raw_message_len_i;
  assign service_o.raw_output_len=raw_output_len_i;
  assign service_o.raw_input_data=raw_input_data_i;
  assign service_o.raw_input_valid=raw_input_valid_i;
  assign raw_input_ready_o=service_i.raw_input_ready;
  assign raw_output_valid_o=service_i.raw_output_valid;
  assign raw_output_core_o=service_i.raw_output_core;
  assign raw_output_id_o=service_i.raw_output_id;
  assign raw_output_data_o=service_i.raw_output_data;
  assign raw_output_bytes_o=service_i.raw_output_bytes;
  assign service_o.raw_output_ready=raw_output_ready_i;
  assign raw_done_valid_o=service_i.raw_done_valid;
  assign raw_done_core_o=service_i.raw_done_core;
  assign raw_done_id_o=service_i.raw_done_id;
  assign service_o.raw_done_ready=raw_done_ready_i;
  assign service_o.job_valid=job_valid_i;
  assign job_ready_o=service_i.job_ready;
  assign job_core_o=service_i.job_core;
  assign service_o.job_bank=job_bank_i;
  assign service_o.job_mode=job_mode_i;
  assign service_o.job_param=job_param_i;
  assign service_o.job_region=job_region_i;
  assign service_o.job_id=job_id_i;
  assign service_o.message_len=message_len_i;
  assign service_o.input_data=input_data_i;
  assign service_o.input_valid=input_valid_i;
  assign input_ready_o=service_i.input_ready;
  assign status_valid_o=service_i.status_valid;
  assign status_core_o=service_i.status_core;
  assign status_id_o=service_i.status_id;
  assign status_code_o=service_i.status_code;
  assign service_o.status_ready=status_ready_i;
  assign active_o=service_i.active;
  assign service_o.read_valid=encode_active?encode_read_valid:(read_valid_i && inspect_allowed && !FULL_KEYGEN);
  assign service_o.read_bank=encode_active?encode_read_region[5:4]:read_bank_i;
  assign service_o.read_region=encode_active?encode_read_region[3:0]:read_region_i;
  assign service_o.read_word=encode_active?encode_read_word:read_word_i;
  assign base_read_ready=service_i.read_ready;
  assign base_response_valid=service_i.response_valid;
  assign response_error_o=service_i.response_error;
  assign response_bank_o=service_i.response_bank;
  assign response_mode_o=service_i.response_mode;
  assign response_param_o=service_i.response_param;
  assign response_region_o=service_i.response_region;
  assign response_word_o=service_i.response_word;
  assign response_data_o=service_i.response_data;
  assign response_id_o=service_i.response_id;
  assign response_ntt_domain_o=service_i.response_ntt_domain;
  assign response_small_o=service_i.response_small;
  assign service_o.response_ready=encode_active?encode_response_ready:response_ready_i;
  assign service_o.release_valid=release_valid_i;
  assign service_o.release_bank=release_bank_i;
  assign service_o.release_region=release_region_i;
  assign release_ready_o=service_i.release_ready;
  assign reserved_o=service_i.reserved;
  assign complete_o=service_i.complete;
  assign base_fault=service_i.fault;
  assign service_o.op_valid=op_valid_i;
  assign op_ready_o=service_i.op_ready;
  assign op_busy_o=service_i.op_busy;
  assign service_o.op=op_i;
  assign service_o.op_a_region=op_a_region_i;
  assign service_o.op_b_region=op_b_region_i;
  assign service_o.op_dest_region=op_dest_region_i;
  assign service_o.op_a_id=op_a_id_i;
  assign service_o.op_b_id=op_b_id_i;
  assign service_o.op_id=op_id_i;
  assign op_done_valid_o=service_i.op_done_valid;
  assign service_o.op_done_ready=op_done_ready_i;
  assign op_done_code_o=service_i.op_done_code;
  assign op_done_id_o=service_i.op_done_id;
  assign op_done_region_o=service_i.op_done_region;
  assign service_o.process_valid=process_valid_i;
  assign process_ready_o=service_i.process_ready;
  assign process_busy_o=service_i.process_busy;
  assign service_o.process_op=process_op_i;
  assign service_o.process_inplace=process_inplace_i;
  assign service_o.process_a=process_a_i;
  assign service_o.process_b=process_b_i;
  assign service_o.process_dest=process_dest_i;
  assign service_o.process_high=process_high_i;
  assign service_o.process_a_id=process_a_id_i;
  assign service_o.process_b_id=process_b_id_i;
  assign service_o.process_id=process_id_i;
  assign process_done_valid_o=service_i.process_done_valid;
  assign service_o.process_done_ready=process_done_ready_i;
  assign process_done_code_o=service_i.process_done_code;
  assign process_done_id_o=service_i.process_done_id;
  assign process_done_dest_o=service_i.process_done_dest;
  assign process_done_high_o=service_i.process_done_high;
  assign service_o.row_valid=row_valid_i;
  assign row_ready_o=service_i.row_ready;
  assign row_busy_o=service_i.row_busy;
  assign service_o.row_param=row_param_i;
  assign service_o.row_index=row_index_i;
  assign service_o.row_id=row_id_i;
  assign service_o.row_acc=row_acc_i;
  assign service_o.row_scratch=row_scratch_i;
  assign service_o.row_result=row_result_i;
  assign service_o.row_a=row_a_i;
  assign service_o.row_s=row_s_i;
  assign service_o.row_a_id=row_a_id_i;
  assign service_o.row_s_id=row_s_id_i;
  assign row_done_valid_o=service_i.row_done_valid;
  assign service_o.row_done_ready=row_done_ready_i;
  assign row_done_code_o=service_i.row_done_code;
  assign row_completed_terms_o=service_i.row_completed_terms;
  assign row_done_id_o=service_i.row_done_id;
  assign row_done_region_o=service_i.row_done_region;
  assign encode_active=FULL_KEYGEN && state==REPORT && owned_r;
  assign raw_valid_i=encode_active?encode_raw_valid:seed_raw_valid;
  assign raw_mode_i=encode_active?encode_raw_mode:seed_raw_mode;
  assign raw_id_i=encode_active?encode_raw_id:seed_raw_id;
  assign raw_message_len_i=encode_active?encode_raw_message_len:seed_raw_message_len;
  assign raw_output_len_i=encode_active?encode_raw_output_len:seed_raw_output_len;
  assign raw_input_data_i=encode_active?encode_raw_input_data:seed_raw_input_data;
  assign raw_input_valid_i=encode_active?encode_raw_input_valid:seed_raw_input_valid;
  assign raw_output_ready_i=encode_active?encode_raw_output_ready:seed_raw_output_ready;
  assign raw_done_ready_i=encode_active?encode_raw_done_ready:seed_raw_done_ready;
  assign response_valid_o=!encode_active && base_response_valid;
  keygen_encode encoder(
    .pack_o(service_o.pack),.pack_i(service_i.pack),
    .clk(clk),.rst(rst),.start_valid_i(encode_active && !encode_started_r),.start_ready_o(encode_start_ready),
    .start_param_i(param_r),.start_id_i(done_id_o),.start_rho_i(rho_o),.start_key_i(key_o),
    .done_valid_o(encode_done),.done_ready_i(encode_active && done_valid_o && done_ready_i),.fault_o(encode_fault),
    .key_valid_o(key_valid_o),.key_ready_i(key_ready_i),.key_data_o(key_data_o),
    .key_bytes_o(key_bytes_o),.key_type_o(key_type_o),.key_last_o(key_last_o),.key_index_o(key_index_o),.key_id_o(key_id_o),
    .read_valid_o(encode_read_valid),.read_ready_i(base_read_ready),.read_region_o(encode_read_region),.read_word_o(encode_read_word),
    .response_valid_i(base_response_valid && encode_active),.response_ready_o(encode_response_ready),
    .response_error_i(response_error_o),.response_domain_i(response_ntt_domain_o),
    .response_region_i({response_bank_o,response_region_o}),.response_word_i(response_word_o),
    .response_id_i(response_id_o),.response_param_i(response_param_o),.response_mode_i(response_mode_o),.response_data_i(response_data_o),
    .raw_valid_o(encode_raw_valid),.raw_ready_i(raw_ready_o && encode_active),.raw_core_i(raw_core_o),
    .raw_mode_o(encode_raw_mode),.raw_id_o(encode_raw_id),.raw_message_len_o(encode_raw_message_len),.raw_output_len_o(encode_raw_output_len),
    .raw_input_data_o(encode_raw_input_data),.raw_input_valid_o(encode_raw_input_valid),.raw_input_ready_i(raw_input_ready_o && encode_active),
    .raw_output_valid_i(raw_output_valid_o && encode_active),.raw_output_core_i(raw_output_core_o),.raw_output_id_i(raw_output_id_o),
    .raw_output_data_i(raw_output_data_o),.raw_output_bytes_i(raw_output_bytes_o),.raw_output_ready_o(encode_raw_output_ready),
    .raw_done_valid_i(raw_done_valid_o && encode_active),.raw_done_core_i(raw_done_core_o),.raw_done_id_i(raw_done_id_o),.raw_done_ready_o(encode_raw_done_ready)
  );
  assign fault_o=controller_fault_r || base_fault || (FULL_KEYGEN && encode_fault);
  assign start_ready_o=!rst && state==IDLE && reserved_o==0 && !fault_o;
  assign busy_o=state!=IDLE;
  assign done_valid_o=!rst && state==REPORT && (!FULL_KEYGEN || !owned_r || encode_done) && !fault_o;
  assign row_result_valid_o=!rst && state==ROW_OUTPUT && !FULL_KEYGEN && !fault_o;
  assign row_result_index_o=index_r;assign row_result_region_o=6'd19;
  assign row_result_id_o=done_id_o+16'd512+16'(index_r);
  assign inspect_allowed=state==ROW_OUTPUT || state==REPORT;
  assign read_ready_o=inspect_allowed && !FULL_KEYGEN && base_read_ready && !fault_o;
  assign source_valid=state==SEED_CMD || state==SECRET_CMD || state==MATRIX_CMD;
  assign source_done_ready=state==SEED_REPLY || state==SECRET_REPLY || state==MATRIX_REPLY;
  assign source_op=state==SEED_CMD?2'd0:(state==SECRET_CMD?2'd2:2'd1);
  assign source_id=state==SEED_CMD?done_id_o:(state==SECRET_CMD?
    done_id_o+16'd16+16'(nonce_r):done_id_o+16'd128+16'(index_r)*16'd8+16'(column_r));
  assign source_nonce=16'(nonce_r);assign source_row=8'(index_r);assign source_column=8'(column_r);
  assign source_region=state==SECRET_CMD?(nonce_r<columns_r?6'd1+6'(nonce_r):
    6'd8+6'(nonce_r-columns_r)):6'd48+6'(column_r);
  assign op_valid_i=state==TRANSFORM_CMD;assign op_i=2'd3; // eligible small secrets
  assign op_a_region_i=6'd1+6'(column_r);assign op_b_region_i=op_a_region_i;
  assign op_dest_region_i=6'd32+6'(column_r);
  assign op_a_id_i=done_id_o+16'd16+16'(column_r);assign op_b_id_i=op_a_id_i;
  assign op_id_i=done_id_o+16'd64+16'(column_r);assign op_done_ready_i=state==TRANSFORM_REPLY;
  assign row_valid_i=state==ROW_CMD;assign row_done_ready_i=state==ROW_REPLY;
  assign row_param_i=param_r;assign row_index_i=index_r;
  assign row_id_i=done_id_o+16'd256+16'(index_r)*16'd32;
  assign row_acc_i=6'd16;assign row_scratch_i=6'd17;assign row_result_i=6'd18;
  for(genvar j=0;j<7;j++)begin:row_descriptors
    assign row_a_i[j]=6'd48+6'(j);assign row_s_i[j]=6'd32+6'(j);
    assign row_a_id_i[j]=done_id_o+16'd128+16'(index_r)*16'd8+16'(j);
    assign row_s_id_i[j]=done_id_o+16'd64+16'(j);
  end
  wire rounding=state==ROUND_CMD || state==ROUND_REPLY;
  assign process_valid_i=state==SUM_CMD || state==ROUND_CMD;
  assign process_op_i=rounding?2'd2:2'd0;assign process_inplace_i=0;
  assign process_a_i=rounding?6'd19:6'd18;assign process_b_i=6'd8+6'(index_r);
  assign process_dest_i=rounding?6'd56+6'(index_r):6'd19;
  assign process_high_i=rounding?6'd40+6'(index_r):6'd0;
  assign process_a_id_i=rounding?row_result_id_o:row_id_i;
  assign process_b_id_i=done_id_o+16'd16+16'(columns_r)+16'(index_r);
  assign process_id_i=rounding?done_id_o+16'd768+16'(index_r):row_result_id_o;
  assign process_done_ready_i=state==SUM_REPLY || state==ROUND_REPLY;
  assign release_valid_i=state==FREE_T || state==FREE_U || state==FREE_MATRIX ||
    state==FREE_RAW || state==FREE_HAT || state==FREE_S2 || state==FREE_LOW || state==FREE_HIGH;
  always_comb begin
    case(state)
      FREE_T:{release_bank_i,release_region_i}=6'd19;
      FREE_U:{release_bank_i,release_region_i}=6'd18;
      FREE_MATRIX:{release_bank_i,release_region_i}=6'd48+6'(cleanup_r);
      FREE_RAW:{release_bank_i,release_region_i}=6'd1+6'(cleanup_r);
      FREE_HAT:{release_bank_i,release_region_i}=6'd32+6'(cleanup_r);
      FREE_LOW:{release_bank_i,release_region_i}=6'd56+6'(cleanup_r);
      FREE_HIGH:{release_bank_i,release_region_i}=6'd40+6'(cleanup_r);
      default:{release_bank_i,release_region_i}=6'd8+6'(cleanup_r);
    endcase
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;param_r<=0;rows_r<=0;columns_r<=0;nonce_r<=0;column_r<=0;index_r<=0;cleanup_r<=0;
      xi_r<=0;done_id_o<=0;done_code_o<=0;owned_r<=0;controller_fault_r<=0;public_pending_r<=0;encode_started_r<=0;
    end else begin
      if(encode_active && !encode_started_r && encode_start_ready)encode_started_r<=1;
      if(response_valid_o && response_ready_i)public_pending_r<=0;
      if(read_valid_i && read_ready_o)public_pending_r<=1;
      case(state)
        IDLE:if(start_valid_i && start_ready_o)begin
          param_r<=start_param_i;xi_r<=start_seed_i;done_id_o<=start_id_i;done_code_o<=0;
          rows_r<=start_param_i==0?4:(start_param_i==1?6:8);
          columns_r<=start_param_i==0?4:(start_param_i==1?5:7);
          nonce_r<=0;column_r<=0;index_r<=0;cleanup_r<=0;owned_r<=start_param_i!=3;encode_started_r<=0;
          if(start_param_i==3)begin done_code_o<=1;state<=REPORT;end else state<=SEED_CMD;
        end
        SEED_CMD:if(source_ready)state<=SEED_REPLY;
        SEED_REPLY:if(source_done)begin
          if(source_code!=0 || source_done_id!=done_id_o)begin controller_fault_r<=1;state<=HALT;end
          else state<=SECRET_CMD;
        end
        SECRET_CMD:if(source_ready)state<=SECRET_REPLY;
        SECRET_REPLY:if(source_done)begin
          if(source_code!=0 || source_done_id!=done_id_o+16'd16+16'(nonce_r))begin controller_fault_r<=1;state<=HALT;end
          else if(nonce_r+1==rows_r+columns_r)begin column_r<=0;state<=TRANSFORM_CMD;end
          else begin nonce_r<=nonce_r+1'b1;state<=SECRET_CMD;end
        end
        TRANSFORM_CMD:if(op_ready_o)state<=TRANSFORM_REPLY;
        TRANSFORM_REPLY:if(op_done_valid_o)begin
          if(op_done_code_o!=0 || op_done_id_o!=op_id_i || op_done_region_o!=op_dest_region_i)begin controller_fault_r<=1;state<=HALT;end
          else if(column_r+1==columns_r)begin column_r<=0;state<=MATRIX_CMD;end
          else begin column_r<=column_r+1'b1;state<=TRANSFORM_CMD;end
        end
        MATRIX_CMD:if(source_ready)state<=MATRIX_REPLY;
        MATRIX_REPLY:if(source_done)begin
          if(source_code!=0 || source_done_id!=done_id_o+16'd128+16'(index_r)*16'd8+16'(column_r))begin controller_fault_r<=1;state<=HALT;end
          else if(column_r+1==columns_r)begin column_r<=0;state<=ROW_CMD;end
          else begin column_r<=column_r+1'b1;state<=MATRIX_CMD;end
        end
        ROW_CMD:if(row_ready_o)state<=ROW_REPLY;
        ROW_REPLY:if(row_done_valid_o)begin
          if(row_done_code_o!=0 || row_done_id_o!=row_id_i || row_done_region_o!=18 ||
             row_completed_terms_o!=3'(columns_r))begin controller_fault_r<=1;state<=HALT;end
          else state<=SUM_CMD;
        end
        SUM_CMD:if(process_ready_o)state<=SUM_REPLY;
        SUM_REPLY:if(process_done_valid_o)begin
          if(process_done_code_o!=0 || process_done_id_o!=row_result_id_o || process_done_dest_o!=19)begin controller_fault_r<=1;state<=HALT;end
          else state<=ROUNDED?ROUND_CMD:ROW_OUTPUT;
        end
        ROUND_CMD:if(process_ready_o)state<=ROUND_REPLY;
        ROUND_REPLY:if(process_done_valid_o)begin
          if(process_done_code_o!=0 || process_done_id_o!=process_id_i ||
             process_done_dest_o!=process_dest_i || process_done_high_o!=process_high_i)begin
            controller_fault_r<=1;state<=HALT;
          end else state<=ROW_OUTPUT;
        end
        ROW_OUTPUT:if(FULL_KEYGEN || row_result_ready_i)state<=WAIT_ROW_READ;
        WAIT_ROW_READ:if(!public_pending_r && !response_valid_o)state<=FREE_T;
        FREE_T:if(release_ready_o)state<=FREE_U;
        FREE_U:if(release_ready_o)begin cleanup_r<=0;state<=FREE_MATRIX;end
        FREE_MATRIX:if(release_ready_o)begin
          if(cleanup_r+1==columns_r)begin
            cleanup_r<=0;
            if(index_r+1==rows_r)state<=REPORT;
            else begin index_r<=index_r+1'b1;column_r<=0;state<=MATRIX_CMD;end
          end else cleanup_r<=cleanup_r+1'b1;
        end
        REPORT:if(done_valid_o && done_ready_i)state<=WAIT_FINAL_READ;
        WAIT_FINAL_READ:if(!public_pending_r && !response_valid_o)begin
          cleanup_r<=0;if(owned_r)state<=FREE_RAW;else state<=IDLE;
        end
        FREE_RAW:if(release_ready_o)begin
          if(cleanup_r+1==columns_r)begin cleanup_r<=0;state<=FREE_HAT;end else cleanup_r<=cleanup_r+1'b1;
        end
        FREE_HAT:if(release_ready_o)begin
          if(cleanup_r+1==columns_r)begin cleanup_r<=0;state<=FREE_S2;end else cleanup_r<=cleanup_r+1'b1;
        end
        FREE_S2:if(release_ready_o)begin
          if(cleanup_r+1==rows_r)begin
            cleanup_r<=0;
            if(ROUNDED)state<=FREE_LOW;else begin owned_r<=0;state<=IDLE;end
          end else cleanup_r<=cleanup_r+1'b1;
        end
        FREE_LOW:if(release_ready_o)begin
          if(cleanup_r+1==rows_r)begin cleanup_r<=0;state<=FREE_HIGH;end else cleanup_r<=cleanup_r+1'b1;
        end
        FREE_HIGH:if(release_ready_o)begin
          if(cleanup_r+1==rows_r)begin owned_r<=0;state<=IDLE;end else cleanup_r<=cleanup_r+1'b1;
        end
        default:state<=HALT;
      endcase
    end
  end
endmodule
`default_nettype wire
