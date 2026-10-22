// Four parallel lanes of the same decomposition;transport owns valid/tags.
`default_nettype none
module decompose_x4 (
  input wire logic [1:0] param_i,input wire logic [3:0][22:0] data_i,
  output logic [3:0][5:0] high_o,output logic [3:0][18:0] low_o,
  output logic error_o
);
  logic [3:0] bad;
  for(genvar i=0;i<4;i++)begin:lanes
    decompose arithmetic(.param_i(param_i),.coefficient_i(data_i[i]),.high_o(high_o[i]),.low_o(low_o[i]));
    assign bad[i]=data_i[i]>=23'd8380417;
  end
  assign error_o=param_i==3 || |bad;
endmodule
`default_nettype wire
