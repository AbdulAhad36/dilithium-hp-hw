`timescale 1ps/1ps
module tb_full_keygen #(parameter bit NIST_VECTORS=0);
  logic key_valid_o;
  logic key_ready_i=0;
  logic [63:0] key_data_o;
  logic [3:0] key_bytes_o;
  logic key_type_o;
  logic key_last_o;
  logic [9:0] key_index_o;
  logic [15:0] key_id_o;
  logic clk=0;
  logic rst=1;
  logic start_valid_i=0;
  logic start_ready_o;
  logic busy_o;
  logic [1:0] start_op_i=0;
  logic [1:0] start_param_i=0;
  logic [15:0] start_id_i=0;
  logic [255:0] start_seed_i=0;
  logic row_result_valid_o;
  logic row_result_ready_i=0;
  logic [3:0] row_result_index_o;
  logic [5:0] row_result_region_o;
  logic [15:0] row_result_id_o;
  logic done_valid_o;
  logic done_ready_i=0;
  logic [2:0] done_code_o;
  logic [15:0] done_id_o;
  logic seed_valid_o;
  logic [255:0] rho_o;
  logic [255:0] key_o;
  logic [511:0] rhoprime_o;
  logic read_valid_i=0;
  logic [1:0] read_bank_i=0;
  logic [3:0] read_region_i=0;
  logic [5:0] read_word_i=0;
  logic read_ready_o;
  logic response_valid_o;
  logic response_error_o;
  logic [1:0] response_bank_o;
  logic [1:0] response_mode_o;
  logic [1:0] response_param_o;
  logic [3:0] response_region_o;
  logic [5:0] response_word_o;
  logic [91:0] response_data_o;
  logic [15:0] response_id_o;
  logic response_ntt_domain_o;
  logic response_small_o;
  logic response_ready_i=0;
  logic [63:0] reserved_o;
  logic [63:0] complete_o;
  logic fault_o;

  dilithium #(.FULL_KEYGEN(1)) dut(.*);
  localparam int CASE_COUNT=NIST_VECTORS?75:16;
  string directory,token,stem;int fd,current=-1,cycle=0,opened=0,complete=0,rejected=0,aborted=0;
  int host_words=0,hash_words=0,tr_bytes=0,read_words=0,host_ahead=0,hash_ahead=0;
  int owner_active_cycles=0,owner_cleanup_cycles=0,owner_idle_cycles=0;
  int ops[CASE_COUNT],params[CASE_COUNT],ids[CASE_COUNT],abort_at[CASE_COUNT];logic [255:0] seeds[CASE_COUNT];
  bit test_passed=0,key_held=0,raw_held=0;logic [95:0] key_snapshot;logic [63:0] raw_snapshot;
  always begin #3378 clk=1;#3379 clk=0;end
  always @(negedge clk)begin
    if(rst)key_ready_i<=0;
    else if(current>=0 && (abort_at[current]==0 ||
      (abort_at[current]==1 && !key_type_o && key_index_o>=13) ||
      (abort_at[current]==3 && key_type_o && key_index_o>=20)))key_ready_i<=0;
    else key_ready_i<=cycle%19>5;
  end
  always @(posedge clk)begin
    cycle++;
    if(rst)begin key_held=0;raw_held=0;end
    else begin
      if(dut.keygen_owner)begin
        owner_active_cycles++;
        if(dut.shared_request!==dut.keygen_request)$fatal(1,"Shared request routing");
        if(dut.state==0 && dut.child_busy)owner_cleanup_cycles++;
      end else begin
        owner_idle_cycles++;
        if(dut.shared_request!=='0 || dut.child_busy || dut.shared_response.reserved ||
          dut.shared_response.active || dut.shared_response.op_busy || dut.shared_response.process_busy ||
          dut.shared_response.row_busy || dut.shared_response.response_valid ||
          dut.shared_response.sign.busy || dut.shared_response.sign.done_valid ||
          dut.shared_response.raw_output_valid || dut.shared_response.raw_done_valid ||
          dut.shared_response.pack.output_valid || dut.shared_response.pack.done_valid)
          $fatal(1,"Unowned shared resource or premature ownership release");
      end
      if(fault_o)$fatal(1,"Full-KeyGen fault run%0d core%0d encoder%0d",current,dut.core.state,dut.core.encoder.state);
      if(row_result_valid_o || read_ready_o)$fatal(1,"Full-key mode exposed polynomial inspection");
      if(key_held && (!key_valid_o || key_snapshot!=={key_id_o,key_type_o,key_index_o,key_bytes_o,key_last_o,key_data_o}))
        $fatal(1,"Unstable held key word");
      key_held=key_valid_o && !key_ready_i;
      key_snapshot={key_id_o,key_type_o,key_index_o,key_bytes_o,key_last_o,key_data_o};
      if(raw_held && (!dut.core.encoder.raw_input_valid_o || raw_snapshot!==dut.core.encoder.raw_input_data_o))
        $fatal(1,"Unstable held public-key hash word");
      raw_held=dut.core.encoder.raw_input_valid_o && !dut.core.encoder.raw_input_ready_i;
      raw_snapshot=dut.core.encoder.raw_input_data_o;
      if(start_valid_i && start_ready_o)begin
        opened++;$fdisplay(fd,"B %0d %0d %0d %0d %064h",current,start_op_i,start_param_i,start_id_i,start_seed_i);
      end
      if(key_valid_o && key_ready_i)begin
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %0d %016h",current,key_id_o,key_type_o,key_index_o,key_bytes_o,key_last_o,key_data_o);host_words++;
      end
      if(dut.core.encoder.raw_valid_o && dut.core.encoder.raw_ready_i)
        $fdisplay(fd,"H %0d %0d %0d %0d %0d %0d",current,dut.core.encoder.raw_id_o,dut.core.encoder.raw_core_i,
          dut.core.encoder.raw_mode_o,dut.core.encoder.raw_message_len_o,dut.core.encoder.raw_output_len_o);
      if(dut.core.encoder.raw_input_valid_o && dut.core.encoder.raw_input_ready_i)begin
        $fdisplay(fd,"I %0d %016h",current,dut.core.encoder.raw_input_data_o);hash_words++;
      end
      if(dut.core.encoder.raw_output_valid_i && dut.core.encoder.raw_output_ready_o)begin
        $fdisplay(fd,"T %0d %0d %0d %0d %032h",current,dut.core.encoder.raw_output_id_i,dut.core.encoder.raw_output_core_i,
          dut.core.encoder.raw_output_bytes_i,dut.core.encoder.raw_output_data_i);tr_bytes+=16;
      end
      if(dut.core.encoder.raw_done_valid_i && dut.core.encoder.raw_done_ready_o)
        $fdisplay(fd,"HD %0d %0d %0d",current,dut.core.encoder.raw_done_id_i,dut.core.encoder.raw_done_core_i);
      if(dut.core.encoder.response_valid_i && dut.core.encoder.response_ready_o)begin
        $fdisplay(fd,"M %0d %0d %0d %0d %0d %0d %0d %0d %0d",current,dut.core.encoder.section_r,
          dut.core.encoder.poly_r,dut.core.encoder.word_r,dut.core.encoder.response_region_i,
          dut.core.encoder.response_id_i,dut.core.encoder.response_param_i,dut.core.encoder.response_mode_i,
          dut.core.encoder.response_domain_i);read_words++;
      end
      if(dut.services.datapath.subsystem.store.release_fire)
        $fdisplay(fd,"L %0d %0d",current,{dut.services.datapath.subsystem.store.release_bank_i,dut.services.datapath.subsystem.store.release_region_i});
      if(done_valid_o && done_ready_i)begin
        $fdisplay(fd,"D %0d %0d %0d",current,done_code_o,done_id_o);
        if(done_code_o==0)complete++;else rejected++;
      end
      if(dut.core.encode_active && dut.core.encoder.pk_phase)begin
        if(dut.core.encoder.host_sent_r && !dut.core.encoder.hash_sent_r)host_ahead++;
        if(dut.core.encoder.hash_sent_r && !dut.core.encoder.host_sent_r)hash_ahead++;
      end
    end
  end
  task automatic reset_all();
    rst=1;start_valid_i=0;done_ready_i=0;$fdisplay(fd,"X");
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved_o || complete_o || busy_o || fault_o || key_valid_o || done_valid_o)$fatal(1,"Full-KeyGen reset state");
  endtask
  task automatic run_case(input int c);
    @(negedge clk);current=c;start_op_i=2'(ops[c]);start_param_i=2'(params[c]);start_id_i=16'(ids[c]);start_seed_i=seeds[c];start_valid_i=1;
    do @(posedge clk);while(!start_ready_o);@(negedge clk);start_valid_i=0;
    if(abort_at[c]>=0)begin
      case(abort_at[c])
        0:do @(negedge clk);while(!dut.core.encoder.hash_sent_r || dut.core.encoder.host_sent_r || !key_valid_o);
        1:do @(negedge clk);while(!key_valid_o || key_type_o || key_index_o!=13);
        2:do @(negedge clk);while(dut.core.encoder.tr_count_r!=1);
        3:do @(negedge clk);while(!key_valid_o || !key_type_o || key_index_o!=20);
        4:do @(negedge clk);while(!done_valid_o);
      endcase
      $fdisplay(fd,"A %0d %0d %0d %0d",c,abort_at[c],dut.core.encoder.host_sent_r,dut.core.encoder.hash_sent_r);
      aborted++;reset_all();return;
    end
    do @(negedge clk);while(!done_valid_o);
    if(done_code_o!==(ops[c]!=0?3'd2:(params[c]==3?3'd1:3'd0)) || done_id_o!=ids[c])$fatal(1,"Full-KeyGen completion identity");
    repeat(4)begin @(negedge clk);if(!done_valid_o || start_ready_o || key_valid_o)$fatal(1,"Held full-KeyGen completion");end
    done_ready_i=1;@(posedge clk);@(negedge clk);done_ready_i=0;
    do @(negedge clk);while(!start_ready_o);
    if(reserved_o || complete_o)$fatal(1,"Full-KeyGen cleanup leak");
    $fdisplay(fd,"CLEAN %0d",c);
    if(NIST_VECTORS)$display("NIST KeyGen case%0d/%0d level-code%0d PASS capture",c+1,CASE_COUNT,params[c]);
  endtask
  initial begin
    int f,count,index;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    stem=NIST_VECTORS?"stage5_nist_keygen":"stage5_full_keygen";
    f=$fopen({directory,"/",stem,"_inputs.txt"},"r");
    if(!f || $fscanf(f,"%s %d",token,count)!=2 || count!=CASE_COUNT)$fatal(1,"Prepare full-KeyGen inputs");
    for(int c=0;c<count;c++)if($fscanf(f,"%d %d %d %d %d %h",index,ops[c],params[c],ids[c],abort_at[c],seeds[c])!=6 || index!=c)$fatal(1,"Full-KeyGen fixture");
    $fclose(f);fd=$fopen({directory,"/",stem,"_outputs.txt"},"w");
    if(!fd)$fatal(1,"Cannot open full-KeyGen capture");
    $fdisplay(fd,"H %s",token);reset_all();
    for(int c=0;c<count;c++)run_case(c);
    if(opened!=CASE_COUNT || complete!=(NIST_VECTORS?75:8) || rejected!=(NIST_VECTORS?0:3) ||
      aborted!=(NIST_VECTORS?0:5) || host_ahead==0 || hash_ahead==0)$fatal(1,"Full-KeyGen campaign gate");
    if(owner_active_cycles==0 || owner_cleanup_cycles==0 || owner_idle_cycles==0)$fatal(1,"Missing main ownership phases");
    $fdisplay(fd,"Q %0d %0d %0d",owner_active_cycles,owner_cleanup_cycles,owner_idle_cycles);
    $fdisplay(fd,"G %0d %0d",host_ahead,hash_ahead);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d",complete,rejected,aborted,host_words,hash_words,tr_bytes,read_words);
    $fclose(fd);
    $display("%s_CAPTURE_PASS:%0d complete,%0d rejects,%0d resets;host%0d hash%0d tr%0d reads%0d",stem,complete,rejected,aborted,host_words,hash_words,tr_bytes,read_words);
    test_passed=1;$finish;
  end
  initial begin #(64'd1000000000000);if(!test_passed)$fatal(1,"Full-KeyGen watchdog run%0d core%0d encoder%0d",current,dut.core.state,dut.core.encoder.state);end
endmodule
