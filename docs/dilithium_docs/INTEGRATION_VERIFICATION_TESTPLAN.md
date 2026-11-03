# Dilithium verification test plan

## Stage7B.9 production top

Drive the real51-group production boundary in the same33-scenario main UVM.
Check every published byte,frame/index/tail,ID/status/verdict,held transfer,
retry count,reset/recovery and empty-pool retirement. Internal read-only
observers retain owner/occupancy checks. No legacy debug request is presented
as production host stimulus. The raw-core focused benches retain debug access.
Static audit requires all74 prior RTL and reference C/H unchanged,all three
operations enabled in the wrapper and the6.757ns SDC unchanged. Compare all30
latency records with the prior source and qualify the current-token negative
gate. Collect fresh main coverage and full production-top fit/retention/timing.

Result:all33 scenarios pass30 checked completions/3 reset aborts,zero errors.
Same-token byte0 corruption receives zero checked outcomes/0of170 bins.
All30 timestamps and every latency CSV field equal7B.7. Functional121/170;
overall code316722/397459=79.69%. The full compile routes and assembles;
retained bits pass. Setup at the unchanged6.757ns target FAILS. Stage7C must
qualify any timing-path changes with independent arithmetic/handshake checks,
current-source main/negative runs and new routed measurement. No Stage7
coverage closure,netlist testing or board signoff is inferred from this baseline.

## Stage7B.7 decoder preservation

The existing383-case tb_verify_decode now instantiates a verification-only
archived decoder through verify_decode_equivalence. Ready,busy and valid
signals must match every checked cycle;all published header,coefficient and
completion fields must match while valid,including stalls. Assertions in
the old reference check HEADER word<8 and hint-input byte alignment. These
are the preconditions for the narrowed storage writes. Existing C/Python
comparison still checks705010 decoded values and all frame/header/error/reset
records independently. The checker-negative suite remains required. This
focused trace comparison does not contribute to main-UVM code or functional
coverage. Fresh main33/negative and same-FPGA fitting qualify the whole design.

## Stage7B.6 memory metadata equivalence

Compare the old and candidate memory controllers under identical inputs.
Check every ready/status pin and each valid response,including held data and
metadata. The old controller is an exact archived copy with module rename,
comments and a trailing newline only;it is never a synthesis source.
The standalone unit covers64 completed slots,interleaved writers,all packed
word addresses,destructive rewrite watermark,simultaneous complete-read and
rewrite admission,cancel/reuse,reset/stale-tag rejection and protocol faults.
Then enable the same comparator outside the DUT in the complete33-scenario
main UVM. Independent published-byte checking remains active. Only that
main UVM supplies the reported functional/code coverage. Confirm inferred
tag RAM geometry and full routing in Quartus before hardware area claims.

## Stage7 main UVM campaign

Stage7B.4 adds serial descriptor validation in two Sign helpers. The focused
tb_handle_scan gate checks every active duplicate position at all three
levels,cross aliases,reported-mask mismatch,one-cycle source changes,reset
at first/middle/final scan steps and valid recovery. It passes256 scenarios
(24 valid/232 rejects/18 reset-recoveries). It must reject before adoption
or any engine request. These unit checks are not merged into main-UVM
functional/code coverage. The7B.4 main33/helper59 reruns pass;its measured
Sign latency increase is0.022-0.060% in the selected profiles. Placement
passes but routing fails. Candidate7B.6 must refresh those source gates.

Stage7A creates the reusable full-operation UVM agent/driver/monitor/scoreboard/
coverage environment in tb_uvm/tb_uvm_dilithium. The first 33 scenarios comprise
18 original published cases (3 KeyGen, 6 Sign, 9 Verify), 6 command errors,
3 wrong-length invalid Verify results, 3 active resets and 3 published-input
same-ID recoveries. Expected outputs are read only by the scoreboard. Source
coverage is collected from this UVM run, with a corrupted-key negative gate.
Detailed sampling/credit rules, group mapping and GUI commands are in COVERAGE.md.

| Feature family | Initial checks | Further Stage7 campaign |
|---|---|---|
|Operation/parameter control|All 3 operations x 3 supported parameters; invalid parameter and op3; accepted metadata poisoning|Every ordered pair, valid ID0/65535, wrap/reuse, long repeated command streams|
|KeyGen|Whole published PK/SK, public-before-secret ordering, word tags/tails, stalled output and post-ACK cleanup|Seed diversity, blocked first/final words, internal row/sampling/Pre-NTT/P2R/hash witnesses|
|Sign|Deterministic and supplied-randomness cases per level; whole signatures and retry-counter consistency|Empty/boundary messages and contexts, diverse retry/rejection reasons, nonce exhaustion, every input/key/packing failure|
|Verify|Valid, equation-invalid and structural-invalid published cases per level; zero signature length; whole-frame or early-prefix checking|All wrong lengths, hint/norm boundaries, message/context mutations, decoder and hash/publication errors|
|Transport|Original byte order, indices, valid-byte counts, last flags, poisoned unused input bytes, zero output tails, actual stalls, held completion|All tail sizes, long pauses, malformed framing, stalls at each internal handoff and final word|
|Memory/services|One owner, debug isolation, actual occupancy, complete cleanup before reuse|All bank conflicts, retained operands, leases, allocator failures, source/destination hazards and internal ownership crosses|
|Reset/recovery|Active reset per operation followed by same-ID published-input recovery|Idle, absorb, sampler, forward/Pre/inverse NTT, PWM, process, raw hash, output and held-completion phases|
|Checker integrity|Corrupted first key byte must fail with zero coverage credit|Signature/verdict/tag/index/tail/status corruption and coverage-credit faults|
|Implementation|Whole-main Quartus baseline at unchanged 6.757ns with all operations enabled|Measured critical-path changes, area/throughput improvements, correctness reruns and user acceptance|

