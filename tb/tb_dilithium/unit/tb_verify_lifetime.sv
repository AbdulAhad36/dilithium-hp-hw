`timescale 1ns/1ps
module tb_verify_lifetime;
  import dilithium_pkg::*;
  tb_main mainbench();
  logic reference_start_ready,reference_busy,reference_fault,reference_input_ready;
  logic reference_done,reference_accept;
  logic [15:0] reference_id;
  logic [2:0] reference_code,reference_stage,reference_detail;
  request_t reference_service;
  int cycles=0,completed=0;
  `define REF mainbench.dut.core.verify_controller
  verify_c17_reference reference_dut(
    .clk(`REF.clk),
    .rst(`REF.rst),
    .start_valid_i(`REF.start_valid_i),
    .start_param_i(`REF.start_param_i),
    .start_id_i(`REF.start_id_i),
    .start_message_len_i(`REF.start_message_len_i),
    .start_signature_len_i(`REF.start_signature_len_i),
    .start_context_len_i(`REF.start_context_len_i),
    .input_valid_i(`REF.input_valid_i),
    .input_data_i(`REF.input_data_i),
    .input_bytes_i(`REF.input_bytes_i),
    .input_index_i(`REF.input_index_i),
    .input_last_i(`REF.input_last_i),
    .done_ready_i(`REF.done_ready_i),
    .service_i(`REF.service_i),
    .start_ready_o(reference_start_ready),
    .busy_o(reference_busy),
    .fault_o(reference_fault),
    .input_ready_o(reference_input_ready),
    .done_valid_o(reference_done),
    .done_id_o(reference_id),
    .done_code_o(reference_code),
    .done_stage_o(reference_stage),
    .done_detail_o(reference_detail),
    .done_accept_o(reference_accept),
    .service_o(reference_service));
  always @(negedge mainbench.clk)if(!mainbench.rst)begin
    cycles++;
    if ({reference_start_ready,reference_busy,reference_fault,reference_input_ready,
         reference_done,reference_id,reference_code,reference_stage,reference_detail,reference_accept}
      !== {`REF.start_ready_o,`REF.busy_o,`REF.fault_o,`REF.input_ready_o,
         `REF.done_valid_o,`REF.done_id_o,`REF.done_code_o,`REF.done_stage_o,`REF.done_detail_o,`REF.done_accept_o})
      $fatal(1,"Verify controller pins changed at cycle%0d",cycles);
    if(reference_service!==`REF.service_o)$fatal(1,"Verify service changed at cycle%0d",cycles);
  end
  always @(posedge mainbench.clk)if(!mainbench.rst && reference_done && `REF.done_ready_i)begin
    if(reference_dut.digest_r!==`REF.digest_r)$fatal(1,"Complete Verify digest differs");
    completed++;
  end
  final begin
    if(completed!=3 || cycles<1000)$error("Incomplete Verify lifetime probe:%0d",completed);
    else $display("LIGHTHD_VERIFY_DIGEST_LIFETIME_PASS:%0d cycles/%0d complete digests/pins and complete service requests exact",cycles,completed);
  end
  `undef REF
endmodule
