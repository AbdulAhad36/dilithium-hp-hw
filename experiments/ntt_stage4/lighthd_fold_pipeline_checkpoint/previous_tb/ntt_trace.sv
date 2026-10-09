// Per-job DUT observations collected by the UVM monitor. No covergroup is
// sampled here: the scoreboard decides whether this trace may credit bins.
class ntt_trace extends uvm_object;
    `uvm_object_utils(ntt_trace)

    ntt_routing_trace routing;
    int issue_hits[8][32], pwm_hits[64];
    bit [255:0] twiddles[8];
    bit [2:0] sources, destinations, occupancy[3], scaling;
    bit [8:0] pre_values[3]; // first, middle, last accepted A coefficient
    int peaks[3], inputs, issues, returns, errors;
    bit [2:0] input_gaps, output_stalls; // first region, middle, last region
    bit pwm_boundary_gap;
    bit previous_tw_valid, previous_half_valid;
    int previous_tw_addr[4];
    logic [4*COEFF_W-1:0] half_a, half_b;
    bit delayed_valid[9], delayed_pwm[9];
    logic [1:0] delayed_a[9], delayed_b[9];

    function new(string name="ntt_trace");
        super.new(name);
        routing=ntt_routing_trace::type_id::create("routing");
    endfunction

    function int mode_index(ntt_op_e op);
        return (op == OP_INTT) ? 1 : ((op == OP_PRE_NTT) ? 2 :
               ((op == OP_PWM) ? 3 : 0));
    endfunction

    function void sample(virtual ntt_if v, ntt_op_e op);
        int counts[3];
        routing.sample(v,op);
        if (v.rst) begin
            previous_tw_valid = 0;
            previous_half_valid = 0;
            foreach (delayed_valid[i]) delayed_valid[i] = 0;
            return;
        end
        if ($isunknown({v.run_issue,v.pwm_issue,v.return_valid,
                        v.fifo_count1,v.fifo_count2,v.fifo_count3})) errors++;
        counts[0] = v.fifo_count1; counts[1] = v.fifo_count2;
        counts[2] = v.fifo_count3;
        for (int f=0; f<3; f++) begin
            int cap;
            cap = (f==2) ? 16 : 32;
            if (counts[f]<0 || counts[f]>cap) errors++;
            else occupancy[f][(counts[f]==0) ? 0 : ((counts[f]==cap) ? 2 : 1)] = 1;
            if (counts[f]>peaks[f]) peaks[f]=counts[f];
        end
        if (v.s_tvalid && v.s_tready) begin
            if (op == OP_PRE_NTT) begin
                int signed value;
                int position;
                value = (v.s_tdata >= Q-4) ? int'(v.s_tdata)-Q : int'(v.s_tdata);
                position = (inputs==0) ? 0 : ((inputs==N-1) ? 2 : 1);
                if (value < -4 || value > 4) errors++;
                else pre_values[position][value+4]=1;
            end
            inputs++;
        end
        if (v.s_tready && !v.s_tvalid && inputs>0 &&
            inputs<((op==OP_PWM) ? 512 : 256)) begin
            int index;
            index=inputs%256;
            if (op==OP_PWM && inputs==256) pwm_boundary_gap=1;
            else input_gaps[(index<16) ? 0 : ((index>=240) ? 2 : 1)]=1;
        end
        if (previous_tw_valid)
            for (int lane=0; lane<4; lane++)
                if (v.tw_value[lane] !== tw(previous_tw_addr[lane])) errors++;
        previous_tw_valid = v.run_issue;

        if (previous_half_valid && (v.result_a !== half_a || v.result_b !== half_b)) errors++;
        previous_half_valid = v.half_valid;
        if (v.half_valid) begin
            half_a='0; half_b='0;
            for (int lane=0; lane<4; lane++) begin
                coeff_t x,y;
                x=mulm(v.bf_a[lane],coeff_t'((Q+1)/2));
                y=mulm(v.bf_b[lane],coeff_t'((Q+1)/2));
                scaling[(v.bf_a[lane]==0) ? 0 : (v.bf_a[lane][0] ? 2 : 1)]=1;
                scaling[(v.bf_b[lane]==0) ? 0 : (v.bf_b[lane][0] ? 2 : 1)]=1;
                if (v.pair_layout>=2) begin
                    half_a[lane*COEFF_W +: COEFF_W]=x;
                    half_b[lane*COEFF_W +: COEFF_W]=y;
                end else if (v.pair_layout==1) begin
                    if (lane<2) begin
                        half_a[lane*COEFF_W +: COEFF_W]=x;
                        half_a[(lane+2)*COEFF_W +: COEFF_W]=y;
                    end else begin
                        half_b[(lane-2)*COEFF_W +: COEFF_W]=x;
                        half_b[lane*COEFF_W +: COEFF_W]=y;
                    end
                end else if (lane<2) begin
                    half_a[(lane*2)*COEFF_W +: COEFF_W]=x;
                    half_a[(lane*2+1)*COEFF_W +: COEFF_W]=y;
                end else begin
                    half_b[((lane-2)*2)*COEFF_W +: COEFF_W]=x;
                    half_b[((lane-2)*2+1)*COEFF_W +: COEFF_W]=y;
                end
            end
        end

        // Observe pipeline destinations independently of the DUT tag shift.
        if (v.return_valid !== delayed_valid[8]) errors++;
        if (v.return_valid) begin
            returns++;
            if (v.return_pwm !== delayed_pwm[8] ||
                v.return_dest_a !== delayed_a[8] ||
                (!v.return_pwm && v.return_dest_b !== delayed_b[8])) errors++;
        end
        for (int d=8; d>0; d--) begin
            delayed_valid[d]=delayed_valid[d-1]; delayed_pwm[d]=delayed_pwm[d-1];
            delayed_a[d]=delayed_a[d-1]; delayed_b[d]=delayed_b[d-1];
        end
        delayed_valid[0]=v.run_issue || v.pwm_issue;
        delayed_pwm[0]=v.pwm_issue;
        delayed_a[0]=v.dest_a; delayed_b[0]=v.dest_b;

        if (v.run_issue || v.pwm_issue) begin
            issues++;
            if (v.source_a>2 || v.dest_a>2) errors++;
            else begin sources[v.source_a]=1; destinations[v.dest_a]=1; end
            if (v.run_issue) begin
                if (v.source_b>2 || v.dest_b>2) errors++;
                else begin sources[v.source_b]=1; destinations[v.dest_b]=1; end
                issue_hits[v.stage][v.issue]++;
                for (int lane=0; lane<4; lane++) begin
                    int low, address;
                    low = (op==OP_INTT) ? (1<<(7-v.stage)) : (1<<v.stage);
                    if (op==OP_INTT) begin
                        if (v.stage==0) address=128+(31-v.issue)*4+(3-lane);
                        else if (v.stage==1) address=64+(31-v.issue)*2+(1-lane/2);
                        else address=low+((31-v.issue)>>(v.stage-2));
                    end else begin
                        if (v.stage<=5) address=low+(v.issue>>(5-v.stage));
                        else if (v.stage==6) address=64+v.issue*2+lane/2;
                        else address=128+v.issue*4+lane;
                    end
                    if (v.tw_addr[lane] !== 8'(address)) errors++;
                    else twiddles[v.stage][address]=1;
                    previous_tw_addr[lane]=address;
                end
            end else pwm_hits[v.tick[5:0]]++;
        end
    endfunction

    function bit valid_job(ntt_op_e op);
        int first_stage, count;
        bit ok;
        first_stage = (op==OP_PRE_NTT) ? 1 : 0;
        count = (op==OP_PWM) ? 64 : (8-first_stage)*32;
        ok = routing.valid_job(op) && errors==0 && inputs==((op==OP_PWM) ? 512 : 256) &&
             issues==count && returns==count;
        if (op==OP_PWM) begin
            foreach (pwm_hits[i]) if (pwm_hits[i]!=1) ok=0;
        end else begin
            for (int s=0; s<8; s++) begin
                int unique_count;
                unique_count=$countones(twiddles[s]);
                for (int i=0; i<32; i++)
                    if (issue_hits[s][i] != ((s>=first_stage) ? 1 : 0)) ok=0;
                if (unique_count != ((s<first_stage) ? 0 :
                    ((op==OP_INTT) ? (1<<(7-s)) : (1<<s)))) ok=0;
            end
            if (op!=OP_PRE_NTT && peaks[2]>11) ok=0;
        end
        return ok;
    endfunction
endclass
