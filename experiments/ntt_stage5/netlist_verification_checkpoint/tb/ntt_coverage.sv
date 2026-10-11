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

    function new(string name = "ntt_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_ntt = new();
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
