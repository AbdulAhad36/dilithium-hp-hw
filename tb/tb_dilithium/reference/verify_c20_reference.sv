// Pure final-FIPS Verify,with fixed bank lifetimes and one shared engine set.
// Frames:PK,SIG,ctx||M. Encoding/norm failure and digest mismatch are invalid
// signatures(code0/accept0);transport failure remains an explicit service error.
`default_nettype none
module verify_c20_reference (
  input wire logic clk,rst,start_valid_i,output logic start_ready_o,busy_o,fault_o,
  input wire logic [1:0] start_param_i,input wire logic [15:0] start_id_i,start_message_len_i,start_signature_len_i,
  input wire logic [8:0] start_context_len_i,
  input wire logic input_valid_i,output logic input_ready_o,input wire logic [63:0] input_data_i,
  input wire logic [3:0] input_bytes_i,input wire logic [15:0] input_index_i,input wire logic input_last_i,
  output logic done_valid_o,input wire logic done_ready_i,output logic [15:0] done_id_o,
  output logic [2:0] done_code_o,done_stage_o,done_detail_o,output logic done_accept_o,
  output dilithium_pkg::request_t service_o,input var dilithium_pkg::response_t service_i
);
  import dilithium_pkg::*;
  typedef enum logic [5:0] {IDLE,INPUT_CMD,INPUT_WAIT,INPUT_RETIRE,MU_CMD,MU_RUN,
    CHAL_CMD,CHAL_FEED,CHAL_WAIT,CHAL_NTT_CMD,CHAL_NTT_RUN,PREP_CMD,PREP_RUN,
    TERM_READY,TERM_CMD,TERM_RUN,CT1_CMD,CT1_RUN,SUB_CMD,SUB_RUN,INV_CMD,INV_RUN,
    PACK_CMD,PACK_RUN,MATRIX_DRAIN,W1_READ_CMD,CHASH_CMD,CHASH_RUN,CHASH_DRAIN,DRAIN,REPORT,HALT} state_e;
  typedef enum logic [1:0] {P_IDLE,P_CMD,P_FEED,P_WAIT} producer_e;
  typedef struct packed {logic [3:0] row,column,slot;} descriptor_t;
  state_e state;producer_e producer;descriptor_t descriptor_r[2],current;
  logic [1:0] level_r,batch_size_r,batch_done_r;logic selected_r,section_r,accept_r,input_bad_r;
  logic [15:0] id_r,message_r,signature_len_r;logic [8:0] context_r;logic [17:0] message_total;
  logic [3:0] k_r,l_r,poly_r,row_r,column_r,a_row_r,a_column_r,a_write_r,a_read_r,sample_word_r,challenge_word_r;
  logic [15:0] a_reserved_r,a_ready_r;logic [511:0] mu_r,digest_r;
  logic [255:0] rho;logic [511:0] tr,ctilde;
  logic input_command_ready,input_done,input_fault,input_payload_ready;logic [2:0] input_code;logic [15:0] input_done_id;
  request_t input_request;
  logic formatter_ready,formatter_done,formatter_payload_ready,format_request,format_sampling,format_mode,format_input_valid;
  logic [2:0] formatter_code;logic [15:0] formatter_done_id,format_id,format_length,format_output_length;
  logic [1:0] format_op,format_param;logic [63:0] format_input_data;logic [3:0] format_input_bytes;
  logic [15:0] format_input_index;logic format_input_last;
  logic [2:0] raw_count_r,raw_expected;logic raw_core_r,format_finished_r,raw_finished_r,bank_finished_r;
  logic [2:0] format_code_r;logic [7:0] memory_word_r,w1_words;
  logic [15:0] ctilde_bytes;logic [3:0] ctilde_words;
  logic raw_phase,ntt_wait,process_wait,producer_enabled,digest_equal;
  logic [9:0] packed_row_offset;
  assign packed_row_offset={2'b0,row_r,4'b0}+(level_r==0?{3'b0,row_r,3'b0}:10'd0);
  function automatic logic [3:0] next_ring(input logic [3:0] position,input logic [1:0] level);
    return position==(level==2?4'd15:4'd8)?4'd0:position+1'b1;
  endfunction
  function automatic logic [15:0] sample_id(input descriptor_t d,input logic [15:0] id);
    return id+16'd1024+{8'd0,d.row,d.column};
  endfunction
  assign current=descriptor_r[selected_r];
  assign message_total=18'd66+18'(start_context_len_i)+18'(start_message_len_i);
  assign ctilde_bytes=level_r==0?32:level_r==1?48:64;assign ctilde_words=level_r==0?4:level_r==1?6:8;
  assign w1_words=level_r==2?128:96;
  assign format_op=state==MU_CMD || state==MU_RUN?0:2;
  assign raw_phase=state==MU_RUN || state==CHASH_RUN || state==CHASH_DRAIN;
  assign producer_enabled=state>=PREP_CMD && state<=PACK_RUN;
  assign ntt_wait=state==CHAL_NTT_RUN || state==PREP_RUN || state==TERM_RUN || state==CT1_RUN || state==INV_RUN;
  assign process_wait=state==SUB_RUN || state==PACK_RUN;
  // Phase overlay: Mu is read only through the CHASH prefix; afterwards this
  // same512-bit bank holds the computed challenge. The debug alias is valid
  // as a digest after hashing,not a second independently retained value.
  assign digest_r=mu_r;
  assign digest_equal=level_r==0?digest_r[255:0]==ctilde[255:0]:level_r==1?digest_r[383:0]==ctilde[383:0]:digest_r==ctilde;
  assign start_ready_o=!rst && !fault_o && state==IDLE && service_i.idle && input_command_ready && formatter_ready;
  assign busy_o=state!=IDLE;assign done_valid_o=!rst && !fault_o && state==REPORT;assign done_id_o=id_r;
  assign done_accept_o=done_valid_o && done_code_o==0 && accept_r;
  assign input_ready_o=!rst && !fault_o && (state==INPUT_WAIT?input_payload_ready:state==MU_RUN?formatter_payload_ready:1'b0);
  verify_input_c20_reference inputs(
    .clk(clk),.rst(rst),.command_valid_i(state==INPUT_CMD),.command_ready_o(input_command_ready),.busy_o(),.fault_o(input_fault),
    .command_param_i(level_r),.command_id_i(id_r),.command_signature_len_i(signature_len_r),
    .input_valid_i(state==INPUT_WAIT && input_valid_i),.input_ready_o(input_payload_ready),.input_data_i(input_data_i),
    .input_bytes_i(input_bytes_i),.input_index_i(input_index_i),.input_last_i(input_last_i),
    .rho_o(rho),.tr_o(tr),.ctilde_o(ctilde),.done_valid_o(input_done),.done_ready_i(state==INPUT_WAIT),
    .done_code_o(input_code),.done_id_o(input_done_id),.service_o(input_request),.service_i(service_i));
  sign_hash_message #(.STABLE_PREFIX_INPUTS(1)) formatter(
    .clk(clk),.rst(rst),.command_valid_i(state==MU_CMD || state==CHASH_CMD),.command_ready_o(formatter_ready),.busy_o(),
    .command_op_i(format_op),.command_param_i(level_r),.command_id_i(id_r+16'd256+16'(format_op)),
    .command_message_len_i(message_r),.command_nonce_i(16'd0),.command_context_len_i(context_r),
    .command_tr_i(tr),.command_mu_i(mu_r),.command_mask_seed_i(512'd0),.command_key_i(256'd0),.command_rnd_i(256'd0),
    .payload_valid_i(state==MU_RUN?input_valid_i:state==CHASH_RUN && service_i.bank.read_valid[0][1]),
    .payload_ready_o(formatter_payload_ready),.payload_data_i(state==MU_RUN?input_data_i:service_i.bank.read_data[0][1][63:0]),
    .payload_bytes_i(state==MU_RUN?input_bytes_i:4'd8),.payload_index_i(state==MU_RUN?input_index_i:16'(memory_word_r)),
    .payload_last_i(state==MU_RUN?input_last_i:memory_word_r+1'b1==w1_words),
    .request_valid_o(format_request),.request_ready_i(service_i.raw.ready),.request_sampling_o(format_sampling),
    .request_mode_o(format_mode),.request_param_o(format_param),.request_id_o(format_id),
    .request_message_len_o(format_length),.request_output_len_o(format_output_length),
    .input_valid_o(format_input_valid),.input_ready_i(service_i.raw.input_ready),.input_data_o(format_input_data),
    .input_bytes_o(format_input_bytes),.input_index_o(format_input_index),.input_last_o(format_input_last),
    .done_valid_o(formatter_done),.done_ready_i(raw_phase),.done_code_o(formatter_code),.done_id_o(formatter_done_id));
  always_comb begin
    service_o='0;
    service_o.raw.valid=format_request;service_o.raw.mode=format_mode;service_o.raw.id=format_id;
    service_o.raw.message_len=format_length;service_o.raw.output_len=format_output_length;
    service_o.raw.input_valid=format_input_valid;service_o.raw.input_data=format_input_data;
    service_o.raw.output_ready=raw_phase && raw_count_r<raw_expected;
    service_o.raw.done_ready=raw_phase && raw_count_r==raw_expected && format_finished_r && !raw_finished_r;
    service_o.sample.valid=producer==P_CMD;service_o.sample.batch_last=selected_r+2'd1==batch_size_r;
    service_o.sample.mode=0;service_o.sample.param=level_r;service_o.sample.bank=3;service_o.sample.base={current.slot,6'd0};
    service_o.sample.id=sample_id(current,id_r);service_o.sample.message_len=34;
    service_o.sample.input_valid=producer==P_FEED;service_o.sample.done_ready=producer!=P_IDLE;
    service_o.sample.input_data=sample_word_r==4?{48'd0,4'd0,current.row,4'd0,current.column}:rho[64*sample_word_r+:64];
    if(state==CHAL_CMD || state==CHAL_FEED || state==CHAL_WAIT)begin
      service_o.sample.valid=state==CHAL_CMD;service_o.sample.batch_last=1;service_o.sample.mode=3;
      service_o.sample.bank=0;service_o.sample.base=960;service_o.sample.id=id_r+16'd512;service_o.sample.message_len=ctilde_bytes;
      service_o.sample.input_valid=state==CHAL_FEED;service_o.sample.input_data=ctilde[64*challenge_word_r+:64];
      service_o.sample.done_ready=state==CHAL_WAIT;
    end
    service_o.ntt.done_ready=ntt_wait;
    case(state)
      CHAL_NTT_CMD:begin service_o.ntt.valid=1;service_o.ntt.op=0;service_o.ntt.a_bank=0;service_o.ntt.a_base=960;service_o.ntt.d_bank=2;service_o.ntt.d_base=896;end
      PREP_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=0;service_o.ntt.a_bank=section_r?0:2;
        service_o.ntt.a_base=(section_r?10'd448:10'd0)+{poly_r,6'd0};
        service_o.ntt.d_bank=service_o.ntt.a_bank;service_o.ntt.d_base=service_o.ntt.a_base;
      end
      TERM_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=2;service_o.ntt.accumulate=column_r!=0;
        service_o.ntt.a_bank=3;service_o.ntt.a_base={a_read_r,6'd0};service_o.ntt.b_bank=2;service_o.ntt.b_base={column_r,6'd0};
        service_o.ntt.c_bank=1;service_o.ntt.d_bank=1;
      end
      CT1_CMD:begin
        service_o.ntt.valid=1;service_o.ntt.op=2;service_o.ntt.a_bank=2;service_o.ntt.a_base=896;
        service_o.ntt.b_bank=0;service_o.ntt.b_base=10'd448+{row_r,6'd0};service_o.ntt.d_bank=0;service_o.ntt.d_base=960;
      end
      INV_CMD:begin service_o.ntt.valid=1;service_o.ntt.op=1;service_o.ntt.a_bank=1;service_o.ntt.d_bank=0;service_o.ntt.d_base=960;end
      default:begin end
    endcase
    service_o.poly_process.param=level_r;service_o.poly_process.done_ready=process_wait;
    if(state==SUB_CMD)begin
      service_o.poly_process.valid=1;service_o.poly_process.op=PROC_SUB;service_o.poly_process.a_bank=1;
      service_o.poly_process.b_enable=1;service_o.poly_process.b_bank=0;service_o.poly_process.b_base=960;
      service_o.poly_process.low_enable=1;service_o.poly_process.d_bank=1;
    end
    if(state==PACK_CMD)begin
      service_o.poly_process.valid=1;service_o.poly_process.op=PROC_USEHINT;service_o.poly_process.a_bank=0;service_o.poly_process.a_base=960;
      service_o.poly_process.b_enable=1;service_o.poly_process.b_bank=1;service_o.poly_process.b_base=10'd64+{row_r,6'd0};
      service_o.poly_process.pack_enable=1;service_o.poly_process.pack_store=1;service_o.poly_process.h_bank=1;
      service_o.poly_process.h_base=10'd576+packed_row_offset;
    end
    service_o.bank.command_valid[0]=state==W1_READ_CMD;service_o.bank.mask[0]=2;
    service_o.bank.base[0][1]=576;service_o.bank.words[0][1]=11'(w1_words);
    service_o.bank.read_ready[0][1]=state==CHASH_RUN && formatter_payload_ready;
    service_o.bank.done_ready[0][1]=state==CHASH_RUN || state==CHASH_DRAIN;
    if(state==INPUT_CMD || state==INPUT_WAIT || state==INPUT_RETIRE)service_o=input_request;
    if(fault_o)service_o='0;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;producer<=P_IDLE;level_r<=0;id_r<=0;message_r<=0;signature_len_r<=0;context_r<=0;
      k_r<=0;l_r<=0;poly_r<=0;row_r<=0;column_r<=0;section_r<=0;accept_r<=0;input_bad_r<=0;
      a_row_r<=0;a_column_r<=0;a_write_r<=0;a_read_r<=0;a_reserved_r<=0;a_ready_r<=0;
      descriptor_r[0]<='0;descriptor_r[1]<='0;batch_size_r<=0;batch_done_r<=0;selected_r<=0;sample_word_r<=0;challenge_word_r<=0;
      mu_r<=0;raw_count_r<=0;raw_expected<=0;raw_core_r<=0;format_finished_r<=0;raw_finished_r<=0;
      bank_finished_r<=0;format_code_r<=0;memory_word_r<=0;done_code_o<=0;done_stage_o<=0;done_detail_o<=0;fault_o<=0;
    end else begin
      if((state==MU_CMD || state==CHASH_CMD) && formatter_ready)begin
        raw_count_r<=0;raw_expected<=state==MU_CMD?3'd4:level_r==0?3'd2:level_r==1?3'd3:3'd4;
        format_finished_r<=0;raw_finished_r<=0;format_code_r<=0;
      end
      if(format_request && service_i.raw.ready)raw_core_r<=service_i.raw.core;
      if(formatter_done && raw_phase)begin format_finished_r<=1;format_code_r<=formatter_code;end
      // The input phase validates its own PK hash tags. This formatter owns
      // raw responses only during mu/challenge hashing,after input retirement.
      if(raw_phase && service_i.raw.output_valid && service_o.raw.output_ready)begin
        // Mu is dead after CHASH has absorbed its prefix. Reuse exactly the
        // same raw-output write port; clear unused digest high bytes once.
        if(state!=MU_RUN && raw_count_r==0)mu_r<={384'd0,service_i.raw.output_data};
        else mu_r[128*raw_count_r+:128]<=service_i.raw.output_data;
        raw_count_r<=raw_count_r+1'b1;
      end
      if(raw_phase && service_i.raw.done_valid && service_o.raw.done_ready)raw_finished_r<=1;
      if(service_i.bank.read_valid[0][1] && service_o.bank.read_ready[0][1])memory_word_r<=memory_word_r+1'b1;
      if(service_i.bank.done_valid[0][1] && service_o.bank.done_ready[0][1])bank_finished_r<=1;
      case(producer)
        P_IDLE:if(producer_enabled && a_row_r<k_r && !a_reserved_r[a_write_r])begin
          logic [3:0] next_row,next_column,next_slot;
          descriptor_r[0]<='{row:a_row_r,column:a_column_r,slot:a_write_r};a_reserved_r[a_write_r]<=1;
          next_row=a_row_r;next_column=a_column_r+1'b1;next_slot=next_ring(a_write_r,level_r);
          if(next_column==l_r)begin next_column=0;next_row=a_row_r+1'b1;end
          if(next_row<k_r && !a_reserved_r[next_slot])begin
            descriptor_r[1]<='{row:next_row,column:next_column,slot:next_slot};a_reserved_r[next_slot]<=1;batch_size_r<=2;
            a_write_r<=next_ring(next_slot,level_r);
            if(next_column+1'b1==l_r)begin a_column_r<=0;a_row_r<=next_row+1'b1;end
            else begin a_column_r<=next_column+1'b1;a_row_r<=next_row;end
          end else begin batch_size_r<=1;a_write_r<=next_slot;a_column_r<=next_column;a_row_r<=next_row;end
          selected_r<=0;sample_word_r<=0;batch_done_r<=0;producer<=P_CMD;
        end
        P_CMD:if(service_i.sample.ready)begin sample_word_r<=0;producer<=P_FEED;end
        P_FEED:if(service_i.sample.input_ready)begin
          if(sample_word_r==4)begin if(selected_r+2'd1==batch_size_r)producer<=P_WAIT;else begin selected_r<=1;producer<=P_CMD;end end
          else sample_word_r<=sample_word_r+1'b1;
        end
        P_WAIT:if(batch_done_r==(batch_size_r==1?1:3))producer<=P_IDLE;
        default:producer<=P_IDLE;
      endcase
      case(state)
        IDLE:if(start_valid_i && start_ready_o)begin
          level_r<=start_param_i;id_r<=start_id_i;message_r<=start_message_len_i;signature_len_r<=start_signature_len_i;context_r<=start_context_len_i;
          k_r<=rows(start_param_i);l_r<=columns(start_param_i);done_code_o<=0;done_stage_o<=0;done_detail_o<=0;
          accept_r<=0;input_bad_r<=0;section_r<=0;poly_r<=0;row_r<=0;column_r<=0;challenge_word_r<=0;
          a_row_r<=0;a_column_r<=0;a_write_r<=0;a_read_r<=0;a_reserved_r<=0;a_ready_r<=0;producer<=P_IDLE;
          mu_r<=0;state<=INPUT_CMD;
          if(start_param_i==3 || start_context_len_i>255 || message_total>65535)begin done_code_o<=1;state<=REPORT;end
        end
        INPUT_CMD:if(input_command_ready)state<=INPUT_WAIT;
        INPUT_WAIT:if(input_done)begin
          input_bad_r<=input_code!=0;state<=INPUT_RETIRE;
          if(input_done_id!=id_r)begin done_code_o<=6;done_stage_o<=1;end
          else if(input_code!=0 && input_code!=2)begin done_code_o<=3;done_stage_o<=1;done_detail_o<=input_code;end
        end
        INPUT_RETIRE:if(input_command_ready)state<=input_bad_r || done_code_o!=0?DRAIN:MU_CMD;
        MU_CMD:if(formatter_ready)state<=MU_RUN;
        MU_RUN:if(raw_finished_r && format_finished_r)begin
          if(format_code_r!=0)begin done_code_o<=4;done_stage_o<=2;done_detail_o<=format_code_r;state<=DRAIN;end
          else state<=CHAL_CMD;
        end
        CHAL_CMD:if(service_i.sample.ready)state<=CHAL_FEED;
        CHAL_FEED:if(service_i.sample.input_ready)begin
          if(challenge_word_r+1'b1==ctilde_words)state<=CHAL_WAIT;else challenge_word_r<=challenge_word_r+1'b1;
        end
        CHAL_WAIT:if(service_i.sample.done_valid)begin
          if(service_i.sample.done_id!=id_r+16'd512 || service_i.sample.done_code!=0)begin fault_o<=1;state<=HALT;end
          else state<=CHAL_NTT_CMD;
        end
        CHAL_NTT_CMD:if(service_i.ntt.ready)state<=CHAL_NTT_RUN;
        CHAL_NTT_RUN:if(service_i.ntt.done_valid)state<=PREP_CMD;
        PREP_CMD:if(service_i.ntt.ready)state<=PREP_RUN;
        PREP_RUN:if(service_i.ntt.done_valid)begin
          if(poly_r+1'b1==(section_r?k_r:l_r))begin
            if(section_r)state<=TERM_READY;else begin section_r<=1;poly_r<=0;state<=PREP_CMD;end
          end else begin poly_r<=poly_r+1'b1;state<=PREP_CMD;end
        end
        TERM_READY:if(a_ready_r[a_read_r])state<=TERM_CMD;
        TERM_CMD:if(service_i.ntt.ready)state<=TERM_RUN;
        TERM_RUN:if(service_i.ntt.done_valid)begin
          a_ready_r[a_read_r]<=0;a_reserved_r[a_read_r]<=0;a_read_r<=next_ring(a_read_r,level_r);
          if(column_r+1'b1==l_r)begin column_r<=0;state<=CT1_CMD;end else begin column_r<=column_r+1'b1;state<=TERM_READY;end
        end
        CT1_CMD:if(service_i.ntt.ready)state<=CT1_RUN;
        CT1_RUN:if(service_i.ntt.done_valid)state<=SUB_CMD;
        SUB_CMD:if(service_i.poly_process.ready)state<=SUB_RUN;
        SUB_RUN:if(service_i.poly_process.done_valid)state<=INV_CMD;
        INV_CMD:if(service_i.ntt.ready)state<=INV_RUN;
        INV_RUN:if(service_i.ntt.done_valid)state<=PACK_CMD;
        PACK_CMD:if(service_i.poly_process.ready)state<=PACK_RUN;
        PACK_RUN:if(service_i.poly_process.done_valid)begin
          if(row_r+1'b1==k_r)state<=MATRIX_DRAIN;else begin row_r<=row_r+1'b1;state<=TERM_READY;end
        end
        MATRIX_DRAIN:if(producer==P_IDLE && service_i.idle)begin memory_word_r<=0;bank_finished_r<=0;state<=W1_READ_CMD;end
        W1_READ_CMD:if(service_i.bank.command_ready[0])state<=CHASH_CMD;
        CHASH_CMD:if(formatter_ready)state<=CHASH_RUN;
        CHASH_RUN:if(format_finished_r)state<=CHASH_DRAIN;
        CHASH_DRAIN:if(format_finished_r && raw_finished_r && bank_finished_r)begin accept_r<=digest_equal;state<=DRAIN;end
        DRAIN:if(service_i.idle && formatter_ready && input_command_ready && producer==P_IDLE)state<=REPORT;
        REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:begin fault_o<=1;state<=HALT;end
      endcase
      if(producer!=P_IDLE && service_i.sample.done_valid && service_o.sample.done_ready)begin
        logic matched;matched=0;
        for(int i=0;i<2;i++)if(i<int'(batch_size_r) && service_i.sample.done_id==sample_id(descriptor_r[i],id_r) && !batch_done_r[i])begin
          matched=1;batch_done_r[i]<=1;a_ready_r[descriptor_r[i].slot]<=1;
        end
        if(!matched || service_i.sample.done_code!=0)begin fault_o<=1;state<=HALT;end
      end
      if(state!=IDLE && state!=REPORT && (input_fault || service_i.sample.fault ||
        (ntt_wait && service_i.ntt.done_valid && service_i.ntt.done_code!=0) ||
        (process_wait && service_i.poly_process.done_valid && service_i.poly_process.done_code!=0) ||
        (formatter_done && raw_phase && formatter_done_id!=format_id) ||
        (raw_phase && service_o.raw.output_ready && service_i.raw.output_valid && (service_i.raw.output_id!=format_id || service_i.raw.output_core!=raw_core_r || service_i.raw.output_bytes!=16)) ||
        (raw_phase && service_o.raw.done_ready && service_i.raw.done_valid && (service_i.raw.done_id!=format_id || service_i.raw.done_core!=raw_core_r)) ||
        (service_o.bank.read_ready[0][1] && service_i.bank.read_valid[0][1] && (service_i.bank.read_address[0][1]!=10'd576+10'(memory_word_r) || service_i.bank.read_last[0][1]!=(memory_word_r+1'b1==w1_words))) ||
        (service_o.bank.done_ready[0][1] && service_i.bank.done_valid[0][1] && service_i.bank.done_error[0][1]) ||
        (state==CHASH_DRAIN && format_finished_r && format_code_r!=0)))begin fault_o<=1;state<=HALT;end
    end
  end
  // synthesis translate_off
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst && raw_phase && state!=MU_RUN &&
    service_i.raw.output_valid && service_o.raw.output_ready && formatter.prefix_left_r!=0)
    $fatal(1,"Verify digest overwrote Mu before prefix consumption");
`endif
  // synthesis translate_on
endmodule
`default_nettype wire
