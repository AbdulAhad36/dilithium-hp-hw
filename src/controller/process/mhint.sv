// Optimized signing convention:corrected low residue and retained w1 high.
// This is not the generic MakeHint(z,r) input interface.
`default_nettype none
module mhint (
  input wire logic [1:0] param_i,input wire logic [3:0][22:0] low_i,
  input wire logic [3:0][5:0] high_i,output logic [3:0] hint_o,
  output logic [2:0] count_o,output logic error_o
);
  // Centered comparisons become one canonical interval. For q=8380417:
  // hint = gamma2 < a < q-gamma2,or a==q-gamma2 with nonzero high.
  // This also preserves the old hint bits on all23-bit invalid encodings;
  // range errors are still reported independently below.
  logic [22:0] lower_bound,upper_bound;
  logic [3:0] bad;
  assign lower_bound=param_i==0?23'd95232:23'd261888;
  assign upper_bound=param_i==0?23'd8285185:23'd8118529;
  genvar i;
  generate for(i=0;i<4;i=i+1)begin:lanes
    assign hint_o[i]=(low_i[i]>lower_bound && low_i[i]<upper_bound) ||
      (low_i[i]==upper_bound && high_i[i]!=0);
    assign bad[i]=low_i[i]>=23'd8380417 || high_i[i]>(param_i==0?6'd43:6'd15);
  end
  endgenerate
  assign count_o=3'(hint_o[0])+3'(hint_o[1])+3'(hint_o[2])+3'(hint_o[3]);
  assign error_o=param_i==3 || |bad;
endmodule
`default_nettype wire
