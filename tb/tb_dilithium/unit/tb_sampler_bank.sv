`timescale 1ns/1ps
module tb_sampler_bank;
  parameter bit BANK_IO=1;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,job_valid_i=0,job_ready_o,job_core_i=0;
  logic [15:0] job_id_i=0,output_id_o,status_id_o;
  logic [1:0] job_mode_i=0,job_param_i=0,active_o,source_stop_o;
  logic [127:0] input_data_i=0;
  logic [4:0] input_bytes_i=0,output_bank_count_o;
  logic input_core_i=0,input_last_i=0,input_valid_i=0,input_ready_o;
  logic [22:0] output_data_o;
  logic output_core_o,output_last_o,output_valid_o,output_ready_i;
  logic [7:0] output_index_o;
  logic [91:0] output_bank_data_o;
  logic status_valid_o,status_core_o,status_ready_i;
  logic [2:0] status_code_o;
  sampler #(.BANK_IO(BANK_IO)) dut(.*);
  int serial[2],ids[2],mode[2],param[2],aborting[2],bad_bytes[2],lengths[2];
  logic [7:0] bytes_data[2][4096];
  int current[2],live_id[2],mode_live[2],count[2],group_count[2];
  bit live[2];
  int cycles=0,jobs=0,retired=0,coefficients=0,regrouped=0,legacy_pin_cycles=0;
  // Drive backpressure between sampling edges; changing it in the monitor's
  // posedge region races the DUT and can credit a transfer that never happened.
  always @(negedge clk)cycles++;
  int file_in,file_out;string token;
  logic packet_allow,status_allow,regroup_ready,regroup_valid,regroup_core,regroup_last,regroup_fault;
  logic [1:0] regroup_start;
  logic [3:0] regroup_word;
  logic [91:0] regroup_data;
  logic [4:0] group_count_reg[2];
  assign packet_allow=cycles%11>2;
  assign status_allow=cycles%7!=0;
  assign output_ready_i=packet_allow && (!BANK_IO || mode_live[output_core_o]!=1 || regroup_ready);
  assign status_ready_i=status_allow && (!BANK_IO || mode_live[status_core_o]!=1 ||
    ((status_code_o!=0 || group_count_reg[status_core_o]==16) &&
     !(regroup_valid && regroup_core==status_core_o)));
  assign regroup_start[0]=BANK_IO && job_valid_i && job_ready_o && job_mode_i==1 && !job_core_i;
  assign regroup_start[1]=BANK_IO && job_valid_i && job_ready_o && job_mode_i==1 && job_core_i;
  generate if(BANK_IO)begin:wide
    secret_regroup regroup(
      .clk(clk),.rst(rst),.job_start_i(regroup_start),
      .input_valid_i(output_valid_o && mode_live[output_core_o]==1 && packet_allow),
      .input_ready_o(regroup_ready),.input_core_i(output_core_o),.input_last_i(output_last_o),
      .input_index_i(output_index_o),.input_data_i(output_bank_data_o[63:0]),
      .output_valid_o(regroup_valid),.output_ready_i(cycles%13>3),
      .output_core_o(regroup_core),.output_last_o(regroup_last),.output_word_o(regroup_word),
      .output_data_o(regroup_data),.fault_o(regroup_fault));
  end else begin:scalar_preservation
    logic ref_job_ready,ref_input_ready,ref_output_core,ref_output_last,ref_output_valid;
    logic ref_status_valid,ref_status_core;
    logic [15:0] ref_output_id,ref_status_id;
    logic [22:0] ref_output_data;
    logic [7:0] ref_output_index;
    logic [2:0] ref_status_code;
    logic [1:0] ref_active,ref_stop;
    sampler_scalar_reference old(
      .clk(clk),.rst(rst),.job_valid_i(job_valid_i),.job_ready_o(ref_job_ready),.job_core_i(job_core_i),
      .job_id_i(job_id_i),.job_mode_i(job_mode_i),.job_param_i(job_param_i),
      .input_data_i(input_data_i),.input_bytes_i(input_bytes_i),.input_core_i(input_core_i),
      .input_last_i(input_last_i),.input_valid_i(input_valid_i),.input_ready_o(ref_input_ready),
      .output_data_o(ref_output_data),.output_core_o(ref_output_core),.output_last_o(ref_output_last),
      .output_valid_o(ref_output_valid),.output_id_o(ref_output_id),.output_index_o(ref_output_index),
      .output_ready_i(output_ready_i),.status_valid_o(ref_status_valid),.status_core_o(ref_status_core),
      .status_id_o(ref_status_id),.status_code_o(ref_status_code),.status_ready_i(status_ready_i),
      .active_o(ref_active),.source_stop_o(ref_stop));
    assign regroup_ready=1;assign regroup_valid=0;assign regroup_core=0;
    assign regroup_last=0;assign regroup_word=0;assign regroup_data=0;assign regroup_fault=0;
    always @(negedge clk)if(!rst)begin
      if({job_ready_o,input_ready_o,output_valid_o,status_valid_o,active_o,source_stop_o} !==
         {ref_job_ready,ref_input_ready,ref_output_valid,ref_status_valid,ref_active,ref_stop})
        $fatal(1,"Sampler scalar ready/status timing changed");
      if(output_valid_o && {output_data_o,output_core_o,output_last_o,output_id_o,output_index_o} !==
          {ref_output_data,ref_output_core,ref_output_last,ref_output_id,ref_output_index})
        $fatal(1,"Sampler scalar output changed");
      if(status_valid_o && {status_core_o,status_id_o,status_code_o} !== {ref_status_core,ref_status_id,ref_status_code})
        $fatal(1,"Sampler scalar completion changed");
      legacy_pin_cycles++;
    end
  end endgenerate
  always @(posedge clk)begin
    int c,n;logic [22:0] value;logic [3:0] nibble;
    if(rst)begin
      for(int k=0;k<2;k++)begin
        if(live[k])begin $fdisplay(file_out,"A %0d",current[k]);retired++;end
        live[k]=0;count[k]=0;group_count_reg[k]=0;
      end
    end else begin
      if(regroup_fault)$fatal(1,"Secret regroup protocol fault");
      if(job_valid_i && job_ready_o)begin
        c=int'(job_core_i);
        if(live[c])$fatal(1,"Sampler context reused while live");
        current[c]=serial[c];live_id[c]=int'(job_id_i);mode_live[c]=int'(job_mode_i);
        live[c]=1;count[c]=0;group_count_reg[c]=0;jobs++;
        $fdisplay(file_out,"J %0d %0d %0d %0d %0d",current[c],c,job_id_i,job_mode_i,job_param_i);
      end
      if(output_valid_o && output_ready_i)begin
        c=int'(output_core_o);n=BANK_IO?int'(output_bank_count_o):1;
        if(!live[c] || output_id_o!=live_id[c] || output_index_o!=count[c] ||
          output_last_o!=(count[c]+n==256) || (BANK_IO && n!=(mode_live[c]==1?16:4)))
          $fatal(1,"Sampler packet ownership/index/count mismatch");
        if(BANK_IO && mode_live[c]==1 && output_bank_data_o[91:64]!=0)$fatal(1,"Secret packet padding");
        for(int i=0;i<n;i++)begin
          if(!BANK_IO)value=output_data_o;
          else if(mode_live[c]==1)begin
            nibble=output_bank_data_o[4*i+:4];
            value=nibble[3]?23'(8380417+int'(nibble)-16):23'(nibble);
          end else value=output_bank_data_o[23*i+:23];
          if($isunknown(value) || value>=8380417)$fatal(1,"Sampler noncanonical packet data");
          $fdisplay(file_out,"C %0d %0d %06h",current[c],count[c],value);
          count[c]++;coefficients++;
        end
      end
      if(regroup_valid && cycles%13>3)begin
        c=int'(regroup_core);
        if(!live[c] || regroup_word!=group_count_reg[c] || regroup_last!=(regroup_word==15) || regroup_data[91:64]!=0)
          $fatal(1,"Regroup memory address/ownership mismatch");
        $fdisplay(file_out,"G %0d %0d %016h",current[c],regroup_word,regroup_data[63:0]);
        group_count_reg[c]++;regrouped++;
      end
      if(status_valid_o && status_ready_i)begin
        c=int'(status_core_o);
        if(!live[c] || status_id_o!=live_id[c] || (status_code_o==0 && count[c]!=256))$fatal(1,"Sampler completion ownership/count");
        $fdisplay(file_out,"S %0d %0d",current[c],status_code_o);live[c]=0;retired++;
      end
    end
  end
  task automatic launch(input int c);
    @(negedge clk);job_core_i=1'(c);job_id_i=16'(ids[c]);job_mode_i=2'(mode[c]);job_param_i=2'(param[c]);
    #1;if(!job_ready_o)$fatal(1,"Sampler job not ready");
    job_valid_i=1;@(negedge clk);job_valid_i=0;
  endtask
  task automatic feed(input int c,position,packet,input bit bad,
                       output bit accepted,output int amount);
    int watchdog;logic [127:0] data;
    amount=bad?bad_bytes[c]:((serial[c]%2==0)?16:(packet%4==0?1:packet%4==1?15:packet%4==2?7:8));
    if(!bad && amount>lengths[c]-position)amount=lengths[c]-position;
    data={16{8'ha5}};
    if(!bad)for(int i=0;i<amount;i++)data[8*i+:8]=bytes_data[c][position+i];
    @(negedge clk);input_core_i=1'(c);input_bytes_i=5'(amount);input_data_i=data;
    input_last_i=bad || position+amount==lengths[c];input_valid_i=1;accepted=0;watchdog=0;
    @(posedge clk);
    while(!input_ready_o && live[c] && !source_stop_o[c])begin
      @(posedge clk);if(watchdog++>10000)$fatal(1,"Sampler input timeout");
    end
    accepted=input_ready_o;@(negedge clk);input_valid_i=0;
  endtask
  initial begin
    int n,position[2],packets[2],turn,watchdog,amount;bit bad_sent[2],accepted,pending,abort_pair;
    for(int c=0;c<2;c++)begin live[c]=0;current[c]=0;mode_live[c]=0;group_count_reg[c]=0;end
    file_in=$fopen("sim/dilithium/sampler_inputs.txt","r");
    file_out=$fopen(BANK_IO?"sim/dilithium/sampler_bank_outputs.txt":"sim/dilithium/sampler_scalar_outputs.txt","w");
    if(!file_in || !file_out || $fscanf(file_in,"%s %d",token,n)!=2 || n%2)$fatal(1,"Prepare sampler bank fixtures");
    $fdisplay(file_out,"%s %0d",token,n);
    repeat(3)@(negedge clk);rst=0;
    for(int pair=0;pair<n/2;pair++)begin
      for(int c=0;c<2;c++)begin
        if($fscanf(file_in,"%d %d %d %d %d %d %d",serial[c],ids[c],mode[c],param[c],aborting[c],bad_bytes[c],lengths[c])!=7 || serial[c]!=2*pair+c)
          $fatal(1,"Invalid sampler fixture order");
        for(int i=0;i<lengths[c];i++)if($fscanf(file_in,"%h",bytes_data[c][i])!=1)$fatal(1,"Truncated sampler bytes");
        position[c]=0;packets[c]=0;bad_sent[c]=0;
      end
      launch(0);launch(1);turn=0;watchdog=0;abort_pair=aborting[0]!=0;
      while(live[0] || live[1])begin
        int c;c=turn;turn=1-turn;pending=0;
        if(live[c] && param[c]!=3)begin
          if(bad_bytes[c]>=0 && !bad_sent[c])pending=1;
          else if(bad_bytes[c]<0 && position[c]<lengths[c] && (!abort_pair || packets[c]<4))pending=1;
        end
        if(pending)begin
          feed(c,position[c],packets[c],bad_bytes[c]>=0,accepted,amount);
          if(accepted)begin
            if(bad_bytes[c]>=0)bad_sent[c]=1;
            else position[c]+=amount;
            packets[c]++;
          end else position[c]=lengths[c];
        end else @(negedge clk);
        if(abort_pair && packets[0]>=4 && packets[1]>=4)begin
          @(negedge clk);rst=1;input_valid_i=0;repeat(3)@(negedge clk);rst=0;
        end
        if(watchdog++>20000)$fatal(1,"Sampler pair did not retire");
      end
    end
    if(jobs!=n || retired!=n)$fatal(1,"Incomplete sampler job capture");
    $fdisplay(file_out,"F %0d",n);$fclose(file_in);$fclose(file_out);
    $display("LIGHTHD_SAMPLER_BANK_CAPTURE_PASS:bank_mode%0d jobs%0d coefficients%0d regrouped%0d scalar_pin_cycles%0d;run independent Python comparison",
      BANK_IO,jobs,coefficients,regrouped,legacy_pin_cycles);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Sampler bank global watchdog");end
endmodule
