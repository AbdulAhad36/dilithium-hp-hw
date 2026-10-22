// Sampling ownership and natural-order4x23 packing over LightHD's four banks.
// Descriptors name an aligned64-word region;the main schedule chooses roles.
// Port A writes packed sampler words;port B serves checked word readback.
`default_nettype none
module memory (
  input wire logic clk,rst,
  input wire logic alloc_valid_i,alloc_core_i,
  input wire logic [1:0] alloc_bank_i,alloc_mode_i,alloc_param_i,
  input wire logic [3:0] alloc_region_i,
  input wire logic [15:0] alloc_id_i,
  // Sequential compute clients share the packer after sampling has drained.
  input wire logic alloc_compute_i,alloc_ntt_domain_i,alloc_rewrite_i,
  output logic alloc_ready_o,
  input wire logic write_valid_i,write_core_i,write_last_i,
  input wire logic [15:0] write_id_i,
  input wire logic [7:0] write_index_i,
  input wire logic [22:0] write_data_i,
  output logic write_ready_o,
  input wire logic finish_valid_i,finish_core_i,
  input wire logic [15:0] finish_id_i,
  input wire logic [2:0] finish_code_i,
  output logic finish_ready_o,
  input wire logic read_valid_i,
  input wire logic [1:0] read_bank_i,
  input wire logic [3:0] read_region_i,
  input wire logic [5:0] read_word_i,
  output logic read_ready_o,response_valid_o,response_error_o,
  output logic [1:0] response_bank_o,response_mode_o,response_param_o,
  output logic [3:0] response_region_o,
  output logic [5:0] response_word_o,
  output logic [91:0] response_data_o,
  output logic [15:0] response_id_o,
  output logic response_ntt_domain_o,response_small_o,
  input wire logic response_ready_i,
  input wire logic release_valid_i,
  input wire logic [1:0] release_bank_i,
  input wire logic [3:0] release_region_i,
  output logic release_ready_o,
  output logic [63:0] reserved_o,complete_o,
  output logic fault_o
);
  localparam logic [1:0] FREE=0,WRITING=1,COMPLETE=2;
  logic [1:0] state_r[64],mode_r[64],param_r[64];
  logic [15:0] id_r[64];logic domain_r[64],small_r[64],rewrite_r[64];
  logic [8:0] count_r[64];
  logic [1:0] context_valid_r,word_valid_r,word_sent_r;
  logic [5:0] context_region_r[2],word_index_r[2];
  logic [91:0] word_r[2],next_word;
  logic [6:0] acknowledged_r[2];
  logic [3:0] bank_pending_r;logic bank_owner_r[4];
  logic [1:0][3:0] request_valid,request_write,request_ready,response_valid,response_write,response_ready;
  logic [1:0][3:0][9:0] request_address,response_address;
  logic [1:0][3:0][91:0] request_data,response_data;
  logic [3:0] collisions;
  logic [1:0] read_state_r;
  localparam logic [1:0] READ_IDLE=0,READ_WAIT=1,READ_RESPONSE=2;
  logic [5:0] alloc_region,write_region,finish_region,read_region,release_region;
  logic write_owner_good,write_good,finish_owner_good,read_good;
  logic alloc_fire,write_fire,finish_fire,read_fire,release_fire;
  assign alloc_region={alloc_bank_i,alloc_region_i};
  assign write_region=context_region_r[write_core_i];
  assign finish_region=context_region_r[finish_core_i];
  assign read_region={read_bank_i,read_region_i};
  assign release_region={release_bank_i,release_region_i};
  assign alloc_ready_o=!rst && !fault_o && !context_valid_r[alloc_core_i] &&
    (alloc_rewrite_i ? (alloc_compute_i && state_r[alloc_region]==COMPLETE && read_state_r==READ_IDLE) : state_r[alloc_region]==FREE);
  assign write_owner_good=context_valid_r[write_core_i] && id_r[write_region]==write_id_i;
  assign write_ready_o=!rst && !fault_o && write_owner_good && !word_valid_r[write_core_i];
  assign write_good=count_r[write_region]<256 && count_r[write_region]=={1'b0,write_index_i} &&
    write_last_i==(write_index_i==255) && write_data_i<23'd8380417;
  assign finish_owner_good=context_valid_r[finish_core_i] && id_r[finish_region]==finish_id_i;
  assign finish_ready_o=!rst && !fault_o && finish_owner_good && !word_valid_r[finish_core_i] &&
    !word_sent_r[finish_core_i] && (finish_code_i!=0 ||
    (count_r[finish_region]==256 && acknowledged_r[finish_core_i]==64));
  // Destructive sequential rewrite: only untouched words can be read. The
  // process controller caches a whole source word before writing any lane.
  assign read_good=state_r[read_region]==COMPLETE ||
    (state_r[read_region]==WRITING && rewrite_r[read_region] &&
      {3'd0,read_word_i,2'b00}>={2'd0,count_r[read_region]});
  assign read_ready_o=!rst && !fault_o && read_state_r==READ_IDLE &&
    (!read_good || request_ready[1][read_bank_i]);
  assign response_valid_o=!rst && !fault_o && read_state_r==READ_RESPONSE;
  assign release_ready_o=!rst && !fault_o && state_r[release_region]==COMPLETE &&
    !(read_state_r!=READ_IDLE && {response_bank_o,response_region_o}==release_region) &&
    !(read_valid_i && read_ready_o && read_region==release_region);
  assign alloc_fire=alloc_valid_i && alloc_ready_o;
  assign write_fire=write_valid_i && write_ready_o;
  assign finish_fire=finish_valid_i && finish_ready_o;
  assign read_fire=read_valid_i && read_ready_o;
  assign release_fire=release_valid_i && release_ready_o;
  always_comb begin
    next_word=word_r[write_core_i];next_word[23*write_index_i[1:0]+:23]=write_data_i;
    reserved_o=0;complete_o=0;
    for(int s=0;s<64;s++)begin reserved_o[s]=state_r[s]!=FREE;complete_o[s]=state_r[s]==COMPLETE;end
    request_valid='0;request_write='0;request_address='0;request_data='0;response_ready='0;
    for(int b=0;b<4;b++)begin
      if(!rst && !fault_o && !bank_pending_r[b])begin
        if(context_valid_r[0] && word_valid_r[0] && !word_sent_r[0] && context_region_r[0][5:4]==2'(b))begin
          request_valid[0][b]=1;request_write[0][b]=1;
          request_address[0][b]={context_region_r[0][3:0],word_index_r[0]};request_data[0][b]=word_r[0];
        end else if(context_valid_r[1] && word_valid_r[1] && !word_sent_r[1] && context_region_r[1][5:4]==2'(b))begin
          request_valid[0][b]=1;request_write[0][b]=1;
          request_address[0][b]={context_region_r[1][3:0],word_index_r[1]};request_data[0][b]=word_r[1];
        end
      end
      response_ready[0][b]=!rst && !fault_o && bank_pending_r[b];
    end
    if(!rst && !fault_o && read_state_r==READ_IDLE && read_valid_i && read_good)begin
      request_valid[1][read_bank_i]=1;request_address[1][read_bank_i]={read_region_i,read_word_i};
    end
    if(!rst && !fault_o && read_state_r==READ_WAIT)response_ready[1][response_bank_o]=1;
  end
  memory_banks banks(
    .clk(clk),.rst(rst),.request_valid_i(request_valid),.request_write_i(request_write),
    .request_address_i(request_address),.request_data_i(request_data),.request_ready_o(request_ready),
    .response_valid_o(response_valid),.response_write_o(response_write),.response_address_o(response_address),
    .response_data_o(response_data),.response_ready_i(response_ready),.collision_o(collisions)
  );
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      context_valid_r<=0;word_valid_r<=0;word_sent_r<=0;bank_pending_r<=0;
      fault_o<=0;read_state_r<=READ_IDLE;response_error_o<=0;response_bank_o<=0;response_region_o<=0;
      response_word_o<=0;response_data_o<=0;response_id_o<=0;response_mode_o<=0;response_param_o<=0;
      response_ntt_domain_o<=0;response_small_o<=0;
      for(int c=0;c<2;c++)begin context_region_r[c]<=0;word_index_r[c]<=0;word_r[c]<=0;acknowledged_r[c]<=0;end
      for(int b=0;b<4;b++)bank_owner_r[b]<=0;
      for(int s=0;s<64;s++)begin state_r[s]<=FREE;mode_r[s]<=0;param_r[s]<=0;id_r[s]<=0;domain_r[s]<=0;small_r[s]<=1;rewrite_r[s]<=0;count_r[s]<=0;end
    end else begin
      if(alloc_fire)begin
        state_r[alloc_region]<=WRITING;mode_r[alloc_region]<=alloc_mode_i;param_r[alloc_region]<=alloc_param_i;
        id_r[alloc_region]<=alloc_id_i;
        domain_r[alloc_region]<=alloc_compute_i ? alloc_ntt_domain_i : alloc_mode_i==0;
        small_r[alloc_region]<=1;count_r[alloc_region]<=0;
        rewrite_r[alloc_region]<=alloc_rewrite_i;
        context_valid_r[alloc_core_i]<=1;context_region_r[alloc_core_i]<=alloc_region;
        word_valid_r[alloc_core_i]<=0;word_sent_r[alloc_core_i]<=0;acknowledged_r[alloc_core_i]<=0;
      end
      if(write_fire)begin
        if(write_good)begin
          word_r[write_core_i]<=next_word;count_r[write_region]<=count_r[write_region]+9'd1;
          small_r[write_region]<=small_r[write_region] && (write_data_i<=4 || write_data_i>=23'd8380413);
          if(write_index_i[1:0]==3)begin word_valid_r[write_core_i]<=1;word_index_r[write_core_i]<=write_index_i[7:2];end
        end else fault_o<=1;
      end
      if(write_valid_i && !write_owner_good)fault_o<=1;
      for(int b=0;b<4;b++)begin
        if(request_valid[0][b] && request_ready[0][b])begin
          bank_pending_r[b]<=1;
          if(context_valid_r[0] && word_valid_r[0] && !word_sent_r[0] && context_region_r[0][5:4]==2'(b))begin
            bank_owner_r[b]<=0;word_sent_r[0]<=1;
          end else begin bank_owner_r[b]<=1;word_sent_r[1]<=1;end
        end
        if(response_valid[0][b] && response_ready[0][b])begin
          if(!response_write[0][b] || response_address[0][b]!={context_region_r[bank_owner_r[b]][3:0],word_index_r[bank_owner_r[b]]})fault_o<=1;
          bank_pending_r[b]<=0;word_valid_r[bank_owner_r[b]]<=0;word_sent_r[bank_owner_r[b]]<=0;
          acknowledged_r[bank_owner_r[b]]<=acknowledged_r[bank_owner_r[b]]+7'd1;
        end
      end
      if(finish_valid_i && (!finish_owner_good || (finish_code_i==0 && count_r[finish_region]!=256)))fault_o<=1;
      if(finish_fire)begin
        state_r[finish_region]<=finish_code_i==0 ? COMPLETE : FREE;
        rewrite_r[finish_region]<=0;
        context_valid_r[finish_core_i]<=0;
      end
      if(release_fire)state_r[release_region]<=FREE;
      if(response_valid_o && response_ready_i)read_state_r<=READ_IDLE;
      if(read_fire)begin
        response_bank_o<=read_bank_i;response_region_o<=read_region_i;response_word_o<=read_word_i;
        response_error_o<=!read_good;response_id_o<=read_good?id_r[read_region]:16'd0;
        response_mode_o<=read_good?mode_r[read_region]:2'd0;response_param_o<=read_good?param_r[read_region]:2'd0;
        response_ntt_domain_o<=read_good && domain_r[read_region];response_small_o<=read_good && small_r[read_region];
        if(read_good)read_state_r<=READ_WAIT;
        else begin read_state_r<=READ_RESPONSE;response_data_o<=0;end
      end
      if(read_state_r==READ_WAIT && response_valid[1][response_bank_o])begin
        if(response_write[1][response_bank_o] || response_address[1][response_bank_o]!={response_region_o,response_word_o})fault_o<=1;
        response_data_o<=response_data[1][response_bank_o];read_state_r<=READ_RESPONSE;
      end
    end
  end
endmodule
`default_nettype wire
