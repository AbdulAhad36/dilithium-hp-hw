// ============================================================================
// ntt_agent.sv  --  UVM agent (sequencer + driver + monitor)
// ----------------------------------------------------------------------------
// Owns the shared collection_done event so the driver waits for the monitor to
// finish collecting a transform's output before it issues the next per-tx
// reset.
// ============================================================================
class ntt_sequencer extends uvm_sequencer #(ntt_transaction);
    `uvm_component_utils(ntt_sequencer)
    function new(string name = "ntt_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class ntt_agent extends uvm_agent;
    `uvm_component_utils(ntt_agent)

    ntt_sequencer sequencer;
    ntt_driver    driver;
    ntt_monitor   monitor;
    uvm_event     collection_done;

    function new(string name = "ntt_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer       = ntt_sequencer::type_id::create("sequencer", this);
        driver          = ntt_driver   ::type_id::create("driver",    this);
        monitor         = ntt_monitor  ::type_id::create("monitor",   this);
        collection_done = new("collection_done");
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
        // driver publishes the expected tx into the monitor's FIFO
        driver.drv_ap.connect(monitor.exp_fifo.analysis_export);
        // shared driver <-> monitor handshake event
        driver.collection_done  = collection_done;
        monitor.collection_done = collection_done;
    endfunction

endclass