No full-main PPA/coverage closure or optimization result is implied by bringing
up Stage7A. Post-synthesis/post-fit and FPGA work remain later gates.

## Stage6 official full-operation qualification

Use the actual main with FULL_KEYGEN=1, ENABLE_SIGN=1, ENABLE_VERIFY=1 for
each official suite. Check the elaborated MAIN_CONFIG line in every run log.
Run nist_keygen (75 original seeds), nist_sign (90 original SK/message/context/
randomness inputs) and nist_verify (45 original PK/signature/message/context
inputs) through the same DO and current source fingerprint. Compare complete
encoded public/secret keys, every signature byte, and published Verify verdicts.
The expected data is consumed only by the separate Python comparison.

Require explicit simulation capture and independent comparison PASS markers,
exact case/byte totals, complete cleanup and held-stream assertions. Corrupt
captures to test each checker, including changed key/signature tails, missing
or duplicated events, stale fingerprints and both directions of Verify verdict
corruption. Retain the full original mode audits, with unsupported cases shown
as excluded rather than passed. The independent C preparation gates must also
match the published supported outputs.

Keep Stage5V.4 error/reset/mixed-operation evidence separate. Stage6 changes
test selection and checking only; verify every production RTL/C/H byte and the
SDC against that archive. Freeze current fixtures, raw captures, comparisons,
checker results, source and commands together in a create-only evidence ZIP.
Full-system UVM coverage and whole-main Quartus/PPA are the following stage;
official-vector passes alone do not establish either coverage closure or timing.

Stage6 result: all 75 KeyGen / 90 Sign / 45 Verify output comparisons pass.
Checker validation rejects 41/41, 152/152 and 158/158 corruptions respectively.
All three captures use one fresh fingerprint and all operations enabled;
final freshness and preservation of 74 RTL / 21 production C/H / SDC pass.
Evidence: evidence/stage6_full_operation_qualification.zip and SHA256.

## Stage5V.4 main Verify qualification gate

Use one focused tb_full_verify on actual main dilithium,configured with
FULL_KEYGEN=1 and both Sign/Verify enabled. Same Python/DO selector full_verify.
Run118 scenarios:45 official pure external cases,15 mutations/boundaries,
nine wrong-length invalids,19 command/framing/metadata errors,14 reset/fault
aborts plus14 recoveries,and one real KeyGen/Sign each between Verify cases.
Compare official verdicts directly;derive intermediate values independently
with Python mathematical models/hashlib and unchanged production C functions.

Check every Verify decode/sample/NTT/PWM/ADD/SUB write,commit and packed read;
all raw descriptors/absorption/digests,UseHint/packer values,context headers/
handles and atomic takes. Check physical allocation/rewrite maps and release
lifetimes. Verify exact encoded keys/signature in mixed operations. Assert
one main services owner,debug/Sign-input isolation,no unowned requests,stable
held verdict,input stability and start refusal until acknowledgement/cleanup.
Finite error paths must drain and free the entire operation before done.

Reset in each frame,raw/math context handoffs,challenge output,FNTT output,
matrix output,PWM output,packing,held verdict,cleanup and fatal raw-ID/memory
faults. Follow every reset by a complete same-ID valid Verify request.
Validate the checker with deleted/duplicate/mutated/stale/trailing captures,
including false-positive/false-negative verdicts,computed domains and operands.
After final prepare,rerun Sign45 and KeyGen-only16 compatibility under the
same fingerprint. Sign's old unsupported-op2 fixture becomes op3;KeyGen-only
benches explicitly disable both later features. Do not retag old captures or
claim full-system UVM/PPA/netlist/FPGA/security completion from these gates.

Final gates PASS:118 primary scenarios/45 published verdicts/2624604 exact
Verify writes/51466 packed reads;170/170 checker mutations reject. C/Python60
distinct full inputs agree. Fresh Sign45 and KeyGen-only16 compatibility pass.
One RTL module is added and only the prior main dispatcher changes;all72 other
RTL,21 production C/H and6.757ns SDC remain unchanged. Evidence:
evidence/stage5v4_full_verify.zip with SHA256. Current-source complete published
KeyGen/Sign/Verify batch qualification is the next Stage6 gate.

## Stage5V.3 equation/verdict component gate

Use verify_equation in the same Python/DO. Real prior preparation feeds the
equation owner,with one physical services tree and a real foreign sentinel.
The87 scenarios contain35 structurally valid official cases,9 cryptographic
mutants,23 protocol errors and10 reset/fault phases each followed by recovery.
Expected normal results are19 valid/35 invalid;the normal invalid verdict is
code0,accept0. It must not be confused with a protocol error. Separate966
UseHint unit cases exercise decomposition boundaries,wrap,low=0,invalid
param/noncanonical coefficient and full-width invalid hints.

Independently check every A,PWM,ADD,SUB and inverse coefficient,domain/ID,
allocation/rewrite/commit/release,every W/h read,every corrected coefficient,
packed byte,mu/body hash input,digest and completion. Test-only C calls the
unchanged production matrix/NTT/UseHint/packing/SHAKE primitives;Python uses
mathematical modular arithmetic and hashlib. No expected polynomial arrays
are injected into the equation DUT. Matrix expansion uses rho||column||row.

