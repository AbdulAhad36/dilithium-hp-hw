// =========================================================================
// keccak_coverage.sv  -  TB v2 functional coverage
// Subscribes to driver's analysis port (expected tx) and samples per-test.
// =========================================================================
class keccak_coverage extends uvm_subscriber #(keccak_transaction);
    `uvm_component_utils(keccak_coverage)

    keccak_transaction tx_sampled;

    covergroup cg_keccak;
        cp_mode : coverpoint tx_sampled.mode {
            bins shake128 = {SHAKE128};
            bins shake256 = {SHAKE256};
            bins sha3_256 = {SHA3_256};
            bins sha3_512 = {SHA3_512};
        }
        // One bin per range (no `[]` expansion) so the cg reports 100% when
        // every range is exercised at least once.
        cp_xof_kind : coverpoint tx_sampled.xof_len_val {
            bins continuous     = {0};
            bins bounded_small  = {[1:32]};
            bins bounded_medium = {[33:168]};
            bins bounded_large  = {[169:65535]};
        }
        cp_msg_len : coverpoint (tx_sampled.msg_hex.len() / 2) {
            bins empty       = {0};
            bins short_msg   = {[1:71]};
            bins around_576  = {[72:135]};
            bins around_1088 = {[136:167]};
            bins around_1344 = {[168:271]};
            bins multi_block = {[272:$]};
        }
        // Cross modes against msg_len. For xof_kind we limit the cross to
        // SHAKE modes only (SHA3-256/512 always have xof_len_val==0), so the
        // cross's "continuous" bin for SHA3 modes isn't a real coverage gap.
        cross_mode_msg : cross cp_mode, cp_msg_len;
        cross_shake_xof : cross cp_mode, cp_xof_kind {
            ignore_bins sha3_modes = binsof(cp_mode) intersect {SHA3_256, SHA3_512}
                                   && binsof(cp_xof_kind) intersect {[1:65535]};
        }
    endgroup

    function new(string name = "keccak_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_keccak = new();
    endfunction

    function void write(keccak_transaction t);
        tx_sampled = t;
        cg_keccak.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
                  $sformatf("Functional Coverage: %0.2f%%", cg_keccak.get_coverage()),
                  UVM_NONE)
    endfunction

endclass
