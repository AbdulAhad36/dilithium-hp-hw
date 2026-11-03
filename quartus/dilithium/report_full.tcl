# Whole-main baseline only. Run after compiling dilithium_full.qpf.
project_open dilithium_full -revision dilithium_full
if {[get_global_assignment -name TOP_LEVEL_ENTITY] ne "dilithium_fpga"} {error "Wrong production synthesis top"}
create_timing_netlist -model slow
read_sdc
file mkdir critical_full
set guard [open critical_full/retained_registers.rpt w]
# Read mapped register names once. Exact scope expressions prevent child
# FSMs/Keccak state arrays from inflating the four controller checks.
set mapped_registers {}
foreach_in_collection reg [get_registers *] {
  set name [get_node_info -name $reg]
  if {![string match {*~DUPLICATE*} $name]} {lappend mapped_registers $name}
}
set mapped_registers [lsort -unique $mapped_registers]
set names_file [open critical_full/mapped_register_names.rpt w]
foreach name $mapped_registers {puts $names_file $name}
close $names_file
foreach {label expression minimum} {
  main_state {^dilithium:core\|state[.\[]} 1
  keygen_controller {\|keygen:keygen_controller\|state[.\[]} 1
  sign_controller {\|sign:sign_controller\|state[.\[]} 1
  verify_controller {\|verify:verify_controller\|state[.\[]} 1
  dual_keccak_state {\|keccak_core:.*u_core\|state_array} 3200
  sampler_extract_secret {\|sampler:sample\|extract_secret_r} 64
  sampler_decode_secret {\|sampler:sample\|decode_secret_r} 64
  sampler_packed_secret {\|sampler:sample\|packed_secret_r} 64
  butterfly0 {\|butterfly_fused:g_bf\[0\]\.u_bf\|keep_a_reg} 23
  butterfly1 {\|butterfly_fused:g_bf\[1\]\.u_bf\|keep_a_reg} 23
  butterfly2 {\|butterfly_fused:g_bf\[2\]\.u_bf\|keep_a_reg} 23
  butterfly3 {\|butterfly_fused:g_bf\[3\]\.u_bf\|keep_a_reg} 23
  physical_port_owners {\|memory_router:router\|owner_r} 16
  sampler_writer_context_ids {\|sampler_writer:writer\|id_r} 32
  writer_normal_payload {\|sampler_writer:writer\|normal_data_r} 184
  writer_normal_address {\|sampler_writer:writer\|normal_address_r} 20
  writer_normal_bank {\|sampler_writer:writer\|normal_bank_r} 4
  writer_normal_core {\|sampler_writer:writer\|normal_core_r} 2
  writer_normal_occupancy {\|sampler_writer:writer\|normal_count_r} 2
  writer_normal_pointers {\|sampler_writer:writer\|normal_(read|write)_r} 2
  decoded_packet_payload {\|load_decode:decoder\|packet[01]_r} 184
  decoded_packet_progress {\|load_decode:decoder\|decoded_r} 7
  shared_process_stage0_data {\|poly_process:.*\|value_r\[0\]\.data} 92
  verify_shared_digest {\|verify:verify_controller\|(mu_r|digest_r)} 512
  process_raw_operand_queue {\|process_dma:process_path\|operand_[ab]_store_r} 368
  process_operand_tags {\|process_dma:process_path\|operand_tag_store_r} 12
  process_operand_occupancy {\|process_dma:process_path\|operand_count_r} 2
  process_operand_pointers {\|process_dma:process_path\|operand_(read|write)_r} 2
  shared_hint_indices {\|hint_codec:.*\|indices_r} 640
  shared_hint_counts {\|hint_codec:.*\|counts_r} 64
  bank_request_payload {\|bank_request_pipe:bank\[[0-3]\]\.request_pipe\|entries_r} 1648
  bank_request_counts {\|bank_request_pipe:bank\[[0-3]\]\.request_pipe\|count_r} 16
  bank_request_pointers {\|bank_request_pipe:bank\[[0-3]\]\.request_pipe\|(read_r|write_r)} 16
  bank_request_order {\|bank_request_pipe:bank\[[0-3]\]\.request_pipe\|a_older_r} 16
  unpacker_selected_window {\|bitunpkg:unpacker\|bits_r} 80
  unpacker_window_valid {\|bitunpkg:unpacker\|window_valid_r} 1
  sampling_completion {\|hash_sampler:hash_sampler\|completion_} 18
  registered_keccak_launch {\|keccak_dual_interleaved:hash\|launch_start_r} 2
  ntt_predecoded_operation {\|ntt_dma:polynomial\|is_(pwm|inverse|compact)_r} 3
  ntt_cached_read_mask {\|ntt_dma:polynomial\|read_command_mask_r} 1
  unpacker_word_store {\|bitunpkg:unpacker\|words_r} 192
  unpacker_ring_pointers {\|bitunpkg:unpacker\|(read_slot_r|write_slot_r)} 4
  unpacker_bit_offset {\|bitunpkg:unpacker\|bit_offset_r} 4
  registered_hint_mask {\|hint_codec:.*\|d_registered_hints} 4
  registered_hint_coordinates {\|hint_codec:.*\|d_registered_(row|word)} 9
  registered_hint_pending {\|hint_codec:.*\|d_output_pending_r} 1
  main_registered_owner {^dilithium:core\|owner_select_r} 3
  sign_rho_store {\|sign:sign_controller\|(rho_store_r|rho)\[} 256
  sign_tr_mu_store {\|sign:sign_controller\|(tr_mu_store_r|mu_r|tr)\[} 512
  sign_entropy_mask_store {\|sign:sign_controller\|(entropy_mask_store_r|mask_r|key|rnd_r)\[} 512
} {
  set names {}
  foreach name $mapped_registers {
    if {[regexp $expression $name]} {lappend names $name}
  }
  set count [llength $names]
  puts $guard "$label:$count original mapped register bits; minimum:$minimum"
  if {$count<$minimum} {close $guard;error "Missing retained registers for $label; inspect actual mapped names/features"}
}
puts $guard {WHOLE_MAIN_RETAINED_REGISTER_GUARD_PASS}
close $guard
foreach corner {{slow 85} {slow 0} {fast 85} {fast 0}} {
  lassign $corner model temperature
  set_operating_conditions -model $model -temperature $temperature -voltage 1100
  update_timing_netlist
  set prefix critical_full/${model}_${temperature}C
  report_timing -setup -npaths 5 -detail full_path -file ${prefix}_setup.rpt
  report_timing -hold -npaths 5 -detail full_path -file ${prefix}_hold.rpt
  report_clock_fmax_summary -file ${prefix}_fmax.rpt
}
delete_timing_netlist
project_close
