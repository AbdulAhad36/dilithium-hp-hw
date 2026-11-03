`timescale 1ns/1ps
module tb_butterfly_fused;
  import ntt_pkg::*;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,valid=0;
  bf_mode_e mode=BF_CT;
  logic [22:0] a=0,b=0,z=0,x,y,old_x,old_y,published_a,published_b;
  logic [46:0] product=0;logic [22:0] residue;
  logic [6:0] bv=0;logic [2:0] rv=0;
  logic [22:0] ex[7],ey[7],er[3];
  bf_mode_e expected_mode[7];
  longint unsigned rng=64'h6d4a72213ea90bcd;
  int butterflies=0,reductions=0,resets=0,wide_gs=0;
  butterfly_fused #(.PUBLISHED_ORDER(0)) dut(.clk(clk),.rst(rst),.mode_i(mode),.a_i(a),.b_i(b),.zeta_i(z),.a_o(x),.b_o(y));
  butterfly_fused #(.PUBLISHED_ORDER(1)) published(.clk(clk),.rst(rst),.mode_i(mode),.a_i(a),.b_i(b),.zeta_i(z),.a_o(published_a),.b_o(published_b));
  butterfly_unit_c11_reference reference(.clk(clk),.rst(rst),.mode_i(mode),.a_i(a),.b_i(b),.zeta_i(z),.a_o(old_x),.b_o(old_y));
  butterfly_reduce direct(.clk(clk),.rst(rst),.product_i(product),.result_o(residue));
  function automatic longint unsigned random64();
    rng=rng^(rng<<13);rng=rng^(rng>>7);rng=rng^(rng<<17);return rng;
  endfunction
  always @(posedge clk)begin
    longint unsigned aa,bb,zz,p;
    if(rst)begin bv<=0;rv<=0;end
    else begin
      bv<={bv[5:0],valid};rv<={rv[1:0],valid};
      expected_mode[0]<=mode;
      for(int i=1;i<7;i++)begin ex[i]<=ex[i-1];ey[i]<=ey[i-1];expected_mode[i]<=expected_mode[i-1];end
      for(int i=1;i<3;i++)er[i]<=er[i-1];
      aa=64'(a);bb=64'(b);zz=64'(z);
      if(mode==BF_CT)begin
        ex[0]<=23'((aa+bb*zz)%Q);ey[0]<=23'((aa+Q-(bb*zz)%Q)%Q);
      end else begin
        p=(aa+Q-bb)*zz;
        ex[0]<=23'((aa+bb)%Q);ey[0]<=23'(p%Q);
        if(valid && p>=(64'd1<<46))wide_gs++;
      end
      er[0]<=23'(64'(product)%Q);
    end
  end
  always @(negedge clk)begin
    if(rst)begin
      if(x!==0 || y!==0 || residue!==0)$fatal(1,"Reset outputs not zero");
    end else begin
      if(bv[6])begin
        if(x!==ex[6] || y!==ey[6])$fatal(1,"Fused arithmetic/7cycle alignment got%0d/%0d expected%0d/%0d",x,y,ex[6],ey[6]);
        if(x!==old_x || y!==old_y)$fatal(1,"C11 butterfly pin mismatch");
        if(published_a!==(expected_mode[6]==BF_GS?ey[6]:ex[6]) ||
          published_b!==(expected_mode[6]==BF_GS?ex[6]:ey[6]))$fatal(1,"Published output ordering mismatch");
        if(x>=Q || y>=Q)$fatal(1,"Noncanonical butterfly output");
        butterflies++;
      end
      if(rv[2])begin
        if(residue!==er[2])$fatal(1,"47bit reduction mismatch got%0d expected%0d",residue,er[2]);
        reductions++;
      end
      if(bv[2] && dut.product_full[63:47]!=0)$fatal(1,"Truncated high DSP carry");
    end
  end
  initial begin
    longint unsigned sample;
    repeat(3)@(negedge clk);#1;rst=0;
    for(int i=0;i<262144;i++)begin
      @(negedge clk);#1;
      if(i!=0 && i%8192==0)begin
        rst=1;valid=0;resets++;repeat(2)@(negedge clk);#1;rst=0;
      end
      valid=i%19!=0;
      mode=bf_mode_e'(i[0]);a=23'(random64()%Q);b=23'(random64()%Q);z=23'(random64()%Q);
      case(i%64)
        0:begin a=0;b=0;z=0;end
        1:begin a=Q-1;b=0;z=Q-1;end
        2:begin a=0;b=Q-1;z=Q-1;end
        3:begin a=Q-1;b=Q-1;z=Q-1;end
        4:begin a=Q-1;b=1;z=1;end
        5:begin a=b;z=1753;end
        6:z=0;
        7:z=1;
        default:begin end
      endcase
      product=47'(random64());
      case(i%32)
        0:product=0;
        1:product=47'(Q);
        2:product=47'(64'(Q)*64'(Q)-1);
        3:product='1;
        4:product=47'd1<<46;
        5:product=(47'd1<<46)-1;
        6:product=47'(64'(Q)*64'(2*Q-1));
        default:begin end
      endcase
      if(i%65536==0)$display("FUSED_BF_PROGRESS:%0d",i);
    end
    @(negedge clk);#1;valid=0;a=0;b=0;z=0;product=0;
    repeat(10)@(negedge clk);
    if(butterflies<240000 || reductions<240000 || wide_gs<10000 || resets!=31)$fatal(1,"Incomplete fused arithmetic campaign");
    $display("LIGHTHD_FUSED_BF_PASS:butterflies%0d reductions%0d resets%0d GS47bitproducts%0d;independent integer math+C11 pin equivalence/II1/7cycles",butterflies,reductions,resets,wide_gs);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Fused BF watchdog");end
endmodule
