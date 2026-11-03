# Current production capture; main UVM uses run_uvm.do.
# From repository root: do sim/dilithium/run.do
# Optional DILITHIUM_TEST: main, main_diagnostic, main_protocol,
# keygen, keygen_protocol, sign, sign_diagnostic, sign_protocol.
if {![info exists DILITHIUM_TEST]} {set DILITHIUM_TEST main}
# Accept old selector spelling; Stage2-5 architectures are retired.
regsub {^lighthd_} $DILITHIUM_TEST {} DILITHIUM_TEST
if {$DILITHIUM_TEST ni {main main_diagnostic main_protocol keygen keygen_protocol sign sign_diagnostic sign_protocol}} {error "Unknown current-design test selector"}
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
set launch [file normalize [pwd]]
if {[file exists [file join $launch stage2_inputs.txt]]} {
    set here $launch
} elseif {[file exists [file join $launch dilithium run.do]]} {
    set here [file join $launch dilithium]
} else {
    set here [file join $launch sim dilithium]
}
set repo [file normalize [file join $here .. ..]]
source [file join $here setup_cyclonev.tcl]
if {1} {
    # The compact reconstruction has its own library; no legacy allocator or
    # private helper engines are compiled into these focused operation benches.
    if {[string match main* $DILITHIUM_TEST]} {
        set prepare_command lighthd_main_prepare;set compare_command lighthd_main_compare
        set top tb_main;set generics {-gDIAGNOSTIC=0};set expected_commands 210
        set capture_name stage7c4_main_outputs.txt;set expected_footer {F 210}
        if {$DILITHIUM_TEST eq "main_diagnostic"} {
            set generics {-gDIAGNOSTIC=1};set expected_commands 9;set compare_command lighthd_main_diagnostic_compare
            set capture_name stage7c4_main_diagnostic_outputs.txt;set expected_footer {F 9}
        } elseif {$DILITHIUM_TEST eq "main_protocol"} {
            set generics {-gDIAGNOSTIC=0 -gPROTOCOL=1};set expected_commands 88;set compare_command lighthd_main_protocol_compare
            set capture_name stage7c4_main_protocol_outputs.txt;set expected_footer {F 88}
        }
    } elseif {[string match keygen* $DILITHIUM_TEST]} {
        set prepare_command lighthd_keygen_prepare
        set compare_command lighthd_keygen_compare
        set top tb_keygen
        set expected_commands 75
        set capture_name stage7c2_keygen_outputs.txt
        set expected_footer {F 75}
        set generics {-gDIAGNOSTIC=0}
        if {$DILITHIUM_TEST eq "keygen_protocol"} {
            set generics {-gPROTOCOL=1};set expected_commands 20;set compare_command lighthd_keygen_protocol_compare
            set capture_name stage7c2_keygen_protocol_outputs.txt;set expected_footer {F 20}
        }
    } else {
        set prepare_command lighthd_sign_prepare
        set compare_command lighthd_sign_compare
        set top tb_sign
        set generics {-gDIAGNOSTIC=0};set expected_commands 90
        set capture_name stage7c3_sign_outputs.txt;set expected_footer {F 90}
        if {$DILITHIUM_TEST eq "sign_diagnostic"} {
            set generics {-gDIAGNOSTIC=1};set expected_commands 3;set compare_command lighthd_sign_diagnostic_compare
            set capture_name stage7c3_sign_diagnostic_outputs.txt;set expected_footer {F 3}
        } elseif {$DILITHIUM_TEST eq "sign_protocol"} {
            set top tb_sign_protocol;set generics {};set expected_commands 69;set compare_command lighthd_sign_protocol_compare
            set capture_name stage7c3_sign_protocol_outputs.txt;set expected_footer {F 69 12 24 33}
        }
    }
    if {[catch {exec python [file join $here dilithium_vectors.py] $prepare_command} prepared]} {error $prepared}
    echo $prepared
    set compact_work [file join $here work_lighthd_public]
    if {![file exists $compact_work]} {vlib $compact_work}
    vmap dilithium_lighthd_work $compact_work
    set settings_handle [open [file join $repo quartus dilithium dilithium_full.qsf] r]
    set settings [read $settings_handle];close $settings_handle
    foreach line [split $settings "\n"] {
        if {[regexp {SYSTEMVERILOG_FILE\s+(.+)$} [string trim $line] -> source]} {
            vlog -sv -work dilithium_lighthd_work [file normalize [file join $repo quartus dilithium $source]]
        }
    }
    vlog -sv -work dilithium_lighthd_work [file join $repo tb tb_dilithium ${top}.sv]
    set access_args {};if {![batch_mode]} {set access_args {-voptargs=+acc}}
    cd $repo
    vsim -L cyclonev_ver {*}$access_args {*}$generics -wlf [file join $here stage7c_${DILITHIUM_TEST}.wlf] dilithium_lighthd_work.$top
    onfinish stop
    if {![batch_mode]} {
        view transcript;view wave
        add wave /$top/clk /$top/rst /$top/start_* /$top/done_* /$top/fault_o
        add wave -divider {Fixed bank schedule and shared engines}
        if {[string match main* $DILITHIUM_TEST]} {
            add wave /$top/dut/core/state /$top/dut/core/op_r /$top/dut/core/request /$top/dut/core/response
            add wave /$top/dut/core/datapath/memory/router/owner_r
            add wave /$top/dut/core/datapath/polynomial/state /$top/dut/core/datapath/process_path/state
            add wave /$top/sign_input_* /$top/verify_input_* /$top/key_* /$top/signature_* /$top/sign_attempts_o /$top/sign_rejections_o
            log /$top/* /$top/dut/core/state /$top/dut/core/datapath/memory/router/owner_r
        } else {
            add wave /$top/controller/state /$top/controller/producer /$top/service_o /$top/service_i
            add wave /$top/datapath/polynomial/state /$top/datapath/process_path/state
            if {[string match keygen* $DILITHIUM_TEST]} {add wave /$top/key_*} else {add wave /$top/input_* /$top/signature_* /$top/attempts_o /$top/rejections_o /$top/next_nonce_o}
            log /$top/* /$top/controller/state /$top/controller/producer
        }
    }
    run -all
    # Each bench writes this footer only AFTER every assertion/completion gate.
    # Querying an optimized-away procedural counter would require broad +acc.
    set capture_handle [open [file join $here $capture_name] r]
    set capture_text [read $capture_handle];close $capture_handle
    set capture_footer [string trim [lindex [split [string trim $capture_text] \n] end]]
    if {$capture_footer ne $expected_footer} {error "Compact operation did not reach its full completion gate"}
    if {![batch_mode]} {wave zoom full}
    # Keep the root as cwd while the design is loaded, so GUI waves remain
    # available. Questa forbids changing directory with an active simulation.
    echo "CAPTURE COMPLETE. Independent comparison: python sim/dilithium/dilithium_vectors.py $compare_command"
    return
}
