`timescale 1ns/1ps
module tb_ntt_decoders;
  import ntt_pkg::*;
  logic forced_clk=0;
  ntt_op_e forced_op;
  logic [7:0] forced_tick;
  logic [12*COEFF_W-1:0] words;
  logic [11:0] mask;
  logic [2:0] code;
  logic [COEFF_W-1:0] expected,actual;
  int checked=0;
  ntt_core #(.BANK_IO(1)) dut(.clk(forced_clk),.rst(1'b1),
    .start_i(1'b0),.op_i(OP_NTT),.wr_en_i(1'b0),.wr_b_sel_i(1'b0),
    .wr_addr_i('0),.wr_data_i('0),.rd_en_i(1'b0),.rd_addr_i('0),
    .bank_load_valid_i(1'b0),.bank_load_index_i('0),
    .bank_load_a_i('0),.bank_load_b_i('0),.bank_pwm_valid_i(1'b0),
    .bank_pwm_a_i('0),.bank_pwm_b_i('0),.bank_pwm_c_i('0),
    .bank_pwm_accumulate_i(1'b0));
  initial begin
    force dut.state=dut.RUN;
    force dut.op_r=forced_op;
    force dut.tick=forced_tick;
    // All SG operation/tick combinations, including unused PWM ticks.
    // Distinct source labels plus every data-bit basis exercise actual
    // RTL encoder and fixed-slice mux against the pre-encoding masks.
    for(int op=0;op<4;op++)begin
      forced_op=ntt_op_e'(op);
      for(int t=0;t<256;t++)begin
        forced_tick=8'(t);
        #1;
        for(int basis=0;basis<=COEFF_W;basis++)begin
          for(int k=0;k<12;k++)
            words[k*COEFF_W+:COEFF_W]=basis==COEFF_W?COEFF_W'(k+1):
              (COEFF_W'(1)<<basis) ^ COEFF_W'(k+1);
          for(int side=0;side<2;side++)begin
            for(int lane=0;lane<4;lane++)begin
              mask=side?dut.operand_b_sel[lane]:dut.operand_a_sel[lane];
              if($isunknown(mask)||$countones(mask)>1)
                $fatal(1,"Invalid source mask:op%0d tick%0d side%0d lane%0d",op,t,side,lane);
              expected=0;
              for(int k=0;k<12;k++)
                if(mask[k])expected|=words[k*COEFF_W+:COEFF_W];
              code=dut.bu_encode(mask,1'(side),2'(lane));
              actual=dut.bu_select(code,1'(side),2'(lane),words);
              if(actual!==expected)
                $fatal(1,"Decoder mismatch:op%0d tick%0d side%0d lane%0d code%0d mask%h got%h expected%h",op,t,side,lane,code,mask,actual,expected);
              checked++;
            end
          end
        end
      end
    end
    $display("LIGHTHD_NTT_DECODER_PASS:%0d selections/all4 operations/256ticks/24 data patterns",checked);
    $finish;
  end
endmodule
