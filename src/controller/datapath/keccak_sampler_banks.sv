// Connected sampling path using LightHD bank geometry. The caller selects an
// aligned region;KeyGen role allocation/NTT/processing scheduling follow later.
`default_nettype none
module keccak_sampler_banks (
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
  output logic [63:0] reserved_o,complete_o,output logic fault_o
);
  logic producer_ready,alloc_ready,finish_ready,command_fire,producer_status_valid;
  logic coeff_valid,coeff_ready,coeff_core,coeff_last;
  logic [15:0] coeff_id;logic [7:0] coeff_index;logic [22:0] coeff_data;
  assign job_ready_o=producer_ready && alloc_ready && !fault_o;
  assign command_fire=job_valid_i && job_ready_o;
  assign status_valid_o=producer_status_valid && finish_ready && !fault_o;
  keccak_sampler producer(
    .clk(clk),.rst(rst),.job_valid_i(command_fire),.job_ready_o(producer_ready),.job_core_o(job_core_o),
    .job_id_i(job_id_i),.message_len_i(message_len_i),.job_mode_i(job_mode_i),.job_param_i(job_param_i),
    .input_data_i(input_data_i),.input_valid_i(input_valid_i),.input_ready_o(input_ready_o),
    .output_data_o(coeff_data),.output_core_o(coeff_core),.output_last_o(coeff_last),.output_valid_o(coeff_valid),
    .output_id_o(coeff_id),.output_index_o(coeff_index),.output_ready_i(coeff_ready),
    .status_valid_o(producer_status_valid),.status_core_o(status_core_o),.status_id_o(status_id_o),.status_code_o(status_code_o),
    .status_ready_i(status_ready_i && finish_ready && !fault_o),.active_o(active_o),
    .raw_valid_i(1'b0),.raw_ready_o(),.raw_core_o(),.raw_mode_i(1'b0),
    .raw_id_i(16'd0),.raw_message_len_i(16'd0),.raw_output_len_i(16'd0),
    .raw_input_data_i(64'd0),.raw_input_valid_i(1'b0),.raw_input_ready_o(),
    .raw_output_valid_o(),.raw_output_core_o(),.raw_output_id_o(),.raw_output_data_o(),.raw_output_bytes_o(),
    .raw_output_ready_i(1'b0),.raw_done_valid_o(),.raw_done_core_o(),.raw_done_id_o(),.raw_done_ready_i(1'b0)
  );
  memory store(
    .clk(clk),.rst(rst),.alloc_valid_i(command_fire),.alloc_core_i(job_core_o),.alloc_bank_i(job_bank_i),.alloc_region_i(job_region_i),
    .alloc_id_i(job_id_i),.alloc_mode_i(job_mode_i),.alloc_param_i(job_param_i),.alloc_ready_o(alloc_ready),
    .alloc_compute_i(1'b0),.alloc_ntt_domain_i(1'b0),.alloc_rewrite_i(1'b0),
    .write_valid_i(coeff_valid),.write_core_i(coeff_core),.write_last_i(coeff_last),.write_id_i(coeff_id),
    .write_index_i(coeff_index),.write_data_i(coeff_data),.write_ready_o(coeff_ready),
    .finish_valid_i(producer_status_valid && status_ready_i),.finish_core_i(status_core_o),.finish_id_i(status_id_o),
    .finish_code_i(status_code_o),.finish_ready_o(finish_ready),
    .read_valid_i(read_valid_i),.read_bank_i(read_bank_i),.read_region_i(read_region_i),.read_word_i(read_word_i),
    .read_ready_o(read_ready_o),.response_valid_o(response_valid_o),.response_error_o(response_error_o),
    .response_bank_o(response_bank_o),.response_region_o(response_region_o),.response_word_o(response_word_o),
    .response_data_o(response_data_o),.response_id_o(response_id_o),.response_mode_o(response_mode_o),.response_param_o(response_param_o),
    .response_ntt_domain_o(response_ntt_domain_o),.response_small_o(response_small_o),.response_ready_i(response_ready_i),
    .release_valid_i(release_valid_i),.release_bank_i(release_bank_i),.release_region_i(release_region_i),.release_ready_o(release_ready_o),
    .reserved_o(reserved_o),.complete_o(complete_o),.fault_o(fault_o)
  );
endmodule
`default_nettype wire
