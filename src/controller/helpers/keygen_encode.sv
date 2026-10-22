// Read retained KeyGen fields,pack PK/SK,and reuse the same raw SHAKE service.
// Caller leases all source regions until this module's held completion retires.
`default_nettype none
module keygen_encode (
  output dilithium_service_pkg::pack_request_t pack_o,
  input dilithium_service_pkg::pack_response_t pack_i,
  input wire logic clk,rst,start_valid_i,output logic start_ready_o,
  input wire logic [1:0] start_param_i,input wire logic [15:0] start_id_i,
  input wire logic [255:0] start_rho_i,start_key_i,
  output logic done_valid_o,input wire logic done_ready_i,output logic fault_o,
  output logic key_valid_o,input wire logic key_ready_i,output logic [63:0] key_data_o,
  output logic [3:0] key_bytes_o,output logic key_type_o,key_last_o,
  output logic [9:0] key_index_o,output logic [15:0] key_id_o,
  output logic read_valid_o,input wire logic read_ready_i,
  output logic [5:0] read_region_o,read_word_o,
  input wire logic response_valid_i,output logic response_ready_o,
  input wire logic response_error_i,response_domain_i,
  input wire logic [5:0] response_region_i,response_word_i,
  input wire logic [15:0] response_id_i,
  input wire logic [1:0] response_param_i,response_mode_i,
  input wire logic [91:0] response_data_i,
  output logic raw_valid_o,input wire logic raw_ready_i,raw_core_i,
  output logic raw_mode_o,output logic [15:0] raw_id_o,raw_message_len_o,raw_output_len_o,
  output logic [63:0] raw_input_data_o,output logic raw_input_valid_o,input wire logic raw_input_ready_i,
  input wire logic raw_output_valid_i,raw_output_core_i,input wire logic [15:0] raw_output_id_i,
  input wire logic [127:0] raw_output_data_i,input wire logic [4:0] raw_output_bytes_i,
  output logic raw_output_ready_o,input wire logic raw_done_valid_i,raw_done_core_i,
  input wire logic [15:0] raw_done_id_i,output logic raw_done_ready_o
);
  typedef enum logic [3:0] {IDLE,HASH_CMD,PK_HEADER,FIELD_CMD,READ_REQUEST,
    READ_RESPONSE,FEED,FIELD_DRAIN,WAIT_HASH,SK_HEADER,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] param_r,section_r,lane_r;
  logic [3:0] rows_r,columns_r,poly_r,header_r;
  logic [15:0] id_r;
  logic [255:0] rho_r,key_r;
  logic [511:0] tr_r;
  logic [2:0] tr_count_r;
  logic [5:0] word_r;
  logic [91:0] cache_r;
  logic hash_core_r,hash_issued_r,hash_retired_r,host_sent_r,hash_sent_r;
  logic pk_phase,packing,source_valid,source_ready,source_fire;
  logic [63:0] source_data;
  logic pack_ready,pack_input_ready,pack_valid,pack_last,pack_done;
  logic [2:0] pack_code;logic [15:0] pack_id,pack_done_id,source_id;
  logic [63:0] pack_data;logic [3:0] pack_bytes;logic [6:0] pack_index;
  logic [1:0] pack_op;
  logic [9:0] pk_words,sk_words;
  assign start_ready_o=!rst && state==IDLE && !fault_o;
  assign done_valid_o=!rst && state==REPORT && !fault_o;
  assign pk_phase=section_r==0;
  assign packing=state==READ_REQUEST || state==READ_RESPONSE || state==FEED || state==FIELD_DRAIN;
  assign pk_words=10'd4+10'(rows_r)*10'd40;
  assign sk_words=10'd16+10'(columns_r+rows_r)*(param_r==1?10'd16:10'd12)+10'(rows_r)*10'd52;
  assign key_type_o=!pk_phase;assign key_id_o=id_r;assign key_bytes_o=4'd8;
  assign key_last_o=key_index_o==(pk_phase?pk_words:sk_words)-10'd1;
  assign source_valid=!rst && !fault_o &&
    (state==PK_HEADER || state==SK_HEADER || (packing && pack_valid));
  assign source_data=state==PK_HEADER?rho_r[64*header_r+:64]:
    (state==SK_HEADER?(header_r<4?rho_r[64*header_r+:64]:
      (header_r<8?key_r[64*(header_r-4)+:64]:tr_r[64*(header_r-8)+:64])):pack_data);
  assign key_valid_o=source_valid && !host_sent_r;
  assign key_data_o=source_data;
  assign raw_input_valid_o=source_valid && pk_phase && !hash_sent_r;
  assign raw_input_data_o=source_data;
  assign source_ready=(host_sent_r || key_ready_i) && (!pk_phase || hash_sent_r || raw_input_ready_i);
  assign source_fire=source_valid && source_ready;
  assign raw_valid_o=!rst && state==HASH_CMD && !fault_o;
  assign raw_mode_o=1;assign raw_id_o=id_r+16'd1024;
  assign raw_message_len_o=16'(pk_words)*16'd8;assign raw_output_len_o=16'd64;
  assign raw_output_ready_o=!rst && hash_issued_r && tr_count_r<4 && !fault_o;
  assign raw_done_ready_o=!rst && hash_issued_r && tr_count_r==4 && !hash_retired_r && !fault_o;
  assign read_valid_o=!rst && state==READ_REQUEST && !fault_o;
  assign read_region_o=section_r==0?6'd40+6'(poly_r):(section_r==1?6'd1+6'(poly_r):
    (section_r==2?6'd8+6'(poly_r):6'd56+6'(poly_r)));
  assign read_word_o=word_r;
  assign source_id=(section_r==0 || section_r==3)?id_r+16'd768+16'(poly_r):
    id_r+16'd16+(section_r==1?16'(poly_r):16'(columns_r)+16'(poly_r));
  assign response_ready_o=state==READ_RESPONSE && !fault_o;
  assign pack_id=id_r+16'd2048+16'(section_r)*16'd16+16'(poly_r);
  assign pack_op=section_r==0?2'd0:(section_r==3?2'd1:2'd2);
  // Bitpkg lives in the shared main-controller service set.
  assign pack_o.command_valid=state==FIELD_CMD;
  assign pack_ready=pack_i.command_ready;
  assign pack_o.command_op=pack_op;
  assign pack_o.command_param=param_r;
  assign pack_o.command_id=pack_id;
  assign pack_o.input_valid=state==FEED && !fault_o;
  assign pack_input_ready=pack_i.input_ready;
  assign pack_o.input_data=cache_r[23*lane_r+:23];
  assign pack_o.input_index={word_r,lane_r};
  assign pack_o.input_last=word_r==63 && lane_r==3;
  assign pack_valid=pack_i.output_valid;
  assign pack_o.output_ready=packing && source_ready && !fault_o;
  assign pack_data=pack_i.output_data;
  assign pack_bytes=pack_i.output_bytes;
  assign pack_index=pack_i.output_index;
  assign pack_last=pack_i.output_last;
  assign pack_done=pack_i.done_valid;
  assign pack_o.done_ready=state==FIELD_DRAIN;
  assign pack_code=pack_i.done_code;
  assign pack_done_id=pack_i.done_id;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;param_r<=0;section_r<=0;lane_r<=0;rows_r<=0;columns_r<=0;poly_r<=0;header_r<=0;
      id_r<=0;rho_r<=0;key_r<=0;tr_r<=0;tr_count_r<=0;word_r<=0;cache_r<=0;
      hash_core_r<=0;hash_issued_r<=0;hash_retired_r<=0;host_sent_r<=0;hash_sent_r<=0;
      key_index_o<=0;fault_o<=0;
    end else begin
      if(source_fire)begin host_sent_r<=0;hash_sent_r<=0;key_index_o<=key_index_o+1'b1;end
      else begin
        if(key_valid_o && key_ready_i)host_sent_r<=1;
        if(raw_input_valid_o && raw_input_ready_i)hash_sent_r<=1;
      end
      if(raw_output_valid_i && raw_output_ready_o)begin
        if(raw_output_id_i!=raw_id_o || raw_output_core_i!=hash_core_r || raw_output_bytes_i!=16)begin
          fault_o<=1;state<=HALT;
        end else begin tr_r[128*tr_count_r+:128]<=raw_output_data_i;tr_count_r<=tr_count_r+1'b1;end
      end
      if(raw_done_valid_i && raw_done_ready_o)begin
        if(raw_done_id_i!=raw_id_o || raw_done_core_i!=hash_core_r)begin fault_o<=1;state<=HALT;end
        else hash_retired_r<=1;
      end
      case(state)
        IDLE:if(start_valid_i && start_ready_o)begin
          param_r<=start_param_i;id_r<=start_id_i;rho_r<=start_rho_i;key_r<=start_key_i;
          rows_r<=start_param_i==0?4:(start_param_i==1?6:8);
          columns_r<=start_param_i==0?4:(start_param_i==1?5:7);
          section_r<=0;poly_r<=0;header_r<=0;tr_r<=0;tr_count_r<=0;
          hash_issued_r<=0;hash_retired_r<=0;host_sent_r<=0;hash_sent_r<=0;key_index_o<=0;
          if(start_param_i==3)begin fault_o<=1;state<=HALT;end else state<=HASH_CMD;
        end
        HASH_CMD:if(raw_ready_i)begin hash_core_r<=raw_core_i;hash_issued_r<=1;state<=PK_HEADER;end
        PK_HEADER:if(source_fire)begin
          if(header_r==3)begin poly_r<=0;state<=FIELD_CMD;end else header_r<=header_r+1'b1;
        end
        FIELD_CMD:if(pack_ready)begin word_r<=0;lane_r<=0;state<=READ_REQUEST;end
        READ_REQUEST:if(read_ready_i)state<=READ_RESPONSE;
        READ_RESPONSE:if(response_valid_i)begin
          if(response_error_i || response_region_i!=read_region_o || response_word_i!=word_r ||
             response_id_i!=source_id || response_param_i!=param_r || response_domain_i ||
             response_mode_i!=((section_r==1 || section_r==2)?2'd1:2'd0))begin
            fault_o<=1;state<=HALT;
          end else begin cache_r<=response_data_i;lane_r<=0;state<=FEED;end
        end
        FEED:if(pack_input_ready)begin
          if(lane_r==3)begin
            lane_r<=0;
            if(word_r==63)state<=FIELD_DRAIN;
            else begin word_r<=word_r+1'b1;state<=READ_REQUEST;end
          end else lane_r<=lane_r+1'b1;
        end
        FIELD_DRAIN:if(pack_done)begin
          if(pack_code!=0 || pack_done_id!=pack_id)begin fault_o<=1;state<=HALT;end
          else if(poly_r+1<(section_r==1?columns_r:rows_r))begin poly_r<=poly_r+1'b1;state<=FIELD_CMD;end
          else if(section_r==0)state<=WAIT_HASH;
          else if(section_r==3)state<=REPORT;
          else begin section_r<=section_r+1'b1;poly_r<=0;state<=FIELD_CMD;end
        end
        WAIT_HASH:if(hash_retired_r)begin
          section_r<=1;header_r<=0;poly_r<=0;key_index_o<=0;state<=SK_HEADER;
        end
        SK_HEADER:if(source_fire)begin
          if(header_r==15)begin poly_r<=0;state<=FIELD_CMD;end else header_r<=header_r+1'b1;
        end
        REPORT:if(done_ready_i)state<=IDLE;
        default:state<=HALT;
      endcase
    end
  end
endmodule
`default_nettype wire
