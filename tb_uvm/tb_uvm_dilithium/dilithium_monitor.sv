// Passive sampling and protocol checks;never reads expected results.
  class dilithium_monitor extends uvm_monitor;
    `uvm_component_utils(dilithium_monitor)
    virtual dilithium_if vif;uvm_analysis_port#(dilithium_transaction) observed;
    longint unsigned cycle=0,start_cycle,first_done;int serial=0,active_op,peak,iw,ow,dw;
    longint unsigned hc,nc,pc;bit active=0,acked=0,was_reset=1,seen_done=0,held_key=0,held_sig=0,held_in=0,held_done=0;
    bit [95:0] key_snapshot;bit [94:0] sig_snapshot;bit [84:0] in_snapshot;bit [76:0] done_snapshot;
    bit inject=0,injected=0;
    function new(string name,uvm_component parent);super.new(name,parent);observed=new("observed",this);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);if(!uvm_config_db#(virtual dilithium_if)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface") inject=$test$plusargs("DILITHIUM_INJECT_BAD_KEY");endfunction
    function void publish(event_e kind);
      dilithium_transaction e=dilithium_transaction::type_id::create("observed_event");e.kind=kind;e.cycle=cycle;e.serial=serial;e.op=active_op;
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
