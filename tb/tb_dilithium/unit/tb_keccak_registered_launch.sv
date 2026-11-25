module keccak_empty_launch_case #(parameter integer OFFSET=0)(output logic finished=0);
 timeunit 1ns;timeprecision 1ps;
 logic clk=0,rst=1,request_valid=0,request_ready,request_core,mode=0;
 logic [1:0] core_busy,core_done;
 logic busy,output_valid,output_core;
 logic output_ready=0;
 logic [127:0] data;
 logic [4:0] bytes_out;
 logic [1:0] expected_valid;
 logic [127:0] expected[2];
 integer clocks=0,accepted=0,checked=0,held=0,consecutive=0,last_accept=-2;
 logic stalled=0;
 logic [127:0] held_data;
 logic held_core;
 always #5 clk=~clk;
 always @(negedge clk)output_ready=!rst && clocks%5>=2;
 keccak_dual_interleaved #(.START_OFFSET_CYCLES(OFFSET)) dut(
  .clk(clk),.rst(rst),.request_valid_i(request_valid),.request_ready_o(request_ready),
  .request_core_o(request_core),.keccak_mode_i(mode),.message_len_i(16'd0),.output_len_i(16'd16),
  .input_data_i(64'd0),.input_valid_i(1'b0),.input_ready_o(),.input_core_o(),
  .stop_i(2'b0),.core_busy_o(core_busy),.core_done_o(core_done),.busy_o(busy),
  .output_data_o(data),.output_valid_o(output_valid),.output_bytes_o(bytes_out),
  .output_core_o(output_core),.output_ready_i(output_ready));
 always @(posedge clk)begin
  if(rst)begin expected_valid=0;accepted=0;checked=0;stalled=0;last_accept=-2;consecutive=0;held=0;clocks=0;end
  else begin
   clocks=clocks+1;
   if(stalled)begin
    if(!output_valid || data!==held_data || output_core!==held_core || bytes_out!==16)$fatal(1,"Empty hash stalled payload changed");
    held=held+1;
   end
   if(request_valid && request_ready)begin
    if(expected_valid[request_core])$fatal(1,"Empty hash reused owned core");
    expected_valid[request_core]=1;
    expected[request_core]=mode?128'h24eb3e74eb3f3b23138da80b2bddb946:128'h3e850576504560617d828fe8a42b9c7f;
    if(clocks==last_accept+1)consecutive=consecutive+1;
    last_accept=clocks;accepted=accepted+1;
   end
   if(output_valid && output_ready)begin
    if(!expected_valid[output_core] || bytes_out!==16 || data!==expected[output_core])$fatal(1,"Empty SHAKE Python-derived digest mismatch");
    expected_valid[output_core]=0;checked=checked+1;
   end
   stalled=output_valid && !output_ready;
   if(stalled)begin held_data=data;held_core=output_core;end
   if(clocks>5000)$fatal(1,"Empty hash watchdog");
  end
 end
 task automatic send_empty(input logic selected_mode);
  @(negedge clk);request_valid=1;mode=selected_mode;
  @(posedge clk);while(!request_ready)@(posedge clk);
  #1;
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  // Reset after descriptor acceptance, before its registered core launch.
  send_empty(0);
  @(negedge clk);request_valid=0;rst=1;
  repeat(2)@(negedge clk);rst=0;
  repeat(3)@(negedge clk);
  if(busy || output_valid)$fatal(1,"Pending descriptor survived reset");
  send_empty(0);send_empty(1);send_empty(1);send_empty(0);send_empty(1);send_empty(0);
  @(negedge clk);request_valid=0;
  wait(checked==6);
  repeat(4)@(negedge clk);
  if(accepted!=6 || expected_valid!=0 || held==0)$fatal(1,"Missing empty-hash/stall checks");
  if(OFFSET<=1 && consecutive==0)$fatal(1,"No consecutive empty command accepts");
  $display("KECCAK_REGISTERED_EMPTY_LAUNCH_PASS:offset%0d accepted%0d checked%0d held%0d consecutive%0d reset-pending",OFFSET,accepted,checked,held,consecutive);
  finished=1;
 end
endmodule
module tb_keccak_registered_launch;
 timeunit 1ns;timeprecision 1ps;
 wire [2:0] finished;
 keccak_empty_launch_case #(.OFFSET(0)) c0(finished[0]);
 keccak_empty_launch_case #(.OFFSET(1)) c1(finished[1]);
 keccak_empty_launch_case #(.OFFSET(26)) c26(finished[2]);
 initial begin wait(&finished);$display("KECCAK_REGISTERED_EMPTY_LAUNCH_ALL_PASS:18 empty SHAKE128/256 outputs;offset0/1/26;stalls;pending reset");$finish;end
endmodule

