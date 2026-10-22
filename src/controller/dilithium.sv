// Main operation FSM. KeyGen is connected;Sign/Verify follow.
// Unsupported operations return code2 without starting the datapath.
`default_nettype none
module dilithium #(parameter bit ROUND_OUTPUTS=0, FULL_KEYGEN=0) (
  output logic key_valid_o,input wire logic key_ready_i,output logic [63:0] key_data_o,
  output logic [3:0] key_bytes_o,output logic key_type_o,key_last_o,
  output logic [9:0] key_index_o,output logic [15:0] key_id_o,
  input wire logic clk,rst,start_valid_i,output logic start_ready_o,busy_o,
  input wire logic [1:0] start_op_i,start_param_i,input wire logic [15:0] start_id_i,
  input wire logic [255:0] start_seed_i,
  output logic row_result_valid_o,input wire logic row_result_ready_i,
  output logic [3:0] row_result_index_o,output logic [5:0] row_result_region_o,
  output logic [15:0] row_result_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o,
  output logic seed_valid_o,output logic [255:0] rho_o,key_o,output logic [511:0] rhoprime_o,
  input wire logic read_valid_i,input wire logic [1:0] read_bank_i,
  input wire logic [3:0] read_region_i,input wire logic [5:0] read_word_i,
  output logic read_ready_o,response_valid_o,response_error_o,
  output logic [1:0] response_bank_o,response_mode_o,response_param_o,
  output logic [3:0] response_region_o,output logic [5:0] response_word_o,
  output logic [91:0] response_data_o,output logic [15:0] response_id_o,
  output logic response_ntt_domain_o,response_small_o,input wire logic response_ready_i,
  output logic [63:0] reserved_o,complete_o,output logic fault_o
);

  dilithium_service_pkg::request_t keygen_request,shared_request;
  dilithium_service_pkg::response_t shared_response;
  logic keygen_owner;

  typedef enum logic [1:0] {IDLE,DISPATCH,WAIT_RESULT,REJECT} state_e;
  state_e state;
  logic [1:0] param_r;logic [15:0] id_r;logic [255:0] xi_r;
  logic child_ready,child_busy,child_done;logic [2:0] child_code;logic [15:0] child_id;
  assign start_ready_o=!rst && state==IDLE && child_ready && !fault_o;
  assign busy_o=state!=IDLE || child_busy;
  assign done_valid_o=!rst && (state==REJECT || (state==WAIT_RESULT && child_done));
  assign done_code_o=state==REJECT?3'd2:child_code;
  assign done_id_o=state==REJECT?id_r:child_id;
  // Operation ownership includes post-completion cleanup,when main state is IDLE.
  // Future Sign/Verify clients join this boundary;only KeyGen is implemented now.
  assign keygen_owner=!rst && (state==DISPATCH || child_busy);
  assign shared_request=keygen_owner?keygen_request:'0;
  dilithium_services services(.clk(clk),.rst(rst),.request_i(shared_request),.response_o(shared_response));
  keygen #(.ROUND_OUTPUTS(ROUND_OUTPUTS),.FULL_KEYGEN(FULL_KEYGEN)) core(
    .service_o(keygen_request),.service_i(shared_response),
    .start_valid_i(state==DISPATCH),.start_ready_o(child_ready),.busy_o(child_busy),
    .start_param_i(param_r),.start_id_i(id_r),.start_seed_i(xi_r),
    .done_valid_o(child_done),.done_ready_i(state==WAIT_RESULT && done_ready_i),
    .done_code_o(child_code),.done_id_o(child_id),.*
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin state<=IDLE;param_r<=0;id_r<=0;xi_r<=0;end
    else case(state)
      IDLE:if(start_valid_i && start_ready_o)begin
        param_r<=start_param_i;id_r<=start_id_i;xi_r<=start_seed_i;
        state<=start_op_i==0?DISPATCH:REJECT;
      end
      DISPATCH:if(child_ready)state<=WAIT_RESULT;
      WAIT_RESULT:if(child_done && done_ready_i)state<=IDLE;
      REJECT:if(done_ready_i)state<=IDLE;
      default:state<=IDLE;
    endcase
  end
endmodule
`default_nettype wire
