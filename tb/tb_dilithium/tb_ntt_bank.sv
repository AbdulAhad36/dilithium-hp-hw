`timescale 1ns/1ps
module tb_ntt_bank;
  import ntt_pkg::*;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,start_scalar=0,start_bank=0;
  ntt_op_e op;
  logic scalar_busy,scalar_done,legacy_busy,legacy_done,bank_busy,bank_done;
  logic wr=0,wr_b=0,rd=0;
  logic [7:0] wr_addr=0,rd_addr=0;
  logic [22:0] wr_data=0,scalar_data,legacy_data,unused_data;
  logic bank_load_valid,bank_load_ready,bank_pwm_valid,bank_pwm_ready,bank_valid,bank_two;
  logic [4:0] bank_load_index,bank_input_index;
  logic [5:0] bank_pwm_index,bank_index_a,bank_index_b;
  logic [91:0] bank_load_a,bank_load_b,bank_pwm_a,bank_pwm_b,bank_pwm_c,bank_data_a,bank_data_b;
  logic [22:0] a[256],b[256],c_acc[256],captured[256];
  logic mac=0;
  logic [255:0] seen;
  bit active=0;
  int cycles=0,scalar_pin_cycles=0,coefficients=0,load_beats=0,pwm_beats=0,case_loads=0;
  int computed[4],cases_checked=0,resets_checked=0;
  string token;int input_file,output_file;
  ntt_core_scalar_reference reference(
    .clk(clk),.rst(rst),.start_i(start_scalar),.op_i(op),.busy_o(scalar_busy),.done_o(scalar_done),
    .wr_en_i(wr),.wr_b_sel_i(wr_b),.wr_addr_i(wr_addr),.wr_data_i(wr_data),
    .rd_en_i(rd),.rd_addr_i(rd_addr),.rd_data_o(scalar_data));
  ntt_core legacy(
    .clk(clk),.rst(rst),.start_i(start_scalar),.op_i(op),.busy_o(legacy_busy),.done_o(legacy_done),
    .wr_en_i(wr),.wr_b_sel_i(wr_b),.wr_addr_i(wr_addr),.wr_data_i(wr_data),
    .rd_en_i(rd),.rd_addr_i(rd_addr),.rd_data_o(legacy_data),
    .bank_load_valid_i(1'b0),.bank_load_index_i(5'd0),.bank_load_a_i(92'd0),.bank_load_b_i(92'd0),
    .bank_load_ready_o(),.bank_load_index_o(),
    .bank_pwm_valid_i(1'b0),.bank_pwm_a_i(92'd0),.bank_pwm_b_i(92'd0),.bank_pwm_c_i(92'd0),.bank_pwm_accumulate_i(1'b0),
    .bank_pwm_ready_o(),.bank_pwm_index_o(),.bank_result_valid_o(),.bank_result_two_o(),
    .bank_result_a_index_o(),.bank_result_b_index_o(),.bank_result_a_o(),.bank_result_b_o());
  ntt_core #(.BANK_IO(1)) dut(
    .clk(clk),.rst(rst),.start_i(start_bank),.op_i(op),.busy_o(bank_busy),.done_o(bank_done),
    .wr_en_i(1'b0),.wr_b_sel_i(1'b0),.wr_addr_i(8'd0),.wr_data_i(23'd0),
    .rd_en_i(1'b0),.rd_addr_i(8'd0),.rd_data_o(unused_data),
    .bank_load_valid_i(bank_load_valid),.bank_load_index_i(bank_load_index),
    .bank_load_a_i(bank_load_a),.bank_load_b_i(bank_load_b),
    .bank_load_ready_o(bank_load_ready),.bank_load_index_o(bank_input_index),
    .bank_pwm_valid_i(bank_pwm_valid),.bank_pwm_a_i(bank_pwm_a),.bank_pwm_b_i(bank_pwm_b),
    .bank_pwm_c_i(bank_pwm_c),.bank_pwm_accumulate_i(mac),
    .bank_pwm_ready_o(bank_pwm_ready),.bank_pwm_index_o(bank_pwm_index),
    .bank_result_valid_o(bank_valid),.bank_result_two_o(bank_two),
    .bank_result_a_index_o(bank_index_a),.bank_result_b_index_o(bank_index_b),
    .bank_result_a_o(bank_data_a),.bank_result_b_o(bank_data_b));
  always_comb begin
    int group;
    bank_load_valid=active && op!=OP_PWM;bank_load_index=bank_input_index;
    bank_load_a=0;bank_load_b=0;group=int'(bank_input_index[3:1]);
    if(op==OP_PRE_NTT)begin
      // Figure5 layout:word g contains0..7 with64..71;word g+8
      // contains128..135 with192..199. Each field is signed4-bit.
      for(int lane=0;lane<8;lane++)begin
        bank_load_a[4*lane+:4]=a[8*group+lane]<=4?4'(a[8*group+lane]):4'(longint'(a[8*group+lane])-Q);
        bank_load_a[4*(lane+8)+:4]=a[64+8*group+lane]<=4?4'(a[64+8*group+lane]):4'(longint'(a[64+8*group+lane])-Q);
        bank_load_b[4*lane+:4]=a[128+8*group+lane]<=4?4'(a[128+8*group+lane]):4'(longint'(a[128+8*group+lane])-Q);
        bank_load_b[4*(lane+8)+:4]=a[192+8*group+lane]<=4?4'(a[192+8*group+lane]):4'(longint'(a[192+8*group+lane])-Q);
      end
    end else for(int lane=0;lane<4;lane++)begin
      bank_load_a[23*lane+:23]=a[(op==OP_INTT?8*int'(bank_input_index):4*int'(bank_input_index))+lane];
      bank_load_b[23*lane+:23]=a[(op==OP_INTT?8*int'(bank_input_index)+4:4*int'(bank_input_index)+128)+lane];
    end
    bank_pwm_valid=active && op==OP_PWM;
    for(int lane=0;lane<4;lane++)begin
      bank_pwm_a[23*lane+:23]=a[4*int'(bank_pwm_index)+lane];
      bank_pwm_b[23*lane+:23]=b[4*int'(bank_pwm_index)+lane];
      bank_pwm_c[23*lane+:23]=c_acc[4*int'(bank_pwm_index)+lane];
    end
  end
  always @(posedge clk)begin
    cycles++;
    if(!rst)begin
      if(bank_load_valid && bank_load_ready)begin load_beats++;case_loads++;end
      if(bank_pwm_ready && bank_pwm_valid)pwm_beats++;
      if(active && bank_valid)begin
        if(bank_two !== (op!=OP_PWM))$fatal(1,"Direct NTT output word count flag");
        for(int lane=0;lane<4;lane++)begin
          if(seen[4*int'(bank_index_a)+lane])$fatal(1,"Duplicate direct NTT output address");
          seen[4*int'(bank_index_a)+lane]=1;
          captured[4*int'(bank_index_a)+lane]=bank_data_a[23*lane+:23];
          if(bank_two)begin
            if(seen[4*int'(bank_index_b)+lane])$fatal(1,"Duplicate second NTT output address");
            seen[4*int'(bank_index_b)+lane]=1;
            captured[4*int'(bank_index_b)+lane]=bank_data_b[23*lane+:23];
          end
        end
      end
    end
  end
  always @(negedge clk)if(!rst)begin
    if({legacy_busy,legacy_done}!=={scalar_busy,scalar_done})$fatal(1,"Legacy NTT pin timing changed");
    scalar_pin_cycles++;
  end
  task automatic load_scalar;
    for(int operand=0;operand<(op==OP_PWM?2:1);operand++)for(int i=0;i<256;i++)begin
      @(negedge clk);wr=1;wr_b=1'(operand);wr_addr=8'(i);wr_data=operand?b[i]:a[i];
    end
    @(negedge clk);wr=0;
  endtask
  task automatic launch;
    @(negedge clk);start_scalar=1;start_bank=1;
    @(negedge clk);start_scalar=0;start_bank=0;
  endtask
  task automatic run_case(input int serial);
    int start_cycle,scalar_cycles,bank_cycles,watchdog;
    seen=0;active=1;case_loads=0;
    load_scalar();
    if(serial%32==31)begin
      launch();repeat(5)@(negedge clk);rst=1;active=0;seen=0;
      repeat(3)@(negedge clk);rst=0;active=1;resets_checked++;case_loads=0;
      load_scalar();
    end
    launch();start_cycle=cycles;scalar_cycles=0;bank_cycles=0;watchdog=0;
    while(!scalar_cycles || !bank_cycles)begin
      @(negedge clk);watchdog++;
      if(scalar_done && !scalar_cycles)scalar_cycles=cycles-start_cycle;
      if(bank_done && !bank_cycles)bank_cycles=cycles-start_cycle;
      if(watchdog>1000)$fatal(1,"Direct NTT timeout case%0d op%0d",serial,op);
    end
    if(bank_cycles!=scalar_cycles-(op==OP_PRE_NTT?1:0))$fatal(1,"Unexpected compute latency old%0d bank%0d",scalar_cycles,bank_cycles);
    if(case_loads!=(op==OP_PWM?0:32))$fatal(1,"First transform stage did not consume exactly32 bank beats");
    computed[int'(op)]=bank_cycles;
    if(seen!=={256{1'b1}})$fatal(1,"Missing direct NTT coefficients case%0d op%0d",serial,op);
    @(negedge clk);
    $fdisplay(output_file,"%0d",serial);
    for(int i=0;i<256;i++)begin
      @(negedge clk);rd=1;rd_addr=8'(i);
      @(posedge clk);#1;
      if(scalar_data!==legacy_data)$fatal(1,"Legacy scalar NTT output changed case%0d index%0d",serial,i);
      if(captured[i] !== (mac?23'((longint'(scalar_data)+longint'(c_acc[i]))%Q):scalar_data))
        $fatal(1,"Direct NTT mismatch case%0d op%0d mac%0d index%0d got%0d old%0d",serial,op,mac,i,captured[i],scalar_data);
      $fwrite(output_file,"%06h%s",captured[i],i==255?"\n":" ");coefficients++;
    end
    @(negedge clk);rd=0;active=0;cases_checked++;
  endtask
  initial begin
    int n,serial,operation,rc;
    op=OP_NTT;seen=0;
    input_file=$fopen("sim/dilithium/stage7c_ntt_inputs.txt","r");
    output_file=$fopen("sim/dilithium/stage7c1_ntt_outputs.txt","w");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2)$fatal(1,"Prepare direct NTT fixtures first");
    $fdisplay(output_file,"%s %0d",token,n);
    repeat(3)@(negedge clk);rst=0;
    for(int c=0;c<n;c++)begin
      if($fscanf(input_file,"%d %d",serial,operation)!=2 || serial!=c)$fatal(1,"Bad NTT case order");
      for(int i=0;i<256;i++)if($fscanf(input_file,"%h",a[i])!=1)$fatal(1,"Bad NTT operandA");
      for(int i=0;i<256;i++)if($fscanf(input_file,"%h",b[i])!=1)$fatal(1,"Bad NTT operandB");
      for(int i=0;i<256;i++)if($fscanf(input_file,"%h",c_acc[i])!=1)$fatal(1,"Bad NTT accumulator");
      mac=operation==4;op=mac?OP_PWM:ntt_op_e'(operation);run_case(c);
    end
    $fclose(input_file);$fclose(output_file);
    $display("LIGHTHD_BANK_NTT_PASS:cases%0d coefficients%0d scalar_pin_cycles%0d load_beats%0d pwm_beats%0d resets%0d;start-to-done-valid edge intervals%0d/%0d/%0d/%0d,inclusive busy counts%0d/%0d/%0d/%0d;scalar preservation/fused MAC checked",
      cases_checked,coefficients,scalar_pin_cycles,load_beats,pwm_beats,resets_checked,computed[0],computed[1],computed[2],computed[3],
      computed[0]+1,computed[1]+1,computed[2]+1,computed[3]+1);
    $finish;
  end
  initial begin #5000000;$fatal(1,"Global direct NTT watchdog");end
endmodule
