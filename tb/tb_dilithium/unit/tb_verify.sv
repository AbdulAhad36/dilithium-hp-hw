`timescale 1ns/1ps
module tb_verify;
  import dilithium_pkg::*;
  parameter bit DIAGNOSTIC=1;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,start_valid_i=0,start_ready_o,busy_o,fault_o;
  logic [1:0] start_param_i=0;logic [15:0] start_id_i=0,start_message_len_i=0,start_signature_len_i=0;
  logic [8:0] start_context_len_i=0;
  logic input_valid_i=0,input_ready_o;logic [63:0] input_data_i=0;logic [3:0] input_bytes_i=0;
  logic [15:0] input_index_i=0;logic input_last_i=0;
  logic done_valid_o,done_ready_i=0,done_accept_o;logic [2:0] done_code_o,done_stage_o,done_detail_o;logic [15:0] done_id_o;
  request_t service_o;response_t service_i;logic physical_fault;
  verify controller(.start_internal_message_i(1'b0),.*);
  datapath datapath(.clk(clk),.rst(rst),.service_i(service_o),.service_o(service_i),.fault_o(physical_fault));
  int input_file,output_file,n,serial,original,level,id,context_len,message_len,pk_len,sig_len,body_len;
  int current=-1,cycles=0,completed=0,start_cycle,overlap=0,max_ring=0;string token,pk_hex,sig_hex,body_hex;
  logic [7:0] pk[2600],signature[4700],body[65535];
  always @(negedge clk)cycles++;
  always @(posedge clk)if(!rst)begin
    int occupancy;occupancy=$countones(controller.a_reserved_r);if(occupancy>max_ring)max_ring=occupancy;
    if(occupancy>(start_param_i==2?16:9))$fatal(1,"Verify A ring overflow");
    if(datapath.polynomial.core_busy && |service_i.sample.active)overlap++;
    if(fault_o || physical_fault)$fatal(1,"Verify fault case%0d state%0d producer%0d NTT%0d poly_process%0d",current,controller.state,controller.producer,service_i.ntt.done_code,service_i.poly_process.done_code);
    if(controller.state==controller.CHASH_DRAIN && controller.format_finished_r && controller.raw_finished_r && controller.bank_finished_r)
      $fdisplay(output_file,"C %0128h",controller.digest_r);
    if(busy_o && cycles%100000==0)$display("COMPACT_VERIFY_PROGRESS:case%0d clock%0d state%0d",current,cycles,controller.state);
  end
  task automatic feed_frame(input int frame,length);
    int index,amount,watchdog;index=0;watchdog=0;
    while(index*8<length && !done_valid_o)begin
      @(negedge clk);input_valid_i=1;input_data_i='1;amount=length-index*8>=8?8:length-index*8;
      for(int lane=0;lane<amount;lane++)input_data_i[8*lane+:8]=frame==0?pk[index*8+lane]:frame==1?signature[index*8+lane]:body[index*8+lane];
      input_index_i=16'(index);input_bytes_i=4'(amount);input_last_i=index*8+amount==length;
      @(posedge clk);while(!input_ready_o && !done_valid_o)begin
        @(posedge clk);if(watchdog++>100000)$fatal(1,"Verify input timeout case%0d frame%0d state%0d",current,frame,controller.state);
      end
      if(input_ready_o)index++;
      @(negedge clk);input_valid_i=0;
    end
  endtask
  initial begin
    int watchdog;
    input_file=$fopen(DIAGNOSTIC?"sim/dilithium/verify_diagnostic_inputs.txt":"sim/dilithium/verify_inputs.txt","r");
    output_file=$fopen(DIAGNOSTIC?"sim/dilithium/verify_diagnostic_outputs.txt":"sim/dilithium/verify_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare compact Verify fixtures");
    $fdisplay(output_file,"%s %0d",token,n);repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %d %d %d %s %s %s",serial,original,level,id,context_len,message_len,pk_len,sig_len,body_len,pk_hex,sig_hex,body_hex)!=12 || serial!=test)
        $fatal(1,"Verify fixture schema");
      for(int i=0;i<pk_len;i++)pk[i]=8'(pk_hex.substr(2*i,2*i+1).atohex());
      for(int i=0;i<sig_len;i++)signature[i]=8'(sig_hex.substr(2*i,2*i+1).atohex());
      for(int i=0;i<body_len;i++)body[i]=8'(body_hex.substr(2*i,2*i+1).atohex());
      @(negedge clk);current=serial;start_param_i=2'(level);start_id_i=16'(id);start_context_len_i=9'(context_len);
      start_message_len_i=16'(message_len);start_signature_len_i=16'(sig_len);start_valid_i=1;start_cycle=cycles;
      #1;if(!start_ready_o)$fatal(1,"Compact Verify not ready");
      $fdisplay(output_file,"J %0d %0d %0d %0d",serial,original,level,id);@(negedge clk);start_valid_i=0;
      feed_frame(0,pk_len);if(!done_valid_o)feed_frame(1,sig_len);if(!done_valid_o)feed_frame(2,body_len);
      watchdog=0;while(!done_valid_o)begin @(negedge clk);if(watchdog++>500000)$fatal(1,"Verify completion timeout state%0d producer%0d",controller.state,controller.producer);end
      if(done_id_o!=start_id_i || !service_i.idle)$fatal(1,"Verify identity/physical retirement gate");
      $fdisplay(output_file,"D %0d %0d %0d %0d %0d",done_code_o,done_stage_o,done_detail_o,done_accept_o,cycles-start_cycle);
      $display("COMPACT_VERIFY_CASE_PASS:case%0d original%0d level%0d code%0d accept%0d cycles%0d",serial,original,level,done_code_o,done_accept_o,cycles-start_cycle);
      repeat(3)begin @(negedge clk);if(!done_valid_o || done_id_o!=start_id_i)$fatal(1,"Verify completion unstable");end
      done_ready_i=1;@(negedge clk);done_ready_i=0;completed++;
    end
    $fdisplay(output_file,"F %0d",completed);$fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_VERIFY_CAPTURE_PASS:%0d completions/overlap%0d/peak_A_ring%0d;independent official-verdict and equation-digest comparison required",completed,overlap,max_ring);$finish;
  end
  initial begin #1000000000;$fatal(1,"Verify global watchdog");end
endmodule
