# Dilithium specification

Trial-by-trial history has been removed. Qualified evidence is retained in evidence/. Current measurements and active work are recorded in AGENTS.md and sim/dilithium/.

## Stage7 implementation work

The same complete KeyGen/Sign/Verify API, four-bank memory and arithmetic
engines are retained. Stage7A passes the initial 33-scenario main UVM gate,
but its first complete-design fit exceeds this Cyclone V's capacity.
Stage7B targets area on the SAME 5CGXFC7C7F23C8, with the 6.757ns constraint.
Its first candidate replaces only six helpers' combinational region-set
construction: independent handle decoders plus pairwise six-bit uniqueness
checks replace repeated variable-index bitmap reads/writes. Region equality,
cross-set overlap, metadata, ownership and error checks remain. No controller
state, interface, memory depth, engine or pipeline latency changes.
45841 function-level equivalence cases pass; current-source main UVM and
Quartus results remain pending. See THROUGHPUT.md and COVERAGE.md for evidence
and scope; the older Stage6 full-suite qualification is a historical baseline.

## Stage6 qualification status

The full-operation configuration FULL_KEYGEN=1, ENABLE_SIGN=1, ENABLE_VERIFY=1
passes 75 official KeyGen / 90 pure external Sign / 45 pure external Verify
cases under one current source fingerprint. These cover final ML-DSA-44/65/87
with level aliases2/3/5. The API and all 74 production RTL files are unchanged
from Stage5V.4. REFERENCE_VERIFICATION.md owns commands, results, pinned NIST
provenance and explicit unsupported-mode audits. Whole-main UVM/PPA is next.

## Stage5V.4 main operation dispatch

Main supports op0 KeyGen,op1 Sign,op2 Verify;op3 returns unsupported code2.
Use FULL_KEYGEN=1 for complete encoded KeyGen. ENABLE_SIGN and ENABLE_VERIFY
default1;the partial-KeyGen generic remains available for the earlier tests.
The full-operation bench enables all three functions and shares one physical
services tree. Sign keeps its existing input/output group. Verify adds one
64-bit input group for PK,signature and ctx||M,with index16,bytes4,last1.
Start carries signature length16,message length16,context length9,ID16 and
parameter2. Parameter0/1/2 retains level2/3/5 labels for final ML-DSA-44/65/87.

PK lengths1312/1952/2592 and signature lengths2420/3309/4627 bytes follow the
level. Each frame restarts index0;an empty body has no beat. The finite hash
contract is context<=255 and66+context+message<=65535. Unused high tail bytes
are ignored. Accepted command metadata is snapshotted;later changes do not
alter the operation. Main Verify completion code0 carries verify_accept1/0;
structural invalidity and wrong signature length produce normal invalid0.
Framing and internal failures retain separate nonzero status/stage/detail.
The host stops remaining payload after early completion,acknowledges it and
starts a new command. Verify frees all owned regions before completion.

Main blocks debug reads and Sign input readiness while Verify owns services.
Further starts wait for every owner to become idle,including KeyGen's existing
post-ack cleanup. Fatal physical/raw faults need reset. The four banks,
all existing arithmetic and6.757ns SDC remain unchanged. No new PPA or
full-system UVM/netlist/board/security signoff is implied by source integration.

## Stage5V.3 equation component boundary

Internal command:id16,valid/ready;upstream context:param2,id16,region mask64,
K t1hat,K hints,L zhat,chat handles6,rho256,mu512,zero-extended ctilde512.
Validate complete unique leases before atomic take. Upstream is allowed to
drop its context after take. Completion is held valid/ready with id16,code3,
detail3,accept1 and zero-extended recomputed digest512. Code0/accept0 means
cryptographically invalid;nonzero code has accept0 and digest0.

Compute inverseNTT(Ahat*zhat-chat*t1hat),then UseHint and packed-w1 hash.
Existing shared engines are reused;all sources/destinations are released
before normal valid/invalid completion. No result context is retained.
Recoverable child/read/packer failures retire/drain before releasing ownership;
fatal physical/raw metadata failures halt until reset. Four banks and6.757ns
constraint remain unchanged. Main host Verify/op2 wiring is still Stage5V.4.

## Stage5V.2b Verify arithmetic preparation boundary

The internal math preparer adopts the successful raw context from5V.2a and
accepts ctx||M as one frame with64-bit data,1..8 valid bytes,index16 starting0
and last. Command ID16 must match the upstream ID;level comes from that
context. Context length9 must be<=255 and66+context+message must fit65535 bytes.
This is the current finite shared-hash interface limit,not an algorithm limit.

Compute mu=SHAKE256(tr64||00||ctxlen_byte||ctx||M).64. Sample c from the full
received ctilde32/48/64 using SHAKE256 and SampleInBall. FNTT each shifted-t1
and z polynomial;use existing Pre-NTT for c. Retain raw hints and publish
K t1hat,L zhat,K hints and chat (13/18/24 region handles),rho32,mu64,ctilde.
All arithmetic remains in existing shared engines;no new coefficient RAM.

Before adoption,command/lease errors leave the original context untouched.
After adoption,framing and recoverable child errors drain/retire the current
service and release every owned source/destination before error completion.
Result clear frees the context;take transfers it;pending reads block both and
clear wins on simultaneous requests. Physical/raw protocol faults need reset.
Status codes are documented in PROCESS_BLOCKS.md.

This helper does not evaluate the Verify equation. The approved main three
frames remain PK/signature/ctx||M;main op2 is still pending. UseHint,equation
and challenge comparison are next5V.3,then main dispatch in5V.4. No new PPA,
board ports,netlist or full-system UVM signoff is part of this checkpoint.

## Stage5V.2a preparation boundary

Internal verify_input_prepare consumes two sequential64-bit frames:PK then
signature,index0/last per frame. It snapshots level0/1/2=2/3/5,operation ID16,
signature byte length16 and base region6. Exact lengths are1312/1952/2592 PK
bytes and2420/3309/4627 signature bytes. Header/endian rules match5V.1.
It retains K shifted-t1,L z,K dense-hint coefficient-domain polynomials in the
existing pool (12/17/23 regions) and returns rho32,tr64,ctilde32/48/64.
tr is SHAKE256 of the complete encoded PK,not merely rho or t1.

Prepared context is published only after both frame loaders and the PK hash
retire successfully. Clear releases it;take transfers the whole lease;clear
wins when both are offered. A pending read response blocks either handoff.
Errors publish no context and preserve foreign regions;fatal service protocol
faults require reset. See PROCESS_BLOCKS.md for status-code definitions.

This is NOT a signature-validity result. The approved main contract remains
PK/signature/ctx||M,with mu/challenge/NTT work next in5V.2b,Verify arithmetic
in5V.3 and main op2 in5V.4. Existing engine RTL,memory geometry,main ports and
6.757ns SDC are retained;the shared loader gains a Verify mode and paired raw
PK admission. No new PPA or full-system UVM/netlist signoff is claimed here.

## Stage5V.1 Verify boundary

Approved future main Verify input:three64-bit frames,PK -> signature -> ctx||M,
each with index0 and its own last. Command carries message/context/signature
lengths;completion reports valid/invalid. Main op2 is still unsupported in this
component checkpoint;no disconnected top-level placeholder ports are added.

The working internal verify_decode frame interface is documented in
PROCESS_BLOCKS.md. It checks exact declared length,all16 index bits,valid-byte
count,last position,z's strict infinity-norm bound and canonical sparse hints.
All output is provisional until done0. A structurally accepted signature still
needs the full Verify equation and challenge comparison. Existing67 RTL files
and the6.757ns timing constraint remain unchanged;one new decoder is added.

## Stage5N.4h.7 official-vector scope

The existing pure Sign host contract maps directly to ACVP's external/public
Sign API. It supports deterministic requests by supplying32 zero rnd bytes,
and randomized requests with the original32-byte rnd. Official corpus
groups1/3/5/13/15/17 supply90 selected cases,30 per level2/3/5;messages1..8192
bytes and contexts0..255 need no RTL/interface change. ACVP internal messages
already carry different formatting;they are not public-message inputs.
Prehash,external-mu and raw internal-message API groups remain unsupported.
See REFERENCE_VERIFICATION.md for provenance,execution and gate results.

## Stage5N.4h.6 main Sign operation and approved host framing

`dilithium.sv` now dispatches operation0 to KeyGen and operation1 to
`src/controller/sign.sv`. Operation2 (Verify) and3 are still unsupported and
return code2. Sign is enabled by default (`ENABLE_SIGN=1`). The old focused
KeyGen-only tests select ENABLE_SIGN0 to retain their unsupported-operation
checks;the main Sign test uses the default enabled path and includes KeyGen.
FULL_KEYGEN still selects encoded versus polynomial KeyGen output as before.

The user approved this two-frame64-bit stream:

1. Command:parameter0/1/2 means labels2/3/5 (ML-DSA-44/65/87),operation ID,
   message length16,context length9 and explicit32-byte signing rnd.
2. Frame1:expanded secret key,2560/4032/4896 bytes. All words have8 valid
   bytes,index starts0,last marks the final word. High index bits are checked
   before narrowing to the existing10-bit key decoder;they cannot silently alias.
3. Frame2:context||message,index restarts0,last marks its last word. The final
   word has1..8 valid bytes and unused high bytes are ignored. An empty body
   consumes no beat. Ready may pause between frames during key transformation;
   hold the first body word until its handshake.
4. Signature:separate data64/bytes4/index10/last/ID ready-valid stream with
   2420/3309/4627 bytes. Hold stalled words. Discard the provisional frame on
   error/reset;matching main completion code0 validates it.

This implementation supports pure ML-DSA with context length<=255 and
66+context+message<=65535 bytes for its current finite hash descriptor.
External-mu/prehash interfaces are not part of this command. start_seed256
continues to serve KeyGen and is ignored by Sign;Sign's key comes from frame1.
Host metadata is snapshotted at accepted start. A malformed frame causes an
operation error;the producer stops sending its unaccepted remainder when
completion/fault/reset cancels the request. A valid request must supply all
required beats;there is no automatic timeout for a silent producer/consumer.

The Sign controller grants only key preparation,attempt/retry or encoding
to the existing services at a time. It retains the prepared key until the
attempt is retired or adopted by the encoder,then clears any remaining attempt
and the key before main completion. All regions are free before a normal Sign
completion is published. KeyGen retains its existing cleanup-after-completion
behavior;the main owner stays granted while child busy remains high and the
next command is blocked. External debug read ready/response-valid are masked
during Sign. No new bank,encoded-key/message/signature RAM or crypto engine.

| Main completion code | Meaning / stage / detail |
|---|---|
|0|Success;stage0/detail0 |
|1|Invalid Sign parameter/context/finite length;stage0/detail0;no key input consumed |
|2|Unsupported main operation or disabled Sign;stage0/detail0 |
|3|Key preparation error;stage1/detail=key-preparer code |
|4|Attempt/retry error;stage2/detail=attempt-loop code |
|5|Signature encoder error;stage3/detail=encoder code |
|6|Observed child publication/ID mismatch;stage1/2/3 |

