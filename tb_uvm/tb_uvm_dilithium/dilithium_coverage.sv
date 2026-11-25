// Analysis subscriber;only scoreboard-checked retirements earn coverage.
  class dilithium_coverage extends uvm_subscriber#(dilithium_transaction);
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
    function void write(dilithium_transaction t);
      dilithium_transaction e=t;
      checked++;outcome_cg.sample(e.op,e.code,e.accept);
      if(e.code==0)foreach(e.checked_tail_bytes[j])
        tail_cg.sample(e.checked_tail_channels[j],e.checked_tail_bytes[j]);
      if(e.code==0 && e.recovered_from_op>=0)reset_cg.sample(e.recovered_from_op,e.op);
      if(prev_op<4)sequence_cg.sample(prev_op,e.op);prev_op=e.op;
      if(e.code==0 && e.op<3)begin operation_cg.sample(e.op,e.p);command_cg.sample(e.op,e.id,e.ctx,e.mlen);transport_cg.sample(e.op,e.input_wait!=0,e.output_wait!=0,e.done_wait!=0);memory_cg.sample(e.op,e.peak);if(e.op==1)retry_cg.sample(e.p,e.attempts);end
    endfunction
  endclass
