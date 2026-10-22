`timescale 1ps/1ps
module tb_keygen #(parameter bit ROUND_OUTPUTS=0);
  logic key_valid_o,key_ready_i=0,key_type_o,key_last_o;
  logic [63:0] key_data_o;logic [3:0] key_bytes_o;logic [9:0] key_index_o;logic [15:0] key_id_o;
  logic clk=0;
  logic rst=1;
  logic start_valid_i=0;
  logic start_ready_o;
  logic busy_o;
  logic [1:0] start_op_i=0;
  logic [1:0] start_param_i=0;
  logic [15:0] start_id_i=0;
  logic [255:0] start_seed_i=0;
  logic row_result_valid_o;
  logic row_result_ready_i=0;
  logic [3:0] row_result_index_o;
  logic [5:0] row_result_region_o;
  logic [15:0] row_result_id_o;
  logic done_valid_o;
  logic done_ready_i=0;
  logic [2:0] done_code_o;
  logic [15:0] done_id_o;
  logic seed_valid_o;
  logic [255:0] rho_o;
  logic [255:0] key_o;
  logic [511:0] rhoprime_o;
  logic read_valid_i=0;
  logic [1:0] read_bank_i=0;
  logic [3:0] read_region_i=0;
  logic [5:0] read_word_i=0;
  logic read_ready_o;
  logic response_valid_o;
  logic response_error_o;
  logic [1:0] response_bank_o;
  logic [1:0] response_mode_o;
  logic [1:0] response_param_o;
  logic [3:0] response_region_o;
  logic [5:0] response_word_o;
  logic [91:0] response_data_o;
  logic [15:0] response_id_o;
  logic response_ntt_domain_o;
  logic response_small_o;
  logic response_ready_i=0;
  logic [63:0] reserved_o;
  logic [63:0] complete_o;
  logic fault_o;
  always begin #3378 clk=1;#3379 clk=0;end

  dilithium #(.ROUND_OUTPUTS(ROUND_OUTPUTS)) dut(.*);
  string directory,token;int fd,cycle=0,run=-1,complete=0,rejected=0,aborted=0,delivered=0,writes=0,reads=0;
  int case_op[14],case_param[14],case_id[14],case_abort[14];logic [255:0] case_seed[14];
  int pending_read_checks=0;bit test_passed=0;
  always @(posedge clk)begin
    cycle++;
    if(!rst)begin
      if(fault_o)$fatal(1,"KeyGen internal protocol fault state%0d",dut.core.state);
      if(start_valid_i && start_ready_o)begin
        run++;$fdisplay(fd,"B %0d %0d %0d %0d %064h",run,start_op_i,start_param_i,start_id_i,start_seed_i);
      end
      if(dut.core.source_done && dut.core.source_done_ready && dut.core.state==2)
        $fdisplay(fd,"K %0d %064h %0128h %064h",run,rho_o,rhoprime_o,key_o);
      if(dut.core.job_valid_i && dut.core.job_ready_o)
        $fdisplay(fd,"J %0d %0d %0d %0d %0d",run,dut.core.job_mode_i,dut.core.job_param_i,
          {dut.core.job_bank_i,dut.core.job_region_i},dut.core.job_id_i);
      if(dut.core.input_valid_i && dut.core.input_ready_o)$fdisplay(fd,"I %0d %016h",run,dut.core.input_data_i);
      if(dut.services.datapath.subsystem.store.alloc_fire)
        $fdisplay(fd,"V %0d %0d %0d %0d",run,dut.services.datapath.subsystem.store.alloc_core_i,
          {dut.services.datapath.subsystem.store.alloc_bank_i,dut.services.datapath.subsystem.store.alloc_region_i},
          dut.services.datapath.subsystem.store.alloc_id_i);
      if(dut.services.datapath.subsystem.store.write_fire)begin
        $fdisplay(fd,"W %0d %0d %0d %06h %0d",run,dut.services.datapath.subsystem.store.write_core_i,
          dut.services.datapath.subsystem.store.write_index_i,dut.services.datapath.subsystem.store.write_data_i,
          dut.services.datapath.subsystem.store.write_last_i);writes++;
      end
      if(dut.services.datapath.subsystem.store.finish_fire)
        $fdisplay(fd,"U %0d %0d",run,dut.services.datapath.subsystem.store.finish_core_i);
      if(row_result_valid_o && row_result_ready_i)begin
        $fdisplay(fd,"E %0d %0d %0d %0d",run,row_result_index_o,row_result_region_o,row_result_id_o);delivered++;
      end
      if(done_valid_o && done_ready_i)begin
        $fdisplay(fd,"D %0d %0d %0d",run,done_code_o,done_id_o);
        if(done_code_o==0)complete++;else rejected++;
      end
      if(dut.services.datapath.subsystem.store.release_fire)
        $fdisplay(fd,"L %0d %0d",run,{dut.services.datapath.subsystem.store.release_bank_i,dut.services.datapath.subsystem.store.release_region_i});
    end
  end
  task automatic reset_all();
    rst=1;start_valid_i=0;row_result_ready_i=0;done_ready_i=0;read_valid_i=0;response_ready_i=0;
    $fdisplay(fd,"X");repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved_o || complete_o || busy_o || response_valid_o || fault_o || seed_valid_o)$fatal(1,"KeyGen reset state");
  endtask
  task automatic read_poly(input int region);
    for(int wordno=0;wordno<64;wordno++)begin
      @(negedge clk);{read_bank_i,read_region_i}=6'(region);read_word_i=6'(wordno);read_valid_i=1;
      do @(posedge clk);while(!read_ready_o);@(negedge clk);read_valid_i=0;
      do @(negedge clk);while(!response_valid_o);
      if(response_error_o || {response_bank_o,response_region_o}!=region || response_word_o!=wordno)$fatal(1,"KeyGen read metadata");
      $fdisplay(fd,"R %0d %0d %0d %023h %0d %0d %0d %0d",run,region,wordno,response_data_o,
        response_id_o,response_mode_o,response_param_o,response_ntt_domain_o);reads++;
      if(region==19 && wordno==63)begin
        // Retire the row while its final read response is still held.
        row_result_ready_i=1;@(posedge clk);@(negedge clk);row_result_ready_i=0;
        repeat(4)begin
          @(negedge clk);
          if(!response_valid_o || !reserved_o[19] || dut.core.state!=14 || start_ready_o)
            $fatal(1,"KeyGen freed output before pending read retirement");
          pending_read_checks++;
        end
      end
      repeat(wordno%3)@(negedge clk);response_ready_i=1;@(posedge clk);@(negedge clk);response_ready_i=0;
    end
  endtask
  task automatic run_command(input int c);
    int p,k,l;
    @(negedge clk);start_op_i=2'(case_op[c]);start_param_i=2'(case_param[c]);start_id_i=16'(case_id[c]);start_seed_i=case_seed[c];start_valid_i=1;
    do @(posedge clk);while(!start_ready_o);@(negedge clk);start_valid_i=0;
    p=case_param[c];k=p==0?4:(p==1?6:8);l=p==0?4:(p==1?5:7);
    if(case_abort[c]>=0)begin
      case(case_abort[c])
        0:do @(negedge clk);while(dut.core.source.seeds.count_r!=4);
        1:do @(negedge clk);while(!dut.services.datapath.subsystem.store.write_valid_i || dut.services.datapath.subsystem.store.write_index_i!=8);
        2:do @(negedge clk);while(!row_result_valid_o);
        3:do @(negedge clk);while(dut.services.datapath.subsystem.process_client.state!=9 || dut.services.datapath.subsystem.process_client.index!=8);
      endcase
      $fdisplay(fd,"A %0d %0d %0d",run,case_abort[c],dut.core.state);aborted++;reset_all();return;
    end
    if(case_op[c]==0 && p<3)begin
      for(int row=0;row<k;row++)begin
        do @(negedge clk);while(!row_result_valid_o);
        if(row_result_index_o!=row || row_result_region_o!=19)$fatal(1,"KeyGen row order");
        if(ROUND_OUTPUTS && (!complete_o[56+row] || !complete_o[40+row]))
          $fatal(1,"Rounded KeyGen published before both rounded regions committed");
        repeat(4)begin @(negedge clk);if(start_ready_o || !row_result_valid_o)$fatal(1,"Held KeyGen row");end
        read_poly(19);
      end
    end
    do @(negedge clk);while(!done_valid_o);
    if(done_code_o!==(case_op[c]!=0?3'd2:(p==3?3'd1:3'd0)) || done_id_o!=start_id_i)$fatal(1,"Main controller retirement");
    if(case_op[c]==0 && p<3)begin
      for(int j=0;j<l;j++)begin read_poly(1+j);read_poly(32+j);end
      for(int i=0;i<k;i++)read_poly(8+i);
      if(ROUND_OUTPUTS)for(int i=0;i<k;i++)begin read_poly(56+i);read_poly(40+i);end
    end
    repeat(4)begin @(negedge clk);if(!done_valid_o || start_ready_o)$fatal(1,"Held KeyGen final completion");end
    done_ready_i=1;@(posedge clk);@(negedge clk);done_ready_i=0;
    do @(negedge clk);while(!start_ready_o);
    if(reserved_o!=0 || complete_o!=0)$fatal(1,"KeyGen cleanup leaked a region");
    $fdisplay(fd,"CLEAN %0d",run);
  endtask
  initial begin
    int f,count,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    f=$fopen({directory,"/stage5_keygen_inputs.txt"},"r");
    if(!f || $fscanf(f,"%s %d",token,count)!=2 || count!=14)$fatal(1,"Prepare KeyGen inputs");
    for(int c=0;c<count;c++)if($fscanf(f,"%d %d %d %d %d %h",index,case_op[c],case_param[c],case_id[c],case_abort[c],case_seed[c])!=6 || index!=c)$fatal(1,"KeyGen fixture");
    $fclose(f);fd=$fopen({directory,ROUND_OUTPUTS?"/stage5_rounded_keygen_outputs.txt":"/stage5_keygen_outputs.txt"},"w");$fdisplay(fd,"H %s",token);reset_all();
    for(int c=0;c<count;c++)run_command(c);
    if(complete!=7 || rejected!=3 || aborted!=4 || delivered!=34 || run!=13 || pending_read_checks!=136)$fatal(1,"KeyGen campaign completion");
    $fdisplay(fd,"G %0d",pending_read_checks);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d",complete,rejected,aborted,delivered,writes,reads);
    $fclose(fd);$display("DILITHIUM_STAGE5J_KEYGEN_POLYNOMIAL_CAPTURE_PASS:7 complete,3 expected rejects,4 aborts,34 rows;writes%0d reads%0d",writes,reads);
    if(ROUND_OUTPUTS)$display("DILITHIUM_STAGE5K_ROUNDED_KEYGEN_CAPTURE_PASS");
    test_passed=1;$finish;
  end
  initial begin #(64'd500000000000);if(!test_passed)$fatal(1,"KeyGen watchdog run%0d main%0d keygen%0d",run,dut.state,dut.core.state);end
endmodule
