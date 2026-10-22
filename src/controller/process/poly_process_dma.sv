// Sequential bank client. Only two cached words, never a polynomial payload RAM.
// P2R stores low modulo q and zero-extended high in separate canonical regions.
`default_nettype none
module poly_process_dma (
  input wire logic clk,rst,command_valid_i,
  output logic command_ready_o,busy_o,fault_o,
  input wire logic [1:0] command_op_i,
  input wire logic command_inplace_i,
  input wire logic [5:0] command_a_i,command_b_i,command_dest_i,command_high_i,
  input wire logic [15:0] command_a_id_i,command_b_id_i,command_id_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic [5:0] done_dest_o,done_high_o,
  input wire logic [63:0] reserved_i,
  output logic [63:0] release_locks_o,hidden_o,
  output logic alloc_valid_o,alloc_core_o,
  output logic [5:0] alloc_region_o,
  output logic [15:0] alloc_id_o,
  output logic [1:0] alloc_mode_o,alloc_param_o,
  output logic alloc_domain_o,alloc_rewrite_o,input wire logic alloc_ready_i,
  output logic read_valid_o,output logic [5:0] read_region_o,read_word_o,
  input wire logic read_ready_i,response_valid_i,response_error_i,
  input wire logic [5:0] response_region_i,response_word_i,
  input wire logic [91:0] response_data_i,
  input wire logic [15:0] response_id_i,
  input wire logic [1:0] response_mode_i,response_param_i,
  input wire logic response_domain_i,
  output logic response_ready_o,
  output logic write_valid_o,write_core_o,write_last_o,
  output logic [15:0] write_id_o,output logic [7:0] write_index_o,
  output logic [22:0] write_data_o,input wire logic write_ready_i,
  output logic finish_valid_o,finish_core_o,
  output logic [15:0] finish_id_o,input wire logic finish_ready_i
);
  typedef enum logic [3:0] {IDLE,CHECK_REQ,CHECK_RESP,WAIT_FREE,ALLOC_LOW,ALLOC_HIGH,
    READ_REQ,READ_RESP,FEED,WRITE_LOW,WRITE_HIGH,COMMIT_LOW,COMMIT_HIGH,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] op_r,mode_r,param_r,lane_r;
  logic [5:0] a_r,b_r,dest_r,high_r,word_r,source;
  logic [15:0] aid_r,bid_r,id_r;
  logic [2:0] code_r;
  logic domain_r,operand_b_r,low_owned_r,high_owned_r,inplace_r;
  logic [91:0] a_word_r,b_word_r;
  logic pp_ready,pp_valid,pp_accept,pp_error,pp_last;
  logic [1:0] pp_op;logic [15:0] pp_id;logic [7:0] pp_index;
  logic [22:0] pp_residue;logic [9:0] pp_high;logic signed [13:0] pp_low;
  logic [12:0] pp_t0;
  logic [7:0] index;
  logic source_bad,domain_bad,output_bad;
  assign index={word_r,lane_r};assign source=operand_b_r?b_r:a_r;
  assign command_ready_o=!rst && state==IDLE && !fault_o;
  assign busy_o=state!=IDLE;
  assign done_valid_o=!rst && state==REPORT && !fault_o;
  assign done_code_o=code_r;assign done_id_o=id_r;
  assign done_dest_o=dest_r;assign done_high_o=high_r;
  always_comb begin
    release_locks_o=0;hidden_o=0;
    if(busy_o)begin
      release_locks_o[a_r]=1;hidden_o[a_r]=1;
      if(op_r<2)begin release_locks_o[b_r]=1;hidden_o[b_r]=1;end
      if(low_owned_r)begin release_locks_o[dest_r]=1;if(state!=REPORT)hidden_o[dest_r]=1;end
      if(high_owned_r)begin release_locks_o[high_r]=1;if(state!=REPORT)hidden_o[high_r]=1;end
    end
  end
  assign alloc_valid_o=!rst && !fault_o && (state==ALLOC_LOW || state==ALLOC_HIGH);
  assign alloc_core_o=state==ALLOC_HIGH;
  assign alloc_region_o=alloc_core_o?high_r:dest_r;
  assign alloc_id_o=id_r;assign alloc_mode_o=mode_r;assign alloc_param_o=param_r;
  assign alloc_domain_o=op_r==2?1'b0:domain_r;
  assign alloc_rewrite_o=inplace_r && state==ALLOC_LOW;
  assign read_valid_o=!rst && !fault_o && (state==CHECK_REQ || state==READ_REQ);
  assign read_region_o=source;assign read_word_o=state==CHECK_REQ?6'd0:word_r;
  assign response_ready_o=!rst && !fault_o && (state==CHECK_RESP || state==READ_RESP);
  assign source_bad=response_error_i || response_region_i!=source ||
    response_id_i!=((state!=CHECK_RESP && inplace_r && source==dest_r)?id_r:(operand_b_r?bid_r:aid_r)) ||
    response_word_i!=(state==CHECK_RESP?6'd0:word_r);
  assign domain_bad=operand_b_r ? (response_domain_i!=domain_r || response_param_i!=param_r) :
    (op_r==2 && response_domain_i);
  assign write_valid_o=!rst && !fault_o && pp_valid && !output_bad && (state==WRITE_LOW || state==WRITE_HIGH);
  assign write_core_o=state==WRITE_HIGH;assign write_id_o=id_r;
  assign write_index_o=pp_index;assign write_last_o=pp_last;
  assign write_data_o=state==WRITE_HIGH?{13'd0,pp_high}:
    (op_r!=2?pp_residue:(pp_low<0?23'(24'sd8380417+$signed(pp_low)):23'(pp_low)));
  assign pp_accept=write_valid_o && write_ready_i && (op_r!=2 || state==WRITE_HIGH);
  assign output_bad=pp_error || pp_op!=op_r || pp_id!=id_r || pp_index!=index || pp_last!=(index==255);
  assign finish_valid_o=!rst && !fault_o && (state==COMMIT_LOW || state==COMMIT_HIGH);
  assign finish_core_o=state==COMMIT_HIGH;assign finish_id_o=id_r;
  poly_process arithmetic(
    .clk(clk),.rst(rst),.input_valid_i(state==FEED && !fault_o),.input_ready_o(pp_ready),.input_op_i(op_r),
    .input_a_i(a_word_r[23*lane_r+:23]),.input_b_i(b_word_r[23*lane_r+:23]),
    .input_id_i(id_r),.input_index_i(index),.input_last_i(index==255),
    .output_valid_o(pp_valid),.output_ready_i(pp_accept),.output_error_o(pp_error),.output_op_o(pp_op),
    .output_residue_o(pp_residue),.output_high_o(pp_high),.output_low_o(pp_low),.output_t0_o(pp_t0),
    .output_id_o(pp_id),.output_index_o(pp_index),.output_last_o(pp_last)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=0;mode_r<=0;param_r<=0;lane_r<=0;word_r<=0;
      a_r<=0;b_r<=0;dest_r<=0;high_r<=0;aid_r<=0;bid_r<=0;id_r<=0;code_r<=0;
      domain_r<=0;operand_b_r<=0;low_owned_r<=0;high_owned_r<=0;inplace_r<=0;a_word_r<=0;b_word_r<=0;fault_o<=0;
    end else begin
      case(state)
        IDLE:if(command_valid_i && command_ready_o)begin
          op_r<=command_op_i;a_r<=command_a_i;b_r<=command_b_i;dest_r<=command_dest_i;high_r<=command_high_i;
          aid_r<=command_a_id_i;bid_r<=command_b_id_i;id_r<=command_id_i;
          operand_b_r<=0;low_owned_r<=0;high_owned_r<=0;code_r<=0;
          inplace_r<=command_inplace_i;
          if(command_op_i==3)begin code_r<=4;state<=REPORT;end
          else if((command_inplace_i && (command_op_i>=2 || command_dest_i!=command_a_i)) ||
            (!command_inplace_i && (command_dest_i==command_a_i || (command_op_i<2 && command_dest_i==command_b_i))) ||
            (command_op_i==2 && (command_high_i==command_a_i || command_high_i==command_dest_i)))begin
            code_r<=3;state<=REPORT;
          end else state<=CHECK_REQ;
        end
        CHECK_REQ:if(read_ready_i)state<=CHECK_RESP;
        CHECK_RESP:if(response_valid_i)begin
          if(source_bad)begin code_r<=1;state<=REPORT;end
          else if(domain_bad)begin code_r<=2;state<=REPORT;end
          else if(op_r<2 && !operand_b_r)begin
            mode_r<=response_mode_i;param_r<=response_param_i;domain_r<=response_domain_i;
            operand_b_r<=1;state<=CHECK_REQ;
          end else begin
            if(!operand_b_r)begin mode_r<=response_mode_i;param_r<=response_param_i;domain_r<=response_domain_i;end
            operand_b_r<=0;state<=WAIT_FREE;
          end
        end
        WAIT_FREE:if((inplace_r || !reserved_i[dest_r]) && (op_r!=2 || !reserved_i[high_r]))state<=ALLOC_LOW;
        ALLOC_LOW:if(alloc_ready_i)begin
          low_owned_r<=1;word_r<=0;lane_r<=0;
          state<=op_r==2?ALLOC_HIGH:READ_REQ;
        end
        ALLOC_HIGH:if(alloc_ready_i)begin high_owned_r<=1;state<=READ_REQ;end
        READ_REQ:if(read_ready_i)state<=READ_RESP;
        READ_RESP:if(response_valid_i)begin
          if(source_bad || response_domain_i!=domain_r || response_param_i!=param_r)begin fault_o<=1;state<=HALT;end
          else if(op_r<2 && !operand_b_r)begin a_word_r<=response_data_i;operand_b_r<=1;state<=READ_REQ;end
          else begin
            if(operand_b_r)b_word_r<=response_data_i;else a_word_r<=response_data_i;
            operand_b_r<=0;state<=FEED;
          end
        end
        FEED:if(pp_ready)state<=WRITE_LOW;
        WRITE_LOW:if(write_valid_o && write_ready_i)begin
          if(op_r==2)state<=WRITE_HIGH;
          else if(index==255)state<=COMMIT_LOW;
          else if(lane_r==3)begin lane_r<=0;word_r<=word_r+6'd1;state<=READ_REQ;end
          else begin lane_r<=lane_r+2'd1;state<=FEED;end
        end
        WRITE_HIGH:if(write_valid_o && write_ready_i)begin
          if(index==255)state<=COMMIT_LOW;
          else if(lane_r==3)begin lane_r<=0;word_r<=word_r+6'd1;state<=READ_REQ;end
          else begin lane_r<=lane_r+2'd1;state<=FEED;end
        end
        COMMIT_LOW:if(finish_ready_i)state<=op_r==2?COMMIT_HIGH:REPORT;
        COMMIT_HIGH:if(finish_ready_i)state<=REPORT;
        REPORT:if(done_ready_i)begin state<=IDLE;low_owned_r<=0;high_owned_r<=0;end
        HALT:state<=HALT;
        default:begin fault_o<=1;state<=HALT;end
      endcase
      if(pp_valid && (state==WRITE_LOW || state==WRITE_HIGH) && output_bad)begin fault_o<=1;state<=HALT;end
    end
  end
endmodule
`default_nettype wire
