// FIPS sparse hint suffix. Four MHint bits per word,ascending coefficient
// order. Only two adjacent64-bit index words can change per input beat.
// Counts are separate8-bit registers;unwritten padding is generated as zero,
// so the640-bit index payload needs neither reset nor whole-array clearing.
`default_nettype none
module hintpkg_c13_reference (
  input wire logic clk,rst,cancel_i,command_valid_i,output logic command_ready_o,
  input wire logic [1:0] command_param_i,input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [3:0] input_hints_i,input wire logic [2:0] input_row_i,
  input wire logic [5:0] input_word_i,input wire logic input_last_i,
  output logic result_valid_o,result_reject_o,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic [63:0] output_data_o,output logic [3:0] output_bytes_o,output_index_o,
  output logic output_last_o,output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,output logic [1:0] done_code_o
);
  typedef enum logic [1:0] {IDLE,FEED,OUTPUT,REPORT} state_e;
  state_e state;
  logic [63:0] indices_r[10],first_word,second_word;
  logic [7:0] counts_r[8];
  logic [6:0] total_r,omega_r,new_total;
  logic [3:0] row_r,k_r,word_out_r;
  logic [5:0] word_r;
  logic [3:0] first_index,second_index;
  logic first_write,second_write,push,bad_frame,overflow;
  assign command_ready_o=!rst && state==IDLE;
  assign input_ready_o=!rst && !cancel_i && state==FEED;
  assign push=input_valid_i && input_ready_o;
  assign result_valid_o=!rst && !cancel_i && (state==OUTPUT || state==REPORT);
  assign output_valid_o=!rst && !cancel_i && state==OUTPUT;
  assign output_index_o=word_out_r;
  assign output_last_o=8'(word_out_r)*8'd8+8'd8>={1'b0,omega_r}+8'(k_r);
  assign output_bytes_o=output_last_o?4'({1'b0,omega_r}+8'(k_r)-8'(word_out_r)*8'd8):4'd8;
  assign done_valid_o=!rst && !cancel_i && state==REPORT;
  always_comb begin
    new_total=total_r;first_index=total_r[6:3];second_index=first_index+1'b1;
    first_word=first_index<10?indices_r[first_index]:64'd0;
    second_word=second_index<10?indices_r[second_index]:64'd0;
    first_write=0;second_write=0;
    for(int lane=0;lane<4;lane++)if(input_hints_i[lane])begin
      if(new_total<omega_r && !result_reject_o)begin
        if(new_total[6:3]==first_index)begin
          first_word[8*new_total[2:0]+:8]={word_r,2'(lane)};first_write=1;
        end else begin
          second_word[8*new_total[2:0]+:8]={word_r,2'(lane)};second_write=1;
        end
      end
      new_total=new_total+1'b1;
    end
    overflow=new_total>omega_r;
    bad_frame={1'b0,input_row_i}!=row_r || input_word_i!=word_r || input_last_i!=(word_r==63);
    output_data_o=0;
    for(int lane=0;lane<8;lane++)begin
      logic [7:0] position;
      position={word_out_r,3'd0}+8'(lane);
      if(position<{1'b0,total_r} && word_out_r<10)output_data_o[8*lane+:8]=indices_r[word_out_r][8*lane+:8];
      else if(position>={1'b0,omega_r} && position<{1'b0,omega_r}+8'(k_r))
        output_data_o[8*lane+:8]=counts_r[3'(position-{1'b0,omega_r})];
    end
  end
  // Payload registers are never reset. Invalid bytes are masked above.
  always_ff @(posedge clk)if(!rst && !cancel_i && push && !bad_frame && !result_reject_o && !overflow)begin
    if(first_write)indices_r[first_index]<=first_word;
    if(second_write)indices_r[second_index]<=second_word;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;total_r<=0;omega_r<=0;row_r<=0;k_r<=0;word_r<=0;word_out_r<=0;
      result_reject_o<=0;output_id_o<=0;done_code_o<=0;
      for(int i=0;i<8;i++)counts_r[i]<=0;
    end else if(cancel_i)begin state<=IDLE;total_r<=0;result_reject_o<=0;done_code_o<=0;end
    else case(state)
      IDLE:if(command_valid_i)begin
        total_r<=0;row_r<=0;word_r<=0;word_out_r<=0;result_reject_o<=0;output_id_o<=command_id_i;
        k_r<=command_param_i==0?4:command_param_i==1?6:8;
        omega_r<=command_param_i==0?80:command_param_i==1?55:75;
        done_code_o<=command_param_i==3?1:0;state<=command_param_i==3?REPORT:FEED;
      end
      FEED:if(push)begin
        if(bad_frame)begin done_code_o<=2;state<=REPORT;end
        else begin
          if(overflow)result_reject_o<=1;
          if(!result_reject_o && !overflow)total_r<=new_total;
          if(word_r==63)begin
            counts_r[row_r[2:0]]<=8'(new_total);
            if(row_r+1'b1==k_r)state<=result_reject_o || overflow?REPORT:OUTPUT;
            else begin row_r<=row_r+1'b1;word_r<=0;end
          end else word_r<=word_r+1'b1;
        end
      end
      OUTPUT:if(output_ready_i)begin
        if(output_last_o)state<=REPORT;else word_out_r<=word_out_r+1'b1;
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:state<=IDLE;
    endcase
  end
endmodule
`default_nettype wire