KeyGen retains its original code meanings and reports stage/detail0. The Sign
status counters are17-bit attempts,rejections,next polynomial nonce and remain
stable through held done. Fatal child/memory faults assert fault and HALT until
global reset instead of publishing a successful completion. No per-request key
cache or explicit zeroization/security signoff is introduced.

## Stage5N.4h.5 accepted attempt to signature bytes

`helpers/sign_signature_encode.sv` snapshots an accepted attempt descriptor,
checks unique handles,exact map/digest length/padding and complete physical
sources,then takes the whole context atomically. Preflight code1 preserves
the old owner. After take,the encoder owns all z/hint regions until cleanup.
The outer scheduler leases the key and exclusive services through completion.

| Label / final FIPS204 format | ctilde | z[l] | Hint indices + counts | Signature | Words / final bytes |
|---|---:|---:|---:|---:|---:|
|2 / ML-DSA-44|32 bytes|4 x576 bytes,18 bits/coefficient|80+4 bytes|2420 bytes|303 /4 |
|3 / ML-DSA-65|48 bytes|5 x640 bytes,20 bits/coefficient|55+6 bytes|3309 bytes|414 /5 |
|5 / ML-DSA-87|64 bytes|7 x640 bytes,20 bits/coefficient|75+8 bytes|4627 bytes|579 /3 |

Shared Bitpkg command op is now3 bits:0=t1,1=t0,2=eta,3=w1,4=z;5..7 reject
with code1. Previous operation values are unchanged. Z converts canonical
residues to centered coefficients and packs gamma1-z,least significant bits
and bytes first. The encodable interval is[-gamma1+1,gamma1];upstream CNB
enforces the stricter signing norm bound. The existing87-bit reservoir suffices.

Hints are scanned in polynomial/coefficient order. Emit each nonzero index,
zero-pad the index area to omega80/55/75,and append k cumulative counts.
Reject nonbinary values and weight above omega. All reads verify region,word,
source ID,mode,param and coefficient domain. Z uses mode2,hints mode0.

Output valid/ready,data64,bytes4,index10,ID16,last1 remains stable while stalled.
Source read tags and output-frame tags are independent and tested with different
IDs. A full hint output word retires before a potentially failing hint response
is consumed,so a recoverable read error cannot withdraw a stalled valid word.
Unused bytes of the last word are zero. **Bytes are provisional until matching
completion code0.** Error/reset means discard the whole frame,including earlier
bytes. Cleanup frees the adopted map before held completion. Code2 is an observed
packer failure;code3 is a malformed hint/read observation. A bad Z read with a
live noncancelable pack command,unexpected pack output framing,physical fault
or disappearing owned region HALTs until global reset. No signature RAM or
duplicate packer. Main host Sign and Verify remain unconnected.

## Stage5N.4h.4 attempt loop and seed reuse

`helpers/sign_attempt_loop.sv` connects the existing mask,matrix,challenge,
challenge-transform,products and candidate-check clients to the same physical
services. It starts from a retained prepared-key context and streamed ctx||M.
The initial mask command hashes mu and the private seed exactly once. After
a genuine candidate rejection,it takes the checker outcome atomically,
retains mu/seed/nextnonce,and launches ExpandMask directly. No message replay,
second private-seed hash,polynomial copy RAM or new arithmetic engine.

The mask helper adds command_retry1 and command_retry_mu/seed512 inputs.
Normal commands tie retry low and retain their original behavior. A retry
snapshots those two headers and enters formatter op3 directly;message/context
lengths and rnd are unused in this mode. Existing vector/base/key/nonce
capacity checks remain in force. payload_ready stays low on retries. The
mask result has the same headers,handles,clear/take and ownership contract.

The parent sequences six child commands. Each successful result retires
before the next command. Matrix/challenge and mask/vector ownership transfers
remain within the existing helpers. A rejected checker publishes no attempt
regions;the parent snapshots its headers on take before the checker invalidates.
Then nonce advances by l(4/5/7),the prepared key remains live,and another
attempt starts. Service errors stop the loop and clear all still-owned child
contexts in reverse dependency order. A fatal child/physical/context fault
HALTs the parent and requires global reset.

| Parent done code | Meaning |
|---|---|
|0|Accepted candidate retained;not yet an encoded signature |
|1|Invalid/missing prepared context or parameter |
|2|Child error;done_stage identifies0mask/1matrix/2challenge/3transform/4products/5checks;done_detail is the child's code |
|3|Observed child publication ID/valid contract mismatch |
|6|The next whole mask vector would exceed nonce65535;no wrapped command launches |
|fault1,no done|Fatal state requiring global reset |

command_nonce,next_nonce,attempt/rejection counters have17 bits. The parent
checks nonce+l<=65536 with18-bit arithmetic **before** narrowing the sampler
nonce to16 bits. A valid final vector may end at nextnonce65536 and still
return an accepted candidate. A rejected final vector instead returns code6
without launching another mask or nonce0. There is no arbitrary retry-count
limit in RTL. The local fixture generator's bounded search is only a test aid.

At accepted REPORT/READY,the parent exposes z[l],h[k],ctilde32/48/64 bytes,
region map and stable attempt/rejection/nextnonce status. z/h regions have
the parent's command ID;z mode2,hints mode0,coefficient domain0. Outputs are
masked until the parent verifies acceptance. Clear releases them;take transfers
them without physical release. Clear wins and pending consumers block both.
The outer controller retains the key and exclusive service routing through
the entire busy interval,including cleanup,held done and READY. Main Sign
host integration,signature encoding and main Verify remain unfinished.

## Stage5N.4h.3 whole-attempt checks

`helpers/sign_attempt_check.sv` consumes the entire products READY context
with its existing take handshake. It snapshots handles,IDs,mu,private seed,
ctilde and17-bit next nonce before the old owner invalidates. The prepared
key remains leased to its existing owner throughout this operation and READY.
No arithmetic engine,polynomial memory or physical bank changes are needed.
As with the preceding clients,the outer controller grants exclusive service
routing across the entire busy interval,including planning,inter-command gaps
and retained READY. A new unrelated allocator must not steal a planned spare.
Explicit consumer reads are allowed only while the controller preserves the
owner's regions;pending responses block clear/take.

CNB reads z,r0,ct0 in that order;each polynomial reduces its256 coefficients.
The first failing polynomial stops the attempt. Centered magnitude **equal
to** its bound rejects. Bounds at levels2/3/5 are:

| Check | Level2 | Level3 | Level5 |
|---|---|---|---|
|z:gamma1-beta|130994|524092|524168|
|r0:gamma2-beta|95154|261692|261768|
|ct0:gamma2|95232|261888|261888|
|Maximum total hint weight,omega|80|55|75|

After every norm passes,shared in-place ADD updates r0[row]+=ct0[row] moduloq.
Shared x4 Mhint compares that combined low part with retained w1[row],writes
one0/1 polynomial and returns its9-bit weight. A12-bit accumulator holds
the vector sum without truncation(maximum8x256=2048). Reject **above** omega;
equality is allowed. Each ADD/hint result must retire before destination
completeness checks or the next operation. Source/key metadata loss or a
physical fault HALTs until global reset.

| Completion | Meaning and retained state |
|---|---|
|code0,reject0,reason0|Candidate accepted;retain z[l],hints[k],ctilde,mu,seed,next nonce |
|code0,reject1,reason1/2/3|Normal z/r0/ct0 norm rejection;release all attempt regions,retain only mu/seed/next nonce |
|code0,reject1,reason4|Normal hint-weight rejection;discard all attempt payloads,including the partial hint vector;retain retry headers |
|code1|Bad/missing/overlapping source contract;previous products owner remains intact |
|code2|No free hint destination before take;previous owner remains intact |
|code3,detail=child code|Shared CNB/Mhint service error;discard adopted attempt |
|code4,detail=child code|Shared ADD service error;discard adopted attempt |
|code5|Observed child tag/destination/result contract mismatch;discard adopted attempt |
|fault1|Unsafe physical/context failure;no done/result credit,global reset required |

`result_valid` represents a retained algorithmic outcome,including rejection.
On rejection,result_regions/z/hints/z_id/ctilde/bytes are allzero;mu,seed and
next_nonce remain valid for retry. On acceptance,z_id is the products ID;
hints use the new command ID. done_reason/weight are stable through held done.
Normal errors publish no result or retry header. Only the next operation's
control can decide to retry;this helper does not rehash the message or sample y.

READY clear discards the retained result and zeroes private headers. READY
take transfers it without physical release and invalidates the old owner.
Clear has priority. Both wait for all services and pending read responses to
retire. Inputs/results are canonical23-bit coefficients,with existing bank
metadata checks;the helper adds no encoded signature interface. Main Sign
and Verify remain unfinished;candidate acceptance alone is not a signature.

## Stage5N.4h.2 response products and in-place correction

sign_mask_prepare adds READY-only take_valid/ready,with the same quiescent,
pending-read and clear-priority contract as the other retained clients.
The receiver must snapshot raw-y handles,mu and the private mask seed before
take. The old mask owner invalidates its publication and clears those header
registers without physically releasing y. Existing diagnostic clients tie
take_valid low.

helpers/sign_response_products.sv atomically adopts the mask context and the
retained w0/w1/chat context. Prepared-key ownership stays with its existing
client for the entire busy/REPORT/READY/cleanup lifetime. It validates unique,
disjoint handle maps,level,digest length,nonce range and complete sources.
It plans k+2 free addresses before taking either owner:k retained ct0 regions
and two reusable PWM/inverse scratch regions. No polynomial payload RAM.

For each secret polynomial,shared PWM computes chat*secret_hat and ordinary
INTT returns the coefficient product. The C Montgomery/inverse factors cancel;
RTL stores ordinary canonical residues. Group0 computes cs1 and rewrites y as
z=y+cs1. Group1 computes cs2 and rewrites w0 as r0=w0-cs2. Group2 computes
ct0=c*t0 and retains it for later norm/hint checks. Scratch regions are released
after their last read and reused. chat is released only after all products.
w1 remains unchanged.

All z/r0/ct0 coefficients are canonical23-bit residues. z retains mode2,
r0 mode0,ct0 mode3,all coefficient domain with the new command ID. w1 retains
mode0 and the original matrix ID. Successful result publishes ordered z[l],
r0[k],w1[k],ct0[k] handles,mu512,private seed512,ctilde512,valid digest bytes
and next_nonce17=nonce+l. Values beyond legal signing bounds may appear:
success here means arithmetic complete,not signature acceptance.

| Code | Meaning | detail |
|---|---|---|
|0|Whole arithmetic context complete|0 |
|1|Invalid/missing context,layout,digest length or nonce|0 |
|2|Fewer than k+2 free planned addresses|0 |
|3|PWM or inverse child rejected|Child code |
|4|In-place ADD/SUB child rejected|Child code |
|5|Result identity/region/storage mismatch|0 |

Each child result retires before the parent checks complete storage and
starts dependent work. Before adoption,normal rejection preserves both old
owners. Afterwards,normal failure releases all adopted/new attempt regions,
including previously rewritten y/w0 and retained ct0 prefixes. It does not
restore those source publications. The prepared key remains intact. Partial
physical write faults or key-context loss require global reset.

