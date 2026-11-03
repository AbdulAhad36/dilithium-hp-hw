# Dilithium current interface and virtual pins

Stage7C.7 keeps the same51 signal groups/1027 bits below. Production
`dilithium_fpga` now forwards them to the compact `dilithium` core.
All three operations remain enabled. Fresh210 official commands,88 protocol
commands and main UVM33 pass through this actual production wrapper.
The four-bank ownership and engine activity probes used by UVM are internal;
no new debug or memory ports are exported. Device/clock/virtual-pin settings
are unchanged. Stage7C.7 now routes on the same FPGA;current measured PPA
and its still-open setup target are recorded in THROUGHPUT.md. Historical
7B.9 physical results are not the new design's measurements.

There are51 signal groups/1027 bits including clock:1026 nonclock bits use
virtual-pin assignments. Clock stays a real clock input selected by the
fitter;no board/package pin location is assigned here. These are port counts,
not ALM counts. The encoded streams retain their existing framing and widths.

|Signal|Direction at FPGA|Bits|Purpose|
|---|---|---:|---|
|key_valid_o|output|1|Encoded key word available|
|key_ready_i|input|1|Host accepts an encoded key word|
|key_data_o|output|64|Public/secret-key byte stream|
|key_bytes_o|output|4|Valid bytes in the current key word|
|key_type_o|output|1|0 public key;1 secret key|
|key_last_o|output|1|Last word of the current key frame|
|key_index_o|output|10|Word index within the current key frame|
|key_id_o|output|16|Operation ID on the key stream|
|clk|input|1|Core clock;6.757ns internal benchmark target|
|rst|input|1|Active-high reset|
|start_valid_i|input|1|Host presents a new command|
|start_ready_o|output|1|Controller accepts a new command|
|busy_o|output|1|Operation/control ownership active|
|start_op_i|input|2|0 KeyGen;1 Sign;2 Verify;3 rejected|
|start_param_i|input|2|0/1/2 selects level2/3/5 (ML-DSA-44/65/87)|
|start_id_i|input|16|Command identity|
|start_seed_i|input|256|32-byte KeyGen seed|
|start_message_len_i|input|16|Message length in bytes|
|start_context_len_i|input|9|Context length in bytes;accepted pure-API range0..255|
|start_rnd_i|input|256|32-byte signing randomness|
|sign_input_valid_i|input|1|Sign input word available|
|sign_input_ready_o|output|1|Controller accepts a Sign input word|
|sign_input_data_i|input|64|Expanded SK frame,then context\|\|message frame|
|sign_input_bytes_i|input|4|Valid bytes in the Sign word|
|sign_input_index_i|input|16|Sign word index;restarts at each frame|
|sign_input_last_i|input|1|Last word of the current Sign frame|
|start_signature_len_i|input|16|Verify signature length in bytes|
|verify_input_valid_i|input|1|Verify input word available|
|verify_input_ready_o|output|1|Controller accepts a Verify input word|
|verify_input_data_i|input|64|Public key,signature,then context\|\|message frames|
|verify_input_bytes_i|input|4|Valid bytes in the Verify word|
|verify_input_index_i|input|16|Verify word index;restarts at each frame|
|verify_input_last_i|input|1|Last word of the current Verify frame|
|verify_accept_o|output|1|Valid Verify result;qualified by successful completion|
|signature_valid_o|output|1|Signature output word available|
|signature_ready_i|input|1|Host accepts a signature word|
|signature_data_o|output|64|Encoded signature stream|
|signature_bytes_o|output|4|Valid bytes in the signature word|
|signature_index_o|output|10|Signature word index|
|signature_last_o|output|1|Last signature word|
|signature_id_o|output|16|Operation ID on the signature stream|
|done_stage_o|output|3|Completion stage code;see SPECIFICATION.md|
|done_detail_o|output|3|Completion detail code;see SPECIFICATION.md|
|sign_attempts_o|output|17|Signing attempt count|
|sign_rejections_o|output|17|Normal signing rejection count|
|sign_next_nonce_o|output|17|Next signing nonce value|
|done_valid_o|output|1|Completion status available|
|done_ready_i|input|1|Host acknowledges completion|
|done_code_o|output|3|Completion code;0 is normal completion|
|done_id_o|output|16|Completed command identity|
|fault_o|output|1|Fatal controller/service fault|

