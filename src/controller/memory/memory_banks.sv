// LightHD logical storage geometry. [port][bank],port0=A,port1=B;
// bank0..3 correspond to the paper's BRAM1..4. No allocation policy here.
`default_nettype none
module memory_banks (
  input wire logic clk,rst,
  input wire logic [1:0][3:0] request_valid_i,request_write_i,
  input wire logic [1:0][3:0][9:0] request_address_i,
  input wire logic [1:0][3:0][91:0] request_data_i,
  output logic [1:0][3:0] request_ready_o,response_valid_o,response_write_o,
  output logic [1:0][3:0][9:0] response_address_o,
  output logic [1:0][3:0][91:0] response_data_o,
  input wire logic [1:0][3:0] response_ready_i,
  output logic [3:0] collision_o
);
  for(genvar b=0;b<4;b++)begin:bank
    poly_bram storage(
      .clk(clk),.rst(rst),
      .a_valid_i(request_valid_i[0][b]),.a_write_i(request_write_i[0][b]),
      .a_address_i(request_address_i[0][b]),.a_data_i(request_data_i[0][b]),
      .a_ready_o(request_ready_o[0][b]),.a_response_valid_o(response_valid_o[0][b]),
      .a_response_write_o(response_write_o[0][b]),.a_response_address_o(response_address_o[0][b]),
      .a_response_data_o(response_data_o[0][b]),.a_response_ready_i(response_ready_i[0][b]),
      .b_valid_i(request_valid_i[1][b]),.b_write_i(request_write_i[1][b]),
      .b_address_i(request_address_i[1][b]),.b_data_i(request_data_i[1][b]),
      .b_ready_o(request_ready_o[1][b]),.b_response_valid_o(response_valid_o[1][b]),
      .b_response_write_o(response_write_o[1][b]),.b_response_address_o(response_address_o[1][b]),
      .b_response_data_o(response_data_o[1][b]),.b_response_ready_i(response_ready_i[1][b]),
      .collision_o(collision_o[b])
    );
  end
endmodule
`default_nettype wire
