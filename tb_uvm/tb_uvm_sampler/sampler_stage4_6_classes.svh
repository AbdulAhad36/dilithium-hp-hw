// Exercise all four-group count combinations through real secret inputs.
// Acceptance counts construct inputs only; the scalar scoreboard owns outputs.
class sampler_stage4_6_seq extends sampler_stage4_5_seq;
  `uvm_object_utils(sampler_stage4_6_seq)
  byte unsigned merge_bytes[$];
  int merge_accepted,merge_serial,merge_patterns,prepare_reset_cases;
  function new(string n="sampler_stage4_6_seq");super.new(n);endfunction
  task flush_merge(int param);
    bit [63:0] data;
    int n;
    if(merge_bytes.size()==0)return;
    while(merge_accepted<256)begin
      n=256-merge_accepted;if(n>16)n=16;data='1;
      for(int j=0;j<n;j++)data[4*j+:4]=4'((j+merge_serial)%(param==1 ? 9:15));
      for(int j=0;j<8;j++)merge_bytes.push_back(data[8*j+:8]);
      merge_accepted+=n;
    end
    complete_one(merge_bytes,merge_serial%2,10000+merge_serial,1,param);
    merge_serial++;merge_bytes.delete();merge_accepted=0;
  endtask
  task merge_pattern(bit [15:0] mask,int param,salt);
    int n=$countones(mask);
    bit [63:0] data='1;
    if(merge_accepted+n>256)flush_merge(param);
    for(int j=0;j<16;j++)if(mask[j])data[4*j+:4]=4'((7*j+salt)%(param==1 ? 9:15));
    for(int j=0;j<8;j++)merge_bytes.push_back(data[8*j+:8]);
    merge_accepted+=n;merge_patterns++;
    if(merge_accepted==256)flush_merge(param);
  endtask
  task body();
    bit [15:0] mask;
    int counts[4];
    super.body();
    for(int param=0;param<2;param++)begin
      // All16 local masks in every group,including non-contiguous survivors.
      for(int pattern=0;pattern<16;pattern++)begin
        mask=0;
        for(int g=0;g<4;g++)for(int j=0;j<4;j++)mask[4*g+j]=1'((pattern>>((j+g)%4))&1);
        merge_pattern(mask,param,pattern);
      end
      //5^4=625 group-count tuples per eta,with rotating survivor placement.
      for(int a=0;a<=4;a++)for(int b=0;b<=4;b++)
      for(int c=0;c<=4;c++)for(int d=0;d<=4;d++)begin
        counts='{a,b,c,d};mask=0;
        for(int g=0;g<4;g++)for(int j=0;j<counts[g];j++)
          mask[4*g+(j+merge_patterns+g)%4]=1;
        merge_pattern(mask,param,merge_patterns);
      end
      flush_merge(param);
    end
    // Every new preparation phase on both contexts in each non-challenge mode.
    // Each abort is followed by a fully checked same-ID recovery polynomial.
    for(int mode=0;mode<3;mode++)for(int core=0;core<2;core++)
    for(int phase=1;phase<=3;phase++)begin
      byte unsigned recovery[$];
      int id=12000+100*mode+10*core+phase;
      int param=(mode+core)%3;
      command(EV_JOB,core,id,mode,param);beat(core,128'h123456789abcdef,16,0);
      control(EV_RESET_AT,core,phase+7);expected_aborts++;prepare_reset_cases++;
      build_directed(recovery,mode,param,150+phase);
      complete_one(recovery,core,id,mode,param);
    end
  endtask
endclass

class sampler_stage4_6_test extends sampler_stage4_5_test;
  `uvm_component_utils(sampler_stage4_6_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    sampler_stage4_6_seq expanded=sampler_stage4_6_seq::type_id::create("seq4_6");seq=expanded;
    phase.raise_objection(this);expanded.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    sampler_stage4_6_seq expanded;
    super.check_phase(phase);
    if(!$cast(expanded,seq) || expanded.merge_patterns!=1282 || expanded.merge_serial==0 || expanded.prepare_reset_cases!=18)
      `uvm_fatal("MERGE_PATTERN_GATE","Incomplete group-merge input sweep")
    `uvm_info("STAGE4_6_PASS",$sformatf("SAMPLER STAGE4.6 UVM PASS:1282 group patterns,625 count tuples per eta,all16 local masks; %0d extra independently checked secret polynomials",expanded.merge_serial),UVM_NONE)
    `uvm_info("PREP_RESET_PASS","18 preparation resets reached:3 phases x2 contexts x3 modes;all same-ID recovery polynomials passed independent checking",UVM_NONE)
  endfunction
endclass
