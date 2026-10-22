# Dilithium verification test plan

## Stage5N.3 checked shared-bank signing processes

| Requirement | Evidence/check |
|---|---|
| Command validation |Invalid opcode,level,CNB kind,source owner/missing region,coefficient-domain/parameter mismatch and destination aliases |
| Every-word integrity |Explicit late owner,param,mode,region,word,error and noncanonical-data faults at group17;exact metadata checks on each read |
| High narrowing |Stored high64 at group17 and high44/16 at last group;must error and rollback,never truncate and accept |
| Canonical results |Independent Python checks every low/high/hint scalar,packed BRAM request and committed92-bit word at all levels |
| Commit ordering |BRAM request precedes ACK;all64 ACKs precede successful finish;two Decompose results publish together |
| Error cleanup |Tentative results discarded by nonzero finish after writes drain;no leaked reserved destinations;next command works without reset,including same-ID retries |
| Lease lifetime |Source protected on acceptance edge,through destination wait and held done;destination protected until done retirement;unrelated occupied destination may be released |
| Reset |Wait-free,read response,partial writes,between Decompose commits,held completion and partial CNB reduction;ownership/result-valid cleared and reused |
| Stalls |Allocation,read request,response,write and finish stalls;held completion fields stable |
| Shared arbitration |Actual main-owned services:pending public read,row,NTT,scalar process precede signing;other clients blocked while signing owns banks |
| Integration output |Real SHAKE/sampler mask sources -> Decompose/CNB/Mhint -> same four banks -> exact host readback |
| Checker independence |32 DMA +33 service corruptions rejected;include premature ACK/finish,reset-prefix data and missing witness evidence |
| Regression |Rerun sign_process,bank_process,local full_keygen and all75 official nist_keygen cases with current source token |

These focused gates do not constitute full-system UVM or coverage closure.
No fabricated coverpoints or target percentage is introduced. Full Sign key
decode/hash/retry/vector reductions/packing and Verify remain later work.
See REFERENCE_VERIFICATION.md for commands,files and measured counts.

## Stage5N.2 signing-process arithmetic and packets

| Requirement | Test/check |
|---|---|
| Decomposition |All3 levels,each high bin's positive tie and adjacent inputs,q-1/special wrap,zero,max,random coefficients |
| CNB |All3 bounds/levels,positive and negative equality/adjacent inputs;early failure followed by passing groups;last-lane late failure |
| Mhint |Corrected low/high convention checked by independent HighBits change;both sides of negative tie,high0/high maximum,all-zero/all-one/random hints |
| Reduction |Sticky CNB failure;Mhint weights0..256 and omega/omega+1 examples;clear at packet boundary/reset |
| Validity |Noncanonical values in each lane,invalid op/level/relevant kind/high;zero returned fields on error |
| Identity/order |Exactly64 groups;wrong initial/duplicate/skipped index,last,ID/op/param/relevant-kind changes |
| Independent errors |Changed opcode carries otherwise valid Mhint data/high,so an unrelated data error cannot mask missing opcode-lock checks |
| Recovery |Every malformed fixture followed by a valid polynomial;six held middle/final output resets with same-ID different-data recovery |
| Backpressure |Stable full payload/metadata for blocked input/output;7509 simultaneous replacements,2865 input stalls,2903 output stalls |
| Oracles |Python division/centered norm/high-bit-change versus unchanged C functions;C decompose exhaustive at each level |
| Checker |27 deliberate corruptions,including zeroing a sticky reject where current lane failures are zero |

7752 accepted groups produce7746 checked results,including45 expected errors;
6 groups abort on reset.117 complete polynomial packets are checked. These
are focused functional tests,not a new coverage percentage or full Sign proof.

### Concrete witnesses in stage5_sign_process inputs/outputs

Case numbers are zero-based input indices;lane0 is the least-significant lane.
Every witness is part of the complete file comparison,not only stimulus intent.