Internal seed exports,rho/key/rhoprime,row inspection,raw memory readback
and occupancy are not production pins. They remain in dilithium.sv and the
standalone verification benches. The main UVM observes ownership/occupancy
through internal probes;it drives only the real production inputs. Raw-core
read request is tied inactive,row/result and read-response sinks are ready.

### Earlier raw-core interface

The historical sections below also list debug ports of dilithium.sv. They
remain useful for verification and are not additional dilithium_fpga pins.


## Stage5V.4 main Verify host signals

These are RTL/virtual signals,not board package-pin assignments. The existing
Sign stream remains separate;only the selected operation can accept input.

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
|start_op_i|in|2|0 KeyGen,1 Sign,2 Verify,3 unsupported|
|start_param_i|in|2|0/1/2 selects level2/3/5 =ML-DSA-44/65/87|
|start_id_i|in|16|Operation identity,snapshotted at start acceptance|
|start_signature_len_i|in|16|Verify signature bytes;2420/3309/4627 by level|
|start_message_len_i|in|16|Message bytes,excluding context|
|start_context_len_i|in|9|Context bytes<=255;66+context+message must fit65535|
|verify_input_valid_i/ready_o|in/out|1 each|One approved stream for all three Verify frames|
|verify_input_data_i|in|64|Low-byte-first PK,signature,then ctx||M|
|verify_input_bytes_i|in|4|1..8 valid bytes;unused high bytes ignored|
|verify_input_index_i|in|16|Word index restarting0 for every frame|
|verify_input_last_i|in|1|Final word of each frame;empty body needs no beat|
|done_valid_o/ready_i/id_o|out/in|1/1/16|Held completion and acknowledgement|
|done_code_o/stage_o/detail_o|out|3 each|Code0 is a valid/invalid check;nonzero is command/protocol/service error|
|verify_accept_o|out|1|Meaningful with Verify done/code0;1 valid,0 invalid|
|busy_o/fault_o|out|1 each|Active owner/fatal error requiring reset|

Stop offering unused input after an early invalid/error completion. Verify
releases all its regions before done;start_ready waits until every owner is
idle and the services are quiescent. ENABLE_VERIFY=0 disables op2 explicitly.

## Stage5V.3 internal equation interface

No main or package pins change;this client consumes the real prepared context.

| Signals | Direction | Width | Meaning |
|---|---|---:|---|
|command_valid_i/ready_o/id_i|in/out|1/1/16|Start a check;ID must match context|
|context_valid_i/param_i/id_i/regions_i|in|1/2/16/64|Prepared owner valid,level,ID and complete region set|
|context_t1hat_i/hints_i/zhat_i/chat_i|in|8x6/8x6/7x6/6|Region handles for equation and hint reads|
|context_rho_i/mu_i/ctilde_i|in|256/512/512|Original headers;ctilde is zero-extended|
|context_take_valid_o/ready_i|out/in|1 each|Atomic transfer;upstream context may drop afterward|
|done_valid_o/ready_i/id_o/code_o/detail_o|out/in|1/1/16/3/3|Held completion after owned regions are released|
|done_accept_o/done_digest_o|out|1/512|Meaningful only with code0;accept0 is normal invalid signature|
|service_o/service_i|out/in|typed structs|Same shared sampler,NTT,process,pack,raw-hash and memory services|
|busy_o/fault_o|out|1 each|Active owner/fatal error needing reset|

## Stage5V.2b internal math-preparation interface

No main or physical package pins change. The control helper uses typed shared
services and atomically takes the raw context from5V.2a.

| Signals | Direction | Width | Meaning |
|---|---|---:|---|
|command_valid_i/ready_o/id_i/message_len_i/context_len_i|in/out|1/1/16/16/9|New preparation request;ID matches upstream;lengths count bytes|
|context_valid_i/param_i/id_i/regions_i|in|1/2/16/64|Stable upstream raw context until take|
|context_t1_i/hints_i/z_i|in|8x6/8x6/7x6|Original raw region handles|
|context_rho_i/tr_i/ctilde_i|in|256/512/512|Low-byte-first headers;ctilde zero-extended|
|context_take_valid_o/ready_i|out/in|1 each|Atomic transfer of every upstream handle|
|payload_valid_i/ready_o/data_i/bytes_i/index_i/last_i|in/out|1/1/64/4/16/1|Third context-and-message frame;unused high bytes ignored|
|done_valid_o/ready_i/code_o/detail_o/id_o|out/in|1/1/3/3/16|Held preparation status,not final validity|
|result_valid_o/param_o/id_o/regions_o|out|1/2/16/64|Successful arithmetic context only|
|result_t1hat_o/hints_o/zhat_o/chat_o|out|8x6/8x6/7x6/6|Transformed t1,z,c;hints remain raw|
|result_rho_o/mu_o/ctilde_o|out|256/512/512|Headers for matrix expansion and challenge comparison|
|clear_valid_i/ready_o,take_valid_i/ready_o|in/out|1 each|Free/transfer result;clear wins;pending read blocks|
|service_o/service_i|out/in|typed structs|Existing shared engines,allocator and four-bank pool|
|busy_o/fault_o|out|1 each|Active owner;fatal protocol violation requires reset|

