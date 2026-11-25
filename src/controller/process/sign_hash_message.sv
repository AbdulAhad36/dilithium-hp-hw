// Signing absorption formatter,not a hash engine. Byte0 is bits7:0.
// op0:pure-ML-DSA mu;op1:private mask seed;op2:challenge;op3:one mask nonce.
// Payload =ctx||M for op0,already encoded w1 for op2;other ops have no payload.
// After a malformed payload beat,zero-fill the remaining descriptor length.
// Owner MUST discard that hash and retain ownership until hash/sampler retires.
// Formatter done only reports completed absorption,not hash completion.
`default_nettype none
module sign_hash_message #(
  // Compact operation owners already retain these fields until prefix use
  // finishes. Reuse that storage;generic callers retain snapshot semantics.
  parameter bit STABLE_PREFIX_INPUTS=0
) (
  input wire logic clk,rst,command_valid_i,output logic command_ready_o,busy_o,
  input wire logic [1:0] command_op_i,command_param_i,
  input wire logic [15:0] command_id_i,command_message_len_i,command_nonce_i,
  input wire logic [8:0] command_context_len_i,
  input tri0 command_internal_message_i,
  input wire logic [511:0] command_tr_i,command_mu_i,command_mask_seed_i,
  input wire logic [255:0] command_key_i,command_rnd_i,
  input wire logic payload_valid_i,output logic payload_ready_o,
  input wire logic [63:0] payload_data_i,input wire logic [3:0] payload_bytes_i,
  input wire logic [15:0] payload_index_i,input wire logic payload_last_i,
  output logic request_valid_o,input wire logic request_ready_i,
  output logic request_sampling_o,request_mode_o,
  output logic [1:0] request_param_o,output logic [15:0] request_id_o,
  output logic [15:0] request_message_len_o,request_output_len_o,
  output logic input_valid_o,input wire logic input_ready_i,
  output logic [63:0] input_data_o,output logic [3:0] input_bytes_o,
  output logic [15:0] input_index_o,output logic input_last_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,output logic [15:0] done_id_o
);
  typedef enum logic [1:0] {IDLE,REQUEST,EMIT,REPORT} state_e;
  state_e state;
  logic [1023:0] prefix_r;logic [7:0] prefix_left_r;
  logic [127:0] bits_r;logic [4:0] count_r;
  logic [15:0] produced_r,payload_left_r,payload_word_r;
  logic draining_r,bad_command,bad_payload;
  logic [17:0] command_total;
  logic [15:0] command_body;
  logic [3:0] take,expected_payload_bytes,prefix_take;
  logic [63:0] chunk;
  logic push,pop;
  logic [1:0] prefix_op_r;
  logic [7:0] context_byte_r;logic internal_message_r;
  logic [15:0] nonce_r;
  logic [3:0] prefix_word_r;
  logic [1023:0] command_prefix,owned_prefix;
  logic [63:0] prefix_chunk;
  always_comb begin
    case(command_op_i)
      0:command_prefix=command_internal_message_i?{512'd0,command_tr_i}:{496'd0,command_context_len_i[7:0],8'd0,command_tr_i};
      1:command_prefix={command_mu_i,command_rnd_i,command_key_i};
      2:command_prefix={512'd0,command_mu_i};
      default:command_prefix={496'd0,command_nonce_i,command_mask_seed_i};
    endcase
    case(prefix_op_r)
      0:owned_prefix=internal_message_r?{512'd0,command_tr_i}:{496'd0,context_byte_r,8'd0,command_tr_i};
      1:owned_prefix={command_mu_i,command_rnd_i,command_key_i};
      2:owned_prefix={512'd0,command_mu_i};
      default:owned_prefix={496'd0,nonce_r,command_mask_seed_i};
    endcase
  end
  assign prefix_chunk=STABLE_PREFIX_INPUTS?owned_prefix[64*prefix_word_r+:64]:prefix_r[63:0];
  always_comb begin
    command_body=0;command_total=0;
    case(command_op_i)
      0:begin command_total=(command_internal_message_i?18'd64:18'd66+18'(command_context_len_i))+18'(command_message_len_i);
        command_body=(command_internal_message_i?16'd0:16'(command_context_len_i))+command_message_len_i;end
      1:command_total=128;
      2:begin command_body=command_param_i==2?16'd1024:16'd768;command_total=18'd64+18'(command_body);end
      3:command_total=66;
    endcase
    bad_command=command_param_i==3 || command_total>65535 ||
      (command_op_i==0 && (command_context_len_i>255 || (command_internal_message_i && command_context_len_i!=0)));
    take=0;chunk=0;push=0;
    expected_payload_bytes=payload_left_r>=8?4'd8:4'(payload_left_r);
    prefix_take=prefix_left_r>=8?4'd8:4'(prefix_left_r);
    bad_payload=payload_bytes_i!=expected_payload_bytes || payload_index_i!=payload_word_r ||
      payload_last_i!=(payload_left_r<=8);
    // Form each source's masked data independently of admission. The wide
    // produced/length and framing checks qualify the register write once;
    // they must not also pass through take,byte masks and the data shifter.
    if(prefix_left_r!=0)begin
      take=prefix_take;
      for(int b=0;b<8;b++)if(b<int'(prefix_take))chunk[8*b+:8]=prefix_chunk[8*b+:8];
    end else if(draining_r)begin
      take=request_message_len_o-produced_r>=8?4'd8:4'(request_message_len_o-produced_r);
    end else begin
      take=expected_payload_bytes;
      for(int b=0;b<8;b++)if(b<int'(expected_payload_bytes))chunk[8*b+:8]=payload_data_i[8*b+:8];
    end
    push=!rst && state==EMIT && count_r<8 && produced_r<request_message_len_o &&
      (prefix_left_r!=0 || draining_r || (payload_valid_i && payload_ready_o && !bad_payload));
  end
  assign command_ready_o=!rst && state==IDLE;assign busy_o=state!=IDLE;
  assign request_valid_o=!rst && state==REQUEST;assign request_mode_o=1;
  assign payload_ready_o=!rst && state==EMIT && prefix_left_r==0 && !draining_r &&
    payload_left_r!=0 && count_r<8;
  assign input_valid_o=!rst && state==EMIT && (count_r>=8 ||
    (produced_r==request_message_len_o && count_r!=0));
  assign input_data_o=bits_r[63:0];assign input_bytes_o=count_r>=8?4'd8:4'(count_r);
  assign input_last_o=produced_r==request_message_len_o && count_r<=8;
  assign pop=input_valid_o && input_ready_i;
  assign done_valid_o=!rst && state==REPORT;assign done_id_o=request_id_o;
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;prefix_r<=0;prefix_left_r<=0;bits_r<=0;count_r<=0;
      produced_r<=0;payload_left_r<=0;payload_word_r<=0;draining_r<=0;
      request_sampling_o<=0;request_param_o<=0;request_id_o<=0;request_message_len_o<=0;request_output_len_o<=0;
      input_index_o<=0;done_code_o<=0;
      prefix_op_r<=0;context_byte_r<=0;internal_message_r<=0;nonce_r<=0;prefix_word_r<=0;
    end else case(state)
      IDLE:if(command_valid_i)begin
        prefix_r<=0;prefix_left_r<=0;bits_r<=0;count_r<=0;produced_r<=0;
        prefix_op_r<=command_op_i;context_byte_r<=command_context_len_i[7:0];internal_message_r<=command_internal_message_i;nonce_r<=command_nonce_i;prefix_word_r<=0;
        if(!STABLE_PREFIX_INPUTS)prefix_r<=command_prefix;
        payload_left_r<=command_body;payload_word_r<=0;draining_r<=0;input_index_o<=0;
        request_sampling_o<=command_op_i==3;request_param_o<=command_param_i;request_id_o<=command_id_i;
        request_message_len_o<=16'(command_total);request_output_len_o<=command_op_i==3?16'd0:
          (command_op_i==2?(command_param_i==0?16'd32:(command_param_i==1?16'd48:16'd64)):16'd64);
        done_code_o<=bad_command?3'd1:3'd0;
        case(command_op_i)
          0:prefix_left_r<=command_internal_message_i?64:66;
          1:prefix_left_r<=128;
          2:prefix_left_r<=64;
          3:prefix_left_r<=66;
        endcase
        state<=bad_command?REPORT:REQUEST;
      end
      REQUEST:if(request_ready_i)state<=EMIT;
      EMIT:begin
        if(push)begin
          // push implies count_r<8,so only these three offset bits can be
          // active. Preserve the byte stream without a wider barrel shifter.
          bits_r<=bits_r | (128'(chunk)<<{count_r[2:0],3'b0});count_r<=count_r+5'(take);produced_r<=produced_r+16'(take);
          if(prefix_left_r!=0)begin
            prefix_left_r<=prefix_left_r-8'(take);
            if(STABLE_PREFIX_INPUTS)prefix_word_r<=prefix_word_r+1'b1;
            else prefix_r<=prefix_r>>64;
          end
          else if(!draining_r)begin payload_left_r<=payload_left_r-16'(take);payload_word_r<=payload_word_r+1'b1;end
        end
        if(payload_valid_i && payload_ready_o && bad_payload)begin
          done_code_o<=2;draining_r<=1;payload_left_r<=0;
        end
        if(pop)begin
          bits_r<=bits_r>>64;count_r<=count_r-5'(input_bytes_o);input_index_o<=input_index_o+1'b1;
          if(input_last_o)state<=REPORT;
        end
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:begin done_code_o<=3;state<=REPORT;end
    endcase
  end
`ifndef SYNTHESIS
  // synthesis translate_off
  logic [1023:0] prefix_witness;
  always @(posedge clk)if(!rst && STABLE_PREFIX_INPUTS)begin
    if(command_valid_i && command_ready_o)prefix_witness<=command_prefix;
    if((state==REQUEST || state==EMIT) && prefix_left_r!=0 && owned_prefix!==prefix_witness)
      $fatal(1,"Formatter owner changed prefix before consumption");
  end
  // synthesis translate_on
`endif
endmodule
`default_nettype wire