| Feature | Actual case/lane | Expected and checked result |
|---|---|---|
| Positive tie |65/lane0:a=95232 |high0,low+95232 |
| Next value |65/lane1:a=95233 |high1,low-95231 |
| q-1 special wrap |119/lane3:a=8380416 |high0,low-1 |
| Norm equality |320/lane1:a=130994,kind0,level2 |lane reject1,error0;lane0 at130993 passes |
| Sticky norm failure |322:all four inputs0 |lane mask0,prefix reject1 from earlier groups |
| Hint negative tie/high0 |1152/lane1:a0=-95232,a1=0 |hint0 |
| Hint negative tie/high1 |1154/lane2:a0=-95232,a1=1 |hint1 |
| Full hint population |1151:final group of all-one hint packet |hint mask15,prefix weight256 |

Later Sign verification must still check vector-wide norm/hint limits,all
memory lifetimes,full signing retries and final encoded signatures.

## Stage5N.1 operation-level resource ownership

| Requirement | Check |
|---|---|
| One physical service set |Main dilithium_services owns the existing banked engine subtree and one Bitpkg;KeyGen/encoder contain no engine/packer instance |
| Exact routing |Entire packed request equals the KeyGen client request on every owned cycle |
| No owner |Entire request is zero;no outstanding engine,bank or packing work |
| Cleanup lifetime |Owner remains active when main is IDLE but KeyGen is busy freeing retained regions |
| Reset |Existing five full-key abort/recovery phases reset both client and services |
| Reuse |Next command only after cleanup;all75 official seeds run without intervening resets |
| Functional preservation |Rerun full_keygen,nist_keygen and both diagnostic modes;unchanged published key bytes and independent arithmetic oracles |
| Witness/fault tests |Q record requires owned,cleanup and idle phases;missing witness and zero cleanup credit must fail |
| Limits |Only KeyGen is connected;no Sign/Verify contention,fairness,PPA or whole-system coverage claim |

No source-level engine arithmetic is changed. The two new service source files
are included in freshness hashes and the prepared Questa/Quartus source lists.
All four gates pass on one current token:full_keygen,nist_keygen,keygen and
rounded_keygen. Their checker fault totals are37,41,29 and36 respectively.
See REFERENCE_VERIFICATION.md for exact arithmetic counts and ownership witnesses.

## Stage5M published NIST KeyGen cases

Selector nist_keygen uses the same full-KeyGen bench with NIST_VECTORS=1.
The complete pinned corpus contains75 cases,25 per parameter set;all are
required for a passing result. Local reset/rejection tests remain a separate
selector so official cases are never substituted with locally chosen seeds.

| Requirement | Check |
|---|---|
| Provenance |Pinned NIST revision,exact raw-file SHA256,size,algorithm/mode/revision and vsId |
| Case binding |Join by(tgId,tcId);reject duplicates,missing/extra cases,wrong parameter counts or key lengths |
| Oracle independence |Expected PK/SK copied directly from NIST JSON;separate C-versus-NIST check |
| Actual full operation |Bench drives only seed/level/start,output/done backpressure and initial reset |
| Exact keys |Every byte of both keys at all75 seeds;correct type,index,bytes,last,ID and output order |
| Shared hash |Actual PK absorption equals published PK;tr equals SHAKE256(PK,64) and the SK header |
| Memory |Correct source-region/owner/domain/field order;no retained source released before retirement |
| Reuse |All75 operations run successively;zero leases before restart;IDs cross65535 |
| Checker sensitivity |Mutated seed/level,tags,lengths,data,hash,ownership,missing/duplicate events and missing whole case must fail |
| Scope |Source KeyGen KATs;does not implement Sign/Verify or establish UVM coverage/PPA/certification |

Results and reproduction commands are recorded in REFERENCE_VERIFICATION.md.
Stage5M:75/75 complete keypairs,433600 exact key bytes,39 checker faults PASS.
The local full_keygen suite freshly repeats8 successful keys,3 rejects,5 resets
and35 checker faults on the same updated source token.
Stage5L's immutable archive preserves the earlier16-gate regression. After
the harness extension,only newly rerun gates are reported as current-token
results;old loose captures remain historical until recaptured.

## Stage5L complete key serialization and PK hashing

