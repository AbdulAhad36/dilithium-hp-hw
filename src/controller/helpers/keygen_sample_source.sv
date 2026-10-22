// Seed-retaining command adapter, not the complete KeyGen scheduler.
// op0 expands xi; op1 samples A[row,column]; op2 samples secret[nonce].
// The caller selects free bank destinations and schedules NTT/row operations.
`default_nettype none
module keygen_sample_source (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [1:0] command_op_i,command_param_i,
  input wire logic [15:0] command_id_i,command_nonce_i,
  input wire logic [7:0] command_row_i,command_column_i,
  input wire logic [255:0] command_seed_i,input wire logic [5:0] command_region_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic seed_valid_o,output logic [1:0] seed_param_o,
  output logic [255:0] rho_o,key_o,output logic [511:0] rhoprime_o,
  output logic job_valid_o,input wire logic job_ready_i,job_core_i,
  output logic [1:0] job_bank_o,job_mode_o,job_param_o,
  output logic [3:0] job_region_o,output logic [15:0] job_id_o,message_len_o,
  output logic [63:0] input_data_o,output logic input_valid_o,input wire logic input_ready_i,
  input wire logic status_valid_i,status_core_i,input wire logic [15:0] status_id_i,
  input wire logic [2:0] status_code_i,output logic status_ready_o,
  output logic raw_valid_o,input wire logic raw_ready_i,raw_core_i,
  output logic raw_mode_o,output logic [15:0] raw_id_o,raw_message_len_o,raw_output_len_o,
  output logic [63:0] raw_input_data_o,output logic raw_input_valid_o,input wire logic raw_input_ready_i,
  input wire logic raw_output_valid_i,raw_output_core_i,input wire logic [15:0] raw_output_id_i,
  input wire logic [127:0] raw_output_data_i,input wire logic [4:0] raw_output_bytes_i,
  output logic raw_output_ready_o,input wire logic raw_done_valid_i,raw_done_core_i,
  input wire logic [15:0] raw_done_id_i,output logic raw_done_ready_o
);
  typedef enum logic [2:0] {IDLE,SEED_START,SEED_WAIT,FORMAT_START,SAMPLE_WAIT,REPORT} state_e;
  state_e state;
  logic [1:0] op_r,param_r;logic [15:0] nonce_r;
  logic [7:0] row_r,column_r;logic [255:0] xi_r;logic [5:0] region_r;
  logic seed_start_ready,seed_result_valid,seed_error;
  logic [1:0] seed_param;logic [15:0] seed_id;
  logic [255:0] seed_rho,seed_key;logic [511:0] seed_rhoprime;
  logic format_ready,format_done,format_error,request_valid,request_ready,request_mode;
  logic [15:0] format_id,unused_length;
  logic issued_r,core_r,message_done_r,status_done_r;
  assign command_ready_o=!rst && state==IDLE;
  assign done_valid_o=!rst && state==REPORT;
  assign job_valid_o=state==SAMPLE_WAIT && request_valid;
  assign request_ready=state==SAMPLE_WAIT && job_ready_i;
  assign job_bank_o=region_r[5:4];assign job_region_o=region_r[3:0];
  assign job_mode_o=op_r==1?2'd0:2'd1;
  assign job_param_o=param_r;assign job_id_o=done_id_o;
  assign status_ready_o=!rst && state==SAMPLE_WAIT && issued_r && !status_done_r;
  keygen_seed_collect seeds(
    .clk(clk),.rst(rst),.start_valid_i(state==SEED_START),.start_ready_o(seed_start_ready),
    .start_param_i(param_r),.start_id_i(done_id_o),.start_seed_i(xi_r),
    .result_valid_o(seed_result_valid),.result_ready_i(state==SEED_WAIT),
    .result_error_o(seed_error),.result_id_o(seed_id),.result_param_o(seed_param),
    .result_rho_o(seed_rho),.result_key_o(seed_key),.result_rhoprime_o(seed_rhoprime),
    .raw_valid_o(raw_valid_o),.raw_ready_i(raw_ready_i),.raw_core_i(raw_core_i),
    .raw_mode_o(raw_mode_o),.raw_id_o(raw_id_o),.raw_message_len_o(raw_message_len_o),.raw_output_len_o(raw_output_len_o),
    .raw_input_data_o(raw_input_data_o),.raw_input_valid_o(raw_input_valid_o),.raw_input_ready_i(raw_input_ready_i),
    .raw_output_valid_i(raw_output_valid_i),.raw_output_core_i(raw_output_core_i),.raw_output_id_i(raw_output_id_i),
    .raw_output_data_i(raw_output_data_i),.raw_output_bytes_i(raw_output_bytes_i),.raw_output_ready_o(raw_output_ready_o),
    .raw_done_valid_i(raw_done_valid_i),.raw_done_core_i(raw_done_core_i),.raw_done_id_i(raw_done_id_i),.raw_done_ready_o(raw_done_ready_o)
  );
  keygen_hash_message format(
    .clk(clk),.rst(rst),.command_valid_i(state==FORMAT_START),.command_ready_o(format_ready),
    .command_op_i(op_r),.command_param_i(param_r),.command_id_i(done_id_o),.command_nonce_i(nonce_r),
    .command_row_i(row_r),.command_column_i(column_r),.command_seed_i(op_r==1?{256'd0,rho_o}:rhoprime_o),
    .request_valid_o(request_valid),.request_ready_i(request_ready),.request_mode_o(request_mode),
    .request_message_len_o(message_len_o),.request_output_len_o(unused_length),
    .input_data_o(input_data_o),.input_valid_o(input_valid_o),.input_ready_i(input_ready_i),
    .done_valid_o(format_done),.done_ready_i(state==SAMPLE_WAIT),.done_error_o(format_error),.done_id_o(format_id)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=0;param_r<=0;nonce_r<=0;row_r<=0;column_r<=0;xi_r<=0;region_r<=0;
      done_code_o<=0;done_id_o<=0;seed_valid_o<=0;seed_param_o<=0;rho_o<=0;key_o<=0;rhoprime_o<=0;
      issued_r<=0;core_r<=0;message_done_r<=0;status_done_r<=0;
    end else begin
      case(state)
        IDLE:if(command_valid_i)begin
          op_r<=command_op_i;param_r<=command_param_i;nonce_r<=command_nonce_i;
          row_r<=command_row_i;column_r<=command_column_i;xi_r<=command_seed_i;region_r<=command_region_i;
          done_id_o<=command_id_i;done_code_o<=0;issued_r<=0;message_done_r<=0;status_done_r<=0;
          if(command_op_i==0)begin seed_valid_o<=0;rho_o<=0;key_o<=0;rhoprime_o<=0;state<=SEED_START;end
          else if(command_op_i==3)begin done_code_o<=3;state<=REPORT;end
          else if(!seed_valid_o)begin done_code_o<=1;state<=REPORT;end
          else if(command_param_i!=seed_param_o)begin done_code_o<=2;state<=REPORT;end
          else state<=FORMAT_START;
        end
        SEED_START:if(seed_start_ready)state<=SEED_WAIT;
        SEED_WAIT:if(seed_result_valid)begin
          seed_valid_o<=!seed_error;seed_param_o<=seed_param;
          rho_o<=seed_rho;key_o<=seed_key;rhoprime_o<=seed_rhoprime;
          done_code_o<=seed_error?3'd3:3'd0;state<=REPORT;
        end
        FORMAT_START:if(format_ready)state<=SAMPLE_WAIT;
        SAMPLE_WAIT:begin
          if(job_valid_o && job_ready_i)begin issued_r<=1;core_r<=job_core_i;end
          if(format_done)begin
            message_done_r<=1;
            if(format_error)begin done_code_o<=3;state<=REPORT;end
          end
          if(status_valid_i && status_ready_o)begin status_done_r<=1;done_code_o<=status_code_i==0?3'd0:3'd4;end
          if(message_done_r && status_done_r)state<=REPORT;
        end
        REPORT:if(done_ready_i)state<=IDLE;
        default:state<=IDLE;
      endcase
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst)begin
    if(status_valid_i && status_ready_o && (status_id_i!=done_id_o || status_core_i!=core_r))
      $fatal(1,"Seed-driven sample status ownership");
    if(format_done && state==SAMPLE_WAIT && format_id!=done_id_o)$fatal(1,"Sample formatter ownership");
    if(seed_result_valid && state==SEED_WAIT && seed_id!=done_id_o)$fatal(1,"Seed result ownership");
  end
`endif
endmodule
`default_nettype wire
