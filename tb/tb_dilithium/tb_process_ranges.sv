`timescale 1ns/1ps
module tb_process_ranges;
  logic [1:0] level,kind;logic [3:0][22:0] data;
  logic [3:0][5:0] high0=0,high1;
  wire [3:0] norm_old,norm_new,hint0_old,hint0_new,hint1_old,hint1_new;
  wire norm_error_old,norm_error_new,e0_old,e0_new,e1_old,e1_new;
  wire [2:0] c0_old,c0_new,c1_old,c1_new;
  cnb_c15_reference old_norm(.param_i(level),.kind_i(kind),.data_i(data),.reject_o(norm_old),.error_o(norm_error_old));
  cnb new_norm(.param_i(level),.kind_i(kind),.data_i(data),.reject_o(norm_new),.error_o(norm_error_new));
  mhint_c15_reference old_hint0(.param_i(level),.low_i(data),.high_i(high0),.hint_o(hint0_old),.count_o(c0_old),.error_o(e0_old));
  mhint new_hint0(.param_i(level),.low_i(data),.high_i(high0),.hint_o(hint0_new),.count_o(c0_new),.error_o(e0_new));
  mhint_c15_reference old_hint1(.param_i(level),.low_i(data),.high_i(high1),.hint_o(hint1_old),.count_o(c1_old),.error_o(e1_old));
  mhint new_hint1(.param_i(level),.low_i(data),.high_i(high1),.hint_o(hint1_new),.count_o(c1_new),.error_o(e1_new));
  int norm_checks=0,hint_checks=0;
  task automatic check;
    if({norm_new,norm_error_new}!=={norm_old,norm_error_old})$fatal(1,"Norm mismatch:level%0d kind%0d data%h old%h new%h",level,kind,data,{norm_old,norm_error_old},{norm_new,norm_error_new});
    if({hint0_new,c0_new,e0_new,hint1_new,c1_new,e1_new}!=={hint0_old,c0_old,e0_old,hint1_old,c1_old,e1_old})$fatal(1,"Hint mismatch:level%0d data%h",level,data);
  endtask
  initial begin
    level=0;kind=0;data=0;high1={6'd63,6'd44,6'd16,6'd1};
    for(int p=0;p<4;p++)begin
      level=2'(p);
      for(int base=0;base<8388608;base+=4)begin
        for(int lane=0;lane<4;lane++)data[lane]=23'(base+lane);
        for(int k=0;k<4;k++)begin
          kind=2'(k);#1;check();norm_checks+=4;if(k==0)hint_checks+=8;
        end
      end
      $display("LIGHTHD_PROCESS_RANGE_DOMAIN_PASS:level%0d all8388608 encodings/all4 norm kinds/zero and nonzero hint high",p);
    end
    // Every high encoding at exact threshold/bad-value boundaries.
    for(int p=0;p<4;p++)for(int h=0;h<64;h++)for(int n=0;n<12;n++)begin
      level=2'(p);kind=2'(n%4);high1='{default:6'(h)};
      for(int lane=0;lane<4;lane++)case(n)
        0:data[lane]=0;1:data[lane]=23'd95232+23'(lane)-1;
        2:data[lane]=23'd8285185+23'(lane)-1;3:data[lane]=23'd261888+23'(lane)-1;
        4:data[lane]=23'd8118529+23'(lane)-1;5:data[lane]=23'd4190208+23'(lane)-1;
        6:data[lane]=23'd8380417+23'(lane)-1;7:data[lane]=23'd8388607-23'(lane);
        default:data[lane]=23'(n*170011+lane);
      endcase
      #1;check();
    end
    $display("LIGHTHD_PROCESS_RANGE_EXHAUSTIVE_PASS:norm%0d/hint%0d coefficient comparisons;all23-bit values including8191noncanonical encodings;all high values at boundaries",norm_checks,hint_checks);
    $finish;
  end
endmodule
