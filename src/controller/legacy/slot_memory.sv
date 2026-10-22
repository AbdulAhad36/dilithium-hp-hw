// Polynomial-slot pool. Payload RAM is not reset; metadata owns its validity.
`default_nettype none
module slot_memory #(
  parameter int SLOTS = 4,
  parameter int SLOT_W = (SLOTS > 1) ? $clog2(SLOTS) : 1
) (
  input wire logic clk, rst,
  input wire logic alloc_valid_i, alloc_core_i,
  input wire logic [15:0] alloc_id_i,
  input wire logic [1:0] alloc_mode_i, alloc_param_i,
  output logic alloc_ready_o,
  output logic [SLOT_W-1:0] alloc_slot_o,
  input wire logic write_valid_i, write_core_i, write_last_i,
  input wire logic [15:0] write_id_i,
  input wire logic [7:0] write_index_i,
  input wire logic [22:0] write_data_i,
  output logic write_ready_o,
  input wire logic finish_valid_i, finish_core_i,
  input wire logic [15:0] finish_id_i,
  input wire logic [2:0] finish_code_i,
  output logic finish_ready_o,
  input wire logic read_valid_i,
  input wire logic [SLOT_W-1:0] read_slot_i,
  input wire logic [7:0] read_index_i,
  output logic read_ready_o,
  output logic response_valid_o, response_error_o,
  output logic [SLOT_W-1:0] response_slot_o,
  output logic [7:0] response_index_o,
  output logic [22:0] response_data_o,
  output logic [15:0] response_id_o,
  output logic [1:0] response_mode_o, response_param_o,
  output logic response_ntt_domain_o,
  input wire logic response_ready_i,
  input wire logic release_valid_i,
  input wire logic [SLOT_W-1:0] release_slot_i,
  output logic release_ready_o,
  output logic [SLOTS-1:0] reserved_o, complete_o,
  output logic fault_o,
  // One sequential NTT reservation. Destination is always a distinct free slot.
  input wire logic exec_valid_i,
  output logic exec_ready_o,
  input wire logic [1:0] exec_op_i,
  input wire logic [SLOT_W-1:0] exec_a_slot_i,exec_b_slot_i,
  input wire logic [15:0] exec_a_id_i,exec_b_id_i,exec_id_i,
  output logic exec_response_valid_o,
  input wire logic exec_response_ready_i,
  output logic [2:0] exec_code_o,
  output logic [SLOT_W-1:0] exec_slot_o,
  input wire logic result_valid_i,result_last_i,
  output logic result_ready_o,
  input wire logic [7:0] result_index_i,
  input wire logic [22:0] result_data_i,
  input wire logic exec_done_i
);
  localparam logic [1:0] FREE=0, WRITING=1, COMPLETE=2, IN_USE=3;
  logic [1:0] state_r[SLOTS], mode_r[SLOTS], param_r[SLOTS];
  logic core_r[SLOTS], poison_r[SLOTS];
  logic [15:0] id_r[SLOTS];
  logic [8:0] count_r[SLOTS];
  logic compute_r[SLOTS],domain_r[SLOTS],small_r[SLOTS];
  logic exec_active_r;
  logic [1:0] exec_op_r;
  logic [SLOT_W-1:0] exec_a_r,exec_b_r,exec_dest_r;
  logic [22:0] payload_r[SLOTS*256];
  integer free_slot, write_slot, finish_slot;
  logic core_writing, write_good, read_good;
  logic alloc_fire, write_fire, finish_fire, read_fire, release_fire;
  logic exec_fire,result_fire,result_good;
  logic [2:0] request_code;

  always_comb begin
    free_slot=-1;write_slot=-1;finish_slot=-1;core_writing=0;
    reserved_o='0;complete_o='0;
    for(int s=0;s<SLOTS;s++)begin
      reserved_o[s]=(state_r[s]!=FREE);
      complete_o[s]=(state_r[s]==COMPLETE);
      if(state_r[s]==FREE && free_slot<0)free_slot=s;
      if(state_r[s]==WRITING && !compute_r[s])begin
        if(core_r[s]==alloc_core_i)core_writing=1;
        if(core_r[s]==write_core_i && id_r[s]==write_id_i)write_slot=s;
        if(core_r[s]==finish_core_i && id_r[s]==finish_id_i)finish_slot=s;
      end
    end
    alloc_slot_o=(free_slot<0)?'0:SLOT_W'(free_slot);
    alloc_ready_o=!rst && free_slot>=0 && !core_writing && !exec_valid_i;
    write_ready_o=!rst && write_slot>=0 && !result_valid_i;
    // Consume malformed owned writes, poison the slot, then drain the job.
    // A poisoned job can never publish COMPLETE, even with a success status.
    write_good=0;
    if(write_slot>=0)write_good=!poison_r[write_slot] && count_r[write_slot]<256 &&
      count_r[write_slot]=={1'b0,write_index_i} &&
      write_last_i==(count_r[write_slot]==255) && write_data_i<23'd8380417;
    finish_ready_o=!rst && finish_slot>=0;
    // One synchronous elastic read response; a stalled response is immutable.
    read_ready_o=!rst && (!response_valid_o || response_ready_i) && !exec_valid_i;
    read_good=0;
    if(int'(read_slot_i)<SLOTS)read_good=(state_r[read_slot_i]==COMPLETE || state_r[read_slot_i]==IN_USE);
    request_code=1;
    if(int'(exec_a_slot_i)<SLOTS && (exec_op_i!=2 || int'(exec_b_slot_i)<SLOTS))begin
      if(state_r[exec_a_slot_i]==COMPLETE && id_r[exec_a_slot_i]==exec_a_id_i &&
         (exec_op_i!=2 || (state_r[exec_b_slot_i]==COMPLETE && id_r[exec_b_slot_i]==exec_b_id_i)))begin
        request_code=0;
        if(((exec_op_i==0 || exec_op_i==3) && domain_r[exec_a_slot_i]) ||
           ((exec_op_i==1 || exec_op_i==2) && !domain_r[exec_a_slot_i]) ||
           (exec_op_i==3 && !small_r[exec_a_slot_i]) ||
           (exec_op_i==2 && (!domain_r[exec_b_slot_i] || param_r[exec_a_slot_i]!=param_r[exec_b_slot_i])))
          request_code=2;
      end
    end
    exec_ready_o=!rst && !exec_active_r && !exec_response_valid_o && !response_valid_o &&
      (request_code!=0 || free_slot>=0);
    exec_fire=exec_valid_i && exec_ready_o;
    result_ready_o=!rst && exec_active_r;
    result_fire=result_valid_i && result_ready_o;
    result_good=exec_active_r && !poison_r[exec_dest_r] && count_r[exec_dest_r]<256 &&
      count_r[exec_dest_r]=={1'b0,result_index_i} &&
      result_last_i==(count_r[exec_dest_r]==255) && result_data_i<23'd8380417;
    release_ready_o=0;
    if(!rst && int'(release_slot_i)<SLOTS)begin
      release_ready_o=state_r[release_slot_i]==COMPLETE && !exec_fire &&
        !(response_valid_o && response_slot_o==release_slot_i) &&
        !(read_valid_i && read_ready_o && read_slot_i==release_slot_i);
    end
    alloc_fire=alloc_valid_i && alloc_ready_o;
    write_fire=write_valid_i && write_ready_o;
    finish_fire=finish_valid_i && finish_ready_o;
    read_fire=read_valid_i && read_ready_o;
    release_fire=release_valid_i && release_ready_o;
  end

  // Keep RAM writes/reads outside reset logic for FPGA memory inference.
  always_ff @(posedge clk)begin
    if(result_fire && result_good)
      payload_r[int'(exec_dest_r)*256+int'(result_index_i)]<=result_data_i;
    else if(write_fire && write_good)
      payload_r[write_slot*256+int'(write_index_i)]<=write_data_i;
    if(read_fire && read_good)
      response_data_o<=payload_r[int'(read_slot_i)*256+int'(read_index_i)];
  end

  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      fault_o<=0;response_valid_o<=0;response_error_o<=0;
      exec_active_r<=0;exec_op_r<=0;exec_a_r<='0;exec_b_r<='0;exec_dest_r<='0;
      exec_response_valid_o<=0;exec_code_o<=0;exec_slot_o<='0;
      response_slot_o<='0;response_index_o<=0;response_id_o<=0;
      response_mode_o<=0;response_param_o<=0;response_ntt_domain_o<=0;
      for(int s=0;s<SLOTS;s++)begin
        state_r[s]<=FREE;core_r[s]<=0;id_r[s]<=0;mode_r[s]<=0;param_r[s]<=0;
        count_r[s]<=0;poison_r[s]<=0;
        compute_r[s]<=0;domain_r[s]<=0;small_r[s]<=1;
      end
    end else begin
      if(response_valid_o && response_ready_i)response_valid_o<=0;
      if(read_fire)begin
        response_valid_o<=1;response_error_o<=!read_good;
        response_slot_o<=read_slot_i;response_index_o<=read_index_i;
        response_id_o<=read_good?id_r[read_slot_i]:16'd0;
        response_mode_o<=read_good?mode_r[read_slot_i]:2'd0;
        response_param_o<=read_good?param_r[read_slot_i]:2'd0;
        response_ntt_domain_o<=read_good && domain_r[read_slot_i];
      end
      if(alloc_fire)begin
        state_r[free_slot]<=WRITING;core_r[free_slot]<=alloc_core_i;
        id_r[free_slot]<=alloc_id_i;mode_r[free_slot]<=alloc_mode_i;
        param_r[free_slot]<=alloc_param_i;count_r[free_slot]<=0;poison_r[free_slot]<=0;
        compute_r[free_slot]<=0;domain_r[free_slot]<=(alloc_mode_i==0);small_r[free_slot]<=1;
      end
      if(write_fire)begin
        if(write_good)begin
          count_r[write_slot]<=count_r[write_slot]+1'b1;
          small_r[write_slot]<=small_r[write_slot] && (write_data_i<=4 || write_data_i>=23'd8380413);
        end
        else begin poison_r[write_slot]<=1;fault_o<=1;end
      end
      if(finish_fire)begin
        // Success requires an earlier completed write, not a same-edge guess.
        // The producer emits status only after all coefficient handshakes.
        if(finish_code_i==0 && count_r[finish_slot]==256 &&
           !poison_r[finish_slot] && !(write_fire && write_slot==finish_slot))
          state_r[finish_slot]<=COMPLETE;
        else begin
          state_r[finish_slot]<=FREE;
          if(finish_code_i==0)fault_o<=1;
        end
      end
      if(release_fire)state_r[release_slot_i]<=FREE;
      if(exec_response_valid_o && exec_response_ready_i)exec_response_valid_o<=0;
      if(exec_fire)begin
        exec_response_valid_o<=1;exec_code_o<=request_code;
        exec_slot_o<=(request_code==0)?SLOT_W'(free_slot):'0;
        if(request_code==0)begin
          exec_active_r<=1;exec_op_r<=exec_op_i;exec_a_r<=exec_a_slot_i;exec_b_r<=exec_b_slot_i;
          exec_dest_r<=SLOT_W'(free_slot);
          state_r[exec_a_slot_i]<=IN_USE;
          if(exec_op_i==2)state_r[exec_b_slot_i]<=IN_USE;
          state_r[free_slot]<=WRITING;compute_r[free_slot]<=1;
          id_r[free_slot]<=exec_id_i;core_r[free_slot]<=0;
          mode_r[free_slot]<=mode_r[exec_a_slot_i];param_r[free_slot]<=param_r[exec_a_slot_i];
          domain_r[free_slot]<=(exec_op_i!=1);small_r[free_slot]<=1;
          count_r[free_slot]<=0;poison_r[free_slot]<=0;
        end
      end
      if(result_fire)begin
        if(result_good)begin
          count_r[exec_dest_r]<=count_r[exec_dest_r]+1'b1;
          small_r[exec_dest_r]<=small_r[exec_dest_r] && (result_data_i<=4 || result_data_i>=23'd8380413);
        end else begin poison_r[exec_dest_r]<=1;fault_o<=1;end
      end
      if(exec_done_i)begin
        if(exec_active_r)begin
          state_r[exec_a_r]<=COMPLETE;
          if(exec_op_r==2)state_r[exec_b_r]<=COMPLETE;
          if(count_r[exec_dest_r]==256 && !poison_r[exec_dest_r] && !result_fire)
            state_r[exec_dest_r]<=COMPLETE;
          else begin state_r[exec_dest_r]<=FREE;fault_o<=1;end
          exec_active_r<=0;
        end else fault_o<=1;
      end
      if(result_valid_i && !exec_active_r)fault_o<=1;
      if(write_valid_i && write_slot<0)fault_o<=1;
      if(finish_valid_i && finish_slot<0)fault_o<=1;
    end
  end
`ifndef SYNTHESIS
  initial begin
    if(SLOTS<1 || SLOT_W<((SLOTS>1)?$clog2(SLOTS):1))
      $fatal(1,"Invalid polynomial memory parameters");
  end
`endif
endmodule
`default_nettype wire
