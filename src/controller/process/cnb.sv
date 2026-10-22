// Four centered infinity-norm checks. Equality with the bound rejects.
// kind0:z,kind1:LowBits(w-cs2),kind2:ct0. Caller reduces across vectors.
`default_nettype none
module cnb (
  input wire logic [1:0] param_i,kind_i,input wire logic [3:0][22:0] data_i,
  output logic [3:0] reject_o,output logic error_o
);
  logic [22:0] bound_value,beta,gamma1,gamma2;
  logic [3:0] bad;
  always_comb begin
    beta=param_i==0?23'd78:(param_i==1?23'd196:23'd120);
    gamma1=param_i==0?23'd131072:23'd524288;
    gamma2=param_i==0?23'd95232:23'd261888;
    bound_value=kind_i==0?gamma1-beta:(kind_i==1?gamma2-beta:gamma2);
  end
  for(genvar i=0;i<4;i++)begin:lanes
    wire [22:0] magnitude=data_i[i]>23'd4190208 ? 23'd8380417-data_i[i]:data_i[i];
    assign reject_o[i]=magnitude>=bound_value;
    assign bad[i]=data_i[i]>=23'd8380417;
  end
  assign error_o=param_i==3 || kind_i==3 || |bad;
endmodule
`default_nettype wire
