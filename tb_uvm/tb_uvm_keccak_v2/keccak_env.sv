// =========================================================================
// keccak_env.sv  -  Multi-lane UVM environment
//
// Hosts N_LANES independent (agent + scoreboard + coverage) bundles, one
// per lane of keccak_engine_parallel. Lanes are completely independent: no
// cross-lane arbitration or shared state - the parallel wrapper exposes
// per-lane AXI ports and we verify each one separately and concurrently.
//
// Per-agent virtual interfaces are pulled from the config_db at paths
//   uvm_test_top.env.agent_<i>.*
// which tb_top sets up.
//
// N_LANES: set to 4 to match tb_top.sv. To run with a different lane count,
// edit both this localparam and the N_LANES in tb_top.sv.
// =========================================================================
class keccak_env extends uvm_env;
    `uvm_component_utils(keccak_env)

    localparam int N_LANES = 4;

    keccak_agent       agent      [N_LANES];
    keccak_scoreboard  scoreboard [N_LANES];
    keccak_coverage    coverage   [N_LANES];

    function new(string name = "keccak_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        for (int i = 0; i < N_LANES; i++) begin
            uvm_config_db#(int)::set(this, $sformatf("coverage_%0d", i),
                                    "lane_id", i);
            agent[i]      = keccak_agent     ::type_id::create($sformatf("agent_%0d",      i), this);
            scoreboard[i] = keccak_scoreboard::type_id::create($sformatf("scoreboard_%0d", i), this);
            coverage[i]   = keccak_coverage  ::type_id::create($sformatf("coverage_%0d",   i), this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        for (int i = 0; i < N_LANES; i++) begin
            agent[i].driver.drv_ap.connect(scoreboard[i].exp_fifo.analysis_export);
            agent[i].monitor.mon_ap.connect(scoreboard[i].obs_fifo.analysis_export);
            scoreboard[i].checked_ap.connect(coverage[i].analysis_export);
        end
    endfunction

endclass
