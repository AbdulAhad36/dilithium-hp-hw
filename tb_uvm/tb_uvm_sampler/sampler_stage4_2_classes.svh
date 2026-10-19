class sampler_stage4_2_seq extends sampler_stage4_seq;
  `uvm_object_utils(sampler_stage4_2_seq)
  function new(string n="sampler_stage4_2_seq");super.new(n);endfunction
  task control(kind_t kind,int core,value,gap=0);
    sampler_item t=new("control");start_item(t);t.kind=kind;t.core=1'(core);t.value=value;t.gap=gap;finish_item(t);
  endtask
  task complete_one(ref byte unsigned bytes[$],input int core,id,mode,param);
    command(EV_JOB,core,id,mode,param);feed_without_wait(bytes,core);command(EV_WAIT_SLOT,core);
    expected_passed++;expected_modes[mode]++;
  endtask
  task body();
    byte unsigned a[$],b[$];
    int id,param,n;
    bit [127:0] data;
    super.body();
    // Every error reason in every mode on both slots, followed by exact same-ID
    // reuse. Error completion remains distinct from successful coverage credit.
    for(int mode=0;mode<4;mode++)for(int core=0;core<2;core++)for(int reason=0;reason<3;reason++)begin
      id=2200+100*mode+10*core+reason;param=(mode+core)%3;
      command(EV_JOB,core,id,mode,reason==1 ? 3:param);
      if(reason==0)beat(core,0,16,1);
      if(reason==2)beat(core,0,(mode+core)%2 ? 17:0,1);
      command(EV_WAIT_SLOT,core);expected_errors++;
      build_directed(a,mode,param,101+core);complete_one(a,core,id,mode,param);
    end
    // Reset exactly at occupied candidate+packed stages, recover same slot/ID.
    for(int mode=0;mode<3;mode++)for(int core=0;core<2;core++)begin
      id=2700+10*mode+core;param=(mode+core)%3;
      command(EV_JOB,core,id,mode,param);beat(core,0,16,0);
      control(EV_RESET_AT,core,0);expected_aborts++;
      build_directed(a,mode,param,111);complete_one(a,core,id,mode,param);
    end
    // CLEAR,COPY,SIGN,READ_OUT are actual observed FSM states at reset.
    for(int phase=1;phase<=4;phase++)for(int core=0;core<2;core++)begin
      id=2800+10*phase+core;param=(phase+core)%3;
      command(EV_JOB,core,id,3,param);
      if(phase==4)begin build_ball_bytes(a,param,112);feed_without_wait(a,core);end
      else beat(core,0,16,0);
      control(EV_RESET_AT,core,phase);expected_aborts++;
      build_directed(a,3,param,113);complete_one(a,core,id,3,param);
    end
    // Questa names individual bins by their VALUE: b[6] means6 bits, not the
    // seventh element. Correct the earlier Stage4.1 report-label interpretation.
    // Three bytes leave6 bits after one18-bit field; follow with1/7 bytes.
    for(int choice=0;choice<2;choice++)begin
      build_directed(a,2,0,114);id=2900+choice;n=choice==0 ? 1:7;
      command(EV_JOB,choice,id,2,0);data=0;
      for(int j=0;j<3;j++)data[8*j+:8]=a[j];beat(choice,data,3,0);
      data=0;for(int j=0;j<n;j++)data[8*j+:8]=a[3+j];beat(choice,data,n,0);
      feed_without_wait(a,choice,3+n);command(EV_WAIT_SLOT,choice);
      expected_passed++;expected_modes[2]++;
    end
    // No-backpressure operation: leave time for clear and for each beat's work.
    control(EV_PROFILE,0,0,1);
    for(int mode=0;mode<4;mode++)begin
      param=mode%3;build_directed(a,mode,param,115);command(EV_JOB,0,3000+mode,mode,param);
      if(mode==3)pause_cycles(300);
      for(int pos=0;pos<a.size();pos+=n)begin
        n=a.size()-pos;if(n>16)n=16;data=0;
        for(int j=0;j<n;j++)data[8*j+:8]=a[pos+j];
        beat(0,data,n,pos+n==a.size(),80);
      end
      command(EV_WAIT_SLOT,0);expected_passed++;expected_modes[mode]++;
    end
    // Stall an actual output offer, then an actual completion offer, for a
    // medium interval. This targets semantic events rather than guessed delays.
    for(int mode=0;mode<4;mode++)begin
      param=mode%3;build_directed(a,mode,param,116);command(EV_JOB,0,3100+mode,mode,param);
      feed_without_wait(a,0);control(EV_STALL_AT,0,0,9);control(EV_STALL_AT,0,1,9);
      command(EV_WAIT_SLOT,0);expected_passed++;expected_modes[mode]++;
    end
    build_directed(a,3,2,117);command(EV_JOB,1,3200,3,2);feed_without_wait(a,1);
    control(EV_STALL_AT,1,0,40);command(EV_WAIT_SLOT,1);expected_passed++;expected_modes[3]++;
    control(EV_PROFILE,0,1,1);
    // An error/reuse on slot0 must preserve a live, partly sampled peer.
    build_ball_bytes(b,0,118);command(EV_JOB,1,3301,3,0);data=0;
    for(int j=0;j<16;j++)data[8*j+:8]=b[j];beat(1,data,16,0);pause_cycles(300);
    command(EV_JOB,0,3300,0,0);beat(0,0,0,1);command(EV_WAIT_SLOT,0);expected_errors++;
    build_directed(a,0,0,119);complete_one(a,0,3300,0,0);
    feed_without_wait(b,1,16);command(EV_WAIT_SLOT,1);expected_passed++;expected_modes[3]++;
  endtask
endclass

class sampler_stage4_2_test extends sampler_stage4_test;
  `uvm_component_utils(sampler_stage4_2_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    sampler_stage4_2_seq expanded=sampler_stage4_2_seq::type_id::create("seq4_2");seq=expanded;
    phase.raise_objection(this);expanded.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if(env.outcome_coverage.successes!=seq.expected_passed || env.outcome_coverage.errors!=seq.expected_errors ||
       env.outcome_coverage.recoveries!=seq.expected_aborts)
      `uvm_fatal("OUTCOME_GATE","Checked outcome/reset-recovery credit counts mismatch")
    `uvm_info("STAGE4_2_PASS","SAMPLER STAGE4.2 UVM PASS: checked success/error/reset-recovery credits match observed outcomes",UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("STAGE4_SCOPE","12 success groups plus5 checked outcome/internal groups; remaining misses are reported without suppressed hits",UVM_NONE)
  endfunction
endclass
