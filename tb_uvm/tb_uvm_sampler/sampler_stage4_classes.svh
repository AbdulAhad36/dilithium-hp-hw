// Stage4.1 directed expansion. Every case uses the main driver/monitor/oracle.
class sampler_stage4_seq extends sampler_smoke_seq;
  `uvm_object_utils(sampler_stage4_seq)
  int expected_passed=52;
  int expected_errors=19,expected_aborts=11;
  int expected_modes[4]='{11,16,14,11};
  function new(string n="sampler_stage4_seq");super.new(n);endfunction
  function void build_directed(ref byte unsigned b[$],input int mode,param,seed);
    int raw,accepted=0,k=0,width,gamma,t,filled=0;
    byte unsigned current_byte=0;
    if(mode==1)begin build_secret_bytes(b,param,seed);return;end
    if(mode==3)begin build_ball_bytes(b,param,seed);return;end
    b.delete();
    if(mode==0)begin
      while(accepted<256)begin
        case(k%12)
          0:raw=0;1:raw=1;2:raw=8380416;3:raw=8380417;
          4:raw=8380418;5:raw=8388607;6:raw=24'h800000;
          7:raw=24'h800001;8:raw=24'hffffff;9:raw=8380415;
          10:raw=8380419;default:raw=(k*7919+seed)%8380417;
        endcase
        for(int j=0;j<3;j++)b.push_back(8'(raw>>(8*j)));
        if((raw&8388607)<8380417)accepted++;k++;
      end
    end else begin
      width=param==0 ? 18:20;gamma=param==0 ? 131072:524288;
      for(int i=0;i<256;i++)begin
        case(i%9)
          0:t=0;1:t=1;2:t=gamma-1;3:t=gamma;4:t=gamma+1;
          5:t=2*gamma-2;6:t=2*gamma-1;7:t=gamma/2;default:t=gamma+19;
        endcase
        for(int j=0;j<width;j++)begin
          current_byte[filled]=1'((t>>j)&1);filled++;
          if(filled==8)begin b.push_back(current_byte);current_byte=0;filled=0;end
        end
      end
    end
  endfunction
  task counted_pair(ref byte unsigned a[$],ref byte unsigned b[$],input int mode0,param0,mode1,param1,id,input bit full=0);
    run_pair(a,b,mode0,param0,mode1,param1,id,full);
    expected_passed+=2;expected_modes[mode0]++;expected_modes[mode1]++;
  endtask
  task feed_without_wait(ref byte unsigned a[$],input int core,start=0);
    int n,pos=start;
    bit [127:0] data;
    while(pos<a.size())begin
      n=a.size()-pos;if(n>16)n=16;data=0;
      for(int j=0;j<n;j++)data[8*j+:8]=a[pos+j];
      beat(core,data,n,pos+n==a.size());pos+=n;
    end
  endtask
  task body();
    byte unsigned a[$],b[$];
    sampler_item t;
    int param;
    super.body();
    // All16 ordered live-mode pairs. Parameters rotate through44/65/87.
    for(int m0=0;m0<4;m0++)for(int m1=0;m1<4;m1++)begin
      param=(m0+m1)%3;
      build_directed(a,m0,param,41+m0);build_directed(b,m1,param,51+m1);
      counted_pair(a,b,m0,param,m1,param,1000+2*(4*m0+m1));
    end
    // All16 successive mode transitions, separately observed on both contexts.
    for(int prior_mode=0;prior_mode<4;prior_mode++)for(int next_mode=0;next_mode<4;next_mode++)begin
      param=(prior_mode+next_mode)%3;
      build_directed(a,prior_mode,param,61);build_directed(b,prior_mode,param,62);
      counted_pair(a,b,prior_mode,param,prior_mode,param,1200+4*(4*prior_mode+next_mode));
      build_directed(a,next_mode,param,63);build_directed(b,next_mode,param,64);
      counted_pair(a,b,next_mode,param,next_mode,param,1202+4*(4*prior_mode+next_mode));
    end
    // Each possible accepted count0..16 in the first full secret chunk.
    // Even a zero-acceptance chunk belongs to a later correctly completed job.
    for(int count=0;count<=16;count++)begin
      a.delete();repeat(8)a.push_back(8'hff);
      for(int j=0;j<count;j++)a[j/2]&=8'(~(15<<(4*(j%2))));
      repeat((256-count+1)/2)a.push_back(0);
      command(EV_JOB,count%2,1600+count,1,count%3);send_bytes(count%2,a);
      expected_passed++;expected_modes[1]++;
    end
    // Prolonged independent output/status backpressure plus input blocking.
    for(int mode=0;mode<4;mode++)begin
      t=new("long_stalls");start_item(t);t.kind=EV_STALL;t.gap=320;t.value=1200;finish_item(t);
      build_directed(a,mode,mode%3,71);build_directed(b,mode,mode%3,72);
      counted_pair(a,b,mode,mode%3,mode,mode%3,1800+2*mode,1);
    end
    // Reusing a completed ID while the companion context remains available.
    repeat(2)begin
      build_directed(a,0,0,81);command(EV_JOB,0,1900,0,0);send_bytes(0,a);
      expected_passed++;expected_modes[0]++;
    end
    // Keep a partly shuffled challenge alive while the other slot completes
    // and reuses its ID. A descriptor must not clear the peer's reference/RAM.
    build_ball_bytes(b,1,94);command(EV_JOB,1,1951,3,1);
    begin
      bit [127:0] data;
      for(int packet=0;packet<2;packet++)begin
        data=0;for(int j=0;j<16;j++)data[8*j+:8]=b[16*packet+j];
        beat(1,data,16,0);
      end
    end
    pause_cycles(80);
    repeat(2)begin
      build_directed(a,0,0,95);command(EV_JOB,0,1950,0,0);
      feed_without_wait(a,0);command(EV_WAIT_SLOT,0);
      expected_passed++;expected_modes[0]++;
    end
    feed_without_wait(b,1,32);command(EV_WAIT);
    expected_passed++;expected_modes[3]++;
  endtask
endclass

class sampler_stage4_test extends sampler_smoke_test;
  `uvm_component_utils(sampler_stage4_test)
  sampler_stage4_seq seq;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task run_phase(uvm_phase phase);
    seq=sampler_stage4_seq::type_id::create("seq");
    phase.raise_objection(this);seq.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    if(env.scoreboard.passed!=seq.expected_passed || env.scoreboard.passed_matrix!=seq.expected_modes[0] ||
       env.scoreboard.passed_secret!=seq.expected_modes[1] || env.scoreboard.passed_mask!=seq.expected_modes[2] ||
       env.scoreboard.passed_ball!=seq.expected_modes[3] || env.scoreboard.failed_jobs!=seq.expected_errors || env.scoreboard.aborted!=seq.expected_aborts ||
       env.scoreboard.live[0] || env.scoreboard.live[1] || env.coverage.credited_jobs!=seq.expected_passed ||
       env.monitor.pipeline_reset_witnesses<2 || env.monitor.pipeline_bad_bytes_witnesses==0 ||
       uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0)
      `uvm_fatal("STAGE4_GATE",$sformatf("Incomplete directed regression: complete%0d/%0d errors%0d/%0d aborts%0d/%0d credits%0d reset_pipeline%0d bad_bytes_pipeline%0d",env.scoreboard.passed,seq.expected_passed,env.scoreboard.failed_jobs,seq.expected_errors,env.scoreboard.aborted,seq.expected_aborts,env.coverage.credited_jobs,env.monitor.pipeline_reset_witnesses,env.monitor.pipeline_bad_bytes_witnesses))
    `uvm_info("PASS",$sformatf("SAMPLER STAGE4 UVM PASS: %0d complete polynomials (A=%0d secret=%0d mask=%0d ball=%0d), %0d expected errors, %0d reset-aborted jobs, %0d checked coefficients; %0d coverage credits",env.scoreboard.passed,env.scoreboard.passed_matrix,env.scoreboard.passed_secret,env.scoreboard.passed_mask,env.scoreboard.passed_ball,env.scoreboard.failed_jobs,env.scoreboard.aborted,env.scoreboard.compared,env.coverage.credited_jobs),UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("STAGE4_SCOPE","12 success-gated groups; error/reset/internal occupancy coverage is the next bounded step",UVM_NONE)
  endfunction
endclass