Whole result holds through done and READY. Clear releases this attempt only;
take transfers handles AND retry headers to the next owner. Consumer reads
block either handoff. Unused digest/handle bits remain zero. A normal service
failure is an operation error;automatic algorithmic rejection/retry is not
implemented here. The future outer Sign controller owns the header lifetime
through such decisions. CNB,Mhint,hint-count rejection,signature bytes and
main Sign/Verify remain separate unfinished work. No Fmax/area claim is added.

## Stage5N.4h.1 atomic ownership and FNTT(c)

sign_matrix_prepare and sign_challenge_prepare add take_valid/take_ready.
Only retained READY may transfer. All physical services and pending consumer
reads must be retired;clear has priority over take. A successful take edge
invalidates the old publication and relinquishes its complete ownership mask,
without releasing any physical region. A receiver must snapshot all handles,
IDs and private header bytes before that edge and retain the exclusive outer
operation lease. Unchanged diagnostic clients tie take_valid low.

helpers/sign_challenge_transform.sv validates and snapshots both contexts,
then joins their handshakes atomically. Neither owner may transfer alone.
The caller must route the two valid/ready pairs consistently and retain the
key AND raw-y contexts throughout busy,held done,READY and cleanup. Matrix
and challenge source publications must stay stable until the transfer;their
invalidation after transfer is expected. The new client owns yhat,w0,w1,c.

It releases all dead yhat regions,chooses the lowest currently free region,
and performs ordinary forward NTT(c) through the existing engine. Pre-NTT
is not requested. Child result ID/region/code and acknowledged complete
storage must validate before releasing coefficient-domain c. w0/w1 stay
unchanged. The result is retained w0/w1 plus chat=NTT(c),ctilde and source
matrix ID. chat has new command ID,mode3,level and NTT-domain metadata;
w0/w1 retain the original matrix ID,mode0 and coefficient-domain metadata.

| Code | Meaning | detail |
|---|---|---|
|0|Whole retained w0/w1/chat context ready|0 |
|1|Invalid context,overlapping/duplicate handles,wrong digest length or missing source|0 |
|2|No free destination after dead-yhat release|0 |
|3|Physical NTT rejected the command|Child code |
|4|NTT result identity/region/complete mismatch|0 |

Before adoption,normal rejection leaves the old owners intact. After
adoption,normal failure releases all adopted attempt regions and any new
complete destination;it does not restore invalidated publications. Key/raw y
remain retained so the attempt can be rebuilt. An incomplete physical write,
physical fault or key/raw-y context loss HALTs until global reset.

Success holds through done and READY. Clear drains pending consumers and
releases only this context. Its own take interface permits the next owner to
adopt all results without physical release. No polynomial payload RAM,new
engine,main Sign host operation,secret products or rejection loop is added.

## Stage5N.4g w1 packing and challenge client

The existing single shared Bitpkg adds op3:w1. Level2 uses6 bits per high
coefficient(range0..43),levels3/5 use4 bits(range0..15). All23 input bits
are range-checked before encoding. Commands op0/t1,op1/t0 and op2/eta retain
their formats. Param3 remains invalid;all four2-bit op values now have uses.
The same87-bit reservoir and existing service record/ports are retained.

helpers/sign_challenge_prepare.sv consumes a retained matrix context:
valid,param2,source ID16,regions64,8x6-bit w1 handles,and mu512. Command ID16
tags the new packing/hash/sampler work. The caller retains the key,mask and
matrix contexts and exclusive outer Sign lease across all handoffs,held done,
READY and clear. It drains previous engine AND packer owners before grant.
Duplicate w1 handles or handles outside the retained matrix mask reject.
Source regions must be reserved/complete;the lowest free region is chosen
for c. Temporary command_ready backpressure is waited out,not a rejection.

Read each source as64 x92-bit words,cache one word,and feed256 ordered23-bit
coefficients to shared Bitpkg op3. Concatenate k packed polynomials in row
order:768 bytes at levels2/3,1024 at level5. The existing signing formatter
op2 absorbs mu64 || encoded_w1 into shared SHAKE256,returning ctilde32/48/64
bytes. Exactly that actual RTL digest becomes the next SHAKE256 sampling
message(mode3 SampleInBall);no nonce is appended. The resulting c contains
256 canonical coefficients,with39/49/60 nonzero entries,each+1 or-1 mod q.

| Parent code | Meaning | detail |
|---|---|---|
|0|Validated ctilde and complete c polynomial ready|0 |
|1|Invalid context/handle set,missing source or non-quiescent grant|0 |
|2|No free c destination|0 |
|3|Source read identity/metadata error|0 |
|4|Bitpkg rejected data/framing|Packer code |
|5|Sampler returned an error|Sampler code |
|6|Pack/hash/sampler identity,length,ordering or committed-result mismatch|0 |

Each source read validates region,word,ID,mode0,level and coefficient domain.
Packed output validates ID,index,8-byte count and final-word marker before
forwarding. Raw hash beats validate ID,assigned core,16-byte size and total
ctilde length;done must match ID/core. All k pack packets and raw/formatter
owners retire before sampling can start. Sampler status and post-retirement
complete storage must succeed before whole-parent publication.

Normal read/pack failures drain the current shared pack packet using framed
zero coefficients,consume its remaining output/done,and inject an invalid
formatter payload beat to zero-fill its remaining declared message. Prior
valid body words remain part of the diagnostic hash,which is discarded.
Already failed packers terminate through their own held error done. Pending
bank responses and raw hash output/done also drain;no next descriptor uses
an invalid digest. Late tag failures may discard an otherwise correct hash.
Sampler-result errors release any completed new c region before error done.

Successful done holds,then READY retains private ctilde512,bytes7 and region6.
Unused digest high bytes are zero. Results are zero/invalid until complete
success. Explicit clear waits for pending consumers/packer readiness and
releases c only;busy0/command_ready1 ends it. Key,y,yhat,w0,w1 and unrelated
regions survive errors/clear. Physical fault or loss/change of retained valid,
level,ID or region map halts until GLOBAL reset. No secure RAM erase/cancel
or completed main Sign/Verify host interface is added.

Storage is one92-bit cache,digest/header/control registers and the existing
formatter/packer reservoirs. No complete message,encoded w1 or polynomial RAM,
second Bitpkg or second Keccak/sampler is instantiated.

## Stage5N.4f matrix/decomposition client contract

helpers/sign_matrix_prepare.sv is a control-only client. The caller retains
the validated key and mask contexts and grants exclusive services ownership
until this client's busy drops,including child gaps,held done,READY and clear.
Input command is ID16. The retained key supplies valid,param2,ID16,rho256 and
regions64;the mask context supplies valid,ID16,regions64 and7x6-bit handles.
Relevant fields are snapshotted on acceptance. Duplicate/mismatched mask
handles,key/mask overlap,missing/incomplete sources or a non-quiescent grant
reject before engine work. A valid prepared context is a caller precondition;
this helper does not revalidate expanded-key bytes.

The helper scans64 region descriptors and chooses the lowest free addresses
for yhat[l],one reusable A row[l],w0[k],w1[k],accumulator,scratch and row w.
Required workspace address counts are19/25/33 at levels2/3/5. The plan is
logically leased by the outer owner before individual services allocate it.
Insufficient capacity returns an error with no physical allocation. No bank
dimensions,polynomial RAM or accelerators are added.

Each y uses ordinary forward NTT(op0),retaining its original coefficient-
domain source. A[row,column] is sampled directly in NTT representation from
SHAKE128(rho || column8 || row8);it is not transformed again. Existing shared
row service performs l PWM terms,destructive accumulator adds and inverse
NTT. Existing sign process op0 decomposes w into canonical w0 residues and
unsigned w1. Sampling status commits storage on its handshake edge;complete
is checked after retirement. The decomposition child hides source w through
its held done,so whole-plan completeness waits for that child to retire too.

| Parent code | Meaning | detail |
|---|---|---|
|0|Entire yhat/w0/w1 vector complete|0 |
|1|Invalid context/handle plan,missing/incomplete sources,non-quiescent grant|0 |
|2|Insufficient free workspace addresses|0 |
|3|Forward NTT rejected|Child code |
|4|A sampling/formatter failed|Sampler code,or0 for formatter error |
|5|Row service rejected|Child code |
|6|Decomposition rejected|Child code |
|7|Child identity,region,term-count or committed-result mismatch|0 |

Every successful child result must match command ID,destination and completed
allocation;row completion must also report l terms. All new persistent data
uses the command ID16,including wraparound;original y keeps its mask ID.
Output valid publishes only after all k rows,decomposition commits and row-
temporary releases. The region mask and yhat[7]/w0[8]/w1[8] handle arrays are
zero while invalid. Successful done holds,then READY retains the vector until
clear. Raw w and the A row are released/reused after each validated row.

Normal errors drain their child and release all new workspace allocations,
including earlier complete rows,before reporting done. The original key,y and
unrelated regions are preserved. Clear releases only this client's retained
yhat/w0/w1,not key/y;caller stops new consumer requests and drains pending
responses first. No separate clear result;busy0/command_ready1 ends cleanup.
Loss/change of a live key/mask valid,ID,level or region map,physical child fault,
or an unexplained incomplete allocation after retirement halts until GLOBAL
reset. No timeout/cancel or secure RAM erase is implemented. Full main Sign,
challenge/retry/signature encoding and Verify remain separate unfinished work.

## Stage5N.4e retained-key hash and mask-vector client

helpers/sign_mask_prepare.sv is a control client of the same services,not a
complete Sign controller. Its caller holds sign_key_prepare in retained READY,
drains prior service owners,and grants the services exclusively for the whole
mask client's busy interval. The outer Sign lease also spans the gaps between
these clients. Main dilithium.sv still implements KeyGen only.

Command fields:ID16,message bytes16,context bytes9,initial nonce16,mask base6,
rnd256. Prepared context supplies valid,param2,key ID16,regions64,K256,tr512.
Accepted commands snapshot these fields. Pure-message absorption is
tr || 00 || ctx_len8 || ctx || M. The payload stream carries ctx || M as
data64/bytes4/index16/last;the existing formatter enforces exact framing and
ignores unused high bytes. Supported absorption length is at most65535 bytes,
context at most255 bytes. No prehash/external-mu API is added.

The client computes mu64 bytes,then SHAKE256(K || rnd || mu,64),then ExpandMask
for l=4/5/7 polynomials at nonces nonce+j. It requires nonce+l<=65536 and
base+l<=64 before launching any hash. The contiguous mask plan must exclude
the prepared key and every already reserved region. This is one attempt's y
vector;the later rejection controller must select/increment its next nonce.

Raw outputs must total exactly64 bytes in four16-byte beats,with assigned
core and command ID matching at every beat and retirement. The formatter's
absorption done is insufficient:the physical raw/sampler owner must retire
and active must become zero before the next descriptor. Mask status must
match ID/core,code0 and acknowledged complete allocation. A bad raw result
never becomes a dependent seed;bad mask status discards the whole vector.

