`timescale 1ps/1ps
module tb_top;
  import uvm_pkg::*;import dilithium_uvm_pkg::*;
  logic clk=0;
  // Match the timing-first integration target:6.500ns (153.85MHz).
  always begin hsla(260, 43%, 23%, 0.00) clk=1;#3250 clk=0;end
  dilithium_if vif(clk);
  dilithium_fpga dut (
    .start_internal_message_i(1'b0),
    .key_valid_o(vif.key_valid_o),
    .key_ready_i(vif.key_ready_i),
    .key_data_o(vif.key_data_o),
    .key_bytes_o(vif.key_bytes_o),
    .key_type_o(vif.key_type_o),
    .key_last_o(vif.key_last_o),
    .key_index_o(vif.key_index_o),
    .key_id_o(vif.key_id_o),
    .clk(clk),
    .rst(vif.rst),
    .start_valid_i(vif.start_valid_i),
    .start_ready_o(vif.start_ready_o),
    .busy_o(vif.busy_o),
    .start_op_i(vif.start_op_i),
    .start_param_i(vif.start_param_i),
    .start_id_i(vif.start_id_i),
    .start_seed_i(vif.start_seed_i),
    .start_message_len_i(vif.start_message_len_i),
    .start_context_len_i(vif.start_context_len_i),
    .start_rnd_i(vif.start_rnd_i),
    .sign_input_valid_i(vif.sign_input_valid_i),
    .sign_input_ready_o(vif.sign_input_ready_o),
    .sign_input_data_i(vif.sign_input_data_i),
    .sign_input_bytes_i(vif.sign_input_bytes_i),
    .sign_input_index_i(vif.sign_input_index_i),
    .sign_input_last_i(vif.sign_input_last_i),
    .start_signature_len_i(vif.start_signature_len_i),
    .verify_input_valid_i(vif.verify_input_valid_i),
    .verify_input_ready_o(vif.verify_input_ready_o),
    .verify_input_data_i(vif.verify_input_data_i),
    .verify_input_bytes_i(vif.verify_input_bytes_i),
    .verify_input_index_i(vif.verify_input_index_i),
    .verify_input_last_i(vif.verify_input_last_i),
    .verify_accept_o(vif.verify_accept_o),
    .signature_valid_o(vif.signature_valid_o),
    .signature_ready_i(vif.signature_ready_i),
    .signature_data_o(vif.signature_data_o),
    .signature_bytes_o(vif.signature_bytes_o),
    .signature_index_o(vif.signature_index_o),
    .signature_last_o(vif.signature_last_o),
    .signature_id_o(vif.signature_id_o),
    .done_stage_o(vif.done_stage_o),
    .done_detail_o(vif.done_detail_o),
    .sign_attempts_o(vif.sign_attempts_o),
    .sign_rejections_o(vif.sign_rejections_o),
    .sign_next_nonce_o(vif.sign_next_nonce_o),
    .done_valid_o(vif.done_valid_o),
    .done_ready_i(vif.done_ready_i),
    .done_code_o(vif.done_code_o),
    .done_id_o(vif.done_id_o),
    .fault_o(vif.fault_o)
  );
  // Observation probes are internal;they are not production FPGA ports.
  assign vif.main_state=dut.core.state;
  assign vif.owners={dut.core.selected_v,dut.core.selected_s,dut.core.selected_k};
  assign vif.hash_active=dut.core.datapath.hash_sampler.engine_active;
  assign vif.ntt_busy=dut.core.datapath.polynomial.core_busy;
  assign vif.process_busy=!dut.core.datapath.process_ready;
  assign vif.datapath_idle=dut.core.response.idle;
  assign vif.bank_owners=dut.core.datapath.memory.router.owner_r;
  assign vif.bank_collision=dut.core.datapath.collision_o;
  for(genvar p=0;p<2;p++)begin:g_ports
    for(genvar b=0;b<4;b++)begin:g_banks
      assign vif.bank_ports[4*p+b]=vif.bank_owners[p][b]!=3;
      // Only the actual owner may receive a memory handshake or payload.
      for(genvar c=0;c<3;c++)begin:g_clients
        always @(posedge clk)if(!vif.rst && vif.bank_owners[p][b]!=c &&
          (dut.core.datapath.client_write_ready_o[c][p][b] ||
           dut.core.datapath.client_read_valid_o[c][p][b] ||
           dut.core.datapath.client_done_valid_o[c][p][b]))
          $fatal(1,"Bank port routed to a non-owner client");
      end
    end
  end
  initial begin uvm_config_db#(virtual dilithium_if)::set(null,"*","vif",vif);
          run_test();end
  initial begin #(64'd4000000000000);$fatal(1,"Dilithium UVM global watchdog");end
endmodule