| Requirement | Checked behavior |
|---|---|
| Complete keys |8 successful keypairs equal unchanged C KeyGen bytes;all levels2/3/5 |
| Independent hash |All2058 accepted PK absorption words and656 tr bytes compare independently;includes abort prefixes |
| Tagged output |5433 exact64-bit words;per-key index,ID,type,last,length and PK-before-SK order |
| Read ownership |11179 field-read metadata records follow t1,s1,s2,t0 order with exact region/owner/level/domain |
| Shared resources |Real raw service and existing banks/Bitpkg;no testbench-generated hashes/coefficients |
| Fork |Independent hash/host backpressure;stable held words,no duplicate delivery;both acknowledgement orders |
| Reset |Hash-first stalled PK header,partial PK,tr first beat,partial SK secret field,held overall completion |
| Recovery |Same-ID different-xi recovery;three ordinary operations restart without reset;ID65500 internal wrap |
| Lifetime |Retained sources cannot release before overall done handshake;zero reservations before next start |
| Rejects |Invalid level and unimplemented Sign/Verify:no keys,hash requests or field reads |
| Checker |35 corruptions rejected,including duplicate delivery,missing hash done,wrong SK bytes and early release |
| Remaining gates |Official NIST full-KeyGen vectors,Sign/Verify controllers,full-system UVM and PPA |

This focused source test is selector full_keygen in the existing launcher.
Earlier15 tests remain separate regression gates. Complete byte agreement
with a local software reference is distinct from published-vector conformance
and from exhaustive functional/code coverage.

## Stage5K rounded KeyGen and polynomial packing

| Requirement | Evidence |
|---|---|
| P2R connection |34 delivered rows at all levels;both rounded arrays committed before row publication |
| Rounded retention |t1/t0 survive later rows and are read before overall completion;cleanup/reuse/reset checked |
| Arithmetic/metadata |190224 scalar values,12800 exact92-bit reads,rounded pair IDs/regions and domain metadata |
| Rounded checker |36 corruptions rejected,including both array values/IDs and missing high commit |
| Bitpkg formats |t1,t0,secret eta2/eta4;all three levels,six data patterns per format/level |
| External reference |66 valid fixture packets/18496 bytes equal unchanged C polynomial packers |
| Malformed packets |31 expected errors;invalid command/level,value,index,last;final status invalidates prefix |
| Stalls/reset |Held outputs/completions;six aborts and same-ID different-data recovery;18292 accepted inputs,2482 exact words |
| Bitpkg checker |15 corruptions rejected |
| Remaining scope |Bank read/packer connection,complete key field order,public-key hash,encoded key outputs and official whole-operation tests |

No new full-system coverage percentage or PPA result follows from these directed
gates. Existing thirteen selectors remain regression baselines;the two new
selectors are rounded_keygen and bitpkg in the same run.do/Python script.

## Stage5J autonomous KeyGen polynomial phase

| Requirement | Checked workload |
|---|---|
| Autonomous control |Bench drives start/read controls only;all seed,nonce,transform,matrix,row and ADD commands originate in RTL |
| Full parameter coverage |All s1/s2 nonces and all matrix positions for levels2/3/5;canonical23-bit residues |
| Arithmetic/output |34 complete t=A*s1+s2 rows;172304 scalar writes;8448 exact92-bit public reads |
| Independent model |hashlib plus sampler/direct NTT references;alternate coefficient-domain schoolbook row0 at every level |
| Retention/reuse |Raw s1/s2 and transformed s1 read back before overall completion;transform cache reused across rows |
| Boundaries |Invalid level,unsupported Sign/Verify with no child side effects;ID65500 wrap |
| Reset |Partial seed,first secret prefix,held first output row,partial accumulator rewrite;different-xi same-ID recovery |
| Ownership |Held row/final completion;136 pending-read handoff checks;no region released while final row response is held |
| Cleanup |Exact release order,zero remaining reservations,normal operations restarted without reset |
| Checker integrity |29 deliberate corruptions rejected |
| Limits |Polynomial phase only;no encoded key bytes/official full-operation vectors/full-system UVM or PPA |

The existing twelve focused gates remain independent regressions after source
relocation and Power2Round extraction. Their coverage/metrics are not combined
into a claimed full-Dilithium verification percentage.

## Stage5I seed-to-row connection

