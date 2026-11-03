package dilithium_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  typedef enum {START,INPUT_SIGN,INPUT_VERIFY,KEY_WORD,SIG_WORD,DONE,RESET,RETIRED} event_e;
  function automatic byte unsigned octet(string s,int i);
    bit [7:0] v;
    if(s=="-" || i<0 || 2*i+1>=s.len())return 0;
    if($sscanf(s.substr(2*i,2*i+1),"%h",v)!=1)$fatal(1,"Invalid hex fixture");
    return v;
  endfunction
  function automatic int size_bytes(string s);return s=="-"?0:s.len()/2;endfunction

  class dilithium_item extends uvm_sequence_item;
    `uvm_object_utils(dilithium_item)
    event_e kind;
    int serial,op,p,id,ctx,mlen,siglen,profile,abort_cycles;
    bit [255:0] seed,rnd;
    string first,second,body;
    bit [63:0] data;bit [7:0] bank_ports;bit datapath_idle;
    int index,nbytes,code,stage,detail,attempts,rejections,nonce;
    bit last,key_type,accept;
    longint unsigned cycle,latency,ack_latency,hash_cycles,ntt_cycles,process_cycles;
    int input_wait,output_wait,done_wait,peak;
    function new(string name="dilithium_item");super.new(name);endfunction
  endclass

  class dilithium_config extends uvm_object;
    `uvm_object_utils(dilithium_config)
    dilithium_item cases[$];string token,directory,prefix;
    function new(string name="dilithium_config");super.new(name);endfunction
    function void load();
      int f,n,rc;string t;dilithium_item c;
      if(!$value$plusargs("DILITHIUM_DIR=%s",directory))directory=".";
      if(!$value$plusargs("DILITHIUM_PREFIX=%s",prefix))prefix={directory,"/stage7_uvm"};
      f=$fopen({directory,"/stage7_uvm_inputs.txt"},"r");
      if(!f || $fscanf(f,"%s %d",token,n)!=2)`uvm_fatal("FIXTURE","Run Python uvm_prepare")
      repeat(n)begin
        c=new();rc=$fscanf(f,"%d %d %d %d %d %d %d %d %d %h %h %s %s %s",c.serial,c.op,c.p,c.id,c.ctx,c.mlen,c.siglen,c.profile,c.abort_cycles,c.seed,c.rnd,c.first,c.second,c.body);
        if(rc!=14 || c.serial!=cases.size())`uvm_fatal("FIXTURE","Malformed input row")
        cases.push_back(c);
      end
      if($fscanf(f,"%s",t)==1)`uvm_fatal("FIXTURE","Trailing input row")
      $fclose(f);
    endfunction
  endclass

  class dilithium_sequence extends uvm_sequence#(dilithium_item);
    `uvm_object_utils(dilithium_sequence)
    dilithium_config cfg;
    function new(string name="dilithium_sequence");super.new(name);endfunction
    task body();foreach(cfg.cases[i])begin start_item(cfg.cases[i]);finish_item(cfg.cases[i]);end endtask
  endclass

  class dilithium_driver extends uvm_driver#(dilithium_item);
    `uvm_component_utils(dilithium_driver)
    virtual dilithium_if vif;int tick=0,profile=0;bit running=0;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);if(!uvm_config_db#(virtual dilithium_if)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface")
    endfunction
    task defaults();
      vif.rst=1;vif.start_valid_i=0;vif.start_op_i=0;vif.start_param_i=0;vif.start_id_i=0;vif.start_seed_i=0;
      vif.start_message_len_i=0;vif.start_context_len_i=0;vif.start_rnd_i=0;vif.start_signature_len_i=0;
      vif.sign_input_valid_i=0;vif.sign_input_data_i=0;vif.sign_input_bytes_i=0;vif.sign_input_index_i=0;vif.sign_input_last_i=0;
      vif.verify_input_valid_i=0;vif.verify_input_data_i=0;vif.verify_input_bytes_i=0;vif.verify_input_index_i=0;vif.verify_input_last_i=0;
      vif.done_ready_i=0;vif.key_ready_i=0;vif.signature_ready_i=0;
    endtask
    task reset_dut();
      @(negedge vif.clk);vif.rst=1;vif.start_valid_i=0;vif.sign_input_valid_i=0;vif.verify_input_valid_i=0;vif.done_ready_i=0;
      repeat(4)@(negedge vif.clk);vif.rst=0;repeat(2)@(negedge vif.clk);
    endtask
    task send_frame(string bytestring,bit verify_stream);
      int n,w=0;bit [63:0] word;
      while(w<size_bytes(bytestring) && !vif.rst && !vif.done_valid_o && !vif.fault_o)begin
        n=size_bytes(bytestring)-w;if(n>8)n=8;word='1;
        for(int b=0;b<n;b++)word[8*b+:8]=octet(bytestring,w+b);
        if(profile && (w/8)%7==0)repeat(profile)@(negedge vif.clk);
        if(vif.rst || vif.done_valid_o)return;
        if(verify_stream)begin vif.verify_input_data_i=word;vif.verify_input_bytes_i=4'(n);vif.verify_input_index_i=16'(w/8);vif.verify_input_last_i=w+n==size_bytes(bytestring);vif.verify_input_valid_i=1;end
        else begin vif.sign_input_data_i=word;vif.sign_input_bytes_i=4'(n);vif.sign_input_index_i=16'(w/8);vif.sign_input_last_i=w+n==size_bytes(bytestring);vif.sign_input_valid_i=1;end
        do @(posedge vif.clk);while(!(verify_stream?vif.verify_input_ready_o:vif.sign_input_ready_o) && !vif.rst && !vif.done_valid_o);
        @(negedge vif.clk);vif.verify_input_valid_i=0;vif.sign_input_valid_i=0;w+=n;
      end
    endtask
    task run_phase(uvm_phase phase);
      defaults();reset_dut();running=1;
      fork
        forever begin
          @(negedge vif.clk);tick++;
          vif.key_ready_i=!vif.rst && (profile==0 || tick%13>profile*3);
          vif.signature_ready_i=!vif.rst && (profile==0 || tick%17>profile*4);
        end
      join_none
      forever begin
        seq_item_port.get_next_item(req);profile=req.profile;
        while(!vif.start_ready_o)@(negedge vif.clk);
        vif.start_op_i=2'(req.op);vif.start_param_i=2'(req.p);vif.start_id_i=16'(req.id);vif.start_seed_i=req.seed;vif.start_rnd_i=req.rnd;
        vif.start_context_len_i=9'(req.ctx);vif.start_message_len_i=16'(req.mlen);vif.start_signature_len_i=16'(req.siglen);vif.start_valid_i=1;
        do @(posedge vif.clk);while(!vif.start_ready_o);
        @(negedge vif.clk);vif.start_valid_i=0;
        // Deliberately change the unaccepted command pins; accepted metadata owns work.
        vif.start_op_i=3;vif.start_param_i=3;vif.start_id_i=~16'(req.id);vif.start_seed_i='1;vif.start_rnd_i='1;
        vif.start_message_len_i=65535;vif.start_context_len_i=511;vif.start_signature_len_i=65535;
        fork
          begin
            if(req.op inside {1,2})begin
              send_frame(req.first,req.op==2);
              if(req.op==2)send_frame(req.second,1);
              send_frame(req.body,req.op==2);
            end
          end
          begin
            if(req.abort_cycles)begin repeat(req.abort_cycles)@(negedge vif.clk);reset_dut();end
            else begin
              while(!vif.done_valid_o)@(negedge vif.clk);
              repeat(3+profile*4)@(negedge vif.clk);
              vif.start_valid_i=1;repeat(3)@(negedge vif.clk);vif.start_valid_i=0;
              vif.done_ready_i=1;@(posedge vif.clk);@(negedge vif.clk);vif.done_ready_i=0;
            end
          end
        join
        while(!vif.start_ready_o)@(negedge vif.clk);
        repeat(3)@(negedge vif.clk);seq_item_port.item_done();
      end
    endtask
  endclass

  class dilithium_monitor extends uvm_monitor;
    `uvm_component_utils(dilithium_monitor)
    virtual dilithium_if vif;uvm_analysis_port#(dilithium_item) observed;
    longint unsigned cycle=0,start_cycle,first_done;int serial=0,active_op,peak,iw,ow,dw;
    longint unsigned hc,nc,pc;bit active=0,acked=0,was_reset=1,seen_done=0,held_key=0,held_sig=0,held_in=0,held_done=0;
    bit [95:0] key_snapshot;bit [94:0] sig_snapshot;bit [84:0] in_snapshot;bit [76:0] done_snapshot;
    bit inject=0,injected=0;
    function new(string name,uvm_component parent);super.new(name,parent);observed=new("observed",this);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);if(!uvm_config_db#(virtual dilithium_if)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface") inject=$test$plusargs("DILITHIUM_INJECT_BAD_KEY");endfunction
    function void publish(event_e kind);
      dilithium_item e=new();e.kind=kind;e.cycle=cycle;e.serial=serial;e.op=active_op;
      e.bank_ports=vif.bank_ports;e.datapath_idle=vif.datapath_idle;e.peak=peak;e.input_wait=iw;e.output_wait=ow;e.done_wait=dw;
      e.latency=first_done-start_cycle;e.ack_latency=cycle-start_cycle;e.hash_cycles=hc;e.ntt_cycles=nc;e.process_cycles=pc;
      case(kind)
        START:begin e.op=vif.start_op_i;e.p=vif.start_param_i;e.id=vif.start_id_i;e.seed=vif.start_seed_i;e.rnd=vif.start_rnd_i;e.ctx=vif.start_context_len_i;e.mlen=vif.start_message_len_i;e.siglen=vif.start_signature_len_i;end
        INPUT_SIGN:begin e.data=vif.sign_input_data_i;e.nbytes=vif.sign_input_bytes_i;e.index=vif.sign_input_index_i;e.last=vif.sign_input_last_i;end
        INPUT_VERIFY:begin e.data=vif.verify_input_data_i;e.nbytes=vif.verify_input_bytes_i;e.index=vif.verify_input_index_i;e.last=vif.verify_input_last_i;end
        KEY_WORD:begin e.data=vif.key_data_o;e.nbytes=vif.key_bytes_o;e.index=vif.key_index_o;e.last=vif.key_last_o;e.id=vif.key_id_o;e.key_type=vif.key_type_o;if(inject && !injected)begin e.data^=1;injected=1;end end
        SIG_WORD:begin e.data=vif.signature_data_o;e.nbytes=vif.signature_bytes_o;e.index=vif.signature_index_o;e.last=vif.signature_last_o;e.id=vif.signature_id_o;end
        DONE:begin e.code=vif.done_code_o;e.stage=vif.done_stage_o;e.detail=vif.done_detail_o;e.id=vif.done_id_o;e.accept=vif.verify_accept_o;e.attempts=vif.sign_attempts_o;e.rejections=vif.sign_rejections_o;e.nonce=vif.sign_next_nonce_o;end
        default:;
      endcase
      observed.write(e);
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);cycle++;
        if(active && (cycle-start_cycle)%100000==0)`uvm_info("PROGRESS",$sformatf("case%0d cycle%0d state%0d owners%b sign_ready%0d verify_ready%0d inputs%0d/%0d attempts%0d",serial,cycle-start_cycle,vif.main_state,vif.owners,vif.sign_input_ready_o,vif.verify_input_ready_o,vif.sign_input_index_i,vif.verify_input_index_i,vif.sign_attempts_o),UVM_LOW)
        if(vif.rst)begin
          if(!was_reset && active)begin publish(RESET);serial++;end
          active=0;acked=0;seen_done=0;held_key=0;held_sig=0;held_in=0;held_done=0;was_reset=1;continue;
        end
        was_reset=0;
        if($isunknown({vif.start_ready_o,vif.busy_o,vif.done_valid_o,vif.key_valid_o,vif.signature_valid_o,vif.sign_input_ready_o,vif.verify_input_ready_o,vif.fault_o}))`uvm_fatal("PROTOCOL","Unknown handshake/control")
        if(vif.fault_o)`uvm_fatal("PROTOCOL","Unexpected physical/service fault")
        if($countones(vif.owners)>1 || (vif.busy_o && vif.start_ready_o))`uvm_fatal("PROTOCOL","Multiple owners or busy command acceptance")
        if($isunknown({vif.bank_ports,vif.bank_owners,vif.bank_collision,vif.datapath_idle}))`uvm_fatal("PROTOCOL","Unknown physical bank ownership")
        if(vif.bank_collision!=0)`uvm_fatal("PROTOCOL","Conflicting physical bank accesses")
        if((vif.start_ready_o || vif.done_valid_o) && (!vif.datapath_idle || vif.bank_ports!=0))`uvm_fatal("PROTOCOL","Publication before physical retirement")
        if(held_key && (!vif.key_valid_o || key_snapshot!=={vif.key_id_o,vif.key_type_o,vif.key_index_o,vif.key_bytes_o,vif.key_last_o,vif.key_data_o}))`uvm_fatal("PROTOCOL","Held key changed")
        if(held_sig && (!vif.signature_valid_o || sig_snapshot!=={vif.signature_id_o,vif.signature_index_o,vif.signature_bytes_o,vif.signature_last_o,vif.signature_data_o}))`uvm_fatal("PROTOCOL","Held signature changed")
        if(held_done && (!vif.done_valid_o || done_snapshot!=={vif.done_id_o,vif.done_code_o,vif.done_stage_o,vif.done_detail_o,vif.verify_accept_o,vif.sign_attempts_o,vif.sign_rejections_o,vif.sign_next_nonce_o}))`uvm_fatal("PROTOCOL","Held completion changed")
        if(held_in && !vif.done_valid_o && (in_snapshot!==(active_op==1?{vif.sign_input_index_i,vif.sign_input_bytes_i,vif.sign_input_last_i,vif.sign_input_data_i}:{vif.verify_input_index_i,vif.verify_input_bytes_i,vif.verify_input_last_i,vif.verify_input_data_i})))`uvm_fatal("PROTOCOL","Held input changed")
        held_key=vif.key_valid_o && !vif.key_ready_i;key_snapshot={vif.key_id_o,vif.key_type_o,vif.key_index_o,vif.key_bytes_o,vif.key_last_o,vif.key_data_o};
        held_sig=vif.signature_valid_o && !vif.signature_ready_i;sig_snapshot={vif.signature_id_o,vif.signature_index_o,vif.signature_bytes_o,vif.signature_last_o,vif.signature_data_o};
        held_done=vif.done_valid_o && !vif.done_ready_i;done_snapshot={vif.done_id_o,vif.done_code_o,vif.done_stage_o,vif.done_detail_o,vif.verify_accept_o,vif.sign_attempts_o,vif.sign_rejections_o,vif.sign_next_nonce_o};
        held_in=active_op==1?(vif.sign_input_valid_i && !vif.sign_input_ready_o):(vif.verify_input_valid_i && !vif.verify_input_ready_o);
        in_snapshot=active_op==1?{vif.sign_input_index_i,vif.sign_input_bytes_i,vif.sign_input_last_i,vif.sign_input_data_i}:{vif.verify_input_index_i,vif.verify_input_bytes_i,vif.verify_input_last_i,vif.verify_input_data_i};
        if(active && acked && vif.start_ready_o)begin publish(RETIRED);serial++;active=0;acked=0;end
        if(vif.start_valid_i && vif.start_ready_o)begin
          if(active)`uvm_fatal("PROTOCOL","Overlapping accepted commands")
          active=1;active_op=vif.start_op_i;start_cycle=cycle;first_done=0;seen_done=0;peak=0;iw=0;ow=0;dw=0;hc=0;nc=0;pc=0;publish(START);
        end
        if(active)begin
          if(cycle-start_cycle>3000000)`uvm_fatal("WATCHDOG","Command timeout")
          if($countones(vif.bank_ports)>peak)peak=$countones(vif.bank_ports);
          iw+=int'(held_in);ow+=int'(held_key || held_sig);dw+=int'(held_done);hc+=int'(|vif.hash_active);nc+=int'(vif.ntt_busy);pc+=int'(vif.process_busy);
          if(vif.done_valid_o && !seen_done)begin first_done=cycle;seen_done=1;end
        end
        if(vif.sign_input_valid_i && vif.sign_input_ready_o)publish(INPUT_SIGN);
        if(vif.verify_input_valid_i && vif.verify_input_ready_o)publish(INPUT_VERIFY);
        if(vif.key_valid_o && vif.key_ready_i)begin if($isunknown({vif.key_data_o,vif.key_bytes_o,vif.key_id_o,vif.key_index_o,vif.key_last_o,vif.key_type_o}))`uvm_fatal("PROTOCOL","Unknown key payload") publish(KEY_WORD);end
        if(vif.signature_valid_o && vif.signature_ready_i)begin if($isunknown({vif.signature_data_o,vif.signature_bytes_o,vif.signature_id_o,vif.signature_index_o,vif.signature_last_o}))`uvm_fatal("PROTOCOL","Unknown signature payload") publish(SIG_WORD);end
        if(vif.done_valid_o && vif.done_ready_i)begin if($isunknown({vif.done_id_o,vif.done_code_o,vif.done_stage_o,vif.done_detail_o,vif.verify_accept_o,vif.sign_attempts_o,vif.sign_rejections_o,vif.sign_next_nonce_o,vif.bank_ports,vif.datapath_idle}))`uvm_fatal("PROTOCOL","Unknown completion") publish(DONE);acked=1;end
      end
    endtask
  endclass

  class dilithium_coverage extends uvm_subscriber#(dilithium_item);
    `uvm_component_utils(dilithium_coverage)
    int checked=0,prev_op=4;
    covergroup operation_cg with function sample(int op,int p);
      option.per_instance=1;
      cp_op:coverpoint op{bins keygen={0};bins sign={1};bins verify={2};}
      cp_level:coverpoint p{bins level2={0};bins level3={1};bins level5={2};}
      op_level:cross cp_op,cp_level;
    endgroup
    covergroup command_cg with function sample(int op,int id,int ctx,int mlen);
      option.per_instance=1;
      cp_id:coverpoint id{bins zero={0};bins max={65535};bins other={[1:65534]};}
      cp_context:coverpoint ctx{bins empty={0};bins one={1};bins short={[2:32]};bins long={[33:254]};bins max={255};}
      cp_message:coverpoint mlen{bins empty={0};bins tail={[1:7]};bins block={[8:135]};bins mid_size={[136:1024]};bins long_message={[1025:65535]};}
    endgroup
    covergroup outcome_cg with function sample(int op,int code,bit accept);
      option.per_instance=1;
      cp_op:coverpoint op{bins operations[]={[0:3]};}
      cp_code:coverpoint code{bins ok={0};bins bad_command={1};bins unsupported={2};bins input_error={3};bins arithmetic_error={4};bins equation_error={5};bins publication_error={6};}
      cp_verify:coverpoint accept iff(op==2 && code==0){bins valid={1};bins invalid={0};}
    endgroup
    covergroup transport_cg with function sample(int op,bit iw,bit ow,bit dw);
      option.per_instance=1;
      cp_op:coverpoint op{bins operations[]={[0:2]};}
      cp_input_wait:coverpoint iw;cp_output_wait:coverpoint ow;cp_done_wait:coverpoint dw;
      op_input:cross cp_op,cp_input_wait;
      op_output:cross cp_op,cp_output_wait{ignore_bins verify_no_encoded_output=binsof(cp_op) intersect{2} && binsof(cp_output_wait) intersect{1};}
    endgroup
    covergroup tail_cg with function sample(int channel,int nbytes);
      option.per_instance=1;
      cp_channel:coverpoint channel{bins input_data={0};bins key={1};bins signature={2};}
      cp_bytes:coverpoint nbytes{bins tails[]={[1:8]};}
      channel_bytes:cross cp_channel,cp_bytes{ignore_bins fixed_key_words=binsof(cp_channel) intersect{1} && binsof(cp_bytes) intersect{[1:7]};}
    endgroup
    covergroup retry_cg with function sample(int p,int attempts);
      option.per_instance=1;
      cp_level:coverpoint p{bins levels[]={[0:2]};}
      cp_attempts:coverpoint attempts{bins first={1};bins few={[2:4]};bins several={[5:15]};bins many={[16:65535]};}
      level_retry:cross cp_level,cp_attempts;
    endgroup
    covergroup sequence_cg with function sample(int prev,int op);
      option.per_instance=1;
      cp_previous:coverpoint prev{bins operations[]={[0:3]};}
      cp_current:coverpoint op{bins operations[]={[0:3]};}
      ordered_pair:cross cp_previous,cp_current;
    endgroup
    covergroup memory_cg with function sample(int op,int peak);
      option.per_instance=1;
      cp_op:coverpoint op{bins operations[]={[0:2]};}
      cp_peak:coverpoint peak{bins empty={0};bins one_two={[1:2]};bins three_four={[3:4]};bins five_six={[5:6]};bins seven_eight={[7:8]};}
      op_peak:cross cp_op,cp_peak;
    endgroup
    covergroup reset_cg with function sample(int op,int recovery);
      option.per_instance=1;
      cp_abort:coverpoint op{bins operations[]={[0:2]};}
      cp_recovery:coverpoint recovery{bins operations[]={[0:2]};}
      abort_recovery:cross cp_abort,cp_recovery;
    endgroup
    function new(string name,uvm_component parent);
      super.new(name,parent);operation_cg=new;command_cg=new;outcome_cg=new;transport_cg=new;tail_cg=new;retry_cg=new;sequence_cg=new;memory_cg=new;reset_cg=new;
    endfunction
    function void write(dilithium_item t);
      dilithium_item e=t;
      checked++;outcome_cg.sample(e.op,e.code,e.accept);
      if(prev_op<4)sequence_cg.sample(prev_op,e.op);prev_op=e.op;
      if(e.code==0 && e.op<3)begin operation_cg.sample(e.op,e.p);command_cg.sample(e.op,e.id,e.ctx,e.mlen);transport_cg.sample(e.op,e.input_wait!=0,e.output_wait!=0,e.done_wait!=0);memory_cg.sample(e.op,e.peak);if(e.op==1)retry_cg.sample(e.p,e.attempts);end
    endfunction
  endclass

  class dilithium_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(dilithium_scoreboard)
    uvm_analysis_imp#(dilithium_item,dilithium_scoreboard) observed;
    uvm_analysis_port#(dilithium_item) accepted;
    dilithium_config cfg;dilithium_coverage cov;
    dilithium_item current,result;int checked=0,aborted=0,position=0,frame=0,offset=0,pkpos=0,skpos=0,sigpos=0,pending_reset=-1;
    int codes[$],stages[$],details[$],accepts[$],tails[$],channels[$];string pks[$],sks[$],sigs[$],origins[$];int csv,witness;
    function new(string name,uvm_component parent);super.new(name,parent);observed=new("observed",this);accepted=new("accepted",this);endfunction
    function void build_phase(uvm_phase phase);
      int f,n,i,code,stage,detail,accept,rc;string token,pk,sk,sig,origin;
      super.build_phase(phase);if(!uvm_config_db#(dilithium_config)::get(this,"","cfg",cfg))`uvm_fatal("CFG","Missing fixtures")
      f=$fopen({cfg.directory,"/stage7_uvm_expected.txt"},"r");
      if(!f || $fscanf(f,"%s %d",token,n)!=2 || token!=cfg.token || n!=cfg.cases.size())`uvm_fatal("GOLD","Expected-file freshness")
      repeat(n)begin
        rc=$fscanf(f,"%d %d %d %d %d %s %s %s %s",i,code,stage,detail,accept,pk,sk,sig,origin);
        if(rc!=9 || i!=codes.size())`uvm_fatal("GOLD","Expected row")
        codes.push_back(code);stages.push_back(stage);details.push_back(detail);accepts.push_back(accept);pks.push_back(pk);sks.push_back(sk);sigs.push_back(sig);origins.push_back(origin);
      end
      $fclose(f);csv=$fopen({cfg.prefix,"_latency.csv"},"w");witness=$fopen({cfg.prefix,"_checked.csv"},"w");
      $fdisplay(csv,"case,op,param,id,latency_to_valid_cycles,latency_to_ack_cycles,input_wait,output_wait,done_wait,peak_bank_ports,hash_active_cycles,ntt_busy_cycles,process_busy_cycles");
      $fdisplay(witness,"case,op,param,id,code,accept,origin,source_token");
    endfunction
    function void require(bit condition,string why);if(!condition)`uvm_fatal("SCOREBOARD",$sformatf("case%0d %s; coverage credit withheld",position,why)) endfunction
    function string input_frame();if(current.op==1)return frame==0?current.first:current.body;return frame==0?current.first:frame==1?current.second:current.body;endfunction
    function void check_word(dilithium_item e,string golden,ref int pos,input bit input_data=0);
      int n=size_bytes(golden)-pos;if(n>8)n=8;
      require(n>0 && e.index==pos/8 && e.nbytes==n && e.last==(pos+n==size_bytes(golden)),"word order/size/last");
      for(int b=0;b<n;b++)require(e.data[8*b+:8]==octet(golden,pos+b),$sformatf("byte mismatch index%0d",pos+b));
      if(!input_data)for(int b=n;b<8;b++)require(e.data[8*b+:8]==0,"nonzero output tail");
      pos+=n;tails.push_back(n);channels.push_back(input_data?0:(e.kind==KEY_WORD?1:2));
    endfunction
    function void write(dilithium_item e);
      if(e.kind==START)begin
        require(current==null && position<cfg.cases.size() && e.serial==position,"unexpected command");current=cfg.cases[position];
        require({e.op,e.p,e.id,e.ctx,e.mlen,e.siglen,e.seed,e.rnd}=={current.op,current.p,current.id,current.ctx,current.mlen,current.siglen,current.seed,current.rnd},"accepted metadata");
        frame=0;offset=0;pkpos=0;skpos=0;sigpos=0;result=null;tails.delete();channels.delete();return;
      end
      require(current!=null && e.serial==position,"event without command");
      case(e.kind)
        INPUT_SIGN,INPUT_VERIFY:begin
          require((e.kind==INPUT_SIGN && current.op==1)||(e.kind==INPUT_VERIFY && current.op==2),"wrong input owner");
          check_word(e,input_frame(),offset,1);if(offset==size_bytes(input_frame()))begin frame++;offset=0;end
        end
        KEY_WORD:begin require(current.op==0 && e.id==current.id && result==null,"key owner/id");if(e.key_type)begin require(pkpos==size_bytes(pks[position]),"secret before public key");check_word(e,sks[position],skpos);end else check_word(e,pks[position],pkpos);end
        SIG_WORD:begin require(current.op==1 && e.id==current.id && result==null,"signature owner/id");check_word(e,sigs[position],sigpos);end
        DONE:begin
          require(!current.abort_cycles && result==null && e.id==current.id && e.code==codes[position] && e.stage==stages[position] && e.detail==details[position] && int'(e.accept)==accepts[position],"completion/verdict");
          require(pkpos==size_bytes(pks[position]) && skpos==size_bytes(sks[position]) && sigpos==size_bytes(sigs[position]),"missing output bytes");
          if(current.op==1 && e.code==0)begin
            require(frame==(size_bytes(current.body)?2:1) && offset==0,"Sign input frames");
            require(e.attempts>=1 && e.rejections==e.attempts-1 && e.nonce==e.attempts*(current.p==0?4:current.p==1?5:7),"Sign retry counters");
          end
          if(current.op==2 && e.code==0 && size_bytes(current.first)!=0)begin
            if(origins[position]!="NIST_Verify_2")require(frame==(size_bytes(current.body)?3:2) && offset==0,"Verify equation input frames");
            else require(frame>=1 && (offset>0 || frame>=2),"structural Verify consumed PK/signature prefix");
          end
          require(e.bank_ports==0 && e.datapath_idle,"completion before physical retirement");
          result=e;
        end
        RESET:begin
          require(current.abort_cycles!=0 && result==null,"unplanned reset");aborted++;pending_reset=current.op;current=null;position++;tails.delete();channels.delete();
        end
        RETIRED:begin
          require(result!=null && e.bank_ports==0 && e.datapath_idle,"retirement/cleanup");
          result.op=current.op;result.p=current.p;result.id=current.id;result.ctx=current.ctx;result.mlen=current.mlen;
          accepted.write(result);
          if(result.code==0)foreach(tails[j])cov.tail_cg.sample(channels[j],tails[j]);
          if(pending_reset>=0 && result.code==0)begin cov.reset_cg.sample(pending_reset,current.op);pending_reset=-1;end
          $fdisplay(csv,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",position,current.op,current.p,current.id,result.latency,result.ack_latency,result.input_wait,result.output_wait,result.done_wait,result.peak,result.hash_cycles,result.ntt_cycles,result.process_cycles);
          $fdisplay(witness,"%0d,%0d,%0d,%0d,%0d,%0d,%s,%s",position,current.op,current.p,current.id,result.code,result.accept,origins[position],cfg.token);
          checked++;`uvm_info("CHECKED",$sformatf("case%0d op%0d level-code%0d checked; %0d/%0d retired",position,current.op,current.p,position+1,cfg.cases.size()),UVM_LOW)
          current=null;result=null;position++;
        end
        default:`uvm_fatal("EVENT","Unknown observation")
      endcase
    endfunction
    function void check_phase(uvm_phase phase);
      super.check_phase(phase);require(current==null && result==null && position==cfg.cases.size() && pending_reset<0,"incomplete campaign/recovery");
      $fclose(csv);$fclose(witness);
    endfunction
  endclass

  class dilithium_agent extends uvm_agent;
    `uvm_component_utils(dilithium_agent)
    uvm_sequencer#(dilithium_item) sequencer;dilithium_driver driver;dilithium_monitor monitor;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);sequencer=new("sequencer",this);driver=dilithium_driver::type_id::create("driver",this);monitor=dilithium_monitor::type_id::create("monitor",this);endfunction
    function void connect_phase(uvm_phase phase);super.connect_phase(phase);driver.seq_item_port.connect(sequencer.seq_item_export);endfunction
  endclass
  class dilithium_env extends uvm_env;
    `uvm_component_utils(dilithium_env)
    dilithium_agent agent;dilithium_scoreboard scoreboard;dilithium_coverage coverage;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);agent=dilithium_agent::type_id::create("agent",this);scoreboard=dilithium_scoreboard::type_id::create("scoreboard",this);coverage=dilithium_coverage::type_id::create("coverage",this);scoreboard.cov=coverage;endfunction
    function void connect_phase(uvm_phase phase);super.connect_phase(phase);agent.monitor.observed.connect(scoreboard.observed);scoreboard.accepted.connect(coverage.analysis_export);endfunction
  endclass
  class dilithium_stage7c5_test extends uvm_test;
    `uvm_component_utils(dilithium_stage7c5_test)
    dilithium_env env;dilithium_config cfg;virtual dilithium_if vif;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);cfg=new;cfg.load();uvm_config_db#(dilithium_config)::set(this,"*","cfg",cfg);
      if(!uvm_config_db#(virtual dilithium_if)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface")
      env=dilithium_env::type_id::create("env",this);
    endfunction
    task run_phase(uvm_phase phase);
      dilithium_sequence sequence0=new();phase.raise_objection(this);sequence0.cfg=cfg;sequence0.start(env.agent.sequencer);repeat(5)@(posedge vif.clk);phase.drop_objection(this);
    endtask
    function void report_phase(uvm_phase phase);
      uvm_report_server server=uvm_report_server::get_server();
      if(server.get_severity_count(UVM_ERROR)==0 && server.get_severity_count(UVM_FATAL)==0 && env.scoreboard.position==cfg.cases.size())begin
        vif.test_passed=1;`uvm_info("STAGE7C5_UVM_PASS",$sformatf("%0d checked completions/%0d reset aborts; %0d coverage-qualified outcomes",env.scoreboard.checked,env.scoreboard.aborted,env.coverage.checked),UVM_NONE)
      end
    endfunction
  endclass
endpackage
