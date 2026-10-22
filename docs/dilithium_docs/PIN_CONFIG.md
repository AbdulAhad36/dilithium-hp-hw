# Dilithium current interface and virtual pins

## Stage5N.3 internal signing service

No dilithium.sv external ports or virtual-pin changes. request_t.sign /
response_t.sign are internal command/completion records;their widths and codes
are documented in SPECIFICATION.md. The prepared Quartus source list includes
sign_process_dma.sv. Its selected legacy top and6.757ns SDC remain unchanged.
No new synthesis/fit or pin-placement result is claimed.

Stage5N.2 adds the standalone sign_process unit;it adds no dilithium.sv ports
or virtual pins. Its focused x4 input/output contract is in SPECIFICATION.md.
The prepared Quartus file list includes the five arithmetic/transport sources;
the selected legacy top and clock constraints are unchanged. No new fit.

Stage5N.1 adds only internal packed service records and relocates physical
instances under the main controller. No dilithium.sv external port changes
or new virtual pins are introduced. The prepared Quartus source list includes
the package/wrapper;its selected legacy top and6.757ns SDC remain unchanged.
No new Quartus compile or pin-assignment result is claimed.

## Stage5L implemented full-key output ports

FULL_KEYGEN=1 on dilithium.sv enables these ports in the source-tested main FSM.
Its input operation/level/ID/xi and held completion ports remain as before.

| Signal | Direction | Width | Function |
|---|---|---:|---|
| key_valid_o / key_ready_i |out/in|1 each|Held output handshake |
| key_data_o |out|64|Little-endian byte stream |
| key_bytes_o |out|4|Valid low bytes;8 for supported key sizes |
| key_type_o |out|1|0 PK,1 SK |
| key_index_o |out|10|Word index within key,reset for SK |
| key_last_o |out|1|Last word of that key |
| key_id_o |out|16|Operation ID |

FULL_KEYGEN=1 internally enables rounding and disables external polynomial
inspection handshakes;the key encoder owns the bank read port.
FULL_KEYGEN=0 preserves earlier diagnostic contracts.
These are implemented RTL ports,not board package assignments. The Quartus
selected top and historical virtual-pin count still describe the old scalar
helper;they must not be reported as the full main-controller pin total.

## Stage5K process interfaces;no main key-port assignment yet

The main keygen/dilithium helpers gain the ROUND_OUTPUTS parameter(default0).
No main pin-port list changes in this stage. Enable1 for retained t1/t0 arrays.
Bitpkg's internal process interface has field2,parameter2,ID16 command;23-bit
coefficient,index8,last input;64-bit output,byte count4,word index7,last,ID16;
and held3-bit completion code. These are internal RTL signals,not board pins.

The external public/secret-key stream or stored-key interface is not yet
connected. The Quartus selected top and existing virtual pin assignments remain
the preserved scalar baseline;there is no fresh fit or main-top pin-count claim.

## Stage5J main operation and polynomial-phase interfaces

dilithium.sv now exists as the main operation FSM around keygen.sv.
Start carries valid/ready,operation2,parameter2,ID16 and xi256.
Row result carries valid/ready,index4,region6 andID16. Bank inspection uses
the existing92-bit word protocol. Final status carries valid/ready,code3 andID16;
seed outputs are rho256,rho-prime512,K256 plus valid. reserved/complete each64
and sticky fault remain observable. See SPECIFICATION.md for operation/status
meaning. A successful result is polynomial-phase completion,not encoded keys.

These are source-tested internal interfaces. The Quartus selected top remains
the preserved scalar helper;virtual-pin counts and historical fit reports do
not describe dilithium.sv. No new main-top board/virtual assignment total is
claimed until its eventual synthesis integration.

## Stage5I helper interfaces;no new physical pin assignment

The banked NTT and row wrappers now expose an optional RAW_SERVICE parameter
(default0) and finite-SHAKE service ports:request valid/ready/core,mode1,
ID16,message/output lengths16,64-bit input valid/ready,128-bit output with
5-bit byte count and ID/core,plus tagged held completion. These ports route
the same Keccak cores;they are internal service interfaces,not board pins.

The new keygen_sample_source command interface and retained seed widths/codes
are listed in SPECIFICATION.md. The focused seed_row bench connects these
signals internally. The Quartus selected top remains keccak_sampler_ntt,with
its existing virtual-pin assignments. Neither this helper nor the banked row
wrapper has a new pin-count/fitted-PPA claim.

