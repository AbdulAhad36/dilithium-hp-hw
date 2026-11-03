// Shared Figure1 x4 Process datapath. Constant arithmetic uses shifts/adds,
// not inferred DSP multiplication. Four elastic stages,one92-bit word/clock.
// ADD/SUB share a stage0 raw operation and stage1 correction.
// Carry/borrow uses the existing high field;output high is cleared.
// The operation controller owns polynomial order,vector bounds and key IDs.
`default_nettype none
module process_c17_reference (
  input wire logic clk,rst,input_valid_i,
  output logic input_ready_o,
  input var dilithium_pkg::process_op_e input_op_i,
  input wire logic [1:0] input_param_i,input_kind_i,
  input wire logic [7:0] input_tag_i,
  input wire logic [3:0][22:0] input_a_i,input_b_i,
  output logic output_valid_o,input wire logic output_ready_i,
  output dilithium_pkg::process_op_e output_op_o,
  output logic [7:0] output_tag_o,
  output logic output_error_o,
  output logic [3:0][22:0] output_data_o,
  output logic [3:0][9:0] output_high_o,
  output logic [3:0] output_reject_o,output_hint_o,
  output logic [2:0] output_weight_o
);
  import dilithium_pkg::*;
  typedef struct packed {
    process_op_e op;logic [7:0] tag;logic error;
    logic [3:0][22:0] data;logic [3:0][9:0] high;
    logic [3:0] reject,hint;logic [2:0] weight;
  } result_t;
  result_t value_r[4],computed,final_value,stage1_value;
  logic [3:0] valid_r;
  logic advance,norm_error,hint_error;
  logic [3:0] norm_reject,hints;
  logic [2:0] hint_count;
  logic [3:0][5:0] hint_high;
  logic [3:0][9:0] rounded_high;
  logic signed [13:0] rounded_low[4];
  logic [3:0][12:0] rounded_packed;
  logic [3:0][22:0] coefficient0_r,coefficient1_r;
  logic [3:0][15:0] coarse_r;
  logic [3:0][5:0] high1_r,high2_r;
  logic signed [24:0] low2_r[4];
  logic [1:0] level0_r,level1_r,level2_r;
  logic [3:0] hint0_r,hint1_r,hint2_r;
  function automatic logic [5:0] quotient(input logic [15:0] c,input logic [1:0] level);
    logic [29:0] a,b,d,product;logic [26:0] other;
    a=(30'(c)<<13)+(30'(c)<<11);
    b=(30'(c)<<10)+(30'(c)<<3);
    d=(30'(c)<<1)+30'(c);
    product=(a+b)+(d+30'd8388608); // c*11275+2^23,less than2^30
    other=(27'(c)<<10)+27'(c)+27'd2097152;
    if(level==0)return product[29:24]>43?6'd0:product[29:24];
    return {2'b0,other[25:22]}; // floor(.../2^22) mod16
  endfunction
  function automatic logic signed [24:0] residual(input logic [22:0] a,
                                                input logic [5:0] h,input logic [1:0] level);
    logic [12:0] times93;logic [23:0] multiple;
    // alpha2=93*2^11;alpha3/5=2^19-2^9. No variable multipliers.
    times93=((13'(h)<<6)+(13'(h)<<5))-((13'(h)<<1)+13'(h));
    multiple=level==0?{times93,11'b0}:((24'(h)<<19)-(24'(h)<<9));
    return $signed({2'b0,a})-$signed({1'b0,multiple});
  endfunction
  genvar lane;
  generate for(lane=0;lane<4;lane=lane+1)begin:rounding
    power2round p2r(.coefficient_i(input_a_i[lane]),.high_o(rounded_high[lane]),
      .low_o(rounded_low[lane]),.packed_t0_o(rounded_packed[lane]));
    assign hint_high[lane]=input_b_i[lane][5:0];
  end endgenerate
  cnb norm(.param_i(input_param_i),.kind_i(input_kind_i),.data_i(input_a_i),
    .reject_o(norm_reject),.error_o(norm_error));
  mhint make(.param_i(input_param_i),.low_i(input_a_i),.high_i(hint_high),
    .hint_o(hints),.count_o(hint_count),.error_o(hint_error));
  assign advance=!valid_r[3] || output_ready_i;
  assign input_ready_o=!rst && advance;
  assign output_valid_o=!rst && valid_r[3];
  assign output_op_o=value_r[3].op;assign output_tag_o=value_r[3].tag;
  assign output_error_o=value_r[3].error;assign output_data_o=value_r[3].data;
  assign output_high_o=value_r[3].high;assign output_reject_o=value_r[3].reject;
  assign output_hint_o=value_r[3].hint;assign output_weight_o=value_r[3].weight;
  always_comb begin
    computed='0;computed.op=input_op_i;computed.tag=input_tag_i;
    computed.error=input_param_i==3;
    for(int i=0;i<4;i++)begin
      logic [23:0] sum;logic subtract;
      computed.error|=input_a_i[i]>=Q;
      subtract=input_op_i==PROC_SUB;
      sum={1'b0,input_a_i[i]}+({1'b0,input_b_i[i]}^{24{subtract}})+24'(subtract);
      case(input_op_i)
        PROC_ADD,PROC_SUB:begin
          computed.error|=input_b_i[i]>=Q;
          computed.data[i]=sum[22:0];computed.high[i][0]=sum[23];
        end
        PROC_P2R:begin
          computed.high[i]=rounded_high[i];
          computed.data[i]=input_a_i[i][12:0]>13'd4096 ?
            {9'h1ff,({1'b0,input_a_i[i][12:0]}+14'd1)}:{10'd0,input_a_i[i][12:0]};
        end
        PROC_CNB:begin computed.error|=norm_error;computed.reject=norm_reject;end
        PROC_MHINT:begin
          computed.error|=hint_error || input_b_i[i][22:6]!=0;
          computed.hint=hints;computed.weight=hint_count;computed.data[i]=23'(hints[i]);
        end
        PROC_USEHINT:computed.error|=input_b_i[i]>1;
        PROC_PACK:computed.data[i]=input_a_i[i];
        default:begin end
      endcase
    end
    stage1_value=value_r[0];
    if(value_r[0].op==PROC_ADD || value_r[0].op==PROC_SUB)begin
      stage1_value.high=0;
      for(int i=0;i<4;i++)begin
        logic correct;logic [22:0] correction;
        correct=value_r[0].op==PROC_SUB?value_r[0].high[i][0]:
          (value_r[0].high[i][0] || value_r[0].data[i]>=Q);
        correction=value_r[0].op==PROC_SUB?Q:23'd8191;
        stage1_value.data[i]=correct?value_r[0].data[i]+correction:value_r[0].data[i];
      end
    end
    final_value=value_r[2];
    if(value_r[2].op==PROC_DECOMPOSE || value_r[2].op==PROC_USEHINT)begin
      for(int i=0;i<4;i++)begin
        logic signed [24:0] low;
        logic [5:0] corrected;
        low=low2_r[i]>25'sd4190208 ? low2_r[i]-25'sd8380417 : low2_r[i];
        corrected=high2_r[i];
        if(value_r[2].op==PROC_USEHINT && hint2_r[i])begin
          if(level2_r==0)corrected=low>0?(high2_r[i]==43?6'd0:high2_r[i]+6'd1):
            (high2_r[i]==0?6'd43:high2_r[i]-6'd1);
          else corrected=low>0?{2'b0,4'(high2_r[i]+6'd1)}:{2'b0,4'(high2_r[i]-6'd1)};
        end
        final_value.high[i]={4'b0,corrected};
        final_value.data[i]=value_r[2].op==PROC_USEHINT?23'(corrected):
          (low<0?23'(low+25'sd8380417):23'(low));
      end
    end
    if(final_value.error)begin
      final_value.data=0;final_value.high=0;final_value.reject=0;final_value.hint=0;final_value.weight=0;
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)valid_r<=0;
    else if(advance)valid_r<={valid_r[2:0],input_valid_i};
  end
  // Invalid payload registers need no reset or zeroing. Valid bits and the
  // shared enable preserve all offered data while the downstream is stalled.
  always_ff @(posedge clk)if(!rst && advance)begin
    if(input_valid_i)begin
      value_r[0]<=computed;coefficient0_r<=input_a_i;level0_r<=input_param_i;
      for(int i=0;i<4;i++)begin
        logic [23:0] biased;
        biased={1'b0,input_a_i[i]}+24'd127;
        coarse_r[i]<=biased[22:7];hint0_r[i]<=input_b_i[i]==1;
      end
    end
    if(valid_r[0])begin
      value_r[1]<=stage1_value;coefficient1_r<=coefficient0_r;
      level1_r<=level0_r;hint1_r<=hint0_r;
      for(int i=0;i<4;i++)high1_r[i]<=quotient(coarse_r[i],level0_r);
    end
    if(valid_r[1])begin
      value_r[2]<=value_r[1];level2_r<=level1_r;hint2_r<=hint1_r;high2_r<=high1_r;
      for(int i=0;i<4;i++)low2_r[i]<=residual(coefficient1_r[i],high1_r[i],level1_r);
    end
    if(valid_r[2])value_r[3]<=final_value;
  end
endmodule
`default_nettype wire
