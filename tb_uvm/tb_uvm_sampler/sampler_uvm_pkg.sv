package sampler_uvm_pkg;
  import uvm_pkg::*;
  import sampler_pkg::*;
  import sampler_ref_pkg::*;
  `include "uvm_macros.svh"
  typedef enum {EV_JOB,EV_INPUT,EV_OUTPUT,EV_STATUS,EV_RESET,EV_WAIT,EV_PAUSE,EV_PROFILE,EV_STREAM,EV_TICK,EV_STALL,EV_WAIT_SLOT,EV_RESET_AT,EV_STALL_AT,EV_WAIT_DUAL_STATUS,EV_BAD_AT_COPY,EV_RANDOM_PROFILE,EV_PROBE_IDLE,EV_PROBE_BUSY,EV_PROBE_STOP,EV_PROTOCOL,EV_SIMULTANEOUS_ERRORS,EV_WAIT_SURPLUS,EV_STOP_THROUGH_STATUS,EV_BAD_AT_PACKED} kind_t;
  typedef struct packed {
    bit [5:0] count;
    bit [1:0] stages;
    bit simultaneous,wrap,clipped,stopped;
    bit dual_status,status_wait;
    bit [2:0] ball_state;
    bit [5:0] ball_edge;
  } sampler_cov_snapshot;

  class sampler_item extends uvm_sequence_item;
    `uvm_object_utils(sampler_item)
    kind_t kind;
    bit core, last;
    int unsigned id, mode, param, nbytes, index, value, code, gap;
    bit [127:0] data;
    byte unsigned streams[2][$];
    // Observed transcript, released for coverage only at checked success.
    byte unsigned cov_bytes[$];
    int unsigned cov_sizes[$],cov_values[$];
    bit cov_paired,cov_switched,cov_reused;
    int cov_prev_mode=4;
    int cov_out_stall,cov_status_stall,cov_input_block;
    bit input_blocked,output_stalled,status_stalled;
    sampler_cov_snapshot snapshot,snapshots[$];
    bit reset_hold,reset_decode,reset_packed,reset_collector;
    bit [1:0] reset_hold_mask,reset_decode_mask,reset_packed_mask,reset_collector_mask;
    int reset_ball_state[2];
    int prior_outcome=6,bad_bytes=-1,recovery_id,recovery_mode;
    int unsigned random_seed;
    bit [2:0] protocol_seen;
    bit source_observed;
    function new(string name="sampler_item"); super.new(name); endfunction
  endclass

  class sampler_smoke_seq extends uvm_sequence#(sampler_item);
    `uvm_object_utils(sampler_smoke_seq)
    function new(string name="sampler_smoke_seq"); super.new(name); endfunction
    task command(kind_t k, int core=0,id=0,mode=0,param=0);
      sampler_item t=sampler_item::type_id::create("command");
      start_item(t); t.kind=k; t.core=1'(core); t.id=id; t.mode=mode;
      t.param=param; finish_item(t);
    endtask
    task beat(int core, bit [127:0] data, int nbytes, bit last, int gap=0);
      sampler_item t=sampler_item::type_id::create("beat");
      start_item(t); t.kind=EV_INPUT; t.core=1'(core); t.data=data;
      t.nbytes=nbytes; t.last=last; t.gap=gap; finish_item(t);
    endtask
    function void build_bytes(ref byte unsigned b[$],input int seed);
      int accepted=0,j=0;
      int unsigned raw;
      b.delete();
      while(accepted<256) begin
        case(j%7)
          0:raw=8380417;        // q: reject
          1:raw=8380416;        // q-1: accept
          2:raw=24'hffffff;     // high bit masked, still reject
          3:raw=24'h800000 | ((j*7919+seed)%8380417);
          4:raw=0;
          5:raw=23'h7fe000;     // just below q
          default:raw=(j*65537+seed*83)%8380417;
        endcase
        b.push_back(8'(raw)); b.push_back(8'(raw>>8)); b.push_back(8'(raw>>16));
        if ((raw & 24'h7fffff)<8380417) accepted++;
        j++;
      end
      // Surplus trailing bytes belong to this job and must not leak on reuse.
      repeat(seed%3) b.push_back(8'hfe);
    endfunction
    function void build_secret_bytes(ref byte unsigned b[$],input int param,seed);
      int accepted=0,j=0,lo,hi;
      b.delete();
      while(accepted<256) begin
        lo=(j+seed)%16;hi=(j*5+seed*3)%16;
        b.push_back(8'(lo | (hi<<4)));
        if(lo<(param==1 ? 9:15))accepted++;
        if(accepted<256 && hi<(param==1 ? 9:15))accepted++;
        j++;
      end
    endfunction
    function void build_mask_bytes(ref byte unsigned b[$],input int param,seed);
      int width,gamma,t,filled=0;
      byte unsigned current_byte=0;
      width=param==0 ? 18:20;gamma=param==0 ? 131072:524288;
      b.delete();
      for(int i=0;i<256;i++)begin
        case(i%8)
          0:t=0;
          1:t=2*gamma-1;
          2:t=gamma;
          3:t=gamma-1;
          4:t=gamma+1;
          default:t=(i*7919+seed*65537)%(2*gamma);
        endcase
        // Construct fields bit-by-bit independently of the RTL chunk unpacker.
        for(int j=0;j<width;j++)begin
          current_byte[filled]=1'((t>>j)&1);filled++;
          if(filled==8)begin b.push_back(current_byte);current_byte=0;filled=0;end
        end
      end
      if(filled!=0 || b.size()!=(param==0 ? 576:640))
        `uvm_fatal("MASK_INPUT","Bad mask stimulus length")
    endfunction
    task send_bytes(input int core,ref byte unsigned b[$],input bit finite=1);
      int pos=0,n;
      bit [127:0] d;
      while(pos<b.size())begin
        n=b.size()-pos;if(n>16)n=16;
        d=0;for(int j=0;j<n;j++)d[j*8+:8]=b[pos+j];
        beat(core,d,n,finite && pos+n==b.size());pos+=n;
      end
      command(EV_WAIT);
    endtask
    task run_pair(ref byte unsigned a[$],ref byte unsigned b[$],
                  input int mode0,param0,mode1,param1,id,input bit full=0);
      int pa=0,pb=0,packet=0,na,nb;
      bit [127:0] d;
      int sizes[16]='{16,1,15,7,8,2,3,9,4,12,5,6,10,11,13,14};
      command(EV_JOB,0,id,mode0,param0);command(EV_JOB,1,id+1,mode1,param1);
      while(pa<a.size() || pb<b.size()) begin
        if(pa<a.size()) begin
          na=full ? 16:sizes[packet%16];if(na>a.size()-pa)na=a.size()-pa;
          d=0;for(int j=0;j<na;j++)d[j*8+:8]=a[pa+j];
          beat(0,d,na,pa+na==a.size(),packet%5==0 ? 2:0);pa+=na;
        end
        if(pb<b.size()) begin
          nb=full ? 16:sizes[(packet+5)%16];if(nb>b.size()-pb)nb=b.size()-pb;
          d=0;for(int j=0;j<nb;j++)d[j*8+:8]=b[pb+j];
          beat(1,d,nb,pb+nb==b.size(),packet%7==0 ? 3:0);pb+=nb;
        end
        packet++;
      end
      command(EV_WAIT);
    endtask
    task pause_cycles(int cycles);
      sampler_item t=sampler_item::type_id::create("pause");
      start_item(t);t.kind=EV_PAUSE;t.gap=cycles;finish_item(t);
    endtask
    function void build_ball_bytes(ref byte unsigned b[$],input int param,seed);
      int tau=param==0 ? 39:(param==1 ? 49:60);
      b.delete();
      for(int k=0;k<8;k++)b.push_back(seed%3==0 ? 8'hff : (seed%3==1 ? 8'h00 : 8'(8'ha5+k*17)));
      for(int i=256-tau;i<256;i++)begin
        if(i<255 && i%3==0)begin b.push_back(255);b.push_back(8'(i+1));end
        case((i+seed)%4)
          0:b.push_back(0); // repeated positions move old entries
          1:b.push_back(8'(i)); // j==i must end with the new sign
          default:b.push_back(8'((i*17+seed*31)%(i+1)));
        endcase
      end
    endfunction
    task ball_cases();
      byte unsigned a[$],b[$];
      for(int param=0;param<3;param++)begin
        build_ball_bytes(a,param,param*2+1);build_ball_bytes(b,param,param*2+2);
        run_pair(a,b,3,param,3,param,600+2*param,param==0);
      end
      build_ball_bytes(a,0,7);build_bytes(b,27);run_pair(a,b,3,0,0,2,610);
      build_secret_bytes(a,1,13);build_ball_bytes(b,1,8);run_pair(a,b,1,1,3,1,612);
      build_mask_bytes(a,2,14);build_ball_bytes(b,2,9);run_pair(a,b,2,2,3,2,614);
      // Hand-derived complete polynomial: repeat j=0, signs start 0x29.
      // Negative entries end at 218,221,223; 0 and the other 35 tail entries +1.
      a.delete();a.push_back(8'h29);repeat(7)a.push_back(0);repeat(39)a.push_back(0);
      a.push_back(8'hff); // final accepted beat surplus is discarded
      command(EV_JOB,0,620,3,0);send_bytes(0,a,0); // continuous-source completion
      // Reset during clear, partial signs, indexed shuffle, then output drain.
      command(EV_JOB,0,630,3,0);beat(0,0,1,0);command(EV_RESET);
      command(EV_JOB,1,631,3,1);beat(1,128'ha5,3,0);pause_cycles(300);command(EV_RESET);
      command(EV_JOB,0,632,3,2);beat(0,0,8,0);beat(0,0,16,0);
      pause_cycles(20);command(EV_RESET);
      a.delete();repeat(47)a.push_back(0);
      command(EV_JOB,1,633,3,0);
      for(int k=0;k<3;k++)beat(1,0,k==2 ? 15:16,k==2);
      pause_cycles(150);command(EV_RESET);
      build_ball_bytes(a,2,11);command(EV_JOB,1,634,3,2);send_bytes(1,a);
      // Finite-source failures: partial/full signs, all-reject, one short.
      command(EV_JOB,0,640,3,0);beat(0,0,7,1);command(EV_WAIT);
      command(EV_JOB,1,641,3,1);beat(1,0,8,1);command(EV_WAIT);
      command(EV_JOB,0,642,3,2);beat(0,'1,16,1);command(EV_WAIT);
      a.delete();repeat(46)a.push_back(0);
      command(EV_JOB,1,643,3,0);send_bytes(1,a);
      command(EV_JOB,0,644,3,0);beat(0,0,0,1);command(EV_WAIT);
      command(EV_JOB,1,645,3,2);beat(1,0,17,1);command(EV_WAIT);
      command(EV_JOB,0,646,3,3);command(EV_WAIT);
    endtask
    task mask_cases();
      byte unsigned a[$],b[$];
      byte unsigned example_bytes[18]='{8'h03,8'h00,8'h02,8'h00,8'he8,8'hff,
        8'h1f,8'h00,8'h00,8'hff,8'hff,8'hff,8'hff,8'h07,8'hd4,8'h30,8'ha8,8'h61};
      for(int param=0;param<3;param++)begin
        build_mask_bytes(a,param,param*2+1);build_mask_bytes(b,param,param*2+2);
        run_pair(a,b,2,param,2,param,500+2*param,param==0);
      end
      build_bytes(a,23);build_mask_bytes(b,1,7);run_pair(a,b,0,0,2,1,510);
      build_mask_bytes(a,0,8);build_secret_bytes(b,1,9);run_pair(a,b,2,0,1,1,512);
      // A literal non-byte-aligned 18-bit example, plus an all-ones wide mask.
      a.delete();b.delete();foreach(example_bytes[j])a.push_back(example_bytes[j]);
      repeat(558)a.push_back(0);repeat(640)b.push_back(8'hff);
      run_pair(a,b,2,0,2,2,520);
      // Reset a context holding one coefficient and twelve leftover mask bits.
      command(EV_JOB,0,530,2,1);beat(0,128'hea,1,0);beat(0,128'habcdef,3,0);
      command(EV_RESET);
      build_mask_bytes(a,1,10);command(EV_JOB,0,531,2,1);send_bytes(0,a);
      command(EV_JOB,1,540,2,0);beat(1,0,1,1);command(EV_WAIT);
      a.delete();repeat(639)a.push_back(0);
      command(EV_JOB,0,541,2,1);send_bytes(0,a);
      a.delete();repeat(575)a.push_back(0);
      command(EV_JOB,1,542,2,0);send_bytes(1,a);
    endtask
    task pipeline_cases();
      byte unsigned a[$],b[$];
      // Reset with both pipeline stages occupied, and another live descriptor.
      // Same slot/ID reuse after reset must never receive stale coefficients.
      for(int core=0;core<2;core++)begin
        command(EV_JOB,1-core,700+4*core,2,1);
        command(EV_JOB,core,701+4*core,1,core);
        beat(core,0,16,0);pause_cycles(1);command(EV_RESET);
        build_secret_bytes(a,core,31+core);build_mask_bytes(b,1,33+core);
        run_pair(a,b,1,core,2,1,700+4*core);
      end
      // Invalid metadata arrives while a previous valid beat is in flight.
      command(EV_JOB,0,710,1,0);beat(0,0,16,0);command(EV_BAD_AT_PACKED,0);command(EV_WAIT);
      build_secret_bytes(a,0,35);command(EV_JOB,0,710,1,0);send_bytes(0,a);
    endtask
    task body();
      byte unsigned a[$],b[$];
      int pa,pb,na,nb,packet;
      bit [127:0] d;
      int sizes[16]='{16,1,15,7,8,2,3,9,4,12,5,6,10,11,13,14};
      command(EV_RESET);
      for(int round=0;round<3;round++) begin
        build_bytes(a,round*2+1); build_bytes(b,round*2+2);
        command(EV_JOB,0,100+round*2,0,round);
        command(EV_JOB,1,101+round*2,0,round);
        pa=0;pb=0;packet=0;
        while(pa<a.size() || pb<b.size()) begin
          if(pa<a.size()) begin
            na=round==0 ? 16 : sizes[packet%16];
            if(na>a.size()-pa)na=a.size()-pa;
            d=0;for(int j=0;j<na;j++)d[j*8+:8]=a[pa+j];
            beat(0,d,na,pa+na==a.size(),packet%5==0 ? 2:0);pa+=na;
          end
          if(pb<b.size()) begin
            nb=round==0 ? 16 : sizes[(packet+5)%16];
            if(nb>b.size()-pb)nb=b.size()-pb;
            d=0;for(int j=0;j<nb;j++)d[j*8+:8]=b[pb+j];
            beat(1,d,nb,pb+nb==b.size(),packet%7==0 ? 3:0);pb+=nb;
          end
          packet++;
        end
        command(EV_WAIT);
      end
      // Finite exhausted stream must report failure, not fabricate output.
      command(EV_JOB,0,200); beat(0,128'h000102030405060708090a0b0c0d0e0f,16,1);
      command(EV_WAIT);
      command(EV_JOB,0,202,0,3); command(EV_WAIT); // invalid parameter
      command(EV_JOB,1,203); beat(1,0,0,1); command(EV_WAIT);
      command(EV_JOB,0,204); beat(0,0,17,1); command(EV_WAIT);
      // Exhaust after earlier groups have been offered: a held group must drain
      // before error status, preserving the same stall contract as success.
      command(EV_JOB,0,207);
      for(int j=0;j<5;j++)
        beat(0,128'h08070605040302010908070605040302,16,j==4);
      command(EV_WAIT);
      // Stage 1.2: both secret contexts, all parameter encodings and nibbles.
      for(int param=0;param<3;param++) begin
        build_secret_bytes(a,param,1+param*2);
        build_secret_bytes(b,param,2+param*2);
        run_pair(a,b,1,param,1,param,300+param*2,param==0);
      end
      // Mixed modes exercise per-slot mode, parameter, group and carry state.
      build_bytes(a,17);build_secret_bytes(b,1,7);
      run_pair(a,b,0,2,1,1,310);
      build_secret_bytes(a,0,8);build_bytes(b,18);
      run_pair(a,b,1,0,0,0,312);
      // Every candidate accepted: maximum 16-secret append per chunk.
      a.delete();b.delete();repeat(128)begin a.push_back(0);b.push_back(0);end
      run_pair(a,b,1,0,1,1,314,1);
      // No accepted nibble and finite input: deterministic exhausted status.
      command(EV_JOB,0,400,1,0);beat(0,'1,16,1);command(EV_WAIT);
      command(EV_JOB,1,401,1,1);
      beat(1,128'h99999999999999999999999999999999,16,1);command(EV_WAIT);
      // Error after a previously offered 16-result group; no success credit.
      command(EV_JOB,0,402,1,0);
      for(int j=0;j<4;j++)beat(0,128'h0123456789abcdef0123456789abcdef,16,j==3);
      command(EV_WAIT);
      // Reset secret state, then verify that a fresh secret starts at index 0.
      command(EV_JOB,1,403,1,1);beat(1,0,16,0);beat(1,0,1,0);
      command(EV_RESET);
      build_secret_bytes(a,1,11);command(EV_JOB,1,404,1,1);pa=0;
      while(pa<a.size())begin
        na=a.size()-pa;if(na>16)na=16;
        d=0;for(int j=0;j<na;j++)d[j*8+:8]=a[pa+j];
        beat(1,d,na,pa+na==a.size());pa+=na;
      end
      command(EV_WAIT);
      // Reset after a partial input/output prefix, then reuse the same slot.
      command(EV_JOB,0,205); beat(0,128'h090807060504030201,13,0);
      command(EV_RESET);
      build_bytes(a,9); command(EV_JOB,0,206);
      pa=0;
      while(pa<a.size()) begin
        na=a.size()-pa; if(na>16)na=16;
        d=0;for(int j=0;j<na;j++)d[j*8+:8]=a[pa+j];
        beat(0,d,na,pa+na==a.size());pa+=na;
      end
      command(EV_WAIT);
      mask_cases();
      ball_cases();
      pipeline_cases();
    endtask
  endclass

  class sampler_driver extends uvm_driver#(sampler_item);
    `uvm_component_utils(sampler_driver)
    virtual sampler_if vif;
    int simultaneous_errors[2],surplus_holds[2],stopped_completion[2];
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(virtual sampler_if)::get(this,"","vif",vif))
        `uvm_fatal("VIF","Missing interface")
    endfunction
    task run_phase(uvm_phase phase);
      vif.rst=1;vif.job_valid=0;vif.input_valid=0;vif.job_core=0;
      vif.job_id=0;vif.job_mode=0;vif.job_param=0;
      vif.input_data=0;vif.input_bytes=0;vif.input_core=0;vif.input_last=0;
      fork
        begin
          int cycle=0;
          int unsigned ready_state=1,prior_seed=0;
          forever begin
            @(negedge vif.clk);cycle++;
            if(vif.random_ready_seed!=prior_seed)begin
              ready_state=vif.random_ready_seed;prior_seed=vif.random_ready_seed;
            end
            ready_state^=ready_state<<13;ready_state^=ready_state>>17;ready_state^=ready_state<<5;
            vif.output_ready=vif.force_output_stall==0 && (vif.random_ready_seed!=0 ? ready_state[0] || ready_state[3]:(!vif.perf_stalls || (cycle%13>=4)));
            vif.status_ready=vif.force_status_stall==0 && (vif.random_ready_seed!=0 ? ready_state[2] || ready_state[7]:(!vif.perf_stalls || (cycle%17>=5)));
            if(vif.force_output_stall>0)vif.force_output_stall--;
            if(vif.force_status_stall>0)vif.force_status_stall--;
          end
        end
        begin
          sampler_item t;
          forever begin
            seq_item_port.get_next_item(t);
            case(t.kind)
              EV_RESET:begin
                @(negedge vif.clk);vif.rst=1;vif.job_valid=0;vif.input_valid=0;
                repeat(3)@(negedge vif.clk);
                vif.rst=0;
                vif.force_output_stall=0;vif.force_status_stall=0;
              end
              EV_RESET_AT:begin
                bit reached=0;
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  if(t.value>=8)begin
                    // Input command returns on the first post-accept negedge;
                    // inspect it before waiting so phase1 cannot be skipped.
                    #1ps;
                    reached=vif.source_probes && vif.perf_hold && vif.perf_hold_core==t.core &&
                      vif.probe_prepare_phase==t.value-7;
                    if(!reached)@(negedge vif.clk);
                  end else begin
                    @(negedge vif.clk);
                    reached=t.value==0 ? (vif.probe_decode_valid && vif.probe_packed_valid) :
                      (vif.perf_ball_state==t.value &&
                        (t.value==1 ? vif.perf_ball_clear_core==t.core:vif.perf_ball_selected==t.core));
                  end
                end
                if(!reached)`uvm_fatal("RESET_TARGET","Requested reset phase was not reached")
                if(t.value>=8)`uvm_info("PREP_RESET_TARGET",$sformatf("Observed input preparation phase%0d,core%0d before reset",t.value-7,t.core),UVM_NONE)
                #1ps;vif.rst=1;vif.job_valid=0;vif.input_valid=0;
                repeat(3)@(negedge vif.clk);vif.rst=0;
                vif.force_output_stall=0;vif.force_status_stall=0;
              end
              EV_STALL_AT:begin
                bit reached=0;
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  @(negedge vif.clk);
                  reached=t.value==0 ? (vif.output_valid && vif.output_core==t.core) :
                    (vif.status_valid && vif.status_core==t.core);
                end
                if(!reached)`uvm_fatal("STALL_TARGET","Requested stalled offer was not reached")
                #1ps;
                if(t.value==0)begin vif.force_output_stall=t.gap;vif.output_ready=0;end
                else begin vif.force_status_stall=t.gap;vif.status_ready=0;end
              end
              EV_JOB:begin
                @(negedge vif.clk);
                vif.job_valid=1;vif.job_core=t.core;vif.job_id=16'(t.id);
                vif.job_mode=2'(t.mode);vif.job_param=2'(t.param);
                vif.job_random_seed=t.random_seed;
                do @(posedge vif.clk); while(!vif.job_ready);
                @(negedge vif.clk);vif.job_valid=0;
              end
              EV_INPUT:begin
                repeat(t.gap)@(negedge vif.clk);
                @(negedge vif.clk);vif.input_valid=1;vif.input_core=t.core;
                vif.input_data=t.data;vif.input_bytes=5'(t.nbytes);vif.input_last=t.last;
                // Invalid high bytes are deliberately nonzero: only nbytes may affect the DUT.
                for(int j=0;j<16;j++)if(j>=t.nbytes)vif.input_data[j*8+:8]=8'hff;
                do @(posedge vif.clk); while(!vif.input_ready);
                @(negedge vif.clk);vif.input_valid=0;
              end
              EV_BAD_AT_PACKED:begin
                bit reached=0;
                // Synchronize the intended overlap instead of assuming a
                // fixed extraction-to-packed latency for every architecture.
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  @(negedge vif.clk);vif.input_core=t.core;#1ps;
                  reached=vif.probe_packed_valid && vif.probe_packed_core==t.core && vif.input_ready;
                end
                if(!reached)`uvm_fatal("BAD_BYTES_TARGET","Pending packed stage was not reached")
                vif.input_data='1;vif.input_bytes=0;vif.input_last=1;vif.input_valid=1;
                @(posedge vif.clk);
                if(!vif.input_ready)`uvm_fatal("BAD_BYTES_TARGET","Targeted invalid beat was not accepted")
                @(negedge vif.clk);vif.input_valid=0;
              end
              EV_PROFILE:begin vif.perf_stalls=1'(t.value);vif.perf_jobs=t.gap;end
              EV_RANDOM_PROFILE:begin #1ps;vif.random_ready_seed=t.random_seed;end
              EV_PROBE_IDLE,EV_PROBE_STOP:begin
                if(t.kind==EV_PROBE_STOP)begin
                  bit reached=0;
                  for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                    @(negedge vif.clk);reached=vif.source_stop[t.core];
                  end
                  if(!reached)`uvm_fatal("PROBE_TARGET","Source stop was not reached")
                end
                @(negedge vif.clk);#1ps;
                vif.input_core=t.core;vif.input_data='1;vif.input_bytes=16;
                vif.input_last=0;vif.input_valid=1;
                repeat(8)begin
                  @(posedge vif.clk);
                  if(vif.input_ready)`uvm_fatal("REFUSAL","Idle/stopped source input unexpectedly accepted")
                end
                @(negedge vif.clk);vif.input_valid=0;
              end
              EV_PROBE_BUSY:begin
                @(negedge vif.clk);#1ps;
                vif.job_core=t.core;vif.job_id=16'hdead;vif.job_mode=3;vif.job_param=3;vif.job_valid=1;
                repeat(8)begin
                  @(posedge vif.clk);
                  if(vif.job_ready)`uvm_fatal("REFUSAL","Occupied descriptor slot unexpectedly accepted replacement")
                end
                @(negedge vif.clk);vif.job_valid=0;
              end
              EV_STALL:begin vif.force_output_stall=t.gap;vif.force_status_stall=t.value;end
              EV_STREAM:begin
                int pos[2]='{0,0};int core=0,n,packet=0;
                @(negedge vif.clk);
                while(pos[0]<t.streams[0].size() || pos[1]<t.streams[1].size())begin
                  if(pos[core]>=t.streams[core].size())core=1-core;
                  if(vif.perf_stalls && packet>0 && packet%5==0)begin
                    vif.input_valid=0;repeat(2)@(negedge vif.clk);
                  end
                  n=t.streams[core].size()-pos[core];if(n>16)n=16;
                  vif.input_valid=1;vif.input_core=1'(core);vif.input_bytes=5'(n);
                  vif.input_last=pos[core]+n==t.streams[core].size();vif.input_data='1;
                  for(int j=0;j<n;j++)vif.input_data[8*j+:8]=t.streams[core][pos[core]+j];
                  do @(posedge vif.clk);while(!vif.input_ready);
                  pos[core]+=n;packet++;core=1-core;
                  @(negedge vif.clk);
                end
                vif.input_valid=0;
              end
              EV_PAUSE:repeat(t.gap)@(negedge vif.clk);
              EV_WAIT:begin
                do @(negedge vif.clk);while(vif.active!=0);
                repeat(2)@(negedge vif.clk);
              end
              EV_WAIT_SLOT:begin
                do @(negedge vif.clk);while(vif.active[t.core]);
                repeat(2)@(negedge vif.clk);
              end
              EV_WAIT_DUAL_STATUS:begin
                bit reached=0;
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  @(negedge vif.clk);reached=vif.probe_status_eligible==2'b11;
                end
                if(!reached)`uvm_fatal("STATUS_TARGET","Both statuses were not pending simultaneously")
                #1ps;vif.force_status_stall=0;vif.status_ready=1;
              end
              EV_SIMULTANEOUS_ERRORS:begin
                // Both failures register on one edge, through separate public
                // input channels. No force/deposit of internal state is used.
                @(negedge vif.clk);#1ps;
                vif.job_core=t.core;vif.job_id=16'(t.id);vif.job_mode=0;
                vif.job_param=3;vif.job_random_seed=0;vif.job_valid=1;
                vif.input_core=~t.core;vif.input_bytes=0;vif.input_last=1;
                vif.input_data=0;vif.input_valid=1;
                @(posedge vif.clk);
                if(!vif.job_ready || !vif.input_ready)
                  `uvm_fatal("DUAL_ERROR_TARGET","Both independent error requests must be accepted on one edge")
                @(negedge vif.clk);#1ps;
                vif.job_valid=0;vif.input_valid=0;
                if(vif.probe_status_lock || vif.probe_status_eligible!=3 ||
                   !vif.status_valid || vif.status_core!=1'(t.value))
                  `uvm_fatal("DUAL_ERROR_TARGET","Unlocked simultaneous eligibility/round-robin choice missing")
                simultaneous_errors[t.value]++;
              end
              EV_WAIT_SURPLUS:begin
                bit reached=0;
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  @(negedge vif.clk);
                  reached=vif.perf_hold && vif.perf_hold_core==t.core && vif.perf_gen[t.core]==256;
                end
                if(!reached)`uvm_fatal("SURPLUS_TARGET","Held surplus after coefficient256 was not reached")
                surplus_holds[t.core]++;
              end
              EV_STOP_THROUGH_STATUS:begin
                bit reached=0;
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  @(negedge vif.clk);reached=vif.source_stop[t.core];
                end
                if(!reached)`uvm_fatal("STOP_STATUS_TARGET","Source stop was not reached")
                #1ps;vif.input_core=t.core;vif.input_data='1;
                vif.input_bytes=16;vif.input_last=0;vif.input_valid=1;
                vif.force_status_stall=0;vif.status_ready=1;
                do begin
                  @(posedge vif.clk);
                  if(vif.input_ready)`uvm_fatal("REFUSAL","Stopped input unexpectedly accepted")
                end while(!(vif.status_valid && vif.status_ready && vif.status_core==t.core));
                stopped_completion[t.core]++;
                @(negedge vif.clk);vif.input_valid=0;
              end
              EV_BAD_AT_COPY:begin
                bit reached=0;
                for(int wait_cycle=0;wait_cycle<10000 && !reached;wait_cycle++)begin
                  @(negedge vif.clk);
                  reached=vif.perf_ball_state==2 && vif.perf_ball_selected==t.core && !vif.perf_hold;
                end
                if(!reached)`uvm_fatal("ABORT_TARGET","COPY with empty input holding register was not reached")
                #1ps;vif.input_core=t.core;vif.input_bytes=0;vif.input_last=1;
                vif.input_data='1;vif.input_valid=1;
                @(posedge vif.clk);
                if(!vif.input_ready)`uvm_fatal("ABORT_TARGET","Malformed beat was not accepted during COPY")
                @(negedge vif.clk);vif.input_valid=0;
              end
              default:`uvm_fatal("DRIVER","Unsupported item")
            endcase
            seq_item_port.item_done();
          end
        end
      join
    endtask
  endclass

  class sampler_monitor extends uvm_monitor;
    `uvm_component_utils(sampler_monitor)
    virtual sampler_if vif;
    uvm_analysis_port#(sampler_item) ap;
    uvm_analysis_port#(sampler_item) timing_ap;
    bit timing_enabled;
    bit stalled_out,stalled_status;
    int pipeline_reset_witnesses,pipeline_bad_bytes_witnesses;
    bit fault_injected;
    string fault_kind="value";
    int prior_ball_state,prior_ball_owner;
    int expected_count[2];bit check_count[2];
    bit [48:0] prior_out;
    bit [19:0] prior_status;
    function new(string n,uvm_component p);super.new(n,p);ap=new("ap",this);timing_ap=new("timing_ap",this);endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(virtual sampler_if)::get(this,"","vif",vif))
        `uvm_fatal("VIF","Missing interface")
      void'($value$plusargs("SAMPLER_FAULT_KIND=%s",fault_kind));
    endfunction
    task run_phase(uvm_phase phase);
      sampler_item t;
      timing_enabled=$test$plusargs("SAMPLER_PERFORMANCE");
      forever begin
        @(posedge vif.clk);
        if(timing_enabled)begin t=new("tick");t.kind=EV_TICK;timing_ap.write(t);end
        if(vif.rst) begin
          if(vif.probe_decode_valid===1'b1 && vif.probe_packed_valid===1'b1)
            pipeline_reset_witnesses++;
          t=new("reset");t.kind=EV_RESET;t.source_observed=vif.source_probes;
          for(int k=0;k<2;k++)begin
            if(vif.source_probes)begin
            t.reset_hold_mask[k]=vif.perf_hold && vif.perf_hold_core==k;
            t.reset_decode_mask[k]=vif.probe_decode_valid && vif.probe_decode_core==k;
            t.reset_packed_mask[k]=vif.probe_packed_valid && vif.probe_packed_core==k;
            t.reset_collector_mask[k]=vif.perf_count[k]!=0;
            t.reset_ball_state[k]=(vif.perf_ball_state==0 ||
              (vif.perf_ball_state==1 ? vif.perf_ball_clear_core==k:vif.perf_ball_selected==k)) ? int'(vif.perf_ball_state):5;
            end else t.reset_ball_state[k]=5;
            check_count[k]=0;
          end
          ap.write(t);if(timing_enabled)timing_ap.write(t);
          stalled_out=0;stalled_status=0;
        end else begin
          // External handshake witnesses are cached, never sampled directly.
          for(int k=0;k<2;k++)begin
            int delta=int'(vif.perf_gen_next[k])-int'(vif.perf_gen[k]);
            int owner=vif.perf_ball_state==1 ? int'(vif.perf_ball_clear_core):int'(vif.perf_ball_selected);
            // Occupancy follows fetch into the output slot. External outputs
            // are still independently checked at their external handshake.
            bit pop=vif.probe_collector_fetch[k];
            if(vif.job_valid && vif.job_ready && vif.job_core==k)delta=0;
            if(vif.source_probes && check_count[k] && vif.perf_count[k]!=expected_count[k])
              `uvm_fatal("OCCUPANCY","Collector append/pop conservation violated")
            if(vif.source_probes && (vif.perf_count[k]>32 || delta<0 || delta>16))
              `uvm_fatal("OCCUPANCY","Collector occupancy/append bound violated")
            expected_count[k]=int'(vif.perf_count[k])+delta-int'(pop);check_count[k]=1;
            // Retired contexts retain unowned numeric state until the next
            // edge;count and reservation then clear together. Continue to
            // check that edge rather than dropping inactive-context checks.
            if(!vif.active[k] || (vif.job_valid && vif.job_ready && vif.job_core==k))expected_count[k]=0;
            if(vif.source_probes && !vif.active[k] && (delta!=0 || pop))
              `uvm_fatal("OCCUPANCY","Unowned collector appended or fetched data")
            t=new("activity");t.kind=EV_TICK;t.core=1'(k);
            t.source_observed=vif.source_probes;
            t.input_blocked=vif.input_valid && vif.input_core==k && !vif.input_ready;
            t.output_stalled=vif.output_valid && vif.output_core==k && !vif.output_ready;
            t.status_stalled=vif.status_valid && vif.status_core==k && !vif.status_ready;
            t.snapshot.count=vif.perf_count[k];
            t.snapshot.stages={vif.probe_packed_valid && vif.probe_packed_core==k,vif.probe_decode_valid && vif.probe_decode_core==k};
            t.snapshot.simultaneous=delta>0 && pop;
            t.snapshot.wrap=(pop && vif.probe_head[k]==31) || (delta>0 && int'(vif.probe_tail[k])+delta>=32);
            t.snapshot.clipped=vif.probe_decode_transfer && vif.probe_decode_core==k && vif.probe_compact_count>vif.probe_admit_count;
            t.snapshot.stopped=vif.source_stop[k];
            t.snapshot.dual_status=vif.probe_status_eligible==2'b11;
            t.snapshot.status_wait=vif.status_valid && vif.status_core==k && !vif.status_ready;
            t.snapshot.ball_state=vif.perf_ball_state==0 || owner==k ? vif.perf_ball_state:3'd5;
            t.snapshot.ball_edge=((vif.perf_ball_state==0 || owner==k) &&
              (prior_ball_state==0 || prior_ball_owner==k)) ? 6'(prior_ball_state*8+int'(vif.perf_ball_state)):6'd63;
            ap.write(t);
          end
          if($isunknown({vif.output_valid,vif.status_valid,vif.active,vif.source_stop}))
            `uvm_fatal("UNKNOWN","Unknown DUT handshake/state output")
          if(vif.output_valid && $isunknown({vif.output_core,vif.output_id,
              vif.output_index,vif.output_data,vif.output_last}))
            `uvm_fatal("UNKNOWN","Unknown coefficient payload")
          if(vif.status_valid && $isunknown({vif.status_core,vif.status_id,vif.status_code}))
            `uvm_fatal("UNKNOWN","Unknown status payload")
          if(stalled_out && (!vif.output_valid ||
             {vif.output_core,vif.output_id,vif.output_index,vif.output_data,vif.output_last}!=prior_out))
            `uvm_error("OUTPUT_STALL","Output changed while stalled")
          if(stalled_status && (!vif.status_valid ||
             {vif.status_core,vif.status_id,vif.status_code}!=prior_status))
            `uvm_error("STATUS_STALL","Status changed while stalled")
          stalled_out=vif.output_valid && !vif.output_ready;
          prior_out={vif.output_core,vif.output_id,vif.output_index,vif.output_data,vif.output_last};
          stalled_status=vif.status_valid && !vif.status_ready;
          prior_status={vif.status_core,vif.status_id,vif.status_code};
          // Refusals describe PRE-edge ownership. Publish them before accepted
          // statuses retire a job, including a stopped valid held through its
          // completion handshake. Otherwise a valid observation looks unowned.
          if(vif.input_valid && !vif.input_ready && (!vif.active[vif.input_core] || vif.source_stop[vif.input_core]))begin
            t=new("refused_input");t.kind=EV_PROTOCOL;t.core=vif.input_core;
            t.code=vif.active[vif.input_core] ? 3:1;ap.write(t);
          end
          if(vif.job_valid && !vif.job_ready && vif.active[vif.job_core])begin
            t=new("blocked_descriptor");t.kind=EV_PROTOCOL;t.core=vif.job_core;t.code=2;ap.write(t);
          end
          if(vif.job_valid && vif.job_ready) begin
            t=new("job");t.kind=EV_JOB;t.core=vif.job_core;t.id=vif.job_id;
            t.mode=vif.job_mode;t.param=vif.job_param;t.random_seed=vif.job_random_seed;ap.write(t);if(timing_enabled)timing_ap.write(t);
          end
          if(vif.input_valid && vif.input_ready) begin
            if((vif.input_bytes==0 || vif.input_bytes>16) && vif.probe_packed_valid)
              pipeline_bad_bytes_witnesses++;
            t=new("input");t.kind=EV_INPUT;t.core=vif.input_core;t.data=vif.input_data;
            t.nbytes=vif.input_bytes;t.last=vif.input_last;ap.write(t);if(timing_enabled)timing_ap.write(t);
          end
          if(vif.output_valid && vif.output_ready) begin
            t=new("output");t.kind=EV_OUTPUT;t.core=vif.output_core;t.id=vif.output_id;
            t.index=vif.output_index;t.value=vif.output_data;t.last=vif.output_last;
            if($test$plusargs("SAMPLER_INJECT_BAD_OUTPUT") && !fault_injected && fault_kind!="status")begin
              case(fault_kind)
                "value":t.value^=1;
                "index":t.index++;
                "tag":t.id^=1;
                "last":t.last=~t.last;
                default:`uvm_fatal("FAULT_CONFIG","Unknown fault kind")
              endcase
              fault_injected=1;
              `uvm_info("FAULT_INJECT",$sformatf("Deliberate first-output %s corruption; expect COEFFICIENT fatal before coverage credit",fault_kind),UVM_NONE)
            end
            ap.write(t);if(timing_enabled)timing_ap.write(t);
          end
          if(vif.status_valid && vif.status_ready) begin
            t=new("status");t.kind=EV_STATUS;t.core=vif.status_core;t.id=vif.status_id;
            t.code=vif.status_code;
            if($test$plusargs("SAMPLER_INJECT_BAD_OUTPUT") && !fault_injected && fault_kind=="status")begin
              t.code^=4;fault_injected=1;
              `uvm_info("FAULT_INJECT","Deliberate first-status corruption; expect STATUS fatal before coverage credit",UVM_NONE)
            end
            ap.write(t);if(timing_enabled)timing_ap.write(t);
          end
        end
        prior_ball_state=vif.perf_ball_state;
        prior_ball_owner=vif.perf_ball_state==1 ? int'(vif.perf_ball_clear_core):int'(vif.perf_ball_selected);
      end
    endtask
  endclass

  class sampler_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(sampler_scoreboard)
    uvm_analysis_imp#(sampler_item,sampler_scoreboard) imp;
    uvm_analysis_port#(sampler_item) checked_ap;
    uvm_analysis_port#(sampler_item) outcome_ap;
    byte unsigned pending[2][$];
    bit pending_bits[2][$];
    int unsigned expected[2][$];
    bit live[2];int ids[2],modes[2],params[2],seen[2],error_code[2];
    int passed_matrix,passed_secret,passed_mask,passed_ball;
    int ball_i[2];int ball_coeff[2][256];bit ball_signs_ready[2];
    int ball_rejected,ball_self,ball_repeated;
    int nonzero[2];
    int received_bytes[2];
    byte unsigned cov_bytes[2][$];
    int unsigned cov_sizes[2][$];
    bit cov_paired[2],cov_switched[2],cov_reused[2],closed_valid[2];
    int last_closed_id[2],previous_mode[2]='{4,4},job_prev_mode[2];
    bit previous_input_valid,previous_input_core;
    int out_run[2],status_run[2],input_run[2],out_max[2],status_max[2],input_max[2];
    int passed,failed_jobs,compared,aborted;
    sampler_cov_snapshot snapshots[2][$];
    sampler_item reset_pending[2][$];
    int last_outcome[2]='{6,6},job_prior_outcome[2],bad_bytes[2];
    int unsigned job_random_seed[2];
    bit [2:0] job_protocol_seen[2];
    function new(string n,uvm_component p);
      super.new(n,p);imp=new("imp",this);checked_ap=new("checked_ap",this);outcome_ap=new("outcome_ap",this);
    endfunction
    function void write(sampler_item t);
      int tau,nz;
      int c=t.core;int unsigned x;int signed signed_value;int width,gamma,field;
      bit next_bit;
      byte unsigned b0,b1,b2;
      sampler_item checked;
      if(t.kind==EV_RESET) begin
        foreach(live[k])begin
          if(live[k])begin
            aborted++;
            checked=new("aborted_pending_recovery");checked.kind=EV_RESET;
            checked.core=1'(k);checked.id=ids[k];checked.mode=modes[k];checked.param=params[k];checked.value=seen[k];
            checked.source_observed=t.source_observed;
            checked.reset_hold=t.reset_hold_mask[k];checked.reset_decode=t.reset_decode_mask[k];
            checked.reset_packed=t.reset_packed_mask[k];checked.reset_collector=t.reset_collector_mask[k];
            checked.snapshot.ball_state=3'(t.reset_ball_state[k]);reset_pending[k].push_back(checked);
            last_outcome[k]=5;
            `uvm_info("RESET_ABORT",$sformatf("id%0d mode%0d coefficients%0d bytes%0d",ids[k],modes[k],seen[k],received_bytes[k]),UVM_LOW)
          end
          live[k]=0;pending[k].delete();expected[k].delete();seen[k]=0;error_code[k]=0;
          pending_bits[k].delete();received_bytes[k]=0;
          cov_bytes[k].delete();cov_sizes[k].delete();previous_mode[k]=4;closed_valid[k]=0;
        end
        previous_input_valid=0;
        return;
      end
      case(t.kind)
        EV_PROTOCOL:begin
          if(t.code==1)begin
            if(live[c])`uvm_fatal("PROTOCOL_ORACLE","Idle-tag observation contradicts scoreboard ownership")
            checked=new("checked_idle_refusal");checked.kind=EV_PROTOCOL;checked.core=t.core;checked.code=1;
            outcome_ap.write(checked);
          end else begin
            if(!live[c] || (t.code!=2 && t.code!=3))`uvm_fatal("PROTOCOL_ORACLE","Refusal without live ownership")
            if(t.code==3 && error_code[c]==0 && expected[c].size()!=256)
              `uvm_fatal("PROTOCOL_ORACLE","Source stopped before complete reference polynomial")
            job_protocol_seen[c][t.code-1]=1;
          end
        end
        EV_TICK:if(live[c])begin
          if(t.source_observed && (snapshots[c].size()==0 || snapshots[c][$]!=t.snapshot))snapshots[c].push_back(t.snapshot);
          out_run[c]=t.output_stalled ? out_run[c]+1:0;
          status_run[c]=t.status_stalled ? status_run[c]+1:0;
          input_run[c]=t.input_blocked ? input_run[c]+1:0;
          if(out_run[c]>out_max[c])out_max[c]=out_run[c];
          if(status_run[c]>status_max[c])status_max[c]=status_run[c];
          if(input_run[c]>input_max[c])input_max[c]=input_run[c];
        end
        EV_JOB:begin
          if(live[c])`uvm_fatal("REUSE","Job reused before status")
          live[c]=1;ids[c]=t.id;modes[c]=t.mode;params[c]=t.param;seen[c]=0;
          pending[c].delete();expected[c].delete();
          pending_bits[c].delete();received_bytes[c]=0;nonzero[c]=0;
          tau=t.param==0 ? 39:(t.param==1 ? 49:60);
          ball_i[c]=256-tau;ball_signs_ready[c]=0;
          for(int j=0;j<256;j++)ball_coeff[c][j]=0;
          error_code[c]=t.param==3 ? 3:0;
          cov_bytes[c].delete();cov_sizes[c].delete();
          cov_paired[c]=live[1-c];if(live[1-c])cov_paired[1-c]=1;
          cov_switched[c]=0;cov_reused[c]=closed_valid[c] && last_closed_id[c]==t.id;
          job_prev_mode[c]=previous_mode[c];
          out_run[c]=0;status_run[c]=0;input_run[c]=0;
          out_max[c]=0;status_max[c]=0;input_max[c]=0;
          snapshots[c].delete();job_prior_outcome[c]=last_outcome[c];bad_bytes[c]=-1;
          job_random_seed[c]=t.random_seed;job_protocol_seen[c]=0;
        end
        EV_INPUT:begin
          if(!live[c])`uvm_fatal("INPUT","Unowned input")
          if(t.nbytes==0 || t.nbytes>16)begin error_code[c]=4;bad_bytes[c]=t.nbytes;end
          else begin
            received_bytes[c]+=t.nbytes;
            cov_sizes[c].push_back(t.nbytes);
            for(int j=0;j<t.nbytes;j++)cov_bytes[c].push_back(t.data[j*8+:8]);
            if(previous_input_valid && previous_input_core!=c && live[1-c])cov_switched[c]=1;
            previous_input_valid=1;previous_input_core=1'(c);
            if(modes[c]==3)begin
              for(int j=0;j<t.nbytes;j++)pending[c].push_back(t.data[j*8+:8]);
              if(!ball_signs_ready[c] && pending[c].size()>=8)begin
                repeat(8)begin
                  b0=pending[c].pop_front();
                  for(int k=0;k<8;k++)pending_bits[c].push_back(b0[k]);
                end
                ball_signs_ready[c]=1;
              end
              // Scalar signed array: no DUT compact encoding, RAM or FSM reuse.
              while(ball_signs_ready[c] && ball_i[c]<256 && pending[c].size()>0)begin
                b0=pending[c].pop_front();
                if(int'(b0)<=ball_i[c])begin
                  if(int'(b0)==ball_i[c])ball_self++;
                  if(ball_coeff[c][int'(b0)]!=0)ball_repeated++;
                  ball_coeff[c][ball_i[c]]=ball_coeff[c][int'(b0)];
                  next_bit=pending_bits[c].pop_front();
                  ball_coeff[c][int'(b0)]=1-2*int'(next_bit);
                  ball_i[c]++;
                end else ball_rejected++;
              end
              if(ball_i[c]==256 && expected[c].size()==0)begin
                for(int j=0;j<256;j++)expected[c].push_back(
                  ball_coeff[c][j]<0 ? 8380417+ball_coeff[c][j] : ball_coeff[c][j]);
              end
            end else if(modes[c]==2)begin
              width=params[c]==0 ? 18:20;gamma=params[c]==0 ? 131072:524288;
              for(int j=0;j<t.nbytes;j++)
                for(int b=0;b<8;b++)pending_bits[c].push_back(t.data[j*8+b]);
              // Scalar bit FIFO, no reuse of the RTL's parallel extraction.
              while(pending_bits[c].size()>=width && expected[c].size()<256)begin
                field=0;
                for(int b=0;b<width;b++)begin
                  next_bit=pending_bits[c].pop_front();field|=int'(next_bit)<<b;
                end
                signed_value=gamma-field;
                expected[c].push_back(signed_value<0 ? 8380417+signed_value : signed_value);
              end
            end else begin
            for(int j=0;j<t.nbytes;j++)pending[c].push_back(t.data[j*8+:8]);
            if(modes[c]==1)begin
              while(pending[c].size()>0 && expected[c].size()<256)begin
                b0=pending[c].pop_front();
                for(int nib=0;nib<2;nib++)begin
                  signed_value=secret_candidate((int'(b0)>>(4*nib)) & 15,params[c]==1);
                  if(signed_value!=-99 && expected[c].size()<256)
                    expected[c].push_back(signed_value<0 ? 8380417+signed_value : signed_value);
                end
              end
            end else while(pending[c].size()>=3 && expected[c].size()<256) begin
              b0=pending[c].pop_front();b1=pending[c].pop_front();b2=pending[c].pop_front();
              x=matrix_candidate(b0,b1,b2);
              if(x<8380417)expected[c].push_back(x);
            end
            end
            if(t.last && expected[c].size()<256)error_code[c]=1;
          end
        end
        EV_OUTPUT:begin
          if(!live[c] || t.id!=ids[c] || t.index!=seen[c] ||
             seen[c]>=expected[c].size() || t.value!=expected[c][seen[c]] ||
             t.last!=(seen[c]==255))
            `uvm_fatal("COEFFICIENT",$sformatf("core%0d id%0d index%0d value%0d expected_index%0d",c,t.id,t.index,t.value,seen[c]))
          seen[c]++;compared++;
          if(modes[c]==3)begin
            if(t.value!=0 && t.value!=1 && t.value!=8380416)
              `uvm_fatal("BALL_RANGE","Challenge coefficient outside 0,+1,-1")
            if(t.value!=0)nonzero[c]++;
            if(t.id==620)begin
              x=(t.index==218 || t.index==221 || t.index==223) ? 8380416 :
                ((t.index==0 || t.index>=218) ? 1:0);
              if(t.value!=x)`uvm_fatal("BALL_LITERAL","Hand-derived repeated-zero challenge mismatch")
            end
          end
          if(t.id==520 && t.index<8)begin
            signed_value=mask_example_signed(t.index);
            x=signed_value<0 ? 8380417+signed_value : signed_value;
            if(t.value!=x)`uvm_fatal("MASK_LITERAL","Literal 18-bit worked example mismatch")
          end
        end
        EV_STATUS:begin
          if(!live[c] || t.id!=ids[c] || t.code!=error_code[c])
            `uvm_fatal("STATUS",$sformatf("Unexpected status id%0d code%0d want%0d",t.id,t.code,error_code[c]))
          if(t.code==0)begin
            if(seen[c]!=256 || expected[c].size()!=256)
              `uvm_fatal("COUNT","Successful polynomial incomplete")
            if(modes[c]==2 && (received_bytes[c]<(params[c]==0 ? 576:640) ||
               received_bytes[c]>(params[c]==0 ? 591:655)))
              `uvm_fatal("MASK_BYTES","Mask input consumption outside final-beat bound")
            if(modes[c]==3 && nonzero[c]!=(params[c]==0 ? 39:(params[c]==1 ? 49:60)))
              `uvm_fatal("BALL_WEIGHT","Challenge Hamming weight mismatch")
            passed++;
            case(modes[c])
              0:passed_matrix++;
              1:passed_secret++;
              2:passed_mask++;
              3:passed_ball++;
              default:`uvm_fatal("MODE","Unsupported mode reported success")
            endcase
            checked=new("checked");checked.core=t.core;checked.mode=modes[c];
            checked.kind=EV_STATUS;checked.code=0;
            checked.param=params[c];checked.id=t.id;checked.value=seen[c];
            checked.cov_bytes=cov_bytes[c];checked.cov_sizes=cov_sizes[c];checked.cov_values=expected[c];
            checked.cov_paired=cov_paired[c];checked.cov_switched=cov_switched[c];
            checked.cov_reused=cov_reused[c];checked.cov_prev_mode=job_prev_mode[c];
            checked.cov_out_stall=out_max[c];checked.cov_status_stall=status_max[c];
            checked.cov_input_block=input_max[c];checked.snapshots=snapshots[c];
            checked.prior_outcome=job_prior_outcome[c];checked.random_seed=job_random_seed[c];
            checked.protocol_seen=job_protocol_seen[c];checked_ap.write(checked);outcome_ap.write(checked);
            while(reset_pending[c].size()>0)begin
              checked=reset_pending[c].pop_front();checked.recovery_id=t.id;checked.recovery_mode=modes[c];
              outcome_ap.write(checked);
            end
          end else begin
            failed_jobs++;
            checked=new("checked_error");checked.kind=EV_STATUS;checked.core=t.core;
            checked.mode=modes[c];checked.param=params[c];checked.id=t.id;checked.code=t.code;
            checked.value=seen[c];checked.bad_bytes=bad_bytes[c];checked.cov_paired=cov_paired[c];
            outcome_ap.write(checked);
          end
          `uvm_info("CHECKED_JOB",$sformatf("id%0d mode%0d param%0d code%0d coefficients%0d bytes%0d",t.id,modes[c],params[c],t.code,seen[c],received_bytes[c]),UVM_LOW)
          live[c]=0;
          previous_mode[c]=t.code==0 ? modes[c]:4;
          closed_valid[c]=1;last_closed_id[c]=t.id;
          last_outcome[c]=t.code;
        end
        default:`uvm_fatal("SCOREBOARD","Unknown observation")
      endcase
    endfunction
  endclass

  `include "sampler_coverage.svh"
  `include "sampler_outcome_coverage.svh"

  class sampler_env extends uvm_env;
    `uvm_component_utils(sampler_env)
    sampler_driver driver;sampler_monitor monitor;sampler_scoreboard scoreboard;
    sampler_coverage coverage;uvm_sequencer#(sampler_item) sequencer;
    sampler_outcome_coverage outcome_coverage;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      driver=sampler_driver::type_id::create("driver",this);
      monitor=sampler_monitor::type_id::create("monitor",this);
      scoreboard=sampler_scoreboard::type_id::create("scoreboard",this);
      coverage=sampler_coverage::type_id::create("coverage",this);
      outcome_coverage=sampler_outcome_coverage::type_id::create("outcome_coverage",this);
      sequencer=new("sequencer",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      monitor.ap.connect(scoreboard.imp);scoreboard.checked_ap.connect(coverage.analysis_export);
      scoreboard.outcome_ap.connect(outcome_coverage.analysis_export);
    endfunction
  endclass

  class sampler_smoke_test extends uvm_test;
    `uvm_component_utils(sampler_smoke_test)
    sampler_env env;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);env=sampler_env::type_id::create("env",this);endfunction
    task run_phase(uvm_phase phase);
      sampler_smoke_seq seq=sampler_smoke_seq::type_id::create("seq");
      phase.raise_objection(this);seq.start(env.sequencer);#100ns;phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
      if(env.scoreboard.passed!=52 || env.scoreboard.passed_matrix!=11 ||
         env.scoreboard.passed_secret!=16 || env.scoreboard.passed_mask!=14 ||
         env.scoreboard.passed_ball!=11 ||
         env.scoreboard.failed_jobs!=19 || env.scoreboard.aborted!=11 ||
         env.scoreboard.live[0] || env.scoreboard.live[1])
        `uvm_fatal("GATE",$sformatf("passed%0d errors%0d aborted%0d",env.scoreboard.passed,env.scoreboard.failed_jobs,env.scoreboard.aborted))
      if(env.scoreboard.ball_rejected==0 || env.scoreboard.ball_self==0 || env.scoreboard.ball_repeated==0)
        `uvm_fatal("GATE","Challenge rejection/self/repeated-position stimulus missing")
      if(uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0)
        `uvm_fatal("GATE","Unexpected UVM errors")
      if(env.monitor.pipeline_reset_witnesses<2 || env.monitor.pipeline_bad_bytes_witnesses==0)
        `uvm_fatal("PIPELINE_GATE","Pending-stage reset/invalid-byte stimulus was not observed")
      `uvm_info("PIPELINE_WITNESSES",$sformatf("reset with both stages occupied=%0d; invalid-byte acceptance with packed work pending=%0d; these are protocol witnesses, not success coverage",env.monitor.pipeline_reset_witnesses,env.monitor.pipeline_bad_bytes_witnesses),UVM_LOW)
      `uvm_info("BALL_WITNESSES",$sformatf("reference candidates: rejected=%0d self-index=%0d repeated-nonzero=%0d (includes aborted/error inputs; only checked complete jobs credit coverage)",env.scoreboard.ball_rejected,env.scoreboard.ball_self,env.scoreboard.ball_repeated),UVM_LOW)
      `uvm_info("PASS",$sformatf("SAMPLER FOUR-MODE UVM PASS: %0d complete polynomials (A=%0d secret=%0d mask=%0d ball=%0d), %0d expected errors, %0d reset-aborted jobs, %0d checked coefficients",env.scoreboard.passed,env.scoreboard.passed_matrix,env.scoreboard.passed_secret,env.scoreboard.passed_mask,env.scoreboard.passed_ball,env.scoreboard.failed_jobs,env.scoreboard.aborted,env.scoreboard.compared),UVM_NONE)
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("COVERAGE",$sformatf("Completed-job group: %0.2f%%; full12-group summary is reported by env.coverage",env.coverage.checked_polynomial.get_inst_coverage()),UVM_NONE)
    endfunction
  endclass
  `include "sampler_vector_classes.svh"
  `include "sampler_performance_classes.svh"
  `include "sampler_stage4_classes.svh"
  `include "sampler_stage4_2_classes.svh"
  `include "sampler_stage4_3_classes.svh"
  `include "sampler_stage4_4_classes.svh"
  `include "sampler_stage4_5_classes.svh"
  `include "sampler_stage4_6_classes.svh"
  `include "sampler_stage4_9_classes.svh"
  `include "sampler_netlist_classes.svh"
endpackage