## Stage5V.2a internal preparation interface

Main/board ports are unchanged. This is a helper connected to typed shared
services,not a new package-pin assignment or a wired main op2 interface.

| Signals | Direction | Width | Meaning |
|---|---|---:|---|
|command_valid_i/command_ready_o|in/out|1 each|Snapshot new first-two-frame preparation request|
|command_param_i/id_i/signature_len_i/base_i|in|2/16/16/6|Level0/1/2=2/3/5,tag,exact signature bytes,flat region base|
|input_valid_i/ready_o/data_i/bytes_i/index_i/last_i|in/out|1/1/64/4/16/1|PK then signature;byte0 low,index restarts0 per frame|
|done_valid_o/ready_i/code_o/detail_o/id_o|out/in|1/1/3/3/16|Held preparation status;not final Verify verdict|
|context_valid_o/param_o/id_o/regions_o|out|1/2/16/64|Successful retained ownership only|
|context_t1_o/hints_o/z_o|out|8x6/8x6/7x6|Flat region handles;unused entries0|
|context_rho_o/tr_o/ctilde_o|out|256/512/512|Low-byte-first rho,tr and zero-extended ctilde|
|clear_valid_i/ready_o,take_valid_i/ready_o|in/out|1 each|Free or transfer context;clear wins;pending read blocks both|
|service_o/service_i|out/in|typed structs|Same shared Keccak/sampler/NTT/bank/process services|
|busy_o/fault_o|out|1 each|Owner active;fatal protocol fault requires reset|

## Stage5V.1 internal Verify decoder

Main ports are unchanged;the approved three-frame Verify host contract is
recorded in DILITHIUM_PLAN.md and is not wired to op2 yet. New internal signals:

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
|command_kind_i/command_param_i|in|1/2|0 PK,1 signature;level code0/1/2 |
|command_id_i/command_length_i|in|16 each|Operation tag,declared frame byte length |
|input_data_i/bytes_i/index_i/last_i|in|64/4/16/1|Byte0 low;strict ready/valid frame |
|header_data_o/bytes_o/id_o|out|512/7/16|rho or ctilde,zero-extended;independent handshake |
|output_data_o/section_o/poly_o/index_o|out|23/2/3/8|Canonical shifted t1,z or dense hint |
|output_last_poly_o/output_last_frame_o|out|1 each|Tentative polynomial/frame boundaries |
|output_id_o|out|16|Original command ID |
|done_code_o/done_id_o|out|3/16|0 success,1 command,2 signature format/norm,3 transport |

Each command/input/header/coefficient/completion boundary has the usual
valid/ready handshake. These are RTL virtual signals,not FPGA package pins.

Stage5N.4h.7 official-vector testing adds no RTL ports. The90 selected pure
public-API Sign cases use the two-frame interface below;deterministic signing
sets start_rnd_i to zero,randomized signing uses the original prompt rnd.
No selector for prehash or external-mu is implemented by this verification step.

## Stage5N.4h.6 new main Sign ports

These are RTL interface/virtual signals,not physical FPGA package assignments.
Existing KeyGen and debug-memory port widths remain unchanged.

