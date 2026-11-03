# Native DSP RTL needs the official Cyclone V functional primitive models.
# Source from Questa with `here` set to sim/dilithium. Compile once per vendor
# source identity;never write into an installed/precompiled vendor library.
if {![info exists here]} {error "Set here to the Dilithium simulation directory"}
if {[info exists ::env(QUARTUS_ROOTDIR)]} {
  set cv_root [file normalize $::env(QUARTUS_ROOTDIR)]
} else {set cv_root F:/altera/quartus}
set cv_sources [list [file join $cv_root eda sim_lib cyclonev_atoms.v] \
  [file join $cv_root eda sim_lib mentor cyclonev_atoms_ncrypt.v]]
set cv_library [file join $here cyclonev_sim_libs cyclonev_ver]
set cv_stamp [file join $here cyclonev_sim_libs source_identity.txt]
set cv_identity {}
foreach cv_source $cv_sources {
  if {![file exists $cv_source]} {error "Missing installed Cyclone V model:$cv_source"}
  lappend cv_identity $cv_source [file size $cv_source] [file mtime $cv_source]
}
set cv_rebuild 1
if {[file exists [file join $cv_library _info]] && [file exists $cv_stamp]} {
  set cv_fd [open $cv_stamp r];set cv_old [read $cv_fd];close $cv_fd
  if {$cv_old eq $cv_identity} {set cv_rebuild 0}
}
if {$cv_rebuild} {
  file mkdir [file dirname $cv_library]
  if {![file exists [file join $cv_library _info]]} {vlib $cv_library}
  foreach cv_source $cv_sources {vlog -work $cv_library $cv_source}
  set cv_fd [open $cv_stamp w];puts -nonewline $cv_fd $cv_identity;close $cv_fd
}
vmap cyclonev_ver $cv_library
