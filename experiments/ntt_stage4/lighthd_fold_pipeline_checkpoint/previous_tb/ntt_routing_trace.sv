// Independent per-job FIFO content model. Coefficient IDs are verification
// metadata, not hardware tags. Queue movement follows arithmetic length/group
// formulas; expected values use the reference arithmetic, never DUT results.
class ntt_routing_trace extends uvm_object;
    `uvm_object_utils(ntt_routing_trace)
    typedef struct {
        int id[4];
        coeff_t value[4];
    } word_t;
    typedef struct {
        bit valid, pwm;
        int stage, da, db;
        word_t a,b;
    } write_t;
    typedef struct {
        bit valid;
        coeff_t a[4],b[4],z[4];
        bf_mode_e mode;
    } input_t;
    word_t queues[3][$];
    write_t pending[9];
    input_t input_pending[2];
    poly_t operand_a,operand_b,final_values;
    bit [255:0] pair_ids[8], destination_ids[8], pwm_ids;
    int inputs, outputs, reads, errors, pairs_checked, destinations_checked;
    int expected_head[3],expected_tail[3];
    bit initialized;
    bit [4:0] ct_sum_classes;
    bit [4:0] ct_sub_classes;
    bit [4:0] gs_sum_classes[4]; // actual registered GS operands, per physical lane
    int observation_fault; // zero in normal regression; separate UVM checker self-tests
    bit fault_injected;
    bit memory_check[3];
    int memory_address[3];
    logic [4*COEFF_W-1:0] memory_value[3];

    function new(string name="ntt_routing_trace");
        super.new(name);
        void'(uvm_config_db#(int)::get(null,"uvm_test_top","routing_observation_fault",observation_fault));
    endfunction

    function void require(bit condition,string message);
        if (!condition) begin
            errors++;
            if (errors<=4) `uvm_error("ROUTING_TRACE",message)
        end
    endfunction

    function logic [4*COEFF_W-1:0] pack_word(word_t word);
        logic [4*COEFF_W-1:0] result;
        for (int lane=0; lane<4; lane++) result[lane*COEFF_W +: COEFF_W]=word.value[lane];
        return result;
    endfunction

    function word_t loaded_word(int base);
        word_t word;
        for (int lane=0; lane<4; lane++) begin
            word.id[lane]=base+lane;
            word.value[lane]=operand_a[base+lane];
        end
        return word;
    endfunction

    function void initialize(virtual ntt_if v,ntt_op_e op);
        require(inputs==((op==OP_PWM) ? 512 : 256),"Computation started before all inputs accepted");
        for (int issue=0; issue<32; issue++) begin
            word_t a,b;
            if (op==OP_INTT) begin a=loaded_word(issue*8); b=loaded_word(issue*8+4); end
            else begin a=loaded_word(issue*4); b=loaded_word(128+issue*4); end
            if (op==OP_PRE_NTT) begin
                for (int lane=0; lane<4; lane++) begin
                    coeff_t t,x;
                    t=mulm(b.value[lane],tw(1)); x=a.value[lane];
                    a.value[lane]=addm(x,t); b.value[lane]=subm(x,t);
                end
                if (issue<16) begin queues[0].push_back(a); queues[1].push_back(b); end
                else begin queues[2].push_back(a); queues[0].push_back(b); end
            end else begin queues[0].push_back(a); queues[1].push_back(b); end
        end
        for (int f=0; f<3; f++) begin
            int cap;
            cap=(f==2) ? 16 : 32;
            expected_head[f]=v.fifo_head[f]; expected_tail[f]=v.fifo_tail[f];
            for (int w=0; w<queues[f].size(); w++)
                require(v.fifo_memory[f][(expected_head[f]+w)%cap]===pack_word(queues[f][w]),
                        $sformatf("Loaded FIFO%0d word %0d does not match coefficient IDs/values",f+1,w));
        end
        initialized=1;
    endfunction

    // Derived from transform length/group counts, not RTL bit concatenations.
    function void routes(int stage,int issue,bit inverse,output int sa,sb,da,db);
        int length,group_cycles,switch_cycles;
        length=inverse ? (1<<stage) : (128>>stage);
        sa=0; sb=1; da=0; db=1;
        if ((inverse && stage>=3) || (!inverse && stage>=1 && stage<=5)) begin
            group_cycles=length/4;
            switch_cycles=inverse ? group_cycles/2 : group_cycles;
            if ((issue/switch_cycles)%2==0) begin sa=0; sb=2; end
            else begin sa=1; sb=0; end
        end
        if (inverse && stage>=2 && stage<=6) begin
            if ((issue/(length/4))%2) begin da=2; db=0; end
        end else if (!inverse && stage<=4) begin
            group_cycles=length/4;
            if (issue%group_cycles>=group_cycles/2) begin da=2; db=0; end
        end
    endfunction

    // Classify ACTUAL registered CT inputs. t uses independent reference
    // multiplication; the existing return/memory/output checks verify the
    // resulting DUT arithmetic before a subscriber can credit these masks.
    function void note_ct_arithmetic(coeff_t a,coeff_t b,coeff_t z);
        coeff_t t;
        int unsigned sum, sum_class, sub_class;
        t=mulm(b,z); sum=int'(a)+int'(t);
        if (sum==0) sum_class=0;
        else if (sum<Q) sum_class=1;
        else if (sum==Q) sum_class=2;
        else if (sum==2*Q-2) sum_class=4;
        else sum_class=3;
        // Exact extrema of canonical subtraction need their own witnesses.
        sub_class=(a==0 && t==Q-1) ? 0 : ((a<t) ? 1 :
                  ((a==t) ? 2 : ((a==Q-1 && t==0) ? 4 : 3)));
        ct_sum_classes[sum_class]=1;
        ct_sub_classes[sub_class]=1;
    endfunction

    // Reference classification uses plain integer sums, not DUT carry logic.
    function void note_gs_sum(int lane,coeff_t a,coeff_t b);
        int unsigned sum, sum_class;
        sum=int'(a)+int'(b);
        if (sum==0) sum_class=0;
        else if (sum<Q) sum_class=1;
        else if (sum==Q) sum_class=2;
        else if (sum==2*Q-2) sum_class=4;
        else sum_class=3;
        gs_sum_classes[lane][sum_class]=1;
    endfunction

    function void sample(virtual ntt_if v,ntt_op_e op);
        write_t issued,returned;
        input_t wanted_input;
        bit [2:0] pops,pushes;
        word_t write_words[3];
        int counts[3];
        issued.valid=0; wanted_input.valid=0; pops=0; pushes=0;
        if (v.rst) return; // object is new per completed job, including recovery
        if (v.s_tvalid && v.s_tready) begin
            if (inputs<256) operand_a[inputs]=v.s_tdata;
            else if (inputs<512) operand_b[inputs-256]=v.s_tdata;
            else require(0,"Extra accepted input coefficient");
            inputs++;
        end
        if (!initialized && (v.run_issue || v.pwm_issue)) initialize(v,op);
        if (!initialized) return;

        counts[0]=v.fifo_count1; counts[1]=v.fifo_count2; counts[2]=v.fifo_count3;
        for (int f=0; f<3; f++) begin
            require(counts[f]==queues[f].size(),$sformatf("FIFO%0d count differs from independent queue",f+1));
            require(v.fifo_head[f]==expected_head[f] && v.fifo_tail[f]==expected_tail[f],"FIFO pointer differs from independent pop/push history");
            if (memory_check[f]) require(v.fifo_memory[f][memory_address[f]]===memory_value[f],"FIFO physical write did not store expected coefficient word");
            memory_check[f]=0;
        end
        if (input_pending[1].valid) begin
            for (int lane=0; lane<4; lane++) begin
                coeff_t observed_a;
                observed_a=v.bf_input_a[lane];
                if (observation_fault==1 && !fault_injected && lane==0) begin
                    observed_a^=coeff_t'(1); fault_injected=1;
                end
                require(observed_a===input_pending[1].a[lane] &&
                        v.bf_input_b[lane]===input_pending[1].b[lane] &&
                        v.bf_input_z[lane]===input_pending[1].z[lane] &&
                        v.bf_input_mode[lane]===input_pending[1].mode,
                        $sformatf("Registered butterfly operand/twiddle/mode mismatch, lane=%0d",lane));
                if (op!=OP_PWM && input_pending[1].mode==BF_CT)
                    note_ct_arithmetic(observed_a,v.bf_input_b[lane],v.bf_input_z[lane]);
                if (op==OP_INTT && input_pending[1].mode==BF_GS)
                    note_gs_sum(lane,observed_a,v.bf_input_b[lane]);
            end
        end

        if (v.run_issue || v.pwm_issue) begin
            int sa,sb,da,db,length;
            sa=0; sb=1; da=0; db=1;
            if (op==OP_PWM) begin sa=v.tick/32; da=sa; end
            else routes(v.stage,v.issue,op==OP_INTT,sa,sb,da,db);
            require(v.source_a==sa && v.dest_a==da,"Issue source/destination A violates independent route formula");
            if (op!=OP_PWM) require(v.source_b==sb && v.dest_b==db,"Issue source/destination B violates independent route formula");
            require(queues[sa].size()>0,"Independent FIFO A underflow");
            if (queues[sa].size()==0) return;
            issued.a=queues[sa].pop_front(); pops[sa]=1;
            issued.valid=1; issued.pwm=(op==OP_PWM); issued.stage=(op==OP_PWM) ? 0 : int'(v.stage); issued.da=da; issued.db=db;
            wanted_input.valid=1; wanted_input.mode=(op==OP_INTT) ? BF_GS : BF_CT;
            if (op==OP_PWM) begin
                for (int lane=0; lane<4; lane++) begin
                    int id;
                    id=issued.a.id[lane];
                    require(id==v.tick*4+lane && !pwm_ids[id],"PWM operand index missing, duplicated or out of order");
                    pwm_ids[id]=1;
                    wanted_input.a[lane]=0; wanted_input.b[lane]=issued.a.value[lane];
                    wanted_input.z[lane]=operand_b[id];
                    issued.a.value[lane]=mulm(issued.a.value[lane],operand_b[id]);
                end
            end else begin
                coeff_t values[8];
                int ids[8],lane;
                require(queues[sb].size()>0,"Independent FIFO B underflow");
                if (queues[sb].size()==0) return;
                issued.b=queues[sb].pop_front(); pops[sb]=1;
                for (int j=0; j<4; j++) begin
                    ids[j]=issued.a.id[j]; values[j]=issued.a.value[j];
                    ids[j+4]=issued.b.id[j]; values[j+4]=issued.b.value[j];
                end
                length=(op==OP_INTT) ? (1<<v.stage) : (128>>v.stage);
                lane=0;
                for (int x=0; x<8; x++) if (ids[x]%(2*length)<length) begin
                    int y,address;
                    coeff_t z,t,low_value,high_value;
                    y=-1;
                    for (int j=0; j<8; j++) if (ids[j]==ids[x]+length) y=j;
                    require(y>=0 && lane<4,"Wrong coefficient butterfly pairing");
                    if (y<0 || lane>=4) return;
                    require(!pair_ids[v.stage][ids[x]],"Duplicate coefficient pair in stage");
                    pair_ids[v.stage][ids[x]]=1; pairs_checked++;
                    address=(op==OP_INTT) ? (256>>v.stage)-1-ids[x]/(2*length) :
                                            (1<<v.stage)+ids[x]/(2*length);
                    z=tw(address);
                    if (op==OP_INTT) z=coeff_t'(Q)-z;
                    wanted_input.a[lane]=values[x]; wanted_input.b[lane]=values[y]; wanted_input.z[lane]=z;
                    if (op==OP_INTT) begin
                        low_value=mulm(addm(values[x],values[y]),coeff_t'((Q+1)/2));
                        high_value=mulm(mulm(subm(values[x],values[y]),z),coeff_t'((Q+1)/2));
                    end else begin
                        t=mulm(values[y],z); low_value=addm(values[x],t); high_value=subm(values[x],t);
                    end
                    if (x<4) issued.a.value[x]=low_value; else issued.b.value[x-4]=low_value;
                    if (y<4) issued.a.value[y]=high_value; else issued.b.value[y-4]=high_value;
                    lane++;
                end
                require(lane==4,"An issue did not contain four independent coefficient pairs");
            end
        end

        returned=pending[8];
        require(v.return_valid===returned.valid,"Return valid differs from independent nine-clock schedule");
        if (returned.valid) begin
            pushes[returned.da]=1; write_words[returned.da]=returned.a;
            if (!returned.pwm) begin pushes[returned.db]=1; write_words[returned.db]=returned.b; end
            for (int word_index=0; word_index<(returned.pwm ? 1 : 2); word_index++) begin
                word_t word;
                word=(word_index==0) ? returned.a : returned.b;
                for (int lane=0; lane<4; lane++) begin
                    int id;
                    id=word.id[lane];
                    require(!destination_ids[returned.stage][id],"Coefficient destination duplicated within stage");
                    destination_ids[returned.stage][id]=1; destinations_checked++;
                    if (returned.pwm || returned.stage==7) final_values[id]=word.value[lane];
                end
            end
        end
        if (v.output_read) begin
            int f;
            require(v.output_address==reads && reads<256,"Output read address duplicated, skipped or out of order");
            f=(op==OP_NTT || op==OP_PRE_NTT) ? ((reads/4)%2) : reads/128;
            if (reads%4==3) begin
                word_t discarded;
                require(queues[f].size()>0,"Output FIFO underflow");
                if (queues[f].size()>0) discarded=queues[f].pop_front();
                pops[f]=1;
            end
            reads++;
        end
        if (v.m_tvalid && v.m_tready) begin
            require(outputs<256 && v.m_tdata===final_values[outputs],"Output coefficient does not match independent destination ID/value");
            outputs++;
        end
        require(v.fifo_pop===pops && v.fifo_push===pushes,"Actual FIFO pop/push mask differs from independent schedule");
        for (int f=0; f<3; f++) begin
            int cap;
            cap=(f==2) ? 16 : 32;
            if (pops[f]) expected_head[f]=(expected_head[f]+1)%cap;
            if (pushes[f]) begin
                logic [4*COEFF_W-1:0] observed_word;
                observed_word=v.fifo_push_word[f];
                if (observation_fault==2 && !fault_injected) begin
                    observed_word^=1; fault_injected=1;
                end
                require(observed_word===pack_word(write_words[f]),"Writeback coefficient IDs/values reassembled incorrectly");
                memory_check[f]=1; memory_address[f]=expected_tail[f]; memory_value[f]=pack_word(write_words[f]);
                queues[f].push_back(write_words[f]);
                expected_tail[f]=(expected_tail[f]+1)%cap;
            end
        end
        for (int d=8; d>0; d--) pending[d]=pending[d-1];
        pending[0]=issued;
        input_pending[1]=input_pending[0]; input_pending[0]=wanted_input;
    endfunction

    function bit valid_job(ntt_op_e op);
        int first_stage;
        first_stage=(op==OP_PRE_NTT) ? 1 : 0;
        if (!initialized || errors || outputs!=256 || reads!=256) return 0;
        if (op==OP_PWM) return $countones(pwm_ids)==256 && $countones(destination_ids[0])==256;
        for (int s=0; s<8; s++) begin
            int length;
            length=(op==OP_INTT) ? (1<<s) : (128>>s);
            for (int id=0; id<256; id++) begin
                if (pair_ids[s][id] != (s>=first_stage && id%(2*length)<length)) return 0;
                if (destination_ids[s][id] != (s>=first_stage)) return 0;
            end
        end
        return pairs_checked==(8-first_stage)*128 && destinations_checked==(8-first_stage)*256;
    endfunction
endclass