| Main signal | Direction | Bits | Meaning |
|---|---|---:|---|
|start_op_i|in|2|0 KeyGen,1 Sign,2 Verify still unsupported,3 reserved |
|start_message_len_i|in|16|M length in bytes;Sign command metadata |
|start_context_len_i|in|9|Context length0..255;larger values reject |
|start_rnd_i|in|256|Explicit32-byte signing randomness |
|sign_input_valid_i / sign_input_ready_o|in /out|1 each|Approved two-frame input handshake |
|sign_input_data_i|in|64|Byte0 in bits7:0;SK first,then ctx||M |
|sign_input_bytes_i|in|4|8 for every SK word,1..8 for body words |
|sign_input_index_i|in|16|Word index starts0 separately for each frame |
|sign_input_last_i|in|1|Last word of each frame;empty body has no beat |
|signature_valid_o / signature_ready_i|out /in|1 each|Provisional signature stream handshake |
|signature_data_o|out|64|Little-endian byte stream |
|signature_bytes_o|out|4|1..8;final valid bytes4/5/3 by level |
|signature_index_o|out|10|Signature word index from0 |
|signature_last_o / signature_id_o|out|1 /16|Final word and operation ID |
|done_stage_o / done_detail_o|out|3 each|Sign child stage/code;0 for KeyGen/unsupported op |
|sign_attempts_o / sign_rejections_o / sign_next_nonce_o|out|17 each|Attempt/retry counters and flat polynomial nonce |

The existing start_param_i encodes0/1/2 for labels2/3/5. Existing start_seed_i
serves KeyGen;Sign uses its SK input frame. Signature bytes commit only on
matching main code0. Read ready/response-valid are suppressed during Sign.
The top-level parameter ENABLE_SIGN defaults1;FULL_KEYGEN behavior is unchanged.

## Stage5N.4h.5 internal signature encoder ports

No external FPGA/host pin assignments change. These are helper interfaces:

| Group | Width / meaning |
|---|---|
|Command|valid/ready1,param2,output ID16 |
|Accepted source|valid1,source ID16,map64,z7x6,hints8x6,ctilde512,ctilde bytes7 |
|Ownership transfer|source_take valid/ready1;descriptor retained until handshake |
|Signature output|valid/ready1,data64,bytes4,index10,last1,ID16 |
|Completion|valid/ready1,code3,ID16;code0 validates the whole frame |
|Services|Existing request_t/response_t;shared pack command op is now3 bits |
|Control|busy1,fault1,global asynchronous reset;fatal faults require reset |

Final signatures contain2420/3309/4627 bytes at levels2/3/5;last word has4/5/3
valid bytes. A receiver must discard provisional bytes on error/reset.

## Stage5N.4h.4 internal attempt-loop ports

No external host/FPGA pin assignments change.

| Group | Width / purpose |
|---|---|
|Prepared context|valid1,param2,id16,map64,handles23x6,rho256,key256,tr512 |
|Command|valid/ready1,id16,message_len16,context_len9,base6,rnd256,nonce17 |
|Payload|valid/ready1,data64,bytes4,index16,last1;initial ctx||M only |
|Done|valid/ready1,code3,stage3,detail3,id16 |
|Status|attempts17,rejections17,next_nonce17;stable through held done |
|Accepted result|valid1,map64,z7x6,hints8x6,ctilde512,ctilde_bytes7 |
|Retention|clear and take valid/ready1 each;clear priority,pending-read barrier |
|Services|Existing request_t/response_t shared physical datapath |
|Mask-helper retry inputs|retry1,mu512,seed512;normal callers tie allzero |

The command nonce is a flat polynomial nonce. One vector consumes l consecutive
values. Values ending at65536 are legal;starting a vector which would cross
that boundary stops before any16-bit narrowing or sampling request.

## Stage5N.4h.3 internal attempt-check interface

No external host or FPGA pin changes. New helper ports are internal:

| Group | Width / meaning |
|---|---|
|command valid/ready,id|1/1/16;one candidate verdict |
|Prepared-key context|valid1,param2,id16,map64,23x6-bit handles;retained lease |
|Products context|valid1,id16,high_id16,map64,z7x6,low/high/ct0 each8x6 |
|Private headers|mu512,seed512,ctilde512,ctilde_bytes7,next_nonce17 |
|Source take valid/ready|1/1;whole context including private headers |
|done valid/ready,code,detail,id|1/1/3/3/16;actual errors use nonzero code |
|done reject,reason,weight|1/3/12;normal code0 rejection,reason1..4;wide vector weight |
|Retained result|valid1,reject1,map64,z7x6,hints8x6,z_id16 and private headers |
|clear/take valid/ready|1/1 each;quiescent READY,clear priority |
|Shared services|Existing request_t/response_t;no new physical engine interface |

