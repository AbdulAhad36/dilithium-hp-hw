`timescale 1ps/1ps
module tb_memory_banks;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic [1:0][3:0] request_valid_i='0,request_write_i='0,request_ready_o;
  logic [1:0][3:0][9:0] request_address_i='0,response_address_o;
  logic [1:0][3:0][91:0] request_data_i='0,response_data_o;
  logic [1:0][3:0] response_valid_o,response_write_o,response_ready_i='0;
  logic [3:0] collision_o;
  memory_banks dut(.*);
  localparam int MAX_ROWS=16000;
  int phases[MAX_ROWS],banks[MAX_ROWS],ports[MAX_ROWS],writes[MAX_ROWS],addresses[MAX_ROWS];
  logic [91:0] words[MAX_ROWS];
  int program_ids[9][4][2][1100],sizes[9][4][2],position[4][2],pending[4][2];
  int phase=-1,cycles=0,count,fd,accepted=0,responses=0,aborted=0,reads=0,acks=0;
  int collisions=0,read_pairs=0,all_port_cycles=0,input_stalls=0,output_stalls=0,replacements=0;
  bit test_passed=0,hold_responses=0;
  logic [1:0][3:0] prev_in='0,prev_out='0;
  logic [1:0][3:0][102:0] saved_in,saved_out;
  string directory,token;
  always @(negedge clk)begin
    for(int b=0;b<4;b++)for(int p=0;p<2;p++)begin
      int i;
      request_valid_i[p][b]=!rst && phase>=0 && position[b][p]<sizes[phase][b][p];
      if(request_valid_i[p][b])begin
        i=program_ids[phase][b][p][position[b][p]];
        request_write_i[p][b]=1'(writes[i]);request_address_i[p][b]=10'(addresses[i]);request_data_i[p][b]=words[i];
      end
      response_ready_i[p][b]=!rst && !hold_responses &&
        ((phase!=0 && phase!=5) || (cycles+3*b+7*p)%19>=6);
    end
  end
  always @(posedge clk)begin
    int i,fires;
    cycles<=cycles+1;fires=0;
    if(!rst)begin
      for(int b=0;b<4;b++)begin
        collisions+=int'(collision_o[b]);
        if(request_valid_i[0][b] && request_ready_o[0][b] && request_valid_i[1][b] && request_ready_o[1][b] &&
           !request_write_i[0][b] && !request_write_i[1][b] && request_address_i[0][b]==request_address_i[1][b])read_pairs++;
        for(int p=0;p<2;p++)begin
          if(prev_in[p][b] && (!request_valid_i[p][b] ||
             {request_write_i[p][b],request_address_i[p][b],request_data_i[p][b]}!==saved_in[p][b]))
            $fatal(1,"Memory request changed under stall");
          if(prev_out[p][b] && (!response_valid_o[p][b] ||
             {response_write_o[p][b],response_address_o[p][b],response_data_o[p][b]}!==saved_out[p][b]))
            $fatal(1,"Memory response changed under stall");
          prev_in[p][b]=request_valid_i[p][b] && !request_ready_o[p][b];
          prev_out[p][b]=response_valid_o[p][b] && !response_ready_i[p][b];
          saved_in[p][b]={request_write_i[p][b],request_address_i[p][b],request_data_i[p][b]};
          saved_out[p][b]={response_write_o[p][b],response_address_o[p][b],response_data_o[p][b]};
          input_stalls+=int'(prev_in[p][b]);output_stalls+=int'(prev_out[p][b]);
          if(response_valid_o[p][b] && response_ready_i[p][b])begin
            i=pending[b][p];if(i<0)$fatal(1,"Response without memory request");
            if(response_write_o[p][b]!==1'(writes[i]) || response_address_o[p][b]!==10'(addresses[i]))
              $fatal(1,"Memory response metadata");
            $fdisplay(fd,"R %0d %0d %0d %0d %0d %0d %023h",i,cycles,b,p,response_write_o[p][b],response_address_o[p][b],response_data_o[p][b]);
            responses++;if(response_write_o[p][b])acks++;else reads++;pending[b][p]=-1;
          end
          if(request_valid_i[p][b] && request_ready_o[p][b])begin
            i=program_ids[phase][b][p][position[b][p]];
            if(pending[b][p]>=0)$fatal(1,"Memory port overwrote pending response");
            if(response_valid_o[p][b] && response_ready_i[p][b])replacements++;
            $fdisplay(fd,"J %0d %0d %0d %0d %0d %0d %023h",i,cycles,b,p,request_write_i[p][b],request_address_i[p][b],request_data_i[p][b]);
            accepted++;fires++;pending[b][p]=i;position[b][p]++;
          end
        end
      end
      if(fires==8)all_port_cycles++;
    end else begin prev_in='0;prev_out='0;end
  end
  task automatic set_phase(input int next_phase);
    phase=next_phase;for(int b=0;b<4;b++)for(int p=0;p<2;p++)position[b][p]=0;
  endtask
  task automatic wait_drained;
    bit done;
    do begin
      @(negedge clk);#1;done=1;
      for(int b=0;b<4;b++)for(int p=0;p<2;p++)
        if(position[b][p]!=sizes[phase][b][p] || pending[b][p]>=0)done=0;
    end while(!done);
  endtask
  task automatic reset_ports;
    rst=1;phase=-1;request_valid_i='0;response_ready_i='0;$fdisplay(fd,"X %0d",cycles);
    repeat(3)@(posedge clk);@(negedge clk);#1;rst=0;
    for(int b=0;b<4;b++)for(int p=0;p<2;p++)if(response_valid_o[p][b])$fatal(1,"Response survived reset");
  endtask
  initial begin
    int inf,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    for(int ph=0;ph<9;ph++)for(int b=0;b<4;b++)for(int p=0;p<2;p++)sizes[ph][b][p]=0;
    for(int b=0;b<4;b++)for(int p=0;p<2;p++)begin position[b][p]=0;pending[b][p]=-1;end
    inf=$fopen({directory,"/stage5_banks_inputs.txt"},"r");
    if(!inf || $fscanf(inf,"%s %d",token,count)!=2 || count>MAX_ROWS || count<14000)$fatal(1,"Bank input header");
    for(int i=0;i<count;i++)begin
      if($fscanf(inf,"%d %d %d %d %d %d %h",index,phases[i],banks[i],ports[i],writes[i],addresses[i],words[i])!=7 || index!=i)
        $fatal(1,"Bank vector row");
      program_ids[phases[i]][banks[i]][ports[i]][sizes[phases[i]][banks[i]][ports[i]]]=i;
      sizes[phases[i]][banks[i]][ports[i]]++;
    end
    $fclose(inf);fd=$fopen({directory,"/stage5_banks_outputs.txt"},"w");if(!fd)$fatal(1,"Bank capture");
    $fdisplay(fd,"H %s",token);reset_ports();
    for(int ph=0;ph<6;ph++)begin set_phase(ph);wait_drained();end
    hold_responses=1;set_phase(6);
    do begin @(negedge clk);#1;end while(response_valid_o!='1);
    set_phase(7);repeat(4)begin @(negedge clk);#1;end
    if(request_valid_i!='1 || request_ready_o!='0)$fatal(1,"Expected blocked offers before reset");
    for(int b=0;b<4;b++)for(int p=0;p<2;p++)begin
      if(position[b][p]!=0 || pending[b][p]<0)$fatal(1,"Blocked command accepted");
      $fdisplay(fd,"A %0d %0d %0d",pending[b][p],b,p);pending[b][p]=-1;aborted++;
    end
    reset_ports();hold_responses=0;set_phase(8);wait_drained();phase=-1;
    repeat(8)begin @(negedge clk);#1;end
    if(accepted!=count-8 || responses!=accepted-8 || aborted!=8 || collisions==0 || read_pairs<4000 ||
       all_port_cycles<1000 || input_stalls==0 || output_stalls==0 || replacements==0 || response_valid_o!=0)
      $fatal(1,"Incomplete bank memory gate");
    $fdisplay(fd,"F %0d %0d %0d %0d %0d",accepted,responses,aborted,reads,acks);$fclose(fd);
    $display("DILITHIUM_STAGE5_BANKS_PASS:%0d accepted,%0d responses,8 reset-aborted acks,%0d exact-read candidates,%0d write acks",
      accepted,responses,reads,acks);
    $display("BANK WITNESSES:collisions%0d,dual-read%0d,all-eight-ports%0d,input-stall%0d,response-stall%0d,replacements%0d",
      collisions,read_pairs,all_port_cycles,input_stalls,output_stalls,replacements);test_passed=1;$finish;
  end
  initial begin #(64'd4_000_000_000);$fatal(1,"Memory bank timeout");end
endmodule
