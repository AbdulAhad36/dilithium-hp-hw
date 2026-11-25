# Sign UVM verification plan

## 1. Purpose, scope and status

Verify the complete signing operation through the production `dilithium_fpga`
interface and the actual shared engines and memory. Levels 2/3/5 select final
ML-DSA-44/65/87. Cover normal signatures, every rejection-loop decision,
malformed inputs, transport behavior, resets, faults and mixed-operation reuse.
This document specifies required work; proposed tests/coverage are not claims
of implemented or passing UVM functionality.

Supported message forms are external pure-message mode and internal already
formatted Mprime, selected by `start_internal_message_i`. Both compute mu in
hardware. Prehash/HashML-DSA and externally supplied mu have no implemented
public selector and are outside this plan's functional acceptance. An ordinary
64-byte message must still be signed normally; its length cannot identify it
as an unsupported externally supplied mu.

Use [final FIPS 204](https://csrc.nist.gov/pubs/fips/204/final) as the algorithm
authority and the local independent C reference for expected values. The
current RTL is the transport/status authority; record conflicts explicitly.
See [KeyGen](KEYGEN_VERIFICATION_PLAN.md), [Verifier](VERIFIER_VERIFICATION_PLAN.md),
[specification](dilithium_docs/SPECIFICATION.md),
[memory map](dilithium_docs/MEMORY_MAP.md) and
[Process descriptions](dilithium_docs/PROCESS_BLOCKS.md).

## 2. Source and verification ownership

| Area | Current source / verification location |
|---|---|
| Root ownership and public interface | `../src/controller/{dilithium_fpga,dilithium}.sv` |
| Signing FSM, producer and retry schedule | `../src/controller/sign.sv` |
| Expanded secret-key frame decoding | `../src/controller/sign_input.sv`, `../src/controller/datapath/load_decode.sv` |
| Message construction / bit encoding | `../src/controller/process/{sign_hash_message,bitunpkg,bitpkg,hint_codec}.sv` |
| Decompose, norm and hints | `../src/controller/process/{poly_process,cnb,mhint}.sv` |
| Engine adapters and queues | `../src/controller/datapath/` |
| Shared arithmetic/hash/sampling | `../src/ntt/`, `../src/keccak/`, `../src/sampler/` |
| Memory roles and physical commitment | `../src/controller/helpers/dilithium_pkg.sv`, `../src/controller/memory/` |
| UVM components to extend | `../tb_uvm/tb_uvm_dilithium/` |
| Independent reference and trace interface | `../dilithium-sw-model/golden/{golden.py,bridge.c}`, `../dilithium-sw-model/ref/` |
| Published case inputs and expected signatures | `../NIST/ML-DSA-sigGen-FIPS204/{prompt.json,expectedResults.json,provenance.json}` |
| Existing capture/vector tooling | `../tb/tb_dilithium/tb_main.sv`, `../sim/dilithium/dilithium_vectors.py` |

The existing UVM transaction, interface and driver do not yet carry the entire
internal-message API. The normal fixture suite is not automatically the full
supported sigGen corpus. Extend the actual UVM path and preserve the original
NIST tgId/tcId and message-mode identity; do not count file-based captures or
standalone helper proofs as main UVM tests without executing them there.

## 3. Parameter and encoding matrix

All sets use 256 coefficients, q=8,380,417 and d=13.

| Quantity | Level 2 | Level 3 | Level 5 |
|---|---:|---:|---:|
| Public parameter code | 0 | 1 | 2 |
| k / l | 4 / 4 | 6 / 5 | 8 / 7 |
| eta / tau / beta | 2 / 39 / 78 | 4 / 49 / 196 | 2 / 60 / 120 |
| gamma1 | 131072 | 524288 | 524288 |
| gamma2 | 95232 | 261888 | 261888 |
| Strict z norm bound gamma1-beta | 130994 | 524092 | 524168 |
| Strict corrected-low bound gamma2-beta | 95154 | 261692 | 261768 |
| Strict ct0 norm bound | 95232 | 261888 | 261888 |
| Maximum hint weight omega | 80 | 55 | 75 |
| Expanded sk bytes / input beats | 2560 / 320 | 4032 / 504 | 4896 / 612 |
| ctilde bytes | 32 | 48 | 64 |
| One encoded z polynomial, bytes | 576 | 640 | 640 |
| Encoded hint suffix omega+k, bytes | 84 | 61 | 83 |
| Complete signature, bytes | 2420 | 3309 | 4627 |
| Signature beats / final valid bytes | 303 / 4 | 414 / 5 | 579 / 3 |
| Packed w1 vector for challenge hash, bytes | 768 | 768 | 1024 |

Norm checks reject equality: centered absolute coefficient >= bound rejects.
Hint weight rejects only when it exceeds omega; equality is legal. Check both
signs and canonical encodings q-x. A coefficient outside 0..q-1 is a service
range error, not an ordinary norm-rejection input.

## 4. Public interface and message contract

Accept `start_op_i=1` only at `start_valid_i && start_ready_o`. Latch level,
16-bit ID, message/context lengths, internal-message selection and all 32 bytes
of `start_rnd_i`. Hardware takes explicit randomness; this plan does not assume
an on-chip RNG. Zero randomness selects the deterministic reference behavior.

Frame 0 is the expanded secret key. Frame 1 is context||message in external
mode, or Mprime alone in internal mode. Both frames use the Sign 64-bit input
stream, least-significant byte first, byte count, index and last; each restarts
index zero. Empty body means no fabricated input beat. A word transfers only
on valid && ready. Undefined unused high **input** byte lanes must not enter
the hash. Unused high **output** byte lanes must follow the existing zero-tail
contract and are checked independently of the valid bytes.

| Mode | SHAKE input for mu | Legal body-length condition |
|---|---|---|
| External | tr \|\| 0x00 \|\| one-byte context length \|\| context \|\| message | 66+ctxlen+mlen <=65535; ctxlen<=255 |
| Internal | tr \|\| Mprime | 64+mlen <=65535; separate ctxlen=0 |

Test exact maximum mlen=65469-ctxlen externally and 65471 internally, and one
below/above each limit. Test all 256 legal external context lengths in a
formatting campaign, and invalid 9-bit context values 256..511. Internal mode
with nonzero separate context is rejected. Already formatted Mprime is an
internal API input; do not require its contents to start with a particular
prefix or silently prepend formatting again.

Output is ctilde || packed z vector || canonical sparse hints on the signature
stream. Index is global across that whole signature, starting at zero, with
one final last flag. Do not restart index at component or polynomial boundaries.
No output from rejected attempts is allowed. Only normal completed signatures
earn algorithmic success credit; partial bytes transferred before a later
reset/fatal fault are an explicitly aborted prefix.

| Outcome | Expected treatment |
|---|---|
| Normal | code0, correct signature, attempts>=1, rejections=attempts-1, next_nonce=attempts*l. |
| Invalid level/context/total formatted length | code1; no signature; root/controller drains as specified. |
| Secret-key input error | code3, stage1, detail from `sign_input`; verify exact detected framing/canonical error. |
| Input-helper identity error | code6, stage1, using an expected-injection campaign. |
| Message formatter failure | code4, stage2, formatter-specific detail. |
| Nonce-space exhaustion | code4, stage2, detail2; finite clean error, no signature. |
| Hint-encoding protocol failure | code5, stage3, codec-specific detail. |
| Ordinary norm/hint-weight rejection | Retry; not a completed error and not a published signature. |
| Physical/service identity or arithmetic error | Fatal quarantine; successful public completion suppressed until reset. |

Inspect current source for overlapping-error priority. Do not infer that a
child's nonzero private code guarantees a public completion in a fatal case.

## 5. Independent scoreboards and checkpoints

The monitor reconstructs accepted commands and beats without reading expected
results. The scoreboard reads independently generated expectations, checks all
outputs/status and publishes checked outcomes to coverage only after clean
retirement. A separate service/memory analysis path verifies intermediate work.

| Checkpoint | Independent comparison |
|---|---|
| sk decoding | Independently parse rho, K, tr, s1, s2, t0; compare every decoded coefficient and field offset. |
| Secret preparation | Compare Pre-NTT(s1), Pre-NTT(s2), general NTT(t0), order and domain. Cached transforms belong to this sk and survive only valid lifetimes. |
| mu | SHAKE256 of the exact observed formatted message bytes, output64 bytes. |
| Mask seed | SHAKE256(K \|\| rnd \|\| mu), output64 bytes; no stale key/rnd/mu after their register lifetimes change. |
| y expansion | Independent ExpandMask with the attempt's nonce base and polynomial position. Check interval [-gamma1+1,gamma1], all coefficients and each nonce. |
| Ahat and w | Independent matrix expansion and w=A*y; row MAC/inverse checking with explicit representation conversion. |
| Decompose | Compare w1 and centered w0, modulo-q recomposition, tie handling and high-part wrap. |
| Challenge hash | SHAKE256(mu \|\| packed w1) truncated to ctilde length for the selected level. |
| Sparse challenge | SampleInBall(ctilde) gives exactly tau nonzeros, each +/-1, with correct positions/sign bits; independently compare the polynomial and transform. |
| z | Compare y+c*s1 coefficient-by-coefficient, including the fused transform-domain add and inverse normalization. |
| Corrected low terms | Compare w0-c*s2, its strict bound and c*t0 strict bound; account for optimized stored representations. |
| MHint | Adapt the optimized RTL low/high operands to the reference MakeHint definition; compare every bit, row count and cumulative weight. Do not apply the generic reference directly to mismatched port meanings. |
| Retry | Independently derive rejection reason/order from reference intermediates, attempt number and nonce sequence. |
| Encoding | Independently decode every observed z field and hint suffix; compare against accepted-attempt intermediates. |
| Final result | All signature bytes against NIST/C expected signature, plus independent verification using the corresponding public key. |
| Memory | Versioned shadow memory updated at physical write commitment; check every read, role transition and release before overwrite. |

Generate expected signatures from the actual supplied sk, rnd, body and mode.
NIST final signatures are the primary oracle for published cases. C traces are
reference-derived diagnostics; they are not official intermediate test vectors.
No recomputation from RTL outputs may replace an independent expected result.

Arbitrary bit changes to a structurally valid sk do not necessarily cause a
Sign input error: the current interface is not a full key-consistency validator.
Use reference behavior for the supplied key. Test canonical eta-field errors
separately from an inconsistent rho/tr/secret relationship. A changed K can
change signing randomness without necessarily making the signature invalid.

## 6. Required UVM extensions

Extend the existing `dilithium_if`, transaction/config/fixtures, driver, monitor,
scoreboard and coverage subscriber together to carry and check the internal
message bit. Preserve four-state monitoring before packing values into
two-state transaction fields. Add explicit per-beat framing mutations and
phase-targeted stall/reset schedules; the existing three transport profiles
cannot express every case below.

Add independent observations for actual rejection reasons, attempt/nonces,
per-core descriptors, finite SHAKE drain, sampler packets, memory commits,
Process tags and NTT mode/release/completion. Expected-fatal tests require a
configured exact fault expectation, quarantine check and coordinated recovery;
the normal monitor currently treats any fault as fatal to the test.

Add separate outcome types for success, checked ordinary error, verified reset
abort and expected fatal fault. A DUT fatal may be an expected test result;
an unrelated UVM fatal is never accepted merely because the test was negative.
All named families below are proposed and must be implemented before use as
`UVM_TESTNAME` values or coverage claims.

## 7. Required test families

### 7.1 Corpus, commands, message modes and inputs

| ID | Stimulus | Required checks |
|---|---|---|
| SG-C01 | All supported NIST sigGen cases, all levels and both message interfaces | Discover manifest counts dynamically; preserve tgId/tcId; exact complete signatures, no supported cases skipped. |
| SG-C02 | Zero/random/repeated rnd, walking bit/byte and asymmetric rnd patterns | Exact C result; all 32 randomness bytes reach mask-seed derivation correctly. |
| SG-C03 | Repeat identical sk/rnd/body under different stalls and IDs | Same signature and retry sequence; only ID and latency differ. |
| SG-C04 | Distinct valid keys, messages and rnd from independent reference | Exact signature and independent Verify; no assumption that every changed input must produce a distinct output. |
| SG-C05 | Message lengths 0,1..9,15..17,31..33,63..65,135..137,167..169 and multi-rate lengths | Byte-accurate SHAKE input, full output and all possible body-tail lengths. |
| SG-C06 | Formatted mu-message totals 135/136/137, 271/272/273 and further SHAKE256 block boundaries | Correct padding/domain suffix and cross-block carry including context prefix. |
| SG-C07 | Context lengths 0..255, varied content including zero and high-bit bytes | Exact length byte and bytes; no C-string truncation or context/message exchange. |
| SG-C08 | External maximum legal mlen for ctx0/1/255, maximum-1 and maximum+1 | Correct acceptance/rejection without 16-bit sum wrap. |
| SG-C09 | Internal Mprime empty, arbitrary bytes, all tails, 136-byte boundaries and maximum length | No external prefix added, no separate context; independent internal reference match. |
| SG-C10 | Paired external(ctx,M) and internal(0x00\|\|len(ctx)\|\|ctx\|\|M), same sk/rnd | Same mu, retry sequence and signature. Internal mlen includes the complete Mprime. |
| SG-C11 | Wrong internal-mode flag or changed Mprime prefix | Match the corresponding reference input; no silent reinterpretation or mode guessing. |
| SG-C12 | Level3, context256..511, internal nonzero context, total length overflow | Correct code1 with no signature or unowned service work; following good operation recovers. |
| SG-C13 | Boundary IDs and internal offset wrap neighborhoods | Correct public IDs; sample/raw/loader responses tied to current descriptors modulo16 bits. |
| SG-C14 | Busy/held/pulsed starts and mutation after accepted command | Exactly one acceptance; all latched fields including internal mode stable for the active job. |
| SG-C15 | Noise on Verify input and irrelevant KeyGen/signature-length fields | No Verify input credit or unintended KeyGen work; Sign result unchanged. |
| SG-I01 | Each sk field and polynomial boundary, nonuniform data patterns | Correct field order, bit unpacking, sign/canonical conversion and destination bank. |
| SG-I02 | Every invalid eta=2 value5..7 and eta=4 value9..15, each lane/bit/field location | Correct key error and bounded decoder cleanup; no signature. |
| SG-I03 | t0 extrema -4095/4096 and every 13-bit packing boundary | Correct representation; do not invent unused t0 bit patterns when all 13-bit encodings are legal. |
| SG-I04 | First/middle/last sk beat index wrong, duplicate, skipped or out of order | Correct detected error, consumed prefix and cleanup. |
| SG-I05 | Byte counts0..15, early/missing/late last, surplus offered sk word | Check actual fixed sk framing and absence of extra credit. Missing data alone is a wait, not an assumed autonomous timeout. |
| SG-I06 | Message-frame malformed count/index/last at every tail width | Formatter error with exact stage/detail and finite zero-fill/hash drain; no signature from the discarded hash. |
| SG-I07 | Sk/message index reset missing or applied within a frame | Frame-specific error; no accidental use of previous frame counters. |
| SG-I08 | Poison unused high input bytes, gaps before/inside/between frames | Invalid lanes and idle values have no cryptographic effect; legal offered words remain stable while stalled. |
| SG-I09 | Truncated frame held forever, then reset/recovery | No fake success; bounded simulation watchdog and documented safety behavior, followed by clean recovery. |
| SG-I10 | Source violates held-valid stability or presents X/Z in qualified fields | Expected driver/protocol-checker failure; do not demand a normal DUT signature. |

### 7.2 Sampling, arithmetic and rejection loop

| ID | Stimulus / checkpoint | Required checks |
|---|---|---|
| SG-A01 | Every s1/s2/t0 preparation polynomial at every level | Actual compact Pre-NTT for small secrets and general transform for t0; one-time preparation, correct cache and no stale previous key. |
| SG-A02 | Mask seed K/rnd/mu boundaries and finite SHAKE completion | Exact 128-byte input and 64-byte result; ownership held until output/drain completes. |
| SG-A03 | ExpandMask at first, interior and final nonce; all y lanes/positions | Independent y values and nonce little-endian serialization; no nonce reuse within an operation. |
| SG-A04 | Both Keccak cores active, mixed A/y jobs, one stalled core and paired/single batches | Independent context leftovers and IDs; correct job-to-polynomial association and stop/drain. |
| SG-A05 | Every matrix row/column and ring wrap | Ahat expansion order and coordinates correct; no occupied-slot overwrite. |
| SG-A06 | First/intermediate/final row MAC, inverse and Decompose | Full polynomial reference values; initialize once, sum l terms, preserve w1/w0 correctly. |
| SG-A07 | Decompose around +/-gamma2, multiples of 2*gamma2, q-1, zero and wrap | Independent high/low pair with correct ties and 44/16 high-part range. |
| SG-A08 | Challenge hash consumes every packed w1 byte and correct ctilde length | Exact hash result at 32/48/64 bytes; no stale or extra word and no truncated level5 comparison. |
| SG-A09 | SampleInBall sign-byte use, rejected candidate positions and byte-block crossing | Exactly tau unique nonzero positions, values +/-1, full independent polynomial and NTT comparison. |
| SG-A10 | z fused yhat+c_hat*s1hat and inverse, all l polynomials | Exact z and scale; no second addition of y or omitted inverse normalization. |
| SG-A11 | z norms at B-1,B,B+1 for both signs and each of four lanes | Strict comparison at B=gamma1-beta; rejection on any coefficient, including first/last polynomial. |
| SG-A12 | Corrected low w0-c*s2 at its signed boundary | Strict B=gamma2-beta behavior and correct subtraction order. |
| SG-A13 | c*t0 norms around +/-gamma2 | Equality rejects; distinguish normal norm rejection from noncanonical arithmetic input error. |
| SG-A14 | MHint low at +/-gamma2, high=0/nonzero, high extremes and wrap cases | Correct optimized low/high interface adaptation; independent hint bits and per-word weight0..4. |
| SG-A15 | Hint weights0,1,omega-1,omega,omega+1; overflow early/late row | Equality accepted; overflow rejects; correct cumulative counts and no buffer overrun. |
| SG-R01 | Reference-selected first-attempt acceptance | attempts1, rejections0, next_nonce=l; full signature exact. |
| SG-R02 | Natural NIST/C cases rejecting individually at z, corrected-low, ct0 and hint-weight gates | Exact reason/order and no signature prefix from rejected attempts. Preserve an observable natural witness where available. |
| SG-R03 | Multiple consecutive rejections, alternating rejection reasons, followed by acceptance | No stale y/w/challenge/hints and correct attempt/nonces; exact accepted signature. |
| SG-R04 | Controlled response injection to force a rare retry branch | Prove control cancellation/cleanup with an explicit injected expectation; do not claim end-to-end cryptographic correctness for the forced arithmetic. |
| SG-R05 | Fault-free retry while the shared hint encoder is active | Cancel retires partial hint state and finite work; no ready/cancel circular wait. |
| SG-R06 | Rejection on first/last polynomial or row and simultaneous service retirement | Counters increment once and only once; all prior attempt work drains before the next attempt. |
| SG-R07 | Nonce guard at last legal group and next illegal group | Level2 last next_nonce65536; level3 max65535; level5 max65534. Never truncate the 17-bit guard into a reused 16-bit nonce. |
| SG-R08 | Attempts-counter and rejection-counter terminal boundaries | Successful attempts cannot exceed floor(65536/l); separately inject near-limit control state to test exhaustion. Mark state injection as a control proof. |
| SG-R09 | Stall/reset during each rejection gate and during RETRY | No double retry, stale completion or accepted result from a canceled attempt. |

For boundary arithmetic stimuli that cannot be selected efficiently by a seed,
use focused UVM sequences on the reusable service/Process boundary or a precise
test-only injection. Preserve separate coverage scope. Do not change live RTL,
expected NIST signatures or checker calculations merely to hit a branch.

### 7.3 Memory lifetimes, output, reset and fault handling

| ID | Stimulus / checkpoint | Required checks |
|---|---|---|
| SG-M01 | Every role/bank/base/count used by the actual schedule | Correct compact/canonical/packed format, lane order and physical bounds. |
| SG-M02 | A ring full/wrap and producer faster/slower than arithmetic | Reuse only after consumption/release; no matrix/y/secret mixing. |
| SG-M03 | A lifetime ends and bank3 becomes z/chat/r0 storage | No queued old A write/read survives into a new role; exact versioned memory contents. |
| SG-M04 | Level5 final w0 uses the reused accumulator slot | Accumulator is retired before reuse; rows0..7 remain associated correctly. |
| SG-M05 | Cached secret transforms across many attempts | No resampling/overwriting or missed use; recomputed public A remains tied to rho and coordinates. |
| SG-M06 | Host/load/NTT/Process contention, A/B same-address conflict, full queues and split renewals | Atomic ownership, actual commit ordering, stable skid responses and one completion per command. |
| SG-M07 | Delayed source-release/done, independent bank release and concurrent final writes | No early read or unsafe overwrite; publication waits for true retirement. |
| SG-M08 | Dirty RAM, repeated IDs, previous malformed job and level transitions | Current signature independent of uninitialized/stale storage. |
| SG-P01 | ctilde/z/hint component and polynomial boundaries | Independent bit reader reconstructs all fields; signature index remains continuous. |
| SG-P02 | Signed z extrema, byte/64-bit crossings and final signature tails4/5/3 | Exact packed value, meaningful lane count, zero unused output lanes and final last flag. |
| SG-P03 | Hint suffix empty/full rows, positions0/255, all row boundaries and sparse extremes | Canonical ascending indices within rows, cumulative counts and zero unused index padding. |
| SG-P04 | Stall first, every component boundary, interior and final signature beat | Stable valid/data/metadata; no lost or repeated word or premature completion. |
| SG-P05 | Independent Process pack sink, hint sink and memory readiness stalls | Each result sink receives exactly its required credit; no deadlock under eventual readiness. |
| SG-P06 | Completion held while toggling host fields and offering a new start | Stable ID/status/counters; no acceptance until root is ready. |
| SG-P07 | Ready asserted early, continuously, periodically and after long pauses | Same signature/retries for same input, with measured latency differences only. |
| SG-Z01 | Reset at every phase listed below | No aborted signature is counted as success; control/queue ownership flushed without assuming RAM zeroization. |
| SG-Z02 | Reset on start, input, service response, signature or completion handshake edge | Defined reset priority; no double accounting, stale response or canceled completion. |
| SG-Z03 | Recovery same ID/new key or message, different level and different operation | Fresh outputs and resource retirement match independent expectations. |
| SG-F01 | Stale/duplicate/wrong core or ID on sample/raw/load responses | Exact error/fatal classification and immediate public quarantine where required. |
| SG-F02 | NTT/Process failure, bank error/collision or internal invalid descriptor | No successful signature; no new commands or inputs admitted after fatal quarantine; reset recovery checked. |
| SG-F03 | Fatal injection while a signature word or completion is stalled | Public valid drops according to quarantine contract; accepted prefix recorded as aborted, never a full signature. |
| SG-F04 | Stuck service/host readiness followed by bounded release; truly missing response | Fairness-conditioned liveness versus watchdog failure distinguished; no fabricated hardware timeout requirement. |
| SG-X01 | All ordered operation/level/message-mode transitions, success/error/reset predecessors | No stale key, mode, tr/mu, nonce, challenge, hint/cache or owner state. |
| SG-X02 | Long reproducible randomized campaigns and repeated same-ID commands | Exact results and no cumulative resource/credit leakage. |
| SG-X03 | Independently Verify every successful signature; KeyGen-generated and NIST keys | Positive interoperability, while retaining exact signature comparison. |
| SG-X04 | Corrupt expected/observed signature bytes, status, nonce/counters, mode, input framing or memory witness separately | Intended checker catches each corruption; no checked-success/coverage credit for it. |

Reset phases: command/key header, each sk field and decoder zero-fill/drain,
secret Pre-NTT/general NTT, mu prefix/body/hash output, mask-seed hash, y and A
sampling on both cores, matrix wrap, row MAC/inverse/decompose, challenge
hash/sample/transform, each rejection gate, active hint cancel, accepted
ctilde/z/hint emission, final tail, held completion and root retirement.
Run every phase at all levels; add full/empty/stalled boundary occupancy and
same-ID recovery. Explicitly cover success -> reject -> success and reset ->
error -> success sequences.

## 8. Functional coverage model

Coverage comes from checked observations, not driver intent. Commit full-job
coverage after successful comparison and retirement. Record validated error,
reset and fatal campaigns separately. Stage coverage requires a matching
reference comparison or verified injected-control expectation; visiting a state
alone cannot earn a cryptographic result.

| Proposed group | Coverpoints / required crosses |
|---|---|
| `sign_command_cg` | Level, ID class, accept/reject, randomness class and mode; level x mode x outcome. |
| `sign_message_cg` | ctx length0/1/interior/254/255/invalid, mlen classes and all body tails, formatted length relative to136 and maximum; mode x context class x level. |
| `sign_mode_transition_cg` | Previous/new mode and level, same input-equivalence pair or different Mprime; every supported ordered pair. |
| `sign_key_decode_cg` | rho/K/tr/s1/s2/t0, polynomial and nibble/lane position, valid/invalid eta encoding, partial cleanup; field x level x boundary. |
| `sign_hash_cg` | mu/mask-seed/challenge purpose, core, input/output first/last/tail and raw completion ordering; purpose x core x level. |
| `sign_preparation_cg` | s1/s2/t0, actual NTT mode, source/destination role, index and source-release; level x kind x mode. |
| `sign_sampler_cg` | A/y/challenge mode, core mask, batch size, nonce/index, block leftovers and candidate rejection; kind x core/order. |
| `sign_matrix_cg` | Every legal row/column, ring slot/wrap, initialize/accumulate and producer/consumer stall. |
| `sign_decompose_cg` | Lane, high/low limits, tie side and wrap; level x lane x tie/wrap. |
| `sign_challenge_cg` | tau, first/last/nonzero position, sign balance classes and candidate rejection; every coefficient position observed across campaign. |
| `sign_norm_cg` | z/r0/ct0, bound-1/equal/bound+1, sign, lane, polynomial/row boundary and decision; kind x level x equality outcome. |
| `sign_hint_cg` | Per-word weight0..4, row count, total0/1/omega-1/omega/overflow, boundary low/high case and suffix tail; level x weight decision. |
| `sign_retry_cg` | Actual cause z/r0/ct0/hint, first/later attempt, accepted/rejected, attempt ranges and final nonce guard; cause x level and cause x next cause. |
| `sign_retry_cleanup_cg` | Hint active/canceled, outstanding hash/memory work, source release and next-attempt admission; cancellation x drain x recovery. |
| `sign_memory_cg` | Role/bank/port/client, real issue/commit, conflict, queue occupancy and lifetime transition; level x role and conflict x phase. |
| `sign_publication_cg` | Component, first/middle/final beat, bytes1..8 where legal, stall duration and first valid only after accepted attempt. |
| `sign_reset_cg` | Checked abort phase, level/mode, active cores, occupied buffers and recovery op; all required phase x level combinations. |
| `sign_error_cg` | Root/key/message/hint/nonce error versus fatal; exact code/stage/detail and checked recovery. |
| `sign_sequence_cg` | Previous/current op, level/mode, repeated/new ID and previous outcome; all ordered operation pairs. |
| `sign_performance_cg` | Preparation, per-attempt sample/arithmetic/drain/encoding clocks, retries, service overlap and transport waits; same-corpus latency and rate comparison. |

Do not create impossible successful attempt bins above floor(65536/l), illegal
context-mode crosses, or tail bins contradicting signature length. Use separate
bins for naturally reached retries and injected control proofs. Cross important
boundaries explicitly; use pairwise randomized traffic for the rest rather than
an unmanageable full Cartesian product. Coverage misses and exclusions need
evidence, not fabricated traffic or a desired overall percentage.

For each coverage hit retain test/case/seed, observed event, reference result,
sample location and count. A z-equality-rejection bin requires a checked
coefficient at the exact signed threshold, observed rejection, no signature
from that attempt, correct next nonce and checked cleanup/recovery.

### Requirement-to-test-to-coverage traceability

The implementation tracker must expand each row into concrete sequence,
checker/assertion, precise bin definition, source identity, case/seed evidence
and result. Initial status is **planned**. A naturally occurring cryptographic
witness and an injected control witness are recorded separately.

| Requirement | Test families | Independent evidence | Coverage groups |
|---|---|---|---|
| SG-REQ01 command/mode/randomness | SG-C01..C14 | Accepted metadata, full reference signature | command, message, mode_transition |
| SG-REQ02 key decode and input cleanup | SG-I01..I10 | Bit-level decode, exact consumed prefix and status | key_decode, error |
| SG-REQ03 secret preparation and mask seed | SG-A01..A03 | Correct transforms, mu/mask hash and y coefficients | preparation, hash, sampler |
| SG-REQ04 matrix, Decompose and challenge | SG-A04..A09 | Full rows/high-low values and challenge polynomial | matrix, decompose, challenge, hash |
| SG-REQ05 response and strict norms | SG-A10..A13 | All coefficients and equality-side decisions | norm, retry |
| SG-REQ06 hints/canonical encoding | SG-A14..A15, SG-P01..P03 | Hint bits/weight and complete independent decode | hint, publication |
| SG-REQ07 retry/nonce/drain correctness | SG-R01..R09 | Reason sequence, no rejected output, exact counters and finite recovery | retry, retry_cleanup, error |
| SG-REQ08 storage and concurrency | SG-M01..M08 | Commit/version/owner and source-release checks | memory, sampler, matrix |
| SG-REQ09 publication and stalls | SG-P04..P07 | Stable full signature, exact sinks and completion | publication, performance |
| SG-REQ10 reset/fatal containment | SG-Z01..Z03, SG-F01..F04 | Checked abort/quarantine and good recovery | reset, error |
| SG-REQ11 composition/checker soundness | SG-X01..X04 | C Verify, mixed-job identity and mutation detection | sequence plus affected feature groups |

Names refer to the `sign_..._cg` groups above. Exhaust small encoding/lane/enum
spaces and use focused scalar UVM checks for norm/ID arithmetic when exhaustive
testing is practical; use end-to-end reference cases for real signing behavior.
Document the domain and denominator of each campaign instead of implying all
keys/messages were exhausted.

## 9. Assertions and checker validation

Required assertions cover: accepted command lifetime; one public owner;
source/sink valid-ready stability; byte/index/last framing; no inactive stream
credit; no signature before acceptance of every norm/hint gate; no publication
from rejected attempts; strictly correct attempt/rejection/nonces; no nonce
reuse/wrap; no duplicate/mismatched internal response; per-core job isolation;
queue capacity and finite hash credit; cache validity/lifetime; memory ownership
through physical retirement; all required result sinks acknowledged; complete
drain before retry/error/done; stable held completion; immediate fatal
quarantine; reset cancels ownership; and fair-service eventual completion.

Assertion covers must prove their antecedents were exercised. Deliberate
checker-corruption tests must include wrong signature byte in each component,
wrong final length, missing/extra beat, wrong ID/mode, false retry credit,
stale memory read, ignored fatal and dropped reset abort. An expected failure
cannot enter the clean UCDB or checked-success counts.

## 10. Code coverage and execution campaigns

Collect DUT statement/branch/condition/expression/toggle/FSM state and transition
coverage, executable package code and per-module metrics. Review each Sign FSM
command/run/drain state, producer branch, all sections/loops/last-index
decisions, four rejection gates, nonce guard, cancellation, publication phases,
format/packing tails, invalid framing and reset/fatal paths. Each cold branch
needs a directed test, a reachable service injection or a reviewed exclusion.
Report real hit/eligible totals and tool aggregation; do not average module
percentages, cap results or merge unrelated-source helper UCDBs.

Campaign order: checker self-test -> directed valid smoke for all levels/modes
-> complete supported sigGen corpus -> C-reference custom keys/messages/rnd ->
arithmetic/retry boundary UVM -> protocol, reset/fault and cancel/drain stress ->
mixed-operation soak -> coverage closure. Preserve original vector files and
IDs. Explicitly list unsupported groups separately from executed/checked cases.
Use bounded reproducible random stalls, directed critical multiway hazards,
and search/trace tools to select natural retry witnesses efficiently.

Existing commands run only the currently implemented campaign:

```powershell
C:/Python314/python.exe sim/dilithium/dilithium_vectors.py uvm_prepare
```

```tcl
set DILITHIUM_UVM_TEST dilithium_regression_test
do sim/dilithium/run_uvm.do
set DILITHIUM_UVM_TEST dilithium_random_stall_test
do sim/dilithium/run_uvm.do
```

Add and validate the planned sequences before claiming this plan is covered.
The existing bad-key monitor injection checks one checker path; it is not a
replacement for actual malformed-sk, message-mode or rejection-loop testing.

## 11. Acceptance and evidence

Every mandatory family must pass its expanded applicable cases or have a
reviewed disposition. Require every supported published case accounted for,
exact signatures, independent Verify, checked intermediates at critical gates,
all natural/control-injected retry causes accounted for, correct output
suppression, finite cleanup/recovery, and no unexplained UVM errors/fatals.
Critical reachable coverage bins must be hit or explicitly waived with proof;
all other functional/code gaps must remain visible and reviewed. No overall
coverage percentage alone establishes completion.

Save source/constraint/reference/vector identity, tool and random seed, original
case IDs, expected and observed outputs, natural versus injected scenario type,
attempt/rejection/nonce/reason traces, checked abort/recovery records, phase
clocks, UCDB and detailed coverage reports. Measure first-attempt and actual
retry-distribution latency separately; compare identical inputs/stalls before
claiming a cycle or throughput improvement. Do not make a constant-time,
side-channel-resistance or secure-erasure claim from these UVM checks.

Keep current filenames stable and evidence in existing storage. Full suites
are for retained RTL candidates under the efficient workflow; this document
does not authorize a new fit or a post-fit/FPGA acceptance campaign.
