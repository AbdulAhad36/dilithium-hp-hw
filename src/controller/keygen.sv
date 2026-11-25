// Compact full FIPS204 KeyGen using LightHD fixed roles and bounded queues.
// No64-region allocator,leases or per-helper copied contexts. One A ring,
// one row accumulator,and early secret Pre-NTT overlap with the sampler.
`default_nettype none
module keygen #(parameter bit PIPELINE_INPUT=0,parameter bit LOCAL_CONTROL=0) (
  input wire logic clk,rst,start_valid_i,output logic start_ready_o,
  input wire logic [1:0] start_param_i,input wire logic [15:0] start_id_i,
  input wire logic [255:0] start_seed_i,
  output dilithium_pkg::request_t service_o,input var dilithium_pkg::response_t service_i,
  output logic key_valid_o,input wire logic key_ready_i,output logic [63:0] key_data_o,
  output logic [3:0] key_bytes_o,output logic key_type_o,key_last_o,
  output logic [9:0] key_index_o,output logic [15:0] key_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,output logic fault_o
);
  import dilithium_pkg::*;
  typedef enum logic  [5:0] {IDLE,SEED_CMD,SEED_FEED,SEED_WAIT,S1_READY,S1_CMD,S1_RUN,
    TERM_READY,TERM_CMD,TERM_RUN,INV_CMD,INV_RUN,ADD_READY,ADD_CMD,ADD_RUN,ROUND_CMD,ROUND_RUN,
    PK_MEM_CMD,PK_HASH_CMD,PK_HEADER,PK_BODY,PK_DRAIN,SK_HEADER,SK_FIELD_CMD,SK_FIELD_STREAM,REPORT,HALT} state_e;
  typedef enum logic [1:0] {P_IDLE,P_CMD,P_FEED,P_WAIT} producer_e;
  typedef struct packed {logic [1:0] kind;logic [3:0] index,row,column,slot;} descriptor_t;
  state_e state;producer_e producer;
  descriptor_t descriptor_r[2],current;
  logic [1:0] level_r,batch_size_r,batch_done_r;
  logic [3:0] k_r,l_r,s1_next_r,s2_next_r,a_row_r,a_column_r,a_write_r,a_read_r,transform_r,row_r,column_r;
  logic [3:0] sample_word_r,seed_word_r,header_r,poly_r;
  logic selected_r,secret_phase_r,s1_credit_r,released_prev_r;
  logic [6:0] s1_ready_r;logic [7:0] s2_ready_r;logic [8:0] a_reserved_r,a_ready_r;
  logic [15:0] id_r;
  // One workspace:words0..3 hold xi before hashing,then rho;words4..11
  // hold rho-prime during sampling,then tr after sampling is finished.
  // Words12..15 retain key. The live phases need only one64-bit read port.
  logic [1023:0] material_r;
  logic [3:0] material_read_word;
  logic [2:0] material_write_word;
  logic [63:0] material_word;
  logic [3:0] raw_count_r;logic [2:0] tr_count_r;
  logic hash_retired_r,bank_retired_r,host_sent_r,hash_sent_r;
  logic [1:0] section_r;
  logic source_valid,source_ready,source_fire;
  logic [63:0] source_data;
  logic [9:0] pk_words,sk_words;
  logic producer_enabled;
  logic [15:0] sample_id;
  logic [15:0] sample_nonce;
  logic [1:0] sample_bank;
  logic [9:0] sample_base;
  logic raw_source_valid,raw_source_ready,sample_source_valid,sample_source_ready;
  logic [63:0] raw_source_data,sample_source_data;
  logic [63:0] input_stage_data_r;
  logic input_stage_raw_r,input_stage_valid_r,input_stage_room,input_stage_push,input_stage_pop;
  // One shared66-bit input boundary for the two mutually framed hash sources.
  // The engine retains message/core ownership from command acceptance until
  // its actual final input beat,so a buffered tail cannot enter the next job.
  generate if(PIPELINE_INPUT)begin:g_message_stage
    assign input_stage_pop=input_stage_valid_r &&
      (input_stage_raw_r?service_i.raw.input_ready:service_i.sample.input_ready);
    assign input_stage_room=!rst && state!=IDLE && state!=REPORT && state!=HALT &&
      (!input_stage_valid_r || input_stage_pop);
    assign raw_source_ready=input_stage_room;
    assign sample_source_ready=input_stage_room && !raw_source_valid;
    assign input_stage_push=input_stage_room && (raw_source_valid || sample_source_valid);
    always_ff @(posedge clk or posedge rst)begin
      if(rst)input_stage_valid_r<=0;
      else if(state==IDLE || state==REPORT || state==HALT)input_stage_valid_r<=0;
      else case({input_stage_push,input_stage_pop})
        2'b10:input_stage_valid_r<=1;
        2'b01:input_stage_valid_r<=0;
        default:begin end
      endcase
    end
    always_ff @(posedge clk)if(input_stage_push)begin
      input_stage_data_r<=raw_source_valid?raw_source_data:sample_source_data;
      input_stage_raw_r<=raw_source_valid;
    end
    // synthesis translate_off
    logic held;logic [64:0] held_word;
    always @(posedge clk)begin
      if(rst || state==IDLE || state==REPORT || state==HALT)held<=0;
      else begin
        if(held && (!input_stage_valid_r || {input_stage_raw_r,input_stage_data_r}!==held_word))
          $fatal(1,"KeyGen staged message changed while stalled");
        held<=input_stage_valid_r && !input_stage_pop;
        held_word<={input_stage_raw_r,input_stage_data_r};
      end
    end
    // synthesis translate_on
  end else begin:g_direct_input
    assign raw_source_ready=service_i.raw.input_ready;
    assign sample_source_ready=service_i.sample.input_ready;
    assign input_stage_data_r=0;assign input_stage_valid_r=0;assign input_stage_raw_r=0;
  end endgenerate

  function automatic logic [9:0] public_words(input logic [3:0] k);
    return 10'd4+{1'b0,k,5'b0}+{3'b0,k,3'b0};
  endfunction
  function automatic logic [9:0] secret_words(input logic [1:0] level,input logic [3:0] k,l);
    logic [4:0] n;
    n={1'b0,k}+{1'b0,l};
    return 10'd16+(level==1?{1'b0,n,4'b0}:
      {2'b0,n,3'b0}+{3'b0,n,2'b0})+
      {1'b0,k,5'b0}+{2'b0,k,4'b0}+{4'b0,k,2'b0};
  endfunction
  function automatic logic [15:0] descriptor_id(input descriptor_t d,input logic [15:0] id,input logic [3:0] columns);
    return id+descriptor_offset(d,columns);
  endfunction
  function automatic logic [15:0] descriptor_offset(input descriptor_t d,input logic [3:0] columns);
    logic [5:0] secret_offset;
    // The secret suffix is at most46,including all four-bit input values.
    // Finish this short sum before the single addition to the command ID.
    secret_offset=6'd16+{2'b0,d.index}+(d.kind==2?{2'b0,columns}:6'd0);
    return d.kind==1?{8'd1,d.row,d.column}:{10'd0,secret_offset};
  endfunction
  function automatic logic descriptor_matches(input descriptor_t d,
    input logic [15:0] id,response_id,input logic [3:0] columns);
    logic [15:0] offset,carry_in,carry_out;
    // Equality to a modular sum does not require computing that sum: the
    // proposed result determines carries locally,then adjacent carries agree.
    offset=descriptor_offset(d,columns);
    carry_in=id^offset^response_id;
    carry_out=(id&offset)|((id|offset)&~response_id);
    return !carry_in[0] && carry_in[15:1]==carry_out[14:0];
  endfunction
  function automatic descriptor_t secret_descriptor(input int index,input bit second);
    descriptor_t d;d='0;d.kind=second?2:0;d.index=4'(index);return d;
  endfunction
  function automatic descriptor_t matrix_descriptor(input int row,column,slot);
    descriptor_t d;d='0;d.kind=1;d.row=4'(row);d.column=4'(column);d.slot=4'(slot);return d;
  endfunction
  logic [1:0][15:0] expected_sample_id_r;
  logic [1:0] expected_sample_valid_r,sample_match,sample_event_mask_r;
  logic sample_take,sample_event_r,sample_bad;
  assign sample_take=service_i.sample.done_valid && service_o.sample.done_ready;
  assign sample_bad=service_i.sample.done_code!=0 || sample_match==0 || sample_match==3 ||
    |(sample_match & batch_done_r) || (sample_event_r && |(sample_match & sample_event_mask_r));
  genvar completion_slot;
  generate for(completion_slot=0;completion_slot<2;completion_slot=completion_slot+1)begin:g_completion_match
    assign sample_match[completion_slot]=expected_sample_valid_r[completion_slot] &&
      completion_slot<int'(batch_size_r) && service_i.sample.done_id==expected_sample_id_r[completion_slot];
  end endgenerate
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin expected_sample_id_r<=0;expected_sample_valid_r<=0;sample_event_r<=0;sample_event_mask_r<=0;end
    else begin
      sample_event_r<=LOCAL_CONTROL && sample_take && !sample_bad;
      if(sample_take)sample_event_mask_r<=sample_match;
      if(producer==P_IDLE)expected_sample_valid_r<=0;
      if(producer==P_CMD && service_i.sample.ready)begin
        expected_sample_id_r[selected_r]<=service_o.sample.id;expected_sample_valid_r[selected_r]<=1;
      end
    end
  end
  assign current=descriptor_r[selected_r];
  assign sample_id=descriptor_id(current,id_r,l_r);
  assign sample_nonce=current.kind==2?16'(l_r)+16'(current.index):16'(current.index);
  assign sample_bank=current.kind==1?3:0;
  assign sample_base=current.kind==1?{current.slot,6'd0}:
    current.kind==2?10'd448+{current.index,6'd0}:{current.index,6'd0};
  assign producer_enabled=state>=S1_READY && state<=ROUND_RUN;
  assign start_ready_o=!rst && state==IDLE && !fault_o;
  assign done_valid_o=!rst && (state==REPORT || state==HALT);
  assign done_id_o=id_r;assign key_id_o=id_r;assign key_bytes_o=8;
  // Lengths are fixed for the entire command. Capture them with k/l so the
  // key-stream terminal decision does not traverse secret-length arithmetic.
  // Preserve the reset/invalid-level lengths as well as the three valid ones.
  assign key_type_o=state==SK_HEADER || state==SK_FIELD_CMD || state==SK_FIELD_STREAM;
  assign key_last_o=key_index_o+10'd1==(key_type_o?sk_words:pk_words);
  assign source_valid=state==PK_HEADER || (state==PK_BODY && service_i.bank.read_valid[0][3]);
  always_comb begin
    material_read_word=current.kind==1?sample_word_r:sample_word_r+4'd4;
    if(state==SEED_FEED)material_read_word=seed_word_r;
    else if(state==PK_HEADER)material_read_word=header_r;
    else if(state==SK_HEADER)material_read_word=header_r<4?header_r:
      header_r<8?header_r+4'd8:header_r-4'd4;
  end
  assign material_word=material_r[64*material_read_word+:64];
  assign material_write_word=state<=SEED_WAIT?raw_count_r[2:0]:3'd2+{1'b0,tr_count_r[1:0]};
  assign source_data=state==PK_HEADER?material_word:service_i.bank.read_data[0][3][63:0];
  assign source_ready=(host_sent_r || key_ready_i) && (hash_sent_r || raw_source_ready);
  assign source_fire=source_valid && source_ready;
  assign raw_source_valid=state==SEED_FEED || (source_valid && !hash_sent_r);
  assign sample_source_valid=producer==P_FEED;
  assign raw_source_data=state==SEED_FEED?
    (seed_word_r==4?{48'd0,4'd0,l_r,4'd0,k_r}:material_word):source_data;
  assign sample_source_data=current.kind==1?
    (sample_word_r==4?{48'd0,4'd0,current.row,4'd0,current.column}:material_word):
    (sample_word_r==8?{48'd0,sample_nonce}:material_word);
  always_comb begin
    service_o='0;key_valid_o=0;key_data_o=0;
    service_o.sample.valid=producer==P_CMD;
    service_o.sample.batch_last=selected_r+2'd1==batch_size_r;
    service_o.sample.mode=current.kind==1?0:1;service_o.sample.param=level_r;
    service_o.sample.bank=sample_bank;service_o.sample.base=sample_base;service_o.sample.id=sample_id;
    service_o.sample.message_len=current.kind==1?34:66;
    service_o.sample.input_valid=PIPELINE_INPUT?(input_stage_valid_r && !input_stage_raw_r):sample_source_valid;
    service_o.sample.input_data=PIPELINE_INPUT?input_stage_data_r:sample_source_data;
    service_o.sample.done_ready=producer!=P_IDLE;
    service_o.raw.mode=1;service_o.raw.id=state<=SEED_WAIT?id_r:id_r+16'd1024;
    service_o.raw.message_len=state<=SEED_WAIT?34:16'(pk_words)*16'd8;
    service_o.raw.output_len=state<=SEED_WAIT?128:64;
    service_o.raw.valid=state==SEED_CMD || state==PK_HASH_CMD;
    service_o.raw.input_valid=PIPELINE_INPUT?(input_stage_valid_r && input_stage_raw_r):raw_source_valid;
    service_o.raw.input_data=PIPELINE_INPUT?input_stage_data_r:raw_source_data;
    // IDLE is not a raw-hash owner. Other operations share this response bus.
    service_o.raw.output_ready=state>=SEED_CMD && state<=SEED_WAIT?raw_count_r<8:state>=PK_HASH_CMD && state<=PK_DRAIN && tr_count_r<4;
    service_o.raw.done_ready=state==SEED_WAIT?raw_count_r==8:
      state>=PK_HEADER && state<=PK_DRAIN && tr_count_r==4 && !hash_retired_r;
    service_o.ntt.valid=state==S1_CMD || state==TERM_CMD || state==INV_CMD;
    service_o.ntt.op=state==S1_CMD?3:state==INV_CMD?1:2;
    service_o.ntt.accumulate=state==TERM_CMD && column_r!=0;
    service_o.ntt.a_bank=state==S1_CMD?0:state==INV_CMD?1:3;
    service_o.ntt.a_base=state==S1_CMD?{transform_r,6'd0}:state==INV_CMD?10'd0:{a_read_r,6'd0};
    service_o.ntt.b_bank=2;service_o.ntt.b_base={column_r,6'd0};
    service_o.ntt.c_bank=1;service_o.ntt.c_base=0;
    service_o.ntt.d_bank=state==S1_CMD?2:state==INV_CMD?0:1;
    service_o.ntt.d_base=state==S1_CMD?{transform_r,6'd0}:state==INV_CMD?10'd960:10'd0;
    service_o.ntt.done_ready=state==S1_RUN || state==TERM_RUN || state==INV_RUN;
    service_o.poly_process.valid=state==ADD_CMD || state==ROUND_CMD || state==SK_FIELD_CMD;
    service_o.poly_process.op=state==ADD_CMD?PROC_ADD:state==ROUND_CMD?PROC_P2R:PROC_PACK;
    service_o.poly_process.param=level_r;
    service_o.poly_process.a_bank=state==ADD_CMD?0:state==ROUND_CMD?1:section_r==3?1:0;
    service_o.poly_process.a_base=state==ADD_CMD?10'd960:state==ROUND_CMD?10'd0:
      section_r==1?{poly_r,6'd0}:section_r==2?10'd448+{poly_r,6'd0}:10'd64+{poly_r,6'd0};
    service_o.poly_process.a_compact=state==SK_FIELD_CMD && section_r!=3;
    service_o.poly_process.b_enable=state==ADD_CMD;service_o.poly_process.b_compact=state==ADD_CMD;
    service_o.poly_process.b_bank=0;service_o.poly_process.b_base=10'd448+{row_r,6'd0};
    service_o.poly_process.low_enable=state==ADD_CMD || state==ROUND_CMD;
    service_o.poly_process.d_bank=1;service_o.poly_process.d_base=state==ROUND_CMD?10'd64+{row_r,6'd0}:10'd0;
    service_o.poly_process.pack_enable=state==ROUND_CMD || state==SK_FIELD_CMD;
    service_o.poly_process.pack_store=state==ROUND_CMD;
    service_o.poly_process.pack_op=section_r==3?1:2;
    service_o.poly_process.h_bank=3;service_o.poly_process.h_base=10'd576+{1'b0,row_r,5'b0}+{3'b0,row_r,3'b0};
    service_o.poly_process.done_ready=state==ADD_RUN || state==ROUND_RUN || state==SK_FIELD_STREAM;
    service_o.poly_process.packed_ready=state==SK_FIELD_STREAM && key_ready_i;
    service_o.bank.command_valid[0]=state==PK_MEM_CMD;service_o.bank.mask[0]=8;
    service_o.bank.base[0][3]=576;service_o.bank.words[0][3]={2'b0,k_r,5'b0}+{4'b0,k_r,3'b0};
    service_o.bank.read_ready[0][3]=state==PK_BODY && source_ready;
    service_o.bank.done_ready[0][3]=state==PK_DRAIN;
    if(source_valid)begin key_valid_o=!host_sent_r;key_data_o=source_data;end
    if(state==SK_HEADER)begin
      key_valid_o=1;
      key_data_o=material_word;
    end
    if(state==SK_FIELD_STREAM)begin key_valid_o=service_i.poly_process.packed_valid;key_data_o=service_i.poly_process.packed_data;end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)material_r<=0;
    else if(state==IDLE && (LOCAL_CONTROL || start_valid_i))material_r[255:0]<=start_seed_i;
    else if(service_i.raw.output_valid && service_o.raw.output_ready &&
      service_i.raw.output_id==service_o.raw.id && service_i.raw.output_bytes==16)
      material_r[128*material_write_word+:128]<=service_i.raw.output_data;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;producer<=P_IDLE;level_r<=0;id_r<=0;
      pk_words<=10'd4;sk_words<=10'd16;
      k_r<=0;l_r<=0;s1_next_r<=0;s2_next_r<=0;a_row_r<=0;a_column_r<=0;a_write_r<=0;a_read_r<=0;
      transform_r<=0;row_r<=0;column_r<=0;sample_word_r<=0;seed_word_r<=0;header_r<=0;poly_r<=0;
      selected_r<=0;secret_phase_r<=0;s1_credit_r<=0;released_prev_r<=0;s1_ready_r<=0;s2_ready_r<=0;
      a_reserved_r<=0;a_ready_r<=0;batch_size_r<=0;batch_done_r<=0;descriptor_r[0]<='0;descriptor_r[1]<='0;
      raw_count_r<=0;tr_count_r<=0;hash_retired_r<=0;bank_retired_r<=0;host_sent_r<=0;hash_sent_r<=0;section_r<=0;
      key_index_o<=0;done_code_o<=0;fault_o<=0;
    end else begin
      released_prev_r<=service_i.ntt.source_released;
      if(secret_phase_r && service_i.ntt.source_released && !released_prev_r)s1_credit_r<=1;
      if(source_fire || (!source_valid && key_valid_o && key_ready_i))key_index_o<=key_index_o+1'b1;
      if(source_fire)begin host_sent_r<=0;hash_sent_r<=0;end
      else if(source_valid)begin
        if(key_valid_o && key_ready_i)host_sent_r<=1;
        if(raw_source_valid && raw_source_ready)hash_sent_r<=1;
      end
      if(service_i.raw.output_valid && service_o.raw.output_ready)begin
        if(service_i.raw.output_id!=service_o.raw.id || service_i.raw.output_bytes!=16)begin fault_o<=1;state<=HALT;done_code_o<=2;end
        else if(state<=SEED_WAIT)raw_count_r<=raw_count_r+1'b1;
        else tr_count_r<=tr_count_r+1'b1;
      end
      if(service_i.raw.done_valid && service_o.raw.done_ready && state>=PK_HEADER)hash_retired_r<=1;
      if(state==PK_DRAIN && service_i.bank.done_valid[0][3])bank_retired_r<=1;
      // Independent sampling producer:only two descriptors and9 A readiness
      // bits. It continues while the polynomial/Process controller runs.
      case(producer)
        P_IDLE:if(producer_enabled)begin
          if(secret_phase_r && s1_next_r<l_r && (s1_next_r==0 || s1_credit_r))begin
            descriptor_r[0]<=secret_descriptor(int'(s1_next_r),0);
            if(s1_next_r+1'b1<l_r)begin
              descriptor_r[1]<=secret_descriptor(int'(s1_next_r)+1,0);batch_size_r<=2;s1_next_r<=s1_next_r+2;
            end else begin batch_size_r<=1;s1_next_r<=s1_next_r+1'b1;end
            s1_credit_r<=0;selected_r<=0;sample_word_r<=0;batch_done_r<=0;producer<=P_CMD;
          end else if(!secret_phase_r || (s1_next_r==l_r &&
            (s1_ready_r & (7'h7f>>(7-l_r)))==(7'h7f>>(7-l_r))))begin
            if(a_row_r<k_r && !a_reserved_r[a_write_r])begin
              descriptor_r[0]<=matrix_descriptor(int'(a_row_r),int'(a_column_r),int'(a_write_r));
              a_reserved_r[a_write_r]<=1;a_write_r<=a_write_r==8?0:a_write_r+1'b1;
              if(a_column_r+1'b1==l_r)begin a_column_r<=0;a_row_r<=a_row_r+1'b1;end
              else a_column_r<=a_column_r+1'b1;
              if(s2_next_r<k_r)begin descriptor_r[1]<=secret_descriptor(int'(s2_next_r),1);s2_next_r<=s2_next_r+1'b1;batch_size_r<=2;end
              else begin
                logic [3:0] next_row,next_column,next_slot;
                next_row=a_row_r;next_column=a_column_r+1'b1;next_slot=a_write_r==8?0:a_write_r+1'b1;
                if(next_column==l_r)begin next_column=0;next_row=a_row_r+1'b1;end
                if(next_row<k_r && !a_reserved_r[next_slot])begin
                  descriptor_r[1]<=matrix_descriptor(int'(next_row),int'(next_column),int'(next_slot));
                  a_reserved_r[next_slot]<=1;a_write_r<=next_slot==8?0:next_slot+1'b1;
                  if(next_column+1'b1==l_r)begin a_column_r<=0;a_row_r<=next_row+1'b1;end
                  else begin a_column_r<=next_column+1'b1;a_row_r<=next_row;end
                  batch_size_r<=2;
                end else batch_size_r<=1;
              end
              selected_r<=0;sample_word_r<=0;batch_done_r<=0;producer<=P_CMD;
            end else if(s2_next_r<k_r)begin
              descriptor_r[0]<=secret_descriptor(int'(s2_next_r),1);s2_next_r<=s2_next_r+1'b1;batch_size_r<=1;
              selected_r<=0;sample_word_r<=0;batch_done_r<=0;producer<=P_CMD;
            end
          end
        end
        P_CMD:if(service_i.sample.ready)begin sample_word_r<=0;producer<=P_FEED;end
        P_FEED:if(sample_source_ready)begin
          if(sample_word_r==(current.kind==1?4:8))begin
            if(selected_r+2'd1==batch_size_r)producer<=P_WAIT;
            else begin selected_r<=1;producer<=P_CMD;end
          end else sample_word_r<=sample_word_r+1'b1;
        end
        P_WAIT:if(batch_done_r==(batch_size_r==1?1:3))producer<=P_IDLE;
        default:producer<=P_IDLE;
      endcase
      if(LOCAL_CONTROL?sample_event_r:sample_take)begin
        logic matched;matched=0;
        for(int i=0;i<2;i++)if((LOCAL_CONTROL?sample_event_mask_r[i]:
          (i<int'(batch_size_r) && descriptor_matches(descriptor_r[i],id_r,service_i.sample.done_id,l_r))) && !batch_done_r[i])begin
          matched=1;batch_done_r[i]<=1;
          case(descriptor_r[i].kind)
            0:s1_ready_r[descriptor_r[i].index]<=1;
            1:a_ready_r[descriptor_r[i].slot]<=1;
            2:s2_ready_r[descriptor_r[i].index]<=1;
          endcase
        end
        if(!matched || (!LOCAL_CONTROL && service_i.sample.done_code!=0))begin fault_o<=1;state<=HALT;done_code_o<=2;end
      end
      if(LOCAL_CONTROL && sample_take && sample_bad)begin fault_o<=1;done_code_o<=2;end
      case(state)
        IDLE:if(start_valid_i)begin
          level_r<=start_param_i;id_r<=start_id_i;k_r<=rows(start_param_i);l_r<=columns(start_param_i);
          pk_words<=public_words(rows(start_param_i));
          sk_words<=secret_words(start_param_i,rows(start_param_i),columns(start_param_i));
          done_code_o<=start_param_i==3?1:0;state<=start_param_i==3?REPORT:SEED_CMD;
          producer<=P_IDLE;s1_next_r<=0;s2_next_r<=0;a_row_r<=0;a_column_r<=0;a_write_r<=0;a_read_r<=0;
          transform_r<=0;row_r<=0;column_r<=0;s1_ready_r<=0;s2_ready_r<=0;a_ready_r<=0;a_reserved_r<=0;
          s1_credit_r<=0;secret_phase_r<=1;released_prev_r<=0;rawkeccak_sampler_count_r<=0;seed_word_r<=0;key_index_o<=0;
          tr_count_r<=0;hash_retired_r<=0;bank_retired_r<=0;host_sent_r<=0;hash_sent_r<=0;section_r<=0;
        end
        SEED_CMD:if(service_i.raw.ready)state<=SEED_FEED;
        SEED_FEED:if(raw_source_ready)begin
          if(seed_word_r==4)state<=SEED_WAIT;else seed_word_r<=seed_word_r+1'b1;
        end
        SEED_WAIT:if(service_i.raw.done_valid && service_o.raw.done_ready)state<=S1_READY;
        S1_READY:if(s1_ready_r[transform_r])state<=S1_CMD;
        S1_CMD:if(service_i.ntt.ready)state<=S1_RUN;
        S1_RUN:if(service_i.ntt.done_valid)begin
          if(transform_r+1'b1==l_r)begin secret_phase_r<=0;state<=TERM_READY;end
          else begin transform_r<=transform_r+1'b1;state<=S1_READY;end
        end
        TERM_READY:if(a_ready_r[a_read_r])state<=TERM_CMD;
        TERM_CMD:if(service_i.ntt.ready)state<=TERM_RUN;
        TERM_RUN:if(service_i.ntt.done_valid)begin
          a_reserved_r[a_read_r]<=0;a_ready_r[a_read_r]<=0;a_read_r<=a_read_r==8?0:a_read_r+1'b1;
          if(column_r+1'b1==l_r)begin column_r<=0;state<=INV_CMD;end
          else begin column_r<=column_r+1'b1;state<=TERM_READY;end
        end
        INV_CMD:if(service_i.ntt.ready)state<=INV_RUN;
        INV_RUN:if(service_i.ntt.done_valid)state<=ADD_READY;
        ADD_READY:if(s2_ready_r[row_r])state<=ADD_CMD;
        ADD_CMD:if(service_i.poly_process.ready)state<=ADD_RUN;
        ADD_RUN:if(service_i.poly_process.done_valid)state<=ROUND_CMD;
        ROUND_CMD:if(service_i.poly_process.ready)state<=ROUND_RUN;
        ROUND_RUN:if(service_i.poly_process.done_valid)begin
          if(row_r+1'b1==k_r)state<=PK_MEM_CMD;
          else begin row_r<=row_r+1'b1;state<=TERM_READY;end
        end
        PK_MEM_CMD:if(service_i.bank.command_ready[0])begin state<=PK_HASH_CMD;header_r<=0;end
        PK_HASH_CMD:if(service_i.raw.ready)state<=PK_HEADER;
        PK_HEADER:if(source_fire)begin if(header_r==3)state<=PK_BODY;else header_r<=header_r+1'b1;end
        PK_BODY:if(source_fire && key_last_o)state<=PK_DRAIN;
        PK_DRAIN:if(hash_retired_r && bank_retired_r && !service_i.sample.active)begin
          state<=SK_HEADER;header_r<=0;key_index_o<=0;
        end
        SK_HEADER:if(key_ready_i)begin
          if(header_r==15)begin section_r<=1;poly_r<=0;state<=SK_FIELD_CMD;end
          else header_r<=header_r+1'b1;
        end
        SK_FIELD_CMD:if(service_i.poly_process.ready)state<=SK_FIELD_STREAM;
        SK_FIELD_STREAM:if(service_i.poly_process.done_valid)begin
          if(poly_r+1'b1==(section_r==1?l_r:k_r))begin
            if(section_r==3)state<=REPORT;
            else begin section_r<=section_r+1'b1;poly_r<=0;state<=SK_FIELD_CMD;end
          end else begin poly_r<=poly_r+1'b1;state<=SK_FIELD_CMD;end
        end
        REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:state<=IDLE;
      endcase
      // Real child failures require coordinated reset;fixed stale RAM words
      // are never made public after an internal protocol/arithmetic failure.
      if(state!=IDLE && state!=REPORT && (service_i.sample.fault ||
        (service_i.ntt.done_valid && service_o.ntt.done_ready && service_i.ntt.done_code!=0) ||
        (service_i.poly_process.done_valid && service_o.poly_process.done_ready && service_i.poly_process.done_code!=0)))begin
        fault_o<=1;done_code_o<=2;state<=HALT;
      end
      if(fault_o)state<=HALT;
    end
  end
endmodule
`default_nettype wire
