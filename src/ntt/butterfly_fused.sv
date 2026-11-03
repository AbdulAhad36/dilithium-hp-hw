// Section III-D LightHD butterfly reconstruction for Cyclone V.
// CT: x=Redc(a+b*z),y=2a-x. GS: x=a+b,y=Redc((a+q-b)*z).
// Two native DSP stages replace multiply-then-add LUT arithmetic.
// Seven clocks,II=1;the core retains its existing GS halving convention.
// Candidate until unit/DSP/bank/full-operation gates qualify it.
`default_nettype none
module butterfly_fused #(parameter bit PUBLISHED_ORDER=1) (
  input wire logic clk,rst,
  input var ntt_pkg::bf_mode_e mode_i,
  input wire logic [22:0] a_i,b_i,zeta_i,
  output logic [22:0] a_o,b_o
);
  import ntt_pkg::*;
  logic [24:0] d_r,subtract_r;
  logic [22:0] keep_a_reg;
  logic [22:0] zeta_r,addend;
  logic [63:0] product_full;
  logic [46:0] product;
  logic [22:0] reduced;
  bf_mode_e mode_r,mode_delay[6];
  logic [22:0] keep_delay[6];
  assign addend=mode_r==BF_CT?keep_a_reg:23'd0;

  function automatic logic [22:0] add_mod(input logic [22:0] a,b);
    logic [23:0] sum,biased,ax,bx,bias,save_bits,carry;
    ax={1'b0,a};bx={1'b0,b};bias=24'd8191;
    sum=ax+bx;save_bits=ax^bx^bias;
    carry=((ax&bx)|(ax&bias)|(bx&bias))<<1;
    biased=save_bits+carry;
    return biased[23]?biased[22:0]:sum[22:0];
  endfunction
  function automatic logic [22:0] subtract_mod(input logic [22:0] a,b);
    logic [23:0] raw,corrected,ax,neg_b,modulus,save_bits,carry;
    ax={1'b0,a};neg_b=~{1'b0,b};modulus=24'd8380418;
    raw=ax-{1'b0,b};save_bits=ax^neg_b^modulus;
    carry=((ax&neg_b)|(ax&modulus)|(neg_b&modulus))<<1;
    corrected=save_bits+carry;
    return raw[23]?corrected[22:0]:raw[22:0];
  endfunction

  // A fixed subtracting pre-adder is used in BOTH modes. D=b,A=0 in CT;
  // D=a+q,A=b in GS. This adapts the DSP48 operation-mode switch to the
  // Cyclone V arithmetic expression. Actual hard-DSP fusion must be checked.
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      d_r<=0;subtract_r<=0;keep_a_reg<=0;zeta_r<=0;mode_r<=BF_CT;
      for(int i=0;i<6;i++)begin keep_delay[i]<=0;mode_delay[i]<=BF_CT;end
      a_o<=0;b_o<=0;
    end else begin
      // Clock1:operands and the companion result,independent of multiplier.
      d_r<=mode_i==BF_GS?25'(a_i)+25'd8380417:25'(b_i);
      subtract_r<=mode_i==BF_GS?25'(b_i):25'd0;
      keep_a_reg<=a_i;zeta_r<=zeta_i;mode_r<=mode_i;
      keep_delay[0]<=mode_i==BF_GS?add_mod(a_i,b_i):add_mod(a_i,a_i);
      mode_delay[0]<=mode_i;
      for(int i=1;i<6;i++)begin keep_delay[i]<=keep_delay[i-1];mode_delay[i]<=mode_delay[i-1];end
      // Clocks2/3:the native two-DSP chain below forms the fused product.
      // Clocks4..6:three-stage reduction below. Clock7:companion subtraction.
      if(PUBLISHED_ORDER)begin
        // The reducer ALWAYS drives portA,as in Section III-D. In INTT the
        // core's compact return decoder places (yi,xi) at logical addresses.
        a_o<=reduced;
        b_o<=mode_delay[5]==BF_GS?keep_delay[5]:subtract_mod(keep_delay[5],reduced);
      end else begin
        a_o<=mode_delay[5]==BF_GS?keep_delay[5]:reduced;
        b_o<=mode_delay[5]==BF_GS?reduced:subtract_mod(keep_delay[5],reduced);
      end
    end
  end
  // Canonical inputs bound GS's full product below2^47. Keep the carry bit
  // that a46-bit generic multiplier interface would incorrectly discard.
  assign product=product_full[46:0];
  dsp_fused_chain arithmetic(.clk(clk),.rst(rst),.d_i(d_r),
    .subtract_i(subtract_r),.zeta_i(zeta_r),.addend_i(addend),.result_o(product_full));
  butterfly_reduce reducer(.clk(clk),.rst(rst),.product_i(product),.result_o(reduced));
endmodule

// Cyclone V adaptation of the paper's two-DSP fused arithmetic. DSP48 has
// a fabric-driven C port;Cyclone V's chain input must come from a DSP's
// chain output. Its27x27 multiplier also fits the FULL product. Therefore
// DSP0 uses the hard signed pre-adder/multiplier,and DSP1 adds the delayed
// CT operand via its multiplier-by-one and hard chain adder. No data-driven
// fabric connection to CHAININ,no shifted partial-product chain,no LUT
// pre/post adders. Zero extension keeps all signed operands nonnegative.
module dsp_fused_chain (
  input wire logic clk,rst,
  input wire logic [24:0] d_i,subtract_i,
  input wire logic [22:0] zeta_i,addend_i,
  output wire [63:0] result_o
);
  wire [63:0] chain;
  logic [22:0] addend_r;
  always_ff @(posedge clk or posedge rst)if(rst)addend_r<=0;else addend_r<=addend_i;
  cyclonev_mac #(.operation_mode("m27x27"),.ax_width(27),
    .ay_scan_in_width(26),.az_width(26),.result_a_width(64),
    .signed_max("true"),.signed_may("true"),.operand_source_may("preadder"),
    .preadder_subtract_a("true"),.output_clock("0")) product_dsp(
    .ax({4'd0,zeta_i}),.ay({1'd0,d_i}),.az({1'd0,subtract_i}),
    .clk({2'd0,clk}),.ena(3'b111),.aclr({1'b0,rst}),.chainout(chain));
  cyclonev_mac #(.operation_mode("m27x27"),.ax_width(27),
    .ay_scan_in_width(27),.az_width(26),.result_a_width(64),
    .signed_max("true"),.signed_may("true"),.use_chainadder("true"),
    .output_clock("0")) add_dsp(
    .ax({4'd0,addend_r}),.ay(27'd1),.chainin(chain),
    .clk({2'd0,clk}),.ena(3'b111),.aclr({1'b0,rst}),.resulta(result_o));
endmodule

// Three-stage canonical reduction for every unsigned47-bit input.
// p = a + 2^23*b + 2^46*t,b=1024*h+l.
// p modq = a + 8191*l +7167*h +49145*t (modq).
// This nonnegative value is <2^27. A final fold is <2q.
module butterfly_reduce (
  input wire logic clk,rst,input wire logic [46:0] product_i,
  output logic [22:0] result_o
);
  logic [26:0] s0,c0,s1,c1,s2,c2,s3,c3,save_r,carry_r,fold_r;
  logic [26:0] x,y,z,n1,n2,k;
  logic [23:0] hs,lo,neg_hi,rs,rc,bs,bc,raw,biased;
  always_comb begin
    x={4'd0,product_i[32:23],13'd0};
    y={1'b0,product_i[45:33],13'd0};
    z={4'd0,product_i[22:0]};
    n1=~{4'd0,product_i[45:23]};n2=~{14'd0,product_i[45:33]};
    k=product_i[46]?27'd49147:27'd2;
    s0=x^y^z;c0=((x&y)|(x&z)|(y&z))<<1;
    s1=n1^n2^k;c1=((n1&n2)|(n1&k)|(n2&k))<<1;
    s2=s0^c0^s1;c2=((s0&c0)|(s0&s1)|(c0&s1))<<1;
    s3=s2^c2^c1;c3=((s2&c2)|(s2&c1)|(c2&c1))<<1;
    hs={7'd0,fold_r[26:23],13'd0};lo={1'b0,fold_r[22:0]};
    neg_hi=~{20'd0,fold_r[26:23]};
    rs=hs^lo^neg_hi;rc=((hs&lo)|(hs&neg_hi)|(lo&neg_hi))<<1;
    raw=rs+(rc|24'd1);
    // raw+8191 = hs+lo+~hi+8192. Compress before propagation so the
    // correction candidate runs in parallel with the uncorrected result.
    bs=rs^rc^24'd8192;
    bc=((rs&rc)|(rs&24'd8192)|(rc&24'd8192))<<1;
    biased=bs+bc;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin save_r<=0;carry_r<=0;fold_r<=0;result_o<=0;end
    else begin
      save_r<=s3;carry_r<=c3;
      fold_r<=save_r+carry_r;
      result_o<=biased[23]?biased[22:0]:raw[22:0];
    end
  end
endmodule
`default_nettype wire
