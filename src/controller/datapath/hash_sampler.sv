// The accepted physical dual Keccak/sampler with direct Figure5/B-port writes.
// Final FIPS absorption messages arrive on the existing64-bit stream. Finite
// raw hashes share those SAME two cores;no private KeyGen/Sign/Verify hash.
`default_nettype none
module hash_sampler (
  input wire logic clk,rst,job_valid_i,output logic job_ready_o,job_core_o,
  input wire logic job_batch_last_i,input wire logic [1:0] job_mode_i,job_param_i,job_bank_i,
  input wire logic [9:0] job_base_i,input wire logic [15:0] job_id_i,message_len_i,
  input wire logic [63:0] input_data_i,input wire logic input_valid_i,output logic input_ready_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic done_core_o,output logic [15:0] done_id_o,output logic [2:0] done_code_o,
  output logic fault_o,output logic [1:0] active_o,output logic idle_o,
  input wire logic raw_valid_i,output logic raw_ready_o,raw_core_o,
  input wire logic raw_mode_i,input wire logic [15:0] raw_id_i,raw_message_len_i,raw_output_len_i,
  input wire logic [63:0] raw_input_data_i,input wire logic raw_input_valid_i,output logic raw_input_ready_o,
  output logic raw_output_valid_o,raw_output_core_o,output logic [15:0] raw_output_id_o,
  output logic [127:0] raw_output_data_o,output logic [4:0] raw_output_bytes_o,input wire logic raw_output_ready_i,
  output logic raw_done_valid_o,raw_done_core_o,output logic [15:0] raw_done_id_o,input wire logic raw_done_ready_i,
  input wire logic load_valid_i,output logic load_ready_o,input wire logic [2:0] load_op_i,
  input wire logic [1:0] load_param_i,load_bank_i,input wire logic [9:0] load_base_i,input wire logic [15:0] load_id_i,
  input wire logic load_input_valid_i,output logic load_input_ready_o,input wire logic [63:0] load_input_data_i,
  input wire logic [6:0] load_input_index_i,input wire logic [3:0] load_input_bytes_i,input wire logic load_input_last_i,
  output logic load_done_valid_o,input wire logic load_done_ready_i,output logic [2:0] load_done_code_o,
  output logic [15:0] load_done_id_o,
  output logic [1:0] memory_command_valid_o,input wire logic [1:0] memory_command_ready_i,
  output logic [1:0][3:0] memory_command_mask_o,memory_command_write_o,
  output logic [1:0][3:0][9:0] memory_command_base_o,
  output logic [1:0][3:0][10:0] memory_command_words_o,
  output logic [1:0][3:0][1:0] memory_command_mode_o,
  output logic [1:0][3:0] memory_write_valid_o,input wire logic [1:0][3:0] memory_write_ready_i,
  output logic [1:0][3:0][91:0] memory_write_data_o,
  output logic [1:0][3:0][9:0] memory_write_address_o,
  input wire logic [1:0][3:0] memory_done_valid_i,memory_done_error_i,
  output logic [1:0][3:0] memory_done_ready_o
);
  logic hash_job_ready,writer_job_ready,hash_job_valid,writer_done_valid,writer_done_ready;
  logic packet_valid,packet_ready,packet_core,packet_last;
  logic [15:0] packet_id;logic [7:0] packet_index;logic [91:0] packet_data;logic [4:0] packet_count;
  logic status_valid,status_core,status_ready,writer_done_core;
  logic [15:0] status_id,writer_done_id;logic [2:0] status_code,writer_done_code;
  logic completion_valid_r,completion_core_r;
  logic [15:0] completion_id_r;logic [2:0] completion_code_r;
  logic completion_take;
  logic bad_job,bad_pending_r;logic [15:0] bad_id_r;
  logic load_owned_r,writer_fault,load_fault,decoder_ready,writer_idle;
  logic [1:0] engine_active;
  logic manual_job_valid,manual_job_core,manual_job_last;
  logic [1:0] manual_job_mode,manual_job_bank;logic [9:0] manual_job_base;logic [15:0] manual_job_id;
  logic manual_packet_valid,manual_packet_core,manual_packet_last;
  logic [15:0] manual_packet_id;logic [7:0] manual_packet_index;logic [4:0] manual_packet_count;logic [91:0] manual_packet_data;
  logic manual_status_valid,manual_status_core,writer_status_ready,manual_done_ready;
  logic [15:0] manual_status_id;logic [2:0] manual_status_code;
  assign fault_o=writer_fault || load_fault;
  assign idle_o=!rst && !load_owned_r && !bad_pending_r && !completion_valid_r && writer_idle && engine_active==0 && decoder_ready;
  assign load_ready_o=!rst && !fault_o && !load_owned_r && !bad_pending_r && !completion_valid_r && !job_valid_i &&
    active_o==0 && writer_job_ready && decoder_ready;
  assign bad_job=job_param_i==3 || job_base_i[5:0]!=0;
  assign hash_job_valid=!bad_job && !bad_pending_r && !completion_valid_r && !fault_o && !load_owned_r && job_valid_i && writer_job_ready;
  assign job_ready_o=!rst && !fault_o && !load_owned_r && !bad_pending_r && !completion_valid_r && (bad_job || (hash_job_ready && writer_job_ready));
  assign done_valid_o=bad_pending_r || completion_valid_r;
  assign done_id_o=bad_pending_r?bad_id_r:completion_id_r;
  assign done_core_o=bad_pending_r?1'b0:completion_core_r;
  assign done_code_o=bad_pending_r?3'd3:completion_code_r;
  assign writer_done_ready=load_owned_r?manual_done_ready:!completion_valid_r && !bad_pending_r;
  assign status_ready=!load_owned_r && writer_status_ready;
  keccak_sampler #(.RAW_SERVICE(1),.BANK_IO(1)) engine(
    .clk(clk),.rst(rst),.job_valid_i(hash_job_valid),.job_ready_o(hash_job_ready),.job_core_o(job_core_o),
    .job_id_i(job_id_i),.message_len_i(message_len_i),.job_mode_i(job_mode_i),.job_param_i(job_param_i),
    .input_data_i(input_data_i),.input_valid_i(input_valid_i),.input_ready_o(input_ready_o),
    .output_data_o(),.output_core_o(packet_core),.output_last_o(packet_last),.output_valid_o(packet_valid),
    .output_id_o(packet_id),.output_index_o(packet_index),.output_ready_i(packet_ready && !load_owned_r),
    .status_valid_o(status_valid),.status_core_o(status_core),.status_id_o(status_id),.status_code_o(status_code),
    .status_ready_i(status_ready),.active_o(engine_active),.output_bank_data_o(packet_data),.output_bank_count_o(packet_count),
    .raw_valid_i(raw_valid_i),.raw_ready_o(raw_ready_o),.raw_core_o(raw_core_o),.raw_mode_i(raw_mode_i),
    .raw_id_i(raw_id_i),.raw_message_len_i(raw_message_len_i),.raw_output_len_i(raw_output_len_i),
    .raw_input_data_i(raw_input_data_i),.raw_input_valid_i(raw_input_valid_i),.raw_input_ready_o(raw_input_ready_o),
    .raw_output_valid_o(raw_output_valid_o),.raw_output_core_o(raw_output_core_o),.raw_output_id_o(raw_output_id_o),
    .raw_output_data_o(raw_output_data_o),.raw_output_bytes_o(raw_output_bytes_o),.raw_output_ready_i(raw_output_ready_i),
    .raw_done_valid_o(raw_done_valid_o),.raw_done_core_o(raw_done_core_o),.raw_done_id_o(raw_done_id_o),.raw_done_ready_i(raw_done_ready_i));
  sampler_writer writer(
    .clk(clk),.rst(rst),.job_valid_i(load_owned_r?manual_job_valid:hash_job_valid && hash_job_ready),.job_ready_o(writer_job_ready),
    .job_core_i(load_owned_r?manual_job_core:job_core_o),.job_batch_last_i(load_owned_r?manual_job_last:job_batch_last_i),
    .job_mode_i(load_owned_r?manual_job_mode:job_mode_i),.job_bank_i(load_owned_r?manual_job_bank:job_bank_i),
    .job_base_i(load_owned_r?manual_job_base:job_base_i),.job_id_i(load_owned_r?manual_job_id:job_id_i),
    .packet_valid_i(load_owned_r?manual_packet_valid:packet_valid),.packet_ready_o(packet_ready),
    .packet_core_i(load_owned_r?manual_packet_core:packet_core),.packet_last_i(load_owned_r?manual_packet_last:packet_last),
    .packet_id_i(load_owned_r?manual_packet_id:packet_id),.packet_index_i(load_owned_r?manual_packet_index:packet_index),
    .packet_data_i(load_owned_r?manual_packet_data:packet_data),.packet_count_i(load_owned_r?manual_packet_count:packet_count),
    .status_valid_i(load_owned_r?manual_status_valid:status_valid),.status_core_i(load_owned_r?manual_status_core:status_core),
    .status_id_i(load_owned_r?manual_status_id:status_id),.status_code_i(load_owned_r?manual_status_code:status_code),.status_ready_o(writer_status_ready),
    .done_valid_o(writer_done_valid),.done_ready_i(writer_done_ready),.done_core_o(writer_done_core),.done_id_o(writer_done_id),
    .done_code_o(writer_done_code),.fault_o(writer_fault),.active_o(active_o),.idle_o(writer_idle),
    .memory_command_valid_o(memory_command_valid_o),.memory_command_ready_i(memory_command_ready_i),
    .memory_command_mask_o(memory_command_mask_o),.memory_command_write_o(memory_command_write_o),
    .memory_command_base_o(memory_command_base_o),.memory_command_words_o(memory_command_words_o),.memory_command_mode_o(memory_command_mode_o),
    .memory_write_valid_o(memory_write_valid_o),.memory_write_ready_i(memory_write_ready_i),.memory_write_data_o(memory_write_data_o),.memory_write_address_o(memory_write_address_o),
    .memory_done_valid_i(memory_done_valid_i),.memory_done_error_i(memory_done_error_i),.memory_done_ready_o(memory_done_ready_o));
  load_decode decoder(
    .clk(clk),.rst(rst),.command_valid_i(load_valid_i && load_ready_o),.command_ready_o(decoder_ready),
    .command_op_i(load_op_i),.command_param_i(load_param_i),.command_bank_i(load_bank_i),.command_base_i(load_base_i),.command_id_i(load_id_i),
    .input_valid_i(load_input_valid_i),.input_ready_o(load_input_ready_o),.input_data_i(load_input_data_i),
    .input_index_i(load_input_index_i),.input_bytes_i(load_input_bytes_i),.input_last_i(load_input_last_i),
    .done_valid_o(load_done_valid_o),.done_ready_i(load_done_ready_i),.done_code_o(load_done_code_o),.done_id_o(load_done_id_o),.fault_o(load_fault),
    .writer_job_valid_o(manual_job_valid),.writer_job_ready_i(writer_job_ready && load_owned_r),
    .writer_job_core_o(manual_job_core),.writer_job_batch_last_o(manual_job_last),.writer_job_mode_o(manual_job_mode),
    .writer_job_bank_o(manual_job_bank),.writer_job_base_o(manual_job_base),.writer_job_id_o(manual_job_id),
    .packet_valid_o(manual_packet_valid),.packet_ready_i(packet_ready && load_owned_r),.packet_core_o(manual_packet_core),
    .packet_last_o(manual_packet_last),.packet_id_o(manual_packet_id),.packet_index_o(manual_packet_index),
    .packet_count_o(manual_packet_count),.packet_data_o(manual_packet_data),
    .status_valid_o(manual_status_valid),.status_ready_i(writer_status_ready && load_owned_r),
    .status_core_o(manual_status_core),.status_id_o(manual_status_id),.status_code_o(manual_status_code),
    .writer_done_valid_i(writer_done_valid && load_owned_r),.writer_done_core_i(writer_done_core),
    .writer_done_id_i(writer_done_id),.writer_done_code_i(writer_done_code),.writer_done_ready_o(manual_done_ready));
  // One registered completion record cuts sampler arbitration/ID selection
  // away from the owning controller's error/state transition path.
  assign completion_take=!load_owned_r && writer_done_valid && writer_done_ready;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)completion_valid_r<=0;
    else if(completion_take)completion_valid_r<=1;
    else if(completion_valid_r && done_ready_i)completion_valid_r<=0;
  end
  always_ff @(posedge clk)if(completion_take)begin
    completion_core_r<=writer_done_core;completion_id_r<=writer_done_id;completion_code_r<=writer_done_code;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin bad_pending_r<=0;bad_id_r<=0;load_owned_r<=0;end
    else begin
      if(load_valid_i && load_ready_o)load_owned_r<=1;
      if(load_done_valid_o && load_done_ready_i)load_owned_r<=0;
      if(job_valid_i && job_ready_o && bad_job)begin bad_pending_r<=1;bad_id_r<=job_id_i;end
      if(bad_pending_r && done_ready_i)bad_pending_r<=0;
    end
  end
endmodule
`default_nettype wire
