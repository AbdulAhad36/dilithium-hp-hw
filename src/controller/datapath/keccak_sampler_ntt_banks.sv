// Sequential sampling/NTT client over the four LightHD-shaped banks.
// Source leases belong to this controller. No external access bypasses it.
`default_nettype none
module keccak_sampler_ntt_banks #(parameter bit PROCESS_SERVICE=0, RAW_SERVICE=0,SIGN_SERVICE=0) (
  input wire dilithium_service_pkg::sign_request_t sign_i,
  output wire dilithium_service_pkg::sign_response_t sign_o,
  input wire logic raw_valid_i,output logic raw_ready_o,raw_core_o,
  input wire logic raw_mode_i,input wire logic [15:0] raw_id_i,raw_message_len_i,raw_output_len_i,
  input wire logic [63:0] raw_input_data_i,input wire logic raw_input_valid_i,output logic raw_input_ready_o,
  output logic raw_output_valid_o,raw_output_core_o,output logic [15:0] raw_output_id_o,
  output logic [127:0] raw_output_data_o,output logic [4:0] raw_output_bytes_o,input wire logic raw_output_ready_i,
  output logic raw_done_valid_o,raw_done_core_o,output logic [15:0] raw_done_id_o,input wire logic raw_done_ready_i,
  input wire logic clk,rst,job_valid_i,
  output logic job_ready_o,job_core_o,
  input wire logic [1:0] job_bank_i,job_mode_i,job_param_i,
  input wire logic [3:0] job_region_i,
  input wire logic [15:0] job_id_i,message_len_i,
  input wire logic [63:0] input_data_i,
  input wire logic input_valid_i,output logic input_ready_o,
  output logic status_valid_o,status_core_o,
  output logic [15:0] status_id_o,output logic [2:0] status_code_o,
  input wire logic status_ready_i,output logic [1:0] active_o,
  input wire logic read_valid_i,input wire logic [1:0] read_bank_i,
  input wire logic [3:0] read_region_i,input wire logic [5:0] read_word_i,
  output logic read_ready_o,response_valid_o,response_error_o,
  output logic [1:0] response_bank_o,response_mode_o,response_param_o,
  output logic [3:0] response_region_o,output logic [5:0] response_word_o,
  output logic [91:0] response_data_o,output logic [15:0] response_id_o,
  output logic response_ntt_domain_o,response_small_o,input wire logic response_ready_i,
  input wire logic release_valid_i,input wire logic [1:0] release_bank_i,
  input wire logic [3:0] release_region_i,output logic release_ready_o,
  output logic [63:0] reserved_o,complete_o,output logic fault_o,
  input wire logic op_valid_i,output logic op_ready_o,op_busy_o,
  input wire logic [1:0] op_i,
  // Flat region = {bank[1:0],region[3:0]}; destination must differ from sources.
  input wire logic [5:0] op_a_region_i,op_b_region_i,op_dest_region_i,
  input wire logic [15:0] op_a_id_i,op_b_id_i,op_id_i,
  output logic op_done_valid_o,input wire logic op_done_ready_i,
  output logic [2:0] op_done_code_o,output logic [15:0] op_done_id_o,
  output logic [5:0] op_done_region_o,
  input wire logic process_valid_i,output logic process_ready_o,process_busy_o,
  input wire logic [1:0] process_op_i,input wire logic process_inplace_i,
  input wire logic [5:0] process_a_i,process_b_i,process_dest_i,process_high_i,
  input wire logic [15:0] process_a_id_i,process_b_id_i,process_id_i,
  output logic process_done_valid_o,input wire logic process_done_ready_i,
  output logic [2:0] process_done_code_o,output logic [15:0] process_done_id_o,
  output logic [5:0] process_done_dest_o,process_done_high_o
);
  typedef enum logic [3:0] {IDLE,CHECK_REQUEST,CHECK_RESPONSE,ALLOCATE,START,
    READ_REQUEST,READ_RESPONSE,WAIT_ENGINE,COMMIT,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] operation_r,mode_r,param_r,lane_r;
  logic [5:0] a_r,b_r,dest_r,source_region,mem_read_region;
  logic [15:0] a_id_r,b_id_r,id_r;
  logic [2:0] code_r;
  logic operand_b_r,controller_fault_r,external_read_pending_r,destination_owned_r;
  logic [5:0] load_word_r;
  logic [8:0] result_count_r;
  logic producer_ready,alloc_ready,finish_ready,command_fire,raw_access,producer_raw_ready;
  logic coeff_valid,coeff_ready,coeff_core,coeff_last;
  logic [15:0] coeff_id;logic [7:0] coeff_index;logic [22:0] coeff_data;
  logic producer_status_valid,mem_fault,mem_release_ready;
  logic mem_read_valid,mem_read_ready,mem_response_valid,mem_response_ready;
  logic [5:0] mem_read_word;
  logic [63:0] store_complete,source_leases;
  logic idle_access,release_allowed,validate_response,source_bad,domain_bad;
  logic ntt_start,ntt_busy,ntt_done,s_valid,s_ready,m_valid,m_ready,m_last;
  logic [22:0] s_data,m_data;
  logic result_ready;
  logic p_request,p_accept,p_ready,p_fault,p_alloc_valid,p_alloc_core,p_domain,p_rewrite;
  logic p_read_valid,p_response_ready,p_write_valid,p_write_core,p_write_last,p_finish_valid,p_finish_core;
  logic [5:0] p_alloc_region,p_read_region,p_read_word;
  logic [15:0] p_alloc_id,p_write_id,p_finish_id;
  logic [1:0] p_mode,p_param;logic [7:0] p_write_index;logic [22:0] p_write_data;
  logic [63:0] p_locks,p_hidden;
  logic s_request,s_accept,s_cmd_ready,s_fault,s_alloc_valid,s_alloc_core,s_domain,s_rewrite;
  logic s_read_valid,s_response_ready,s_write_valid,s_write_core,s_write_last,s_finish_valid,s_finish_core;
  logic [5:0] s_alloc_region,s_read_region,s_read_word;
  logic [15:0] s_alloc_id,s_write_id,s_finish_id;
  logic [1:0] s_mode,s_param;logic [7:0] s_write_index;logic [22:0] s_write_data;
  logic [2:0] s_finish_code;logic [63:0] s_locks,s_hidden;
  logic client_busy,c_alloc_valid,c_alloc_core,c_domain,c_rewrite;
  logic c_read_valid,c_response_ready,c_write_valid,c_write_core,c_write_last,c_finish_valid,c_finish_core;
  logic [5:0] c_alloc_region,c_read_region,c_read_word;
  logic [15:0] c_alloc_id,c_write_id,c_finish_id;
  logic [1:0] c_mode,c_param;logic [7:0] c_write_index;logic [22:0] c_write_data;
  logic [2:0] c_finish_code;
  assign s_request=SIGN_SERVICE && sign_i.valid;
  assign sign_o.ready=SIGN_SERVICE && s_cmd_ready && idle_access && active_o==0 &&
    !mem_response_valid && !external_read_pending_r && !op_valid_i && !p_request && !process_busy_o && !fault_o;
  assign s_accept=s_request && sign_o.ready;
  assign client_busy=process_busy_o || sign_o.busy;
  assign {c_alloc_valid,c_alloc_core,c_domain,c_rewrite,c_read_valid,c_response_ready,
    c_write_valid,c_write_core,c_write_last,c_finish_valid,c_finish_core,c_alloc_region,c_read_region,c_read_word,
    c_alloc_id,c_write_id,c_finish_id,c_mode,c_param,c_write_index,c_write_data,c_finish_code}=
    sign_o.busy?{s_alloc_valid,s_alloc_core,s_domain,s_rewrite,s_read_valid,s_response_ready,
      s_write_valid,s_write_core,s_write_last,s_finish_valid,s_finish_core,s_alloc_region,s_read_region,s_read_word,
      s_alloc_id,s_write_id,s_finish_id,s_mode,s_param,s_write_index,s_write_data,s_finish_code}:
      {p_alloc_valid,p_alloc_core,p_domain,p_rewrite,p_read_valid,p_response_ready,
      p_write_valid,p_write_core,p_write_last,p_finish_valid,p_finish_core,p_alloc_region,p_read_region,p_read_word,
      p_alloc_id,p_write_id,p_finish_id,p_mode,p_param,p_write_index,p_write_data,3'd0};

  assign idle_access=state==IDLE;
  assign fault_o=mem_fault || controller_fault_r || p_fault || s_fault;
  assign op_ready_o=!rst && idle_access && active_o==0 && !mem_response_valid &&
    !external_read_pending_r && !client_busy && !fault_o;
  assign op_busy_o=!idle_access;
  assign p_request=PROCESS_SERVICE && process_valid_i;
  assign process_ready_o=PROCESS_SERVICE && p_ready && idle_access && active_o==0 &&
    !mem_response_valid && !external_read_pending_r && !op_valid_i && !sign_o.busy && !fault_o;
  assign p_accept=p_request && process_ready_o;
  assign job_ready_o=idle_access && !op_valid_i && !p_request && !s_request && !client_busy && producer_ready && alloc_ready && !fault_o;
  assign command_fire=job_valid_i && job_ready_o;
  assign status_valid_o=producer_status_valid && finish_ready && !fault_o;
  assign op_done_valid_o=!rst && state==REPORT && !fault_o;
  assign op_done_code_o=code_r;assign op_done_id_o=id_r;assign op_done_region_o=dest_r;
  assign source_region=operand_b_r?b_r:a_r;
  always_comb begin
    source_leases=0;
    if(!idle_access)begin source_leases[a_r]=1;if(operation_r==2)source_leases[b_r]=1;end
  end
  assign complete_o=store_complete & ~source_leases & ~p_hidden & ~s_hidden;
  // The acceptance edge also protects sources; unrelated regions may be freed
  // while a command waits for its explicitly selected destination.
  assign release_allowed=!source_leases[{release_bank_i,release_region_i}] &&
    !p_locks[{release_bank_i,release_region_i}] &&
    !s_locks[{release_bank_i,release_region_i}] &&
    !(s_accept && ({release_bank_i,release_region_i}==sign_i.a ||
      (sign_i.op==2 && {release_bank_i,release_region_i}==sign_i.b))) &&
    !(p_accept && ({release_bank_i,release_region_i}==process_a_i ||
      (process_op_i<2 && {release_bank_i,release_region_i}==process_b_i))) &&
    !(destination_owned_r && {release_bank_i,release_region_i}==dest_r) &&
    !(op_valid_i && op_ready_o && ({release_bank_i,release_region_i}==op_a_region_i ||
      (op_i==2 && {release_bank_i,release_region_i}==op_b_region_i)));
  assign release_ready_o=release_allowed && mem_release_ready;
  assign mem_read_valid=state==CHECK_REQUEST || state==READ_REQUEST ||
    (idle_access && !op_valid_i && !p_request && !s_request && !client_busy && read_valid_i);
  assign mem_read_region=idle_access?{read_bank_i,read_region_i}:source_region;
  assign mem_read_word=state==CHECK_REQUEST?6'd0:(idle_access?read_word_i:load_word_r);
  assign read_ready_o=idle_access && !op_valid_i && !p_request && !s_request && !client_busy && mem_read_ready;
  assign response_valid_o=idle_access && !client_busy && mem_response_valid;
  assign mem_response_ready=client_busy?c_response_ready:(state==CHECK_RESPONSE ||
    (state==READ_RESPONSE && s_ready && lane_r==3) || (idle_access && response_ready_i));
  assign validate_response=state==CHECK_RESPONSE && mem_response_valid;
  assign source_bad=response_error_o || {response_bank_o,response_region_o}!=source_region ||
    response_id_o!=(operand_b_r?b_id_r:a_id_r) || response_word_o!=0;
  assign domain_bad=operand_b_r ? (!response_ntt_domain_o || response_param_o!=param_r) :
    (((operation_r==0 || operation_r==3) && response_ntt_domain_o) ||
     ((operation_r==1 || operation_r==2) && !response_ntt_domain_o) ||
     (operation_r==3 && !response_small_o));
  assign ntt_start=state==START && !rst;
  assign s_valid=state==READ_RESPONSE && mem_response_valid && !response_error_o;
  assign s_data=response_data_o[23*lane_r+:23];
  assign m_ready=state==WAIT_ENGINE && result_ready;

  // Finite seed hashes use the same physical cores. Compute arbitration wins;
  // raw requests then win over sampling inside the producer (no bank allocation).
  assign raw_access=RAW_SERVICE && idle_access && !op_valid_i && !p_request && !s_request && !client_busy && !fault_o;
  assign raw_ready_o=raw_access && producer_raw_ready;
  keccak_sampler #(.RAW_SERVICE(RAW_SERVICE)) producer(
    .clk(clk),.rst(rst),.job_valid_i(command_fire),.job_ready_o(producer_ready),.job_core_o(job_core_o),
    .job_id_i(job_id_i),.message_len_i(message_len_i),.job_mode_i(job_mode_i),.job_param_i(job_param_i),
    .input_data_i(input_data_i),.input_valid_i(input_valid_i && idle_access),.input_ready_o(input_ready_o),
    .output_data_o(coeff_data),.output_core_o(coeff_core),.output_last_o(coeff_last),.output_valid_o(coeff_valid),
    .output_id_o(coeff_id),.output_index_o(coeff_index),.output_ready_i(coeff_ready),
    .status_valid_o(producer_status_valid),.status_core_o(status_core_o),.status_id_o(status_id_o),.status_code_o(status_code_o),
    .status_ready_i(status_ready_i && finish_ready && !fault_o),.active_o(active_o),
    .raw_valid_i(raw_valid_i && raw_access),.raw_ready_o(producer_raw_ready),.raw_core_o(raw_core_o),.raw_mode_i(raw_mode_i),
    .raw_id_i(raw_id_i),.raw_message_len_i(raw_message_len_i),.raw_output_len_i(raw_output_len_i),
    .raw_input_data_i(raw_input_data_i),.raw_input_valid_i(raw_input_valid_i),.raw_input_ready_o(raw_input_ready_o),
    .raw_output_valid_o(raw_output_valid_o),.raw_output_core_o(raw_output_core_o),.raw_output_id_o(raw_output_id_o),
    .raw_output_data_o(raw_output_data_o),.raw_output_bytes_o(raw_output_bytes_o),.raw_output_ready_i(raw_output_ready_i),
    .raw_done_valid_o(raw_done_valid_o),.raw_done_core_o(raw_done_core_o),.raw_done_id_o(raw_done_id_o),.raw_done_ready_i(raw_done_ready_i)
  );
  memory store(
    .clk(clk),.rst(rst),.alloc_valid_i(client_busy?c_alloc_valid:(command_fire || state==ALLOCATE)),
    .alloc_core_i(client_busy?c_alloc_core:(idle_access?job_core_o:1'b0)),
    .alloc_bank_i(client_busy?c_alloc_region[5:4]:(idle_access?job_bank_i:dest_r[5:4])),
    .alloc_region_i(client_busy?c_alloc_region[3:0]:(idle_access?job_region_i:dest_r[3:0])),
    .alloc_id_i(client_busy?c_alloc_id:(idle_access?job_id_i:id_r)),
    .alloc_mode_i(client_busy?c_mode:(idle_access?job_mode_i:mode_r)),
    .alloc_param_i(client_busy?c_param:(idle_access?job_param_i:param_r)),.alloc_ready_o(alloc_ready),
    .alloc_compute_i(client_busy || !idle_access),.alloc_ntt_domain_i(client_busy?c_domain:operation_r!=1),
    .alloc_rewrite_i(client_busy && c_rewrite),
    .write_valid_i(client_busy?c_write_valid:(idle_access?coeff_valid:(m_valid && state==WAIT_ENGINE))),
    .write_core_i(client_busy?c_write_core:(idle_access?coeff_core:1'b0)),
    .write_last_i(client_busy?c_write_last:(idle_access?coeff_last:m_last)),
    .write_id_i(client_busy?c_write_id:(idle_access?coeff_id:id_r)),
    .write_index_i(client_busy?c_write_index:(idle_access?coeff_index:result_count_r[7:0])),
    .write_data_i(client_busy?c_write_data:(idle_access?coeff_data:m_data)),.write_ready_o(result_ready),
    .finish_valid_i(client_busy?c_finish_valid:(idle_access?(producer_status_valid && status_ready_i):state==COMMIT)),
    .finish_core_i(client_busy?c_finish_core:(idle_access?status_core_o:1'b0)),
    .finish_id_i(client_busy?c_finish_id:(idle_access?status_id_o:id_r)),
    .finish_code_i(client_busy?c_finish_code:(idle_access?status_code_o:3'd0)),.finish_ready_o(finish_ready),
    .read_valid_i(client_busy?c_read_valid:mem_read_valid),
    .read_bank_i(client_busy?c_read_region[5:4]:mem_read_region[5:4]),
    .read_region_i(client_busy?c_read_region[3:0]:mem_read_region[3:0]),
    .read_word_i(client_busy?c_read_word:mem_read_word),.read_ready_o(mem_read_ready),.response_valid_o(mem_response_valid),
    .response_error_o(response_error_o),.response_bank_o(response_bank_o),.response_region_o(response_region_o),
    .response_word_o(response_word_o),.response_data_o(response_data_o),.response_id_o(response_id_o),
    .response_mode_o(response_mode_o),.response_param_o(response_param_o),
    .response_ntt_domain_o(response_ntt_domain_o),.response_small_o(response_small_o),.response_ready_i(mem_response_ready),
    .release_valid_i(release_valid_i && release_allowed),.release_bank_i(release_bank_i),.release_region_i(release_region_i),
    .release_ready_o(mem_release_ready),.reserved_o(reserved_o),.complete_o(store_complete),.fault_o(mem_fault)
  );
  assign coeff_ready=idle_access && !client_busy && result_ready;
  sign_process_dma sign_client(
    .clk(clk),.rst(rst),.command_valid_i(s_accept),.command_ready_o(s_cmd_ready),.busy_o(sign_o.busy),.fault_o(s_fault),
    .command_op_i(sign_i.op),.command_param_i(sign_i.param),.command_kind_i(sign_i.kind),
    .command_a_i(sign_i.a),.command_b_i(sign_i.b),.command_dest_i(sign_i.dest),.command_high_i(sign_i.high),
    .command_a_id_i(sign_i.a_id),.command_b_id_i(sign_i.b_id),.command_id_i(sign_i.id),
    .done_valid_o(sign_o.done_valid),.done_ready_i(sign_i.done_ready),.done_code_o(sign_o.done_code),
    .done_id_o(sign_o.done_id),.done_dest_o(sign_o.done_dest),.done_high_o(sign_o.done_high),
    .done_reject_o(sign_o.done_reject),.done_weight_o(sign_o.done_weight),
    .reserved_i(reserved_o),.release_locks_o(s_locks),.hidden_o(s_hidden),
    .alloc_valid_o(s_alloc_valid),.alloc_core_o(s_alloc_core),.alloc_region_o(s_alloc_region),.alloc_id_o(s_alloc_id),
    .alloc_mode_o(s_mode),.alloc_param_o(s_param),.alloc_domain_o(s_domain),.alloc_rewrite_o(s_rewrite),.alloc_ready_i(alloc_ready),
    .read_valid_o(s_read_valid),.read_region_o(s_read_region),.read_word_o(s_read_word),.read_ready_i(mem_read_ready),
    .response_valid_i(mem_response_valid),.response_error_i(response_error_o),
    .response_region_i({response_bank_o,response_region_o}),.response_word_i(response_word_o),.response_data_i(response_data_o),
    .response_id_i(response_id_o),.response_mode_i(response_mode_o),.response_param_i(response_param_o),
    .response_domain_i(response_ntt_domain_o),.response_ready_o(s_response_ready),
    .write_valid_o(s_write_valid),.write_core_o(s_write_core),.write_last_o(s_write_last),.write_id_o(s_write_id),
    .write_index_o(s_write_index),.write_data_o(s_write_data),.write_ready_i(result_ready),
    .finish_valid_o(s_finish_valid),.finish_core_o(s_finish_core),.finish_id_o(s_finish_id),
    .finish_code_o(s_finish_code),.finish_ready_i(finish_ready)
  );
  poly_process_dma process_client(
    .clk(clk),.rst(rst),.command_valid_i(p_accept),.command_ready_o(p_ready),.busy_o(process_busy_o),.fault_o(p_fault),
    .command_op_i(process_op_i),.command_inplace_i(process_inplace_i),.command_a_i(process_a_i),.command_b_i(process_b_i),
    .command_dest_i(process_dest_i),.command_high_i(process_high_i),
    .command_a_id_i(process_a_id_i),.command_b_id_i(process_b_id_i),.command_id_i(process_id_i),
    .done_valid_o(process_done_valid_o),.done_ready_i(process_done_ready_i),.done_code_o(process_done_code_o),
    .done_id_o(process_done_id_o),.done_dest_o(process_done_dest_o),.done_high_o(process_done_high_o),
    .reserved_i(reserved_o),.release_locks_o(p_locks),.hidden_o(p_hidden),
    .alloc_valid_o(p_alloc_valid),.alloc_core_o(p_alloc_core),.alloc_region_o(p_alloc_region),.alloc_id_o(p_alloc_id),
    .alloc_mode_o(p_mode),.alloc_param_o(p_param),.alloc_domain_o(p_domain),.alloc_rewrite_o(p_rewrite),.alloc_ready_i(alloc_ready),
    .read_valid_o(p_read_valid),.read_region_o(p_read_region),.read_word_o(p_read_word),.read_ready_i(mem_read_ready),
    .response_valid_i(mem_response_valid),.response_error_i(response_error_o),
    .response_region_i({response_bank_o,response_region_o}),.response_word_i(response_word_o),.response_data_i(response_data_o),
    .response_id_i(response_id_o),.response_mode_i(response_mode_o),.response_param_i(response_param_o),
    .response_domain_i(response_ntt_domain_o),.response_ready_o(p_response_ready),
    .write_valid_o(p_write_valid),.write_core_o(p_write_core),.write_last_o(p_write_last),.write_id_o(p_write_id),
    .write_index_o(p_write_index),.write_data_o(p_write_data),.write_ready_i(result_ready),
    .finish_valid_o(p_finish_valid),.finish_core_o(p_finish_core),.finish_id_o(p_finish_id),.finish_ready_i(finish_ready)
  );
  ntt_engine engine(
    .clk(clk),.rst(rst),.start_i(ntt_start),.op_i(ntt_pkg::ntt_op_e'(operation_r)),.busy_o(ntt_busy),.done_o(ntt_done),
    .s_tdata(s_data),.s_tvalid(s_valid),.s_tready(s_ready),.s_tlast(load_word_r==63 && lane_r==3),
    .m_tdata(m_data),.m_tvalid(m_valid),.m_tready(m_ready),.m_tlast(m_last)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;operation_r<=0;mode_r<=0;param_r<=0;lane_r<=0;
      a_r<=0;b_r<=0;dest_r<=0;a_id_r<=0;b_id_r<=0;id_r<=0;code_r<=0;
      operand_b_r<=0;load_word_r<=0;result_count_r<=0;controller_fault_r<=0;external_read_pending_r<=0;destination_owned_r<=0;
    end else begin
      if(read_valid_i && read_ready_o)external_read_pending_r<=1;
      if(response_valid_o && response_ready_i)external_read_pending_r<=0;
      case(state)
        IDLE:if(op_valid_i && op_ready_o)begin
          operation_r<=op_i;a_r<=op_a_region_i;b_r<=op_b_region_i;dest_r<=op_dest_region_i;
          a_id_r<=op_a_id_i;b_id_r<=op_b_id_i;id_r<=op_id_i;operand_b_r<=0;code_r<=0;
          destination_owned_r<=0;
          if(op_dest_region_i==op_a_region_i || (op_i==2 && op_dest_region_i==op_b_region_i))begin
            code_r<=3;state<=REPORT;
          end else state<=CHECK_REQUEST;
        end
        CHECK_REQUEST:if(mem_read_ready)state<=CHECK_RESPONSE;
        CHECK_RESPONSE:if(validate_response)begin
          if(source_bad)begin code_r<=1;state<=REPORT;end
          else if(domain_bad)begin code_r<=2;state<=REPORT;end
          else if(operation_r==2 && !operand_b_r)begin
            mode_r<=response_mode_o;param_r<=response_param_o;operand_b_r<=1;state<=CHECK_REQUEST;
          end else begin
            if(!operand_b_r)begin mode_r<=response_mode_o;param_r<=response_param_o;end
            operand_b_r<=0;state<=ALLOCATE;
          end
        end
        ALLOCATE:if(alloc_ready)begin destination_owned_r<=1;load_word_r<=0;lane_r<=0;result_count_r<=0;state<=START;end
        START:state<=READ_REQUEST;
        READ_REQUEST:if(mem_read_ready)state<=READ_RESPONSE;
        READ_RESPONSE:if(mem_response_valid)begin
          if(response_error_o || {response_bank_o,response_region_o}!=source_region ||
             response_id_o!=(operand_b_r?b_id_r:a_id_r) || response_word_o!=load_word_r)begin
            controller_fault_r<=1;state<=HALT;
          end else if(s_ready)begin
            lane_r<=lane_r+2'd1;
            if(lane_r==3)begin
              if(load_word_r==63)begin
                if(operation_r==2 && !operand_b_r)begin operand_b_r<=1;load_word_r<=0;state<=READ_REQUEST;end
                else state<=WAIT_ENGINE;
              end else begin load_word_r<=load_word_r+6'd1;state<=READ_REQUEST;end
            end
          end
        end
        WAIT_ENGINE:begin
          if(m_valid && m_ready)result_count_r<=result_count_r+9'd1;
          if(ntt_done)begin
            if(result_count_r==256)state<=COMMIT;
            else begin controller_fault_r<=1;state<=HALT;end
          end
        end
        COMMIT:if(finish_ready)state<=REPORT;
        REPORT:if(op_done_ready_i)begin destination_owned_r<=0;state<=IDLE;end
        HALT:state<=HALT;
        default:begin controller_fault_r<=1;state<=HALT;end
      endcase
      if(mem_fault)begin controller_fault_r<=1;state<=HALT;end
    end
  end
endmodule
`default_nettype wire
