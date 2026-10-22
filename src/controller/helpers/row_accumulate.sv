// One staged matrix row: sum_j(A_hat[j]*s_hat[j]),then inverse NTT.
// Source arrays are descriptors only. No matrix/polynomial payload RAM here.
`default_nettype none
module row_accumulate (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,busy_o,fault_o,
  input wire logic [1:0] command_param_i,input wire logic [3:0] command_row_i,
  input wire logic [15:0] command_id_i,
  input wire logic [5:0] command_acc_i,command_scratch_i,command_result_i,
  input wire logic [6:0][5:0] command_a_i,command_s_i,
  input wire logic [6:0][15:0] command_a_id_i,command_s_id_i,
  input wire logic [63:0] reserved_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic [5:0] done_region_o,output logic [2:0] completed_terms_o,
  output logic [63:0] locks_o,hidden_o,
  output logic read_valid_o,output logic [5:0] read_region_o,
  input wire logic read_ready_i,response_valid_i,response_error_i,
  input wire logic [5:0] response_region_i,response_word_i,
  input wire logic [15:0] response_id_i,input wire logic [1:0] response_param_i,
  input wire logic response_domain_i,output logic response_ready_o,
  output logic ntt_valid_o,input wire logic ntt_ready_i,
  output logic [1:0] ntt_op_o,output logic [5:0] ntt_a_o,ntt_b_o,ntt_dest_o,
  output logic [15:0] ntt_a_id_o,ntt_b_id_o,ntt_id_o,
  input wire logic ntt_done_valid_i,output logic ntt_done_ready_o,
  input wire logic [2:0] ntt_done_code_i,input wire logic [15:0] ntt_done_id_i,
  input wire logic [5:0] ntt_done_region_i,
  output logic process_valid_o,input wire logic process_ready_i,
  output logic [5:0] process_a_o,process_b_o,
  output logic [15:0] process_a_id_o,process_b_id_o,process_id_o,
  input wire logic process_done_valid_i,output logic process_done_ready_o,
  input wire logic [2:0] process_done_code_i,input wire logic [15:0] process_done_id_i,
  input wire logic [5:0] process_done_region_i,
  output logic release_valid_o,output logic [5:0] release_region_o,input wire logic release_ready_i
);
  typedef enum logic [3:0] {IDLE,CHECK_REQ,CHECK_RESP,PWM_REQ,PWM_REPLY,ADD_REQ,ADD_REPLY,
    FREE_SCRATCH,INVERSE_REQ,INVERSE_REPLY,FREE_ACC,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] param_r;logic [2:0] column_r,columns_r;
  logic [15:0] id_r,acc_id_r;
  logic [5:0] acc_r,scratch_r,result_r;
  logic [6:0][5:0] a_r,s_r;logic [6:0][15:0] aid_r,sid_r;
  logic [2:0] code_r;logic check_secret_r,owned_r;
  logic [2:0] command_columns;logic [3:0] command_rows;
  logic alias_bad,busy_bad;
  always_comb begin
    command_columns=command_param_i==0?3'd4:(command_param_i==1?3'd5:3'd7);
    command_rows=command_param_i==0?4'd4:(command_param_i==1?4'd6:4'd8);
    alias_bad=command_acc_i==command_scratch_i || command_acc_i==command_result_i || command_scratch_i==command_result_i;
    busy_bad=reserved_i[command_acc_i] || reserved_i[command_scratch_i] || reserved_i[command_result_i];
    for(int j=0;j<7;j++)if(j<int'(command_columns))begin
      if(command_a_i[j]==command_acc_i || command_a_i[j]==command_scratch_i || command_a_i[j]==command_result_i ||
         command_s_i[j]==command_acc_i || command_s_i[j]==command_scratch_i || command_s_i[j]==command_result_i)alias_bad=1;
    end
    locks_o=0;hidden_o=0;
    if(busy_o && owned_r)begin
      locks_o[acc_r]=1;locks_o[scratch_r]=1;locks_o[result_r]=1;
      hidden_o[acc_r]=1;hidden_o[scratch_r]=1;
      if(state!=REPORT)hidden_o[result_r]=1;
      for(int j=0;j<7;j++)if(j<int'(columns_r))begin locks_o[a_r[j]]=1;locks_o[s_r[j]]=1;end
    end
  end
  assign command_ready_o=!rst && state==IDLE && !fault_o;
  assign busy_o=state!=IDLE;
  assign done_valid_o=!rst && state==REPORT && !fault_o;
  assign done_code_o=code_r;assign done_id_o=id_r;assign done_region_o=result_r;
  assign read_valid_o=!rst && state==CHECK_REQ;
  assign read_region_o=check_secret_r?s_r[column_r]:a_r[column_r];
  assign response_ready_o=state==CHECK_RESP;
  assign ntt_valid_o=!rst && (state==PWM_REQ || state==INVERSE_REQ);
  assign ntt_op_o=state==INVERSE_REQ?2'd1:2'd2;
  assign ntt_a_o=state==INVERSE_REQ?acc_r:a_r[column_r];
  assign ntt_b_o=state==INVERSE_REQ?acc_r:s_r[column_r];
  assign ntt_a_id_o=state==INVERSE_REQ?acc_id_r:aid_r[column_r];
  assign ntt_b_id_o=state==INVERSE_REQ?acc_id_r:sid_r[column_r];
  assign ntt_dest_o=state==INVERSE_REQ?result_r:(column_r==0?acc_r:scratch_r);
  assign ntt_id_o=state==INVERSE_REQ?id_r:(column_r==0?id_r+16'd1:id_r+16'd2+16'(column_r)*16'd2);
  assign ntt_done_ready_o=state==PWM_REPLY || state==INVERSE_REPLY;
  assign process_valid_o=!rst && state==ADD_REQ;
  assign process_a_o=acc_r;assign process_b_o=scratch_r;
  assign process_a_id_o=acc_id_r;assign process_b_id_o=id_r+16'd2+16'(column_r)*16'd2;
  assign process_id_o=id_r+16'd3+16'(column_r)*16'd2;
  assign process_done_ready_o=state==ADD_REPLY;
  assign release_valid_o=!rst && (state==FREE_SCRATCH || state==FREE_ACC);
  assign release_region_o=state==FREE_SCRATCH?scratch_r:acc_r;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;param_r<=0;column_r<=0;columns_r<=0;id_r<=0;acc_id_r<=0;
      acc_r<=0;scratch_r<=0;result_r<=0;a_r<=0;s_r<=0;aid_r<=0;sid_r<=0;
      code_r<=0;check_secret_r<=0;owned_r<=0;completed_terms_o<=0;fault_o<=0;
    end else begin
      case(state)
        IDLE:if(command_valid_i && command_ready_o)begin
          param_r<=command_param_i;columns_r<=command_columns;column_r<=0;completed_terms_o<=0;
          id_r<=command_id_i;acc_r<=command_acc_i;scratch_r<=command_scratch_i;result_r<=command_result_i;
          a_r<=command_a_i;s_r<=command_s_i;aid_r<=command_a_id_i;sid_r<=command_s_id_i;
          code_r<=0;owned_r<=0;check_secret_r<=0;
          if(command_param_i==3 || command_row_i>=command_rows)begin code_r<=4;state<=REPORT;end
          else if(alias_bad || busy_bad)begin code_r<=3;state<=REPORT;end
          else begin owned_r<=1;state<=CHECK_REQ;end
        end
        CHECK_REQ:if(read_ready_i)state<=CHECK_RESP;
        CHECK_RESP:if(response_valid_i)begin
          if(response_error_i || response_region_i!=read_region_o || response_word_i!=0 ||
             response_id_i!=(check_secret_r?sid_r[column_r]:aid_r[column_r]))begin code_r<=1;state<=REPORT;end
          else if(!response_domain_i || response_param_i!=param_r)begin code_r<=2;state<=REPORT;end
          else if(!check_secret_r)begin check_secret_r<=1;state<=CHECK_REQ;end
          else if(column_r==columns_r-1'b1)begin column_r<=0;state<=PWM_REQ;end
          else begin column_r<=column_r+3'd1;check_secret_r<=0;state<=CHECK_REQ;end
        end
        PWM_REQ:if(ntt_ready_i)state<=PWM_REPLY;
        PWM_REPLY:if(ntt_done_valid_i)begin
          if(ntt_done_code_i!=0 || ntt_done_id_i!=ntt_id_o || ntt_done_region_i!=ntt_dest_o)begin fault_o<=1;state<=HALT;end
          else if(column_r==0)begin
            acc_id_r<=ntt_id_o;completed_terms_o<=1;column_r<=1;state<=PWM_REQ;
          end else state<=ADD_REQ;
        end
        ADD_REQ:if(process_ready_i)state<=ADD_REPLY;
        ADD_REPLY:if(process_done_valid_i)begin
          if(process_done_code_i!=0 || process_done_id_i!=process_id_o || process_done_region_i!=acc_r)begin fault_o<=1;state<=HALT;end
          else begin acc_id_r<=process_id_o;completed_terms_o<=completed_terms_o+3'd1;state<=FREE_SCRATCH;end
        end
        FREE_SCRATCH:if(release_ready_i)begin
          if(column_r==columns_r-1'b1)state<=INVERSE_REQ;
          else begin column_r<=column_r+3'd1;state<=PWM_REQ;end
        end
        INVERSE_REQ:if(ntt_ready_i)state<=INVERSE_REPLY;
        INVERSE_REPLY:if(ntt_done_valid_i)begin
          if(ntt_done_code_i!=0 || ntt_done_id_i!=id_r || ntt_done_region_i!=result_r)begin fault_o<=1;state<=HALT;end
          else state<=FREE_ACC;
        end
        FREE_ACC:if(release_ready_i)state<=REPORT;
        REPORT:if(done_ready_i)begin state<=IDLE;owned_r<=0;end
        HALT:state<=HALT;
        default:begin fault_o<=1;state<=HALT;end
      endcase
    end
  end
endmodule
`default_nettype wire
