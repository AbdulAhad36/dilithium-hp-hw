`timescale 1ps/1ps
// Trace preservation only;independent C/Python checking remains required.
module verify_decode_equivalence (
  input wire logic  clk,
  input wire logic  rst,
  input wire logic  command_valid_i,
  input wire logic  dut_command_ready_o,
  input wire logic  dut_busy_o,
  input wire logic  command_kind_i,
  input wire logic [1:0] command_param_i,
  input wire logic [15:0] command_id_i,
  input wire logic [15:0] command_length_i,
  input wire logic  input_valid_i,
  input wire logic  dut_input_ready_o,
  input wire logic [63:0] input_data_i,
  input wire logic [3:0] input_bytes_i,
  input wire logic [15:0] input_index_i,
  input wire logic  input_last_i,
  input wire logic  dut_header_valid_o,
  input wire logic  header_ready_i,
  input wire logic [511:0] dut_header_data_o,
  input wire logic [6:0] dut_header_bytes_o,
  input wire logic [15:0] dut_header_id_o,
  input wire logic  dut_output_valid_o,
  input wire logic  output_ready_i,
  input wire logic [22:0] dut_output_data_o,
  input wire logic [1:0] dut_output_section_o,
  input wire logic [2:0] dut_output_poly_o,
  input wire logic [7:0] dut_output_index_o,
  input wire logic  dut_output_last_poly_o,
  input wire logic  dut_output_last_frame_o,
  input wire logic [15:0] dut_output_id_o,
  input wire logic  dut_done_valid_o,
  input wire logic  done_ready_i,
  input wire logic [2:0] dut_done_code_o,
  input wire logic [15:0] dut_done_id_o
);
  logic  ref_command_ready_o;
  logic  ref_busy_o;
  logic  ref_input_ready_o;
  logic  ref_header_valid_o;
  logic [511:0] ref_header_data_o;
  logic [6:0] ref_header_bytes_o;
  logic [15:0] ref_header_id_o;
  logic  ref_output_valid_o;
  logic [22:0] ref_output_data_o;
  logic [1:0] ref_output_section_o;
  logic [2:0] ref_output_poly_o;
  logic [7:0] ref_output_index_o;
  logic  ref_output_last_poly_o;
  logic  ref_output_last_frame_o;
  logic [15:0] ref_output_id_o;
  logic  ref_done_valid_o;
  logic [2:0] ref_done_code_o;
  logic [15:0] ref_done_id_o;
  bit failed=0;longint cycles=0,headers=0,values=0,finishes=0;
  verify_decode_reference reference (
    .clk(clk),
    .rst(rst),
    .command_valid_i(command_valid_i),
    .command_ready_o(ref_command_ready_o),
    .busy_o(ref_busy_o),
    .command_kind_i(command_kind_i),
    .command_param_i(command_param_i),
    .command_id_i(command_id_i),
    .command_length_i(command_length_i),
    .input_valid_i(input_valid_i),
    .input_ready_o(ref_input_ready_o),
    .input_data_i(input_data_i),
    .input_bytes_i(input_bytes_i),
    .input_index_i(input_index_i),
    .input_last_i(input_last_i),
    .header_valid_o(ref_header_valid_o),
    .header_ready_i(header_ready_i),
    .header_data_o(ref_header_data_o),
    .header_bytes_o(ref_header_bytes_o),
    .header_id_o(ref_header_id_o),
    .output_valid_o(ref_output_valid_o),
    .output_ready_i(output_ready_i),
    .output_data_o(ref_output_data_o),
    .output_section_o(ref_output_section_o),
    .output_poly_o(ref_output_poly_o),
    .output_index_o(ref_output_index_o),
    .output_last_poly_o(ref_output_last_poly_o),
    .output_last_frame_o(ref_output_last_frame_o),
    .output_id_o(ref_output_id_o),
    .done_valid_o(ref_done_valid_o),
    .done_ready_i(done_ready_i),
    .done_code_o(ref_done_code_o),
    .done_id_o(ref_done_id_o)
  );
  always @(posedge clk)if(!rst)begin
    cycles++;headers+=int'(dut_header_valid_o && header_ready_i);values+=int'(dut_output_valid_o && output_ready_i);finishes+=int'(dut_done_valid_o && done_ready_i);
    if(reference.state==1 && reference.push && !reference.bad_frame && reference.word_r>=8)begin failed=1;$fatal(1,"HEADER write exceeds eight words");end
    if(reference.state==4 && reference.push && !reference.bad_frame && reference.hint_bytes_r[2:0]!=0)begin failed=1;$fatal(1,"Hint input word lost alignment");end
  end
  always @(negedge clk)begin #2;if(!rst)begin
      if({dut_command_ready_o,dut_busy_o,dut_input_ready_o,dut_header_valid_o,dut_output_valid_o,dut_done_valid_o} !== {ref_command_ready_o,ref_busy_o,ref_input_ready_o,ref_header_valid_o,ref_output_valid_o,ref_done_valid_o})begin failed=1;$fatal(1,"VERIFY_DECODE_EQUIVALENCE:ready/status cycle%0d",cycles);end
      if(dut_header_valid_o && {dut_header_data_o,dut_header_bytes_o,dut_header_id_o} !== {ref_header_data_o,ref_header_bytes_o,ref_header_id_o})begin failed=1;$fatal(1,"VERIFY_DECODE_EQUIVALENCE:header cycle%0d",cycles);end
      if(dut_output_valid_o && {dut_output_data_o,dut_output_section_o,dut_output_poly_o,dut_output_index_o,dut_output_last_poly_o,dut_output_last_frame_o,dut_output_id_o} !== {ref_output_data_o,ref_output_section_o,ref_output_poly_o,ref_output_index_o,ref_output_last_poly_o,ref_output_last_frame_o,ref_output_id_o})begin failed=1;$fatal(1,"VERIFY_DECODE_EQUIVALENCE:coefficient cycle%0d",cycles);end
      if(dut_done_valid_o && {dut_done_code_o,dut_done_id_o} !== {ref_done_code_o,ref_done_id_o})begin failed=1;$fatal(1,"VERIFY_DECODE_EQUIVALENCE:completion cycle%0d",cycles);end
    end end
  final if(!failed)$display("VERIFY_DECODE_TRACE_MATCH:cycles%0d headers%0d coefficients%0d completions%0d",cycles,headers,values,finishes);
endmodule