Directed errors cover duplicate handles,wrong ID,pending read,incomplete
context,synthetic no-free-workspace report,wrong sampler/NTT/process/packer/
formatter completion metadata,actual child source-ID rejection,bad read tag,
full-width hint64 and changed context before take. Three levels cover each
read/hint/packer failure. Read/packer errors must zero-drain hash/packer and
free all adopted regions;pre-take errors preserve the upstream owner.

Reset phases:held adoption,matrix absorption,matrix output,PWM output,in-place
ADD output,UseHint/packing,held digest,cleanup,fatal raw-ID and physical-memory
fault. Recover with a real full prepared context after each. Check held
verdict/digest stability,foreign sentinel preservation and final empty pool.
Validate the checker with deleted,duplicated,corrupted,stale and trailing
records,including verdict,digest,domain,allocation and arithmetic operands.
Rerun verify_math under the final source fingerprint. This is a focused
component gate;main Verify/op2 and full-system UVM remain subsequent work.

Final fresh gate PASS:87 scenarios,966 units,2104627 exact writes,49903 packed
reads;172/172 checker corruptions rejected. C/Python44 inputs/519168 equation
values agree. Fresh verify_math134-scenario capture/compare passes unchanged.
Evidence:evidence/stage5v3_verify_equation.zip and SHA256. The6.757ns target,
71 prior RTL files and21 production C/H files remain byte-identical.

## Stage5V.2b mu,challenge and NTT gate

One focused bench connects real5V.2a preparation to verify_math_prepare and
ONE services tree. Use the same Python/DO selector verify_math.134 scenarios
cover35 structurally acceptable original NIST Verify cases,18 message/context
boundary cases,57 directed failures and12 reset/fault phases with recovery.
The10 structurally invalid official cases remain covered by5V.1/5V.2a;none is
silently credited as a math-preparation success. The26 crypto-invalid but
structurally valid cases still require the later Verify equation.

Independent C/Python checks cover56 distinct inputs,mu hashes and191232
challenge/NTT coefficients. C uses unchanged production SHAKE256,poly_challenge,
poly_shiftl and poly_ntt;Python uses hashlib,sampling rules and mathematical
NTT. RTL checking covers every new scalar write,packed result/foreign word,
header,digest,tag/domain,adoption,commit,source release and context handoff.

Exercise empty ctx/M,partial words,maximum255-byte ctx,hash prefix/body merging,
bad length/layout/ID,missing upstream completion,pending read,changed source
before take,high payload-index bits,zero bytes,early/missing last,truncated/
extended message frames,wrong sampler/NTT/formatter completion metadata and
actual NTT source-ID rejection. Test-only response overrides report no free
challenge/workspace regions;these are exhaustion-response tests,not physical
full-pool capacity tests. Preserve a real sampled foreign polynomial throughout.

Reset at held adoption,mu absorption/output,challenge input/output,NTT input/
output,held completion,read response and cleanup;inject fatal raw-ID/memory
faults and prove reset recovery. Clear must win over take and both must wait
for pending reads. Validate the checker with missing/duplicate/mutated/stale/
trailing records. Revalidate the earlier5V.2a gate under the final fingerprint.
Existing70 RTL files remain unchanged;this adds a client without changing main
Sign/KeyGen paths. Prior full Sign/KeyGen compatibility remains frozen in5V.2a.

## Stage5V.2a load/hash ownership gate

Use the same Python/DO with selector verify_prepare. Run133 scenarios:all45
original official Verify PK/signature pairs,three maximum-fitting bases,63
directed cases (21 per level),and11 reset/fault boundaries each followed by a
recovery request. Structural rejects remain separate from official verdicts.

Check every scalar coefficient and all successful packed words against direct
Python unpacking/canonical hint rules. Verify SHAKE256(PK)->tr independently
with Python hashlib and unchanged C SHAKE256. Track every allocation,partial
discard,commit,release and ownership transfer. Preserve one sampled foreign
region per case and read it back exactly before its explicit owner release.
Test first-two-frame input gaps,poisoned unused bytes,independent decoder/raw
stalls,held outputs/status,high input index,zero bytes,early/missing last,
truncation/extension,bad parameter/length,overflow/collision and pending reads.
Inject wrong loader ID/mask/header length;inject raw-tag/physical-memory faults.
Reset at fork/header/coeff/hint/done/read/cleanup/raw-output boundaries and
revalidate recovery. Deny competing bank clients during either load mode.
Clear and take must wait for held read responses;clear wins when both offered.
Validate the checker using missing,duplicate,mutated,stale and trailing records.

Because the shared load response/arbitration changes,rerun the original
sign_load_service,actual main full_sign and full_keygen compatibility gates.
This focused integration gate does not collect full-system UVM/code coverage,
prove final Verify verdicts,or provide physical/security signoff.

## Stage5V.1 Verify frame checks

Independent oracles:Python integer slicing/canonical hint rules vs unchanged
C unpack_pk/unpack_sig/CNB. Full C Verify must separately match all45 official
pure-API verdicts (9valid/36invalid);do not credit this as main RTL verification.

