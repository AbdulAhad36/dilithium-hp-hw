// Figure1/2 sampler write port:B writes tagged words while NTT reads A.
// Two Keccak contexts form a bounded batch of one or two polynomials. Their
// compact/full words may interleave on the SAME B bank without new payload RAM.
`default_nettype none
module sampler_writer (
  input wire logic clk,rst,job_valid_i,output logic job_ready_o,
  input wire logic job_core_i,job_batch_last_i,input wire logic [1:0] job_mode_i,job_bank_i,
  input wire logic [9:0] job_base_i,input wire logic [15:0] job_id_i,
  input wire logic packet_valid_i,output logic packet_ready_o,
  input wire logic packet_core_i,packet_last_i,
  input wire logic [15:0] packet_id_i,input wire logic [7:0] packet_index_i,
  input wire logic [91:0] packet_data_i,input wire logic [4:0] packet_count_i,
  input wire logic status_valid_i,status_core_i,input wire logic [15:0] status_id_i,
  input wire logic [2:0] status_code_i,output logic status_ready_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic done_core_o,output logic [15:0] done_id_o,output logic [2:0] done_code_o,
  output logic fault_o,output logic [1:0] active_o,output logic idle_o,
  output logic [1:0] memory_command_valid_o,input wire logic [1:0] memory_command_ready_i,
  output logic [1:0][3:0] memory_command_mask_o,memory_command_write_o,
  output logic [1:0][3:0][9:0] memory_command_base_o,
  output logic [1:0][3:0][10:0] memory_command_words_o,
  output logic [1:0][3:0][1:0] memory_command_mode_o,
  output logic [1:0][3:0] memory_write_valid_o,input wire logic [1:0][3:0] memory_write_ready_i,
  output logic [1:0][3:0][91:0] memory_write_data_o,
  output logic [1:0][3:0][9:0] memory_write_address_o,
  input wire logic [1:0][3:0] memory_done_valid_i,memory_done_error_i,
  output logic [1:0][3:0] memory_done_ready_o
);
  logic [1:0] active_r,secret_r,regroup_start;
  logic [1:0] bank_r[2];logic [9:0] base_r[2];logic [15:0] id_r[2];
  logic [6:0] words_r[2];logic [8:0] coefficients_r[2];
  logic closed_r;
  logic [3:0] bank_mask_r,started_r,finished_r,held_normal_r;
  logic [3:0][7:0] planned_r;
  logic regroup_valid,regroup_ready,regroup_core,regroup_last,regroup_fault,regroup_input_ready;
  logic [3:0] regroup_word;logic [91:0] regroup_data;
  logic normal_selected,regroup_selected,normal_ready;
  // One shared normal-word handoff,not a per-bank/key/polynomial buffer.
  // Register occupancy drives admission;RAM collision/ready cannot feed back
  // through the live decoder packet or its address formatting.
  logic [1:0] normal_count_r;
  logic normal_read_r,normal_write_r,normal_push,normal_core;
  logic [1:0] normal_bank;
  logic [9:0] normal_address;
  logic [91:0] normal_data;
  (* ramstyle = "logic" *) logic [91:0] normal_data_r[2];
  logic [9:0] normal_address_r[2];
  logic [1:0] normal_bank_r[2];logic normal_core_r[2];
  assign normal_core=normal_core_r[normal_read_r];
  assign normal_bank=normal_bank_r[normal_read_r];
  assign normal_address=normal_address_r[normal_read_r];
  assign normal_data=normal_data_r[normal_read_r];
  assign normal_push=packet_valid_i && packet_ready_o && !secret_r[packet_core_i];
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin normal_count_r<=0;normal_read_r<=0;normal_write_r<=0;end
    else begin
      case({normal_push,normal_ready})
        2'b10:normal_count_r<=normal_count_r+1'b1;
        2'b01:normal_count_r<=normal_count_r-1'b1;
        default:begin end
      endcase
      if(normal_push)normal_write_r<=!normal_write_r;
      if(normal_ready)normal_read_r<=!normal_read_r;
    end
  end
  always @(posedge clk)if(normal_push)begin
    normal_data_r[normal_write_r]<=packet_data_i;
    normal_core_r[normal_write_r]<=packet_core_i;
    normal_bank_r[normal_write_r]<=bank_r[packet_core_i];
    normal_address_r[normal_write_r]<=base_r[packet_core_i]+10'(coefficients_r[packet_core_i][8:2]);
  end
  assign active_o=active_r;
  assign idle_o=!rst && active_r==0 && !closed_r && bank_mask_r==0;
  assign job_ready_o=!rst && !fault_o && !closed_r && !active_r[job_core_i];
  assign regroup_start[0]=job_valid_i && job_ready_o && !job_core_i && job_mode_i==1;
  assign regroup_start[1]=job_valid_i && job_ready_o && job_core_i && job_mode_i==1;
  assign done_valid_o=!rst && !fault_o && status_valid_i && active_r[status_core_i] &&
    words_r[status_core_i]==(secret_r[status_core_i]?16:64);
  assign done_core_o=status_core_i;assign done_id_o=status_id_i;assign done_code_o=status_code_i;
  assign status_ready_o=done_valid_o && done_ready_i;
  always_comb begin
    memory_command_valid_o=0;memory_command_mask_o=0;memory_command_write_o=0;
    memory_command_base_o=0;memory_command_words_o=0;memory_command_mode_o=0;
    memory_write_valid_o=0;memory_write_data_o=0;memory_write_address_o=0;memory_done_ready_o=0;
    memory_command_mask_o[1]=bank_mask_r & ~started_r;
    memory_command_write_o[1]=memory_command_mask_o[1];
    memory_command_valid_o[1]=!rst && !fault_o && closed_r && |memory_command_mask_o[1];
    for(int b=0;b<4;b++)begin
      memory_command_words_o[1][b]={3'd0,planned_r[b]};
      memory_command_mode_o[1][b]=2; // producer-addressed write stream
      memory_done_ready_o[1][b]=!rst && !fault_o && started_r[b] && !finished_r[b];
    end
    normal_selected=!rst && !fault_o && normal_count_r!=0 && active_r[normal_core] &&
      !secret_r[normal_core] && started_r[normal_bank];
    regroup_selected=!rst && !fault_o && regroup_valid && active_r[regroup_core] &&
      started_r[bank_r[regroup_core]];
    // A pending regrouped word wins a same-bank conflict. Different banks may
    // accept both words simultaneously;no shared payload register is copied.
    if(normal_selected && regroup_selected && normal_bank==bank_r[regroup_core])begin
      if(held_normal_r[normal_bank])regroup_selected=0;
      else normal_selected=0;
    end
    if(normal_selected)begin
      memory_write_valid_o[1][normal_bank]=1;
      memory_write_data_o[1][normal_bank]=normal_data;
      memory_write_address_o[1][normal_bank]=normal_address;
    end
    if(regroup_selected)begin
      memory_write_valid_o[1][bank_r[regroup_core]]=1;
      memory_write_data_o[1][bank_r[regroup_core]]=regroup_data;
      memory_write_address_o[1][bank_r[regroup_core]]=base_r[regroup_core]+10'(words_r[regroup_core]);
    end
    normal_ready=normal_selected && memory_write_ready_i[1][normal_bank];
    packet_ready_o=!rst && !fault_o && active_r[packet_core_i] &&
      (secret_r[packet_core_i]?regroup_input_ready:
        (started_r[bank_r[packet_core_i]] && normal_count_r<2));
    regroup_ready=regroup_selected && memory_write_ready_i[1][bank_r[regroup_core]];
  end
  secret_regroup regroup(
    .clk(clk),.rst(rst),.job_start_i(regroup_start),
    .input_valid_i(packet_valid_i && active_r[packet_core_i] && secret_r[packet_core_i] && !fault_o),
    .input_ready_o(regroup_input_ready),.input_core_i(packet_core_i),.input_last_i(packet_last_i),
    .input_index_i(packet_index_i),.input_data_i(packet_data_i[63:0]),
    .output_valid_o(regroup_valid),.output_ready_i(regroup_ready),
    .output_core_o(regroup_core),.output_last_o(regroup_last),.output_word_o(regroup_word),
    .output_data_o(regroup_data),.fault_o(regroup_fault));
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      active_r<=0;secret_r<=0;fault_o<=0;closed_r<=0;bank_mask_r<=0;started_r<=0;finished_r<=0;planned_r<=0;held_normal_r<=0;
      for(int c=0;c<2;c++)begin bank_r[c]<=0;base_r[c]<=0;id_r[c]<=0;words_r[c]<=0;coefficients_r[c]<=0;end
    end else begin
      if(regroup_fault)fault_o<=1;
      if(normal_selected)held_normal_r[normal_bank]<=!normal_ready;
      if(job_valid_i && job_ready_o)begin
        active_r[job_core_i]<=1;
        secret_r[job_core_i]<=job_mode_i==1;bank_r[job_core_i]<=job_bank_i;
        base_r[job_core_i]<=job_base_i;id_r[job_core_i]<=job_id_i;
        words_r[job_core_i]<=0;coefficients_r[job_core_i]<=0;
        bank_mask_r[job_bank_i]<=1;
        planned_r[job_bank_i]<=planned_r[job_bank_i]+(job_mode_i==1?8'd16:8'd64);
        if(job_batch_last_i)closed_r<=1;
        if(job_base_i[5:0]!=0)fault_o<=1;
        if(active_r[!job_core_i] && bank_r[!job_core_i]==job_bank_i && base_r[!job_core_i]==job_base_i)fault_o<=1;
      end
      if(packet_valid_i && packet_ready_o)begin
        if(packet_id_i!=id_r[packet_core_i] || packet_index_i!=coefficients_r[packet_core_i][7:0] ||
          packet_count_i!=(secret_r[packet_core_i]?16:4) || packet_last_i!=(coefficients_r[packet_core_i]+9'(packet_count_i)==256))fault_o<=1;
        coefficients_r[packet_core_i]<=coefficients_r[packet_core_i]+9'(packet_count_i);
      end
      if(normal_ready)words_r[normal_core]<=words_r[normal_core]+1'b1;
      if(regroup_ready)begin
        words_r[regroup_core]<=words_r[regroup_core]+1'b1;
        if(regroup_word!=words_r[regroup_core] || regroup_last!=(words_r[regroup_core]==15))fault_o<=1;
      end
      if(memory_command_valid_o[1] && memory_command_ready_i[1])started_r<=started_r | memory_command_mask_o[1];
      for(int b=0;b<4;b++)if(memory_done_valid_i[1][b] && memory_done_ready_o[1][b])begin
        finished_r[b]<=1;if(memory_done_error_i[1][b])fault_o<=1;
      end
      if(status_valid_i && active_r[status_core_i] &&
        (status_id_i!=id_r[status_core_i] || status_code_i!=0))fault_o<=1;
      if(status_ready_o)begin
        active_r[status_core_i]<=0;
        if(coefficients_r[status_core_i]!=256)fault_o<=1;
      end
      if(closed_r && active_r==0 && (finished_r & bank_mask_r)==bank_mask_r)begin
        closed_r<=0;bank_mask_r<=0;started_r<=0;finished_r<=0;planned_r<=0;
      end
    end
  end
  // synthesis translate_off
  always @(posedge clk)if(!rst)begin
    if(normal_count_r>2)$fatal(1,"Normal writer queue overflow");
    if(normal_ready && (normal_bank!=bank_r[normal_core] ||
      normal_address!=base_r[normal_core]+10'(words_r[normal_core])))
      $fatal(1,"Normal writer queue changed the committed context/address");
    if(idle_o && normal_count_r!=0)$fatal(1,"Idle writer retained queued data");
  end
  // synthesis translate_on
endmodule
`default_nettype wire