Rejected result maps/handles/ctilde/bytes arezero;only mu/seed/nextnonce remain.
Read SPECIFICATION.md for reason codes and error/ownership semantics.

## Stage5N.4h.2 internal response arithmetic ports

No external main-host or physical/virtual pin assignment changes.

| Port group | Width / purpose |
|---|---|
|Mask take_valid/ready|1/1;READY-only transfer of raw-y ownership AND mu/seed headers |
|command_valid/ready,id|1/1/16;one full arithmetic schedule |
|key_valid,param,id,regions,handles|1/2/16/64/23x6;retained prepared-key lease |
|mask_valid,id,nonce,regions,handles,mu,seed|1/16/16/64/7x6/512/512;raw-y and retry context |
|vector_valid,id,matrix_id,regions,low,high,chat,ctilde,bytes|1/16/16/64/8x6/8x6/6/512/7;retained transformed challenge context |
|mask_take_valid/ready,vector_take_valid/ready|1 each;joined atomic source adoption |
|done_valid/ready,code,detail,id|1/1/3/3/16;held whole schedule result |
|result_valid,regions,z,low,high,ct0|1/64/7x6/8x6/8x6/8x6;complete coefficient-domain vectors |
|result_high_id|16;unchanged w1 metadata ID;other new vectors use done_id |
|result_mu,seed,ctilde,bytes,next_nonce|512/512/512/7/17;retry headers and nonce+l without16-bit wrap |
|clear_valid/ready,take_valid/ready|1 each;release or transfer whole result context |
|service request/response|Unchanged shared physical engine/bank records |

## Stage5N.4h.1 internal ownership/transform ports

No main host port or FPGA package/virtual-pin assignment changes.

| Port group | Width / purpose |
|---|---|
|Matrix/challenge take_valid/ready|1/1 each;READY-only ownership transfer,no physical release;clear priority |
|Transform command_valid/ready,id|1/1/16;one atomic adoption/reuse/FNTT schedule |
|key_valid,mask_valid,param,key_id,mask_id|1/1/2/16/16;retained upstream leases |
|key_regions,mask_regions|64 each;protected sources |
|matrix_valid,id,regions,yhat,low,high|1/16/64/7x6/8x6/8x6;whole retained matrix result |
|challenge_valid,id,region,bytes,ctilde|1/16/6/7/512;complete coefficient-domain c and challenge seed |
|matrix_take_valid/ready,challenge_take_valid/ready|1 each;atomic joined source handoff |
|done_valid/ready,code,detail,id|1/1/3/3/16;held completion |
|result_valid,regions,low,high,matrix_id|1/64/8x6/8x6/16;retained low/high handles with original ID |
|result_chat,ctilde,bytes|6/512/7;new NTT-domain c handle and seed |
|clear_valid/ready,take_valid/ready|1 each;release or transfer the complete new context |
|service request/response|Unchanged records and physical engines/banks |

## Stage5N.4g internal challenge client

These internal ports do not change the main host interface or package pins.

| Port group | Width / purpose |
|---|---|
|command_valid/ready,id|1/1/16;start one challenge schedule |
|context_valid,param,id|1/2/16;retained matrix-result lease |
|context_regions,context_high|64/8x6;protected source map and ordered w1 handles |
|context_mu|512;64-byte message representative |
|done_valid/ready,code,detail,id|1/1/3/3/16;held result and rejection detail |
|result_valid,ctilde,bytes,region|1/512/7/6;whole challenge publication,unused digest bits zero |
|clear_valid/ready,busy,fault|1/1/1/1;retention,consumer drain and global-reset requirement |
|service request/response|Existing shared records;no physical interface expansion |

Bitpkg retains its existing2-bit operation field;op3 now means w1 packing.
This replaces the formerly reserved opcode. Invalid parameter3 still rejects.

## Stage5N.4f internal matrix client ports

No main dilithium.sv external port or Quartus virtual-pin assignment changes.
These are internal controller connections in the focused integration harness;
they are not FPGA package pins or a completed main Sign host interface.