| Parent done code | Meaning |
|---|---|
|0|Entire mu/seed/mask vector ready |
|1|Missing/invalid prepared context or non-quiescent/incomplete-key grant |
|2|Context/message length,region bounds,key alias or nonce overflow |
|3|Mask plan already occupied |
|4|Formatter/payload error |
|5|Raw/sampler result tag,length,status or formatter ID error |

Malformed payloads follow the existing zero-fill/drain rule;their digest is
discarded. Earlier mask allocations are released before error done. Successful
done holds until acknowledgment,then retained READY keeps mu512,seed512,
regions64 and7x6-bit handles stable. Outputs are zero/invalid before complete
success. New commands cannot overwrite a live vector. Explicit clear waits
for consumers to drain,invalidates exposed results and releases only masks;
busy0/command_ready1 signals clear completion. No separate clear result.

Physical fault,loss/change of retained key valid/ID/level/region map during
work,or an incomplete allocation after service retirement halts without
normal done;global reset is required. The caller must not clear the key until
mask work and later consumers have retired. Caller must stop new consumer
requests while clearing;pending responses still drain. Reset clears metadata,
not physical RAM contents. No secure-erasure/security signoff is claimed.

All added storage is control/header/digest registers. No message RAM,polynomial
RAM,encoded-key RAM,second Keccak/sampler/NTT or new physical bank is added.
No synthesis result is implied for this uninstantiated main-Sign client.

## Stage5N.4d retained key-preparation contract

sign_key_prepare is a control-only services client,not a complete Sign
controller. Commands snapshot level2-bit,ID16,raw base6 and scratch6. The raw
plan has12/17/23 regions in s1,s2,t0 order. Scratch must be outside that plan
and free. Bounds/alias/scratch occupancy and raw-plan occupancy reject before
any key input. The caller must drain the previous services lease before
granting this client;CHECK also rejects a non-quiescent grant.

Input64/bytes4/index10/last retains the exact expanded-key stream contract.
The validated load result is retained internally. Each s1/s2 polynomial uses
Pre-NTT(op3);all validated eta2/4 coefficients meet its small-coefficient
eligibility. t0 uses ordinary forward NTT(op0). Every result must match ID
and destination and have acknowledged complete storage. Only then is its raw
source released and reused as the next scratch region. No in-place NTT is used.

| Parent done code | Meaning | detail |
|---|---|---|
|0|Entire prepared key ready|0 |
|1|Invalid level|0 |
|2|Raw bounds or scratch aliases raw plan|0 |
|3|Scratch already occupied|0 |
|4|Raw-plan conflict or loader rejection|Loader code;4 for preflight conflict |
|5|NTT rejection|NTT code |
|6|Non-quiescent grant or wrong child result ID/region/mask/reservation|Child code,or0 for grant/result identity error |

done/ID/detail hold under backpressure. Successful context contains rho256,
K256,tr512,param2,ID16,region mask64 and23 x6-bit polynomial handles;unused
handles are zero. It becomes valid only after every transform and raw-source
release,then persists across done retirement in READY. New commands cannot
replace a live key. busy stays high;service_active becomes low in READY so
the outer Sign owner may grant its other privileged service clients.

clear_valid/clear_ready accepts only READY and quiescent services. The caller
must stop new consumer requests on a clear request,while draining existing
responses. Clear immediately invalidates/zeros exposed context and releases
all owned transformed regions. Completion is busy=0 and command_ready=1;
there is no separate clear-result channel. The caller keeps the outer lease
through this cleanup. Reset clears context and shared allocation validity,
not payload RAM erasure. Physical service faults halt without normal done and
retain the outer lease until global reset. Silent truncated input also needs
external cancellation/reset. Algebraic key consistency/full signatures are
outside this component gate;main Sign/Verify still reject as unsupported.

## Stage5N.4c2 shared key-load service

request_t.load carries valid,param2,id16,base6,input_valid,input_data64,
input_bytes4,input_index10,input_last and done_ready. response_t.load returns
ready,busy,input_ready,done_valid,done_code3,done_id16,done_regions64 and
rho256/key256/tr512. The decoder and loader byte/error contracts below remain
unchanged. No external dilithium.sv ports are added;main Sign is still pending.

New-command priority is row,NTT,scalar process,sign process,key load,raw hash,
sampling,public read. Key loading waits for all existing Keccak/sampler owners,
compute clients and pending public reads/responses to retire. Priority does
not preempt an accepted key:its busy remains high through held done. Waiting
row requests cannot mask that owner's input or done-ready.

The bank arbiter blocks external release on the key acceptance edge and for
the entire busy interval,including unrelated releases. Public reads are also
blocked when a new key descriptor has priority. Internal rollback releases
are routed directly to the same memory interface. The complete bitmap is
filtered with the loader's whole-key hidden mask;that bitmap alone is not the
access control. Successful header/region outputs must be captured at done
retirement by the future Sign owner;they are not retained for a later caller.

The standalone loader contract requires exclusive ownership;that requirement
is now implemented by production services. The focused client gate below is
preserved as earlier evidence,not a statement that wiring is still pending.

## Stage5N.4c1 decoded-key ingestion contract

sign_key_load is an exclusive memory client,not yet wired into production
services/main Sign. Commands snapshot parameter,ID16 and base region6.
Regions are contiguous in section order s1,s2,t0:12/17/23 for levels2/3/5.
The7-bit exclusive end must be<=64. The entire plan must be free before any
input or allocation;occupied plans reject. The caller prevents competing
allocations for the entire busy interval,including held done.

Core0 packs natural-order canonical23-bit coefficients,all in coefficient
domain. s1/s2 retain mode1;t0 uses mode3 as a storage label,not a sampling
command. Regions retain key ID and level. No algebraic key check is added.

| done code | Meaning |
|---|---|
|0|Entire key decoded and all writes acknowledged |
|1|Invalid parameter |
|2|Unused eta encoding,from decoder |
|3|Input framing error,from decoder |
|4|Planned region already occupied |
|5|Region plan extends beyond64 |

Header rho256/K256/tr512 and done_regions64 are meaningful only during
successful done;otherwise outputs are zero. Publication waits for whole-key
success;busy/planned release locks persist through done retirement. Errors
discard the active partial allocation with finish1,then release every earlier
commit. Internal ordering/ID mismatch faults and halts until reset. Reset
invalidates ownership/header outputs;RAM payload is not securely erased.
Silent truncated input needs external reset/cancellation.

## Stage5N.4b signing hash-message interface

sign_hash_message is a standalone client verified against dilithium_services;
it is not yet instantiated in main Sign. All fields are byte-aligned.

| Opcode | Absorption bytes | Service / result |
|---|---|---|
|0 mu|tr64 ||00 ||ctx_len1 ||ctx ||M|Raw SHAKE256,64 bytes |
|1 private mask seed|K32 ||rnd32 ||mu64|Raw SHAKE256,64 bytes |
|2 challenge|mu64 ||encoded_w1|Raw SHAKE256,32/48/64 bytes at levels2/3/5 |
|3 mask nonce|mask_seed64 ||nonce_le16|Sampler mode2,256 canonical coefficients |

command_op3/param2,id16 and input fields are snapshotted. Relevant data ports:
tr/mu/mask_seed512,key/rnd256,context_len9,message_len16,nonce16. Params0/1/2
mean levels2/3/5;3 is invalid. Op0 context0..255;its total66+ctx_len+message_len
must fit65535. Other command fields are irrelevant to that opcode.
Private mask seed is FIPS204 rho-double-prime(the C rhoprime variable),not
KeyGen's different rho-prime secret-sampling seed.

Payload is ctx||M for op0 and already encoded w1 for op2. Expected w1 lengths
are768/768/1024 bytes;the formatter checks framing,not individual w1 high values.
No payload for op1/3. Payload64,index16,bytes4,last must name exact ordered
words,valid bytes1..8 with partial bytes only on the final beat. Unused high
bytes are ignored. Hash output stream input_data64/input_bytes4/index16/last
is checked in the harness;the existing service consumes data64 by declared
message length. Byte0 occupies bits7:0. request has mode1(SHAKE256),
sampling1,param2,id16,message_len16,output_len16;output_len0 means sampler route,
not a raw zero-length hash. A mask caller must set sampler job_mode2.

done_code0 means absorption completed;1 invalid command/no descriptor;
2 malformed payload with completed error drain;3 internal state error.
Done is held and means neither hash success nor service-owner release.
On code2,remaining declared bytes are replaced with zeros;the owner must
discard EVERY output and retain service ownership until raw done or sampler
status retires. Future Sign must not publish a signature from that result.
The tested harness only commits a digest cache after code0 and service retirement.
Reset cancels formatter and service together. Missing payload without an end
event waits;external cancellation must reset/drain the owning operation.

All16-bit PER-POLYNOMIAL nonces are accepted,including65535. Future vector/
retry control must ensure kappa+j does not wrap. Arbitrarily long messages,
non-byte messages,HashML-DSA prehash/OID formatting,external-mu API,w1 packing
and main Sign control are not implemented by this client. The current
descriptor limit is an explicit interface constraint,not the FIPS message limit.

## Stage5N.4a expanded secret-key decoding

process/sign_key_decode.sv implements the byte layout of final FIPS204
skDecode,with an explicit additional strict check for unused eta encodings.
It is a standalone process foundation,not yet driven by main Sign or bank DMA.

| Interface | Contract |
|---|---|
| command_valid/ready,param2,id16 |Params0/1/2=levels2/3/5;param3 completes with code1;busy through done retirement |
| input_valid/ready,data64,bytes4,index10,last1 |First byte in bits7:0;exact8 valid bytes/word;indices0..319/503/611;last only on final word |
| header_valid/ready,rho256,K256,tr512,id16 |One held header after16 accepted words;byte ranges0..31,32..63,64..127 |
| output_valid/ready,data23,id16 |Canonical coefficient modulo8380417,one accepted coefficient per handshake |
| output_section2,poly3,index8 |Sections0 s1,1 s2,2 t0;poly starts0 in each section;coefficient0..255 |
| output_last_poly,last_key |Last-poly iff index255;last-key iff last t0 polynomial's coefficient255 |
| done_valid/ready,code3,id16 |Code0 complete success;1 invalid level;2 unused eta encoding;3 word index/byte count/last or internal framing failure |

At levels2/3/5:(k,l,eta)=(4,4,2),(6,5,4),(8,7,2). Encoded key sizes
are2560/4032/4896 bytes. s1 and s2 use3/4/3 bits/coefficient with decoded
value eta-encoded;t0 uses13 bits with value4096-encoded. Negative values are
converted to canonical23-bit residues. Unused eta bit patterns are rejected
before emitting that coefficient. FIPS204 skDecode itself describes how such
malformed inputs can decode out of range;our rejection is an explicit input
validation choice,not a claim that the unchanged C unpacker rejects them.

No full-key RAM. Header outputs,coefficient outputs and done fields remain
stable under stalls. All emitted header/coefficient data is tentative until
code0;on error,the future key-memory owner must discard the ENTIRE key,
including earlier complete polynomials. Missing data alone cannot be detected
without an external end/timeout;reset cancels a truncated stream. A supplied
wrong final last flag is detected. Surplus unaccepted input can be canceled
after terminal completion. This block checks format/range,not algebraic key
consistency or side-channel security. Main external ports remain unchanged.

