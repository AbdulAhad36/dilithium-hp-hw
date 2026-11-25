// Direct Figure1/2 memory boundary:two independently scheduled bank ports.
// Exactly one four-bank payload array. Phase controllers own fixed addresses.
`default_nettype none
module memory #(parameter bit COHERENT_ADMISSION=0,parameter bit LOCAL_DESCRIPTOR=0) (
  input wire logic clk,rst,
  input wire logic [1:0] command_valid_i,
  output logic [1:0] command_ready_o,
  output logic [1:0][3:0] busy_o,
  input wire logic [1:0][3:0] command_mask_i,command_write_i,
  input wire logic [1:0][3:0][9:0] command_base_i,
  input wire logic [1:0][3:0][10:0] command_words_i,
  input wire logic [1:0][3:0][1:0] command_mode_i,
  input wire logic [1:0][3:0] write_valid_i,
  output logic [1:0][3:0] write_ready_o,
  input wire logic [1:0][3:0][91:0] write_data_i,
  input wire logic [1:0][3:0][9:0] write_address_i,
  output logic [1:0][3:0] read_valid_o,
  input wire logic [1:0][3:0] read_ready_i,
  output logic [1:0][3:0][91:0] read_data_o,
  output logic [1:0][3:0][9:0] read_address_o,
  output logic [1:0][3:0] read_last_o,
  output logic [1:0][3:0] done_valid_o,
  input wire logic [1:0][3:0] done_ready_i,
  output logic [1:0][3:0] done_error_o,
  output logic [3:0] collision_o
);
  logic [1:0][3:0] request_valid,request_write,request_ready;
  logic [1:0][3:0] response_valid,response_write,response_ready;
  logic [1:0][3:0][9:0] request_address,response_address;
  logic [1:0][3:0][91:0] request_data,response_data;
  genvar p;
  generate for(p=0;p<2;p=p+1)begin:port_fsm
    memory_port #(.COHERENT_ADMISSION(COHERENT_ADMISSION),.LOCAL_DESCRIPTOR(LOCAL_DESCRIPTOR)) scheduler(
      .clk(clk),.rst(rst),.command_valid_i(command_valid_i[p]),
      .command_ready_o(command_ready_o[p]),.busy_o(busy_o[p]),
      .command_mask_i(command_mask_i[p]),.command_write_i(command_write_i[p]),
      .command_base_i(command_base_i[p]),.command_words_i(command_words_i[p]),.command_mode_i(command_mode_i[p]),
      .write_valid_i(write_valid_i[p]),.write_ready_o(write_ready_o[p]),.write_data_i(write_data_i[p]),.write_address_i(write_address_i[p]),
      .read_valid_o(read_valid_o[p]),.read_ready_i(read_ready_i[p]),.read_data_o(read_data_o[p]),
      .read_address_o(read_address_o[p]),.read_last_o(read_last_o[p]),
      .done_valid_o(done_valid_o[p]),.done_ready_i(done_ready_i[p]),.done_error_o(done_error_o[p]),
      .request_valid_o(request_valid[p]),.request_write_o(request_write[p]),
      .request_address_o(request_address[p]),.request_data_o(request_data[p]),
      .request_ready_i(request_ready[p]),.response_valid_i(response_valid[p]),
      .response_write_i(response_write[p]),.response_address_i(response_address[p]),
      .response_data_i(response_data[p]),.response_ready_o(response_ready[p])
    );
  end endgenerate
  memory_banks banks(
    .clk(clk),.rst(rst),.request_valid_i(request_valid),.request_write_i(request_write),
    .request_address_i(request_address),.request_data_i(request_data),.request_ready_o(request_ready),
    .response_valid_o(response_valid),.response_write_o(response_write),
    .response_address_o(response_address),.response_data_o(response_data),
    .response_ready_i(response_ready),.collision_o(collision_o)
  );
endmodule
`default_nettype wire
