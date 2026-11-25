// Sole physical engines and bank storage for compact KeyGen/Sign/Verify.
// Controllers select fixed roles/counters. No helper leases or context copies.
`default_nettype none
module datapath (
  input wire logic clk,rst,
  input var dilithium_pkg::request_t service_i,
  output dilithium_pkg::response_t service_o,
  output logic fault_o
);
  import dilithium_pkg::*;
  logic [2:0][1:0] client_command_valid_i,client_command_ready_o;
  logic [2:0][1:0][3:0] client_command_mask_i,client_command_write_i,client_write_valid_i,client_write_ready_o;
  logic [2:0][1:0][3:0][9:0] client_command_base_i,client_write_address_i,client_read_address_o;
  logic [2:0][1:0][3:0][10:0] client_command_words_i;
  logic [2:0][1:0][3:0][1:0] client_command_mode_i;
  logic [2:0][1:0][3:0][91:0] client_write_data_i,client_read_data_o;
  logic [2:0][1:0][3:0] client_read_valid_o,client_read_ready_i,client_read_last_o,client_done_valid_o,client_done_error_o,client_done_ready_i;
  logic [3:0] collision_o;
  logic memory_idle,hash_idle;
  bank_request_t process_bank_o;
  bank_response_t process_bank_i;
  logic process_owner_r,process_ready,process_hint_idle;
  logic [1:0][3:0] host_busy_r;
  logic process_admit;
  // A manual memory reservation wins a simultaneous admission request.
  // Never switch client2 to Process after already accepting a host burst.
  assign process_admit=host_busy_r==0 && !(|service_i.bank.command_valid);
  assign service_o.poly_process.ready=process_ready && process_admit;
  assign process_bank_o.write_address=0;
  assign client_command_valid_i[2]=process_owner_r?process_bank_o.command_valid:service_i.bank.command_valid;
  assign client_command_mask_i[2]=process_owner_r?process_bank_o.mask:service_i.bank.mask;
  assign client_command_write_i[2]=process_owner_r?process_bank_o.write:service_i.bank.write;
  assign client_command_base_i[2]=process_owner_r?process_bank_o.base:service_i.bank.base;
  assign client_command_words_i[2]=process_owner_r?process_bank_o.words:service_i.bank.words;
  assign client_command_mode_i[2]=process_owner_r?process_bank_o.mode:service_i.bank.mode;
  assign client_write_valid_i[2]=process_owner_r?process_bank_o.write_valid:service_i.bank.write_valid;
  assign client_write_data_i[2]=process_owner_r?process_bank_o.write_data:service_i.bank.write_data;
  assign client_write_address_i[2]=process_owner_r?process_bank_o.write_address:service_i.bank.write_address;
  assign client_read_ready_i[2]=process_owner_r?process_bank_o.read_ready:service_i.bank.read_ready;
  assign client_done_ready_i[2]=process_owner_r?process_bank_o.done_ready:service_i.bank.done_ready;
  assign process_bank_i.command_ready=client_command_ready_o[2];
  assign service_o.bank.command_ready=process_owner_r?'0:client_command_ready_o[2];
  assign process_bank_i.write_ready=client_write_ready_o[2];
  assign service_o.bank.write_ready=process_owner_r?'0:client_write_ready_o[2];
  assign process_bank_i.read_valid=client_read_valid_o[2];
  assign service_o.bank.read_valid=process_owner_r?'0:client_read_valid_o[2];
  assign process_bank_i.read_data=client_read_data_o[2];
  assign service_o.bank.read_data=process_owner_r?'0:client_read_data_o[2];
  assign process_bank_i.read_address=client_read_address_o[2];
  assign service_o.bank.read_address=process_owner_r?'0:client_read_address_o[2];
  assign process_bank_i.read_last=client_read_last_o[2];
  assign service_o.bank.read_last=process_owner_r?'0:client_read_last_o[2];
  assign process_bank_i.done_valid=client_done_valid_o[2];
  assign service_o.bank.done_valid=process_owner_r?'0:client_done_valid_o[2];
  assign process_bank_i.done_error=client_done_error_o[2];
  assign service_o.bank.done_error=process_owner_r?'0:client_done_error_o[2];
  assign fault_o=service_o.sample.fault;
  assign service_o.idle=memory_idle && hash_idle && service_o.ntt.ready && process_ready &&
    !process_owner_r && host_busy_r==0 && process_hint_idle;
  bank_fabric #(.TIMING_PIPELINE(1),.REGISTER_RETIREMENT(1)) memory(.idle_o(memory_idle),.*);
  hash_sampler #(.PIPELINE_INPUT(1),.PIPELINE_LOAD_FRAME(1)) hash_sampler(
    .clk(clk),.rst(rst),.job_valid_i(service_i.sample.valid),.job_ready_o(service_o.sample.ready),.job_core_o(service_o.sample.core),
    .job_batch_last_i(service_i.sample.batch_last),.job_mode_i(service_i.sample.mode),.job_param_i(service_i.sample.param),
    .job_bank_i(service_i.sample.bank),.job_base_i(service_i.sample.base),.job_id_i(service_i.sample.id),.message_len_i(service_i.sample.message_len),
    .input_data_i(service_i.sample.input_data),.input_valid_i(service_i.sample.input_valid),.input_ready_o(service_o.sample.input_ready),
    .done_valid_o(service_o.sample.done_valid),.done_ready_i(service_i.sample.done_ready),.done_core_o(service_o.sample.done_core),
    .done_id_o(service_o.sample.done_id),.done_code_o(service_o.sample.done_code),.fault_o(service_o.sample.fault),.active_o(service_o.sample.active),.idle_o(hash_idle),
    .raw_valid_i(service_i.raw.valid),.raw_ready_o(service_o.raw.ready),.raw_core_o(service_o.raw.core),.raw_mode_i(service_i.raw.mode),
    .raw_id_i(service_i.raw.id),.raw_message_len_i(service_i.raw.message_len),.raw_output_len_i(service_i.raw.output_len),
    .raw_input_data_i(service_i.raw.input_data),.raw_input_valid_i(service_i.raw.input_valid),.raw_input_ready_o(service_o.raw.input_ready),
    .raw_output_valid_o(service_o.raw.output_valid),.raw_output_core_o(service_o.raw.output_core),.raw_output_id_o(service_o.raw.output_id),
    .raw_output_data_o(service_o.raw.output_data),.raw_output_bytes_o(service_o.raw.output_bytes),.raw_output_ready_i(service_i.raw.output_ready),
    .raw_done_valid_o(service_o.raw.done_valid),.raw_done_core_o(service_o.raw.done_core),.raw_done_id_o(service_o.raw.done_id),.raw_done_ready_i(service_i.raw.done_ready),
    .load_valid_i(service_i.load.valid),.load_ready_o(service_o.load.ready),.load_op_i(service_i.load.op),
    .load_param_i(service_i.load.param),.load_bank_i(service_i.load.bank),.load_base_i(service_i.load.base),.load_id_i(service_i.load.id),
    .load_input_valid_i(service_i.load.input_valid),.load_input_ready_o(service_o.load.input_ready),.load_input_data_i(service_i.load.input_data),
    .load_input_index_i(service_i.load.input_index),.load_input_bytes_i(service_i.load.input_bytes),.load_input_last_i(service_i.load.input_last),
    .load_done_valid_o(service_o.load.done_valid),.load_done_ready_i(service_i.load.done_ready),.load_done_code_o(service_o.load.done_code),.load_done_id_o(service_o.load.done_id),
    .memory_command_valid_o(client_command_valid_i[1]),
    .memory_command_ready_i(client_command_ready_o[1]),
    .memory_command_mask_o(client_command_mask_i[1]),
    .memory_command_write_o(client_command_write_i[1]),
    .memory_command_base_o(client_command_base_i[1]),
    .memory_command_words_o(client_command_words_i[1]),
    .memory_command_mode_o(client_command_mode_i[1]),
    .memory_write_valid_o(client_write_valid_i[1]),
    .memory_write_ready_i(client_write_ready_o[1]),
    .memory_write_data_o(client_write_data_i[1]),
    .memory_write_address_o(client_write_address_i[1]),
    .memory_done_valid_i(client_done_valid_o[1]),
    .memory_done_error_i(client_done_error_o[1]),
    .memory_done_ready_o(client_done_ready_i[1]));
  assign client_read_ready_i[1]=0;
  assign client_write_address_i[0]=0;
  ntt_dma polynomial(
    .clk(clk),.rst(rst),.command_valid_i(service_i.ntt.valid),.command_ready_o(service_o.ntt.ready),
    .command_op_i(ntt_pkg::ntt_op_e'(service_i.ntt.op)),.command_accumulate_i(service_i.ntt.accumulate),
    .command_a_bank_i(service_i.ntt.a_bank),.command_b_bank_i(service_i.ntt.b_bank),
    .command_c_bank_i(service_i.ntt.c_bank),.command_d_bank_i(service_i.ntt.d_bank),
    .command_a_base_i(service_i.ntt.a_base),.command_b_base_i(service_i.ntt.b_base),
    .command_c_base_i(service_i.ntt.c_base),.command_d_base_i(service_i.ntt.d_base),
    .done_valid_o(service_o.ntt.done_valid),.done_ready_i(service_i.ntt.done_ready),.done_code_o(service_o.ntt.done_code),
    .source_released_o(service_o.ntt.source_released),
    .memory_command_valid_o(client_command_valid_i[0]),
    .memory_command_ready_i(client_command_ready_o[0]),
    .memory_command_mask_o(client_command_mask_i[0]),
    .memory_command_write_o(client_command_write_i[0]),
    .memory_command_base_o(client_command_base_i[0]),
    .memory_command_words_o(client_command_words_i[0]),
    .memory_command_mode_o(client_command_mode_i[0]),
    .memory_write_valid_o(client_write_valid_i[0]),
    .memory_write_ready_i(client_write_ready_o[0]),
    .memory_write_data_o(client_write_data_i[0]),
    .memory_read_valid_i(client_read_valid_o[0]),
    .memory_read_ready_o(client_read_ready_i[0]),
    .memory_read_data_i(client_read_data_o[0]),
    .memory_done_valid_i(client_done_valid_o[0]),
    .memory_done_error_i(client_done_error_o[0]),
    .memory_done_ready_o(client_done_ready_i[0]));
  process_dma #(.SHARED_HINT(1),.PIPELINE_PACK(1),.PIPELINE_OPERANDS(1),.PIPELINE_RESULTS(1)) process_path(
    .clk(clk),.rst(rst),.command_valid_i(service_i.poly_process.valid && process_admit),.command_ready_o(process_ready),
    .command_op_i(service_i.poly_process.op),.command_param_i(service_i.poly_process.param),.command_kind_i(service_i.poly_process.kind),
    .command_a_compact_i(service_i.poly_process.a_compact),.command_b_enable_i(service_i.poly_process.b_enable),.command_b_compact_i(service_i.poly_process.b_compact),
    .command_low_enable_i(service_i.poly_process.low_enable),.command_pack_high_i(service_i.poly_process.pack_enable),
    .command_pack_store_i(service_i.poly_process.pack_store),.command_pack_op_i(service_i.poly_process.pack_op),
    .command_hint_enable_i(service_i.poly_process.hint_enable),
    .command_a_bank_i(service_i.poly_process.a_bank),.command_b_bank_i(service_i.poly_process.b_bank),
    .command_d_bank_i(service_i.poly_process.d_bank),.command_h_bank_i(service_i.poly_process.h_bank),
    .command_a_base_i(service_i.poly_process.a_base),.command_b_base_i(service_i.poly_process.b_base),
    .command_d_base_i(service_i.poly_process.d_base),.command_h_base_i(service_i.poly_process.h_base),
    .done_valid_o(service_o.poly_process.done_valid),.done_ready_i(service_i.poly_process.done_ready),.done_code_o(service_o.poly_process.done_code),
    .done_reject_o(service_o.poly_process.reject),.done_hint_weight_o(service_o.poly_process.hint_weight),
    .packed_valid_o(service_o.poly_process.packed_valid),.packed_ready_i(service_i.poly_process.packed_ready),
    .packed_data_o(service_o.poly_process.packed_data),.packed_index_o(service_o.poly_process.packed_index),.packed_last_o(service_o.poly_process.packed_last),
    .hint_valid_o(service_o.poly_process.hint_valid),.hint_ready_i(service_i.poly_process.hint_ready),
    .hint_mask_o(service_o.poly_process.hint_mask),.hint_word_o(service_o.poly_process.hint_word),.hint_last_o(service_o.poly_process.hint_last),
    .hint_encode_i(service_i.hint_encode),.hint_encode_o(service_o.hint_encode),
    .hint_decode_i(service_i.hint_decode),.hint_decode_o(service_o.hint_decode),.hint_idle_o(process_hint_idle),
    .memory_command_valid_o(process_bank_o.command_valid),
    .memory_command_ready_i(process_bank_i.command_ready),
    .memory_command_mask_o(process_bank_o.mask),
    .memory_command_write_o(process_bank_o.write),
    .memory_command_base_o(process_bank_o.base),
    .memory_command_words_o(process_bank_o.words),
    .memory_command_mode_o(process_bank_o.mode),
    .memory_write_valid_o(process_bank_o.write_valid),
    .memory_write_ready_i(process_bank_i.write_ready),
    .memory_write_data_o(process_bank_o.write_data),
    .memory_read_valid_i(process_bank_i.read_valid),
    .memory_read_ready_o(process_bank_o.read_ready),
    .memory_read_data_i(process_bank_i.read_data),
    .memory_done_valid_i(process_bank_i.done_valid),
    .memory_done_error_i(process_bank_i.done_error),
    .memory_done_ready_o(process_bank_o.done_ready));
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin process_owner_r<=0;host_busy_r<=0;end
    else begin
      if(service_i.poly_process.valid && service_o.poly_process.ready)process_owner_r<=1;
      if(service_o.poly_process.done_valid && service_i.poly_process.done_ready)process_owner_r<=0;
      if(!process_owner_r)for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
        if(service_o.bank.done_valid[p][b] && service_i.bank.done_ready[p][b])host_busy_r[p][b]<=0;
        if(service_i.bank.command_valid[p] && service_o.bank.command_ready[p] &&
          (service_i.bank.mask[p][b] || (service_i.bank.mask[p]==0 && b==0)))host_busy_r[p][b]<=1;
      end
    end
  end
endmodule
`default_nettype wire
