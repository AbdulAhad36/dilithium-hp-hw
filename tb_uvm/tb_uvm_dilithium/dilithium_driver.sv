// Drive on falling edges;sample acceptance on rising edges.
  class dilithium_driver extends uvm_driver#(dilithium_transaction);
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
