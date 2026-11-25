# KeyGen UVM verification plan

## 1. Purpose and status

Verify the complete KeyGen path through `dilithium_fpga`, including its use of
the shared Keccak, sampler, NTT, Process and physical coefficient memory.
User-facing levels 2/3/5 mean final ML-DSA-44/65/87. This is a requirements and
test-design document, not a statement that the listed tests or covergroups
already exist or have passed. No simulation results are created by this plan.

“Complete” means that every requirement below has an independent checker,
stimulus, coverage and recorded disposition. It does not mean exhaustive
enumeration of all 2^256 seeds or all possible stall histories. Exhaust small
finite spaces where practical; use directed boundaries, reproducible random
campaigns and compositional checking for the remaining spaces.

Companion plans: [Sign](SIGN_VERIFICATION_PLAN.md) and
[Verifier](VERIFIER_VERIFICATION_PLAN.md). Shared-resource tests must run in
the main UVM environment; standalone module proofs may support them but cannot
be reported as full-accelerator UVM coverage.

## 2. Authorities and source map

The normative algorithm is [final FIPS 204](https://csrc.nist.gov/pubs/fips/204/final).
Algorithm checking also uses the independently compiled local C reference;
RTL source determines the current transport and error contract. Record any
disagreement as a defect or specification decision, not an automatic waiver.

| Area | Files to study / monitor |
|---|---|
| Public boundary and operation ownership | `../src/controller/dilithium_fpga.sv`, `../src/controller/dilithium.sv` |
| KeyGen schedule | `../src/controller/keygen.sv` |
| Requests and fixed memory roles | `../src/controller/helpers/dilithium_pkg.sv` |
| Shared services | `../src/controller/datapath/{datapath,hash_sampler,keccak_sampler,sampler_writer,ntt_dma,process_dma}.sv` |
| Memory commitment and ownership | `../src/controller/memory/{bank_fabric,memory_router,memory_port,memory_banks,bank_request_pipe,poly_bram}.sv` |
| Arithmetic / serialization | `../src/ntt/`, `../src/sampler/`, `../src/keccak/`, `../src/controller/process/{power2round,bitpkg,secret_regroup}.sv` |
| Independent golden interface | `../dilithium-sw-model/golden/{golden.py,bridge.c}`, `../dilithium-sw-model/ref/` |
| Published final-output cases | `../NIST/ML-DSA-keyGen-FIPS204/{prompt.json,expectedResults.json,provenance.json}` |
| Main UVM | `../tb_uvm/tb_uvm_dilithium/` |
| Existing capture and vector tooling | `../tb/tb_dilithium/tb_main.sv`, `../sim/dilithium/dilithium_vectors.py` |

Related design contracts: [specification](dilithium_docs/SPECIFICATION.md),
[memory map](dilithium_docs/MEMORY_MAP.md),
[Process blocks](dilithium_docs/PROCESS_BLOCKS.md) and
[coverage rules](dilithium_docs/COVERAGE.md).

## 3. Parameters and public contract

All sets use N=256, q=8,380,417 and d=13. Bytes are serialized with the earliest
byte in bits [7:0]. Arithmetic checkers must explicitly distinguish canonical,
centered, NTT-order and Montgomery representations.

| Quantity | Level 2 | Level 3 | Level 5 |
|---|---:|---:|---:|
| `start_param_i` | 0 | 1 | 2 |
| k / l | 4 / 4 | 6 / 5 | 8 / 7 |
| eta | 2 | 4 | 2 |
| Seed xi, bytes | 32 | 32 | 32 |
| rho / rhoprime / K, bytes | 32 / 64 / 32 | 32 / 64 / 32 | 32 / 64 / 32 |
| Public-key bytes / 64-bit beats | 1312 / 164 | 1952 / 244 | 2592 / 324 |
| Expanded secret-key bytes / beats | 2560 / 320 | 4032 / 504 | 4896 / 612 |
| Packed secret polynomial, bytes | 96 | 128 | 96 |
| Packed t1 / t0 polynomial, bytes | 320 / 416 | 320 / 416 | 320 / 416 |
| A polynomials / scalar MAC terms | 16 | 30 | 56 |

An operation starts only at a rising edge with `start_valid_i && start_ready_o`.
KeyGen uses `start_op_i=0`, level, 16-bit `start_id_i` and 256-bit
`start_seed_i`. There is no host input frame. Ignore irrelevant command fields
for KeyGen, including message/context/randomness/signature length and message
mode; test that they do not alter a valid KeyGen. Changes after acceptance must
not affect the accepted seed, ID or level.

The output is one public-key frame (`key_type_o=0`) followed by one expanded
secret-key frame (`key_type_o=1`). Both use `key_valid_o/key_ready_i`,
`key_data_o`, `key_bytes_o`, `key_index_o`, `key_last_o` and `key_id_o`.
Index restarts at zero for the second frame. Every key beat has eight valid
bytes; other byte counts are illegal for these fixed encoded lengths.
Completion is consumed with `done_valid_o && done_ready_i`, after all output
and physical work have retired. Hold a stalled valid offer stable until its
handshake, reset or documented fatal quarantine.

Root invalid-opcode error is code 2; root invalid-level error is code 1. Normal
KeyGen completes with code 0. Its internal code 2 accompanies a fatal service
failure; root quarantine suppresses normal completion in that situation.
Check stage/detail against the root-selected response (normal KeyGen uses
zero), rather than expecting Sign/Verify error enums to apply to KeyGen.

## 4. Independent checking architecture

Use the existing UVM sequencer -> driver -> interface -> production DUT path.
The passive monitor reconstructs **accepted** commands and output words;
driver counters are not evidence that a word transferred. Scoreboard checks
precede coverage publication. Use a separate observed service/memory analysis
stream or bind-based checker for internal events; do not add debug FPGA pins.

| Checkpoint | Independent expected result and required comparison |
|---|---|
| Command | Snapshot accepted fields; compare ID and operation on every publication. |
| Seed expansion | SHAKE256 over xi followed by the one-byte k and l encodings; compare all 128 bytes split into rho, rhoprime and K. |
| Matrix expansion | SHAKE128(rho \|\| column byte \|\| row byte), independent rejection sampling and coordinate order. Compare every accepted coefficient of each Ahat polynomial in the representation used by the reference. |
| Small secrets | SHAKE256 over rhoprime and the little-endian 16-bit nonce; s1 nonces 0..l-1, s2 nonces l..l+k-1. Check all coefficients, eta bounds and their compact nibble/group ordering. |
| Secret transforms | Compare every s1hat coefficient, with explicit ordering and scale conversion. Validate Pre-NTT against general NTT and the C reference. |
| Matrix product | Independently compute each row sum of Ahat*s1hat and the inverse-domain result. Confirm the first term initializes rather than accumulating stale RAM. |
| t | Compare t = A*s1+s2 modulo q after the defined transform/scaling conversions. |
| Power2Round | For every coefficient verify t = 8192*t1+t0 (mod q), 0<=t1<=1023 and -4095<=t0<=4096. Verify packed t0 encodes 4096-t0. |
| Encoded pk | Exact rho \|\| packed t1, full length and all bytes. |
| Public-key hash | Feed **observed accepted pk bytes** to an independent SHAKE256 checker; compare 64-byte tr. Its host and hash forks must each consume every byte exactly once. |
| Encoded sk | Exact rho \|\| K \|\| tr \|\| packed s1 \|\| packed s2 \|\| packed t0. Check offsets and each complete field. |
| Final outputs | Compare complete pk/sk against NIST expected results for published cases, and C-generated results for custom seeds. |
| Memory | Shadow writes on physical issue/commit, not upstream admission. Compare each owned read against its committed version. Track valid regions independently of payload contents. |

Use `golden.py`/`bridge.c` to call `ref/` functions; do not port RTL equations
verbatim into the scoreboard. Trace intermediates are reference-derived,
not official standalone NIST NTT/sampler vectors. Keep original tgId/tcId and
parameter set in transaction identity; discover the complete current KeyGen
case list from the files instead of assuming a fixed row count forever.

For a custom case, build expected values from its actual seed before driving
it. Never use a DUT-produced key as its own expected key. A Sign/Verify round
trip is an additional check and cannot replace pk/sk byte comparison.

## 5. UVM work required before claiming plan coverage

The existing environment has separate transaction, configuration, sequence,
driver, monitor, scoreboard, coverage subscriber, agent and environment files.
Extend these components rather than building another top-level non-UVM bench.
Existing normal/random-stall fixture campaigns are a starting point, not this
plan's complete case set.

| Required extension | Purpose |
|---|---|
| Per-operation corpus selection and case identity | Run all KeyGen cases and preserve tgId/tcId, source, seed and expected key identity. |
| Programmable ready/pause schedules | Independently stall key output, completion and selected internal service boundaries; control duration and phase. |
| Accepted-command and four-state observations | Catch X/Z controls and unknown valid payload before converting observations to two-state transaction fields. |
| Expected-error / expected-fatal classification | A planned fault needs a precise expected fault window, immediate quarantine checks and reset recovery; do not disable the monitor globally. |
| Semantic phase/reset trigger | Trigger by observed phase and occupancy, rather than assuming a fixed clock count after start. |
| Independent memory/service monitors | Observe two hash cores, descriptor IDs, actual memory issues, NTT/Process commands and their retirements. |
| Checked abort/event coverage | Count a verified reset abort separately from a successfully completed key pair. |
| End-of-test accounting | Require all scheduled cases and recovery jobs to finish; no unconsumed expectations, requests, responses or objections. |

All scenario names below are **proposed test families**, not existing working
`UVM_TESTNAME` values. Each row must expand across applicable levels, phases,
lanes, IDs, stall profiles and boundary values described here.

## 6. Required test families and checks

### 6.1 Command, seed and deterministic behavior

| ID | Stimulus | Pass conditions |
|---|---|---|
| KG-C01 | Entire supported NIST KeyGen corpus, all levels | Every published pk/sk byte, correct case identity, exact count and no skipped supported case. |
| KG-C02 | Zero, all-ones, alternating AA/55, incrementing/decrementing and asymmetric 32-byte seeds | Full C-reference pk/sk match; no endian reversal or word swap. |
| KG-C03 | Walking one and walking zero over all 256 seed bits | Every seed bit reaches the correct byte lane; reference comparison for each case. |
| KG-C04 | Repeat identical seed/level with changed ID and stall profile | Identical key bytes; only requested ID and latency may differ. |
| KG-C05 | Same seed at all three levels | Reference-specific expansion includes k/l and produces the expected keys for each set; do not infer correctness merely from outputs differing. |
| KG-C06 | IDs 0, 1, 0x7fff, 0x8000, 0xfffe, 0xffff and offset-wrap neighborhoods | Outer ID preserved; internal arithmetic wraps only where specified, with no completion misassociation. |
| KG-C07 | Valid held before ready; busy command pulse; busy held command | Accept exactly at ready. Busy pulse gets no credit; a legally held command may become the next accepted job once ready returns. |
| KG-C08 | Mutate every command field after acceptance | Active result matches accepted snapshot. Checker also observes that no second command was accepted. |
| KG-C09 | Level code 3; operation code 3 at root | Correct rejection, zero key output and no engine work; held error completion and following valid recovery. |
| KG-C10 | Toggle all irrelevant message/randomness/input-stream fields | No Sign/Verify input credit, signature output or change to KeyGen result. |
| KG-C11 | Reset-level start valid, command at first legal post-reset edge | No acceptance during reset; one acceptance afterward with a fresh seed. |
| KG-C12 | Reproducible random seeds, levels and IDs | Exact independent outputs and coverage-driven selection of missing classes. |

### 6.2 Hashing, sampling, Pre-NTT and row arithmetic

| ID | Stimulus / observation | Pass conditions |
|---|---|---|
| KG-A01 | Seed message first/final 64-bit word and two-byte parameter suffix | Exact byte stream and length 34; unneeded high input bytes do not enter SHAKE. |
| KG-A02 | All 128 expansion bytes; transitions between rho/rhoprime/K | No missing/duplicated 128-bit output beat or wrong slice. |
| KG-A03 | First/last row and column; every coordinate for every level | Ahat coordinate-to-nonce mapping and coefficient order match the independent model. |
| KG-A04 | A candidates q-1, q, q+1, max 23-bit value; long rejection runs in controlled service stimuli | Accept only legal candidates; maintain byte grouping and stop at 256 accepted coefficients. Controlled arithmetic/service stimuli are not ordinary end-to-end NIST cases. |
| KG-A05 | Every eta=2/4 nibble acceptance/reduction class and carry between hash words | Independent secret sampling matches; 16 packed samples/packet and no lost leftover bytes. |
| KG-A06 | Both cores active; one core delayed/stalled; alternating single/paired batches | Each core keeps its own hash/sampler leftovers, ID and count. No peer completion replaces a stalled completion. |
| KG-A07 | Same-bank secret/matrix writes and different-bank concurrency | Legal ordering/arbitration; no conflict, lost word or stale data. |
| KG-A08 | Final sampler packet and final discarded SHAKE word; stop during permutation/squeeze | Stop, bridge drain, core idle and writer completion occur in legal order, once each. |
| KG-A09 | Each s1 polynomial through actual Pre-NTT mode | Coefficients/order/scaling equal independent NTT; confirm the optimized mode was really selected and executed. |
| KG-A10 | Compact nibble values -eta..eta, each lane and regroup position | Correct sign extension and Figure5 regrouping; compare all 256 positions. |
| KG-A11 | Synthetic arithmetic operands zero, impulses at 0/255, all q-1, alternating signs and randomized canonical values | Focused UVM service sequences verify NTT and row arithmetic independently. Count separately from seed-generated end-to-end cases. |
| KG-A12 | Every row's first, middle and final MAC term | Initialize once, accumulate l terms, no omitted/repeated term or cross-row accumulator carryover. |
| KG-A13 | s2 ready early/late and sampling overlapping secret transforms | No consumption before checked sample/transform completion; correct arithmetic under every legal ordering. |
| KG-A14 | Inverse transform and subsequent add | Correct inverse normalization and modulo-q addition; no duplicated scaling. |
| KG-A15 | Power2Round residues 4095, 4096, 4097 and neighborhoods of every 8192 boundary, plus 0 and q-1 | Correct tie convention, high carry, negative low part and 13-bit t0 encoding. Exhaust canonical coefficient domain in a focused arithmetic campaign where practical. |
| KG-A16 | Four-lane isolated and simultaneous arithmetic boundaries | All lanes and tags aligned; errors and result-valid refer to the same input word. |
| KG-A17 | NTT source-release before completion; delayed completion | Release enables only documented safe reuse; no premature destination read/overwrite. |
| KG-A18 | Service response before/after another core's response | ID matching and one-shot credit updates; no response accepted for an unissued/live-other job. |

### 6.3 Memory, packing and output forks

| ID | Stimulus / observation | Pass conditions |
|---|---|---|
| KG-M01 | Full memory-role sweep at each level | Correct bank/base/count from the role map, four 23-bit lanes and no out-of-range access. |
| KG-M02 | KeyGen A ring slots 0..8; more than one wrap | No occupied-slot overwrite; correct row/column after wrap; checked consumption before reuse. |
| KG-M03 | Packed t1 starts at bank3 word576 and uses 40*k words | A ring 0..575 stays disjoint; all pk data read from the correct addresses. |
| KG-M04 | Simultaneous A/B operations, conflicting and independent bank selections | Physical commitment follows the documented ordering; compare shadow memory, not just requests. |
| KG-M05 | Full/empty request queues and read-response skid buffers | Stable payload under stalls, no overwrite/drop, exact response and completion counts. |
| KG-M06 | Completion plus same-owner renewal; A/B renew on different clocks | No reservation lost or prematurely reassigned; other bank work may continue. |
| KG-M07 | Dirty RAM before job and level5 -> level2 -> level5 transitions | Results use only current valid locations; no assumption that reset cleared RAM. |
| KG-M08 | First/last coefficient, word63 and bank word1023 in focused legal memory tests | No truncation, address wrap or lane reversal; illegal descriptor bounds rejected by the actual service contract. |
| KG-P01 | Every t1 10-bit field and t0 13-bit field crossing byte/word boundaries | Decode observed encoded output with an independent bit reader and recover the reference polynomial. |
| KG-P02 | Public/secret frame boundary | Final pk last flag, first sk index0/type1, correct IDs; no intervening extra key or signature beat. |
| KG-P03 | rho/K/tr/s1/s2/t0 boundaries, first/last polynomial and field word | Correct ordering, exact lengths and no residual reservoir data in the next field. |
| KG-P04 | Host pk sink stalled while hash fork ready | Host word held; hash consumes each pk word once; tr and both final keys remain correct. |
| KG-P05 | Hash fork stalled while host ready | Same single-consumption property for both forks; no premature source advance. |
| KG-P06 | Both sinks stalled, alternate release order, including final pk beat | No deadlock under eventual readiness; one shared source word cannot be lost or duplicated. |
| KG-P07 | Compare tr from observed pk bytes, then sk's embedded tr | Exact 64-byte digest, not a digest of internal t1 or only part of pk. |
| KG-P08 | Stall first, interior, last pk/sk words and the frame transition | Valid/data/type/index/bytes/last/ID stay stable; completion does not bypass blocked output. |
| KG-P09 | Hold completion ready low; change unrelated host pins | Exactly one held completion with stable fields; no command acceptance or engine reuse until legal retirement. |
| KG-P10 | Ready high before valid and permanent ready | No phantom transfer, no duplicate last word, exact expected beat totals. |

### 6.4 Reset, faults, recovery and mixed operations

| ID | Stimulus / observation | Pass conditions |
|---|---|---|
| KG-R01 | Reset in each phase listed below, with zero/one/two queued words | Control/ownership flushed, publications invalidated and no canceled completion. |
| KG-R02 | Reset on command, output and completion handshake edges | Defined reset priority; monitor does not credit a reset-aborted transfer as a completed operation. |
| KG-R03 | Reset with stalled output, both hash cores busy or pending memory response | No stale held word/response gains credit after reset. Already committed RAM may remain. |
| KG-R04 | Recovery with same ID/new seed; same seed/new level; different operation | Fresh result matches model, including first legal command after reset. |
| KG-F01 | Wrong/duplicate/stale sample response ID or core tag; nonzero service status | Expected fatal quarantine, no successful completion, and only reset recovers. |
| KG-F02 | Wrong raw digest ID/byte count; early/late or duplicate completion | Detect at the accepting boundary; never publish a falsely checked key pair. |
| KG-F03 | NTT/Process error, physical memory error, ownership/collision fault | Immediate suppression of public key/signature/done/start; no new work admitted after fault. Internal finite cleanup must follow its documented policy. |
| KG-F04 | Fault while first/last key beat or completion is stalled | Quarantine wins over normal publication. Previously transferred prefix is recorded as aborted, not rolled back or counted as a valid key pair. |
| KG-F05 | X/Z in valid control, accepted payload or service metadata | Four-state checker detects it; unobserved/unqualified RAM bits are not blanket failures. |
| KG-X01 | All nine KeyGen/Sign/Verify ordered operation pairs, all level pairs | No stale owner, seed, key, hint, formatter or response leaks across operations. |
| KG-X02 | Long randomized legal jobs with dirty RAM and varied stalls | Full reference checking and eventual resource retirement after every job. |
| KG-X03 | KeyGen -> Sign -> Verify using generated encoded keys | Interoperability succeeds in every level and message mode supported by the companion plans; independent final-output checking still required. |
| KG-X04 | Corrupt scoreboard expected byte, observed ID/type/index/last, completion or memory expectation one at a time | Checker fails for the intended reason; no success/coverage credit for the corrupted case. |

Reset phase set: root admission, seed command/feed/permutation/output, first and
second sampler dispatch, compact regroup, Pre-NTT load/run/drain, matrix-ring
wrap, MAC, inverse, s2 add, P2R, packing, pk dual-sink fork, pk hash drain,
sk header/fields, final output, held completion and root retirement. Cross each
phase with all levels and a representative stalled/full boundary. For every
nonfatal error/reset, schedule a subsequent good job that checks recovery.

For missing input/readiness, distinguish a legal pause from a completed bad
frame. There is no assumed autonomous DUT timeout. A permanently stalled sink
is a safety test; a simulation watchdog must not invent a hardware error code.
Illegal source behavior such as changing a stalled offer is a driver/protocol
negative test, with an expected checker failure, not a required crypto result.

## 7. Functional coverage model

Proposed groups below extend the existing coverage subscriber. Every operation
bin samples after full scoreboard-checked retirement. Stage/resource bins use
independently checked accepted internal events. Reset and injected-fault bins
sample through separately checked abort/fault records. Keep these denominators
and outcomes separate; reaching a phase by itself earns no algorithmic pass.

| Group | Coverpoints and required crosses |
|---|---|
| `kg_command_cg` | Level, ID classes, accepted/rejected command, busy offer and held-valid acceptance; level x ID class x command outcome. |
| `kg_seed_cg` | Seed pattern class, changed byte/bit position, repeat/new seed and byte-asymmetry; level x pattern, each seed byte/lane. Do not create 2^256 seed bins. |
| `kg_expand_cg` | k/l suffix position, expansion field, output core, first/interior/last beat; level x field x core. |
| `kg_sample_cg` | A/s1/s2, eta, nonce first/middle/last/wrap neighborhood, row/column, accepted/rejected candidates, hash-block/byte carry; level x kind x core, kind x boundary. |
| `kg_context_cg` | Single/paired batch, active-core mask, completion order, bridge occupancy, stop/drain phase; kind x core mask x completion ordering. |
| `kg_regroup_cg` | Core, all 16 packet positions, nibble lane, sign/value class and group destination; level x core x quarter, every coefficient position checked. |
| `kg_pre_ntt_cg` | Actual NTT mode, compact/general source, polynomial index, lane/address boundary and release timing; level x mode x index. |
| `kg_row_cg` | Row/column, initialize/accumulate, source-ready ordering and inverse/add phase; all legal row x column pairs per level. |
| `kg_p2r_cg` | Four lanes; remainder below/equal/above4096; zero/q-1; t0 sign/extrema; level x lane x tie class. |
| `kg_memory_cg` | Role, bank, physical port/client owner, address boundary, command mode, queue occupancy and real commit event; role x bank and conflict x port. |
| `kg_ring_cg` | Slot0..8, empty/full, wrap count class and producer/consumer overlap; level x wrap x occupancy boundary. |
| `kg_pack_cg` | pk/sk field, polynomial first/middle/last, bit-boundary crossing and frame transition; level x field x boundary. |
| `kg_fork_cg` | Host/hash accepted mask, host/hash first consumer, held duration, final-beat condition; all legal sink-order combinations. |
| `kg_output_cg` | pk/sk type, index class, first/last, ID, output stall and completion hold; level x type x stall location. All legal key-tail bins are eight bytes. |
| `kg_reset_cg` | Checked abort phase, level, queue occupancy, active cores and recovery op/level; every required phase per level and same-ID recovery. |
| `kg_error_cg` | Root reject vs service fatal, cause, phase, checked quarantine and successful post-reset recovery; error cause x phase where reachable. |
| `kg_sequence_cg` | Previous/current operation and level, same/new ID, previous error/reset/success; all operation pairs and level pairs. |
| `kg_latency_cg` | Measured phase clocks, stalls, overlap and end-to-end latency buckets; compare identical seeds/traffic, not a fixed universal cycle count. |

Use targeted crosses for risk combinations, not an uncontrolled Cartesian
product. Exhaust legal small enum/row/column/lane spaces; use pairwise traffic
crosses plus directed multiway cases for reset, last-word and ownership hazards.
Unreachable bins need a written reason and review. Do not create impossible
key tails or force misses to hold overall coverage below a chosen percentage.

For each bin retain: requirement/test ID, definition/sample location, observed
event/case/seed, checker result and hit count. Example: a “pk hash-only accepted”
bin needs an observed hash acceptance without host acceptance, the held host
word later accepted exactly once, and a checked tr/final key result.

### Requirement-to-test-to-coverage traceability

These are minimum links. Each expanded case needs a tracker row with
requirement ID, concrete UVM sequence, checker/assertion, bin name, source
identity, observed evidence and result. Until implemented and executed its
status is **planned**, regardless of older captures.

| Requirement | Test families | Independent evidence | Coverage groups |
|---|---|---|---|
| KG-REQ01 command/seed ownership | KG-C01..C12 | Accepted-command snapshot and full key bytes | command, seed, sequence |
| KG-REQ02 seed expansion/domain separation | KG-A01..A02, KG-C05 | Exact SHAKE input and rho/rhoprime/K | expand, command |
| KG-REQ03 matrix/secret sampling | KG-A03..A08 | Candidate decisions, coefficients, context IDs and drain | sample, context, regroup |
| KG-REQ04 Pre-NTT and row arithmetic | KG-A09..A14, KG-A17..A18 | Full normalized polynomials and MAC term count | pre_ntt, row, context |
| KG-REQ05 Power2Round | KG-A15..A16 | Recomposition, tie, ranges and packed t0 | p2r, pack |
| KG-REQ06 memory lifetime/commit | KG-M01..M08 | Physical-issue shadow memory and owner versions | memory, ring |
| KG-REQ07 encoding and public-key hash fork | KG-P01..P07 | All bytes, independently decoded fields and tr | pack, fork, output |
| KG-REQ08 transport/completion | KG-P08..P10, KG-C07..C11 | Stable offers, exact beat/retirement counts | output, command, latency |
| KG-REQ09 abort/fatal containment | KG-R01..R04, KG-F01..F05 | Checked abort/quarantine and following good job | reset, error |
| KG-REQ10 composition/checker soundness | KG-X01..X04 | Independent round trip, mutation detection and clean accounting | sequence plus affected feature groups |

Group names above use the `kg_..._cg` prefix/suffix from the coverage table.
Sweep all 65,536 job IDs in a focused descriptor/ID arithmetic UVM check where
practical; expensive full KeyGen uses the directed ID neighborhoods and random
samples. Never confuse that focused exhaustive space with full-seed enumeration.

## 8. Assertions and checker self-tests

Implement or bind properties for: command acceptance only when ready; single
root owner; accepted metadata lifetime; stable valid key/completion under stall;
no Sign/Verify input credit during KeyGen; key type/order/index/last/count;
no completion before both key frames and all physical retirements; per-core
descriptor ownership; finite raw-hash byte credit; queue overflow/underflow;
no read before checked production; no role overwrite before source release;
atomic port ownership through completion/renewal; publication suppressed on
fatal fault; no stale publication after reset; no duplicate completion; and
eventual completion under explicitly bounded service/sink fairness assumptions.

Use covers to show each assertion's antecedent actually occurred. Test the
checkers with deliberate one-byte, one-lane, ID, framing, missing/extra-word,
early-completion and stale-memory corruptions. Planned failures must fail,
and their runs must not merge into clean qualification coverage.

## 9. Code coverage, campaigns and acceptance

Collect DUT statement, branch, condition, expression, toggle and inferred FSM
state/transition coverage with `run_uvm.do`. Include executable package logic;
exclude testbench/vendor primitives from the reported DUT denominator. Report
per-module and overall raw hit/eligible counts for each enabled metric, plus
the tool-defined aggregate. Do not average module percentages or mix helper
proof databases into main UVM without an explicit source-identical merge policy.

Review misses in every KeyGen FSM state/transition, producer states, first/final
loop decisions, batch-size1/2 paths, ring wraps, both cores, P2R ties, packer
refill/drain, fork sent flags, invalid commands, error/fatal/reset paths and
every active memory mode. Exclusions for constants, elaboration modes and
unreachable states need evidence; dormant fault paths need an injection test
or an approved explanation. Coverage is never artificially capped.

Campaign order: checker self-tests -> small directed UVM smoke -> full KeyGen
NIST corpus -> custom seed/reference campaign -> transport/phase stress ->
memory/dual-core overlap -> protocol/fault/reset recovery -> mixed-operation
soak -> coverage closure. Keep expected-failure runs separate. Change-aware
focused tests precede expensive full campaigns; synthesis/fit follows the
project workflow, with one expensive job at a time.

Existing entry points (these run the current implemented suite, not all new
families in this document):

```powershell
C:/Python314/python.exe sim/dilithium/dilithium_vectors.py uvm_prepare
```

```tcl
set DILITHIUM_UVM_TEST dilithium_regression_test
do sim/dilithium/run_uvm.do
# Existing transport-randomized alternative:
set DILITHIUM_UVM_TEST dilithium_random_stall_test
do sim/dilithium/run_uvm.do
```

Acceptance requires all mandatory test families expanded and passing or a
reviewed disposition; all supported NIST cases accounted for; exact pk/sk
and relevant intermediate comparisons; stable transport and clean retirement;
every reset/error recovery checked; checker-negative tests detected; no
unexplained UVM errors/fatals; and reviewed functional/code coverage gaps.
Every critical reachable bin must be hit or explicitly waived with evidence.
There is no claim that a percentage alone proves correctness.

Save source/reference/vector identities, tool/version/seed, test list, original
tgId/tcId, observed outputs, checked/aborted/error counts, phase/operation clocks,
UCDB, bin reports, code reports and reproducible failure traces. Use current
normal artifact names and existing evidence storage; do not create a new
script/archive for each test. Existing result numbers do not automatically
qualify this larger plan. Post-synthesis/post-fit/FPGA campaigns remain gated.
