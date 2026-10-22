# Focused integration regression;full Dilithium UVM comes later.
# Questa GUI,from sim/: do dilithium/run.do
# Default Stage4;set DILITHIUM_STAGE 2 or3 to rerun earlier connection gates.
if {![info exists DILITHIUM_STAGE]} {set DILITHIUM_STAGE 4}
if {![info exists DILITHIUM_TEST]} {set DILITHIUM_TEST process}
if {$DILITHIUM_TEST ni {process hash_format shared_hash bank_memory bank_store bank_ntt bank_process row seed_row keygen rounded_keygen bitpkg full_keygen nist_keygen sign_process sign_dma sign_service}} {error "Unknown DILITHIUM_TEST selector"}
if {$DILITHIUM_STAGE ni {2 3 4 5}} {error "DILITHIUM_STAGE must be2,3,4 or5 (process unit gate)"}
if {[batch_mode]} {onerror {quit -code 1 -f}} else {onerror {abort}}
set launch [file normalize [pwd]]
if {[file exists [file join $launch stage2_inputs.txt]]} {
    set here $launch
} elseif {[file exists [file join $launch dilithium run.do]]} {
    set here [file join $launch dilithium]
} else {
    set here [file join $launch sim dilithium]
}
set repo [file normalize [file join $here .. ..]]
if {[catch {exec python [file join $here dilithium_vectors.py] check} freshness]} {error $freshness}
echo $freshness
set workdir [file join $here work]
if {![file exists $workdir]} {vlib $workdir}
vmap dilithium_work $workdir
set rtl [file join $repo src]
vlog -sv -work dilithium_work [file join $rtl keccak keccak_pkg.sv]
foreach n {keccak_param_unit keccak_absorb_unit theta_step rho_step pi_step chi_step iota_step keccak_step_unit keccak_output_unit keccak_core keccak_dual_interleaved} {
    vlog -sv -work dilithium_work [file join $rtl keccak ${n}.sv]
}
vlog -sv -work dilithium_work [file join $rtl sampler sampler_pkg.sv]
foreach n {sampler_secret_lane sampler_mask_unpack sampler_input_prepare sampler_ball sampler_compact sampler} {
    vlog -sv -work dilithium_work [file join $rtl sampler ${n}.sv]
}
vlog -sv -work dilithium_work [file join $rtl ntt ntt_pkg.sv]
foreach n {mod_mul butterfly_unit twiddle_rom ntt_core ntt_engine} {
    vlog -sv -work dilithium_work [file join $rtl ntt ${n}.sv]
}
vlog -sv -work dilithium_work [file join $rtl controller datapath keccak_sampler.sv] [file join $rtl controller legacy slot_memory.sv] [file join $rtl controller legacy keccak_sampler_memory.sv] [file join $rtl controller legacy keccak_sampler_ntt.sv]
vlog -sv -work dilithium_work [file join $rtl controller process power2round.sv] [file join $rtl controller process poly_process.sv]
vlog -sv -work dilithium_work [file join $rtl controller process poly_process_dma.sv]
vlog -sv -work dilithium_work [file join $rtl controller process bitpkg.sv]
foreach n {decompose decompose_x4 cnb mhint sign_process sign_process_dma} {vlog -sv -work dilithium_work [file join $rtl controller process ${n}.sv]}
vlog -sv -work dilithium_work [file join $rtl controller process keygen_hash_message.sv]
vlog -sv -work dilithium_work [file join $rtl controller helpers keygen_seed_collect.sv]
vlog -sv -work dilithium_work [file join $rtl controller helpers keygen_sample_source.sv]
vlog -sv -work dilithium_work [file join $rtl controller helpers dilithium_service_pkg.sv]
vlog -sv -work dilithium_work [file join $rtl controller helpers keygen_encode.sv]
vlog -sv -work dilithium_work [file join $rtl controller memory poly_bram.sv] [file join $rtl controller memory memory_banks.sv]
vlog -sv -work dilithium_work [file join $rtl controller memory.sv] [file join $rtl controller datapath keccak_sampler_banks.sv]
vlog -sv -work dilithium_work [file join $rtl controller datapath keccak_sampler_ntt_banks.sv]
vlog -sv -work dilithium_work [file join $rtl controller helpers row_accumulate.sv] [file join $rtl controller datapath keccak_sampler_row.sv]
vlog -sv -work dilithium_work [file join $rtl controller datapath dilithium_services.sv]
vlog -sv -work dilithium_work [file join $rtl controller keygen.sv] [file join $rtl controller dilithium.sv]
if {$DILITHIUM_STAGE == 5} {
    if {$DILITHIUM_TEST eq "sign_service"} {set top tb_sign_service} elseif {$DILITHIUM_TEST eq "sign_dma"} {set top tb_sign_process_dma} elseif {$DILITHIUM_TEST eq "sign_process"} {set top tb_sign_process} elseif {$DILITHIUM_TEST in {full_keygen nist_keygen}} {set top tb_full_keygen} elseif {$DILITHIUM_TEST eq "bitpkg"} {set top tb_bitpkg} elseif {$DILITHIUM_TEST in {keygen rounded_keygen}} {set top tb_keygen} elseif {$DILITHIUM_TEST in {row seed_row}} {set top tb_row_accumulate} elseif {$DILITHIUM_TEST eq "bank_process"} {set top tb_bank_process} elseif {$DILITHIUM_TEST eq "bank_ntt"} {set top tb_keccak_sampler_ntt_banks} elseif {$DILITHIUM_TEST eq "bank_store"} {set top tb_keccak_sampler_banks} elseif {$DILITHIUM_TEST eq "bank_memory"} {set top tb_memory_banks} elseif {$DILITHIUM_TEST eq "shared_hash"} {set top tb_shared_hash} elseif {$DILITHIUM_TEST eq "hash_format"} {set top tb_keygen_hash_message} else {set top tb_poly_process}
    if {$DILITHIUM_TEST eq "bank_store"} {vlog -sv -work dilithium_work [file join $repo tb tb_dilithium bank_store_protocol_test.sv]}
    vlog -sv -work dilithium_work [file join $repo tb tb_dilithium ${top}.sv]
} elseif {$DILITHIUM_STAGE == 4} {
    set top tb_keccak_sampler_ntt
    vlog -sv -work dilithium_work [file join $repo tb tb_dilithium ${top}.sv]
} elseif {$DILITHIUM_STAGE == 3} {
    set top tb_keccak_sampler_memory
    vlog -sv -work dilithium_work [file join $repo tb tb_dilithium memory_protocol_test.sv] [file join $repo tb tb_dilithium ${top}.sv]
} else {
    set top tb_keccak_sampler
    vlog -sv -work dilithium_work [file join $repo tb tb_dilithium ${top}.sv]
}
set generics {}
if {$DILITHIUM_TEST eq "seed_row"} {lappend generics -gSEED_SOURCE=1}
if {$DILITHIUM_TEST eq "rounded_keygen"} {lappend generics -gROUND_OUTPUTS=1}
if {$DILITHIUM_TEST eq "nist_keygen"} {lappend generics -gNIST_VECTORS=1}
vsim -voptargs=+acc {*}$generics -wlf [file join $here stage${DILITHIUM_STAGE}.wlf] dilithium_work.$top +STAGE2_DIR=$here
onfinish stop
if {![batch_mode]} {
    view transcript;view wave
    add wave /$top/clk /$top/rst
    if {$DILITHIUM_STAGE == 5} {
      if {$DILITHIUM_TEST eq "sign_service"} {
        add wave -divider {Main-owned shared services and signing client}
        add wave /$top/request_i /$top/response_o /$top/dut/datapath/subsystem/sign_client/state
        add wave /$top/dut/datapath/subsystem/s_locks /$top/dut/datapath/subsystem/s_hidden
        add wave /$top/dut/datapath/subsystem/store/acknowledged_r
      } elseif {$DILITHIUM_TEST eq "sign_dma"} {
        add wave -divider {Signing DMA,private allocations and acknowledged publication}
        add wave /$top/command_* /$top/done_* /$top/dut/state /$top/dut/word_r /$top/dut/lane_r
        add wave /$top/reserved /$top/visible /$top/release_locks_o /$top/hidden_o
        add wave /$top/store/acknowledged_r /$top/write_* /$top/finish_*
      } elseif {$DILITHIUM_TEST eq "sign_process"} {
        add wave -divider {x4 signing processes and polynomial reductions}
        add wave /$top/input_* /$top/output_* /$top/dut/active_r /$top/dut/reject_r /$top/dut/weight_r
      } elseif {$DILITHIUM_TEST in {full_keygen nist_keygen}} {
        add wave -divider {Main shared-service ownership}
        add wave /$top/dut/keygen_owner /$top/dut/shared_request /$top/dut/shared_response
        add wave -divider {Whole key output and shared public-key hash}
        add wave /$top/start_* /$top/key_* /$top/done_* /$top/dut/core/state
        add wave /$top/dut/core/encoder/state /$top/dut/core/encoder/section_r /$top/dut/core/encoder/poly_r
        add wave /$top/dut/core/encoder/host_sent_r /$top/dut/core/encoder/hash_sent_r /$top/dut/core/encoder/raw_*
        add wave /$top/reserved_o /$top/complete_o
      } elseif {$DILITHIUM_TEST eq "bitpkg"} {
        add wave -divider {Polynomial bit packing and packet retirement}
        add wave /$top/command_* /$top/input_* /$top/output_* /$top/done_* /$top/dut/state
        add wave /$top/dut/count_r /$top/dut/bits_r
      } elseif {$DILITHIUM_TEST in {keygen rounded_keygen}} {
        add wave -divider {Main FSM and autonomous KeyGen}
        add wave /$top/start_* /$top/done_* /$top/dut/state /$top/dut/core/state
        add wave /$top/dut/core/nonce_r /$top/dut/core/column_r /$top/dut/core/index_r
        add wave -divider {Rows,secrets and bank ownership}
        add wave /$top/row_result_* /$top/read_* /$top/response_* /$top/reserved_o /$top/complete_o
      } elseif {$DILITHIUM_TEST in {row seed_row}} {
        if {$DILITHIUM_TEST eq "seed_row"} {
          add wave -divider {Seed retention and RTL message construction}
          add wave /$top/command_* /$top/done_* /$top/seed_* /$top/raw_*
          add wave /$top/seed_path/source/state /$top/seed_path/source/format/state
        }
        add wave -divider {Whole-row schedule and leases}
        add wave /$top/row_* /$top/dut/controller/state /$top/dut/controller/column_r /$top/dut/row_locks
        add wave -divider {PWM,destructive accumulator ADD,inverse NTT}
        add wave /$top/dut/row_ntt_* /$top/dut/row_process_* /$top/dut/subsystem/process_client/inplace_r
        add wave /$top/dut/subsystem/process_client/word_r /$top/dut/subsystem/process_client/pp_*
        add wave /$top/read_* /$top/response_* /$top/complete_o
      } elseif {$DILITHIUM_TEST eq "bank_process"} {
        add wave -divider {Shared memory ownership and process commands}
        add wave /$top/process_* /$top/op_* /$top/dut/process_client/state /$top/dut/p_locks /$top/dut/p_hidden
        add wave -divider {Process DMA and Power2Round outputs}
        add wave /$top/dut/process_client/word_r /$top/dut/process_client/lane_r /$top/dut/process_client/pp_*
        add wave /$top/dut/store/word_* /$top/dut/store/acknowledged_r /$top/read_* /$top/response_*
      } elseif {$DILITHIUM_TEST eq "bank_ntt"} {
        add wave -divider {Banked sampling and NTT ownership}
        add wave /$top/job_* /$top/status_* /$top/op_* /$top/dut/state /$top/dut/source_leases
        add wave -divider {Packed DMA and committed result}
        add wave /$top/dut/load_word_r /$top/dut/lane_r /$top/dut/s_* /$top/dut/m_*
        add wave /$top/dut/store/word_* /$top/dut/store/acknowledged_r /$top/read_* /$top/response_*
      } elseif {$DILITHIUM_TEST eq "bank_store"} {
        add wave -divider {Bank region descriptor and publication}
        add wave /$top/job_* /$top/status_* /$top/reserved_o /$top/complete_o /$top/fault_o
        add wave -divider {Coefficient packing and word acknowledgement}
        add wave /$top/dut/coeff_* /$top/dut/store/word_* /$top/dut/store/acknowledged_r
        add wave -divider {Protected bank read and release}
        add wave /$top/read_* /$top/response_* /$top/release_*
      } elseif {$DILITHIUM_TEST eq "bank_memory"} {
        add wave -divider {Four banks,ports A/B}
        add wave /$top/request_* /$top/response_* /$top/collision_o /$top/phase
      } elseif {$DILITHIUM_TEST eq "shared_hash"} {
        add wave -divider {Seed submission and retained material}
        add wave /$top/start_* /$top/result_* /$top/collector/count_r
        add wave -divider {Shared raw hash and sampling ownership}
        add wave /$top/raw_* /$top/job_* /$top/output_* /$top/status_*
        add wave /$top/dut/owned_r /$top/dut/raw_r /$top/dut/hash_busy
      } elseif {$DILITHIUM_TEST eq "hash_format"} {
        add wave -divider {KeyGen message construction}
        add wave /$top/command_* /$top/request_* /$top/input_* /$top/done_* /$top/dut/state
        add wave -divider {Shared SHAKE test service}
        add wave /$top/hash_* /$top/words /$top/beats
      } else {
        add wave -divider {Process input and output}
        add wave /$top/input_* /$top/output_*
      }
    } else {
    add wave -divider {Descriptor and absorption}
    add wave /$top/job_* /$top/input_*
    add wave -divider {Coefficient and completion}
    add wave /$top/status_*
    if {$DILITHIUM_STAGE >= 3} {
        add wave -divider {Slot ownership and readback}
        add wave /$top/reserved_o /$top/complete_o /$top/fault_o
        add wave /$top/read_* /$top/response_* /$top/release_*
        add wave /$top/dut/coeff_* /$top/dut/store/count_r /$top/dut/store/state_r
        if {$DILITHIUM_STAGE == 4} {
            add wave -divider {NTT command and DMA}
            add wave /$top/op_* /$top/dut/state /$top/dut/load_index_r /$top/dut/result_count_r
            add wave /$top/dut/ntt_* /$top/dut/s_* /$top/dut/m_*
        }
    } else {
        add wave /$top/output_*
        add wave -divider {Bridge,drain and ownership}
        add wave /$top/dut/owned_r /$top/dut/drain_r /$top/dut/stop_r
        add wave /$top/dut/bridge_valid_r /$top/dut/hash_valid /$top/dut/hash_ready
    }
    }
    log /$top/*
}
run -all
if {[examine -radix unsigned /$top/test_passed] != 1} {
    error "Stage$DILITHIUM_STAGE test did not reach its explicit completion gate"
}
if {![batch_mode]} {wave zoom full}
echo "Run python sim/dilithium/dilithium_vectors.py compare --stage $DILITHIUM_STAGE --unit $DILITHIUM_TEST from repository root for the independent verdict."
