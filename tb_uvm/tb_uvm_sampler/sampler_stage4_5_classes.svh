// Target reachable code gaps through public handshakes, preserving the oracle.
class sampler_stage4_5_seq extends sampler_stage4_4_seq;
  `uvm_object_utils(sampler_stage4_5_seq)
  function new(string n="sampler_stage4_5_seq");super.new(n);endfunction
  task dual_errors(int peer_id,expected_chosen_core);
    sampler_item t=new("dual_errors");start_item(t);
    t.kind=EV_SIMULTANEOUS_ERRORS;t.core=1;t.id=peer_id;t.value=expected_chosen_core;
    finish_item(t);
  endtask
  task body();
    byte unsigned a[$];
    super.body();
    control(EV_PROFILE,0,0,1);
    for(int turn=0;turn<2;turn++)begin
      // A prior completion sets the next status-arbiter turn explicitly.
      build_directed(a,0,0,151);complete_one(a,1-turn,7000+10*turn,0,0);
      command(EV_JOB,0,7001+10*turn,0,0);
      dual_errors(7002+10*turn,turn);
      command(EV_WAIT);expected_errors+=2;
      build_directed(a,0,0,152);complete_one(a,0,7001+10*turn,0,0);
      build_directed(a,0,0,153);complete_one(a,1,7002+10*turn,0,0);
    end
    for(int core=0;core<2;core++)begin
      //120 bytes provide240 secret coefficients; low half of the final beat
      // completes256, while backpressure keeps its surplus high half held.
      command(EV_JOB,core,7100+core,1,0);
      for(int pos=0;pos<112;pos+=16)beat(core,0,16,0);
      beat(core,0,8,0);control(EV_STALL,0,0,80);beat(core,0,16,1);
      command(EV_WAIT_SURPLUS,core);command(EV_WAIT_SLOT,core);
      expected_passed++;expected_modes[1]++;
      // Hold a refused valid through the successful status edge. Refusal
      // checking must use pre-edge ownership, before the job is retired.
      build_directed(a,2,core,154);control(EV_STALL,0,10000,0);
      command(EV_JOB,core,7200+core,2,core);feed_without_wait(a,core);
      command(EV_STOP_THROUGH_STATUS,core);command(EV_WAIT_SLOT,core);
      expected_passed++;expected_modes[2]++;
      // Let challenge initialization finish before malformed byte metadata.
      // Unlike an error during CLEAR, this exercises initialized IDLE abort
      // inhibition. The subsequent same-ID challenge must still match exactly.
      command(EV_JOB,core,7300+core,3,core);pause_cycles(300);
      beat(core,0,0,1);command(EV_WAIT_SLOT,core);expected_errors++;
      build_directed(a,3,core,155);complete_one(a,core,7300+core,3,core);
    end
    control(EV_PROFILE,0,1,1);
  endtask
endclass

class sampler_stage4_5_test extends sampler_stage4_4_test;
  `uvm_component_utils(sampler_stage4_5_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    sampler_stage4_5_seq expanded=sampler_stage4_5_seq::type_id::create("seq4_5");seq=expanded;
    phase.raise_objection(this);expanded.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    for(int core=0;core<2;core++)
      if(env.driver.simultaneous_errors[core]!=1 || env.driver.surplus_holds[core]!=1 ||
         env.driver.stopped_completion[core]!=1)
        `uvm_fatal("STAGE4_5_GATE","Missing dual-error/surplus/stopped-completion target witness")
    `uvm_info("STAGE4_5_PASS","SAMPLER STAGE4.5 UVM PASS: both unlocked status choices,held surplus,stopped-valid completion and initialized challenge abort/recovery checked on both contexts",UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("STAGE4_SCOPE","20 checked groups retained;targeted code-gap cases;no RTL changes or code exclusions",UVM_NONE)
  endfunction
endclass
