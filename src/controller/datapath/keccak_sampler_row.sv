// Row scheduler and the single shared banked engine subsystem.
`default_nettype none
module keccak_sampler_row #(parameter bit RAW_SERVICE=0,SIGN_SERVICE=0) (
  input wire dilithium_service_pkg::sign_request_t sign_i,
  output dilithium_service_pkg::sign_response_t sign_o,
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
  output logic [5:0] process_done_dest_o,process_done_high_o,
  input wire logic row_valid_i,output logic row_ready_o,row_busy_o,
  input wire logic [1:0] row_param_i,input wire logic [3:0] row_index_i,
  input wire logic [15:0] row_id_i,
  input wire logic [5:0] row_acc_i,row_scratch_i,row_result_i,
  input wire logic [6:0][5:0] row_a_i,row_s_i,
  input wire logic [6:0][15:0] row_a_id_i,row_s_id_i,
  output logic row_done_valid_o,input wire logic row_done_ready_i,
  output logic [2:0] row_done_code_o,row_completed_terms_o,
  output logic [15:0] row_done_id_o,output logic [5:0] row_done_region_o
);

  logic base_job_ready,base_read_ready,base_response_valid,base_release_ready,base_raw_ready;
  logic base_op_ready,base_op_done_valid,base_process_ready,base_process_done_valid,base_fault;
  logic external_read_r,row_command_ready,row_fault,row_read_valid,row_read_ready,row_response_ready;
  logic row_ntt_valid,row_ntt_done_ready,row_process_valid,row_process_done_ready,row_release_valid;
  logic [1:0] row_ntt_op;
  logic [5:0] row_read_region,row_ntt_a,row_ntt_b,row_ntt_dest,row_process_a,row_process_b,row_release_region;
  logic [15:0] row_ntt_aid,row_ntt_bid,row_ntt_id,row_process_aid,row_process_bid,row_process_id;
  logic [63:0] base_complete,row_locks,row_hidden;
  dilithium_service_pkg::sign_request_t base_sign_request;
  dilithium_service_pkg::sign_response_t base_sign_response;
  always_comb begin
    base_sign_request=SIGN_SERVICE?sign_i:'0;
    base_sign_request.valid=SIGN_SERVICE && sign_i.valid && !row_busy_o && !row_valid_i;
    sign_o=base_sign_response;
    sign_o.ready=SIGN_SERVICE && !row_busy_o && !row_valid_i && base_sign_response.ready && !fault_o;
  end
  assign fault_o=base_fault || row_fault;
  assign row_ready_o=row_command_ready && !rst && active_o==0 && !op_busy_o && !process_busy_o &&
    !external_read_r && !base_response_valid && !base_sign_response.busy && !fault_o;
  assign job_ready_o=!row_busy_o && !row_valid_i && base_job_ready && !fault_o;
  assign op_ready_o=!row_busy_o && !row_valid_i && base_op_ready && !fault_o;
  assign process_ready_o=!row_busy_o && !row_valid_i && base_process_ready && !fault_o;
  assign read_ready_o=!row_busy_o && !row_valid_i && base_read_ready && !fault_o;
  assign response_valid_o=!row_busy_o && base_response_valid;
  assign release_ready_o=!row_busy_o && !row_valid_i && base_release_ready && !fault_o;
  assign op_done_valid_o=!row_busy_o && base_op_done_valid;
  assign process_done_valid_o=!row_busy_o && base_process_done_valid;
  assign complete_o=base_complete & ~row_hidden;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)external_read_r<=0;
    else begin
      if(read_valid_i && read_ready_o)external_read_r<=1;
      if(response_valid_o && response_ready_i)external_read_r<=0;
    end
  end
  assign raw_ready_o=!row_busy_o && !row_valid_i && base_raw_ready && !fault_o;
  keccak_sampler_ntt_banks #(.PROCESS_SERVICE(1),.RAW_SERVICE(RAW_SERVICE),.SIGN_SERVICE(SIGN_SERVICE)) subsystem(
    .sign_i(base_sign_request),.sign_o(base_sign_response),
    .raw_valid_i(RAW_SERVICE && raw_valid_i && !row_busy_o && !row_valid_i),.raw_ready_o(base_raw_ready),
    .job_valid_i(job_valid_i && !row_busy_o && !row_valid_i),.job_ready_o(base_job_ready),
    .input_valid_i(input_valid_i && !row_busy_o),
    .op_valid_i(row_busy_o?row_ntt_valid:(op_valid_i && !row_valid_i)),.op_ready_o(base_op_ready),
    .op_i(row_busy_o?row_ntt_op:op_i),.op_a_region_i(row_busy_o?row_ntt_a:op_a_region_i),
    .op_b_region_i(row_busy_o?row_ntt_b:op_b_region_i),.op_dest_region_i(row_busy_o?row_ntt_dest:op_dest_region_i),
    .op_a_id_i(row_busy_o?row_ntt_aid:op_a_id_i),.op_b_id_i(row_busy_o?row_ntt_bid:op_b_id_i),
    .op_id_i(row_busy_o?row_ntt_id:op_id_i),.op_done_valid_o(base_op_done_valid),
    .op_done_ready_i(row_busy_o?row_ntt_done_ready:op_done_ready_i),
    .process_valid_i(row_busy_o?row_process_valid:(process_valid_i && !row_valid_i)),.process_ready_o(base_process_ready),
    .process_op_i(row_busy_o?2'd0:process_op_i),.process_inplace_i(row_busy_o?1'b1:process_inplace_i),
    .process_a_i(row_busy_o?row_process_a:process_a_i),.process_b_i(row_busy_o?row_process_b:process_b_i),
    .process_dest_i(row_busy_o?row_process_a:process_dest_i),.process_high_i(row_busy_o?6'd0:process_high_i),
    .process_a_id_i(row_busy_o?row_process_aid:process_a_id_i),.process_b_id_i(row_busy_o?row_process_bid:process_b_id_i),
    .process_id_i(row_busy_o?row_process_id:process_id_i),.process_done_valid_o(base_process_done_valid),
    .process_done_ready_i(row_busy_o?row_process_done_ready:process_done_ready_i),
    .read_valid_i(row_busy_o?row_read_valid:(read_valid_i && !row_valid_i)),.read_ready_o(base_read_ready),
    .read_bank_i(row_busy_o?row_read_region[5:4]:read_bank_i),.read_region_i(row_busy_o?row_read_region[3:0]:read_region_i),
    .read_word_i(row_busy_o?6'd0:read_word_i),.response_valid_o(base_response_valid),
    .response_ready_i(row_busy_o?row_response_ready:response_ready_i),
    .release_valid_i(row_busy_o?row_release_valid:(release_valid_i && !row_valid_i)),.release_ready_o(base_release_ready),
    .release_bank_i(row_busy_o?row_release_region[5:4]:release_bank_i),
    .release_region_i(row_busy_o?row_release_region[3:0]:release_region_i),
    .complete_o(base_complete),.fault_o(base_fault),.*
  );
  row_accumulate controller(
    .clk(clk),.rst(rst),.command_valid_i(row_valid_i && row_ready_o),.command_ready_o(row_command_ready),
    .busy_o(row_busy_o),.fault_o(row_fault),.command_param_i(row_param_i),.command_row_i(row_index_i),.command_id_i(row_id_i),
    .command_acc_i(row_acc_i),.command_scratch_i(row_scratch_i),.command_result_i(row_result_i),
    .command_a_i(row_a_i),.command_s_i(row_s_i),.command_a_id_i(row_a_id_i),.command_s_id_i(row_s_id_i),
    .reserved_i(reserved_o),.done_valid_o(row_done_valid_o),.done_ready_i(row_done_ready_i),
    .done_code_o(row_done_code_o),.done_id_o(row_done_id_o),.done_region_o(row_done_region_o),.completed_terms_o(row_completed_terms_o),
    .locks_o(row_locks),.hidden_o(row_hidden),.read_valid_o(row_read_valid),.read_region_o(row_read_region),
    .read_ready_i(base_read_ready),.response_valid_i(base_response_valid),.response_error_i(response_error_o),
    .response_region_i({response_bank_o,response_region_o}),.response_word_i(response_word_o),.response_id_i(response_id_o),
    .response_param_i(response_param_o),.response_domain_i(response_ntt_domain_o),.response_ready_o(row_response_ready),
    .ntt_valid_o(row_ntt_valid),.ntt_ready_i(base_op_ready),.ntt_op_o(row_ntt_op),.ntt_a_o(row_ntt_a),.ntt_b_o(row_ntt_b),
    .ntt_dest_o(row_ntt_dest),.ntt_a_id_o(row_ntt_aid),.ntt_b_id_o(row_ntt_bid),.ntt_id_o(row_ntt_id),
    .ntt_done_valid_i(base_op_done_valid),.ntt_done_ready_o(row_ntt_done_ready),.ntt_done_code_i(op_done_code_o),
    .ntt_done_id_i(op_done_id_o),.ntt_done_region_i(op_done_region_o),
    .process_valid_o(row_process_valid),.process_ready_i(base_process_ready),.process_a_o(row_process_a),.process_b_o(row_process_b),
    .process_a_id_o(row_process_aid),.process_b_id_o(row_process_bid),.process_id_o(row_process_id),
    .process_done_valid_i(base_process_done_valid),.process_done_ready_o(row_process_done_ready),.process_done_code_i(process_done_code_o),
    .process_done_id_i(process_done_id_o),.process_done_region_i(process_done_dest_o),
    .release_valid_o(row_release_valid),.release_region_o(row_release_region),.release_ready_i(base_release_ready)
  );
endmodule
`default_nettype wire