| Port group | Width / purpose |
|---|---|
|command_valid/ready,id|1/1/16;start one yhat/A*y/decomposition schedule |
|context_valid,param,id|1/2/16;retained prepared-key lease |
|context_regions,rho|64/256;protected key regions and public matrix seed |
|mask_valid,id,regions,handles|1/16/64/7x6;retained coefficient-domain y |
|done_valid/ready,code,detail,id|1/1/3/3/16;held parent completion and child rejection detail |
|result_valid,regions|1/64;whole validated new vector publication |
|result_yhat|7x6;used entries l=4/5/7,unused entries zero |
|result_low,result_high|8x6 each;used entries k=4/6/8,unused entries zero |
|clear_valid/ready|1/1;release this client's results after consumer retirement |
|busy,fault|1/1;exclusive client lifetime,global-reset requirement |
|service request/response|Unchanged dilithium_service_pkg records,one physical services tree |

The preceding internal sign_mask_prepare client accepts command ID16,
message length16,context length9,nonce16,base6,rnd256;streams payload
64/bytes4/index16/last1;publishes mu512,seed512,regions64 and7x6 handles.
It receives retained key K256/tr512 plus valid/level/ID/region metadata.
Both clients keep results private until whole-command success and retain them
through READY. The outer owner must protect the key,y and all leased workspace
from unrelated clients across child handoffs. Clear never authorizes a host
to read secret polynomial storage.

## Stage5N.4d internal key-preparation client ports

No main dilithium.sv external port or virtual-pin change. The new helper is
tested at the shared-services operation-owner boundary.

| Port group | Width / purpose |
|---|---|
|command_param/id/base/work|2/16/6/6;level,key owner,raw plan,initial spare region |
|input_data/bytes/index/last|64/4/10/1;expanded-key stream |
|done_code/detail/id|3/3/16;parent result and child error detail |
|context_valid/param/id|1/2/16;retained validated key metadata |
|context_regions/handles|64 /23 x6;NTT-domain locations in polynomial order |
|context_rho/key/tr|256/256/512;retained header |
|clear_valid/ready|1/1;invalidate context and start release;busy=0 ends cleanup |
|busy/service_active/fault|1 each;outer key lease,preparation service grant,fatal reset requirement |
|service request/response|Existing packed service records;one physical engine/bank tree |

Only the outer operation owner may route privileged consumer requests while
the context is retained. It blocks unrelated host access and stops new
consumer requests when clearing;existing responses can still drain.

## Stage5N.4c2 production internal service record

No dilithium.sv external port or virtual-pin assignment changes. The loader
ports listed below now route through request_t.load/response_t.load in the
existing services tree. KeyGen drives load='0. The record carries the same
64-bit key input,byte/index/last framing,validated header/region outputs and
held done handshake;it adds no physical memory or host interface.
LOAD_SERVICE enables this client in production services;older focused row/
bank benches explicitly tie the new request to zero.

## Stage5N.4c1 internal key-loader interface

No external dilithium.sv port or virtual-pin assignment changes. This client
is not yet connected to the production shared-service tree.

| Internal port group | Width / purpose |
|---|---|
|command_param/id/base|2/16/6;level,key owner,first flat region |
|input_data/bytes/index/last|64/4/10/1;existing expanded-key framing |
|done_code/id/regions|3/16/64;whole-key outcome and validated locations |
|header_rho/key/tr|256/256/512;valid only during successful held done |
|reserved / release_locks / hidden|64 each;availability,owner protection,privacy |
|alloc_region/id/mode/param|6/16/2/2;existing core0 memory allocation |
|write_data/index/id/last|23/8/16/1;canonical natural-order scalar writes |
|finish_id/code|16/3;commit after ACKs or discard partial |
|release_region|6;rollback earlier polynomial commits |

Each transfer uses valid/ready. Busy owns the memory-client lease through held
done. Internal fault halts until reset. See SPECIFICATION.md for error codes.

## Stage5N.4b signing formatter ports

No dilithium.sv external-port or virtual-pin changes. sign_hash_message exposes
internal command fields,64-bit payload and absorption streams,and held
descriptor/completion;all widths are in SPECIFICATION.md. The prepared Quartus
source list adds the formatter;the selected top/6.757ns SDC are unchanged.
No new synthesis/fit or placement claim.

## Stage5N.4a key-decoder interface

No main dilithium.sv external-port/virtual-pin changes. Standalone
sign_key_decode.sv uses64-bit indexed input words,one1024-bit held header and
tagged23-bit coefficient output,with a held completion. Full widths and
error codes are in SPECIFICATION.md. The prepared Quartus file list includes
the decoder;the selected top and6.757ns SDC are unchanged. No fresh fit.

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
