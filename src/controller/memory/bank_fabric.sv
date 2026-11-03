// Sole coefficient storage for the compact controller. The three clients are
// NTT,sampling and shared Process/host scheduling. No second payload array.
`default_nettype none
module bank_fabric (
  input wire logic clk,rst,
  input wire logic [2:0][1:0] client_command_valid_i,
  output logic [2:0][1:0] client_command_ready_o,
  input wire logic [2:0][1:0][3:0] client_command_mask_i,client_command_write_i,
  input wire logic [2:0][1:0][3:0][9:0] client_command_base_i,
  input wire logic [2:0][1:0][3:0][10:0] client_command_words_i,
  input wire logic [2:0][1:0][3:0][1:0] client_command_mode_i,
  input wire logic [2:0][1:0][3:0] client_write_valid_i,
  output logic [2:0][1:0][3:0] client_write_ready_o,
  input wire logic [2:0][1:0][3:0][91:0] client_write_data_i,
  input wire logic [2:0][1:0][3:0][9:0] client_write_address_i,
  output logic [2:0][1:0][3:0] client_read_valid_o,
  input wire logic [2:0][1:0][3:0] client_read_ready_i,
  output logic [2:0][1:0][3:0][91:0] client_read_data_o,
  output logic [2:0][1:0][3:0][9:0] client_read_address_o,
  output logic [2:0][1:0][3:0] client_read_last_o,client_done_valid_o,client_done_error_o,
  input wire logic [2:0][1:0][3:0] client_done_ready_i,
  output logic [3:0] collision_o,output logic idle_o
);
  logic [1:0] memory_command_valid_o,memory_command_ready_i;
  logic [1:0][3:0] memory_command_mask_o,memory_command_write_o;
  logic [1:0][3:0][9:0] memory_command_base_o,memory_read_address_i;
  logic [1:0][3:0][10:0] memory_command_words_o;
  logic [1:0][3:0][1:0] memory_command_mode_o;
  logic [1:0][3:0] memory_write_valid_o,memory_write_ready_i,memory_read_valid_i,memory_read_ready_o;
  logic [1:0][3:0][91:0] memory_write_data_o,memory_read_data_i;
  logic [1:0][3:0][9:0] memory_write_address_o;
  logic [1:0][3:0] memory_read_last_i,memory_done_valid_i,memory_done_error_i,memory_done_ready_o;
  logic [1:0][3:0] storage_busy;
  memory_router #(.COHERENT_PORTS(1)) router(.*);
  memory #(.COHERENT_ADMISSION(1)) storage(
    .clk(clk),.rst(rst),.command_valid_i(memory_command_valid_o),.command_ready_o(memory_command_ready_i),.busy_o(storage_busy),
    .command_mask_i(memory_command_mask_o),.command_write_i(memory_command_write_o),
    .command_base_i(memory_command_base_o),.command_words_i(memory_command_words_o),.command_mode_i(memory_command_mode_o),
    .write_valid_i(memory_write_valid_o),.write_ready_o(memory_write_ready_i),.write_data_i(memory_write_data_o),.write_address_i(memory_write_address_o),
    .read_valid_o(memory_read_valid_i),.read_ready_i(memory_read_ready_o),.read_data_o(memory_read_data_i),
    .read_address_o(memory_read_address_i),.read_last_o(memory_read_last_i),
    .done_valid_o(memory_done_valid_i),.done_ready_i(memory_done_ready_o),.done_error_o(memory_done_error_i),.collision_o(collision_o));
// synthesis translate_off
  always @(posedge clk)if(!rst)for(int p=0;p<2;p++)for(int b=0;b<4;b++)
    if((router.owner_r[p][b]==3)!==!storage_busy[p][b])
      $fatal(1,"Physical scheduler IDLE and router ownership disagree");
  // synthesis translate_on
endmodule
`default_nettype wire
