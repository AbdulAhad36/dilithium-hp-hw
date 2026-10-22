`timescale 1ps/1ps
// Real memory/BRAM path. The host only loads fixtures and reads committed
// results;no hierarchical RAM writes. Explicit response faults are identified
// by fixture inject7..13;they do not alter the stored source polynomial.
module tb_sign_process_dma;
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic command_valid_i=0,command_ready_o,busy_o,fault_o,done_valid_o,done_ready_i=0;
  logic [1:0] command_op_i=0,command_param_i=0,command_kind_i=0;
  logic [5:0] command_a_i=0,command_b_i=16,command_dest_i=32,command_high_i=48;
  logic [15:0] command_a_id_i=100,command_b_id_i=101,command_id_i=9000;
  logic [2:0] done_code_o;logic [15:0] done_id_o;logic [5:0] done_dest_o,done_high_o;
  logic done_reject_o;logic [8:0] done_weight_o;
  logic [63:0] reserved,complete,visible,release_locks_o,hidden_o;
  logic alloc_valid_o,alloc_core_o,alloc_domain_o,alloc_rewrite_o,alloc_ready_i;
  logic [5:0] alloc_region_o;logic [15:0] alloc_id_o;logic [1:0] alloc_mode_o,alloc_param_o;
  logic read_valid_o,read_ready_i,response_valid_i,response_error_i,response_ready_o;
  logic [5:0] read_region_o,read_word_o,response_region_i,response_word_i;
  logic [91:0] response_data_i;logic [15:0] response_id_i;logic [1:0] response_mode_i,response_param_i;
  logic response_domain_i;
  logic write_valid_o,write_core_o,write_last_o,write_ready_i;
  logic [15:0] write_id_o;logic [7:0] write_index_o;logic [22:0] write_data_o;
  logic finish_valid_o,finish_core_o,finish_ready_i;logic [15:0] finish_id_o;logic [2:0] finish_code_o;
  sign_process_dma dut(.reserved_i(reserved),.*);
  logic ca=0,cc=0,cw=0,cl=0,cf=0,cr=0,cy=0,release_valid=0;
  logic [5:0] region=0,read_region=0,read_word=0,release_region=0;
  logic [15:0] owner=0;logic [1:0] param=0;logic domain=0;
  logic [7:0] index=0;logic [22:0] data=0;
  logic ma,mw,mf,mr,mv,me,my,release_ready,mem_fault;
  logic [1:0] mbank,mmode,mparam;logic [3:0] mregion;logic [5:0] mword;
  logic [91:0] mdata;logic [15:0] mid;logic mdomain,msmall;
  int cycles=0,case_no=-1,inject=0,abort_phase=0,op,p,kind,style,code,count;
  int completed=0,errors=0,aborts=0;int witnesses[8];
  bit hold_response=0,hold_finish=0,monitor=0,test_passed=0,probing=0;
  wire ga=cycles%5>1,gw=cycles%7>2,gr=cycles%11>3,gy=cycles%13>5 && !hold_response;
  wire gf=cycles%17>7 && !hold_finish;
  wire releasing=release_valid && !release_locks_o[release_region] &&
    !(command_valid_i && command_ready_o && (release_region==command_a_i || (command_op_i==2 && release_region==command_b_i)));
  assign visible=complete & ~hidden_o;
  assign alloc_ready_i=ma && ga;assign write_ready_i=mw && gw;
  assign read_ready_i=mr && gr;assign finish_ready_i=mf && gf;
  assign response_valid_i=mv && gy;
  assign response_error_i=me || (inject==12 && dut.state==7 && dut.word_r==17);
  assign response_region_i={mbank,mregion} ^ ((inject==10 && dut.state==7 && dut.word_r==17)?6'd1:6'd0);
  assign response_word_i=mword ^ ((inject==11 && dut.state==7 && dut.word_r==17)?6'd1:6'd0);
  assign response_id_i=mid ^ ((inject==7 && dut.state==7 && dut.word_r==17)?16'd1:16'd0);
  assign response_param_i=mparam ^ ((inject==8 && dut.state==7 && dut.word_r==17)?2'd1:2'd0);
  assign response_mode_i=mmode ^ ((inject==9 && dut.state==7 && dut.word_r==17)?2'd1:2'd0);
  assign response_domain_i=mdomain;
  assign response_data_i=(inject==13 && dut.state==7 && dut.word_r==17)?92'(23'd8380417):mdata;
  assign my=busy_o?(response_ready_o && gy):cy;
  memory store(
    .clk(clk),.rst(rst),.alloc_valid_i(busy_o?(alloc_valid_o && ga):ca),
    .alloc_core_i(busy_o?alloc_core_o:cc),.alloc_bank_i(busy_o?alloc_region_o[5:4]:region[5:4]),
    .alloc_region_i(busy_o?alloc_region_o[3:0]:region[3:0]),.alloc_id_i(busy_o?alloc_id_o:owner),
    .alloc_mode_i(busy_o?alloc_mode_o:2'd2),.alloc_param_i(busy_o?alloc_param_o:param),
    .alloc_compute_i(1'b1),.alloc_ntt_domain_i(busy_o?alloc_domain_o:domain),.alloc_rewrite_i(1'b0),.alloc_ready_o(ma),
    .write_valid_i(busy_o?(write_valid_o && gw):cw),.write_core_i(busy_o?write_core_o:cc),
    .write_last_i(busy_o?write_last_o:cl),.write_id_i(busy_o?write_id_o:owner),
    .write_index_i(busy_o?write_index_o:index),.write_data_i(busy_o?write_data_o:data),.write_ready_o(mw),
    .finish_valid_i(busy_o?(finish_valid_o && gf):cf),.finish_core_i(busy_o?finish_core_o:cc),
    .finish_id_i(busy_o?finish_id_o:owner),.finish_code_i(busy_o?finish_code_o:3'd0),.finish_ready_o(mf),
    .read_valid_i(busy_o?(read_valid_o && gr):cr),.read_bank_i(busy_o?read_region_o[5:4]:read_region[5:4]),
    .read_region_i(busy_o?read_region_o[3:0]:read_region[3:0]),.read_word_i(busy_o?read_word_o:read_word),
    .read_ready_o(mr),.response_valid_o(mv),.response_error_o(me),.response_bank_o(mbank),.response_region_o(mregion),
    .response_word_o(mword),.response_data_o(mdata),.response_id_o(mid),.response_mode_o(mmode),.response_param_o(mparam),
    .response_ntt_domain_o(mdomain),.response_small_o(msmall),.response_ready_i(my),
    .release_valid_i(releasing),.release_bank_i(release_region[5:4]),.release_region_i(release_region[3:0]),
    .release_ready_o(release_ready),.reserved_o(reserved),.complete_o(complete),.fault_o(mem_fault)
  );
  logic [22:0] aa[256],bb[256];string directory,token;int fd;
  bit held=0;logic [40:0] last_done;
  wire [40:0] done_payload={done_code_o,done_id_o,done_dest_o,done_high_o,done_reject_o,done_weight_o};
  always @(posedge clk)begin
    cycles++;
    if(rst)held=0;
    else begin
      if(fault_o || mem_fault)$fatal(1,"DMA/store fault case%0d state%0d",case_no,dut.state);
      if(held && (!done_valid_o || done_payload!==last_done))$fatal(1,"DMA completion changed while held");
      held=done_valid_o && !done_ready_i;last_done=done_payload;
      if(monitor)begin
        if(command_valid_i && command_ready_o)$fdisplay(fd,"C %0d %0d %0d %0d",case_no,command_op_i,command_param_i,command_kind_i);
        if(busy_o)begin
          if(command_ready_o)$fatal(1,"DMA reaccepted command while busy");
          if(dut.low_owned_r && dut.state!=16 && visible[32])$fatal(1,"Tentative low visible");
          if(dut.high_owned_r && dut.state!=16 && visible[48])$fatal(1,"Tentative high visible");
          if(dut.low_owned_r && dut.high_owned_r && dut.state!=16 && complete[32])witnesses[4]++;
          if(write_valid_o && !write_ready_i)witnesses[1]++;
          if(mv && !my)witnesses[2]++;
          if(finish_valid_o && !finish_ready_i)witnesses[3]++;
          if(alloc_valid_o && !alloc_ready_i)witnesses[6]++;
          if(read_valid_o && !read_ready_i)witnesses[7]++;
          if(release_valid && release_locks_o[release_region])begin
            if(releasing)$fatal(1,"Released DMA lease");witnesses[5]++;
          end
          if(store.write_fire)$fdisplay(fd,"W %0d %0d %0d %06h %0d",case_no,store.write_core_i,store.write_index_i,store.write_data_i,store.write_last_i);
          if(store.finish_fire)$fdisplay(fd,"U %0d %0d %0d",case_no,store.finish_core_i,store.finish_code_i);
          for(int b=0;b<4;b++)begin
            if(store.request_valid[0][b] && store.request_ready[0][b])
              $fdisplay(fd,"P %0d %0d %0d %023h",case_no,16*b+int'(store.request_address[0][b][9:6]),store.request_address[0][b][5:0],store.request_data[0][b]);
            if(store.response_valid[0][b] && store.response_ready[0][b])
              $fdisplay(fd,"Q %0d %0d %0d",case_no,16*b+int'(store.response_address[0][b][9:6]),store.response_address[0][b][5:0]);
          end
        end
      end
    end
  end
  task automatic reset_all();
    @(negedge clk);rst=1;command_valid_i=0;done_ready_i=0;release_valid=0;
    ca=0;cw=0;cf=0;cr=0;cy=0;hold_response=0;hold_finish=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved || complete || busy_o || done_valid_o || mv || fault_o || mem_fault)$fatal(1,"DMA reset ownership");
  endtask
  task automatic load(input int slot,jid,which,dom,lev);
    @(negedge clk);region=6'(slot);owner=16'(jid);cc=0;domain=1'(dom);param=2'(lev);ca=1;
    do @(posedge clk);while(!ma);@(negedge clk);ca=0;
    for(int k=0;k<256;k++)begin
      index=8'(k);data=which==0?aa[k]:(which==1?bb[k]:23'd0);cl=k==255;cw=1;
      do @(posedge clk);while(!mw);@(negedge clk);cw=0;
    end
    do @(negedge clk);while(!mf);cf=1;@(posedge clk);@(negedge clk);cf=0;
    if(!complete[slot])$fatal(1,"Fixture not committed");
  endtask
  task automatic release_slot(input int slot);
    @(negedge clk);release_region=6'(slot);release_valid=1;
    do @(posedge clk);while(!release_ready || !releasing);
    @(negedge clk);release_valid=0;
  endtask
  task automatic read_result(input int slot);
    for(int k=0;k<64;k++)begin
      @(negedge clk);read_region=6'(slot);read_word=6'(k);cr=1;
      do @(posedge clk);while(!mr);@(negedge clk);cr=0;
      do @(negedge clk);while(!mv);
      if(me || {mbank,mregion}!==6'(slot) || mword!==6'(k))$fatal(1,"DMA public read metadata");
      $fdisplay(fd,"R %0d %0d %0d %023h %0d %0d %0d",case_no,slot,k,mdata,mid,mparam,mdomain);
      repeat(k%3)@(negedge clk);cy=1;@(posedge clk);@(negedge clk);cy=0;
    end
  endtask
  task automatic witness();
    $fdisplay(fd,"T %0d %0d %0d %0d %0d %0d %0d %0d %0d",case_no,witnesses[0],witnesses[1],witnesses[2],witnesses[3],witnesses[4],witnesses[5],witnesses[6],witnesses[7]);
  endtask
  initial begin
    int f,n,idx;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    f=$fopen({directory,"/stage5_sign_dma_inputs.txt"},"r");
    if(!f || $fscanf(f,"%s %d",token,count)!=2 || count<50)$fatal(1,"Prepare signing DMA fixtures");
    fd=$fopen({directory,"/stage5_sign_dma_outputs.txt"},"w");$fdisplay(fd,"H %s",token);reset_all();
    for(int c=0;c<count;c++)begin
      if($fscanf(f,"%d %d %d %d %d %d %d %d",case_no,op,p,kind,style,inject,abort_phase,code)!=8 || case_no!=c)$fatal(1,"DMA fixture header");
      for(int k=0;k<256;k++)if($fscanf(f,"%h %h",aa[k],bb[k])!=2)$fatal(1,"DMA fixture data");
      foreach(witnesses[k])witnesses[k]=0;monitor=0;
      if(inject!=1)load(0,100,0,inject==3,inject==4?1:p);
      if(op==2)load(16,101,1,0,p);
      if(inject==6)load(32,102,2,0,p);
      @(negedge clk);monitor=1;command_op_i=2'(op);command_param_i=2'(p);command_kind_i=2'(kind);
      command_a_id_i=inject==2?16'd999:16'd100;command_high_i=inject==5?6'd0:6'd48;
      command_valid_i=1;release_valid=1;release_region=0;
      // Lease applies on the SAME acceptance edge,not just one clock later.
      #1;if(releasing)$fatal(1,"Acceptance-edge source lease absent");
      do @(posedge clk);while(!command_ready_o);@(negedge clk);command_valid_i=0;
      if(inject==6)begin
        do @(negedge clk);while(dut.state!=3);
        repeat(6)begin @(negedge clk);witnesses[0]++;end
        if(abort_phase==0)begin release_valid=0;release_slot(32);release_valid=1;release_region=0;end
      end
      if(abort_phase!=0)begin
        case(abort_phase)
          1:begin end
          2:do @(negedge clk);while(dut.state!=7 || dut.word_r!=3);
          3:do @(negedge clk);while(dut.state!=10 || dut.word_r!=7);
          4:begin do @(negedge clk);while(dut.state!=13);hold_finish=1;end
          5:do @(negedge clk);while(!done_valid_o);
          6:do @(negedge clk);while(dut.state!=6 || dut.word_r!=4);
        endcase
        hold_response=1;repeat(6)begin @(negedge clk);witnesses[0]++;end
        $fdisplay(fd,"A %0d %0d",case_no,abort_phase);witness();aborts++;reset_all();monitor=0;continue;
      end
      do @(negedge clk);while(!done_valid_o);
      if(done_code_o!==3'(code))$fatal(1,"DMA case%0d code actual%0d expected%0d",case_no,done_code_o,code);
      repeat(6)begin
        @(negedge clk);witnesses[0]++;
        if(!release_locks_o[0])$fatal(1,"Source lease retired before completion");
        if(code!=0 && (reserved[32] || reserved[48]))$fatal(1,"Failed DMA allocation leaked");
        if(code==0 && op==0 && (!visible[32] || !visible[48]))$fatal(1,"Pair not atomically published");
      end
      $fdisplay(fd,"D %0d %0d %0d %0d %0d %0d %0d",case_no,done_code_o,done_id_o,done_dest_o,done_high_o,done_reject_o,done_weight_o);
      witness();completed++;if(code!=0)errors++;
      release_valid=0;done_ready_i=1;@(posedge clk);@(negedge clk);done_ready_i=0;
      if(code==0 && op!=1)begin read_result(32);if(op==0)read_result(48);end
      monitor=0;
      for(int s=0;s<64;s++)if(reserved[s])release_slot(s);
      if(reserved || complete)$fatal(1,"DMA cleanup retained allocation");
    end
    $fdisplay(fd,"F %0d %0d %0d %0d",count,completed,errors,aborts);$fclose(f);$fclose(fd);
    $display("STAGE5N3A_SIGN_DMA_CAPTURE_PASS:%0d commands,%0d completions,%0d expected errors,%0d resets",count,completed,errors,aborts);
    test_passed=1;$finish;
  end
  initial begin #(64'd20000000000);$fatal(1,"Signing DMA watchdog case%0d state%0d",case_no,dut.state);end
endmodule
