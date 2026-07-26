// =========================================================================
// keccak_coverage.sv  -  TB v2 functional coverage (SHAKE-only)
// Samples monitor-observed transactions only after the scoreboard passes them.
// =========================================================================
class keccak_coverage extends uvm_subscriber #(keccak_transaction);
    `uvm_component_utils(keccak_coverage)

    keccak_transaction tx_sampled;

    covergroup cg_keccak;
        cp_mode : coverpoint tx_sampled.mode {
            bins shake128 = {SHAKE128};
            bins shake256 = {SHAKE256};
        }
        // One bin per range (no `[]` expansion) so the cg reports 100% when
        // every range is exercised at least once.
        cp_xof_kind : coverpoint tx_sampled.xof_len_val {
            bins continuous     = {0};
            bins bounded_small  = {[1:32]};
            bins bounded_medium = {[33:168]};
            bins bounded_large  = {[169:65535]};
        }
        cp_msg_len : coverpoint (tx_sampled.obs_msg_hex.len() / 2) {
            bins empty       = {0};
            bins short_msg   = {[1:71]};
            bins around_576  = {[72:135]};
            bins around_1088 = {[136:167]};
            bins around_1344 = {[168:271]};
            bins multi_block = {[272:$]};
        }
        // Cross modes against msg_len and xof_kind. SHAKE-only design, so
        // no ignore_bins are needed.
        cross_mode_msg  : cross cp_mode, cp_msg_len;
        cross_shake_xof : cross cp_mode, cp_xof_kind;
    endgroup

    function new(string name = "keccak_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_keccak = new();
    endfunction

    function void write(keccak_transaction t);
        if (!t.passed || !t.protocol_ok || !t.data_ok) begin
            `uvm_error(get_type_name(),
                       $sformatf("Coverage rejected unchecked transaction %s", t.test_name))
            return;
        end
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