Stage5H's keccak_sampler_row is the latest focused row wrapper. It retains the
banked helper interfaces and adds the internal descriptor API below. It is not
the Quartus top;no new physical/virtual-pin total is claimed.

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
| row_valid_i / row_ready_o |in/out|1 each|Accept a complete staged-row command;waits for previous jobs/reads/compute to retire |
| row_busy_o |out|1|Exclusive row ownership,including held completion |
| row_param_i |in|2|0/1/2 = level2/3/5;3 invalid |
| row_index_i |in|4|Row index;must be less than k=4/6/8 |
| row_id_i |in|16|Final coefficient-result ID |
| row_acc_i / row_scratch_i / row_result_i |in|6 each|Three distinct,free {bank2,region4} workspace descriptors |
| row_a_i / row_s_i |in|7 x6 each|Staged A_hat and retained s1_hat regions;first l=4/5/7 entries used |
| row_a_id_i / row_s_id_i |in|7 x16 each|Expected source IDs;unused entries ignored |
| row_done_valid_o / row_done_ready_i |out/in|1 each|Held whole-row completion |
| row_done_code_o |out|3|0 success,1 source absent/stale,2 domain/level mismatch,3 workspace busy/alias,4 level/row invalid |
| row_done_id_o / row_done_region_o |out|16 /6|Final requested ID/region,echoed on rejection too |
| row_completed_terms_o |out|3|0 for rejected commands;l=4/5/7 for success;partial count visible during execution |

Stage5H also adds process_inplace_i(1-bit input) to the banked process helper:
0 preserves ordinary distinct-result behavior;1 permits ADD/SUB overwriting A.
It consumes the old A version,so ordinary callers should keep it0. P2R rejects
in-place requests. The row scheduler uses it1 for accumulation. Internal IDs
are16-bit arithmetic modulo65536;the final output keeps row_id_i.

Stage5G enables PROCESS_SERVICE=1 on the banked helper. These are internal
process-client ports,not a changed Quartus top or physical pin assignment:

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
| process_valid_i / process_ready_o |in/out|1 each|Process command handshake;NTT command priority |
| process_busy_o |out|1|Client owns memory,including held completion |
| process_op_i |in|2|0 ADD,1 SUB,2 Power2Round,3 invalid |
| process_a_i / process_b_i |in|6 each|{bank2,region4};B ignored for P2R |
| process_dest_i / process_high_i |in|6 each|Residue/low and P2R high destinations;high ignored for ADD/SUB |
| process_a_id_i / process_b_id_i / process_id_i |in|16 each|Expected source IDs and result ID |
| process_done_valid_o / process_done_ready_i |out/in|1 each|Held process completion handshake |
| process_done_code_o |out|3|0 success,1 missing/stale source,2 domain/parameter mismatch,3 alias,4 invalid opcode |
| process_done_id_o |out|16|Echo result ID |
| process_done_dest_o / process_done_high_o |out|6 each|Echo requested destinations,including rejection |

The default PROCESS_SERVICE=0 leaves this service inactive. Full controller/key
transfer interfaces remain future work;no new external pin total is claimed.

Stage5F's keccak_sampler_ntt_banks is source-tested through selector5/bank_ntt.
It is not the Quartus top;the pin counts/assignments below remain historical.
Its sampling/read/release ports follow keccak_sampler_banks. Added compute API:

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
| op_valid_i / op_ready_o |in/out|1 each|Compute command handshake |
| op_busy_o |out|1|Sequential command active,including held completion |
| op_i |in|2|0 NTT,1 INTT,2 PWM,3 Pre |
| op_a_region_i / op_b_region_i |in|6 each|{bank2,aligned region4};B used only for PWM |
| op_dest_region_i |in|6|Explicit distinct destination;waits if occupied |
| op_a_id_i / op_b_id_i / op_id_i |in|16 each|Expected source owners and new result ID |
| op_done_valid_o / op_done_ready_i |out/in|1 each|Held completion handshake |
| op_done_code_o |out|3|0 success,1 missing/stale source,2 domain/parameter/bounds,3 alias destination |
| op_done_id_o / op_done_region_o |out|16 /6|Result descriptor identity,destination echoed on rejection too |

No physical package pins or new virtual-pin total are claimed for this helper.

Stage5E's keccak_sampler_banks is a focused connected sampling/storage wrapper.
Its descriptor adds bank2/region4 and reads92-bit words with checked metadata.
It is not yet the synthesis top;the public main pin count below remains for
keccak_sampler_ntt. See MEMORY_MAP.md for the banked internal API.

