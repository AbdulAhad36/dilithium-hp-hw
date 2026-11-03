`timescale 1ns/1ps
module tb_process_payload;
  import dilithium_pkg::*;
  parameter bit EXHAUSTIVE=1;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,input_valid_i,input_ready_o,output_valid_o,output_ready_i;
  process_op_e input_op_i,output_op_o;
  logic [1:0] input_param_i,input_kind_i;
  logic [7:0] input_tag_i,output_tag_o;
  logic [3:0][22:0] input_a_i,input_b_i,output_data_o;
  logic [3:0][9:0] output_high_o;
  logic [3:0] output_reject_o,output_hint_o;
  logic [2:0] output_weight_o;logic output_error_o;
  poly_process dut(.*);
  logic ref_ready,ref_valid,ref_error;
  process_op_e ref_op;logic [7:0] ref_tag;
  logic [3:0][22:0] ref_data;logic [3:0][9:0] ref_high;
  logic [3:0] ref_reject,ref_hint;logic [2:0] ref_weight;
  process_c17_reference reference_dut(.input_ready_o(ref_ready),.output_valid_o(ref_valid),
    .output_op_o(ref_op),.output_tag_o(ref_tag),.output_error_o(ref_error),
    .output_data_o(ref_data),.output_high_o(ref_high),.output_reject_o(ref_reject),
    .output_hint_o(ref_hint),.output_weight_o(ref_weight),.*);
  always @(posedge clk)if(!rst)begin
    if({input_ready_o,output_valid_o}!=={ref_ready,ref_valid})$fatal(1,"ALU probe handshake/latency mismatch");
    if(output_valid_o && {output_op_o,output_tag_o,output_error_o,output_data_o,output_high_o,output_reject_o,output_hint_o,output_weight_o}!==
       {ref_op,ref_tag,ref_error,ref_data,ref_high,ref_reject,ref_hint,ref_weight})$fatal(1,"ALU probe cycle/payload mismatch");
  end
  typedef struct packed {
    process_op_e op;logic [7:0] tag;logic error;
    logic [3:0][22:0] data;logic [3:0][9:0] high;
    logic [3:0] reject,hint;logic [2:0] weight;
  } result_t;
  result_t expected[$],held_value;
  bit held=0,gaps=0;int cycles=0,accepted=0,checked=0,errors_checked=0,stalls=0,tag=0;
  int decomp_coefficients=0;
  function automatic result_t reference_value;
    result_t r;int a,b,h,lo,gamma,alpha,beta,bound,magnitude;
    r='0;r.op=input_op_i;r.tag=input_tag_i;r.error=input_param_i==3;
    gamma=input_param_i==0?95232:261888;alpha=2*gamma;
    beta=input_param_i==0?78:input_param_i==1?196:120;
    for(int i=0;i<4;i++)begin
      a=int'(input_a_i[i]);b=int'(input_b_i[i]);r.error|=a>=8380417;
      case(input_op_i)
        PROC_ADD:begin r.error|=b>=8380417;r.data[i]=23'((a+b)%8380417);end
        PROC_SUB:begin r.error|=b>=8380417;r.data[i]=23'((a+8380417-b)%8380417);end
        PROC_P2R:begin
          h=(a+4095)/8192;lo=a-h*8192;r.high[i]=10'(h);r.data[i]=23'(lo<0?lo+8380417:lo);
        end
        PROC_DECOMPOSE,PROC_USEHINT:begin
          // Independent mathematical interval division,not the RTL's
          // reciprocal constants/shift-add implementation.
          h=(a+gamma-1)/alpha;
          if(h==8380416/alpha)begin h=0;lo=a-8380417;end
          else lo=a-h*alpha;
          if(input_op_i==PROC_USEHINT)begin
            r.error|=b>1;
            if(b==1)h=(h+(lo>0?1:-1)+8380416/alpha)%(8380416/alpha);
            r.data[i]=23'(h);
          end else r.data[i]=23'(lo<0?lo+8380417:lo);
          r.high[i]=10'(h);
        end
        PROC_CNB:begin
          bound=input_kind_i==0?(input_param_i==0?131072:524288)-beta:
            input_kind_i==1?gamma-beta:gamma;
          r.error|=input_kind_i==3;magnitude=a<=4190208?a:8380417-a;
          r.reject[i]=magnitude>=bound;
        end
        PROC_MHINT:begin
          r.error|=b>(input_param_i==0?43:15);lo=a<=4190208?a:a-8380417;
          r.hint[i]=lo>gamma || lo< -gamma || (lo== -gamma && b!=0);
          r.data[i]=23'(r.hint[i]);r.weight=r.weight+3'(r.hint[i]);
        end
        PROC_PACK:r.data[i]=23'(a);
        default:r.error=1;
      endcase
    end
    if(r.error)begin r.data=0;r.high=0;r.reject=0;r.hint=0;r.weight=0;end
    return r;
  endfunction
  function automatic result_t observed;
    return {output_op_o,output_tag_o,output_error_o,output_data_o,output_high_o,
      output_reject_o,output_hint_o,output_weight_o};
  endfunction
  always @(negedge clk)output_ready_i=rst?0:(!gaps || cycles%13>3);
  always @(posedge clk)begin
    result_t want;
    cycles++;
    if(rst)begin expected.delete();held=0;end
    else begin
      if(held)begin
        if(!output_valid_o || observed()!==held_value)$fatal(1,"Unstable x4 Process output");
        stalls++;
      end
      held=output_valid_o && !output_ready_i;held_value=observed();
      if(output_valid_o && output_ready_i)begin
        if(expected.size()==0)$fatal(1,"Unexpected Process output");
        want=expected.pop_front();
        if(observed()!==want)$fatal(1,"Process mismatch op%0d tag%0d got%h want%h",output_op_o,output_tag_o,observed(),want);
        checked++;if(want.error)errors_checked++;
      end
      if(input_valid_i && input_ready_o)begin
        want=reference_value();expected.push_back(want);accepted++;
        if(input_op_i==PROC_DECOMPOSE && !want.error)decomp_coefficients+=4;
      end
    end
  end
  task automatic send(input process_op_e op,input int level,kind,
                       input logic [3:0][22:0] a,b);
    @(negedge clk);input_valid_i=1;input_op_i=op;input_param_i=2'(level);input_kind_i=2'(kind);
    input_a_i=a;input_b_i=b;input_tag_i=8'(tag);tag++;
    @(posedge clk);while(!input_ready_o)@(posedge clk);
  endtask
  task automatic drain;
    int watchdog;@(negedge clk);input_valid_i=0;watchdog=0;
    while(expected.size()!=0 || output_valid_o)begin
      @(negedge clk);if(watchdog++>100)$fatal(1,"Process drain timeout");
    end
  endtask
  initial begin
    logic [3:0][22:0] a,b;int seed,gamma,bound;
    input_valid_i=0;input_op_i=PROC_ADD;input_param_i=0;input_kind_i=0;input_tag_i=0;
    input_a_i=0;input_b_i=0;output_ready_i=0;seed=20261025;void'($urandom(seed));
    repeat(3)@(negedge clk);rst=0;gaps=1;
    for(int level=0;level<3;level++)begin
      gamma=level==0?95232:261888;
      for(int h=0;h<(level==0?44:16);h++)for(int d=-2;d<=2;d++)begin
        for(int i=0;i<4;i++)begin a[i]=23'((2*gamma*h+gamma+d+i+8380417)%8380417);b[i]=23'(i%2);end
        send(PROC_DECOMPOSE,level,0,a,b);send(PROC_USEHINT,level,0,a,b);
      end
      for(int kind=0;kind<3;kind++)for(int d=-2;d<=2;d++)begin
        bound=kind==0?(level==0?131072-78:level==1?524288-196:524288-120):
          kind==1?gamma-(level==0?78:level==1?196:120):gamma;
        for(int i=0;i<4;i++)a[i]=23'(i[0]?8380417-bound-d:bound+d);
        send(PROC_CNB,level,kind,a,0);
      end
      for(int d=-2;d<=2;d++)begin
        for(int i=0;i<4;i++)begin a[i]=23'(i[0]?8380417-gamma-d:gamma+d);b[i]=23'(i%2);end
        send(PROC_MHINT,level,0,a,b);
      end
    end
    for(int n=0;n<5000;n++)begin
      for(int i=0;i<4;i++)begin a[i]=23'($urandom_range(8380416,0));b[i]=23'($urandom_range(8380416,0));end
      case(n%7)
        5:for(int i=0;i<4;i++)b[i]=23'($urandom_range(n%3==0?43:15,0));
        6:for(int i=0;i<4;i++)b[i]=23'(i%2);
        default:begin end
      endcase
      send(process_op_e'(n%7),n%3,(n/3)%3,a,b);
    end
    for(int op=0;op<8;op++)begin
      a='{default:23'd8380416};b='{default:23'd1};
      send(process_op_e'(op),3,0,a,b);
      a[2]=23'd8380417;send(process_op_e'(op),0,0,a,b);
    end
    a=0;b='{default:23'd2};send(PROC_USEHINT,0,0,a,b);
    b='{default:23'd64};send(PROC_MHINT,0,0,a,b);
    send(PROC_CNB,0,3,a,0);drain();
    // Reset with live pipeline words,then reuse tags and different data.
    repeat(3)send(PROC_ADD,0,0,92'd12,92'd7);
    @(negedge clk);rst=1;input_valid_i=0;repeat(3)@(negedge clk);rst=0;tag=0;
    send(PROC_SUB,2,0,92'd2,92'd17);drain();gaps=0;
    for(int total=0;total<=16760832;total+=4)begin
      for(int i=0;i<4;i++)begin
        int t;t=total+i<=16760832?total+i:16760832;
        a[i]=23'(t<8380417?t:8380416);b[i]=23'(t-int'(a[i]));
      end
      send(PROC_ADD,0,0,a,b);
    end
    drain();$display("PAYLOAD_REUSE_PROBE_SUM_DOMAIN_PASS:all16760833 canonical reachable sums");
    for(int diff=-8380416;diff<=8380416;diff+=4)begin
      for(int i=0;i<4;i++)begin
        int d;d=diff+i<=8380416?diff+i:8380416;
        a[i]=23'(d>=0?d:0);b[i]=23'(d<0?-d:0);
      end
      send(PROC_SUB,0,0,a,b);
    end
    drain();$display("PAYLOAD_REUSE_PROBE_DIFF_DOMAIN_PASS:all16760833 canonical reachable differences");
    for(int base=0;base<8388608;base+=4)begin
      for(int i=0;i<4;i++)a[i]=23'(base+i);
      send(PROC_P2R,0,0,a,0);
    end
    drain();$display("PAYLOAD_REUSE_PROBE_P2R_DOMAIN_PASS:all8388608 coefficient encodings");
    if(EXHAUSTIVE)for(int level=0;level<3;level++)begin
      for(int base=0;base<8380417;base+=4)begin
        for(int i=0;i<4;i++)a[i]=23'(base+i<8380417?base+i:8380416);
        send(PROC_DECOMPOSE,level,0,a,0);send(PROC_USEHINT,level,0,a,0);send(PROC_USEHINT,level,0,a,{4{23'd1}});
      end
      drain();$display("LIGHTHD_DECOMPOSE_CANONICAL_DOMAIN_PASS:level%0d all8380417 inputs/UseHint0/UseHint1",level);
    end
    if(stalls==0 || errors_checked==0)$fatal(1,"Missing Process stalls/invalid inputs");
    $display("PAYLOAD_REUSE_PROBE_PIPELINE_EQUIVALENCE_PASS:accepted%0d checked%0d invalid_words%0d stalled_checks%0d decomposed_coefficients%0d exhaustive%0d;interval-division oracle/reset checked",
      accepted,checked,errors_checked,stalls,decomp_coefficients,EXHAUSTIVE);
    $finish;
  end
  initial begin #1000000000;$fatal(1,"Global Process watchdog");end
endmodule
