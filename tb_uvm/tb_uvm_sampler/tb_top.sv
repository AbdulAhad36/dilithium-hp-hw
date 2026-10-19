`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import sampler_uvm_pkg::*;
  bit clk=0;
  always #5 clk=~clk;
  sampler_if vif(clk);
  sampler dut(
    .clk(clk),.rst(vif.rst),
    .job_valid_i(vif.job_valid),.job_ready_o(vif.job_ready),
    .job_core_i(vif.job_core),.job_id_i(vif.job_id),
    .job_mode_i(vif.job_mode),.job_param_i(vif.job_param),
    .input_data_i(vif.input_data),.input_bytes_i(vif.input_bytes),
    .input_core_i(vif.input_core),.input_last_i(vif.input_last),
    .input_valid_i(vif.input_valid),.input_ready_o(vif.input_ready),
    .output_data_o(vif.output_data),.output_core_o(vif.output_core),
    .output_id_o(vif.output_id),.output_index_o(vif.output_index),
    .output_last_o(vif.output_last),.output_valid_o(vif.output_valid),
    .output_ready_i(vif.output_ready),
    .status_valid_o(vif.status_valid),.status_core_o(vif.status_core),
    .status_id_o(vif.status_id),.status_code_o(vif.status_code),
    .status_ready_i(vif.status_ready),.active_o(vif.active),.source_stop_o(vif.source_stop)
  );
`ifndef SAMPLER_NETLIST
  assign vif.perf_hold=dut.hold_r;
  assign vif.perf_hold_core=dut.hold_core_r;
  assign vif.perf_hold_bytes=dut.hold_bytes_r;
  assign vif.perf_chunk=dut.chunk_fire;
  assign vif.probe_decode_valid=dut.decode_valid_r;
  assign vif.probe_prepare_phase=dut.u_prepare.phase_r;
  assign vif.probe_packed_valid=dut.packed_valid_r;
  assign vif.probe_decode_core=dut.decode_core_r;
  assign vif.probe_packed_core=dut.packed_core_r;
  assign vif.probe_decode_transfer=dut.decode_transfer;
  assign vif.probe_compact_count=dut.compact_count;
  assign vif.probe_admit_count=dut.admit_count;
  assign vif.probe_status_eligible=dut.status_eligible;
  assign vif.probe_status_lock=dut.status_lock_r;
  assign vif.probe_collector_pop=dut.collector_pop;
  assign vif.probe_collector_core=dut.chosen;
  assign vif.probe_collector_fetch=dut.read_fill;
  assign vif.perf_ball_state=dut.u_ball.state;
  assign vif.perf_ball_selected=dut.u_ball.selected;
  assign vif.perf_ball_clear_core=dut.u_ball.clear_core;
  assign vif.perf_ball_byte_ready=dut.u_ball.byte_ready_o;
  assign vif.perf_ball_byte_valid=dut.u_ball.byte_valid_i;
  assign vif.perf_ball_done=dut.u_ball.done_o;
  assign vif.perf_byte=dut.held_byte;
  generate for(genvar k=0;k<2;k++)begin: g_perf_probe
    assign vif.perf_res_bytes[k]=dut.residual_count_r[k];
    assign vif.perf_res_bits[k]=dut.mask_bits_r[k];
    assign vif.perf_count[k]=dut.count_r[k];
    assign vif.probe_head[k]=dut.head_r[k];
    assign vif.probe_tail[k]=dut.tail_r[k];
    assign vif.perf_gen[k]=dut.generated_r[k];
    assign vif.perf_gen_next[k]=dut.generated_n[k];
    assign vif.perf_ball_sign_bytes[k]=dut.u_ball.sign_bytes[k];
    assign vif.perf_ball_position[k]=dut.u_ball.position[k];
  end endgenerate
`endif
  initial begin
    uvm_config_db#(virtual sampler_if)::set(null,"*","vif",vif);
    run_test();
  end
  initial begin #5ms;$fatal(1,"Sampler test watchdog expired");end
endmodule