## Stage5N.3 checked memory-service contract

Internal request_t.sign / response_t.sign reach sign_process_dma through
the row/bank service. KeyGen drives sign='0;main external ports are unchanged.

| Field | Width | Contract |
|---|---:|---|
| valid / ready |1 each|Accept once;busy persists through completion retirement |
| op,param,kind |2 each|op0 Decompose,1 CNB,2 Mhint;params0/1/2=levels2/3/5;kind selects CNB bound |
| a,b,dest,high |6 each|Flat region descriptors;b is Mhint's retained-high source;high is Decompose's high destination |
| a_id,b_id,id |16 each|Expected source owners and result/completion owner |
| done_ready |1|Retire held completion and release client leases |
| busy,done_valid |1 each|Service ownership and completion availability |
| done_code |3|0 success,1 source/owner/address/read error,2 domain/parameter/mode mismatch,3 alias,4 invalid command,5 invalid arithmetic/high data |
| done_id,dest,high |16,6,6|Echo retained descriptors,including on error |
| done_reject,done_weight |1,9|CNB polynomial OR / Mhint polynomial weight;zero on errors/irrelevant operations |

Sources must be complete coefficient-domain objects with matching owner/level.
Initial mode is retained separately for each source and checked on later reads.
All23 stored high bits are checked against43/15/15 BEFORE6-bit narrowing.
CNB allocates/writes nothing. Decompose writes256 canonical lows and256 highs;
Mhint writes256 canonical0/1 hints. Destination metadata inherits A's mode,
requested level,coefficient domain and command ID.

No in-place signing writes. Decompose destinations differ from A and each other;
Mhint destination differs from A/B. Occupied destinations wait for release.
Sources and allocated results stay leased through held completion. Both
Decompose results remain hidden until all64 word ACKs per region and both
finish handshakes. Late errors use nonzero finish to drain/free tentative
allocations before reporting;partial reductions clear before same-ID retries.
Unexpected internal result identity/order faults are sticky until reset;
memory faults remain global. Reset cancels all metadata ownership.
Vector reduction,omega limit,retry and main Sign control remain future work.

## Stage5N.2 signing-process interface

sign_process is a focused process unit,not a new main-operation implementation.
All dilithium.sv external ports and unsupported Sign/Verify codes are unchanged.

| Input / output | Contract |
|---|---|
| input_valid/ready |Accept one group on handshake;up to4 coefficients/cycle unstalled |
| op2,param2,kind2 |op0 Decompose,1 CNB,2 Mhint;3 invalid. Params0/1/2=levels2/3/5. Kind0/1/2 selects CNB bound |
| id16,index6,last1 |Start at group0;advance exactly through63;last iff63. ID/op/param and relevant kind remain constant |
| data92,high24 |Four canonical23-bit residues;four6-bit high lanes used only by Mhint |
| output_valid/ready |One registered elastic result;all fields stable while blocked |
| output high24,low76 |Decompose result;each low lane is signed19-bit two's complement |
| hint4,lane_reject4 |Per-lane Mhint/CNB results;zero for irrelevant operations |
| reject1,weight9 |CNB prefix OR / Mhint prefix popcount within one polynomial |
| error1 |Invalid opcode/level/relevant field,noncanonical data,wrong index,last or changing packet identity |

Metadata echoes on every result,including errors. Error results carry zero
arithmetic/reduction fields and flush packet tracking. The next accepted
packet must start at0. Any error invalidates earlier tentative packet results;
the caller must not publish a partial polynomial. Completed valid packets
require all64 groups and an error-free final result. Norm rejection remains
a valid result with error=0. Reset cancels pending input/output ownership,
packet tracking and both accumulators. No command FIFO or polynomial RAM.
The caller owns vector-wide failure/hint reduction and Sign retry control.
All three operations require coefficient-domain operands;the memory DMA must
check domain/owner/parameter metadata before offering a packet. When reading
23-bit stored highs for Mhint,it must validate the full value before narrowing
to6 bits;discarding upper bits could hide an invalid source value.
See PROCESS_BLOCKS.md for formulas,bounds and the chosen Mhint convention.

Stage5N.1 preserves all dilithium.sv external ports. Its internal service
boundary is now typed by helpers/dilithium_service_pkg.sv:

| Record/group | Existing payload contract |
|---|---|
| request_t raw/job |64-bit hash input;16-bit ID/lengths;mode,param,core handshakes unchanged |
| request_t memory |Bank2,region4,word6;release and read handshakes |
| request_t NTT/process/row |Existing operation/region/owner descriptors,including seven-column row arrays |
| request_t.pack |Field opcode2,param2,ID16;coefficient23,index8,last and handshakes |
| response_t engine/memory |Tagged128-bit raw hash,92-bit bank data,metadata,status,reservations,faults |
| response_t.pack |Tagged64-bit packed word,bytes4,index7,last and held completion |

These are internal wires,not additional external pins or memory. KeyGen is
currently the only operation client;ownership includes all cleanup after done
acceptance. The services receive zero requests without an owner and retain
visible responses/faults. Sign/Verify remain unsupported.

Stage5M validates the implemented FULL_KEYGEN=1 byte format against all75
official NIST ACVP KeyGen cases at ML-DSA-44/65/87. The external32-byte seed
is the deterministic KeyGen input;this test does not test an on-chip random
number generator. See REFERENCE_VERIFICATION.md for corpus and exact results.
Stage5M left RTL/ports unchanged from Stage5L;Stage5N.1 changes only internal
ownership as described above and preserves these external ports.

## Stage5L implemented full-KeyGen interface

FULL_KEYGEN=1 enables complete encoded public/secret keys on dilithium.sv.
It automatically enables P2R,consumes internal row completions,and reserves
the bank read client for the encoder. Polynomial inspection row-valid/read-ready
are disabled in this mode. FULL_KEYGEN=0 preserves the previous diagnostic
contracts;ROUND_OUTPUTS still selects optional rounding there.

| Port | Direction / width | Meaning |
|---|---|---|
| key_valid_o / key_ready_i |out/in,1 each|One held output word;advance on handshake |
| key_data_o |out,64|First byte in bits7:0 |
| key_bytes_o |out,4|Valid low byte count;8 for supported key lengths |
| key_type_o |out,1|0 public key,1 secret key |
| key_index_o |out,10|Zero-based word index within the current key |
| key_last_o |out,1|Last word of that key |
| key_id_o |out,16|Accepted main-controller operation ID |
| done_valid_o / done_ready_i |out/in,1 each|Held overall completion after all key/hash work |
| done_code_o |out,3|0 full KeyGen success in FULL_KEYGEN mode;1 invalid level;2 unsupported operation |

| Level / final format | Public-key bytes / words | Secret-key bytes / words |
|---|---:|---:|
|2 / ML-DSA-44|1312 /164|2560 /320|
|3 / ML-DSA-65|1952 /244|4032 /504|
|5 / ML-DSA-87|2592 /324|4896 /612|

PK is rho||packed t1[0..k-1]. SK is rho||K||tr||packed s1[0..l-1]||
packed s2[0..k-1]||packed t0[0..k-1]. tr is the actual64-byte shared-Keccak
SHAKE256 output for the complete encoded PK. PK precedes SK. All field sizes
are whole64-bit words,so no partial final word occurs for these formats.

Each PK word remains owned until both output and hash consumers acknowledge
it. Independent acknowledgement bits suppress duplicate delivery to a faster
sink. Overall success waits for finite-hash retirement,all SK words and the
last polynomial packer's completion. Cleanup waits for overall completion
acceptance;new start-ready waits for all retained regions to be released.
Reset aborts the operation and invalidates pending output/hash/bank ownership.
An emitted prefix without successful overall completion is an aborted object.

keygen_encode is a shared-resource control/format client,not another hash/NTT
engine. Internal IDs wrap modulo65536:PK hash=base+1024;field pack command=
base+2048+16*section+poly. Source IDs remain the existing secret/rounded IDs.
Unexpected memory/packer/hash ownership errors set sticky fault and require
coordinated reset. Full-key tests exercise normal paths,external rejects,
stalls and resets;they are not comprehensive internal-fault/security signoff.

## Stage5K rounded arrays and polynomial bit packing

ROUND_OUTPUTS=1 enables post-sum P2R in keygen.sv/dilithium.sv. Default0
preserves the polynomial-phase contract. Row inspection still returns t at19;
rounded arrays are retained separately until overall completion acceptance.
The rounded result ID is base+768+i modulo65536 for both low/high regions.
Low values use canonical23-bit residues;high values are zero-extended10-bit.
See MEMORY_MAP.md for dimensions and lifetimes.

process/bitpkg.sv is implemented for KeyGen fields:

| Interface | Contract |
|---|---|
| Command |valid/ready;field opcode2,parameter2,ID16 |
| Field0 |t1,values0..1023,10 bits/coefficient,320 bytes/polynomial |
| Field1 |t0 low in(-4096,4096],canonical residue input;encode4096-low,13 bits,416 bytes |
| Field2 |Secret signed value[-eta,eta],canonical residue input;encode eta-s;96 bytes for eta2,128 for eta4 |
| Input |valid/ready,data23,index8,last;exactly indices0..255 and last only at255 |
| Output |valid/ready,data64,byte count4(always8 for these polynomial lengths),word index7,last,ID16 |
| Byte order |First byte in bits7:0;coefficient fields concatenated least-significant-bit first |
| Completion |held valid/code3/ID16;success only after final output word is accepted |
| Codes |0 success;1 invalid command/level;2 out-of-format coefficient;3 wrong input framing |
| Reset |Abort current packet,clear bit reservoir/index/output/completion ownership |

### Selected full-key interface (implemented in Stage5L FULL_KEYGEN mode)

The user delegated choices supporting reconstruction of LightHD's shared
controller and memory reuse,with improvements where justified. Use one tagged
64-bit output stream;retain rounded fields in the existing banks for hashing
and encoding instead of allocating encoded-key RAM. This is our compatible
interface selection,not a claim about the paper's exact external ports.

| Stream field | Width / meaning |
|---|---|
| valid / ready |1 each;hold data/tags until accepted |
| data |64 bits;byte0 in bits7:0 |
| bytes |4 bits;number of valid low bytes,8 for all current fixed key lengths |
| operation ID |16 bits;the accepted main-controller ID |
| key type |1 bit;0 public key,1 secret key |
| word index |10 bits;starts at0 for each key |
| last |1 bit;last word of that key |

Emit PK before SK. Public keys contain164/244/324 words and secret keys
320/504/612 words at levels2/3/5. A registered word with separate hash/host
acknowledgements will fork PK data exactly once to both sinks under independent
backpressure. Begin the shared finite SHAKE request after all matrix sampling,
collect64-byte tr,then serialize SK. Preserve secrets/t0/t1 until consumers
and final operation completion retire. Test abort prefixes separately from
complete valid keys. Stage5L exposes these ports with FULL_KEYGEN=1.

