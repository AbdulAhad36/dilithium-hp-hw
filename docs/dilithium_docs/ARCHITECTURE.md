# Dilithium architecture

C14 replaces private Sign/Verify hint encoders/decoders with one codec inside
shared Process DMA:704 suffix bits and two shared index-word read ports.
MHint connects directly;controllers provide phase/row/host-stream controls.
Process port assignment uses direct phase equations with all bounds/format
checks retained. Full210/protocol88/UVM33/negative and physical guards pass.
Actual31,882 placed ALMs/56.72MHz is an area/timing tradeoff versus C12's
33,056/57.38. No operation cycles change. Performance targets and remaining
controller/memory reconstruction are open. C15's direct-memory prototype
remains outside this qualified source snapshot until separately connected.

C11R1 reuses KeyGen xi/rho-prime/tr lifetimes in one1024-bit workspace and
one64-bit read selector. Sign/Verify formatters read retained owner fields
under a checked stability contract;generic snapshot mode remains available.
Encoding/control arithmetic is narrowed or uses exact fixed shifts/adds.
Full source/routed gates pass at33066 placed ALMs/57.57MHz. The below20000
and148MHz targets remain open. The user rejected shared controller-context
RAM/one formatter. C12 instead corrects the published butterfly and compact
decoder structure. Its qualified whole-main result is33056 placed ALMs/
57.38MHz;area is effectively unchanged and Fmax falls0.33%. Performance
targets remain open. All public operations and measured cycles are retained.

## Current compact control boundary

`dilithium_fpga` selects `dilithium`:three operation FSMs share one
physical hash/sampler/NTT/Process set and four coefficient banks. C11R1 passes
210 official commands,88 protocol commands and main33 UVM/negative. Controller
workspace reuse and exact arithmetic reduce placement to33066 ALMs;worst
reported Fmax57.57MHz. Setup remains open at148MHz and the below20000 area
target is unachieved. Engine mathematics and public streams are fixed.

```mermaid
flowchart LR
  READ["A/B read reports<br/>plus cached completed reads"] --> REDUCE["All source reads complete"]
  REDUCE --> ARM["C10 read_release_r<br/>1 registered decision"]
  ARM --> CMD["Renewal command<br/>and read retirement readiness"]
  CMD --> ROUTE["Round-robin router<br/>16 owner bits<br/>8 deferred-retirement bits"]
  ROUTE --> ADMIT["Captured descriptor<br/>one ADMIT validation clock"]
  ADMIT --> RAM["RUN on physical A/B ports<br/>4 banks x1024 x92 bits"]
  RAM --> FINAL["All result writes complete"]
  FINAL --> FIN["C10 finish_ready_r<br/>1 registered decision"]
  FIN --> DONE["Retire result lanes<br/>report NTT completion"]
```

The registered decisions break the measured ownership-to-completion-to-
arbitration feedback path. They do not change the NTT core's arithmetic or
pipeline. Deferred retirement prevents a losing renewal from releasing its
physical lane;the client sees the old completion once. All20 new control bits
are retained in the C10 fit. The new worst path is RAM-to-Process arithmetic;
these control changes alone do not close148MHz timing.

## Stage7C replacement under construction

`controller/keygen.sv` is the first compact operation controller;
`datapath/datapath.sv` owns one physical engine set. Controllers send
scalar phase/address commands defined in `helpers/dilithium_pkg.sv`. They do
not adopt leases or copy per-helper polynomial-handle arrays. The shared compact main passes210 official and88 protocol commands at the
frozen7C.4 checkpoint. Production selection now points to this hierarchy;
fresh production210/protocol88/main UVM33 and routed7C.7 qualification pass.
The memory feedback loop is removed;148MHz setup remains open. Historical
7B.9 PPA is not a measurement of this replacement.

```mermaid
flowchart TB
  KG["Compact KeyGen FSM<br/>producer:two descriptors<br/>consumer:one row accumulator"]
  SIGN["Compact Sign FSM<br/>cached secret transforms<br/>one rejection loop;row-local work"]
  FUTURE["Compact Verify / main<br/>one operation owner;row-local equation"]
  HASH["hash_sampler<br/>same dual Keccak + sampler<br/>raw SHAKE shares both cores"]
  REGROUP["Fig5 secret regroup<br/>16 signed nibbles per packet"]
  NTT["ntt_dma<br/>one4-BU /3-FIFO NTT<br/>streamed first stage / fused MAC"]
  PROC["process_dma<br/>shared x4 Process + one BitPkg<br/>packed RAM or64-bit output"]
  LOAD["Shared BitUnpkg/manual input route<br/>same sampler writer + secret regroup"]
  HINT["Bounded sparse hint suffix<br/>ordered indices + row counts"]
  ROUTER["memory_router<br/>8 physical lane owners<br/>round-robin atomic command admission"]
  RAM["ONE physical coefficient array<br/>4 x1024 words x92 bits<br/>independent A/B bank-port FSMs"]
  KG --> HASH
  KG --> NTT
  KG --> PROC
  SIGN --> HASH
  SIGN --> NTT
  SIGN --> PROC
  SIGN --> LOAD
  LOAD --> Q["Two validated decoded packets<br/>92-bit payload each<br/>admit/commit counters and reset ownership"]
  Q -->|"secret packets through same writer"| REGROUP
  Q -->|"canonical packets through same writer"| ROUTER
  PROC -->|"four MHint flags/word"| HINT
  FUTURE -. shared requests .-> HASH
  HASH --> REGROUP
  REGROUP -->|"tagged B-port words"| ROUTER
  HASH -->|"other modes:4 x23-bit words"| ROUTER
  NTT <-->|"A/B bank streams"| ROUTER
  PROC <-->|"packed word streams"| ROUTER
  KG <-->|"encoded PK read / hash / host fork"| ROUTER
  ROUTER <--> RAM
```

Sampler writes from both hash contexts share port B even when they alternate
polynomials in one bank. The producer supplies each accepted word's address.
NTT reserves output lanes before starting when the output bank differs from
its source. For an in-place transform,the same owner atomically renews its
finished read bursts as write bursts. Other clients cannot take those lanes
in the gap before the non-stallable final NTT stage.

KeyGen keeps raw compact secrets for the final SK stream and caches s1hat in
the fixed transform bank. It samples A and s2 in bounded batches,uses at most
nine A slots,and completes each MAC row,INTT,secret addition and P2R before
reusing scratch. Packed t1 is stored above the A ring in the same BRAM4 so
the approved full PK/SK streams and final FIPS tr64 need no extra key RAM.

`sign.sv` now consumes the approved SK then ctx||M frames through
that same datapath. It retains the128-byte SK header in `sign_input`,
transforms s1/s2/t0 once, and keeps those fixed bank roles through all retries.
Each attempt samples y and A in bounded producer batches, transforms y early,
and uses one row accumulator. After row-local INTT/Decompose, packed w1 is
hashed with mu. The A phase retires before its bank becomes z/chat/r0 storage.
The same Process pipeline checks z/r0/ct0 and generates hints; the same BitPkg
streams z after ctilde, followed by the bounded sparse suffix. Public completion
waits for the physical services and suffix formatter to retire. All90 official
signatures and69 protocol commands pass, with62 comparator faults rejected.
These are the frozen7C.3 results. Production now selects the compact shared
main and passes its fresh operation/protocol/UVM gates;physical fitting is
in progress,so no new whole-design area/timing is claimed here.

