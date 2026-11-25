`timescale 1ns/1ps
module tb_sampler_writer #(parameter bit MIXED_ORDER=0,DIFFERENT_BANKS=0,STRESS_QUEUE=0);
  logic clk=0;always #5 clk=~clk;
  logic rst=1,job_valid=0,job_ready,job_core=0,job_batch_last=0,writer_ready,sampler_ready;
  logic [1:0] job_mode=0,job_param=0;
  logic [15:0] job_id=0;
  logic [127:0] input_data=0;logic [4:0] input_bytes=0;
  logic input_core=0,input_last=0,input_valid=0,input_ready;
  logic packet_valid,packet_ready,packet_core,packet_last;
  logic [15:0] packet_id;logic [7:0] packet_index;
  logic [91:0] packet_data;logic [4:0] packet_count;
  logic status_valid,status_ready,status_core;logic [15:0] status_id;logic [2:0] status_code;
  logic done_valid,done_ready,done_core;logic [15:0] done_id;logic [2:0] done_code;
  logic writer_fault;logic [1:0] active,source_stop,writer_active;
  int cycles=0,serial[2],ids[2],mode[2],param[2],aborting[2],bad_bytes[2],lengths[2];
  logic [7:0] data[2][4096];logic [91:0] captured[1024];
  bit retired[2];int jobs=0,statuses=0,words=0,input_file,output_file,n;
  string token;
  always @(negedge clk)cycles++;
  assign job_ready=sampler_ready && writer_ready;
  assign done_ready=cycles%7!=0;
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
  sampler #(.BANK_IO(1)) sample(
    .clk(clk),.rst(rst),.job_valid_i(job_valid && writer_ready),.job_ready_o(sampler_ready),
    .job_core_i(job_core),.job_id_i(job_id),.job_mode_i(job_mode),.job_param_i(job_param),
    .input_data_i(input_data),.input_bytes_i(input_bytes),.input_core_i(input_core),.input_last_i(input_last),
    .input_valid_i(input_valid),.input_ready_o(input_ready),.output_data_o(),
    .output_core_o(packet_core),.output_last_o(packet_last),.output_valid_o(packet_valid),
    .output_id_o(packet_id),.output_index_o(packet_index),.output_ready_i(packet_ready),
    .status_valid_o(status_valid),.status_core_o(status_core),.status_id_o(status_id),
    .status_code_o(status_code),.status_ready_i(status_ready),.active_o(active),.source_stop_o(source_stop),
    .output_bank_data_o(packet_data),.output_bank_count_o(packet_count));
  logic [1:0][3:0] probe_write_valid,probe_write_ready;
  logic [1:0][3:0] probe_gate;
  int queue_peak=0,queue_held=0,queue_renew=0,dual_writes=0;
  assign probe_gate={8{!STRESS_QUEUE || cycles%97>=23}};
  assign dut_write_valid_i[0]=probe_write_valid & probe_gate;
  assign probe_write_ready=dut_write_ready_o[0] & probe_gate;
  always @(posedge clk)if(!rst)begin
    if(dut.normal_count_r>queue_peak)queue_peak=dut.normal_count_r;
    if(dut.normal_count_r==2)queue_held++;
    if(dut.normal_push && dut.normal_ready)queue_renew++;
    if($countones(probe_write_valid[1] & probe_write_ready[1])==2)dual_writes++;
  end
  sampler_writer dut(
    .clk(clk),.rst(rst),.job_valid_i(job_valid && sampler_ready),.job_ready_o(writer_ready),
    .job_core_i(job_core),.job_batch_last_i(job_batch_last),.job_mode_i(job_mode),.job_bank_i(DIFFERENT_BANKS?{1'b0,job_core}:2'd0),
    .job_base_i(job_core?10'd64:10'd0),.job_id_i(job_id),
    .packet_valid_i(packet_valid),.packet_ready_o(packet_ready),.packet_core_i(packet_core),
    .packet_last_i(packet_last),.packet_id_i(packet_id),.packet_index_i(packet_index),
    .packet_data_i(packet_data),.packet_count_i(packet_count),
    .status_valid_i(status_valid),.status_core_i(status_core),.status_id_i(status_id),
    .status_code_i(status_code),.status_ready_o(status_ready),.done_valid_o(done_valid),
    .done_ready_i(done_ready),.done_core_o(done_core),.done_id_o(done_id),.done_code_o(done_code),
    .fault_o(writer_fault),.active_o(writer_active),.memory_write_address_o(dut_write_address_i[0]),
    .memory_command_valid_o(dut_command_valid_i[0]),
    .memory_command_ready_i(dut_command_ready_o[0]),
    .memory_command_mask_o(dut_command_mask_i[0]),
    .memory_command_write_o(dut_command_write_i[0]),
    .memory_command_base_o(dut_command_base_i[0]),
    .memory_command_words_o(dut_command_words_i[0]),
    .memory_command_mode_o(dut_command_mode_i[0]),
    .memory_write_valid_o(probe_write_valid),
    .memory_write_ready_i(probe_write_ready),
    .memory_write_data_o(dut_write_data_i[0]),
    .memory_done_valid_i(dut_done_valid_o[0]),
    .memory_done_error_i(dut_done_error_o[0]),
    .memory_done_ready_o(dut_done_ready_i[0]));
  always @(posedge clk)if(!rst)begin
    if(writer_fault)$fatal(1,"Packed sampler writer protocol fault");
    if(job_valid && job_ready)begin retired[job_core]=0;jobs++;end
    if(done_valid && done_ready)begin
      if(done_id!=ids[done_core] || done_code!=0 || retired[done_core])$fatal(1,"Writer completion ownership");
      retired[done_core]=1;statuses++;
    end
  end
  task automatic launch(input int c);
    @(negedge clk);job_core=1'(c);job_id=16'(ids[c]);job_mode=2'(mode[c]);job_param=2'(param[c]);
    job_batch_last=c==1;job_valid=1;
    @(posedge clk);while(!job_ready)@(posedge clk);
    @(negedge clk);job_valid=0;
  endtask
  task automatic feed(input int c,position,packet,output int amount);
    amount=packet%3==0?16:packet%3==1?7:1;
    if(amount>lengths[c]-position)amount=lengths[c]-position;
    @(negedge clk);input_core=1'(c);input_bytes=5'(amount);input_data='1;
    for(int i=0;i<amount;i++)input_data[8*i+:8]=data[c][position+i];
    input_last=position+amount==lengths[c];input_valid=1;
    @(posedge clk);while(!input_ready)@(posedge clk);
    @(negedge clk);input_valid=0;
  endtask
  initial begin
    int position[2],packets[2],amount,turn,watchdog,nwords;
    input_file=$fopen(MIXED_ORDER?"sim/dilithium/writer_mixed_inputs.txt":"sim/dilithium/sampler_inputs.txt","r");
    output_file=$fopen(MIXED_ORDER?(DIFFERENT_BANKS?"sim/dilithium/writer_mixed_different_outputs.txt":"sim/dilithium/writer_mixed_same_outputs.txt"):"sim/dilithium/sampler_writer_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare sampler inputs");
    $fdisplay(output_file,"%s 112",token);
    retired[0]=1;retired[1]=1;repeat(3)@(negedge clk);rst=0;
    for(int pair=0;pair<n/2;pair++)begin
      for(int c=0;c<2;c++)begin
        if($fscanf(input_file,"%d %d %d %d %d %d %d",serial[c],ids[c],mode[c],param[c],aborting[c],bad_bytes[c],lengths[c])!=7)$fatal(1,"Writer fixtures");
        for(int i=0;i<lengths[c];i++)if($fscanf(input_file,"%h",data[c][i])!=1)$fatal(1,"Writer raw bytes");
        position[c]=0;packets[c]=0;
      end
      if(param[0]==3 || aborting[0] || bad_bytes[0]>=0 || lengths[0]<=10)continue;
      launch(0);launch(1);turn=0;watchdog=0;
      while(!retired[0] || !retired[1])begin
        int c;c=turn;turn=1-turn;
        if(position[c]<lengths[c] && !source_stop[c] && !retired[c])begin
          feed(c,position[c],packets[c],amount);position[c]+=amount;packets[c]++;
        end else @(negedge clk);
        if(watchdog++>20000)$fatal(1,"Sampler writer pair timeout");
      end
      for(int c=0;c<2;c++)begin
        nwords=mode[c]==1?16:64;
        banks.read_bank(DIFFERENT_BANKS?c:0,c*64,nwords,captured);
        $fdisplay(output_file,"%0d %0d",serial[c],nwords);
        for(int w=0;w<nwords;w++)begin $fdisplay(output_file,"%023h",captured[w]);words++;end
      end
    end
    if(jobs!=112 || statuses!=112)$fatal(1,"Incomplete sampler writer campaign");
    $fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_SAMPLER_WRITER_CAPTURE_PASS:112 full polynomials/%0d physical words;interleaved same-bank B-port writes;independent Python compare required",words);
    if(STRESS_QUEUE && (queue_peak!=2 || queue_held==0 || queue_renew==0))$fatal(1,"Normal queue stress missing");
    $display("LIGHTHD_WRITER_NORMAL_QUEUE_PASS:depth%0d full_cycles%0d simultaneous_renewals%0d",queue_peak,queue_held,queue_renew);
    if(MIXED_ORDER && DIFFERENT_BANKS && dual_writes==0)$fatal(1,"No independent bank dual write");
    $display("LIGHTHD_WRITER_MIXED_BANK_PASS:mixed%0d different%0d dual_write_cycles%0d",MIXED_ORDER,DIFFERENT_BANKS,dual_writes);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Sampler writer global watchdog");end
endmodule
