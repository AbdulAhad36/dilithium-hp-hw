// Shared bank-word Process path:ADD/SUB/P2R/Decompose/CNB/MHint/UseHint.
// One arithmetic pipeline and one BitPkg. Each command retains only scalar
// addresses/counters. Low writes and packed-high consumption have independent
// credits,so backpressure never duplicates a word or couples bank ownership.
`default_nettype none
module process_dma_c12_reference (
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
  logic [1:0] bank_r[4];logic [9:0] base_r[4];
  logic [3:0] port_r,port_next,enabled;
  logic [1:0][3:0] mask_r,write_r,mask_next,write_next,completed_r;
  logic [1:0] sent_r;
  logic pack_sent_r,pack_finished_r,low_sent_r,high_sent_r,hint_sent_r;
  logic bad_command,available,all_commands,all_done;
  logic [1:0] selected_bank[4];logic [9:0] selected_base[4];
  logic [6:0] consumed_r,produced_r;
  logic [10:0] packed_words_r;
  logic process_valid,process_ready,result_valid,result_ready,result_error;
  logic [3:0][22:0] process_a,process_b,result_data,pack_data;
  logic [3:0][9:0] result_high;
  logic [3:0] result_reject,result_hint;
  logic [2:0] result_weight;
  logic [7:0] result_tag;
  logic pack_command,pack_command_ready,pack_input_valid,pack_input_ready,pack_output_valid,pack_output_ready,pack_done;
  logic [63:0] packed_data;logic [3:0] packed_bytes;
  logic [6:0] packed_index;logic packed_last;logic [2:0] packed_code;
  logic low_fire,high_fire,result_fire;
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
    // Writes first:low prefers B,packed high prefers A. Reads use the other
    // lanes. Fixed-role controllers never require three accesses to one bank.
    for(int step=0;step<4;step++)begin
      int s,preferred;s=step==0?2:step==1?3:step-2;preferred=s==2?1:0;
      if(enabled[s])begin
        bad_command|=s==3?({1'b0,selected_base[s]}+(command_op_i==PROC_P2R?11'd40:command_op_i==PROC_PACK?
          command_pack_op_i==0?11'd40:command_pack_op_i==1?11'd52:command_pack_op_i==2?(command_param_i==1?11'd16:11'd12):
          command_pack_op_i==3?(command_param_i==0?11'd24:11'd16):(command_param_i==0?11'd72:11'd80):
          command_param_i==0?11'd24:11'd16)>1024):selected_base[s][5:0]!=0;
        if(!mask_next[preferred][selected_bank[s]])begin
          mask_next[preferred][selected_bank[s]]=1;port_next[s]=1'(preferred);
          if(s>=2)write_next[preferred][selected_bank[s]]=1;
        end else if(!mask_next[1-preferred][selected_bank[s]])begin
          mask_next[1-preferred][selected_bank[s]]=1;port_next[s]=1'(1-preferred);
          if(s>=2)write_next[1-preferred][selected_bank[s]]=1;
        end else bad_command=1;
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
    process_a=memory_read_data_i[port_r[0]][bank_r[0]];
    process_b=b_enable_r?memory_read_data_i[port_r[1]][bank_r[1]]:92'd0;
    if(b_compact_r)for(int lane=0;lane<4;lane++)begin
      logic [3:0] value;
      value=memory_read_data_i[port_r[1]][bank_r[1]][4*int'({consumed_r[4],consumed_r[0],2'(lane)})+:4];
      process_b[lane]=compact_coefficient(value);
    end
    if(a_compact_r)for(int lane=0;lane<4;lane++)begin
      logic [3:0] value;
      value=memory_read_data_i[port_r[0]][bank_r[0]][4*int'({consumed_r[4],consumed_r[0],2'(lane)})+:4];
      process_a[lane]=compact_coefficient(value);
    end
    available=memory_read_valid_i[port_r[0]][bank_r[0]] &&
      (!b_enable_r || memory_read_valid_i[port_r[1]][bank_r[1]]);
    process_valid=!rst && state==STREAM && consumed_r<64 && available;
    memory_read_ready_o=0;
    if(process_valid && process_ready)begin
      memory_read_ready_o[port_r[0]][bank_r[0]]=1;
      if(b_enable_r)memory_read_ready_o[port_r[1]][bank_r[1]]=1;
    end
    for(int lane=0;lane<4;lane++)pack_data[lane]=op_r==PROC_PACK?result_data[lane]:23'(result_high[lane]);
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
    result_ready=(!low_enable_r || low_sent_r || memory_write_ready_i[port_r[2]][bank_r[2]]) &&
      (!pack_r || high_sent_r || pack_input_ready) && (!hint_enable_r || hint_sent_r || hint_ready_i);
    result_fire=result_valid && result_ready;
    memory_done_ready_o=state==STREAM?memory_done_valid_i & mask_r:8'd0;
    all_done=1;
    for(int p=0;p<2;p++)all_done&=((completed_r[p]|memory_done_valid_i[p])&mask_r[p])==mask_r[p];
  end
  assign packed_valid_o=pack_r && !pack_store_r && pack_output_valid;
  assign packed_data_o=packed_data;assign packed_index_o=packed_index;assign packed_last_o=packed_last;
  assign hint_valid_o=result_valid && hint_enable_r && !hint_sent_r;
  assign hint_mask_o=result_hint;assign hint_word_o=result_tag[5:0];assign hint_last_o=result_tag==63;
  poly_process process_unit(
    .clk(clk),.rst(rst),.input_valid_i(process_valid),.input_ready_o(process_ready),
    .input_op_i(op_r),.input_param_i(level_r),.input_kind_i(kind_r),.input_tag_i({1'b0,consumed_r}),
    .input_a_i(process_a),.input_b_i(process_b),.output_valid_o(result_valid),.output_ready_i(result_ready),
    .output_op_o(),.output_tag_o(result_tag),.output_error_o(result_error),.output_data_o(result_data),
    .output_high_o(result_high),.output_reject_o(result_reject),.output_hint_o(result_hint),.output_weight_o(result_weight));
  bitpkg packer(
    .clk(clk),.rst(rst),.command_valid_i(pack_command),.command_ready_o(pack_command_ready),
    .command_op_i(pack_op_r),.command_param_i(level_r),.command_id_i(16'd0),
    .input_valid_i(pack_input_valid),.input_ready_o(pack_input_ready),.input_data_i(pack_data),
    .input_index_i(result_tag[5:0]),.input_last_i(result_tag==63),
    .output_valid_o(pack_output_valid),.output_ready_i(pack_output_ready),.output_data_o(packed_data),
    .output_bytes_o(packed_bytes),.output_index_o(packed_index),.output_last_o(packed_last),.output_id_o(),
    .done_valid_o(pack_done),.done_ready_i(state==STREAM),.done_code_o(packed_code),.done_id_o());
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=PROC_ADD;level_r<=0;kind_r<=0;a_compact_r<=0;b_enable_r<=0;b_compact_r<=0;low_enable_r<=0;pack_r<=0;pack_store_r<=0;pack_op_r<=0;hint_enable_r<=0;hint_sent_r<=0;
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
      if(process_valid && process_ready)consumed_r<=consumed_r+1'b1;
      if(result_fire)begin
        produced_r<=produced_r+1'b1;low_sent_r<=0;high_sent_r<=0;hint_sent_r<=0;
        done_reject_o<=done_reject_o | (|result_reject);
        done_hint_weight_o<=done_hint_weight_o+9'(result_weight);
        if(result_error || result_tag!={1'b0,produced_r})done_code_o<=2;
      end else begin
        if(low_fire)low_sent_r<=1;
        if(high_fire)high_sent_r<=1;
        if(hint_valid_o && hint_ready_i)hint_sent_r<=1;
      end
      if(|(memory_done_valid_i & memory_done_error_i & mask_r) && state==STREAM)done_code_o<=2;
      case(state)
        IDLE:if(command_valid_i)begin
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
