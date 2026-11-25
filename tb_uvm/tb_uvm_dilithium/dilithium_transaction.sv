  class dilithium_transaction extends uvm_sequence_item;

    event_e kind;
    int serial,op,p,id,ctx,mlen,siglen,profile,abort_cycles;
    bit [255:0] seed,rnd;
    string first,second,body;
    bit [63:0] data;bit [7:0] bank_ports;bit datapath_idle;
    int index,nbytes,code,stage,detail,attempts,rejections,nonce;
    bit last,key_type,accept;
    longint unsigned cycle,latency,ack_latency,hash_cycles,ntt_cycles,process_cycles;
    int input_wait,output_wait,done_wait,peak;
    // Only the scoreboard publishes these after a fully checked retirement.
    int checked_tail_bytes[$],checked_tail_channels[$];
    int recovered_from_op=-1;
    `uvm_object_utils_begin(dilithium_transaction)
      `uvm_field_enum(event_e,kind,UVM_DEFAULT)
      `uvm_field_int(serial,UVM_DEFAULT)
      `uvm_field_int(op,UVM_DEFAULT)
      `uvm_field_int(p,UVM_DEFAULT)
      `uvm_field_int(id,UVM_DEFAULT)
      `uvm_field_int(ctx,UVM_DEFAULT)
      `uvm_field_int(mlen,UVM_DEFAULT)
      `uvm_field_int(siglen,UVM_DEFAULT)
      `uvm_field_int(profile,UVM_DEFAULT)
      `uvm_field_int(abort_cycles,UVM_DEFAULT)
      `uvm_field_int(seed,UVM_DEFAULT)
      `uvm_field_int(rnd,UVM_DEFAULT)
      `uvm_field_int(data,UVM_DEFAULT)
      `uvm_field_int(bank_ports,UVM_DEFAULT)
      `uvm_field_int(datapath_idle,UVM_DEFAULT)
      `uvm_field_int(index,UVM_DEFAULT)
      `uvm_field_int(nbytes,UVM_DEFAULT)
      `uvm_field_int(code,UVM_DEFAULT)
      `uvm_field_int(stage,UVM_DEFAULT)
      `uvm_field_int(detail,UVM_DEFAULT)
      `uvm_field_int(attempts,UVM_DEFAULT)
      `uvm_field_int(rejections,UVM_DEFAULT)
      `uvm_field_int(nonce,UVM_DEFAULT)
      `uvm_field_int(last,UVM_DEFAULT)
      `uvm_field_int(key_type,UVM_DEFAULT)
      `uvm_field_int(accept,UVM_DEFAULT)
      `uvm_field_int(cycle,UVM_DEFAULT)
      `uvm_field_int(latency,UVM_DEFAULT)
      `uvm_field_int(ack_latency,UVM_DEFAULT)
      `uvm_field_int(hash_cycles,UVM_DEFAULT)
      `uvm_field_int(ntt_cycles,UVM_DEFAULT)
      `uvm_field_int(process_cycles,UVM_DEFAULT)
      `uvm_field_int(input_wait,UVM_DEFAULT)
      `uvm_field_int(output_wait,UVM_DEFAULT)
      `uvm_field_int(done_wait,UVM_DEFAULT)
      `uvm_field_int(peak,UVM_DEFAULT)
      `uvm_field_int(recovered_from_op,UVM_DEFAULT)
      `uvm_field_string(first,UVM_DEFAULT)
      `uvm_field_string(second,UVM_DEFAULT)
      `uvm_field_string(body,UVM_DEFAULT)
      `uvm_field_queue_int(checked_tail_bytes,UVM_DEFAULT)
      `uvm_field_queue_int(checked_tail_channels,UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name="dilithium_transaction");super.new(name);endfunction
  endclass
  typedef dilithium_transaction dilithium_item; // Compatibility for user sequences.

