// FIPS204 D=13 decomposition; canonical input 0..q-1.
// Pure combinational arithmetic. The shared process stage owns valid/tags.
`default_nettype none
module power2round (
  input wire logic [22:0] coefficient_i,
  output logic [9:0] high_o,
  output logic signed [13:0] low_o,
  output logic [12:0] packed_t0_o
);
  logic signed [14:0] low_wide;
  assign high_o=coefficient_i[22:13]+10'(coefficient_i[12:0]>13'd4096);
  assign low_wide=$signed({2'b00,coefficient_i[12:0]})-
    (coefficient_i[12:0]>13'd4096 ? 15'sd8192 : 15'sd0);
  assign low_o=14'(low_wide);
  assign packed_t0_o=13'(15'sd4096-low_wide);
endmodule
`default_nettype wire