Test PK10-bit extremes and all3 levels;z just inside and exactly at both norm
bounds;maximum encodable z;empty/full hints,empty rows,indices0/255 and legal
index repetition across rows. Reject decreasing/oversized counts,duplicate or
descending indices within a row and nonzero padding. Exercise partial tails,
poisoned unused bytes,all16 index bits,zero/oversized byte counts,early/missing
last,truncated/extended frames,bad declared lengths/parameter,metadata snapshots,
held input/header/coefficient/done and reset/recovery at nine boundaries.
Only accepted handshakes credit exact decoded prefixes. Compare full data on
success,exact error prefixes and legal reset prefixes. Deliberately corrupt
capture fields/records/header/footer to validate the checker. Main op2 remains
unsupported until later wiring;current results must retain that limitation.

Fresh gate:383commands/705010values,275 structural successes/99 errors/
9resets,37checker corruptions rejected. Full C Verify matches45/45 original
verdicts;10 invalid signatures fail decoding and26 need the later arithmetic.
Full-KeyGen compatibility8complete/3rejects/5aborts and37checker faults pass.
Frozen source-bound evidence is linked in REFERENCE_VERIFICATION.md.

## Stage5N.4h.7 official Sign vector gate

Audit all360 pinned sigGen cases by(tgId,tcId);select90 external/public-API
pure cases (15 deterministic+15 randomized per level). Audit CSV must list
the270 unsupported prehash/internal-API cases without crediting them as passes.
Match the complete original SK/context/message/rnd stream and every published
signature byte using the actual main controller;never preload arithmetic
intermediates. Deterministic rnd is32 zero bytes. Contexts0..255 and messages
1..8192 bytes fit the existing interface without RTL changes.

Reuse tb_full_sign with NIST_VECTORS1,including input/output/done stability,
busy refusals,exclusive shared ownership,debug isolation and the physical
allocate/rewrite/finish/release ledger. Every successful request must return
all regions before main completion. Compare against the original NIST JSON,
not the additional C preflight result. Corrupt fields/records/header/footer
and missing/duplicate/truncated/trailing records to validate the file checker.
Rerun the local45-case full_sign gate with NIST_VECTORS0 to check that adding
the selector preserves error/reset/mixed-KeyGen behavior. Fresh execution
results:90/90 official signatures/310680 bytes,152 checker corruptions rejected;
local45 scenarios and196checker corruptions also pass. Details live in
REFERENCE_VERIFICATION.md;earlier sections below are historical gates.
Main Verify/full UVM/PPA remain separate work.

## Stage5N.4h.6 main Sign and shared-operation gate

| Requirement | Main-top check |
|---|---|
|Actual main Sign dispatch|Default ENABLE_SIGN1,op1 into real sign.sv and one physical services tree |
|Independent complete output|Exact C-reference signatures;C Verify accepts each unique oracle result;three fixtures also Python math |
|Approved host interface|SK then ctx||M;frame indices restart;empty body;partial high-byte poison;metadata snapshots |
|Parameter/context boundaries|All3 levels,ctx0/7/255,empty/1/169-byte M;ctx256 and finite overflow reject |
|Malformed inputs|Five SK faults including pre-narrowing high-index alias;four body framing faults |
|Ownership and cleanup|Physical allocate/rewrite/finish/release ledger;zero regions at normal Sign done;no debug response theft |
|Main operation transition|Actual KeyGen between Sign requests;next offer refused during KeyGen post-done cleanup |
|Backpressure|Stable input,signature,keys and done;busy command offers refused |
|Reset/fatal|Nine cases spanning key input/transform,hash,retry,encoding,held done,pending response and forced memory fault |
|Checker validation|Field/record mutation,missing/duplicate/stale/truncated/trailing capture checks |
|Compatibility|Rerun encoded KeyGen and rounded/debug-read KeyGen with explicit legacy ENABLE_SIGN0 |

Known limits:finite pure-ML-DSA host descriptor,no external-mu/prehash command,
main Verify unsupported,official NIST Sign vectors still next. Main encoder/
publication-error propagation combinations remain for broader UVM;their child
mechanisms were tested in previous focused gates. No full-coverage/PPA claim.

## Stage5N.4h.5 signature encoder gate

| Requirement | Evidence / check |
|---|---|
|Complete final-format signatures|Real key preparation+attempt loop ->encoder;all bytes compared with independent Python/C |
|Independent software oracle|Original SK/message/rnd inputs;production pack_sig;nonce-zero also full C signing |
|All levels and tail formats|2420/3309/4627 bytes;final4/5/3 bytes;zero unused tail bytes |
|Z packing|18/20-bit gamma1-z;shared packer endpoints/invalid neighbors/noncanonical inputs/framing/stalls/reset |
|Sparse hints|Ordered indices,zero padding,cumulative counts;binary value and omega checks |
|Ownership|Preflight preserves old owner;one atomic take;whole cleanup;no foreign release;key/sentinel retained |
|Errors|Invalid descriptor,z/hint data,hint metadata/error;fatal noncancelable Z read/physical fault reset |
|Stalls and resets|Stable output/done;digest,Z,hints,final-word,done,pending-read reset/recovery |
|Checker validation|163 corrupted captures rejected;separate packer15-fault gate |
|Error while output stalled|Explicit HOLD witness:full hint word remains valid before bad read response is consumed |
|Independent tags|Source-region ID differs from output ID;reads and output/done check their respective IDs |
|Shared-interface compatibility|Expanded188-case packer and existing full KeyGen gate rerun |

This is focused functional testing,not full UVM/code coverage or security
signoff. Official full-operation NIST Sign outputs and main host Sign/Verify
dispatch remain open. REFERENCE_VERIFICATION.md contains commands and results.

