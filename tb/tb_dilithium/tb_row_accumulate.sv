`timescale 1ps/1ps
module tb_row_accumulate #(parameter bit SEED_SOURCE=0);
  logic clk=0,rst=1;always begin #3378 clk=1;#3379 clk=0;end
  logic manual_job_valid_i=0,job_ready_o,job_core_o;logic [5:0] job_slot_o;logic [1:0] manual_job_bank_i=0;logic [3:0] manual_job_region_i=0;assign job_slot_o={manual_job_bank_i,manual_job_region_i};
  logic [15:0] manual_job_id_i=0,manual_message_len_i=0;logic [1:0] manual_job_mode_i=0,manual_job_param_i=0;
  logic [63:0] manual_input_data_i=0;logic manual_input_valid_i=0,input_ready_o;
  logic status_valid_o,status_core_o,manual_status_ready_i=0;logic [15:0] status_id_o;logic [2:0] status_code_o;
  logic [1:0] active_o;logic read_valid_i=0,read_ready_o,response_valid_o,response_error_o;
  logic [5:0] read_slot_i=0,response_slot_o;logic [7:0] read_index_i=0,response_index_o;
  logic [1:0] read_bank_i=0,response_bank_o;logic [3:0] read_region_i=0,response_region_o;
  logic [5:0] read_word_i=0,response_word_o;logic [91:0] response_data_o;
  logic [15:0] response_id_o;logic [1:0] response_mode_o,response_param_o;
  logic response_ntt_domain_o,response_small_o,response_ready_i=0;
  logic release_valid_i=0,release_ready_o;logic [5:0] release_slot_i=0;
  logic [1:0] release_bank_i=0;logic [3:0] release_region_i=0;

  assign response_slot_o={response_bank_o,response_region_o};assign response_index_o={2'd0,response_word_o};

  logic [63:0] reserved_o,complete_o;logic fault_o;
  logic op_valid_i=0,op_ready_o,op_busy_o;logic [1:0] op_i=0;
  logic [5:0] op_a_slot_i=0,op_b_slot_i=0,op_dest_region_i=0;
  wire [5:0] op_a_region_i=op_a_slot_i,op_b_region_i=op_b_slot_i;
  logic [15:0] op_a_id_i=0,op_b_id_i=0,op_id_i=0;
  logic op_done_valid_o,op_done_ready_i=0;logic [2:0] op_done_code_o;
  logic [15:0] op_done_id_o;logic [5:0] op_done_region_o;
  wire [5:0] op_done_slot_o=op_done_region_o;

  logic process_valid_i=0,process_ready_o,process_busy_o;
  logic process_inplace_i=0;
  logic [1:0] process_op_i=0;logic [5:0] process_a_i=0,process_b_i=0,process_dest_i=0,process_high_i=0;
  logic [15:0] process_a_id_i=0,process_b_id_i=0,process_id_i=0;
  logic process_done_valid_o,process_done_ready_i=0;logic [2:0] process_done_code_o;
  logic [15:0] process_done_id_o;logic [5:0] process_done_dest_o,process_done_high_o;
  logic row_valid_i=0,row_ready_o,row_busy_o;logic [1:0] row_param_i=0;logic [3:0] row_index_i=0;
  logic [15:0] row_id_i=0;logic [5:0] row_acc_i=16,row_scratch_i=17,row_result_i=18;
  logic [6:0][5:0] row_a_i=0,row_s_i=0;logic [6:0][15:0] row_a_id_i=0,row_s_id_i=0;
  logic row_done_valid_o,row_done_ready_i=0;logic [2:0] row_done_code_o,row_completed_terms_o;
  logic [15:0] row_done_id_o;logic [5:0] row_done_region_o;

  logic command_valid_i=0,command_ready_o,done_valid_o,done_ready_i=0;
  logic [1:0] command_op_i=0,command_param_i=0,seed_param_o;
  logic [15:0] command_id_i=0,command_nonce_i=0,done_id_o;
  logic [7:0] command_row_i=0,command_column_i=0;
  logic [255:0] command_seed_i=0,rho_o,key_o;logic [511:0] rhoprime_o;
  logic [5:0] command_region_i=0;logic [2:0] done_code_o;logic seed_valid_o;
  logic [255:0] xi[3];int source_param=-1,source_commands=0;
  logic raw_valid_i,raw_ready_o,raw_core_o,raw_mode_i,raw_input_valid_i,raw_input_ready_o;
  logic [15:0] raw_id_i,raw_message_len_i,raw_output_len_i,raw_output_id_o,raw_done_id_o;
  logic [63:0] raw_input_data_i;logic [127:0] raw_output_data_o;
  logic [4:0] raw_output_bytes_o;
  logic raw_output_valid_o,raw_output_core_o,raw_output_ready_i,raw_done_valid_o,raw_done_core_o,raw_done_ready_i;
  logic source_job_valid,source_input_valid,source_status_ready;
  logic [1:0] source_job_bank,source_job_mode,source_job_param;
  logic [3:0] source_job_region;logic [15:0] source_job_id,source_message_len;
  logic [63:0] source_input_data;
  wire job_valid_i=SEED_SOURCE?source_job_valid:manual_job_valid_i;
  wire [1:0] job_bank_i=SEED_SOURCE?source_job_bank:manual_job_bank_i;
  wire [3:0] job_region_i=SEED_SOURCE?source_job_region:manual_job_region_i;
  wire [1:0] job_mode_i=SEED_SOURCE?source_job_mode:manual_job_mode_i;
  wire [1:0] job_param_i=SEED_SOURCE?source_job_param:manual_job_param_i;
  wire [15:0] job_id_i=SEED_SOURCE?source_job_id:manual_job_id_i;
  wire [15:0] message_len_i=SEED_SOURCE?source_message_len:manual_message_len_i;
  wire [63:0] input_data_i=SEED_SOURCE?source_input_data:manual_input_data_i;
  wire input_valid_i=SEED_SOURCE?source_input_valid:manual_input_valid_i;
  wire status_ready_i=SEED_SOURCE?source_status_ready:manual_status_ready_i;
  keccak_sampler_row #(.RAW_SERVICE(SEED_SOURCE)) dut(.sign_i('0),.sign_o(),.*);
  generate if(SEED_SOURCE)begin:seed_path
    keygen_sample_source source(
      .clk(clk),.rst(rst),.command_valid_i(command_valid_i),.command_ready_o(command_ready_o),
      .command_op_i(command_op_i),.command_param_i(command_param_i),.command_id_i(command_id_i),
      .command_nonce_i(command_nonce_i),.command_row_i(command_row_i),.command_column_i(command_column_i),
      .command_seed_i(command_seed_i),.command_region_i(command_region_i),
      .done_valid_o(done_valid_o),.done_ready_i(done_ready_i),.done_code_o(done_code_o),.done_id_o(done_id_o),
      .seed_valid_o(seed_valid_o),.seed_param_o(seed_param_o),.rho_o(rho_o),.key_o(key_o),.rhoprime_o(rhoprime_o),
      .job_valid_o(source_job_valid),.job_ready_i(job_ready_o),.job_core_i(job_core_o),
      .job_bank_o(source_job_bank),.job_region_o(source_job_region),.job_mode_o(source_job_mode),.job_param_o(source_job_param),
      .job_id_o(source_job_id),.message_len_o(source_message_len),.input_data_o(source_input_data),
      .input_valid_o(source_input_valid),.input_ready_i(input_ready_o),
      .status_valid_i(status_valid_o),.status_core_i(status_core_o),.status_id_i(status_id_o),.status_code_i(status_code_o),
      .status_ready_o(source_status_ready),
      .raw_valid_o(raw_valid_i),.raw_ready_i(raw_ready_o),.raw_core_i(raw_core_o),.raw_mode_o(raw_mode_i),
      .raw_id_o(raw_id_i),.raw_message_len_o(raw_message_len_i),.raw_output_len_o(raw_output_len_i),
      .raw_input_data_o(raw_input_data_i),.raw_input_valid_o(raw_input_valid_i),.raw_input_ready_i(raw_input_ready_o),
      .raw_output_valid_i(raw_output_valid_o),.raw_output_core_i(raw_output_core_o),.raw_output_id_i(raw_output_id_o),
      .raw_output_data_i(raw_output_data_o),.raw_output_bytes_i(raw_output_bytes_o),.raw_output_ready_o(raw_output_ready_i),
      .raw_done_valid_i(raw_done_valid_o),.raw_done_core_i(raw_done_core_o),.raw_done_id_i(raw_done_id_o),.raw_done_ready_o(raw_done_ready_i)
    );
    always @(posedge clk)if(!rst)begin
      if(command_valid_i && command_ready_o)begin
        source_commands++;
        $fdisplay(fd,"SC %0d %0d %0d %0d %0d %0d %0d %064h",command_op_i,command_param_i,command_id_i,command_nonce_i,command_row_i,command_column_i,command_region_i,command_seed_i);
      end
      if(raw_valid_i && raw_ready_o)$fdisplay(fd,"SR %0d %0d %0d %0d %0d",raw_id_i,raw_core_o,raw_mode_i,raw_message_len_i,raw_output_len_i);
      if(raw_input_valid_i && raw_input_ready_o)$fdisplay(fd,"SI %016h",raw_input_data_i);
      if(raw_output_valid_o && raw_output_ready_i)$fdisplay(fd,"SO %0d %0d %0d %032h",raw_output_id_o,raw_output_core_o,raw_output_bytes_o,raw_output_data_o);
      if(raw_done_valid_o && raw_done_ready_i)$fdisplay(fd,"SE %0d %0d",raw_done_id_o,raw_done_core_o);
      if(input_valid_i && input_ready_o)$fdisplay(fd,"SF %016h",input_data_i);
      if(done_valid_o && done_ready_i)$fdisplay(fd,"SD %0d %0d %0d %0d %064h %0128h %064h",done_id_o,done_code_o,seed_valid_o,seed_param_o,rho_o,rhoprime_o,key_o);
    end
  end else begin:legacy_path
    assign raw_valid_i=0;assign raw_mode_i=0;assign raw_id_i=0;assign raw_message_len_i=0;assign raw_output_len_i=0;
    assign raw_input_data_i=0;assign raw_input_valid_i=0;assign raw_output_ready_i=0;assign raw_done_ready_i=0;
  end endgenerate
  task automatic source_command(input int op,p,jid,nonce,row,col,region,code);
    logic [1026:0] held;
    @(negedge clk);command_op_i=2'(op);command_param_i=2'(p);command_id_i=16'(jid);
    command_nonce_i=16'(nonce);command_row_i=8'(row);command_column_i=8'(col);
    command_region_i=6'(region);command_seed_i=p<3?xi[p]:256'd0;command_valid_i=1;
    do @(posedge clk);while(!command_ready_o);@(negedge clk);command_valid_i=0;
    do @(negedge clk);while(!done_valid_o);
    if(done_id_o!==16'(jid) || done_code_o!==3'(code))$fatal(1,"Seed source completion op%0d code%0d expected%0d",op,done_code_o,code);
    held={seed_valid_o,seed_param_o,rho_o,rhoprime_o,key_o};
    repeat(4)begin
      @(negedge clk);
      if(command_ready_o || !done_valid_o || held!=={seed_valid_o,seed_param_o,rho_o,rhoprime_o,key_o})$fatal(1,"Seed source held completion");
    end
    done_ready_i=1;@(posedge clk);@(negedge clk);done_ready_i=0;
  endtask

  int fixture_row[48],fixture_col[48];
  int ids[48],modes[48],params[48],lengths[48],secret_case[3][7],matrix_case[3][2][7];
  byte unsigned messages[48][$];string directory,token;
  int fd,step_no=-1,current_sample=0,cycles=0,ntt_seen=0,seen=0,row_run=-1;
  int samples=0,ntts=0,processes=0,row_good=0,row_bad=0,row_aborts=0,values=0,words=0,reads=0;
  int held_checks=0,read_checks=0,current_abort=-1;
  bit lower_live=0,row_live=0,test_passed=0;
  always @(negedge clk)manual_status_ready_i<=!rst && cycles%23>4;
  always @(posedge clk)begin
    cycles++;
    if(!rst)begin
      if(fault_o)$fatal(1,"Bank process fault NTTstate%0d processstate%0d",dut.subsystem.state,dut.subsystem.process_client.state);

      if(job_valid_i && job_ready_o)begin
        step_no++;lower_live=1;
        $fdisplay(fd,"J %0d %0d %0d %0d %0d",step_no,current_sample,job_core_o,{job_bank_i,job_region_i},job_id_i);samples++;
      end
      if(dut.subsystem.op_valid_i && dut.subsystem.op_ready_o)begin
        step_no++;lower_live=1;ntt_seen=0;
        $fdisplay(fd,"O %0d %0d %0d %0d %0d %0d %0d %0d",step_no,dut.subsystem.op_i,dut.subsystem.op_a_region_i,dut.subsystem.op_b_region_i,dut.subsystem.op_dest_region_i,dut.subsystem.op_a_id_i,dut.subsystem.op_b_id_i,dut.subsystem.op_id_i);ntts++;
      end
      if(dut.subsystem.process_valid_i && dut.subsystem.process_ready_o)begin
        step_no++;lower_live=1;seen=0;
        $fdisplay(fd,"C %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",step_no,dut.subsystem.process_op_i,dut.subsystem.process_a_i,dut.subsystem.process_b_i,dut.subsystem.process_dest_i,dut.subsystem.process_high_i,dut.subsystem.process_a_id_i,dut.subsystem.process_b_id_i,dut.subsystem.process_id_i,dut.subsystem.process_inplace_i);processes++;
      end
      if(dut.subsystem.store.alloc_fire)$fdisplay(fd,"V %0d %0d %0d %0d %0d %0d %0d",step_no,dut.subsystem.store.alloc_core_i,
        {dut.subsystem.store.alloc_bank_i,dut.subsystem.store.alloc_region_i},dut.subsystem.store.alloc_id_i,dut.subsystem.store.alloc_mode_i,dut.subsystem.store.alloc_param_i,
        dut.subsystem.store.alloc_compute_i?dut.subsystem.store.alloc_ntt_domain_i:dut.subsystem.store.alloc_mode_i==0);
      if(dut.subsystem.store.write_fire)begin
        $fdisplay(fd,"W %0d %0d %0d %06h %0d",step_no,dut.subsystem.store.write_core_i,dut.subsystem.store.write_index_i,dut.subsystem.store.write_data_i,dut.subsystem.store.write_last_i);values++;
      end
      if(dut.subsystem.store.finish_fire)$fdisplay(fd,"U %0d %0d",step_no,dut.subsystem.store.finish_core_i);
      for(int bank=0;bank<4;bank++)begin
        if(dut.subsystem.store.request_valid[0][bank] && dut.subsystem.store.request_ready[0][bank])begin
          $fdisplay(fd,"P %0d %0d %0d %023h",step_no,16*bank+int'(dut.subsystem.store.request_address[0][bank][9:6]),
            dut.subsystem.store.request_address[0][bank][5:0],dut.subsystem.store.request_data[0][bank]);words++;
        end
        if(dut.subsystem.store.response_valid[0][bank] && dut.subsystem.store.response_ready[0][bank])
          $fdisplay(fd,"Q %0d %0d %0d",step_no,16*bank+int'(dut.subsystem.store.response_address[0][bank][9:6]),dut.subsystem.store.response_address[0][bank][5:0]);
      end
      if(status_valid_o && status_ready_i)begin $fdisplay(fd,"S %0d %0d %0d",step_no,status_id_o,status_code_o);lower_live=0;end
      if(dut.subsystem.s_valid && dut.subsystem.s_ready)$fdisplay(fd,"T %0d %0d %0d %06h",step_no,dut.subsystem.source_region,{dut.subsystem.load_word_r,dut.subsystem.lane_r},dut.subsystem.s_data);
      if(dut.subsystem.m_valid && dut.subsystem.m_ready)begin $fdisplay(fd,"N %0d %0d %06h %0d",step_no,ntt_seen,dut.subsystem.m_data,dut.subsystem.m_last);ntt_seen++;end
      if(dut.subsystem.process_client.state==8 && dut.subsystem.process_client.pp_ready)begin
        $fdisplay(fd,"I %0d %0d %06h %06h",step_no,dut.subsystem.process_client.index,
          dut.subsystem.process_client.arithmetic.input_a_i,dut.subsystem.process_client.arithmetic.input_b_i);seen++;
      end
      if(dut.subsystem.process_client.pp_valid && dut.subsystem.process_client.pp_accept)
        $fdisplay(fd,"K %0d %0d %0d %0d %0d %06h %0d %0d %0d %0d",step_no,dut.subsystem.process_client.pp_index,
          dut.subsystem.process_client.pp_error,dut.subsystem.process_client.pp_op,dut.subsystem.process_client.pp_id,dut.subsystem.process_client.pp_residue,
          dut.subsystem.process_client.pp_high,$signed(dut.subsystem.process_client.pp_low),dut.subsystem.process_client.pp_t0,dut.subsystem.process_client.pp_last);
      if(dut.subsystem.op_done_valid_o && dut.subsystem.op_done_ready_i)begin
        $fdisplay(fd,"D %0d N %0d %0d %0d 0",step_no,op_done_code_o,op_done_id_o,op_done_region_o);lower_live=0;
      end
      if(dut.subsystem.process_done_valid_o && dut.subsystem.process_done_ready_i)begin
        $fdisplay(fd,"D %0d P %0d %0d %0d %0d",step_no,process_done_code_o,process_done_id_o,process_done_dest_o,process_done_high_o);lower_live=0;
      end
      if(dut.subsystem.process_busy_o && dut.subsystem.process_client.state==7 && dut.subsystem.mem_response_valid)
        $fdisplay(fd,"M %0d %0d %0d %023h %0d %0d",step_no,{response_bank_o,response_region_o},response_word_o,response_data_o,
          response_id_o,dut.subsystem.store.count_r[{response_bank_o,response_region_o}]);
      if(dut.subsystem.store.release_fire)$fdisplay(fd,"L %0d %0d",{dut.subsystem.store.release_bank_i,dut.subsystem.store.release_region_i},row_busy_o);
      if(row_busy_o && (job_ready_o || op_ready_o || process_ready_o || read_ready_o || release_ready_o || row_ready_o))$fatal(1,"Row lost exclusive ownership");
      if(row_valid_i && row_ready_o)begin
        row_run++;row_live=1;
        $fwrite(fd,"B %0d %0d %0d %0d %0d %0d %0d",row_run,row_param_i,row_index_i,row_acc_i,row_scratch_i,row_result_i,row_id_i);
        for(int j=0;j<7;j++)$fwrite(fd," %0d %0d %0d %0d",row_a_i[j],row_a_id_i[j],row_s_i[j],row_s_id_i[j]);
        $fdisplay(fd,"");
      end
      if(row_done_valid_o && row_done_ready_i)begin
        $fdisplay(fd,"DROW %0d %0d %0d %0d %0d",row_run,row_done_code_o,row_done_id_o,row_done_region_o,row_completed_terms_o);
        if(row_done_code_o==0)row_good++;else row_bad++;row_live=0;
      end
    end
  end

  task automatic reset_all();
    command_valid_i=0;done_ready_i=0;source_param=-1;
    if(lower_live)begin $fdisplay(fd,"A %0d",step_no);lower_live=0;end
    if(row_live)begin $fdisplay(fd,"Z %0d %0d",row_run,current_abort);row_live=0;row_aborts++;end
    $fdisplay(fd,"X");rst=1;manual_job_valid_i=0;manual_input_valid_i=0;op_valid_i=0;process_valid_i=0;row_valid_i=0;
    read_valid_i=0;response_ready_i=0;release_valid_i=0;op_done_ready_i=0;process_done_ready_i=0;row_done_ready_i=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;@(negedge clk);
    if(reserved_o || complete_o || row_busy_o || process_busy_o || op_busy_o || response_valid_o || row_done_valid_o || fault_o)$fatal(1,"Row reset ownership");
  endtask
  function automatic int columns(input int p);return p==0?4:(p==1?5:7);endfunction
  task automatic forward_secret(input int c,j);
    @(negedge clk);op_i=(j%2==0)?2'd3:2'd0;op_a_slot_i=6'(1+j);op_b_slot_i=6'(1+j);op_dest_region_i=6'(32+j);
    op_a_id_i=16'(ids[c]);op_b_id_i=16'(ids[c]);op_id_i=16'(3000+c);op_valid_i=1;
    do @(posedge clk);while(!op_ready_o);@(negedge clk);op_valid_i=0;
    do @(negedge clk);while(!op_done_valid_o);
    if(op_done_code_o!=0)$fatal(1,"Secret transform failed");op_done_ready_i=1;
    @(posedge clk);@(negedge clk);op_done_ready_i=0;
  endtask
  task automatic setup_secrets(input int p);
    for(int j=0;j<columns(p);j++)begin sample_job(secret_case[p][j],1+j,ids[secret_case[p][j]]);forward_secret(secret_case[p][j],j);end
  endtask
  task automatic setup_matrix(input int p,row);
    for(int j=0;j<columns(p);j++)sample_job(matrix_case[p][row][j],48+j,ids[matrix_case[p][row][j]]);
  endtask
  task automatic read_sources(input int p);
    for(int j=0;j<columns(p);j++)begin read_region(1+j,0);read_region(32+j,0);read_region(48+j,0);end
  endtask
  task automatic run_row(input int p,row,variant=-1,abortphase=-1);
    int code;code=0;current_abort=abortphase;
    @(negedge clk);row_param_i=2'(p);row_index_i=4'(row);row_id_i=16'(5000+16*p);
    row_acc_i=16;row_scratch_i=17;row_result_i=18;row_a_i=0;row_s_i=0;row_a_id_i=0;row_s_id_i=0;
    for(int j=0;j<columns(p);j++)begin
      row_a_i[j]=6'(48+j);row_a_id_i[j]=16'(ids[matrix_case[p][row][j]]);
      row_s_i[j]=6'(32+j);row_s_id_i[j]=16'(3000+secret_case[p][j]);
    end
    case(variant)
      0:begin row_param_i=3;code=4;end
      1:begin row_index_i=4'(p==0?4:(p==1?6:8));code=4;end
      2:begin row_acc_i=48;code=3;end
      3:begin row_acc_i=1;code=3;end
      4:begin row_a_id_i[0]=row_a_id_i[0]^16'd1;code=1;end
      5:begin row_s_id_i[0]=row_s_id_i[0]^16'd1;code=1;end
      6:begin row_a_i[0]=62;row_a_id_i[0]=16'(ids[matrix_case[(p+1)%3][0][0]]);code=2;end
      7:begin row_s_i[0]=1;row_s_id_i[0]=16'(ids[secret_case[p][0]]);code=2;end
      8:begin row_a_i[0]=61;row_a_id_i[0]=0;code=1;end
      default:;
    endcase
    row_valid_i=1;do @(posedge clk);while(!row_ready_o);@(negedge clk);row_valid_i=0;
    if(abortphase>=0)begin
      case(abortphase)
        0:do @(negedge clk);while(dut.controller.state!=2);
        1:do @(negedge clk);while(dut.controller.state!=4 || dut.subsystem.engine.u_core.state!=2);
        2:do @(negedge clk);while(dut.controller.state!=3 || dut.controller.column_r!=1);
        3:do @(negedge clk);while(!dut.subsystem.process_busy_o || dut.subsystem.process_client.state!=9 || dut.subsystem.process_client.index!=8);
        4:do @(negedge clk);while(dut.controller.state!=7);
        5:do @(negedge clk);while(dut.controller.state!=9 || dut.subsystem.engine.u_core.state!=2);
        6:do @(negedge clk);while(!row_done_valid_o);
      endcase
      $display("ROW_RESET_TARGET:%0d terms%0d rowstate%0d",abortphase,row_completed_terms_o,dut.controller.state);
      reset_all();
    end else begin
      do @(negedge clk);while(!row_done_valid_o);
      if(row_done_code_o!==3'(code) || row_done_id_o!==row_id_i || row_done_region_o!==row_result_i ||
         row_completed_terms_o!==3'(code==0?columns(p):0))$fatal(1,"Row retirement metadata/code");
      if(code==0 && (!complete_o[18] || reserved_o[16] || reserved_o[17]))$fatal(1,"Row temporary lifecycle");
      release_valid_i=1;{release_bank_i,release_region_i}=row_result_i;op_valid_i=1;process_valid_i=1;read_valid_i=1;manual_job_valid_i=1;
      repeat(4)begin @(negedge clk);if(release_ready_o || op_ready_o || process_ready_o || read_ready_o || job_ready_o)$fatal(1,"Held row released/reused");held_checks++;end
      release_valid_i=0;op_valid_i=0;process_valid_i=0;read_valid_i=0;manual_job_valid_i=0;
      row_done_ready_i=1;@(posedge clk);@(negedge clk);row_done_ready_i=0;
    end
  endtask
  task automatic sample_job(input int c,region,jobid);
    int n,pos;logic [63:0] data;
    if(SEED_SOURCE)begin
      current_sample=c;
      if(source_param!=params[c])begin
        source_command(0,params[c],6000+params[c],0,0,0,0,0);source_param=params[c];
      end
      source_command(modes[c]==0?1:2,params[c],jobid,fixture_col[c],fixture_row[c],fixture_col[c],region,0);
      return;
    end
    @(negedge clk);current_sample=c;manual_job_mode_i=2'(modes[c]);manual_job_param_i=2'(params[c]);manual_job_id_i=16'(jobid);
    {manual_job_bank_i,manual_job_region_i}=6'(region);manual_message_len_i=16'(lengths[c]);manual_job_valid_i=1;
    do @(posedge clk);while(!job_ready_o);@(negedge clk);manual_job_valid_i=0;pos=0;
    while(pos<lengths[c])begin
      n=lengths[c]-pos;if(n>8)n=8;data='1;
      for(int b=0;b<n;b++)data[8*b+:8]=messages[c][pos+b];
      manual_input_data_i=data;manual_input_valid_i=1;do @(posedge clk);while(!input_ready_o);
      @(negedge clk);manual_input_valid_i=0;pos+=n;
    end
    do @(negedge clk);while(active_o!=0);
  endtask
  task automatic read_region(input int region,invalid);
    for(int wordno=0;wordno<(invalid?1:64);wordno++)begin
      @(negedge clk);{read_bank_i,read_region_i}=6'(region);read_word_i=6'(wordno);read_valid_i=1;
      do @(posedge clk);while(!read_ready_o);@(negedge clk);read_valid_i=0;
      // Offer and cancel a competing process command while the response owns the port.
      if(read_checks==0)begin
        row_valid_i=1;repeat(4)begin @(negedge clk);if(row_ready_o)$fatal(1,"Row stole pending public read");read_checks++;end
        row_valid_i=0;
      end
      do @(negedge clk);while(!response_valid_o);
      if(response_error_o!==1'(invalid) || {response_bank_o,response_region_o}!==6'(region) || response_word_o!==6'(wordno))$fatal(1,"Read response tag");
      if(invalid)$fdisplay(fd,"E %0d %0d",step_no,region);
      else begin
        $fdisplay(fd,"R %0d %0d %0d %023h %0d %0d %0d %0d %0d",step_no,region,wordno,response_data_o,
          response_id_o,response_mode_o,response_param_o,response_ntt_domain_o,response_small_o);reads++;
      end
      repeat(wordno%3)@(negedge clk);response_ready_i=1;@(posedge clk);@(negedge clk);response_ready_i=0;
    end
  endtask
  task automatic release_region(input int region);
    @(negedge clk);{release_bank_i,release_region_i}=6'(region);release_valid_i=1;
    do @(posedge clk);while(!release_ready_o);
    @(negedge clk);release_valid_i=0;
  endtask
  initial begin
    int f,count,idx,row,col,parsed;string hex_message;byte unsigned octet;
    if(!$value$plusargs("STAGE2_DIR=%s",directory))directory=".";
    f=$fopen({directory,"/stage5_row_samples.txt"},"r");
    if(!f || $fscanf(f,"%s %d",token,count)!=2 || count!=48)$fatal(1,"Prepare row samples");
    for(int i=0;i<48;i++)begin
      if($fscanf(f,"%d %d %d %d %d %d %d %s",idx,ids[i],modes[i],params[i],row,col,lengths[i],hex_message)!=8 || idx!=i)$fatal(1,"Row sample file");
      fixture_row[i]=row;fixture_col[i]=col;
      if(modes[i]==1)secret_case[params[i]][col]=i;else matrix_case[params[i]][row][col]=i;
      for(int k=0;k<lengths[i];k++)begin parsed=$sscanf(hex_message.substr(2*k,2*k+1),"%h",octet);if(parsed!=1)$fatal(1,"Row byte");messages[i].push_back(octet);end
    end
    $fclose(f);
    if(SEED_SOURCE)begin
      f=$fopen({directory,"/stage5_seed_inputs.txt"},"r");
      if(!f || $fscanf(f,"%s %d",token,count)!=2 || count!=3)$fatal(1,"Prepare seed inputs");
      for(int p=0;p<3;p++)if($fscanf(f,"%d %h",idx,xi[p])!=2 || idx!=p)$fatal(1,"Seed file");
      $fclose(f);
    end
    fd=$fopen({directory,SEED_SOURCE?"/stage5_seed_row_outputs.txt":"/stage5_row_outputs.txt"},"w");if(!fd)$fatal(1,"Row capture");$fdisplay(fd,"H %s",token);
    @(negedge clk);reset_all();
    if(SEED_SOURCE)begin
      source_command(2,0,6100,0,0,0,1,1);
      source_command(3,0,6101,0,0,0,1,3);
      source_command(0,3,6102,0,0,0,0,3);
      source_command(0,0,6103,0,0,0,0,0);source_param=0;
      source_command(2,1,6104,0,0,0,1,2);
      source_command(2,0,6105,8,0,0,1,3);
      source_command(1,0,6106,0,4,0,48,3);
      source_command(1,0,6107,0,0,4,48,3);
    end
    for(int p=0;p<3;p++)begin
      setup_secrets(p);setup_matrix(p,0);run_row(p,0);read_region(18,0);read_sources(p);release_region(18);
      for(int j=0;j<columns(p);j++)release_region(48+j);
      setup_matrix(p,1);sample_job(matrix_case[(p+1)%3][0][0],62,ids[matrix_case[(p+1)%3][0][0]]);
      for(int v=0;v<9;v++)run_row(p,1,v);
      read_region(62,0);release_region(62);run_row(p,1);read_region(18,0);read_sources(p);
      @(negedge clk);reset_all();
    end
    for(int phase=0;phase<7;phase++)begin
      setup_secrets(0);setup_matrix(0,0);run_row(0,0,-1,phase);
      read_region(16,1);read_region(17,1);read_region(18,1);read_region(32,1);
      setup_secrets(0);setup_matrix(0,1);run_row(0,1);read_region(18,0);read_sources(0);
      @(negedge clk);reset_all();
    end
    if(row_run!=46 || row_good!=13 || row_bad!=27 || row_aborts!=7 || samples!=163 || held_checks!=160 || read_checks!=4 || reserved_o!=0)$fatal(1,"Row completion gate run%0d good%0d bad%0d abort%0d samples%0d held%0d reads%0d",row_run,row_good,row_bad,row_aborts,samples,held_checks,read_checks);
    $fdisplay(fd,"G %0d %0d",held_checks,read_checks);
    $fdisplay(fd,"F %0d %0d %0d %0d %0d %0d %0d %0d %0d",samples,ntts,processes,row_good,row_bad,row_aborts,values,words,reads);
    $fclose(fd);if(SEED_SOURCE)$display("DILITHIUM_STAGE5I_SEED_ROW_CAPTURE_PASS:commands%0d",source_commands);$display("DILITHIUM_STAGE5H_ROW_CAPTURE_PASS:13 complete rows,27 rejections,7 reset aborts;sample%0d NTT%0d ADD%0d values%0d words%0d reads%0d",samples,ntts,processes,values,words,reads);test_passed=1;$finish;
  end
  initial begin #(64'd50000000000);if(!test_passed)$fatal(1,"Row watchdog run%0d rowstate%0d childstate%0d",row_run,dut.controller.state,dut.subsystem.state);end
endmodule
