`timescale 1ns/1ps
module tb_load_decode;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o,input_valid_i=0,input_ready_o,input_last_i=0;
  logic [2:0] command_op_i=0,done_code_o;logic [1:0] command_param_i=0,command_bank_i=0;
  logic [9:0] command_base_i=0;logic [15:0] command_id_i=0,done_id_o;
  logic [63:0] input_data_i=0;logic [6:0] input_index_i=0;logic [3:0] input_bytes_i=8;
  logic done_valid_o,done_ready_i=0,fault_o;
  logic writer_job_valid_o,writer_job_ready_i,writer_job_core_o,writer_job_batch_last_o;
  logic [1:0] writer_job_mode_o,writer_job_bank_o;
  logic [9:0] writer_job_base_o;logic [15:0] writer_job_id_o;
  logic packet_valid_o,packet_ready_i,packet_core_o,packet_last_o;
  logic [15:0] packet_id_o;logic [7:0] packet_index_o;logic [4:0] packet_count_o;logic [91:0] packet_data_o;
  logic status_valid_o,status_ready_i,status_core_o;logic [15:0] status_id_o;logic [2:0] status_code_o;
  logic writer_done_valid_i,writer_done_core_i,writer_done_ready_o;
  logic [15:0] writer_done_id_i;logic [2:0] writer_done_code_i;
  logic writer_fault,writer_packet_ready;
  load_decode dut(.*);
  logic [1:0][1:0] dut_command_valid_i,dut_command_ready_o;
  logic [1:0][1:0][3:0] dut_command_mask_i,dut_command_write_i,dut_write_valid_i,dut_write_ready_o;
  logic [1:0][1:0][3:0][9:0] dut_command_base_i,dut_read_address_o;
  logic [1:0][1:0][3:0][10:0] dut_command_words_i;
  logic [1:0][1:0][3:0][1:0] dut_command_mode_i;
  logic [1:0][1:0][3:0][91:0] dut_write_data_i,dut_read_data_o;
  logic [1:0][1:0][3:0] dut_read_valid_o,dut_read_ready_i,dut_read_last_o,dut_done_valid_o,dut_done_error_o,dut_done_ready_i;
  assign dut_command_valid_i[1]=0;assign dut_command_mask_i[1]=0;assign dut_command_write_i[1]=0;
  assign dut_command_base_i[1]=0;assign dut_command_words_i[1]=0;assign dut_command_mode_i[1]=0;
  assign dut_write_valid_i[1]=0;assign dut_write_data_i[1]=0;assign dut_read_ready_i[1]=0;assign dut_done_ready_i[1]=0;
  logic [1:0][1:0][3:0][9:0] dut_write_address_i;
  assign dut_write_address_i[1]=0;
  bank_fixture banks(.*);
  assign dut_read_ready_i[0]=0;
  int cycles=0,got=0,packets=0,coefficients=0,errors=0,resets=0,zero_fill_coefficients=0,ram_words=0;
  int decoded[256],model[256];logic [63:0] words[80];
  logic [91:0] readback[1024],gold_word;
  wire packet_allow=cycles%11>3;
  assign packet_ready_i=packet_allow && writer_packet_ready;
  sampler_writer writer(
    .clk(clk),.rst(rst),.job_valid_i(writer_job_valid_o),.job_ready_o(writer_job_ready_i),
    .job_core_i(writer_job_core_o),.job_batch_last_i(writer_job_batch_last_o),.job_mode_i(writer_job_mode_o),
    .job_bank_i(writer_job_bank_o),.job_base_i(writer_job_base_o),.job_id_i(writer_job_id_o),
    .packet_valid_i(packet_valid_o && packet_allow),.packet_ready_o(writer_packet_ready),
    .packet_core_i(packet_core_o),.packet_last_i(packet_last_o),.packet_id_i(packet_id_o),.packet_index_i(packet_index_o),
    .packet_data_i(packet_data_o),.packet_count_i(packet_count_o),
    .status_valid_i(status_valid_o),.status_core_i(status_core_o),.status_id_i(status_id_o),.status_code_i(status_code_o),
    .status_ready_o(status_ready_i),.done_valid_o(writer_done_valid_i),.done_core_o(writer_done_core_i),
    .done_id_o(writer_done_id_i),.done_code_o(writer_done_code_i),.done_ready_i(writer_done_ready_o),
    .fault_o(writer_fault),.active_o(),.memory_write_address_o(dut_write_address_i[0]),
    .memory_command_valid_o(dut_command_valid_i[0]),
    .memory_command_ready_i(dut_command_ready_o[0]),
    .memory_command_mask_o(dut_command_mask_i[0]),
    .memory_command_write_o(dut_command_write_i[0]),
    .memory_command_base_o(dut_command_base_i[0]),
    .memory_command_words_o(dut_command_words_i[0]),
    .memory_command_mode_o(dut_command_mode_i[0]),
    .memory_write_valid_o(dut_write_valid_i[0]),
    .memory_write_ready_i(dut_write_ready_o[0]),
    .memory_write_data_o(dut_write_data_i[0]),
    .memory_done_valid_i(dut_done_valid_o[0]),
    .memory_done_error_i(dut_done_error_o[0]),
    .memory_done_ready_o(dut_done_ready_i[0]));
  always @(negedge clk)cycles++;
  always @(posedge clk)if(rst)got=0;else begin
    if(fault_o || writer_fault)$fatal(1,"Shared decode/write path fault");
    if(packet_valid_o && packet_ready_i)begin
      int amount,value,want;logic [3:0] nibble;
      amount=command_op_i==2?16:4;
      if(packet_id_o!=command_id_i || packet_index_o!=got || packet_count_o!=amount ||
        packet_last_o!=(got+amount==256))$fatal(1,"Shared decoder packet metadata");
      for(int lane=0;lane<amount;lane++)begin
        want=dut.state==dut.ZERO_FILL?0:decoded[got];
        if(command_op_i==2)begin
          nibble=packet_data_o[4*lane+:4];value=nibble[3]?int'(nibble)-16:int'(nibble);
          if(value<0)value+=8380417;
        end else value=int'(packet_data_o[23*lane+:23]);
        if(value!=want)$fatal(1,"Shared decoder packet value op%0d index%0d got%0d want%0d",command_op_i,got,value,want);
        model[got]=want;got++;coefficients++;if(dut.state==dut.ZERO_FILL)zero_fill_coefficients++;
      end
    end
  end
  task automatic verify_ram;
    int n,index,value;
    n=command_op_i==2?16:64;
    banks.read_bank(0,0,n,readback);
    for(int w=0;w<n;w++)begin
      gold_word=0;
      if(command_op_i==2)for(int lane=0;lane<16;lane++)begin
        index=128*(w/8)+8*(w%8)+(lane%8)+(lane>=8?64:0);
        value=model[index]<=4?model[index]:model[index]-8380417;
        gold_word[4*lane+:4]=4'(value);
      end else for(int lane=0;lane<4;lane++)gold_word[23*lane+:23]=23'(model[4*w+lane]);
      if(readback[w]!==gold_word)$fatal(1,"Shared decoder RAM mismatch op%0d word%0d got%h want%h",command_op_i,w,readback[w],gold_word);
      ram_words++;
    end
  endtask
  task automatic run_case(input int op,level,variant,fault=0,input bit abort_run=0);
    int width,eta,gamma,value,encoded,nbits,index,watchdog,expected_error;
    width=(op==0 || op==5)?10:op==1?13:op==2?(level==1?4:3):op==3?(level==0?6:4):(level==0?18:20);
    eta=level==1?4:2;gamma=level==0?131072:524288;nbits=0;
    for(int i=0;i<80;i++)words[i]=0;
    for(int i=0;i<256;i++)begin
      case(op)
        0,5:encoded=(i*37+variant*19)%1024;
        1:encoded=(i*97+variant*29)%8192;
        2:encoded=(i+variant)%(2*eta+1);
        3:encoded=(i+variant)%(level==0?44:16);
        default:encoded=(i*7919+variant*31)%(2*gamma);
      endcase
      case(op)
        0:value=encoded;5:value=encoded*8192;1:value=4096-encoded;
        2:value=eta-encoded;3:value=encoded;default:value=gamma-encoded;
      endcase
      decoded[i]=value<0?value+8380417:value;model[i]=0;
      if(fault==1 && i==19)encoded=op==2?2*eta+1:44;
      for(int bit_index=0;bit_index<width;bit_index++)begin
        words[nbits/64][nbits%64]=encoded[bit_index];nbits++;
      end
    end
    expected_error=fault==1?2:fault>=2?3:level==3 || op>5?1:0;
    @(negedge clk);got=0;command_op_i=3'(op);command_param_i=2'(level);command_id_i++;command_valid_i=1;
    #1;if(!command_ready_o)$fatal(1,"Shared decoder not ready");
    @(negedge clk);command_valid_i=0;index=0;watchdog=0;
    while(!done_valid_o)begin
      if(index<nbits/64)begin
        input_valid_i=cycles%7!=0;input_data_i=words[index];input_index_i=7'(index);
        input_bytes_i=fault==2 && index==1?7:8;
        if(fault==3 && index==1)input_index_i=0;
        input_last_i=fault==4 && index==1?1:index+1==nbits/64;
        @(posedge clk);if(input_valid_i && input_ready_o)index++;
        @(negedge clk);
      end else begin input_valid_i=0;@(negedge clk);end
      if(abort_run && got!=0)begin rst=1;input_valid_i=0;repeat(3)@(negedge clk);rst=0;resets++;return;end
      if(watchdog++>3000)$fatal(1,"Shared decoder timeout state%0d committed%0d writer%0d",dut.state,dut.committed_r,writer.words_r[0]);
    end
    input_valid_i=0;
    if(done_code_o!=expected_error || done_id_o!=command_id_i || (expected_error!=1 && got!=256))
      $fatal(1,"Shared decoder completion op%0d level%0d code%0d expected%0d count%0d",op,level,done_code_o,expected_error,got);
    repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=expected_error)$fatal(1,"Unstable shared decode completion");end
    done_ready_i=1;@(negedge clk);done_ready_i=0;packets++;
    if(expected_error!=0)errors++;
    if(expected_error!=1)verify_ram();
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int op=0;op<6;op++)for(int level=0;level<3;level++)for(int variant=0;variant<2;variant++)run_case(op,level,variant);
    for(int level=0;level<3;level++)run_case(2,level,0,1);
    run_case(3,0,0,1);
    for(int op=0;op<6;op++)begin
      for(int fault=2;fault<=4;fault++)run_case(op,0,0,fault);
      run_case(op,3,0);run_case(op,0,1,0,1);run_case(op,0,2);
    end
    run_case(6,0,0);
    $display("LIGHTHD_SHARED_LOAD_DECODE_PASS:packets%0d coefficients%0d RAMwords%0d invalid%0d resets%0d zero_fill%0d;correct-prefix and bounded cleanup verified",packets,coefficients,ram_words,errors,resets,zero_fill_coefficients);
    $finish;
  end
  initial begin #20000000;$fatal(1,"Shared decode global watchdog");end
endmodule
