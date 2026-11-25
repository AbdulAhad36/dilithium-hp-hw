# Verifier UVM verification plan

## 1. Purpose and scope

Verify the complete production Verify operation, including public-key hashing,
signature decoding, message formatting, the verification equation, hint use,
challenge comparison, early rejection and physical resource retirement.
User-facing levels 2/3/5 are final ML-DSA-44/65/87. Cover external pure-message
and internal Mprime interfaces. Both compute mu internally; prehash/HashML-DSA
and externally supplied mu have no implemented selector and remain outside
functional acceptance for this interface.

This is a proposed verification specification, not evidence that its sequences,
covergroups or assertions already exist or passed. Exhaust finite encoding and
control spaces where practical; cover large cryptographic spaces through
independent references, directed boundaries and reproducible random testing.
No finite simulation campaign proves all possible public keys/signatures.

Use [final FIPS 204](https://csrc.nist.gov/pubs/fips/204/final) as the algorithm
authority. Related plans: [KeyGen](KEYGEN_VERIFICATION_PLAN.md) and
[Sign](SIGN_VERIFICATION_PLAN.md). Shared contracts are in
[SPECIFICATION](dilithium_docs/SPECIFICATION.md),
[MEMORY_MAP](dilithium_docs/MEMORY_MAP.md),
[PROCESS_BLOCKS](dilithium_docs/PROCESS_BLOCKS.md) and
[COVERAGE](dilithium_docs/COVERAGE.md).

## 2. Implementation and independent reference map

| Area | Files / observation point |
|---|---|
| Public interface and root ownership | `../src/controller/{dilithium_fpga,dilithium}.sv` |
| Verify schedule and digest comparison | `../src/controller/verify.sv` |
| Public-key/signature framing and early rejection | `../src/controller/verify_input.sv` |
| Message formatter and binary codecs | `../src/controller/process/{sign_hash_message,bitunpkg,bitpkg,hint_codec}.sv` |
| Norm / UseHint / decomposition | `../src/controller/process/{poly_process,cnb}.sv` |
| Shared engine requests and adaptation | `../src/controller/helpers/dilithium_pkg.sv`, `../src/controller/datapath/` |
| Physical storage, port ownership and queues | `../src/controller/memory/` |
| Arithmetic, SHAKE and challenge sampler | `../src/ntt/`, `../src/keccak/`, `../src/sampler/` |
| Main UVM components | `../tb_uvm/tb_uvm_dilithium/` |
| Independent reference | `../dilithium-sw-model/golden/{golden.py,bridge.c}`, `../dilithium-sw-model/ref/` |
| Published cases | `../NIST/ML-DSA-sigVer-FIPS204/{prompt.json,expectedResults.json,provenance.json}` |
| Current capture/vector utilities | `../tb/tb_dilithium/tb_main.sv`, `../sim/dilithium/dilithium_vectors.py` |

Use the full existing UVM environment. Extend it with missing message-mode,
malformed-beat and expected-fault support, and independent internal-event
observations. The normal monitor presently treats a DUT fault as an unexpected
test failure; a fault-injection campaign needs an explicit expected-fault
policy and quarantine checker. Do not simply switch those checks off.

## 3. Parameters and public protocol

All sets use N=256, q=8,380,417 and d=13. Define centered(x) explicitly in
the reference adapter for canonical 0<=x<q, and convert NTT/Montgomery ordering
and scaling before comparing intermediate polynomials.

| Quantity | Level 2 | Level 3 | Level 5 |
|---|---:|---:|---:|
| `start_param_i` | 0 | 1 | 2 |
| k / l | 4 / 4 | 6 / 5 | 8 / 7 |
| tau | 39 | 49 | 60 |
| gamma1 | 131072 | 524288 | 524288 |
| beta | 78 | 196 | 120 |
| Strict z norm bound | 130994 | 524092 | 524168 |
| gamma2 / high-part modulus | 95232 / 44 | 261888 / 16 | 261888 / 16 |
| Hint weight bound omega | 80 | 55 | 75 |
| Public-key bytes / beats | 1312 / 164 | 1952 / 244 | 2592 / 324 |
| Signature bytes / beats | 2420 / 303 | 3309 / 414 | 4627 / 579 |
| Final signature input bytes | 4 | 5 | 3 |
| ctilde bytes / 64-bit words | 32 / 4 | 48 / 6 | 64 / 8 |
| Packed z polynomial bytes | 576 | 640 | 640 |
| Hint suffix bytes | 84 | 61 | 83 |
| Reconstructed packed w1 bytes | 768 | 768 | 1024 |

Accept `start_op_i=2` only on `start_valid_i && start_ready_o`. Latch level,
ID, body/context lengths, internal-message mode and signature length. Host
provides exactly three sequential frames on the Verify stream: public key,
signature, then context||message (external) or Mprime (internal). Each frame
starts at word index zero; lowest byte lane is earliest. A zero-length final
body has no input beat. Public-key size follows the level, not a separate
host-supplied length field. `start_signature_len_i` must match the fixed size.

External mu input is tr || 0x00 || ctxlen-byte || context || message, with
ctxlen<=255 and 66+ctxlen+mlen<=65535. Internal mu input is tr || Mprime, with
separate ctxlen=0 and 64+mlen<=65535. The hash is SHAKE256, not SHA-256.
Changing command fields after acceptance cannot change the active operation.

Verify produces no public key or encoded signature stream. Inspect
`verify_accept_o` only with a normal completion (`done_valid_o`, code0);
consume the result at done valid && ready. Do not interpret its idle value as
a verification result. Completion fields must remain stable under backpressure.

## 4. Outcome classification: required scoreboard distinction

| Outcome | Public expectation | Required checking |
|---|---|---|
| Valid signature | code0, accept1 | Exact input identity, all required equation/hash work and clean retirement. |
| Cryptographically invalid signature | code0, accept0 | Independent false verdict; mismatch/early-reject reason observed; no physical fault. |
| Structural signature invalidity | Normally code0, accept0 for wrong declared signature length, z norm rejection or canonical hint failure represented by input code2 | Check current `verify_input` to `verify` mapping, not an invented universal nonzero error. |
| Command invalid | code1 | Invalid level/context/total formatted length; no crypto publication or unowned work. Root opcode3 uses code2. |
| Transport / load input failure | code3, stage1, detail from input helper | Accepted malformed prefix and bounded cleanup checked independently. |
| Formatter error | code4, stage2, formatter detail | Message hash is discarded and finite work drained. |
| Helper identity error | code6, stage1 in its specific controller path | Expected-injection check of the precise source condition; distinct from fatal physical identity errors. |
| Fatal service/ownership fault | fault/quarantine; normal public completion suppressed | No new admission or output until reset; no false normal-invalid credit. |
| Reset abort | No completed crypto result | Canceled pending expectations and checked recovery; never counted as a valid/invalid signature result. |

Check exact status and detection priority against source for compound faults.
For example, a decoder transport failure can take a different path from an
ordered-hint canonicality failure even though both are negative inputs.

A structurally invalid signature may return before the body or even all
signature words have been accepted. The driver must stop sending that canceled
frame when completion/reset/fault terminates it. The scoreboard checks the
**actual accepted prefix** and the documented early rejection; it must not
require three complete frames on every negative case. No DUT autonomous
timeout is assumed for a source that stops supplying required data.

## 5. Independent checking architecture

Keep the existing sequencer/driver/monitor/scoreboard/coverage separation.
Monitor real accepted handshakes, including the full four-state values before
transaction conversion. Use an independently compiled C verifier for custom
and mutated cases and NIST's expected verdict for published cases. Successful
Sign -> Verify round trips are supplemental and cannot be the sole oracle:
two RTL paths could share the same error.

| Checkpoint | Required independent result |
|---|---|
| pk parse | Decode rho and k complete 10-bit t1 polynomials, with correct bit order. Every 10-bit t1 value is representable; a changed encoded pk is not automatically a framing error. |
| tr | SHAKE256 of the complete encoded public-key bytes, output64 bytes; model uses observed accepted pk bytes and fixed descriptor length. |
| Signature parse | Exact ctilde length, l z polynomials and omega+k hint suffix, including global frame offsets and tail masking. |
| z range | Centered infinity norm strictly below gamma1-beta. Equality rejects normally; separate noncanonical internal arithmetic faults. |
| Hint decode | Independent byte parser checks cumulative counts, strict per-row index order, total<=omega and zero unused index padding; compare all reconstructed hint bits. |
| mu | SHAKE256 of the exact tr and mode-specific formatted body, output64 bytes. |
| Challenge | Independent SampleInBall(ctilde), exactly tau signed nonzeros; then independent NTT. |
| Inputs to equation | Compare zhat and NTT(t1*8192), with correct ordering/scale. Maximum t1=1023 shifts to q-1 and is still canonical. |
| Row equation | Reconstruct inverse NTT(Ahat*zhat - c_hat*NTT(t1*8192)), with l MAC terms and one correct subtraction per row. |
| UseHint | Independently apply the reference hint definition to each coefficient; compare high-part wrap modulo44 or16 and every recovered w1 coefficient. |
| Re-encoding | Compare complete independent packed w1, correct row and byte order, total768/768/1024 bytes. |
| Final challenge hash | SHAKE256(mu \|\| packed w1), correct32/48/64-byte ctilde length; compare every meaningful byte against the signature. |
| Verdict / retirement | True only after all validation and complete comparison; false reason appropriate; no live physical work at published completion. |
| Storage | Versioned physical-commit shadow memory, ownership and live-role lifetimes, including clearing/rebuilding the hint-mask cache. |

Reference trace intermediates are not official NIST intermediate vectors.
Store enough trace to explain the first divergence. Never derive the expected
verdict by copying `verify_accept_o`, nor accept digest equality without first
checking parsing, norm/hints, lengths and input identity.

## 6. UVM infrastructure needed

| Extension | Requirement |
|---|---|
| Mode-aware transaction/interface/driver/monitor/scoreboard | Add `start_internal_message_i` throughout; match accepted mode and distinguish body versus Mprime lengths. |
| Full sigVer corpus import | Discover supported groups, preserve original tgId/tcId, expected boolean and source identity; do not silently keep only a small fixture subset. |
| Programmable beat programs | Mutate framing fields and payload independently, and stop legal driving on early termination; preserve precise consumed-prefix expectations. |
| Independent parser and arithmetic analysis | Observe hash inputs/output lengths, service IDs, norm results, hints, equation rows and actual memory commits through verification-only observations. |
| Error/reset/fault outcome records | Credit checked aborts, expected faults and normal invalid verdicts separately, each with its own checker. |
| Phase/occupancy-directed stress | Trigger stalls/reset on observed events and buffer state, not a fixed unqualified cycle count. |
| Checker self-test configuration | Corrupt one observed/expected field in isolated expected-failure runs; no clean-coverage merge. |
| Dynamic finite liveness budget | Fairness-based watchdog large enough for legal maximum body and worst documented stalls; identify the stuck service, not merely a global timeout. |

The current UVM monitor exposes aggregate hash/NTT/Process activity and memory
ownership, not every algorithm checkpoint. Add analysis observations and
checkers without changing production pins. Names below are proposed test
families; they are not automatically existing runnable test classes.

## 7. Required test families

### 7.1 Published cases, commands and message formatting

| ID | Stimulus | Pass conditions |
|---|---|---|
| VF-C01 | Every supported NIST sigVer case, all levels/modes | Exact published verdict and original case identity; valid and invalid populations accounted for independently. |
| VF-C02 | Independent C-generated key/signature/message/context/rnd cases | Correct verdict without depending on RTL Sign as the oracle. |
| VF-C03 | RTL-generated keys/signatures checked by C and RTL Verify | Positive interoperability, full Verify input checking and correct normal completion. |
| VF-C04 | Same case under varied stalls, repeated IDs and alternating levels | Same verdict/intermediate equation, no stale result or cross-job state. |
| VF-C05 | IDs0/1/0x7fff/0x8000/0xfffe/0xffff and child-offset wrap neighborhoods | Exact owner/response identity and no stale ID matching. |
| VF-C06 | Busy start pulses, held start and field mutation after acceptance | Only ready handshakes accepted; accepted level/mode/lengths remain latched. |
| VF-C07 | Invalid level3, root opcode3, invalid context or formatted-length overflow | Correct command status, no false normal-invalid success and no leaked service work. |
| VF-C08 | Context0..255 and message0,1..9,15..17,31..33,63..65,135..137,167..169 | Correct exact mu stream, empty-body handling and all byte tails. |
| VF-C09 | Formatted SHAKE256 total lengths135/136/137,271/272/273 and multiblock messages | Correct rate-boundary padding and domain suffix, including context contribution. |
| VF-C10 | Maximum external mlen65469-ctxlen and internal mlen65471, plus +/-1 | Correct boundary acceptance and no arithmetic wrap. |
| VF-C11 | Internal empty/arbitrary Mprime, all tails and nonzero separate context | Exact internal input when legal; reject separate context; no duplicate external prefix. |
| VF-C12 | Paired external(ctx,M) and internal(0x00\|\|len(ctx)\|\|ctx\|\|M) | Same mu and verdict for the same pk/signature. |
| VF-C13 | Changed mode/body/context with reference-selected expected false cases | Normal invalid verdict when equation differs; no heuristic content-based mode detection. |
| VF-C14 | Toggle seed/rnd/key-ready/signature-ready and inactive Sign input | Verify has no dependence on irrelevant command/output channels and grants no Sign input credit. |

### 7.2 Public-key transport and its hash/decode fork

| ID | Stimulus | Pass conditions |
|---|---|---|
| VF-P01 | First/last rho byte and each t1 polynomial boundary | Full independent pk parsing, correct destinations and field offset. |
| VF-P02 | t1 values0/1/1022/1023 and all10-bit packing crossings in focused UVM input tests | Correct decode and *8192 shift, including q-1; all lanes checked. |
| VF-P03 | Incorrect pk frame last/index/count at first/interior/final beat | Transport error with exact prefix, finite hash/load cleanup and no normal accept. |
| VF-P04 | Wrong-level pk length or extra offered words | No silent truncation/shift into signature frame; expected framing outcome. No separate pk-length pin is invented. |
| VF-P05 | Hash sink ready/load stalled; load ready/hash stalled; both stalled | Each pk word consumed once by each required sink; no duplicate hash bytes or source advancement before both credits. |
| VF-P06 | Fork release order reversed on final pk word | Hash and decoder completions may reorder; no publication until both retire. |
| VF-P07 | Raw tr result arrives before/after final load retirement | Correct tr capture and ID/core association; no overwrite before formatter prefix consumption. |
| VF-P08 | Public-key byte mutations and bit changes in every header/t1 field class | Compare C verdict; distinguish valid binary encoding from wrong cryptographic key. |
| VF-P09 | Missing pk data then resume/reset | Safety during the wait and correct continuation/recovery; no assumed automatic hardware timeout. |

### 7.3 Signature parsing, z norms and canonical hints

| ID | Stimulus | Pass conditions |
|---|---|---|
| VF-S01 | Declared signature length0,1,exact-1,exact,exact+1,65535 | Only exact length proceeds as a valid-size signature; wrong length produces documented normal invalid result and early clean completion. |
| VF-S02 | ctilde/z/hint boundaries, first/last z polynomial and full-frame index continuity | Correct offsets; only new frame restarts index0. |
| VF-S03 | Final signature tails4/5/3 with poisoned high unused input bytes | Ignore invalid lanes, validate meaningful count/last and no high-lane leakage into hints. |
| VF-S04 | Wrong count0..15, early/missing/late last, repeated/skipped/swapped index | Exact transport outcome and cleanup, not mislabeled cryptographic mismatch. |
| VF-S05 | Truncated signature, trailing offered words and absent body after early rejection | No credit for unaccepted data; legal early termination leaves no stale response/owner. |
| VF-Z01 | z=0, +/-1, signed extrema and all 18/20-bit field crossings | Independent decode to canonical/centered representation in every lane. |
| VF-Z02 | abs(z)=B-1,B,B+1, both signs, all lanes and polynomial boundaries | B=gamma1-beta strict; equality normally invalid; no incorrect sign/absolute-value comparison. |
| VF-Z03 | One offending coefficient in first/middle/last word and first/last polynomial | Whole-vector norm reduction catches every position; early stop cannot accept. |
| VF-Z04 | Multiple offending z coefficients with later malformed hints | Correct first detected outcome; no requirement to consume later frames after legitimate rejection. |
| VF-H01 | Valid empty hints, one hint, omega-1 and omega hints | All reconstructed bits, row counts and unused zero padding exact. |
| VF-H02 | Hint index0 and255, first/last row, each of256 coefficient coordinates | Every legal location decoded correctly. Use focused canonical suffixes and/or independent full-case verdicts; arbitrary hints need not make a valid signature. |
| VF-H03 | Repeated row counts and empty interior/first/final rows | Equal cumulative counts are legal for empty rows; no accidental duplicate-index rejection across rows. |
| VF-H04 | Identical coefficient index in different rows | Legal canonical row separation; same index twice within one row remains invalid. |
| VF-H05 | Descending or duplicate indices within a row, including initial zero | Reject all non-strict row orders; a first index0 is legal. |
| VF-H06 | Decreasing cumulative count, count>omega, invalid final count | Canonical rejection before using invalid masks; no memory out-of-bounds access. |
| VF-H07 | Total count omega+1 and high count-byte values up to255 | Reject weight/count overflow without counter truncation. |
| VF-H08 | One nonzero byte anywhere in unused index padding | Canonical rejection even if used indices/counts are otherwise valid. Distinguish padding zero from a used coefficient index0. |
| VF-H09 | Canonical fault at first/middle/last row or final padding byte | No acceptance or premature valid mask publication before canonical validation. |
| VF-H10 | All four-bit lane masks0..15 and all row/word boundaries in focused codec UVM | Correct bit positions, four-lane grouping and output tags. |
| VF-H11 | Maximum-density suffix and repeated decode jobs across levels5->2->5 | Old hint cache bits/unused rows never gain validity; correct clear/insert/drain ordering. |
| VF-H12 | Reset/stall during count/order/padding/cache insert/mask emission | No incomplete validation becomes a published valid hint polynomial; post-reset recovery independent of stale cache RAM. |

Hint indices are bytes: values greater than255 cannot be represented on that
interface and must not become fake coverage bins. t1 has no unused 10-bit
patterns. All z packed bit patterns decode to a value; use norm checks to
classify forbidden magnitudes rather than inventing binary padding errors.

### 7.4 Verification equation and final comparison

| ID | Stimulus / checkpoint | Pass conditions |
|---|---|---|
| VF-A01 | Full pk hash and both message modes | tr and mu exact64-byte results, correct finite raw output counts/IDs/core. |
| VF-A02 | Challenge SampleInBall with first/last sign and position bytes, rejected candidates and SHAKE boundaries | Exactly tau unique +/-1 entries, correct full polynomial and transform. |
| VF-A03 | Each z and shifted-t1 transform at every level | Correct index, storage, normalization and domain; no secret Pre-NTT mode applied to general z/t1 operands. |
| VF-A04 | Every Ahat row/column, first/final sampled coefficient and all ring wraps | Correct rho/coordinate suffix and no A/z/t1/challenge mixing. |
| VF-A05 | First/intermediate/final matrix MAC term for each row | Initialize only first term, sum exactly l terms and preserve accumulator ownership. |
| VF-A06 | Challenge*t1 term and subtraction with zero/wrap/equal operands | Correct sign, *8192 placement, one subtraction and modular reduction. |
| VF-A07 | Inverse transform and row reconstruction | Exact coefficient polynomial and scaling, not only final digest agreement. |
| VF-A08 | UseHint with h0/h1, low<0/0/>0, high0/max and wrap neighbors | Correct high-part correction modulo44/16; independently test every lane. |
| VF-A09 | Decompose/UseHint at +/-gamma2, multiples of2*gamma2,0,q-1 and exceptional wrap | Correct reference tie conventions and canonical output range. |
| VF-A10 | Reconstructed w1 at every row/word boundary | Exact independent polynomial and packed768/768/1024-byte stream. |
| VF-A11 | Challenge hash mu/w1 boundary, rate crossings, first/final output beats | Correct SHAKE input/output length and no stale prefix, duplicate or omitted byte. |
| VF-D01 | Digest equal in every meaningful byte | Accept only after all structural/norm/hint/equation conditions passed and resources retired. |
| VF-D02 | Mismatch in each ctilde byte individually, across all32/48/64 positions | No prefix-only or low-word-only comparison; normal invalid result. |
| VF-D03 | Matching prefix with mismatch in last meaningful byte/word/128-bit beat | Detect last-byte difference at every level, particularly level5 upper digest half. |
| VF-D04 | Multiple separated mismatches and all-zero/all-one comparison operands in focused comparison UVM | Full compare reduction correct; injected compare operands are classified as focused control/arithmetic proof. |
| VF-D05 | Distinct wrong key/message/context/signature, each field's single-bit/burst mutation | Verdict matches independent C; no blanket assumption that every mutation is malformed transport. |
| VF-D06 | Normal invalid after completing the equation versus early structural/norm rejection | Separate observed reasons, consumed input, digest availability and latency classes. Do not require an equation digest for a case that legally never computes it. |

### 7.5 Shared memory, transport, reset, faults and operation reuse

| ID | Stimulus / checkpoint | Pass conditions |
|---|---|---|
| VF-M01 | Every role/bank/base/count and all four coefficient lanes | Actual committed data and read addresses match the fixed-role schedule and reference. |
| VF-M02 | Bank0 shifted t1, bank2 z/zhat and cached challenge, bank1 decoded hints/reconstructed w1 | No premature lifetime reuse or format confusion; decoded hints remain tied to the same signature. |
| VF-M03 | A ring producer/consumer imbalance, full/wrap, one/two active hash contexts | Correct per-core isolation, bounded credits and safe slot reuse. |
| VF-M04 | A/B conflicts, independent banks, full queues, stalled read skid and split same-owner renewals | Physical commitment ordering, atomic ownership and no response drop or stolen reservation. |
| VF-M05 | Dirty memory/hint cache, repeated ID and level changes after invalid signature | Next job cannot read stale z, challenge, w1 or hint-mask validity. |
| VF-T01 | Input gaps at every frame/component boundary; independent hash/load/memory stalls | Accepted byte stream unchanged and eventually completes under bounded readiness. |
| VF-T02 | Hold done ready low for valid, invalid and command/input errors | Stable verdict/ID/code/stage/detail; no new acceptance or change in outcome. |
| VF-T03 | Missing input/service response or indefinitely stalled sink | No fake accept; fairness assumptions and simulation watchdog explicit. Resume/reset verifies recovery. |
| VF-T04 | Garbage/unqualified X on inactive inputs versus X/Z in accepted controls/data | Ignore irrelevant values; qualified unknowns are detected before two-state conversion. |
| VF-T05 | Completion and next start offered on adjacent legal edges | No overlap, duplicate completion or lost second command; obey actual root retirement capacity. |
| VF-R01 | Reset at every phase listed below, all levels/modes | Cancel ownership/control, invalidate queued work and any pending verdict; no assumption that RAM payload was cleared. |
| VF-R02 | Reset on start/input/response/completion handshake, while one/both cores busy | Defined reset priority and no response from a canceled command credited afterward. |
| VF-R03 | Reset after partial signature parse, early invalid result or held completion | No false success and clean same-ID/new-data recovery. |
| VF-R04 | Good case following every malformed/invalid/reset case | Independent true or false result as appropriate; no persistent owner or hint ready/drain deadlock. |
| VF-F01 | Wrong/stale/duplicate raw/sample/load/hint IDs or core tags | Correct controller error versus fatal classification, exactly once; no false normal invalid. |
| VF-F02 | NTT/Process nonzero status, noncanonical service coefficient, memory error/collision | Immediate fatal quarantine of public completion/admission; no accept1 until reset and a new checked job. |
| VF-F03 | Fault concurrent with a would-be valid comparison or held normal completion | Fatal quarantine wins; no accepted false success. |
| VF-F04 | Unexpected extra hash byte/beat, missing/early done or mismatched read address/last | Service protocol checker fires; correct finite drain or fatal containment according to the interface. |
| VF-X01 | All nine ordered KeyGen/Sign/Verify pairs and all level/mode pairs | No cross-operation input credit, output, cached digest, hint state or stale completion. |
| VF-X02 | Valid -> invalid -> valid, invalid -> invalid -> valid and reset/fault -> recovery | Independent verdicts, stable IDs and fully restored service capacity. |
| VF-X03 | Long reproducible mixed-case/random-stall campaign | No cumulative state/credit leak; complete expected manifest and retirement accounting. |
| VF-X04 | Inject wrong expected/observed verdict, ID/status, digest byte, hint bit, consumed-prefix or memory witness | Checker fails for the intended reason; no checked-result/coverage credit for corruption. |

Reset phases include root acceptance; pk rho/t1 and hash/decode fork; finite tr
output; ctilde; z decode/norm; hint count/order/padding/cache build/emission;
input drain; mu prefix/body; sparse challenge sampling/transform; z/t1
transforms; matrix sampling and ring wrap; row MAC/subtract/inverse/UseHint;
w1 packing/readback; final hash/compare; early rejection; held completion and
root retirement. Cross each with all levels, both supported message modes
where relevant, and representative occupied/full/stalled boundaries.

## 8. Functional coverage model and traceability

Retirement coverage samples only after independent verdict/status and cleanup
checks. Algorithm checkpoint coverage samples checked accepted events.
Expected errors, reset aborts and fatal-fault containment use separately checked
event streams and denominators. Code execution or a driver's planned mutation
does not establish a correctly verified negative result.

| Proposed covergroup | Coverpoints / required crosses |
|---|---|
| `verify_command_cg` | Level, mode, ID class, command accept/reject, declared signature-length class; level x mode x result class. |
| `verify_case_cg` | NIST/C/custom-mutated source, original group/case identity, expected true/false and actual checked outcome; all supported manifest cases accounted for separately from aggregate bins. |
| `verify_message_cg` | Context classes, body length/tail, formatted rate boundary and legal maximum; mode x context x level. |
| `verify_input_frame_cg` | pk/signature/body, field boundary, byte count/index/last mutation, consumed prefix and early-stop phase. |
| `verify_pk_fork_cg` | Hash/load acceptance mask and first consumer, final-word skew and completion order; all legal fork stall/release combinations. |
| `verify_decode_cg` | rho/t1/ctilde/z/hints, lane, bit crossing, first/last polynomial, valid versus transport error. |
| `verify_z_norm_cg` | Bound-1/equal/bound+1, centered sign, lane and offending polynomial/position; level x equality outcome x sign. |
| `verify_hint_count_cg` | Total0/1/omega-1/omega/overflow, empty/nonempty row, equal/increasing/decreasing cumulative count; level x row class x decision. |
| `verify_hint_order_cg` | Index0/255, ascending/equal/descending, within-row/cross-row, padding zero/nonzero and rejection position. |
| `verify_hint_mask_cg` | All legal rows, words0..63, lane masks0..15, cache clear/insert/drain, prior/current level and valid/error/reset predecessor. |
| `verify_hash_cg` | tr/mu/challenge-recompute purpose, core and finite beat count, rate/tail boundary, response ordering and prefix lifetime. |
| `verify_challenge_cg` | tau, coefficient position/sign, rejected sample candidate, core and source-stop/drain. |
| `verify_ntt_cg` | z/t1/chat/row operation, polynomial index, source-release order and mode; legal level x operation pairs. |
| `verify_row_cg` | Every legal row/column, accumulator initialize/accumulate, subtract/inverse/UseHint and ring wrap. |
| `verify_usehint_cg` | Hint bit, low sign/zero, high0/interior/max, wrap/nonwrap and lane; level x hint x boundary. |
| `verify_digest_cg` | Equal/not equal, first mismatch byte/word/beat, first/middle/final byte and matching-prefix length; every meaningful byte position at each level. |
| `verify_verdict_cg` | Normal valid, equation invalid, early norm/hint/length invalid, command/input error, checked reset/fatal; level x mode x outcome/reason. |
| `verify_memory_cg` | Role/bank/physical port/client, actual commit, same-address conflict, queue/skid occupancy, renewal and valid lifetime. |
| `verify_reset_cg` | Checked phase, level/mode, occupied boundary, same/new ID and recovery op/verdict; required phase x level coverage. |
| `verify_fault_cg` | Exact cause, detected boundary, quarantine versus normal error, reset and checked recovery. |
| `verify_sequence_cg` | Prior/current op/level/mode/result, repeated ID and error -> success transitions. |
| `verify_latency_cg` | Valid versus early/equation-invalid latency, phase clocks, stalls and service overlap; compare equivalent input/traffic classes. |

Keep valid Verify timing separate from early invalid signatures when measuring
performance. Target important multiway risks directly (last signature beat +
hint boundary + stall/reset); use pairwise selection for broad traffic crosses.
Do not force a full cross of sparse hint bitmaps, unbounded stalls or 2^256
keys. Every exclusion needs an architectural or mathematical reason.

A canonical-hint-rejection bin needs the observed malformed suffix, independent
parser failure at the expected field, normal-invalid verdict or documented
transport error, no accepted cryptographic result, clean drain and checked
recovery. A digest-final-byte-mismatch bin needs a checked unequal final byte
after the required equation was actually executed; an early z rejection cannot
earn it. Retain case/seed/checker evidence and sample-location references for
every requirement-to-bin mapping.

### Requirement-to-test-to-coverage traceability

Expand each row into a concrete sequence, checker/assertion, precise bin,
source identity, input/case/seed, observed evidence and disposition. All newly
specified work starts **planned**. A normal-invalid verdict is credited only
after checking its status, accepted prefix, reason and clean retirement.

| Requirement | Test families | Independent evidence | Coverage groups |
|---|---|---|---|
| VF-REQ01 command/corpus/mode | VF-C01..C14 | Accepted metadata, original NIST IDs and C verdict | command, case, message |
| VF-REQ02 public-key fork and tr | VF-P01..P09 | Exact hash/decode streams, fields and tr | pk_fork, decode, hash |
| VF-REQ03 signature framing | VF-S01..S05 | Expected size/tails and accepted prefix/status | input_frame, decode, verdict |
| VF-REQ04 z decoding and norm | VF-Z01..Z04 | Centered coefficients and strict boundary decisions | z_norm, decode, verdict |
| VF-REQ05 canonical hints/cache | VF-H01..H12 | Independent suffix parser, masks and no stale validity | hint_count, hint_order, hint_mask |
| VF-REQ06 challenge and equation | VF-A01..A07 | Full normalized transforms, MAC/subtraction and rows | hash, challenge, ntt, row |
| VF-REQ07 UseHint and w1 | VF-A08..A11 | High-part wrap/ties and all packed bytes | usehint, row, hash |
| VF-REQ08 complete digest comparison | VF-D01..D06 | Each compared byte, expected reason and verdict | digest, verdict |
| VF-REQ09 memory and protocol | VF-M01..M05, VF-T01..T05 | Actual commitment, ownership, stable offers and drain | memory, input_frame, latency |
| VF-REQ10 abort/fault/recovery | VF-R01..R04, VF-F01..F04 | Checked abort/quarantine, no false accept, recovery | reset, fault, verdict |
| VF-REQ11 composition/checker soundness | VF-X01..X04 | Independent mixed-job verdicts and checker corruption detection | sequence plus affected feature groups |

Names refer to the `verify_..._cg` groups above. A focused codec campaign can
enumerate all 4608 legal row/coefficient coordinates across the three levels,
while full signature cases check reference verdicts. The codec sweep alone
does not establish that every such hint belongs to a valid full signature.

## 9. Assertions and verification of the checkers

Require properties for accepted command stability; one root owner; no Verify
encoded-output stream; only active Verify input credit; valid-ready stability;
frame index/count/last; each pk fork sink consumes once; finite hash byte
credit; per-core ownership and matched service IDs; no unchecked hint mask
publication; no normal accept after norm/canonical failure; full digest
comparison before accept; exact memory ownership/commit/release; queue bounds;
no done with live physical resources; stable held verdict; exactly one
completion; immediate fatal quarantine; reset flush; and eventual retirement
under explicit bounded source/service/sink fairness assumptions.

Cover every assertion antecedent. Four-state assertions operate on the sampled
interface, not an already truncated `bit` transaction. Planned protocol-driver
violations and injected faults must produce the precise expected failure;
unrelated UVM errors/fatals remain failures. Deliberately flip a verdict and a
digest/hint bit, mislabel an early-invalid case as valid, drop an output/result,
reuse an old completion, ignore a reset and corrupt a memory expectation.
Require the scoreboard/protocol checker to reject all such checker self-tests
with no false checked-success coverage.

## 10. Code coverage, campaign order and acceptance

Collect enabled DUT statement, branch, condition, expression, toggle and FSM
state/transition coverage, including executable package code and per-module
details. Review all Verify/input FSM states and transitions, both message
modes, all length/last/loop exits, canonical count/order/padding decisions,
both sides of norm boundaries, UseHint wrap/tie conditions, digest equal and
unequal paths, early exits, fork sent flags, drain/renewal, reset and fatal
containment. Report raw hit/eligible counts for each metric and the defined
tool aggregate; do not average percentages or merge incompatible sources.

Campaigns: checker self-tests -> small directed positive/negative smoke -> full
supported sigVer manifest -> independent C custom and mutation cases ->
canonical/norm/equation boundary UVM -> stall, early-exit, reset/fault and
recovery campaigns -> mixed-operation soak -> reviewed coverage closure.
Error tests must not simply count “accept0”: wrong status, stale work,
unconsumed errors or no completion still fail. Match expected consumed prefixes
and distinguish a legal early return from a hang.

Current UVM launch commands (the new families still require implementation):

```powershell
C:/Python314/python.exe sim/dilithium/dilithium_vectors.py uvm_prepare
```

```tcl
set DILITHIUM_UVM_TEST dilithium_regression_test
do sim/dilithium/run_uvm.do
set DILITHIUM_UVM_TEST dilithium_random_stall_test
do sim/dilithium/run_uvm.do
```

Acceptance requires complete supported-case accounting, exact expected verdicts
and status, independently checked cryptographic checkpoints, no false accept,
correct early-reject prefix/drain, every required fault/reset recovery, all
checker self-tests detected, no unexplained UVM errors/fatals, and reviewed
functional/code gaps. Every critical reachable bin must be hit or explicitly
waived with evidence. A high percentage alone cannot establish this; never add
impossible bins or cap coverage to manufacture a preferred percentage.

Retain source/constraints/reference/vector identities, tool/seed, original
tgId/tcId, accepted input trace, verdict/status/reason, computed digest when
the equation executes, row/intermediate mismatch diagnostics, fault/reset
records, phase and operation clocks, UCDB and detailed bin/code reports.
Use normal active filenames and existing evidence storage. The case list must
separately identify supported/executed/checked/aborted/unsupported cases.
Current-source coverage must be measured after implementing the missing UVM
features; older captures/percentages do not qualify this plan. Physical timing,
side-channel resistance, secure erasure and post-fit/FPGA acceptance require
their own evidence and gates.