| Requirement | Evidence / limit |
|---|---|
| Seed expansion |20 actual expansions at all3 levels;2560 bytes equal hashlib SHAKE256(xi||k||l) |
| Retained material |Exact rho,rho-prime,K and level/valid checked at every source completion |
| Real messages |163 sampling jobs;1103 accepted absorption words checked byte-for-byte including zeroed unused high bytes |
| Memory/row outputs |Existing row checker validates every scalar/packed write,ack,publication,NTT/ADD result and12544 exact92-bit reads |
| Reject before side effects |7 expected adapter errors;no raw request,bank allocation or sample descriptor on rejection |
| Completion ownership |Tagged raw output/done,matching sample ID/core,full hash retirement and bank commit before source done |
| Held result |4-cycle held completion on all190 source commands;seed fields stable and command-ready low |
| Reset/reuse |7 row-phase resets with seed/bank invalidation and successful re-expansion/recovery |
| Independent checks |6 schoolbook reference rows,C ADD results;23 checker corruptions rejected |
| Not yet covered here |All s2 nonces,all matrix rows,seed-phase reset sweep on this wrapper,autonomous KeyGen,key bytes,full-system UVM/PPA |

Use existing testbench parameter SEED_SOURCE=1 through selector5/seed_row;
SEED_SOURCE=0 preserves selector5/row. The eleven earlier focused gates remain
separate regressions. Do not report their counts as one full-operation suite
or interpret these directed tests as a functional/code coverage percentage.

## Stage5H reusable row scheduling

| Requirement | Checked behavior |
|---|---|
| Full row mathematics |4/5/7-column rows at all levels;two distinct matrix rows per level;direct-transform and coefficient-domain schoolbook agreement |
| Real producers |163 actual SHAKE/sampler jobs;FIPS-format A/secret messages;ordinary NTT and eligible Pre-NTT secret transforms |
| Row schedule |First PWM -> accumulator;later PWM -> scratch;in-place ADD -> same accumulator;scratch release;final inverse -> coefficient output;accumulator release |
| Retained operands |Transformed secrets reused between rows without retransform;complete raw/transform/matrix readbacks prove preservation |
| Rewrite safety |6918 old-word cache reads match old accumulator/product,updated owner and untouched write frontier;96264 scalar writes/24066 packed writes/acks checked |
| Descriptor rejection |Invalid level/row,workspace alias/busy,stale A/S,wrong parameter,untransformed secret,missing matrix;no child arithmetic |
| Exclusive ownership |External jobs/compute/reads/releases blocked during row;held completion protects result/sources;pending public read blocks row acceptance |
| Reset |Validation,PWM execution,first accumulator result,partial rewrite,scratch release,inverse execution,held row completion;IDs reused with different matrix row |
| Campaign |13 successes,27 rejections,7 aborts;12544 exact92-bit public reads;160 held-row refusal checks and4 pending-read checks |
| Checker integrity |26 deliberate corruptions rejected,including missing column work,commit/ack,wrong cached old value/frontier and row output |

This gate uses selector5/row and the existing script/launcher. It verifies the
tested staged-row product u=A*s1,not s2 addition,KeyGen byte encoding,NIST whole-
operation conformance,full-system UVM coverage or PPA. In-place ADD is tested;
in-place SUB is exposed by the generic DMA but is outside this row workload.

## Stage5G banked process/NTT chains

| Requirement | Checked behavior |
|---|---|
| Shared ownership |PROCESS_SERVICE=1;one store/four banks;sampling,NTT and process sequential;pending public reads block process commands |
| Arithmetic domains |ADD/SUB accept matching domains/parameters;P2R coefficient domain only;missing/stale A/B and invalid opcode reject |
| Destinations |Aliasing A/B or P2R high/low rejects;busy explicit destinations wait;unrelated release unblocks them |
| Real chains |23 real sample jobs;15 real NTT commands;PWM -> ADD/SUB -> INTT -> ADD -> P2R,then stored low -> NTT |
| Canonical low/high |Signed low converted modulo q for storage;high zero-extended10-bit;all signed low/high/encoded t0 arithmetic outputs match Python/C |
| Physical storage |22297 scalar writes,5574 packed writes/acks;correct ID,region,core,lane/index/value;8512 exact92-bit readbacks |
| Atomic pair |Two P2R commits;22 actual snapshots prove no partial public visibility;held completion protects both destinations |
| Reset |Before DMA,partial arithmetic writeback,between low/high writes,and between low/high commit;old descriptors invalid;ID reuse with different inputs |
| Campaign |71 process commands:34 successes,33 expected rejections,4 reset aborts;8978 input beats/8976 completed results |
| Checker fault gate |29 corruptions rejected,including false partial visibility,missing high commit,wrong signed low/encoded t0 and physical memory corruption |

