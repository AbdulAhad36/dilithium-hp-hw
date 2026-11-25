// Shared inverse of the packed Process formats. Secret output is16 signed
// nibbles for Figure5 regrouping;other formats are four canonical coefficients.
// No whole encoded key/signature buffer. Operation5 is t1 shifted by13 for
// Verify;operation0 retains unshifted t1. Format validation precedes credit.
`default_nettype none
module bitunpkg_c16_reference (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [2:0] command_op_i,input wire logic [1:0] command_param_i,
  input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [63:0] input_data_i,input wire logic [6:0] input_index_i,
  input wire logic [3:0] input_bytes_i,input wire logic input_last_i,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic [91:0] output_data_o,output logic [4:0] output_count_o,
  output logic [7:0] output_index_o,output logic output_last_o,
  output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o
);
  typedef enum logic [1:0] {IDLE,FEED,REPORT} state_e;
  state_e state;
  logic [143:0] bits_r,bits_next;
  logic [7:0] count_r,count_next,group_bits,refill_limit_r;
  logic [4:0] width_r;
  logic [2:0] op_r,eta_r;
  logic [19:0] gamma_r;
  logic [6:0] input_words_r,word_r;
  logic [8:0] coefficients_r;
  logic ended_r,pop,push,enough,bad_value,bad_frame;
  logic [15:0][19:0] field;
  logic [3:0][22:0] decoded;
  logic [15:0][3:0] small_value;
  assign command_ready_o=!rst && state==IDLE;
  assign done_valid_o=!rst && state==REPORT;
  assign output_id_o=done_id_o;
  assign output_count_o=op_r==2?16:4;
  assign enough=count_r>=group_bits;
  assign output_valid_o=!rst && state==FEED && enough && !bad_value;
  assign output_data_o=op_r==2?{28'd0,small_value}:92'(decoded);
  assign output_index_o=coefficients_r[7:0];
  assign output_last_o=coefficients_r+9'(output_count_o)==256;
  assign pop=output_valid_o && output_ready_i;
  // count +64 - (pop?group_bits:0) <=144,with the command's refill
  // threshold cached once. Preserve same-cycle pop/push without putting two
  // carry chains after downstream ready on the public input-ready path.
  assign input_ready_o=!rst && state==FEED && !ended_r && (!output_valid_o || output_ready_i) &&
    (count_r<=8'd80 || (pop && count_r<=refill_limit_r));
  assign push=input_valid_i && input_ready_o;
  always_comb begin
    field=0;decoded=0;small_value=0;bad_value=0;
    for(int lane=0;lane<16;lane++)begin
      if(op_r==2)field[lane]=width_r==3?20'(bits_r[3*lane+:3]):20'(bits_r[4*lane+:4]);
      else if(lane<4)case(width_r)
        4:field[lane]=20'(bits_r[4*lane+:4]);
        6:field[lane]=20'(bits_r[6*lane+:6]);
        10:field[lane]=20'(bits_r[10*lane+:10]);
        13:field[lane]=20'(bits_r[13*lane+:13]);
        18:field[lane]=20'(bits_r[18*lane+:18]);
        20:field[lane]=bits_r[20*lane+:20];
        default:field[lane]=0;
      endcase
      if(op_r==2)begin
        bad_value|=field[lane]>20'(eta_r<<1);
        small_value[lane]=4'(eta_r)-field[lane][3:0];
      end
    end
    for(int lane=0;lane<4;lane++)case(op_r)
      0:decoded[lane]=23'(field[lane]);
      5:decoded[lane]={field[lane][9:0],13'd0};
      1:decoded[lane]=field[lane]<=4096?23'd4096-23'(field[lane]):23'd8384513-23'(field[lane]);
      3:begin decoded[lane]=23'(field[lane]);bad_value|=field[lane]>(width_r==6?43:15);end
      4:decoded[lane]=field[lane]<=gamma_r?23'(gamma_r)-23'(field[lane]):
        23'd8380417+23'(gamma_r)-23'(field[lane]);
      default:decoded[lane]=0;
    endcase
    bad_frame=input_bytes_i!=8 || input_index_i!=word_r || input_last_i!=(word_r+1'b1==input_words_r);
    bits_next=pop?(bits_r>>group_bits):bits_r;
    count_next=count_r-(pop?group_bits:8'd0);
    if(push && !bad_frame)begin bits_next=bits_next | (144'(input_data_i)<<count_next);count_next=count_next+8'd64;end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;count_r<=0;bits_r<=0;op_r<=0;width_r<=0;eta_r<=0;gamma_r<=0;
      input_words_r<=0;word_r<=0;coefficients_r<=0;ended_r<=0;done_code_o<=0;done_id_o<=0;
      group_bits<=0;refill_limit_r<=0;
    end else case(state)
      IDLE:if(command_valid_i)begin
        logic [4:0] width;
        width=command_op_i==0 || command_op_i==5?10:command_op_i==1?13:command_op_i==2?
          (command_param_i==1?4:3):command_op_i==3?(command_param_i==0?6:4):(command_param_i==0?18:20);
        op_r<=command_op_i;width_r<=width;input_words_r<={width,2'b0};
        group_bits<=command_op_i==2?(8'(width)<<4):(8'(width)<<2);
        refill_limit_r<=8'd80+(command_op_i==2?(8'(width)<<4):(8'(width)<<2));
        eta_r<=command_param_i==1?4:2;gamma_r<=command_param_i==0?20'd131072:20'd524288;
        count_r<=0;bits_r<=0;word_r<=0;coefficients_r<=0;ended_r<=0;done_id_o<=command_id_i;
        done_code_o<=command_op_i>5 || command_param_i==3?1:0;
        state<=command_op_i>5 || command_param_i==3?REPORT:FEED;
      end
      FEED:begin
        if(pop || push)begin bits_r<=bits_next;count_r<=count_next;end
        if(pop)begin
          coefficients_r<=coefficients_r+9'(output_count_o);
          if(output_last_o)begin
            if(!ended_r || count_next!=0)done_code_o<=3;
            state<=REPORT;
          end
        end
        if(push)begin
          if(bad_frame)begin done_code_o<=3;state<=REPORT;count_r<=0;end
          else begin word_r<=word_r+1'b1;if(input_last_i)ended_r<=1;end
        end
        if(enough && bad_value)begin done_code_o<=2;state<=REPORT;count_r<=0;end
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:state<=IDLE;
    endcase
  end
endmodule
`default_nettype wire
