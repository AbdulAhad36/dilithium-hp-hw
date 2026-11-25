`timescale 1ns/1ps
module tb_hash_sampler;
  parameter bit INGRESS_RESET_PROOF=0;
  parameter bit PIPELINE_INPUT=0;
  parameter bit MEMORY_PIPELINE=0;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,job_valid_i=0,job_ready_o,job_core_o,job_batch_last_i=0;
  logic [1:0] job_mode_i=0,job_param_i=0,job_bank_i=0;
  logic [9:0] job_base_i=0;
  logic [15:0] job_id_i=0,message_len_i=0;
  logic [63:0] input_data_i=0;logic input_valid_i=0,input_ready_o;
  logic done_valid_o,done_ready_i,done_core_o;logic [15:0] done_id_o;logic [2:0] done_code_o;
  logic fault_o;logic [1:0] active_o;
  logic raw_valid_i=0,raw_ready_o,raw_core_o,raw_mode_i=1;
  logic [15:0] raw_id_i=0,raw_message_len_i=0,raw_output_len_i=64;
  logic [63:0] raw_input_data_i=0;logic raw_input_valid_i=0,raw_input_ready_o;
  logic raw_output_valid_o,raw_output_core_o;logic [15:0] raw_output_id_o;
  logic [127:0] raw_output_data_o;logic [4:0] raw_output_bytes_o;
  logic raw_output_ready_i,raw_done_valid_o,raw_done_core_o;logic [15:0] raw_done_id_o;logic raw_done_ready_i=0;
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
  bank_fixture #(.TIMING_PIPELINE(MEMORY_PIPELINE)) banks(.*);
  assign dut_read_ready_i[0]=0;
  hash_sampler #(.PIPELINE_INPUT(PIPELINE_INPUT)) dut(
    .clk(clk),.rst(rst),.job_valid_i(job_valid_i),.job_ready_o(job_ready_o),.job_core_o(job_core_o),
    .job_batch_last_i(job_batch_last_i),.job_mode_i(job_mode_i),.job_param_i(job_param_i),
    .job_bank_i(job_bank_i),.job_base_i(job_base_i),.job_id_i(job_id_i),.message_len_i(message_len_i),
    .input_data_i(input_data_i),.input_valid_i(input_valid_i),.input_ready_o(input_ready_o),
    .done_valid_o(done_valid_o),.done_ready_i(done_ready_i),.done_core_o(done_core_o),
    .done_id_o(done_id_o),.done_code_o(done_code_o),.fault_o(fault_o),.active_o(active_o),
    .raw_valid_i(raw_valid_i),.raw_ready_o(raw_ready_o),.raw_core_o(raw_core_o),.raw_mode_i(raw_mode_i),
    .raw_id_i(raw_id_i),.raw_message_len_i(raw_message_len_i),.raw_output_len_i(raw_output_len_i),
    .raw_input_data_i(raw_input_data_i),.raw_input_valid_i(raw_input_valid_i),.raw_input_ready_o(raw_input_ready_o),
    .raw_output_valid_o(raw_output_valid_o),.raw_output_core_o(raw_output_core_o),.raw_output_id_o(raw_output_id_o),
    .raw_output_data_o(raw_output_data_o),.raw_output_bytes_o(raw_output_bytes_o),.raw_output_ready_i(raw_output_ready_i),
    .raw_done_valid_o(raw_done_valid_o),.raw_done_core_o(raw_done_core_o),.raw_done_id_o(raw_done_id_o),.raw_done_ready_i(raw_done_ready_i),
    .memory_write_address_o(dut_write_address_i[0]),
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
  int serial[2],ids[2],mode[2],param[2],aborting[2],lengths[2],core_map[2];
  logic [7:0] message[2][512];string token,hex;
  bit retired[2],live[2];int cycles=0,jobs=0,statuses=0,invalids=0,aborts=0,words=0,raw_beats=0;
  int input_file,output_file,n;
  logic [91:0] captured[1024];
  always @(negedge clk)cycles++;
  assign done_ready_i=cycles%9>2;
  assign raw_output_ready_i=cycles%11>3;
  always @(posedge clk)if(!rst)begin
    if(fault_o)$fatal(1,"Keccak sampler writer fault");
    if(done_valid_o && done_ready_i)begin
      int c;c=-1;
      for(int i=0;i<2;i++)if(live[i] && ids[i]==done_id_o)c=i;
      if(c<0 || retired[c] || done_code_o!=(param[c]==3?3:0))$fatal(1,"Hash sampler completion ownership/code");
      if(param[c]!=3 && done_core_o!=core_map[c])$fatal(1,"Hash sampler context mismatch");
      live[c]=0;retired[c]=1;statuses++;if(param[c]==3)invalids++;
    end
    if(raw_output_valid_o && raw_output_ready_i)begin
      if(raw_output_id_o!=raw_id_i || raw_output_bytes_o!=16 || raw_beats>=4)$fatal(1,"Raw shared Keccak ownership/count");
      $fdisplay(output_file,"%032h",raw_output_data_o);raw_beats++;
    end
  end
  task automatic launch(input int c);
    int watchdog;
    @(negedge clk);job_mode_i=2'(mode[c]);job_param_i=2'(param[c]);
    job_base_i=10'(c*64);job_id_i=16'(ids[c]);message_len_i=16'(lengths[c]);job_batch_last_i=c==1;job_valid_i=1;
    watchdog=0;@(posedge clk);while(!job_ready_o)begin
      @(posedge clk);if(watchdog++>10000)$fatal(1,"Hash sampler launch timeout");
    end
    core_map[c]=int'(job_core_o);retired[c]=0;live[c]=1;jobs++;
    @(negedge clk);job_valid_i=0;
    if(param[c]==3)return;
    for(int w=0;w<(lengths[c]+7)/8;w++)begin
      input_data_i='1;
      for(int lane=0;lane<8;lane++)if(w*8+lane<lengths[c])input_data_i[8*lane+:8]=message[c][8*w+lane];
      input_valid_i=1;watchdog=0;@(posedge clk);while(!input_ready_o)begin
        @(posedge clk);if(watchdog++>10000)$fatal(1,"Hash sampler absorption timeout");
      end
      @(negedge clk);input_valid_i=0;
    end
  endtask
  task automatic raw_hash(input int test,length);
    int watchdog;logic captured_core;
    @(negedge clk);raw_id_i=16'(5000+test);raw_message_len_i=16'(length);raw_mode_i=test!=0;raw_valid_i=1;raw_beats=0;
    @(posedge clk);while(!raw_ready_o)@(posedge clk);
    captured_core=raw_core_o;@(negedge clk);raw_valid_i=0;
    $fdisplay(output_file,"H %0d 4",test);
    for(int w=0;w<(length+7)/8;w++)begin
      raw_input_data_i='1;
      for(int lane=0;lane<8;lane++)if(w*8+lane<length)raw_input_data_i[8*lane+:8]=8'((w*8+lane)*17+test);
      raw_input_valid_i=1;@(posedge clk);while(!raw_input_ready_o)@(posedge clk);
      @(negedge clk);raw_input_valid_i=0;
    end
    watchdog=0;
    while(!raw_done_valid_o)begin @(negedge clk);if(watchdog++>10000)$fatal(1,"Raw hash timeout");end
    if(raw_done_id_o!=raw_id_i || raw_done_core_o!=captured_core || raw_beats!=4)$fatal(1,"Raw done metadata/count");
    raw_done_ready_i=1;@(negedge clk);raw_done_ready_i=0;
  endtask
  initial begin
    int watchdog,nwords;
    input_file=$fopen("sim/dilithium/chain_inputs.txt","r");
    output_file=$fopen("sim/dilithium/hash_sampler_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare chain fixtures");
    $fdisplay(output_file,"%s 91",token);
    retired[0]=1;retired[1]=1;live[0]=0;live[1]=0;
    repeat(3)@(negedge clk);rst=0;
    if(INGRESS_RESET_PROOF && PIPELINE_INPUT)begin
      // Hold the actual native input handshake,fill both new slots,hold a
      // third offer,then reset before any of this descriptor can produce data.
      @(negedge clk);raw_id_i=4999;raw_message_len_i=33;raw_mode_i=1;raw_valid_i=1;
      do @(posedge clk);while(!raw_ready_o);
      @(negedge clk);raw_valid_i=0;
      force dut.engine.hash.input_ready_o=1'b0;
      for(int beat=0;beat<2;beat++)begin
        raw_input_data_i=64'(beat+1);raw_input_valid_i=1;
        @(posedge clk);if(!raw_input_ready_o)$fatal(1,"Ingress failed to accept available slot");
        @(negedge clk);
      end
      #1;if(dut.engine.ingress_count_r!=2 || raw_input_ready_o)$fatal(1,"Ingress full credit");
      repeat(5)begin @(negedge clk);if(raw_input_ready_o || dut.engine.ingress_count_r!=2)$fatal(1,"Ingress held offer leaked");end
      rst=1;raw_input_valid_i=0;release dut.engine.hash.input_ready_o;
      repeat(3)@(negedge clk);rst=0;#1;
      if(dut.engine.ingress_count_r!=0 || dut.engine.ingress_left_r!=0 || active_o!=0)
        $fatal(1,"Ingress reset failed to squash queued payload/credits");
      $display("SHAKE_INGRESS_FULL_RESET_PASS:2queued words/third held offer/5stalls/reset;following independent jobs check stale-data isolation");
    end
    for(int pair=0;pair<n/2;pair++)begin
      for(int c=0;c<2;c++)begin
        if($fscanf(input_file,"%d %d %d %d %d %d %s",serial[c],ids[c],mode[c],param[c],aborting[c],lengths[c],hex)!=7)$fatal(1,"Chain fixtures");
        for(int i=0;i<lengths[c];i++)message[c][i]=8'(hex.substr(2*i,2*i+1).atohex());
      end
      launch(0);launch(1);
      if(aborting[0])begin
        repeat(3)@(negedge clk);
        if(active_o==0)$fatal(1,"Reset case reached no live sampler");
        rst=1;input_valid_i=0;live[0]=0;live[1]=0;retired[0]=1;retired[1]=1;aborts+=2;
        repeat(3)@(negedge clk);rst=0;continue;
      end
      watchdog=0;
      while(!retired[0] || !retired[1])begin
        @(negedge clk);if(watchdog++>20000)$fatal(1,"Hash sampler completion timeout");
      end
      if(param[0]==3)continue;
      for(int c=0;c<2;c++)begin
        nwords=mode[c]==1?16:64;banks.read_bank(0,c*64,nwords,captured);
        $fdisplay(output_file,"P %0d %0d",serial[c],nwords);
        for(int w=0;w<nwords;w++)begin $fdisplay(output_file,"%023h",captured[w]);words++;end
      end
    end
    raw_hash(0,0);raw_hash(1,33);raw_hash(2,136);
    if(jobs!=104 || statuses!=96 || invalids!=8 || aborts!=8)$fatal(1,"Incomplete chain campaign");
    $fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_HASH_SAMPLER_CAPTURE_PASS:104 commands/88 complete polynomials/8 rejected/8 reset aborts/%0d physical words/3 shared raw hashes;independent Python compare required",words);
    $finish;
  end
  initial begin #20000000;$fatal(1,"Hash sampler global watchdog");end
endmodule
