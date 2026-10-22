// One elastic x4 process stage,64 ordered groups per polynomial.
// op0:Decompose,op1:CNB,op2:Mhint. Errors invalidate the tentative packet.
`default_nettype none
module sign_process (
  input wire logic clk,rst,input_valid_i,output logic input_ready_o,
  input wire logic [1:0] input_op_i,input_param_i,input_kind_i,
  input wire logic [15:0] input_id_i,input wire logic [5:0] input_index_i,
  input wire logic input_last_i,input wire logic [3:0][22:0] input_data_i,
  input wire logic [3:0][5:0] input_high_i,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic output_error_o,output logic [1:0] output_op_o,output_param_o,output_kind_o,
  output logic [15:0] output_id_o,output logic [5:0] output_index_o,
  output logic output_last_o,output logic [3:0][5:0] output_high_o,
  output logic [3:0][18:0] output_low_o,output logic [3:0] output_hint_o,output_lane_reject_o,
  output logic output_reject_o,output logic [8:0] output_weight_o
);
  logic [3:0][5:0] high;
  logic [3:0][18:0] low;
  logic [3:0] hints,rejects;
  logic [2:0] count;
  logic decomp_error,norm_error,hint_error,bad;
  logic active_r,reject_r;logic [5:0] next_r;
  logic [1:0] op_r,param_r,kind_r;logic [15:0] id_r;logic [8:0] weight_r;
  decompose_x4 decomposition(.param_i(input_param_i),.data_i(input_data_i),.high_o(high),.low_o(low),.error_o(decomp_error));
  cnb bounds(.param_i(input_param_i),.kind_i(input_kind_i),.data_i(input_data_i),.reject_o(rejects),.error_o(norm_error));
  mhint hints_block(.param_i(input_param_i),.low_i(input_data_i),.high_i(input_high_i),.hint_o(hints),.count_o(count),.error_o(hint_error));
  assign input_ready_o=!rst && (!output_valid_o || output_ready_i);
  assign bad=input_op_i==3 || input_last_i!=(input_index_i==63) ||
    (!active_r && input_index_i!=0) || (active_r && (input_index_i!=next_r ||
      input_id_i!=id_r || input_op_i!=op_r || input_param_i!=param_r ||
      (input_op_i==1 && input_kind_i!=kind_r))) ||
    (input_op_i==0?decomp_error:(input_op_i==1?norm_error:hint_error));
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      output_valid_o<=0;output_error_o<=0;output_op_o<=0;output_param_o<=0;output_kind_o<=0;
      output_id_o<=0;output_index_o<=0;output_last_o<=0;output_high_o<=0;output_low_o<=0;
      output_hint_o<=0;output_lane_reject_o<=0;output_reject_o<=0;output_weight_o<=0;
      active_r<=0;next_r<=0;op_r<=0;param_r<=0;kind_r<=0;id_r<=0;reject_r<=0;weight_r<=0;
    end else if(input_ready_o)begin
      output_valid_o<=input_valid_i;
      if(input_valid_i)begin
        output_error_o<=bad;output_op_o<=input_op_i;output_param_o<=input_param_i;output_kind_o<=input_kind_i;
        output_id_o<=input_id_i;output_index_o<=input_index_i;output_last_o<=input_last_i;
        output_high_o<=0;output_low_o<=0;output_hint_o<=0;output_lane_reject_o<=0;
        output_reject_o<=0;output_weight_o<=0;
        if(bad)begin active_r<=0;reject_r<=0;weight_r<=0;end
        else begin
          if(input_op_i==0)begin output_high_o<=high;output_low_o<=low;end
          if(input_op_i==1)begin output_lane_reject_o<=rejects;output_reject_o<=reject_r || |rejects;end
          if(input_op_i==2)begin output_hint_o<=hints;output_weight_o<=weight_r+9'(count);end
          active_r<=!input_last_i;next_r<=input_index_i+1'b1;
          op_r<=input_op_i;param_r<=input_param_i;kind_r<=input_kind_i;id_r<=input_id_i;
          reject_r<=!input_last_i && input_op_i==1 && (reject_r || |rejects);
          weight_r<=!input_last_i && input_op_i==2?weight_r+9'(count):9'd0;
        end
      end
    end
  end
endmodule
`default_nettype wire
