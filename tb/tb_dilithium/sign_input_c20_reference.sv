// Final FIPS204 expanded SK frame:rho32|K32|tr64|s1|s2|t0.
// Only its128-byte header is retained here. Every polynomial is decoded
// directly through the shared Process loader into its fixed bank role.
// A successful header/field prefix is tentative until the complete frame passes.
`default_nettype none
module sign_input_c20_reference (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [1:0] command_param_i,input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [63:0] input_data_i,input wire logic [3:0] input_bytes_i,
  input wire logic [15:0] input_index_i,input wire logic input_last_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic [255:0] rho_o,key_o,output logic [511:0] tr_o,
  output logic poly_valid_o,output logic [1:0] poly_section_o,output logic [3:0] poly_index_o,
  output logic load_valid_o,input wire logic load_ready_i,
  output logic [2:0] load_op_o,output logic [1:0] load_param_o,load_bank_o,
  output logic [9:0] load_base_o,output logic [15:0] load_id_o,
  output logic load_input_valid_o,input wire logic load_input_ready_i,
  output logic [63:0] load_input_data_o,output logic [6:0] load_input_index_o,
  output logic [3:0] load_input_bytes_o,output logic load_input_last_o,
  input wire logic load_done_valid_i,output logic load_done_ready_o,
  input wire logic [2:0] load_done_code_i,input wire logic [15:0] load_done_id_i
);
  typedef enum logic [2:0] {IDLE,HEADER,LOAD_COMMAND,LOAD_DATA,LOAD_WAIT,REPORT} state_e;
  state_e state;
  logic [1:0] level_r,section_r;
  logic [3:0] k_r,l_r,poly_r;
  logic [9:0] word_r,total_words_r;
  logic [6:0] field_word_r,field_words;
  logic [1023:0] header_r;
  logic bad_frame;
  assign command_ready_o=!rst && state==IDLE;
  assign done_valid_o=!rst && state==REPORT;
  assign rho_o=header_r[255:0];assign key_o=header_r[511:256];assign tr_o=header_r[1023:512];
  assign field_words=section_r==2?52:level_r==1?16:12;
  assign bad_frame=input_bytes_i!=8 || input_index_i!={6'd0,word_r} || input_last_i!=(word_r+1'b1==total_words_r);
  assign input_ready_o=!rst && (state==HEADER || (state==LOAD_DATA && load_input_ready_i));
  assign load_valid_o=!rst && state==LOAD_COMMAND;
  assign load_op_o=section_r==2?1:2;assign load_param_o=level_r;
  assign load_bank_o=section_r==2?1:0;
  assign load_base_o=section_r==0?{poly_r,6'd0}:section_r==1?10'd448+{poly_r,6'd0}:10'd64+{poly_r,6'd0};
  assign load_id_o=done_id_o+16'd16+16'(section_r)*16'd16+16'(poly_r);
  assign load_input_valid_o=!rst && state==LOAD_DATA && input_valid_i;
  assign load_input_data_o=input_data_i;assign load_input_index_o=field_word_r;
  // A malformed host beat forces the shared decoder's bounded cleanup path.
  // Its per-polynomial last marker is independent of the whole-frame marker.
  assign load_input_bytes_o=bad_frame?4'd0:input_bytes_i;
  assign load_input_last_o=field_word_r+1'b1==field_words;
  assign load_done_ready_o=!rst && (state==LOAD_DATA || state==LOAD_WAIT);
  assign poly_valid_o=load_done_valid_i && load_done_ready_o && load_done_code_i==0 &&
    load_done_id_i==load_id_o && done_code_o==0;
  assign poly_section_o=section_r;assign poly_index_o=poly_r;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;level_r<=0;section_r<=0;k_r<=0;l_r<=0;poly_r<=0;word_r<=0;total_words_r<=0;
      field_word_r<=0;header_r<=0;done_code_o<=0;done_id_o<=0;
    end else begin
      case(state)
        IDLE:if(command_valid_i)begin
          level_r<=command_param_i;section_r<=0;poly_r<=0;word_r<=0;field_word_r<=0;
          k_r<=command_param_i==0?4:command_param_i==1?6:8;
          l_r<=command_param_i==0?4:command_param_i==1?5:7;
          total_words_r<=command_param_i==0?320:command_param_i==1?504:612;
          done_id_o<=command_id_i;done_code_o<=command_param_i==3?1:0;header_r<=0;
          state<=command_param_i==3?REPORT:HEADER;
        end
        HEADER:if(input_valid_i && input_ready_o)begin
          if(bad_frame)begin done_code_o<=3;state<=REPORT;end
          else begin
            header_r[64*word_r[3:0]+:64]<=input_data_i;word_r<=word_r+1'b1;
            if(word_r==15)state<=LOAD_COMMAND;
          end
        end
        LOAD_COMMAND:if(load_ready_i)begin field_word_r<=0;state<=LOAD_DATA;end
        LOAD_DATA:if(input_valid_i && input_ready_o)begin
          word_r<=word_r+1'b1;field_word_r<=field_word_r+1'b1;
          if(bad_frame)done_code_o<=3;
          if(bad_frame || field_word_r+1'b1==field_words)state<=LOAD_WAIT;
        end
        LOAD_WAIT:begin end
        REPORT:if(done_ready_i)state<=IDLE;
        default:state<=IDLE;
      endcase
      // Decode errors may finish before every encoded input word is consumed.
      // The loader has already zero-filled/retired its partial write burst.
      if(load_done_valid_i && load_done_ready_o)begin
        if(load_done_id_i!=load_id_o)begin done_code_o<=4;state<=REPORT;end
        else if(load_done_code_i!=0 || done_code_o!=0)begin
          if(done_code_o==0)done_code_o<=load_done_code_i==2?3'd2:3'd3;
          state<=REPORT;
        end else if(field_word_r!=field_words)begin done_code_o<=4;state<=REPORT;end
        // Explicit comparisons avoid a Quartus conditional-elaboration crash.
        // Same section limit,arithmetic width and transition clock.
        else if((section_r==0 && poly_r+1'b1==l_r) ||
                (section_r!=0 && poly_r+1'b1==k_r))begin
          if(section_r==2)begin
            if(word_r!=total_words_r)done_code_o<=4;
            state<=REPORT;
          end else begin section_r<=section_r+1'b1;poly_r<=0;state<=LOAD_COMMAND;end
        end else begin poly_r<=poly_r+1'b1;state<=LOAD_COMMAND;end
      end
    end
  end
endmodule
`default_nettype wire
