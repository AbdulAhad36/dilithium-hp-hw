# Functional post-fit main UVM; Cyclone V has no SDF timing netlist.
set NTT_REPRESENTATION post_fit
set NTT_NETLIST_FILE ../quartus/ntt_LightHD/simulation_postfit/ntt.vo
do ntt_LightHD/run_netlist.do