### Compact Verify and shared main candidate

`verify.sv` now passes45 official verdicts (9 valid/36 invalid) and
35 independent equation digests at its preserved initial checkpoint:
`evidence/stage7c4_verify_official_initial.zip`, SHA256
`4ccad7b198fe7130c26583c414c07b934a2c904e05851f56ea0c9c1baf17aae2`.
It caches transformed z/t1 and chat in fixed banks, samples A in a bounded
ring while transforms run, and finishes one equation row before reusing
its accumulator/scratch. One shared UseHint/BitPkg writes packed w1, which
the same SHAKE service hashes with mu. There are no per-helper leases or
copied polynomial-handle contexts.

`dilithium.sv` is the candidate main controller. Its51 port groups
match the approved production boundary. A five-state owner FSM selects
KeyGen, Sign or Verify requests into ONE physical `datapath`; the
selected child latches command inputs directly at the public handshake.
The main adds no copies of seeds or wide contexts. Busy and held-completion
states block new commands, and ownership retires before the next start.
The mixed diagnostic9,protocol88 and all210 interleaved official operations
pass,with744280 exact published key/signature bytes and35 independent Verify
equation digests. Protocol88 exercises29 errors,3 normal invalids,12 resets,
44 cross-operation recoveries and44 blocked busy probes. Checkers reject90/90
corruptions. This qualified the7C.4 candidate core. The7C.5 production wrapper
now selects it;fresh210/88 and main UVM33 pass with real fixed-port ownership
observations. Routed7C.7 has34302 actual placed ALMs and no combinational
loop,but setup remains-12.556ns at the unchanged6.757ns constraint.

## Historical Stage7B.9 production boundary

`controller/dilithium_fpga.sv` is the main synthesis and main-UVM top. It wraps
the existing `dilithium` core with full KeyGen, Sign and Verify enabled. All
74 earlier RTL files are unchanged from Stage7B.7. The wrapper adds no state,
arithmetic, memory or pipeline stage.

```mermaid
flowchart TB
    host["Host: commands, streamed input, output backpressure"]
    top["dilithium_fpga\n51 signal groups / 1027 bits including clock"]
    main["dilithium core\nKeyGen / Sign / Verify controllers"]
    service["Shared services and arbitration"]
    engines["Dual Keccak / sampler / NTT / process blocks"]
    memory["Four coefficient banks\n64 polynomial regions + metadata"]
    monitor["Verification-only internal probes\nownership, occupancy and legacy-path guards"]
    host --> top
    top --> main
    main --> service
    service --> engines
    service <--> memory
    main -. read-only observation .-> monitor
    memory -. read-only observation .-> monitor
```

The production boundary exposes command/data/status ports. Raw seed, legacy
row/read and pool-occupancy outputs remain inside the original core. The
unused legacy read request is tied inactive; its response and row sinks are
tied ready. Main UVM drives the actual production interface and observes
internal status without driving a second debug interface. Existing focused
benches can still instantiate the original core for debug verification.

There are 751 input bits including clock and 276 output bits; all 1026
nonclock bits are virtual in the current Quartus project. These counts are
interface geometry, not area estimates or a board pin assignment. Main33 and
the current-token negative pass;all30 latency records equal7B.7. The fresh
full compile routes at51162 actual placed ALMs,but the6.757ns setup target
fails. THROUGHPUT.md records the four-corner measurements and the Verify
arithmetic/packing critical path. Earlier failed-route counts are not current PPA.

## Stage5V.4 one main owner for Verify

`controller/verify.sv` sequences the existing three helpers. Main op2 grants
it the physical services tree for the entire request,including handoffs and
cleanup. The main mux now selects exactly one KeyGen,Sign or Verify client;
debug reads are blocked while Sign/Verify owns it. A held completion blocks
new starts. KeyGen's existing post-ack cleanup also retains ownership.
The separate Verify input group carries the approved PK/SIG/body frames;
no new RAM or arithmetic engine is added. FULL_KEYGEN=1 selects complete
KeyGen;both ENABLE_SIGN/ENABLE_VERIFY default1. No synthesis top,clock target
or accepted engine implementation is changed by this functional gate.

## Stage5V.3 equation component

`verify_equation` is a new services client after real raw/math preparation.
The owner expands one A row with the existing sampler,uses shared PWM and
in-place ADD/SUB in NTT domain,then one inverse NTT per row. Shared memory
retains W rows while UseHint reads W/h pairs and feeds the existing Bitpkg
and hash formatter. Recomputed c2 is compared with received ctilde;all adopted
and temporary leases are released before completion. Only scalar UseHint is
new arithmetic;NTT,matrix sampling,process DMA,packing and SHAKE are reused.
Main op2 is not yet connected. See universal reference/memory docs.

## Stage5V.2b Verify math owner

The first-two-frame owner and math owner share ONE physical services tree.
An atomic context take transfers all raw handles and header snapshots. The
math client reuses sign_hash_message op0 to format pure-message mu,then uses
the shared raw Keccak service for its64-byte digest. It samples c from the
received ctilde through the shared challenge sampler. Shared FNTT transforms
t1<<13 and z;the existing Pre-NTT transforms small c. Hints remain untransformed.

One free scratch region rotates through source releases;result ownership is
published only after all transforms retire. It contains13/18/24 regions plus
rho,mu and ctilde. Pre-adoption errors preserve the old owner;later errors
clean every adopted/new region. Foreign leases survive. Pending reads block
clear/take. Fatal raw/service violations halt until reset.

All70 existing RTL modules remain unchanged;one control module makes71 total.
The same four banks,engines,synthesis top and6.757ns SDC remain. This is a
focused source-level preparation gate,not main Verify arithmetic or a PPA run.

## Stage5V.2a shared Verify front end

The new verify_input_prepare helper connects the existing Verify decoder to
the real four-bank memory and real shared Keccak engines. The existing load
service selects SK or Verify mode;it uses one existing scalar memory writer.
The PK stream forks through one64-bit elastic word into decoding and SHAKE256.
The two sink credits are independent;paired descriptors prevent split start.
Signature loading follows complete PK/hash retirement. Successful context owns
K t1<<13,L z and K dense-hint regions plus rho,tr,ctilde header registers.
It transfers or clears all regions together;pending reads preserve ownership.
Error cleanup drains finite raw hashing and preserves unrelated bank regions.

This is a first-two-frame helper,not the main Verify controller. ctx||M,mu,
SampleInBall/NTT preparation and the Verify equation follow in5V.2b/5V.3.
Main op2 is still unsupported. Existing services,engines,memory geometry,main
host ports,synthesis top and6.757ns SDC remain;no new PPA claim is made.

## Stage5V.1 Verify decoding component