The packer uses one87-bit reservoir,not a polynomial or key buffer. Errors
after earlier accepted words invalidate the packet via final completion code;
a consumer must not treat a prefix as a complete valid field. The main full-key
protocol is connected in FULL_KEYGEN mode. Sign formats z/w1/hint encoding
and byte unpacking remain separate future work,not supported opcodes.

## Stage5J current controller layout and operation contract

The user requested separate memory,KeyGen,Sign,Verify and main-FSM files,with
all LightHD processing blocks under process/. Current working files:

```text
src/controller/
  memory.sv                 # Active banked ownership/packing/commit controller
  keygen.sv                 # Autonomous KeyGen polynomial phase
  dilithium.sv              # Main operation FSM;KeyGen phase connected
  process/
    power2round.sv          # Implemented combinational D=13 arithmetic
    poly_process.sv         # Shared elastic ADD/SUB/P2R stage
    poly_process_dma.sv     # Bank-to-process routing/writeback
    keygen_hash_message.sv  # Seed/nonce message formatter
  memory/                   # memory_banks.sv,poly_bram.sv
  datapath/                 # Shared Keccak/sampler/NTT/row connections
  helpers/                  # Seed collection/source,row command scheduler
  legacy/                   # Preserved scalar-pool tests and slot_memory
```

Planned concrete files,created as working RTL when their phases are implemented:
sign.sv,verify.sv;process/decompose_x4.sv,cnb.sv,mhint.sv,bitpkg.sv and required
UseHint/checking helpers. The user's LightHD labels are CNB,Decompose x4,Mhint,
Bitpkg and P2R. No empty Sign/Verify controller or nonfunctional processing
module is presented as implemented.

memory.sv now contains the former bank_poly_store implementation,module memory.
Its four-bank geometry,ports,metadata and lifecycle are unchanged. The former
scalar memory module is renamed slot_memory under legacy/,with callers/tests
updated. Other integration helpers are relocated by role;accepted Keccak/NTT/
sampler RTL stays in its original module folders.

| Main interface | Current contract |
|---|---|
| Start | valid/ready;operation2,parameter2,ID16,xi256 |
| Operation |0 = KeyGen polynomial phase;1/2(Sign/Verify) and3 return code2 unsupported |
| Parameter |0/1/2=level2/3/5=final ML-DSA-44/65/87;3 returns code1 |
| Row output |held valid/index4/region6/ID16;region19 contains256 coefficient-domain t values |
| Inspection |Existing92-bit bank read protocol,enabled during row output and overall completion |
| Completion |held valid/code3/ID16;code0 means all polynomial rows processed,not encoded keys |
| Cleanup |After completion acceptance,release retained raw s1/s2 and s1_hat before next start-ready |
| Fault |Unexpected child protocol result raises sticky fault;coordinated reset required |
| Seed |rho256,rho-prime512,K256 retained;not serialized key outputs |

The caller reads a row before accepting it;the region is consumed after
acceptance. A previously accepted read response may still be pending;cleanup
waits for its retirement. Raw secrets/transforms stay available while overall
completion is held. The main FSM remains busy during internal cleanup even
after its completion has been accepted. Reset invalidates descriptors/seed
state,not secure erasure of physical RAM payload.

## Stage5I seed-source command contract

`keygen_sample_source` is a new synthesizable adapter,connected to the banked
row subsystem by the focused seed_row test. It is not yet the full controller.

| Interface / value | Contract |
|---|---|
| Command | valid/ready;opcode2,parameter2,ID16,nonce16,row8,column8,xi256,destination6 |
| op0 | SHAKE256(xi32||byte(k)||byte(l)),128 bytes;retain rho256,rho-prime512,K256 |
| op1 | Matrix sample using retained rho||column||row;matrix mode0 |
| op2 | Secret sample using retained rho-prime||nonce_le16;secret mode1 |
| Parameter | 0/1/2 = levels2/3/5 = final ML-DSA-44/65/87;op1/2 must match retained seed |
| Destination | Caller-selected bank2/region4;existing FREE-region allocation/backpressure |
| Completion | held valid/code3/ID16;no new command until accepted |
| Codes | 0 success;1 no seed;2 retained-level mismatch;3 invalid opcode/format;4 sampler error |
| Reset | Abort coordinated subsystem;invalidate retained seed and polynomial descriptors |
| Seed replacement | Old seed validity/payload cleared on accepting op0;invalid replacement leaves no valid seed |

The existing formatter bounds matrix row<k,column<l and secret nonce<k+l.
s1 nonces0..l-1 and s2 noncesl..l+k-1 share op2;connected Stage5I tests currently
exercise s1 only. Invalid/failed seed output is zero;seed fields are not a
public-key/secret-key serialization. Low input byte occupies bits7:0.
RAW_SERVICE=1 on both banked wrappers connects the same physical Keccak;
default0 preserves old clients. Key bytes/polynomial results still await the
whole KeyGen schedule,addition of s2,rounding and encoding.

## Status and supported scope

Stage5H adds row_accumulate and keccak_sampler_row:one staged matrix row with
4/5/7 column pairs at levels2/3/5,using the existing PWM,explicit in-place ADD
and inverse NTT. Rows validate sources,retain secrets,reuse one accumulator and
scratch,then return coefficient-domain u_i=(A*s1)_i. Source/Python/C PASS:
13 completed rows,27 expected rejections,7 reset aborts,12544 exact92-bit public
reads;26 checker corruptions rejected and6 reference rows agree with schoolbook
products. Select5/row in the common launcher. No new PPA/full KeyGen claim.
Stage5I above connects the raw seed/hash helpers through the command adapter.
The next KeyGen work is autonomous scheduling,s2 addition,Power2Round and byte
encoding;the preserved Stage5H selector still drives preformatted fixtures.

Stage5G connects banked ADD/SUB/Power2Round with PROCESS_SERVICE=1 on
keccak_sampler_ntt_banks. The new poly_process_dma shares the same banks/packers
with the existing sequential sampling/NTT path. It leases sources and validates
IDs/domains/parameters,destination aliases and acknowledgements. P2R stores low
modulo q and high in two distinct regions with atomic public visibility. Source/
Python/C checks pass:23 samples,15 NTT commands,71 process commands(34 successful,
33 rejected,4 aborted),8512 exact92-bit reads. No new PPA/full KeyGen claim.
The default parameter0 and default selector4 preserve earlier tests;select
5/bank_process explicitly. MEMORY_MAP.md defines representations/status and
REFERENCE_VERIFICATION.md gives prepare/capture/compare commands.

Stage5F's keccak_sampler_ntt_banks now connects real sampling and all four NTT
operations through memory_banks. It accepts caller-selected6-bit source/result
regions and16-bit IDs;reads92-bit words as four scalar coefficients and packs
results back into64-word regions. Source leases,ID/domain/parameter/bounds checks,
explicit destination waits,write acknowledgements,held completion and reset
recovery pass.16 sample jobs/54 commands/30 results/21 rejections/3 aborts and
2944 exact92-bit reads match independent Python. See MEMORY_MAP.md for the
compute contract and REFERENCE_VERIFICATION.md for selector5/bank_ntt execution.
The default selector4 and Quartus top remain the historical scalar baseline;
the new banked controller is source-tested,not fitted or full KeyGen.

Stage5E now connects real sampling to the new banks through keccak_sampler_banks
and bank_poly_store. Caller-selected bank2/region4 names a64-word destination.
Per-context packing,write acknowledgements,publication,protected read/release,
error invalidation and reset are tested.104 jobs/88 complete/5632 exact92-bit
word readbacks PASS. This sampling-only path is preserved alongside the Stage5F
banked NTT connection;the old Stage4 top remains a scalar baseline.
See MEMORY_MAP.md for port/control details and REFERENCE_VERIFICATION.md for
the bank_store selector and independent comparison commands.

Stage5D now implements/tests the selected LightHD memory foundation:four
1024x92-bit dual-port logical banks(46KiB). User chose this organization over
the scalar-pool proposals. poly_bram.sv/memory_banks.sv pass14872 requests and
9509 exact word reads. The bank primitive owns ports,not polynomial allocation;
Stage5E adds sampling ownership/packing around it. Current all-engine main top
still uses memory.sv with four scalar slots. No new physical RAM/PPA claim.

Stage5C now tests shared finite raw-SHAKE access and seed collection. The
keccak_sampler helper has optional RAW_SERVICE=1 support;the existing Stage3/4
wrappers keep it disabled,with unchanged top-level ports and polynomial capacity.
The focused shared-service test connects it to keygen_seed_collect and the real
sampler. See ARCHITECTURE.md for ownership/routing and REFERENCE_VERIFICATION.md
for commands. Full KeyGen remains unimplemented.

**Preserved Stage5A:algorithm audit and isolated process arithmetic.** The
Quartus top remains the verified Stage4 subsystem. poly_process.sv implements
modular ADD/SUB and Power2Round;Stage5G above now connects it to the banks.
The user selected final FIPS204 bytes,
with level2/3/5 labels, on2026-10-20. Do not infer a completed KeyGen/controller.

Stage1 imported/revalidated Keccak. Stage2 now connects the real Keccak and
sampler through `src/controller/keccak_sampler.sv` on branch `integration`.
Focused source tests and independent comparison pass. The historical Stage2 main fit
reaches137.74MHz with-0.503ns setup against6.757ns;timing is open. The user
chose functionality-first integration on2026-10-20:defer Fmax/area/throughput
optimization until correct full-operation outputs. The main full-operation
controller and remaining algorithm process blocks are not implemented yet.
Stage4 connects all three engines through the four-slot memory using
src/controller/keccak_sampler_ntt.sv. NTT RTL/UVM comes from
ntt_v2:577a34b2fff19864cb16b490b7629ed211613000. Source and standalone checks pass;
no Stage4 synthesis/PPA/netlist claim. Historical standalone reports remain under
quartus/ntt/results and describe the original branch build,not this subsystem.
Stage3 now implements approved four-slot polynomial memory in memory.sv and
connects it through keccak_sampler_memory.sv.104 jobs/23180 writes and22528
stored readbacks pass independent comparison. MEMORY_MAP.md defines its API,
metadata,lifecycle and fault semantics. Stage3 synthesis is not run yet;
all fitted Stage2 numbers below refer to the earlier producer-only top.
The user selected **the same full-operation scope as LightHD**:CRYSTALS-Dilithium
KeyGen,Sign and Verify at security levels2,3 and5. Bring up level2 first,then
extend the verified controller/memory schedules to levels3 and5.

### NTT import and arithmetic contract

| Asset | Current location |
|---|---|
| Six unchanged RTL files |src/ntt/|
| Unchanged UVM and reference package |tb_uvm/tb_uvm_ntt_LightHD/|
| Three standalone launchers |sim/ntt/|
| Standalone Quartus project/helpers |quartus/ntt/|
| Python standalone reference/vectors |FIPS204_NTT/|
| Module docs |docs/ntt_docs/|
| Import provenance |ntt_import_manifest.csv;57 initial files,with path adapters identified|

