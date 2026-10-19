// Stage 3.3: registered extraction/compaction/collector pipeline.
// Earliest input byte occupies bits 7:0. Per-context matrix collectors serialize
// groups of four; tags keep interleaved polynomials distinct at the output.
module sampler (
  input logic clk, rst,
  input logic job_valid_i, output logic job_ready_o,
  input logic job_core_i, input logic [15:0] job_id_i,
  input logic [1:0] job_mode_i, job_param_i,
  input logic [127:0] input_data_i,
  input logic [4:0] input_bytes_i,
  input logic input_core_i, input_last_i, input_valid_i,
  output logic input_ready_o,
  output logic [22:0] output_data_o,
  output logic output_core_o, output_last_o, output_valid_o,
  output logic [15:0] output_id_o,
  output logic [7:0] output_index_o,
  input logic output_ready_i,
  output logic status_valid_o, status_core_o,
  output logic [15:0] status_id_o,
  output logic [2:0] status_code_o,
  input logic status_ready_i,
  output logic [1:0] active_o, source_stop_o
);
  import sampler_pkg::*;
  localparam int COLLECTOR_DEPTH=32;
  logic [1:0] active_r, active_n, failed_r, failed_n;
  logic [15:0] id_r [2], id_n [2];
  logic [2:0] error_r [2], error_n [2];
  logic [1:0] mode_r [2], mode_n [2], param_r [2], param_n [2];
  logic [3:0] mode_flags_r[2];
  logic wide_flag_r[2],eta4_flag_r[2];
  logic [8:0] generated_r [2], generated_n [2], emitted_r [2], emitted_n [2];
  logic [15:0] residual_r [2], residual_n [2];
  logic [1:0] residual_count_r [2], residual_count_n [2];
  logic [18:0] mask_residual_r [2], mask_residual_n [2];
  logic [4:0] mask_bits_r [2], mask_bits_n [2];
  // Snapshot the selected job's carry at beat acceptance. The working copy
  // advances between low/high chunks without a context mux before alignment.
  logic [18:0] mask_work_r;
  logic [4:0] mask_work_bits_r;
  logic mask_work_wide_r;
  logic [1:0][6:0] mask_carry_shift_r;
  logic [1:0] mask_has_field_r;
  logic [4:0] mask_lower_bits_r;
  logic [18:0] mask_upper_carry_r;
  logic [18:0] mask_lower_unfinished_r[2];
  function automatic logic [4:0] mask_advance_bits(
      input logic [4:0] saved,bytes,input logic wide);
    logic [4:0] offset;
    logic [5:0] sum;
    if(wide)case(bytes)
      0,5,10,15:offset=0;
      1,6,11,16:offset=8;
      2,7,12:offset=16;
      3,8,13:offset=4;
      default:offset=12;
    endcase
    else case(bytes)
      0,9:offset=0;
      1,10:offset=8;
      2,11:offset=16;
      3,12:offset=6;
      4,13:offset=14;
      5,14:offset=4;
      6,15:offset=12;
      7,16:offset=2;
      default:offset=10;
    endcase
    sum={1'b0,saved}+{1'b0,offset};
    return wide ? 5'(sum>=20 ? sum-6'd20:sum):5'(sum>=18 ? sum-6'd18:sum);
  endfunction
  // Decode each half's carry shift when accepting its owning beat. For the
  // upper half, total consumed bits minus64 also removes the lower input word.
  // These metadata registers add no sampling cycle; hold_r owns their use.
  function automatic logic [6:0] mask_carry_shift(
      input logic [4:0] saved_bits,bytes,
      input logic wide,upper);
    return 7'({bytes,3'b000}-8'(mask_advance_bits(saved_bits,bytes,wide))-
      (upper ? 8'd64:8'd0));
  endfunction
  wire [18:0] mask_residual;
  wire [4:0] mask_bits;
  wire [3:0] mask_valid;
  wire [3:0][19:0] mask_fields;
  logic [22:0] collector_r [2][COLLECTOR_DEPTH], collector_n [2][COLLECTOR_DEPTH];
  logic [5:0] count_r [2], count_n [2];
  logic [4:0] head_r [2],head_n [2],tail_r [2],tail_n [2];
  logic hold_r, hold_n, hold_core_r, hold_core_n, hold_last_r, hold_last_n;
  logic [127:0] hold_data_r,input_skid_r;
  logic capture_pending_r,prepare_ready,prepare_accept;
  wire [1:0][3:0][19:0] prepared_mask_fields;
  wire [1:0][3:0] prepared_mask_valid;
  wire [1:0][18:0] prepared_mask_carry;
  wire [1:0][4:0] prepared_mask_bits;
  wire [1:0][2:0][22:0] prepared_a_fields;
  wire [1:0][1:0] prepared_a_lanes,prepared_a_bytes;
  wire [1:0][15:0] prepared_a_carry;
  logic [127:0] masked_input;
  logic [3:0] ball_byte_index_r;
  logic [7:0] ball_byte_r;
  wire [7:0] held_byte=ball_byte_r;
  logic [1:0][1:0] a_carry_bytes_r;
  logic [1:0][3:0] a_carry_shift_r;
  logic [1:0] a_has_field_r;
  logic [1:0][15:0] a_half_carry;
  logic [1:0][15:0] a_finished_carry;
  function automatic logic [1:0] mod3_bytes(input logic [4:0] total);
    case(total)
      0,3,6,9,12,15,18:return 2'd0;
      1,4,7,10,13,16:return 2'd1;
      default:return 2'd2;
    endcase
  endfunction
  function automatic logic [1:0] advance_mod3(input logic [1:0] saved,input logic [4:0] bytes);
    logic [2:0] total;
    total={1'b0,saved}+3'(mod3_bytes(bytes));
    return total>=3 ? 2'(total-3'd3):2'(total);
  endfunction
  logic hold_upper_r,hold_upper_n;
  // Stage4.7a: select after two parallel carry shifts, off the wide input mux.
  wire [1:0][18:0] mask_half_carry;
  assign mask_half_carry[0]=19'(hold_data_r[63:0]>>mask_carry_shift_r[0]);
  assign mask_half_carry[1]=19'(hold_data_r[127:64]>>mask_carry_shift_r[1]);
  wire [1:0][18:0] mask_finished_carry;
  assign mask_finished_carry[0]=mask_has_field_r[0] ? mask_half_carry[0]:
    mask_lower_unfinished_r[hold_core_r];
  assign mask_finished_carry[1]=mask_has_field_r[1] ? mask_half_carry[1]:
    (mask_work_r | (19'(hold_data_r[127:64])<<mask_work_bits_r));
  wire [18:0] mask_prepared_upper=mask_has_field_r[1] ? mask_half_carry[1]:
    (mask_half_carry[0] | (19'(hold_data_r[127:64])<<mask_lower_bits_r));
  wire [18:0] mask_next_carry=prepared_mask_carry[hold_upper_r];
  wire [63:0] chunk_data=hold_upper_r ? hold_data_r[127:64]:hold_data_r[63:0];
  logic [4:0] beat_bytes_r,ball_remaining_r;
  wire [4:0] hold_bytes_r=mode_flags_r[hold_core_r][SAMPLE_BALL] ? ball_remaining_r:
    (hold_upper_r ? beat_bytes_r-5'd8:beat_bytes_r);
  logic lock_r, lock_n, lock_core_r, lock_core_n, turn_r, turn_n;
  logic [4:0] left_r, left_n;
  logic status_turn_r, status_turn_n;
  logic status_lock_r, status_lock_n, status_core_r, status_core_n;
  logic [1:0] eligible, status_eligible;
  logic out_valid_r,out_core_r,out_last_r;
  logic [22:0] out_data_r;
  logic [15:0] out_id_r;
  logic [7:0] out_index_r;
  logic [8:0] fetched_r[2],fetched_n[2];
  logic collector_pop;
  logic [1:0] read_valid_r,read_fill,read_space;
  logic [22:0] read_data_r[2];
  logic [7:0] read_index_r[2];
  logic chosen, schosen;
  integer remaining, c, used, available, consumed;
  logic [79:0] assembled;
  logic chunk_fire;
  logic [1:0] chunk_issue;
  logic [15:0] candidate_valid;
  logic [3:0][22:0] candidate_data;
  logic [15:0][3:0] candidate_secret;
  logic extract_valid_r,extract_core_r,extract_last_r,extract_transfer;
  logic extract_is_mask_r,extract_is_secret_r,extract_wide_r;
  logic [15:0] extract_mask_r;
  logic [3:0][22:0] extract_data_r;
  logic [15:0][3:0] extract_secret_r;
  logic [4:0] extract_bound_r;
  logic decode_valid_r,decode_core_r,decode_last_r;
  logic decode_is_mask_r,decode_wide_r;
  logic decode_is_secret_r;
  logic [15:0] decode_mask_r;
  logic [3:0][22:0] decode_data_r;
  logic [15:0][3:0] decode_secret_r;
  logic [3:0][2:0] decode_secret_count_r;
  logic [4:0] decode_total_count_r;
  logic [4:0] decode_bound_r;
  logic packed_valid_r,packed_core_r,packed_last_r;
  logic [4:0] packed_count_r;
  logic [4:0] packed_base_r;
  logic [1:0][31:0] incoming_write_mask,packed_write_mask_r;
  logic commit_valid_r,commit_core_r,commit_last_r;
  logic [4:0] commit_count_r,commit_bound_r,commit_base_r;
  logic [1:0][31:0] commit_write_mask_r;
  logic [15:0][22:0] commit_data_r;
  logic [4:0] append_tail_r[2],append_tail_n[2];
  logic ball_commit_valid_r,ball_commit_core_r,ball_commit_transfer;
  logic [1:0] ball_commit_code_r;
  logic [1:0][31:0] ball_write_mask_r,ball_write_mask;
  logic [8:0] ball_reserved_index[2];
  logic [8:0] ball_issue_index_r[2];
  logic [1:0] ball_room_r;
  wire [22:0] ball_commit_data=ball_commit_code_r==2 ? 23'(Q-1):
    (ball_commit_code_r==1 ? 23'd1:23'd0);
  wire [22:0] collector_write_data[2][16];
  genvar write_core,write_bank;
  generate for(write_core=0;write_core<2;write_core=write_core+1)begin:g_collector_source
    for(write_bank=0;write_bank<16;write_bank=write_bank+1)begin:g_bank
      // The job mode is stable until every pipeline token has drained. Share
      // this selector across the two circular rows with the same bank index.
      assign collector_write_data[write_core][write_bank]=mode_flags_r[write_core][SAMPLE_BALL] ?
        ball_commit_data:commit_data_r[write_bank];
    end
  end endgenerate
  logic [4:0] packed_bound_r;
  logic [6:0] slot_reservation_r[2],slot_reservation_n[2];
  logic [6:0] slot_refund_r[2],slot_refund_n[2];
  logic [6:0] reservation_incoming[2],reservation_sum[2],reservation_carry[2];
  logic [4:0] reservation_pending_r[2];
  logic [1:0] reservation_pop_r;
  logic [8:0] quota_r[2],quota_n[2];
  logic [4:0] admit_by_context[2];
  logic [9:0] quota_difference[2];
  logic packed_is_secret_r;
  logic [3:0][22:0] packed_wide_r;
  logic [15:0][3:0] packed_secret_r;
  logic decode_transfer,packed_transfer;
  logic [1:0] chunk_capacity;
  logic [4:0] chunk_bound;
  function automatic logic [22:0] secret_coefficient(input logic [3:0] small_value);
    case(small_value)
      4'hc:return 23'(Q-4);
      4'hd:return 23'(Q-3);
      4'he:return 23'(Q-2);
      4'hf:return 23'(Q-1);
      default:return 23'(small_value);
    endcase
  endfunction
  function automatic logic [22:0] mask_coefficient(input logic [19:0] field,input logic wide);
    logic [18:0] low_field;
    logic upper_half;
    logic [19:0] normalized,base,difference;
    low_field=wide ? field[18:0]:19'(field[16:0]);
    upper_half=wide ? field[19]:field[17];
    normalized=wide ? field:20'(field[17:0]);
    // Stage4.9o: q=2^23-8191. For upper-half t, subtract t from
    // gamma-8191 in20 bits and prepend111 to account for modulo2^23.
    // Lower-half values use gamma-t with000. t==gamma is the special zero.
    case({wide,upper_half})
      2'b00:base=20'h20000;
      2'b01:base=20'h1e001;
      2'b10:base=20'h80000;
      default:base=20'h7e001;
    endcase
    difference=base-normalized;
    if(upper_half && low_field==0)return 23'd0;
    return {{3{upper_half}},difference};
  endfunction
  wire [4:0] compact_count;
  wire [4:0] secret_count,a_count,mask_count;
  wire [15:0][3:0] compact_data;
  wire [2:0][22:0] a_data;
  logic [4:0] admit_count;
  logic [4:0] append_base;
  logic [8:0] remaining_coefficients;
  logic [15:0] next_residual;
  logic [1:0] next_residual_count;
  wire [15:0][3:0] secret_aligned [0:4];
  wire [4:0] incoming_append_base=append_tail_r[decode_core_r];
  wire ball_result_core;
  always_comb begin
    incoming_write_mask='0;
    ball_write_mask='0;
    for(int core=0;core<2;core++)for(int word_index=0;word_index<COLLECTOR_DEPTH;word_index++)
      begin
        incoming_write_mask[core][word_index]=decode_core_r==core &&
          5'(5'(word_index)-incoming_append_base)<admit_count;
        ball_write_mask[core][word_index]=ball_result_core==core && word_index==tail_r[core];
      end
  end
  logic [15:0][22:0] wide_aligned;
  wire [15:0][22:0] aligned_coefficient;
  // Stage4.6a: pack within four-nibble groups BEFORE the existing candidate
  // register. Its outputs are dense/zero-padded, so the next stage merges only
  // four ordered groups instead of ranking every nibble across all16 inputs.
  wire [3:0][4:0] secret_group_count;
  wire [3:0][3:0][3:0] secret_group_data;
  wire [1:0][31:0] secret_pair_data;
  wire [1:0][3:0] secret_pair_count;
  genvar group_index,pair_index;
  generate
    for(group_index=0;group_index<4;group_index=group_index+1)begin:g_secret_compact
      sampler_compact #(.LANES(4),.WIDTH(4)) u_group(
        .valid_i(extract_mask_r[4*group_index+:4]),
        .data_i(extract_secret_r[4*group_index+:4]),
        .count_o(secret_group_count[group_index]),.data_o(secret_group_data[group_index]));
    end
    for(pair_index=0;pair_index<2;pair_index=pair_index+1)begin:g_secret_merge
      assign secret_pair_count[pair_index]=4'(decode_secret_count_r[2*pair_index])+
        4'(decode_secret_count_r[2*pair_index+1]);
      assign secret_pair_data[pair_index]=32'(decode_secret_r[8*pair_index+:4]) |
        (32'(decode_secret_r[8*pair_index+4+:4]) << {decode_secret_count_r[2*pair_index],2'b00});
    end
  endgenerate
  assign secret_count=5'(secret_pair_count[0])+5'(secret_pair_count[1]);
  assign compact_data=64'(secret_pair_data[0]) |
    (64'(secret_pair_data[1]) << {secret_pair_count[0],2'b00});
  sampler_compact #(.LANES(3),.WIDTH(23)) u_a_compact(.valid_i(decode_mask_r[2:0]),.data_i(decode_data_r[2:0]),
    .count_o(a_count),.data_o(a_data));
  assign mask_count=(5'(decode_mask_r[0])+5'(decode_mask_r[1]))+
    (5'(decode_mask_r[2])+5'(decode_mask_r[3]));
  // The registered valid population is the accepted count for every mode.
  assign compact_count=decode_total_count_r;
  // Rotate once for the shared append source. Each collector entry then has a
  // single fixed write, rather than 16 dependent dynamic whole-array updates.
  assign secret_aligned[0]=packed_secret_r;
  genvar rotate_level,bank;
  generate
    for(rotate_level=0;rotate_level<4;rotate_level=rotate_level+1)begin: g_rotate
      for(bank=0;bank<16;bank=bank+1)begin: g_bank
        assign secret_aligned[rotate_level+1][bank]=append_base[rotate_level] ?
          secret_aligned[rotate_level][(bank+16-(1<<rotate_level))%16] : secret_aligned[rotate_level][bank];
      end
    end
  endgenerate
  // Stage4.9a: A/mask append at most four consecutive wide values. Their
  // enabled destination rows have unique addresses modulo4, so all16 payload
  // slots can share four rotated wide values. The independent row masks own
  // every write; unused aliases never become readable collector entries.
  // Secret values still need the full16-position,4-bit rotation above.
  always_comb begin
    wide_aligned='0;
    for(int dest=0;dest<16;dest++)for(int source=0;source<4;source++)
      wide_aligned[dest] |= packed_wide_r[source] & {23{append_base[1:0]==2'((dest+4-source)%4)}};
  end
  generate for(bank=0;bank<16;bank=bank+1)begin: g_format
    assign aligned_coefficient[bank]=packed_is_secret_r ?
      23'(secret_aligned[4][bank]):wide_aligned[bank];
  end endgenerate
  logic [3:0][2:0] secret_nibbles;
  wire [3:0][3:0] secret_valid;
  wire [3:0][3:0][3:0] secret_small;
  integer chunk_bytes;

  wire [1:0] ball_done,ball_exhausted;
  wire ball_byte_ready,ball_read_ready,ball_result_valid;
  wire [22:0] ball_result;
  logic ball_read_valid,ball_read_core;
  sampler_ball u_ball(
    .clk(clk),.rst(rst),
    .start_i(job_valid_i && job_ready_o && job_mode_i==SAMPLE_BALL && job_param_i!=3),
    .start_core_i(job_core_i),.start_param_i(job_param_i),.abort_i(failed_r),
    .byte_valid_i(hold_r && !capture_pending_r && mode_flags_r[hold_core_r][SAMPLE_BALL] && !failed_r[hold_core_r]),
    .byte_core_i(hold_core_r),.byte_i(held_byte),
    // Valid challenge bytes always own ball_remaining;avoid the shared mode/
    // half byte-count selector on the challenge exhaustion path.
    .byte_last_i(hold_last_r && ball_remaining_r==1),.byte_ready_o(ball_byte_ready),
    .done_o(ball_done),.exhausted_o(ball_exhausted),
    .read_valid_i(ball_read_valid),.read_core_i(ball_read_core),
    .read_index_i(ball_issue_index_r[ball_read_core][7:0]),.read_ready_o(ball_read_ready),
    .result_valid_o(ball_result_valid),.result_core_o(ball_result_core),.result_o(ball_result)
  );
  always_comb begin
    ball_read_valid=0;ball_read_core=0;
    for(int k=0;k<2;k++)ball_reserved_index[k]=generated_r[k]+
      9'(ball_commit_valid_r && ball_commit_core_r==k);
    // A completed challenge is immutable. Read it into the existing collector.
    for(int k=1;k>=0;k--)if(active_r[k] && !failed_r[k] &&
        mode_flags_r[k][SAMPLE_BALL] && ball_done[k] && ball_issue_index_r[k]<N && ball_room_r[k])begin
      ball_read_valid=1;ball_read_core=1'(k);
    end
  end

  always_comb begin
    chunk_bytes=hold_bytes_r>8 ? 8 : int'(hold_bytes_r);
    secret_nibbles='0;
    for(int lane=0;lane<4;lane++) begin
      if(chunk_bytes>=2*lane+2)secret_nibbles[lane]=4;
      else if(chunk_bytes==2*lane+1)secret_nibbles[lane]=2;
    end
  end
  genvar lane;
  generate
  for(lane=0;lane<4;lane=lane+1) begin: g_secret_lane
    sampler_secret_lane u_lane(
      .word_i(chunk_data[lane*16+:16]),.nibbles_i(secret_nibbles[lane]),
      .eta4_i(eta4_flag_r[hold_core_r]),
      .valid_o(secret_valid[lane]),.small_o(secret_small[lane])
    );
  end
  endgenerate
  assign prepare_accept=input_valid_i && input_ready_o && input_bytes_i>=1 && input_bytes_i<=16;
  sampler_input_prepare u_prepare(
    .clk(clk),.rst(rst),.accept_i(prepare_accept),.word_i(masked_input),.bytes_i(input_bytes_i),
    .mask_carry_i(mask_residual_r[input_core_i]),.mask_bits_i(mask_bits_r[input_core_i]),
    .wide_i(wide_flag_r[input_core_i]),.mode_a_i(mode_flags_r[input_core_i][SAMPLE_A]),
    .a_carry_i(residual_r[input_core_i]),
    .a_bytes_i(residual_count_r[input_core_i]),.ready_o(prepare_ready),
    .mask_fields_o(prepared_mask_fields),.mask_valid_o(prepared_mask_valid),
    .mask_carry_o(prepared_mask_carry),.mask_bits_o(prepared_mask_bits),
    .a_fields_o(prepared_a_fields),.a_lanes_o(prepared_a_lanes),
    .a_carry_o(prepared_a_carry),.a_bytes_o(prepared_a_bytes));
  genvar issue_core;
  generate for(issue_core=0;issue_core<2;issue_core++)begin:g_issue
    assign chunk_issue[issue_core]=!rst && hold_r && prepare_ready && hold_core_r==issue_core &&
      !mode_flags_r[issue_core][SAMPLE_BALL] && !failed_r[issue_core] && chunk_capacity[issue_core];
  end endgenerate
  assign chunk_fire=|chunk_issue;
  sampler_mask_unpack u_mask_unpack(
    .word_i(chunk_data),.bytes_i(4'(chunk_bytes)),
    .word_lower_i(hold_data_r[63:0]),.word_upper_i(hold_data_r[127:64]),.upper_i(hold_upper_r),
    .wide_i(mask_work_wide_r),
    .residual_i(mask_work_r),
    .residual_bits_i(mask_work_bits_r),
    .carry_shift_i(mask_carry_shift_r[hold_upper_r]),
    .valid_o(mask_valid),.field_o(mask_fields),
    .residual_o(mask_residual),.residual_bits_o(mask_bits)
  );

  always_comb begin
    candidate_valid='0;candidate_secret=secret_small;
    used=chunk_bytes;
    assembled=80'(residual_r[hold_core_r]) |
      (80'(chunk_data) << (8*residual_count_r[hold_core_r]));
    available=int'(residual_count_r[hold_core_r])+used;
    consumed=available>=9 ? 9 : (available>=6 ? 6 : (available>=3 ? 3:0));
    next_residual_count=prepared_a_bytes[hold_upper_r];
    // Discard every invalid high byte, including the unused half of a one-byte
    // carry. The next chunk uses OR alignment, so stale high bits must be zero.
    a_half_carry[0]=16'(hold_data_r[63:0]>>(8*a_carry_shift_r[0]));
    a_half_carry[1]=16'(hold_data_r[127:64]>>(8*a_carry_shift_r[1]));
    for(int half=0;half<2;half++)begin
      a_finished_carry[half]=a_has_field_r[half] ? a_half_carry[half]:
        (residual_r[hold_core_r] | (16'(hold_data_r[half*64+:64])<<(8*residual_count_r[hold_core_r])));
      case(a_carry_bytes_r[half])
        1:a_finished_carry[half]={8'd0,a_finished_carry[half][7:0]};
        2:;
        default:a_finished_carry[half]=0;
      endcase
    end
    next_residual=prepared_a_carry[hold_upper_r];
    // Payload may change in unused modes;mode/valid tags own every consumer.
    for(int j=0;j<3;j++)candidate_data[j]=mode_flags_r[hold_core_r][SAMPLE_A] ?
      prepared_a_fields[hold_upper_r][j]:23'(prepared_mask_fields[hold_upper_r][j]);
    candidate_data[3]=23'(prepared_mask_fields[hold_upper_r][3]);
    unique case(1'b1)
      mode_flags_r[hold_core_r][SAMPLE_SECRET]:begin
        for(int lane_index=0;lane_index<4;lane_index++)for(int nib=0;nib<4;nib++)begin
          candidate_valid[4*lane_index+nib]=secret_valid[lane_index][nib];
        end
      end
      mode_flags_r[hold_core_r][SAMPLE_MASK]:begin
        candidate_valid[3:0]=prepared_mask_valid[hold_upper_r];
      end
      mode_flags_r[hold_core_r][SAMPLE_A]:begin
        for(int j=0;j<3;j++)begin
          candidate_valid[j]=(j<prepared_a_lanes[hold_upper_r]) && prepared_a_fields[hold_upper_r][j]<Q;
        end
      end
      default:;
    endcase
    // generated counts committed collector entries. The packed stage has
    // already reserved its admitted polynomial positions, even before commit.
    remaining_coefficients=quota_r[decode_core_r];
    for(int slot=0;slot<2;slot++)begin
      // One widened subtraction supplies both clipping and saturated quota.
      // Avoid compare->min-mux->second subtraction on the quota feedback path.
      quota_difference[slot]={1'b0,quota_r[slot]}-{5'd0,compact_count};
      admit_by_context[slot]=quota_difference[slot][9] ? quota_r[slot][4:0]:compact_count;
    end
    admit_count=admit_by_context[decode_core_r];
    // The circular write pointer is independent of this clock's output pop.
    append_base=packed_base_r;
    chunk_bound=mode_flags_r[hold_core_r][SAMPLE_SECRET] ? 5'd16 :
      (mode_flags_r[hold_core_r][SAMPLE_A] ? 5'd3:5'd4);
  end

  // Stage4.7q: the counter adds a registered pending reservation. Safe issue
  // capacity includes both that pending token and this clock's issue. Compare
  // constant thresholds in parallel,without an occupancy adder on this path.
  // Returns/pops only decrease occupancy and are conservatively ignored here.
  always_ff @(posedge clk)for(int core=0;core<2;core++)begin
    if(rst || !active_r[core] || (job_valid_i && job_ready_o && job_core_i==core))begin
      chunk_capacity[core]<=1;reservation_pending_r[core]<=0;reservation_pop_r[core]<=0;
    end else begin
      reservation_pending_r[core]<=5'(reservation_incoming[core]);
      reservation_pop_r[core]<=read_fill[core];
      if(chunk_issue[core] && reservation_pending_r[core]!=0)
        chunk_capacity[core]<=!mode_flags_r[core][SAMPLE_SECRET] && slot_reservation_r[core]<=
          (mode_flags_r[core][SAMPLE_A] ? 7'd23:7'd20);
      else if(chunk_issue[core] || reservation_pending_r[core]!=0)
      chunk_capacity[core]<=slot_reservation_r[core]<=
        (mode_flags_r[core][SAMPLE_SECRET] ? 7'd0:(mode_flags_r[core][SAMPLE_A] ? 7'd26:7'd24));
      else
      chunk_capacity[core]<=slot_reservation_r[core]<=
        (mode_flags_r[core][SAMPLE_SECRET] ? 7'd16:(mode_flags_r[core][SAMPLE_A] ? 7'd29:7'd28));
    end
  end

  always_comb begin
    active_o = active_r;
    for (int k=0; k<2; k++) begin
      source_stop_o[k] = active_r[k] && (failed_r[k] || generated_r[k]==N || (mode_flags_r[k][SAMPLE_BALL] && ball_done[k]));
      // An unlocked read slot starts only after a whole burst is available.
      // During a locked burst it contains the next reserved coefficient.
      eligible[k] = read_valid_r[k];
      status_eligible[k] = active_r[k] &&
        !(hold_r && hold_core_r==k) &&
        (failed_r[k] || emitted_r[k]==N) && !(lock_r && lock_core_r==k) &&
        !(out_valid_r && out_core_r==k) &&
        !read_valid_r[k] &&
        !(extract_valid_r && extract_core_r==k) &&
        !(commit_valid_r && commit_core_r==k) && !(ball_commit_valid_r && ball_commit_core_r==k) &&
        !(decode_valid_r && decode_core_r==k) && !(packed_valid_r && packed_core_r==k);
    end
    job_ready_o = !rst && !active_r[job_core_i];
    input_ready_o = !rst && !hold_r && active_r[input_core_i] &&
      !failed_r[input_core_i] && generated_r[input_core_i]<N &&
      !(mode_flags_r[input_core_i][SAMPLE_BALL] && (ball_done[input_core_i] || ball_exhausted[input_core_i]));
    chosen = lock_r ? lock_core_r :
      (eligible==2'b11 ? turn_r : eligible[1]);
    // Formatting terminates at a clocked elastic slot, not a combinational
    // output outside internal timing constraints. Tags/valid own stalled data.
    collector_pop=!rst && (!out_valid_r || output_ready_i) && (lock_r || |eligible);
    for(int k=0;k<2;k++)begin
      read_space[k]=!read_valid_r[k] || (collector_pop && chosen==k);
      read_fill[k]=!rst && active_r[k] && read_space[k] && count_r[k]!=0 &&
        ((lock_r && lock_core_r==k && left_r>1) ||
         (collector_pop && chosen==k && !lock_r) ||
         (!failed_r[k] && count_r[k]>=(mode_flags_r[k][SAMPLE_SECRET] ? 16:4)));
    end
    output_core_o = out_core_r;
    output_id_o = out_id_r;
    output_index_o = out_index_r;
    output_last_o = out_last_r;
    output_data_o = out_data_r;
    output_valid_o = !rst && out_valid_r;
    schosen = status_lock_r ? status_core_r :
      (status_eligible==2'b11 ? status_turn_r : status_eligible[1]);
    status_core_o = schosen;
    status_id_o = id_r[schosen];
    status_code_o = failed_r[schosen] ? error_r[schosen] : STATUS_OK;
    status_valid_o = !rst && (status_lock_r || |status_eligible);
  end

  always_comb begin
    packed_transfer=commit_valid_r && active_r[commit_core_r] && !failed_r[commit_core_r];
    ball_commit_transfer=ball_commit_valid_r && active_r[ball_commit_core_r] && !failed_r[ball_commit_core_r];
    active_n=active_r; failed_n=failed_r;
    hold_n=hold_r; hold_core_n=hold_core_r; hold_last_n=hold_last_r;
    hold_upper_n=hold_upper_r;
    lock_n=lock_r; lock_core_n=lock_core_r; left_n=left_r; turn_n=turn_r;
    status_turn_n=status_turn_r;
    status_lock_n=status_lock_r; status_core_n=status_core_r;
    for (int k=0; k<2; k++) begin
      logic [4:0] appended;
      appended=(packed_transfer && commit_core_r==k) ? commit_count_r :
        ((ball_commit_transfer && ball_commit_core_r==k) ? 5'd1:5'd0);
      id_n[k]=id_r[k]; error_n[k]=error_r[k];
      mode_n[k]=mode_r[k];param_n[k]=param_r[k];
      generated_n[k]=generated_r[k]; emitted_n[k]=emitted_r[k];fetched_n[k]=fetched_r[k];
      residual_n[k]=residual_r[k]; residual_count_n[k]=residual_count_r[k];
      mask_residual_n[k]=mask_residual_r[k];mask_bits_n[k]=mask_bits_r[k];
      // One equation per fixed context replaces cascaded dynamic updates for
      // pop, challenge append and packed append. Both appends are mode-exclusive.
      count_n[k]=count_r[k]+6'(appended)-6'(read_fill[k]);
      // Unowned counts/credits clear together one clock after retirement.
      // New descriptors initialize both earlier if the context is reused.
      if(!active_r[k])count_n[k]=0;
      head_n[k]=head_r[k]+5'(read_fill[k]);tail_n[k]=tail_r[k];
      fetched_n[k]=fetched_r[k]+9'(read_fill[k]);
      for (int j=0; j<COLLECTOR_DEPTH; j++) collector_n[k][j]=collector_r[k][j];
    end
    remaining=0; c=0;
    decode_transfer=1'b0;
    extract_transfer=1'b0;

    if (status_valid_o) begin
      status_lock_n=1; status_core_n=schosen;
      if (status_ready_i) begin
        active_n[schosen]=0;
        status_turn_n=~schosen; status_lock_n=0;
      end
    end
    if (job_valid_i && job_ready_o) begin
      c=int'(job_core_i);
      active_n[c]=1; id_n[c]=job_id_i;
      mode_n[c]=job_mode_i;param_n[c]=job_param_i;
      generated_n[c]=0; emitted_n[c]=0; fetched_n[c]=0; count_n[c]=0;
      head_n[c]=0;tail_n[c]=0;
      residual_n[c]=0; residual_count_n[c]=0;
      mask_residual_n[c]=0;mask_bits_n[c]=0;
    end
    if(output_valid_o && output_ready_i)
      emitted_n[out_core_r]=emitted_r[out_core_r]+1'b1;
    // Fetch arbitration is separate from the external slot's stall ownership.
    if (collector_pop) begin
      remaining=lock_r ? int'(left_r) : (mode_flags_r[chosen][SAMPLE_SECRET] ? 16 : 4);
      lock_n=1; lock_core_n=chosen; left_n=5'(remaining);
      begin
        left_n=5'(remaining-1);
        if (remaining==1) begin lock_n=0; turn_n=~chosen; end
      end
    end
    if (input_valid_i && input_ready_o) begin
      if (input_bytes_i>=1 && input_bytes_i<=16) begin
        hold_n=1; hold_core_n=input_core_i;
        hold_upper_n=0;
        // Zero unused bytes once at acceptance. In particular the mask path
        // no longer gates each byte with hold_bytes immediately before carry
        // alignment. High-half shifting preserves this zero-padding invariant.
        hold_last_n=input_last_i;
      end
    end
    if(ball_commit_transfer)begin
      tail_n[ball_commit_core_r]=tail_r[ball_commit_core_r]+1'b1;
      generated_n[ball_commit_core_r]=generated_n[ball_commit_core_r]+1'b1;
    end
    // Challenge consumes one position/sign byte per handshake. Copy/sign RAM
    // updates stall its byte port; the shared input beat remains tagged.
    if(hold_r && !capture_pending_r && mode_flags_r[hold_core_r][SAMPLE_BALL])begin
      if(ball_done[hold_core_r] || ball_exhausted[hold_core_r])hold_n=0;
      else if(ball_byte_ready && !failed_r[hold_core_r])begin
        if(hold_bytes_r==1)hold_n=0;
      end
    end
    // Commit registered packed data. No candidate checks or prefix count lie
    // between this stage and the collector. Five-bit addresses wrap modulo32;
    // each bank has one fixed write and output pop only advances its read head.
    if(packed_transfer)begin
      tail_n[commit_core_r]=tail_r[commit_core_r]+5'(commit_count_r);
      generated_n[commit_core_r]=generated_r[commit_core_r]+9'(commit_count_r);
    end
    // Drop pending work on error. Status/reuse waits until both pipeline stages
    // have drained; reset cancels both valids, so no old job can write a new one.
    // Valid tokens retain their reservations while draining after an error.
    // Only packed_transfer may commit; canceled tokens refund at that boundary.
    decode_transfer=decode_valid_r;
    extract_transfer=extract_valid_r;
    if (chunk_fire) begin
      c=int'(hold_core_r);
      begin
        // Finish the admitted word even if its polynomial filled meanwhile.
        // Quota clips surplus candidates to zero;avoids a9-bit completion
        // comparator on half-selector and held-byte control paths.
        if (hold_upper_r || beat_bytes_r<=8) begin
          hold_n=0;
        end else begin
          // Keep non-challenge payload stationary. Capacity only controls this
          // one-bit half selector, rather than a wide holding-register mux.
          hold_upper_n=1;
        end
      end
    end
    for(int core=0;core<2;core++)if(chunk_issue[core])begin
      if(mode_flags_r[core][SAMPLE_MASK])begin
        mask_residual_n[core]=mask_next_carry;mask_bits_n[core]=prepared_mask_bits[hold_upper_r];
      end else if(mode_flags_r[core][SAMPLE_A])begin
        residual_n[core]=next_residual;residual_count_n[core]=next_residual_count;
      end
    end
    // Registered masks include token validity and context ownership. Local
    // failure cancellation avoids the selected-context global write-enable.
    for(int core=0;core<2;core++)for(int row=0;row<COLLECTOR_DEPTH;row++)begin
      // Stage4.9j trial: mode owns the shared data selector; row masks alone
      // enable the write. A context cannot mix challenge and ordinary tokens.
      if(!failed_r[core] && (ball_write_mask_r[core][row] || commit_write_mask_r[core][row]))
        collector_n[core][row]=collector_write_data[core][row%16];
    end
    // Stage4.9d: fixed-context failure equations avoid serial dynamic writes.
    // Preserve the old priority:short final commit > challenge exhaustion >
    // bad input bytes > new descriptor parameter > prior error.
    for(int core=0;core<2;core++)begin
      logic new_descriptor,bad_input,challenge_exhaustion,short_final;
      new_descriptor=job_valid_i && job_ready_o && job_core_i==core;
      bad_input=input_valid_i && input_ready_o && input_core_i==core &&
        (input_bytes_i==0 || input_bytes_i>16);
      challenge_exhaustion=active_r[core] && mode_flags_r[core][SAMPLE_BALL] && ball_exhausted[core];
      short_final=packed_transfer && commit_core_r==core && commit_last_r && generated_n[core]<N;
      failed_n[core]=(failed_r[core] && !new_descriptor) ||
        (new_descriptor && job_param_i==3) || bad_input || challenge_exhaustion || short_final;
      if(new_descriptor)error_n[core]=job_param_i==3 ? STATUS_PARAM:STATUS_OK;
      if(bad_input)error_n[core]=STATUS_BYTES;
      if(challenge_exhaustion || short_final)error_n[core]=STATUS_EXHAUSTED;
    end
    if (hold_r && failed_r[hold_core_r]) hold_n=0;
  end

  // Payload registers need no reset: their valid bits own every use. Both
  // stages advance each clock, so a new chunk can enter while an older commits.
  always_ff @(posedge clk)begin
    // A held beat and a newly accepted beat are mutually exclusive. Save both
    // the persistent per-context state and this local copy on each mask chunk.
    // No reset is needed: hold_r owns use and is reset; acceptance initializes.
    if(input_valid_i && input_ready_o && input_bytes_i>=1 && input_bytes_i<=16)begin
      logic [4:0] lower_bytes,upper_bytes,lower_total,all_total;
      logic [1:0] lower_carry,upper_carry;
      lower_bytes=input_bytes_i>8 ? 5'd8:input_bytes_i;
      upper_bytes=input_bytes_i>8 ? input_bytes_i-5'd8:5'd0;
      lower_total=5'(residual_count_r[input_core_i])+lower_bytes;
      all_total=5'(residual_count_r[input_core_i])+input_bytes_i;
      lower_carry=advance_mod3(residual_count_r[input_core_i],lower_bytes);
      upper_carry=advance_mod3(residual_count_r[input_core_i],input_bytes_i);
      a_carry_bytes_r[0]<=lower_carry;a_carry_bytes_r[1]<=upper_carry;
      a_carry_shift_r[0]<=4'(lower_bytes-5'(lower_carry));
      a_carry_shift_r[1]<=4'(upper_bytes-5'(upper_carry));
      a_has_field_r[0]<=lower_total>=3;
      a_has_field_r[1]<=5'(lower_carry)+upper_bytes>=3;
      mask_has_field_r[0]<=lower_bytes>=3 ||
        (8'(mask_bits_r[input_core_i])+{lower_bytes,3'b000}>=(wide_flag_r[input_core_i] ? 20:18));
      mask_has_field_r[1]<=upper_bytes>=3 ||
        (8'(mask_advance_bits(mask_bits_r[input_core_i],5'd8,wide_flag_r[input_core_i]))+
          {upper_bytes,3'b000}>=(wide_flag_r[input_core_i] ? 20:18));
      mask_lower_bits_r<=mask_advance_bits(mask_bits_r[input_core_i],5'd8,wide_flag_r[input_core_i]);
      ball_byte_index_r<=0;
      mask_work_r<=mask_residual_r[input_core_i];
      mask_work_bits_r<=mask_bits_r[input_core_i];
      mask_work_wide_r<=wide_flag_r[input_core_i];
      mask_carry_shift_r[0]<=mask_carry_shift(mask_bits_r[input_core_i],
        input_bytes_i>8 ? 5'd8:input_bytes_i,wide_flag_r[input_core_i],1'b0);
      mask_carry_shift_r[1]<=mask_carry_shift(mask_bits_r[input_core_i],
        input_bytes_i,wide_flag_r[input_core_i],1'b1);
    end else if(chunk_fire && mode_flags_r[hold_core_r][SAMPLE_MASK])begin
      mask_work_r<=mask_next_carry;mask_work_bits_r<=prepared_mask_bits[hold_upper_r];
    end
    if(hold_r && !capture_pending_r && mode_flags_r[hold_core_r][SAMPLE_BALL] && !failed_r[hold_core_r] &&
       !ball_done[hold_core_r] && !ball_exhausted[hold_core_r] && ball_byte_ready)
      ball_byte_index_r<=ball_byte_index_r+1'b1;
    if(rst)begin extract_valid_r<=0;decode_valid_r<=0;packed_valid_r<=0;commit_valid_r<=0;ball_commit_valid_r<=0;end
    else begin
      extract_valid_r<=chunk_fire;decode_valid_r<=extract_transfer;packed_valid_r<=decode_transfer;
      commit_valid_r<=packed_valid_r;
      ball_commit_valid_r<=ball_result_valid && active_r[ball_result_core] && !failed_r[ball_result_core];
    end
    commit_core_r<=packed_core_r;commit_count_r<=packed_count_r;commit_bound_r<=packed_bound_r;
    commit_base_r<=packed_base_r;commit_last_r<=packed_last_r;
    commit_write_mask_r<=rst ? '0:(packed_write_mask_r & {64{packed_valid_r}});
    commit_data_r<=aligned_coefficient;
    ball_commit_core_r<=ball_result_core;ball_commit_code_r<={ball_result[22],ball_result[0]};
    ball_write_mask_r<=rst ? '0:(ball_write_mask &
      {64{ball_result_valid && active_r[ball_result_core] && !failed_r[ball_result_core]}});
    // Stage4.7c: extraction ends before four-lane local compaction. All payload
    // banks advance while invalid; valid/tag ownership controls every consumer.
    extract_core_r<=hold_core_r;extract_mask_r<=candidate_valid;extract_data_r<=candidate_data;
    extract_secret_r<=candidate_secret;extract_bound_r<=chunk_bound;
    extract_last_r<=hold_last_r && (hold_upper_r || beat_bytes_r<=8);
    extract_is_mask_r<=mode_flags_r[hold_core_r][SAMPLE_MASK];
    extract_is_secret_r<=mode_flags_r[hold_core_r][SAMPLE_SECRET];
    extract_wide_r<=wide_flag_r[hold_core_r];
    // Capture payload every clock: decode_valid_r owns its use. Keeping the
    // capacity check off these data-register enables shortens the launch path.
    begin
      decode_core_r<=extract_core_r;decode_mask_r<=extract_mask_r;decode_data_r<=extract_data_r;
      // One complete packed assignment avoids Quartus dropping the variable
      // outer-dimension part-select writes used by the earlier group loop.
      // The packed64-bit order is identical: group0 holds nibbles0..3.
      decode_secret_r<=secret_group_data;
      decode_total_count_r<=(secret_group_count[0]+secret_group_count[1])+
        (secret_group_count[2]+secret_group_count[3]);
      for(int group_slot=0;group_slot<4;group_slot++)begin
        decode_secret_count_r[group_slot]<=secret_group_count[group_slot][2:0];
      end
      decode_bound_r<=extract_bound_r;decode_last_r<=extract_last_r;
      decode_is_mask_r<=extract_is_mask_r;
      decode_is_secret_r<=extract_is_secret_r;
      decode_wide_r<=extract_wide_r;
    end
    // Stage4.6r: payload may change while invalid. packed_valid_r alone owns
    // every consumer, so no failure/cancel enable is needed on this wide bank.
    // Its valid,core,count,address and payload still refer to the same decode
    // cycle. This preserves both stage depth and cancellation/drain semantics.
    begin
      packed_core_r<=decode_core_r;packed_count_r<=admit_count;packed_wide_r<='0;
      packed_bound_r<=decode_bound_r;
      // Forward this clock's committed append before saving the next write
      // address. Output pops do not change tail. This removes the packed-core
      // selection mux from the collector alignment/write path, with no bubble.
      packed_base_r<=incoming_append_base;
      packed_write_mask_r<=incoming_write_mask;
      packed_is_secret_r<=decode_is_secret_r;packed_secret_r<=compact_data;
      packed_last_r<=decode_last_r;
      // Restore4.9j's stage placement. Shorter20-bit converters operate before
      // packing;collector mask values are canonical again. This retains the
      // original timing depth while reducing each converter's arithmetic.
      if(decode_is_mask_r)begin
        for(int j=0;j<4;j++)
          packed_wide_r[j]<=decode_mask_r[j] ? mask_coefficient(decode_data_r[j][19:0],decode_wide_r):23'd0;
      end else if(!decode_is_secret_r)begin
        for(int j=0;j<3;j++)packed_wide_r[j]<=a_data[j];
      end
    end
  end

  // Payload is captured whenever the holding slot is empty; acceptance only
  // controls hold_r/tag ownership. Challenge uses a byte pointer,not128-bit shifts.
  always_comb begin
    masked_input=input_data_i;
    for(int j=0;j<16;j++)if(j>=input_bytes_i)masked_input[8*j+:8]=0;
  end
  always_ff @(posedge clk)begin
    input_skid_r<=masked_input;
    if(rst)capture_pending_r<=0;else capture_pending_r<=prepare_accept;
    if(capture_pending_r)begin hold_data_r<=input_skid_r;ball_byte_r<=input_skid_r[7:0];end
    else if(hold_r && !capture_pending_r && mode_flags_r[hold_core_r][SAMPLE_BALL] &&
       !failed_r[hold_core_r] && !ball_done[hold_core_r] && !ball_exhausted[hold_core_r] && ball_byte_ready)
      ball_byte_r<=hold_data_r[8*4'(ball_byte_index_r+4'd1)+:8];
    if(prepare_accept)begin beat_bytes_r<=input_bytes_i;ball_remaining_r<=input_bytes_i;end
    else if(hold_r && !capture_pending_r && mode_flags_r[hold_core_r][SAMPLE_BALL] &&
       !failed_r[hold_core_r] && !ball_done[hold_core_r] && !ball_exhausted[hold_core_r] && ball_byte_ready)
      ball_remaining_r<=ball_remaining_r-1'b1;
    // The RAM address is an issued-read counter,not generated+pending on the
    // address path. A one-clock-old count<=24 guarantees<=25 now. At most two
    // additional coefficients can be in RAM/result-commit stages,so27<32.
    for(int k=0;k<2;k++)begin
      if(rst)begin ball_issue_index_r[k]<=0;ball_room_r[k]<=0;end
      else begin
        ball_room_r[k]<=count_r[k]<=24;
        if(job_valid_i && job_ready_o && job_core_i==k)ball_issue_index_r[k]<=0;
        else if(ball_read_valid && ball_read_ready && ball_read_core==k)
          ball_issue_index_r[k]<=ball_issue_index_r[k]+1'b1;
      end
    end
    for(int k=0;k<2;k++)if(!hold_r)
      mask_lower_unfinished_r[k]<=mask_residual_r[k] | (19'(masked_input)<<mask_bits_r[k]);
    // The lower half provides a full cycle to prepare upper carry. Hold the
    // prepared result while the upper half waits for reserved collector space.
    if(!hold_upper_r)mask_upper_carry_r<=mask_prepared_upper;
    for(int k=0;k<2;k++)if(job_valid_i && job_ready_o && job_core_i==k)begin
      mode_flags_r[k]<=4'b0001<<job_mode_i;
      wide_flag_r[k]<=job_param_i!=0;eta4_flag_r[k]<=job_param_i==1;
    end
    // Collector validity/counts reset; payload need not clear to prevent reads.
    // Every readable location is written by its owning job before count grows.
    for(int k=0;k<2;k++)for(int j=0;j<COLLECTOR_DEPTH;j++)collector_r[k][j]<=collector_n[k][j];
  end

  // Reserve worst-case slots at extraction issue. Keep each reservation until
  // commit,then return unused slots. Cancellation returns the entire bound.
  // The threshold sees a register,not a sum of every in-flight stage.
  always_comb begin
    for(int k=0;k<2;k++)begin
      quota_n[k]=(decode_transfer && decode_core_r==k) ?
        (quota_difference[k][9] ? 9'd0:quota_difference[k][8:0]):quota_r[k];
      append_tail_n[k]=(decode_transfer && decode_core_r==k) ?
        (quota_difference[k][9] ? 5'd0:append_tail_r[k]+compact_count):append_tail_r[k];
      slot_refund_n[k]=(commit_valid_r && commit_core_r==k) ?
        (packed_transfer ? 7'(commit_bound_r)-7'(commit_count_r):7'(commit_bound_r)):
        7'(ball_commit_valid_r && ball_commit_core_r==k && !ball_commit_transfer);
      reservation_incoming[k]=chunk_issue[k] ?
        (mode_flags_r[k][SAMPLE_SECRET] ? 7'd16:(mode_flags_r[k][SAMPLE_A] ? 7'd3:7'd4)):
        ((ball_result_valid && ball_result_core==k && active_r[k] && !failed_r[k]) ? 7'd1:7'd0);
      // Carry-save slots+incoming-refund-pop;the final bit is the carry-in.
      reservation_sum[k]=slot_reservation_r[k]^7'(reservation_pending_r[k])^~slot_refund_r[k];
      reservation_carry[k]=((slot_reservation_r[k]&7'(reservation_pending_r[k])) |
        (slot_reservation_r[k]&~slot_refund_r[k]) |
        (7'(reservation_pending_r[k])&~slot_refund_r[k]))<<1;
      slot_reservation_n[k]=reservation_sum[k]+reservation_carry[k]+7'(!reservation_pop_r[k]);
      // Keep status eligibility/arbitration off the credit register reset.
      // Status can retire only after tokens drain;inactive state owns no data.
      if(!active_r[k])slot_reservation_n[k]=0;
      if(job_valid_i && job_ready_o && job_core_i==k)begin
        slot_reservation_n[k]=0;slot_refund_n[k]=0;quota_n[k]=9'(N);append_tail_n[k]=0;
      end
    end
  end

  always_ff @(posedge clk)begin
    if(rst)out_valid_r<=0;
    else if(!out_valid_r || output_ready_i)begin
      out_valid_r<=collector_pop;
      begin
        out_core_r<=chosen;out_id_r<=id_r[chosen];
        out_index_r<=read_index_r[chosen];out_last_r<=read_index_r[chosen]==N-1;
        out_data_r<=mode_flags_r[chosen][SAMPLE_SECRET] ?
          secret_coefficient(read_data_r[chosen][3:0]):read_data_r[chosen];
      end
    end
  end

  // Stage4.7b: independent collector reads terminate before arbitration and
  // formatting. Space, not count/failed eligibility, enables the data flops.
  always_ff @(posedge clk)begin
    if(rst)read_valid_r<=0;
    else for(int k=0;k<2;k++)if(read_space[k])read_valid_r[k]<=read_fill[k];
    for(int k=0;k<2;k++)if(read_space[k])begin
      read_data_r[k]<=collector_r[k][head_r[k]];
      read_index_r[k]<=fetched_r[k][7:0];
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      active_r<=0; failed_r<=0;
      hold_r<=0; hold_core_r<=0; hold_last_r<=0;
      hold_upper_r<=0;
      lock_r<=0; lock_core_r<=0; left_r<=0; turn_r<=0; status_turn_r<=0;
      status_lock_r<=0; status_core_r<=0;
      for (int k=0; k<2; k++) begin
        id_r[k]<=0; error_r[k]<=0; generated_r[k]<=0; emitted_r[k]<=0;fetched_r[k]<=0;
        slot_reservation_r[k]<=0;slot_refund_r[k]<=0;quota_r[k]<=9'(N);append_tail_r[k]<=0;
        mode_r[k]<=0;param_r[k]<=0;
        residual_r[k]<=0; residual_count_r[k]<=0; count_r[k]<=0;
        head_r[k]<=0;tail_r[k]<=0;
        mask_residual_r[k]<=0;mask_bits_r[k]<=0;
      end
    end else begin
      active_r<=active_n; failed_r<=failed_n;
      hold_r<=hold_n; hold_core_r<=hold_core_n; hold_last_r<=hold_last_n;
      hold_upper_r<=hold_upper_n;
      lock_r<=lock_n; lock_core_r<=lock_core_n; left_r<=left_n; turn_r<=turn_n;
      status_turn_r<=status_turn_n;
      status_lock_r<=status_lock_n; status_core_r<=status_core_n;
      for (int k=0; k<2; k++) begin
        id_r[k]<=id_n[k]; error_r[k]<=error_n[k]; generated_r[k]<=generated_n[k];
        mode_r[k]<=mode_n[k];param_r[k]<=param_n[k];
        emitted_r[k]<=emitted_n[k];fetched_r[k]<=fetched_n[k]; residual_r[k]<=residual_n[k];
        slot_reservation_r[k]<=slot_reservation_n[k];slot_refund_r[k]<=slot_refund_n[k];quota_r[k]<=quota_n[k];
        append_tail_r[k]<=append_tail_n[k];
        residual_count_r[k]<=residual_count_n[k]; count_r[k]<=count_n[k];
        head_r[k]<=head_n[k];tail_r[k]<=tail_n[k];
        mask_residual_r[k]<=mask_residual_n[k];mask_bits_r[k]<=mask_bits_n[k];
      end
    end
  end

  // Simulation-only storage/ordering invariants supplement independent checking.
  // synthesis translate_off
  always @(posedge clk) if (!rst) begin
    for(int core=0;core<2;core++)begin
      if(|commit_write_mask_r[core])assert(commit_valid_r && commit_core_r==core && active_r[core])
        else $fatal(1,"Collector row mask lost valid-token/context ownership");
      if(|ball_write_mask_r[core])assert(ball_commit_valid_r && ball_commit_core_r==core && active_r[core])
        else $fatal(1,"Challenge row mask lost valid-token/context ownership");
    end
    if(hold_r && !capture_pending_r && mode_flags_r[hold_core_r][SAMPLE_BALL] && !failed_r[hold_core_r])
      assert(ball_byte_r==hold_data_r[8*ball_byte_index_r+:8])
        else $fatal(1,"Prefetched challenge byte lost held-word ownership");
    for(int k=0;k<2;k++)if(active_r[k] && !failed_r[k] && !mode_flags_r[k][SAMPLE_BALL] && chunk_capacity[k])
      assert(slot_reservation_r[k]+7'(reservation_pending_r[k])<=
        (mode_flags_r[k][SAMPLE_SECRET] ? 7'd16:(mode_flags_r[k][SAMPLE_A] ? 7'd29:7'd28)))
        else $fatal(1,"Registered capacity overbooks outstanding reservations");
    for(int k=0;k<2;k++)if(active_r[k] && !failed_r[k] && mode_flags_r[k][SAMPLE_BALL])begin
      assert(ball_issue_index_r[k]==generated_r[k]+
        9'(ball_commit_valid_r && ball_commit_core_r==k)+
        9'(ball_result_valid && ball_result_core==k))
        else $fatal(1,"Challenge issued index lost outstanding RAM/commit ownership");
      if(ball_read_valid && ball_read_core==k)assert(count_r[k]<=25 &&
        9'(count_r[k])+9'(ball_commit_valid_r && ball_commit_core_r==k)+
        9'(ball_result_valid && ball_result_core==k)<=27)
        else $fatal(1,"Registered challenge room overbooked collector capacity");
    end
    for(int k=0;k<2;k++)if(active_r[k])
      assert(mode_flags_r[k]==(4'b0001<<mode_r[k]) &&
        wide_flag_r[k]==(param_r[k]!=0) && eta4_flag_r[k]==(param_r[k]==1))
        else $fatal(1,"Decoded job flags lost descriptor ownership");
    if(decode_valid_r)
      assert(decode_total_count_r==(decode_is_secret_r ? secret_count:(decode_is_mask_r ? mask_count:a_count)))
        else $fatal(1,"Registered accepted count differs from owned group counts");
    if(packed_transfer)
      assert(commit_base_r==tail_r[commit_core_r])
        else $fatal(1,"Packed append address lost committed-tail forwarding");
    if(packed_valid_r && !packed_is_secret_r)
      assert(packed_count_r<=4)
        else $fatal(1,"Four-slot wide payload alias exceeded its append bound");
    if(packed_valid_r)for(int k=0;k<2;k++)for(int j=0;j<COLLECTOR_DEPTH;j++)
      assert(packed_write_mask_r[k][j]==(packed_core_r==k && 5'(5'(j)-packed_base_r)<packed_count_r))
        else $fatal(1,"Registered collector write mask lost payload ownership");
    if(chunk_fire && mode_flags_r[hold_core_r][SAMPLE_A])begin
      assert(next_residual_count==2'(available-consumed))
        else $fatal(1,"Prepared matrix carry count differs from stream length");
      assert(next_residual==(next_residual_count==0 ? 16'd0 :
        (next_residual_count==1 ? {8'd0,8'(assembled>>(8*consumed))}:16'(assembled>>(8*consumed)))))
        else $fatal(1,"Prepared matrix carry differs from stream extraction");
    end
    if(chunk_fire && mode_flags_r[hold_core_r][SAMPLE_MASK])begin
      assert(mask_work_r==mask_residual_r[hold_core_r] &&
        mask_work_bits_r==mask_bits_r[hold_core_r] &&
        mask_work_wide_r==(wide_flag_r[hold_core_r]))
        else $fatal(1,"Mask working carry lost context ownership");
      if(mask_valid!=0)
        assert(8'(mask_carry_shift_r[hold_upper_r])+8'(mask_bits)==8'(8*chunk_bytes))
          else $fatal(1,"Mask carry shift metadata lost held-half ownership");
      if(chunk_fire)assert(mask_next_carry==mask_residual)
        else $fatal(1,"Parallel-half mask carry differs from stream extraction");
    end
    for (int k=0; k<2; k++) begin
      assert(count_r[k]<=COLLECTOR_DEPTH) else $fatal(1,"Collector overflow");
      assert((ball_write_mask_r[k] & commit_write_mask_r[k])==0)
        else $fatal(1,"Collector sources own the same context/row");
      if(ball_write_mask_r[k]!=0)assert(mode_flags_r[k][SAMPLE_BALL])
        else $fatal(1,"Challenge collector payload lost mode ownership");
      if(commit_write_mask_r[k]!=0)assert(!mode_flags_r[k][SAMPLE_BALL])
        else $fatal(1,"Ordinary collector payload lost mode ownership");
      if(active_r[k] && !failed_r[k])
        assert(5'(tail_r[k]-head_r[k])==5'(count_r[k]))
          else $fatal(1,"Circular collector pointer/count mismatch");
      assert(7'(count_r[k]) +
        ((commit_valid_r && commit_core_r==k) ? 7'(commit_bound_r):7'd0)+
        ((extract_valid_r && extract_core_r==k) ? 7'(extract_bound_r):7'd0) +
        ((decode_valid_r && decode_core_r==k) ? 7'(decode_bound_r):7'd0) +
        ((packed_valid_r && packed_core_r==k) ? 7'(packed_count_r):7'd0)<=COLLECTOR_DEPTH)
        else $fatal(1,"Pipeline capacity reservation overflow");
      assert(slot_reservation_r[k]+7'(reservation_pending_r[k])==7'(count_r[k])+
        ((extract_valid_r && extract_core_r==k) ? 7'(extract_bound_r):7'd0)+
        ((decode_valid_r && decode_core_r==k) ? 7'(decode_bound_r):7'd0)+
        ((packed_valid_r && packed_core_r==k) ? 7'(packed_bound_r):7'd0)+
        ((commit_valid_r && commit_core_r==k) ? 7'(commit_bound_r):7'd0)+
        7'(ball_commit_valid_r && ball_commit_core_r==k)+slot_refund_r[k]+7'(reservation_pop_r[k]))
        else $fatal(1,"Registered slot reservation lost pipeline ownership core%0d slots%0d pending%0d count%0d",k,slot_reservation_r[k],reservation_pending_r[k],count_r[k]);
      if(active_r[k] && reservation_pending_r[k]!=0)
        assert(reservation_pending_r[k]==(mode_flags_r[k][SAMPLE_SECRET] ? 5'd16:
          (mode_flags_r[k][SAMPLE_A] ? 5'd3:(mode_flags_r[k][SAMPLE_BALL] ? 5'd1:5'd4))))
          else $fatal(1,"Pending reservation lost its owning job bound");
      if(active_r[k] && !failed_r[k] && !mode_flags_r[k][SAMPLE_BALL])
        assert(quota_r[k]+generated_r[k]+
          ((commit_valid_r && commit_core_r==k) ? 9'(commit_count_r):9'd0)+
          ((packed_valid_r && packed_core_r==k) ? 9'(packed_count_r):9'd0)==9'(N))
          else $fatal(1,"Admission quota lost uncommitted coefficient ownership");
      if(active_r[k] && !mode_flags_r[k][SAMPLE_BALL])
        assert(append_tail_r[k]==5'(-quota_r[k][4:0]))
          else $fatal(1,"Reserved append pointer lost admitted quota ownership");
      assert(generated_r[k]<=N && emitted_r[k]<=generated_r[k])
        else $fatal(1,"Coefficient accounting violated");
      if(active_r[k])begin
        assert(fetched_r[k]<=generated_r[k] && emitted_r[k]<=fetched_r[k])
          else $fatal(1,"Output fetch/accept accounting violated");
        assert(fetched_r[k]==emitted_r[k]+9'(out_valid_r && out_core_r==k)+9'(read_valid_r[k]))
          else $fatal(1,"Output-slot reservation lost context ownership");
      end
      assert(residual_count_r[k]<=2) else $fatal(1,"Byte carry violated");
      assert(mask_bits_r[k]<(param_r[k]==0 ? 18:20))
        else $fatal(1,"Mask bit carry violated");
    end
  end
  // synthesis translate_on
endmodule