Approved host ordering is PK -> signature -> ctx||M. The new verify_decode
component decodes a PK/signature frame with bounded reservoir/suffix storage.
It is not connected to main op2 or the shared bank writer yet. All67 prior RTL
files remain unchanged;the new module makes68 RTL files. The Quartus source
list includes it,but the selected synthesis top and6.757ns SDC are unchanged.
No new synthesis or full-main timing claim is made.

The next client will own decoded t1/z/h and PK hashing in the existing pool.
UseHint,Az-c*(2^13*t1),inverse NTT,packed-w1 hash and challenge comparison then
complete the Verify arithmetic before main dispatch. The same services tree
will remain exclusive to the active operation.

Stage5N.4h.7 adds official Sign vectors to the existing main-top verification
flow. All67 RTL files remain byte-identical to the4h.6 checkpoint;the ownership,
engines and memory architecture below are unchanged. The selected pure public
Sign cases use the existing interface. REFERENCE_VERIFICATION.md records the
scope and results;unsupported ACVP APIs are not extra implemented hardware.

## Stage5N.4h.6 main KeyGen/Sign ownership

The main FSM now has KeyGen and Sign dispatch/result states. Default
ENABLE_SIGN1 instantiates one Sign control client;legacy KeyGen-only tests
explicitly select0. Main start readiness waits for both clients and physical
services to be idle. The owner mux includes child cleanup,even if the main FSM
has already returned to IDLE after KeyGen completion. Both owners cannot be
active together. Sign suppresses external debug-read handshakes/responses.

The new Sign client grants its key preparer,attempt loop or encoder exclusive
services access in order. It reloads and frees the key per approved request.
No new bank or crypto engine;the same SHAKE,sampler,NTT,process and Bitpkg
hardware serves both operations. Main op2 Verify remains unsupported. The
Quartus source list includes Sign;its selected synthesis top/6.757ns constraint
are unchanged and no whole-main synthesis claim is made here.

## Stage5N.4h.5 accepted attempt to encoded signature

Attempt READY -> atomic take -> sign_signature_encode -> existing bank read
port/shared Bitpkg ->64-bit signature stream -> release adopted regions ->held
completion. No new bank,arithmetic engine,signature RAM or duplicate packer.
Z extends Bitpkg to op4 with a3-bit op port;old operations and87-bit reservoir
remain. The encoder stores descriptor/digest,a read cache,a hint word and counts.
The outer scheduler retains the key and exclusive service lease. Output is
provisional until code0. Main Sign host dispatch and main Verify remain open.

## Stage5N.4h.4 one shared attempt loop

sign_attempt_loop instantiates control clients for the six previously verified
attempt stages. A request mux grants one client the same services tree at a
time;ownership transfers still occur atomically between retained clients.
The parent holds the prepared-key lease across all stages and retries. It
rehashes mu/private seed only for the initial pass;retries select the mask
helper's existing seed-to-ExpandMask path. A17-bit nonce and18-bit bound check
prevent wrap. Reverse-order clear handles ordinary failures. No new hash,
sampler,NTT,arithmetic engine,bank or polynomial/message RAM is introduced.
This functionality-first schedule resamples A each attempt. Main Sign host
dispatch and signature encoding remain later;no new PPA claim is implied.

## Stage5N.4h.3 shared norm/hint checks

New sign_attempt_check adopts the products context and sequences the existing
sign-process DMA(CNB then Mhint) and scalar in-place ADD. One rotating hint
address is sufficient;there is no polynomial copy or additional processing
engine. Products releases ownership before any destructive update. The new
owner retains key leases and headers across service gaps,held done and READY.
Normal algorithmic rejection frees the complete attempt but retains private
retry headers. Hardware errors are a separate completion category. This
focused connected helper is not yet the main Sign controller or retry loop.

## Stage5N.4h.2 shared response arithmetic

sign_response_products adopts the mask and transformed-challenge contexts
together. It retains mu/private-seed/ctilde metadata and uses existing PWM,
INTT and in-place ADD/SUB clients sequentially. Two scratch handles are reused;
the ct0 vector stays in existing banks. Key context is retained,raw y becomes
z,and w0 becomes r0. w1 is unchanged. No new physical arithmetic or payload
RAM is instantiated. Result handoff preserves headers for the future retry
controller;this phase does not make norm/hint/signature decisions.

## Stage5N.4h.1 ownership transfer and challenge transform

The matrix and challenge clients can now relinquish their retained contexts
through take_valid/ready. sign_challenge_transform joins both transfers on
one edge,then owns yhat,w0,w1,c. No physical data moves at that edge. It frees
dead yhat,uses existing FNTT for c,waits for complete storage and child
retirement,and frees raw c. It retains w0/w1/chat and ctilde for secret products.
Key/raw y stay protected by the outer owner. Clear or another whole-context
take ends the new retained lifetime. The existing banks and service records
are unchanged. No new physical engines or payload RAM are instantiated.

## Stage5N.4g retained w1 to challenge

sign_challenge_prepare is a control client of the same physical services.
It reads each retained w1 row through the packed92-bit port,feeds the four
23-bit lanes sequentially into shared Bitpkg op3,and forwards packed words
to the existing sign_hash_message challenge formatter. SHAKE256 hashes
mu64 || encoded_w1. Its actual32/48/64 digest bytes become the input to
the same shared SampleInBall path;the resulting c occupies one free region.
No duplicate packer,hash engine,sampler,polynomial RAM or encoded-w1 RAM is
added. One92-bit read cache and512-bit digest register bridge the services.

The outer owner preserves the prepared key,y and matrix result leases.
Whole-result publication waits for hash and sampler retirement and complete
storage. Normal errors drain current packing/hash work and discard its
diagnostic digest;clear releases only c. Physical/context faults require
global reset. Main Sign and retry scheduling remain unfinished.

## Stage5N.4f connected signing-attempt arithmetic client

The focused harness selects sign_key_prepare,sign_mask_prepare and the new
sign_matrix_prepare around the same dilithium_services instance. The outer
operation owner retains both key/mask contexts and excludes unrelated host
commands across each child handoff. This is not yet the main Sign controller.

sign_matrix_prepare allocates a descriptor plan from free existing regions,
then schedules ordinary FNTT(y),one reusable sampled A row,the existing row
PWM/ADD/INTT client,and the existing x4 decomposition DMA. yhat,w0,w1 remain
private until the entire vector completes. All new payloads use existing
banks;only rho/handles/ownership/FSM registers are added. Row temporaries are
released between rows;original coefficient-domain y stays with the mask owner.
Normal failures roll back all new workspace,including earlier completed rows.

The decomposition source stays hidden through its done retirement. Parent
whole-plan checks therefore distinguish a source lease from an incomplete
physical write and wait until that lease retires. Fatal faults require global
reset;normal errors preserve key/y for subsequent work. Full signature/retry/
Verify,main host routing and PPA improvement remain later stages.

## Stage5N.4d retained signing-key preparation client

New helpers/sign_key_prepare.sv is a working control-only client of the same
dilithium_services instance. It is tested at the operation-owner boundary;
it does not add another engine/memory tree or enable unfinished main Sign.
All57 previous RTL files are unchanged. The future Sign owner selects this
client while service_active is high,then other signing clients while the
validated key context remains retained in READY.