The full262-action program must retire without missing actions. Python models
ownership/packing/acknowledgements and arithmetic independently;the C reference
cross-checks actual captured process operands/outputs. These are focused source
tests,not a full-system coverage percentage,formal proof,whole-operation KAT or
PPA result. Next:row multiply/accumulate scheduling and first full KeyGen control.

## Stage5F banked sampling/NTT/result gate

| Requirement | Checked behavior |
|---|---|
| Real connected outputs |16 actual Keccak/sampler jobs;all4 NTT operations,all3 parameters;direct NTT/inverse and schoolbook references |
| Source eligibility |Missing/stale A and B;matrix already transformed;PWM parameter/domain checks;Pre checks actual[-4,4] bounds |
| Destination safety |Both A/B alias cases rejected;occupied distinct destination waits;unrelated release unblocks it |
| Source leases |Protected from acceptance through completion retirement,including waiting for destination;source data preserved |
| Packed DMA |64 words/unary,128/PWM;four low-first scalar lanes/word;exact ID/index/value order;A==B and same/different banks |
| Physical writeback |2952 packed writes and2951 acknowledgements checked by Python;publication requires64 acknowledged words |
| Read/result ownership |Held external read prevents compute acceptance;held result prevents destination release;metadata/domain/small flags checked |
| Reset/recovery |Load,core execution and partial packed writeback aborted;no stale region publication;IDs reused with different inputs |
| Exact campaign |54 commands:30 results,21 expected rejections,3 aborts;2944 exact92-bit readbacks=11776 coefficients |
| Checker integrity |19 deliberate corruptions rejected,including missing packed ack,wrong lane data/region/index/domain/bounds,missing publication and stale token |

This gate uses the single launcher/script with selector5/bank_ntt. It establishes
the tested banked connection,not a full KeyGen result,formal proof,full-system UVM
coverage or new PPA measurement. Banked process reads/writeback and row scheduling
are the next integration requirements.

## Stage5E connected packed-bank sampling

| Requirement | Checked behavior |
|---|---|
| Atomic reservation |Actual core/ID bound to caller's bank/region;occupied destination cannot accept replacement |
| Context isolation |Interleaved coefficient streams use separate92-bit packers;same/different destination banks |
| Physical word correctness |23-bit low-first lanes;all5792 bank writes independently compared before readback |
| Durable publication |64 write acknowledgements and256 coefficients plus matching external success;held success does not publish |
| Word reads |5632 completed92-bit words;ID/mode/parameter/domain/bounded metadata checked;invalid/partial/reset regions reject reads |
| Release/reuse |Matching pending read blocks release;same-index fresh jobs update all data/metadata;all64 regions fill |
| Error/reset |8 expected parameter errors free reservations;8 partial jobs aborted;held successful/error read responses reset |
| Internal protocol faults |Wrong index,last,value,ID/core;premature/wrong-ID status;extra coefficient all halt publication until reset |
| Checker fault gate |12 corruptions rejected,including missing physical write and altered bounded/domain bits |

104 jobs,88 completed polynomials,22528 complete coefficient readbacks. Tests
use actual Keccak/sampler and independent Python expectations. Stage5F above adds
NTT source locks/compute writeback. Packed narrow fields and full-phase scheduling
remain future connected requirements. No new coverage percentage is reported.

## Stage5D bank-memory foundation gate