## Stage5N.4h.4 retry-loop gate

| Requirement | Evidence / independent check |
|---|---|
|Whole connected path|Real prepared key,streamed ctx/message/rnd;one shared physical services tree;no intermediate preload |
|Independent whole-attempt oracle|New test adapter uses unchanged C SHAKE,sampling,matrix,NTT,PWM/INTT,norm and MakeHint functions from SK/message/rnd,not Python intermediates |
|Real retries|Level2 nonce0 rejects then4 accepts;level3 nonce5 rejects six times then35 accepts;level3 nonce455 rejects hints then progresses to480;level5 rejects0/7/14/21 then28 accepts |
|Private seed lifetime|Exactly one mu and one private-seed derivation per normal initial command;zero such requests on retries;actual absorption and digest bytes match Python |
|New masks|Every accepted seed||LE16(nonce) input word,sampler descriptor/status and y coefficient matches the new nonce's independent model |
|Publication order|Exactly six ordered child starts/results per complete attempt;no dependent command before predecessor retirement;strict maps/IDs and complete storage |
|Header take|Rejected checker owns zero regions;actual mu/seed/nextnonce transfer occurs before new ExpandMask,all rejected payloads already freed |
|No wrap|Initial nonce65536 launches no mask;final legal level2/3 vectors reject and stop at65536;final legal level5 vector accepts and reports65536 |
|Hardware failures|Malformed initial payload,observed retry sampler-status ID corruption,real retry NTT bad-source-ID request,observed retry CNB result-ID corruption;stop without retrying an error |
|Reset/fatal|Reset during retry mask generation,partial products,norm reads and held accepted done;fatal fault during retry mask writes,then global reset/recovery |
|Physical ownership|Record every actual allocation,rewrite,commit/discard and release,including row-controller internal scratch releases and temporary tags;preserve key/sentinel |
|Backpressure|Independently stall physical command,input,output,status,result and release channels;held public outcome stable |
|Final consumers|Exact accepted z/hints/digest/metadata;held read blocks clear/take;clear priority;result transfers/release and final key-only map |
|Checker sensitivity|Corrupt descriptors,seed/digest/nonce/mask bytes,verdicts,counters,memory events,headers and final reads;remove/duplicate events and reject stale/trailing captures |

The new controller still produces candidate polynomials/digest,not encoded
signature bytes. The focused gate is not full-UVM/functional/code coverage
closure or a PPA/netlist/security result. Source-context rejection and direct
parent-facing child publication corruption remain defensive guards;this gate
does not claim every parent error code has been reached. Full Sign dispatch,
signature bytes and Verify remain separate later acceptance gates.

Final gate PASS:47 commands,19 accepted parent results,12 expected service
errors,5 exhaustions,11 aborts;87 attempts/45 normal rejections,105667 exact
y coefficients/56256 packed reads.152/152 checker corruptions reject.
The default mask78-case regression and85/85 checker faults also pass.
Independent full C/Python13 starting fixtures/26 attempts/24064 accepted
z/hint coefficients agree. Source token,evidence and counting arithmetic
are in REFERENCE_VERIFICATION.md and THROUGHPUT.md. No stage beyond candidate
retry is inferred from these results.

## Stage5N.4h.3 norm/hint acceptance gate

| Requirement | Observation / independent check |
|---|---|
|Real connected inputs|Actual key load/transforms,mu/seed/y,A*y,decomposition,challenge hash/sampling,FNTT(c),products and response corrections;read all z/r0/w1/ct0 words before take |
|Independent verdict|Python centered norms and mathematical HighBits inequality versus unchanged C poly_chknorm/poly_make_hint;local fixtures at all levels |
|Genuine branches|Clean candidate at2/4,3/0,5/28;norm rejections2/0,3/5,5/0,5/7;norm-clean3/455 produces56 hints above omega55 |
|Ownership|Products take under independent stalls;old owner invalidates and cannot clear;key/sentinel leases and exact values survive |
|CNB order|z then r0 then ct0,first failing polynomial terminates;exact descriptors and individual child reject flags |
|Hint arithmetic|Every in-place combined-low scalar and every0/1 hint scalar equals the independent model;exact polynomial and whole-vector weights |
|Resource reuse|One first hint spare,then freed low-row destinations;release only after full child retirement;no duplicate,early or foreign release |
|Rejection versus error|Norm/omega reject:code0 plus reason and retained retry headers;service failures:nonzero code,no result credit |
|Ordinary errors|Duplicate source handles,no free hint address,actual bad source IDs in CNB/ADD/Mhint,observed CNB/ADD completion-ID corruption |
|Interrupted ownership|Reset during norm reads,partial ADD,partial hints and held accepted done;force fatal fault during partial hints,then global reset/recovery |
|Backpressure|Independently stall source take,child command/result and releases;held done/result fields remain stable |
|Final consumers|Read exact z/hints/IDs/modes;hold pending consumer read across clear/take;verify private mu/seed/nextnonce transfer even on rejection |
|Checker sensitivity|Fresh token,strict event ordering and footer;corrupt individual descriptors,verdicts,weights,payloads,headers,releases,reads and reset evidence;remove/duplicate events |

