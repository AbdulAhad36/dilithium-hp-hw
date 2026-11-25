// Shared bank-word Process path:ADD/SUB/P2R/Decompose/CNB/MHint/UseHint.
// One arithmetic pipeline and one BitPkg. Each command retains only scalar
// addresses/counters. Low writes and packed-high consumption have independent
// credits,so backpressure never duplicates a word or couples bank ownership.
`default_nettype none
module process_dma #(parameter bit SHARED_HINT=0,parameter bit PIPELINE_PACK=0,
  parameter bit PIPELINE_OPERANDS=0,parameter bit PIPELINE_RESULTS=0) (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input var dilithium_pkg::process_op_e command_op_i,
  input wire logic [1:0] command_param_i,command_kind_i,
  input wire logic command_a_compact_i,command_b_enable_i,command_b_compact_i,command_low_enable_i,command_pack_high_i,
  input wire logic command_pack_store_i,input wire logic [2:0] command_pack_op_i,
  input wire logic command_hint_enable_i,
  input wire logic [1:0] command_a_bank_i,command_b_bank_i,command_d_bank_i,command_h_bank_i,
  input wire logic [9:0] command_a_base_i,command_b_base_i,command_d_base_i,command_h_base_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [1:0] done_code_o,output logic done_reject_o,output logic [8:0] done_hint_weight_o,
  output logic packed_valid_o,input wire logic packed_ready_i,
  output logic [63:0] packed_data_o,output logic [6:0] packed_index_o,
  output logic packed_last_o,
  output logic hint_valid_o,input wire logic hint_ready_i,
  output logic [3:0] hint_mask_o,output logic [5:0] hint_word_o,output logic hint_last_o,
  input var dilithium_pkg::hint_encode_request_t hint_encode_i,
  output dilithium_pkg::hint_encode_response_t hint_encode_o,
  input var dilithium_pkg::hint_decode_request_t hint_decode_i,
  output dilithium_pkg::hint_decode_response_t hint_decode_o,
  output logic hint_idle_o,
  output logic [1:0] memory_command_valid_o,input wire logic [1:0] memory_command_ready_i,
  output logic [1:0][3:0] memory_command_mask_o,memory_command_write_o,
  output logic [1:0][3:0][9:0] memory_command_base_o,
  output logic [1:0][3:0][10:0] memory_command_words_o,
  output logic [1:0][3:0][1:0] memory_command_mode_o,
  output logic [1:0][3:0] memory_write_valid_o,input wire logic [1:0][3:0] memory_write_ready_i,
  output logic [1:0][3:0][91:0] memory_write_data_o,
  input wire logic [1:0][3:0] memory_read_valid_i,
  output logic [1:0][3:0] memory_read_ready_o,
  input wire logic [1:0][3:0][91:0] memory_read_data_i,
  input wire logic [1:0][3:0] memory_done_valid_i,memory_done_error_i,
  output logic [1:0][3:0] memory_done_ready_o
);
  import dilithium_pkg::*;
  typedef enum logic [2:0] {IDLE,RESERVE,STREAM,REPORT} state_e;
  state_e state;
  process_op_e op_r;
  logic [1:0] level_r,kind_r;
  logic a_compact_r,b_enable_r,b_compact_r,low_enable_r,pack_r,pack_store_r,hint_enable_r;
  logic [2:0] pack_op_r;
  (* preserve *) logic pack_raw_r;
  logic [1:0] bank_r[4];logic [9:0] base_r[4];
  logic [3:0] port_r,port_next,enabled;
  logic [1:0][3:0] mask_r,write_r,mask_next,write_next,completed_r;
  logic [1:0] sent_r;
  logic pack_sent_r,pack_finished_r,low_sent_r,high_sent_r,hint_sent_r;
  logic bad_command,available,all_commands,all_done;
  logic packed_base_bad;
  // Compare the base against each CONSTANT bound in parallel. Operation
  // selection follows those comparisons instead of preceding an 11-bit add.
  // Equality at base+words==1024 remains legal;no command/pipeline clocks added.
  assign packed_base_bad=command_op_i==PROC_P2R?(command_h_base_i>10'd984):
    command_op_i==PROC_PACK?
      command_pack_op_i==0?(command_h_base_i>10'd984):
      command_pack_op_i==1?(command_h_base_i>10'd972):
      command_pack_op_i==2?(command_param_i==1?(command_h_base_i>10'd1008):(command_h_base_i>10'd1012)):
      command_pack_op_i==3?(command_param_i==0?(command_h_base_i>10'd1000):(command_h_base_i>10'd1008)):
      (command_param_i==0?(command_h_base_i>10'd952):(command_h_base_i>10'd944)):
    command_param_i==0?(command_h_base_i>10'd1000):(command_h_base_i>10'd1008);

  logic a_busy_a,a_busy_b,a_accepted,b_busy_a,b_busy_b,b_accepted;
  logic [1:0] selected_bank[4];logic [9:0] selected_base[4];
  logic [6:0] consumed_r,produced_r;
  logic [10:0] packed_words_r;
  logic process_valid,process_ready,result_valid,result_ready,result_error;
  logic operand_valid_r,operand_ready,operand_take,operand_pop;
  logic [1:0] operand_count_r;
  logic operand_read_r,operand_write_r;
  (* ramstyle="logic" *) logic [1:0][91:0] operand_a_store_r,operand_b_store_r;
  (* ramstyle="logic" *) logic [1:0][5:0] operand_tag_store_r;
  logic [91:0] operand_a_r,operand_b_r;
  logic [6:0] operand_tag_r;
  logic [3:0][22:0] process_a,process_b,result_data,pack_data;
  logic operand_feed_valid;
  logic [3:0][22:0] operand_feed_a,operand_feed_b;
  logic [6:0] operand_feed_tag;
  logic [3:0][9:0] arithmetic_high;
  logic [3:0] result_reject,result_hint;
  logic [2:0] result_weight;
  logic [7:0] result_tag;
  typedef struct packed {
    logic [3:0][22:0] data;
    logic [3:0] reject,hint;
    logic [2:0] weight;
    logic [7:0] tag;
    logic error;
  } process_result_t;
  typedef struct packed {
    process_result_t result;
    logic [3:0][22:0] pack_fields;
  } queued_result_t;
  process_result_t arithmetic_result,result_head;
  logic [3:0][22:0] selected_pack_fields;
  logic arithmetic_valid,arithmetic_ready;
  logic pack_command,pack_command_ready,pack_input_valid,pack_input_ready,pack_output_valid,pack_output_ready,pack_done;
  logic [63:0] packed_data;logic [3:0] packed_bytes;
  logic [6:0] packed_index;logic packed_last;logic [2:0] packed_code;
  logic low_fire,high_fire,result_fire;
  logic low_blocked,pack_blocked,hint_blocked;
  logic codec_hint_ready,hint_consumer_ready;
  assign hint_consumer_ready=SHARED_HINT?
    (hint_encode_i.feed_enable && codec_hint_ready):hint_ready_i;
  generate if(SHARED_HINT)begin:shared_hint
    hint_codec #(.PIPELINE_APPEND(1),.PREDECODE_HINT(1)) codec(
      .clk(clk),.rst(rst),.idle_o(hint_idle_o),
      .e_cancel_i(hint_encode_i.cancel),.e_command_valid_i(hint_encode_i.valid),
      .e_command_ready_o(hint_encode_o.ready),.e_command_param_i(hint_encode_i.param),.e_command_id_i(hint_encode_i.id),
      .e_input_valid_i(hint_valid_o && hint_encode_i.feed_enable),.e_input_ready_o(codec_hint_ready),
      .e_input_hints_i(result_hint),.e_input_row_i(hint_encode_i.row),
      .e_input_word_i(result_tag[5:0]),.e_input_last_i(result_tag==63),
      .e_result_valid_o(hint_encode_o.result_valid),.e_result_reject_o(hint_encode_o.reject),
      .e_output_valid_o(hint_encode_o.output_valid),.e_output_ready_i(hint_encode_i.output_ready),
      .e_output_data_o(hint_encode_o.output_data),.e_output_bytes_o(hint_encode_o.output_bytes),
      .e_output_index_o(hint_encode_o.output_index),.e_output_last_o(hint_encode_o.output_last),
      .e_output_id_o(hint_encode_o.output_id),.e_done_valid_o(hint_encode_o.done_valid),
      .e_done_ready_i(hint_encode_i.done_ready),.e_done_code_o(hint_encode_o.done_code),
      .d_command_valid_i(hint_decode_i.valid),.d_command_ready_o(hint_decode_o.ready),
      .d_command_param_i(hint_decode_i.param),.d_command_id_i(hint_decode_i.id),
      .d_input_valid_i(hint_decode_i.input_valid),.d_input_ready_o(hint_decode_o.input_ready),
      .d_input_data_i(hint_decode_i.input_data),.d_input_index_i(hint_decode_i.input_index),
      .d_input_bytes_i(hint_decode_i.input_bytes),.d_input_last_i(hint_decode_i.input_last),
      .d_output_valid_o(hint_decode_o.output_valid),.d_output_ready_i(hint_decode_i.output_ready),
      .d_output_hints_o(hint_decode_o.output_hints),.d_output_row_o(hint_decode_o.output_row),
      .d_output_word_o(hint_decode_o.output_word),.d_output_last_o(hint_decode_o.output_last),
      .d_output_id_o(hint_decode_o.output_id),.d_done_valid_o(hint_decode_o.done_valid),
      .d_done_ready_i(hint_decode_i.done_ready),.d_done_code_o(hint_decode_o.done_code),.d_done_id_o(hint_decode_o.done_id));
    assign hint_encode_o.input_ready=codec_hint_ready;
  end else begin:legacy_hint_callback
    assign hint_encode_o='0;assign hint_decode_o='0;
    assign codec_hint_ready=0;assign hint_idle_o=1;
  end endgenerate
  function automatic logic [22:0] compact_coefficient(input logic [3:0] value);
    // Exact signed-nibble -> canonical mapping,including -8 and -1.
    // Avoid propagating a four-bit carry through a full23-bit constant sum.
    if(!value[3])return {19'd0,value};
    if(value==15)return 23'd8380416;
    return {19'h7fdff,4'(value+4'd1)};
  endfunction
  assign command_ready_o=!rst && state==IDLE;
  assign done_valid_o=!rst && state==REPORT;
  always_comb begin
    selected_bank[0]=command_a_bank_i;selected_bank[1]=command_b_bank_i;
    selected_bank[2]=command_d_bank_i;selected_bank[3]=command_h_bank_i;
    selected_base[0]=command_a_base_i;selected_base[1]=command_b_base_i;
    selected_base[2]=command_d_base_i;selected_base[3]=command_h_base_i;
    enabled={command_pack_high_i && command_pack_store_i,command_low_enable_i,command_b_enable_i,1'b1};
    mask_next=0;write_next=0;port_next=0;
    bad_command=command_param_i==3 ||
      (command_b_compact_i && !command_b_enable_i) ||
      (command_pack_high_i && command_op_i!=PROC_P2R && command_op_i!=PROC_DECOMPOSE && command_op_i!=PROC_USEHINT && command_op_i!=PROC_PACK) ||
      (command_op_i==PROC_PACK && (!command_pack_high_i || command_pack_op_i>4)) ||
      (command_hint_enable_i && command_op_i!=PROC_MHINT);
    // Direct phase controls:low result ->B,packed result ->A. Each read
    // takes its bank's remaining port. No search/variable-index allocator.
    a_busy_a=enabled[3] && selected_bank[0]==selected_bank[3];
    a_busy_b=enabled[2] && selected_bank[0]==selected_bank[2];
    a_accepted=!(a_busy_a && a_busy_b);
    port_next[2]=enabled[2];
    port_next[0]=a_busy_a && !a_busy_b;
    b_busy_a=(enabled[3] && selected_bank[1]==selected_bank[3]) ||
      (a_accepted && !port_next[0] && selected_bank[1]==selected_bank[0]);
    b_busy_b=(enabled[2] && selected_bank[1]==selected_bank[2]) ||
      (a_accepted && port_next[0] && selected_bank[1]==selected_bank[0]);
    b_accepted=enabled[1] && !(b_busy_a && b_busy_b);
    port_next[1]=enabled[1] && b_busy_a && !b_busy_b;
    bad_command|=!a_accepted || (enabled[1] && b_busy_a && b_busy_b);
    for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
      write_next[p][b]=(p==1 && enabled[2] && selected_bank[2]==b) ||
                       (p==0 && enabled[3] && selected_bank[3]==b);
      mask_next[p][b]=write_next[p][b] ||
        (a_accepted && port_next[0]==p && selected_bank[0]==b) ||
        (b_accepted && port_next[1]==p && selected_bank[1]==b);
    end
    // Keep all descriptor bounds/format checks;only allocation is replaced.
    for(int s=0;s<4;s++)begin
      if(enabled[s])begin
        bad_command|=s==3?packed_base_bad:selected_base[s][5:0]!=0;
      end
    end
  end
  assign pack_command=state==RESERVE && pack_r && !pack_sent_r;
  always_comb begin
    memory_command_valid_o=0;memory_command_mask_o=mask_r;memory_command_write_o=write_r;
    memory_command_base_o=0;memory_command_words_o=0;memory_command_mode_o=0;
    for(int s=0;s<4;s++)if(s==0 || (s==1 && b_enable_r) || (s==2 && low_enable_r) || (s==3 && pack_r && pack_store_r))begin
      memory_command_base_o[port_r[s]][bank_r[s]]=base_r[s];
      memory_command_words_o[port_r[s]][bank_r[s]]=s==3?packed_words_r:64;
      if((s==0 && a_compact_r) || (s==1 && b_compact_r))memory_command_mode_o[port_r[s]][bank_r[s]]=3;
    end
    all_commands=!pack_r || pack_sent_r || (pack_command && pack_command_ready);
    for(int p=0;p<2;p++)begin
      memory_command_valid_o[p]=!rst && state==RESERVE && mask_r[p]!=0 && !sent_r[p];
      all_commands&=mask_r[p]==0 || sent_r[p] || (memory_command_valid_o[p] && memory_command_ready_i[p]);
    end
    // RAM selection ends at the operand registers. Compact-secret expansion
    // and Process arithmetic start from those registers in the next cycle.
    process_a=operand_a_r;
    process_b=b_enable_r?operand_b_r:92'd0;
    if(b_compact_r)for(int lane=0;lane<4;lane++)begin
      logic [3:0] value;
      value=operand_b_r[4*int'({operand_tag_r[4],operand_tag_r[0],2'(lane)})+:4];
      process_b[lane]=compact_coefficient(value);
    end
    if(a_compact_r)for(int lane=0;lane<4;lane++)begin
      logic [3:0] value;
      value=operand_a_r[4*int'({operand_tag_r[4],operand_tag_r[0],2'(lane)})+:4];
      process_a[lane]=compact_coefficient(value);
    end
    available=memory_read_valid_i[port_r[0]][bank_r[0]] &&
      (!b_enable_r || memory_read_valid_i[port_r[1]][bank_r[1]]);
    operand_ready=operand_count_r<2;
    operand_take=!rst && state==STREAM && consumed_r<64 && available && operand_ready;
    memory_read_ready_o=0;
    if(operand_take)begin
      memory_read_ready_o[port_r[0]][bank_r[0]]=1;
      if(b_enable_r)memory_read_ready_o[port_r[1]][bank_r[1]]=1;
    end
    pack_input_valid=result_valid && pack_r && !high_sent_r;
    memory_write_valid_o=0;memory_write_data_o=0;
    if(low_enable_r)begin
      memory_write_valid_o[port_r[2]][bank_r[2]]=result_valid && !low_sent_r;
      memory_write_data_o[port_r[2]][bank_r[2]]=result_data;
    end
    if(pack_r && pack_store_r)begin
      memory_write_valid_o[port_r[3]][bank_r[3]]=pack_output_valid;
      memory_write_data_o[port_r[3]][bank_r[3]]={28'd0,packed_data};
    end
    pack_output_ready=pack_r && (pack_store_r?memory_write_ready_i[port_r[3]][bank_r[3]]:packed_ready_i);
    low_fire=low_enable_r && result_valid && !low_sent_r && memory_write_ready_i[port_r[2]][bank_r[2]];
    high_fire=pack_input_valid && pack_input_ready;
    low_blocked=low_enable_r && !low_sent_r && !memory_write_ready_i[port_r[2]][bank_r[2]];
    pack_blocked=pack_r && !high_sent_r && !pack_input_ready;
    hint_blocked=hint_enable_r && !hint_sent_r && !hint_consumer_ready;
    result_ready=!(low_blocked || pack_blocked || hint_blocked);
    result_fire=result_valid && result_ready;
    memory_done_ready_o=state==STREAM?memory_done_valid_i & mask_r:8'd0;
    all_done=1;
    for(int p=0;p<2;p++)all_done&=((completed_r[p]|memory_done_valid_i[p])&mask_r[p])==mask_r[p];
  end
  assign packed_valid_o=pack_r && !pack_store_r && pack_output_valid;
  assign packed_data_o=packed_data;assign packed_index_o=packed_index;assign packed_last_o=packed_last;
  assign hint_valid_o=result_valid && hint_enable_r && !hint_sent_r;
  assign hint_mask_o=result_hint;assign hint_word_o=result_tag[5:0];assign hint_last_o=result_tag==63;
  assign {result_data,result_reject,result_hint,result_weight,result_tag,result_error}=result_head;
  genvar pack_lane;
  generate for(pack_lane=0;pack_lane<4;pack_lane=pack_lane+1)begin:select_pack_field
    assign selected_pack_fields[pack_lane]=pack_raw_r?
      arithmetic_result.data[pack_lane]:23'(arithmetic_high[pack_lane]);
  end endgenerate

  generate if(PIPELINE_RESULTS)begin:g_result_queue
    queued_result_t offered,head_r,tail_r;
    logic [1:0] count_r;
    logic push_result;
    // The arithmetic pipeline sees only registered occupancy. The external
    // sinks may accept their portions independently from the fixed head.
    assign arithmetic_ready=!rst && count_r<2;
    assign push_result=arithmetic_valid && arithmetic_ready;
    assign result_valid=!rst && count_r!=0;
    assign offered={arithmetic_result,selected_pack_fields};
    assign result_head=head_r.result;
    assign pack_data=head_r.pack_fields;
    always_ff @(posedge clk)begin
      if(result_fire && count_r==2)head_r<=tail_r;
      else if(push_result && (count_r==0 || result_fire))head_r<=offered;
      if(push_result && count_r==1 && !result_fire)tail_r<=offered;
    end
    always_ff @(posedge clk or posedge rst)begin
      if(rst)count_r<=0;
      else case({push_result,result_fire})
        2'b10:count_r<=count_r+1'b1;
        2'b01:count_r<=count_r-1'b1;
        default:begin end
      endcase
    end
    // synthesis translate_off
    always @(posedge clk)if(!rst && ((count_r!=0 && state!=STREAM) || count_r>2))
      $fatal(1,"Process result queue left its active command");
    // synthesis translate_on
  end else begin:g_direct_result
    assign arithmetic_ready=result_ready;
    assign result_valid=arithmetic_valid;
    assign result_head=arithmetic_result;
    assign pack_data=selected_pack_fields;
  end endgenerate

  poly_process process_unit(
    .clk(clk),.rst(rst),.input_valid_i(process_valid),.input_ready_o(process_ready),
    .input_op_i(op_r),.input_param_i(level_r),.input_kind_i(kind_r),.input_tag_i({1'b0,operand_feed_tag}),
    .input_a_i(operand_feed_a),.input_b_i(operand_feed_b),.output_valid_o(arithmetic_valid),.output_ready_i(arithmetic_ready),
    .output_op_o(),.output_tag_o(arithmetic_result.tag),.output_error_o(arithmetic_result.error),.output_data_o(arithmetic_result.data),
    .output_high_o(arithmetic_high),.output_reject_o(arithmetic_result.reject),
    .output_hint_o(arithmetic_result.hint),.output_weight_o(arithmetic_result.weight));
  bitpkg #(.PIPELINE_FORMAT(PIPELINE_PACK)) packer(
    .clk(clk),.rst(rst),.command_valid_i(pack_command),.command_ready_o(pack_command_ready),
    .command_op_i(pack_op_r),.command_param_i(level_r),.command_id_i(16'd0),
    .input_valid_i(pack_input_valid),.input_ready_o(pack_input_ready),.input_data_i(pack_data),
    .input_index_i(result_tag[5:0]),.input_last_i(result_tag==63),
    .output_valid_o(pack_output_valid),.output_ready_i(pack_output_ready),.output_data_o(packed_data),
    .output_bytes_o(packed_bytes),.output_index_o(packed_index),.output_last_o(packed_last),.output_id_o(),
    .done_valid_o(pack_done),.done_ready_i(state==STREAM),.done_code_o(packed_code),.done_id_o());
  // Two registered raw-word entries break output-ready -> RAM-read-ready
  // feedback. Admission depends only on registered occupancy. The head is
  // stable under stalls;simultaneous pop/push retains one word per clock.
  assign operand_valid_r=operand_count_r!=0;
  assign operand_a_r=operand_a_store_r[operand_read_r];
  assign operand_b_r=operand_b_store_r[operand_read_r];
  assign operand_tag_r={1'b0,operand_tag_store_r[operand_read_r]};
  assign operand_feed_valid=!rst && state==STREAM && operand_valid_r;
  generate if(PIPELINE_OPERANDS)begin:g_operand_stage
    logic valid_r,room;
    logic [3:0][22:0] a_r,b_r;
    logic [6:0] tag_r;
    assign room=!valid_r || process_ready;
    assign operand_pop=operand_feed_valid && room;
    assign process_valid=!rst && state==STREAM && valid_r;
    assign operand_feed_a=a_r;
    assign operand_feed_b=b_r;
    assign operand_feed_tag=tag_r;
    // Keep selection/compact expansion separate from Process arithmetic.
    // Refill on the same edge as consumption to sustain one group per clock.
    always_ff @(posedge clk or posedge rst)begin
      if(rst)valid_r<=0;
      else if(state!=STREAM)valid_r<=0;
      else if(room)valid_r<=operand_feed_valid;
    end
    always_ff @(posedge clk)if(operand_pop)begin
      a_r<=process_a;
      b_r<=process_b;
      tag_r<=operand_tag_r;
    end
  end else begin:g_direct_operands
    assign process_valid=operand_feed_valid;
    assign operand_pop=operand_feed_valid && process_ready;
    assign operand_feed_a=process_a;
    assign operand_feed_b=process_b;
    assign operand_feed_tag=operand_tag_r;
  end endgenerate
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin operand_count_r<=0;operand_read_r<=0;operand_write_r<=0;end
    else if(state!=STREAM)begin operand_count_r<=0;operand_read_r<=0;operand_write_r<=0;end
    else begin
      case({operand_take,operand_pop})
        2'b10:operand_count_r<=operand_count_r+1'b1;
        2'b01:operand_count_r<=operand_count_r-1'b1;
        default:begin end
      endcase
      if(operand_take)operand_write_r<=!operand_write_r;
      if(operand_pop)operand_read_r<=!operand_read_r;
    end
  end
  always_ff @(posedge clk)if(operand_take)begin
    operand_a_store_r[operand_write_r]<=memory_read_data_i[port_r[0]][bank_r[0]];
    operand_b_store_r[operand_write_r]<=memory_read_data_i[port_r[1]][bank_r[1]];
    operand_tag_store_r[operand_write_r]<=consumed_r[5:0];
  end
  // synthesis translate_off
  always @(posedge clk)if(!rst && state==STREAM)begin
    if(operand_count_r>2 || (operand_pop && operand_count_r==0) ||
      (operand_take && operand_count_r==2))$fatal(1,"Process operand queue occupancy");
    if(operand_take && operand_count_r!=0 && operand_write_r==operand_read_r)
      $fatal(1,"Process operand queue overwrites a live head");
  end
  // synthesis translate_on
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=PROC_ADD;level_r<=0;kind_r<=0;a_compact_r<=0;b_enable_r<=0;b_compact_r<=0;low_enable_r<=0;pack_r<=0;pack_store_r<=0;pack_op_r<=0;pack_raw_r<=0;hint_enable_r<=0;hint_sent_r<=0;
      port_r<=0;mask_r<=0;write_r<=0;completed_r<=0;sent_r<=0;pack_sent_r<=0;pack_finished_r<=0;
      low_sent_r<=0;high_sent_r<=0;consumed_r<=0;produced_r<=0;packed_words_r<=0;
      done_code_o<=0;done_reject_o<=0;done_hint_weight_o<=0;
      for(int s=0;s<4;s++)begin bank_r[s]<=0;base_r[s]<=0;end
    end else begin
      for(int p=0;p<2;p++)begin
        if(memory_command_valid_o[p] && memory_command_ready_i[p])sent_r[p]<=1;
        completed_r[p]<=completed_r[p] | (memory_done_valid_i[p] & memory_done_ready_o[p]);
      end
      if(pack_command && pack_command_ready)pack_sent_r<=1;
      if(pack_done && state==STREAM)begin pack_finished_r<=1;if(packed_code!=0)done_code_o<=2;end
      if(operand_take)consumed_r<=consumed_r+1'b1;
      if(result_fire)begin
        produced_r<=produced_r+1'b1;
        done_reject_o<=done_reject_o | (|result_reject);
        done_hint_weight_o<=done_hint_weight_o+9'(result_weight);
        if(result_error || result_tag!={1'b0,produced_r})done_code_o<=2;
      end
      // A sink's credit clears once every OTHER sink is ready. If this sink
      // has not accepted the word,its credit was already zero. This removes
      // the shared result_fire net from the three credit-register inputs.
      if(result_valid)begin
        if(!pack_blocked && !hint_blocked)low_sent_r<=0;
        else if(low_fire)low_sent_r<=1;
        if(!low_blocked && !hint_blocked)high_sent_r<=0;
        else if(high_fire)high_sent_r<=1;
        if(!low_blocked && !pack_blocked)hint_sent_r<=0;
        else if(hint_valid_o && hint_consumer_ready)hint_sent_r<=1;
      end
      if(|(memory_done_valid_i & memory_done_error_i & mask_r) && state==STREAM)done_code_o<=2;
      case(state)
        IDLE:if(command_valid_i)begin
          pack_raw_r<=command_op_i==PROC_PACK;
          op_r<=command_op_i;level_r<=command_param_i;kind_r<=command_kind_i;
          b_enable_r<=command_b_enable_i;b_compact_r<=command_b_compact_i;
          a_compact_r<=command_a_compact_i;pack_store_r<=command_pack_store_i;
          hint_enable_r<=command_hint_enable_i;hint_sent_r<=0;
          pack_op_r<=command_op_i==PROC_PACK?command_pack_op_i:command_op_i==PROC_P2R?3'd0:3'd3;
          low_enable_r<=command_low_enable_i;pack_r<=command_pack_high_i;
          port_r<=port_next;mask_r<=mask_next;write_r<=write_next;
          for(int s=0;s<4;s++)begin bank_r[s]<=selected_bank[s];base_r[s]<=selected_base[s];end
          packed_words_r<=command_op_i==PROC_P2R?40:command_op_i==PROC_PACK?
            command_pack_op_i==0?40:command_pack_op_i==1?52:command_pack_op_i==2?(command_param_i==1?16:12):
            command_pack_op_i==3?(command_param_i==0?24:16):(command_param_i==0?72:80):command_param_i==0?24:16;
          completed_r<=0;sent_r<=0;pack_sent_r<=0;pack_finished_r<=0;low_sent_r<=0;high_sent_r<=0;
          consumed_r<=0;produced_r<=0;done_code_o<=bad_command?1:0;done_reject_o<=0;done_hint_weight_o<=0;
          state<=bad_command?REPORT:RESERVE;
        end
        RESERVE:if(all_commands)state<=STREAM;
        STREAM:if(all_done && consumed_r==64 && produced_r==64 && (!pack_r || pack_finished_r))state<=REPORT;
        REPORT:if(done_ready_i)state<=IDLE;
        default:state<=IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
