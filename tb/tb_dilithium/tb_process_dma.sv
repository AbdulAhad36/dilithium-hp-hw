`timescale 1ns/1ps
module tb_process_dma;
  parameter bit CYCLE_REFERENCE=0;
  import dilithium_pkg::*;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i=0,command_ready_o,done_valid_o,done_ready_i=0;
  process_op_e command_op_i;
  logic [1:0] command_param_i=0,command_kind_i=0,done_code_o;
  logic command_b_enable_i=0,command_b_compact_i=0,command_low_enable_i=1,command_pack_high_i=0;
  logic command_a_compact_i=0,command_pack_store_i=1,packed_valid_o,packed_ready_i=1,packed_last_o;
  logic [2:0] command_pack_op_i=0;logic [63:0] packed_data_o;logic [6:0] packed_index_o;
  logic command_hint_enable_i=0,hint_valid_o,hint_ready_i,hint_last_o;
  logic [3:0] hint_mask_o;logic [5:0] hint_word_o;
  logic [1:0] command_a_bank_i=0,command_b_bank_i=2,command_d_bank_i=0,command_h_bank_i=3;
  logic [9:0] command_a_base_i=0,command_b_base_i=0,command_d_base_i=0,command_h_base_i=576;
  logic done_reject_o;logic [8:0] done_hint_weight_o;
  logic [1:0][1:0] dut_command_valid_i,dut_command_ready_o;
  logic [1:0][1:0][3:0] dut_command_mask_i,dut_command_write_i,dut_write_valid_i,dut_write_ready_o;
  logic [1:0][1:0][3:0][9:0] dut_command_base_i,dut_read_address_o;
  logic [1:0][1:0][3:0][10:0] dut_command_words_i;
  logic [1:0][1:0][3:0][1:0] dut_command_mode_i;
  logic [1:0][1:0][3:0][91:0] dut_write_data_i,dut_read_data_o;
  wire [1:0][1:0][3:0][9:0] dut_write_address_i='0;
  logic [1:0][1:0][3:0] dut_read_valid_o,dut_read_ready_i,dut_read_last_o,dut_done_valid_o,dut_done_error_o,dut_done_ready_i;
  assign dut_command_valid_i[1]=0;assign dut_command_mask_i[1]=0;assign dut_command_write_i[1]=0;
  assign dut_command_base_i[1]=0;assign dut_command_words_i[1]=0;assign dut_command_mode_i[1]=0;
  assign dut_write_valid_i[1]=0;assign dut_write_data_i[1]=0;assign dut_read_ready_i[1]=0;assign dut_done_ready_i[1]=0;
  bank_fixture banks(.*);
  process_dma dut(
    .clk(clk),.rst(rst),.command_valid_i(command_valid_i),.command_ready_o(command_ready_o),
    .command_op_i(command_op_i),.command_param_i(command_param_i),.command_kind_i(command_kind_i),
    .command_b_enable_i(command_b_enable_i),.command_b_compact_i(command_b_compact_i),
    .command_a_compact_i(command_a_compact_i),.command_pack_store_i(command_pack_store_i),.command_pack_op_i(command_pack_op_i),
    .command_hint_enable_i(command_hint_enable_i),.hint_valid_o(hint_valid_o),.hint_ready_i(hint_ready_i),
    .hint_mask_o(hint_mask_o),.hint_word_o(hint_word_o),.hint_last_o(hint_last_o),
    .packed_valid_o(packed_valid_o),.packed_ready_i(packed_ready_i),.packed_data_o(packed_data_o),.packed_index_o(packed_index_o),.packed_last_o(packed_last_o),
    .command_low_enable_i(command_low_enable_i),.command_pack_high_i(command_pack_high_i),
    .command_a_bank_i(command_a_bank_i),.command_b_bank_i(command_b_bank_i),
    .command_d_bank_i(command_d_bank_i),.command_h_bank_i(command_h_bank_i),
    .command_a_base_i(command_a_base_i),.command_b_base_i(command_b_base_i),
    .command_d_base_i(command_d_base_i),.command_h_base_i(command_h_base_i),
    .done_valid_o(done_valid_o),.done_ready_i(done_ready_i),.done_code_o(done_code_o),
    .done_reject_o(done_reject_o),.done_hint_weight_o(done_hint_weight_o),
    .memory_command_valid_o(dut_command_valid_i[0]),
    .memory_command_ready_i(dut_command_ready_o[0]),
    .memory_command_mask_o(dut_command_mask_i[0]),
    .memory_command_write_o(dut_command_write_i[0]),
    .memory_command_base_o(dut_command_base_i[0]),
    .memory_command_words_o(dut_command_words_i[0]),
    .memory_command_mode_o(dut_command_mode_i[0]),
    .memory_write_valid_o(dut_write_valid_i[0]),
    .memory_write_ready_i(dut_write_ready_o[0]),
    .memory_write_data_o(dut_write_data_i[0]),
    .memory_read_valid_i(dut_read_valid_o[0]),
    .memory_read_ready_o(dut_read_ready_i[0]),
    .memory_read_data_i(dut_read_data_o[0]),
    .memory_done_valid_i(dut_done_valid_o[0]),
    .memory_done_error_i(dut_done_error_o[0]),
    .memory_done_ready_o(dut_done_ready_i[0]));
  generate if(CYCLE_REFERENCE)begin:timing_reference
    int checked_clocks=0;
    logic reference_command_ready_o;
    logic reference_done_valid_o;
    logic [1:0] reference_done_code_o;
    logic reference_done_reject_o;
    logic [8:0] reference_done_hint_weight_o;
    logic reference_packed_valid_o;
    logic [63:0] reference_packed_data_o;
    logic [6:0] reference_packed_index_o;
    logic reference_packed_last_o;
    logic reference_hint_valid_o;
    logic [3:0] reference_hint_mask_o;
    logic [5:0] reference_hint_word_o;
    logic reference_hint_last_o;
    logic [1:0] reference_memory_command_valid_o;
    logic [1:0][3:0] reference_memory_command_mask_o;
    logic [1:0][3:0] reference_memory_command_write_o;
    logic [1:0][3:0][9:0] reference_memory_command_base_o;
    logic [1:0][3:0][10:0] reference_memory_command_words_o;
    logic [1:0][3:0][1:0] reference_memory_command_mode_o;
    logic [1:0][3:0] reference_memory_write_valid_o;
    logic [1:0][3:0][91:0] reference_memory_write_data_o;
    logic [1:0][3:0] reference_memory_read_ready_o;
    logic [1:0][3:0] reference_memory_done_ready_o;
  process_dma_timing_reference reference_dut(
    .clk(clk),.rst(rst),.command_valid_i(command_valid_i),.command_ready_o(reference_command_ready_o),
    .command_op_i(command_op_i),.command_param_i(command_param_i),.command_kind_i(command_kind_i),
    .command_b_enable_i(command_b_enable_i),.command_b_compact_i(command_b_compact_i),
    .command_a_compact_i(command_a_compact_i),.command_pack_store_i(command_pack_store_i),.command_pack_op_i(command_pack_op_i),
    .command_hint_enable_i(command_hint_enable_i),.hint_valid_o(reference_hint_valid_o),.hint_ready_i(hint_ready_i),
    .hint_mask_o(reference_hint_mask_o),.hint_word_o(reference_hint_word_o),.hint_last_o(reference_hint_last_o),
    .packed_valid_o(reference_packed_valid_o),.packed_ready_i(packed_ready_i),.packed_data_o(reference_packed_data_o),.packed_index_o(reference_packed_index_o),.packed_last_o(reference_packed_last_o),
    .command_low_enable_i(command_low_enable_i),.command_pack_high_i(command_pack_high_i),
    .command_a_bank_i(command_a_bank_i),.command_b_bank_i(command_b_bank_i),
    .command_d_bank_i(command_d_bank_i),.command_h_bank_i(command_h_bank_i),
    .command_a_base_i(command_a_base_i),.command_b_base_i(command_b_base_i),
    .command_d_base_i(command_d_base_i),.command_h_base_i(command_h_base_i),
    .done_valid_o(reference_done_valid_o),.done_ready_i(done_ready_i),.done_code_o(reference_done_code_o),
    .done_reject_o(reference_done_reject_o),.done_hint_weight_o(reference_done_hint_weight_o),
    .memory_command_valid_o(reference_memory_command_valid_o),
    .memory_command_ready_i(dut_command_ready_o[0]),
    .memory_command_mask_o(reference_memory_command_mask_o),
    .memory_command_write_o(reference_memory_command_write_o),
    .memory_command_base_o(reference_memory_command_base_o),
    .memory_command_words_o(reference_memory_command_words_o),
    .memory_command_mode_o(reference_memory_command_mode_o),
    .memory_write_valid_o(reference_memory_write_valid_o),
    .memory_write_ready_i(dut_write_ready_o[0]),
    .memory_write_data_o(reference_memory_write_data_o),
    .memory_read_valid_i(dut_read_valid_o[0]),
    .memory_read_ready_o(reference_memory_read_ready_o),
    .memory_read_data_i(dut_read_data_o[0]),
    .memory_done_valid_i(dut_done_valid_o[0]),
    .memory_done_error_i(dut_done_error_o[0]),
    .memory_done_ready_o(reference_memory_done_ready_o));
    always @(posedge clk)if(!rst)begin
      if((command_ready_o) !== reference_command_ready_o ||
         (done_valid_o) !== reference_done_valid_o ||
         (done_code_o) !== reference_done_code_o ||
         (done_reject_o) !== reference_done_reject_o ||
         (done_hint_weight_o) !== reference_done_hint_weight_o ||
         (packed_valid_o) !== reference_packed_valid_o ||
         (packed_data_o) !== reference_packed_data_o ||
         (packed_index_o) !== reference_packed_index_o ||
         (packed_last_o) !== reference_packed_last_o ||
         (hint_valid_o) !== reference_hint_valid_o ||
         (hint_mask_o) !== reference_hint_mask_o ||
         (hint_word_o) !== reference_hint_word_o ||
         (hint_last_o) !== reference_hint_last_o ||
         (dut_command_valid_i[0]) !== reference_memory_command_valid_o ||
         (dut_command_mask_i[0]) !== reference_memory_command_mask_o ||
         (dut_command_write_i[0]) !== reference_memory_command_write_o ||
         (dut_command_base_i[0]) !== reference_memory_command_base_o ||
         (dut_command_words_i[0]) !== reference_memory_command_words_o ||
         (dut_command_mode_i[0]) !== reference_memory_command_mode_o ||
         (dut_write_valid_i[0]) !== reference_memory_write_valid_o ||
         (dut_write_data_i[0]) !== reference_memory_write_data_o ||
         (dut_read_ready_i[0]) !== reference_memory_read_ready_o ||
         (dut_done_ready_i[0]) !== reference_memory_done_ready_o)$fatal(1,"Process DMA timing rewrite changed an output/cycle");
      if({dut.low_sent_r,dut.high_sent_r,dut.hint_sent_r} !== {reference_dut.low_sent_r,reference_dut.high_sent_r,reference_dut.hint_sent_r})$fatal(1,"Process sink-credit invariant");
      checked_clocks++;
    end
    final $display("PROCESS_DMA_CYCLE_REFERENCE_PASS:%0d clocks/all connected outputs/three sink credits",checked_clocks);
  end endgenerate

  logic [91:0] data[1024],got[1024],gold[1024];
  int a[256],b[256],high[256],low[256];
  int cases_checked=0,coefficients=0,packed_words=0,reset_checks=0,negative_checks=0;
  int operand_refills=0,operand_consecutive=0,operand_held_checks=0,operand_reset_payloads=0;
  bit operand_held=0,operand_previous_take=0;
  logic [190:0] operand_snapshot;
  always @(posedge clk)begin
    if(rst)begin operand_held=0;operand_previous_take=0;end
    else begin
      if(operand_held)begin
        if(!dut.operand_valid_r || {dut.operand_a_r,dut.operand_b_r,dut.operand_tag_r}!==operand_snapshot)
          $fatal(1,"Registered Process operand changed while stalled");
        operand_held_checks++;
      end
      if(dut.operand_take && dut.operand_valid_r && dut.process_ready)operand_refills++;
      if(dut.operand_take && operand_previous_take)operand_consecutive++;
      operand_previous_take=dut.operand_take;
      operand_held=dut.operand_valid_r && !dut.process_ready;
      operand_snapshot={dut.operand_a_r,dut.operand_b_r,dut.operand_tag_r};
    end
  end
  int stream_words=0,expected_stream_words=0,cycles=0,hint_words=0,hints_checked=0;
  always @(negedge clk)begin cycles++;packed_ready_i=!rst && cycles%11>3;end
  assign hint_ready_i=!rst && cycles%13>4;
  always @(posedge clk)if(!rst && hint_valid_o && hint_ready_i)begin
    if(hint_word_o!=hint_words || hint_last_o!=(hint_words==63))$fatal(1,"Process MHint callback framing");
    for(int lane=0;lane<4;lane++)begin
      if(hint_mask_o[lane]!=1'(low[4*hint_words+lane]))$fatal(1,"Process MHint callback value");
      hints_checked++;
    end
    hint_words++;
  end
  always @(posedge clk)if(!rst && packed_valid_o && packed_ready_i)begin
    if(packed_index_o!=stream_words || packed_data_o!==gold[stream_words][63:0] ||
      packed_last_o!=(stream_words+1==expected_stream_words))$fatal(1,"Process shared pack stream mismatch");
    stream_words++;
  end
  bit reject_expected;int weight_expected;
  task automatic values(input int op,level,variant,input bit compact);
    int gamma,alpha,beta,bound,h,lo,word,bit_position,width,eta,gamma1,encoded;
    gamma=level==0?95232:261888;alpha=2*gamma;beta=level==0?78:level==1?196:120;
    reject_expected=0;weight_expected=0;eta=level==1?4:2;gamma1=level==0?131072:524288;
    for(int i=0;i<256;i++)begin
      a[i]=(i*7919+variant*37317)%8380417;b[i]=(i*3571+variant*791)%8380417;
      if(i<8)a[i]=i==0?0:i==1?8380416:i==2?gamma:i==3?8380417-gamma:i==4?4096:i==5?4097:i==6?gamma+1:8380416-gamma;
      if(compact)b[i]=((i+variant)%9-4+8380417)%8380417;
      if(op==5)b[i]=i%(level==0?44:16);
      if(op==6)b[i]=i%2;
      if(op==7)case(command_pack_op_i)
        0:a[i]=(i*37+variant)%1024;
        1:a[i]=((i*61+variant)%8192-4095+8380417)%8380417;
        2:a[i]=((i+variant)%(2*eta+1)-eta+8380417)%8380417;
        3:a[i]=(i+variant)%(level==0?44:16);
        4:a[i]=((i*7919+variant)%(2*gamma1)-gamma1+1+8380417)%8380417;
      endcase
      high[i]=0;low[i]=0;
      case(op)
        0:low[i]=(a[i]+b[i])%8380417;
        1:low[i]=(a[i]+8380417-b[i])%8380417;
        2:begin high[i]=(a[i]+4095)/8192;lo=a[i]-high[i]*8192;low[i]=(lo+8380417)%8380417;end
        3,6:begin
          h=(a[i]+gamma-1)/alpha;
          if(h==8380416/alpha)begin h=0;lo=a[i]-8380417;end else lo=a[i]-h*alpha;
          if(op==6)begin if(b[i])h=(h+(lo>0?1:-1)+8380416/alpha)%(8380416/alpha);low[i]=h;end
          else low[i]=(lo+8380417)%8380417;
          high[i]=h;
        end
        4:begin
          bound=command_kind_i==0?(level==0?131072:524288)-beta:command_kind_i==1?gamma-beta:gamma;
          reject_expected|=(a[i]>4190208?8380417-a[i]:a[i])>=bound;
        end
        5:begin
          lo=a[i]<=4190208?a[i]:a[i]-8380417;
          low[i]=lo>gamma || lo< -gamma || (lo== -gamma && b[i]!=0);
          weight_expected+=low[i];
        end
      endcase
    end
    for(int i=0;i<1024;i++)gold[i]=0;
    if(command_pack_high_i)begin
      width=op==7?(command_pack_op_i==0?10:command_pack_op_i==1?13:command_pack_op_i==2?(level==1?4:3):
        command_pack_op_i==3?(level==0?6:4):(level==0?18:20)):op==2?10:level==0?6:4;
      expected_stream_words=width*4;bit_position=0;
      for(int i=0;i<256;i++)for(int bit_index=0;bit_index<width;bit_index++)begin
        lo=a[i]<=4190208?a[i]:a[i]-8380417;
        encoded=op!=7?high[i]:(command_pack_op_i==0 || command_pack_op_i==3)?a[i]:
          command_pack_op_i==1?4096-lo:command_pack_op_i==2?eta-lo:gamma1-lo;
        gold[bit_position/64][bit_position%64]=encoded[bit_index];bit_position++;
      end
    end
  endtask
  task automatic prepare(input bit compact);
    if(command_a_compact_i)for(int w=0;w<16;w++)begin
      int index;data[w]=0;
      for(int lane=0;lane<16;lane++)begin
        index=128*(w/8)+8*(w%8)+(lane%8)+(lane>=8?64:0);
        data[w][4*lane+:4]=4'(a[index]>4?a[index]-8380417:a[index]);
      end
    end else for(int w=0;w<64;w++)for(int lane=0;lane<4;lane++)data[w][23*lane+:23]=23'(a[4*w+lane]);
    banks.write_bank(0,0,command_a_compact_i?16:64,data);
    if(command_b_enable_i)begin
      if(compact)for(int w=0;w<16;w++)begin
        int index;data[w]=0;
        for(int lane=0;lane<16;lane++)begin
          index=128*(w/8)+8*(w%8)+(lane%8)+(lane>=8?64:0);
          data[w][4*lane+:4]=4'(b[index]>4?b[index]-8380417:b[index]);
        end
      end
      else for(int w=0;w<64;w++)for(int lane=0;lane<4;lane++)data[w][23*lane+:23]=23'(b[4*w+lane]);
      banks.write_bank(2,0,compact?16:64,data);
    end
  endtask
  task automatic execute(input int expected_code=0,input bit abort_run=0);
    int watchdog;
    @(negedge clk);command_valid_i=1;stream_words=0;hint_words=0;
    #1;if(!command_ready_o)$fatal(1,"Process DMA not ready");
    @(negedge clk);command_valid_i=0;watchdog=0;
    while(!done_valid_o)begin
      @(negedge clk);
      if(abort_run && watchdog>=20 && dut.operand_valid_r)begin
        operand_reset_payloads++;rst=1;repeat(3)@(negedge clk);rst=0;reset_checks++;return;
      end
      if(watchdog++>2000)$fatal(1,"Process DMA timeout state%0d in%0d out%0d mask%h completed%h",dut.state,dut.consumed_r,dut.produced_r,dut.mask_r,dut.completed_r);
    end
    if(done_code_o!=expected_code)$fatal(1,"Process DMA code%0d expected%0d",done_code_o,expected_code);
    if(expected_code==0 && command_hint_enable_i && hint_words!=64)$fatal(1,"Missing Process MHint callbacks");
    if(expected_code==0 && command_pack_high_i && !command_pack_store_i && stream_words!=expected_stream_words)$fatal(1,"Missing shared pack output words");
    if(expected_code==0 && (done_reject_o!=reject_expected || done_hint_weight_o!=weight_expected))$fatal(1,"Process summary flags mismatch");
    repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=expected_code)$fatal(1,"Unstable Process DMA completion");end
    done_ready_i=1;@(negedge clk);done_ready_i=0;
  endtask
  task automatic verify_result;
    if(command_low_enable_i)begin
      banks.read_bank(0,0,64,got);
      for(int w=0;w<64;w++)for(int lane=0;lane<4;lane++)begin
        if(got[w][23*lane+:23]!==23'(low[4*w+lane]))$fatal(1,"Process DMA low mismatch op%0d level%0d index%0d got%0d want%0d",command_op_i,command_param_i,4*w+lane,got[w][23*lane+:23],low[4*w+lane]);
        coefficients++;
      end
    end
    if(command_pack_high_i && command_pack_store_i)begin
      int count;count=command_op_i==PROC_P2R?40:command_param_i==0?24:16;
      banks.read_bank(3,576,count,got);
      for(int w=0;w<count;w++)begin if(got[w]!==gold[w])$fatal(1,"Process packed-high mismatch op%0d level%0d word%0d",command_op_i,command_param_i,w);packed_words++;end
    end
    cases_checked++;
  endtask
  initial begin
    repeat(3)@(negedge clk);rst=0;
    for(int op=0;op<7;op++)for(int level=0;level<3;level++)for(int variant=0;variant<2;variant++)begin
      command_op_i=process_op_e'(op);command_param_i=2'(level);command_kind_i=2'(variant);
      command_b_enable_i=op==0 || op==1 || op==5 || op==6;command_b_compact_i=0;
      command_low_enable_i=op!=4;command_pack_high_i=op==2 || op==3 || op==6;command_hint_enable_i=op==5;
      values(op,level,variant,0);prepare(0);execute();verify_result();
    end
    for(int level=0;level<3;level++)begin
      command_op_i=PROC_ADD;command_param_i=2'(level);command_b_enable_i=1;command_b_compact_i=1;command_hint_enable_i=0;
      command_low_enable_i=1;command_pack_high_i=0;values(0,level,7,1);prepare(1);execute();verify_result();
      prepare(1);execute(0,1);prepare(1);execute();verify_result();
    end
    command_a_base_i=1;execute(1);negative_checks++;command_a_base_i=0;
    command_param_i=3;execute(1);negative_checks++;command_param_i=0;
    command_op_i=PROC_ADD;command_pack_high_i=1;execute(1);negative_checks++;command_pack_high_i=0;
    values(0,0,3,1);prepare(1);execute();verify_result();
    command_op_i=PROC_PACK;command_b_enable_i=0;command_b_compact_i=0;command_low_enable_i=0;
    command_pack_high_i=1;command_pack_store_i=0;
    for(int format=0;format<5;format++)for(int level=0;level<3;level++)begin
      command_param_i=2'(level);command_pack_op_i=3'(format);command_a_compact_i=format==2;
      values(7,level,19,0);prepare(0);execute();verify_result();
    end
    if(operand_refills==0 || operand_consecutive==0 || operand_held_checks==0 || operand_reset_payloads!=3)
      $fatal(1,"Missing registered-operand refill,II1,stall or occupied-reset scenario");
    $display("LIGHTHD_PROCESS_OPERAND_STAGE_PASS:refills%0d consecutive_accepts%0d stalled_checks%0d occupied_resets%0d;II1 transfers and payload/tag stability checked",operand_refills,operand_consecutive,operand_held_checks,operand_reset_payloads);
    $display("LIGHTHD_PROCESS_DMA_PASS:cases%0d coefficients%0d packed_words%0d negatives%0d reset_recoveries%0d;real bank reads/writes independent mathematical checks",cases_checked,coefficients,packed_words,negative_checks,reset_checks);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Process DMA global watchdog");end
endmodule