These are focused source-integration tests,not functional/code coverage closure
or security signoff. Eight distinct local FIPS-derived fixtures use three
official KeyGen SK inputs;they are not official signature-output vectors.
The ct0 norm-reject and exact whole-vector omega-equality boundary are not
claimed reached by these honest fixtures. Existing process unit gates cover
arbitrary coefficient boundaries separately. For valid secrets at levels3/5,
tau*4096 is already below gamma2,so arbitrary ct0 rejection tests must not be
misrepresented as normal key/attempt reachability. Full retry and signature
bytes/main Sign/Verify remain later gates.

Final results:59 cases=18 accepted+5 genuine rejects+21 expected errors+
15 aborts;70944 exact writes/157888 packed reads,118/118 checker corruptions
reject. Independent Python/C8 fixtures/25794 values PASS. Fresh unchanged
products63-case regression and84/84 checker faults PASS. Archive and source
token are recorded in REFERENCE_VERIFICATION.md. No full-UVM/code-coverage,
PPA,netlist or security closure is inferred from these focused gates.

## Stage5N.4h.2 product/response gate

| Requirement | Check |
|---|---|
|Independent product oracle|Sparse negacyclic schoolbook convolution versus unchanged C unpack_sk/NTT/Montgomery/INTT/add/sub;all levels,nonce0 and nonce=l |
|Actual inputs|Real upstream KeyGen SK load,secret transforms,mu/seed/y,matrix/decompose,challenge packing/hash/sampling and FNTT(c);no intermediate preload |
|Atomic handoff|Mask and vector contexts transfer together under independent readiness stalls;old owners invalidate and cannot clear adopted regions |
|Workspace|k+2 disjoint lowest-free addresses;real sampled capacity blockers leave only k+1,so reject before either ownership transfer |
|Shared arithmetic|Every PWM,INTT and ADD/SUB descriptor,result and scalar write;ordered s1/s2/t0 groups and exact identities/domains |
|In-place updates|y->z and w0->r0 only after adoption;readback new IDs/modes;no temporary result exposed as a whole attempt |
|Reuse/lifetimes|Release PWM/inverse after last read,retain every ct0 row,release chat after all groups;no duplicate/foreign releases |
|Normal errors|Duplicate y handles,insufficient capacity,real wrong-source-ID PWM/INTT/ADD-SUB rejections,observed late NTT/process result-ID faults |
|Rollback/noninterference|After adoption,discard all attempt data,including modified prefixes;all prepared-key/sentinel/blocker readbacks unchanged;preflight errors preserve raw-y/vector sources |
|Private retry headers|Exact mu,private seed,ctilde and nonce+l publication,held stability,header transfer to next owner;unused bits zero |
|Reset/fault|Partial PWM,partial INTT,partial in-place write,partial later PWM after ct0 prefix,held done,parent HALT then global reset/recovery |
|Compatibility|Fresh sign_transform gate exercises mask take tied low and prior matrix/challenge adoption/clear behavior |
|Negative checker|Corrupted source/header/layout/value/tag/count;missing every event class;duplicate ownership,request/result,publication/completion/footer records |

Arithmetic completion does not establish legal signature norms,hint weight or
rejection-loop correctness. The current source fixtures use nonce0/nonce=l;
full nonce exhaustion,algorithmic retry,hint/encoding edge cases and complete
NIST signature comparison remain future full-Sign verification requirements.

## Stage5N.4h.1 ownership/challenge-transform gate

| Requirement | Check |
|---|---|
|Actual source chain|Real SK/key preparation,mu/seed/y,matrix/decomposition,packed challenge hash and SampleInBall;no expected intermediate injection |
|Independent arithmetic|Python direct root evaluation of sparse c versus unchanged C poly_challenge/poly_ntt;nonce0 and nonce=l at each level |
|Atomic adoption|Matrix/challenge transfers occur on the same edge under independent readiness stalls;old owners invalidate and cannot clear adopted data |
|Lifetime reuse|Release every dead yhat exactly once before FNTT,lowest-free destination,retain raw c until acknowledged chat completion |
|Full memory|Real sampled blockers fill every other slot;freeing yhat makes room without adding banks/RAM;read blockers back unchanged |
|Result storage|Every actual chat scalar write and final packed read,all w0/w1 preserved,exact metadata and source IDs |
|Preflight errors|Duplicate low handles and invalid ctilde length reject without ownership transfer;old contexts read back and clear normally |
|Post-adoption errors|Real source-ID NTT rejection and observed result-ID fault;rollback all adopted/new regions;key/raw y preserved |
|Retention/transfer|Held result and done;pending consumer read blocks clear AND outbound take;whole-result take followed by one new owner cleanup |
|Reset/fault|Blocked adoption,partial yhat release,partial NTT output,held done,parent HALT;global reset and real-source recovery |
|Compatibility|Fresh sign_challenge regression with new take inputs tied low exercises prior matrix/challenge behavior |
|Negative checker|Corrupted values/IDs/layout/maps/counts,missing every event class,duplicate ownership/command/result/credit records |

This gate stops at retained w0/w1/chat. Secret products,z,correction/hint/norm
checks,rejection/retry,signature bytes,main Sign/Verify and full-system UVM
coverage/PPA remain open;no coverage percentage is inferred from these cases.

## Stage5N.4g challenge gate

