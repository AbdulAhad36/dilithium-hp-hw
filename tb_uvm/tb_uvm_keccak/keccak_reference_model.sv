// =========================================================================
// Keccak Reference Model - Software implementation of Keccak
// =========================================================================
class keccak_reference_model extends uvm_component;
    `uvm_component_utils(keccak_reference_model)

    uvm_analysis_port #(keccak_transaction) ref_ap;

    // Internal state (simplified - in real implementation, use proper Keccak)
    logic [1600-1:0] state;
    
    function new(string name = "keccak_reference_model", uvm_component parent = null);
        super.new(name, parent);
        ref_ap = new("ref_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // The reference model can be driven by sequences
        // For now, it will be called directly from tests
    endtask

    // Calculate expected hash for a transaction
    virtual function void calculate_expected(keccak_transaction tx);
        // This would implement the actual Keccak algorithm in software
        // For the testbench, you can use the expected values from NIST vectors
        // Or implement a pure SystemVerilog Keccak reference model
        
        // Placeholder - actual implementation needed
        `uvm_info(get_type_name(), $sformatf("Calculating expected for %s", 
                   tx.convert2string()), UVM_HIGH)
        
        // Send to scoreboard
        ref_ap.write(tx);
    endfunction

endclass