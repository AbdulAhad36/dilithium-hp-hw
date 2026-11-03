`timescale 1ns/1ps
module tb_bank_pipe;
 logic clk=0;always #5 clk=~clk;
 logic rst=1;
 logic [1:0] input_valid_i=0,input_write_i=0,input_ready_o;
 logic [1:0][9:0] input_address_i=0;
 logic [1:0][91:0] input_data_i=0;
 logic [1:0] output_valid_o,output_write_o,output_ready_i;
 logic [1:0][9:0] output_address_o,response_address;
 logic [1:0][91:0] output_data_o,response_data;
 logic [1:0] response_valid,response_write,response_ready=3;
 logic collision;
 bank_request_pipe dut(.*);
 poly_bram ram(.clk(clk),.rst(rst),
  .a_valid_i(output_valid_o[0]),.a_write_i(output_write_o[0]),.a_address_i(output_address_o[0]),.a_data_i(output_data_o[0]),.a_ready_o(output_ready_i[0]),
  .a_response_valid_o(response_valid[0]),.a_response_write_o(response_write[0]),.a_response_address_o(response_address[0]),.a_response_data_o(response_data[0]),.a_response_ready_i(response_ready[0]),
  .b_valid_i(output_valid_o[1]),.b_write_i(output_write_o[1]),.b_address_i(output_address_o[1]),.b_data_i(output_data_o[1]),.b_ready_o(output_ready_i[1]),
  .b_response_valid_o(response_valid[1]),.b_response_write_o(response_write[1]),.b_response_address_o(response_address[1]),.b_response_data_o(response_data[1]),.b_response_ready_i(response_ready[1]),.collision_o(collision));
 typedef struct packed {bit write;bit [9:0] address;bit [91:0] data;int age;} item_t;
 item_t pending_a[$],pending_b[$],expected_a[$],expected_b[$];
 bit [91:0] logical_model[1024],physical_model[1024];
 bit [1:0] admitted,committed;
 int ages=0,accepted=0,issued=0,reads=0,writes=0,replies=0,age_checks=0;
 int full_clocks=0,renewals=0,bypass=0,resets=0,reset_pending=0,reset_read_phases=0;
 task automatic issue(input int p,ref item_t own[$],ref item_t other[$]);
  item_t e;
  if(own.size()==0)$fatal(1,"RAM issued an unaccepted request");
  e=own[0];
  if({output_write_o[p],output_address_o[p],output_data_o[p]}!=={e.write,e.address,e.data})$fatal(1,"Queue reordered/corrupted request");
  foreach(other[j])begin
   if(other[j].age<e.age && other[j].address==e.address && (other[j].write || e.write))$fatal(1,"Younger conflicting request overtook older request");
   age_checks++;
  end
  e=own.pop_front();issued++;
  if(e.write)physical_model[e.address]=e.data;
 endtask
 task automatic accept(input int p,ref item_t pending[$],ref item_t expected[$]);
  item_t e,reply;
  e.write=input_write_i[p];e.address=input_address_i[p];e.data=input_data_i[p];e.age=ages++;
  pending.push_back(e);reply=e;
  if(e.write)begin logical_model[e.address]=e.data;writes++;end
  else begin reply.data=logical_model[e.address];reads++;end
  expected.push_back(reply);accepted++;
  if(pending.size()>2 || expected.size()>4)$fatal(1,"Exceeded bounded physical-port storage");
 endtask
 task automatic reply(input int p,ref item_t expected[$]);
  item_t e;
  if(response_valid[p])begin
   if(expected.size()==0)$fatal(1,"Unowned RAM response");
   e=expected[0];
   if({response_write[p],response_address[p]}!=={e.write,e.address})$fatal(1,"Response order/metadata");
   if(!e.write && response_data[p]!==e.data)$fatal(1,"Read differs from acceptance-ordered independent memory model");
   if(response_ready[p])begin e=expected.pop_front();replies++;end
  end
 endtask
 always @(posedge clk)begin
  admitted=input_valid_i & input_ready_o;committed=output_valid_o & output_ready_i;
  if(rst)begin
   pending_a.delete();pending_b.delete();expected_a.delete();expected_b.delete();admitted=0;committed=0;
   for(int a=0;a<1024;a++)logical_model[a]=physical_model[a];
  end else begin
   reply(0,expected_a);reply(1,expected_b);
   if(committed[0])issue(0,pending_a,pending_b);
   if(committed[1])issue(1,pending_b,pending_a);
   // Same-edge source acceptance order is A then B,independent of the DUT's age bits.
   if(admitted[0])accept(0,pending_a,expected_a);
   if(admitted[1])accept(1,pending_b,expected_b);
   if(dut.count_r[0]==2 || dut.count_r[1]==2)full_clocks++;
   if((|(admitted & committed)))renewals++;
   if(committed[1] && dut.count_r[0]==2 && response_valid[0] && !response_ready[0])bypass++;
   if(collision)$fatal(1,"Queue ordering failed to serialize conflicting heads");
  end
 end
 task automatic occupied_reset(input bit phase);
  int wait_count;
  input_valid_i=0;response_ready=3;wait_count=0;
  while(expected_a.size() || expected_b.size())begin
   @(negedge clk);if(wait_count++>1000)$fatal(1,"Pre-reset drain stalled");
  end
  if(dut.read_r[0]!=phase)begin
   input_valid_i=1;input_write_i=1;input_address_i[0]=10;input_data_i[0]=92'(accepted);
   do @(negedge clk);while(!admitted[0]);input_valid_i=0;
   while(expected_a.size())@(negedge clk);
  end
  input_valid_i=3;input_write_i=3;response_ready=0;
  for(int n=0;n<14;n++)begin
   for(int p=0;p<2;p++)if(admitted[p] || n==0)begin
    input_address_i[p]=10'(10+p);input_data_i[p]=92'(accepted+p);
   end
   @(negedge clk);
  end
  if(dut.count_r[0]!=2 || dut.count_r[1]!=2 || dut.read_r[0]!=phase)$fatal(1,"Reset did not cover full queue/pointer phase");
  reset_pending+=pending_a.size()+pending_b.size();reset_read_phases|=1<<dut.read_r[0];
  rst=1;input_valid_i=0;repeat(3)@(negedge clk);rst=0;resets++;
 endtask
 initial begin
  int seed,unused,watchdog;
  seed=20261029;unused=$urandom(seed);
  for(int a=0;a<1024;a++)begin logical_model[a]=0;physical_model[a]=0;end
  repeat(3)@(negedge clk);rst=0;
  // Real RAM,all initialized addresses,continuous dual-port II1 at both boundaries.
  for(int n=0;n<256;n++)begin
   input_valid_i=3;input_write_i=n<128?3:0;response_ready=3;
   input_address_i[0]=10'(2*(n%32));input_address_i[1]=10'(2*(n%32)+1);
   input_data_i[0]=92'(n)*92'h123456789ab;input_data_i[1]=~input_data_i[0];
   @(negedge clk);
   if(admitted!=3 || (n>=3 && committed!=3))$fatal(1,"Dual-port continuous rate below II1");
  end
  input_valid_i=0;repeat(8)@(negedge clk);
  for(int n=0;n<20000;n++)begin
   if(n inside {1000,7000,14000})occupied_reset(n==7000);
   for(int p=0;p<2;p++)begin
    if(admitted[p] || !input_valid_i[p])begin
     input_valid_i[p]=$urandom_range(0,4)!=0;input_write_i[p]=$urandom_range(0,1);
     input_address_i[p]=10'($urandom_range(0,63));input_data_i[p]={$urandom(),$urandom(),28'($urandom())};
    end
    response_ready[p]=(n%200>=40) && $urandom_range(0,3)!=0;
   end
   if(n%500<70)response_ready[0]=0;
   @(negedge clk);
  end
  input_valid_i=0;response_ready=3;watchdog=0;
  while(expected_a.size() || expected_b.size())begin @(negedge clk);if(watchdog++>1000)$fatal(1,"Failed to drain after backpressure release");end
  if(full_clocks==0 || renewals==0 || bypass==0 || reset_pending!=12 || resets!=3 || reset_read_phases!=3 || reads<1000 || age_checks==0)$fatal(1,"Missing request-pipeline pressure scenario");
  $display("LIGHTHD_BANK_PIPE_PASS:%0d accepted/%0d issued/%0d replies/%0d reads/%0d writes/%0d age checks/%0d full clocks/%0d renewals/%0d independent bypasses/%0d resets/%0d discarded pending/reset phases%0d;real RAM/acceptance-ordered model/dual-port II1",accepted,issued,replies,reads,writes,age_checks,full_clocks,renewals,bypass,resets,reset_pending,reset_read_phases);
  $finish;
 end
 initial begin #1000000;$fatal(1,"Bank-pipe watchdog");end
endmodule