| Requirement | Check |
|---|---|
|Independent values|Python bit packing,SHAKE256 and sparse sampling versus unchanged C polyveck_pack_w1/poly_challenge at every level and nonce0/nonce=l |
|Actual sources|Real key preparation,mu/seed/y,matrix multiplication and decomposition;no expected intermediate injection or RAM preload |
|Packing|All rows,6/4-bit encodings,exact accepted inputs/outputs/tags/last;standalone t1/t0/eta regression plus new w1 ranges/frame/reset cases |
|Hash|Exact mu prefix and concatenated body,32/48/64-byte actual raw outputs;retirement before sampler |
|Sparse c|Every scalar write and final packed read,canonical0/1/q-1 values,weight39/49/60,exact seed forwarding |
|Errors|Read ID/mode,value/frame rejection,pack output/done tags,raw tag/length/done,sampler tag/code,duplicate handles,real capacity blockers |
|Drain/privacy|Consume abandoned current pack packet,zero-fill remaining hash body,discard invalid digest,no dependent sampling,no early result |
|Retention|Held done/output,source leases,all key/y/yhat/w0/w1/sentinel/blocker readbacks;pending consumer response blocks clear |
|Reset/fault|Partial pack input,held pack output,partial digest,partial c write,held done,parent HALT;global reset and real-source recovery |
|Checker|Corrupt values/tags/metadata/counts;missing every record class;duplicate command/output/status/publication/completion/footer records |

This gate proves the tested intermediate challenge flow. Full signatures,
rejection/retry,main Sign/Verify,full-system UVM coverage and PPA remain open.

## Stage5N.4f matrix/decomposition gate

| Requirement | Check |
|---|---|
|Independent whole-intermediate oracle|Python SHAKE/sampling,direct root evaluation/inverse formula and mathematical decomposition versus unchanged C matrix expansion/NTT/PWM/INTT/decompose;both nonce0 and nonce=l at all levels |
|Actual connected sources|Prepare expanded published SK,derive mu/seed/sample y through working clients;no RAM preload or expected-digest injection;reuse contexts between commands |
|Forward y|Ordinary FNTT for every mask,exact writes and readbacks,original y retained;verify coefficient/NTT metadata and IDs |
|Matrix row generation|Exact rho32/column8/row8 absorption,SHAKE128 sampling,all k*l coefficient sets;reuse the same A row only after releases |
|Row arithmetic|Every PWM/accumulator ADD/inverse write versus independent expected values,complete term count,result ID/region and acknowledgment order |
|Decomposition|Both w0/w1 writes,canonical signed low residues,high bounds,dual finish ACKs,all k rows before publication |
|Capacity/privacy|Lowest-free disjoint plan,19/25/33 addresses;real sampled capacity blockers;zero physical work on insufficient space;whole-parent owner through gaps,held done and READY |
|Normal errors|Real wrong-source-ID NTT,row and decomposition rejections;observed NTT/A/row/decompose result-tag faults after earlier work;no invalid dependent command;full workspace rollback |
|Noninterference|Exact key,raw y,sentinel and capacity-blocker reads after each non-reset success/error;clear releases new outputs only |
|Reset/fault|Partial forward write,partial A sample,partial row PWM,between low/high decomposition finish ACKs,held whole-vector done,and injected parent fault with global reset/reload/recovery |
|Checker gate|Mutated values/tags/layout/provenance/counts,missing every record class and duplicate credit/ledger records;require independent compare and negative-checker PASS |

This focused source gate is one signing attempt through decomposition. It
does not supply full signature bytes,rejection-loop correctness,main Sign/
Verify host behavior,full-system UVM coverage,PPA,netlist or board signoff.

## Stage5N.4d key-context/preparation gate

| Requirement | Check |
|---|---|
|Independent arithmetic/format oracle|75 official KeyGen SK inputs;Python direct root evaluation versus unchanged C unpack_sk/poly_ntt,164 source fixtures/709632 transformed values |
|Full prepared key|All s1/s2 via eligible Pre,all t0 via ordinary FNTT;exact physical scalar/packed writes,64 ACKs per polynomial,final privileged reads and metadata |
|Storage reuse|One free destination;release source only after validated result;track allocation generations and peak<=N+1;final ordered handles plus complete region mask |
|Private retained header/context|No publication until all transforms/source releases;poison command fields;held done,retained READY,new-command refusal and explicit clear |
|Input/layout rejection|Invalid level,bounds,scratch alias,occupied raw/scratch,unused eta,wrong input bytes/index/last;unrelated sampled sentinel preserved |
|Normal failure rollback|Real source-ID NTT rejection,observed load/NTT result tag/mask faults after earlier work;drain child status and release all owned raw/replacements/results |
|Fault/reset boundaries|Five exact progress resets plus three fatal service-fault/HALT/global-reset cases;same-ID/different-key reuse |
|Clear barrier|Privileged read pending while clear is held;drain response before clear and release every owned region |
|Checker fault gate|Mutated/missing command,input,child result,physical write/ACK,release,context,read,reset,clear and required witness records |

This is focused source functional verification. Existing standalone module UVM
is preserved;full-system Sign/Verify UVM,code/functional coverage,PPA,netlists,
physical security/erasure and full official signature vectors are later gates.

## Stage5N.4c2 production shared key-loader gate

