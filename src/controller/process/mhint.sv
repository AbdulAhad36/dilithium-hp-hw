// Optimized signing convention:corrected low residue and retained w1 high.
// This is not the generic MakeHint(z,r) input interface.
`default_nettype none
module mhint (
  input wire logic [1:0] param_i,input wire logic [3:0][22:0] low_i,
  input wire logic [3:0][5:0] high_i,output logic [3:0] hint_o,
  output logic [2:0] count_o,output logic error_o
);
  logic signed [23:0] gamma2;
  logic [3:0] bad;
  assign gamma2=param_i==0?24'sd95232:24'sd261888;
  for(genvar i=0;i<4;i++)begin:lanes
    wire signed [23:0] centered=low_i[i]>23'd4190208 ?
      $signed({1'b0,low_i[i]})-24'sd8380417:$signed({1'b0,low_i[i]});
    assign hint_o[i]=centered>gamma2 || centered< -gamma2 || (centered== -gamma2 && high_i[i]!=0);
    assign bad[i]=low_i[i]>=23'd8380417 || high_i[i]>(param_i==0?6'd43:6'd15);
  end
  assign count_o=3'(hint_o[0])+3'(hint_o[1])+3'(hint_o[2])+3'(hint_o[3]);
  assign error_o=param_i==3 || |bad;
endmodule
`default_nettype wire
