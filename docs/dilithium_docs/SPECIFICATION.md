# Current Dilithium specification

## Algorithm and parameters

The core implements final FIPS 204 ML-DSA using level names 2/3/5. Both
external pure-message and internal already-formatted message APIs are supported.
The core computes mu internally in either case. HashML-DSA prehash and
externally supplied mu are outside the implemented interface.

| Quantity | Level 2 / ML-DSA-44 | Level 3 / ML-DSA-65 | Level 5 / ML-DSA-87 |
|---|---:|---:|---:|
| Polynomial degree N | 256 | 256 | 256 |
| Modulus q | 8,380,417 | 8,380,417 | 8,380,417 |
| Matrix rows k | 4 | 6 | 8 |
| Matrix columns l | 4 | 5 | 7 |
| eta | 2 | 4 | 2 |
| Challenge weight tau | 39 | 49 | 60 |
| Hint bound omega | 80 | 55 | 75 |
| Public-key bytes | 1,312 | 1,952 | 2,592 |
| Secret-key bytes | 2,560 | 4,032 | 4,896 |
| Signature bytes | 2,420 | 3,309 | 4,627 |

## Command interface

Production top: `src/controller/dilithium_fpga.sv`. A command is accepted on a
rising clock edge with `start_valid_i && start_ready_o`. Hold command fields
stable until acceptance. Only one public operation runs at a time.

| Field | Meaning |
|---|---|
| `start_op_i` | 0 KeyGen; 1 Sign; 2 Verify; 3 invalid |
| `start_param_i` | 0 level 2; 1 level 3; 2 level 5; 3 invalid |
| `start_id_i` | 16-bit caller job identity, returned with output/completion |
| `start_seed_i` | 32-byte KeyGen seed |
| `start_rnd_i` | 32-byte signing randomness; zeros for deterministic signing |
| `start_context_len_i` | Separate context bytes, 0..255 in external mode |
| `start_message_len_i` | Message byte count within the implemented length bounds |
| `start_internal_message_i` | 0 original message/context; 1 already formatted message |
| `start_signature_len_i` | Signature frame length supplied for Verify |

The message formatting length must fit 65,535 bytes. Internal mode requires
separate context length zero and hashes `tr || Mprime`. External mode hashes
`tr || 0x00 || context_length_byte || context || message`. The 64-byte tr
is included in the internal length check; external formatting includes its
two-byte prefix as well. Changing public fields after acceptance must not
alter the active command.

## Input and output frames

| Operation | Inputs after command | Result |
|---|---|---|
| KeyGen | Seed is in the command; no streamed input frame | Public-key frame then secret-key frame |
| Sign | Expanded secret-key frame, then context followed by message | Encoded signature frame |
| Verify | Public-key frame, signature frame, then context followed by message | Normal valid/invalid completion or input/error completion |

Input streams carry 64-bit data, valid, ready, byte count, word index and last.
Each frame starts at word index zero. The lower byte lanes contain the earliest
bytes, and byte count selects the meaningful lanes. Internal-mode final frames
contain Mprime alone. Empty bodies use the command's zero length; no fabricated
payload word is required. Frame lengths, IDs where applicable, indexes and last
markers are checked by the receiving path.

Key/signature output streams use the same 64-bit byte packing. Key type zero
means public key; one means secret key. Index restarts for each key frame.
On stalled valid output, data and metadata must remain stable until accepted.

## Completion, errors and reset

Consume completion with `done_valid_o && done_ready_i`. `done_code_o == 0`
means normal completion. For Verify, inspect `verify_accept_o` only with that
successful completion: false can be a normal invalid signature, not a hardware
failure. Nonzero code plus stage/detail identifies the selected controller's
command, input, arithmetic or publication failure. These encodings are defined
by the current child controller RTL; they are not one interchangeable enum.

Sign exposes attempts, rejections and next nonce for the active operation.
Reset is active high. It flushes control/queue validity and ownership; coefficient
RAM payload is not bulk-cleared. Consumers may use only newly qualified data.
Fatal physical/control faults suppress publication and new commands until reset.

## Physical and acceptance constraints

Target device: Cyclone V 5CGXFC7C7F23C8. The production constraint is 6.500 ns
with unchanged hold requirements and multicorner analysis. Production nonclock
ports are virtual, so board I/O timing and pin assignments remain open.
The current seed-1 fit measures a worst-corner Fmax of 97.10 MHz with
33,909 placed ALMs, 59 M10Ks and eight DSP blocks. At 6.500 ns, worst setup
slack is -3.799 ns, worst setup TNS is -37,243.049 ns, and minimum hold
slack is +0.083 ns. Hold TNS is zero at all four corners. Setup closure and
board validation remain open.
See [PIN_CONFIG.md](PIN_CONFIG.md) and
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).
