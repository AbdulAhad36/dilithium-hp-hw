`timescale 1ns/1ps
// Reuse the same sampler/physical-memory checker with mixed algorithm pairs.
module tb_sampler_writer_mixed #(parameter bit DIFFERENT_BANKS=0);
  tb_sampler_writer #(.MIXED_ORDER(1),.DIFFERENT_BANKS(DIFFERENT_BANKS),.STRESS_QUEUE(1)) testbench();
endmodule
