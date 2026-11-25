# Current production capture; main UVM uses run_uvm.do.
# From repository root: do sim/dilithium/run.do
# Select DILITHIUM_TEST: all (default), keygen, sign or verify.
# DILITHIUM_OPERATION also selects operations when using main/main_diagnostic.
# DILITHIUM_TEST main_diagnostic/main_protocol and legacy focused diagnostics remain available.
if {![info exists DILITHIUM_TEST]} {set DILITHIUM_TEST main}
# Accept old selector spelling; Stage2-5 architectures are retired.
regsub {^lighthd_} $DILITHIUM_TEST {} DILITHIUM_TEST
# Simple operation selectors all use the full production top and main testbench.
if {$DILITHIUM_TEST in {all keygen sign verify}} {
    set DILITHIUM_OPERATION $DILITHIUM_TEST
    set DILITHIUM_TEST main
}
if {![info exists DILITHIUM_OPERATION]} {set DILITHIUM_OPERATION all}
if {$DILITHIUM_OPERATION ni {all keygen sign verify}} {error "Choose DILITHIUM_OPERATION all, keygen, sign or verify"}
if {$DILITHIUM_TEST ni {main main_diagnostic main_protocol keygen keygen_protocol sign sign_diagnostic sign_protocol}} {error "Unknown current-design test selector"}
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
set launch [file normalize [pwd]]
if {[file exists [file join $launch run.do]] && [file exists [file join $launch dilithium_vectors.py]]} {
    set here $launch
} elseif {[file exists [file join $launch dilithium run.do]]} {
    set here [file join $launch dilithium]
} else {
    set here [file join $launch sim dilithium]
}
set repo [file normalize [file join $here .. ..]]
if {![info exists DILITHIUM_FAST]} {set DILITHIUM_FAST [batch_mode]}
if {$DILITHIUM_FAST ni {0 1}} {error "DILITHIUM_FAST must be 0 or 1"}
set data_dir $here
if {[info exists DILITHIUM_DATA_DIR]} {set data_dir [file normalize $DILITHIUM_DATA_DIR]}
if {$data_dir ne $here && ![string match main* $DILITHIUM_TEST]} {error "Alternate capture directory requires the main bench"}
set launch_started [clock milliseconds]
set simulator_tag [file tail [file dirname [file dirname [info nameofexecutable]]]]
regsub -all {[^a-zA-Z0-9_]} $simulator_tag _ simulator_tag
set compact_work [file join $here work_main_$simulator_tag]
if {[info exists DILITHIUM_WORK_DIR]} {set compact_work [file normalize $DILITHIUM_WORK_DIR]}
set work_alias dilithium_main_work
if {[info exists DILITHIUM_LIBRARY]} {set work_alias $DILITHIUM_LIBRARY}
if {![file exists [file join $compact_work _info]]} {vlib $compact_work}
vmap $work_alias $compact_work

