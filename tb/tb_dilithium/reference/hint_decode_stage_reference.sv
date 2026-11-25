// Final FIPS sparse hint suffix -> four canonical hint bits per bank word.
// Validate counts, ordered indices and zero padding BEFORE any output credit.
// Only the bounded suffix (at most84 bytes) is retained, never a signature RAM.
`default_nettype none
module hint_decode_stage_reference (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,
  input wire logic [1:0] command_param_i,input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,input wire logic [63:0] input_data_i,
  input wire logic [3:0] input_index_i,input_bytes_i,input wire logic input_last_i,
  output logic output_valid_o,input wire logic output_ready_i,output logic [3:0] output_hints_o,
  output logic [2:0] output_row_o,output logic [5:0] output_word_o,output logic output_last_o,
  output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,output logic [2:0] done_code_o,
  output logic [15:0] done_id_o
);
  logic raw_command_ready,raw_valid,raw_done,slot_valid,slot_ready;
  logic [3:0] raw_hints,mask_r;logic [2:0] raw_row,row_r;
  logic [5:0] raw_word,word_r;logic raw_last,last_r;
  assign slot_ready=!slot_valid || output_ready_i;
  assign command_ready_o=raw_command_ready && !slot_valid;
  assign output_valid_o=!rst && slot_valid;
  assign output_hints_o=mask_r;assign output_row_o=row_r;
  assign output_word_o=word_r;assign output_last_o=last_r;
  assign done_valid_o=raw_done && !slot_valid;
  hintunpkg_c13_reference old_decoder(
    .command_ready_o(raw_command_ready),.output_valid_o(raw_valid),.output_ready_i(slot_ready),
    .output_hints_o(raw_hints),.output_row_o(raw_row),.output_word_o(raw_word),.output_last_o(raw_last),
    .done_valid_o(raw_done),.done_ready_i(done_ready_i && !slot_valid),.*);
  always_ff @(posedge clk or posedge rst)begin
    if(rst)slot_valid<=0;else if(slot_ready)slot_valid<=raw_valid;
  end
  always_ff @(posedge clk)if(raw_valid && slot_ready)begin
    mask_r<=raw_hints;row_r<=raw_row;word_r<=raw_word;last_r<=raw_last;
  end
endmodule
`default_nettype wire
