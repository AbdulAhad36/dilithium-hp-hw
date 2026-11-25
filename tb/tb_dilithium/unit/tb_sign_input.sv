`timescale 1ns/1ps
module tb_sign_input;
  logic header_write_valid_o;logic [3:0] header_write_index_o;logic [63:0] header_write_data_o;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o;
  logic [1:0] command_param_i=0;logic [15:0] command_id_i=0;
  logic input_valid_i=0,input_ready_o,input_last_i=0;logic [63:0] input_data_i=0;
  logic [3:0] input_bytes_i=8;logic [15:0] input_index_i=0;
  logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o;logic [15:0] done_id_o;
  logic [255:0] rho_o,key_o;logic [511:0] tr_o;
  logic poly_valid_o;logic [1:0] poly_section_o;logic [3:0] poly_index_o;
  logic load_valid_o,load_ready_i;logic [2:0] load_op_o;logic [1:0] load_param_o,load_bank_o;
  logic [9:0] load_base_o;logic [15:0] load_id_o;
  logic load_input_valid_o,load_input_ready_i;logic [63:0] load_input_data_o;logic [6:0] load_input_index_o;
  logic [3:0] load_input_bytes_o;logic load_input_last_o,load_done_valid_i,load_done_ready_o;
  logic [2:0] load_done_code_i;logic [15:0] load_done_id_i;
  sign_input parser(.*);
  dilithium_pkg::request_t request_i;
  dilithium_pkg::response_t response_o;
  logic load_fault,writer_fault,packet_valid;
  service_fixture banks(.*,.fault_o(writer_fault));
  assign load_fault=0;
  assign packet_valid=banks.datapath.hash_sampler.manual_packet_valid;
  always_comb begin
    request_i='0;
    request_i.load.valid=load_valid_o;request_i.load.op=load_op_o;
    request_i.load.param=load_param_o;request_i.load.bank=load_bank_o;
    request_i.load.base=load_base_o;request_i.load.id=load_id_o;
    request_i.load.input_valid=load_input_valid_o;request_i.load.input_data=load_input_data_o;
    request_i.load.input_index=load_input_index_o;request_i.load.input_bytes=load_input_bytes_o;
    request_i.load.input_last=load_input_last_o;request_i.load.done_ready=load_done_ready_o;
  end
  assign load_ready_i=response_o.load.ready;
  assign load_input_ready_i=response_o.load.input_ready;
  assign load_done_valid_i=response_o.load.done_valid;
  assign load_done_id_i=response_o.load.done_id;assign load_done_code_i=response_o.load.done_code;
  int input_file,output_file,n,serial,level,id,action,expected_code,length,cycles=0,poly_pulses=0,total_cases=0,reset_cases=0;
  string token,hex;logic [7:0] bytes_data[6000];logic [91:0] captured[1024];
  always @(negedge clk)cycles++;
  always @(posedge clk)if(!rst)begin
    if(load_fault || writer_fault)$fatal(1,"SK load internal fault");
    if(poly_valid_o)poly_pulses++;
    if(action==1 && (load_valid_o || packet_valid))$fatal(1,"Invalid SK command launched decoder work");
  end
  task automatic capture_fields;
    int k,l,bank,base,count;
    k=level==0?4:level==1?6:8;l=level==0?4:level==1?5:7;
    $fdisplay(output_file,"H %064h %064h %0128h",rho_o,key_o,tr_o);
    for(int section=0;section<3;section++)for(int p=0;p<(section==0?l:k);p++)begin
      bank=section==2?1:0;base=section==0?64*p:section==1?448+64*p:64+64*p;count=section==2?64:16;
      banks.read_bank(bank,base,count,captured);
      $fdisplay(output_file,"P %0d %0d %0d",section,p,count);
      for(int w=0;w<count;w++)$fdisplay(output_file,"%023h",captured[w]);
    end
    if(poly_pulses!=l+2*k)$fatal(1,"Incomplete SK field publication");
  endtask
  initial begin
    int index,watchdog,amount;bit reset_now;
    input_file=$fopen("sim/dilithium/sign_load_inputs.txt","r");
    output_file=$fopen("sim/dilithium/sign_load_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare compact SK-load fixtures");
    $fdisplay(output_file,"%s %0d",token,n);repeat(3)@(negedge clk);rst=0;
    for(int test=0;test<n;test++)begin
      if($fscanf(input_file,"%d %d %d %d %d %d %s",serial,level,id,action,expected_code,length,hex)!=7 || serial!=test)$fatal(1,"SK-load fixture metadata");
      for(int i=0;i<length;i++)bytes_data[i]=8'(hex.substr(2*i,2*i+1).atohex());
      @(negedge clk);command_param_i=action==1?2'd3:2'(level);command_id_i=16'(id);poly_pulses=0;command_valid_i=1;
      #1;if(!command_ready_o)$fatal(1,"SK parser not ready");
      $fdisplay(output_file,"J %0d %0d %0d",serial,command_param_i,command_id_i);
      @(negedge clk);command_valid_i=0;index=0;watchdog=0;reset_now=0;
      while(!done_valid_o)begin
        if(index<length/8)begin
          input_valid_i=cycles%7!=0;input_data_i='1;
          for(int lane=0;lane<8;lane++)input_data_i[8*lane+:8]=bytes_data[8*index+lane];
          input_index_i=16'(index);input_bytes_i=8;input_last_i=index+1==length/8;
          if(action==2 && index==0)input_bytes_i=7;
          if(action==3 && index==0)input_index_i=1024;
          if(action==5 && index==16)input_last_i=1;
          if(action==6 && index+1==length/8)input_last_i=0;
          if(action==7 && index==17)input_index_i=16;
          @(posedge clk);if(input_valid_i && input_ready_o)index++;
          @(negedge clk);
        end else begin input_valid_i=0;@(negedge clk);end
        if((action==8 && index>=4) || (action==9 && banks.datapath.hash_sampler.decoder.committed_r>32) ||
          (action==10 && parser.section_r==2 && banks.datapath.hash_sampler.decoder.committed_r>16))begin
          rst=1;input_valid_i=0;$fdisplay(output_file,"A");repeat(3)@(negedge clk);rst=0;reset_now=1;reset_cases++;break;
        end
        if(watchdog++>20000)$fatal(1,"SK parser timeout case%0d state%0d section%0d poly%0d word%0d decoder%0d",serial,parser.state,parser.section_r,parser.poly_r,parser.word_r,banks.datapath.hash_sampler.decoder.state);
      end
      input_valid_i=0;
      if(!reset_now)begin
        if(done_code_o!=expected_code || done_id_o!=command_id_i)$fatal(1,"SK-load completion code%0d want%0d case%0d",done_code_o,expected_code,serial);
        if(done_code_o==0)capture_fields();
        $fdisplay(output_file,"D %0d",done_code_o);
        repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=expected_code)$fatal(1,"Unstable SK-load completion");end
        done_ready_i=1;@(negedge clk);done_ready_i=0;
      end
      total_cases++;
    end
    $fdisplay(output_file,"F %0d",total_cases);$fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_SIGN_INPUT_CAPTURE_PASS:commands%0d reset%0d;actual fixed-bank SK fields;independent published-SK unpack comparison required",total_cases,reset_cases);
    $finish;
  end
  initial begin #100000000;$fatal(1,"SK parser global watchdog");end
endmodule
