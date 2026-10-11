# Run from sim/. Compile local vendor primitives once, including encrypted atoms.
if {![info exists QUARTUS_SIMLIB]} {set QUARTUS_SIMLIB F:/altera/quartus/eda/sim_lib}
set vendor_root ntt_LightHD/vendor_libs
file mkdir $vendor_root
set vendor_pairs [list altera_ver altera_primitives.v lpm_ver 220model.v sgate_ver sgate.v altera_mf_ver altera_mf.v altera_lnsim_ver altera_lnsim.sv cyclonev_ver cyclonev_atoms.v]
foreach {lib source_file} $vendor_pairs {
    set lib_dir $vendor_root/$lib
    if {![file exists $lib_dir]} {vlib $lib_dir}
    vmap $lib $lib_dir
    if {![file exists $lib_dir/compiled.ok]} {
        if {[file extension $source_file] eq ".sv"} {
            vlog -sv -work $lib $QUARTUS_SIMLIB/$source_file
        } else {vlog -work $lib $QUARTUS_SIMLIB/$source_file}
        if {$lib eq "cyclonev_ver"} {vlog -work $lib $QUARTUS_SIMLIB/mentor/cyclonev_atoms_ncrypt.v}
        set marker [open $lib_dir/compiled.ok w]
        puts $marker "Questa primitives compiled from $QUARTUS_SIMLIB"
        close $marker
    }
}
unset vendor_root vendor_pairs lib source_file lib_dir