source [file join $here setup_cyclonev.tcl]
if {1} {
    # The compact reconstruction has its own library; no legacy allocator or
    # private helper engines are compiled into these focused operation benches.
    if {[string match main* $DILITHIUM_TEST]} {
        set prepare_command main_prepare;set compare_command main_compare
        set top tb_main;set generics {-gDIAGNOSTIC=0};set expected_commands 210
        set capture_name main_outputs.txt;set expected_footer {F 210}
        if {$DILITHIUM_TEST eq "main_diagnostic"} {
            set generics {-gDIAGNOSTIC=1};set expected_commands 9;set compare_command main_diagnostic_compare
            set capture_name main_diagnostic_outputs.txt;set expected_footer {F 9}
        } elseif {$DILITHIUM_TEST eq "main_protocol"} {
            set generics {-gDIAGNOSTIC=0 -gPROTOCOL=1};set expected_commands 88;set compare_command main_protocol_compare
            set capture_name main_protocol_outputs.txt;set expected_footer {F 88}
        }
    } elseif {[string match keygen* $DILITHIUM_TEST]} {
        set prepare_command keygen_prepare
        set compare_command keygen_compare
        set top tb_keygen
        set expected_commands 75
        set capture_name keygen_outputs.txt
        set expected_footer {F 75}
        set generics {-gDIAGNOSTIC=0}
        if {$DILITHIUM_TEST eq "keygen_protocol"} {
            set generics {-gPROTOCOL=1};set expected_commands 20;set compare_command keygen_protocol_compare
            set capture_name keygen_protocol_outputs.txt;set expected_footer {F 20}
        }
    } else {
        set prepare_command sign_prepare
        set compare_command sign_compare
        set top tb_sign
        set generics {-gDIAGNOSTIC=0};set expected_commands 90
        set capture_name sign_outputs.txt;set expected_footer {F 90}
        if {$DILITHIUM_TEST eq "sign_diagnostic"} {
            set generics {-gDIAGNOSTIC=1};set expected_commands 3;set compare_command sign_diagnostic_compare
            set capture_name sign_diagnostic_outputs.txt;set expected_footer {F 3}
        } elseif {$DILITHIUM_TEST eq "sign_protocol"} {
            set top tb_sign_protocol;set generics {};set expected_commands 69;set compare_command sign_protocol_compare
            set capture_name sign_protocol_outputs.txt;set expected_footer {F 69 12 24 33}
        }
    }
    set prepare_args {};set compare_args {}
    if {$DILITHIUM_TEST in {main main_diagnostic}} {
        set prepare_args [list --operation $DILITHIUM_OPERATION --output-dir $data_dir --cache-dir $compact_work]
        set compare_args " --operation $DILITHIUM_OPERATION"
        if {$data_dir ne $here} {append compare_args [format { --output-dir "%s"} $data_dir]}
    }
    if {[catch {exec python [file join $here dilithium_vectors.py] $prepare_command {*}$prepare_args} prepared]} {error $prepared}
    if {$DILITHIUM_TEST in {main main_diagnostic}} {
        set selected_input [expr {$DILITHIUM_TEST eq "main" ? "main_inputs.txt" : "main_diagnostic_inputs.txt"}]
        set selected_handle [open [file join $data_dir $selected_input] r]
        gets $selected_handle selected_header;close $selected_handle
        set expected_commands [lindex $selected_header 1]
        set expected_footer "F $expected_commands"
        echo "Operation selection: $DILITHIUM_OPERATION; $expected_commands cases"
    }
    echo $prepared
    set settings_handle [open [file join $repo quartus dilithium dilithium_full.qsf] r]
    set settings [read $settings_handle];close $settings_handle
    set sources {}
    foreach line [split $settings "\n"] {
        if {[regexp {SYSTEMVERILOG_FILE\s+(.+)$} [string trim $line] -> source]} {
            lappend sources [file normalize [file join $repo quartus dilithium $source]]
        }
    }
    lappend sources [file join $repo tb tb_dilithium ${top}.sv]
    # Content-sensitive compilation cache. Includes force rebuilding until their
    # dependency search is explicitly supported,so changed headers cannot go stale.
    set compile_identity [list sfcu_cache_v1 [info nameofexecutable] $work_alias $sources]
    set has_includes 0
    foreach source $sources {
        set source_handle [open $source rb];set source_bytes [read $source_handle];close $source_handle
        lappend compile_identity [file size $source] [zlib crc32 $source_bytes]
        if {[regexp {`include\s} $source_bytes]} {set has_includes 1}
    }
    set compile_stamp [file join $compact_work main_compile.stamp]
    set compile_needed 1
    if {![info exists DILITHIUM_REBUILD]} {set DILITHIUM_REBUILD 0}
    if {!$DILITHIUM_REBUILD && !$has_includes && [file exists $compile_stamp]} {
        set stamp_handle [open $compile_stamp r];set old_identity [read $stamp_handle];close $stamp_handle
        if {$old_identity eq $compile_identity} {set compile_needed 0}
    }
    if {$compile_needed} {
        # Preserve the original separate-compilation-unit semantics in one call.
        if {[file exists $compile_stamp]} {file delete $compile_stamp}
        vlog -sv -sfcu -work $work_alias {*}$sources
        set stamp_handle [open $compile_stamp w];puts -nonewline $stamp_handle $compile_identity;close $stamp_handle
        echo "RTL compilation refreshed"
    } else {echo "RTL compile cache hit:all compiled source contents unchanged"}
    set access_args {};if {!$DILITHIUM_FAST} {set access_args {-voptargs=+acc}}
    set capture_args {}
    if {[string match main* $DILITHIUM_TEST]} {set capture_args [list +DILITHIUM_DATA_DIR=$data_dir]}
    if {$DILITHIUM_FAST} {echo "FAST mode:no broad debug access or waveform logging;all RTL checks/cases retained"}
    cd $repo
    vsim -L cyclonev_ver {*}$access_args {*}$generics -wlf [file join $data_dir ${DILITHIUM_TEST}.wlf] $work_alias.$top {*}$capture_args
    if {$DILITHIUM_FAST} {
        catch {nolog -all}
        if {![batch_mode]} {catch {delete wave *}}
    }
    onfinish stop
    if {![batch_mode] && !$DILITHIUM_FAST} {
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
    set simulation_started [clock milliseconds]
    run -all
    set simulation_elapsed [expr {([clock milliseconds]-$simulation_started)/1000.0}]
    # Each bench writes this footer only AFTER every assertion/completion gate.
    # Querying an optimized-away procedural counter would require broad +acc.
    set capture_handle [open [file join $data_dir $capture_name] r]
    set capture_text [read $capture_handle];close $capture_handle
    set capture_footer [string trim [lindex [split [string trim $capture_text] \n] end]]
    if {$capture_footer ne $expected_footer} {error "Compact operation did not reach its full completion gate"}
    if {![batch_mode] && !$DILITHIUM_FAST} {wave zoom full}
    # Keep the root as cwd while the design is loaded, so GUI waves remain
    # available. Questa forbids changing directory with an active simulation.
    if {![string match *_protocol $DILITHIUM_TEST]} {
        echo "Plain RTL output written DIRECTLY by the testbench: [file join $data_dir outputs_hw.txt]"
    }
    echo "CAPTURE COMPLETE. Independent comparison: python sim/dilithium/dilithium_vectors.py $compare_command$compare_args"
    echo "SIMULATION_WALL_SECONDS:$simulation_elapsed TOTAL_WALL_SECONDS:[expr {([clock milliseconds]-$launch_started)/1000.0}] FAST:$DILITHIUM_FAST"
    return
}
