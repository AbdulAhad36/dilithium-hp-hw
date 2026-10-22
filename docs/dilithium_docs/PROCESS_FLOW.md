# Dilithium processing flow

## Stage5N.3 checked process-memory flow

1. Accept a tagged Decompose/CNB/Mhint request after existing service owners drain.
2. Lease sources immediately;read/validate owner,region,word,level and coefficient domain.
3. Wait for selected result regions to become free;allocate two for Decompose,
   none for CNB,one for Mhint.
4. Read64 ordered x4 groups,rechecking metadata and retained modes. Check all
   stored high23 bits before narrowing for Mhint.
5. Feed sign_process. Store canonical lows/highs/hint bits through the existing
   scalar packers;CNB only accumulates a rejection flag.
6. Wait for64 acknowledged result words per destination and finish handshake(s).
   Publish both Decompose outputs together. Hold completion and leases until accepted.
7. On late error,drain/discard every tentative destination before reporting an
   error;clear partial reductions/tracking. Reset cancels ownership.

This path is integrated into dilithium_services and tested using real sampling
and shared memory. Main Sign does not issue it yet. Next implement signing
key/input decode and hash formatting,then vector checks/retry/signature control.
Earlier milestone paragraphs below describe their historical state.

Stage5N.2 adds the arithmetic for the next signing steps:
Decompose(w) supplies high/low parts;CNB checks z,corrected low and ct0 bounds;
Mhint derives hints from corrected low plus retained high. sign_process checks
64 ordered x4 groups and returns norm/hint prefix reductions. These blocks
are independently verified now;they do not yet receive commands from Sign.
Next connect shared-bank DMA and acknowledged result publication,then signing
inputs/hash/retry/packing control. Complete KeyGen remains the active operation.

## Stage5L implemented complete KeyGen sequence

1. Main FSM accepts operation0,level2/3/5,ID and32-byte xi.
2. Existing RTL expands xi,samples s1/s2,retains/Pre-transforms s1,and
   processes every matrix row through PWM/ADD/inverse,s2 addition and P2R.
3. Full-key mode accepts row results internally;retained t1/t0 stay in the banks.
4. After all matrix sampling finishes,submit the PK hash descriptor to the
   same raw SHAKE service. Stream rho and Bitpkg(t1) to host and hash exactly
   once each,with independent backpressure.
5. Collect64-byte tr and retire that physical hash request.
6. Stream rho,K,tr,Bitpkg(s1),Bitpkg(s2),Bitpkg(t0) as the secret key.
7. Wait for every word and packet completion,then assert held overall done.
   On its acceptance,free retained regions and allow the next operation.

Both complete keys match the unmodified final-format C KeyGen at all levels.
Stage5M also matches all75 official NIST keypairs. Next add the Sign
controller/remaining LightHD process blocks on the existing shared resources.
Full UVM/PPA optimization remains
after supported operation outputs. No Sign/Verify functionality is claimed yet.

## Stage5K rounding before key encoding

With ROUND_OUTPUTS=1,the autonomous scheduler now performs P2R after every
t=A*s1+s2 row. It stores all t1/t0 fields in dedicated existing bank regions,
preserves them across subsequent matrix rows,and makes them readable while
overall completion is held. Existing temporary cleanup still follows each t row.

The working Bitpkg block encodes one polynomial field per command. Its t1,
t0 and secret bit order agrees with the software C packers at all levels.
It is currently independently exercised;the next step is a bank read/field
sequencer for rho,t1,rho,K,tr,s1,s2,t0 in final key order,plus SHAKE256(pk,64)
for tr. Complete public/secret-key byte outputs are not yet claimed.

## Stage5J autonomous polynomial execution

Only a start operation,level,ID and32-byte xi are required:
RTL expands the seed; samples s1 nonces0..l-1 and s2 noncesl..l+k-1;
retains raw secrets; Pre-transforms s1 once; samples each A_hat row;
runs PWM/accumulation/inverse; adds s2[i]; and presents tagged coefficient
rows t_i. The caller reads and accepts each row. RTL frees row temporaries,
retains secrets/transforms until overall completion acceptance,and cleans
them up before accepting another operation.

This phase now runs for levels2/3/5. It ends at t=A*s1+s2. Still required:
Power2Round integration into this KeyGen schedule,t1/t0/secret byte packing,
public-key hash tr and complete public/secret-key output. The P2R arithmetic
is implemented under process/ and already independently tested.

## Stage5I implemented seed-to-row path

1. Submit op0 with xi32 and level. RTL sends xi||k||l to the same dual Keccak,
   accepts eight128-bit output beats and retires the raw request.
