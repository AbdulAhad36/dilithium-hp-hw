// One four-BU/three-FIFO engine connected directly to reserved bank ports.
// No polynomial-copy RAM,region leases or retained operand snapshots. Unary
// first-stage reads finish before those ports become final-stage writers.
`default_nettype none
module ntt_dma (
  input wire logic clk,rst,command_valid_i,
  output logic command_ready_o,
  input var ntt_pkg::ntt_op_e command_op_i,
  input wire logic command_accumulate_i,
  input wire logic [1:0] command_a_bank_i,command_b_bank_i,command_c_bank_i,command_d_bank_i,
  input wire logic [9:0] command_a_base_i,command_b_base_i,command_c_base_i,command_d_base_i,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [1:0] done_code_o,
  output logic source_released_o,
  output logic [1:0] memory_command_valid_o,input wire logic [1:0] memory_command_ready_i,
  output logic [1:0][3:0] memory_command_mask_o,memory_command_write_o,
  output logic [1:0][3:0][9:0] memory_command_base_o,
  output logic [1:0][3:0][10:0] memory_command_words_o,
  output logic [1:0][3:0][1:0] memory_command_mode_o,
  output logic [1:0][3:0] memory_write_valid_o,input wire logic [1:0][3:0] memory_write_ready_i,
  output logic [1:0][3:0][91:0] memory_write_data_o,
  input wire logic [1:0][3:0] memory_read_valid_i,
  output logic [1:0][3:0] memory_read_ready_o,
  input wire logic [1:0][3:0][91:0] memory_read_data_i,
  input wire logic [1:0][3:0] memory_done_valid_i,memory_done_error_i,
  output logic [1:0][3:0] memory_done_ready_o
);
  import ntt_pkg::*;
  typedef enum logic [3:0] {IDLE,READ_COMMAND,PRIME,COMPUTE,READ_RETIRE,
    WRITE_COMMAND,FINISH,REPORT,HALT} state_e;
  state_e state;
  ntt_op_e op_r;
  logic mac_r;
  (* preserve *) logic is_pwm_r,is_inverse_r,is_compact_r;
  logic [1:0][3:0] read_command_mask_r,write_mask_next;
  logic [1:0] bank_r[3],destination_r;
  logic [9:0] base_r[3],destination_base_r;
  logic [2:0] source_port_r;
  logic [1:0][3:0] source_mask_r,write_mask_r,completed_r;
  logic [1:0] sent_r;
  logic [6:0] inputs_r,outputs_r;
  logic core_start,core_done,core_busy,load_ready,pwm_ready,result_valid,result_two;
  logic [4:0] load_index;
  logic [5:0] pwm_index,result_index_a,result_index_b;
  logic [91:0] result_a,result_b,source_data[3];
  logic all_sources,source_pop,commands_accepted,all_done,read_done,bad_command,stream_fault;
  logic [1:0][3:0] allocation,source_mask_next;
  logic [2:0] source_port_next;
  logic [1:0] selected_bank[3];
  logic [9:0] selected_base[3];
  logic [1:0] code_r;
  logic source_released_r;
  logic read_release_r,finish_ready_r;
  assign source_released_o=source_released_r;
  logic [1:0][3:0] active_mask;
  assign command_ready_o=!rst && state==IDLE;
  assign done_valid_o=!rst && (state==REPORT || state==HALT);
  assign done_code_o=code_r;
  // Reserve the destination B port first,then place reads on free A/B ports.
  // This admits paper MAC roles and rejects a third same-bank read/write.
  always_comb begin
    selected_bank[0]=command_a_bank_i;selected_bank[1]=command_b_bank_i;selected_bank[2]=command_c_bank_i;
    selected_base[0]=command_a_base_i;selected_base[1]=command_b_base_i;selected_base[2]=command_c_base_i;
    allocation=0;source_mask_next=0;source_port_next=0;
    write_mask_next=0;write_mask_next[1][command_d_bank_i]=1;
    if(command_op_i!=OP_PWM)write_mask_next[0][command_d_bank_i]=1;
    bad_command=command_accumulate_i && command_op_i!=OP_PWM;
    bad_command|=command_d_base_i[5:0]!=0;
    if(command_op_i==OP_PWM)begin
      allocation[1][command_d_bank_i]=1;
      for(int s=0;s<3;s++)if(s<2 || command_accumulate_i)begin
        bad_command|=selected_base[s][5:0]!=0;
        if(!allocation[0][selected_bank[s]])begin
          allocation[0][selected_bank[s]]=1;source_mask_next[0][selected_bank[s]]=1;
        end else if(!allocation[1][selected_bank[s]])begin
          allocation[1][selected_bank[s]]=1;source_mask_next[1][selected_bank[s]]=1;source_port_next[s]=1;
        end else bad_command=1;
      end
    end else begin
      bad_command|=command_op_i==OP_PRE_NTT?command_a_base_i[3:0]!=0:command_a_base_i[5:0]!=0;
      source_mask_next[0][command_a_bank_i]=1;source_mask_next[1][command_a_bank_i]=1;
      source_port_next[1]=1;
    end
  end
  always_comb begin
    all_sources=1;
    for(int s=0;s<3;s++)begin
      source_data[s]=memory_read_data_i[source_port_r[s]][bank_r[s]];
      if(s<2 || mac_r)all_sources&=memory_read_valid_i[source_port_r[s]][bank_r[s]];
    end
    core_start=state==PRIME && all_sources;
    source_pop=state==COMPUTE && (load_ready || pwm_ready) && all_sources;
    active_mask=(is_pwm_r?source_mask_r:8'd0) | write_mask_r;
    all_done=1;read_done=1;
    for(int p=0;p<2;p++)begin
      all_done&=((memory_done_valid_i[p]|completed_r[p])&active_mask[p])==active_mask[p];
      // A/B renewal commands may win arbitration on different clocks. A
      // retired read remains complete after its lane has become a writer.
      read_done&=((memory_done_valid_i[p]|completed_r[p])&source_mask_r[p])==source_mask_r[p];
    end
    memory_command_valid_o=0;memory_command_mask_o=0;memory_command_write_o=0;
    memory_command_base_o=0;memory_command_words_o=0;memory_command_mode_o=0;
    memory_write_valid_o=0;memory_write_data_o=0;memory_read_ready_o=0;memory_done_ready_o=0;
    if(state==READ_COMMAND)begin
      memory_command_mask_o=read_command_mask_r;
      if(is_pwm_r || destination_r!=bank_r[0])memory_command_write_o=write_mask_r;
      for(int s=0;s<3;s++)if(s<2 || mac_r)begin
        memory_command_base_o[source_port_r[s]][bank_r[s]]=base_r[s];
        memory_command_words_o[source_port_r[s]][bank_r[s]]=is_pwm_r?64:32;
        memory_command_mode_o[source_port_r[s]][bank_r[s]]=
          is_inverse_r?1:is_compact_r?2:0;
      end
      if(is_pwm_r)begin
        memory_command_base_o[1][destination_r]=destination_base_r;
        memory_command_words_o[1][destination_r]=64;
      end
      else if(destination_r!=bank_r[0])for(int p=0;p<2;p++)begin
        memory_command_base_o[p][destination_r]=destination_base_r |
          (p==0?10'd0:is_inverse_r?10'd32:10'd1);
        memory_command_words_o[p][destination_r]=32;
        memory_command_mode_o[p][destination_r]=is_inverse_r?0:1;
      end
      for(int p=0;p<2;p++)memory_command_valid_o[p]=!sent_r[p] && memory_command_mask_o[p]!=0;
    end
    if(state==WRITE_COMMAND || (state==READ_RETIRE && read_release_r && destination_r==bank_r[0]))begin
      memory_command_mask_o=write_mask_r;memory_command_write_o=write_mask_r;
      for(int p=0;p<2;p++)begin
        memory_command_valid_o[p]=!sent_r[p];
        memory_command_base_o[p][destination_r]=destination_base_r |
          (p==0?10'd0:is_inverse_r?10'd32:10'd1);
        memory_command_words_o[p][destination_r]=32;
        memory_command_mode_o[p][destination_r]=is_inverse_r?0:1;
      end
    end
    commands_accepted=1;
    for(int p=0;p<2;p++)commands_accepted&=sent_r[p] ||
      (memory_command_mask_o[p]==0) || (memory_command_valid_o[p] && memory_command_ready_i[p]);
    if(source_pop)for(int s=0;s<3;s++)if(s<2 || mac_r)
      memory_read_ready_o[source_port_r[s]][bank_r[s]]=1;
    if(state==READ_RETIRE && read_release_r)memory_done_ready_o=source_mask_r;
    if((state==COMPUTE || state==FINISH) && is_pwm_r)
      memory_done_ready_o=memory_done_valid_i & source_mask_r;
    if(state==FINISH && finish_ready_r)memory_done_ready_o=memory_done_valid_i & active_mask;
    if(result_valid)begin
      memory_write_valid_o[is_pwm_r?1:0][destination_r]=1;
      memory_write_data_o[is_pwm_r?1:0][destination_r]=result_a;
      if(result_two)begin memory_write_valid_o[1][destination_r]=1;memory_write_data_o[1][destination_r]=result_b;end
    end
    stream_fault=(state==COMPUTE && (load_ready || pwm_ready) && !all_sources);
    if(result_valid)begin
      stream_fault|=!memory_write_ready_i[is_pwm_r?1:0][destination_r] ||
        (result_two && !memory_write_ready_i[1][destination_r]);
      stream_fault|=result_index_a!=(is_pwm_r?outputs_r[5:0]:is_inverse_r?outputs_r[5:0]:{outputs_r[4:0],1'b0});
      stream_fault|=result_two!=(!is_pwm_r);
      if(result_two)stream_fault|=result_index_b!=(is_inverse_r?outputs_r[5:0]+6'd32:{outputs_r[4:0],1'b1});
    end
  end
  ntt_core #(.BANK_IO(1)) core(
    .clk(clk),.rst(rst),.start_i(core_start),.op_i(op_r),.busy_o(core_busy),.done_o(core_done),
    .wr_en_i(1'b0),.wr_b_sel_i(1'b0),.wr_addr_i(8'd0),.wr_data_i(23'd0),
    .rd_en_i(1'b0),.rd_addr_i(8'd0),.rd_data_o(),
    .bank_load_valid_i(all_sources),.bank_load_index_i(inputs_r[4:0]),
    .bank_load_a_i(source_data[0]),.bank_load_b_i(source_data[1]),
    .bank_load_ready_o(load_ready),.bank_load_index_o(load_index),
    .bank_pwm_valid_i(all_sources),.bank_pwm_a_i(source_data[0]),.bank_pwm_b_i(source_data[1]),
    .bank_pwm_c_i(source_data[2]),.bank_pwm_accumulate_i(mac_r),
    .bank_pwm_ready_o(pwm_ready),.bank_pwm_index_o(pwm_index),
    .bank_result_valid_o(result_valid),.bank_result_two_o(result_two),
    .bank_result_a_index_o(result_index_a),.bank_result_b_index_o(result_index_b),
    .bank_result_a_o(result_a),.bank_result_b_o(result_b));
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;op_r<=OP_NTT;mac_r<=0;is_pwm_r<=0;is_inverse_r<=0;is_compact_r<=0;read_command_mask_r<=0;source_port_r<=0;source_mask_r<=0;write_mask_r<=0;
      completed_r<=0;sent_r<=0;inputs_r<=0;outputs_r<=0;code_r<=0;destination_r<=0;destination_base_r<=0;source_released_r<=0;
      read_release_r<=0;finish_ready_r<=0;
      for(int s=0;s<3;s++)begin bank_r[s]<=0;base_r[s]<=0;end
    end else begin
      // Break ownership -> client completion -> arbitration -> ownership.
      // Hold each decision until its phase retires;A/B may renew separately.
      if(state==READ_RETIRE && read_done)read_release_r<=1;
      if(state==FINISH && all_done)finish_ready_r<=1;
      for(int p=0;p<2;p++)begin
        if(memory_command_valid_o[p] && memory_command_ready_i[p])sent_r[p]<=1;
        completed_r[p]<=completed_r[p] | (memory_done_valid_i[p]&memory_done_ready_o[p]);
      end
      if(source_pop)inputs_r<=inputs_r+1'b1;
      if(result_valid)outputs_r<=outputs_r+1'b1;
      case(state)
        IDLE:if(command_valid_i)begin
          op_r<=command_op_i;mac_r<=command_accumulate_i;destination_r<=command_d_bank_i;
          is_pwm_r<=command_op_i==OP_PWM;is_inverse_r<=command_op_i==OP_INTT;is_compact_r<=command_op_i==OP_PRE_NTT;
          read_command_mask_r<=source_mask_next |
            (command_op_i==OP_PWM || command_d_bank_i!=command_a_bank_i?write_mask_next:8'd0);
          destination_base_r<=command_d_base_i;code_r<=bad_command?1:0;
          source_port_r<=source_port_next;source_mask_r<=source_mask_next;write_mask_r<=write_mask_next;
          for(int s=0;s<3;s++)begin bank_r[s]<=selected_bank[s];base_r[s]<=selected_base[s];end
          if(command_op_i!=OP_PWM)begin
            bank_r[1]<=command_a_bank_i;
            base_r[1]<=command_a_base_i+(command_op_i==OP_INTT?10'd1:command_op_i==OP_PRE_NTT?10'd8:10'd32);
          end
          sent_r<=0;completed_r<=0;inputs_r<=0;outputs_r<=0;source_released_r<=0;
          read_release_r<=0;finish_ready_r<=0;
          state<=bad_command?REPORT:READ_COMMAND;
        end
        READ_COMMAND:if(commands_accepted)begin state<=PRIME;sent_r<=0;end
        PRIME:if(all_sources)state<=COMPUTE;
        COMPUTE:begin
          if(!is_pwm_r && source_pop && inputs_r==31)state<=READ_RETIRE;
          if(core_done)state<=FINISH;
        end
        READ_RETIRE:if(read_release_r && (destination_r!=bank_r[0] || commands_accepted))begin
          state<=COMPUTE;sent_r<=0;completed_r<=0;source_released_r<=1;
          read_release_r<=0;
        end
        WRITE_COMMAND:if(commands_accepted)begin state<=COMPUTE;sent_r<=0;end
        FINISH:if(finish_ready_r)begin
          if(inputs_r!=(is_pwm_r?64:32) || outputs_r!=(is_pwm_r?64:32))code_r<=2;
          state<=REPORT;
        end
        REPORT:if(done_ready_i)state<=IDLE;
        HALT:state<=HALT;
        default:state<=IDLE;
      endcase
      if(state!=IDLE && state!=REPORT && state!=HALT &&
        (stream_fault || |(memory_done_error_i & memory_done_valid_i & (source_mask_r|write_mask_r))))begin
        state<=HALT;code_r<=2;
      end
    end
  end
// synthesis translate_off
  always @(posedge clk)if(!rst)begin
    if(is_pwm_r!==(op_r==OP_PWM) || is_inverse_r!==(op_r==OP_INTT) || is_compact_r!==(op_r==OP_PRE_NTT))
      $fatal(1,"Cached NTT operation decode differs from binary opcode");
    if(state==READ_COMMAND && read_command_mask_r!==(source_mask_r | (op_r==OP_PWM || destination_r!=bank_r[0]?write_mask_r:8'd0)))
      $fatal(1,"Cached NTT read command mask differs from original equation");
    if((|memory_command_valid_o) && destination_base_r[5:0]!=0)
      $fatal(1,"Unaligned NTT destination reached a physical command");
  end
  // synthesis translate_on
endmodule
`default_nettype wire
