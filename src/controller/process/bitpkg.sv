// KeyGen polynomial bit packing. First byte is output_data_o[7:0].
// op0:t1(10 bits),op1:t0(13 bits),op2:eta-s(3/4 bits).
// One87-bit reservoir;no full-polynomial/key RAM. Final done owns packet validity.
`default_nettype none
module bitpkg (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [1:0] command_op_i,command_param_i,
  input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [22:0] input_data_i,input wire logic [7:0] input_index_i,
  input wire logic input_last_i,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic [63:0] output_data_o,output logic [3:0] output_bytes_o,
  output logic [6:0] output_index_o,output logic output_last_o,
  output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o
);
  typedef enum logic [1:0] {IDLE,FEED,REPORT} state_e;
  state_e state;
  logic [86:0] bits_r,bits_next;
  logic [6:0] count_r,count_next;
  logic [8:0] index_r;
  logic [1:0] op_r;
  logic [4:0] width_r;
  logic [2:0] eta_r;
  logic ended_r,pop,push,bad_value,bad_frame;
  logic [23:0] encoded;
  assign command_ready_o=!rst && state==IDLE;
  assign output_valid_o=!rst && state==FEED && count_r>=64;
  assign output_data_o=bits_r[63:0];assign output_bytes_o=4'd8;
  assign output_last_o=ended_r && count_r==64;
  assign output_id_o=done_id_o;
  assign input_ready_o=!rst && state==FEED && !ended_r && (!output_valid_o || output_ready_i);
  assign done_valid_o=!rst && state==REPORT;
  assign pop=output_valid_o && output_ready_i;assign push=input_valid_i && input_ready_o;
  always_comb begin
    encoded=0;bad_value=input_data_i>=23'd8380417;
    case(op_r)
      0:begin encoded={1'b0,input_data_i};bad_value|=input_data_i>1023;end
      1:begin
        bad_value|=(input_data_i>4096 && input_data_i<23'd8376322);
        encoded=input_data_i<=4096?24'd4096-{1'b0,input_data_i}:
          24'd8384513-{1'b0,input_data_i};
      end
      default:begin
        bad_value|=(input_data_i>23'(eta_r) && input_data_i<23'd8380417-23'(eta_r));
        encoded=input_data_i<=23'(eta_r)?24'(eta_r)-{1'b0,input_data_i}:
          24'd8380417+24'(eta_r)-{1'b0,input_data_i};
      end
    endcase
    bad_frame=index_r>255 || input_index_i!=index_r[7:0] || input_last_i!=(index_r==255);
    bits_next=pop?(bits_r>>64):bits_r;
    count_next=pop?count_r-7'd64:count_r;
    if(push && !bad_value && !bad_frame)begin
      bits_next=bits_next | (87'(encoded)<<count_next);
      count_next=count_next+7'(width_r);
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;bits_r<=0;count_r<=0;index_r<=0;op_r<=0;width_r<=0;eta_r<=0;
      ended_r<=0;output_index_o<=0;done_code_o<=0;done_id_o<=0;
    end else case(state)
      IDLE:if(command_valid_i)begin
        op_r<=command_op_i;done_id_o<=command_id_i;done_code_o<=0;
        bits_r<=0;count_r<=0;index_r<=0;ended_r<=0;output_index_o<=0;
        eta_r<=command_param_i==1?3'd4:3'd2;
        width_r<=command_op_i==0?5'd10:(command_op_i==1?5'd13:(command_param_i==1?5'd4:5'd3));
        if(command_op_i==3 || command_param_i==3)begin done_code_o<=1;state<=REPORT;end
        else state<=FEED;
      end
      FEED:begin
        bits_r<=bits_next;count_r<=count_next;
        if(pop)begin
          output_index_o<=output_index_o+1'b1;
          if(ended_r && count_r==64)state<=REPORT;
        end
        if(push)begin
          if(bad_frame || bad_value)begin
            done_code_o<=bad_frame?3'd3:3'd2;bits_r<=0;count_r<=0;state<=REPORT;
          end else begin index_r<=index_r+1'b1;if(input_last_i)ended_r<=1;end
        end
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:state<=IDLE;
    endcase
  end
endmodule
`default_nettype wire