```mermaid
flowchart LR
  IN["Expanded SK64-bit stream<br/>level /ID /base /scratch"] --> PREP["sign_key_prepare<br/>control +retained key context"]
  PREP --> LOAD["Existing shared load service<br/>whole-key validation"]
  LOAD --> MEM["One existing four-bank memory<br/>raw s1,s2,t0"]
  PREP --> NTT["One existing shared NTT engine<br/>Pre for s1/s2,FNTT for t0"]
  MEM --> NTT
  NTT --> WORK["One free scratch region"]
  WORK --> MOVE["Validate done /publish handle<br/>release old source<br/>old source becomes next scratch"]
  MOVE --> PREP
  PREP --> CTX["Validated rho,K,tr +level,ID<br/>23 x6-bit handles +region mask"]
  CTX --> SIGN["Future Sign hash/vector clients<br/>same shared services"]
```

One spare region rotates through freed raw-source locations. Peak key storage
is N+1 regions;steady prepared-key storage is N,where N=12/17/23. Header
retention adds1024 bits and metadata,not encoded-key or polynomial RAM.
The outer operation owner blocks unrelated host access between child jobs
and throughout retained context. complete from the underlying services is
not a public key-valid indication. Normal errors drain child status and clean
all owned raw/transformed regions before done;physical faults halt the owner
until global reset. An explicit clear invalidates context and releases it.

## Stage5N.4c2 production key-loader connection

The existing main-owned dilithium_services now exposes a nested load request/
response record. It routes through the row wrapper to sign_key_load in the
existing bank arbiter. The same memory allocator,scalar packer and four banks
serve sampling,NTT,process operations and decoded-key writes. No second engine
or RAM tree is added. KeyGen explicitly drives load='0;main Sign/Verify remain
unsupported until their control schedules are implemented.

```mermaid
flowchart LR
  CLIENT["KeyGen / future Sign owner"] --> REC["Single services request/response<br/>nested load record"]
  REC --> ROW["Existing row wrapper<br/>row priority +owner tracking"]
  ROW --> ARB["Existing bank arbiter<br/>NTT / scalar / sign process / key load"]
  ARB --> LOAD["sign_key_load +existing decoder<br/>private whole-key plan"]
  LOAD -->|"allocate /23-bit write /finish /rollback release"| MEM["One existing memory +packer<br/>four1024 x92-bit banks"]
  ARB -->|"existing clients"| MEM
  MEM -->|"ACKs +metadata"| LOAD
  LOAD --> VALID["Whole-key done +header +region mask<br/>held through retirement"]
```

An accepted key load exclusively owns the bank client until done retires.
Public reads/responses and releases,new sampling/raw requests,row,NTT and
other compute clients remain blocked. Whole-key hidden masks filter complete;
rollback releases use an internal mux while external releases stay blocked.
Only a NEW load command is masked by waiting row priority;input and done-ready
continue for the current owner,preventing a held-row retirement deadlock.

## Stage5N.4c1 whole-key ingestion client

```mermaid
flowchart LR
  SK["Expanded SK stream<br/>64 bits,8 bytes/beat"] --> DEC["sign_key_decode<br/>1024-bit header +76-bit reservoir"]
  DEC -->|"23-bit coefficient + section/poly/index"| LOAD["sign_key_load<br/>plan,commit mask,one active region"]
  LOAD -->|"allocate/write/finish"| MEM["Existing memory packer<br/>4 coefficients per92-bit word"]
  MEM --> BANKS["Four dual-port banks<br/>each1024 x92 bits"]
  BANKS -->|"64 write ACKs/poly"| LOAD
  LOAD -->|"error:discard partial +release commits"| MEM
  LOAD --> PUB["Whole-key success only<br/>rho,K,tr +region mask"]
```

This is the focused real-memory client gate,not a second production bank tree.
The client is not yet instantiated in dilithium_services. Its future arbiter
must grant exclusive access until done retires,mask complete with hidden_o,
block public reads,and protect planned regions against release. The primitive
can read internally COMPLETE polynomials before whole-key success;the client
contract prohibits exposing that bypass.

## Stage5N.4b signing hash client

```mermaid
flowchart LR
  CMD["Sign fields / opcode / level / ID"]
  BODY["ctx +message<br/>or already encoded w1"]
  FMT["sign_hash_message<br/>1024-bit selected prefix<br/>128-bit merge reservoir"]
  OWNER["Future Sign owner<br/>snapshot core/tag<br/>discard errors / wait for service retirement"]
  SVC["Existing dilithium_services<br/>one Keccak pair / sampler / four banks"]
  RAW["mu64 / private seed64<br/>challenge32,48,64 bytes"]
  MASK["256 mask coefficients<br/>existing shared-bank result"]
  CMD --> FMT
  BODY --> FMT
  FMT --> OWNER --> SVC
  SVC --> RAW
  SVC --> MASK
  SVC --> OWNER
```

The focused TB supplies the owner logic and actual main-owned service;
the formatter is not yet wired into main Sign. Actual RTL mu and private-seed
results feed9 dependent requests.29 peer empty-hash jobs occupy the other
physical core,with exact payload/core/tag/retirement checks. No existing RTL
or bank geometry change,no new hash copy. Error drain completes declared
absorption with dummy bytes;only code0 plus service retirement may commit a
dependent digest. Separate hash/sampler lifetime is not hidden by formatter done.

## Stage5N.4a key-input foundation

The new standalone process/sign_key_decode.sv is not yet instantiated in
dilithium_services or main Sign. Existing production RTL remains unchanged.

```mermaid
flowchart LR
  SK["Expanded SK input<br/>64-bit data / bytes4 / index10 / last / ID16"]
  DEC["sign_key_decode<br/>indexed framing + eta range checks<br/>76-bit little-endian reservoir"]
  HDR["rho256 / K256 / tr512<br/>one held header"]
  POLY["data23 / section2 / poly3<br/>index8 / last-poly / last-key / ID16"]
  DONE["Held done/code/ID<br/>only code0 validates the whole key"]
  FUTURE["Future signing key-memory owner<br/>discard entire tentative key on error"]
  SK --> DEC --> HDR
  DEC --> POLY
  DEC --> DONE
  HDR -.-> FUTURE
  POLY -.-> FUTURE
  DONE -.-> FUTURE
```

No main external-port change,full-key/poly RAM,engine copy or shared-bank
allocation is introduced. The next checkpoint formats signing hash messages;
bank ingestion and main Sign control remain later connection work.

## Stage5N.3 shared signing memory client

The main-owned service enables SIGN_SERVICE and contains one new
sign_process_dma/sign_process instance. No polynomial payload RAM or second
Keccak/sampler/NTT/bank tree is added.

