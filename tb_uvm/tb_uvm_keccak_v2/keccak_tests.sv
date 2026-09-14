// =========================================================================
// keccak_tests.sv  -  UVM tests (multi-lane)
//
// Each test forks N_LANES copies of a sequence onto the per-lane sequencers
// and joins before dropping the objection. With N_LANES=1 this behaves like
// the original single-lane regression.
// =========================================================================
class keccak_base_test extends uvm_test;
    `uvm_component_utils(keccak_base_test)

    keccak_env env;

    function new(string name = "keccak_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = keccak_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass


// Directed only: 13 NIST vectors per lane, in parallel.
class keccak_directed_test extends keccak_base_test;
    `uvm_component_utils(keccak_directed_test)

    function new(string name = "keccak_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        keccak_directed_seq seq [keccak_env::N_LANES];
        phase.raise_objection(this);

        foreach (seq[i]) seq[i] = keccak_directed_seq::type_id::create($sformatf("seq_%0d", i));

        fork
            seq[0].start(env.agent[0].sequencer);
            seq[1].start(env.agent[1].sequencer);
            seq[2].start(env.agent[2].sequencer);
            seq[3].start(env.agent[3].sequencer);
        join

        #200;
        phase.drop_objection(this);
    endtask
endclass


// Full: directed + stress + coverage closure per lane, in parallel.
class keccak_full_test extends keccak_base_test;
    `uvm_component_utils(keccak_full_test)

    function new(string name = "keccak_full_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        keccak_full_seq seq [keccak_env::N_LANES];
        phase.raise_objection(this);

        foreach (seq[i]) seq[i] = keccak_full_seq::type_id::create($sformatf("seq_%0d", i));

        fork
            seq[0].start(env.agent[0].sequencer);
            seq[1].start(env.agent[1].sequencer);
            seq[2].start(env.agent[2].sequencer);
            seq[3].start(env.agent[3].sequencer);
        join

        run_concurrency_wave(1);
        run_concurrency_wave(2);
        run_concurrency_wave(3);
        for (int kind = 1; kind <= 3; kind++) begin
            run_isolation_wave(kind, SHAKE128);
            run_isolation_wave(kind, SHAKE256);
        end
        run_mixed_lane_wave();

        #200;
        phase.drop_objection(this);
    endtask

    task run_isolation_wave(int kind, keccak_mode mode);
        keccak_lane_isolation_target_seq target;
        keccak_lane_isolation_peer_seq peer;

        target = keccak_lane_isolation_target_seq::type_id::create(
            $sformatf("isolation_target_%0d_%s", kind, mode.name()));
        peer = keccak_lane_isolation_peer_seq::type_id::create(
            $sformatf("isolation_peer_%0d_%s", kind, mode.name()));
        target.isolation_kind = kind;
        target.target_mode = mode;
        peer.isolation_kind = kind;
        peer.peer_mode = (mode == SHAKE128) ? SHAKE256 : SHAKE128;

        fork
            target.start(env.agent[0].sequencer);
            begin
                #500;
                peer.start(env.agent[1].sequencer);
            end
        join
    endtask

    task run_concurrency_wave(int active_lanes);
        keccak_concurrency_seq seq [keccak_env::N_LANES];
        foreach (seq[i]) begin
            seq[i] = keccak_concurrency_seq::type_id::create(
                $sformatf("concurrency_%0d_seq_%0d", active_lanes, i));
            seq[i].active_lanes = active_lanes;
        end

        case (active_lanes)
            1: seq[0].start(env.agent[0].sequencer);
            2: fork
                   seq[0].start(env.agent[0].sequencer);
                   seq[1].start(env.agent[1].sequencer);
               join
            3: fork
                   seq[0].start(env.agent[0].sequencer);
                   seq[1].start(env.agent[1].sequencer);
                   seq[2].start(env.agent[2].sequencer);
               join
            default: `uvm_fatal(get_type_name(), "Unsupported lane count")
        endcase
    endtask

    task run_mixed_lane_wave();
        keccak_mixed_lane_seq seq [keccak_env::N_LANES];
        foreach (seq[i]) begin
            seq[i] = keccak_mixed_lane_seq::type_id::create(
                $sformatf("mixed_lane_seq_%0d", i));
            seq[i].lane_index = i;
        end

        fork
            seq[0].start(env.agent[0].sequencer);
            seq[1].start(env.agent[1].sequencer);
            seq[2].start(env.agent[2].sequencer);
            seq[3].start(env.agent[3].sequencer);
        join
    endtask
endclass
