# Stage4.7: user's150+MHz objective;6.5ns requests153.85MHz in fitter/STA.
# Prior100MHz sources,SDC and reports remain in immutable4.6r/4.6z archives.
create_clock -name clk -period 6.500 [get_ports clk]
derive_clock_uncertainty
# Standalone core timing: virtual I/O is intentionally excluded. These exceptions
# do not waive internal register/memory paths. Board integration needs I/O delays.
set sampler_data_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_false_path -from $sampler_data_inputs
set_false_path -to [all_outputs]
unset sampler_data_inputs
