`timescale 1ns/1ps
// Check the registered admission boundary itself. RAM payload/response timing
// is checked separately by tb_memory and the real-bank NTT campaign.
module tb_memory_admission;
  parameter bit COHERENT_ADMISSION=0,LOCAL_DESCRIPTOR=0;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,command_valid_i,command_ready_o;
  logic [3:0] command_mask_i,command_write_i,busy_o,request_valid_o,done_valid_o,done_error_o,done_ready_i;
  logic [3:0][9:0] command_base_i;
  logic [3:0][10:0] command_words_i;
  logic [3:0][1:0] command_mode_i;
  int checked=0,valid_cases=0,invalid_cases=0,admit_resets=0;
  int bases[8]='{0,1,511,512,1008,1009,1016,1023};
  int counts[8]='{0,1,31,32,64,512,1024,2047};
  memory_port #(.COHERENT_ADMISSION(COHERENT_ADMISSION),.LOCAL_DESCRIPTOR(LOCAL_DESCRIPTOR)) dut(
    .clk(clk),.rst(rst),.command_valid_i(command_valid_i),.command_ready_o(command_ready_o),
    .command_mask_i(command_mask_i),.command_write_i(command_write_i),
    .command_base_i(command_base_i),.command_words_i(command_words_i),.command_mode_i(command_mode_i),
    .busy_o(busy_o),.request_valid_o(request_valid_o),.done_valid_o(done_valid_o),.done_error_o(done_error_o),
    .write_valid_i(4'b1111),.write_data_i(368'b0),.write_address_i(40'b0),
    .read_ready_i(4'b0),.done_ready_i(done_ready_i),.request_ready_i(4'b0),
    .response_valid_i(4'b0),.response_write_i(4'b0),
    .response_address_i(40'b0),.response_data_i(368'b0));
  function automatic bit reference_bad();
    bit bad;int last;
    bad=command_mask_i==0 || (command_write_i & ~command_mask_i)!=0;
    for(int b=0;b<4;b++)if(command_mask_i[b])begin
      case(command_mode_i[b])
        1:last=int'(command_base_i[b])+2*(int'(command_words_i[b])-1);
        2:last=int'(command_base_i[b])+7;
        3:last=int'(command_base_i[b])+15;
        default:last=int'(command_base_i[b])+int'(command_words_i[b])-1;
      endcase
      bad|=command_words_i[b]==0 || command_words_i[b]>1024 ||
        (command_mode_i[b]==2 && !command_write_i[b] && command_words_i[b]!=32) ||
        (command_mode_i[b]==3 && command_words_i[b]!=64) ||
        (!(command_mode_i[b]==2 && command_write_i[b]) && last>=1024);
    end
    return bad;
  endfunction
  task automatic reset_port();
    @(negedge clk);rst=1;command_valid_i=0;done_ready_i=0;
    @(negedge clk);rst=0;
  endtask
  task automatic trial();
    bit bad;logic [3:0] mask;
    reset_port();bad=reference_bad();mask=command_mask_i==0?4'b1:command_mask_i;
    command_valid_i=1;#1;if(!command_ready_o)$fatal(1,"Fresh command blocked");
    @(posedge clk);#1;
    if(busy_o!==mask || request_valid_o!=0 || done_valid_o!=0)
      $fatal(1,"Admission issued RAM/completion before validation");
    @(negedge clk);command_valid_i=0;
    // Poison the live command after acceptance;the captured one must decide.
    command_mask_i=0;command_write_i='1;command_base_i='1;command_words_i=0;command_mode_i='1;
    @(posedge clk);#1;
    if(busy_o!==mask || (done_valid_o&mask)!==(bad?mask:4'b0) || (done_error_o&mask)!==(bad?mask:4'b0))
      $fatal(1,"Registered admission result mismatch trial%0d",checked);
    if((request_valid_o&mask)!==(bad?4'b0:mask))$fatal(1,"Bad command reached RAM or valid command failed to run");
    checked++;if(bad)invalid_cases++;else valid_cases++;
  endtask
  task automatic reset_in_admit();
    reset_port();command_mask_i=15;command_write_i=0;command_base_i=0;command_words_i='{default:11'd32};command_mode_i=0;
    command_valid_i=1;@(posedge clk);#1;
    if(busy_o!=15 || request_valid_o!=0)$fatal(1,"Reset trial missed ADMIT");
    @(negedge clk);rst=1;command_valid_i=0;#1;
    if(busy_o!=0 || request_valid_o!=0 || done_valid_o!=0)$fatal(1,"ADMIT reset leaked a transaction");
    @(negedge clk);rst=0;#1;if(!command_ready_o)$fatal(1,"ADMIT reset did not recover");
    admit_resets++;
  endtask
  initial begin
    command_valid_i=0;done_ready_i=0;command_mask_i=0;command_write_i=0;command_base_i=0;command_words_i=0;command_mode_i=0;
    for(int mode=0;mode<4;mode++)for(int wr=0;wr<2;wr++)
      for(int bi=0;bi<8;bi++)for(int wi=0;wi<8;wi++)for(int mask=0;mask<16;mask++)begin
        command_mask_i=4'(mask);command_write_i=wr?4'(mask):4'b0;
        for(int b=0;b<4;b++)begin
          command_base_i[b]=10'(bases[bi]);command_words_i[b]=11'(counts[wi]);command_mode_i[b]=2'(mode);
        end
        trial();if(checked%64==0)reset_in_admit();
      end
    for(int mask=0;mask<16;mask++)for(int wr=0;wr<16;wr++)begin
      command_mask_i=4'(mask);command_write_i=4'(wr);command_mode_i=0;command_base_i=0;
      command_words_i='{default:11'd1};trial();
    end
    // Three independent banks accept on consecutive clocks. An invalid second
    // descriptor must poison only its own command,not its neighbors.
    reset_port();command_valid_i=1;command_mask_i=1;command_write_i=0;command_mode_i=0;
    command_base_i=0;command_words_i='{default:11'd1};
    @(posedge clk);#1;
    @(negedge clk);command_mask_i=2;command_base_i[1]=1023;command_words_i[1]=2;
    #1;if(!command_ready_o)$fatal(1,"Independent bank cannot overlap ADMIT");
    @(posedge clk);#1;if(request_valid_o!=1 || done_valid_o!=0)$fatal(1,"First overlapping descriptor lost");
    @(negedge clk);command_mask_i=4;
    @(posedge clk);#1;if(request_valid_o!=1 || done_valid_o!=2 || done_error_o!=2)
      $fatal(1,"Second overlapping descriptor not rejected independently");
    @(negedge clk);command_valid_i=0;
    @(posedge clk);#1;if(request_valid_o!=5 || done_valid_o!=2 || done_error_o!=2)
      $fatal(1,"Third overlapping descriptor contaminated");
    // Renew the failed bank directly from REPORT into a valid command.
    @(negedge clk);done_ready_i=2;command_valid_i=1;command_mask_i=2;command_base_i[1]=0;command_words_i[1]=1;
    #1;if(!command_ready_o)$fatal(1,"Atomic REPORT renewal blocked");
    @(posedge clk);#1;if(busy_o!=7 || request_valid_o!=5 || done_valid_o!=0)
      $fatal(1,"Atomic renewal lost reservation or bypassed ADMIT");
    @(negedge clk);command_valid_i=0;done_ready_i=0;
    @(posedge clk);#1;if(request_valid_o!=7 || done_error_o!=0)$fatal(1,"Renewal did not validate captured descriptor");
    if(checked!=8448 || valid_cases==0 || invalid_cases==0 || admit_resets!=128)$fatal(1,"Incomplete admission campaign");
    $display("LIGHTHD_MEMORY_ADMISSION_PASS:%0d commands/%0d valid/%0d invalid/%0d ADMIT resets;live-input mutation,consecutive-bank isolation and atomic renewal checked",checked,valid_cases,invalid_cases,admit_resets);
    $finish;
  end
endmodule