Stage5C adds optional raw-service ports inside keccak_sampler and a seed
collector;these are internal helper interfaces,documented in SPECIFICATION.md.
The current synthesis top disables them,so the public pin table/count below is
unchanged. New full-controller/key-transfer pins await their interface decision.

Current synthesis top:`keccak_sampler_ntt`,the Stage4 subsystem helper. The future
`dilithium.sv` top will extend this table when main-controller interfaces exist.
All294 non-clock bits are assigned virtual pins;clk is the one physical clock
input. No board/package assignment is selected. Stage4 has not been fitted yet.
Count:214 Stage3 non-clock bits plus80 compute-command/completion bits=294.
Clock adds one for295 total top-level bits. These are interface bits,not a
claim that294 physical package pins are needed or assigned.

| Port | Direction | Bits | Meaning |
|---|---|---:|---|
| clk | Input |1|Shared clock,target6.757ns/about148MHz |
| rst | Input |1|Active-high coordinated reset;hold through rising edges;abort both contexts |
| job_valid_i / job_ready_o | Input/output |1 each|Descriptor ready/valid transfer |
| job_core_o | Output |1|Actual assigned Keccak/sampler context on command acceptance |
| job_slot_o | Output |2|Reserved polynomial slot on command acceptance |
| job_id_i | Input |16|Polynomial/job ID |
| message_len_i | Input |16|Complete absorption-message byte length,0..65535 |
| job_mode_i | Input |2|0=A,1=secret,2=mask,3=challenge |
| job_param_i | Input |2|0/1/2 select level2/3/5 parameters;3 yields parameter error |
| input_data_i | Input |64|Message bytes,earliest in low byte;declared length controls final partial word |
| input_valid_i / input_ready_o | Input/output |1 each|Message ready/valid transfer |
| read_valid_i / read_ready_o | Input/output |1 each|Read-request handshake |
| read_slot_i / read_index_i | Input |2 /8|Polynomial slot and coefficient index |
| response_valid_o / response_ready_i | Output/input |1 each|Synchronous read-response handshake |
| response_error_o | Output |1|Slot not COMPLETE;ignore response payload |
| response_slot_o / response_index_o | Output |2 /8|Echoed read location |
| response_data_o | Output |23|Canonical stored coefficient on successful read |
| response_id_o | Output |16|Stored job ID |
| response_mode_o / response_param_o | Output |2 each|Stored sampling mode and parameter |
| response_ntt_domain_o | Output |1|Matrix A is already transform-domain |
| release_valid_i / release_ready_o | Input/output |1 each|Explicit slot-release handshake |
| release_slot_i | Input |2|Slot to release after all consumers finish |
| reserved_o / complete_o | Output |4 each|Per-slot allocation and successful-commit masks |
| fault_o | Output |1|Sticky internal memory-protocol fault;reset recovery required |
| status_valid_o / status_ready_i | Output/input |1 each|Completion/error ready/valid;source drained before external offer |
| status_core_o | Output |1|Completed context |
| status_id_o | Output |16|Completed job ID |
| status_code_o | Output |3|Existing sampler status encoding;current tests exercise OK0 and parameter error3 |
| active_o | Output |2|Context ownership until external status acceptance |
| op_valid_i / op_ready_o | Input/output |1 each|Sequential compute-command handshake |
| op_busy_o | Output |1|Accepted command is reserving,loading,running,committing or awaiting reply acceptance |
| op_i | Input |2|0=NTT,1=INTT,2=PWM,3=Pre-NTT |
| op_a_slot_i / op_b_slot_i | Input |2 each|Source slots;B ignored for unary operations |
| op_a_id_i / op_b_id_i | Input |16 each|Expected source job IDs;stale IDs rejected |
| op_id_i | Input |16|New destination/result ID |
| op_done_valid_o / op_done_ready_i | Output/input |1 each|Held compute-completion/rejection reply |
| op_done_code_o | Output |3|0=success,1=missing/stale source,2=domain/parameter/Pre-ineligible |
| op_done_id_o | Output |16|Echoed result ID |
| op_done_slot_o | Output |2|Committed result slot on success;zero on rejection |

Hold producer payloads stable while valid and not ready. Public output/status
offers remain stable until accepted or reset. input_data_i belongs to the
currently accepted Keccak message;new absorption messages are serialized by its
ingress protocol. Reset discards old jobs;it does not securely erase all data.
Independent per-job cancellation and finite-XOF length controls are not exposed.
Read/status offers remain stable until accepted or coordinated reset. Pending
read responses prevent slot release;the future controller owns longer lifetimes.