| Requirement | Check |
|---|---|
|One physical service tree|Actual dilithium_services;no bench RAM preload,force or alternate allocator |
|Prior owner retirement|At all levels:sample status,raw output,raw done,public read,row,NTT,scalar process,sign process each hold a waiting key |
|Acceptance edge|Every key descriptor blocks simultaneous external read/release;occupied destination remains occupied and rejects |
|Exclusive key lease|Isolated queued request classes during payload;all classes together at held done;no new ready/public response/release |
|Whole-key publication/rollback|All138 original client cases,physical packing/ACKs,late eta/framing failures and zero invalid header/region outputs |
|Reset/reuse|Five exact reset prefixes,clear all shared ownership,then same-ID/different-key recovery |
|Real sentinel isolation|SHAKE/sampler-generated unrelated region checked after133 non-reset key commands;8512 exact packed reads |
|Physical raw-core isolation|Three real SHAKE256 empty-message17-byte outputs and retirement IDs/cores,held before key acceptance |
|Real consumer handoff|95 successful keys consumed by existing read-only CNB before complete key readback/release |
|Regression|Existing signing process/hash,KeyGen,row/process and standalone loader gates rerun against current source |

This proves the shared ingestion/ownership milestone. Header retention and
the full Sign schedule are next;no full signature/NIST sigGen,UVM coverage,
netlist verification,board timing or new PPA result is claimed here.

## Stage5N.4c1 whole-key bank client gate

| Requirement | Evidence/check |
|---|---|
|Correct key fields/coefficient order|75 official KeyGen SKs plus local boundary patterns;independent Python/C decoder oracle |
|Real storage correctness|449992 scalar writes,packing/ACK causality,105728 exact92-bit readbacks including ownership/domain/mode/small flag |
|Whole-key publication|Earlier primitive commits stay hidden;success requires every64-word ACK and decoder done0 |
|Late rollback|Invalid last s2 coefficient releases every earlier commit and discards active partial |
|Occupied/overflow plans|Last-region collision,exclusive end64 accepted,65 rejected;sentinel survives |
|Held ownership|Write/alloc/finish/release stalls;held done stable;external release probes blocked |
|Reset/reuse|Partial header,first commit,held first/last coefficient,held done;clear validity and reuse ID with different key |
|Checker trust|Corrupt command,input,allocation,scalar/packed/ACK/finish/release/header/read/status/reset records;missing/early events rejected |

The bench implements exclusive-client gating around the actual memory
primitive. Production arbitration clashes and owner handoff are explicitly
the next Stage5N.4c2 gate;this is not a complete Sign/NIST sigGen result.

## Stage5N.4b signing-message client

| Requirement | Check |
|---|---|
| Correct messages |Independent Python byte assembly/hashlib versus unchanged C SHAKE,w1 packer and mask sampler;real shared service outputs |
| Pure-message mu |tr64+00+context length+context+message;empty/tails/rate boundaries;max context255 and total65535 |
| Private seed/challenge |K/rnd/mu order,zero rnd and supplied rnd,mu plus encoded w1,32/48/64-byte challenge results |
| Mask nonce |LE16 order,all levels,nonces through65535;256 coefficients read from actual shared sampler/banks |
| Alignment/snapshots |66-byte prefix across8-byte payload boundaries,poisoned unused bytes,all command fields changed after acceptance |
| Invalid input |Reject level/context/length overflow before descriptor;bad payload index/bytes/last after launch triggers exact zero-filled drain and error |
| Ownership |29 peer-core jobs;exact IDs/cores/data/statuses;service retirement precedes formatter acceptance;error digests not cache-valid |
| Actual dependencies |9 actual RTL mu/private-seed outputs feed subsequent requests,with valid-cache checks |
| Stalls/reset |Held descriptor/absorption/raw/status/done;5 reset checkpoints with exact prefixes;new-data/same-ID recovery |
| Checker strength |61 corruptions rejected,including early service/formatter retirement,peer/forward faults,error-zero-fill and reset-prefix loss |
| Regression |Fresh decoder,shared signing process and local full-KeyGen gates;previous55 RTL/clock unchanged |

This is not full NIST signature generation,HashML-DSA,whole-system UVM or
coverage closure. Encoded-w1 input is supplied by fixtures/C packer;its RTL
packer and complete Sign control remain later work. See reference docs.

## Stage5N.4a expanded signing-key decode

| Requirement | Check |
|---|---|
| Correct standard key layout |All75 pinned official KeyGen sk byte strings;unchanged C unpack_sk/pack_sk and independent Python slicing |
| Header fields |Exact rho32,K32,tr64 byte boundaries and little-endian64-bit words;ID held under stall |
| Secret fields |All levels,eta2/4 encodings,negative canonical conversion;s1/s2/t0 section/poly/index/last ordering |
| Boundary values |Local zero/max/adjacent/random raw encodings;t0 encodes13-bit range endpoints;eta valid values and every unused code |
| Late error |Invalid final s2 coefficient rejects overall key;previous full polynomials remain tentative |
| Framing |Wrong first/middle/final word index;bytes0/1/7/9/15;wrong header/payload/final last;invalid level |
| Backpressure |Held input,header,coefficient,done remain stable;input held across bit-extraction waits and deliberate downstream stalls |
| Reset |Exact prefixes at partial header,held header,first coefficient,last coefficient and done;no leaked completion;zeroed state and same-ID recovery |
| Checker |35 deliberate corruptions reject,including bad/missing reset prefix,missing header/data/metadata/reset/witness/footer and stale token |
| Regression |Fresh shared signing-service and local full-KeyGen capture/compare/selftest;all prior production RTL unchanged |

This is not full Sign verification,decoder-memory ingestion,whole-system UVM
or coverage closure. Missing bytes without a terminal event cannot imply an
error by themselves;external cancel/reset handles truncated input. Strict eta
validation does not prove algebraic key consistency. See reference docs for
exact counts,commands and provenance. Next checkpoint is hash formatting.

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
