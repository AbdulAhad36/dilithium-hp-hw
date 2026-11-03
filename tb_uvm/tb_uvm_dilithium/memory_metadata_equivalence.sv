`timescale 1ps/1ps
// Verification-only cycle comparison with the immutable pre-optimization memory.
// Payload/metadata are compared only when valid; all ready/status pins always.
module memory_metadata_equivalence (
  input wire logic  clk,
  input wire logic  rst,
  input wire logic  alloc_valid_i,
  input wire logic  alloc_core_i,
  input wire logic [1:0] alloc_bank_i,
  input wire logic [1:0] alloc_mode_i,
  input wire logic [1:0] alloc_param_i,
  input wire logic [3:0] alloc_region_i,
  input wire logic [15:0] alloc_id_i,
  input wire logic  alloc_compute_i,
  input wire logic  alloc_ntt_domain_i,
  input wire logic  alloc_rewrite_i,
  input wire logic  dut_alloc_ready_o,
  input wire logic  write_valid_i,
  input wire logic  write_core_i,
  input wire logic  write_last_i,
  input wire logic [15:0] write_id_i,
  input wire logic [7:0] write_index_i,
  input wire logic [22:0] write_data_i,
  input wire logic  dut_write_ready_o,
  input wire logic  finish_valid_i,
  input wire logic  finish_core_i,
  input wire logic [15:0] finish_id_i,
  input wire logic [2:0] finish_code_i,
  input wire logic  dut_finish_ready_o,
  input wire logic  read_valid_i,
  input wire logic [1:0] read_bank_i,
  input wire logic [3:0] read_region_i,
  input wire logic [5:0] read_word_i,
  input wire logic  dut_read_ready_o,
  input wire logic  dut_response_valid_o,
  input wire logic  dut_response_error_o,
  input wire logic [1:0] dut_response_bank_o,
  input wire logic [1:0] dut_response_mode_o,
  input wire logic [1:0] dut_response_param_o,
  input wire logic [3:0] dut_response_region_o,
  input wire logic [5:0] dut_response_word_o,
  input wire logic [91:0] dut_response_data_o,
  input wire logic [15:0] dut_response_id_o,
  input wire logic  dut_response_ntt_domain_o,
  input wire logic  dut_response_small_o,
  input wire logic  response_ready_i,
  input wire logic  release_valid_i,
  input wire logic [1:0] release_bank_i,
  input wire logic [3:0] release_region_i,
  input wire logic  dut_release_ready_o,
  input wire logic [63:0] dut_reserved_o,
  input wire logic [63:0] dut_complete_o,
  input wire logic  dut_fault_o
);
  logic  ref_alloc_ready_o;
  logic  ref_write_ready_o;
  logic  ref_finish_ready_o;
  logic  ref_read_ready_o;
  logic  ref_response_valid_o;
  logic  ref_response_error_o;
  logic [1:0] ref_response_bank_o;
  logic [1:0] ref_response_mode_o;
  logic [1:0] ref_response_param_o;
  logic [3:0] ref_response_region_o;
  logic [5:0] ref_response_word_o;
  logic [91:0] ref_response_data_o;
  logic [15:0] ref_response_id_o;
  logic  ref_response_ntt_domain_o;
  logic  ref_response_small_o;
  logic  ref_release_ready_o;
  logic [63:0] ref_reserved_o;
  logic [63:0] ref_complete_o;
  logic  ref_fault_o;
  bit failed=0;longint cycles=0,allocations=0,writes=0,finishes=0,reads=0,releases=0;
  memory_metadata_reference reference (
    .clk(clk),
    .rst(rst),
    .alloc_valid_i(alloc_valid_i),
    .alloc_core_i(alloc_core_i),
    .alloc_bank_i(alloc_bank_i),
    .alloc_mode_i(alloc_mode_i),
    .alloc_param_i(alloc_param_i),
    .alloc_region_i(alloc_region_i),
    .alloc_id_i(alloc_id_i),
    .alloc_compute_i(alloc_compute_i),
    .alloc_ntt_domain_i(alloc_ntt_domain_i),
    .alloc_rewrite_i(alloc_rewrite_i),
    .alloc_ready_o(ref_alloc_ready_o),
    .write_valid_i(write_valid_i),
    .write_core_i(write_core_i),
    .write_last_i(write_last_i),
    .write_id_i(write_id_i),
    .write_index_i(write_index_i),
    .write_data_i(write_data_i),
    .write_ready_o(ref_write_ready_o),
    .finish_valid_i(finish_valid_i),
    .finish_core_i(finish_core_i),
    .finish_id_i(finish_id_i),
    .finish_code_i(finish_code_i),
    .finish_ready_o(ref_finish_ready_o),
    .read_valid_i(read_valid_i),
    .read_bank_i(read_bank_i),
    .read_region_i(read_region_i),
    .read_word_i(read_word_i),
    .read_ready_o(ref_read_ready_o),
    .response_valid_o(ref_response_valid_o),
    .response_error_o(ref_response_error_o),
    .response_bank_o(ref_response_bank_o),
    .response_mode_o(ref_response_mode_o),
    .response_param_o(ref_response_param_o),
    .response_region_o(ref_response_region_o),
    .response_word_o(ref_response_word_o),
    .response_data_o(ref_response_data_o),
    .response_id_o(ref_response_id_o),
    .response_ntt_domain_o(ref_response_ntt_domain_o),
    .response_small_o(ref_response_small_o),
    .response_ready_i(response_ready_i),
    .release_valid_i(release_valid_i),
    .release_bank_i(release_bank_i),
    .release_region_i(release_region_i),
    .release_ready_o(ref_release_ready_o),
    .reserved_o(ref_reserved_o),
    .complete_o(ref_complete_o),
    .fault_o(ref_fault_o)
  );
  always @(posedge clk)if(!rst)begin
    cycles++;
    allocations+=int'(alloc_valid_i && dut_alloc_ready_o);
    writes+=int'(write_valid_i && dut_write_ready_o);
    finishes+=int'(finish_valid_i && dut_finish_ready_o);
    reads+=int'(read_valid_i && dut_read_ready_o);
    releases+=int'(release_valid_i && dut_release_ready_o);
  end
  always @(negedge clk)begin
    #1;if(!rst)begin
      if ({dut_alloc_ready_o,dut_write_ready_o,dut_finish_ready_o,dut_read_ready_o,dut_response_valid_o,dut_release_ready_o,dut_reserved_o,dut_complete_o,dut_fault_o} !== {ref_alloc_ready_o,ref_write_ready_o,ref_finish_ready_o,ref_read_ready_o,ref_response_valid_o,ref_release_ready_o,ref_reserved_o,ref_complete_o,ref_fault_o})begin
        failed=1;$fatal(1,"MEMORY_METADATA_EQUIVALENCE: ready/status mismatch cycle%0d",cycles);
      end
      if (dut_response_valid_o && {dut_response_error_o,dut_response_bank_o,dut_response_mode_o,dut_response_param_o,dut_response_region_o,dut_response_word_o,dut_response_data_o,dut_response_id_o,dut_response_ntt_domain_o,dut_response_small_o} !== {ref_response_error_o,ref_response_bank_o,ref_response_mode_o,ref_response_param_o,ref_response_region_o,ref_response_word_o,ref_response_data_o,ref_response_id_o,ref_response_ntt_domain_o,ref_response_small_o})begin
        failed=1;$fatal(1,"MEMORY_METADATA_EQUIVALENCE: published response mismatch cycle%0d",cycles);
      end
    end
  end
  final if(!failed)$display("MEMORY_METADATA_TRACE_MATCH:cycles%0d alloc%0d writes%0d finish%0d reads%0d releases%0d",cycles,allocations,writes,finishes,reads,releases);
endmodule

