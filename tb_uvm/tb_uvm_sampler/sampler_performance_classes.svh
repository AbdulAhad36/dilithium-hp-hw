// Source-only measurements in the main UVM. A row is published only after
// scoreboard.checked_ap confirms all 256 coefficients and successful status.
`uvm_analysis_imp_decl(_perf_observed)
`uvm_analysis_imp_decl(_perf_checked)
class sampler_performance extends uvm_component;
  `uvm_component_utils(sampler_performance)
  uvm_analysis_imp_perf_observed#(sampler_item,sampler_performance) observed;
  uvm_analysis_imp_perf_checked#(sampler_item,sampler_performance) checked;
  virtual sampler_if vif;
  int clock_count,fd,rows;
  bit live[2],verified[2];
  int ids[2],modes[2],params[2],jobs[2],stalls[2];
  int start_cycle[2],first_in[2],last_in[2],first_out[2],last_out[2],stop_cycle[2];
  int stats[2][17],buckets[2][8];
  function new(string n,uvm_component p);
    super.new(n,p);observed=new("observed",this);checked=new("checked",this);
  endfunction
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual sampler_if)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface")
    fd=$fopen("sampler/performance.csv","w");
    if(fd==0)`uvm_fatal("PERF","Cannot create performance.csv")
    $fdisplay(fd,"id,scenario,mode,param,core,jobs,stalls,start_cycle,first_input_cycle,last_input_cycle,first_output_cycle,last_output_cycle,source_stop_cycle,status_cycle,latency_cycles,input_to_first_cycles,input_bytes,processed_bytes,candidates,accepted_candidates,generated_coefficients,output_coefficients,input_offered_cycles,input_blocked_cycles,output_stall_cycles,clear_cycles,shuffle_write_cycles,readout_cycles,chunk_cycles,max_collector,peak_candidates_per_cycle,peak_generated_per_cycle,peak_processed_bytes_per_cycle,exclusive_output_stall,exclusive_input_blocked,exclusive_output_transfer,exclusive_clear,exclusive_shuffle_write,exclusive_readout,exclusive_source_gap,exclusive_other");
  endfunction
  function void write_perf_checked(sampler_item t);
    if(!live[t.core] || ids[t.core]!=t.id)`uvm_fatal("PERF","Checked job not owned")
    verified[t.core]=1;
  endfunction
  function void write_perf_observed(sampler_item t);
    int c=t.core,n,delta,bucket,total,per_cycle_candidates;
    bit clear_work,shuffle_work,read_work,out_stall,in_block,out_transfer;
    string line;
    if(t.kind==EV_TICK)begin
      clock_count++;
      for(int k=0;k<2;k++)if(live[k] && last_out[k]<0 && !vif.rst)begin
        n=0;per_cycle_candidates=0;
        clear_work=vif.perf_ball_state==1 && vif.perf_ball_clear_core==k;
        shuffle_work=(vif.perf_ball_state==2 || vif.perf_ball_state==3) && vif.perf_ball_selected==k;
        read_work=vif.perf_ball_state==4 && vif.perf_ball_selected==k;
        out_stall=vif.output_valid && vif.output_core==k && !vif.output_ready;
        out_transfer=vif.output_valid && vif.output_core==k && vif.output_ready;
        in_block=vif.input_valid && vif.input_core==k && !vif.input_ready;
        if(vif.source_stop[k] && stop_cycle[k]<0)stop_cycle[k]=clock_count;
        if(vif.input_valid && vif.input_core==k)stats[k][6]++;
        if(in_block)stats[k][7]++;
        if(out_stall)stats[k][8]++;
        if(clear_work)stats[k][9]++;
        if(shuffle_work)stats[k][10]++;
        if(read_work)stats[k][11]++;
        if(vif.perf_count[k]>stats[k][13])stats[k][13]=vif.perf_count[k];
        delta=int'(vif.perf_gen_next[k])-int'(vif.perf_gen[k]);
        if(delta>0)stats[k][4]+=delta;
        // Pipelining separates extraction from collector commit. Accepted
        // coefficients are counted at commit, not on the extractor's clock.
        if(modes[k]!=3 && delta>0)stats[k][3]+=delta;
        if(vif.perf_chunk && vif.perf_hold_core==k)begin
          n=vif.perf_hold_bytes>8 ? 8:int'(vif.perf_hold_bytes);
          stats[k][1]+=n;stats[k][12]++;
          case(modes[k])
            0:per_cycle_candidates=(int'(vif.perf_res_bytes[k])+n)/3;
            1:per_cycle_candidates=2*n;
            2:per_cycle_candidates=(int'(vif.perf_res_bits[k])+8*n)/(params[k]==0 ? 18:20);
          endcase
          stats[k][2]+=per_cycle_candidates;
        end
        if(modes[k]==3 && vif.perf_ball_byte_valid && vif.perf_hold_core==k && vif.perf_ball_byte_ready)begin
          n=1;stats[k][1]++;
          if(vif.perf_ball_sign_bytes[k]>=8)begin
            per_cycle_candidates=1;stats[k][2]++;
            if(vif.perf_byte<=vif.perf_ball_position[k])stats[k][3]++;
          end
        end
        if(per_cycle_candidates>stats[k][14])stats[k][14]=per_cycle_candidates;
        if(delta>stats[k][15])stats[k][15]=delta;
        if(n>stats[k][16])stats[k][16]=n;
        // Priority partition: exactly one primary reason per latency clock.
        // Raw overlays above can overlap and must not be added as a total.
        if(out_stall)bucket=0;
        else if(in_block)bucket=1;
        else if(out_transfer)bucket=2;
        else if(clear_work)bucket=3;
        else if(shuffle_work)bucket=4;
        else if(read_work)bucket=5;
        else if(!vif.input_valid && !vif.source_stop[k])bucket=6;
        else bucket=7;
        buckets[k][bucket]++;
      end
      return;
    end
    case(t.kind)
      EV_RESET:foreach(live[k])begin
        if(live[k])`uvm_fatal("PERF","Unexpected reset during measured job")
      end
      EV_JOB:begin
        live[c]=1;verified[c]=0;ids[c]=t.id;modes[c]=t.mode;params[c]=t.param;
        jobs[c]=vif.perf_jobs;stalls[c]=int'(vif.perf_stalls);
        start_cycle[c]=clock_count;first_in[c]=-1;last_in[c]=-1;
        first_out[c]=-1;last_out[c]=-1;stop_cycle[c]=-1;
        for(int j=0;j<17;j++)stats[c][j]=0;
        for(int j=0;j<8;j++)buckets[c][j]=0;
      end
      EV_INPUT:begin
        if(first_in[c]<0)first_in[c]=clock_count;
        last_in[c]=clock_count;stats[c][0]+=t.nbytes;
      end
      EV_OUTPUT:begin
        if(first_out[c]<0)first_out[c]=clock_count;
        if(t.last)last_out[c]=clock_count;
        stats[c][5]++;
      end
      EV_STATUS:begin
        if(!verified[c] || t.code!=0 || stats[c][4]!=256 || stats[c][5]!=256)
          `uvm_fatal("PERF","Only exactly checked successful jobs may publish measurements")
        if(stats[c][1]>stats[c][0])`uvm_fatal("PERF",$sformatf("Processed more bytes than received: id%0d processed%0d received%0d",ids[c],stats[c][1],stats[c][0]))
        total=0;for(int j=0;j<8;j++)total+=buckets[c][j];
        if(total!=last_out[c]-start_cycle[c])`uvm_fatal("PERF","Exclusive cycle accounting mismatch")
        line=$sformatf("%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",ids[c],(ids[c]-2000)/2,modes[c],params[c],c,jobs[c],stalls[c],start_cycle[c],first_in[c],last_in[c],first_out[c],last_out[c],stop_cycle[c],clock_count,last_out[c]-start_cycle[c],first_out[c]-first_in[c]);
        for(int j=0;j<17;j++)line={line,$sformatf(",%0d",stats[c][j])};
        for(int j=0;j<8;j++)line={line,$sformatf(",%0d",buckets[c][j])};
        $fdisplay(fd,"%s",line);$fflush(fd);rows++;live[c]=0;
      end
      default:;
    endcase
  endfunction
  function void report_phase(uvm_phase phase);$fclose(fd);endfunction
endclass

class sampler_performance_seq extends sampler_smoke_seq;
  `uvm_object_utils(sampler_performance_seq)
  byte unsigned cached[4][3][2][$];
  function new(string n="sampler_performance_seq");super.new(n);endfunction
  task load_seed_streams();
    string token,run_id;
    int fd,rc,core,id,mode,param,nbytes,last;
    int jobs,success,errors,aborts,slot_mode[2],slot_param[2];
    bit selected[2]='{0,0};bit [127:0] data;
    fd=$fopen("../FIPS204_SAMPLER/sampler_inputs.txt","r");
    if(fd==0)`uvm_fatal("PERF_INPUT","Run Python prepare first")
    rc=$fscanf(fd,"%s %s %d %d %d %d",token,run_id,jobs,success,errors,aborts);
    if(rc!=6 || token!="H")`uvm_fatal("PERF_INPUT","Invalid input header")
    forever begin
      rc=$fscanf(fd,"%s",token);
      if(rc!=1)`uvm_fatal("PERF_INPUT","Input truncated")
      case(token)
        "J":begin
          rc=$fscanf(fd,"%d %d %d %d",core,id,mode,param);
          if(rc!=4)`uvm_fatal("PERF_INPUT","Invalid J")
          selected[core]=0;
          if(param<3 && cached[mode][param][core].size()==0)begin
            selected[core]=1;slot_mode[core]=mode;slot_param[core]=param;
          end
        end
        "B":begin
          rc=$fscanf(fd,"%d %d %d %h",core,nbytes,last,data);
          if(rc!=4)`uvm_fatal("PERF_INPUT","Invalid B")
          if(selected[core])for(int j=0;j<nbytes;j++)cached[slot_mode[core]][slot_param[core]][core].push_back(data[j*8+:8]);
        end
        "W","R":begin selected[0]=0;selected[1]=0;end
        "E":break;
        default:`uvm_fatal("PERF_INPUT","Unknown record")
      endcase
    end
    $fclose(fd);
    for(int m=0;m<4;m++)for(int p=0;p<3;p++)for(int c=0;c<2;c++)
      if(cached[m][p][c].size()==0)`uvm_fatal("PERF_INPUT","Seed stream missing")
  endtask
  task body();
    int scenario=0;
    sampler_item t;
    load_seed_streams();command(EV_RESET);
    for(int mode=0;mode<4;mode++)for(int param=0;param<3;param++)
      for(int stall=0;stall<2;stall++)for(int arrangement=0;arrangement<3;arrangement++)begin
        t=sampler_item::type_id::create("profile");start_item(t);
        t.kind=EV_PROFILE;t.value=stall;t.gap=arrangement==2 ? 2:1;finish_item(t);
        for(int core=0;core<2;core++)if(arrangement==2 || arrangement==core)
          command(EV_JOB,core,2000+2*scenario+core,mode,param);
        t=sampler_item::type_id::create("stream");start_item(t);t.kind=EV_STREAM;
        for(int core=0;core<2;core++)if(arrangement==2 || arrangement==core)t.streams[core]=cached[mode][param][core];
        finish_item(t);command(EV_WAIT);scenario++;
      end
  endtask
endclass

class sampler_performance_test extends uvm_test;
  `uvm_component_utils(sampler_performance_test)
  sampler_env env;sampler_performance metrics;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
    env=sampler_env::type_id::create("env",this);
    metrics=sampler_performance::type_id::create("metrics",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    env.monitor.timing_ap.connect(metrics.observed);
    env.scoreboard.checked_ap.connect(metrics.checked);
  endfunction
  task run_phase(uvm_phase phase);
    sampler_performance_seq seq=sampler_performance_seq::type_id::create("seq");
    phase.raise_objection(this);seq.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    if(env.scoreboard.passed!=96 || env.scoreboard.failed_jobs!=0 || metrics.rows!=96 ||
       env.scoreboard.aborted!=0 || env.scoreboard.live[0] || env.scoreboard.live[1] ||
       uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0)
      `uvm_fatal("PERF_GATE","Measurement run incomplete or checker failure")
    `uvm_info("PASS","SAMPLER PERFORMANCE UVM PASS: 96 checked polynomials, 24576 coefficients; 72 scenarios",UVM_NONE)
  endfunction
endclass

