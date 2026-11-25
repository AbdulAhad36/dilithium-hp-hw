// Shared Process decode client for SK,PK and z/w1 fields. It reuses the SAME
// sampler writer/regrouper through an exclusive manual packet route. Invalid
// fields remain tentative:zero-fill only the bounded remaining polynomial,
// retire the physical write,then return the original decode error to owner.
`default_nettype none
module load_decode #(parameter bit PIPELINE_FRAME=0) (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [2:0] command_op_i,input wire logic [1:0] command_param_i,command_bank_i,
  input wire logic [9:0] command_base_i,input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [63:0] input_data_i,input wire logic [6:0] input_index_i,
  input wire logic [3:0] input_bytes_i,input wire logic input_last_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,output logic fault_o,
  output logic writer_job_valid_o,input wire logic writer_job_ready_i,
  output logic writer_job_core_o,writer_job_batch_last_o,
  output logic [1:0] writer_job_mode_o,writer_job_bank_o,
  output logic [9:0] writer_job_base_o,output logic [15:0] writer_job_id_o,
  output logic packet_valid_o,input wire logic packet_ready_i,
  output logic packet_core_o,packet_last_o,output logic [15:0] packet_id_o,
  output logic [7:0] packet_index_o,output logic [4:0] packet_count_o,output logic [91:0] packet_data_o,
  output logic status_valid_o,input wire logic status_ready_i,
  output logic status_core_o,output logic [15:0] status_id_o,output logic [2:0] status_code_o,
  input wire logic writer_done_valid_i,writer_done_core_i,input wire logic [15:0] writer_done_id_i,
  input wire logic [2:0] writer_done_code_i,output logic writer_done_ready_o
);
  typedef enum logic [2:0] {IDLE,WRITER_START,DECODE_START,FEED,ZERO_FILL,WRITER_WAIT,REPORT,HALT} state_e;
  state_e state;
  logic [2:0] op_r,code_r;logic [1:0] level_r,bank_r;logic [9:0] base_r;
  logic [15:0] id_r;logic [8:0] committed_r;
  logic unpack_command_ready,unpack_input_ready,unpack_valid,unpack_ready,unpack_last,unpack_done;
  logic [91:0] unpack_data;logic [4:0] unpack_count;logic [7:0] unpack_index;
  logic [15:0] unpack_id,unpack_done_id;logic [2:0] unpack_code;
  typedef struct packed {
    logic [63:0] data;
    logic [6:0] index;
    logic [3:0] bytes;
    logic last;
  } frame_word_t;
  frame_word_t unpack_word;
  logic unpack_word_valid;
  // Two decoded words decouple value validation from the bank writer's ready
  // path. The polynomial remains in the physical banks;only this handoff is
  // buffered. IDs/count/index/last are checked BEFORE a word is admitted.
  logic [91:0] packet0_r,packet1_r;
  logic packet_read_r,packet_write_r,packet_push,packet_pop,unpack_metadata_ok;
  logic [1:0] packet_count_r;
  logic [8:0] decoded_r;
  assign command_ready_o=!rst && state==IDLE && !fault_o;
  generate if(PIPELINE_FRAME)begin:g_frame_queue
    frame_word_t head_r,tail_r;
    logic [1:0] count_r;
    logic last_queued_r,push_word,pop_word;
    frame_word_t offered;
    assign offered={input_data_i,input_index_i,input_bytes_i,input_last_i};
    assign input_ready_o=!rst && state==FEED && !fault_o && !unpack_done &&
      !last_queued_r && count_r<2;
    assign unpack_word_valid=!rst && state==FEED && !fault_o && count_r!=0;
    assign unpack_word=head_r;
    assign push_word=input_valid_i && input_ready_o;
    assign pop_word=unpack_word_valid && unpack_input_ready;

    // The fixed head feeds the unpacker without another payload mux. One
    // queued tail allows a new acceptance while the unpacker stalls.
    always_ff @(posedge clk)begin
      if(pop_word && count_r==2)head_r<=tail_r;
      else if(push_word && (count_r==0 || pop_word))head_r<=offered;
      if(push_word && count_r==1 && !pop_word)tail_r<=offered;
    end
    always_ff @(posedge clk or posedge rst)begin
      if(rst)begin count_r<=0;last_queued_r<=0;end
      else if(state!=FEED || unpack_done || fault_o)begin
        count_r<=0;last_queued_r<=0;
      end else begin
        case({push_word,pop_word})
          2'b10:count_r<=count_r+1'b1;
          2'b01:count_r<=count_r-1'b1;
          default:begin end
        endcase
        if(push_word && input_last_i)last_queued_r<=1;
      end
    end
  end else begin:g_direct_frame
    assign input_ready_o=state==FEED && !fault_o && unpack_input_ready;
    assign unpack_word_valid=input_valid_i && state==FEED && !fault_o;
    assign unpack_word={input_data_i,input_index_i,input_bytes_i,input_last_i};
  end endgenerate
  assign done_valid_o=!rst && !fault_o && (state==REPORT || (state==WRITER_WAIT && writer_done_valid_i));
  assign done_id_o=id_r;assign done_code_o=code_r;
  assign writer_job_valid_o=!rst && state==WRITER_START && !fault_o;
  assign writer_job_core_o=0;assign writer_job_batch_last_o=1;
  assign writer_job_mode_o=op_r==2?1:0;assign writer_job_bank_o=bank_r;
  assign writer_job_base_o=base_r;assign writer_job_id_o=id_r;
  assign packet_valid_o=!rst && !fault_o && ((state==FEED && packet_count_r!=0) || (state==ZERO_FILL && committed_r<256));
  assign packet_data_o=state==ZERO_FILL?92'd0:packet_read_r?packet1_r:packet0_r;
  assign packet_count_o=op_r==2?16:4;assign packet_index_o=committed_r[7:0];
  assign packet_id_o=id_r;assign packet_core_o=0;
  assign packet_last_o=committed_r+9'(packet_count_o)==256;
  assign unpack_ready=state==FEED && packet_count_r<2 && !fault_o;
  assign unpack_metadata_ok=unpack_id==id_r && unpack_index==decoded_r[7:0] &&
    unpack_count==packet_count_o && unpack_last==(decoded_r+9'(packet_count_o)==256);
  assign packet_push=unpack_valid && unpack_ready && unpack_metadata_ok;
  assign packet_pop=state==FEED && packet_valid_o && packet_ready_i;
  assign status_valid_o=!rst && state==WRITER_WAIT && !fault_o;
  assign status_id_o=id_r;assign status_core_o=0;assign status_code_o=0;
  assign writer_done_ready_o=state==WRITER_WAIT && done_ready_i && !fault_o;
  bitunpkg unpacker(
    .clk(clk),.rst(rst),.command_valid_i(state==DECODE_START),.command_ready_o(unpack_command_ready),
    .command_op_i(op_r),.command_param_i(level_r),.command_id_i(id_r),
    .input_valid_i(unpack_word_valid),.input_ready_o(unpack_input_ready),
    .input_data_i(unpack_word.data),.input_index_i(unpack_word.index),.input_bytes_i(unpack_word.bytes),.input_last_i(unpack_word.last),
    .output_valid_o(unpack_valid),.output_ready_i(unpack_ready),.output_data_o(unpack_data),.output_count_o(unpack_count),
    .output_index_o(unpack_index),.output_last_o(unpack_last),.output_id_o(unpack_id),
    .done_valid_o(unpack_done),.done_ready_i(state==FEED && packet_count_r==0),.done_code_o(unpack_code),.done_id_o(unpack_done_id));
  // No reset on payload;reset/new-command invalidates queue ownership.
  always @(posedge clk)if(packet_push)begin
    if(packet_write_r)packet1_r<=unpack_data;else packet0_r<=unpack_data;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=0;code_r<=0;level_r<=0;bank_r<=0;base_r<=0;id_r<=0;committed_r<=0;fault_o<=0;
      packet_read_r<=0;packet_write_r<=0;packet_count_r<=0;decoded_r<=0;
    end
    else begin
      case({packet_push,packet_pop})
        2'b10:packet_count_r<=packet_count_r+1'b1;
        2'b01:packet_count_r<=packet_count_r-1'b1;
        default:begin end
      endcase
      if(packet_push)begin packet_write_r<=!packet_write_r;decoded_r<=decoded_r+9'(packet_count_o);end
      if(packet_pop)packet_read_r<=!packet_read_r;
      if(packet_valid_o && packet_ready_i)committed_r<=committed_r+9'(packet_count_o);
      case(state)
        IDLE:if(command_valid_i)begin
          op_r<=command_op_i;level_r<=command_param_i;bank_r<=command_bank_i;base_r<=command_base_i;id_r<=command_id_i;
          packet_read_r<=0;packet_write_r<=0;packet_count_r<=0;decoded_r<=0;
          committed_r<=0;code_r<=command_param_i==3 || command_op_i>5 || command_base_i[5:0]!=0?1:0;
          state<=command_param_i==3 || command_op_i>5 || command_base_i[5:0]!=0?REPORT:WRITER_START;
        end
        WRITER_START:if(writer_job_ready_i)state<=DECODE_START;
        DECODE_START:if(unpack_command_ready)state<=FEED;
        // Decode REPORT may arrive while valid words are still queued. Drain
        // those words before success or bounded zero-fill/error retirement.
        FEED:if(unpack_done && packet_count_r==0)begin
          code_r<=unpack_code;
          if(unpack_done_id!=id_r || (unpack_code==0 && committed_r!=256))begin fault_o<=1;state<=HALT;end
          else state<=committed_r==256?WRITER_WAIT:ZERO_FILL;
        end
        ZERO_FILL:if(packet_valid_o && packet_ready_i && packet_last_o)state<=WRITER_WAIT;
        WRITER_WAIT:if(writer_done_valid_i)begin
          if(writer_done_core_i || writer_done_id_i!=id_r || writer_done_code_i!=0)begin fault_o<=1;state<=HALT;end
          else if(done_ready_i)state<=IDLE;
        end
        REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:state<=IDLE;
      endcase
      // A metadata fault wins over an otherwise simultaneous normal transition.
      if(state==FEED && unpack_valid && unpack_ready &&
        !unpack_metadata_ok)begin
        fault_o<=1;state<=HALT;
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst && state==FEED && !fault_o)begin
    if(packet_count_r>2 || decoded_r-committed_r!=9'(packet_count_r)*9'(packet_count_o))
      $fatal(1,"Decoded packet ownership/count mismatch");
  end
`endif
endmodule
`default_nettype wire
