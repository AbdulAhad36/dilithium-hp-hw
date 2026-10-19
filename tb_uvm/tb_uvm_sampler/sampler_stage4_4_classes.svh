// Explicit PRNGs make byte values/partitions/scheduling reproducible without
// depending on simulator class-randomization call order. This generates INPUTS;
// the existing independent scalar scoreboard still computes expected outputs.
class sampler_stage4_4_seq extends sampler_stage4_3_seq;
  `uvm_object_utils(sampler_stage4_4_seq)
  int unsigned data_state,schedule_state,current_seed;
  function new(string n="sampler_stage4_4_seq");super.new(n);endfunction
  function int unsigned next_data();
    data_state^=data_state<<13;data_state^=data_state>>17;data_state^=data_state<<5;return data_state;
  endfunction
  function int unsigned next_schedule();
    schedule_state^=schedule_state<<13;schedule_state^=schedule_state>>17;schedule_state^=schedule_state<<5;return schedule_state;
  endfunction
  function void random_bytes(ref byte unsigned bytes[$],input int mode,param);
    int accepted=0,position=256-(param==0 ? 39:(param==1 ? 49:60));
    int unsigned raw;
    bytes.delete();
    case(mode)
      0:while(accepted<256)begin
        raw=next_data()&24'hffffff;
        for(int j=0;j<3;j++)bytes.push_back(8'(raw>>(8*j)));
        if((raw&8388607)<8380417)accepted++;
      end
      1:while(accepted<256)begin
        raw=next_data()&255;bytes.push_back(8'(raw));
        for(int j=0;j<2;j++)if(((raw>>(4*j))&15)<(param==1 ? 9:15) && accepted<256)accepted++;
      end
      2:repeat(param==0 ? 576:640)bytes.push_back(8'(next_data()));
      3:begin
        repeat(8)bytes.push_back(8'(next_data()));
        while(position<256)begin
          raw=next_data()&255;bytes.push_back(8'(raw));if(raw<=position)position++;
        end
      end
    endcase
  endfunction
  task seeded_job(int core,id,mode,param);
    sampler_item t=new("seeded_job");start_item(t);t.kind=EV_JOB;t.core=1'(core);
    t.id=id;t.mode=mode;t.param=param;t.random_seed=current_seed;finish_item(t);
  endtask
  task random_profile(int unsigned seed);
    sampler_item t=new("random_profile");start_item(t);t.kind=EV_RANDOM_PROFILE;t.random_seed=seed;finish_item(t);
  endtask
  task body();
    byte unsigned a[$],b[$];
    bit [127:0] data;
    int pos[2],core,n,id;
    int unsigned seeds[3]='{32'h13579bdf,32'h2468ace1,32'hdeadbeef};
    super.body();
    // No ownership: these8-cycle offers must never be accepted. No polynomial
    // is fabricated for an idle-tag refusal; scoreboard validates lack of owner.
    for(int slot=0;slot<2;slot++)command(EV_PROBE_IDLE,slot);
    control(EV_PROFILE,0,0,1);
    for(int mode=0;mode<4;mode++)for(int slot=0;slot<2;slot++)begin
      id=5000+10*mode+slot;build_directed(a,mode,mode%3,141);
      control(EV_STALL,0,10000,0);command(EV_JOB,slot,id,mode,mode%3);
      command(EV_PROBE_BUSY,slot);
      feed_without_wait(a,slot);command(EV_PROBE_STOP,slot);
      control(EV_STALL,0,0,0);command(EV_WAIT_SLOT,slot);
      expected_passed++;expected_modes[mode]++;
    end
    // Each seed covers all modes,parameters and both contexts,with unrelated
    // byte streams per context and randomized beat lengths1..16/gaps0..7.
    foreach(seeds[seed_index])begin
      current_seed=seeds[seed_index];data_state=current_seed;
      schedule_state=current_seed^32'h9e3779b9;random_profile(current_seed);
      `uvm_info("RANDOM_SEED",$sformatf("seed=%08x;12 paired mode/parameter cases; byte PRNG and schedule PRNG start from this seed",current_seed),UVM_NONE)
      for(int mode=0;mode<4;mode++)for(int param=0;param<3;param++)begin
        random_bytes(a,mode,param);random_bytes(b,mode,param);
        id=6000+100*seed_index+10*mode+2*param;
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

class sampler_stage4_4_test extends sampler_stage4_3_test;
  `uvm_component_utils(sampler_stage4_4_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    sampler_stage4_4_seq expanded=sampler_stage4_4_seq::type_id::create("seq4_4");seq=expanded;
    phase.raise_objection(this);expanded.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info("STAGE4_4_PASS","SAMPLER STAGE4.4 UVM PASS: idle/busy/stopped refusals and72 seeded random polynomials checked",UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("STAGE4_SCOPE","20 checked groups;72 deterministic random jobs;code misses remain visible;no RTL changes",UVM_NONE)
  endfunction
endclass