2. Retain rho32,rho-prime64,K32. Hold source completion until accepted.
3. Submit op2 with an s1 nonce and explicit bank region. RTL formats the secret
   message and waits for actual sampling plus acknowledged memory publication.
4. Use eligible Pre/ordinary NTT to retain transformed s1. Submit op1 descriptors
   for A[row,column];RTL formats each matrix message from retained rho.
5. Run the existing row scheduler through PWM,accumulation and inverse NTT.
   Seed state and transformed secrets survive ordinary row completion;reset
   invalidates them together with bank metadata.

This complete connected path now passes selector5/seed_row. The bench still
schedules commands;the adapter is not an autonomous KeyGen sequencer.
Next:generate all s1/s2 nonces and matrix rows under controller control,add
s2[i] to each inverse row,then Power2Round and serialize the keys.

## Selected first KeyGen direction — LightHD memory/reuse

Final FIPS204 bytes are selected,with level2/3/5 names. The user chose LightHD's
four-bank organization and reuse strategy. The bank foundation passes its tests;
Stage5E connects sampling,per-context word packing and region ownership;
Stage5F adds source leases,word DMA and NTT result storage;Stage5G adds banked
ADD/SUB/Power2Round with low/high result storage. Stage5H adds staged-row
PWM/accumulation/inverse scheduling. Full KeyGen/Sign phase scheduling remains
next. Figure2 is the peak
Sign memory map,so complete KeyGen addresses/ownership must be derived and
checked rather than assumed to be fully specified by that figure.

1. Expand a test-supplied32-byte seed into rho,rho-prime and K using the selected
   reference's exact input formatting. The optional shared raw-hash service and
   keygen_seed_collect now pass their focused gate. The tested
   keygen_hash_message builder now emits SHAKE256(xi32||K||L),requesting128 bytes.
   Collect bytes0..31 as rho,32..95 as rho-prime,and96..127 as K(key seed).
2. Sample s1 and retain secret data for key encoding/subsequent signing. Schedule
   s2 once alongside the matrix stream as capacity permits. Use eligible
   Pre/NTT for s1 and retain transformed s1 for reuse across matrix rows.
   For each matrix row i and column j,sample A_hat[i,j] using exact
   row/column/secret nonces. The formatter emits rho||column||row for A and
   rho-prime||nonce_le16 for secrets. s1 uses0..L-1;s2 uses L..L+K-1.
   A_hat is already transformed;do not forward-transform it again.
3. Compute PWM and accumulate the row in transform domain using modular ADD.
   Reuse a64-word accumulator region across columns. Consume bounded A staging
   entries as they are generated;do not regenerate s1 for each row as in the
   superseded four-slot proposal. Prove read-before-overwrite on accumulator reuse.
4. Inverse-transform the row sum,obtain the stored/scheduled s2[i],and add it
   modulo q. Preserve each raw secret until key encoding has consumed it;do not
   overwrite its only copy merely because a transformed cache exists.
5. Power2Round each t coefficient into t1 and t0;encode them using the selected
   byte format. Preserve t0 until the chosen key-output/storage destination owns it.
6. Hash the complete encoded public key to obtain tr;encode the secret key
   with the required seed/hash/secret/t0 fields. Byte order and hash length
   must follow the selected version. Compare complete keys with its reference.

The shared coefficient ADD/SUB/Power2Round unit now passes its isolated tests.
The shared raw hash service,seed/nonce builder and seed collector pass focused
tests and now feed the banked row path in Stage5I. Process/memory routing
passes Stage5G/H. Still required:byte serializers/key storage and the actual
main-controller schedule. See MEMORY_MAP.md for the selected dimensions and
published Sign regions. The prior four-slot regeneration/ten-slot proposals
are superseded. Extra encoded-key buffers are not silently allocated.

## Current Stage4 sampled-polynomial arithmetic

1. Submit real sampling jobs and wait for successful slot commit using the
   producer/storage flow below. Keep Matrix A marked transform-domain.
2. Present opcode,source slot(s),expected source ID(s) and a new result ID.
   The helper accepts the command after active sampling and old reads retire.
3. Memory validates state/IDs/domain/Pre eligibility and PWM parameter agreement.
   Invalid requests return a held rejection reply without starting the engine.
4. For a valid request,wait for a free destination,lock sources and reserve it.
   Inputs remain stored. The four-slot pool may need an unrelated slot released
   before proceeding;no implicit overwrite or automatic input release occurs.
5. DMA reads A indices0..255,and B0..255 for PWM,with one outstanding read.
   Engine arithmetic uses normal canonical residues;INTT includes its scaling.
6. Write results0..255 into the reserved slot. Wait for engine done,then commit
   the destination and unlock sources. Offer the tagged completion until accepted.
