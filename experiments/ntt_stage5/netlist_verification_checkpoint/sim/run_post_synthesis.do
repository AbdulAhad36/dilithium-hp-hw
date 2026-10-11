# Functional post-synthesis main UVM; run from sim/.
set NTT_REPRESENTATION post_synthesis
set NTT_NETLIST_FILE ../quartus/ntt_LightHD/simulation_postsynth/ntt.vo
do ntt_LightHD/run_netlist.do
