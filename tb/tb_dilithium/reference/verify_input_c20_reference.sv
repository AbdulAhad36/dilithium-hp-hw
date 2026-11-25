// Compact Verify input phase. PK then signature;no encoded-key/signature RAM.
// Shared BitUnpkg writes shifted t1 to bank0[448..],z to bank2[0..].
// Canonical hint words occupy bank1[64..]. PK hashing shares the SAME Keccak.
// done0 qualifies all raw operands;done2 is signature invalidity,done3 framing.
`default_nettype none
module verify_input_c20_reference (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,busy_o,fault_o,
  input wire logic [1:0] command_param_i,input wire logic [15:0] command_id_i,command_signature_len_i,
  input wire logic input_valid_i,output logic input_ready_o,input wire logic [63:0] input_data_i,
  input wire logic [3:0] input_bytes_i,input wire logic [15:0] input_index_i,input wire logic input_last_i,
  output logic [255:0] rho_o,output logic [511:0] tr_o,ctilde_o,
  output logic done_valid_o,input wire logic done_ready_i,output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output dilithium_pkg::request_t service_o,input var dilithium_pkg::response_t service_i
);
  import dilithium_pkg::*;
  typedef enum logic [4:0] {IDLE,HASH_CMD,PK_HEADER,PK_LOAD_CMD,PK_DATA,PK_WAIT,SIG_HEADER,
    Z_LOAD_CMD,Z_DATA,Z_WAIT,NORM_CMD,NORM_RUN,HINT_CMD,HINT_RUN,DRAIN,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] level_r;logic [15:0] id_r,word_r,signature_len_r;
  logic [3:0] k_r,l_r,poly_r,ctilde_words_r,hint_word_r;
  logic [6:0] field_word_r,z_words_r;
  logic [9:0] hash_words_r,pk_words_r,hint_words_sent_r;
  logic [2:0] digest_beats_r;logic signature_r,raw_sent_r,load_sent_r,raw_core_r;
  logic hash_active_r,hash_finished_r,load_active_r,load_finished_r;
  logic hint_active_r,hint_finished_r,bank_started_r,bank_finished_r;
  logic host_fire,pk_phase,bad_frame;logic [3:0] expected_bytes;
  logic hint_ready,hint_input_ready,hint_valid,hint_last,hint_done,hint_output_ready;
  logic [3:0] hint_mask;logic [2:0] hint_row,hint_code;logic [5:0] hint_word;
  logic [15:0] hint_id,hint_done_id,hash_id,load_id;
  assign hash_id=id_r+16'd32;
  assign load_id=id_r+16'd64+(signature_r?16'd32:16'd0)+16'(poly_r);
  assign pk_phase=state==PK_HEADER || state==PK_DATA;
  assign expected_bytes=!signature_r?4'd8:signature_len_r-16'(word_r)*16'd8>=8?4'd8:4'(signature_len_r-16'(word_r)*16'd8);
  assign bad_frame=input_bytes_i!=expected_bytes || input_index_i!=word_r ||
    input_last_i!=(signature_r?(16'(word_r)*16'd8+16'(expected_bytes)==signature_len_r):word_r+1'b1==16'(pk_words_r));
  assign command_ready_o=!rst && !fault_o && state==IDLE && service_i.idle && hint_ready;
  assign busy_o=state!=IDLE;assign done_valid_o=!rst && !fault_o && state==REPORT;assign done_id_o=id_r;
  assign input_ready_o=!rst && !fault_o && (state==PK_HEADER?(raw_sent_r || service_i.raw.input_ready):
    state==PK_DATA?(raw_sent_r || service_i.raw.input_ready) && (load_sent_r || service_i.load.input_ready):
    state==SIG_HEADER?1'b1:state==Z_DATA?service_i.load.input_ready:state==HINT_RUN?hint_input_ready:1'b0);
  assign host_fire=input_valid_i && input_ready_o;
  assign hint_output_ready=state==HINT_RUN && bank_started_r && service_i.bank.write_ready[1][1] && !fault_o;
  assign hint_ready=service_i.hint_decode.ready;assign hint_input_ready=service_i.hint_decode.input_ready;
  assign hint_valid=service_i.hint_decode.output_valid;assign hint_mask=service_i.hint_decode.output_hints;
  assign hint_row=service_i.hint_decode.output_row;assign hint_word=service_i.hint_decode.output_word;
  assign hint_last=service_i.hint_decode.output_last;assign hint_id=service_i.hint_decode.output_id;
  assign hint_done=service_i.hint_decode.done_valid;assign hint_code=service_i.hint_decode.done_code;
  assign hint_done_id=service_i.hint_decode.done_id;
  always_comb begin
    service_o='0;
    service_o.hint_decode.valid=state==HINT_CMD;service_o.hint_decode.param=level_r;
    service_o.hint_decode.id=id_r+16'd128;service_o.hint_decode.input_valid=state==HINT_RUN && input_valid_i;
    service_o.hint_decode.input_data=input_data_i;service_o.hint_decode.input_index=hint_word_r;
    service_o.hint_decode.input_bytes=bad_frame?4'd0:input_bytes_i;service_o.hint_decode.input_last=input_last_i;
    service_o.hint_decode.output_ready=hint_output_ready;service_o.hint_decode.done_ready=state==HINT_RUN || state==DRAIN;
    service_o.raw.valid=state==HASH_CMD;service_o.raw.mode=1;service_o.raw.id=hash_id;
    service_o.raw.message_len=16'(pk_words_r)*16'd8;service_o.raw.output_len=64;
    service_o.raw.input_valid=(pk_phase && input_valid_i && !raw_sent_r) || (state==DRAIN && hash_words_r<pk_words_r);
    service_o.raw.input_data=state==DRAIN?64'd0:input_data_i;
    service_o.raw.output_ready=hash_active_r && digest_beats_r<4;
    service_o.raw.done_ready=hash_active_r && digest_beats_r==4 && hash_words_r==pk_words_r;
    service_o.load.valid=state==PK_LOAD_CMD || state==Z_LOAD_CMD;service_o.load.op=signature_r?4:5;
    service_o.load.param=level_r;service_o.load.bank=signature_r?2:0;
    service_o.load.base=signature_r?{poly_r,6'd0}:10'd448+{poly_r,6'd0};service_o.load.id=load_id;
    service_o.load.input_valid=input_valid_i && ((state==PK_DATA && !load_sent_r) || state==Z_DATA);
    service_o.load.input_data=input_data_i;service_o.load.input_index=field_word_r;
    service_o.load.input_bytes=bad_frame?4'd0:input_bytes_i;
    service_o.load.input_last=field_word_r+1'b1==(signature_r?z_words_r:7'd40);
    service_o.load.done_ready=load_active_r;
    service_o.poly_process.valid=state==NORM_CMD;service_o.poly_process.op=PROC_CNB;service_o.poly_process.param=level_r;
    service_o.poly_process.kind=0;service_o.poly_process.a_bank=2;service_o.poly_process.a_base={poly_r,6'd0};
    service_o.poly_process.done_ready=state==NORM_RUN;
    service_o.bank.command_valid[1]=state==HINT_RUN && hint_valid && !bank_started_r;
    service_o.bank.mask[1]=2;service_o.bank.write[1]=2;service_o.bank.base[1][1]=64;
    service_o.bank.words[1][1]=11'(k_r)<<6;
    service_o.bank.write_valid[1][1]=state==HINT_RUN && bank_started_r && hint_valid;
    for(int lane=0;lane<4;lane++)service_o.bank.write_data[1][1][23*lane+:23]={22'd0,hint_mask[lane]};
    service_o.bank.done_ready[1][1]=state==HINT_RUN || state==DRAIN;
    if(fault_o)service_o='0;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;level_r<=0;id_r<=0;word_r<=0;signature_len_r<=0;k_r<=0;l_r<=0;poly_r<=0;
      ctilde_words_r<=0;hint_word_r<=0;field_word_r<=0;z_words_r<=0;hash_words_r<=0;pk_words_r<=0;
      hint_words_sent_r<=0;digest_beats_r<=0;signature_r<=0;raw_sent_r<=0;load_sent_r<=0;raw_core_r<=0;
      hash_active_r<=0;hash_finished_r<=0;load_active_r<=0;load_finished_r<=0;hint_active_r<=0;hint_finished_r<=0;
      bank_started_r<=0;bank_finished_r<=0;rho_o<=0;tr_o<=0;ctilde_o<=0;done_code_o<=0;fault_o<=0;
    end else begin
      if(state==HASH_CMD && service_i.raw.ready)begin hash_active_r<=1;raw_core_r<=service_i.raw.core;end
      if(service_o.raw.input_valid && service_i.raw.input_ready)begin hash_words_r<=hash_words_r+1'b1;if(pk_phase)raw_sent_r<=1;end
      if(service_o.raw.output_ready && service_i.raw.output_valid)begin
        tr_o[128*digest_beats_r+:128]<=service_i.raw.output_data;digest_beats_r<=digest_beats_r+1'b1;
      end
      if(service_o.raw.done_ready && service_i.raw.done_valid)begin hash_active_r<=0;hash_finished_r<=1;end
      if(service_o.load.valid && service_i.load.ready)begin load_active_r<=1;load_finished_r<=0;field_word_r<=0;end
      if(service_o.load.input_valid && service_i.load.input_ready && state==PK_DATA)load_sent_r<=1;
      if(service_o.load.done_ready && service_i.load.done_valid)begin load_active_r<=0;load_finished_r<=1;end
      if(host_fire)begin word_r<=word_r+1'b1;raw_sent_r<=0;load_sent_r<=0;end
      if(state==HINT_CMD && hint_ready)hint_active_r<=1;
      if(hint_done && (state==HINT_RUN || state==DRAIN))begin hint_active_r<=0;hint_finished_r<=1;end
      if(service_o.bank.command_valid[1] && service_i.bank.command_ready[1])bank_started_r<=1;
      if(hint_valid && hint_output_ready)hint_words_sent_r<=hint_words_sent_r+1'b1;
      if(service_o.bank.done_ready[1][1] && service_i.bank.done_valid[1][1])bank_finished_r<=1;
      case(state)
        IDLE:if(command_valid_i && command_ready_o)begin
          level_r<=command_param_i;id_r<=command_id_i;k_r<=rows(command_param_i);l_r<=columns(command_param_i);
          signature_len_r<=command_signature_len_i;pk_words_r<=10'd4+10'(rows(command_param_i))*10'd40;
          z_words_r<=command_param_i==0?72:80;ctilde_words_r<=command_param_i==0?4:command_param_i==1?6:8;
          word_r<=0;poly_r<=0;field_word_r<=0;signature_r<=0;hash_words_r<=0;digest_beats_r<=0;
          raw_sent_r<=0;load_sent_r<=0;hash_active_r<=0;hash_finished_r<=0;load_active_r<=0;load_finished_r<=0;
          hint_active_r<=0;hint_finished_r<=0;hint_words_sent_r<=0;hint_word_r<=0;bank_started_r<=0;bank_finished_r<=0;
          rho_o<=0;tr_o<=0;ctilde_o<=0;done_code_o<=0;state<=HASH_CMD;
          if(command_param_i==3)begin done_code_o<=1;state<=REPORT;end
          else if(command_signature_len_i!=(command_param_i==0?2420:command_param_i==1?3309:4627))begin done_code_o<=2;state<=REPORT;end
        end
        HASH_CMD:if(service_i.raw.ready)state<=PK_HEADER;
        PK_HEADER:if(host_fire)begin
          if(!bad_frame)rho_o[64*word_r[1:0]+:64]<=input_data_i;
          if(word_r==3)state<=PK_LOAD_CMD;
        end
        PK_LOAD_CMD:if(service_i.load.ready)state<=PK_DATA;
        PK_DATA:if(host_fire)begin
          field_word_r<=field_word_r+1'b1;
          if(field_word_r==39)state<=PK_WAIT;
        end
        PK_WAIT:if(load_finished_r)begin
          if(poly_r+1'b1==k_r)begin signature_r<=1;poly_r<=0;word_r<=0;state<=SIG_HEADER;end
          else begin poly_r<=poly_r+1'b1;state<=PK_LOAD_CMD;end
        end
        SIG_HEADER:if(host_fire)begin
          if(!bad_frame)ctilde_o[64*word_r[2:0]+:64]<=input_data_i;
          if(word_r+1'b1==16'(ctilde_words_r))state<=Z_LOAD_CMD;
        end
        Z_LOAD_CMD:if(service_i.load.ready)state<=Z_DATA;
        Z_DATA:if(host_fire)begin field_word_r<=field_word_r+1'b1;if(field_word_r+1'b1==z_words_r)state<=Z_WAIT;end
        Z_WAIT:if(load_finished_r)state<=NORM_CMD;
        NORM_CMD:if(service_i.poly_process.ready)state<=NORM_RUN;
        NORM_RUN:if(service_i.poly_process.done_valid)begin
          if(service_i.poly_process.reject)begin done_code_o<=2;state<=DRAIN;end
          else if(poly_r+1'b1==l_r)state<=HINT_CMD;
          else begin poly_r<=poly_r+1'b1;state<=Z_LOAD_CMD;end
        end
        HINT_CMD:if(hint_ready)state<=HINT_RUN;
        HINT_RUN:begin
          if(host_fire)hint_word_r<=hint_word_r+1'b1;
          if(hint_done)begin
            done_code_o<=hint_code==2?3'd2:hint_code==0?3'd0:3'd3;state<=DRAIN;
          end
        end
        DRAIN:if(hash_finished_r && !load_active_r && !hint_active_r && hint_ready &&
          (!bank_started_r || bank_finished_r) && service_i.idle)state<=REPORT;
        REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:begin fault_o<=1;state<=HALT;end
      endcase
      // Transport errors discard the entire context,then drain finite requests.
      // A decoder may finish before the raw-hash fork accepts that host word.
      if((host_fire && bad_frame) || (service_o.load.done_ready && service_i.load.done_valid && service_i.load.done_code!=0))begin
        done_code_o<=3;state<=DRAIN;
      end
      if(state!=IDLE && state!=REPORT && (
        service_i.sample.fault ||
        (service_o.raw.output_ready && service_i.raw.output_valid &&
          (service_i.raw.output_id!=hash_id || service_i.raw.output_core!=raw_core_r || service_i.raw.output_bytes!=16)) ||
        (service_o.raw.done_ready && service_i.raw.done_valid && (service_i.raw.done_id!=hash_id || service_i.raw.done_core!=raw_core_r)) ||
        (service_o.load.done_ready && service_i.load.done_valid && service_i.load.done_id!=load_id) ||
        (state==NORM_RUN && service_i.poly_process.done_valid && service_i.poly_process.done_code!=0) ||
        (hint_done && (state==HINT_RUN || state==DRAIN) && hint_done_id!=id_r+16'd128) ||
        (hint_valid && hint_output_ready && (hint_id!=id_r+16'd128 || hint_row!=hint_words_sent_r[8:6] ||
          hint_word!=hint_words_sent_r[5:0] || hint_last!=(hint_word==63))) ||
        (service_o.bank.done_ready[1][1] && service_i.bank.done_valid[1][1] && service_i.bank.done_error[1][1])))begin
        fault_o<=1;state<=HALT;
      end
    end
  end
endmodule
`default_nettype wire
