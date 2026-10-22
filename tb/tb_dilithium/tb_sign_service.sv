`timescale 1ps/1ps
// Exercise the actual main-owned shared services,including its existing
// Keccak/sampler,bank arbiter and BRAM. No fixture RAM preload or forced RTL.
module tb_sign_service;
  import dilithium_service_pkg::*;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  request_t request_i='0;response_t response_o;
  dilithium_services dut(.*);
  int ids[104],modes[104],params[104],lengths[104];byte unsigned messages[104][$];
  int cycles=0,level=0,phase=0,fd,completed=0,aborts=0,source_words=0,result_words=0;
  int row_blocks=0,ntt_blocks=0,scalar_blocks=0,read_blocks=0,exclusive=0,leases=0,atomic=0;
  string directory,token;bit test_passed=0;
  always @(posedge clk)begin
    cycles++;
    if(!rst)begin
      if(response_o.fault)$fatal(1,"Signing service fault level%0d phase%0d",level,phase);
      if(response_o.sign.busy)begin
        if(response_o.job_ready || response_o.op_ready || response_o.process_ready || response_o.read_ready || response_o.row_ready || response_o.raw_ready)
          $fatal(1,"Signing client lost shared service ownership");
        exclusive++;
        if(request_i.release_valid && {request_i.release_bank,request_i.release_region}==request_i.sign.a)begin
          if(response_o.release_ready)$fatal(1,"Signing source lease was released");leases++;
        end
        if(dut.datapath.subsystem.store_complete[32] && !response_o.sign.done_valid && phase==0)begin
          if(response_o.complete[32] || response_o.complete[48])$fatal(1,"Service exposed partial Decompose pair");atomic++;
        end
      end
    end
  end
  task automatic reset_all();
    @(negedge clk);rst=1;request_i='0;repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(response_o.reserved || response_o.complete || response_o.sign.busy || response_o.sign.done_valid || response_o.fault)$fatal(1,"Service reset state");
  endtask
  task automatic sample(input int c);
    int pos,n;logic [63:0] data;
    @(negedge clk);request_i.job_valid=1;request_i.job_bank=0;request_i.job_region=0;
    request_i.job_mode=2'(modes[c]);request_i.job_param=2'(level);request_i.job_id=16'(100+level);
    request_i.message_len=16'(lengths[c]);request_i.status_ready=1;
    do @(posedge clk);while(!response_o.job_ready);@(negedge clk);request_i.job_valid=0;pos=0;
    while(pos<lengths[c])begin
      n=lengths[c]-pos;if(n>8)n=8;data='1;
      for(int b=0;b<n;b++)data[8*b+:8]=messages[c][pos+b];
      request_i.input_data=data;request_i.input_valid=1;
      do @(posedge clk);while(!response_o.input_ready);@(negedge clk);request_i.input_valid=0;pos+=n;
    end
    do @(negedge clk);while(response_o.active!=0);
    if(!response_o.complete[0])$fatal(1,"Sample source not committed");request_i.status_ready=0;
  endtask
  task automatic read_poly(input int region,input bit source);
    for(int w=0;w<64;w++)begin
      @(negedge clk);request_i.read_valid=1;{request_i.read_bank,request_i.read_region}=6'(region);request_i.read_word=6'(w);
      do @(posedge clk);while(!response_o.read_ready);@(negedge clk);request_i.read_valid=0;
      do @(negedge clk);while(!response_o.response_valid);
      if(response_o.response_error || {response_o.response_bank,response_o.response_region}!==6'(region) || response_o.response_word!==6'(w))$fatal(1,"Shared service read tag");
      $fdisplay(fd,"%s %0d %0d %0d %0d %023h %0d %0d %0d",source?"S":"R",level,phase,region,w,response_o.response_data,
        response_o.response_id,response_o.response_param,response_o.response_ntt_domain);
      if(source)source_words++;else result_words++;
      repeat(w%3)@(negedge clk);request_i.response_ready=1;@(posedge clk);@(negedge clk);request_i.response_ready=0;
    end
  endtask
  task automatic blockers();
    // A held public read owns its response before signing may take the banks.
    request_i.read_valid=1;request_i.read_word=0;
    do @(posedge clk);while(!response_o.read_ready);@(negedge clk);request_i.read_valid=0;request_i.sign.valid=1;
    repeat(6)begin @(negedge clk);if(response_o.sign.ready)$fatal(1,"Sign stole public read");read_blocks++;end
    request_i.row_valid=1;request_i.row_param=3;
    do @(negedge clk);while(!response_o.response_valid);request_i.response_ready=1;@(posedge clk);@(negedge clk);request_i.response_ready=0;
    // Invalid commands isolate priority without modifying any polynomial.
    do @(posedge clk);while(!response_o.row_ready);@(negedge clk);request_i.row_valid=0;
    repeat(5)begin @(negedge clk);if(response_o.sign.ready)$fatal(1,"Sign stole row ownership");row_blocks++;end
    if(!response_o.row_done_valid || response_o.row_done_code!=4)$fatal(1,"Row priority completion");
    request_i.op_valid=1;request_i.op_a_region=0;request_i.op_dest_region=0;
    request_i.row_done_ready=1;@(posedge clk);@(negedge clk);request_i.row_done_ready=0;
    do @(posedge clk);while(!response_o.op_ready);@(negedge clk);request_i.op_valid=0;
    repeat(5)begin @(negedge clk);if(response_o.sign.ready)$fatal(1,"Sign stole NTT ownership");ntt_blocks++;end
    if(!response_o.op_done_valid || response_o.op_done_code!=3)$fatal(1,"NTT priority completion");
    request_i.process_valid=1;request_i.process_op=3;request_i.op_done_ready=1;
    @(posedge clk);@(negedge clk);request_i.op_done_ready=0;
    do @(posedge clk);while(!response_o.process_ready);@(negedge clk);request_i.process_valid=0;
    repeat(5)begin @(negedge clk);if(response_o.sign.ready)$fatal(1,"Sign stole scalar process ownership");scalar_blocks++;end
    if(!response_o.process_done_valid || response_o.process_done_code!=4)$fatal(1,"Scalar priority completion");
    request_i.process_done_ready=1;@(posedge clk);@(negedge clk);request_i.process_done_ready=0;
  endtask
  initial begin
    int f,n,c,flag,idx,parsed,expected;string hex_message;byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    f=$fopen({directory,"/stage2_inputs.txt"},"r");
    if(!f || $fscanf(f,"%s %d",token,n)!=2 || n!=104)$fatal(1,"Prepare service fixtures");
    for(int i=0;i<n;i++)begin
      if($fscanf(f,"%d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],flag,lengths[i],hex_message)!=7 || idx!=i)$fatal(1,"Fixture header");
      for(int k=0;k<lengths[i];k++)begin parsed=$sscanf(hex_message.substr(2*k,2*k+1),"%h",octet);if(parsed!=1)$fatal(1,"Fixture byte");messages[i].push_back(octet);end
    end
    $fclose(f);fd=$fopen({directory,"/stage5_sign_service_outputs.txt"},"w");$fdisplay(fd,"H %s",token);reset_all();
    for(level=0;level<3;level++)begin
      row_blocks=0;ntt_blocks=0;scalar_blocks=0;read_blocks=0;exclusive=0;leases=0;atomic=0;
      phase=0;sample(12+2*level);read_poly(0,1);
      for(phase=0;phase<11;phase++)begin
        @(negedge clk);request_i.sign='0;
        request_i.sign.op=phase==0?0:((phase==4 || phase==5 || phase==8 || phase==10)?2:1);
        request_i.sign.param=phase==7?2'((level+1)%3):2'(level);
        request_i.sign.kind=phase==2?1:(phase==3?2:0);
        request_i.sign.a=(phase==2 || phase==3 || phase==5 || phase==6 || phase==7)?32:0;
        request_i.sign.b=phase==8?0:48;request_i.sign.dest=phase==0?32:(phase==4?16:(phase==5?17:18));request_i.sign.high=48;
        request_i.sign.a_id=phase==6?9:(request_i.sign.a==32?9000:16'(100+level));
        request_i.sign.b_id=phase==8?16'(100+level):16'd9000;request_i.sign.id=16'(9000+phase);
        if(phase==0)blockers();else request_i.sign.valid=1;
        request_i.release_valid=1;{request_i.release_bank,request_i.release_region}=request_i.sign.a;
        do @(posedge clk);while(!response_o.sign.ready);
        $fdisplay(fd,"C %0d %0d %0d %0d %0d %0d %0d %0d %0d",level,phase,request_i.sign.op,request_i.sign.param,
          request_i.sign.kind,request_i.sign.a,request_i.sign.b,request_i.sign.dest,request_i.sign.id);
        @(negedge clk);request_i.sign.valid=0;
        if(phase==10)begin
          do @(negedge clk);while(dut.datapath.subsystem.sign_client.word_r!=7 || dut.datapath.subsystem.sign_client.state!=10);
          $fdisplay(fd,"A %0d %0d",level,phase);aborts++;reset_all();continue;
        end
        do @(negedge clk);while(!response_o.sign.done_valid);
        expected=phase==6?1:(phase==7?2:(phase==8?5:0));
        if(response_o.sign.done_code!==3'(expected))$fatal(1,"Service command status level%0d phase%0d",level,phase);
        // Other service requests remain blocked during held signing completion.
        request_i.job_valid=1;request_i.op_valid=1;request_i.process_valid=1;request_i.row_valid=1;request_i.raw_valid=1;request_i.raw_output_len=1;
        repeat(6)@(negedge clk);
        request_i.job_valid=0;request_i.op_valid=0;request_i.process_valid=0;request_i.row_valid=0;request_i.raw_valid=0;
        $fdisplay(fd,"D %0d %0d %0d %0d %0d %0d %0d %0d",level,phase,response_o.sign.done_code,response_o.sign.done_id,
          response_o.sign.done_dest,response_o.sign.done_high,response_o.sign.done_reject,response_o.sign.done_weight);
        request_i.release_valid=0;request_i.sign.done_ready=1;@(posedge clk);@(negedge clk);request_i.sign.done_ready=0;completed++;
        if(phase==0)begin read_poly(32,0);read_poly(48,0);end
        if(phase==4)read_poly(16,0);if(phase==5)read_poly(17,0);
      end
      $fdisplay(fd,"T %0d %0d %0d %0d %0d %0d %0d %0d",level,row_blocks,ntt_blocks,scalar_blocks,read_blocks,exclusive,leases,atomic);
    end
    $fdisplay(fd,"F %0d %0d %0d %0d",completed,aborts,source_words,result_words);$fclose(fd);
    $display("STAGE5N3_SIGN_SERVICE_CAPTURE_PASS:%0d completed,%0d reset aborts,%0d source words,%0d result words",completed,aborts,source_words,result_words);
    test_passed=1;$finish;
  end
  initial begin #(64'd20000000000);$fatal(1,"Sign service watchdog level%0d phase%0d",level,phase);end
endmodule
