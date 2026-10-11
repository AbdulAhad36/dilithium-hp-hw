// ============================================================================
// ntt_coverage.sv  --  UVM functional coverage for ntt_engine
// ----------------------------------------------------------------------------
// Subscribes to the scoreboard's checked-pass port. A transaction only hits
// coverage after all 256 observed coefficients and output framing pass.
// ============================================================================
class ntt_coverage extends uvm_subscriber #(ntt_transaction);
    `uvm_component_utils(ntt_coverage)

    ntt_transaction tx_sampled;
    int checked_jobs;
    bit previous_checked;
    int previous_mode;

    // Encoded bins keep the legal denominator explicit and reviewable.
    // issue bin = mode*1024 + stage*128 + issue*4 + lane.
    // mode indexes: NTT=0, INTT=1, Pre=2, PWM=3.
    covergroup cg_schedule with function sample(int position);
        cp_position : coverpoint position {
            bins positions[] = {[0:3071]};
            ignore_bins pre_lookup_stage = {[2048:2175]};
        }
    endgroup
    covergroup cg_twiddle with function sample(int position);
        cp_position : coverpoint position {
            bins mode_address[] = {[0:764]};
            ignore_bins pre_lookup = {510};
        }
    endgroup
    covergroup cg_fifo with function sample(int source_route, int dest_route,
                                            int occupancy_bin);
        cp_source : coverpoint source_route {
            bins routes[] = {[0:11]};
            ignore_bins pwm_fifo3 = {11};
        }
        cp_destination : coverpoint dest_route {
            bins routes[] = {[0:11]};
            ignore_bins pwm_fifo3 = {11};
        }
        cp_occupancy : coverpoint occupancy_bin {
            bins states[] = {[0:35]};
            // mode*9 + fifo*3 + class (empty=0, partial=1, full=2).
            ignore_bins standard_fifo3_full = {8,17};
            ignore_bins pwm_fifo3_nonempty = {34,35};
        }
    endgroup
    covergroup cg_scaling with function sample(int scaling_class);
        cp_class : coverpoint scaling_class {
            bins zero = {0}; bins even_nonzero = {1}; bins odd = {2};
        }
    endgroup
    covergroup cg_pre_lookup with function sample(int position);
        cp_value_position : coverpoint position {
            // position(first/middle/last)*9 + signed_value+4
            bins value_position[] = {[0:26]};
        }
    endgroup
    covergroup cg_pwm_schedule with function sample(int word);
        cp_word : coverpoint word { bins words[] = {[0:63]}; }
    endgroup

    covergroup cg_flow with function sample(int gap, int stall, int boundary);
        cp_input_gap : coverpoint gap {
            // mode*4 + class (none=0, first region=1, middle=2, last region=3)
            bins mode_region[] = {[0:15]};
        }
        cp_output_stall : coverpoint stall { bins mode_position[] = {[0:15]}; }
        cp_pwm_boundary_gap : coverpoint boundary { bins observed = {1}; }
    endgroup

    covergroup cg_reset_abort with function sample(int point);
        cp_point : coverpoint point { bins checked_points[] = {[0:8]}; }
    endgroup

    covergroup cg_pre_equivalence with function sample(in_kind_e kind);
        cp_kind : coverpoint kind { bins eta2={IK_ETA2}; bins eta4={IK_ETA4}; }
    endgroup

    covergroup cg_coefficient_routing with function sample(int pair_position,
            int destination_position,int pwm_id,int output_position);
        cp_pair : coverpoint pair_position {
            // mode*1024 + stage*128 + mathematical pair ordinal.
            bins pairs[] = {[0:3071]};
            ignore_bins pre_lookup_stage={[2048:2175]};
        }
        cp_destination : coverpoint destination_position {
            // mode*2048 + stage*256 + global coefficient ID.
            bins coefficients[] = {[0:6143]};
            ignore_bins pre_lookup_stage={[4096:4351]};
        }
        cp_pwm_id : coverpoint pwm_id { bins coefficients[] = {[0:255]}; }
        cp_output_order : coverpoint output_position { bins mode_index[] = {[0:1023]}; }
    endgroup

    covergroup cg_ntt;
        cp_op : coverpoint tx_sampled.op {
            bins ntt  = {OP_NTT};
            bins intt = {OP_INTT};
            bins pwm  = {OP_PWM};
        }
        cp_in_kind : coverpoint tx_sampled.in_kind {
            bins zero   = {IK_ZERO};
            bins max    = {IK_MAX};
            bins delta  = {IK_DELTA};
            bins random = {IK_RANDOM};
        }
        cross_op_kind : cross cp_op, cp_in_kind;
    endgroup

`ifdef NTT_FIFO
    covergroup cg_pre;
        cp_pre_kind : coverpoint tx_sampled.in_kind {
            bins boundary = {IK_PRE_BOUNDARY};
            bins eta2 = {IK_ETA2};
            bins eta4 = {IK_ETA4};
        }
    endgroup

    covergroup cg_restart;
        cp_op : coverpoint tx_sampled.op {
            bins ntt = {OP_NTT};
            bins intt = {OP_INTT};
            bins pwm = {OP_PWM};
            bins pre = {OP_PRE_NTT};
        }
        cp_reset : coverpoint tx_sampled.reset_before {
            bins reset = {1'b1};
            bins no_reset = {1'b0};
        }
        cross_op_reset : cross cp_op, cp_reset;
    endgroup
`endif

    covergroup cg_butterfly_arithmetic with function sample(int sum_class,int sub_class);
        cp_sum: coverpoint sum_class iff (sum_class>=0) { bins classes[]={[0:4]}; }
        cp_sub: coverpoint sub_class iff (sub_class>=0) { bins classes[]={[0:4]}; }
    endgroup

    // Expanded behavioral bins. All are sampled only in checked write().
    covergroup cg_input_range with function sample(int position);
        cp_stream_value: coverpoint position {
            // NTT A / INTT A / PWM A / PWM B / Pre A, each x eight ranges.
            bins classes[]={[0:39]};
            ignore_bins pre_outside_contract={35,36,37};
        }
    endgroup
    covergroup cg_output_range with function sample(int position);
        cp_mode_value: coverpoint position {bins classes[]={[0:31]};}
    endgroup
    covergroup cg_pwm_pairs with function sample(int position);
        // A range x B range x physical coefficient lane: 8*8*4.
        cp_pair_lane: coverpoint position {bins pairs[]={[0:255]};}
    endgroup
    covergroup cg_input_gap_duration with function sample(int position);
        // Four modes x first/middle/last x five nonzero duration classes.
        cp_mode_region_length: coverpoint position {bins classes[]={[0:59]};}
    endgroup
    covergroup cg_output_stall_duration with function sample(int position);
        cp_mode_region_length: coverpoint position {bins classes[]={[0:59]};}
    endgroup
    covergroup cg_flow_combination with function sample(int position);
        // Four modes x six max-gap classes x six max-stall classes (zero included).
        cp_mode_gap_stall: coverpoint position {bins combinations[]={[0:143]};}
    endgroup
    covergroup cg_operation_transition with function sample(int position);
        // Previous checked mode x current checked mode x observed reset between.
        cp_modes_reset: coverpoint position {bins transitions[]={[0:31]};}
    endgroup
    covergroup cg_polynomial_shape with function sample(int position);
        // Modes x zero/constant/single/alternating/ascending/descending/eta2/other.
        cp_mode_shape: coverpoint position {bins shapes[]={[0:31]};}
    endgroup
    // Deeper contract intersections: observed pins/results, after scoreboard pass.
    // Encoded cross bins retain a stable, explicit legal denominator.
    covergroup cg_shape_input_flow with function sample(int position);
        cp_mode_shape_gap: coverpoint position {bins combinations[]={[0:191]};}
    endgroup
    covergroup cg_shape_output_flow with function sample(int position);
        cp_mode_shape_stall: coverpoint position {bins combinations[]={[0:191]};}
    endgroup
    covergroup cg_shape_reset with function sample(int position);
        cp_mode_shape_reset: coverpoint position {bins combinations[]={[0:63]};}
    endgroup
    covergroup cg_pwm_shapes with function sample(int position);
        cp_a_shape_b_shape: coverpoint position {bins combinations[]={[0:63]};}
    endgroup
    covergroup cg_pre_spatial_values with function sample(int position);
        // Nine exact signed values x four 64-coefficient quadrants x four lanes.
        cp_value_quadrant_lane: coverpoint position {bins combinations[]={[0:143]};}
    endgroup
    covergroup cg_output_lane_ranges with function sample(int position);
        cp_mode_range_lane: coverpoint position {bins combinations[]={[0:127]};}
    endgroup
    covergroup cg_input_spatial_ranges with function sample(int position);
        // Five operand streams x eight ranges x four polynomial quadrants.
        cp_stream_range_quadrant: coverpoint position {
            bins combinations[]={[0:159]};
            ignore_bins pre_outside_contract={[140:151]};
        }
    endgroup
    covergroup cg_transition_flow with function sample(int position);
        cp_prior_current_gap_stall: coverpoint position {bins combinations[]={[0:575]};}
    endgroup
    covergroup cg_shape_dual_flow with function sample(int mode_shape,int gap_stall);
        // Standard equal-weight marginals plus their explicit two-dimensional cross.
        cp_mode_shape: coverpoint mode_shape {
            bins classes[]={[0:31]};
        }
        cp_gap_stall: coverpoint gap_stall {
            bins classes[]={[0:35]};
        }
        cross_shape_flow: cross cp_mode_shape,cp_gap_stall;
    endgroup
    covergroup cg_transition_shape_flow with function sample(int position);
        // Previous/current mode x actual current shape x gap x stall.
        cp_transition_shape_gap_stall: coverpoint position {bins combinations[]={[0:4607]};}
    endgroup

    function real interaction_mean_coverage();
        return (cg_shape_input_flow.get_coverage()+cg_shape_output_flow.get_coverage()+
            cg_shape_reset.get_coverage()+cg_pwm_shapes.get_coverage()+
            cg_pre_spatial_values.get_coverage()+cg_output_lane_ranges.get_coverage()+
            cg_input_spatial_ranges.get_coverage()+cg_transition_flow.get_coverage()+
            cg_shape_dual_flow.get_coverage()+cg_transition_shape_flow.get_coverage())/10.0;
    endfunction
    function real overall_coverage();
        // Equal weight for every covergroup type, matching the existing headline.
        real legacy;
        legacy=cg_ntt.get_coverage()+cg_coefficient_routing.get_coverage()+
            cg_schedule.get_coverage()+cg_twiddle.get_coverage()+cg_fifo.get_coverage()+
            cg_flow.get_coverage()+cg_reset_abort.get_coverage()+cg_pre_equivalence.get_coverage()+
            cg_butterfly_arithmetic.get_coverage()+cg_scaling.get_coverage()+
            cg_pre_lookup.get_coverage()+cg_pwm_schedule.get_coverage()+
            cg_pre.get_coverage()+cg_restart.get_coverage();
        return (legacy+8.0*expanded_mean_coverage()+10.0*interaction_mean_coverage())/32.0;
    endfunction
    function void sample_interactions(ntt_transaction t);
        int mode,shape,stream,gap,stall,reset_event,pre_value;
        mode=t.trace.mode_index(t.op);
        shape=ntt_trace::polynomial_shape(t.trace.routing.operand_a);
        stream=(t.op==OP_PRE_NTT)?4:((t.op==OP_PWM)?2:mode);
        gap=ntt_trace::duration_class(t.trace.max_gap);
        stall=ntt_trace::duration_class(t.trace.max_stall);
        reset_event=int'(t.trace.reset_seen || t.reset_checks_ok);
        cg_shape_input_flow.sample((mode*8+shape)*6+gap);
        cg_shape_output_flow.sample((mode*8+shape)*6+stall);
        cg_shape_reset.sample((mode*8+shape)*2+reset_event);
        cg_shape_dual_flow.sample(mode*8+shape,gap*6+stall);
        if(t.op==OP_PWM)
            cg_pwm_shapes.sample(shape*8+ntt_trace::polynomial_shape(t.trace.routing.operand_b));
        for(int i=0;i<N;i++) begin
            cg_input_spatial_ranges.sample((stream*8+
                ntt_trace::value_class(t.trace.routing.operand_a[i]))*4+i/64);
            cg_output_lane_ranges.sample((mode*8+ntt_trace::value_class(t.obs_poly[i]))*4+i%4);
            if(t.op==OP_PWM)
                cg_input_spatial_ranges.sample((3*8+
                    ntt_trace::value_class(t.trace.routing.operand_b[i]))*4+i/64);
            if(t.op==OP_PRE_NTT) begin
                pre_value=int'(t.trace.routing.operand_a[i]);
                if(pre_value>4) pre_value-=Q;
                if(pre_value < -4 || pre_value > 4)
                    `uvm_fatal("PRE_SPATIAL_COVERAGE","Ineligible observed Pre coefficient")
                cg_pre_spatial_values.sample(((pre_value+4)*4+i/64)*4+i%4);
            end
        end
        if(previous_checked) begin
            cg_transition_flow.sample((previous_mode*4+mode)*36+gap*6+stall);
            cg_transition_shape_flow.sample(((previous_mode*4+mode)*8+shape)*36+gap*6+stall);
        end
        `uvm_info("CHECKED_INTERACTIONS",$sformatf("[%s] mode=%0d prior=%0d prior_valid=%0b shape=%0d gap_class=%0d stall_class=%0d reset=%0d",
            t.test_name,mode,previous_mode,previous_checked,shape,gap,stall,reset_event),UVM_LOW)
    endfunction


    function real expanded_mean_coverage();
        return (cg_input_range.get_coverage()+cg_output_range.get_coverage()+cg_pwm_pairs.get_coverage()+cg_input_gap_duration.get_coverage()+cg_output_stall_duration.get_coverage()+cg_flow_combination.get_coverage()+cg_operation_transition.get_coverage()+cg_polynomial_shape.get_coverage())/8.0;
    endfunction
    function real minimum_group_coverage();
        real values[22];
        real minimum;
        values='{cg_ntt.get_coverage(),cg_coefficient_routing.get_coverage(),cg_schedule.get_coverage(),cg_twiddle.get_coverage(),cg_fifo.get_coverage(),cg_flow.get_coverage(),cg_reset_abort.get_coverage(),cg_pre_equivalence.get_coverage(),cg_butterfly_arithmetic.get_coverage(),cg_scaling.get_coverage(),cg_pre_lookup.get_coverage(),cg_pwm_schedule.get_coverage(),cg_pre.get_coverage(),cg_restart.get_coverage(),cg_input_range.get_coverage(),cg_output_range.get_coverage(),cg_pwm_pairs.get_coverage(),cg_input_gap_duration.get_coverage(),cg_output_stall_duration.get_coverage(),cg_flow_combination.get_coverage(),cg_operation_transition.get_coverage(),cg_polynomial_shape.get_coverage()};
        minimum=100;
        foreach(values[i]) if(values[i]<minimum) minimum=values[i];
        return minimum;
    endfunction
    function void sample_expanded(ntt_transaction t);
        int mode,stream;
        mode=t.trace.mode_index(t.op);
        stream=(t.op==OP_PRE_NTT)?4:((t.op==OP_PWM)?2:mode);
        for(int i=0;i<N;i++) begin
            cg_input_range.sample(stream*8+ntt_trace::value_class(t.trace.routing.operand_a[i]));
            cg_output_range.sample(mode*8+ntt_trace::value_class(t.obs_poly[i]));
            if(t.op==OP_PWM) begin
                cg_input_range.sample(3*8+ntt_trace::value_class(t.trace.routing.operand_b[i]));
                cg_pwm_pairs.sample((ntt_trace::value_class(t.trace.routing.operand_a[i])*8+
                    ntt_trace::value_class(t.trace.routing.operand_b[i]))*4+i%4);
            end
        end
        for(int region=0;region<3;region++) for(int length=1;length<6;length++) begin
            if(t.trace.gap_lengths[region][length]>0)
                cg_input_gap_duration.sample(mode*15+region*5+length-1);
            if(t.trace.stall_lengths[region][length]>0)
                cg_output_stall_duration.sample(mode*15+region*5+length-1);
        end
        cg_flow_combination.sample(mode*36+ntt_trace::duration_class(t.trace.max_gap)*6+
            ntt_trace::duration_class(t.trace.max_stall));
        cg_polynomial_shape.sample(mode*8+ntt_trace::polynomial_shape(t.trace.routing.operand_a));
        if(previous_checked)
            cg_operation_transition.sample((previous_mode*4+mode)*2+
                int'(t.trace.reset_seen || t.reset_checks_ok));
        previous_checked=1;previous_mode=mode;
        `uvm_info("CHECKED_EXTENDED",$sformatf("[%s] mode=%0d shape=%0d max_gap=%0d max_stall=%0d reset_seen=%0b",
            t.test_name,mode,ntt_trace::polynomial_shape(t.trace.routing.operand_a),
            t.trace.max_gap,t.trace.max_stall,t.trace.reset_seen || t.reset_checks_ok),UVM_LOW)
    endfunction

    function new(string name = "ntt_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_ntt = new();
        cg_shape_input_flow=new();cg_shape_output_flow=new();cg_shape_reset=new();
        cg_pwm_shapes=new();cg_pre_spatial_values=new();cg_output_lane_ranges=new();
        cg_input_spatial_ranges=new();cg_transition_flow=new();
        cg_shape_dual_flow=new();cg_transition_shape_flow=new();
        cg_input_range=new();
        cg_output_range=new();
        cg_pwm_pairs=new();
        cg_input_gap_duration=new();
        cg_output_stall_duration=new();
        cg_flow_combination=new();
        cg_operation_transition=new();
        cg_polynomial_shape=new();

        cg_coefficient_routing = new();
        cg_schedule = new(); cg_twiddle = new(); cg_fifo = new();
        cg_flow = new();
        cg_reset_abort = new();
        cg_pre_equivalence = new();
        cg_butterfly_arithmetic = new();
        cg_scaling = new(); cg_pre_lookup = new(); cg_pwm_schedule = new();
`ifdef NTT_FIFO
        cg_pre = new();
        cg_restart = new();
`endif
    endfunction

    function void write(ntt_transaction t);
        // The scoreboard is the only publisher to this subscriber.
        if (t.trace == null || !t.trace.valid_job(t.op))
            `uvm_fatal("COVERAGE_GATE", "Unverified trace reached checked coverage")
        tx_sampled = t;
        sample_interactions(t);
        sample_expanded(t);
        if (t.equivalence_pair>=0 && t.equivalence_second)
            cg_pre_equivalence.sample(t.in_kind);
        if (t.observed_reset_point>=0) begin
            if (!t.reset_checks_ok) `uvm_fatal("COVERAGE_GATE", "Unchecked reset reached coverage")
            cg_reset_abort.sample(t.observed_reset_point);
        end
        checked_jobs++;
        for (int c=0;c<5;c++) if (t.trace.routing.ct_sum_classes[c])
            cg_butterfly_arithmetic.sample(c,-1);
        for (int c=0;c<5;c++) if (t.trace.routing.ct_sub_classes[c])
            cg_butterfly_arithmetic.sample(-1,c);
        if (t.test_name=="ARITH CT addition/subtraction boundaries") begin
            if (t.trace.routing.ct_sum_classes!=5'b11111 || t.trace.routing.ct_sub_classes!=5'b11111)
                `uvm_fatal("ARITH_BOUNDARY_GATE","Required observed CT boundary classes were not checked")
            `uvm_info("CHECKED_ARITHMETIC_BOUNDARIES",
                "Observed/check-passed CT sums: zero, below q, equal q, above q, maximum; subtraction: minimum, negative, zero, positive, maximum",UVM_LOW)
        end
        begin
            int mode, twiddle_count;
            mode=t.trace.mode_index(t.op);
            `uvm_info("CHECKED_COEFFICIENT_ROUTING",
                $sformatf("[%s] pairs=%0d destinations=%0d pwm_ids=%0d output_reads=%0d output_coefficients=%0d routing_errors=%0d",
                    t.test_name,t.trace.routing.pairs_checked,t.trace.routing.destinations_checked,
                    $countones(t.trace.routing.pwm_ids),t.trace.routing.reads,t.trace.routing.outputs,t.trace.routing.errors),UVM_LOW)
            if (t.op==OP_PWM) begin
                for (int id=0; id<256; id++)
                    if (t.trace.routing.pwm_ids[id]) cg_coefficient_routing.sample(-1,-1,id,-1);
            end else begin
                for (int stage=0; stage<8; stage++) begin
                    int length;
                    length=(t.op==OP_INTT) ? (1<<stage) : (128>>stage);
                    for (int id=0; id<256; id++) begin
                        if (t.trace.routing.pair_ids[stage][id])
                            cg_coefficient_routing.sample(mode*1024+stage*128+
                                (id/(2*length))*length+id%length,-1,-1,-1);
                        if (t.trace.routing.destination_ids[stage][id])
                            cg_coefficient_routing.sample(-1,mode*2048+stage*256+id,-1,-1);
                    end
                end
            end
            for (int id=0; id<256; id++) cg_coefficient_routing.sample(-1,-1,-1,mode*256+id);
            twiddle_count=0;
            for (int stage=0; stage<8; stage++) twiddle_count+=$countones(t.trace.twiddles[stage]);
            `uvm_info("CHECKED_TRACE",
                $sformatf("[%s] op=%s inputs=%0d issues=%0d returns=%0d twiddles=%0d fifo_peak=%0d/%0d/%0d occupancy=%03b/%03b/%03b sources=%03b destinations=%03b scaling=%03b pre_values=%09b/%09b/%09b gaps=%03b stalls=%03b pwm_boundary_gap=%0b",
                    t.test_name,t.op.name(),t.trace.inputs,t.trace.issues,t.trace.returns,twiddle_count,
                    t.trace.peaks[0],t.trace.peaks[1],t.trace.peaks[2],
                    t.trace.occupancy[0],t.trace.occupancy[1],t.trace.occupancy[2],
                    t.trace.sources,t.trace.destinations,t.trace.scaling,
                    t.trace.pre_values[0],t.trace.pre_values[1],t.trace.pre_values[2],
                    t.trace.input_gaps,t.trace.output_stalls,t.trace.pwm_boundary_gap),UVM_LOW)
            if (t.trace.input_gaps==0) cg_flow.sample(mode*4,-1,-1);
            if (t.trace.output_stalls==0) cg_flow.sample(-1,mode*4,-1);
            for (int c=0; c<3; c++) begin
                if (t.trace.input_gaps[c]) cg_flow.sample(mode*4+c+1,-1,-1);
                if (t.trace.output_stalls[c]) cg_flow.sample(-1,mode*4+c+1,-1);
            end
            if (t.trace.pwm_boundary_gap) cg_flow.sample(-1,-1,1);
            if (t.op==OP_PWM) begin
                for (int i=0; i<64; i++)
                    if (t.trace.pwm_hits[i]) cg_pwm_schedule.sample(i);
            end else begin
                for (int s=0; s<8; s++) begin
                    for (int i=0; i<32; i++)
                        if (t.trace.issue_hits[s][i])
                            for (int lane=0; lane<4; lane++)
                                cg_schedule.sample(mode*1024+s*128+i*4+lane);
                    for (int addr=1; addr<256; addr++)
                        if (t.trace.twiddles[s][addr])
                            cg_twiddle.sample(mode*255+addr-1);
                end
            end
            for (int f=0; f<3; f++) begin
                // -1 is outside bins when only another event is sampled.
                if (t.trace.sources[f]) cg_fifo.sample(mode*3+f,-1,-1);
                if (t.trace.destinations[f]) cg_fifo.sample(-1,mode*3+f,-1);
                for (int c=0; c<3; c++)
                    if (t.trace.occupancy[f][c]) cg_fifo.sample(-1,-1,mode*9+f*3+c);
            end
            for (int c=0; c<3; c++) if (t.trace.scaling[c]) cg_scaling.sample(c);
            for (int p=0; p<3; p++)
                for (int value=0; value<9; value++)
                    if (t.trace.pre_values[p][value]) cg_pre_lookup.sample(p*9+value);
        end
`ifdef NTT_FIFO
        cg_restart.sample();
        if (t.op == OP_PRE_NTT) cg_pre.sample();
        else cg_ntt.sample();
`else
        cg_ntt.sample();
`endif
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("OVERALL_FUNCTIONAL_COVERAGE",$sformatf("32 covergroup types, equal-weight mean=%0.4f%%; interaction mean=%0.4f%%",overall_coverage(),interaction_mean_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_shape_input_flow=%0.4f%%",cg_shape_input_flow.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_shape_output_flow=%0.4f%%",cg_shape_output_flow.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_shape_reset=%0.4f%%",cg_shape_reset.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_pwm_shapes=%0.4f%%",cg_pwm_shapes.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_pre_spatial_values=%0.4f%%",cg_pre_spatial_values.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_output_lane_ranges=%0.4f%%",cg_output_lane_ranges.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_input_spatial_ranges=%0.4f%%",cg_input_spatial_ranges.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_transition_flow=%0.4f%%",cg_transition_flow.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_shape_dual_flow=%0.4f%%",cg_shape_dual_flow.get_coverage()),UVM_NONE)
        `uvm_info("INTERACTION_COVERAGE",$sformatf("cg_transition_shape_flow=%0.4f%%",cg_transition_shape_flow.get_coverage()),UVM_NONE)

        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_input_range=%0.2f%%",cg_input_range.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_output_range=%0.2f%%",cg_output_range.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_pwm_pairs=%0.2f%%",cg_pwm_pairs.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_input_gap_duration=%0.2f%%",cg_input_gap_duration.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_output_stall_duration=%0.2f%%",cg_output_stall_duration.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_flow_combination=%0.2f%%",cg_flow_combination.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_operation_transition=%0.2f%%",cg_operation_transition.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("cg_polynomial_shape=%0.2f%%",cg_polynomial_shape.get_coverage()),UVM_NONE)
        `uvm_info("EXPANDED_COVERAGE",$sformatf("eight-group equal-weight mean=%0.2f%% minimum_of_22=%0.2f%%",expanded_mean_coverage(),minimum_group_coverage()),UVM_NONE)

        `uvm_info("COEFFICIENT_ROUTING_COVERAGE",$sformatf("checked_pairs_destinations_PWM_output=%0.2f%%",cg_coefficient_routing.get_coverage()),UVM_NONE)
        `uvm_info("CHECKED_PRE_EQUIVALENCE",$sformatf("observed_Pre_general_equivalence=%0.2f%%",cg_pre_equivalence.get_coverage()),UVM_NONE)
        `uvm_info("CHECKED_RESET_COVERAGE",
            $sformatf("reset_cancel_and_recovery=%0.2f%%",cg_reset_abort.get_coverage()),UVM_NONE)
        `uvm_info("CHECKED_INTERNAL_COVERAGE",
                  $sformatf("jobs=%0d schedule=%0.2f%% twiddle=%0.2f%% fifo=%0.2f%% scaling=%0.2f%% pre_lookup=%0.2f%% pwm_words=%0.2f%% flow=%0.2f%%",
                            checked_jobs, cg_schedule.get_coverage(), cg_twiddle.get_coverage(),
                            cg_fifo.get_coverage(), cg_scaling.get_coverage(),
                            cg_pre_lookup.get_coverage(), cg_pwm_schedule.get_coverage(), cg_flow.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(),
                  $sformatf("Functional Coverage: %0.2f%%", cg_ntt.get_coverage()),
                  UVM_NONE)
`ifdef NTT_FIFO
        `uvm_info(get_type_name(),
                  $sformatf("Checked Pre-NTT Coverage: %0.2f%%", cg_pre.get_coverage()),
                  UVM_NONE)
        `uvm_info(get_type_name(),
                  $sformatf("Checked Operation x Reset Coverage: %0.2f%%", cg_restart.get_coverage()),
                  UVM_NONE)
`endif
    endfunction

endclass
