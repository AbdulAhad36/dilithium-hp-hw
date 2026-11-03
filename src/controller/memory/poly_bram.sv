// One published-size LightHD logical bank:1024 words,4*23 bits per word.
// Full-word writes;coefficient packing belongs to the producer adapter.
// Each port has two response slots (one RAM read register plus one skid slot).
// Registered occupancy cuts ready feedback while retaining unstalled word rate.
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
  logic a_pending_valid,a_skid_valid,a_pending_write,a_skid_write;
  logic [9:0] a_pending_address,a_skid_address;
  logic [91:0] a_ram_data,a_skid_data;
  assign a_response_valid_o=a_pending_valid || a_skid_valid;
  assign a_response_write_o=a_skid_valid?a_skid_write:a_pending_write;
  assign a_response_address_o=a_skid_valid?a_skid_address:a_pending_address;
  assign a_response_data_o=a_skid_valid?a_skid_data:a_ram_data;
  logic b_pending_valid,b_skid_valid,b_pending_write,b_skid_write;
  logic [9:0] b_pending_address,b_skid_address;
  logic [91:0] b_ram_data,b_skid_data;
  assign b_response_valid_o=b_pending_valid || b_skid_valid;
  assign b_response_write_o=b_skid_valid?b_skid_write:b_pending_write;
  assign b_response_address_o=b_skid_valid?b_skid_address:b_pending_address;
  assign b_response_data_o=b_skid_valid?b_skid_data:b_ram_data;
  // Registered occupancy cuts ready-to-ready feedback. Two response slots
  // sustain one request per clock until actual downstream congestion fills both.
  assign a_ready_o=!rst && !(a_pending_valid && a_skid_valid);
  assign collision_o=!rst && a_valid_i && a_ready_o && b_valid_i &&
                     a_address_i==b_address_i && (a_write_i || b_write_i);
  assign b_ready_o=!rst && !(b_pending_valid && b_skid_valid) && !collision_o;
  assign a_fire=a_valid_i && a_ready_o;
  assign b_fire=b_valid_i && b_ready_o;
  // One synchronous RAM read register and one skid register per port.
  // Payload has no reset;only response validity is invalidated.
  always @(posedge clk)begin
    if(a_fire)begin
      if(a_write_i)words_r[a_address_i]<=a_data_i;
      else a_ram_data<=words_r[a_address_i];
    end
    if(a_pending_valid && !a_skid_valid && !a_response_ready_i && a_fire)
      a_skid_data<=a_ram_data;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      a_pending_valid<=0;a_skid_valid<=0;
      a_pending_write<=0;a_skid_write<=0;
      a_pending_address<=0;a_skid_address<=0;
    end else begin
      if(a_skid_valid && a_response_ready_i)a_skid_valid<=0;
      if(a_pending_valid && !a_skid_valid && !a_response_ready_i && a_fire)begin
        a_skid_valid<=1;a_skid_write<=a_pending_write;
        a_skid_address<=a_pending_address;
      end
      if(a_fire)begin
        a_pending_valid<=1;a_pending_write<=a_write_i;
        a_pending_address<=a_address_i;
      end else if(!a_skid_valid && a_response_ready_i)a_pending_valid<=0;
    end
  end
  // One synchronous RAM read register and one skid register per port.
  // Payload has no reset;only response validity is invalidated.
  always @(posedge clk)begin
    if(b_fire)begin
      if(b_write_i)words_r[b_address_i]<=b_data_i;
      else b_ram_data<=words_r[b_address_i];
    end
    if(b_pending_valid && !b_skid_valid && !b_response_ready_i && b_fire)
      b_skid_data<=b_ram_data;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      b_pending_valid<=0;b_skid_valid<=0;
      b_pending_write<=0;b_skid_write<=0;
      b_pending_address<=0;b_skid_address<=0;
    end else begin
      if(b_skid_valid && b_response_ready_i)b_skid_valid<=0;
      if(b_pending_valid && !b_skid_valid && !b_response_ready_i && b_fire)begin
        b_skid_valid<=1;b_skid_write<=b_pending_write;
        b_skid_address<=b_pending_address;
      end
      if(b_fire)begin
        b_pending_valid<=1;b_pending_write<=b_write_i;
        b_pending_address<=b_address_i;
      end else if(!b_skid_valid && b_response_ready_i)b_pending_valid<=0;
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst && a_fire && b_fire && a_address_i==b_address_i && (a_write_i || b_write_i))
    $fatal(1,"Unserialized dual-port RAM collision");
`endif
endmodule
`default_nettype wire
