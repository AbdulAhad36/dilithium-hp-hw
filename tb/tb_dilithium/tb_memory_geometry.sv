`timescale 1ns/1ps
// Exhaustive command-admission equivalence against the frozen C7 expression.
// No RAM payloads or protocol timing are replaced by this arithmetic gate.
module tb_memory_geometry;
  logic clk=0,rst=1;
  logic [3:0] command_mask_i,command_write_i;
  logic [3:0][9:0] command_base_i;
  logic [3:0][10:0] command_words_i;
  logic [3:0][1:0] command_mode_i;
  int checked=0;
  memory_port dut(
    .clk(clk),.rst(rst),.command_valid_i(1'b0),
    .command_mask_i(command_mask_i),.command_write_i(command_write_i),
    .command_base_i(command_base_i),.command_words_i(command_words_i),.command_mode_i(command_mode_i),
    .write_valid_i(4'b0),.write_data_i(368'b0),.write_address_i(40'b0),
    .read_ready_i(4'b0),.done_ready_i(4'b0),.request_ready_i(4'b0),
    .response_valid_i(4'b0),.response_write_i(4'b0),
    .response_address_i(40'b0),.response_data_i(368'b0));
  function automatic logic [11:0] old_offset(input logic [10:0] index,input logic [1:0] mode);
    case(mode)
      1:return {index,1'b0};
      2:return {9'd0,index[3:1]};
      3:return {8'd0,index[5],index[3:1]};
      default:return {1'b0,index};
    endcase
  endfunction
  function automatic bit old_bad();
    logic bad;
    bad=command_mask_i==0 || (command_write_i & ~command_mask_i)!=0;
    for(int b=0;b<4;b++)if(command_mask_i[b])
      bad|=command_words_i[b]==0 || command_words_i[b]>1024 ||
        (command_mode_i[b]==2 && !command_write_i[b] && command_words_i[b]!=32) ||
        (command_mode_i[b]==3 && command_words_i[b]!=64) ||
        (!(command_mode_i[b]==2 && command_write_i[b]) && ({2'b0,command_base_i[b]}+
         (command_mode_i[b]==2?12'd7:command_mode_i[b]==3?12'd15:
          old_offset(command_words_i[b]-11'd1,command_mode_i[b]))+12'd1)>12'd1024);
    return bad;
  endfunction
  task automatic check();
    logic bad;
    #0.001;
    bad=command_mask_i==0 || (command_write_i & ~command_mask_i)!=0;
    for(int b=0;b<4;b++)if(command_mask_i[b])
      bad|=dut.bank_bad(command_base_i[b],command_words_i[b],command_mode_i[b],command_write_i[b]);
    if(bad!==old_bad())
      $fatal(1,"Geometry mismatch mask%h write%h base%h words%h mode%h",
        command_mask_i,command_write_i,command_base_i,command_words_i,command_mode_i);
    checked++;
  endtask
  initial begin
    command_mask_i=1;command_write_i=0;command_base_i=0;command_words_i='1;command_mode_i=0;
    #1;clk=1;#1;clk=0;rst=0;
    // Every encoded base/count/mode/direction, including zero and oversize.
    for(int mode=0;mode<4;mode++)for(int wr=0;wr<2;wr++)begin
      command_mode_i[0]=2'(mode);command_write_i=4'(wr);
      for(int base=0;base<1024;base++)for(int words=0;words<2048;words++)begin
        command_base_i[0]=10'(base);command_words_i[0]=11'(words);check();
      end
      $display("GEOMETRY_PROGRESS mode%0d write%0d checked%0d",mode,wr,checked);
    end
    // All bank/write masks with different per-bank geometries; check the
    // all-bank rejection OR as well as ignored fields on unselected banks.
    for(int trial=0;trial<256;trial++)begin
      for(int b=0;b<4;b++)begin
        command_base_i[b]=10'((trial*37+b*127)%1024);
        command_words_i[b]=11'((trial*31+b*257)%2048);
        command_mode_i[b]=2'((trial+b)%4);
      end
      for(int mask=0;mask<16;mask++)for(int wr=0;wr<16;wr++)begin
        command_mask_i=4'(mask);command_write_i=4'(wr);check();
      end
    end
    if(checked!=16842752)$fatal(1,"Incomplete exhaustive geometry gate");
    $display("LIGHTHD_MEMORY_GEOMETRY_PASS:%0d exact C7 command-admission comparisons",checked);
    $finish;
  end
endmodule
