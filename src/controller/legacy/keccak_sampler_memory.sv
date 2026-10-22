// Stage3 producer and slot storage. The algorithm controller and NTT follow.
`default_nettype none
module keccak_sampler_memory #(
  parameter int SLOTS=4,
  parameter int SLOT_W=(SLOTS>1)?$clog2(SLOTS):1
) (
  input wire logic clk,rst,
  input wire logic job_valid_i,
  output logic job_ready_o,job_core_o,
  output logic [SLOT_W-1:0] job_slot_o,
  input wire logic [15:0] job_id_i,message_len_i,
  input wire logic [1:0] job_mode_i,job_param_i,
  input wire logic [63:0] input_data_i,
  input wire logic input_valid_i,
  output logic input_ready_o,
  output logic status_valid_o,status_core_o,
  output logic [15:0] status_id_o,
  output logic [2:0] status_code_o,
  input wire logic status_ready_i,
  output logic [1:0] active_o,
  input wire logic read_valid_i,
  input wire logic [SLOT_W-1:0] read_slot_i,
  input wire logic [7:0] read_index_i,
  output logic read_ready_o,response_valid_o,response_error_o,
  output logic [SLOT_W-1:0] response_slot_o,
  output logic [7:0] response_index_o,
  output logic [22:0] response_data_o,
  output logic [15:0] response_id_o,
  output logic [1:0] response_mode_o,response_param_o,
  output logic response_ntt_domain_o,
  input wire logic response_ready_i,
  input wire logic release_valid_i,
  input wire logic [SLOT_W-1:0] release_slot_i,
  output logic release_ready_o,
  output logic [SLOTS-1:0] reserved_o,complete_o,
  output logic fault_o
);
  logic producer_ready,alloc_ready,finish_ready;
  logic coeff_valid,coeff_ready,coeff_core,coeff_last;
  logic [15:0] coeff_id;
  logic [7:0] coeff_index;
  logic [22:0] coeff_data;
  logic producer_status_valid,producer_status_ready;
  logic command_fire;
  assign job_ready_o=producer_ready && alloc_ready;
  assign command_fire=job_valid_i && job_ready_o;
  assign status_valid_o=producer_status_valid && finish_ready;
  assign producer_status_ready=status_ready_i && finish_ready;

  keccak_sampler producer(
    .clk(clk),.rst(rst),.job_valid_i(command_fire),.job_ready_o(producer_ready),
    .job_core_o(job_core_o),.job_id_i(job_id_i),.message_len_i(message_len_i),
    .job_mode_i(job_mode_i),.job_param_i(job_param_i),
    .input_data_i(input_data_i),.input_valid_i(input_valid_i),.input_ready_o(input_ready_o),
    .output_data_o(coeff_data),.output_core_o(coeff_core),.output_id_o(coeff_id),
    .output_index_o(coeff_index),.output_last_o(coeff_last),
    .output_valid_o(coeff_valid),.output_ready_i(coeff_ready),
    .status_valid_o(producer_status_valid),.status_core_o(status_core_o),
    .status_id_o(status_id_o),.status_code_o(status_code_o),
    .status_ready_i(producer_status_ready),.active_o(active_o),
    .raw_valid_i(1'b0),.raw_ready_o(),.raw_core_o(),.raw_mode_i(1'b0),
    .raw_id_i(16'd0),.raw_message_len_i(16'd0),.raw_output_len_i(16'd0),
    .raw_input_data_i(64'd0),.raw_input_valid_i(1'b0),.raw_input_ready_o(),
    .raw_output_valid_o(),.raw_output_core_o(),.raw_output_id_o(),
    .raw_output_data_o(),.raw_output_bytes_o(),.raw_output_ready_i(1'b0),
    .raw_done_valid_o(),.raw_done_core_o(),.raw_done_id_o(),.raw_done_ready_i(1'b0)
  );
  slot_memory #(.SLOTS(SLOTS),.SLOT_W(SLOT_W)) store(
    .clk(clk),.rst(rst),.alloc_valid_i(command_fire),.alloc_ready_o(alloc_ready),
    .alloc_slot_o(job_slot_o),.alloc_core_i(job_core_o),.alloc_id_i(job_id_i),
    .alloc_mode_i(job_mode_i),.alloc_param_i(job_param_i),
    .write_valid_i(coeff_valid),.write_ready_o(coeff_ready),.write_core_i(coeff_core),
    .write_id_i(coeff_id),.write_index_i(coeff_index),.write_last_i(coeff_last),
    .write_data_i(coeff_data),.finish_valid_i(producer_status_valid && status_ready_i),
    .finish_ready_o(finish_ready),.finish_core_i(status_core_o),
    .finish_id_i(status_id_o),.finish_code_i(status_code_o),
    .read_valid_i(read_valid_i),.read_ready_o(read_ready_o),.read_slot_i(read_slot_i),
    .read_index_i(read_index_i),.response_valid_o(response_valid_o),
    .response_ready_i(response_ready_i),.response_error_o(response_error_o),
    .response_slot_o(response_slot_o),.response_index_o(response_index_o),
    .response_data_o(response_data_o),.response_id_o(response_id_o),
    .response_mode_o(response_mode_o),.response_param_o(response_param_o),
    .response_ntt_domain_o(response_ntt_domain_o),.release_valid_i(release_valid_i),
    .release_slot_i(release_slot_i),.release_ready_o(release_ready_o),
    .reserved_o(reserved_o),.complete_o(complete_o),.fault_o(fault_o),
    .exec_valid_i(1'b0),.exec_ready_o(),.exec_op_i(2'd0),
    .exec_a_slot_i({SLOT_W{1'b0}}),.exec_b_slot_i({SLOT_W{1'b0}}),
    .exec_a_id_i(16'd0),.exec_b_id_i(16'd0),.exec_id_i(16'd0),
    .exec_response_valid_o(),.exec_response_ready_i(1'b0),.exec_code_o(),.exec_slot_o(),
    .result_valid_i(1'b0),.result_last_i(1'b0),.result_ready_o(),
    .result_index_i(8'd0),.result_data_i(23'd0),.exec_done_i(1'b0)
  );
endmodule
`default_nettype wire
