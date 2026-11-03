`timescale 1ns/1ps
module tb_bram;
  logic clk=0,rst=1;
  always #5 clk=~clk;
  logic [1:0] valid,write_enable,ready,response_valid,response_write,response_ready;
  logic [1:0][9:0] address,response_address;
  logic [1:0][91:0] data,response_data;
  logic collision;
  poly_bram dut(.clk(clk),.rst(rst),
    .a_valid_i(valid[0]),.a_write_i(write_enable[0]),.a_address_i(address[0]),.a_data_i(data[0]),.a_ready_o(ready[0]),
    .a_response_valid_o(response_valid[0]),.a_response_write_o(response_write[0]),.a_response_address_o(response_address[0]),
    .a_response_data_o(response_data[0]),.a_response_ready_i(response_ready[0]),
    .b_valid_i(valid[1]),.b_write_i(write_enable[1]),.b_address_i(address[1]),.b_data_i(data[1]),.b_ready_o(ready[1]),
    .b_response_valid_o(response_valid[1]),.b_response_write_o(response_write[1]),.b_response_address_o(response_address[1]),
    .b_response_data_o(response_data[1]),.b_response_ready_i(response_ready[1]),.collision_o(collision));
  typedef struct packed {bit wr;bit [9:0] addr;bit [91:0] payload;} expected_t;
  expected_t qa[$],qb[$];bit [91:0] model[1024];
  int accepted=0,reads=0,writes=0,replies=0,collisions=0,resets=0,max_depth=0;
  bit [1:0] fire;
  task automatic check_head(input int p,ref expected_t q[$]);
    if(response_valid[p]!==1'(q.size()!=0))$fatal(1,"Response validity port%0d depth%0d",p,q.size());
    if(q.size())begin
      if(response_write[p]!==q[0].wr || response_address[p]!==q[0].addr)$fatal(1,"Response metadata port%0d",p);
      if(!q[0].wr && response_data[p]!==q[0].payload)$fatal(1,"Read data port%0d addr%0d",p,q[0].addr);
    end
  endtask
  task automatic push_request(input int p,ref expected_t q[$]);
    expected_t e;
    e.wr=write_enable[p];e.addr=address[p];e.payload=model[address[p]];q.push_back(e);
    if(write_enable[p])begin model[address[p]]=data[p];writes++;end else reads++;
    accepted++;if(q.size()>max_depth)max_depth=q.size();
    if(q.size()>2)$fatal(1,"Response FIFO overflow");
  endtask
  always @(posedge clk)begin
    expected_t discard;
    fire=valid & ready;
    if(rst)begin qa.delete();qb.delete();fire=0;end
    else begin
      check_head(0,qa);check_head(1,qb);
      if(response_valid[0] && response_ready[0])begin discard=qa.pop_front();replies++;end
      if(response_valid[1] && response_ready[1])begin discard=qb.pop_front();replies++;end
      if(fire[0])push_request(0,qa);if(fire[1])push_request(1,qb);
      if(collision)begin collisions++;if(fire==3)$fatal(1,"Write collision accepted");end
    end
    #1;if(!rst)begin check_head(0,qa);check_head(1,qb);end
  end
  initial begin
    int seed,unused;
    seed=20261026;unused=$urandom(seed);valid=0;write_enable=0;address=0;data=0;response_ready=3;
    repeat(3)@(negedge clk);rst=0;
    // Continuous one-request/port/clock initialization proves sustained rate.
    for(int i=0;i<512;i++)begin
      valid=3;write_enable=3;address[0]=10'(2*i);address[1]=10'(2*i+1);
      data[0]=92'(i)*92'h123456789abcdef;data[1]=~data[0];
      @(negedge clk);if(fire!=3)$fatal(1,"Continuous write throughput fell below two ports/clock");
    end
    for(int i=0;i<512;i++)begin
      write_enable=0;address[0]=10'(2*i);address[1]=10'(2*i+1);
      @(negedge clk);if(fire!=3)$fatal(1,"Continuous read throughput fell below two ports/clock");
    end
    for(int i=0;i<20000;i++)begin
      if(i inside {5000,10000,15000})begin
        rst=1;valid=0;repeat(2)@(negedge clk);rst=0;resets++;
      end
      for(int p=0;p<2;p++)begin
        if(fire[p] || !valid[p])begin
          valid[p]=$urandom_range(0,4)!=0;write_enable[p]=$urandom_range(0,1);
          address[p]=10'($urandom_range(0,31));data[p]={$urandom(),$urandom(),28'($urandom())};
        end
        response_ready[p]=(i%200>=40) && $urandom_range(0,3)!=0;
      end
      @(negedge clk);
    end
    valid=0;response_ready=3;repeat(5)@(negedge clk);
    if(qa.size() || qb.size() || max_depth!=2 || reads<1000 || collisions<1 || resets!=3)$fatal(1,"Missing response/coverage witness");
    $display("BRAM_FIFO_PASS:accepted%0d reads%0d writes%0d replies%0d collisions%0d resets%0d depth%0d;two continuous ports/clock",accepted,reads,writes,replies,collisions,resets,max_depth);
    $finish;
  end
  initial begin #1000000;$fatal(1,"RAM probe timeout");end
endmodule
