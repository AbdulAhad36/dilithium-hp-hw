// =========================================================================
// Keccak Agent - Container for Driver, Monitor, and Sequencer
// =========================================================================
class keccak_agent extends uvm_agent;
    `uvm_component_utils(keccak_agent)

    keccak_driver               driver;
    keccak_monitor              monitor;
    uvm_sequencer #(keccak_transaction) sequencer;

    bit is_active = 1;

    function new(string name = "keccak_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = keccak_monitor::type_id::create("monitor", this);
        if (is_active) begin
            sequencer = uvm_sequencer#(keccak_transaction)::type_id::create("sequencer", this);
            driver = keccak_driver::type_id::create("driver", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (is_active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass