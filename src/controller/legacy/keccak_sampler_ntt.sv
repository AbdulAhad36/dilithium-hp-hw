// Stage4 sequential sampled-polynomial -> memory -> NTT -> memory subsystem.
// The full algorithm controller/encoding/process blocks are still separate work.
`default_nettype none
module keccak_sampler_ntt #(
  parameter int SLOTS=4,
  parameter int SLOT_W=(SLOTS>1)?$clog2(SLOTS):1
) (
  input wire logic clk,rst,
  input wire logic job_valid_i,
  output logic job_ready_o,job_core_o,
  output logic [SLOT_W-1:0] job_slot_o,
  input wire logic [15:0] job_id_i,message_len_i,
  input wire logic [1:0] job_mode_i,job_param_i,
  input wire logic [63:0] input_data_i,
  input wire logic input_valid_i,
  output logic input_ready_o,
  output logic status_valid_o,status_core_o,
  output logic [15:0] status_id_o,
  output logic [2:0] status_code_o,
  input wire logic status_ready_i,
  output logic [1:0] active_o,
  input wire logic read_valid_i,
  input wire logic [SLOT_W-1:0] read_slot_i,
  input wire logic [7:0] read_index_i,
  output logic read_ready_o,response_valid_o,response_error_o,
  output logic [SLOT_W-1:0] response_slot_o,
  output logic [7:0] response_index_o,
  output logic [22:0] response_data_o,
  output logic [15:0] response_id_o,
  output logic [1:0] response_mode_o,response_param_o,
  output logic response_ntt_domain_o,
  input wire logic response_ready_i,
  input wire logic release_valid_i,
  input wire logic [SLOT_W-1:0] release_slot_i,
  output logic release_ready_o,
  output logic [SLOTS-1:0] reserved_o,complete_o,
  output logic fault_o,
  input wire logic op_valid_i,
  output logic op_ready_o,op_busy_o,
  input wire logic [1:0] op_i,
  input wire logic [SLOT_W-1:0] op_a_slot_i,op_b_slot_i,
  input wire logic [15:0] op_a_id_i,op_b_id_i,op_id_i,
  output logic op_done_valid_o,
  input wire logic op_done_ready_i,
  output logic [2:0] op_done_code_o,
  output logic [15:0] op_done_id_o,
  output logic [SLOT_W-1:0] op_done_slot_o
);
  typedef enum logic [3:0] {IDLE,RESERVE,RESERVE_REPLY,START,READ_REQUEST,
    READ_RESPONSE,WAIT_ENGINE,COMMIT,REPORT,HALT} state_e;
  state_e state;
  logic [1:0] operation_r;
  logic [SLOT_W-1:0] a_slot_r,b_slot_r,dest_r;
  logic [15:0] a_id_r,b_id_r,id_r;
  logic [2:0] code_r;
  logic operand_b_r,controller_fault_r;
  logic [7:0] load_index_r;
  logic [8:0] result_count_r;
  logic producer_ready,alloc_ready,finish_ready,command_fire;
  logic coeff_valid,coeff_ready,coeff_core,coeff_last;
  logic [15:0] coeff_id;
  logic [7:0] coeff_index;
  logic [22:0] coeff_data;
  logic producer_status_valid,producer_status_ready;
  logic mem_read_valid,mem_read_ready,mem_response_valid,mem_response_ready,mem_response_error;
  logic [SLOT_W-1:0] mem_read_slot,mem_response_slot;
  logic [7:0] mem_read_index,mem_response_index;
  logic [22:0] mem_response_data;
  logic [15:0] mem_response_id;
  logic [1:0] mem_response_mode,mem_response_param;
  logic mem_response_domain,mem_release_ready,mem_fault;
  logic exec_ready,exec_response_valid,result_ready;
  logic [2:0] exec_code;
  logic [SLOT_W-1:0] exec_slot;
  logic ntt_start,ntt_busy,ntt_done,s_valid,s_ready,m_valid,m_ready,m_last;
  logic [22:0] m_data;
  logic idle_access,release_allowed;

  assign idle_access=(state==IDLE);
  assign op_ready_o=!rst && idle_access && active_o==0 && !mem_response_valid && !fault_o;
  assign op_busy_o=(state!=IDLE);
  assign job_ready_o=idle_access && !op_valid_i && !fault_o && producer_ready && alloc_ready;
  assign command_fire=job_valid_i && job_ready_o;
  assign status_valid_o=producer_status_valid && finish_ready;
  assign producer_status_ready=status_ready_i && finish_ready;
  assign fault_o=mem_fault || controller_fault_r;
  assign op_done_valid_o=!rst && state==REPORT && !fault_o;
  assign op_done_code_o=code_r;
  assign op_done_id_o=id_r;
  assign op_done_slot_o=dest_r;

  // Once a compute command is accepted, its DMA owns the read interface.
  // Before acceptance, an old external response must be fully consumed.
  assign mem_read_valid=(state==READ_REQUEST) || (idle_access && !op_valid_i && read_valid_i);
  assign mem_read_slot=(state==READ_REQUEST)?(operand_b_r?b_slot_r:a_slot_r):read_slot_i;
  assign mem_read_index=(state==READ_REQUEST)?load_index_r:read_index_i;
  assign read_ready_o=idle_access && !op_valid_i && mem_read_ready;
  assign response_valid_o=idle_access && mem_response_valid;
  assign response_error_o=mem_response_error;
  assign response_slot_o=mem_response_slot;assign response_index_o=mem_response_index;
  assign response_data_o=mem_response_data;assign response_id_o=mem_response_id;
  assign response_mode_o=mem_response_mode;assign response_param_o=mem_response_param;
  assign response_ntt_domain_o=mem_response_domain;
  assign mem_response_ready=(state==READ_RESPONSE)?s_ready:(idle_access && response_ready_i);
  // Protect accepted source descriptors even while waiting for a destination.
  // Only unrelated completed slots may be freed during that reservation wait.
  assign release_allowed=(idle_access && !(op_valid_i && op_ready_o)) ||
    (state==RESERVE && release_slot_i!=a_slot_r &&
      (operation_r!=2 || release_slot_i!=b_slot_r));
  assign release_ready_o=release_allowed && mem_release_ready;
  assign ntt_start=(state==START) && !rst;
  assign s_valid=(state==READ_RESPONSE) && mem_response_valid && !mem_response_error;
  assign m_ready=(state==WAIT_ENGINE) && result_ready;

  keccak_sampler producer(
    .clk(clk),.rst(rst),.job_valid_i(command_fire),.job_ready_o(producer_ready),
    .job_core_o(job_core_o),.job_id_i(job_id_i),.message_len_i(message_len_i),
    .job_mode_i(job_mode_i),.job_param_i(job_param_i),
    .input_data_i(input_data_i),.input_valid_i(input_valid_i),.input_ready_o(input_ready_o),
    .output_data_o(coeff_data),.output_core_o(coeff_core),.output_id_o(coeff_id),
    .output_index_o(coeff_index),.output_last_o(coeff_last),
    .output_valid_o(coeff_valid),.output_ready_i(coeff_ready),
    .status_valid_o(producer_status_valid),.status_core_o(status_core_o),
    .status_id_o(status_id_o),.status_code_o(status_code_o),
    .status_ready_i(producer_status_ready),.active_o(active_o),
    .raw_valid_i(1'b0),.raw_ready_o(),.raw_core_o(),.raw_mode_i(1'b0),
    .raw_id_i(16'd0),.raw_message_len_i(16'd0),.raw_output_len_i(16'd0),
    .raw_input_data_i(64'd0),.raw_input_valid_i(1'b0),.raw_input_ready_o(),
    .raw_output_valid_o(),.raw_output_core_o(),.raw_output_id_o(),
    .raw_output_data_o(),.raw_output_bytes_o(),.raw_output_ready_i(1'b0),
    .raw_done_valid_o(),.raw_done_core_o(),.raw_done_id_o(),.raw_done_ready_i(1'b0)
  );
  slot_memory #(.SLOTS(SLOTS),.SLOT_W(SLOT_W)) store(
    .clk(clk),.rst(rst),.alloc_valid_i(command_fire),.alloc_ready_o(alloc_ready),
    .alloc_slot_o(job_slot_o),.alloc_core_i(job_core_o),.alloc_id_i(job_id_i),
    .alloc_mode_i(job_mode_i),.alloc_param_i(job_param_i),
    .write_valid_i(coeff_valid),.write_ready_o(coeff_ready),.write_core_i(coeff_core),
    .write_id_i(coeff_id),.write_index_i(coeff_index),.write_last_i(coeff_last),.write_data_i(coeff_data),
    .finish_valid_i(producer_status_valid && status_ready_i),.finish_ready_o(finish_ready),
    .finish_core_i(status_core_o),.finish_id_i(status_id_o),.finish_code_i(status_code_o),
    .read_valid_i(mem_read_valid),.read_ready_o(mem_read_ready),.read_slot_i(mem_read_slot),
    .read_index_i(mem_read_index),.response_valid_o(mem_response_valid),
    .response_ready_i(mem_response_ready),.response_error_o(mem_response_error),
    .response_slot_o(mem_response_slot),.response_index_o(mem_response_index),
    .response_data_o(mem_response_data),.response_id_o(mem_response_id),
    .response_mode_o(mem_response_mode),.response_param_o(mem_response_param),
    .response_ntt_domain_o(mem_response_domain),
    .release_valid_i(release_valid_i && release_allowed),
    .release_slot_i(release_slot_i),.release_ready_o(mem_release_ready),
    .reserved_o(reserved_o),.complete_o(complete_o),.fault_o(mem_fault),
    .exec_valid_i(state==RESERVE),.exec_ready_o(exec_ready),.exec_op_i(operation_r),
    .exec_a_slot_i(a_slot_r),.exec_b_slot_i(b_slot_r),
    .exec_a_id_i(a_id_r),.exec_b_id_i(b_id_r),.exec_id_i(id_r),
    .exec_response_valid_o(exec_response_valid),.exec_response_ready_i(state==RESERVE_REPLY),
    .exec_code_o(exec_code),.exec_slot_o(exec_slot),
    .result_valid_i(m_valid && state==WAIT_ENGINE),.result_last_i(m_last),
    .result_ready_o(result_ready),.result_index_i(result_count_r[7:0]),.result_data_i(m_data),
    .exec_done_i(state==COMMIT)
  );
  ntt_engine engine(
    .clk(clk),.rst(rst),.start_i(ntt_start),.op_i(ntt_pkg::ntt_op_e'(operation_r)),
    .busy_o(ntt_busy),.done_o(ntt_done),
    .s_tdata(mem_response_data),.s_tvalid(s_valid),.s_tready(s_ready),.s_tlast(load_index_r==255),
    .m_tdata(m_data),.m_tvalid(m_valid),.m_tready(m_ready),.m_tlast(m_last)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;operation_r<=0;a_slot_r<='0;b_slot_r<='0;dest_r<='0;
      a_id_r<=0;b_id_r<=0;id_r<=0;code_r<=0;operand_b_r<=0;
      load_index_r<=0;result_count_r<=0;controller_fault_r<=0;
    end else begin
      case(state)
        IDLE:if(op_valid_i && op_ready_o)begin
          operation_r<=op_i;a_slot_r<=op_a_slot_i;b_slot_r<=op_b_slot_i;
          a_id_r<=op_a_id_i;b_id_r<=op_b_id_i;id_r<=op_id_i;code_r<=0;dest_r<='0;
          state<=RESERVE;
        end
        RESERVE:if(exec_ready)state<=RESERVE_REPLY;
        RESERVE_REPLY:if(exec_response_valid)begin
          code_r<=exec_code;dest_r<=exec_slot;
          if(exec_code==0)begin
            operand_b_r<=0;load_index_r<=0;result_count_r<=0;state<=START;
          end else state<=REPORT;
        end
        START:state<=READ_REQUEST;
        READ_REQUEST:if(mem_read_ready)state<=READ_RESPONSE;
        READ_RESPONSE:if(mem_response_valid)begin
          if(mem_response_error || mem_response_slot!=(operand_b_r?b_slot_r:a_slot_r) ||
             mem_response_id!=(operand_b_r?b_id_r:a_id_r) || mem_response_index!=load_index_r)begin
            controller_fault_r<=1;state<=HALT;
          end else if(s_ready)begin
            if(load_index_r==255)begin
              if(operation_r==2 && !operand_b_r)begin
                operand_b_r<=1;load_index_r<=0;state<=READ_REQUEST;
              end else state<=WAIT_ENGINE;
            end else begin load_index_r<=load_index_r+1'b1;state<=READ_REQUEST;end
          end
        end
        WAIT_ENGINE:begin
          if(m_valid && m_ready)result_count_r<=result_count_r+1'b1;
          if(ntt_done)begin
            if(result_count_r==256)state<=COMMIT;
            else begin controller_fault_r<=1;state<=HALT;end
          end
        end
        COMMIT:state<=REPORT;
        REPORT:if(op_done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:begin controller_fault_r<=1;state<=HALT;end
      endcase
      if(mem_fault)begin controller_fault_r<=1;state<=HALT;end
    end
  end
endmodule
`default_nettype wire
