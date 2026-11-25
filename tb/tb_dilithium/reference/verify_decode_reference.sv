// Verification-only Stage7B.6 decoder,unchanged except module name/comments.
// Public-key/signature frame decoder. No encoded-key/signature RAM.
// kind0:rho||t1 -> canonical(t1<<13). kind1:ctilde||z||sparse hints.
// Outputs are tentative until done0;the owner discards the whole frame on error.
// done1:command/length,done2:signature norm/canonical hints,done3:transport framing.
`default_nettype none
module verify_decode_reference (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,busy_o,
  input wire logic command_kind_i,input wire logic [1:0] command_param_i,
  input wire logic [15:0] command_id_i,command_length_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [63:0] input_data_i,input wire logic [3:0] input_bytes_i,
  input wire logic [15:0] input_index_i,input wire logic input_last_i,
  output logic header_valid_o,input wire logic header_ready_i,
  output logic [511:0] header_data_o,output logic [6:0] header_bytes_o,
  output logic [15:0] header_id_o,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic [22:0] output_data_o,output logic [1:0] output_section_o,
  output logic [2:0] output_poly_o,output logic [7:0] output_index_o,
  output logic output_last_poly_o,output_last_frame_o,output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o
);
  typedef enum logic [3:0] {IDLE,HEADER,HEADER_OUT,PAYLOAD,HINT_INPUT,HINT_COUNT,
    HINT_ORDER,PADDING,HINT_OUT,REPORT} state_e;
  state_e state;
  logic kind_r;logic [1:0] param_r;logic [3:0] k_r,l_r;
  logic [15:0] length_r,received_r,word_r;logic [3:0] header_words_r;
  logic [83:0] bits_r;logic [6:0] count_r;
  // Maximum encoded hint suffix:omega80+K4=84 bytes at level2.
  logic [671:0] hints_r;logic [6:0] omega_r,hint_bytes_r,pos_r,start_r,end_r;
  logic [7:0] previous_r,index_r;logic [2:0] poly_r;
  logic [4:0] width;logic [19:0] encoded;logic [22:0] gamma,bound_value,z_value;
  logic [3:0] valid_bytes;logic bad_frame,bad_norm,push,pop,hint_bit;
  logic [7:0] hint_count;
  logic [15:0] expected_length;
  assign expected_length=command_kind_i?(command_param_i==0?16'd2420:command_param_i==1?16'd3309:16'd4627):
    (command_param_i==0?16'd1312:command_param_i==1?16'd1952:16'd2592);
  assign width=!kind_r?5'd10:param_r==0?5'd18:5'd20;
  assign encoded=bits_r[19:0]&((20'h1<<width)-1'b1);
  assign gamma=param_r==0?23'd131072:23'd524288;
  assign bound_value=gamma-(param_r==0?23'd78:param_r==1?23'd196:23'd120);
  assign z_value=23'(encoded)<=gamma?gamma-23'(encoded):23'd8380417+gamma-23'(encoded);
  assign bad_norm=kind_r && (z_value>23'd4190208 ? 23'd8380417-z_value : z_value)>=bound_value;
  assign valid_bytes=length_r-received_r>=8?4'd8:4'(length_r-received_r);
  assign bad_frame=input_bytes_i!=valid_bytes || input_index_i!=word_r ||
    input_last_i!=(received_r+16'(valid_bytes)==length_r);
  assign command_ready_o=!rst && state==IDLE;assign busy_o=state!=IDLE;
  assign input_ready_o=!rst && (state==HEADER || state==HINT_INPUT || (state==PAYLOAD && count_r<7'(width)));
  assign header_valid_o=!rst && state==HEADER_OUT;
  assign header_id_o=done_id_o;assign output_id_o=done_id_o;
  assign output_valid_o=!rst && ((state==PAYLOAD && count_r>=7'(width) && !bad_norm) || state==HINT_OUT);
  assign output_section_o=state==HINT_OUT?2'd2:kind_r?2'd1:2'd0;
  assign output_poly_o=poly_r;assign output_index_o=index_r;
  assign hint_bit=pos_r<end_r && index_r==hints_r[8*pos_r+:8];
  assign output_data_o=state==HINT_OUT?{22'd0,hint_bit}:kind_r?z_value:23'(encoded)<<13;
  assign output_last_poly_o=index_r==255;
  assign output_last_frame_o=index_r==255 && {1'b0,poly_r}==k_r-1'b1 && (!kind_r || state==HINT_OUT);
  assign hint_count=hints_r[8*(omega_r+7'(poly_r))+:8];
  assign done_valid_o=!rst && state==REPORT;
  assign push=input_valid_i && input_ready_o;assign pop=output_valid_o && output_ready_i;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;kind_r<=0;param_r<=0;k_r<=0;l_r<=0;length_r<=0;received_r<=0;word_r<=0;header_words_r<=0;
      bits_r<=0;count_r<=0;hints_r<=0;omega_r<=0;hint_bytes_r<=0;pos_r<=0;start_r<=0;end_r<=0;
      previous_r<=0;index_r<=0;poly_r<=0;header_data_o<=0;header_bytes_o<=0;done_code_o<=0;done_id_o<=0;
    end else case(state)
      IDLE:if(command_valid_i)begin
        kind_r<=command_kind_i;param_r<=command_param_i;done_id_o<=command_id_i;done_code_o<=0;
        length_r<=command_length_i;received_r<=0;word_r<=0;bits_r<=0;count_r<=0;hints_r<=0;
        hint_bytes_r<=0;pos_r<=0;start_r<=0;end_r<=0;previous_r<=0;index_r<=0;poly_r<=0;header_data_o<=0;
        k_r<=command_param_i==0?4'd4:command_param_i==1?4'd6:4'd8;
        l_r<=command_param_i==0?4'd4:command_param_i==1?4'd5:4'd7;
        omega_r<=command_param_i==0?7'd80:command_param_i==1?7'd55:7'd75;
        header_bytes_o<=!command_kind_i?7'd32:command_param_i==0?7'd32:command_param_i==1?7'd48:7'd64;
        header_words_r<=!command_kind_i?4'd4:command_param_i==0?4'd4:command_param_i==1?4'd6:4'd8;
        if(command_param_i==3 || command_length_i!=expected_length)begin done_code_o<=1;state<=REPORT;end
        else state<=HEADER;
      end
      HEADER:if(push)begin
        if(bad_frame)begin done_code_o<=3;state<=REPORT;end
        else begin
          header_data_o[64*word_r+:64]<=input_data_i;word_r<=word_r+1'b1;received_r<=received_r+8;
          if(word_r==16'(header_words_r)-1'b1)state<=HEADER_OUT;
        end
      end
      HEADER_OUT:if(header_ready_i)state<=PAYLOAD;
      PAYLOAD:begin
        if(push)begin
          if(bad_frame)begin done_code_o<=3;state<=REPORT;bits_r<=0;count_r<=0;end
          else begin bits_r<=bits_r|(84'(input_data_i)<<count_r);count_r<=count_r+64;word_r<=word_r+1'b1;received_r<=received_r+8;end
        end
        if(count_r>=7'(width) && bad_norm)begin done_code_o<=2;state<=REPORT;bits_r<=0;count_r<=0;end
        else if(pop)begin
          bits_r<=bits_r>>width;count_r<=count_r-7'(width);index_r<=index_r+1'b1;
          if(index_r==255)begin
            index_r<=0;
            if({1'b0,poly_r}==(kind_r?l_r:k_r)-1'b1)begin
              poly_r<=0;
              if(kind_r)state<=HINT_INPUT;
              else begin done_code_o<=received_r==length_r && count_r==7'(width)?3'd0:3'd3;state<=REPORT;end
            end else poly_r<=poly_r+1'b1;
          end
        end
      end
      HINT_INPUT:if(push)begin
        if(bad_frame)begin done_code_o<=3;state<=REPORT;end
        else begin
          for(int b=0;b<8;b++)if(b<int'(valid_bytes))hints_r[8*(int'(hint_bytes_r)+b)+:8]<=input_data_i[8*b+:8];
          hint_bytes_r<=hint_bytes_r+7'(valid_bytes);word_r<=word_r+1'b1;received_r<=received_r+16'(valid_bytes);
          if(input_last_i)begin state<=HINT_COUNT;poly_r<=0;pos_r<=0;start_r<=0;end
        end
      end
      HINT_COUNT:begin
        if(hint_count<{1'b0,pos_r} || hint_count>{1'b0,omega_r})begin done_code_o<=2;state<=REPORT;end
        else begin end_r<=hint_count[6:0];start_r<=pos_r;state<=HINT_ORDER;end
      end
      HINT_ORDER:begin
        if(pos_r<end_r)begin
          if(pos_r>start_r && hints_r[8*pos_r+:8]<=previous_r)begin done_code_o<=2;state<=REPORT;end
          else begin previous_r<=hints_r[8*pos_r+:8];pos_r<=pos_r+1'b1;end
        end else if({1'b0,poly_r}==k_r-1'b1)state<=PADDING;
        else begin poly_r<=poly_r+1'b1;state<=HINT_COUNT;end
      end
      PADDING:begin
        if(pos_r<omega_r)begin
          if(hints_r[8*pos_r+:8]!=0)begin done_code_o<=2;state<=REPORT;end
          else pos_r<=pos_r+1'b1;
        end else begin state<=HINT_OUT;poly_r<=0;index_r<=0;pos_r<=0;end_r<=hints_r[8*omega_r+:8];end
      end
      HINT_OUT:if(pop)begin
        if(hint_bit)pos_r<=pos_r+1'b1;
        index_r<=index_r+1'b1;
        if(index_r==255)begin
          if({1'b0,poly_r}==k_r-1'b1)begin done_code_o<=0;state<=REPORT;end
          else begin poly_r<=poly_r+1'b1;end_r<=hints_r[8*(omega_r+7'(poly_r)+1)+:8];end
        end
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:begin done_code_o<=3;state<=REPORT;end
    endcase
  end
endmodule
`default_nettype wire
