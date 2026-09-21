# =========================================================================
# run.do - Unified Keccak compile, simulation, coverage and waveform
#
# GUI:      vsim -do run.do
# Headless: vsim -c -do "do run.do; quit -f"
#
# This script opens one simulation session and leaves it loaded in GUI mode.
# =========================================================================

onerror {quit -code 1 -f}

set launch_dir [file normalize [pwd]]
if {[file exists [file join $launch_dir run.do]]} {
    set script_dir $launch_dir
} elseif {[file exists [file join $launch_dir sim run.do]]} {
    set script_dir [file join $launch_dir sim]
} else {
    error "Run from the repository root or its sim directory"
}
set repo [file normalize [file join $script_dir ..]]
set rtl [file join $repo src keccak_engine]
set tb [file join $repo tb_uvm tb_uvm_keccak_v2]
set worklib [file join $script_dir work]

# 1. Clean and recreate the work library.
catch {quit -sim}
if {[file isdirectory $worklib]} {
    vdel -lib $worklib -all
}
vlib $worklib
vmap work $worklib

# 2. Compile the active dual-core RTL with structural coverage enabled.
foreach source {
    keccak_pkg.sv
    keccak_param_unit.sv
    keccak_absorb_unit.sv
    theta_step.sv
    rho_step.sv
    pi_step.sv
    chi_step.sv
    iota_step.sv
    keccak_step_unit.sv
    keccak_output_unit.sv
    keccak_core.sv
    keccak_dual_interleaved.sv
} {
    vlog -work work -sv -cover bcesft [file join $rtl $source]
}

# 3. Compile the UVM core regression and all dual tests from one top file.
vlog -work work -sv +incdir+$tb [file join $tb keccak_ref_pkg.sv]
vlog -work work -sv +incdir+$tb [file join $tb keccak_if.sv]
vlog -work work -sv +incdir+$tb [file join $tb keccak_assertions.sv]
vlog -work work -sv +incdir+$tb [file join $tb tb_top.sv]

# 4. Elaborate once with coverage and full debug visibility.
vsim -coverage -voptargs=+acc work.tb_top
coverage save -onexit [file join $script_dir keccak_dual_coverage.ucdb]
onfinish stop

# 5. Restore the old GUI experience.
if {[batch_mode] == 0} {
    view transcript
    view wave
    view structure
    view signals
}
log -r /*

if {[batch_mode] == 0} {
    add wave -divider "Clock and Reset"
    add wave -radix binary /tb_top/u_uvm_core/clk
    add wave -radix binary /tb_top/u_uvm_core/rst

    add wave -divider "Request"
    add wave -radix binary   /tb_top/u_uvm_core/request_valid
    add wave -radix binary   /tb_top/u_uvm_core/request_ready
    add wave -radix unsigned /tb_top/u_uvm_core/request_core
    add wave -radix unsigned /tb_top/u_uvm_core/mode
    add wave -radix unsigned /tb_top/u_uvm_core/message_len
    add wave -radix unsigned /tb_top/u_uvm_core/output_len

    add wave -divider "Shared Input"
    add wave -radix hex      /tb_top/u_uvm_core/input_data
    add wave -radix binary   /tb_top/u_uvm_core/input_valid
    add wave -radix binary   /tb_top/u_uvm_core/input_ready
    add wave -radix unsigned /tb_top/u_uvm_core/input_core

    add wave -divider "Core Status"
    add wave -radix binary /tb_top/u_uvm_core/core_busy
    add wave -radix binary /tb_top/u_uvm_core/core_done
    add wave -radix binary /tb_top/u_uvm_core/busy
    add wave -radix binary /tb_top/u_uvm_core/dual_dut/core_start
    add wave -radix binary /tb_top/u_uvm_core/dual_dut/core_output_valid

    add wave -divider "Interleaved Output"
    add wave -radix hex      /tb_top/u_uvm_core/output_data
    add wave -radix binary   /tb_top/u_uvm_core/output_valid
    add wave -radix unsigned /tb_top/u_uvm_core/output_bytes
    add wave -radix unsigned /tb_top/u_uvm_core/output_core
    add wave -radix binary   /tb_top/u_uvm_core/output_ready

    add wave -divider "Scheduler and Arbiter"
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/dispatch_preference
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/dispatch_core
    add wave -radix binary   /tb_top/u_uvm_core/dual_dut/ingress_active
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/ingress_core
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/offset_count
    add wave -radix binary   /tb_top/u_uvm_core/dual_dut/arbiter_locked
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/arbiter_turn

    add wave -divider "Core 0"
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/g_core[0]/u_core/state
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/g_core[0]/u_core/round_idx

    add wave -divider "Core 1"
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/g_core[1]/u_core/state
    add wave -radix unsigned /tb_top/u_uvm_core/dual_dut/g_core[1]/u_core/round_idx

    add wave -divider "Two-Core UVM Regression"
    add wave -radix binary /tb_top/uvm_core_done
    add wave -radix binary /tb_top/u_uvm_core/clk
    add wave -radix binary /tb_top/u_uvm_core/g_lane[0]/u_core/busy_o
    add wave -radix binary /tb_top/u_uvm_core/g_lane[1]/u_core/busy_o
}

# 6. Run once and keep the completed design loaded for inspection.
run -all
coverage report -summary
if {[batch_mode] == 0} {
    wave zoom full
}
