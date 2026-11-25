# Current production ports and virtual pins

The production boundary is `src/controller/dilithium_fpga.sv`, which instantiates
`dilithium`. There are 52 signal groups / 1028 bits including clock. The 1027
nonclock bits use virtual-pin assignments in the production Quartus project.
Clock is a real input; no board-specific package location is assigned here.
These are interface counts, not FPGA resource counts.

The synthesis target is 6.500 ns on Cyclone V 5CGXFC7C7F23C8, with unchanged
hold constraints. Current-source physical timing is not yet qualified.
A virtual-pin project is not a complete on-board wiring/host interface.

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

|clk|input|1|Core clock;6.500 ns synthesis target|

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

|start_internal_message_i|input|1|0 original message+context (default);1 already formatted Mprime,requires separate context length0|

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



## How to operate the ports

Present command fields until `start_valid_i && start_ready_o` on a rising edge.
For Sign, send expanded SK then the body on the Sign stream. For Verify, send
PK, signature then the body on the Verify stream. Each frame restarts its word
index at zero and ends with last; bytes gives the meaningful low byte lanes.
External body is context followed by message. Internal body is Mprime alone
and requires zero separate context length.

Consume key/signature output only when valid and ready. Key type zero is PK,
one is SK; index restarts for each key frame. Preserve output readiness or
accept the resulting backpressure. Consume final status with done valid/ready;
Verify accept is meaningful only with normal successful completion.

`start_seed_i` and `start_rnd_i` are packed 32-byte inputs. Software/NIST byte
zero maps to the least-significant byte lane; the vector text prints these
packed values as little-endian integers. Stream data uses the same low-byte-first
lane convention. Reset is active high and clears command/queue ownership.

The wrapper exports no raw coefficient memory/debug interface. UVM observes
internal ownership/engine activity through probes while driving the production
ports. See [SPECIFICATION.md](SPECIFICATION.md) for command limits and framing,
and [OUTPUT_SIM_COMAPRE.md](OUTPUT_SIM_COMAPRE.md) for simulation commands.
