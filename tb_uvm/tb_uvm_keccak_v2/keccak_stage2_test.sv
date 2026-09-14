// Port-only suite: same stimulus/checker for RTL and Quartus functional netlist.
// Internal FSM-targeted reset tests remain in Stage 1.
class keccak_stage2_evidence extends uvm_subscriber #(keccak_transaction);
    `uvm_component_utils(keccak_stage2_evidence)
    int fd;
    int count;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fd = $fopen("checked_transactions.txt", "w");
        if (!fd) `uvm_fatal("STAGE2", "Cannot open checked transaction record")
    endfunction
    function void write(keccak_transaction t);
        keccak_transaction tx = t;
        string observed = "";
        if (!tx.passed) `uvm_fatal("STAGE2", "Unchecked evidence received")
        foreach (tx.obs_bytes[i])
            observed = {observed, $sformatf("%02x", tx.obs_bytes[i])};
        count++;
        $fdisplay(fd, "%0d|%s|%0d|%0d|%s|%s",
            count, tx.test_name, tx.mode, tx.xof_len_val,
            tx.obs_msg_hex, observed);
    endfunction
    function void final_phase(uvm_phase phase);
        $fclose(fd);
    endfunction
endclass

class keccak_stage2_test extends keccak_base_test;
    `uvm_component_utils(keccak_stage2_test)
    keccak_stage2_evidence evidence;
    function new(string name = "keccak_stage2_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        evidence = keccak_stage2_evidence::type_id::create("evidence", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.scoreboard[0].checked_ap.connect(evidence.analysis_export);
    endfunction
    task run_phase(uvm_phase phase);
        keccak_directed_seq directed_seq;
        keccak_boundary_seq boundary_seq;
        keccak_protocol_stress_seq protocol_seq;
        keccak_config_latch_seq config_seq;
        keccak_continuous_stop_seq stop_seq;
        keccak_stress_seq random_seq;
        phase.raise_objection(this);
        directed_seq = keccak_directed_seq::type_id::create("directed_seq");
        boundary_seq = keccak_boundary_seq::type_id::create("boundary_seq");
        protocol_seq = keccak_protocol_stress_seq::type_id::create("protocol_seq");
        config_seq = keccak_config_latch_seq::type_id::create("config_seq");
        stop_seq = keccak_continuous_stop_seq::type_id::create("stop_seq");
        random_seq = keccak_stress_seq::type_id::create("random_seq");
        random_seq.num_items = 8;
        directed_seq.start(env.agent[0].sequencer);
        boundary_seq.start(env.agent[0].sequencer);
        protocol_seq.start(env.agent[0].sequencer);
        config_seq.start(env.agent[0].sequencer);
        stop_seq.start(env.agent[0].sequencer);
        random_seq.start(env.agent[0].sequencer);
        #200;
        phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (evidence.count != 125 || env.scoreboard[0].failed_tests != 0 ||
            env.scoreboard[0].total_tests != 125 ||
            !env.scoreboard[0].exp_fifo.is_empty() ||
            !env.scoreboard[0].obs_fifo.is_empty())
            `uvm_error("STAGE2", "Incomplete or failed 125-transaction suite")
        else
            `uvm_info("STAGE2", "STAGE2_SUITE_COMPLETE 125 checked transactions", UVM_NONE)
    endfunction
endclass
