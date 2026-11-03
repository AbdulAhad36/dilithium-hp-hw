// Reusable integration fixture:two real clients plus a verification-only host.
// All transfers traverse the production router,port FSMs and physical banks.
`timescale 1ns/1ps
module bank_fixture (
  input logic clk,rst,
  input logic [1:0][1:0] dut_command_valid_i,
  output logic [1:0][1:0] dut_command_ready_o,
  input logic [1:0][1:0][3:0] dut_command_mask_i,dut_command_write_i,
  input logic [1:0][1:0][3:0][9:0] dut_command_base_i,
  input logic [1:0][1:0][3:0][10:0] dut_command_words_i,
  input logic [1:0][1:0][3:0][1:0] dut_command_mode_i,
  input logic [1:0][1:0][3:0] dut_write_valid_i,
  output logic [1:0][1:0][3:0] dut_write_ready_o,
  input logic [1:0][1:0][3:0][91:0] dut_write_data_i,
  input logic [1:0][1:0][3:0][9:0] dut_write_address_i,
  output logic [1:0][1:0][3:0] dut_read_valid_o,
  input logic [1:0][1:0][3:0] dut_read_ready_i,
  output logic [1:0][1:0][3:0][91:0] dut_read_data_o,
  output logic [1:0][1:0][3:0][9:0] dut_read_address_o,
  output logic [1:0][1:0][3:0] dut_read_last_o,dut_done_valid_o,dut_done_error_o,
  input logic [1:0][1:0][3:0] dut_done_ready_i
);
  logic [2:0][1:0] client_command_valid_i,client_command_ready_o;
  logic [2:0][1:0][3:0] client_command_mask_i,client_command_write_i,client_write_valid_i,client_write_ready_o;
  logic [2:0][1:0][3:0][9:0] client_command_base_i,client_read_address_o;
  logic [2:0][1:0][3:0][10:0] client_command_words_i;
  logic [2:0][1:0][3:0][1:0] client_command_mode_i;
  logic [2:0][1:0][3:0][91:0] client_write_data_i,client_read_data_o;
  logic [2:0][1:0][3:0][9:0] client_write_address_i;
  logic [2:0][1:0][3:0] client_read_valid_o,client_read_ready_i,client_read_last_o;
  logic [2:0][1:0][3:0] client_done_valid_o,client_done_error_o,client_done_ready_i;
  logic [3:0] collision_o;logic idle_o;
  assign client_command_valid_i[1:0]=dut_command_valid_i;
  assign client_command_mask_i[1:0]=dut_command_mask_i;
  assign client_command_write_i[1:0]=dut_command_write_i;
  assign client_command_base_i[1:0]=dut_command_base_i;
  assign client_command_words_i[1:0]=dut_command_words_i;
  assign client_command_mode_i[1:0]=dut_command_mode_i;
  assign client_write_valid_i[1:0]=dut_write_valid_i;
  assign client_write_data_i[1:0]=dut_write_data_i;
  assign client_write_address_i[1:0]=dut_write_address_i;
  assign client_write_address_i[2]=0;
  assign client_read_ready_i[1:0]=dut_read_ready_i;
  assign client_done_ready_i[1:0]=dut_done_ready_i;
  assign dut_command_ready_o=client_command_ready_o[1:0];
  assign dut_write_ready_o=client_write_ready_o[1:0];
  assign dut_read_valid_o=client_read_valid_o[1:0];
  assign dut_read_data_o=client_read_data_o[1:0];
  assign dut_read_address_o=client_read_address_o[1:0];
  assign dut_read_last_o=client_read_last_o[1:0];
  assign dut_done_valid_o=client_done_valid_o[1:0];
  assign dut_done_error_o=client_done_error_o[1:0];
  bank_fabric memory(.*);
  int host_commands=0,host_writes=0,host_reads=0;
  task automatic begin_burst(input int bank,base,n,input bit writing);
    int watchdog;
    @(negedge clk);client_command_mask_i[2][0]=4'b1<<bank;
    client_command_write_i[2][0]=writing?(4'b1<<bank):0;
    client_command_base_i[2][0][bank]=10'(base);client_command_words_i[2][0][bank]=11'(n);
    client_command_valid_i[2][0]=1;watchdog=0;
    @(posedge clk);while(!client_command_ready_o[2][0])begin
      @(posedge clk);if(watchdog++>2000)$fatal(1,"Fixture bank reservation timeout");
    end
    @(negedge clk);client_command_valid_i[2][0]=0;host_commands++;
  endtask
  task automatic end_burst(input int bank);
    int watchdog;watchdog=0;
    while(!client_done_valid_o[2][0][bank])begin
      @(negedge clk);if(watchdog++>2000)$fatal(1,"Fixture burst completion timeout");
    end
    if(client_done_error_o[2][0][bank])$fatal(1,"Fixture burst error");
    client_done_ready_i[2][0][bank]=1;@(negedge clk);client_done_ready_i[2][0][bank]=0;
  endtask
  task automatic write_bank(input int bank,base,n,input logic [91:0] values[1024]);
    int watchdog;begin_burst(bank,base,n,1);
    for(int w=0;w<n;w++)begin
      client_write_valid_i[2][0][bank]=1;client_write_data_i[2][0][bank]=values[w];watchdog=0;
      @(posedge clk);while(!client_write_ready_o[2][0][bank])begin
        @(posedge clk);if(watchdog++>2000)$fatal(1,"Fixture write timeout");
      end
      host_writes++;@(negedge clk);
    end
    client_write_valid_i[2][0][bank]=0;end_burst(bank);
  endtask
  task automatic read_bank(input int bank,base,n,output logic [91:0] values[1024]);
    int watchdog,w;
    begin_burst(bank,base,n,0);w=0;watchdog=0;
    while(w<n)begin
      client_read_ready_i[2][0][bank]=watchdog%7>1;
      @(posedge clk);
      if(client_read_valid_o[2][0][bank] && client_read_ready_i[2][0][bank])begin
        if(client_read_address_o[2][0][bank]!=base+w || client_read_last_o[2][0][bank]!=(w+1==n))$fatal(1,"Fixture read framing");
        values[w]=client_read_data_o[2][0][bank];w++;host_reads++;
      end
      @(negedge clk);if(watchdog++>20000)$fatal(1,"Fixture read timeout");
    end
    client_read_ready_i[2][0][bank]=0;end_burst(bank);
  endtask
  initial begin
    client_command_valid_i[2]=0;client_command_mask_i[2]=0;client_command_write_i[2]=0;
    client_command_base_i[2]=0;client_command_words_i[2]=0;client_command_mode_i[2]=0;
    client_write_valid_i[2]=0;client_write_data_i[2]=0;client_read_ready_i[2]=0;client_done_ready_i[2]=0;
  end
endmodule
