// Three clients (NTT,sampling,Process/controller) share eight physical lanes.
// Sixteen ownership and eight deferred-completion bits;no polynomial tags.
// Commands reserve a selected set atomically per A/B port;other banks keep
// running independently. Owners retire on the real memory-done handshake.
`default_nettype none
module memory_router #(parameter bit COHERENT_PORTS=0,
  parameter bit REGISTER_COMMANDS=0,parameter bit ONEHOT_OWNERS=0,
  parameter bit REGISTER_RETIREMENT=0) (
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
  (* preserve *) logic [1:0][3:0][2:0] owner_hot_r;
  logic [1:0][2:0] chosen_hot;
  logic [2:0][1:0] staged_valid_r,command_valid;
  logic [2:0][1:0][99:0] staged_payload_r;
  logic [2:0][1:0][3:0] staged_lane_mask_r,request_lane_mask;
  logic [2:0][1:0][3:0] command_mask,command_write;
  logic [2:0][1:0][3:0][9:0] command_base;
  logic [2:0][1:0][3:0][10:0] command_words;
  logic [2:0][1:0][3:0][1:0] command_mode;
  // Capture an offered descriptor before arbitration. READY still denotes
  // actual grant/reservation, so no client sees speculative acceptance.
  // Withdrawal (including fatal quarantine) cancels an unaccepted offer.
  always_comb begin
    command_valid=client_command_valid_i;
    command_mask=client_command_mask_i;command_write=client_command_write_i;
    command_base=client_command_base_i;command_words=client_command_words_i;
    command_mode=client_command_mode_i;
    if(REGISTER_COMMANDS)begin
      command_valid=REGISTER_RETIREMENT?staged_valid_r:
        client_command_valid_i & staged_valid_r;
      for(int c=0;c<3;c++)for(int p=0;p<2;p++)
        {command_mask[c][p],command_write[c][p],command_base[c][p],
         command_words[c][p],command_mode[c][p]}=staged_payload_r[c][p];
    end
    for(int c=0;c<3;c++)for(int p=0;p<2;p++)
      request_lane_mask[c][p]=REGISTER_RETIREMENT?staged_lane_mask_r[c][p]:
        command_mask[c][p]==0?4'b0001:command_mask[c][p];
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)staged_valid_r<=0;
    else if(REGISTER_COMMANDS)for(int c=0;c<3;c++)for(int p=0;p<2;p++)begin
      if(!client_command_valid_i[c][p] || client_command_ready_o[c][p])staged_valid_r[c][p]<=0;
      else if(!staged_valid_r[c][p])staged_valid_r[c][p]<=1;
    end
  end
  always_ff @(posedge clk)if(!rst && REGISTER_COMMANDS)
    for(int c=0;c<3;c++)for(int p=0;p<2;p++)
      if(client_command_valid_i[c][p] && !staged_valid_r[c][p])begin
        staged_payload_r[c][p]<={client_command_mask_i[c][p],client_command_write_i[c][p],
          client_command_base_i[c][p],client_command_words_i[c][p],client_command_mode_i[c][p]};
        staged_lane_mask_r[c][p]<=client_command_mask_i[c][p]==0?4'b0001:client_command_mask_i[c][p];
      end
  // A client can consume its completion while a same-lane renewal waits for
  // arbitration. Retain the physical REPORT/owner until that renewal wins.
  logic [1:0][3:0] retire_pending_r;
  logic [1:0][3:0] legacy_retire_r,completion_ack_r;
  logic [1:0][1:0] turn_r,selected;
  logic [1:0][3:0] effective_mask;
  assign retire_pending_r=REGISTER_RETIREMENT?
    (completion_ack_r & memory_done_valid_i):legacy_retire_r;
  // Each lane records the client acknowledgement independently of grant
  // selection. The physical scheduler leaves REPORT for at least one
  // clock on release or renewal, which clears the old acknowledgement.
  always_ff @(posedge clk or posedge rst)begin
    if(rst)completion_ack_r<=0;
    else if(REGISTER_RETIREMENT)for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
      if(!memory_done_valid_i[p][b])completion_ack_r[p][b]<=0;
      else for(int c=0;c<3;c++)if(owner_hot_r[p][b][c] && client_done_ready_i[c][p][b])
        completion_ack_r[p][b]<=1;
    end
  end
  assign idle_o=(&owner_r) && (!REGISTER_COMMANDS || staged_valid_r==0);
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
    selected='1;effective_mask=0;chosen_hot=0;
    for(int p=0;p<2;p++)begin
      logic [2:0] eligible,grant,grant_live;
      eligible=0;grant=0;
      for(int c=0;c<3;c++)begin
        logic available;logic [3:0] mask;
        mask=request_lane_mask[c][p];
        available=!rst;
        for(int b=0;b<4;b++)if(mask[b])begin
          if(REGISTER_RETIREMENT)begin
            if((|owner_hot_r[p][b]) && !(owner_hot_r[p][b][c] && retire_pending_r[p][b]))
              available=0;
          end else if(owner_r[p][b]!=3 && !(owner_r[p][b]==c && memory_done_valid_i[p][b] &&
            (client_done_ready_i[c][p][b] || retire_pending_r[p][b])))available=0;
        end
        eligible[c]=command_valid[c][p] && available;
      end
      case(turn_r[p])
        1:if(eligible[1])grant[1]=1;else if(eligible[2])grant[2]=1;else if(eligible[0])grant[0]=1;
        2:if(eligible[2])grant[2]=1;else if(eligible[0])grant[0]=1;else if(eligible[1])grant[1]=1;
        default:if(eligible[0])grant[0]=1;else if(eligible[1])grant[1]=1;else if(eligible[2])grant[2]=1;
      endcase
      selected[p]=grant[0]?2'd0:grant[1]?2'd1:grant[2]?2'd2:2'd3;
      chosen_hot[p]=grant;
      for(int c=0;c<3;c++)
        grant_live[c]=grant[c] && (!REGISTER_RETIREMENT || client_command_valid_i[c][p]);
      memory_command_valid_o[p]=|grant_live;
      for(int c=0;c<3;c++)begin
        effective_mask[p]|=request_lane_mask[c][p] & {4{grant[c]}};
        memory_command_mask_o[p]|=command_mask[c][p] & {4{grant[c]}};
        memory_command_write_o[p]|=command_write[c][p] & {4{grant[c]}};
        memory_command_base_o[p]|=command_base[c][p] & {40{grant[c]}};
        memory_command_words_o[p]|=command_words[c][p] & {44{grant[c]}};
        memory_command_mode_o[p]|=command_mode[c][p] & {8{grant[c]}};
        client_command_ready_o[c][p]=grant_live[c] && (COHERENT_PORTS || memory_command_ready_i[p]);
      end
      for(int b=0;b<4;b++)if(!rst && !ONEHOT_OWNERS && owner_r[p][b]!=3)begin
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
      if(ONEHOT_OWNERS)for(int b=0;b<4;b++)for(int c=0;c<3;c++)
        if(!rst && owner_hot_r[p][b][c])begin
          memory_write_valid_o[p][b]=client_write_valid_i[c][p][b];
          memory_write_data_o[p][b]=client_write_data_i[c][p][b];
          memory_write_address_o[p][b]=client_write_address_i[c][p][b];
          memory_read_ready_o[p][b]=client_read_ready_i[c][p][b];
          if(REGISTER_RETIREMENT)begin
            // An offer present on the acknowledgement edge is staged
            // before retirement. Hold an in-place renewal until it wins.
            memory_done_ready_o[p][b]=retire_pending_r[p][b] &&
              (!(staged_valid_r[c][p] && request_lane_mask[c][p][b]) || grant_live[c]);
          end else begin
            memory_done_ready_o[p][b]=client_done_ready_i[c][p][b] || retire_pending_r[p][b];
            if(client_command_valid_i[c][p] &&
              (client_command_mask_i[c][p][b] || (client_command_mask_i[c][p]==0 && b==0)) &&
              !grant[c])memory_done_ready_o[p][b]=0;
          end
          client_write_ready_o[c][p][b]=memory_write_ready_i[p][b];
          client_read_valid_o[c][p][b]=memory_read_valid_i[p][b];
          client_read_address_o[c][p][b]=memory_read_address_i[p][b];
          client_read_last_o[c][p][b]=memory_read_last_i[p][b];
          client_done_valid_o[c][p][b]=memory_done_valid_i[p][b] && !retire_pending_r[p][b];
          client_done_error_o[c][p][b]=memory_done_error_i[p][b];
        end
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin owner_r<='1;owner_hot_r<=0;turn_r<=0;legacy_retire_r<=0;end
    else for(int p=0;p<2;p++)begin
      for(int b=0;b<4;b++)begin
        if(!REGISTER_RETIREMENT && owner_r[p][b]!=3 && memory_done_valid_i[p][b] &&
          client_done_ready_i[owner_r[p][b]][p][b] && !memory_done_ready_o[p][b])legacy_retire_r[p][b]<=1;
        if(memory_done_valid_i[p][b] && memory_done_ready_o[p][b])begin
          owner_r[p][b]<=3;owner_hot_r[p][b]<=0;legacy_retire_r[p][b]<=0;
        end
        if(memory_command_valid_o[p] && (COHERENT_PORTS || memory_command_ready_i[p]) && effective_mask[p][b])begin
          owner_r[p][b]<=selected[p];owner_hot_r[p][b]<=chosen_hot[p];legacy_retire_r[p][b]<=0;
        end
      end
      if(memory_command_valid_o[p] && (COHERENT_PORTS || memory_command_ready_i[p]))turn_r[p]<=selected[p]==2?2'd0:selected[p]+1'b1;
    end
  end
`ifndef SYNTHESIS
  initial if(REGISTER_RETIREMENT && !(REGISTER_COMMANDS && ONEHOT_OWNERS && COHERENT_PORTS))
    $fatal(1,"Registered retirement needs staged commands and a coherent one-hot router");
  always @(posedge clk)if(!rst && ONEHOT_OWNERS)for(int p=0;p<2;p++)for(int b=0;b<4;b++)
    if(owner_hot_r[p][b] !== (owner_r[p][b]==3?3'b000:(3'b001<<owner_r[p][b])))
      $fatal(1,"Registered one-hot memory owner disagrees with binary owner");
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
