# Compile the Quartus Cyclone V Verilog primitives used by generated netlists.
# Call after script_dir has been set by a post-synthesis/post-fit run script.
if {[info exists ::env(QUARTUS_ROOTDIR)]} {
    set quartus_root [file normalize $::env(QUARTUS_ROOTDIR)]
} else {
    set quartus_root F:/altera/quartus
}
set sim_lib [file join $quartus_root eda sim_lib]
set sim_tag default
if {[info exists ::env(KECCAK_SIM_LIB_TAG)]} {
    set sim_tag $::env(KECCAK_SIM_LIB_TAG)
}
set lib_root [file join $script_dir cyclonev_sim_libs_$sim_tag]
file mkdir $lib_root

foreach {lib source} {
    altera_ver    altera_primitives.v
    lpm_ver       220model.v
    sgate_ver     sgate.v
    altera_mf_ver altera_mf.v
    cyclonev_ver  cyclonev_atoms.v
} {
    set lib_dir [file join $lib_root $lib]
    if {![file exists [file join $lib_dir _info]]} {
        vlib $lib_dir
        vlog -work $lib_dir [file join $sim_lib $source]
    }
    vmap $lib $lib_dir
}

set cyclonev_ncrypt [file join $sim_lib mentor cyclonev_atoms_ncrypt.v]
set cyclonev_marker [file join $lib_root cyclonev_ncrypt_compiled]
if {![file exists $cyclonev_marker]} {
    vlog -work [file join $lib_root cyclonev_ver] $cyclonev_ncrypt
    close [open $cyclonev_marker w]
}
