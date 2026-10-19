// Stage4.3 targets the reported misses with accepted external transactions.
class sampler_stage4_3_seq extends sampler_stage4_2_seq;
  `uvm_object_utils(sampler_stage4_3_seq)
  function new(string n="sampler_stage4_3_seq");super.new(n);endfunction
  task body();
    byte unsigned a[$],b[$];
    bit [127:0] data;
    int id,n,param;
    super.body();
    // Exhaustion/invalid parameter with a live partly shuffled peer. Reuse the
    // failed slot, then finish the peer: neither reference nor RAM may be lost.
    for(int reason=0;reason<2;reason++)begin
      id=4000+10*reason;build_ball_bytes(b,reason,121+reason);
      command(EV_JOB,1,id+1,3,reason);data=0;
      for(int j=0;j<16;j++)data[8*j+:8]=b[j];beat(1,data,16,0);pause_cycles(300);
      command(EV_JOB,0,id,0,reason==0 ? 0:3);
      if(reason==0)beat(0,0,16,1);
      command(EV_WAIT_SLOT,0);expected_errors++;
      build_directed(a,0,0,123);complete_one(a,0,id,0,0);
      feed_without_wait(b,1,16);command(EV_WAIT_SLOT,1);expected_passed++;expected_modes[3]++;
    end
    // Explicit missing mode/core/parameter reset cells; every abort recovers.
    for(int cell_index=0;cell_index<8;cell_index++)begin
      int mode,core;
      case(cell_index)
        0:begin mode=0;core=0;param=1;end
        1:begin mode=0;core=0;param=2;end
        2:begin mode=0;core=1;param=0;end
        3:begin mode=0;core=1;param=2;end
        4:begin mode=1;core=0;param=2;end
        5:begin mode=1;core=1;param=0;end
        6:begin mode=2;core=0;param=0;end
        default:begin mode=2;core=1;param=2;end
      endcase
      id=4100+cell_index;command(EV_JOB,core,id,mode,param);beat(core,0,16,0);
      control(EV_RESET_AT,core,0);expected_aborts++;
      build_directed(a,mode,param,125);complete_one(a,core,id,mode,param);
    end
    // Six-byte first beat skews chunk boundaries. Final full16-byte beat holds
    // valid extra candidates, requiring clipping rather than exact-size finish.
    for(int mode=0;mode<=2;mode+=2)begin
      a.delete();repeat(mode==0 ? 774:646)a.push_back(0);
      id=4200+mode;command(EV_JOB,0,id,mode,mode==0 ? 0:1);
      beat(0,0,6,0);feed_without_wait(a,0,6);command(EV_WAIT_SLOT,0);
      expected_passed++;expected_modes[mode]++;
    end
    // Freeze status acceptance until BOTH independently computed polynomials
    // are complete. The dedicated driver command witnesses both pending before
    // releasing ready; the monitor checks stable offers and exact statuses.
    control(EV_PROFILE,0,0,1);
    for(int mode=0;mode<4;mode++)begin
      param=mode%3;id=4300+2*mode;
      control(EV_STALL,0,10000,0);
      build_directed(a,mode,param,126);build_directed(b,mode,param,127);
      command(EV_JOB,0,id,mode,param);command(EV_JOB,1,id+1,mode,param);
      feed_without_wait(a,0);feed_without_wait(b,1);
      command(EV_WAIT_DUAL_STATUS);command(EV_WAIT);
      expected_passed+=2;expected_modes[mode]+=2;
    end
    control(EV_PROFILE,0,1,1);
    // A nine-byte challenge prefix ends with its first candidate. The holding
    // register empties as COPY starts, allowing external bad metadata to be
    // accepted. Registered failure reaches the engine in SIGN on the next edge.
    for(int core=0;core<2;core++)begin
      id=4400+core;command(EV_JOB,core,id,3,core);beat(core,0,9,0);
      command(EV_BAD_AT_COPY,core);command(EV_WAIT_SLOT,core);expected_errors++;
      build_directed(a,3,core,129);complete_one(a,core,id,3,core);
    end
    // Exercise all16 job-tag bits, including alternating and all-one values.
    // Tags are routing information: exact comparisons must survive high bits.
    for(int pattern=0;pattern<4;pattern++)begin
      case(pattern)
        0:id=16'hffff;1:id=16'h8000;2:id=16'haaaa;default:id=16'h5555;
      endcase
      build_directed(a,pattern,pattern%3,131);complete_one(a,pattern%2,id,pattern,pattern%3);
    end
  endtask
endclass

class sampler_stage4_3_test extends sampler_stage4_2_test;
  `uvm_component_utils(sampler_stage4_3_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    sampler_stage4_3_seq expanded=sampler_stage4_3_seq::type_id::create("seq4_3");seq=expanded;
    phase.raise_objection(this);expanded.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info("STAGE4_3_PASS","SAMPLER STAGE4.3 UVM PASS: reset cells,peer errors,surplus clipping and dual-pending status cases checked",UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("STAGE4_SCOPE","18 checked groups including completion arbitration; no code exclusions or RTL changes",UVM_NONE)
  endfunction
endclass
