// Checked errors use their own outcome stream, never the successful-polynomial
// stream used by performance. Reset observations wait for exact recovery first.
class sampler_outcome_coverage extends uvm_subscriber#(sampler_item);
  `uvm_component_utils(sampler_outcome_coverage)
  int successes,errors,recoveries,fd,activity_fd,protocol_fd;
  string prefix="sampler/smoke";
  covergroup checked_errors with function sample(int mode,core,code,prefix_count,bad_bytes,peer);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_reason:coverpoint code {bins exhausted={1};bins invalid_param={3};bins byte_count={4};}
    cp_prefix:coverpoint prefix_count {bins none={0};bins partial={[1:255]};}
    cp_bad_bytes:coverpoint bad_bytes iff(code==4) {bins zero={0};bins oversized[]={[17:31]};}
    cp_peer:coverpoint peer {bins alone={0};bins live_peer={1};}
    cx_mode_reason:cross cp_mode,cp_reason;
    cx_core_reason:cross cp_core,cp_reason;
    cx_reason_peer:cross cp_reason,cp_peer;
    // Only invalid-byte outcomes sample this cross; all128 combinations legal.
    cx_metadata_mode_core:cross cp_mode,cp_core,cp_bad_bytes iff(code==4);
  endgroup
  covergroup reset_recovery with function sample(int mode,param,core,held,decoded,packed_seen,collector,prefix_count,ball_state);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_param:coverpoint param {bins p[]={0,1,2};}
    cp_hold:coverpoint held {bins b[]={0,1};}
    cp_decode:coverpoint decoded {bins b[]={0,1};}
    cp_packed:coverpoint packed_seen {bins b[]={0,1};}
    cp_collector:coverpoint collector {bins b[]={0,1};}
    cp_prefix:coverpoint prefix_count {bins none={0};bins partial={[1:255]};}
    cp_ball_phase:coverpoint ball_state iff(mode==3) {bins phase[]={[0:4]};}
    cx_mode_core:cross cp_mode,cp_core;
    cx_mode_core_param:cross cp_mode,cp_core,cp_param;
  endgroup
  covergroup lifecycle_recovery with function sample(int prior,mode);
    option.per_instance=1;
    cp_prior:coverpoint prior {bins success={0};bins exhausted={1};bins invalid_param={3};bins bad_bytes={4};bins reset_abort={5};}
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cx_prior_mode:cross cp_prior,cp_mode;
  endgroup
  covergroup pipeline_activity with function sample(int mode,count,stages,simultaneous,wrapped,clipped,stopped);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_count:coverpoint count {bins empty={0};bins few={[1:3]};bins grouped={[4:15]};bins many={[16:31]};bins full={32};}
    cp_stages:coverpoint stages {bins s[]={[0:3]};}
    cp_simultaneous:coverpoint simultaneous {bins b[]={0,1};}
    cp_wrap:coverpoint wrapped {bins b[]={0,1};}
    cp_clip:coverpoint clipped {bins b[]={0,1};}
    cp_stop:coverpoint stopped {bins b[]={0,1};}
    cx_mode_stages:cross cp_mode,cp_stages {
      // Challenge bypasses both candidate/packed stages by architecture.
      ignore_bins challenge_pending=binsof(cp_mode) intersect {3} && binsof(cp_stages) intersect {1,2,3};
    }
    cx_mode_clip:cross cp_mode,cp_clip {
      ignore_bins challenge_clip=binsof(cp_mode) intersect {3} && binsof(cp_clip) intersect {1};
    }
  endgroup
  covergroup challenge_states with function sample(int param,state,edge_code);
    option.per_instance=1;
    cp_param:coverpoint param {bins p[]={0,1,2};}
    cp_state:coverpoint state {bins idle={0};bins clear={1};bins copy_state={2};bins sign_state={3};bins read_out={4};}
    cp_edge:coverpoint edge_code {
      bins idle_clear={1};bins clear_loop={9};bins clear_idle={8};
      bins idle_copy={2};bins copy_sign={19};bins sign_idle={24};
      bins idle_read={4};bins read_idle={32};
    }
    cx_param_state:cross cp_param,cp_state;
  endgroup
  covergroup completion_arbitration with function sample(int mode,core,dual_pending,stalled);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_pending:coverpoint dual_pending {bins single_pending={0};bins dual_pending={1};}
    cp_stall:coverpoint stalled {bins ready={0};bins stalled={1};}
    cx_core_pending:cross cp_core,cp_pending;
    cx_mode_pending:cross cp_mode,cp_pending;
  endgroup
  covergroup protocol_refusals with function sample(int kind,core,mode);
    option.per_instance=1;
    cp_kind:coverpoint kind {bins idle_tag={1};bins busy_descriptor={2};bins stopped_source={3};}
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_mode:coverpoint mode iff(kind!=1) {bins m[]={0,1,2,3};}
    cx_kind_core:cross cp_kind,cp_core;
    cx_owned_mode:cross cp_kind,cp_mode {
      ignore_bins idle_has_no_mode=binsof(cp_kind) intersect {1};
    }
  endgroup
  covergroup randomized_jobs with function sample(int unsigned seed,int mode,param,core);
    option.per_instance=1;
    cp_seed:coverpoint seed {bins first={32'h13579bdf};bins second={32'h2468ace1};bins third={32'hdeadbeef};}
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_param:coverpoint param {bins p[]={0,1,2};}
    cp_core:coverpoint core {bins c[]={0,1};}
    cx_seed_mode_param_core:cross cp_seed,cp_mode,cp_param,cp_core;
  endgroup
  function new(string n,uvm_component p);
    super.new(n,p);checked_errors=new;reset_recovery=new;lifecycle_recovery=new;
    pipeline_activity=new;challenge_states=new;completion_arbitration=new;
    protocol_refusals=new;randomized_jobs=new;
  endfunction
  function void build_phase(uvm_phase phase);
    void'($value$plusargs("SAMPLER_COV_PREFIX=%s",prefix));
    fd=$fopen({prefix,"_checked_outcomes.csv"},"w");
    if(!fd)`uvm_fatal("COV_FILE","Cannot create outcome witness CSV")
    $fdisplay(fd,"kind,id,core,mode,param,code,checked_prefix,recovery_id,recovery_mode,hold,decode,packed,collector,ball_state");
    activity_fd=$fopen({prefix,"_checked_activity.csv"},"w");
    if(!activity_fd)`uvm_fatal("COV_FILE","Cannot create checked activity CSV")
    $fdisplay(activity_fd,"id,core,mode,param,max_collector,stage_mask_seen,clipped_snapshots,dual_status_snapshots,wrap_snapshots,random_seed");
    protocol_fd=$fopen({prefix,"_checked_protocol.csv"},"w");
    if(!protocol_fd)`uvm_fatal("COV_FILE","Cannot create protocol witness CSV")
    $fdisplay(protocol_fd,"id,core,mode,refusal_kind");
  endfunction
  function void write(sampler_item t);
    int max_count=0,stage_seen=0,clip_seen=0,dual_seen=0,wrap_seen=0;
    if(uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0 ||
       uvm_report_server::get_server().get_severity_count(UVM_FATAL)!=0)return;
    if(t.kind==EV_PROTOCOL && t.code==1)begin
      protocol_refusals.sample(1,t.core,4);
      $fdisplay(protocol_fd,"0,%0d,4,1",t.core);$fflush(protocol_fd);
    end else if(t.kind==EV_RESET)begin
      recoveries++;
      if(t.source_observed)reset_recovery.sample(t.mode,t.param,t.core,t.reset_hold,t.reset_decode,t.reset_packed,t.reset_collector,t.value,t.snapshot.ball_state);
      $fdisplay(fd,"reset,%0d,%0d,%0d,%0d,5,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",t.id,t.core,t.mode,t.param,t.value,t.recovery_id,t.recovery_mode,t.reset_hold,t.reset_decode,t.reset_packed,t.reset_collector,t.snapshot.ball_state);
    end else if(t.kind==EV_STATUS && t.code!=0)begin
      errors++;checked_errors.sample(t.mode,t.core,t.code,t.value,t.bad_bytes,t.cov_paired);
      $fdisplay(fd,"error,%0d,%0d,%0d,%0d,%0d,%0d,0,0,0,0,0,0,0",t.id,t.core,t.mode,t.param,t.code,t.value);
    end else if(t.kind==EV_STATUS && t.code==0 && t.value==256)begin
      successes++;
      if(t.random_seed!=0)randomized_jobs.sample(t.random_seed,t.mode,t.param,t.core);
      for(int kind=2;kind<=3;kind++)if(t.protocol_seen[kind-1])begin
        protocol_refusals.sample(kind,t.core,t.mode);
        $fdisplay(protocol_fd,"%0d,%0d,%0d,%0d",t.id,t.core,t.mode,kind);$fflush(protocol_fd);
      end
      if(t.prior_outcome<6)lifecycle_recovery.sample(t.prior_outcome,t.mode);
      foreach(t.snapshots[k])begin
        if(t.snapshots[k].count>max_count)max_count=t.snapshots[k].count;
        stage_seen|=1<<t.snapshots[k].stages;
        clip_seen+=int'(t.snapshots[k].clipped);dual_seen+=int'(t.snapshots[k].dual_status);
        wrap_seen+=int'(t.snapshots[k].wrap);
        pipeline_activity.sample(t.mode,t.snapshots[k].count,t.snapshots[k].stages,t.snapshots[k].simultaneous,t.snapshots[k].wrap,t.snapshots[k].clipped,t.snapshots[k].stopped);
        if(t.mode==3 && t.snapshots[k].ball_state<5)
          challenge_states.sample(t.param,t.snapshots[k].ball_state,t.snapshots[k].ball_edge);
        if(t.snapshots[k].stopped)
          completion_arbitration.sample(t.mode,t.core,t.snapshots[k].dual_status,t.snapshots[k].status_wait);
      end
      $fdisplay(activity_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",t.id,t.core,t.mode,t.param,max_count,stage_seen,clip_seen,dual_seen,wrap_seen,t.random_seed);
      $fflush(activity_fd);
    end else `uvm_fatal("OUTCOME_GATE","Unaccepted outcome reached coverage")
    $fflush(fd);
  endfunction
  function void report_phase(uvm_phase phase);
    real pct[8];
    string names[8]='{"checked_errors","reset_recovery","lifecycle_recovery","pipeline_activity","challenge_states","completion_arbitration","protocol_refusals","randomized_jobs"};
    int summary_fd=$fopen({prefix,"_outcome_summary.csv"},"w");
    pct[0]=checked_errors.get_inst_coverage();pct[1]=reset_recovery.get_inst_coverage();
    pct[2]=lifecycle_recovery.get_inst_coverage();pct[3]=pipeline_activity.get_inst_coverage();pct[4]=challenge_states.get_inst_coverage();
    pct[5]=completion_arbitration.get_inst_coverage();
    pct[6]=protocol_refusals.get_inst_coverage();pct[7]=randomized_jobs.get_inst_coverage();
    if(!summary_fd)`uvm_fatal("COV_FILE","Cannot create outcome summary")
    $fdisplay(summary_fd,"group,percent");
    foreach(pct[k])begin
      $fdisplay(summary_fd,"%s,%0.6f",names[k],pct[k]);
      `uvm_info("OUTCOME_GROUP",$sformatf("%s: %0.2f%%",names[k],pct[k]),UVM_NONE)
    end
    $fclose(summary_fd);$fclose(fd);$fclose(activity_fd);$fclose(protocol_fd);
    `uvm_info("OUTCOME_CREDITS",$sformatf("%0d checked successes, %0d checked errors, %0d reset observations released after exact recovery",successes,errors,recoveries),UVM_NONE)
  endfunction
endclass