// Fast field-level proof of the aligned output unit,using the qualified unit.
module keccak_output_bounds_case #(parameter int WIDTH=128)(output logic finished=0);
 timeunit 1ns;timeprecision 1ps;
 localparam int B=WIDTH/8;
 localparam int CW=$clog2(B+1);
 logic [4:0][4:0][63:0] state_array_i='0;
 logic [10:0] rate_i=0;
 logic [7:0] bytes_squeezed_i=0;
 logic [15:0] xof_len_i=0;
 logic is_xof_fixed_len_i=0;
 wire [7:0] next_count,ref_next_count;
 wire need_perm,ref_need_perm,final_o,ref_final;
 wire [WIDTH-1:0] data_o,ref_data;
 wire [CW-1:0] valid_bytes,ref_bytes;
 longint checks=0;
 keccak_output_unit #(.OUTPUT_DWIDTH(WIDTH),.ALIGNED_COUNTER(1)) dut(
  .state_array_i(state_array_i),.rate_i(rate_i),.bytes_squeezed_i(bytes_squeezed_i),
  .xof_len_i(xof_len_i),.is_xof_fixed_len_i(is_xof_fixed_len_i),
  .bytes_squeezed_o(next_count),.squeeze_perm_needed_o(need_perm),
  .data_o(data_o),.valid_bytes_o(valid_bytes),.final_o(final_o));
 keccak_output_timing_reference #(.OUTPUT_DWIDTH(WIDTH)) old(
  .state_array_i(state_array_i),.rate_i(rate_i),.bytes_squeezed_i(bytes_squeezed_i),
  .xof_len_i(xof_len_i),.is_xof_fixed_len_i(is_xof_fixed_len_i),
  .bytes_squeezed_o(ref_next_count),.squeeze_perm_needed_o(ref_need_perm),
  .data_o(ref_data),.valid_bytes_o(ref_bytes),.final_o(ref_final));
 task automatic compare_outputs;
  #1ps;
  if({next_count,need_perm,data_o,valid_bytes,final_o} !==
     {ref_next_count,ref_need_perm,ref_data,ref_bytes,ref_final})
   $fatal(1,"KOU mismatch width%0d rate%h count%h xof%h fixed%b",WIDTH,rate_i,bytes_squeezed_i,xof_len_i,is_xof_fixed_len_i);
  checks++;
 endtask
 initial begin
  for(int y=0;y<5;y++)for(int x=0;x<5;x++)state_array_i[x][y]={$urandom,$urandom};
  // Every raw rate and aligned counter,including wrapped/invalid ranges;
  // every XOF value which can change a clamp/last decision,plus a high value.
  for(int rate=0;rate<2048;rate++)for(int count=0;count<256;count+=B)
   for(int length=0;length<=B+2;length++)for(int fixed_mode=0;fixed_mode<2;fixed_mode++)begin
    rate_i=11'(rate);bytes_squeezed_i=8'(count);
    xof_len_i=length==B+2?16'hffff:16'(length);is_xof_fixed_len_i=1'(fixed_mode);
    compare_outputs();
   end
  // For each possible rate-limited byte count,sweep EVERY16-bit XOF length.
  bytes_squeezed_i=0;
  for(int available=0;available<=B;available++)begin
   rate_i=11'(available*8);
   for(int length=0;length<65536;length++)for(int fixed_mode=0;fixed_mode<2;fixed_mode++)begin
    xof_len_i=16'(length);is_xof_fixed_len_i=1'(fixed_mode);compare_outputs();
   end
  end
  // Preserve generic procedural X behavior for unknown rate/XOF bits.
  for(int rate=0;rate<2048;rate+=8)for(int count=0;count<256;count+=B)
   for(int bitno=0;bitno<11;bitno++)for(int xz=0;xz<2;xz++)begin
    rate_i=11'(rate);rate_i[bitno]=xz?1'bz:1'bx;
    bytes_squeezed_i=8'(count);xof_len_i=16'd9;is_xof_fixed_len_i=1;
    compare_outputs();
   end
  rate_i=11'd1344;bytes_squeezed_i=0;
  for(int bitno=0;bitno<16;bitno++)for(int fixed_mode=0;fixed_mode<3;fixed_mode++)begin
   xof_len_i=16'd9;xof_len_i[bitno]=1'bx;
   is_xof_fixed_len_i=fixed_mode==2?1'bx:1'(fixed_mode);compare_outputs();
  end
  $display("KECCAK_OUTPUT_BOUNDS_EQUIVALENCE_PASS:width%0d/%0d all-output checks;all rates/aligned counters;all XOF lengths per bound;X/Z probes",WIDTH,checks);
  finished=1;
 end
endmodule
module tb_keccak_output_bounds;
 timeunit 1ns;timeprecision 1ps;
 wire [1:0] finished;
 keccak_output_bounds_case #(.WIDTH(64)) c64(finished[0]);
 keccak_output_bounds_case #(.WIDTH(128)) c128(finished[1]);
 initial begin wait(&finished);$display("KECCAK_OUTPUT_BOUNDS_ALL_PASS");$finish;end
 initial begin #1000000000;$fatal(1,"KOU bound proof watchdog");end
endmodule
