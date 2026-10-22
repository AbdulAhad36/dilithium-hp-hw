// Stage2 subsystem helper; the full dilithium controller/memory follow later.
// Commands supply the complete SHAKE absorption message on the64-bit stream.
`default_nettype none
module keccak_sampler #(
  parameter bit RAW_SERVICE=0
) (
  input wire logic clk, rst,
  input wire logic job_valid_i, output logic job_ready_o, job_core_o,
  input wire logic [15:0] job_id_i, message_len_i,
  input wire logic [1:0] job_mode_i, job_param_i,
  input wire logic [63:0] input_data_i,
  input wire logic input_valid_i, output logic input_ready_o,
  output logic [22:0] output_data_o,
  output logic output_core_o, output_last_o, output_valid_o,
  output logic [15:0] output_id_o,
  output logic [7:0] output_index_o,
  input wire logic output_ready_i,
  output logic status_valid_o, status_core_o,
  output logic [15:0] status_id_o,
  output logic [2:0] status_code_o,
  input wire logic status_ready_i,
  output logic [1:0] active_o,
  // Optional finite raw-SHAKE client sharing the same two physical hash cores.
  // RAW_SERVICE=0 ties this route off for preserved sampling-only wrappers.
  input wire logic raw_valid_i, output logic raw_ready_o,raw_core_o,
  input wire logic raw_mode_i,
  input wire logic [15:0] raw_id_i,raw_message_len_i,raw_output_len_i,
  input wire logic [63:0] raw_input_data_i,
  input wire logic raw_input_valid_i,output logic raw_input_ready_o,
  output logic raw_output_valid_o,raw_output_core_o,
  output logic [15:0] raw_output_id_o,
  output logic [127:0] raw_output_data_o,
  output logic [4:0] raw_output_bytes_o,
  input wire logic raw_output_ready_i,
  output logic raw_done_valid_o,raw_done_core_o,
  output logic [15:0] raw_done_id_o,
  input wire logic raw_done_ready_i
);
  logic request_valid, request_ready, request_core, sampler_job_ready;
  logic hash_mode;
  logic [1:0] owned_r, drain_r, stop_r, hash_busy, hash_done;
  logic [127:0] hash_data;
  logic [4:0] hash_bytes;
  logic hash_valid, hash_ready, hash_core;
  logic [127:0] bridge_data_r;
  logic [4:0] bridge_bytes_r;
  logic bridge_valid_r, bridge_core_r, bridge_cancel, bridge_room;
  logic [1:0] bridge_count_r;
  logic bridge_read_r, bridge_write_r, bridge_push, bridge_pop;
  (* ramstyle = "logic" *) logic [127:0] bridge_data_mem [2];
  logic [4:0] bridge_bytes_mem [2];
  logic bridge_core_mem [2];
  logic bridge_pending_for_status;
  logic sampler_input_valid, sampler_input_ready;
  logic [1:0] sampler_active, sampler_stop;
  logic sampler_status_valid, sampler_status_ready, sampler_status_core;
  logic [15:0] sampler_status_id;
  logic [2:0] sampler_status_code;
  logic discard, quiesced, command_fire, hash_fire;
  logic raw_select,raw_fire,ingress_raw_r,hash_input_ready;
  logic [1:0] raw_r;
  logic [15:0] raw_ids_r[2],raw_remaining_r[2];

  assign job_core_o = request_core;
  // Ownership outlives sampler activity and clears on its external status
  // handshake. An unowned context is already sampler-ready;do not feed the
  // sampler's combinational ready mux back into Keccak's command launch.
  assign raw_select = RAW_SERVICE && raw_valid_i && raw_output_len_i!=0;
  assign raw_core_o = request_core;
  assign raw_ready_o = RAW_SERVICE && !rst && raw_output_len_i!=0 &&
                       request_ready && !owned_r[request_core];
  assign raw_fire = raw_valid_i && raw_ready_o;
  assign job_ready_o = !rst && request_ready && !owned_r[request_core] && !raw_select;
  assign command_fire = job_valid_i && job_ready_o;
  // One common handshake atomically starts both contexts.
  assign request_valid = (raw_select || job_valid_i) && !rst && !owned_r[request_core];
  assign active_o = owned_r;
  // Sampling mode0 is A/SHAKE128;all other modes use SHAKE256. Keep the
  // decode outside the port expression for consistent Quartus enum handling.
  assign hash_mode = raw_select ? raw_mode_i : (job_mode_i != 2'd0);
  assign input_ready_o = hash_input_ready && !ingress_raw_r && !rst;
  assign raw_input_ready_o = RAW_SERVICE && hash_input_ready && ingress_raw_r && !rst;

  keccak_dual_interleaved hash (
    .clk(clk), .rst(rst),
    .request_valid_i(request_valid), .request_ready_o(request_ready),
    .request_core_o(request_core),
    .keccak_mode_i(hash_mode),
    .message_len_i(raw_select ? raw_message_len_i : message_len_i),
    .output_len_i(raw_select ? raw_output_len_i : 16'd0),
    .input_data_i(ingress_raw_r ? raw_input_data_i : input_data_i),
    .input_valid_i(!rst && (ingress_raw_r ? raw_input_valid_i : input_valid_i)),
    .input_ready_o(hash_input_ready), .input_core_o(),
    .stop_i(stop_r), .core_busy_o(hash_busy), .core_done_o(hash_done), .busy_o(),
    .output_data_o(hash_data), .output_valid_o(hash_valid),
    .output_bytes_o(hash_bytes), .output_core_o(hash_core),
    .output_ready_i(hash_ready)
  );

  // source_stop cancels surplus unaccepted input offers. They belong to the
  // old job and must never enter the next descriptor. Required bytes have
  // already been consumed before the sampler can assert successful stop.
  assign bridge_cancel = bridge_valid_r &&
                         (drain_r[bridge_core_r] || sampler_stop[bridge_core_r]);
  assign sampler_input_valid = bridge_valid_r && !bridge_cancel && !rst;
  // Registered occupancy cuts the sampler-ready/stop path into Keccak. Two
  // slots sustain a simultaneous push/pop without a combinational ready chain.
  assign bridge_valid_r = (bridge_count_r != 0);
  assign bridge_data_r = bridge_data_mem[bridge_read_r];
  assign bridge_bytes_r = bridge_bytes_mem[bridge_read_r];
  assign bridge_core_r = bridge_core_mem[bridge_read_r];
  assign bridge_room = (bridge_count_r < 2);
  assign discard = drain_r[hash_core];
  assign hash_ready = !rst && (raw_r[hash_core] ? raw_output_ready_i : (discard || bridge_room));
  assign hash_fire = hash_valid && hash_ready;
  assign bridge_push = hash_fire && !discard && !raw_r[hash_core];
  assign bridge_pop = bridge_cancel || (sampler_input_valid && sampler_input_ready);
  assign raw_output_valid_o = !rst && hash_valid && raw_r[hash_core];
  assign raw_output_data_o = hash_data;
  assign raw_output_bytes_o = hash_bytes;
  assign raw_output_core_o = hash_core;
  assign raw_output_id_o = raw_ids_r[hash_core];

  // Status is held inside the sampler until old SHAKE tokens are gone. A new
  // job cannot reuse an idle hash core while its old descriptor still owns it.
  assign bridge_pending_for_status =
    (bridge_valid_r && bridge_core_r == sampler_status_core) ||
    (bridge_count_r == 2 && bridge_core_mem[~bridge_read_r] == sampler_status_core);
  assign quiesced = owned_r[sampler_status_core] &&
                    !hash_busy[sampler_status_core] && !bridge_pending_for_status;
  assign status_valid_o = !rst && sampler_status_valid && quiesced;
  assign sampler_status_ready = !rst && status_ready_i && quiesced;
  assign status_core_o = sampler_status_core;
  assign status_id_o = sampler_status_id;
  assign status_code_o = sampler_status_code;

  sampler sample (
    .clk(clk), .rst(rst), .job_valid_i(command_fire),
    .job_ready_o(sampler_job_ready), .job_core_i(request_core),
    .job_id_i(job_id_i), .job_mode_i(job_mode_i), .job_param_i(job_param_i),
    .input_data_i(bridge_data_r), .input_bytes_i(bridge_bytes_r),
    .input_core_i(bridge_core_r), .input_last_i(1'b0),
    .input_valid_i(sampler_input_valid), .input_ready_o(sampler_input_ready),
    .output_data_o(output_data_o), .output_core_o(output_core_o),
    .output_id_o(output_id_o), .output_index_o(output_index_o),
    .output_last_o(output_last_o), .output_valid_o(output_valid_o),
    .output_ready_i(output_ready_i),
    .status_valid_o(sampler_status_valid), .status_ready_i(sampler_status_ready),
    .status_core_o(sampler_status_core), .status_id_o(sampler_status_id),
    .status_code_o(sampler_status_code), .active_o(sampler_active),
    .source_stop_o(sampler_stop)
  );

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      owned_r <= 0; drain_r <= 0; stop_r <= 0; raw_r <= 0; ingress_raw_r <= 0;
      raw_done_valid_o <= 0; raw_done_core_o <= 0; raw_done_id_o <= 0;
      for(int core=0;core<2;core++)begin raw_ids_r[core]<=0;raw_remaining_r[core]<=0;end
      bridge_count_r <= 0; bridge_read_r <= 0; bridge_write_r <= 0;
    end else begin
      if (request_valid && request_ready) ingress_raw_r <= raw_select;
      // Register completion selection: a newly finished peer cannot replace a
      // stalled completion offer. Ownership lasts through its handshake.
      if(raw_done_valid_o)begin
        if(raw_done_ready_i)raw_done_valid_o<=0;
      end else if(RAW_SERVICE)begin
        if(raw_r[0] && owned_r[0] && raw_remaining_r[0]==0 && !hash_busy[0])begin
          raw_done_valid_o<=1;raw_done_core_o<=0;raw_done_id_o<=raw_ids_r[0];
        end else if(raw_r[1] && owned_r[1] && raw_remaining_r[1]==0 && !hash_busy[1])begin
          raw_done_valid_o<=1;raw_done_core_o<=1;raw_done_id_o<=raw_ids_r[1];
        end
      end
      case ({bridge_push, bridge_pop})
        2'b10: bridge_count_r <= bridge_count_r + 2'd1;
        2'b01: bridge_count_r <= bridge_count_r - 2'd1;
        default: ;
      endcase
      if (bridge_push) bridge_write_r <= ~bridge_write_r;
      if (bridge_pop) bridge_read_r <= ~bridge_read_r;
      for (int core=0; core<2; core++) begin
        if (owned_r[core] && !raw_r[core] && sampler_stop[core]) drain_r[core] <= 1;
        // Register stop only AFTER a discarded transfer releases the wrapper
        // arbiter lock. Keep it high through any intervening permutation.
        if (hash_fire && hash_core == core && discard && !raw_r[core]) stop_r[core] <= 1;
        if (hash_fire && hash_core == core && raw_r[core])
          raw_remaining_r[core]<=raw_remaining_r[core]-16'(hash_bytes);
        if (raw_done_valid_o && raw_done_ready_i && raw_done_core_o == core) begin
          owned_r[core]<=0;raw_r[core]<=0;
        end
        if (status_valid_o && status_ready_i && status_core_o == core) begin
          owned_r[core] <= 0; drain_r[core] <= 0; stop_r[core] <= 0;
        end
        if (command_fire && request_core == core) begin
          owned_r[core] <= 1; drain_r[core] <= 0; stop_r[core] <= 0; raw_r[core]<=0;
        end
        if (raw_fire && request_core == core) begin
          owned_r[core]<=1;raw_r[core]<=1;drain_r[core]<=0;stop_r[core]<=0;
          raw_ids_r[core]<=raw_id_i;raw_remaining_r[core]<=raw_output_len_i;
        end
      end
    end
  end

  // Occupancy/pointers own the payload; no bulk data reset is needed.
  always_ff @(posedge clk) if (bridge_push) begin
    bridge_data_mem[bridge_write_r] <= hash_data;
    bridge_bytes_mem[bridge_write_r] <= hash_bytes;
    bridge_core_mem[bridge_write_r] <= hash_core;
  end

`ifndef SYNTHESIS
  always @(posedge clk) if (!rst) begin
    if ((sampler_active & ~owned_r) != 0) $fatal(1,"Sampler activity without ownership");
    if ((sampler_active & raw_r) != 0) $fatal(1,"Raw core also owns sampler state");
    if (raw_fire && command_fire) $fatal(1,"Two clients accepted one descriptor");
    if (raw_output_valid_o && (discard || !owned_r[hash_core]))$fatal(1,"Raw output ownership");
    if (hash_fire && raw_r[hash_core] && raw_remaining_r[hash_core]<16'(hash_bytes))
      $fatal(1,"Raw SHAKE output overrun");
    if (raw_done_valid_o && (!owned_r[raw_done_core_o] || !raw_r[raw_done_core_o] ||
        hash_busy[raw_done_core_o] || raw_remaining_r[raw_done_core_o]!=0))$fatal(1,"Premature raw completion");
    if (command_fire && !sampler_job_ready) $fatal(1,"Unowned context was not sampler-ready");
    if (hash_valid && !owned_r[hash_core]) $fatal(1,"SHAKE output without descriptor ownership");
    if (bridge_valid_r && !owned_r[bridge_core_r]) $fatal(1,"Unowned bridge token");
    if (bridge_count_r == 2 && !owned_r[bridge_core_mem[~bridge_read_r]])
      $fatal(1,"Unowned second bridge token");
    if (bridge_count_r > 2 || (bridge_push && bridge_count_r == 2) ||
        (bridge_pop && bridge_count_r == 0)) $fatal(1,"Bridge occupancy violation");
    if (status_valid_o && bridge_pending_for_status) $fatal(1,"Status before queued-token drain");
    if (command_fire && owned_r[request_core]) $fatal(1,"Premature context reuse");
    if (status_valid_o && status_ready_i && hash_busy[status_core_o])
      $fatal(1,"Status retired before SHAKE drain");
    if (hash_fire && (hash_bytes==0 || hash_bytes>16)) $fatal(1,"Invalid SHAKE byte count");
  end
`endif
endmodule
`default_nettype wire
