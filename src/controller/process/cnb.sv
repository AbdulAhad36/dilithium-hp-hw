// Four centered infinity-norm checks. Equality with the bound rejects.
// kind0:z,kind1:LowBits(w-cs2),kind2:ct0. Caller reduces across vectors.
`default_nettype none
module cnb (
  input wire logic [1:0] param_i,kind_i,input wire logic [3:0][22:0] data_i,
  output logic [3:0] reject_o,output logic error_o
);
  logic [22:0] lower_bound,upper_bound;
  logic [3:0] bad;
  always_comb begin
    // |centered(a)|>=B iff B<=a<=q-B for canonical coefficients.
    // Select the two constant thresholds once;no q-a or gamma-beta carry
    // chains sit between each RAM word and its four norm comparisons.
    case(kind_i)
      0:case(param_i)
        0:begin lower_bound=23'd130994;upper_bound=23'd8249423;end
        1:begin lower_bound=23'd524092;upper_bound=23'd7856325;end
        default:begin lower_bound=23'd524168;upper_bound=23'd7856249;end
      endcase
      1:case(param_i)
        0:begin lower_bound=23'd95154;upper_bound=23'd8285263;end
        1:begin lower_bound=23'd261692;upper_bound=23'd8118725;end
        default:begin lower_bound=23'd261768;upper_bound=23'd8118649;end
      endcase
      default:begin
        lower_bound=param_i==0?23'd95232:23'd261888;
        upper_bound=param_i==0?23'd8285185:23'd8118529;
      end
    endcase
  end
  genvar i;
  generate for(i=0;i<4;i=i+1)begin:lanes
    // Keep the old unsigned-wrap result on invalid a>q as well. At a==q,
    // the old magnitude is zero (not rejected),but error_o remains asserted.
    assign reject_o[i]=data_i[i]>23'd8380417 ||
      (data_i[i]>=lower_bound && data_i[i]<=upper_bound);
    assign bad[i]=data_i[i]>=23'd8380417;
  end
  endgenerate
  assign error_o=param_i==3 || kind_i==3 || |bad;
endmodule
`default_nettype wire
