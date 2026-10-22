// Sequential client of the existing four-bank memory interface. No poly RAM.
// op0 writes canonical low + high;op1 only reduces CNB;op2 writes 0/1 hints.
// Source/result leases last through done retirement. Rollback finishes discard
// tentative allocations;publication waits for BOTH successful finish ACKs.
`default_nettype none
module sign_process_dma (
  input wire logic clk,rst,command_valid_i,
  output logic command_ready_o,busy_o,fault_o,
  input wire logic [1:0] command_op_i,command_param_i,command_kind_i,
  input wire logic [5:0] command_a_i,command_b_i,command_dest_i,command_high_i,
  input wire logic [15:0] command_a_id_i,command_b_id_i,command_id_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic [5:0] done_dest_o,done_high_o,
  output logic done_reject_o,output logic [8:0] done_weight_o,
  input wire logic [63:0] reserved_i,
  output logic [63:0] release_locks_o,hidden_o,
  output logic alloc_valid_o,alloc_core_o,output logic [5:0] alloc_region_o,
  output logic [15:0] alloc_id_o,output logic [1:0] alloc_mode_o,alloc_param_o,
  output logic alloc_domain_o,alloc_rewrite_o,input wire logic alloc_ready_i,
  output logic read_valid_o,output logic [5:0] read_region_o,read_word_o,
  input wire logic read_ready_i,response_valid_i,response_error_i,
  input wire logic [5:0] response_region_i,response_word_i,
  input wire logic [91:0] response_data_i,input wire logic [15:0] response_id_i,
  input wire logic [1:0] response_mode_i,response_param_i,input wire logic response_domain_i,
  output logic response_ready_o,
  output logic write_valid_o,write_core_o,write_last_o,output logic [15:0] write_id_o,
  output logic [7:0] write_index_o,output logic [22:0] write_data_o,input wire logic write_ready_i,
  output logic finish_valid_o,finish_core_o,output logic [15:0] finish_id_o,
  output logic [2:0] finish_code_o,input wire logic finish_ready_i
);
  typedef enum logic [4:0] {IDLE,CHECK_REQ,CHECK_RESP,WAIT_FREE,ALLOC_LOW,ALLOC_HIGH,
    READ_REQ,READ_RESP,FEED,RESULT,WRITE_LOW,WRITE_HIGH,COMMIT_LOW,COMMIT_HIGH,
    ABORT_LOW,ABORT_HIGH,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] op_r,param_r,kind_r,mode_r,bmode_r,lane_r;
  logic [5:0] a_r,b_r,dest_r,high_r,word_r;
  logic [15:0] aid_r,bid_r,id_r;logic [2:0] code_r;
  logic operand_b_r,low_owned_r,high_owned_r,reject_r;logic [8:0] weight_r;
  logic [91:0] a_word_r,b_word_r;
  logic pp_ready,pp_valid,pp_accept,pp_error,pp_last,pp_reject;
  logic [1:0] pp_op,pp_param,pp_kind;logic [15:0] pp_id;logic [5:0] pp_index;
  logic [23:0] pp_high;logic [75:0] pp_low;logic [3:0] pp_hint,pp_lanes;logic [8:0] pp_weight;
  logic source_bad,metadata_bad,high_bad,output_bad,process_reset;
  assign command_ready_o=!rst && state==IDLE && !fault_o;
  assign busy_o=state!=IDLE;
  assign done_valid_o=!rst && state==REPORT && !fault_o;
  assign done_code_o=code_r;assign done_id_o=id_r;
  assign done_dest_o=dest_r;assign done_high_o=high_r;
  assign done_reject_o=reject_r;assign done_weight_o=weight_r;
  always_comb begin
    release_locks_o=0;hidden_o=0;
    if(busy_o)begin
      release_locks_o[a_r]=1;hidden_o[a_r]=1;
      if(op_r==2)begin release_locks_o[b_r]=1;hidden_o[b_r]=1;end
      if(low_owned_r)begin release_locks_o[dest_r]=1;if(state!=REPORT)hidden_o[dest_r]=1;end
      if(high_owned_r)begin release_locks_o[high_r]=1;if(state!=REPORT)hidden_o[high_r]=1;end
    end
  end
  assign alloc_valid_o=!rst && !fault_o && (state==ALLOC_LOW || state==ALLOC_HIGH);
  assign alloc_core_o=state==ALLOC_HIGH;assign alloc_region_o=alloc_core_o?high_r:dest_r;
  assign alloc_id_o=id_r;assign alloc_mode_o=mode_r;assign alloc_param_o=param_r;
  assign alloc_domain_o=0;assign alloc_rewrite_o=0;
  assign read_valid_o=!rst && !fault_o && (state==CHECK_REQ || state==READ_REQ);
  assign read_region_o=operand_b_r?b_r:a_r;assign read_word_o=state==CHECK_REQ?6'd0:word_r;
  assign response_ready_o=!rst && !fault_o && (state==CHECK_RESP || state==READ_RESP);
  assign source_bad=response_error_i || response_region_i!=read_region_o ||
    response_word_i!=read_word_o || response_id_i!=(operand_b_r?bid_r:aid_r);
  assign metadata_bad=response_domain_i || response_param_i!=param_r ||
    (state==READ_RESP && response_mode_i!=(operand_b_r?bmode_r:mode_r));
  always_comb begin
    high_bad=0;
    // Validate all23 bits BEFORE narrowing;64 must never silently become0.
    for(int k=0;k<4;k++)if(b_word_r[23*k+:23]>(param_r==0?23'd43:23'd15))high_bad=1;
  end
  assign output_bad=pp_op!=op_r || pp_param!=param_r || pp_kind!=kind_r ||
    pp_id!=id_r || pp_index!=word_r || pp_last!=(word_r==63);
  assign write_valid_o=!rst && !fault_o && pp_valid && !pp_error && !output_bad &&
    (state==WRITE_LOW || state==WRITE_HIGH);
  assign write_core_o=state==WRITE_HIGH;assign write_id_o=id_r;
  assign write_index_o={word_r,lane_r};assign write_last_o=write_index_o==255;
  always_comb begin
    write_data_o=0;
    if(state==WRITE_HIGH)write_data_o={17'd0,pp_high[6*lane_r+:6]};
    else if(op_r==2)write_data_o={22'd0,pp_hint[lane_r]};
    else if($signed(pp_low[19*lane_r+:19])<0)
      write_data_o=23'(24'sd8380417+$signed(pp_low[19*lane_r+:19]));
    else write_data_o=23'(pp_low[19*lane_r+:19]);
  end
  assign pp_accept=(state==RESULT && pp_valid && (op_r==1 || pp_error || output_bad)) ||
    (write_valid_o && write_ready_i && lane_r==3 && (op_r==2 || state==WRITE_HIGH));
  assign finish_valid_o=!rst && !fault_o && (state==COMMIT_LOW || state==COMMIT_HIGH ||
    (state==ABORT_LOW && low_owned_r) || (state==ABORT_HIGH && high_owned_r));
  assign finish_core_o=state==COMMIT_HIGH || state==ABORT_HIGH;
  assign finish_id_o=id_r;assign finish_code_o=(state==ABORT_LOW || state==ABORT_HIGH)?3'd1:3'd0;
  // A failed partial polynomial must not leave the arithmetic packet tracker
  // alive for the next command,including same-ID retries.
  assign process_reset=rst || state==IDLE || state==ABORT_LOW || state==ABORT_HIGH;
  sign_process arithmetic(
    .clk(clk),.rst(process_reset),.input_valid_i(state==FEED && !fault_o && !(op_r==2 && high_bad)),
    .input_ready_o(pp_ready),.input_op_i(op_r),.input_param_i(param_r),.input_kind_i(kind_r),
    .input_id_i(id_r),.input_index_i(word_r),.input_last_i(word_r==63),.input_data_i(a_word_r),
    .input_high_i({b_word_r[69+:6],b_word_r[46+:6],b_word_r[23+:6],b_word_r[0+:6]}),
    .output_valid_o(pp_valid),.output_ready_i(pp_accept),.output_error_o(pp_error),.output_op_o(pp_op),
    .output_param_o(pp_param),.output_kind_o(pp_kind),.output_id_o(pp_id),.output_index_o(pp_index),
    .output_last_o(pp_last),.output_high_o(pp_high),.output_low_o(pp_low),.output_hint_o(pp_hint),
    .output_lane_reject_o(pp_lanes),.output_reject_o(pp_reject),.output_weight_o(pp_weight)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=0;param_r<=0;kind_r<=0;mode_r<=0;bmode_r<=0;lane_r<=0;
      a_r<=0;b_r<=0;dest_r<=0;high_r<=0;word_r<=0;aid_r<=0;bid_r<=0;id_r<=0;code_r<=0;
      operand_b_r<=0;low_owned_r<=0;high_owned_r<=0;reject_r<=0;weight_r<=0;
      a_word_r<=0;b_word_r<=0;fault_o<=0;
    end else begin
      case(state)
        IDLE:if(command_valid_i && command_ready_o)begin
          op_r<=command_op_i;param_r<=command_param_i;kind_r<=command_kind_i;
          a_r<=command_a_i;b_r<=command_b_i;dest_r<=command_dest_i;high_r<=command_high_i;
          aid_r<=command_a_id_i;bid_r<=command_b_id_i;id_r<=command_id_i;
          code_r<=0;word_r<=0;lane_r<=0;operand_b_r<=0;low_owned_r<=0;high_owned_r<=0;reject_r<=0;weight_r<=0;
          if(command_op_i==3 || command_param_i==3 || (command_op_i==1 && command_kind_i==3))begin code_r<=4;state<=REPORT;end
          else if((command_op_i!=1 && command_dest_i==command_a_i) ||
            (command_op_i==2 && command_dest_i==command_b_i) ||
            (command_op_i==0 && (command_high_i==command_a_i || command_high_i==command_dest_i)))begin code_r<=3;state<=REPORT;end
          else state<=CHECK_REQ;
        end
        CHECK_REQ:if(read_ready_i)state<=CHECK_RESP;
        CHECK_RESP:if(response_valid_i)begin
          if(source_bad)begin code_r<=1;state<=REPORT;end
          else if(metadata_bad)begin code_r<=2;state<=REPORT;end
          else if(op_r==2 && !operand_b_r)begin mode_r<=response_mode_i;operand_b_r<=1;state<=CHECK_REQ;end
          else begin
            if(operand_b_r)bmode_r<=response_mode_i;else mode_r<=response_mode_i;
            operand_b_r<=0;state<=op_r==1?READ_REQ:WAIT_FREE;
          end
        end
        WAIT_FREE:if(!reserved_i[dest_r] && (op_r!=0 || !reserved_i[high_r]))state<=ALLOC_LOW;
        ALLOC_LOW:if(alloc_ready_i)begin low_owned_r<=1;state<=op_r==0?ALLOC_HIGH:READ_REQ;end
        ALLOC_HIGH:if(alloc_ready_i)begin high_owned_r<=1;state<=READ_REQ;end
        READ_REQ:if(read_ready_i)state<=READ_RESP;
        READ_RESP:if(response_valid_i)begin
          if(source_bad || metadata_bad)begin code_r<=source_bad?3'd1:3'd2;reject_r<=0;weight_r<=0;state<=ABORT_LOW;end
          else if(op_r==2 && !operand_b_r)begin a_word_r<=response_data_i;operand_b_r<=1;state<=READ_REQ;end
          else begin
            if(operand_b_r)b_word_r<=response_data_i;else a_word_r<=response_data_i;
            operand_b_r<=0;state<=FEED;
          end
        end
        FEED:if(op_r==2 && high_bad)begin code_r<=5;reject_r<=0;weight_r<=0;state<=ABORT_LOW;end
          else if(pp_ready)state<=RESULT;
        RESULT:if(pp_valid)begin
          if(output_bad)begin fault_o<=1;state<=HALT;end
          else if(pp_error)begin code_r<=5;reject_r<=0;weight_r<=0;state<=ABORT_LOW;end
          else begin
            reject_r<=pp_reject;weight_r<=pp_weight;lane_r<=0;
            if(op_r!=1)state<=WRITE_LOW;
            else if(word_r==63)state<=REPORT;
            else begin word_r<=word_r+1'b1;state<=READ_REQ;end
          end
        end
        WRITE_LOW:if(write_valid_o && write_ready_i)begin
          if(op_r==0)state<=WRITE_HIGH;
          else if(lane_r!=3)lane_r<=lane_r+1'b1;
          else if(word_r==63)state<=COMMIT_LOW;
          else begin word_r<=word_r+1'b1;state<=READ_REQ;end
        end
        WRITE_HIGH:if(write_valid_o && write_ready_i)begin
          if(lane_r!=3)begin lane_r<=lane_r+1'b1;state<=WRITE_LOW;end
          else if(word_r==63)state<=COMMIT_LOW;
          else begin word_r<=word_r+1'b1;state<=READ_REQ;end
        end
        COMMIT_LOW:if(finish_ready_i)state<=op_r==0?COMMIT_HIGH:REPORT;
        COMMIT_HIGH:if(finish_ready_i)state<=REPORT;
        ABORT_LOW:if(!low_owned_r || finish_ready_i)begin low_owned_r<=0;state<=ABORT_HIGH;end
        ABORT_HIGH:if(!high_owned_r || finish_ready_i)begin high_owned_r<=0;state<=REPORT;end
        REPORT:if(done_ready_i)begin state<=IDLE;low_owned_r<=0;high_owned_r<=0;end
        HALT:state<=HALT;
        default:begin fault_o<=1;state<=HALT;end
      endcase
    end
  end
endmodule
`default_nettype wire