NTT uses n=256,q=8380417,root1753,canonical23-bit residues. Forward output
uses the Dilithium bit-reversed odd-root ordering. INTT includes1/256 scaling;
PWM computes ordinary modular products. No Montgomery conversion is required
at these engine boundaries. The independent Python model checks direct
evaluation/inverse formulas,round trips and schoolbook negacyclic multiplication.

Compute opcodes:0=NTT,1=INTT,2=PWM,3=Pre-NTT. Sources must be committed and IDs
must match. NTT/Pre require coefficient-domain input;INTT/PWM require transform
domain. PWM source parameters must match. Pre requires every canonical value
to represent[-4,4];memory records this eligibility from all256 stored values.
Do not infer eligibility from the mode name alone. Matrix A is already in the
transform domain and can enter PWM directly. Small negative values use q-|x|.

A command locks its source(s) and reserves a distinct free destination.
Aliased PWM sources are allowed for a square;inputs are never overwritten.
No free destination means wait,with release of unrelated completed slots
allowed. Compute completion is offered only after256 results and engine done,
memory publication and source unlock. op_done_code_o:0=success,1=missing/stale
source,2=domain/parameter/Pre-ineligible. Invalid requests do not start the NTT.
Internal protocol faults halt the helper with fault_o;coordinated reset is
required. Computation is sequential with sampling;no overlap/throughput claim.

The DMA has one outstanding synchronous read and issues the next request after
the current coefficient is accepted. This favors traceability over bandwidth.
Public reads wait while the DMA owns the port;pending responses drain before
a compute command can be accepted. The same ready/valid/reset rules apply.

Relocated standalone UVM:748/748 jobs,191488 coefficients,zero errors/fatals;
32 group type mean90.4731%,raw DUT code12990/14093=92.17%. These remain
standalone NTT coverage,not integration coverage. Python18/18 cases/4608 values
PASS. Integrated source:16 sample jobs,50 compute commands,30 successes,
17 rejects,3 reset aborts,11776 readbacks;see REFERENCE_VERIFICATION.md.

### Algorithm-scope decision

#### Stage5A compatibility audit (2026-10-20)

The user selected **final FIPS204 ML-DSA-44/65/87**, retaining **level2/3/5** names
on2026-10-20. This resolves the byte-format gate. The mapping below is a naming
convention;legacy round-3 keys/signatures are not interchangeable with final
ML-DSA keys/signatures. Keep the accepted hardware architecture and implement
the final standard's seed/hash/encoding/message rules.

| Parameter port | User-facing name | Final algorithm | K | L |
|---:|---|---|---:|---:|
|0|level2|ML-DSA-44|4|4|
|1|level3|ML-DSA-65|6|5|
|2|level5|ML-DSA-87|8|7|

The following audit explains why the explicit choice was required:

| Detail | LightHD printed pseudocode | Local software snapshot / final-format candidate |
|---|---|---|
| Public-key hash tr |256 bits |TRBYTES=64 bytes|
| Challenge seed |256 bits in the displayed Sign algorithm |CTILDEBYTES=32/48/64 for modes2/3/5|
| Seed-expansion input |H(c),without explicit parameter suffix |32-byte seed followed by one-byte K,L|
| External message context |Not specified in displayed algorithms |Context/prefix supported by signing API|
| Paper reference |2023 initial public draft link |Local code has final-format features;full official-vector conformance not established here|

LightHD's printed algorithms are not a byte-exact implementation contract:
the cited draft also specifies a64-byte tr,so the citation alone cannot resolve
the32-byte value printed in the paper. A legacy round-3 choice would require
pinning its own reference and vector set. It must not reuse final ML-DSA bytes.