| Requirement | Implemented check |
|---|---|
| Published geometry |Four independent1024x92-bit logical banks;two ports each |
| Full address/lane capacity |Initialize all4096 words;read all through both ports;compare full92 bits |
| Dual-port hazards |Same-address read/read accepted together;read/write and write/write serialize with A priority |
| Independence |Simultaneous access to all eight ports and independent per-port stalls |
| Elastic responses |Replace consumed response without bubble;hold read data/address/type under stall |
| Reset |Eight held write acknowledgements canceled;eight blocked offers unaccepted;payload retention and canceled-write absence checked |
| Independent reference |Python word dictionary and per-port response queues;exact accepted request/response ledger |
| Checker fault gate |12 corruptions rejected:payload,address,bank,port,type,ID,latency,missing/duplicate records,token/footer/reset |

Measured:14872 accepted,14864 responses,9509 exact reads,5355 write acks,8
reset-aborted acks. This is storage-primitive verification,not full algorithm
coverage or completed four-bank migration. Region ownership/locks,packing,
DMA/process routing and safe phase reuse still need their own connected tests.

## Stage5C shared raw-SHAKE and seed gate

| Requirement | Implemented check |
|---|---|
| One real shared engine |RAW_SERVICE=1 in existing keccak_sampler;no extra Keccak instance |
| Correct client selection |Raw/raw and raw/sampling jobs;captured per-core type/ID;simultaneous requests give raw priority |
| Finite raw hash math |Both SHAKE modes;empty/partial/multi-rate input;partial output and rate-boundary beats;1699 exact bytes |
| Complete seed ownership |rho32/rho-prime64/K32 captured from128 output bytes;wait raw completion;hold result/ID/parameter |
| Actual seed-to-polynomial connection |RTL-collected seeds feed formatter/sampler;7 polynomials/1792 exact coefficients across all parameters |
| Parameter error |Seed parameter3 returns zero fields/error without issuing hash |
| Backpressure |Raw payload,raw done and seed result remain stable;held completion survives peer finishing |
| Reset/recovery |Partial seed absorption,partial output,held complete result;coordinated reset and same-ID fresh seeds |
| Independent checking |Same Python script;hashlib plus independent sampler;12 corruptions rejected |

Workload26 commands,18 raw requests,7 seed results(including1 expected error),
7 complete polynomials,3 reset aborts. Main Stage3/4 tie raw service off and
retain their earlier gates. No full-operation output or new coverage/PPA claim.

## Stage5B final-standard KeyGen message gate

Target final FIPS204 bytes,with level2/3/5 labels for44/65/87. Use the existing
Python script and DILITHIUM_STAGE5,DILITHIUM_TEST hash_format. This is a focused
message-construction/hash test;main controller,seed-result storage and complete
key outputs are not established by it.

| Requirement | Implemented check |
|---|---|
| Parameter-bound seed expansion | SHAKE256(seed32+K+L),128 bytes;three seed patterns per set,three reset recoveries |
| Matrix byte order and bounds | All102 legal row/column positions;SHAKE128(rho+column+row),32 exact test output bytes |
| Secret nonce and bounds | All34 legal KeyGen nonces;SHAKE256(rho-prime64+nonce_le16),32 exact test output bytes |
| Command snapshot | Mutate seed,ID,opcode,parameter and coordinate inputs immediately after acceptance |
| Illegal requests |14 error completions;no hash request/input issued |
| Backpressure | Descriptor,64-bit message,completion and128-bit hash output held stable |
| Reset/recovery | Held descriptor,partial input and held completion aborted;coordinated Keccak reset;reuse IDs with changed seeds |
| Independent oracle | Python hashlib plus explicit normative byte concatenation;no RTL/reference sharing |
| Checker credibility |12 injected capture corruptions rejected |

Measured:165 commands,162 completions,3 aborts,883 absorption words and5888 exact
SHAKE bytes PASS. No new functional/code coverage percentage is claimed.

## Stage5A process-unit gate

tb_poly_process.sv checks the shared one-stage coefficient arithmetic unit.
It does not instantiate a full KeyGen/controller. Expected math is generated
by the existing singular Python script and cross-checked with the unchanged C
rounding reference plus ordinary modular arithmetic in process_reference.c.

