interface sampler_if(input logic clk);
`ifdef SAMPLER_NETLIST
  bit source_probes=0;
`else
  bit source_probes=1;
`endif
  logic rst;
  logic job_valid, job_ready, job_core;
  logic [15:0] job_id;
  logic [1:0] job_mode, job_param;
  logic [127:0] input_data;
  logic [4:0] input_bytes;
  logic input_core, input_last, input_valid, input_ready;
  logic [22:0] output_data;
  logic output_core, output_last, output_valid, output_ready;
  logic [15:0] output_id;
  logic [7:0] output_index;
  logic status_valid, status_ready, status_core;
  logic [15:0] status_id;
  logic [2:0] status_code;
  logic [1:0] active, source_stop;
  // Source-only measurement probes, not sampler ports or reference inputs.
  bit perf_stalls=1;
  int force_output_stall=0,force_status_stall=0;
  int perf_jobs=1;
  int unsigned random_ready_seed=0,job_random_seed=0;
  logic perf_hold,perf_hold_core,perf_chunk;
  logic probe_decode_valid,probe_packed_valid;
  logic [2:0] probe_prepare_phase;
  logic probe_decode_core,probe_packed_core,probe_decode_transfer;
  logic [4:0] probe_compact_count,probe_admit_count;
  logic [4:0] probe_head[2],probe_tail[2];
  logic [1:0] probe_status_eligible;
  logic probe_status_lock;
  logic probe_collector_pop,probe_collector_core;
  logic [1:0] probe_collector_fetch;
  logic [4:0] perf_hold_bytes;
  logic [1:0] perf_res_bytes[2];
  logic [4:0] perf_res_bits[2];
  logic [5:0] perf_count[2];
  logic [8:0] perf_gen[2],perf_gen_next[2];
  logic [2:0] perf_ball_state;
  logic perf_ball_selected,perf_ball_clear_core,perf_ball_byte_ready,perf_ball_byte_valid;
  logic [3:0] perf_ball_sign_bytes[2];
  logic [7:0] perf_ball_position[2];
  logic [1:0] perf_ball_done;
  logic [7:0] perf_byte;
endinterface
