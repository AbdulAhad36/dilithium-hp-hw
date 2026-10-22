// Submit seed expansion through a shared finite-SHAKE service and retain its
// complete rho/rho-prime/key result. Reset must coordinate with that service.
`default_nettype none
module keygen_seed_collect (
  input wire logic clk,rst,
  input wire logic start_valid_i,output logic start_ready_o,
  input wire logic [1:0] start_param_i,
  input wire logic [15:0] start_id_i,
  input wire logic [255:0] start_seed_i,
  output logic result_valid_o,input wire logic result_ready_i,
  output logic result_error_o,output logic [15:0] result_id_o,
  output logic [1:0] result_param_o,
  output logic [255:0] result_rho_o,result_key_o,
  output logic [511:0] result_rhoprime_o,
  output logic raw_valid_o,input wire logic raw_ready_i,raw_core_i,
  output logic raw_mode_o,
  output logic [15:0] raw_id_o,raw_message_len_o,raw_output_len_o,
  output logic [63:0] raw_input_data_o,
  output logic raw_input_valid_o,input wire logic raw_input_ready_i,
  input wire logic raw_output_valid_i,raw_output_core_i,
  input wire logic [15:0] raw_output_id_i,
  input wire logic [127:0] raw_output_data_i,
  input wire logic [4:0] raw_output_bytes_i,
  output logic raw_output_ready_o,
  input wire logic raw_done_valid_i,raw_done_core_i,
  input wire logic [15:0] raw_done_id_i,
  output logic raw_done_ready_o
);
  logic busy_r,issued_r,core_r,message_done_r;
  logic [3:0] count_r;
  logic [1023:0] seed_material_r;
  logic format_ready,format_done,format_error;
  logic [15:0] format_id;
  assign start_ready_o=!rst && !busy_r && !result_valid_o && format_ready;
  assign raw_id_o=result_id_o;
  assign raw_output_ready_o=!rst && busy_r && issued_r && count_r<8;
  assign raw_done_ready_o=!rst && busy_r && issued_r && count_r==8 && message_done_r;
  assign result_rho_o=result_error_o ? 256'd0 : seed_material_r[255:0];
  assign result_rhoprime_o=result_error_o ? 512'd0 : seed_material_r[767:256];
  assign result_key_o=result_error_o ? 256'd0 : seed_material_r[1023:768];
  keygen_hash_message format(
    .clk(clk),.rst(rst),.command_valid_i(start_valid_i && start_ready_o),
    .command_ready_o(format_ready),.command_op_i(2'd0),.command_param_i(start_param_i),
    .command_id_i(start_id_i),.command_nonce_i(16'd0),.command_row_i(8'd0),
    .command_column_i(8'd0),.command_seed_i({256'd0,start_seed_i}),
    .request_valid_o(raw_valid_o),.request_ready_i(raw_ready_i),.request_mode_o(raw_mode_o),
    .request_message_len_o(raw_message_len_o),.request_output_len_o(raw_output_len_o),
    .input_data_o(raw_input_data_o),.input_valid_o(raw_input_valid_o),.input_ready_i(raw_input_ready_i),
    .done_valid_o(format_done),.done_ready_i(busy_r),.done_error_o(format_error),.done_id_o(format_id)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      busy_r<=0;issued_r<=0;core_r<=0;message_done_r<=0;count_r<=0;
      seed_material_r<=0;result_valid_o<=0;result_error_o<=0;result_id_o<=0;result_param_o<=0;
    end else begin
      if(result_valid_o && result_ready_i)result_valid_o<=0;
      if(start_valid_i && start_ready_o)begin
        busy_r<=1;issued_r<=0;message_done_r<=0;count_r<=0;seed_material_r<=0;
        result_error_o<=0;result_id_o<=start_id_i;result_param_o<=start_param_i;
      end
      if(raw_valid_o && raw_ready_i)begin issued_r<=1;core_r<=raw_core_i;end
      if(format_done && busy_r)begin
        message_done_r<=1;
        if(format_error)begin busy_r<=0;result_valid_o<=1;result_error_o<=1;end
      end
      if(raw_output_valid_i && raw_output_ready_o)begin
        seed_material_r[128*count_r +: 128]<=raw_output_data_i;count_r<=count_r+4'd1;
      end
      if(raw_done_valid_i && raw_done_ready_o)begin busy_r<=0;result_valid_o<=1;end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst)begin
    if(raw_output_valid_i && raw_output_ready_o &&
       (raw_output_id_i!=result_id_o || raw_output_core_i!=core_r || raw_output_bytes_i!=16))
      $fatal(1,"Seed collection output ownership/size");
    if(raw_done_valid_i && raw_done_ready_o &&
       (raw_done_id_i!=result_id_o || raw_done_core_i!=core_r))$fatal(1,"Seed collection completion ownership");
    if(format_done && busy_r && format_id!=result_id_o)$fatal(1,"Seed formatter ID mismatch");
  end
`endif
endmodule
`default_nettype wire
