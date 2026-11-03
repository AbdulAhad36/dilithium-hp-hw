`timescale 1ns/1ps
module tb_process_ports;
 import dilithium_pkg::*;
 logic  clk;
 logic  rst;
 logic  command_valid_i;
 process_op_e  command_op_i;
 logic [1:0] command_param_i;
 logic [1:0] command_kind_i;
 logic  command_a_compact_i;
 logic  command_b_enable_i;
 logic  command_b_compact_i;
 logic  command_low_enable_i;
 logic  command_pack_high_i;
 logic  command_pack_store_i;
 logic [2:0] command_pack_op_i;
 logic  command_hint_enable_i;
 logic [1:0] command_a_bank_i;
 logic [1:0] command_b_bank_i;
 logic [1:0] command_d_bank_i;
 logic [1:0] command_h_bank_i;
 logic [9:0] command_a_base_i;
 logic [9:0] command_b_base_i;
 logic [9:0] command_d_base_i;
 logic [9:0] command_h_base_i;
 logic  done_ready_i;
 logic  packed_ready_i;
 logic  hint_ready_i;
 logic [1:0] memory_command_ready_i;
 logic [1:0][3:0] memory_write_ready_i;
 logic [1:0][3:0] memory_read_valid_i;
 logic [1:0][3:0][91:0] memory_read_data_i;
 logic [1:0][3:0] memory_done_valid_i;
 logic [1:0][3:0] memory_done_error_i;
 int checked=0,rejected=0;
 process_dma dut(
.hint_encode_i('0),.hint_decode_i('0),.hint_encode_o(),.hint_decode_o(),.hint_idle_o(),
.clk(clk),
.rst(rst),
.command_valid_i(command_valid_i),
.command_ready_o(),
.command_op_i(command_op_i),
.command_param_i(command_param_i),
.command_kind_i(command_kind_i),
.command_a_compact_i(command_a_compact_i),
.command_b_enable_i(command_b_enable_i),
.command_b_compact_i(command_b_compact_i),
.command_low_enable_i(command_low_enable_i),
.command_pack_high_i(command_pack_high_i),
.command_pack_store_i(command_pack_store_i),
.command_pack_op_i(command_pack_op_i),
.command_hint_enable_i(command_hint_enable_i),
.command_a_bank_i(command_a_bank_i),
.command_b_bank_i(command_b_bank_i),
.command_d_bank_i(command_d_bank_i),
.command_h_bank_i(command_h_bank_i),
.command_a_base_i(command_a_base_i),
.command_b_base_i(command_b_base_i),
.command_d_base_i(command_d_base_i),
.command_h_base_i(command_h_base_i),
.done_valid_o(),
.done_ready_i(done_ready_i),
.done_code_o(),
.done_reject_o(),
.done_hint_weight_o(),
.packed_valid_o(),
.packed_ready_i(packed_ready_i),
.packed_data_o(),
.packed_index_o(),
.packed_last_o(),
.hint_valid_o(),
.hint_ready_i(hint_ready_i),
.hint_mask_o(),
.hint_word_o(),
.hint_last_o(),
.memory_command_valid_o(),
.memory_command_ready_i(memory_command_ready_i),
.memory_command_mask_o(),
.memory_command_write_o(),
.memory_command_base_o(),
.memory_command_words_o(),
.memory_command_mode_o(),
.memory_write_valid_o(),
.memory_write_ready_i(memory_write_ready_i),
.memory_write_data_o(),
.memory_read_valid_i(memory_read_valid_i),
.memory_read_ready_o(),
.memory_read_data_i(memory_read_data_i),
.memory_done_valid_i(memory_done_valid_i),
.memory_done_error_i(memory_done_error_i),
.memory_done_ready_o());
 process_dma_c12_reference reference_dut(
.clk(clk),
.rst(rst),
.command_valid_i(command_valid_i),
.command_ready_o(),
.command_op_i(command_op_i),
.command_param_i(command_param_i),
.command_kind_i(command_kind_i),
.command_a_compact_i(command_a_compact_i),
.command_b_enable_i(command_b_enable_i),
.command_b_compact_i(command_b_compact_i),
.command_low_enable_i(command_low_enable_i),
.command_pack_high_i(command_pack_high_i),
.command_pack_store_i(command_pack_store_i),
.command_pack_op_i(command_pack_op_i),
.command_hint_enable_i(command_hint_enable_i),
.command_a_bank_i(command_a_bank_i),
.command_b_bank_i(command_b_bank_i),
.command_d_bank_i(command_d_bank_i),
.command_h_bank_i(command_h_bank_i),
.command_a_base_i(command_a_base_i),
.command_b_base_i(command_b_base_i),
.command_d_base_i(command_d_base_i),
.command_h_base_i(command_h_base_i),
.done_valid_o(),
.done_ready_i(done_ready_i),
.done_code_o(),
.done_reject_o(),
.done_hint_weight_o(),
.packed_valid_o(),
.packed_ready_i(packed_ready_i),
.packed_data_o(),
.packed_index_o(),
.packed_last_o(),
.hint_valid_o(),
.hint_ready_i(hint_ready_i),
.hint_mask_o(),
.hint_word_o(),
.hint_last_o(),
.memory_command_valid_o(),
.memory_command_ready_i(memory_command_ready_i),
.memory_command_mask_o(),
.memory_command_write_o(),
.memory_command_base_o(),
.memory_command_words_o(),
.memory_command_mode_o(),
.memory_write_valid_o(),
.memory_write_ready_i(memory_write_ready_i),
.memory_write_data_o(),
.memory_read_valid_i(memory_read_valid_i),
.memory_read_ready_o(),
.memory_read_data_i(memory_read_data_i),
.memory_done_valid_i(memory_done_valid_i),
.memory_done_error_i(memory_done_error_i),
.memory_done_ready_o());
 initial begin
 clk='0;
 rst='0;
 command_valid_i='0;
 command_op_i=PROC_ADD;
 command_param_i='0;
 command_kind_i='0;
 command_a_compact_i='0;
 command_b_enable_i='0;
 command_b_compact_i='0;
 command_low_enable_i='0;
 command_pack_high_i='0;
 command_pack_store_i='0;
 command_pack_op_i='0;
 command_hint_enable_i='0;
 command_a_bank_i='0;
 command_b_bank_i='0;
 command_d_bank_i='0;
 command_h_bank_i='0;
 command_a_base_i='0;
 command_b_base_i='0;
 command_d_base_i='0;
 command_h_base_i='0;
 done_ready_i='0;
 packed_ready_i='0;
 hint_ready_i='0;
 memory_command_ready_i='0;
 memory_write_ready_i='0;
 memory_read_valid_i='0;
 memory_read_data_i='0;
 memory_done_valid_i='0;
 memory_done_error_i='0;
 rst=1;#2;
 for(int level=0;level<4;level++)for(int op=0;op<8;op++)for(int pack=0;pack<8;pack++)
 for(int flags=0;flags<16;flags++)for(int banks=0;banks<256;banks++)for(int compact=0;compact<2;compact++)begin
  command_param_i=2'(level);command_op_i=process_op_e'(op);command_pack_op_i=3'(pack);
  command_b_enable_i=1'(flags);command_low_enable_i=1'(flags>>1);
  command_pack_high_i=1'(flags>>2);command_pack_store_i=1'(flags>>3);
  command_b_compact_i=1'(compact);command_a_compact_i=1'(banks);command_hint_enable_i=1'(banks>>1);
  command_a_bank_i=2'(banks);command_b_bank_i=2'(banks>>2);command_d_bank_i=2'(banks>>4);command_h_bank_i=2'(banks>>6);
  command_a_base_i=10'(banks*4);command_b_base_i=10'(banks*16+compact);
  command_d_base_i=10'(banks*64);command_h_base_i=10'(banks*4+pack*80);
  #1;
  if({dut.port_next,dut.mask_next,dut.write_next,dut.bad_command}!==
     {reference_dut.port_next,reference_dut.mask_next,reference_dut.write_next,reference_dut.bad_command})
   $fatal(1,"Phase port mismatch level%0d op%0d pack%0d flags%h banks%h compact%0d",level,op,pack,flags,banks,compact);
  checked++;rejected+=int'(dut.bad_command);
 end
 $display("LIGHTHD_PROCESS_PHASE_PORT_PASS:%0d actual production/C12 descriptor comparisons/%0d expected rejects;all bank,enable,operation,level,format and compact combinations",checked,rejected);
 $finish;
 end
endmodule