| Requirement | Check |
|---|---|
| Canonical add/sub |Directed q/zero/half-range boundaries and512 deterministic random pairs for both operations|
| Power2Round ties/width |9208 canonical cases spanning every high-part region with low offsets0,1,4094..4098,8190,8191 where valid|
| Signed/packed low |Exact signed14-bit low and13-bit 4096-low;reconstruction and strict tie interval|
| Relevant operands |ADD/SUB require both canonical;rounding ignores an intentionally noncanonical unused B|
| Framing/errors |13 invalid opcode,noncanonical operand or last/index errors;zero arithmetic results,metadata retained|
| Stalls/pipeline |10009 simultaneous output/input transfers,3505 blocked-input and3511 held-output observations|
| Reset and ID reuse |Three operation-specific pending outputs aborted;one reset also cancels an unaccepted blocked input;fresh recovery reuses IDs|
| Checker integrity |12 corruptions of arithmetic/signedness/packing/opcode/tag/framing/sequence rejected|

PASS:10349 accepted,10346 compared outputs (including13 expected errors),
3 reset aborts. C separately checks all8380417 canonical Power2Round values
against reconstruction/range constraints. This exhaustive reference check
does not mean exhaustive RTL simulation or full functional/code coverage.
Memory routing,packing,stateful polynomial sequencing and KeyGen remain untested
until implemented after the required architecture decisions.

## Current Stage4 focused tests

tb_keccak_sampler_ntt.sv connects all three real engines through memory. It uses
generated independent expectations and writes a trace consumed by the separate
Python checker. Standalone NTT UVM is retained and revalidated independently.

| Requirement | Observed check |
|---|---|
| Four arithmetic operations |NTT,INTT,PWM,Pre;canonical values and exact root/order/scaling|
| All parameter levels |Three Matrix A/secret chains with parameter encodings0/1/2|
| Matrix A bypass |Already-transformed A enters PWM;attempted forward NTT(A) is rejected|
| Independent product |INTT(PWM(A_hat,NTT(s))) equals schoolbook(inverse(A_hat),s)|
| Pre eligibility |Bounded secret and challenge accepted;unbounded mask rejected|
| Round trips |Secret,mask and challenge recovered exactly after NTT/INTT|
| Operand preservation/alias |A and s remain exact after use;PWM may read the same NTT slot twice|
| DMA order/tags |9745 accepted values checked against the exact source ID,slot,index and value|
| Result publication |256 results plus engine done precede commit and completion reply|
| Full-pool handling |24 reservation-wait cycles;release unrelated Pre result to allow PWM destination|
| Source locks |33 successful reservations checked;source complete bits clear while IN_USE|
| Rejection containment |17 stale/free/domain/Pre/parameter errors;zero engine launches,loads or outputs for them|
| Stalls |188 held completion cycles and699 held read-response cycles;payload/metadata stable|
| Reset/recovery |Load17 values,coreRUN after256 loads,and writeback after32 outputs;reset clears all roles and six old-slot reads fail|
| Checker integrity |12 corruptions of DMA/output/read/tag/domain/reservation/completion records rejected|

Source/Python PASS:16 sampled jobs,4096 sampled values;50 compute commands,
30 complete,17 rejected,3 reset aborts;7713 output values (7680 complete+33
aborted prefix) and11776 exact stored reads. Stage2 andStage3 regressions remain
separate and pass their existing gates. This is not full-operation verification,
integration functional/code coverage or formal proof. Compute/sampling overlap,
multi-consumer schedules and general process-block arbitration are not tested.

Relocated NTT standalone UVM:748 jobs,191488 values,32 group type mean90.4731%;
raw DUT code12990/14093=92.17%. Python18 cases/4608 values PASS. These figures
belong solely to standalone NTT,not the connected subsystem.

## Preserved Stage3 focused tests

tb_keccak_sampler_memory.sv uses the real producer and memory. The separate
memory_protocol_test.sv companion injects faults into a three-slot configuration.
Stage2 remains a selectable regression in the same launcher.

