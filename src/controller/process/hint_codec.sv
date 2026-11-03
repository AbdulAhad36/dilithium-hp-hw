// Shared Process hint codec:one suffix buffer and two index-word read ports.
// Registered decoded masks separate suffix lookups from physical RAM writes.
// Encoding and decoding commands are mutually exclusive;both FIPS formats
// retain their original framing,canonicality,reset and backpressure checks.
`default_nettype none
module hint_codec(
  input wire logic clk,rst,
  output logic idle_o,
  input wire logic  e_cancel_i,
  input wire logic  e_command_valid_i,
  output logic  e_command_ready_o,
  input wire logic [1:0] e_command_param_i,
  input wire logic [15:0] e_command_id_i,
  input wire logic  e_input_valid_i,
  output logic  e_input_ready_o,
  input wire logic [3:0] e_input_hints_i,
  input wire logic [2:0] e_input_row_i,
  input wire logic [5:0] e_input_word_i,
  input wire logic  e_input_last_i,
  output logic  e_result_valid_o,
  output logic  e_result_reject_o,
  output logic  e_output_valid_o,
  input wire logic  e_output_ready_i,
  output logic [63:0] e_output_data_o,
  output logic [3:0] e_output_bytes_o,
  output logic [3:0] e_output_index_o,
  output logic  e_output_last_o,
  output logic [15:0] e_output_id_o,
  output logic  e_done_valid_o,
  input wire logic  e_done_ready_i,
  output logic [1:0] e_done_code_o,
  input wire logic  d_command_valid_i,
  output logic  d_command_ready_o,
  input wire logic [1:0] d_command_param_i,
  input wire logic [15:0] d_command_id_i,
  input wire logic  d_input_valid_i,
  output logic  d_input_ready_o,
  input wire logic [63:0] d_input_data_i,
  input wire logic [3:0] d_input_index_i,
  input wire logic [3:0] d_input_bytes_i,
  input wire logic  d_input_last_i,
  output logic  d_output_valid_o,
  input wire logic  d_output_ready_i,
  output logic [3:0] d_output_hints_o,
  output logic [2:0] d_output_row_o,
  output logic [5:0] d_output_word_o,
  output logic  d_output_last_o,
  output logic [15:0] d_output_id_o,
  output logic  d_done_valid_o,
  input wire logic  d_done_ready_i,
  output logic [2:0] d_done_code_o,
  output logic [15:0] d_done_id_o
);
  logic [9:0][63:0] indices_r;
  logic [7:0][7:0] counts_r;
  logic [3:0] shared_read_index,shared_read_next;
  logic [3:0] read_index_r;
  logic [63:0] shared_read_first,shared_read_second;
  logic [31:0] decoded_window;
  logic d_output_pending_r,d_stage_ready;
  logic [3:0] d_generated_hints,d_registered_hints;
  logic [2:0] d_registered_row;
  logic [5:0] d_registered_word;
  logic d_registered_last;
  typedef enum logic [2:0] {d_IDLE,d_FEED,d_COUNT,d_ORDER,d_PADDING,d_SETUP,d_EMIT,d_REPORT} d_state_e;
  d_state_e d_state;

  typedef enum logic [1:0] {e_IDLE,e_FEED,e_OUTPUT,e_REPORT} e_state_e;
  e_state_e e_state;
  assign idle_o=e_state==e_IDLE && d_state==d_IDLE;
  logic [63:0] e_first_word,e_second_word;
  
  logic [6:0] e_total_r,e_omega_r,e_new_total;
  logic [3:0] e_row_r,e_k_r,e_word_out_r;
  logic [5:0] e_word_r;
  logic [3:0] e_first_index,e_second_index;
  logic e_first_write,e_second_write,e_push,e_bad_frame,e_overflow;
  logic [4:0][2:0] e_prefix;logic [3:0][6:0] e_target;
  assign e_command_ready_o=!rst && e_state==e_IDLE && d_state==d_IDLE;
  assign e_input_ready_o=!rst && !e_cancel_i && e_state==e_FEED;
  assign e_push=e_input_valid_i && e_input_ready_o;
  assign e_result_valid_o=!rst && !e_cancel_i && (e_state==e_OUTPUT || e_state==e_REPORT);
  assign e_output_valid_o=!rst && !e_cancel_i && e_state==e_OUTPUT;
  assign e_output_index_o=e_word_out_r;
  assign e_output_last_o=8'(e_word_out_r)*8'd8+8'd8>={1'b0,e_omega_r}+8'(e_k_r);
  assign e_output_bytes_o=e_output_last_o?4'({1'b0,e_omega_r}+8'(e_k_r)-8'(e_word_out_r)*8'd8):4'd8;
  assign e_done_valid_o=!rst && !e_cancel_i && e_state==e_REPORT;
  always_comb begin
    // Narrow parallel prefix counts:one7-bit base addition per lane,not
    // four serial7-bit increments controlled by the incoming hint mask.
    e_prefix[0]=0;e_prefix[1]=3'(e_input_hints_i[0]);
    e_prefix[2]=3'(e_input_hints_i[0])+3'(e_input_hints_i[1]);
    e_prefix[3]=e_prefix[2]+3'(e_input_hints_i[2]);
    e_prefix[4]=e_prefix[2]+(3'(e_input_hints_i[2])+3'(e_input_hints_i[3]));
    for(int lane=0;lane<4;lane++)e_target[lane]=e_total_r+7'(e_prefix[lane]);
    e_new_total=e_total_r+7'(e_prefix[4]);e_first_index=e_total_r[6:3];e_second_index=e_first_index+1'b1;
    e_first_word=shared_read_first;
    e_second_word=shared_read_second;
    e_first_write=0;e_second_write=0;
    for(int e_lane=0;e_lane<4;e_lane++)if(e_input_hints_i[e_lane])begin
      if(e_target[e_lane]<e_omega_r && !e_result_reject_o)begin
        if(e_target[e_lane][6:3]==e_first_index)begin
          e_first_word[8*e_target[e_lane][2:0]+:8]={e_word_r,2'(e_lane)};e_first_write=1;
        end else begin
          e_second_word[8*e_target[e_lane][2:0]+:8]={e_word_r,2'(e_lane)};e_second_write=1;
        end
      end
    end
    e_overflow=e_new_total>e_omega_r;
    e_bad_frame={1'b0,e_input_row_i}!=e_row_r || e_input_word_i!=e_word_r || e_input_last_i!=(e_word_r==63);
    e_output_data_o=0;
    for(int e_lane=0;e_lane<8;e_lane++)begin
      logic [7:0] e_position;
      e_position={e_word_out_r,3'd0}+8'(e_lane);
      if(e_position<{1'b0,e_total_r} && e_word_out_r<10)e_output_data_o[8*e_lane+:8]=shared_read_first[8*e_lane+:8];
      else if(e_position>={1'b0,e_omega_r} && e_position<{1'b0,e_omega_r}+8'(e_k_r))
        e_output_data_o[8*e_lane+:8]=counts_r[3'(e_position-{1'b0,e_omega_r})];
    end
  end
  // Payload registers are never reset. Invalid bytes are masked above.
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      e_state<=e_IDLE;e_total_r<=0;e_omega_r<=0;e_row_r<=0;e_k_r<=0;e_word_r<=0;e_word_out_r<=0;
      e_result_reject_o<=0;e_output_id_o<=0;e_done_code_o<=0;
      
    end else if(e_cancel_i)begin e_state<=e_IDLE;e_total_r<=0;e_result_reject_o<=0;e_done_code_o<=0;end
    else case(e_state)
      e_IDLE:if(e_command_valid_i && e_command_ready_o)begin
        e_total_r<=0;e_row_r<=0;e_word_r<=0;e_word_out_r<=0;e_result_reject_o<=0;e_output_id_o<=e_command_id_i;
        e_k_r<=e_command_param_i==0?4:e_command_param_i==1?6:8;
        e_omega_r<=e_command_param_i==0?80:e_command_param_i==1?55:75;
        e_done_code_o<=e_command_param_i==3?1:0;e_state<=e_command_param_i==3?e_REPORT:e_FEED;
      end
      e_FEED:if(e_push)begin
        if(e_bad_frame)begin e_done_code_o<=2;e_state<=e_REPORT;end
        else begin
          if(e_overflow)e_result_reject_o<=1;
          if(!e_result_reject_o && !e_overflow)e_total_r<=e_new_total;
          if(e_word_r==63)begin
            
            if(e_row_r+1'b1==e_k_r)e_state<=e_result_reject_o || e_overflow?e_REPORT:e_OUTPUT;
            else begin e_row_r<=e_row_r+1'b1;e_word_r<=0;end
          end else e_word_r<=e_word_r+1'b1;
        end
      end
      e_OUTPUT:if(e_output_ready_i)begin
        if(e_output_last_o)e_state<=e_REPORT;else e_word_out_r<=e_word_out_r+1'b1;
      end
      e_REPORT:if(e_done_ready_i)e_state<=e_IDLE;
      default:e_state<=e_IDLE;
    endcase
  end


  logic [6:0] d_omega_r,d_position_r,d_start_r,d_end_r,d_next_position;
  logic [7:0] d_total_r,d_previous_r,d_count_byte,d_position_byte;
  logic [3:0] d_k_r,d_input_word_r,d_words_r,d_expected_bytes;
  logic [2:0] d_row_r;logic [5:0] d_word_r;
  logic [63:0] d_masked_input;logic d_push,d_bad_frame;
  logic [2:0] d_matched_positions;
  logic [3:0] d_matches;
  logic [1:0] d_matches_low,d_matches_high;
  // Both directions use the SAME two consecutive index-word read ports.
  // Decode scans/emission only consume positions below omega;row counts
  // come directly from the separate eight-byte count bank.
  assign shared_read_index=read_index_r;
  assign shared_read_next=shared_read_index+4'd1;
  assign shared_read_first=shared_read_index<10?indices_r[shared_read_index]:64'd0;
  assign shared_read_second=shared_read_next<10?indices_r[shared_read_next]:64'd0;
  assign decoded_window=32'({shared_read_second,shared_read_first} >> {d_position_r[2:0],3'b0});
  assign d_command_ready_o=!rst && d_state==d_IDLE && e_state==e_IDLE && !e_command_valid_i;
  assign d_input_ready_o=!rst && d_state==d_FEED;
  assign d_expected_bytes=d_total_r-8'(d_input_word_r)*8'd8>=8?4'd8:4'(d_total_r-8'(d_input_word_r)*8'd8);
  assign d_bad_frame=d_input_index_i!=d_input_word_r || d_input_bytes_i!=d_expected_bytes || d_input_last_i!=(d_input_word_r+1'b1==d_words_r);
  assign d_output_valid_o=!rst && d_output_pending_r;
  assign d_stage_ready=!d_output_pending_r || d_output_ready_i;
  assign d_output_hints_o=d_registered_hints;
  assign d_output_row_o=d_registered_row;assign d_output_word_o=d_registered_word;assign d_output_last_o=d_registered_last;
  assign d_output_id_o=d_done_id_o;
  assign d_done_valid_o=!rst && d_state==d_REPORT && !d_output_pending_r;
  assign d_push=!rst && d_state==d_EMIT && d_stage_ready;
  assign d_count_byte=counts_r[d_row_r];
  assign d_position_byte=decoded_window[7:0];
  always_comb begin
    d_masked_input=0;
    for(int d_lane=0;d_lane<8;d_lane++)if(d_lane<int'(d_expected_bytes))d_masked_input[8*d_lane+:8]=d_input_data_i[8*d_lane+:8];
    d_generated_hints=0;d_matches=0;
    // Canonical validation has already proved strictly increasing row indices.
    // At most four indices can belong to this word. Read the four consecutive
    // positions in PARALLEL;none of the RAM/mux addresses depends on a match.
    for(int d_offset=0;d_offset<4;d_offset++)begin
      logic [6:0] d_position;
      logic [7:0] d_index_byte;
      d_position=d_position_r+7'(d_offset);d_index_byte=decoded_window[8*d_offset+:8];
      if(d_position<d_end_r && d_index_byte[7:2]==d_word_r)begin
        d_generated_hints[d_index_byte[1:0]]=1;
        d_matches[d_offset]=1;
      end
    end
  end
  // Count two pairs in parallel. Precompute each possible advance so the
  // index lookup does not feed a second,seven-bit carry chain in this cycle.
  assign d_matches_low={1'b0,d_matches[0]}+{1'b0,d_matches[1]};
  assign d_matches_high={1'b0,d_matches[2]}+{1'b0,d_matches[3]};
  assign d_matched_positions={1'b0,d_matches_low}+{1'b0,d_matches_high};
  always_comb case(d_matched_positions)
    0:d_next_position=d_position_r;
    1:d_next_position=d_position_r+7'd1;
    2:d_next_position=d_position_r+7'd2;
    3:d_next_position=d_position_r+7'd3;
    4:d_next_position=d_position_r+7'd4;
    default:d_next_position=d_position_r;
  endcase
  // Payload is overwritten by the complete suffix before validation;no reset.
  
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      d_state<=d_IDLE;d_omega_r<=0;d_position_r<=0;d_start_r<=0;d_end_r<=0;d_previous_r<=0;
      d_total_r<=0;d_k_r<=0;d_input_word_r<=0;d_words_r<=0;d_row_r<=0;d_word_r<=0;d_done_code_o<=0;d_done_id_o<=0;
    end else case(d_state)
      d_IDLE:if(d_command_valid_i && d_command_ready_o)begin
        logic [7:0] d_total;
        d_total=d_command_param_i==0?84:d_command_param_i==1?61:83;
        d_omega_r<=d_command_param_i==0?80:d_command_param_i==1?55:75;
        d_k_r<=d_command_param_i==0?4:d_command_param_i==1?6:8;
        d_total_r<=d_total;d_words_r<=4'((d_total+7)>>3);d_input_word_r<=0;
        d_row_r<=0;d_word_r<=0;d_position_r<=0;d_start_r<=0;d_end_r<=0;d_previous_r<=0;
        d_done_id_o<=d_command_id_i;d_done_code_o<=d_command_param_i==3?1:0;d_state<=d_command_param_i==3?d_REPORT:d_FEED;
      end
      d_FEED:if(d_input_valid_i)begin
        if(d_bad_frame)begin d_done_code_o<=3;d_state<=d_REPORT;end
        else if(d_input_word_r+1'b1==d_words_r)d_state<=d_COUNT;
        else d_input_word_r<=d_input_word_r+1'b1;
      end
      d_COUNT:begin
        if(d_count_byte<{1'b0,d_position_r} || d_count_byte>{1'b0,d_omega_r})begin d_done_code_o<=2;d_state<=d_REPORT;end
        else begin d_start_r<=d_position_r;d_end_r<=d_count_byte[6:0];d_previous_r<=0;d_state<=d_ORDER;end
      end
      d_ORDER:begin
        if(d_position_r==d_end_r)begin
          if({1'b0,d_row_r}+4'd1==d_k_r)d_state<=d_PADDING;
          else begin d_row_r<=d_row_r+1'b1;d_state<=d_COUNT;end
        end else if(d_position_r>d_start_r && d_position_byte<=d_previous_r)begin d_done_code_o<=2;d_state<=d_REPORT;end
        else begin d_previous_r<=d_position_byte;d_position_r<=d_position_r+1'b1;end
      end
      d_PADDING:begin
        if(d_position_r==d_omega_r)d_state<=d_SETUP;
        else if(d_position_byte!=0)begin d_done_code_o<=2;d_state<=d_REPORT;end
        else d_position_r<=d_position_r+1'b1;
      end
      d_SETUP:begin d_row_r<=0;d_word_r<=0;d_position_r<=0;d_end_r<=7'(counts_r[0]);d_state<=d_EMIT;end
      d_EMIT:if(d_push)begin
        d_position_r<=d_next_position;
        if(d_word_r==63)begin
          if({1'b0,d_row_r}+4'd1==d_k_r)d_state<=d_REPORT;
          else begin d_row_r<=d_row_r+1'b1;d_word_r<=0;d_end_r<=7'(counts_r[3'(d_row_r+3'd1)]);end
        end else d_word_r<=d_word_r+1'b1;
      end
      d_REPORT:if(d_done_ready_i && !d_output_pending_r)d_state<=d_IDLE;
      default:begin d_done_code_o<=4;d_state<=d_REPORT;end
    endcase
  end

  // Anticipate the existing counters' next address at the same clock edge.
  // This keeps owner/state selection in front of a small register,not in
  // series with both suffix lookups and decoder matching. No extra cycle.
  always_ff @(posedge clk or posedge rst)begin
    if(rst)read_index_r<=0;
    else if(d_command_valid_i && d_command_ready_o)read_index_r<=0;
    else if(d_state!=d_IDLE)begin
      case(d_state)
        d_ORDER:if(d_position_r!=d_end_r &&
          !(d_position_r>d_start_r && d_position_byte<=d_previous_r))
          read_index_r<=4'(7'(d_position_r+7'd1)>>3);
        d_PADDING:if(d_position_r!=d_omega_r && d_position_byte==0)
          read_index_r<=4'(7'(d_position_r+7'd1)>>3);
        d_SETUP:read_index_r<=0;
        d_EMIT:if(d_push)read_index_r<=d_next_position[6:3];
        default:begin end
      endcase
    end else if(e_command_valid_i && e_command_ready_o)read_index_r<=0;
    else if(e_cancel_i)read_index_r<=0;
    else case(e_state)
      e_FEED:if(e_push && !e_bad_frame && !e_result_reject_o && !e_overflow)begin
        if(e_word_r==63 && e_row_r+1'b1==e_k_r)read_index_r<=0;
        else read_index_r<=e_new_total[6:3];
      end
      e_OUTPUT:if(e_output_ready_i)read_index_r<=e_word_out_r+4'd1;
      default:begin end
    endcase
  end

  logic decode_write;
  // Store tentatively using the internal expected word address. Frame errors
  // still enter REPORT immediately;no masks are published from rejected data.
  // New decode commands refill all required bytes before count/order checking.
  assign decode_write=d_input_valid_i && d_input_ready_o;
  // One shared first-word write route and the encoder's optional second word.
  always_ff @(posedge clk)if(!rst)begin
    if(decode_write && d_input_word_r<10)indices_r[d_input_word_r]<=d_masked_input;
    else if(!e_cancel_i && e_push && !e_bad_frame && !e_result_reject_o && !e_overflow && e_first_write)
      indices_r[e_first_index]<=e_first_word;
    if(!e_cancel_i && e_push && !e_bad_frame && !e_result_reject_o && !e_overflow && e_second_write)
      indices_r[e_second_index]<=e_second_word;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)for(int i=0;i<8;i++)counts_r[i]<=0;
    else begin
      if(!e_cancel_i && e_state==e_FEED && e_push && !e_bad_frame && e_word_r==63)
        counts_r[e_row_r[2:0]]<=8'(e_new_total);
      if(decode_write)for(int lane=0;lane<8;lane++)begin
        logic [7:0] position;
        position={1'b0,d_input_word_r,3'b0}+8'(lane);
        if(position>=8'(d_omega_r) && position<8'(d_omega_r)+8'(d_k_r))
          counts_r[3'(position-8'(d_omega_r))]<=d_masked_input[8*lane+:8];
      end
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)d_output_pending_r<=0;
    else if(d_stage_ready)d_output_pending_r<=d_state==d_EMIT;
  end
  always_ff @(posedge clk)if(d_push)begin
    d_registered_hints<=d_generated_hints;d_registered_row<=d_row_r;
    d_registered_word<=d_word_r;d_registered_last<=d_word_r==63;
  end
`ifndef SYNTHESIS
  // synthesis translate_off
  always @(posedge clk)if(!rst)begin
    if((d_state==d_ORDER || d_state==d_PADDING || d_state==d_EMIT) &&
      read_index_r!==d_position_r[6:3])$fatal(1,"Hint decoder cached read address mismatch");
    if(!e_cancel_i && (e_state==e_FEED || e_state==e_OUTPUT) &&
      read_index_r!==(e_state==e_OUTPUT?e_word_out_r:e_total_r[6:3]))
      $fatal(1,"Hint encoder cached read address mismatch");
  end
  always @(posedge clk)if(!rst && e_state!=e_IDLE && d_state!=d_IDLE)
    $fatal(1,"Both hint directions active in one shared suffix buffer");
  // synthesis translate_on
`endif
endmodule

`default_nettype wire
