// =========================================================================
// Keccak Coverage Collector
// =========================================================================
import keccak_pkg::*;

class keccak_coverage extends uvm_subscriber #(keccak_transaction);
    `uvm_component_utils(keccak_coverage)

    keccak_mode mode;
    int msg_len;
    int output_len_bits;
    int rate_bytes;

    // Covergroups
    covergroup mode_cg;
        option.per_instance = 1;
        mode_cp: coverpoint mode;
    endgroup

    covergroup msg_len_cg;
        option.per_instance = 1;
        msg_len_cp: coverpoint msg_len {
            bins zero = {0};
            bins small_bin = {[1:136]};
            bins medium_bin = {[137:1024]};
            bins large_bin = {[1025:8192]};
        }
    endgroup

    covergroup output_len_cg;
        option.per_instance = 1;
        output_len_cp: coverpoint output_len_bits {
            bins bits_128 = {128};
            bins bits_224 = {224};
            bins bits_256 = {256};
            bins bits_384 = {384};
            bins bits_512 = {512};
            bins other = {[1:8192]};
        }
    endgroup

    covergroup rate_cross_cg;
        option.per_instance = 1;
        mode_x_rate: cross mode, rate_bytes;
    endgroup


    function new(string name = "keccak_coverage", uvm_component parent = null);
        super.new(name, parent);
        mode_cg = new();
        msg_len_cg = new();
        output_len_cg = new();
        rate_cross_cg = new();
    endfunction

    virtual function void write(keccak_transaction tx);
        mode = tx.mode;
        msg_len = tx.msg_bytes.size();
        output_len_bits = tx.output_len_bits;
        rate_bytes = tx.get_rate_bytes();
        
        mode_cg.sample();
        msg_len_cg.sample();
        output_len_cg.sample();
        rate_cross_cg.sample();
        
        `uvm_info(get_type_name(), "Coverage sampled", UVM_HIGH)
    endfunction

endclass