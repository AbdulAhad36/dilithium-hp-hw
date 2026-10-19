# Run after a full compile: quartus_sta -t report_paths.tcl
# Read the declared constraint unchanged; inspect all supported corners.
project_open sampler -revision sampler
create_timing_netlist -model slow
read_sdc
file mkdir critical_paths
# A source-only simulation cannot detect synthesis dropping a payload register.
# Stage4.6 found this in the old variable outer-dimension part-select writes.
# Check both64-bit secret stages survived mapping before accepting timing data.
set payload_report [open critical_paths/secret_payload_registers.rpt w]
# Wide values repeat modulo4; secret low nibbles retain16 distinct slots.
# Expected original commit payload:4*19 upper bits +16*4 low bits =140.
# A fields now derive from the147-bit shared stream;their separate bank is absent.
foreach {payload expected_bits} {extract_secret_r 64 decode_secret_r 64 decode_total_count_r 5 packed_secret_r 64 packed_write_mask_r 64 commit_data_r 140 commit_write_mask_r 64 ball_write_mask_r 64 read_data_r 46 out_data_r 23 *u_prepare*mask_fine_r 131 *u_prepare*mask_stream_r 147 *u_prepare*a_values_r 0 *u_prepare*carry_masks_r 38 *u_prepare*mask_carry_o 38 *u_prepare*a_carry_o 32 ball_issue_index_r 18 chunk_capacity 2 reservation_pending_r 8 reservation_pop_r 2 ball_byte_r 8 *u_ball*signs 128} {
  set payload_nodes [get_registers ${payload}*]
  # Router copies keep the original registers and append~DUPLICATE names.
  # Count original payload bits separately so valid duplication cannot fail
  # the guard, while a missing original bit still does.
  set payload_names {}
  set payload_duplicates 0
  foreach_in_collection payload_node $payload_nodes {
    set payload_name [get_node_info -name $payload_node]
    if {[string match {*~DUPLICATE*} $payload_name]} {
      incr payload_duplicates
    } else {
      lappend payload_names $payload_name
    }
  }
  set payload_count [llength [lsort -unique $payload_names]]
  puts $payload_report [format {%s: %d registers} $payload $payload_count]
  puts $payload_report [format {  Router duplicates: %d; physical matches: %d} $payload_duplicates [get_collection_size $payload_nodes]]
  if {$payload_count != $expected_bits} {
    close $payload_report
    error "Expected$expected_bits mapped registers for $payload; found $payload_count"
  }
}
puts $payload_report "SECRET PAYLOAD REGISTER GUARD PASS:64 decode and64 packed registers"
puts $payload_report "EXTRACTION/OUTPUT PIPELINE REGISTER GUARD PASS:64 extract,46 read,23 output bits"
close $payload_report
foreach corner {{slow 85} {slow 0} {fast 85} {fast 0}} {
  lassign $corner model temperature
  set_operating_conditions -model $model -temperature $temperature -voltage 1100
  update_timing_netlist
  set prefix critical_paths/${model}_${temperature}C
  report_timing -setup -npaths 3 -detail full_path -file ${prefix}_setup.rpt
  report_timing -hold -npaths 3 -detail full_path -file ${prefix}_hold.rpt
}
# Stage4.7 frequency closure: expose each stage's worst endpoint so fixing one
# path does not hide another long path behind thousands of similar registers.
foreach temperature {85 0} {
  set_operating_conditions -model slow -temperature $temperature -voltage 1100
  update_timing_netlist
  foreach family {hold_data_r hold_bytes_r beat_bytes_r ball_remaining_r ball_issue_index_r ball_room_r mask_residual_r residual_r mask_carry_shift_r a_carry_shift_r extract_secret_r extract_mask_r extract_data_r decode_secret_r decode_total_count_r packed_secret_r packed_wide_r packed_write_mask_r commit_data_r commit_write_mask_r ball_write_mask_r append_tail_r collector_r read_data_r out_data_r quota_r slot_reservation_r slot_refund_r ball_byte_index_r read_valid_r *u_prepare*mask_fine_r *u_prepare*mask_stream_r *u_prepare*a_values_r *u_prepare*end_bits_r *u_prepare*field_counts_r *u_prepare*mask_carry_o *u_prepare*saved_bits_r *u_prepare*lower_valid_r *u_prepare*full_valid_r} {
    set endpoints [get_registers ${family}*]
    set family_file [string map {* _} $family]
    if {[get_collection_size $endpoints] > 0} {
      report_timing -setup -npaths 1 -to $endpoints -detail full_path -file critical_paths/family_${family_file}_slow_${temperature}C_setup.rpt
    } else {
      set absent [open critical_paths/family_${family_file}_slow_${temperature}C_setup.rpt w]
      puts $absent "No mapped registers in this revision"
      close $absent
    }
  }
}
delete_timing_netlist
project_close