```mermaid
flowchart TD
  MAIN["dilithium.sv / operation clients<br/>KeyGen sign request=0;Sign controller pending"]
  SVC["dilithium_services<br/>request_t / response_t"]
  ROW["row priority / pending-public-read ownership"]
  ARB["bank arbiter<br/>NTT > scalar process > signing process<br/>then raw hash / sampling / external reads"]
  DMA["sign_process_dma<br/>A92 + B92-bit caches<br/>64 ordered groups / source leases"]
  PP["sign_process<br/>Decompose x4 / CNB / Mhint<br/>polynomial reductions"]
  MEM["memory.sv<br/>2 scalar packers:4x23 ->92 bits<br/>commit after64 write ACKs / destination"]
  BANK["memory_banks<br/>4x1024x92 bits<br/>two ports / logical bank"]
  MAIN --> SVC --> ROW --> ARB
  ARB <--> DMA
  DMA <--> PP
  ARB <--> MEM <--> BANK
```

Pending public reads block signing acceptance. Row commands take priority before
acceptance;once signing owns the banks,other service commands/reads stay blocked
through done retirement. Unrelated region releases are allowed. Acceptance-edge
and ongoing leases protect sources;allocated results stay protected as well.
The two Decompose commits are serialized but share one publication mask.
Error rollback drains writes and frees tentative results. KeyGen retains its
existing output/cleanup lifetime. The earlier sections below are historical.

## Stage5N.2 signing-process arithmetic foundation

sign_process currently wraps one decompose_x4,four-lane CNB and four-lane Mhint
behind one elastic x4 transport. All use existing23-bit canonical coefficient
conventions. Decompose returns signed19-bit low lanes;the future bank DMA must
convert negative lows to canonical residues. Mhint consumes corrected-low
residues and retained6-bit high lanes,avoiding duplicate decomposition hardware
inside the hint block. CNB and hint counts reduce within one polynomial.
This source-tested unit is not yet instantiated in dilithium_services;main
Sign control and vector-wide reductions remain the following integration work.
No new engine copies,bank RAM or external top-level ports are added here.

## Stage5N.1 main-owned services

The main dilithium.sv now owns one dilithium_services instance. KeyGen and
keygen_encode are control/format clients;they no longer instantiate the
banked engine subtree or Bitpkg. The wrapper contains the same
keccak_sampler_row(RAW_SERVICE=1) and one unchanged Bitpkg. No additional
Keccak,sampler,NTT,bank memory or key RAM is added.

```mermaid
flowchart TD
  MAIN["dilithium.sv<br/>operation dispatch + service ownership"]
  KG["keygen.sv<br/>schedule + seed/sample control"]
  ENC["keygen_encode<br/>field reads + PK/SK sequencing"]
  GATE["Main-owned service boundary<br/>request_t / response_t"]
  ENGINE["dilithium_services.datapath<br/>existing SHAKE,sampler,NTT,row/process DMA"]
  BANK["Existing four1024x92-bit banks"]
  PACK["dilithium_services.packer<br/>one existing87-bit Bitpkg"]
  MAIN --> KG
  KG --> ENC
  KG --> GATE
  ENC --> GATE
  MAIN --> GATE
  GATE --> ENGINE
  ENGINE <--> BANK
  GATE --> PACK
```

helpers/dilithium_service_pkg.sv defines packed request/response records.
They group existing ports without buffering,serialization,width reduction
or added pipeline registers. pack_request_t/pack_response_t are nested in
the overall records. datapath/dilithium_services.sv connects their fields
explicitly to the unchanged engine and packer ports.

Main keygen_owner is true during DISPATCH or while the KeyGen child is busy.
It stays true after main completion retirement:the main FSM may already be
IDLE while the child releases retained regions. Only after cleanup may the
request bus become all zero and another main command be accepted. Responses,
including faults and memory reservations,remain visible even without an owner.
Reset drives the request bus to zero and resets all clients/services.

Only KeyGen is connected as an operation client at this stage. There is no
implemented Sign/Verify client or tested multi-client contention/arbitration
claim yet. Future clients must use this boundary and keep ownership through
their own drain/cleanup. No duplicate engine trees are permitted.

## Prior Stage5M evidence

Stage5M ran all75 official NIST KeyGen seeds through the complete architecture
and compared complete encoded keys. At that checkpoint all46 RTL files were unchanged from
Stage5L;the new selector extends only the preparation/checking harness.

## Stage5L complete KeyGen on shared resources

dilithium(FULL_KEYGEN=1) dispatches to the existing autonomous KeyGen scheduler
with rounding enabled. Each row finishes normally,then internal control
accepts its polynomial result. Once every row is complete,keygen_encode owns
the retained sources and the existing raw service/read port.

The encoder submits a finite SHAKE256 request for the exact PK byte length,
emits rho,then streams all t1 fields through Bitpkg. PK words have separate
host/hash acknowledgement state. A fast consumer cannot receive a word twice,
and a stalled consumer sees stable data/tags. The source advances after both
acknowledgements. Four128-bit SHAKE output beats become tr;hash completion is
accepted only with the complete64 bytes. The controller emits SK headers and
s1/s2/t0 fields,waits for the final packet completion,and holds overall done.
The polynomial scheduler then releases retained regions on done acceptance.

One existing dual Keccak,one sampler,one NTT,one process DMA and the four-bank
store are reused. keygen_encode adds no engine or encoded-key RAM.
The default FULL_KEYGEN=0 mode keeps earlier polynomial/rounded gates and
their manual read interface. Sign and Verify controllers are still planned.
Stage5N.1 lifts the engine/packer instances to the main controller as described
above. Sign/Verify will join as clients of these same resources;their scheduling
and contention handling remain future work. Preserve the full-KeyGen byte gate.

## Stage5K optional rounding and Bitpkg process block

After s2 addition,the rounded KeyGen path issues P2R with source t and explicit
low/high destinations. Both outputs share the tagged operation ID and existing
store/ack/publication machinery. All rows' rounded arrays remain available until
overall completion is consumed. The previous polynomial-only mode remains
selectable.

Bitpkg accepts one tagged polynomial command,encodes canonical scalar inputs
into10/13/3/4-bit fields,and shifts them through an87-bit reservoir into64-bit
words. It can consume an old output and append a new coefficient on the same
edge. Stalled output stays stable. Final status establishes packet completeness;
invalid input/frame status cannot turn a truncated prefix into a valid packet.
No hash engine or polynomial RAM is added. Bank-to-Bitpkg routing and complete
key-field/public-key-hash scheduling are the next integration step.

## Stage5J main FSM and KeyGen polynomial scheduler

dilithium.sv accepts operation/level/ID/xi and dispatches operation0 to keygen.sv.
Sign/Verify remain unimplemented and return explicit unsupported status.
keygen.sv instantiates the existing seed-source adapter and one shared row
datapath. It schedules all k+l secret samples,then l eligible Pre transforms,
then each of the k complete matrix rows. Each row uses the existing PWM/ADD/
inverse schedule,followed by modular ADD of s2[i]. Transformed s1 is reused.

The polynomial controller states are seed,secret sampling,secret transforms,
matrix sampling,row multiply/accumulate,inverse,s2 addition,held t output,
temporary release,held overall completion,and retained-secret cleanup.
No testbench drives those internal commands. All accepted child completion
IDs/regions/codes are checked;an unexpected result halts with sticky fault.

