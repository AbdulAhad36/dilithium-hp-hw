// One of four published-width lanes: four consecutive low-first nibbles.
// Constant compare/subtract mapping avoids a hardware divide/modulo operation.
module sampler_secret_lane (
  input logic [15:0] word_i,
  input logic [2:0] nibbles_i,
  input logic eta4_i,
  output logic [3:0] valid_o,
  output logic [3:0][3:0] small_o
);
  logic [3:0] t, reduced;
  always_comb begin
    valid_o='0;small_o='0;t='0;reduced='0;
    for(int j=0;j<4;j++) begin
      t=word_i[j*4+:4];
      if(j<nibbles_i) begin
        if(eta4_i) begin
          if(t<9) begin
            valid_o[j]=1;
            small_o[j]=4'd4-t; // four-bit two's-complement [-4,+4]
          end
        end else if(t<15) begin
          valid_o[j]=1;
          reduced=t>=10 ? t-4'd10 : (t>=5 ? t-4'd5 : t);
          small_o[j]=4'd2-reduced;
        end
      end
    end
  end
endmodule
