// Stage4 robustness expansion. Public handshakes only; scalar oracle unchanged.
class sampler_stage4_9_seq extends sampler_stage4_6_seq;
  `uvm_object_utils(sampler_stage4_9_seq)
  int burst_jobs,metadata_errors,stall_jobs,mask_format_jobs;
  function new(string n="sampler_stage4_9_seq");super.new(n);endfunction
  task body();
    byte unsigned bytes[$],suffix[$];
    int lengths[3]='{17,129,513};
    int id=14000,run_length,tau;
    super.body();
    control(EV_PROFILE,0,0,0);
    for(int mode=0;mode<4;mode++)if(mode!=2)
    for(int core=0;core<2;core++)for(int param=0;param<3;param++)
    foreach(lengths[k])begin
      bytes.delete();run_length=lengths[k];
      if(mode==3)begin
        // Eight sign bytes, then rejected255 candidates, then accepted zeros.
        repeat(8)bytes.push_back(8'ha5);
        repeat(run_length)bytes.push_back(8'hff);
        tau=param==0 ? 39:(param==1 ? 49:60);
        repeat(tau)bytes.push_back(0);
      end else begin
        // Matrix rejection uses3 bytes/candidate; secrets use two nibbles/byte.
        // Odd secret lengths round up to an even number of rejected nibbles.
        repeat(mode==0 ? 3*run_length:(run_length+1)/2)bytes.push_back(8'hff);
        build_directed(suffix,mode,param,200+k);
        foreach(suffix[j])bytes.push_back(suffix[j]);
      end
      complete_one(bytes,core,id++,mode,param);burst_jobs++;
    end
    // Every invalid5-bit byte count, in every mode and on both contexts.
    // Every error is followed by same-ID, same-mode, independently checked reuse.
    for(int mode=0;mode<4;mode++)for(int core=0;core<2;core++)
    for(int size=0;size<32;size++)if(size==0 || size>16)begin
      int param=(size+core)%3;
      command(EV_JOB,core,id,mode,param);beat(core,'1,size,1);
      command(EV_WAIT_SLOT,core);expected_errors++;metadata_errors++;
      build_directed(bytes,mode,param,210+size);
      complete_one(bytes,core,id++,mode,param);
    end
    // Bounded long backpressure, not an unbounded-liveness assumption.
    for(int mode=0;mode<4;mode++)for(int core=0;core<2;core++)
    for(int param=0;param<3;param++)begin
      control(EV_STALL,0,4096,1024);
      build_directed(bytes,mode,param,250+core);
      complete_one(bytes,core,id++,mode,param);stall_jobs++;
    end
    // Explicit modular-format boundaries after moving conversion to readout.
    // Scalar scoreboard computes gamma-t independently of RTL arithmetic.
    for(int core=0;core<2;core++)for(int param=0;param<3;param++)begin
      int gamma=param==0 ? 131072:524288;
      int width=param==0 ? 18:20;
      int fields[12];
      int filled=0;
      byte unsigned packed_byte=0;
      fields='{0,1,gamma-1,gamma,gamma+1,gamma+8190,gamma+8191,gamma+8192,
        gamma+(gamma>516096 ? 516096:gamma-1),
        gamma+(gamma>516097 ? 516097:gamma-1),
        gamma+(gamma>516098 ? 516098:gamma-1),2*gamma-1};
      bytes.delete();
      for(int j=0;j<256;j++)for(int bit_index=0;bit_index<width;bit_index++)begin
        packed_byte[filled]=1'((fields[j%12]>>bit_index)&1);filled++;
        if(filled==8)begin bytes.push_back(packed_byte);packed_byte=0;filled=0;end
      end
      complete_one(bytes,core,id++,2,param);mask_format_jobs++;
    end
    control(EV_PROFILE,0,1,1);
  endtask
endclass

class sampler_stage4_9_test extends sampler_stage4_6_test;
  `uvm_component_utils(sampler_stage4_9_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    sampler_stage4_9_seq expanded=sampler_stage4_9_seq::type_id::create("seq4_9");seq=expanded;
    phase.raise_objection(this);expanded.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    sampler_stage4_9_seq expanded;
    super.check_phase(phase);
    if(!$cast(expanded,seq) || expanded.burst_jobs!=54 ||
       expanded.metadata_errors!=128 || expanded.stall_jobs!=24 || expanded.mask_format_jobs!=6)
      `uvm_fatal("ROBUSTNESS_GATE","Incomplete rejection/metadata/backpressure sweep")
    `uvm_info("STAGE4_9_PASS","SAMPLER ROBUSTNESS UVM PASS:54 rejection-burst jobs,128 metadata errors with same-ID recovery,24 long-backpressure jobs",UVM_NONE)
    `uvm_info("MASK_FORMAT_PASS","SAMPLER MASK FORMAT BOUNDARY PASS:6 complete jobs;zero,modular borrow and both widths on both contexts",UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("STAGE4_SCOPE","23 checked groups;reachable gaps retained;raw functional and DUT code totals follow in Questa Transcript;no percentage ceiling or exclusions",UVM_NONE)
  endfunction
endclass
