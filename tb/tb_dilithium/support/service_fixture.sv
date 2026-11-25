// Verification host for the ACTUAL shared datapath. It adds no DUT bank,
// writer,codec or engine. Controller clients and explicit host memory reads
// traverse the same production command boundary.
`timescale 1ns/1ps
module service_fixture (
  input logic clk,rst,input var dilithium_pkg::request_t request_i,
  output dilithium_pkg::response_t response_o,output logic fault_o
);
  import dilithium_pkg::*;
  request_t service_i;response_t service_o;
  bank_request_t host_request;
  logic host_active=0;
  always_comb begin service_i=request_i;if(host_active)service_i.bank=host_request;end
  assign response_o=service_o;
  datapath datapath(.*);
  task automatic begin_burst(input int bank,base,n,input bit writing);
    int watchdog;
    @(negedge clk);host_active=1;host_request='0;
    host_request.mask[0]=4'b1<<bank;host_request.write[0]=writing?(4'b1<<bank):0;
    host_request.base[0][bank]=10'(base);host_request.words[0][bank]=11'(n);
    host_request.command_valid[0]=1;watchdog=0;
    @(posedge clk);while(!service_o.bank.command_ready[0])begin
      @(posedge clk);if(watchdog++>2000)$fatal(1,"Shared-service fixture reservation timeout");
    end
    @(negedge clk);host_request.command_valid[0]=0;
  endtask
  task automatic end_burst(input int bank);
    int watchdog;watchdog=0;
    while(!service_o.bank.done_valid[0][bank])begin
      @(negedge clk);if(watchdog++>2000)$fatal(1,"Shared-service fixture completion timeout");
    end
    if(service_o.bank.done_error[0][bank])$fatal(1,"Shared-service fixture burst error");
    host_request.done_ready[0][bank]=1;@(negedge clk);host_request='0;host_active=0;
  endtask
  task automatic write_bank(input int bank,base,n,input logic [91:0] values[1024]);
    int watchdog;begin_burst(bank,base,n,1);
    for(int w=0;w<n;w++)begin
      host_request.write_valid[0][bank]=1;host_request.write_data[0][bank]=values[w];watchdog=0;
      @(posedge clk);while(!service_o.bank.write_ready[0][bank])begin
        @(posedge clk);if(watchdog++>2000)$fatal(1,"Shared-service fixture write timeout");
      end
      @(negedge clk);
    end
    host_request.write_valid[0][bank]=0;end_burst(bank);
  endtask
  task automatic read_bank(input int bank,base,n,output logic [91:0] values[1024]);
    int watchdog,w;
    begin_burst(bank,base,n,0);w=0;watchdog=0;
    while(w<n)begin
      host_request.read_ready[0][bank]=watchdog%7>1;
      @(posedge clk);
      if(service_o.bank.read_valid[0][bank] && host_request.read_ready[0][bank])begin
        if(service_o.bank.read_address[0][bank]!=base+w || service_o.bank.read_last[0][bank]!=(w+1==n))
          $fatal(1,"Shared-service fixture read framing");
        values[w]=service_o.bank.read_data[0][bank];w++;
      end
      @(negedge clk);if(watchdog++>20000)$fatal(1,"Shared-service fixture read timeout");
    end
    host_request.read_ready[0][bank]=0;end_burst(bank);
  endtask
  initial host_request='0;
  always @(posedge clk)if(!rst && host_active && |request_i.bank.command_valid)
    $fatal(1,"Verification host conflicts with controller manual-memory request");
endmodule