Output row ownership lasts until the caller accepts it and its pending read
response retires. Overall completion similarly protects retained secrets until
accepted and pending reads drain. The controller then frees every owned region
before permitting another start. The next integration work is rounding and
key serialization/public-key hashing,followed by actual Sign/Verify controllers.

## Stage5I retained seed and shared hash route

```mermaid
flowchart LR
  X["xi:256 bits + level2/3/5"] --> S["keygen_sample_source<br/>command adapter and seed registers"]
  S --> E["keygen_seed_collect<br/>xi || k || l;128 output bytes"]
  E --> R["RAW_SERVICE=1<br/>same dual-core Keccak"]
  R --> E
  E --> K["rho256 / rho-prime512 / K256<br/>retained after hash retirement"]
  K --> F["keygen_hash_message<br/>A:rho || j || i<br/>secret:rho-prime || nonce_LE"]
  F --> P["Existing Keccak -> sampler"]
  P --> B["bank_poly_store<br/>4 x 1024 x 92 bits"]
  B --> N["Existing Pre/NTT/PWM/ADD/INTT<br/>row_accumulate"]
  N --> B
```

The source adapter is synthesizable;the focused bench connects it to the
optional raw-service ports on keccak_sampler_row/keccak_sampler_ntt_banks.
RAW_SERVICE defaults to 0 for old clients. Row commands have priority over
external raw requests;inside the banked wrapper NTT/process commands have
priority over new raw requests. Accepted raw work owns a core until all output
bytes and its held raw completion retire. Compute accepts only when active_o
is zero. The producer gives an eligible raw request priority over sampling;
only an actual sample handshake allocates a polynomial region.

Adapter op0 replaces the retained seed;op1 samples matrix A;op2 samples a
KeyGen secret. It snapshots descriptors,validates retained-level agreement and
uses the existing formatter to validate row/column/nonce bounds. A sample
completion waits for both message completion and matching sampler retirement;
that retirement includes the store's 256 values and 64 acknowledged words.
Seed replacement invalidates old material immediately. Errors and successes
are held until accepted;reset clears seed validity with the rest of the path.

This adds seed/control registers,not an autonomous full-KeyGen controller.
The bench still schedules sampling,transforms and whole-row commands. No extra
polynomial/key buffer or change to the accepted engine RTL is introduced.

## Stage5H staged-row scheduler

keccak_sampler_row wraps one existing banked subsystem and row_accumulate.
It arbitrates the existing NTT,process,read and release interfaces;it does not
instantiate another engine or bank array. Row commands contain level,row index,
ID,three workspace regions and up to seven A/s1_hat region/owner pairs.
Row command priority blocks new external commands;pending jobs/reads retire
before acceptance. Source metadata is checked for committed state,ID,domain
and level before any child arithmetic. The accepted descriptors are retained
and protected for the whole row.

For each column,the scheduler issues PWM. The first product initializes the
single accumulator;later products occupy the reusable scratch region. An
explicit in-place modular ADD reads/caches old accumulator and scratch words,
then rewrites the same accumulator under a new ID. Scratch is released after
each ADD. Finally inverse NTT writes coefficient output u_i and the accumulator
is released. The output/source leases last through held whole-row completion.
Invalid/busy/aliased descriptors reject without child work;unexpected child
protocol failures halt until reset. See MEMORY_MAP.md for dimensions/addresses.

The in-place store marks the old accumulator WRITING and permits private reads
only at or beyond its write frontier. No partially rewritten word is treated
as old data. External reads are blocked during row/process ownership and reset
invalidates all descriptors. Tests capture actual old-word data/frontiers and
check every rewrite/commit. Both ordinary NTT and Pre-NTT produce retained
secret transforms. Matrix row sampling is complete before row arithmetic;
sampling/compute overlap and the full KeyGen controller are later work.

## Stage5G shared bank/process client

```mermaid
flowchart LR
  C["Command arbitration<br/>NTT,process,then sampling"] --> M["One existing bank_poly_store<br/>four1024x92-bit banks"]
  M --> R["poly_process_dma<br/>two92-bit input-word caches"]
  R --> A["Existing elastic poly_process<br/>ADD / SUB / Power2Round"]
  A --> L["Low/residue -> context0 packer"]
  A --> H["P2R high -> context1 packer"]
  L --> M
  H --> M
  M --> K["Acknowledged commits<br/>mask partial P2R pair"]
  K --> D["Held tagged completion<br/>release leases on retirement"]
```

PROCESS_SERVICE=1 enables the process command ports on keccak_sampler_ntt_banks.
The default0 preserves the NTT-only gate. Sampling,NTT and process execute
sequentially;an existing public read must retire before either compute client
can accept. NTT has command priority,then process,then sampling. This adds one
coefficient arithmetic unit/client,not another hash/NTT engine or polynomial RAM.

The process client reads metadata before allocation,leases sources immediately,
and waits for caller-selected distinct destinations. ADD/SUB require matching
domain/parameters;P2R requires coefficient domain. Each binary word group loads
A then B,then processes its four lanes. The elastic arithmetic output stays
held until its residue/low write accepts and,for P2R,its high write accepts.
P2R low is converted to canonical modulo q before storage. The two existing
packers own separate destinations,so same-bank port serialization stays valid.

After256 coefficients and64 acknowledgements per output,the client commits low
then high. Public complete bits hide both until the pair is committed;read access
is exclusive and the completion is held. Source/result release locks last through
completion retirement. Reset clears metadata/leases and cancels partial work.
Source-preservation,write acknowledgements and actual partial-publication
snapshots pass Python/C checks. Full row scheduling/KeyGen control remains next.

## Stage5F complete banked sampling and NTT connection

```mermaid
flowchart LR
  H["Existing dual Keccak + sampler"] --> P["Context-owned coefficient packers"]
  P --> S["bank_poly_store<br/>64 region descriptors"]
  S <--> B["4 banks x1024 words x92 bits"]
  B --> D["Port B word response<br/>4 scalar lanes in order"]
  D --> N["Existing scalar NTT engine<br/>NTT / INTT / PWM / Pre"]
  N --> W["Reuse context0 packer<br/>256 values ->64 words"]
  W --> S
  C["keccak_sampler_ntt_banks<br/>Source leases + sequential command FSM"] --> D
  C --> N
  C --> S
  S --> A["64 write acks + engine done<br/>publish destination;hold completion"]
```

Sampling and compute are mutually exclusive in this initial controller. Source
regions are leased on command acceptance and cannot be released until the held
completion is consumed. The controller owns the only external read/release path;
its complete bitmap masks leased sources. The underlying store descriptors stay
COMPLETE for internal DMA reads. No other client may bypass this ownership layer.

Checks read source metadata before destination allocation. A destination alias
is rejected;an occupied distinct destination waits for release. A held external
read must retire before compute acceptance. One92-bit response remains held
through four23-bit NTT input handshakes. PWM reads all A then all B. Result
writeback reuses packer0 after both sampler contexts drain. Its domain comes
from the operation,not the inherited sampling mode. Publication waits for engine
completion,256 results and64 acknowledgements. The result region remains protected
while its completion is held. Reset clears ownership/leases,not RAM payload.

