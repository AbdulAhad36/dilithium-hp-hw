`timescale 1ns/1ps
module tb_memory;
  parameter bit CYCLE_REFERENCE=0,COHERENT_ADMISSION=0;
  import dilithium_pkg::*;
  logic clk=0;always #5 clk=~clk;
  logic rst=1;
  logic [1:0] command_valid_i,command_ready_o;
  logic [1:0][3:0] busy_o,done_valid_o,done_ready_i,done_error_o;
  logic [1:0][3:0][1:0] command_mode_i;
  logic [1:0][3:0] command_mask_i,command_write_i,write_valid_i,write_ready_o;
  logic [1:0][3:0] read_valid_o,read_ready_i,read_last_o;
  logic [1:0][3:0][9:0] command_base_i,read_address_o;
  logic [1:0][3:0][10:0] command_words_i;
  logic [1:0][3:0][91:0] write_data_i,read_data_o;
  wire [1:0][3:0][9:0] write_address_i='0;
  logic [3:0] collision_o;
  memory #(.COHERENT_ADMISSION(COHERENT_ADMISSION)) dut(.*);
  generate if(CYCLE_REFERENCE)begin:timing_reference
    for(genvar p=0;p<2;p++)begin:port_shadow
      logic ready;
      logic [3:0] busy,write_ready,read_valid,read_last,done_valid,done_error;
      logic [3:0] request_valid,request_write,response_ready;
      logic [3:0][91:0] read_data,request_data;
      logic [3:0][9:0] read_address,request_address;
      int compared=0;
      memory_port_timing_reference #(.COHERENT_ADMISSION(COHERENT_ADMISSION)) reference_port(
        .clk(clk),.rst(rst),.command_valid_i(command_valid_i[p]),.command_ready_o(ready),.busy_o(busy),
        .command_mask_i(command_mask_i[p]),.command_write_i(command_write_i[p]),
        .command_base_i(command_base_i[p]),.command_words_i(command_words_i[p]),.command_mode_i(command_mode_i[p]),
        .write_valid_i(write_valid_i[p]),.write_ready_o(write_ready),.write_data_i(write_data_i[p]),
        .write_address_i(write_address_i[p]),.read_valid_o(read_valid),.read_ready_i(read_ready_i[p]),
        .read_data_o(read_data),.read_address_o(read_address),.read_last_o(read_last),
        .done_valid_o(done_valid),.done_ready_i(done_ready_i[p]),.done_error_o(done_error),
        .request_valid_o(request_valid),.request_write_o(request_write),.request_address_o(request_address),
        .request_data_o(request_data),.request_ready_i(dut.request_ready[p]),
        .response_valid_i(dut.response_valid[p]),.response_write_i(dut.response_write[p]),
        .response_address_i(dut.response_address[p]),.response_data_i(dut.response_data[p]),
        .response_ready_o(response_ready));
      always @(posedge clk)if(!rst)begin
        if({ready,busy,write_ready,read_valid,read_last,read_data,read_address,done_valid,done_error,
            request_valid,request_write,request_address,request_data,response_ready} !==
           {command_ready_o[p],busy_o[p],write_ready_o[p],read_valid_o[p],read_last_o[p],read_data_o[p],
            read_address_o[p],done_valid_o[p],done_error_o[p],dut.request_valid[p],dut.request_write[p],
            dut.request_address[p],dut.request_data[p],dut.response_ready[p]})
          $fatal(1,"Memory timing change altered a pin/cycle port%0d",p);
        compared++;
      end
      final $display("MEMORY_PORT_CYCLE_REFERENCE_PASS:coherent%0d port%0d cycles%0d",COHERENT_ADMISSION,p,compared);
    end
  end endgenerate
  typedef struct packed {logic [9:0] address;logic [91:0] data;} read_t;
  read_t expected[2][4][$];
  typedef struct packed {logic writing;logic [9:0] address;logic [91:0] data;} request_t;
  request_t physical_expected[2][4][$];
  logic [1:0][3:0] physical_fire,physical_write;
  logic [1:0][3:0][9:0] physical_address;
  logic [1:0][3:0][91:0] physical_data;
  int physical_requests=0,queued_conflicts=0;
  // Observe the RAM boundary after the new registered request queues.
  for(genvar bank_probe=0;bank_probe<4;bank_probe++)begin:physical_probe
    for(genvar port_probe=0;port_probe<2;port_probe++)begin:physical_port
      assign physical_fire[port_probe][bank_probe]=dut.banks.bank[bank_probe].queued_valid[port_probe] && dut.banks.bank[bank_probe].queued_ready[port_probe];
      assign physical_write[port_probe][bank_probe]=dut.banks.bank[bank_probe].queued_write[port_probe];
      assign physical_address[port_probe][bank_probe]=dut.banks.bank[bank_probe].queued_address[port_probe];
      assign physical_data[port_probe][bank_probe]=dut.banks.bank[bank_probe].queued_data[port_probe];
    end
  end
  logic [91:0] model[4][1024];
  logic initialized[4][1024];
  logic [91:0] held_data[2][4];logic [9:0] held_addr[2][4];logic held_last[2][4],held[2][4];
  int sent[2][4],received[2][4],epoch[2][4],command_epoch[2],base_cfg[2][4],words_cfg[2][4];
  int mode_cfg[2][4];
  bit write_cfg[2][4],write_stalled[2][4];
  bit gaps=0,drive=0;
  int cycles=0,writes=0,reads=0,requests=0,max_parallel=0,collisions=0,stable_checks=0,commands=0;
  function automatic logic [91:0] pattern(input int bank,address,e);
    return {23'(e*17+bank),23'(address^32'h123456),23'(address+e*31),23'(bank*1024+address)};
  endfunction
  function automatic int address_offset(input int index,mode);
    case(mode)
      1:return 2*index;
      2:return (index/2)%8;
      3:return (index/32)*8+(index/2)%8;
      default:return index;
    endcase
  endfunction
  always @(negedge clk)if(drive && !rst)begin
    for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
      if(!write_stalled[p][b])begin
        write_valid_i[p][b]=busy_o[p][b] && !done_valid_o[p][b] && write_cfg[p][b] &&
          sent[p][b]<words_cfg[p][b] && (!gaps || (cycles+3*b+p)%7!=0);
        write_data_i[p][b]=pattern(b,base_cfg[p][b]+address_offset(sent[p][b],mode_cfg[p][b]),epoch[p][b]);
      end
      read_ready_i[p][b]=!gaps || (cycles+2*b+3*p)%9>2;
    end
  end
  always @(posedge clk)begin
    int parallel_count;read_t next_read;request_t next_request;
    cycles++;
    if(rst)begin
      for(int p=0;p<2;p++)for(int b=0;b<4;b++)begin
        expected[p][b].delete();physical_expected[p][b].delete();sent[p][b]=0;received[p][b]=0;held[p][b]=0;write_stalled[p][b]=0;
        base_cfg[p][b]=0;words_cfg[p][b]=0;write_cfg[p][b]=0;mode_cfg[p][b]=0;epoch[p][b]=0;
      end
    end else begin
      parallel_count=0;
      for(int p=0;p<2;p++)begin
        if(command_valid_i[p] && command_ready_o[p])begin
          commands++;
          for(int b=0;b<4;b++)if(command_mask_i[p][b] || (command_mask_i[p]==0 && b==0))begin
            sent[p][b]=0;received[p][b]=0;base_cfg[p][b]=int'(command_base_i[p][b]);
            words_cfg[p][b]=int'(command_words_i[p][b]);mode_cfg[p][b]=int'(command_mode_i[p][b]);
            write_cfg[p][b]=command_write_i[p][b];epoch[p][b]=command_epoch[p];
          end
        end
        for(int b=0;b<4;b++)begin
          if(held[p][b])begin
            if(!read_valid_o[p][b] || read_data_o[p][b]!==held_data[p][b] ||
               read_address_o[p][b]!==held_addr[p][b] || read_last_o[p][b]!==held_last[p][b])
              $fatal(1,"Unstable bank response port%0d bank%0d",p,b);
            stable_checks++;
          end
          held[p][b]=read_valid_o[p][b] && !read_ready_i[p][b];
          held_data[p][b]=read_data_o[p][b];held_addr[p][b]=read_address_o[p][b];held_last[p][b]=read_last_o[p][b];
          write_stalled[p][b]=write_valid_i[p][b] && !write_ready_o[p][b];
          if(write_valid_i[p][b] && write_ready_o[p][b])sent[p][b]++;
          if(read_valid_o[p][b] && read_ready_i[p][b])begin
            if(expected[p][b].size()==0)$fatal(1,"Unexpected read response");
            next_read=expected[p][b].pop_front();
            if(read_address_o[p][b]!==next_read.address || read_data_o[p][b]!==next_read.data)
              $fatal(1,"Bank payload/address mismatch p%0d b%0d a%0d",p,b,read_address_o[p][b]);
            if(read_address_o[p][b]!==10'(base_cfg[p][b]+address_offset(received[p][b],mode_cfg[p][b])) ||
              read_last_o[p][b] !== (received[p][b]+1==words_cfg[p][b]))
              $fatal(1,"Bank burst order/last mismatch");
            received[p][b]++;reads++;
          end
        end
      end
      // Physical issue must match an earlier accepted request exactly.
      // Front acceptance is not RAM issue after adding the request pipeline.
      for(int p=0;p<2;p++)for(int b=0;b<4;b++)if(physical_fire[p][b])begin
        if(physical_expected[p][b].size()==0)$fatal(1,"RAM issued an unaccepted bank request");
        next_request=physical_expected[p][b].pop_front();
        if({physical_write[p][b],physical_address[p][b],physical_data[p][b]}!==
           {next_request.writing,next_request.address,next_request.data})$fatal(1,"Physical bank request reordered/corrupted");
        physical_requests++;
      end
      // Independent acceptance-order model:A precedes B on the same edge.
      // Conflicting writes may both enqueue;the backend must serialize them.
      for(int p=0;p<2;p++)for(int b=0;b<4;b++)
        if(dut.request_valid[p][b] && dut.request_ready[p][b])begin
          parallel_count++;requests++;
          next_request.writing=dut.request_write[p][b];next_request.address=dut.request_address[p][b];next_request.data=dut.request_data[p][b];
          physical_expected[p][b].push_back(next_request);
          if(physical_expected[p][b].size()>2)$fatal(1,"Bank request queue exceeded its bound");
          if(dut.request_write[p][b])begin
            if(dut.request_data[p][b]!==pattern(b,dut.request_address[p][b],epoch[p][b]))$fatal(1,"Bank write payload/order mismatch");
            model[b][dut.request_address[p][b]]=dut.request_data[p][b];initialized[b][dut.request_address[p][b]]=1;writes++;
          end else begin
            if(!initialized[b][dut.request_address[p][b]])$fatal(1,"Test read never initialized word");
            next_read.address=dut.request_address[p][b];next_read.data=model[b][next_read.address];expected[p][b].push_back(next_read);
          end
        end
      for(int b=0;b<4;b++)begin
        if(collision_o[b])collisions++;
        if(dut.request_valid[0][b] && dut.request_ready[0][b] && dut.request_valid[1][b] && dut.request_ready[1][b] &&
           dut.request_address[0][b]==dut.request_address[1][b] && (dut.request_write[0][b] || dut.request_write[1][b]))queued_conflicts++;
        if(physical_fire[0][b] && physical_fire[1][b] && physical_address[0][b]==physical_address[1][b] &&
           (physical_write[0][b] || physical_write[1][b]))$fatal(1,"Physical collision accepted");
      end
      if(parallel_count>max_parallel)max_parallel=parallel_count;
    end
  end
  task automatic launch(input int p,input logic [3:0] mask,writes_mask,
                        input int base,count,e,input int mode=0);
    @(negedge clk);
    command_mask_i[p]=mask;command_write_i[p]=writes_mask;command_epoch[p]=e;
    for(int b=0;b<4;b++)begin
      command_base_i[p][b]=10'(base);command_words_i[p][b]=11'(count);command_mode_i[p][b]=2'(mode);
    end
    #1;if(!command_ready_o[p])$fatal(1,"Selected bank ports not idle at launch");
    command_valid_i[p]=1;@(negedge clk);command_valid_i[p]=0;
  endtask
  task automatic retire(input int p,input bit error=0,input logic [3:0] selected=0);
    int watchdog;logic [3:0] mask;
    mask=selected!=0?selected:command_mask_i[p]!=0?command_mask_i[p]:4'b0001;
    watchdog=0;
    while((done_valid_o[p]&mask)!=mask)begin @(negedge clk);watchdog++;if(watchdog>20000)$fatal(1,"Memory burst timeout");end
    if((done_error_o[p]&mask)!==(error?mask:4'b0))$fatal(1,"Unexpected burst status port%0d",p);
    for(int b=0;b<4;b++)if(mask[b] && physical_expected[p][b].size()!=0)
      $fatal(1,"Bank burst reported complete before its queued requests reached RAM");
    repeat(4)begin @(negedge clk);if((done_valid_o[p]&mask)!=mask || (done_error_o[p]&mask)!==(error?mask:4'b0))$fatal(1,"Unstable completion");end
    done_ready_i[p]=mask;@(negedge clk);done_ready_i[p]=0;
  endtask
  task automatic check_maps;
    span_t s,t;int k,l;bit seen[4][1024];
    for(int level=0;level<3;level++)begin
      k=int'(rows(2'(level)));l=int'(columns(2'(level)));
      foreach(seen[b,w])seen[b][w]=0;
      for(int role=0;role<=int'(ROLE_W1);role++)if(role!=int'(ROLE_ROW))begin
        int n;n=(role==int'(ROLE_Y) || role==int'(ROLE_S1) || role==int'(ROLE_YHAT))?l:
          role==int'(ROLE_W1)?1:k;
        for(int i=0;i<n;i++)begin
          s=span(2'(level),role_e'(role),5'(i));
          if(!s.valid || int'(s.base)+int'(s.words)>1024)$fatal(1,"Invalid fixed Sign span");
          for(int w=int'(s.base);w<int'(s.base)+int'(s.words);w++)begin
            if(seen[s.bank][w])$fatal(1,"Fixed Sign regions alias level%0d role%0d",level,role);
            seen[s.bank][w]=1;
          end
        end
      end
      // Level5's last w0 intentionally takes the accumulator only AFTER
      // its final row;before then the accumulator is otherwise disjoint.
      s=span(2'(level),ROLE_ROW,0);t=span(2'(level),ROLE_W0,5'(k-1));
      if(level==2 && (s.bank!=t.bank || s.base!=t.base))$fatal(1,"Missing final-row scratch reuse");
      s=span(2'(level),ROLE_PK_T1,0);
      if(!s.valid || int'(s.base)+int'(s.words)>1024 || s.base<9*64)$fatal(1,"KeyGen packed t1 overlaps A ring");
      if(span(2'(level),ROLE_Y,5'(l)).valid || span(2'(level),ROLE_T0,5'(k)).valid)
        $fatal(1,"Out-of-range role accepted");
    end
    if(span(3,ROLE_Y,0).valid)$fatal(1,"Invalid level accepted");
  endtask
  initial begin
    command_valid_i=0;command_mask_i=0;command_write_i=0;command_base_i=0;command_words_i=0;
    write_valid_i=0;write_data_i=0;read_ready_i=0;done_ready_i=0;command_mode_i=0;command_epoch[0]=1;command_epoch[1]=2;
    foreach(initialized[b,w])initialized[b][w]=0;
    check_maps();repeat(3)@(negedge clk);rst=0;drive=1;
    launch(0,15,15,0,1024,1);retire(0);
    // Terminal capacity around every relevant carry boundary,with both read
    // and write handshakes. The real-RAM scoreboards remain the data oracle.
    if(CYCLE_REFERENCE)begin
      int counts[15]='{1,2,3,31,33,63,65,127,129,255,257,511,513,1023,1024};
      foreach(counts[i])begin
        launch(0,1,1,0,counts[i],20+i);retire(0);
        launch(1,1,0,0,counts[i],0);retire(1);
      end
    end
    fork launch(0,15,0,0,1024,1);launch(1,15,0,0,1024,1);join
    fork retire(0);retire(1);join
    gaps=1;
    fork launch(0,15,15,64,128,2);launch(1,15,0,512,128,1);join
    fork retire(0);retire(1);join
    // Both streams begin at the same address:the physical A/B collision
    // policy must serialize each conflict and preserve every accepted write.
    fork launch(0,15,15,256,128,3);launch(1,15,15,256,128,4);join
    fork retire(0);retire(1);join
    launch(0,15,0,256,128,0);retire(0);
    launch(0,0,0,0,64,0);retire(0,1);
    launch(0,1,2,0,64,0);retire(0,1);
    launch(0,1,0,1000,25,0);retire(0,1);
    launch(1,1,0,0,0,0);retire(1,1);
    // Free bank1 is admitted on portA while bank0 is still streaming.
    launch(0,1,0,0,256,0);
    launch(0,2,2,700,64,6);
    retire(0,0,2);retire(0,0,1);
    fork launch(0,15,15,0,32,7,1);launch(1,15,15,1,32,8,1);join
    fork retire(0);retire(1);join
    launch(0,15,0,0,64,0);retire(0);
    launch(0,1,0,1000,13,0,1);retire(0,1);
    // Pre-NTT repeats each compact word twice,then revisits the8 words;
    // natural secret serialization walks all16 compact words in quarters.
    launch(0,15,0,0,32,0,2);retire(0);
    launch(1,15,0,0,64,0,3);retire(1);
    launch(0,1,0,1020,32,0,2);retire(0,1);
    launch(1,1,0,1010,64,0,3);retire(1,1);
    launch(0,1,0,0,31,0,2);retire(0,1);
    fork launch(0,15,0,0,1024,0);launch(1,15,0,0,1024,0);join
    repeat(8)@(negedge clk);rst=1;write_valid_i=0;repeat(3)@(negedge clk);rst=0;
    fork launch(0,15,15,900,64,5);launch(1,15,0,0,64,0);join
    fork retire(0);retire(1);join
    launch(1,15,0,900,64,0);retire(1);
    if(max_parallel!=8 || queued_conflicts==0 || stable_checks==0)$fatal(1,"Missing real port concurrency/stall/collision stimulus");
    for(int p=0;p<2;p++)for(int b=0;b<4;b++)if(physical_expected[p][b].size()!=0)$fatal(1,"Bank completed before physical requests drained");
    $display("LIGHTHD_DIRECT_MEMORY_PASS:commands%0d writes%0d reads%0d accepted_requests%0d physical_requests%0d max_parallel%0d queued_conflicts%0d physical_collisions%0d stable_checks%0d;all3 maps/reset and both boundaries checked",
      commands,writes,reads,requests,physical_requests,max_parallel,queued_conflicts,collisions,stable_checks);
    $finish;
  end
  initial begin #5000000;$fatal(1,"Global memory watchdog");end
endmodule