Primary standard:[FIPS204](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf),
Algorithms6 and35;[publication/errata page](https://csrc.nist.gov/pubs/fips/204/final),
checked2026-10-20. Local evidence:dilithium-sw-model/ref/params.h,sign.c,api.h and
packing.c;the cached LightHD text displays Algorithms1/2. The local software
was added in repository commit47a187e. File hashes are in reference_manifest.csv.
The final-standard reference was checked for the specific seed/hash/rounding
rules above;that is not complete certification of the local software.

Selected encoded lengths from the standard/local parameters:

| Set | Public key bytes | Secret key bytes | Signature bytes |
|---|---:|---:|---:|
| ML-DSA-44 |1312|2560|2420|
| ML-DSA-65 |1952|4032|3309|
| ML-DSA-87 |2592|4896|4627|

These are implementation targets,not completed RTL outputs. Pin the exact supported
interfaces and signing modes before claiming full-operation interoperability.

#### Shared process unit (independent of the byte-format choice)

src/controller/process/poly_process.sv is a one-stage elastic coefficient unit:
opcode0 ADD,1 SUB,2 Power2Round,3 invalid. ADD/SUB accept canonical23-bit a,b
and return a canonical residue. Power2Round accepts canonical a and ignores b.
With D=13,it returns high[9:0],signed low[13:0] and the13-bit packing value
4096-low. Its defining conditions are a=8192*high+low and -4096<low<=4096.
The positive tie4096 stays in the low part;4097 rounds upward. Signed low needs
14 bits because +4096 does not fit signed13 bits. This packing value is not
a complete t0 byte serializer.

Ready/valid preserves opcode,job ID16,index8 and last through stalls. Last must
match index255. Invalid opcode/noncanonical relevant operand/bad last is accepted
as an error beat with zero arithmetic outputs and preserved metadata. The future
controller must invalidate the owning job on error. This scalar unit does not
check cross-beat polynomial ordering or own slot allocations. Reset cancels its
pending output. ADD/SUB use only residue output;Power2Round uses high/low/t0.

Unit gate:10349 accepted cases,10346 exact outputs,3 reset aborts and13 expected
errors.9208 dense canonical rounding cases cover every high-part region and
each valid tie neighborhood. Python arithmetic matches the unchanged C oracle;
the C oracle separately checks all8380417 canonical Power2Round inputs against
reconstruction/range conditions. That exhaustive C check is not exhaustive RTL
simulation.12 corrupted captures are rejected. No new PPA/coverage claim.

Source:LightHD's local paper,SectionII (three security levels),SectionIII
(KeyGen/Sign and Verify sides supporting all levels),and TableIII (results for
all three). The architecture is our own implementation with the accepted
Keccak/sampler/NTT engines and the user's agreed folder structure.

Audit each implemented encoding,message-format and signing-randomness rule
against final FIPS204 before freezing full-operation vectors. LightHD labels
alone do not define final bytes. Existing component checks retain their own
documented provenance and do not establish full-operation conformance.

#### Stage5B KeyGen message formatter

src/controller/keygen_hash_message.sv snapshots a command and emits a held
SHAKE descriptor followed by little-endian64-bit absorption words. Byte0 is
bits[7:0]. Parameter encodings are unchanged. Invalid commands return a held
error/ID without issuing any SHAKE request or data.

| Opcode | Input fields used | Absorbed bytes | SHAKE | Output length descriptor |
|---:|---|---|---|---:|
|0 seed expansion|Low32 seed bytes,parameter|xi32 + byte(K) + byte(L)|256|128 bytes|
|1 matrix entry|Low32 seed bytes,row,column|rho32 + byte(column) + byte(row)|128|0 continuous|
|2 KeyGen secret|All64 seed bytes,nonce|rho-prime64 + nonce low byte + nonce high byte|256|0 continuous|
|3|Invalid|None|None|None|

Here + means byte concatenation. Matrix coordinates must satisfy row<K,column<L. Secret nonce must be below
K+L:0..L-1 for s1,and L..L+K-1 for s2. This is a KeyGen formatter,not a general
Sign mask/challenge builder. Parameter3 is rejected. Irrelevant command fields
are ignored. The last word contains the two suffix bytes and six zero bytes;
message_len tells Keccak to consume only the two valid bytes.

done means the complete message was accepted by the hash service,not that SHAKE
output finished. The service/controller must retain output ownership until hash
completion. Reset must coordinate with that service. No main-top ports change:
this formatter is tested separately and is not yet connected to the Stage4 top.
Seed-expansion bytes0..31 are rho,32..95 rho-prime,96..127 K. Stage5C now
implements collection through the optional shared raw-hash service. Main-top
connection and complete KeyGen scheduling are still required.

#### Stage5C raw service and seed collector contract

| Interface group | Contract |
|---|---|
| keccak_sampler RAW_SERVICE parameter |Default0;1 enables the additional internal client;no new hash core |
| raw_valid/ready/core |Atomic finite request;captures ID16,mode1,message_len16,output_len16 and actual assigned core |
| Raw output length |1..65535 bytes;0 does not accept a raw request;sampling still uses continuous0 |
| Shared descriptor arbitration |A valid finite raw request takes priority over sampling;one descriptor total per edge;no fairness guarantee under unlimited raw traffic |
| Absorption |Separate raw64-bit and sampling64-bit input ports;latched ingress owner selects one until that message is accepted by Keccak |
| Raw output |Tagged128-bit data,valid byte count5,core1,ID16;stable under stall;only the stated bytes are valid |
| Raw completion |Registered held core/ID;offered after all requested bytes are accepted and hash core is idle;ownership clears on its handshake |
| active_o |Both raw and sampling owners;held completion still counts as active |
| Sampling route |Existing bridge/drain/status contracts retained;raw beats never enter sampler |
| Seed start |ID16,parameter2,xi256;one outstanding seed-expansion result |
| Seed result |rho256,rho-prime512,K256,ID16,parameter2,error1;retained under ready/valid |
| Seed rejection |Parameter3 returns zero fields/error;no raw request |
| Reset |Coordinate helper,collector and clients;cancel raw/sampling ownership and pending results |

The service is finite raw SHAKE,not a new SHA3 fixed-digest mode. A caller must
not issue raw output_len0 expecting a stop interface. Hash rate boundaries may
produce a short beat before another permutation;valid byte count,not fixed16,
advances the byte offset. Seed128 output fits within one SHAKE256 rate block.

See [DILITHIUM_PLAN.md](DILITHIUM_PLAN.md) for the common roadmap. All integration
milestones update this universal documentation set.

## Imported source provenance

| Component | Source | Destination | Changes |
|---|---|---|---|
| Sampler | sampler_v1 accepted Stage4.9r; Stage5 commit e1b9c84 | src/sampler, existing tb_uvm/sim/quartus/sampler assets | None during Keccak import |
| Keccak | keccak_v2 at fe54a782e3df9ed684dc960b0067b39ce323289d | src/keccak; tb_uvm/tb_uvm_keccak_v2 | RTL/UVM identical at import;later Stage2 control changes are described below and preserved in their own evidence |
| Keccak simulation | Same commit, sim/ | sim/keccak/ | Launcher discovery, root/RTL/project paths and Python defaults relocated; main run sets local working directory |
| Keccak synthesis | Same commit, quartus/dual_interleaved/ | quartus/keccak/ | QSF source paths only; original settings/SDC preserved |
| Keccak vectors/docs | Same commit, NIST/ and docs/keccak_docs/ | Same paths | Original published vector files and historical module documentation preserved |
| NTT | ntt_v2 at577a34b2fff19864cb16b490b7629ed211613000 | src/ntt,tb_uvm/tb_uvm_ntt_LightHD,sim/ntt,quartus/ntt,FIPS204_NTT,docs/ntt_docs | Six RTL files and16 SV testbench/reference files identical;57 imported assets with path adapters recorded in ntt_import_manifest.csv |

Imports used create-only writes and included no historical experiment trees,
generated synthesis databases or shared-template overwrite. Standalone test
tops named `tb_top` stay in separate simulator work libraries; the eventual
full-design testbench must not compile all standalone tops into one library.

## Current engine contracts

| Interface | Existing behavior | Integration obligation |
|---|---|---|
| Keccak request | ready/valid; actual assigned core on request_core_o; 1-bit SHAKE128/256 mode; 16-bit message/XOF byte lengths | Capture the actual core on acceptance and reserve its descriptor/destination |
| Keccak absorption | Shared64-bit ready/valid stream; message length controls final valid bytes | Feed exactly the specified message in little-endian byte order; retain descriptor while feeding |
| Keccak output | Shared128-bit ready/valid,5-bit valid-byte count and1-bit core tag | Preserve data/bytes/tag while stalled and bind each core to the correct sampler job |
| Keccak continuous mode | output_len_i=0; stop_i sampled in SQUEEZE | Manage stop, outstanding output and busy/done before reuse; do not treat a rate-block boundary as stream end |
| Sampler job | ready/valid; core1 bit,ID16 bits,mode2 bits,param2 bits | Establish matching context before accepting that Keccak stream |
| Sampler input |128-bit ready/valid,1..16 contiguous low valid bytes,core tag,last | Pass actual valid bytes; continuous SHAKE input_last stays0; bounded end needs explicit controller accounting |
| Sampler output |23-bit canonical residue,core/ID/index/last; one accepted coefficient per clock | Route by job to the correct destination; output alone does not identify memory ownership lifetime |
| Sampler completion | source_stop_o per context and checked status; success after256 outputs | Stop/dispose upstream surplus,handle error/abort and invalidate partial destinations |

The sampler's internal64-bit chunk issue remains unchanged. No native128
sampling or integrated throughput claim follows from this connection plan.
Matrix A uses SHAKE128; secret/mask/challenge expansion uses SHAKE256. Their
seed/nonce/message constructions must match the chosen algorithm/version.
Derive the Keccak mode explicitly from the sampling operation:the sampler's
2-bit mode encoding must not be truncated and wired to the1-bit SHAKE selector.

## Implemented stop/drain and context reuse

Source inspection found that Keccak stop can suppress a core's output-valid,
while the wrapper retains a selected output under backpressure. Therefore the
future adapter must not simply wire sampler source_stop directly to Keccak stop
and assume all outstanding offers disappear safely.

The Stage2 helper implements a shared two-slot registered-credit queue plus per-context
ownership/drain/stop flags. It accepts/discards surplus to release the wrapper
lock,then registers stop and waits for Keccak idle before exposing completion.
Focused tests check this sequence,held output stability and same-ID reset/reuse.
Do not reuse a context until both sampler ownership and Keccak/adapter tokens
from the old job are retired. See ARCHITECTURE.md for the exact contract.

## Clock/reset and pending major decisions

Keccak uses an active-high asynchronous control reset; sampler reset is
active-high synchronous. Start with a common clock and coordinated top-level
reset,then test release/cancellation semantics explicitly. FPGA reset input
conditioning belongs to the top-level design when specified.

Standalone Keccak constraint:6.757ns. Standalone sampler constraint:6.500ns.
The user explicitly selected about148MHz as the initial combined target:
quartus/dilithium/dilithium.sdc uses6.757ns. Do not relax it to conceal a miss.
Final FIPS204 version/format is selected with level2/3/5 labels. Signing modes,
external message interfaces/key delivery still need specification. Expanded
memory is selected as LightHD's four1024x92-bit banks;its foundation is tested
and the initial four-slot pool remains the current connected baseline. Full fitted timing is measured
separately from the6.757ns functional simulation clock.

Keccak message/XOF length fields are16 bits. The current fixed-length command
therefore represents at most65535 input bytes;continuous XOF uses output_len=0.
Do not advertise unrestricted full-operation message lengths without specifying
and testing the hashing interface. Supporting longer streamed messages would
require a deliberate interface/controller decision;hashing separate chunks as
independent SHAKE requests would not implement one continued hash operation.

## Stage1 relocation verification — 2026-10-19

| Check | Observed result |
|---|---|
| Source identity | All12 RTL and13 UVM files byte-identical to the selected Keccak commit |
| Existing sampler | No source/UVM/Quartus changes during this import |
| Full Keccak source regression | COMPLETE_KECCAK_SUITE_PASS:904 two-core UVM transactions plus all dual-interleaved regressions |
| Source/NIST UVM errors and fatals | Zero in both runs |
| Published NIST suite |3182 cases from six short/long/variable-output files;both standalone cores captured |
| Separate Python byte comparison |6364/6364 outputs match published expected values;3182/3182 per core |
| Standalone Quartus compile | Full compilation successful with original RTL/settings and relocated source paths |
| RTL package/module names | No collisions with the current sampler source set |

The NIST flow compares published bytes directly;it does not generate expected
SHAKE outputs from the DUT or reuse the SV golden model. Capture completion
alone is not the verdict. The full wrapper regressions check dispatch/routing/
interleaving separately from the published-vector standalone-core capture.

### Fresh standalone Keccak implementation

| Metric | Measured value |
|---|---:|
| Device | Cyclone V 5CGXFC7C7F23C8 |
| Tool | Quartus25.1std Lite |
| Actual placed ALMs |8058|
| Registers |3501|
| Combinational ALUTs |11860|
| M10K / DSP |0 /0|
| Clock period |6.757ns|
| Slow85 / Slow0 Fmax |149.63 /152.88MHz|
| Worst setup / hold |+0.074 /+0.166ns|
| Setup/hold TNS |0 at all four corners|
| Minimum pulse-width slack |Positive at all four corners;minimum+2.442ns|

Area uses the report row **[A] ALMs used in final placement**. Historical7581
figures in imported module docs refer to the needed estimate in this reproduced
fit. The current area record is8058 placed ALMs. RTL/UVM and synthesis settings
are unchanged;do not interpret this reporting correction as added integration
logic or a source redesign. Data pins remain virtual with the inherited I/O
exceptions;these results establish standalone internal timing only.

### Reproduce and inspect

From repository root:`python sim/keccak/nist_shake.py prepare`.
From sim/ in fresh Questa sessions,run `do keccak/run.do` for the full source
regression and `do keccak/run_nist.do` for the NIST capture. Then run
`python sim/keccak/nist_shake.py compare` from repository root.
Open `quartus/keccak/keccak_dual_interleaved.qpf` and start full compilation in
Quartus GUI. Scripts and README files contain the relocated paths.

Live reports:sim/keccak/import_uvm.log,import_nist.log,import_nist_compare.log;
quartus/keccak/import_compile.log and output_files/*.fit.rpt/*.sta.rpt/*.sta.summary.
Frozen milestone evidence:evidence/keccak_import.zip with SHA256 sidecar;
the archive includes the source/destination hash manifest and selected reports.

No relocated post-synthesis/post-fit simulation or connected-system result is
claimed. Standalone netlist launchers are imported for later use with fresh
exports. The next work is Stage2 adapter design and seeded polynomial checking.

## Stage2 connected subsystem results

The implemented helper is controller/keccak_sampler.sv;the full main controller
and polynomial memory remain future work. Focused source/Python checking passes
104 jobs:88 complete,8 expected parameter errors,8 reset aborts,23089 values
(22528 complete-polynomial values+561 aborted-prefix values). All24 mode/param/
actual-core combinations are observed,and12 deliberate checker faults rejected.
All four reset targets reach both owned contexts. See REFERENCE_VERIFICATION.md
and INTEGRATION_VERIFICATION_TESTPLAN.md for exact stimuli and limits.

Initial combined implementation:11059 actual placed ALMs,7396 registers,16025
ALUTs,one M10K,zero DSP. Worst Fmax129.18MHz,setup?0.984ns and hold+0.166ns at
unchanged6.757ns. The148MHz target is not closed. Original sampler structural
register guards pass. Critical path:Keccak core1 absorb_block_full?state_array.
Details and negative setup TNS are in THROUGHPUT.md. Do not describe compile
success as timing closure or use standalone module coverage as system coverage.

Stage2 initial evidence:evidence/stage2_subsystem_initial.zip+SHA256. The archive records the
functional PASS and timing miss separately. No integrated netlist simulation,
full-operation NIST comparison,full UVM,FPGA or security signoff is claimed.
The earlier timing-first choice was superseded on2026-10-20:proceed to memory
for functionality,then optimize after full-operation output verification.
The first trial of Keccak-scoped retiming and physical-synthesis settings
reproduced the timing miss exactly;sampler original register guards passed.
Trial2 lane-qualified absorb writes pass104 focused jobs/23081 values,904 UVM
transactions plus dual suites,and6364 published NIST outputs,but worsen timing
to125.20MHz/-1.230ns and area to11758 placed ALMs. It is rejected.
Trial3 dedicated global enable routing also fails:93.59MHz/-3.928ns and11256
placed ALMs;it is rejected despite passing source/NIST/register checks.
Trial4 disables clock-enable inference only on the two original Keccak state
arrays. It reaches130.79MHz/-0.889ns at12366 placed ALMs;timing remains open.
Trial5 additionally registers the launch-offset-zero decision,with no
changed launch gap or job cycles.104 focused jobs/23081 values and12 checker
faults pass;all104 cycle witness rows are unchanged. Full904-transaction Keccak
regression plus dual suites pass,but the fit still misses at129.27MHz/-0.979ns.
Trial6 adds the two-slot registered-credit bridge to cut sampler-to-hash
ready/stop paths.104 jobs/23089 values and12 checker faults pass,including full
queue/reset/parallel push-pop witnesses. Its clean fit reaches134.17MHz/-0.696ns
at12542 placed ALMs;all structural guards pass. The queue payload uses registers,
with no added block RAM. Active trial7 restores ordinary clock-enable mapping
and predecodes absorb-ready per core.104-job checking and904-transaction Keccak
regression plus dual suites pass;all104 job-cycle rows match trial6 exactly.
Fresh6364-output NIST comparison passes. Trial7 fit:11204 placed ALMs,
124.72MHz/-1.261ns setup;all guards pass. Active trial8 removes a command-ready
condition redundant with ownership,with source assertions checking the
equivalence.104 jobs/23089 values and12 checker faults pass;all104 cycle rows
match trial7. Both seed1/seed2 compiles finished;the main seed1 result is11293
placed ALMs,137.74MHz worst Fmax,-0.503ns setup and+0.157ns hold,with all
structural guards passing. Seed2 is not selected. Further PPA work is deferred.
See THROUGHPUT.md for the measured trial history.
The original imported Keccak source remains in the immutable import archive;
standalone PPA above refers to that prior source,not this experimental change.
The user subsequently approved the four-slot pool;Stage3 source verification
passes. Larger capacity/parallel banking remains a later architectural decision.