The banked path is selector5/bank_ntt;the legacy Stage4 top and synthesis top
remain separate baselines. Shared seed/raw hashing and process arithmetic are
tested helpers awaiting main-controller scheduling. No new timing/area claim.

## Stage5E real sampling to owned bank regions

```mermaid
flowchart LR
  J["Job + destination bank2/region4"] --> H["Existing dual Keccak + sampler"]
  J --> D["64 region descriptors<br/>FREE / WRITING / COMPLETE"]
  H -->|"core/ID/index + coefficient23"| P["Two context-owned92-bit word packers"]
  P --> W["Per-bank port A write + acknowledgement"]
  W --> B["Four1024x92-bit banks"]
  B --> R["Port B synchronous word read"]
  D --> R
  R --> O["Held92-bit read response + owner/domain/bounds"]
  H -->|"Successful external status"| C["Commit after256 coefficients +64 write acks"]
  W --> C
  C --> D
```

keccak_sampler_banks instantiates the existing producer and new bank_poly_store.
Natural-order packing is separate for each context;bank writes never mix jobs.
Read requests are checked against committed descriptors and block matching
release until the response is consumed. The geometry and primitive collision
rules are unchanged. This path is now connected and tested for all sampling
modes/parameters. Stage5F above adds NTT DMA/result ownership;full-controller
scheduling remains next. The legacy Stage4 top is preserved.

## Stage5D selected memory foundation

User selected LightHD's published memory rather than either proposed scalar
pool. memory_banks.sv instantiates four poly_bram banks,each1024x92 bits with
independent A/B interfaces. Capacity46KiB;four coefficients per word. See
MEMORY_MAP.md for a dimensioned diagram and the published peak Sign region map.

Each port accepts a full-word read/write and returns an elastic read response
or write acknowledgement. Same-address read/read may proceed together;A-priority
serialization prevents same-edge read/write or write/write collisions. Reset
clears only interface state. Stage5E adds sampling region ownership,domain/
bounded metadata and coefficient packing. Stage5F adds NTT DMA/leases;process
schedules remain controller/adaptor work.

The Stage4 connected top remains on its verified scalar pool during migration.
The new bank foundation is separately exercised through the common launcher.
The Stage5E sampling-to-bank connection is above;physical RAM inference remains
unmeasured.

## Stage5C shared raw-SHAKE service and seed collector

```mermaid
flowchart LR
  XI["xi32 + level2/3/5"] --> SC["keygen_seed_collect<br/>formatter +128-byte collector"]
  SC --> ARB["Request arbitration<br/>raw finite priority;one ingress owner"]
  SJ["Sampling command /64-bit message"] --> ARB
  ARB --> K["Existing dual Keccak<br/>same two physical cores"]
  K --> ROUTE["Output route from captured core owner<br/>128 bits + valid bytes + core + ID"]
  ROUTE -->|"raw owner"| SC
  ROUTE -->|"sampling owner"| B["Two-slot bridge / stop-drain"]
  B --> S["Existing sampler"]
  SC -->|"rho / rho-prime"| F["KeyGen sample-message formatter"]
  F --> SJ
  SC --> O["Held rho32 / rho-prime64 / K32 result"]
```

The focused Stage5C harness implements this path and compares sampled outputs
from the RTL-collected seeds. The current Stage4 main top continues to disable
RAW_SERVICE;its memory interface and four-slot capacity stay unchanged.

Per-core raw/type/ID/remaining-byte state captures destination at acceptance.
The latest accepted descriptor selects the shared absorption source;Keccak
accepts no new descriptor until its prior message has been ingested. Output
selection uses the core's stored type,not the current command or ingress owner.
Raw beats bypass the sampler bridge. A raw core remains owned through its held
completion,including after the hash itself is idle. Completion selection is
registered so a newly finished peer cannot replace a blocked offer. Raw and
sampling jobs can own different cores;the single output arbiter still serializes
their beats. No cycle/throughput optimization claim follows from this test.

RAW_SERVICE defaults to0. Old wrappers tie all raw inputs off explicitly. The
existing bridge hierarchy and standalone Keccak/sampler/NTT RTL are preserved.
No new persistent key memory is chosen by adding a128-byte seed-result register.
Main KeyGen memory is now selected as the four-bank design above;the actual
port/lifetime/controller migration remains to be implemented.

## Stage5B KeyGen absorption-message builder

keygen_hash_message.sv snapshots seed,parameter,ID and coordinates/nonce;
it emits a held descriptor,then five or nine64-bit words,then held completion.
Invalid commands issue only an error completion. Final FIPS204 bytes are used
with level2/3/5 labels for44/65/87. See SPECIFICATION.md for the byte table.

The focused test connects one existing dual-Keccak instance to the formatter.
It does not add another engine to the Stage4 top. Shared service arbitration
between raw hashes and sampling,plus rho/rho-prime/K collection,are now tested
by Stage5C;the full main-controller connection remains next.
Message completion precedes hash completion;the service must preserve ownership.

## Preserved Stage5A isolated process unit

controller/process/poly_process.sv adds one elastic stage for canonical modular
ADD/SUB and Power2Round. It transports opcode,ID,index and last with each beat;
Power2Round exposes high10,signed low14 and packed-low13 separately. A stalled
result blocks/replaces inputs correctly;reset cancels the pending beat.

The current Quartus top remains keccak_sampler_ntt. Stage5G above connects this
unit through the banked process DMA,including two-input reads,result reservations
and rounding output lifetimes. Byte packing remains future work. Final FIPS204 bytes are selected;KeyGen
memory is now selected;key-output transport/controller details remain. Do not
infer a full KeyGen datapath.

## Preserved scalar boundary:Stage4

```text
messages/jobs -> keccak_sampler_ntt
                    | producer (unchanged Keccak + sampler)
                    v
                 four-slot memory <--- NTT result writeback
                    |    ^                     ^
                    |    | compute reservation  |
                    v    | / source locks      |
                 sequential DMA ------------> ntt_engine
                    |                         NTT/INTT/PWM/Pre
                    +--> public readback when idle
```

The new helper arbitrates sampling commands,compute commands and public reads.
Accepted compute descriptors latch both slot/expected-ID pairs,opcode and new
result ID. Memory checks eligibility,locks sources and chooses a free separate
destination. The DMA serially loads256 A values and,for PWM,256 B values.
The unchanged NTT emits256 results into that destination. Engine completion
precedes publication and the held ready/valid completion reply.

Compute has priority over a new sampling command/public read request;an old
read response drains before command acceptance. Sampling is not overlapped
with compute in this first implementation. Source release is refused while
locked;an unrelated completed slot may be released while destination reservation
is waiting for capacity. The source data remains intact after completion.

Domain/Pre/parameter/ID checks are hardware checks,not assumptions based solely
on the testbench. SPECIFICATION.md and MEMORY_MAP.md define them. This top
does not implement seed/nonce assembly,full polynomial schedules or full
KeyGen/Sign/Verify. Whole-system PPA optimization remains deferred.

## Preserved Stage3 producer/storage boundary

The approved four-slot memory now receives real sampled polynomials:

