`timescale 1ns/1ps
module tb_ntt_dma;
  import ntt_pkg::*;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o,command_accumulate_i=0;
  ntt_op_e command_op_i;
  logic [1:0] command_a_bank_i=0,command_b_bank_i=2,command_c_bank_i=1,command_d_bank_i=1;
  logic [9:0] command_a_base_i=0,command_b_base_i=0,command_c_base_i=0,command_d_base_i=0;
  logic done_valid_o,done_ready_i=0,source_released_o;logic [1:0] done_code_o;
  logic [1:0] memory_command_valid_o,memory_command_ready_i;
  logic [1:0][3:0] memory_command_mask_o,memory_command_write_o,memory_write_valid_o,memory_write_ready_i;
  logic [1:0][3:0][9:0] memory_command_base_o;
  logic [1:0][3:0][10:0] memory_command_words_o;
  logic [1:0][3:0][1:0] memory_command_mode_o;
  logic [1:0][3:0][91:0] memory_write_data_o,memory_read_data_i;
  logic [1:0][3:0] memory_read_valid_i,memory_read_ready_o,memory_done_valid_i,memory_done_error_i,memory_done_ready_o;
  ntt_dma dut(.*);
  logic host=1;
  logic [1:0] command_valid,command_ready;
  logic [1:0][3:0] command_mask,command_write,write_valid,write_ready,read_valid,read_ready,read_last;
  logic [1:0][3:0][9:0] command_base,read_address;
  logic [1:0][3:0][10:0] command_words;
  logic [1:0][3:0][1:0] command_mode;
  logic [1:0][3:0][91:0] write_data,read_data;
  logic [1:0][3:0] busy,done_valid,done_ready,done_error;
  logic [3:0] collision;
  logic [1:0] hcommand_valid=0;
  logic [1:0][3:0] hcommand_mask=0,hcommand_write=0,hwrite_valid=0,hread_ready=0,hdone_ready=0;
  logic [1:0][3:0][9:0] hcommand_base=0;
  logic [1:0][3:0][10:0] hcommand_words=0;
  logic [1:0][3:0][1:0] hcommand_mode=0;
  logic [1:0][3:0][91:0] hwrite_data=0;
  logic [2:0][1:0] client_command_valid_i,client_command_ready_o;
  logic [2:0][1:0][3:0] client_command_mask_i,client_command_write_i,client_write_valid_i,client_write_ready_o;
  logic [2:0][1:0][3:0][9:0] client_command_base_i,client_read_address_o;
  logic [2:0][1:0][3:0][10:0] client_command_words_i;
  logic [2:0][1:0][3:0][1:0] client_command_mode_i;
  logic [2:0][1:0][3:0][91:0] client_write_data_i,client_read_data_o;
  wire [2:0][1:0][3:0][9:0] client_write_address_i='0;
  logic [2:0][1:0][3:0] client_read_valid_o,client_read_ready_i,client_read_last_o;
  logic [2:0][1:0][3:0] client_done_valid_o,client_done_error_o,client_done_ready_i;
  logic side_command=0,side_write=0,side_done_ready=0;
  int side_port=0,split_renewals=0,reserved_split_checks=0;
  logic [91:0] side_data;
  int side_words=0,overlap_cycles=0,side_received=0;
  bit side_read=0;
  logic [91:0] initial_words[4][64];
  logic [22:0] a[256],b[256],c[256];
  int issued[4],received,cycles=0,words_written=0,words_read=0,engine_words=0,commands=0;
  int input_file,output_file,n,serial,operation;string token;
  assign client_command_valid_i[0]=memory_command_valid_o;
  assign client_command_mask_i[0]=memory_command_mask_o;
  assign client_command_write_i[0]=memory_command_write_o;
  assign client_command_base_i[0]=memory_command_base_o;
  assign client_command_words_i[0]=memory_command_words_o;
  assign client_command_mode_i[0]=memory_command_mode_o;
  assign client_write_valid_i[0]=memory_write_valid_o;
  assign client_write_data_i[0]=memory_write_data_o;
  assign client_read_ready_i[0]=memory_read_ready_o;
  assign client_done_ready_i[0]=memory_done_ready_o;
  assign memory_command_ready_i=client_command_ready_o[0];
  assign memory_write_ready_i=client_write_ready_o[0];
  assign memory_read_valid_i=client_read_valid_o[0];
  assign memory_read_data_i=client_read_data_o[0];
  assign memory_done_valid_i=client_done_valid_o[0];
  assign memory_done_error_i=client_done_error_o[0];
  assign client_command_valid_i[2]=hcommand_valid;
  assign client_command_mask_i[2]=hcommand_mask;
  assign client_command_write_i[2]=hcommand_write;
  assign client_command_base_i[2]=hcommand_base;
  assign client_command_words_i[2]=hcommand_words;
  assign client_command_mode_i[2]=hcommand_mode;
  assign client_write_valid_i[2]=hwrite_valid;
  assign client_write_data_i[2]=hwrite_data;
  assign client_read_ready_i[2]=hread_ready;
  assign client_done_ready_i[2]=hdone_ready;
  assign command_ready=client_command_ready_o[2];
  assign write_ready=client_write_ready_o[2];
  assign read_valid=client_read_valid_o[2];
  assign read_data=client_read_data_o[2];
  assign read_address=client_read_address_o[2];
  assign read_last=client_read_last_o[2];
  assign done_valid=client_done_valid_o[2];
  assign done_error=client_done_error_o[2];
  always_comb begin
    client_command_valid_i[1]=0;client_command_valid_i[1][side_port]=side_command;
    client_command_mask_i[1]=0;client_command_mask_i[1][side_port]=4'h8;
    client_command_write_i[1]=client_command_mask_i[1];client_command_base_i[1]=0;
    client_command_words_i[1]=0;client_command_words_i[1][side_port][3]=64;
    client_command_mode_i[1]=0;client_write_valid_i[1]=0;client_write_valid_i[1][side_port][3]=side_write;
    client_write_data_i[1]=0;client_write_data_i[1][side_port][3]=side_data;
    client_read_ready_i[1]=0;client_done_ready_i[1]=0;client_done_ready_i[1][side_port][3]=side_done_ready;
  end
  bank_fabric memory(.clk(clk),.rst(rst),.client_command_valid_i(client_command_valid_i),
    .client_command_ready_o(client_command_ready_o),.client_command_mask_i(client_command_mask_i),
    .client_command_write_i(client_command_write_i),.client_command_base_i(client_command_base_i),
    .client_command_words_i(client_command_words_i),.client_command_mode_i(client_command_mode_i),
    .client_write_valid_i(client_write_valid_i),.client_write_ready_o(client_write_ready_o),.client_write_data_i(client_write_data_i),.client_write_address_i(client_write_address_i),
    .client_read_valid_o(client_read_valid_o),.client_read_ready_i(client_read_ready_i),.client_read_data_o(client_read_data_o),
    .client_read_address_o(client_read_address_o),.client_read_last_o(client_read_last_o),
    .client_done_valid_o(client_done_valid_o),.client_done_error_o(client_done_error_o),
    .client_done_ready_i(client_done_ready_i),.collision_o(collision));
  always @(negedge clk)begin
    cycles++;
    if(!rst && dut.state==dut.READ_RETIRE && dut.sent_r==1)begin
      if(memory.router.owner_r[1][command_a_bank_i]!=0 || !dut.read_done ||
         !memory.memory_done_valid_i[1][command_a_bank_i] ||
         !memory.router.retire_pending_r[1][command_a_bank_i])$fatal(1,"Split renewal lost reserved read port");
      reserved_split_checks++;
    end
  end
  always @(posedge clk)if(!rst)begin
    if(side_write && client_write_ready_o[1][side_port][3])begin
      side_words++;
      if(dut.core_busy)overlap_cycles++;
    end
    if(dut.state==dut.READ_RETIRE && dut.read_done && memory_command_valid_o==3 &&
       memory_command_ready_i==1)split_renewals++;
    if(!host)begin
      for(int p=0;p<2;p++)for(int k=0;k<4;k++)begin
        if(memory_write_valid_o[p][k] && memory_write_ready_i[p][k])engine_words++;
      end
    end else begin
      for(int k=0;k<4;k++)if(hwrite_valid[0][k] && write_ready[0][k])begin issued[k]++;words_written++;end
      if(read_valid[0][command_d_bank_i] && hread_ready[0][command_d_bank_i])begin
        if(read_address[0][command_d_bank_i]!=command_d_base_i+received || read_last[0][command_d_bank_i]!=(received==63))
          $fatal(1,"DMA result read address/order mismatch");
        for(int lane=0;lane<4;lane++)$fwrite(output_file,"%06h ",read_data[0][command_d_bank_i][23*lane+:23]);
        received++;words_read++;
      end
      if(side_read && read_valid[0][3] && hread_ready[0][3])begin
        if(read_address[0][3]!=side_received || read_data[0][3]!==92'(side_received*17+serial*97))
          $fatal(1,"Concurrent client RAM data/address mismatch");
        side_received++;
      end
    end
  end
  task automatic initialize_memory;
    @(negedge clk);host=1;hcommand_mask[0]=7;hcommand_write[0]=7;hcommand_words[0]='{default:11'd64};
    if(command_op_i==OP_PRE_NTT)hcommand_words[0][command_a_bank_i]=16;
    for(int k=0;k<4;k++)issued[k]=0;
    hcommand_base=0;hcommand_valid=1;
    @(posedge clk);while(!command_ready[0])@(posedge clk);
    @(negedge clk);hcommand_valid=0;
    while((done_valid[0]&7)!=7)begin
      for(int k=0;k<3;k++)begin
        hwrite_valid[0][k]=issued[k]<int'(hcommand_words[0][k]);
        hwrite_data[0][k]=initial_words[k][issued[k]%64];
      end
      @(negedge clk);
    end
    hwrite_valid=0;hdone_ready[0]=7;@(negedge clk);hdone_ready=0;
  endtask
  task automatic concurrent_writer;
    while(!dut.core_busy)@(negedge clk);
    // On every in-place unary operation,contend exactly when both read ports
    // finish. Client1 wins B's free bank3 while NTT renews A;B must stay owned
    // by NTT until its renewal wins on the following clock.
    if(side_port==1)begin
      while(!(dut.state==dut.READ_RETIRE && memory_command_valid_o==3))@(negedge clk);
    end else @(negedge clk);
    side_command=1;
    @(posedge clk);while(!client_command_ready_o[1][side_port])@(posedge clk);
    @(negedge clk);side_command=0;
    for(int w=0;w<64;w++)begin
      side_write=1;side_data=92'(w*17+serial*97);
      @(posedge clk);while(!client_write_ready_o[1][side_port][3])@(posedge clk);
      @(negedge clk);side_write=0;
      if(w%7==0)@(negedge clk);
    end
    while(!client_done_valid_o[1][side_port][3])@(negedge clk);
    if(client_done_error_o[1][side_port][3])$fatal(1,"Concurrent bank writer error");
    side_done_ready=1;@(negedge clk);side_done_ready=0;
  endtask
  task automatic capture_side;
    @(negedge clk);side_read=1;side_received=0;
    hcommand_mask[0]=8;hcommand_write=0;hcommand_base=0;hcommand_words[0][3]=64;
    hcommand_valid=1;@(posedge clk);while(!command_ready[0])@(posedge clk);
    @(negedge clk);hcommand_valid=0;hread_ready[0][3]=1;
    while(!done_valid[0][3])@(negedge clk);
    hread_ready=0;hdone_ready[0]=8;@(negedge clk);hdone_ready=0;side_read=0;
    if(side_received!=64)$fatal(1,"Concurrent write readback incomplete");
  endtask
  task automatic execute;
    int watchdog;
    @(negedge clk);host=0;command_valid_i=1;
    #1;if(!command_ready_o)$fatal(1,"NTT DMA not command-ready");
    @(negedge clk);command_valid_i=0;watchdog=0;
    while(!done_valid_o)begin
      @(negedge clk);
      if(watchdog++>1000)$fatal(1,"NTT DMA timeout case%0d state%0d inputs%0d outputs%0d",serial,dut.state,dut.inputs_r,dut.outputs_r);
    end
    if(done_code_o!=0)$fatal(1,"NTT DMA error case%0d code%0d state%0d inputs%0d outputs%0d",serial,done_code_o,dut.state,dut.inputs_r,dut.outputs_r);
    repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=0)$fatal(1,"DMA completion unstable");end
    done_ready_i=1;@(negedge clk);done_ready_i=0;commands++;
  endtask
  task automatic capture;
    @(negedge clk);host=1;received=0;
    hcommand_mask[0]=4'b1<<command_d_bank_i;hcommand_write=0;
    hcommand_base[0][command_d_bank_i]=command_d_base_i;hcommand_words[0][command_d_bank_i]=64;
    hcommand_valid=1;@(posedge clk);while(!command_ready[0])@(posedge clk);
    @(negedge clk);hcommand_valid=0;
    while((done_valid[0]&hcommand_mask[0])!=hcommand_mask[0])begin
      hread_ready[0][command_d_bank_i]=cycles%7>1;@(negedge clk);
    end
    hread_ready=0;hdone_ready[0]=hcommand_mask[0];@(negedge clk);hdone_ready=0;
    if(received!=64)$fatal(1,"DMA capture missing words");
    $fwrite(output_file,"\n");
  endtask
  initial begin
    input_file=$fopen("sim/dilithium/stage7c_ntt_inputs.txt","r");
    output_file=$fopen("sim/dilithium/stage7c1_ntt_dma_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare NTT fixtures");
    $fdisplay(output_file,"%s %0d",token,n);
    repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d",serial,operation)!=2 || serial!=test)$fatal(1,"DMA fixture case");
      for(int i=0;i<256;i++)if($fscanf(input_file,"%h",a[i])!=1)$fatal(1,"DMA fixture A");
      for(int i=0;i<256;i++)if($fscanf(input_file,"%h",b[i])!=1)$fatal(1,"DMA fixture B");
      for(int i=0;i<256;i++)if($fscanf(input_file,"%h",c[i])!=1)$fatal(1,"DMA fixture C");
      command_op_i=ntt_op_e'(operation==4?2:operation);command_accumulate_i=operation==4;
      command_a_bank_i=0;command_b_bank_i=2;command_c_bank_i=1;
      command_d_bank_i=command_op_i==OP_PWM?1:(test%2==0?0:2);
      side_port=command_op_i!=OP_PWM && command_d_bank_i==command_a_bank_i?1:0;
      foreach(initial_words[k,w])initial_words[k][w]=0;
      for(int w=0;w<64;w++)for(int lane=0;lane<4;lane++)begin
        initial_words[0][w][23*lane+:23]=a[4*w+lane];
        initial_words[2][w][23*lane+:23]=b[4*w+lane];
        initial_words[1][w][23*lane+:23]=c[4*w+lane];
      end
      if(command_op_i==OP_PRE_NTT)for(int w=0;w<16;w++)begin
        int index;initial_words[0][w]=0;
        for(int lane=0;lane<16;lane++)begin
          index=128*(w/8)+8*(w%8)+(lane%8)+(lane>=8?64:0);
          initial_words[0][w][4*lane+:4]=4'(a[index]<=4?a[index]:longint'(a[index])-8380417);
        end
      end
      initialize_memory();fork execute();concurrent_writer();join
      $fdisplay(output_file,"%0d",serial);capture();capture_side();
    end
    $fclose(input_file);$fclose(output_file);
    if(overlap_cycles==0 || side_words!=n*64)$fatal(1,"Missing actual NTT/concurrent-client overlap");
    if(split_renewals!=48 || reserved_split_checks<48)$fatal(1,"Missing deliberate split-port renewals");
    $display("LIGHTHD_NTT_SPLIT_RENEWAL_PASS:%0d deliberate split A/B renewals/%0d reserved-port checks",split_renewals,reserved_split_checks);
    $display("LIGHTHD_NTT_DMA_CAPTURE_PASS:commands%0d input_words%0d engine_written%0d readback_words%0d concurrent_writes%0d overlap_cycles%0d;independent Python compare required",commands,words_written,engine_words,words_read,side_words,overlap_cycles);
    $finish;
  end
  initial begin #10000000;$fatal(1,"NTT DMA global watchdog");end
endmodule
