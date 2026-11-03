// Three clients (NTT,sampling,Process/controller) share eight physical lanes.
// Sixteen ownership and eight deferred-completion bits;no polynomial tags.
// Commands reserve a selected set atomically per A/B port;other banks keep
// running independently. Owners retire on the real memory-done handshake.
`default_nettype none
module memory_router #(parameter bit COHERENT_PORTS=0) (
  input wire logic clk,rst,output logic idle_o,
  input wire logic [2:0][1:0] client_command_valid_i,
  output logic [2:0][1:0] client_command_ready_o,
  input wire logic [2:0][1:0][3:0] client_command_mask_i,client_command_write_i,
  input wire logic [2:0][1:0][3:0][9:0] client_command_base_i,
  input wire logic [2:0][1:0][3:0][10:0] client_command_words_i,
  input wire logic [2:0][1:0][3:0][1:0] client_command_mode_i,
  input wire logic [2:0][1:0][3:0] client_write_valid_i,
  output logic [2:0][1:0][3:0] client_write_ready_o,
  input wire logic [2:0][1:0][3:0][91:0] client_write_data_i,
  input wire logic [2:0][1:0][3:0][9:0] client_write_address_i,
  output logic [2:0][1:0][3:0] client_read_valid_o,
  input wire logic [2:0][1:0][3:0] client_read_ready_i,
  output logic [2:0][1:0][3:0][91:0] client_read_data_o,
  output logic [2:0][1:0][3:0][9:0] client_read_address_o,
  output logic [2:0][1:0][3:0] client_read_last_o,client_done_valid_o,client_done_error_o,
  input wire logic [2:0][1:0][3:0] client_done_ready_i,
  output logic [1:0] memory_command_valid_o,input wire logic [1:0] memory_command_ready_i,
  output logic [1:0][3:0] memory_command_mask_o,memory_command_write_o,
  output logic [1:0][3:0][9:0] memory_command_base_o,
  output logic [1:0][3:0][10:0] memory_command_words_o,
  output logic [1:0][3:0][1:0] memory_command_mode_o,
  output logic [1:0][3:0] memory_write_valid_o,input wire logic [1:0][3:0] memory_write_ready_i,
  output logic [1:0][3:0][91:0] memory_write_data_o,
  output logic [1:0][3:0][9:0] memory_write_address_o,
  input wire logic [1:0][3:0] memory_read_valid_i,
  output logic [1:0][3:0] memory_read_ready_o,
  input wire logic [1:0][3:0][91:0] memory_read_data_i,
  input wire logic [1:0][3:0][9:0] memory_read_address_i,
  input wire logic [1:0][3:0] memory_read_last_i,memory_done_valid_i,memory_done_error_i,
  output logic [1:0][3:0] memory_done_ready_o
);
  logic [1:0][3:0][1:0] owner_r;
  // A client can consume its completion while a same-lane renewal waits for
  // arbitration. Retain the physical REPORT/owner until that renewal wins.
  logic [1:0][3:0] retire_pending_r;
  logic [1:0][1:0] turn_r,selected;
  logic [1:0][3:0] effective_mask;
  assign idle_o=&owner_r;
  always_comb begin
    client_command_ready_o=0;client_write_ready_o=0;client_read_valid_o=0;
    client_read_address_o=0;client_read_last_o=0;
    // Physical RAM data is common wiring. Ownership qualifies VALID, not
    // the payload value when no transfer is offered. Consumers may only
    // accept a read word while their read_valid is asserted.
    for(int c=0;c<3;c++)for(int p=0;p<2;p++)for(int b=0;b<4;b++)
      client_read_data_o[c][p][b]=memory_read_data_i[p][b];
    client_done_valid_o=0;client_done_error_o=0;
    memory_command_valid_o=0;memory_command_mask_o=0;memory_command_write_o=0;
    memory_command_base_o=0;memory_command_words_o=0;memory_command_mode_o=0;
    memory_write_valid_o=0;memory_write_data_o=client_write_data_i[2];memory_write_address_o=0;memory_read_ready_o=0;memory_done_ready_o=0;
    selected='1;effective_mask=0;
    for(int p=0;p<2;p++)begin
      logic [2:0] eligible,grant;
      eligible=0;grant=0;
      for(int c=0;c<3;c++)begin
        logic available;logic [3:0] mask;
        mask=client_command_mask_i[c][p]==0?4'b1:client_command_mask_i[c][p];
        available=!rst;
        for(int b=0;b<4;b++)if(mask[b] && owner_r[p][b]!=3 &&
          !(owner_r[p][b]==c && memory_done_valid_i[p][b] &&
            (client_done_ready_i[c][p][b] || retire_pending_r[p][b])))available=0;
        eligible[c]=client_command_valid_i[c][p] && available;
      end
      case(turn_r[p])
        1:if(eligible[1])grant[1]=1;else if(eligible[2])grant[2]=1;else if(eligible[0])grant[0]=1;
        2:if(eligible[2])grant[2]=1;else if(eligible[0])grant[0]=1;else if(eligible[1])grant[1]=1;
        default:if(eligible[0])grant[0]=1;else if(eligible[1])grant[1]=1;else if(eligible[2])grant[2]=1;
      endcase
      selected[p]=grant[0]?2'd0:grant[1]?2'd1:grant[2]?2'd2:2'd3;
      memory_command_valid_o[p]=|grant;
      for(int c=0;c<3;c++)begin
        effective_mask[p]|=(client_command_mask_i[c][p]==0?4'b1:client_command_mask_i[c][p]) & {4{grant[c]}};
        memory_command_mask_o[p]|=client_command_mask_i[c][p] & {4{grant[c]}};
        memory_command_write_o[p]|=client_command_write_i[c][p] & {4{grant[c]}};
        memory_command_base_o[p]|=client_command_base_i[c][p] & {40{grant[c]}};
        memory_command_words_o[p]|=client_command_words_i[c][p] & {44{grant[c]}};
        memory_command_mode_o[p]|=client_command_mode_i[c][p] & {8{grant[c]}};
        client_command_ready_o[c][p]=grant[c] && (COHERENT_PORTS || memory_command_ready_i[p]);
      end
      for(int b=0;b<4;b++)if(!rst && owner_r[p][b]!=3)begin
        memory_write_valid_o[p][b]=client_write_valid_i[owner_r[p][b]][p][b];
        memory_write_data_o[p][b]=client_write_data_i[owner_r[p][b]][p][b];
        memory_write_address_o[p][b]=client_write_address_i[owner_r[p][b]][p][b];
        memory_read_ready_o[p][b]=client_read_ready_i[owner_r[p][b]][p][b];
        memory_done_ready_o[p][b]=client_done_ready_i[owner_r[p][b]][p][b] || retire_pending_r[p][b];
        // A pending same-lane renewal must win arbitration before retiring
        // the old burst. Otherwise a different free-bank command could win
        // this clock and leave an idle/unowned gap in the reserved lane.
        if(client_command_valid_i[owner_r[p][b]][p] &&
          (client_command_mask_i[owner_r[p][b]][p][b] ||
           (client_command_mask_i[owner_r[p][b]][p]==0 && b==0)) &&
          selected[p]!=owner_r[p][b])memory_done_ready_o[p][b]=0;
        client_write_ready_o[owner_r[p][b]][p][b]=memory_write_ready_i[p][b];
        client_read_valid_o[owner_r[p][b]][p][b]=memory_read_valid_i[p][b];
        client_read_address_o[owner_r[p][b]][p][b]=memory_read_address_i[p][b];
        client_read_last_o[owner_r[p][b]][p][b]=memory_read_last_i[p][b];
        client_done_valid_o[owner_r[p][b]][p][b]=memory_done_valid_i[p][b] && !retire_pending_r[p][b];
        client_done_error_o[owner_r[p][b]][p][b]=memory_done_error_i[p][b];
      end
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin owner_r<='1;turn_r<=0;retire_pending_r<=0;end
    else for(int p=0;p<2;p++)begin
      for(int b=0;b<4;b++)begin
        if(owner_r[p][b]!=3 && memory_done_valid_i[p][b] &&
          client_done_ready_i[owner_r[p][b]][p][b] && !memory_done_ready_o[p][b])retire_pending_r[p][b]<=1;
        if(memory_done_valid_i[p][b] && memory_done_ready_o[p][b])begin
          owner_r[p][b]<=3;retire_pending_r[p][b]<=0;
        end
        if(memory_command_valid_o[p] && (COHERENT_PORTS || memory_command_ready_i[p]) && effective_mask[p][b])begin
          owner_r[p][b]<=selected[p];retire_pending_r[p][b]<=0;
        end
      end
      if(memory_command_valid_o[p] && (COHERENT_PORTS || memory_command_ready_i[p]))turn_r[p]<=selected[p]==2?2'd0:selected[p]+1'b1;
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst)for(int p=0;p<2;p++)for(int b=0;b<4;b++)
    if(retire_pending_r[p][b] && (owner_r[p][b]==3 || !memory_done_valid_i[p][b]))
      $fatal(1,"Deferred bank retirement lost its physical REPORT/owner");
`endif
// synthesis translate_off
  always @(posedge clk)if(!rst && COHERENT_PORTS)for(int p=0;p<2;p++)
    if(memory_command_valid_o[p] && !memory_command_ready_i[p])
      $fatal(1,"Paired router granted a non-admissible physical command");
  // synthesis translate_on
endmodule
`default_nettype wire