```text
commands/messages -> keccak_sampler_memory
                         | atomic job + slot allocation
                         v
                    keccak_sampler
                    Keccak -> sampler
                         | tagged coefficient stream
                         v
                    memory.sv (4 x256 x23)
                         | synchronous ready/valid reads
                         v
                  testbench;NTT consumer follows
```

Allocation and producer-command acceptance share one handshake. The actual
assigned core,job ID,mode and parameter bind to the slot. Status retirement and
memory commit share another handshake. The producer cannot accept a job when
the pool is full. Completed slots survive context reuse until explicit release.
Reads and writes use separate logical ports;payload RAM is not bulk-reset.
MEMORY_MAP.md defines publication,invalidation,release conflicts and fault handling.

The synthesis project now selects keccak_sampler_ntt;Stage4 source checking
passes. Existing Stage2 fitted metrics do not include memory or the NTT.

## Preserved Stage2 producer boundary

```text
Job descriptor + complete absorption message
             |                     64-bit ready/valid
             v                            |
  controller/keccak_sampler.sv            v
     ownership/atomic start --> dual Keccak cores
             |                            |
             |               shared128-bit data/bytes/core
             |                            v
             |                 two-slot credit bridge
             |                            |
             +-- matching context --> sampler
                                          |
                         tagged23-bit coefficients + status
                                          |
                              external sink (testbench)
```

This helper will be controlled by the future `src/controller/dilithium.sv`.
No main algorithm controller,NTT connection or complete KeyGen/Sign/Verify
implementation is present yet. Sampler RTL remains unchanged. The Stage2
producer's external sink is memory when instantiated by the Stage3 wrapper.
The Keccak wrapper has a registered offset-ready decode,and each core has a
registered absorb-ready decode without changing its processing cycles.
The user selected an initial combined target of about148MHz;the
Quartus project uses6.757ns and is not silently relaxed to close timing.
On2026-10-20 the user deferred PPA optimization until full-operation outputs
are correct. Timing closure does not block the next memory integration step.

## Command and context ownership

`job_valid_i && job_ready_o` atomically starts Keccak and sampler for the core
actually assigned by Keccak. The descriptor contains job ID,sampling mode,
parameter encoding,and the absorption-message byte count. The source supplies
those message bytes on the shared64-bit ready/valid port. Seed/nonce assembly
is external at this stage;the adapter does not implement full algorithm encoding.

Mode0 explicitly selects SHAKE128;all other sampling modes select SHAKE256.
The decode uses a dedicated scalar wire. Quartus treated the original
package-qualified constant in a port expression as an implicit net despite
Questa accepting it. That build was stopped and excluded;the current adapter
uses explicit net declarations and `default_nettype none`.

Two ownership bits keep a descriptor live until the external status handshake.
Sampler activity always implies ownership:reset clears both,accepted commands
set both,and ownership releases only on the sampler's external status handshake.
Thus !owned already guarantees sampler-ready for a new command. The helper
does not feed the redundant sampler_job_ready mux back into Keccak start;
source assertions check this invariant and readiness at every accepted command.
An idle Keccak core cannot be reused while its old sampler job/status still owns
it. The inherited Keccak dispatch preference can cause head-of-line command
waiting when its chosen idle core is still owned;this baseline favors simple
ownership over new dispatch scheduling. Performance optimization follows later.

## Bridge and backpressure

Two shared slots store128 data bits,a5-bit byte count and a core tag each.
Registered occupancy and read/write pointers own the slots. Required data is
forwarded in order;the existing sampler handles64-bit chunks internally. A push
and pop can occur on the same edge. Hash ready uses registered free space or
registered drain state;sampler ready/source_stop no longer propagate through
the bridge into Keccak's same-cycle output-ready logic. A full queue may stall
the peer stream. This is a small register queue,not polynomial memory.

Sampler `source_stop` explicitly cancels surplus unaccepted sampler-input offers.
Such offers belong to the old job and must not enter its replacement. This is a
documented internal cancellation boundary;ordinary public coefficient/status
offers remain stable under backpressure until accepted or reset.

## Drain,stop and completion

The adapter never wires sampler stop directly to Keccak stop:

1. The sampler requests stop after successful generation or an error.
2. The adapter marks that context draining and cancels its surplus bridge beat.
3. It accepts/discards a further offered SHAKE beat for that context. This
   handshake releases the shared Keccak output lock,even under downstream stalls.
4. It registers Keccak stop AFTER that handshake and holds stop through any
   intervening permutation until the core returns idle.
5. It exposes the sampler's status only when that core is idle and neither queue slot has a
   token from the job. Status acceptance releases ownership.

The peer context is retained throughout. The selected sampler status may wait
for its hash core,so another status can experience head-of-line waiting. Arbitrary
permanent sink stalls or missing declared message bytes cannot guarantee progress.
The producer must send the declared message;coordinated reset cancels a job that
cannot finish absorption. This stage has no independent per-job cancel command.

Continuous SHAKE uses `output_len_i=0`;sampler input_last is0. Bounded-XOF
exhaustion/refill is outside this stage's interface and is not simulated by
calling a rate-block boundary the end of a polynomial.

## Reset and validation hooks

One shared clock is used. Hold active-high reset through rising edges so both
the asynchronous Keccak controls and synchronous sampler controls reset.
Ownership,bridge valid and stop/drain state cancel together. The focused test
then reuses job IDs with different messages to expose stale-state leakage.

Source assertions reject unowned hash/bridge tokens,premature reuse and invalid
hash byte counts. The testbench additionally checks stable coefficient/status/
Keccak offers and proves every stop rise follows a discarded release handshake.
The combined TimeQuest helper checks the original accepted sampler payload and
reservation register counts with hierarchy-qualified patterns. These checks
complement tests;they are not formal proof or full security signoff.

## Historical Stage2 timing work (further optimization deferred)

The initial routed critical path ends at a shared Keccak1600-bit state enable.
Rejected timing trial2 qualified absorption writes by64-bit destination lane. Absorbing
one word XORs data into one lane;the absorb unit returns the previous value
for every other lane,so leaving those registers untouched preserves the state.
Padding and permutation still write the whole state on their original edges.
That change passed correctness but worsened routed timing and area,so it was
rejected. Trial3 dedicated global enable routing also worsened timing and was
rejected. Trial4 restores exact initial RTL and uses a local synthesis
assignment to implement only the two state arrays' hold behavior through data
feedback muxes instead of register clock-enable ports. Trial5 additionally
registers the launch-offset-zero flag while preserving the exact countdown and
launch interval;the source checks its equality to the counter. Trial6
adds the two-slot queue described above. External interfaces and the engines'
processing stages remain unchanged;queueing latency under stalls can change.
Standalone sampler RTL is unchanged. Active trial7 restores ordinary clock-enable
mapping and predecodes absorb-ready in each core to shorten the wide write control.
Trial8 additionally removes a redundant sampler-ready condition from command
launch;ownership and source assertions enforce atomic acceptance. This is the
current verified functional source. Its main fit is137.74MHz with-0.503ns setup;
structural guards pass. See THROUGHPUT.md for historical trial results.
