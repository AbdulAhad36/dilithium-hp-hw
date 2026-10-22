# Run from sim/ after: python nist_shake.py prepare
# Runs only the standalone UVM cores and captures DUT outputs quickly.
# Run python nist_shake.py compare afterward.
set ::keccak_nist_mode 1
set launch_dir [file normalize [pwd]]
if {[file exists [file join $launch_dir run.do]]} {
    set nist_script_dir $launch_dir
} elseif {[file exists [file join $launch_dir keccak run.do]]} {
    set nist_script_dir [file join $launch_dir keccak]
} else {
    set nist_script_dir [file join $launch_dir sim keccak]
}
do [file join $nist_script_dir run.do]
vmap work [file join $script_dir work]
unset ::keccak_nist_mode
