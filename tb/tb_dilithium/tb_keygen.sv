`timescale 1ns/1ps
module tb_keygen;
  import dilithium_pkg::*;
  parameter bit DIAGNOSTIC=0;
  parameter bit PROTOCOL=0;
  parameter bit CYCLE_REFERENCE=0;
  parameter bit ID_PROOF_ONLY=0;
  logic clk=0;always #5 clk=~clk;
  logic rst=1,start_valid_i=0,start_ready_o;
  logic [1:0] start_param_i=0;logic [15:0] start_id_i=0;
  logic [255:0] start_seed_i=0;
  request_t service_o;response_t service_i;
  logic key_valid_o,key_ready_i,key_type_o,key_last_o;
  logic [63:0] key_data_o;logic [3:0] key_bytes_o;
  logic [9:0] key_index_o;logic [15:0] key_id_o;
  logic done_valid_o,done_ready_i=0;logic [2:0] done_code_o;
  logic [15:0] done_id_o;logic fault_o,datapath_fault;
  keygen controller(.*);
  // Optional actual pre-change controller, driven by the same real datapath
  // responses. Compare every public/control pin, including stalled cycles.
  generate if(CYCLE_REFERENCE)begin:timing_reference
    request_t reference_service;
    logic reference_start_ready,reference_key_valid,reference_key_type,reference_key_last;
    logic [63:0] reference_key_data;
    logic [3:0] reference_key_bytes;
    logic [9:0] reference_key_index;
    logic [15:0] reference_key_id,reference_done_id;
    logic reference_done_valid,reference_fault;
    logic [2:0] reference_done_code;
    int compared=0;
    keygen_timing_reference reference_controller(
      .clk(clk),.rst(rst),.start_valid_i(start_valid_i),.start_ready_o(reference_start_ready),
      .start_param_i(start_param_i),.start_id_i(start_id_i),.start_seed_i(start_seed_i),
      .service_o(reference_service),.service_i(service_i),
      .key_valid_o(reference_key_valid),.key_ready_i(key_ready_i),.key_data_o(reference_key_data),
      .key_bytes_o(reference_key_bytes),.key_type_o(reference_key_type),.key_last_o(reference_key_last),
      .key_index_o(reference_key_index),.key_id_o(reference_key_id),
      .done_valid_o(reference_done_valid),.done_ready_i(done_ready_i),.done_code_o(reference_done_code),
      .done_id_o(reference_done_id),.fault_o(reference_fault));
    always @(posedge clk)if(!rst)begin
      if({service_o,start_ready_o,key_valid_o,key_data_o,key_bytes_o,key_type_o,key_last_o,
          key_index_o,key_id_o,done_valid_o,done_code_o,done_id_o,fault_o} !==
         {reference_service,reference_start_ready,reference_key_valid,reference_key_data,
          reference_key_bytes,reference_key_type,reference_key_last,reference_key_index,
          reference_key_id,reference_done_valid,reference_done_code,reference_done_id,reference_fault})
        $fatal(1,"KeyGen timing change altered a pin/cycle at state%0d",controller.state);
      // Independent serialized sizes from FIPS204 (bytes / 8).
      case(controller.level_r)
        0:if(controller.k_r!=0 && (controller.pk_words!=164 || controller.sk_words!=320))
            $fatal(1,"Level2 serialized key sizes");
        1:if(controller.pk_words!=244 || controller.sk_words!=504)$fatal(1,"Level3 serialized key sizes");
        2:if(controller.pk_words!=324 || controller.sk_words!=612)$fatal(1,"Level5 serialized key sizes");
        3:if(controller.pk_words!=4 || controller.sk_words!=16)$fatal(1,"Invalid-level key sizes");
      endcase
      compared++;
    end
    final $display("KEYGEN_CYCLE_REFERENCE_PASS:%0d cycles compared",compared);
  end endgenerate
  datapath datapath(.clk(clk),.rst(rst),.service_i(service_o),.service_o(service_i),.fault_o(datapath_fault));
  int cycles=0,current=-1,completed=0,key_words=0,overlap_cycles=0,secret_overlap_cycles=0,max_ring=0,reset_phase=-1,reset_count=0,invalid_count=0;
  bit invalid_command=0;
  int input_file,output_file,ledger_file,n,serials[75],levels[75],ids[75],phase_cycles[27];
  logic [255:0] seeds[75];string token;
  logic held=0;logic [95:0] held_word;
  assign key_ready_i=!rst && cycles%13>3 &&
    !(PROTOCOL && ((reset_phase==6 && controller.state==controller.PK_BODY && key_index_o>=20) ||
      (reset_phase==7 && controller.state==controller.SK_FIELD_STREAM)));
  function automatic bit reset_point;
    case(reset_phase)
      0:return controller.producer==controller.P_FEED;
      1:return controller.state==controller.S1_RUN && datapath.polynomial.inputs_r>4;
      2:return controller.state==controller.TERM_RUN && datapath.polynomial.inputs_r>8;
      3:return controller.state==controller.INV_RUN && datapath.polynomial.core_busy;
      4:return controller.state==controller.ROUND_RUN && datapath.process_path.produced_r>4;
      5:return controller.state==controller.PK_HEADER;
      6:return controller.state==controller.PK_BODY && key_index_o>=20 && key_valid_o;
      7:return controller.state==controller.SK_FIELD_STREAM && key_valid_o;
      default:return 0;
    endcase
  endfunction
  always @(negedge clk)cycles++;
  always @(posedge clk)if(rst)held=0;else begin
    int occupancy;occupancy=$countones(controller.a_reserved_r);
    if(occupancy>max_ring)max_ring=occupancy;
    if(datapath.polynomial.core_busy && |service_i.sample.active)overlap_cycles++;
    if(controller.secret_phase_r && datapath.polynomial.core_busy && |service_i.sample.active)secret_overlap_cycles++;
    if(controller.state!=controller.IDLE && controller.state!=controller.REPORT && controller.state!=controller.HALT)
      phase_cycles[controller.state]++;
    if(invalid_command && (key_valid_o || service_o.raw.valid || service_o.sample.valid || service_o.ntt.valid ||
      service_o.poly_process.valid || |service_o.bank.command_valid))$fatal(1,"Invalid KeyGen command launched work");
    if(DIAGNOSTIC && service_o.sample.valid && service_i.sample.ready)$display("KG_SAMPLE_LAUNCH:id%0d state%0d kind%0d idx%0d batch%0d",service_o.sample.id,controller.state,controller.current.kind,controller.current.index,controller.batch_size_r);
    if(DIAGNOSTIC && service_i.sample.done_valid && service_o.sample.done_ready)$display("KG_SAMPLE_DONE:id%0d code%0d expected%0d/%0d done%0b state%0d",service_i.sample.done_id,service_i.sample.done_code,controller.descriptor_id(controller.descriptor_r[0],controller.id_r,controller.l_r),controller.descriptor_id(controller.descriptor_r[1],controller.id_r,controller.l_r),controller.batch_done_r,controller.state);
    if(DIAGNOSTIC && service_i.raw.output_valid && service_o.raw.output_ready)$display("KG_RAW:id%0d want%0d count%0d state%0d",service_i.raw.output_id,service_o.raw.id,controller.raw_count_r,controller.state);
    if(held)begin
      if(!key_valid_o || {key_data_o,key_bytes_o,key_type_o,key_last_o,key_index_o,key_id_o}!==held_word)
        $fatal(1,"Compact KeyGen key stream changed under backpressure");
    end
    held=key_valid_o && !key_ready_i;
    held_word={key_data_o,key_bytes_o,key_type_o,key_last_o,key_index_o,key_id_o};
    if(key_valid_o && key_ready_i)begin
      if(key_id_o!=start_id_i || key_bytes_o!=8)$fatal(1,"Compact key identity/byte count");
      $fdisplay(output_file,"K %0d %0d %016h %0d %0d",key_type_o,key_index_o,key_data_o,key_bytes_o,key_last_o);key_words++;
    end
    if(fault_o || datapath_fault)$fatal(1,"Compact KeyGen child fault case%0d state%0d producer%0d ntt%0d poly_process%0d sample%0d",
      current,controller.state,controller.producer,service_i.ntt.done_code,service_i.poly_process.done_code,service_i.sample.done_code);
  end
  initial begin:main_capture
    int watchdog,start_cycle,selected_case,expected_code,reset_action,limit;bit was_reset,busy_probe;
    if(ID_PROOF_ONLY)disable main_capture;
    input_file=$fopen("sim/dilithium/stage7c_keygen_inputs.txt","r");
    output_file=$fopen(PROTOCOL?"sim/dilithium/stage7c2_keygen_protocol_outputs.txt":DIAGNOSTIC?"sim/dilithium/stage7c2_keygen_diagnostic_outputs.txt":"sim/dilithium/stage7c2_keygen_outputs.txt","w");
    ledger_file=$fopen(PROTOCOL?"sim/dilithium/stage7c2_keygen_protocol_cycles.csv":DIAGNOSTIC?"sim/dilithium/stage7c2_keygen_diagnostic_cycles.csv":"sim/dilithium/stage7c2_keygen_cycles.csv","w");
    $fdisplay(ledger_file,"case,level,total,seed,secret_prepare,matrix_wait,multiply,inverse,add,round,public_key,secret_key");
    if(!input_file || !output_file || $fscanf(input_file,"%s %d",token,n)!=2 || n!=75)$fatal(1,"Prepare compact KeyGen fixtures");
    for(int i=0;i<n;i++)if($fscanf(input_file,"%d %d %d %h",serials[i],levels[i],ids[i],seeds[i])!=4)$fatal(1,"Compact KeyGen seed records");
    $fclose(input_file);limit=PROTOCOL?20:75;$fdisplay(output_file,"%s %0d",token,PROTOCOL?20:DIAGNOSTIC?3:75);
    repeat(3)@(negedge clk);rst=0;
    for(int i=0;i<limit;i++)begin
      if(DIAGNOSTIC && i!=0 && i!=25 && i!=50)continue;
      selected_case=i;expected_code=0;reset_action=-1;busy_probe=0;
      if(PROTOCOL)begin
        selected_case=i<3?25*i:i<19?25*(((i-3)/2)%3):0;
        if(i<3)expected_code=1;
        else if(i<19 && (i-3)%2==0)reset_action=(i-3)/2;
        else if(i==19)busy_probe=1;
      end
      @(negedge clk);current=i;start_param_i=expected_code==1?2'd3:2'(levels[selected_case]);
      start_id_i=PROTOCOL?16'(i<3?5000+i:i<19?6000+(i-3)/2:7000):16'(ids[i]);start_seed_i=seeds[selected_case];
      reset_phase=reset_action;invalid_command=expected_code==1;was_reset=0;
      for(int phase=0;phase<27;phase++)phase_cycles[phase]=0;
      start_valid_i=1;
      #1;if(!start_ready_o)$fatal(1,"Compact KeyGen not ready");
      $fdisplay(output_file,"J %0d %0d %0d",i,start_param_i,start_id_i);start_cycle=cycles;
      @(negedge clk);start_valid_i=0;watchdog=0;
      while(!done_valid_o)begin
        @(negedge clk);
        if(PROTOCOL && reset_phase>=0 && reset_point())begin
          $fdisplay(output_file,"A");rst=1;start_valid_i=0;repeat(3)@(negedge clk);rst=0;
          reset_count++;completed++;reset_phase=-1;was_reset=1;break;
        end
        if(PROTOCOL && busy_probe && watchdog==20)begin
          if(start_ready_o)$fatal(1,"Busy KeyGen accepted another command");
          start_valid_i=1;start_param_i=3;start_id_i=123;start_seed_i='1;
          @(negedge clk);start_valid_i=0;start_param_i=2'(levels[selected_case]);start_id_i=7000;start_seed_i=seeds[selected_case];
        end
        if(watchdog++>100000)$fatal(1,"Compact KeyGen timeout case%0d state%0d producer%0d s1next%0d transform%0d row%0d col%0d Aready%h reserved%h s2%h",
          i,controller.state,controller.producer,controller.s1_next_r,controller.transform_r,controller.row_r,
          controller.column_r,controller.a_ready_r,controller.a_reserved_r,controller.s2_ready_r);
      end
      if(was_reset)continue;
      if(done_code_o!=expected_code || done_id_o!=start_id_i)$fatal(1,"Compact KeyGen completion identity/code code%0d state%0d producer%0d fault%0d sampleFault%0d nttstate%0d nttcode%0d inputs%0d outputs%0d procCode%0d",
        done_code_o,controller.state,controller.producer,fault_o,service_i.sample.fault,datapath.polynomial.state,
        service_i.ntt.done_code,datapath.polynomial.inputs_r,datapath.polynomial.outputs_r,service_i.poly_process.done_code);
      $fdisplay(output_file,"D %0d %0d",done_code_o,cycles-start_cycle);
      $display("COMPACT_KEYGEN_CASE_PASS:case%0d level%0d cycles%0d",i,start_param_i,cycles-start_cycle);
      $fdisplay(ledger_file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",i,start_param_i,cycles-start_cycle,
        phase_cycles[1]+phase_cycles[2]+phase_cycles[3],phase_cycles[4]+phase_cycles[5]+phase_cycles[6],
        phase_cycles[7],phase_cycles[8]+phase_cycles[9],phase_cycles[10]+phase_cycles[11],
        phase_cycles[12]+phase_cycles[13]+phase_cycles[14],phase_cycles[15]+phase_cycles[16],
        phase_cycles[17]+phase_cycles[18]+phase_cycles[19]+phase_cycles[20]+phase_cycles[21],
        phase_cycles[22]+phase_cycles[23]+phase_cycles[24]);
      repeat(3)begin @(negedge clk);if(!done_valid_o || done_code_o!=expected_code)$fatal(1,"Compact completion unstable");end
      done_ready_i=1;@(negedge clk);done_ready_i=0;completed++;
      if(expected_code!=0)invalid_count++;
    end
    if(overlap_cycles==0 || max_ring>9)$fatal(1,"Compact schedule overlap/ring gate");
    if(PROTOCOL && (reset_count!=8 || invalid_count!=3 || completed!=20))$fatal(1,"Incomplete compact KeyGen protocol campaign");
    $fdisplay(output_file,"F %0d",completed);$fclose(output_file);$fclose(ledger_file);
    $display("LIGHTHD_KEYGEN_CAPTURE_PASS:%0d outcomes/%0d words/overlap_cycles%0d/peak_A_ring%0d/reset%0d/invalid%0d;independent NIST comparison required",completed,key_words,overlap_cycles,max_ring,reset_count,invalid_count);
    $display("LIGHTHD_KEYGEN_SECRET_OVERLAP:cycles%0d",secret_overlap_cycles);
    $finish;
  end
  generate if(ID_PROOF_ONLY)begin:descriptor_proof
    initial begin
      logic [17:0] d;
      logic [15:0] want;
      logic [3:0] columns,index,row,column;
      int checked=0;
      for(int id=0;id<65536;id++)begin
        for(int kind=0;kind<4;kind++)begin
          for(int suffix=0;suffix<16;suffix++)begin
            index=4'(suffix);columns=4'(id^suffix);
            row=4'(id>>4);column=4'(id^suffix);
            d={2'(kind),index,row,column,4'b0};
            want=16'(kind==1?id+256+16*int'(row)+int'(column):
              id+16+int'(index)+(kind==2?int'(columns):0));
            if(controller.descriptor_id(d,16'(id),columns)!==want ||
               !controller.descriptor_matches(d,16'(id),want,columns) ||
               controller.descriptor_matches(d,16'(id),want^16'h0001,columns) ||
               controller.descriptor_matches(d,16'(id),want^16'h0100,columns) ||
               controller.descriptor_matches(d,16'(id),want^16'h8000,columns))
              $fatal(1,"KeyGen descriptor ID/matcher id%0d kind%0d suffix%0d",id,kind,suffix);
            checked++;
          end
        end
      end
      $display("KEYGEN_DESCRIPTOR_ID_PROOF_PASS:%0d descriptor cases/%0d positive-negative checks;all65536 IDs/all4 kinds/all16 indices",checked,4*checked);
      $finish;
    end
  end endgenerate
  initial begin #100000000;$fatal(1,"Compact KeyGen global watchdog");end
endmodule
