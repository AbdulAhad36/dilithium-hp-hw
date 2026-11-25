// Independent NIST expectations stay here;the driver sees only inputs.
  class dilithium_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(dilithium_scoreboard)
    uvm_analysis_imp#(dilithium_transaction,dilithium_scoreboard) observed;
    uvm_analysis_port#(dilithium_transaction) accepted;
    dilithium_config cfg;
    dilithium_transaction current,result;int checked=0,aborted=0,position=0,frame=0,offset=0,pkpos=0,skpos=0,sigpos=0,pending_reset=-1;
    int codes[$],stages[$],details[$],accepts[$],tails[$],channels[$];string pks[$],sks[$],sigs[$],origins[$];int csv,witness;
    function new(string name,uvm_component parent);super.new(name,parent);observed=new("observed",this);accepted=new("accepted",this);endfunction
    function void build_phase(uvm_phase phase);
      int f,n,i,code,stage,detail,accept,rc;string token,pk,sk,sig,origin;
      super.build_phase(phase);if(!uvm_config_db#(dilithium_config)::get(this,"","cfg",cfg))`uvm_fatal("CFG","Missing fixtures")
      f=$fopen({cfg.directory,"/uvm_expected.txt"},"r");
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
    function void check_word(dilithium_transaction e,string golden,ref int pos,input bit input_data=0);
      int n=size_bytes(golden)-pos;if(n>8)n=8;
      require(n>0 && e.index==pos/8 && e.nbytes==n && e.last==(pos+n==size_bytes(golden)),"word order/size/last");
      for(int b=0;b<n;b++)require(e.data[8*b+:8]==octet(golden,pos+b),$sformatf("byte mismatch index%0d",pos+b));
      if(!input_data)for(int b=n;b<8;b++)require(e.data[8*b+:8]==0,"nonzero output tail");
      pos+=n;tails.push_back(n);channels.push_back(input_data?0:(e.kind==KEY_WORD?1:2));
    endfunction
    function void write(dilithium_transaction e);
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
          result.checked_tail_bytes=tails;result.checked_tail_channels=channels;
          result.recovered_from_op=pending_reset;
          accepted.write(result);
          if(pending_reset>=0 && result.code==0)pending_reset=-1;
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