7. Read/consume the completed result and explicitly release slots after their
   scheduled consumers finish. A new NTT job is not loaded while one is active.

Tested mathematical chain:A_hat (directly sampled) and s -> NTT(s) ->
PWM(A_hat,NTT(s)) -> INTT -> coefficient polynomial. Python independently
checks this against schoolbook(inverse(A_hat),s) in Z_q[x]/(x^256+1).
Pre(s) equals NTT(s),and INTT(NTT(s)) equals s exactly. Reset cancels the
whole subsystem during DMA load,core execution or writeback;new jobs recover
with fresh messages,including reusing the same source/result IDs.

This is still a subsystem flow. Full KeyGen/Sign/Verify scheduling,seed/nonce
assembly and remaining process blocks come in Stage5.

## Preserved Stage3 memory transaction

1. Reserve a free polynomial slot on the same handshake that accepts the job;
   capture job_slot_o and actual job_core_o for the future controller.
2. Run the Stage2 SHAKE/sampling flow below. Tagged coefficient writes must
   match the slot owner,index,last and canonical range.
3. Keep the slot WRITING through all256 writes and source drain. A premature
   read returns an error;the last coefficient alone does not commit the slot.
4. Successful external status acceptance commits COMPLETE. An expected error
   frees the slot;reset invalidates all slots and pending responses.
5. Request coefficients by slot/index. A synchronous response carries data,
   job ID,mode,parameter and domain;hold it stable under backpressure.
6. Release the slot explicitly after its scheduled consumers finish. A pending
   read response blocks release. Pool exhaustion stalls new jobs.

The focused testbench drives public reads/releases. Stage4 additionally supplies
NTT compute descriptors and checks DMA/result/commit behavior.

## Preserved Stage2 producer transaction

1. Present the sampling mode,parameter encoding,ID and absorption-message length.
2. Hold the descriptor until ready/valid accepts it;capture assigned core.
3. Feed exactly the declared message on64-bit beats,earliest byte in bits7:0.
   Keccak handles the final partial word using the declared byte length.
4. Keccak absorbs,pads,permutes and produces a tagged SHAKE stream.
5. The shared two-slot registered-credit queue passes data/byte count/core to the matching
   sampler context. Concurrent jobs keep separate parser/carry state.
6. The sampler emits256 canonical23-bit coefficients,with job ID,core,index and
   last. The Stage3 receiver is polynomial memory;the preserved Stage2 test
   still checks the producer stream directly.
7. On sampler stop,the adapter drains/discards surplus,then stops Keccak after
   releasing its held output. It waits for old source tokens to retire.
8. The external status handshake releases the context for a new job.

Invalid parameter3 produces the existing parameter-error status after safe
upstream retirement. A coordinated reset cancels both jobs;partial polynomials
must be discarded. The focused test checks accepted partial prefixes and then
checks same-ID recovery with different messages.

## Implemented versus planned

| Operation | Current ownership |
|---|---|
| Raw absorbed message generation | Stage4 uses test vectors;isolated keygen_hash_message now formats final KeyGen seed/A/secret messages;not connected to main top |
| Raw hash/seed collection | Optional service in keccak_sampler plus keygen_seed_collect;focused seed-to-real-sampler gate PASS;main Stage4 top disables the raw client |
| SHAKE128/256 | Accepted Keccak RTL |
| A/secret/mask/challenge sampling | Accepted sampler RTL |
| Job binding,two-slot credit bridge,stop/drain | controller/keccak_sampler.sv |
| Polynomial allocation and memory writes/readback | controller/memory.sv and keccak_sampler_memory.sv;Stage3 source PASS |
| NTT/INTT/PWM/Pre-NTT | src/ntt/ imported unchanged;controller/keccak_sampler_ntt.sv DMA/source locks/result commit;Stage4 source PASS |
| Banked NTT routing | controller/keccak_sampler_ntt_banks.sv;sequential92-bit word DMA,source leases,shared packer and acknowledged result publication;Stage5F PASS |
| Modular ADD/SUB and Power2Round | poly_process.sv plus process/poly_process_dma.sv;Stage5G banked path PASS with PROCESS_SERVICE=1 |
| Staged matrix-row execution | row_accumulate.sv plus keccak_sampler_row.sv;Stage5H returns u_i=INTT(sum_j A_hat[i,j]*s1_hat[j]);one reused accumulator/product scratch;PASS |
| Full KeyGen/Sign/Verify schedules,decompose/hints/encoding | Later controller/process stages |

A is already transform-domain data and will go to operand storage/PWM. Small
secrets can later use ordinary NTT or eligible Pre-NTT with one owner for the
first-stage work. Final FIPS204 is the selected format;complete controllers,
memory scheduling and exact-output checks remain before a full-operation claim.
