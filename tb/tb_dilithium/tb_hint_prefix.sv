`timescale 1ns/1ps
module tb_hint_prefix;
 logic clk=0,rst=1;logic [3:0] hints=0;logic [5:0] word_cfg;
 logic [6:0] total_cfg,omega_cfg;logic reject_cfg;
 logic [63:0] first,second;int checks=0;
 logic [6:0] decode_position_cfg,decode_end_cfg;
 logic [5:0] decode_word_cfg;logic [31:0] decode_window_cfg;
 hint_codec dut(.clk(clk),.rst(rst),.e_input_hints_i(hints),.e_input_word_i(word_cfg),.e_cancel_i('0),.e_command_valid_i('0),.e_command_param_i('0),.e_command_id_i('0),.e_input_valid_i('0),.e_input_row_i('0),.e_input_last_i('0),.e_output_ready_i('0),.e_done_ready_i('0),.d_command_valid_i('0),.d_command_param_i('0),.d_command_id_i('0),.d_input_valid_i('0),.d_input_data_i('0),.d_input_index_i('0),.d_input_bytes_i('0),.d_input_last_i('0),.d_output_ready_i('0),.d_done_ready_i('0));
 hint_codec_c22_reference old(.clk(clk),.rst(rst),.e_input_hints_i(hints),.e_input_word_i(word_cfg),.e_cancel_i('0),.e_command_valid_i('0),.e_command_param_i('0),.e_command_id_i('0),.e_input_valid_i('0),.e_input_row_i('0),.e_input_last_i('0),.e_output_ready_i('0),.e_done_ready_i('0),.d_command_valid_i('0),.d_command_param_i('0),.d_command_id_i('0),.d_input_valid_i('0),.d_input_data_i('0),.d_input_index_i('0),.d_input_bytes_i('0),.d_input_last_i('0),.d_output_ready_i('0),.d_done_ready_i('0));
 task automatic check_decode_advance;
  int decoded_checks;decoded_checks=0;
  force dut.d_position_r=decode_position_cfg;force old.d_position_r=decode_position_cfg;
  force dut.d_end_r=decode_end_cfg;force old.d_end_r=decode_end_cfg;
  force dut.d_word_r=decode_word_cfg;force old.d_word_r=decode_word_cfg;
  force dut.decoded_window=decode_window_cfg;force old.decoded_window=decode_window_cfg;
  for(int position=0;position<128;position++)for(int count=0;count<=4;count++)
   for(int mask=0;mask<16;mask++)for(int wordno=0;wordno<64;wordno++)begin
    int matched;logic [3:0] gold_hints;matched=0;gold_hints=0;
    decode_position_cfg=7'(position);decode_end_cfg=7'(position+count);decode_word_cfg=6'(wordno);
    for(int lane=0;lane<4;lane++)begin
     decode_window_cfg[8*lane+:8]={6'(mask&(1<<lane)?wordno:wordno^1),2'(lane)};
     if((mask&(1<<lane)) && ((position+lane)&127)<int'(decode_end_cfg))begin
      matched++;gold_hints[lane]=1;
     end
    end
    #1;
    if(dut.d_matched_positions!==3'(matched) || dut.d_generated_hints!==gold_hints ||
       dut.d_next_position!==7'(position+matched) ||
       {dut.d_matched_positions,dut.d_generated_hints,dut.d_next_position}!==
       {old.d_matched_positions,old.d_generated_hints,old.d_next_position})
      $fatal(1,"Hint decode advance mismatch position%0d end%0d mask%0h word%0d",position,decode_end_cfg,mask,wordno);
    decoded_checks++;
   end
  release dut.d_position_r;release old.d_position_r;release dut.d_end_r;release old.d_end_r;
  release dut.d_word_r;release old.d_word_r;release dut.decoded_window;release old.decoded_window;
  $display("HINT_DECODE_ADVANCE_PROOF_PASS:%0d combinations/all128positions/all16matchpatterns/all64words/row-end clipping/wrap;oldRTL plus integer oracle",decoded_checks);
 endtask
 initial begin
  check_decode_advance();
  force dut.e_total_r=total_cfg;force old.e_total_r=total_cfg;
  force dut.e_omega_r=omega_cfg;force old.e_omega_r=omega_cfg;
  force dut.e_result_reject_o=reject_cfg;force old.e_result_reject_o=reject_cfg;
  force dut.e_word_r=word_cfg;force old.e_word_r=word_cfg;
  force dut.shared_read_first=first;force old.shared_read_first=first;
  force dut.shared_read_second=second;force old.shared_read_second=second;
  for(int total=0;total<128;total++)for(int omega=0;omega<3;omega++)
   for(int rejected=0;rejected<2;rejected++)for(int mask=0;mask<16;mask++)for(int word=0;word<64;word++)begin
    logic [63:0] gold_first,gold_second;bit fw,sw;int new_total,target,first_index,second_index;
    total_cfg=7'(total);omega_cfg=omega==0?55:omega==1?75:80;reject_cfg=1'(rejected);hints=4'(mask);word_cfg=6'(word);
    first=64'h6a129e5f0324ac81 ^ (64'(checks)*64'h105050505);second=~first;
    gold_first=first;gold_second=second;fw=0;sw=0;new_total=(total+$countones(hints))&127;
    first_index=total>>3;second_index=(first_index+1)&15;
    for(int lane=0;lane<4;lane++)if(hints[lane])begin
     target=(total+$countones(hints & 4'((1<<lane)-1)))&127;
     if(target<int'(omega_cfg) && !rejected)begin
      if((target>>3)==first_index)begin gold_first[8*(target&7)+:8]={6'(word),2'(lane)};fw=1;end
      else begin gold_second[8*(target&7)+:8]={6'(word),2'(lane)};sw=1;end
     end
    end
    #1;
    if({dut.e_new_total,dut.e_first_index,dut.e_second_index,dut.e_first_write,dut.e_second_write,dut.e_overflow,dut.e_first_word,dut.e_second_word}!==
       {old.e_new_total,old.e_first_index,old.e_second_index,old.e_first_write,old.e_second_write,old.e_overflow,old.e_first_word,old.e_second_word})$fatal(1,"Hint prefix old/new mismatch");
    if(dut.e_new_total!=new_total || dut.e_first_index!=first_index || dut.e_second_index!=second_index || dut.e_first_write!==fw || dut.e_second_write!==sw || dut.e_overflow!==(new_total>int'(omega_cfg)) || dut.e_first_word!==gold_first || dut.e_second_word!==gold_second)$fatal(1,"Independent hint append oracle mismatch");
    checks++;
   end
  $display("LIGHTHD_HINT_PREFIX_PROOF_PASS:%0d combinations/all masks/all64words/all128totals/3limits/reject0and1;integer prefix oracle/C22 actual logic;field-only,no UVM credit",checks);
  $finish;
 end
endmodule
