// One published-size LightHD logical bank:1024 words,4*23 bits per word.
// Full-word writes;coefficient packing belongs to the producer adapter.
// Both ports have one elastic response (read data or write acknowledgement).
`default_nettype none
module poly_bram (
  input wire logic clk,rst,
  input wire logic a_valid_i,a_write_i,
  input wire logic [9:0] a_address_i,
  input wire logic [91:0] a_data_i,
  output logic a_ready_o,a_response_valid_o,a_response_write_o,
  output logic [9:0] a_response_address_o,
  output logic [91:0] a_response_data_o,
  input wire logic a_response_ready_i,
  input wire logic b_valid_i,b_write_i,
  input wire logic [9:0] b_address_i,
  input wire logic [91:0] b_data_i,
  output logic b_ready_o,b_response_valid_o,b_response_write_o,
  output logic [9:0] b_response_address_o,
  output logic [91:0] b_response_data_o,
  input wire logic b_response_ready_i,
  output logic collision_o
);
  logic [91:0] words_r[1024];
  logic a_fire,b_fire;
  assign a_ready_o=!rst && (!a_response_valid_o || a_response_ready_i);
  // Serialize any same-address pair containing a write. Read/read may proceed
  // together. A has priority;this avoids device-specific mixed-port collisions.
  assign collision_o=!rst && a_valid_i && a_ready_o && b_valid_i &&
                     a_address_i==b_address_i && (a_write_i || b_write_i);
  assign b_ready_o=!rst && (!b_response_valid_o || b_response_ready_i) && !collision_o;
  assign a_fire=a_valid_i && a_ready_o;
  assign b_fire=b_valid_i && b_ready_o;
  // No reset on the array or read-data registers:allow synchronous dual-port
  // RAM inference. A read of never-written storage has unspecified data.
  always @(posedge clk)if(a_fire)begin
    if(a_write_i)words_r[a_address_i]<=a_data_i;
    else a_response_data_o<=words_r[a_address_i];
  end
  always @(posedge clk)if(b_fire)begin
    if(b_write_i)words_r[b_address_i]<=b_data_i;
    else b_response_data_o<=words_r[b_address_i];
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      a_response_valid_o<=0;a_response_write_o<=0;a_response_address_o<=0;
      b_response_valid_o<=0;b_response_write_o<=0;b_response_address_o<=0;
    end else begin
      if(a_response_valid_o && a_response_ready_i)a_response_valid_o<=0;
      if(b_response_valid_o && b_response_ready_i)b_response_valid_o<=0;
      if(a_fire)begin
        a_response_valid_o<=1;a_response_write_o<=a_write_i;a_response_address_o<=a_address_i;
      end
      if(b_fire)begin
        b_response_valid_o<=1;b_response_write_o<=b_write_i;b_response_address_o<=b_address_i;
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst && a_fire && b_fire && a_address_i==b_address_i && (a_write_i || b_write_i))
    $fatal(1,"Unserialized dual-port RAM collision");
`endif
endmodule
`default_nettype wire