| Requirement | Observed check |
|---|---|
| Atomic allocation and both contexts |104 accepted jobs;slot/core/ID binding checked;full pool refuses new commands|
| Stored contents and metadata |88 x256=22528 readbacks match independent values,IDs,mode,param,domain and index|
| Commit only on success |Reads rejected during writes and after coefficient255 while status is held|
| Concurrent traffic |170 read-request/write-accept overlaps on different slots;exact readback|
| Stable stalled response |1321 held-response cycles;payload and all metadata immutable|
| Release arbitration |Outstanding response blocks release;same-slot read wins simultaneous release|
| Invalidation/reuse |8 parameter errors,8 reset aborts,99 rejected reads;88 releases;ID reuse with new messages|
| Read pipeline/reset |Back-to-back response replacement;reset cancels stalled valid and error responses|
| Protocol containment |8 injected faults cannot publish COMPLETE;sticky fault detected|
| Configuration bounds |Three-slot companion rejects encoded slot3|
| Independent checker integrity |12/12 corrupted Stage3 captures rejected|

Source and Python gates pass:104 jobs,88 complete,8 expected errors,8 aborts,
23180 exact writes and22528 exact reads. Stage2 also freshly passes104 jobs,
23089 values and12 checker faults. This is focused verification,not comprehensive
coverage,formal proof or a full-operation Dilithium output claim.

## Preserved Stage2 focused tests

The user authorized efficient non-UVM tests during integration. The current
testbench is `tb/tb_dilithium/tb_keccak_sampler.sv`. Accepted individual UVM
environments remain intact. Full-design UVM and detailed covergroups/crosses
will be developed after complete operation outputs and reference/vector gates.

| Requirement | Current stimulus | Check/evidence |
|---|---|---|
| Both contexts/all sampling parameters |24 baseline jobs:4 modes*3 parameters*2 contexts | Python confirms all24 mode/parameter/actual-core combinations |
| Independent simultaneous operations |32 jobs covering16 ordered mode pairs | Exact per-job polynomial and tags;overlap witness |
| Empty,partial and multi-rate absorption |24 jobs with lengths0,1,7,8,9,15,16,17,33,34,65,66,135,136,137,167,168,169,271,272,273,335,336,337 | Hashlib+scalar expected values;unused high input bytes poisoned |
| Parameter error with live SHAKE source |8 jobs:param3 in4 modes on2 contexts | Parameter-error status,no coefficients,safe upstream drain |
| Output/status backpressure |Periodic stalls,forced stalls for reset targets | Held public value/core/ID/index/last and status stable |
| Shared Keccak lock and cancellation |Observed blocked hash offer,bridge cancellation and stop/drain | Hash offer stable;each stop rise must follow a discarded accepted beat |
| Reset and same-ID reuse |8 aborted jobs at4 observed phases,then8 recovery jobs | Accepted old prefixes exact;no old status/data crosses reset/reuse |
| Completion and source retirement |Every job | Status cannot retire a busy hash core or matching bridge token |
| Registered-credit queue |Two slots,forced full-queue reset,observed concurrent push/pop | Occupancy bounds,ordered values,tags retained,both slots drained before status |
| Ownership |Every accepted command/hash/bridge/output/status transfer | No unowned token or premature context reuse |
| Comparison integrity |12 deliberately corrupted captures | All rejected without changing DUT output or expected models |

Observed source gate:104 jobs,88 complete,8 expected errors,8 aborts,23089 exact
coefficient comparisons. Four reset targets are explicitly reached with both
ownership bits asserted. Raw witnesses:drops99,bridge cancellations140,blocked
hash cycles33316,dual-owned cycles37383,upstream-retirement wait cycles293,
full-queue cycles34198,simultaneous push/pop128.
These event counts describe this workload;they are not throughput rates.

## Remaining verification work

- Future NTT writeback/consumer leases,multi-consumer slot lifetimes and broader memory arbitration.
- Full-operation polynomial lifetimes,matrix-vector accumulation and remaining arithmetic/processes.
- Controller seed/nonce formation,parameter schedules,encoding and signing retries.
- Broader reset points,malformed/incomplete traffic,finite-source semantics and
  independent cancel/timeout features if they are added to the interface.
- Comprehensive UVM functional/code coverage and justified reachable gaps.
- Distinct integrated implementation netlists,physical I/O/FPGA and security review.

Do not interpret104 passing jobs or24 observed combinations as full verification
or a measured overall functional-coverage percentage. The imported components'
standalone coverage figures must not be summed into integrated coverage.
