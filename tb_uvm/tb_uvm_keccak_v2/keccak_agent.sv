// =========================================================================
// keccak_agent.sv  -  TB v2 agent (sequencer + driver + monitor)
// Owns the driver/monitor handshake event (collection_done).
// =========================================================================
class keccak_sequencer extends uvm_sequencer #(keccak_transaction);
    `uvm_component_utils(keccak_sequencer)
    function new(string name = "keccak_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class keccak_agent extends uvm_agent;
    `uvm_component_utils(keccak_agent)

    keccak_sequencer    sequencer;
    keccak_driver       driver;
    keccak_monitor      monitor;

    // Shared event so driver waits for monitor to finish collection before
    // it issues the next reset.
    uvm_event           collection_done;

    function new(string name = "keccak_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer       = keccak_sequencer::type_id::create("sequencer", this);
        driver          = keccak_driver  ::type_id::create("driver",    this);
        monitor         = keccak_monitor ::type_id::create("monitor",   this);
        collection_done = new("collection_done");
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);

        // Driver publishes expected tx → monitor's FIFO
        driver.drv_ap.connect(monitor.exp_fifo.analysis_export);

        // Wire shared event
        driver.collection_done  = collection_done;
        monitor.collection_done = collection_done;
    endfunction

endclass
