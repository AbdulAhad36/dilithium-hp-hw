`timescale 1ns/1ps
module tb_sampler_writer_queue;
  parameter bit CYCLE_REFERENCE=0;
  logic clk=0,rst=1;always #5 clk=~clk;
  logic job_valid_i=0,job_ready_o,job_core_i=0,job_batch_last_i=0;
  logic [1:0] job_mode_i=0,job_bank_i=0;logic [9:0] job_base_i=0;logic [15:0] job_id_i=0;
  logic packet_valid_i=0,packet_ready_o,packet_core_i=0,packet_last_i=0;
  logic [15:0] packet_id_i=0;logic [7:0] packet_index_i=0;
  logic [91:0] packet_data_i=0;logic [4:0] packet_count_i=4;
  logic status_valid_i=0,status_core_i=0,status_ready_o;logic [15:0] status_id_i=0;logic [2:0] status_code_i=0;
  logic done_valid_o,done_ready_i,done_core_o,fault_o,idle_o;
  logic [15:0] done_id_o;logic [2:0] done_code_o;logic [1:0] active_o;
  logic [1:0] memory_command_valid_o,memory_command_ready_i=3;
  logic [1:0][3:0] memory_command_mask_o,memory_command_write_o;
  logic [1:0][3:0][9:0] memory_command_base_o;
  logic [1:0][3:0][10:0] memory_command_words_o;
  logic [1:0][3:0][1:0] memory_command_mode_o;
  logic [1:0][3:0] memory_write_valid_o,memory_write_ready_i,memory_done_valid_i,memory_done_error_i=0,memory_done_ready_o;
  logic [1:0][3:0][91:0] memory_write_data_o;logic [1:0][3:0][9:0] memory_write_address_o;
  sampler_writer dut(.*);
  generate if(CYCLE_REFERENCE)begin:timing_reference
    int checked_clocks=0;
    logic reference_job_ready_o;
    logic reference_packet_ready_o;
    logic reference_status_ready_o;
    logic reference_done_valid_o;
    logic reference_done_core_o;
    logic [15:0] reference_done_id_o;
    logic [2:0] reference_done_code_o;
    logic reference_fault_o;
    logic [1:0] reference_active_o;
    logic reference_idle_o;
    logic [1:0] reference_memory_command_valid_o;
    logic [1:0][3:0] reference_memory_command_mask_o;
    logic [1:0][3:0] reference_memory_command_write_o;
    logic [1:0][3:0][9:0] reference_memory_command_base_o;
    logic [1:0][3:0][10:0] reference_memory_command_words_o;
    logic [1:0][3:0][1:0] reference_memory_command_mode_o;
    logic [1:0][3:0] reference_memory_write_valid_o;
    logic [1:0][3:0][91:0] reference_memory_write_data_o;
    logic [1:0][3:0][9:0] reference_memory_write_address_o;
    logic [1:0][3:0] reference_memory_done_ready_o;
    sampler_writer_timing_reference reference_dut(
    .clk(clk),
    .rst(rst),
    .job_valid_i(job_valid_i),
    .job_ready_o(reference_job_ready_o),
    .job_core_i(job_core_i),
    .job_batch_last_i(job_batch_last_i),
    .job_mode_i(job_mode_i),
    .job_bank_i(job_bank_i),
    .job_base_i(job_base_i),
    .job_id_i(job_id_i),
    .packet_valid_i(packet_valid_i),
    .packet_ready_o(reference_packet_ready_o),
    .packet_core_i(packet_core_i),
    .packet_last_i(packet_last_i),
    .packet_id_i(packet_id_i),
    .packet_index_i(packet_index_i),
    .packet_data_i(packet_data_i),
    .packet_count_i(packet_count_i),
    .status_valid_i(status_valid_i),
    .status_core_i(status_core_i),
    .status_id_i(status_id_i),
    .status_code_i(status_code_i),
    .status_ready_o(reference_status_ready_o),
    .done_valid_o(reference_done_valid_o),
    .done_ready_i(done_ready_i),
    .done_core_o(reference_done_core_o),
    .done_id_o(reference_done_id_o),
    .done_code_o(reference_done_code_o),
    .fault_o(reference_fault_o),
    .active_o(reference_active_o),
    .idle_o(reference_idle_o),
    .memory_command_valid_o(reference_memory_command_valid_o),
    .memory_command_ready_i(memory_command_ready_i),
    .memory_command_mask_o(reference_memory_command_mask_o),
    .memory_command_write_o(reference_memory_command_write_o),
    .memory_command_base_o(reference_memory_command_base_o),
    .memory_command_words_o(reference_memory_command_words_o),
    .memory_command_mode_o(reference_memory_command_mode_o),
    .memory_write_valid_o(reference_memory_write_valid_o),
    .memory_write_ready_i(memory_write_ready_i),
    .memory_write_data_o(reference_memory_write_data_o),
    .memory_write_address_o(reference_memory_write_address_o),
    .memory_done_valid_i(memory_done_valid_i),
    .memory_done_error_i(memory_done_error_i),
    .memory_done_ready_o(reference_memory_done_ready_o)
    );
    always @(posedge clk)if(!rst)begin
      if(job_ready_o !== reference_job_ready_o ||
         packet_ready_o !== reference_packet_ready_o ||
         status_ready_o !== reference_status_ready_o ||
         done_valid_o !== reference_done_valid_o ||
         done_core_o !== reference_done_core_o ||
         done_id_o !== reference_done_id_o ||
         done_code_o !== reference_done_code_o ||
         fault_o !== reference_fault_o ||
         active_o !== reference_active_o ||
         idle_o !== reference_idle_o ||
         memory_command_valid_o !== reference_memory_command_valid_o ||
         memory_command_mask_o !== reference_memory_command_mask_o ||
         memory_command_write_o !== reference_memory_command_write_o ||
         memory_command_base_o !== reference_memory_command_base_o ||
         memory_command_words_o !== reference_memory_command_words_o ||
         memory_command_mode_o !== reference_memory_command_mode_o ||
         memory_write_valid_o !== reference_memory_write_valid_o ||
         memory_write_data_o !== reference_memory_write_data_o ||
         memory_write_address_o !== reference_memory_write_address_o ||
         memory_done_ready_o !== reference_memory_done_ready_o)$fatal(1,"Writer fault rewrite changed an output/cycle");
      checked_clocks++;
    end
    final $display("WRITER_CYCLE_REFERENCE_PASS:%0d clocks/all public pins including fault timing",checked_clocks);
  end endgenerate

  int cycles=0,profile=0,base[2],bank[2],ids[2],next_write[2],planned[4],committed[4];
  int total_writes=0,total_completions=0,batches=0,reset_cases=0,rejections=0,reset_prefix_writes=0;
  int streak=0,longest=0,full_cycles=0,renewals=0,held_checks=0;
  bit blocked=0,expect_fault=0;bit [3:0] reserved=0,held=0;
  logic [3:0][101:0] held_tuple;
  function automatic logic [91:0] word_value(input int core,word_index);
    logic [91:0] result;
    for(int lane=0;lane<4;lane++)result[23*lane+:23]=23'(100000*core+word_index*31+lane*7919+17);
    return result;
  endfunction
  always @(negedge clk)cycles++;
  assign done_ready_i=profile==0 || cycles%7!=0;
  always_comb begin
    memory_write_ready_i=0;memory_done_valid_i=0;
    for(int b=0;b<4;b++)begin
      memory_write_ready_i[1][b]=!rst && reserved[b] && !blocked &&
        (profile==0 || (profile==1?cycles%37>=13:cycles%11>=4));
      memory_done_valid_i[1][b]=!rst && reserved[b] && committed[b]==planned[b];
    end
  end
  always @(posedge clk)begin
    bit wrote;
    wrote=0;
    if(rst)begin
      reserved=0;held=0;streak=0;
      for(int c=0;c<2;c++)next_write[c]=0;
      for(int b=0;b<4;b++)begin planned[b]=0;committed[b]=0;end
    end else begin
      if(fault_o && !expect_fault)$fatal(1,"Unexpected writer fault");
      if(job_valid_i && job_ready_o)next_write[job_core_i]=0;
      if(dut.normal_count_r==2)begin
        full_cycles++;
        if(packet_ready_o && packet_valid_i && !dut.secret_r[packet_core_i])$fatal(1,"Full normal handoff accepted a third word");
      end
      if(dut.normal_push && dut.normal_ready)renewals++;
      if(memory_command_valid_o[0] || |memory_write_valid_o[0])$fatal(1,"Sampler used A port");
      if(memory_command_valid_o[1] && memory_command_ready_i[1])begin
        for(int b=0;b<4;b++)if(memory_command_mask_o[1][b])begin
          if(reserved[b] || !memory_command_write_o[1][b] || memory_command_mode_o[1][b]!=2)
            $fatal(1,"Bad bounded B-port reservation");
          reserved[b]=1;planned[b]=int'(memory_command_words_o[1][b]);committed[b]=0;
        end
      end
      for(int b=0;b<4;b++)begin
        if(held[b])begin
          if(!memory_write_valid_o[1][b] || {memory_write_address_o[1][b],memory_write_data_o[1][b]}!==held_tuple[b])
            $fatal(1,"Stalled normal memory request changed");
          held_checks++;
        end
        held[b]=memory_write_valid_o[1][b] && !memory_write_ready_i[1][b];
        held_tuple[b]={memory_write_address_o[1][b],memory_write_data_o[1][b]};
        if(memory_write_valid_o[1][b] && memory_write_ready_i[1][b])begin
          int c;bit found;
          found=0;
          for(int probe=0;probe<2;probe++)if(bank[probe]==b &&
            int'(memory_write_address_o[1][b])>=base[probe] && int'(memory_write_address_o[1][b])<base[probe]+64)begin c=probe;found=1;end
          if(!found || memory_write_address_o[1][b]!=10'(base[c]+next_write[c]) ||
            memory_write_data_o[1][b]!==word_value(c,next_write[c]))$fatal(1,"Committed context/address/payload differs bank%0d addr%0d core%0d word%0d",b,memory_write_address_o[1][b],c,next_write[c]);
          next_write[c]++;committed[b]++;total_writes++;wrote=1;
          if(committed[b]>planned[b])$fatal(1,"B burst overflow");
        end
        if(memory_done_valid_i[1][b] && memory_done_ready_o[1][b])reserved[b]=0;
      end
      if(wrote)begin streak++;if(streak>longest)longest=streak;end else streak=0;
      if(done_valid_o && done_ready_i)begin
        if(done_code_o!=0 || done_id_o!=16'(ids[done_core_o]) || next_write[done_core_o]!=64)
          $fatal(1,"Completion preceded all64 physical writes");
        total_completions++;
      end
    end
  end
  task automatic reset_dut;
    @(negedge clk);rst=1;job_valid_i=0;packet_valid_i=0;status_valid_i=0;
    repeat(3)@(negedge clk);
    if(dut.normal_count_r!=0 || fault_o || active_o!=0)$fatal(1,"Reset retained queued ownership");
    expect_fault=0;rst=0;
  endtask
  task automatic jobs(input int target_bank,input bit different_bank=0,input bit invalid_base=0,duplicate_base=0);
    base[0]=128;base[1]=duplicate_base?128:192;bank[0]=target_bank;bank[1]=different_bank?(target_bank+1)%4:target_bank;
    ids[0]=16'hfff0;ids[1]=16'hfff1;
    for(int c=0;c<2;c++)begin
      @(negedge clk);job_core_i=1'(c);job_id_i=16'(ids[c]);job_base_i=10'(base[c]+int'(invalid_base && c==1));
      job_bank_i=2'(bank[c]);job_mode_i=c?2:0;job_batch_last_i=c==1;job_valid_i=1;
      @(posedge clk);while(!job_ready_o)@(posedge clk);
      @(negedge clk);job_valid_i=0;
    end
  endtask
  task automatic packet(input int c,w,input int bad=-1);
    packet_core_i=1'(c);packet_id_i=16'(ids[c]+int'(bad==0));packet_index_i=8'(4*w+4*int'(bad==1));
    packet_count_i=bad==2?3:4;packet_last_i=bad==3 || w==63;
    packet_data_i=word_value(c,w);packet_valid_i=1;
    @(posedge clk);while(!packet_ready_o)@(posedge clk);
    @(negedge clk);
  endtask
  task automatic finish_batch;
    int watchdog;
    packet_valid_i=0;
    for(int c=0;c<2;c++)begin
      status_core_i=1'(c);status_id_i=16'(ids[c]);status_code_i=0;status_valid_i=1;watchdog=0;
      @(posedge clk);while(!status_ready_o)begin @(posedge clk);if(watchdog++>2000)$fatal(1,"Queued context did not retire");end
      @(negedge clk);status_valid_i=0;
    end
    watchdog=0;
    while(!idle_o)begin @(negedge clk);if(watchdog++>100)$fatal(1,"Writer never idle after completion");end
    if(next_write[0]!=64 || next_write[1]!=64 || dut.normal_count_r!=0)$fatal(1,"Lost/duplicate normal word");
    batches++;
  endtask
  task automatic full_batch(input int target_bank,input bit different=0);
    blocked=0;jobs(target_bank,different);
    for(int w=0;w<64;w++)begin packet(0,w);packet(1,w);end
    finish_batch();
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int p=0;p<3;p++)for(int b=0;b<4;b++)begin
      profile=p;full_batch(b,b[0]);
    end
    // Occupied reset at both FIFO pointer phases and both occupancies,
    // followed by complete same-ID replay through the normal write path.
    for(int trial=0;trial<4;trial++)begin
      reset_dut();profile=0;blocked=1;jobs(trial);
      if(trial>=2)begin
        blocked=0;packet(0,0);packet_valid_i=0;
        while(next_write[0]!=1)@(negedge clk);
        blocked=1;reset_prefix_writes++;
      end
      for(int n=0;n<(trial%2)+1;n++)packet(n%2,trial>=2 && n==0?1:0);
      packet_valid_i=0;
      if(dut.normal_count_r!=(trial%2)+1 || dut.normal_read_r!=1'(trial>=2))$fatal(1,"Occupied reset/pointer phase not reached");
      reset_dut();reset_cases++;full_batch(trial);
    end
    // Metadata rejects leave no successful completion;reset permits reuse.
    for(int bad=0;bad<8;bad++)begin
      reset_dut();blocked=1;expect_fault=1;
      jobs(0,0,bad==6,bad==7);
      if(bad<4)begin packet(0,0,bad);packet_valid_i=0;end
      else if(bad<6)begin status_valid_i=1;status_core_i=0;status_id_i=16'(ids[0]+int'(bad==4));status_code_i=bad==5?1:0;end
      repeat(3)@(negedge clk);status_valid_i=0;
      if(!fault_o || done_valid_o)$fatal(1,"Writer metadata fault accepted bad%0d",bad);
      rejections++;
    end
    reset_dut();profile=0;full_batch(3);
    if(longest<128 || reset_cases!=4 || rejections!=8 || batches!=17 || total_writes!=2178 || reset_prefix_writes!=2 || total_completions!=34 || renewals==0 || full_cycles==0)
      $fatal(1,"Missing queue rate/reset/fault witness batches%0d writes%0d longest%0d",batches,total_writes,longest);
    $display("LIGHTHD_WRITER_QUEUE_STRESS_PASS:%0dbatches/%0dwrites/%0dcompletions/%0doccupied-reset recoveries/%0drejects/%0dreset-prefix writes;longest%0d/full%0d/renew%0d/held%0d",batches,total_writes,total_completions,reset_cases,rejections,reset_prefix_writes,longest,full_cycles,renewals,held_checks);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Writer queue unit watchdog");end
endmodule
