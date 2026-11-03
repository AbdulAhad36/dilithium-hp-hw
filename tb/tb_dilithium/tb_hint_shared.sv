`timescale 1ns/1ps
module tb_hint_shared;
 logic idle_o;logic clk=0,rst=1;always #5 clk=~clk;
 logic  e_cancel_i;
 logic  e_command_valid_i;
 logic  e_command_ready_o;
 logic  ref_e_command_ready_o;
 logic [1:0] e_command_param_i;
 logic [15:0] e_command_id_i;
 logic  e_input_valid_i;
 logic  e_input_ready_o;
 logic  ref_e_input_ready_o;
 logic [3:0] e_input_hints_i;
 logic [2:0] e_input_row_i;
 logic [5:0] e_input_word_i;
 logic  e_input_last_i;
 logic  e_result_valid_o;
 logic  ref_e_result_valid_o;
 logic  e_result_reject_o;
 logic  ref_e_result_reject_o;
 logic  e_output_valid_o;
 logic  ref_e_output_valid_o;
 logic  e_output_ready_i;
 logic [63:0] e_output_data_o;
 logic [63:0] ref_e_output_data_o;
 logic [3:0] e_output_bytes_o;
 logic [3:0] ref_e_output_bytes_o;
 logic [3:0] e_output_index_o;
 logic [3:0] ref_e_output_index_o;
 logic  e_output_last_o;
 logic  ref_e_output_last_o;
 logic [15:0] e_output_id_o;
 logic [15:0] ref_e_output_id_o;
 logic  e_done_valid_o;
 logic  ref_e_done_valid_o;
 logic  e_done_ready_i;
 logic [1:0] e_done_code_o;
 logic [1:0] ref_e_done_code_o;
 logic  d_command_valid_i;
 logic  d_command_ready_o;
 logic  ref_d_command_ready_o;
 logic [1:0] d_command_param_i;
 logic [15:0] d_command_id_i;
 logic  d_input_valid_i;
 logic  d_input_ready_o;
 logic  ref_d_input_ready_o;
 logic [63:0] d_input_data_i;
 logic [3:0] d_input_index_i;
 logic [3:0] d_input_bytes_i;
 logic  d_input_last_i;
 logic  d_output_valid_o;
 logic  ref_d_output_valid_o;
 logic  d_output_ready_i;
 logic [3:0] d_output_hints_o;
 logic [3:0] ref_d_output_hints_o;
 logic [2:0] d_output_row_o;
 logic [2:0] ref_d_output_row_o;
 logic [5:0] d_output_word_o;
 logic [5:0] ref_d_output_word_o;
 logic  d_output_last_o;
 logic  ref_d_output_last_o;
 logic [15:0] d_output_id_o;
 logic [15:0] ref_d_output_id_o;
 logic  d_done_valid_o;
 logic  ref_d_done_valid_o;
 logic  d_done_ready_i;
 logic [2:0] d_done_code_o;
 logic [2:0] ref_d_done_code_o;
 logic [15:0] d_done_id_o;
 logic [15:0] ref_d_done_id_o;
 parameter bit CYCLE_REFERENCE=0;
 generate if(CYCLE_REFERENCE)begin:retained_compare
  hint_timing_reference old(
    .clk(clk),
    .rst(rst),
    .e_cancel_i(e_cancel_i),
    .e_command_valid_i(e_command_valid_i),
    .e_command_param_i(e_command_param_i),
    .e_command_id_i(e_command_id_i),
    .e_input_valid_i(e_input_valid_i),
    .e_input_hints_i(e_input_hints_i),
    .e_input_row_i(e_input_row_i),
    .e_input_word_i(e_input_word_i),
    .e_input_last_i(e_input_last_i),
    .e_output_ready_i(e_output_ready_i),
    .e_done_ready_i(e_done_ready_i),
    .d_command_valid_i(d_command_valid_i),
    .d_command_param_i(d_command_param_i),
    .d_command_id_i(d_command_id_i),
    .d_input_valid_i(d_input_valid_i),
    .d_input_data_i(d_input_data_i),
    .d_input_index_i(d_input_index_i),
    .d_input_bytes_i(d_input_bytes_i),
    .d_input_last_i(d_input_last_i),
    .d_output_ready_i(d_output_ready_i),
    .d_done_ready_i(d_done_ready_i));
  int compared_clocks=0;
  always @(posedge clk)begin
   #1;
   if(!rst)begin
    if({dut.indices_r,dut.counts_r,dut.read_index_r,dut.e_state,dut.d_state,dut.e_total_r}
       !=={old.indices_r,old.counts_r,old.read_index_r,old.e_state,old.d_state,old.e_total_r})
     $fatal(1,"Hint payload/storage/control differs from qualified RTL");
    compared_clocks++;
   end
  end
  final $display("HINT_RETAINED_CYCLE_REFERENCE_PASS:%0d clocks/exact640bit indices,counts,read address,FSMs,total",compared_clocks);
 end endgenerate
 hint_codec dut(.*);
 hintpkg_c13_reference reference_0(.clk(clk),.rst(rst),
  .cancel_i(e_cancel_i),
  .command_valid_i(e_command_valid_i),
  .command_ready_o(ref_e_command_ready_o),
  .command_param_i(e_command_param_i),
  .command_id_i(e_command_id_i),
  .input_valid_i(e_input_valid_i),
  .input_ready_o(ref_e_input_ready_o),
  .input_hints_i(e_input_hints_i),
  .input_row_i(e_input_row_i),
  .input_word_i(e_input_word_i),
  .input_last_i(e_input_last_i),
  .result_valid_o(ref_e_result_valid_o),
  .result_reject_o(ref_e_result_reject_o),
  .output_valid_o(ref_e_output_valid_o),
  .output_ready_i(e_output_ready_i),
  .output_data_o(ref_e_output_data_o),
  .output_bytes_o(ref_e_output_bytes_o),
  .output_index_o(ref_e_output_index_o),
  .output_last_o(ref_e_output_last_o),
  .output_id_o(ref_e_output_id_o),
  .done_valid_o(ref_e_done_valid_o),
  .done_ready_i(e_done_ready_i),
  .done_code_o(ref_e_done_code_o));
 hint_decode_stage_reference reference_1(.clk(clk),.rst(rst),
  .command_valid_i(d_command_valid_i),
  .command_ready_o(ref_d_command_ready_o),
  .command_param_i(d_command_param_i),
  .command_id_i(d_command_id_i),
  .input_valid_i(d_input_valid_i),
  .input_ready_o(ref_d_input_ready_o),
  .input_data_i(d_input_data_i),
  .input_index_i(d_input_index_i),
  .input_bytes_i(d_input_bytes_i),
  .input_last_i(d_input_last_i),
  .output_valid_o(ref_d_output_valid_o),
  .output_ready_i(d_output_ready_i),
  .output_hints_o(ref_d_output_hints_o),
  .output_row_o(ref_d_output_row_o),
  .output_word_o(ref_d_output_word_o),
  .output_last_o(ref_d_output_last_o),
  .output_id_o(ref_d_output_id_o),
  .done_valid_o(ref_d_done_valid_o),
  .done_ready_i(d_done_ready_i),
  .done_code_o(ref_d_done_code_o),
  .done_id_o(ref_d_done_id_o));
 int active=0,cycles=0,packets=0,checks=0,resets=0,produced=0,final_stall_checks=0,encoder_frame_rejects=0;
 logic [7:0] encoded_bytes[88],frame[88];
 assign e_output_ready_i=cycles%5!=1;
 assign d_output_ready_i=cycles%7>=3;
 always @(posedge clk)begin
  cycles++;
  if(cycles>200000)$fatal(1,"Shared hint switching timeout");
  if(!rst && e_output_valid_o && e_output_ready_i)begin
   for(int b=0;b<8;b++)if(b<int'(e_output_bytes_o))begin
    if(produced>=88)$fatal(1,"Encoder byte overflow");
    encoded_bytes[produced]=e_output_data_o[8*b+:8];produced++;
   end
  end
  #1;
  if(!rst)begin
   if(active==1 && d_output_valid_o && !d_output_ready_i && d_output_last_o &&
      d_output_row_o==(d_command_param_i==0?3'd3:d_command_param_i==1?3'd5:3'd7))begin
    if(d_done_valid_o)$fatal(1,"Decoder completed with stalled final registered mask");
    final_stall_checks++;
   end
   if(active==0)begin
    if({e_command_ready_o,e_input_ready_o,e_result_valid_o,e_result_reject_o,e_done_valid_o,e_done_code_o}
       !=={ref_e_command_ready_o,ref_e_input_ready_o,ref_e_result_valid_o,ref_e_result_reject_o,ref_e_done_valid_o,ref_e_done_code_o})
     $fatal(1,"Shared encoder control mismatch clock%0d",cycles);
    if(e_output_valid_o!==ref_e_output_valid_o || (e_output_valid_o &&
      {e_output_data_o,e_output_bytes_o,e_output_index_o,e_output_last_o,e_output_id_o}!==
      {ref_e_output_data_o,ref_e_output_bytes_o,ref_e_output_index_o,ref_e_output_last_o,ref_e_output_id_o}))
     $fatal(1,"Shared encoder payload mismatch clock%0d",cycles);
   end else begin
    if({d_command_ready_o,d_input_ready_o,d_output_valid_o,d_done_valid_o,d_done_code_o,d_done_id_o}!==
       {ref_d_command_ready_o,ref_d_input_ready_o,ref_d_output_valid_o,ref_d_done_valid_o,ref_d_done_code_o,ref_d_done_id_o})
     $fatal(1,"Shared decoder control mismatch clock%0d",cycles);
    if(d_output_valid_o && {d_output_hints_o,d_output_row_o,d_output_word_o,d_output_last_o,d_output_id_o}!==
       {ref_d_output_hints_o,ref_d_output_row_o,ref_d_output_word_o,ref_d_output_last_o,ref_d_output_id_o})
     $fatal(1,"Shared decoder payload mismatch clock%0d",cycles);
   end
   checks++;
  end
 end
 task automatic reset_all();
  @(negedge clk);e_input_valid_i=0;d_input_valid_i=0;rst=1;
  repeat(2)@(negedge clk);rst=0;resets++;
 endtask
 task automatic encode_job(input int p,trial,output bit complete);
  int k,lev;
  lev=trial==9?3:p;k=lev==0?4:lev==1?6:8;complete=0;produced=0;
  @(negedge clk);active=0;e_command_param_i=2'(lev);e_command_id_i=16'(100+trial+p*10);e_command_valid_i=1;
  do @(posedge clk);while(!e_command_ready_o);
  @(negedge clk);e_command_valid_i=0;
  if(lev!=3)for(int s=0;s<k*64;s++)begin
   @(negedge clk);e_input_valid_i=1;e_input_row_i=3'(s/64);e_input_word_i=6'(s%64);e_input_last_i=s%64==63;
   e_input_hints_i=0;
   for(int lane=0;lane<4;lane++)begin
    if(trial==10)e_input_hints_i[lane]=s*4+lane<(p==0?80:p==1?55:75);
    else if(trial==11)e_input_hints_i[lane]=s%64==63 && lane==3;
    else if(trial==2 || (trial!=1 && (s*4+lane)%43==trial%43))e_input_hints_i[lane]=1;
   end
   // Force an actual candidate append on each malformed metadata variant.
   if(trial>=12 && s==9)begin
    e_input_hints_i=4'b0101;
    case(trial)
     12:e_input_row_i=1;
     13:e_input_word_i=10;
     14:e_input_last_i=1;
    endcase
   end
   do @(posedge clk);while(!e_input_ready_o);
   @(negedge clk);e_input_valid_i=0;
   if(trial>=12 && s==9)break;
   if(trial==3 && s==9)begin e_cancel_i=1;@(negedge clk);e_cancel_i=0;packets++;return;end
   if(trial==4 && s==17)begin reset_all();packets++;return;end
  end
  while(!e_done_valid_o)@(negedge clk);
  if(trial>=12)begin
   if(e_done_code_o!=2 || produced!=0)$fatal(1,"Malformed encoder frame published bytes or missed code2");
   encoder_frame_rejects++;
  end
  complete=!e_result_reject_o && e_done_code_o==0;
  @(negedge clk);e_done_ready_i=1;@(negedge clk);e_done_ready_i=0;packets++;
 endtask
 task automatic decode_job(input int p,trial,input bit complete);
  int omega,k,total,n;
  omega=p==0?80:p==1?55:75;k=p==0?4:p==1?6:8;total=omega+k;n=(total+7)/8;
  for(int i=0;i<88;i++)frame[i]=complete?encoded_bytes[i]:0;
  if(trial==6)frame[omega]=8'(omega+1);
  @(negedge clk);active=1;e_cancel_i=trial==5;d_done_ready_i=1;d_command_param_i=2'(p);d_command_id_i=16'(200+trial+p*10);d_command_valid_i=1;
  do @(posedge clk);while(!d_command_ready_o);
  @(negedge clk);d_command_valid_i=0;
  for(int wordno=0;wordno<n;wordno++)begin
   @(negedge clk);d_input_valid_i=1;d_input_index_i=4'(wordno);d_input_last_i=wordno==n-1;
   d_input_bytes_i=4'(wordno==n-1?total-wordno*8:8);d_input_data_i=0;
   for(int b=0;b<8;b++)if(wordno*8+b<total)d_input_data_i[8*b+:8]=frame[wordno*8+b];
   if(trial==7 && wordno==0)d_input_bytes_i=7;
   do @(posedge clk);while(!d_input_ready_o);
   @(negedge clk);d_input_valid_i=0;
   if(trial==7)break;
   if(trial==8 && wordno==3)begin reset_all();packets++;return;end
  end
  while(!d_done_valid_o)@(negedge clk);
  @(negedge clk);e_cancel_i=0;d_done_ready_i=1;@(negedge clk);d_done_ready_i=0;packets++;
 endtask
 initial begin
  e_cancel_i=0;
  e_command_valid_i=0;
  e_command_param_i=0;
  e_command_id_i=0;
  e_input_valid_i=0;
  e_input_hints_i=0;
  e_input_row_i=0;
  e_input_word_i=0;
  e_input_last_i=0;
  e_done_ready_i=0;
  d_command_valid_i=0;
  d_command_param_i=0;
  d_command_id_i=0;
  d_input_valid_i=0;
  d_input_data_i=0;
  d_input_index_i=0;
  d_input_bytes_i=0;
  d_input_last_i=0;
  d_done_ready_i=0;
  repeat(3)@(negedge clk);rst=0;
  for(int p=0;p<3;p++)for(int trial=0;trial<15;trial++)begin
   bit complete;encode_job(p,trial,complete);decode_job(p,trial,complete);
  end
  if(encoder_frame_rejects!=9)$fatal(1,"Missing encoder metadata reject/recovery cases");
  $display("HINT_ENCODER_FRAME_REJECT_PASS:%0d row/word/last faults with candidate payload and cross-mode recovery",encoder_frame_rejects);
  if(final_stall_checks==0)$fatal(1,"Missing final registered hint-output stall");
  $display("SHARED_HINT_REGISTERED_FINAL_STALL_PASS:%0d held-final checks with early done-ready",final_stall_checks);
  $display("SHARED_HINT_MODE_SWITCH_PASS:%0d alternating commands/%0d qualified control-payload checks/%0d resets;cancel,overflow,malformed input and cross-mode recovery",packets,checks,resets);
  $finish;
 end
endmodule
