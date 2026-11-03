// Final FIPS sparse hint suffix -> four canonical hint bits per bank word.
// Validate counts, ordered indices and zero padding BEFORE any output credit.
// Only the bounded suffix (at most84 bytes) is retained, never a signature RAM.
`default_nettype none
module hintunpkg (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [1:0] command_param_i,input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,input wire logic [63:0] input_data_i,
  input wire logic [3:0] input_index_i,input_bytes_i,input wire logic input_last_i,
  output logic output_valid_o,input wire logic output_ready_i,output logic [3:0] output_hints_o,
  output logic [2:0] output_row_o,output logic [5:0] output_word_o,output logic output_last_o,
  output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,output logic [2:0] done_code_o,
  output logic [15:0] done_id_o
);
  typedef enum logic [2:0] {IDLE,FEED,COUNT,ORDER,PADDING,SETUP,EMIT,REPORT} state_e;
  state_e state;
  logic [10:0][63:0] suffix_r;
  logic [6:0] omega_r,position_r,start_r,end_r,next_position;
  logic [7:0] total_r,previous_r,count_byte,position_byte;
  logic [3:0] k_r,input_word_r,words_r,expected_bytes;
  logic [2:0] row_r;logic [5:0] word_r;
  logic [63:0] masked_input;logic push,bad_frame;
  logic [2:0] matched_positions;
  function automatic logic [7:0] byte_at(input logic [10:0][63:0] data,input logic [6:0] position);
    return position<88?data[position[6:3]][8*position[2:0]+:8]:8'd0;
  endfunction
  assign command_ready_o=!rst && state==IDLE;
  assign input_ready_o=!rst && state==FEED;
  assign expected_bytes=total_r-8'(input_word_r)*8'd8>=8?4'd8:4'(total_r-8'(input_word_r)*8'd8);
  assign bad_frame=input_index_i!=input_word_r || input_bytes_i!=expected_bytes || input_last_i!=(input_word_r+1'b1==words_r);
  assign output_valid_o=!rst && state==EMIT;
  assign output_row_o=row_r;assign output_word_o=word_r;assign output_last_o=word_r==63;
  assign output_id_o=done_id_o;
  assign done_valid_o=!rst && state==REPORT;
  assign push=output_valid_o && output_ready_i;
  assign count_byte=byte_at(suffix_r,omega_r+7'(row_r));
  assign position_byte=byte_at(suffix_r,position_r);
  always_comb begin
    masked_input=0;
    for(int lane=0;lane<8;lane++)if(lane<int'(expected_bytes))masked_input[8*lane+:8]=input_data_i[8*lane+:8];
    output_hints_o=0;matched_positions=0;
    // Canonical validation has already proved strictly increasing row indices.
    // At most four indices can belong to this word. Read the four consecutive
    // positions in PARALLEL;none of the RAM/mux addresses depends on a match.
    for(int offset=0;offset<4;offset++)begin
      logic [6:0] position;
      logic [7:0] index_byte;
      position=position_r+7'(offset);index_byte=byte_at(suffix_r,position);
      if(position<end_r && index_byte[7:2]==word_r)begin
        output_hints_o[index_byte[1:0]]=1;
        matched_positions=matched_positions+1'b1;
      end
    end
    next_position=position_r+7'(matched_positions);
  end
  // Payload is overwritten by the complete suffix before validation;no reset.
  always_ff @(posedge clk)if(!rst && input_valid_i && input_ready_o && !bad_frame)suffix_r[input_word_r]<=masked_input;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;omega_r<=0;position_r<=0;start_r<=0;end_r<=0;previous_r<=0;
      total_r<=0;k_r<=0;input_word_r<=0;words_r<=0;row_r<=0;word_r<=0;done_code_o<=0;done_id_o<=0;
    end else case(state)
      IDLE:if(command_valid_i)begin
        logic [7:0] total;
        total=command_param_i==0?84:command_param_i==1?61:83;
        omega_r<=command_param_i==0?80:command_param_i==1?55:75;
        k_r<=command_param_i==0?4:command_param_i==1?6:8;
        total_r<=total;words_r<=4'((total+7)>>3);input_word_r<=0;
        row_r<=0;word_r<=0;position_r<=0;start_r<=0;end_r<=0;previous_r<=0;
        done_id_o<=command_id_i;done_code_o<=command_param_i==3?1:0;state<=command_param_i==3?REPORT:FEED;
      end
      FEED:if(input_valid_i)begin
        if(bad_frame)begin done_code_o<=3;state<=REPORT;end
        else if(input_word_r+1'b1==words_r)state<=COUNT;
        else input_word_r<=input_word_r+1'b1;
      end
      COUNT:begin
        if(count_byte<{1'b0,position_r} || count_byte>{1'b0,omega_r})begin done_code_o<=2;state<=REPORT;end
        else begin start_r<=position_r;end_r<=count_byte[6:0];previous_r<=0;state<=ORDER;end
      end
      ORDER:begin
        if(position_r==end_r)begin
          if({1'b0,row_r}+4'd1==k_r)state<=PADDING;
          else begin row_r<=row_r+1'b1;state<=COUNT;end
        end else if(position_r>start_r && position_byte<=previous_r)begin done_code_o<=2;state<=REPORT;end
        else begin previous_r<=position_byte;position_r<=position_r+1'b1;end
      end
      PADDING:begin
        if(position_r==omega_r)state<=SETUP;
        else if(position_byte!=0)begin done_code_o<=2;state<=REPORT;end
        else position_r<=position_r+1'b1;
      end
      SETUP:begin row_r<=0;word_r<=0;position_r<=0;end_r<=7'(byte_at(suffix_r,omega_r));state<=EMIT;end
      EMIT:if(push)begin
        position_r<=next_position;
        if(word_r==63)begin
          if({1'b0,row_r}+4'd1==k_r)state<=REPORT;
          else begin row_r<=row_r+1'b1;word_r<=0;end_r<=7'(byte_at(suffix_r,omega_r+7'(row_r)+7'd1));end
        end else word_r<=word_r+1'b1;
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:begin done_code_o<=4;state<=REPORT;end
    endcase
  end
endmodule
`default_nettype wire
