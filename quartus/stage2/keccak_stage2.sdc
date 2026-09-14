# Provisional 50 MHz module integration budget, not a measured Fmax.
create_clock -name clk -period 20.0 [get_ports clk]
derive_clock_uncertainty
set data_inputs [get_ports {start_i mode_i stop_i message_len_i[*] output_len_i[*] input_data_i[*] input_valid_i output_ready_i}]
set_input_delay -clock clk -max 2.0 $data_inputs
set_input_delay -clock clk -min 0.0 $data_inputs
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.0 [all_outputs]
# External asynchronous reset; board-level synchronized release is a later task.
set_false_path -from [get_ports rst]
