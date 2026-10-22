// Canonical coefficient -> high6 and signed low19;positive tie and q-1 wrap.
`default_nettype none
module decompose (
  input wire logic [1:0] param_i,input wire logic [22:0] coefficient_i,
  output logic [5:0] high_o,output logic signed [18:0] low_o
);
  logic [31:0] coarse,scaled,high;
  logic signed [31:0] low;
  always_comb begin
    scaled=0;
    coarse=({9'b0,coefficient_i}+32'd127)>>7;
    if(param_i==0)begin
      scaled=(coarse*32'd11275+32'd8388608)>>24;
      high=scaled>43?32'd0:scaled;
      low=$signed({9'b0,coefficient_i})-$signed(high*32'd190464);
    end else begin
      high=((coarse*32'd1025+32'd2097152)>>22)&32'd15;
      low=$signed({9'b0,coefficient_i})-$signed(high*32'd523776);
    end
    if(low>32'sd4190208)low=low-32'sd8380417;
    high_o=6'(high);low_o=19'(low);
  end
endmodule
`default_nettype wire
