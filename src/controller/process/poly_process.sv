// Shared coefficient arithmetic for KeyGen and later polynomial processing.
// One elastic stage;the controller owns polynomial ordering and slot lifetime.
`default_nettype none
module poly_process (
  input wire logic clk,rst,
  input wire logic input_valid_i,
  output logic input_ready_o,
  input wire logic [1:0] input_op_i,
  input wire logic [22:0] input_a_i,input_b_i,
  input wire logic [15:0] input_id_i,
  input wire logic [7:0] input_index_i,
  input wire logic input_last_i,
  output logic output_valid_o,
  input wire logic output_ready_i,
  output logic output_error_o,
  output logic [1:0] output_op_o,
  output logic [22:0] output_residue_o,
  output logic [9:0] output_high_o,
  output logic signed [13:0] output_low_o,
  output logic [12:0] output_t0_o,
  output logic [15:0] output_id_o,
  output logic [7:0] output_index_o,
  output logic output_last_o
);
  localparam logic [23:0] Q=24'd8380417;
  logic error_next;
  logic [23:0] sum;
  logic [22:0] residue_next;
  logic [9:0] high_next;
  logic signed [14:0] low_wide;
  logic [12:0] packed_next;
  logic [9:0] rounded_high;
  logic signed [13:0] rounded_low;
  logic [12:0] rounded_t0;
  power2round rounding(.coefficient_i(input_a_i),.high_o(rounded_high),
    .low_o(rounded_low),.packed_t0_o(rounded_t0));
  assign input_ready_o=!rst && (!output_valid_o || output_ready_i);
  always_comb begin
    sum={1'b0,input_a_i}+{1'b0,input_b_i};
    residue_next=0;high_next=0;low_wide=0;packed_next=0;
    error_next=(input_op_i==3 || {1'b0,input_a_i}>=Q ||
      (input_op_i<2 && {1'b0,input_b_i}>=Q) || input_last_i!=(input_index_i==255));
    if(!error_next)case(input_op_i)
      0:residue_next=23'(sum>=Q?sum-Q:sum);
      1:residue_next=23'(input_a_i>=input_b_i ? {1'b0,input_a_i}-{1'b0,input_b_i} :
                          {1'b0,input_a_i}+Q-{1'b0,input_b_i});
      2:begin
        // D=13,with the positive tie retained: -4096 < low <=4096.
        high_next=rounded_high;
        low_wide=15'(rounded_low);
        packed_next=rounded_t0;
      end
      default:;
    endcase
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      output_valid_o<=0;output_error_o<=0;output_op_o<=0;output_residue_o<=0;
      output_high_o<=0;output_low_o<=0;output_t0_o<=0;
      output_id_o<=0;output_index_o<=0;output_last_o<=0;
    end else if(input_ready_o)begin
      output_valid_o<=input_valid_i;
      if(input_valid_i)begin
        output_error_o<=error_next;output_op_o<=input_op_i;
        output_residue_o<=residue_next;output_high_o<=high_next;
        output_low_o<=14'(low_wide);output_t0_o<=packed_next;
        output_id_o<=input_id_i;output_index_o<=input_index_i;output_last_o<=input_last_i;
      end
    end
  end
endmodule
`default_nettype wire
