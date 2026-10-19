// Public-port-only extension of the same sequences, driver and scalar oracle.
class sampler_netlist_extra_seq extends sampler_stage4_4_seq;
  `uvm_object_utils(sampler_netlist_extra_seq)
  function new(string n="sampler_netlist_extra_seq");super.new(n);endfunction
  task body();
    byte unsigned a[$],b[$];
    bit [127:0] data;
    int pos[2],core,n,id;
    int unsigned seeds[3]='{32'h13579bdf,32'h2468ace1,32'hdeadbeef};
    expected_passed=0;expected_errors=0;expected_aborts=0;
    for(int m=0;m<4;m++)expected_modes[m]=0;
    for(int slot=0;slot<2;slot++)command(EV_PROBE_IDLE,slot);
    control(EV_PROFILE,0,0,1);
    for(int mode=0;mode<4;mode++)for(int slot=0;slot<2;slot++)begin
      id=8000+10*mode+slot;build_directed(a,mode,mode%3,161);
      control(EV_STALL,0,10000,0);command(EV_JOB,slot,id,mode,mode%3);
      command(EV_PROBE_BUSY,slot);feed_without_wait(a,slot);
      command(EV_STOP_THROUGH_STATUS,slot);command(EV_WAIT_SLOT,slot);
      expected_passed++;expected_modes[mode]++;
    end
    foreach(seeds[seed_index])begin
      current_seed=seeds[seed_index];data_state=current_seed;
      schedule_state=current_seed^32'h9e3779b9;random_profile(current_seed);
      for(int mode=0;mode<4;mode++)for(int param=0;param<3;param++)begin
        random_bytes(a,mode,param);random_bytes(b,mode,param);
        id=9000+100*seed_index+10*mode+2*param;
        seeded_job(0,id,mode,param);seeded_job(1,id+1,mode,param);
        pos[0]=0;pos[1]=0;
        while(pos[0]<a.size() || pos[1]<b.size())begin
          core=int'(next_schedule()&1);
          if(pos[core]>=(core==0 ? a.size():b.size()))core=1-core;
          n=1+int'(next_schedule()%16);
          if(n>(core==0 ? a.size():b.size())-pos[core])n=(core==0 ? a.size():b.size())-pos[core];
          data='1;for(int j=0;j<n;j++)data[8*j+:8]=core==0 ? a[pos[core]+j]:b[pos[core]+j];
          beat(core,data,n,pos[core]+n==(core==0 ? a.size():b.size()),int'(next_schedule()%8));pos[core]+=n;
        end
        command(EV_WAIT);expected_passed+=2;expected_modes[mode]+=2;
      end
    end
    random_profile(0);control(EV_PROFILE,0,1,1);
  endtask
endclass

class sampler_netlist_test extends sampler_vector_test;
  `uvm_component_utils(sampler_netlist_test)
  sampler_netlist_extra_seq extra;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    seq=sampler_vector_seq::type_id::create("vectors");
    extra=sampler_netlist_extra_seq::type_id::create("extra");
    phase.raise_objection(this);seq.start(env.sequencer);
    // Keep the independent Python capture exactly the104 file jobs. The80
    // additional jobs still use the main SV scoreboard and checked coverage.
    capture.enabled=0;extra.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    if(env.scoreboard.passed!=156 || env.scoreboard.failed_jobs!=24 ||
       env.scoreboard.aborted!=4 || env.scoreboard.compared!=39936 ||
       capture.jobs!=104 || capture.success!=76 || capture.errors!=24 ||
       capture.aborted!=4 || capture.coefficients!=19456 ||
       extra.expected_passed!=80 || env.scoreboard.live[0] || env.scoreboard.live[1] ||
       env.outcome_coverage.successes!=156 || env.outcome_coverage.errors!=24 ||
       env.outcome_coverage.recoveries!=4 ||
       uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0)
      `uvm_fatal("NETLIST_GATE","Incomplete external netlist regression/capture")
    for(int core=0;core<2;core++)if(env.driver.stopped_completion[core]!=4)
      `uvm_fatal("NETLIST_GATE","Stopped-valid completion not checked in all modes/cores")
    `uvm_info("NETLIST_PASS","SAMPLER NETLIST UVM PASS:184 jobs,156 complete,24 expected errors,4 reset aborts,39936 coefficient checks;104-job Python capture19456 coefficients",UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("NETLIST_SCOPE","Functional vendor netlist;external scalar scoreboard/stall/reset/refusal checks;no source-only occupancy/FSM/pipeline probes or RTL code/timing simulation claim",UVM_NONE)
  endfunction
endclass
