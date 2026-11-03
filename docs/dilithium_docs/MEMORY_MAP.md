# Dilithium polynomial memory

Trial-by-trial history has been removed. Qualified evidence is retained in evidence/. Current measurements and active work are recorded in AGENTS.md and sim/dilithium/.

### Registered request boundary (one of four banks)

```mermaid
flowchart LR
  A["A scheduler request
write +10-bit address +92-bit data"] --> AQ["A queue:2 x103bits
ready from registered occupancy"]
  B["B scheduler request
write +10-bit address +92-bit data"] --> BQ["B queue:2 x103bits
ready from registered occupancy"]
  AQ --> ORDER["4-bit older-slot relation
only conflicting younger requests wait"]
  BQ --> ORDER
  ORDER --> RAM["Existing dual-port RAM
1024words x92bits
collision protection retained"]
  RAM --> RESP["Existing registered responses
physical completion before retirement"]
```

Four banks retain the same coefficient storage. The new transport is1,648
request-payload/metadata bits plus48 queue-control/age bits across the four
banks (1,696logical FF bits),not another polynomial RAM. Reset invalidates
queued requests and responses;already committed RAM writes remain. The
independent model rolls back unissued requests to the actual committed RAM
state on reset. RAM responses and burst retirement follow physical issue.
The scheduler request handshake now means queue admission. Producer write
counters and producer status can therefore advance before the last RAM commit;
the age relation prevents subsequent conflicting reads from bypassing those
writes. Physical response/retirement checks remain separate from admission.
Full placed ALMs/registers must be measured after compilation.

## Stage7C compact fixed-bank replacement

Current C10 adds registered NTT read-release/final-completion decisions to the
qualified C9R1 transport below. Full210/protocol88/main33 UVM/negative passes;
48 forced split-port renewals retain ownership and match all160 NTT results.
The whole-main fit uses34660 placed ALMs,59M10Ks,8DSP and409381 block bits.
Worst reported Fmax56.65MHz/setup-10.894ns/hold+0.122ns;148MHz setup remains
open. Payload capacity stays four1024x92-bit coefficient banks. No key or
polynomial RAM is added by C8/C9/C10 control changes.

Stage7C.9 R1 introduces ADMIT,one command-validation clock
using existing descriptors. The router adds one deferred-completion bit per
physical lane (8 total). If the client consumes a completion while its same-
lane renewal loses arbitration,the router hides the already consumed report
from the client but holds the physical REPORT and owner. The cached bit makes
the later renewal eligible even after the client deasserts done-ready. Physical
retirement and the new command then happen atomically. The NTT adapter also
remembers read completion when A and B renew on different clocks. Expanded
160-case real-bank testing passes48 deliberate split renewals/48 owner checks
and40960 exact Python coefficients. The frozen C8 design fails that new legal
contention stimulus;its older qualified campaigns did not exercise this phase.
Full R1 end-to-end and physical results pass within their recorded scope;
its53.85MHz result is slower than C8 and remains a historical trial.

Stage7C.8 simplifies command validation without changing addressing or timing:
sequential bursts require `base+words<=1024`;stride-two bursts require
`words+floor(base/2)<=512`. Zero and counts above1024 still reject. Mode2 reads
require32 words and `base<=1016`;mode3 requires64 words and `base<=1008`.
Tagged mode2 writes retain producer-address handling. Mask/write checks and
atomic same-owner read-to-write renewal are unchanged. Actual command-admission
equivalence against C7 passes16842752 cases. Complete native210/protocol88 and
all30 UVM latency rows remain exact C7. The new whole-main fit uses34333 placed
ALMs,59M10Ks and8DSP;worst Fmax55.53MHz/setup-11.251ns/hold+0.121ns. Setup
remains open at148MHz. Payload size and four fixed bank roles are unchanged.

Stage7C.6 changes the response transport,not the bank roles or payload size.
Each physical port has a synchronous RAM read register plus one skid entry.
Request readiness uses registered two-slot occupancy;it does not look through
the consumer's response-ready signal. This breaks the feedback loop seen in
the frozen7C.5 implementation. One request per port per clock is sustained
without stalls;recovering from completely full buffering may add an admission
bubble. Native queue checking passes23397 requests,204 serialized conflicts
and three resets. The direct-memory28 and real-bank NTT160 gates also pass.
Fresh production210/protocol88/UVM33 gates pass with all measured cycle
fields unchanged. The current7C.7 whole accelerator routes with59 M10Ks and34302
actual placed ALMs;its148MHz setup target remains open.

```mermaid
flowchart LR
  REQ["One physical A or B port<br/>address10,data92,write,valid"] --> RAM["Synchronous bank RAM<br/>1024 x92 bits"]
  RAM --> HEAD["RAM read register<br/>data92 + response metadata"]
  HEAD --> MUX["Oldest valid response<br/>address10,write,valid/ready"]
  HEAD -->|"new request while head is stalled"| SKID["One skid entry<br/>data92,address10,write,valid"]
  SKID --> MUX
  OCC["Two registered valid bits<br/>accept when a slot is empty"] -->|"request ready"| REQ
  MUX --> CLIENT["Current physical-port owner"]
```

There is one such response path per A/B port of each of the four banks.
The first response retains its synchronous latency. Request ready does not
depend on response ready;the extra slot absorbs the request already in flight.
Payload is not reset. Reset clears both validity bits,so old read data cannot
be published as a new response. Logical field widths here are not an estimate
of placed ALMs or register allocation;Quartus can absorb RAM read registers
and optimize unused acknowledgement data.

The7C.7 loader adds two92-bit decoded-packet registers before the SAME
sampler writer. They hold at most two packets,with format/ID/index checks at
admission and separate admitted/committed counters. They are not extra
polynomial banks. The184 payload bits are retained in the fitted register
report;the four coefficient banks and total block-memory bits are unchanged.

The replacement uses exactly four logical1024 x92-bit banks:376832 payload
bits =47104 bytes. A92-bit word holds four23-bit canonical coefficients;
a full polynomial occupies64 words. A secret in Fig5 signed-nibble form
uses16 words with only bits63:0 meaningful. It is not a second coefficient
array. The7C.6 fitted hierarchy allocates40 M10Ks to these four coefficient
banks;59 M10Ks are used by the complete accelerator. Logical bank count is
not the physical M10K block count.

```mermaid
flowchart LR
  SAMPLE["Dual-context sampler<br/>4 canonical coefficients<br/>or16 signed nibbles"] -->|"B:tagged address +92-bit word"| PORTS
  NTT["4-BU NTT / Pre-NTT / MAC"] <-->|"A/B:two92-bit transform words<br/>or streamed PWM operands"| PORTS
  PROCESS["x4 Process / BitPkg / controller"] <-->|"92-bit words / packed low64"| PORTS
  PORTS["Independent A/B schedulers<br/>4 lanes per port<br/>8 small ownership entries"] <--> B1
  PORTS <--> B2
  PORTS <--> B3
  PORTS <--> B4
  B1["BRAM1 / RTL bank0<br/>1024 x92<br/>0..447:y or raw s1<br/>448..959:s2<br/>960..1023:row coefficients"]
  B2["BRAM2 / RTL bank1<br/>1024 x92<br/>0..63:row accumulator<br/>64..575:t0<br/>576..1023:first7 w0"]
  B3["BRAM3 / RTL bank2<br/>1024 x92<br/>0..447:s1hat<br/>448..895:yhat<br/>896..1023:packed w1"]
  B4["BRAM4 / RTL bank3<br/>1024 x92<br/>A ring during matrix phase<br/>then z / chat / r0<br/>KeyGen packed t1:576..895 max"]
```

These are phase-specific lifetimes,not simultaneous ownership of every label.
At level5,the final w0 uses BRAM2 words0..63 only after the final accumulator
is consumed. KeyGen uses a nine-slot A ring0..575;packed t1 occupies40*K
low64-bit words from576,and never overlaps it. Its raw s1/s2 remain compact
until final secret-key encoding. `helpers/dilithium_pkg.sv` is the executable
fixed-role address contract;memory/router state carries no64-slot ID database.

Read address modes:0 sequential,1 stride2,2 repeated compact Pre words,
3 natural-order groups from compact secret storage. Write mode2 accepts the
producer's word address,so both Keccak contexts can interleave on the same
B lane;the command still supplies the exact bounded number of writes.
All other writes follow the selected sequential/stride address sequence.
Accepted writes occur in the synchronous RAM on that edge;status publication
requires all words of the polynomial accepted and sampler completion. The
batch's physical completion retires its lane before reuse by another client.

### Compact Verify lifetimes

Verify uses the SAME four arrays. These phase-specific addresses are inferred
controller scheduling details on the published geometry, not additional RAM.
The input gate writes shifted t1 and z through the shared BitUnpkg/writer,
and expands validated sparse hints into canonical0/1 bank words.

|RTL bank|Word addresses|Verify role|
|---|---|---|
|0|448..959|Up to8 shifted t1 polynomials, then their in-place FNTTs|
|0|960..1023|Challenge coefficients, then reused CT1 product / inverse-row scratch|
|1|0..63|One row accumulator; SUB subtracts chat*t1hat before its INTT|
|1|64..575|Up to8 raw hint polynomials, four0/1 values per92-bit word|
|1|576..703 maximum|Contiguous packed w1;96 words at levels2/3,128 at level5|
|2|0..447|Up to7 z polynomials, then their in-place FNTTs|
|2|896..959|Cached challenge transform chat|
|3|Bounded ring|Sampled Ahat;9 slots at levels2/3,physical16-slot limit inferred for level5|

Each row finishes MAC, CT1 multiplication, SUB, one inverse and shared
UseHint/BitPkg before scratch is reused. Packed w1 is disjoint from hints
and the accumulator. Hashing reads it only after all rows and sampling retire.
All raw operands must pass the whole input gate before math starts; malformed
frames return an error, while noncanonical hints or an out-of-bound z return
normal signature invalidity. New commands overwrite required roles before use.

## Stage7B.7 decoder-local alignment candidate

The coefficient pool and completed-tag RAM are unchanged from7B.6. Only the
Verify decoder's local hint suffix registers change layout:eleven64-bit words
provide88 source-storage bytes for at most84 encoded bytes. Four high padding
bytes are unused and tail input lanes are masked. No whole-signature RAM,
coefficient bank or pipeline cycle is added. Final mapped register/ALM cost
must come from the current Quartus build;source padding is not a fitted-area
claim. The383-case decoder comparison checks all qualified outputs and timing.

## Stage7B.6 candidate: descriptor storage

The coefficient pool remains four banks of1024 words x92 bits:47104 bytes,
64 regions,256 coefficients per region. Only descriptor implementation changes.
Previously all64 slots kept ID,mode,parameter,domain,smallness,rewrite and
progress in registers. Only two writers can be active. Their mutable records
now stay beside the two writer contexts;successful finish copies a22-bit tag
to a64-entry synchronous RAM. The two-bit region states remain registers.

| Storage | Geometry | Meaning |
|---|---|---|
|Coefficient RAM|4 x1024 x92 bits|Four23-bit coefficients per word|
|Region state|64 x2 register bits|FREE,WRITING,COMPLETE;reset to FREE|
|Completed tags|64 x22 RAM bits|ID16,mode2,parameter2,NTT-domain1,small1|
|Active writer records|2 x32 register bits|Tag22,accepted-count9,rewrite1|
|Writer ownership|2 valid bits +2 x6-bit handles|Existing context ownership|

```mermaid
flowchart LR
  ALLOC["Allocation descriptor<br/>ID16,mode2,param2,domain1"] --> WR["Two active writer records<br/>2 x32 bits<br/>tag22 +count9 +rewrite1"]
  SCALAR["Scalar write<br/>index8 +coefficient23"] --> WR
  SCALAR --> PACK["Existing two word packers<br/>4 x23 =92 bits"]
  PACK --> COEFF["Coefficient pool<br/>4 banks x1024 x92 bits<br/>64 regions x64 words"]
  WR -->|"successful finish:256 coefficients<br/>64 acknowledged words"| TAG["Completed tag RAM<br/>64 x22 bits<br/>address:bank2 +region4"]
  STATE["Region states<br/>64 x2 register bits"] --> SELECT["Read legality and tag selection"]
  REQ["Read request<br/>bank2,region4,word6"] --> SELECT
  SELECT -->|"COMPLETE:synchronous tag read"| TAG
  SELECT -->|"WRITING:untouched rewrite word<br/>snapshot active tag"| ACTIVE["Active-tag snapshot"]
  REQ --> COEFF
  TAG --> RESP["Existing held response<br/>data92,ID16,mode2,param2<br/>domain1,small1,error1"]
  ACTIVE --> RESP
  COEFF --> RESP
```

Tag RAM is read in parallel with coefficient RAM,so qualified response timing
is unchanged. COMPLETE-region metadata is immutable until rewrite/release;
a finish writes only a WRITING region. This excludes same-address tag RAM
read/write. Rewrite reads snapshot the active tag before a possible cancel
or context reuse. Reset invalidates all region states,so stale/uninitialized
RAM entries cannot become externally readable. Failed reads return zero tags.

The internal administration contract has one active writer per region. The
integrated adapters enforce it:sample allocations select FREE regions;
compute rewrites lock their source/destination;release_allowed excludes those
locks,including the command-acceptance edge. Load owns its own allocation and
release sequence exclusively. Thus an owning region cannot be released and
reallocated behind a live writer. The per-writer metadata representation
depends on this arbitration contract. The raw memory pins are internal,not
an additional unrestricted host interface. The full-main public API retains
the existing ownership guards;the trace comparison checks its actual traffic.

The isolated old/new comparison passes64 slots,two interleaved writers,
16647 scalar writes and4418 reads,including simultaneous read/rewrite admission,
rewrite watermarks,cancellation,reset and fault cases. Full-main UVM runs the
same comparison alongside its independent scoreboard. Fresh synthesis confirms
all1408 tag bits in a64 x22 M10K instance. Local store registers drop2543->560
and local ALUT3972->1919 relative to7B.4 synthesis. Full routing and the final
placed ALM cost remain pending;these synthesis counts are not fitted metrics.

## Stage5V.4 whole Verify ownership

Main grants one services owner for the entire operation. Input preparation
loads raw t1/z/h and computes tr. Its atomic take transfers that context to
math preparation,which uses rotating scratch and publishes t1hat/zhat/h/chat.
The next take transfers it to the equation owner. The parent retains ownership
until the equation and all cleanup have retired. No additional bank or
coefficient/key/signature/message RAM is introduced by the main controller.

The same pool is4 x1024 words x92 bits=64 polynomial regions=47104 payload
bytes. One region is64 words x92 bits=256 x23-bit coefficients=736 bytes.
Verify peaks remain22/30/40 private regions (16192/22080/29440 payload bytes)
for levels2/3/5. There is no foreign owner in the whole main Verify gate;
the component gate separately preserved one foreign region. Main excludes
debug clients while an operation owns the shared pool.

```mermaid
flowchart TD
  HOST["Main op2<br/>PK64 ->SIG64 ->ctx/message64"] --> INPUT["Input owner<br/>K raw t1 +L z +K hints<br/>12 /17 /23 regions,rho/tr/ctilde"]
  INPUT -->|"atomic take"| MATH["Math owner<br/>mu hash,SampleInBall,NTT rotation<br/>peak14 /19 /25 regions"]
  MATH -->|"atomic take"| EQ["Equation owner<br/>Ahat *zhat -chat *t1hat<br/>inverse,UseHint,packing/hash<br/>peak22 /30 /40 regions"]
  POOL["One shared physical pool<br/>4 banks x1024 x92 bits<br/>64 regions x64 words<br/>each word4 coefficients x23 bits"] --- INPUT
  POOL --- MATH
  POOL --- EQ
  EQ --> FREE["Release every adopted/new region<br/>retire all services<br/>main held valid/invalid result"]
  INPUT -->|"structural invalid:cleanup"| FREE
  MATH -->|"error:drain and cleanup"| FREE
```

Failed pre-adoption handoffs leave the previous owner responsible. The parent
clears retained math and input contexts before reporting error. Normal invalid
signatures also leave an empty pool. Fatal faults discard the operation only
through global reset;recovery tests reconstruct the full chain afterward.

## Stage5V.3 Verify equation workspace

The unchanged pool is4 banks x1024 words x92 bits=47104 payload bytes.
Each region is64 words x92 bits=256 coefficients x23 bits=736 bytes.
The equation owner adopts the13/18/24-region prepared context,then plans
L A regions,one accumulator,one product scratch,and K inverse-result regions.
Planning does not allocate RAM or occupy the regions;the exclusive services
lease prevents another client from taking them during the operation.

| Role | Level2 | Level3 | Level5 | Lifetime/domain |
|---|---:|---:|---:|---|
|Adopted t1hat,zhat,h,chat|13|18|24|Through challenge hash;h coefficient domain,others NTT domain|
|A row workspace|4|5|7|Sample Ahat,consume during PWM,release at row end|
|Accumulator +product|2|2|2|NTT domain;product reused after each ADD/SUB|
|Inverse W results|4|6|8|Coefficient domain;retain until all UseHint/packing/hash retire|
|Conservative private planning bound|23|31|41|Adopted context +L+2+K;foreign owners excluded|

Fresh captures measure private peaks22/30/40 because product/accumulator leases
are released before all K W rows coexist. The count comes from actual
allocation/release events and excludes the foreign sentinel. The owner stores
only two92-bit read caches (W/h),handles and hash
headers;no new polynomial,key,signature or message RAM is added.

```mermaid
flowchart TD
  CTX["Actual prepared context<br/>t1hat,zhat,raw h,chat<br/>rho,mu,ctilde"] --> OWN["Atomic take<br/>same64-region pool"]
  OWN --> A["L Ahat row regions<br/>SHAKE128 rho||column||row"]
  A --> PWM["Shared PWM +in-place ADD<br/>one accumulator +one product"]
  OWN --> PWM
  PWM --> SUB["Subtract chat*t1hat<br/>in NTT domain"]
  SUB --> INV["One shared inverse NTT per row<br/>K W result regions"]
  INV --> READ["Read W92 +hint92<br/>4 coefficients per word"]
  OWN --> READ
  READ --> HINT["UseHint ->shared Bitpkg<br/>w1:6 or4 bits/coefficient"]
  HINT --> HASH["Shared SHAKE256<br/>mu||packed_w1 ->c2"]
  HASH --> FREE["Compare c2 with ctilde<br/>release all owned regions<br/>held valid/invalid completion"]
```

No-free-workspace and other pre-take errors preserve the upstream context.
After take,successful valid and invalid checks both release the entire
context/workspace. Foreign leases remain intact and are read back before
their own explicit release. Fatal faults require a global reset.

## Stage5V.2b transformed Verify context

The math owner adopts all raw handles on one take edge;the old owner then
returns idle. It chooses the first free region for sampled c and another for
NTT workspace. Each successful NTT commits its destination,fully retires the
engine,then releases its raw source. That freed source becomes the next NTT
destination. Hints stay in their original regions and coefficient domain.
After the last transform,raw c is freed and only chat remains.

| Item | Level2 | Level3 | Level5 | Contents |
|---|---:|---:|---:|---|
|Input context|12|17|23|K shifted t1,L z,K dense hints|
|Peak private regions|14|19|25|Input context plus sampled c plus rotating work|
|Successful result regions|13|18|24|K t1hat,L zhat,K raw hints,chat|
|Successful payload bytes|9568|13248|17664|Each region is256x23 bits=736 bytes|

These figures exclude any retained foreign owner,which the tests preserve
and read back independently. The physical pool is unchanged:4 banks x16
regions x64 words x92 bits=47104 payload bytes. No new polynomial RAM exists.
Result t1hat/zhat/chat have domain1;hints have domain0. The operation ID and
parameter stay attached to all regions. Sampling uses mode3 with domain0;
its allocation ignores the raw domain port when alloc_compute=0,as defined
in memory.sv. Captures record both allocation signals and verify the effective
stored domain by readback and engine eligibility.

```mermaid
flowchart TD
  RAW["5V.2a raw context<br/>K shifted t1,L z,K hints<br/>rho,tr,ctilde"] --> TAKE["Atomic context take<br/>complete leases +identity checked"]
  MSG["Third frame:ctx and M<br/>64-bit stream,1..8 valid bytes"] --> MU["Existing formatter +shared SHAKE256<br/>tr64 ||00 ||ctxlen ||ctx ||M<br/>mu64"]
  TAKE --> MU
  MU --> BALL["Shared SampleInBall(ctilde)<br/>first free region<br/>256 coefficients:0,+1,-1"]
  BALL --> WORK["One free NTT work region<br/>commit destination,retire engine<br/>free source,rotate work handle"]
  TAKE --> WORK
  WORK --> HATS["K FNTT(t1 shifted by13)<br/>L FNTT(z)<br/>Pre-NTT(c) ->chat"]
  MU --> READY["Retained Verify arithmetic context<br/>13 /18 /24 regions<br/>rho,mu,ctilde"]
  HATS --> READY
  TAKE -->|"hints kept raw"| READY
  READY --> NEXT["Next5V.3:Az-c*t1hat<br/>inverse NTT,UseHint,w1 hash"]
```

Pre-adoption errors leave the old context intact. After adoption,message
errors drain the finite hash and release the raw context;sampler/NTT errors
also release any actual new destination. Metadata mismatches use actual
reservation state for cleanup. Fatal physical/raw protocol faults require
global reset. A pending read response blocks result clear/take;clear wins
when both are offered. Normal transform source releases follow successful
NTT retirement;error cleanup explicitly discards the adopted raw sources.

## Stage5V.2a Verify context ownership

The same pool has4 banks,each1024 words x92 bits (4 coefficients x23 bits).
Each polynomial occupies64 words=256 coefficients=736 bytes. Each bank has
16 regions;flat region[5:4] selects the bank,region[3:0] selects its polynomial,
and word[5:0] selects one packed word. Capacity=64*736=47104 payload bytes.
No additional coefficient memory or whole encoded-key/signature RAM is added.

| Role | Regions relative to base B | Level2 /3 /5 polynomials | Payload bytes2 /3 /5 |
|---|---|---|---|
|Shifted public t1 (t1<<13)|B through B+K-1|4 /6 /8|2944 /4416 /5888|
|Canonical z|B+K through B+K+L-1|4 /5 /7|2944 /3680 /5152|
|Dense hints (0/1)|B+K+L through B+2K+L-1|4 /6 /8|2944 /4416 /5888|
|Total retained context|B through B+2K+L-1|12 /17 /23|8832 /12512 /16928|

All roles are coefficient-domain (domain0). t1/h use mode3;z uses mode2.
Operation ID16 and parameter2 are attached to every region. The `small` flag
is derived from stored values,not the role label. A caller grants an exclusive
services lease and a free contiguous range ending at or below region63.
Previously owned foreign regions remain untouched. The decoder hides tentative
frame commits;the parent publishes handles/rho/tr/ctilde only after both frames
and the finite PK hash have retired successfully.

```mermaid
flowchart TD
  HOST["PK then signature<br/>64-bit words,1..8 valid bytes<br/>index16,last per frame"] --> FORK["PK:one-word fork<br/>separate decoder/hash credits<br/>signature goes directly to decoder"]
  FORK --> LOAD["Verify decoder + existing scalar writer<br/>23-bit coefficients ->4-lane packed92-bit words<br/>whole-frame commit or rollback"]
  FORK --> HASH["Shared physical Keccak<br/>SHAKE256 of full encoded PK<br/>four128-bit beats ->tr512"]
  LOAD --> PORT["Existing allocator/packer<br/>region6,word6,ID16<br/>no extra bank"]
  subgraph POOL["Existing four-bank pool:64 regions /47104 payload bytes"]
    B0["Bank0:regions0..15<br/>1024 x92 bits<br/>A/B synchronous ports"]
    B1["Bank1:regions16..31<br/>1024 x92 bits<br/>A/B synchronous ports"]
    B2["Bank2:regions32..47<br/>1024 x92 bits<br/>A/B synchronous ports"]
    B3["Bank3:regions48..63<br/>1024 x92 bits<br/>A/B synchronous ports"]
  end
  PORT --> B0
  PORT --> B1
  PORT --> B2
  PORT --> B3
  B0 --> READ["Existing packed read response<br/>92-bit data +region/word/tag/metadata<br/>held response blocks clear/take"]
  B1 --> READ
  B2 --> READ
  B3 --> READ
  READ --> NEXT["Future Verify arithmetic owner<br/>take transfers all12/17/23 handles<br/>clear releases them"]
  HASH --> NEXT
```

PK error:stop host acceptance,finish already accepted fork data,zero-fill only
the remaining raw hash absorption needed to retire that failed request,discard
its digest and release its regions. Signature error:the frame loader rolls
back z/h;the parent releases the retained PK regions. Errors publish no context.
Reset invalidates all allocator leases;it does not erase the underlying RAM.
Clear wins over simultaneous take. A successful take does not physically free
memory;the next owner must release it. No NTT/mu/challenge work occurs here.

## Stage5V.1 decoder storage

The new decoder uses84 reservoir bits,512 header bits and an84-byte maximum
encoded hint suffix,plus counters/metadata. It does not instantiate coefficient
banks or a full encoded-key/signature RAM. Its coefficient outputs are tentative
until successful completion. The later5V.2 owner must allocate destinations in
the existing four-bank pool and discard all tentative regions on error/reset.
No memory.sv or existing allocator/engine path changes in this checkpoint.

Stage5N.4h.7 official Sign testing reuses this exact pool and memory ledger.
It adds no memory/register architecture. Each selected request supplies its
original expanded SK and message stream;expected signatures remain outside
RTL. Measured58802 new lifetimes/58802 releases and33/45/61-region peaks are
recorded in THROUGHPUT.md. Every official Sign returns all regions before done.

## Stage5N.4h.6 one main operation owner

The approved host reloads the expanded secret key for every Sign request.
The existing four banks/64 regions/47104 payload bytes remain unchanged.
Key preparation uses base0 and one rotating spare31. Its12/17/23 retained
transformed-key regions stay leased through all retries and encoding. Raw y
starts at32;existing clients choose free workspace regions from the same pool.
The new controller stores command metadata and handles;it adds no payload RAM.

```mermaid
flowchart TD
  HOST["Command + SK frame<br/>64 bits,8 bytes/word<br/>320 /504 /612 words"] --> MAIN["Main owner mux<br/>KeyGen OR Sign<br/>lease includes cleanup"]
  MAIN --> KEY["Sign key preparation<br/>base0,rotating spare31<br/>12 /17 /23 regions"]
  MSG["ctx and message frame<br/>64 bits,1..8 valid bytes<br/>index restarts0"] --> A["Attempt/retry clients<br/>same four-bank pool<br/>no message replay RAM"]
  KEY -->|"retained key lease"| A
  A -->|"accepted z and hints<br/>atomic context take"| ENC["Signature encoder<br/>8 /11 /15 payload regions<br/>64-bit output"]
  ENC --> DROP["Release attempt payload<br/>then clear prepared key"]
  DROP --> DONE["All regions free<br/>held main Sign completion"]
  MAIN --> KG["Existing KeyGen<br/>owner retained through its<br/>post-completion cleanup"]
```

Main start readiness requires both clients idle and services quiescent.
During Sign,external debug reads cannot observe or consume the internal read
stream. New requests cannot enter during KeyGen cleanup even after main done
has retired. Reset discards all contexts globally;fatal failure needs reset.
The main-top gate reconstructs every physical allocation/rewrite,finish and
release. It checks zero outstanding regions at normal Sign completion and
before the next request;reset snapshots may contain incomplete regions.

## Stage5N.4h.5 signature packing lifetime

Physical memory stays four1024 x92-bit banks. Each region is64 x92-bit words
=256 x23-bit coefficients=736 payload bytes. The encoder snapshots handles/
digest,one92-bit read cache,one64-bit hint word and eight8-bit counts. Z uses
the existing87-bit packer reservoir. No full-signature or polynomial RAM.

```mermaid
flowchart LR
  K["Key owner<br/>12 /17 /23 regions<br/>retained throughout"]
  A["Attempt READY<br/>z:4 /5 /7 regions<br/>h:4 /6 /8 regions<br/>ctilde:256 /384 /512 bits"] -->|"atomic take;old owner invalidates"| E["Encoder owns z+h<br/>8 /11 /15 regions<br/>5888 /8096 /11040 bytes"]
  E -->|"64 words x92 bits per region<br/>4 x23-bit coefficients per word"| Z["Shared Bitpkg<br/>z:18 /20 bits<br/>87-bit reservoir"]
  E --> H["Binary hint scan<br/>8-bit indices and counts<br/>64-bit output word"]
  Z --> O["64-bit signature stream<br/>2420 /3309 /4627 bytes<br/>backpressure,final byte count"]
  H --> O
  O -->|"last byte handshake or recoverable error"| C["Release ALL adopted z+h<br/>then held completion"]
  C --> K
```

The scheduler grants only the encoder during packing and keeps the key leased.
Preflight failures preserve the attempt owner. After adoption,recoverable
failures free the whole map;fatal/reset paths need global reset. Key/sentinel
regions are outside the map. Quiescence and upstream take block outstanding
read responses before ownership moves. No adopted region is freed during reads.

## Stage5N.4h.4 retry ownership and cleanup

The parent retains the prepared key while the six existing clients move one
attempt through the same64-region pool. On normal rejection,the checker has
already freed **every** attempt payload before its header-only take. The next
ExpandMask therefore reuses the y/workspace addresses without overwriting a
live polynomial. One transit copy of mu512+private-seed512 and nextnonce17
connects the rejected checker to the next mask command. It is control/header
storage,not another polynomial or arbitrary-message buffer.

On success,only z[l]+h[k] remain with the checker and parent. On ordinary
failure,clear live clients in dependency order:checks,products,transform,
challenge,matrix,mask. This preserves raw y while matrix/transform need it
and w1 while challenge needs it. Transfers invalidate old owners before any
reuse. The key owner is outside this cleanup chain and remains intact.

```mermaid
flowchart TD
  KEY["Retained prepared key<br/>12 /17 /23 regions"] --> LOOP["Attempt parent<br/>exclusive services"]
  MSG["Stream ctx and M once"] --> M["Initial mu/seed hash<br/>then y[l]"]
  LOOP --> M
  M --> A["A*y and Decompose<br/>existing workspace"]
  A --> C["w1 hash and challenge<br/>then FNTT c"]
  C --> P["cs1/cs2/ct0<br/>z and corrected low"]
  P --> B["CNB and hints"]
  B -->|reject and free payload| R["Take mu512,seed512,nextnonce17<br/>guard nonce+l <=65536"]
  R -->|legal| Y["ExpandMask only<br/>same seed,next nonce"]
  Y --> A
  R -->|exhausted| E["Code6<br/>key retained,no nonce wrap"]
  B -->|accept| OUT["Retain z[l],h[k],ctilde<br/>clear or whole-context take"]
```

Earlier phase storage peaks remain unchanged;this control loop adds no bank
or payload RAM. Existing matrices are resampled for each attempt in this
functionality-first schedule;matrix caching is a later measured optimization.
The focused gate records physical allocations,rewrites,commits and releases,
including row-MAC internal scratch releases and temporary IDs. Test sentinel
storage and artificial errors are separate from the algorithm's requirements.

## Stage5N.4h.3 norm/hint lifetime and rotating destination

The physical memory is unchanged:four banks,each1024 words x92 bits,with
four23-bit coefficients per word. A region is64 words=256 coefficients=
736 payload bytes. The64-region pool has47104 payload bytes. No new RAM.

The owner adopts z[l],r0[k],w1[k],ct0[k] together. CNB reads do not allocate.
One lowest-free address is planned by the exclusive owner as the first hint
destination;the Mhint client physically allocates it when launched. After
each ADD and successful Mhint fully retire,the old r0,
w1 and ct0 row regions are released. That freed r0 address becomes the next
hint destination. Completed hints remain owned until acceptance/clear/take.
An over-weight partial hint vector is entirely discarded before rejection
publication. The prepared key and unrelated clients are never released.

| Level | Adopted attempt | Key | Peak including first hint | Accepted result +key | Rejected result +key |
|---|---|---|---|---|---|
|2|4+3x4=16|12|29|4z+4h+12=20|12|
|3|5+3x6=23|17|41|5z+6h+17=28|17|
|5|7+3x8=31|23|55|7z+8h+23=38|23|

Counts exclude the test sentinel/capacity blockers and earlier phase peaks.
The owner holds scalar headers mu512,seed512,ctilde512,nextnonce17 plus
handle/control metadata. A rejected outcome exposes no ctilde/payload handles,
but preserves mu/seed/nextnonce for the later retry controller.

```mermaid
flowchart TD
  P["Products owner<br/>z[l],r0[k],w1[k],ct0[k]"] --> T["Whole-context take<br/>no polynomial copy"]
  T --> C["Read-only CNB<br/>z then r0 then ct0"]
  C -->|pass| A["Shared ADD<br/>r0[row] += ct0[row] in place"]
  A --> H["Shared Mhint x4<br/>combined low + retained w1<br/>write256 hints to spare region"]
  H --> W["12-bit sum vs omega"]
  W -->|within limit| F["Release old low/high/ct0 row<br/>reuse freed low as next spare"]
  F -->|next row| A
  F -->|all rows| OK["Retain z[l],h[k],ctilde<br/>mu,seed,next nonce"]
  C -->|norm reject| R["Release entire attempt<br/>retain mu,seed,next nonce only"]
  W -->|above limit| R
```

## Stage5N.4h.2 mask handoff and response workspace

The new owner adopts raw y and w0/w1/chat together. It copies only the small
mu/seed/ctilde headers and handle metadata. After the last read of each raw
polynomial,shared ADD/SUB rewrites y->z and w0->r0 in place. The previous
owners are invalid before these writes,so their clear paths cannot reclaim
or expose a partially updated attempt.

| Level | Adopted attempt regions | Planned free addresses | Retained result + key | Phase peak + key |
|---|---|---|---|---|
|2|4 y+4 w0+4 w1+1 chat=13|4 ct0+2 scratch=6|4 z+4 r0+4 w1+4 ct0+12 key=28|30 |
|3|5+6+6+1=18|6+2=8|5+6+6+6+17=40|42 |
|5|7+8+8+1=24|8+2=10|7+8+8+8+23=54|56 |

Counts exclude the test sentinel and capacity blockers. The planned address
set includes an inverse scratch used for s1/s2 which is already free while
the final ct0 vector accumulates;the peak counts are actual simultaneous
allocations,not the sum of every planned address. Prior matrix-generation
peaks remain separate. Physical storage stays four1024x92-bit banks/64regions.

```mermaid
flowchart TD
  MASK["Mask owner:y[l],mu,private seed"] --> TAKE["Atomic take;no bank copy"]
  VECTOR["Vector owner:w0[k],w1[k],chat,ctilde"] --> TAKE
  KEY["Prepared s1/s2/t0 NTT handles<br/>remain with key owner"] --> PWM["Shared PWM:chat*secret_hat<br/>one reusable region"]
  TAKE --> PWM
  PWM --> INV["Shared INTT<br/>reusable scratch or retained ct0[row]"]
  INV --> ADD["In-place ADD:y -> z"]
  INV --> SUB["In-place SUB:w0 -> r0"]
  INV --> T0["Keep ct0[k] for later norm/hints"]
  ADD --> KEEP["Retain z,r0,w1,ct0<br/>mu,seed,ctilde,next nonce"]
  SUB --> KEEP
  T0 --> KEEP
```

PWM/inverse scratch is freed after each polynomial. chat is freed after all
three groups. Normal post-adoption errors discard the whole attempt;only the
prepared key survives. Full-sign retry will consume the retained headers and
choose the next nonce rather than replaying arbitrary message RAM. That
controller and rejection handling are not part of this arithmetic checkpoint.

## Stage5N.4h.1 ownership transfer and dead-yhat reuse

Ownership changes without copying bank data. The previous matrix and
challenge clients transfer on one edge;their clear paths then cannot release
the adopted regions. The new sign_challenge_transform owner releases yhat,
allocates chat=FNTT(c),validates its complete commit,then releases raw c.
Key and original y remain with their existing owners.

| Level | Before transfer | Dead yhat released | c/chat overlap | Retained after raw c released |
|---|---|---|---|---|
|2|29 regions|4|26|12 key+4 y+8 low/high+1 chat=25 |
|3|40|5|36|17+5+12+1=35 |
|5|54|7|48|23+7+16+1=47 |

These counts cover this phase,excluding the test sentinel and capacity
blockers;they do not replace earlier matrix-generation peak counts. At
736 payload bytes per region,the retained totals are18400/25760/34592 bytes.
No encoded key,message or polynomial copy RAM is added. Even when every
other region is occupied,the released yhat slots provide the NTT destination.

```mermaid
flowchart TD
  M["Matrix owner:yhat[l],w0[k],w1[k]"] --> T["Atomic take edge<br/>no allocation or physical release"]
  C["Challenge owner:c + ctilde"] --> T
  T --> N["New owner:all adopted handles"]
  N --> F["Release dead yhat:4/5/7 regions"]
  F --> D["FNTT c -> one free chat region<br/>64 x92 bits"]
  D --> ACK["Validate complete commit and child retirement"]
  ACK --> R["Release raw c"]
  R --> KEEP["Retain w0,w1,chat + ctilde<br/>clear or transfer to next owner"]
```

Normal post-adoption error releases all adopted attempt data;raw y and
prepared secrets survive. Global reset is the recovery for partial/fatal
faults. Later products/z/hints still need their own region lifetimes;this
checkpoint establishes the handoff and challenge transform only.

## Stage5N.4g challenge lifetime

The original key,raw y and retained yhat/w0/w1 keep28/39/53 regions at
levels2/3/5. Challenge generation reads w1 in place and needs one additional
free region for c:29/40/54 logical live regions. The test fixture also keeps
one unrelated sentinel. No full encoded-w1 buffer is stored:one92-bit cache
feeds the existing87-bit packer reservoir and formatter stream.

ctilde uses a private512-bit register with32/48/64 meaningful bytes. The
same bytes are hashed for SampleInBall. c occupies64 x92 bits =256 x23-bit
coefficients =736 payload bytes in the existing four-bank memory. Its handle
is chosen from currently free descriptors,including released row workspace;
the outer Sign owner retains all other contexts across the handoff.

```mermaid
flowchart LR
  SOURCE["Existing key,y,yhat,w0,w1<br/>28/39/53 retained regions"]
  W1["w1[k]<br/>64 x92 bits each"] --> CACHE["92-bit read cache"]
  CACHE --> PACK["Shared87-bit packing reservoir"]
  PACK --> HASH["mu || packed w1 -> SHAKE256"]
  HASH --> DIGEST["ctilde register512 bits<br/>32/48/64 valid bytes"]
  DIGEST --> SAMPLE["Same SHAKE256/SampleInBall"]
  SAMPLE --> DEST["One new c region<br/>64 x92 bits"]
  DEST --> CLEAR["Explicit clear releases c only"]
```

Hash/packing failures allocate no polynomial. A completed c with bad status
identity is released before error done. All source regions remain intact.
During teardown,drain consumers then clear challenge,matrix,mask and key
clients in that order. Partial ownership transfers for later secret products
and rejection/retry are still to be scheduled;this is not the final full Sign
memory lifetime map or a new fitted resource measurement.

## Stage5N.4f reusable matrix-row workspace

Same physical memory:four banks,each1024 x92 bits;64 logical regions,each
64 x92 bits =256 x23-bit coefficients =736 payload bytes. sign_matrix_prepare
chooses free region handles automatically and adds metadata only.

| Level | Existing key + raw y | Workspace addresses | Total address plan | Retained after row temporaries released |
|---|---|---|---|---|
|2|12+4=16|4 yhat+4 A+4 w0+4 w1+3 row work=19|35|12+4+12=28 regions |
|3|17+5=22|5 yhat+5 A+6 w0+6 w1+3 row work=25|47|17+5+17=39 regions |
|5|23+7=30|7 yhat+7 A+8 w0+8 w1+3 row work=33|63|23+7+23=53 regions |

Address-plan counts include workspace addresses leased for later use;they
are not simultaneous physical allocations. Accumulator/scratch are released
by the row service before decomposition allocates its new outputs. The focused
bench also reserves region50 as an unrelated sentinel,so the largest complete
address plan covers all64 regions. Artificial capacity tests fill additional
free regions with real sampled blockers;these are not normal Sign storage.

```mermaid
flowchart LR
  KEY["Prepared key<br/>N=l+2k regions<br/>retained by key client"]
  Y["Original y[l]<br/>coefficient domain<br/>each64 x92 bits"] --> FNTT["Shared forward NTT"]
  FNTT --> YH["yhat[l]<br/>NTT domain<br/>retained by matrix client"]
  RHO["rho register256 bits"] --> SAMPLE["Shared SHAKE128 + sampler"]
  SAMPLE --> A["A row[l]<br/>NTT domain<br/>reused for each row"]
  A --> ROW["Shared PWM + in-place ADD + INTT<br/>acc,scratch,w:3 region addresses"]
  YH --> ROW
  ROW --> DEC["Shared x4 Decompose"]
  DEC --> LOW["w0[k]<br/>canonical signed-low residues"]
  DEC --> HIGH["w1[k]<br/>unsigned high parts"]
  Y --> Z["Later z calculation<br/>original y is preserved"]
  KEY --> LATER["Later secret products"]
```

A row and raw w are freed after validated decomposition;acc/scratch retire
inside the existing row service. All yhat/w0/w1 stay private until the whole
vector succeeds. Errors roll back only workspace regions. Clear order during
teardown is matrix client,then mask client,then key client,after consumers
drain;normal algorithm rejection/retry will define its own lifetimes later.

## Stage5N.4e mask-vector lifetime

The prepared key remains in its N=12/17/23 regions throughout hashing and
mask generation. One attempt adds l=4/5/7 contiguous coefficient-domain mask
regions,each64 x92 bits=256 x23-bit coefficients=736 payload bytes. The raw
key transform scratch is already free;it is not required by the mask client.

| Level | Key + mask live regions | Logical payload bytes |
|---|---|---|
|2|12+4=16|11776 |
|3|17+5=22|16192 |
|5|23+7=30|22080 |

These are live payload sizes in the same four1024 x92-bit banks,not newly
allocated hardware or fitted resources. Tests use key handles
[31,0,...,N-2],mask regions32..32+l-1,and an unrelated sentinel in region50.
All mask regions stay private under the outer owner until the full vector
is validated. Clear/error cleanup releases masks only;key and sentinel
readback must remain exact. Later arithmetic may use a different explicit
nonoverlapping plan. This is not the final complete Sign memory schedule.

```mermaid
flowchart TB
  KEY["Retained key regions<br/>N x64 x92 bits<br/>s1hat,s2hat,t0hat"]
  MU["Registers:mu512 + mask seed512<br/>plus snapshotted header/control"] --> ENGINE["Same Keccak/sampler"]
  ENGINE --> Y["Mask base..base+l-1<br/>l x64 x92 bits<br/>y in coefficient domain"]
  KEY --> NEXT["Later shared NTT/PWM/process clients"]
  Y --> NEXT
  Y --> CLEAR["Clear/rollback releases y only"]
```

## Stage5N.4d one-scratch prepared-key layout

The existing four1024 x92-bit banks remain unchanged. Let B be raw base,W
the initial free scratch,N=l+2k. Raw key region B+j initially holds polynomial
j. Transform0 writes W and releases B;transform1 writes B and releases B+1;
continue until the last transform releases B+N-1. Prepared handles therefore
become [W,B,B+1,...,B+N-2];B+N-1 is the final free scratch. The explicit handle
array preserves polynomial order even though physical regions move.

| Level | Prepared polynomials | Steady key payload | Peak key+scratch payload |
|---|---|---|---|
|2|12|12 x736=8832 bytes|13 x736=9568 bytes |
|3|17|17 x736=12512 bytes|18 x736=13248 bytes |
|5|23|23 x736=16928 bytes|24 x736=17664 bytes |

Each region is64 x92 bits=256 x23-bit coefficients=736 payload bytes. These
are logical live payload sizes inside the existing banks,not added RAM or
fitted resource counts. rho/K/tr require1024 retained register bits;handles,
owned/plan masks and control are metadata. No polynomial/key-byte RAM is added.

```mermaid
flowchart LR
  RAW["Raw regions B..B+N-1<br/>s1[l],s2[k],t0[k]<br/>64 words x92 bits each"] --> NTT["Shared Pre/FNTT"]
  NTT --> W["Free scratch W<br/>64 x92 bits"]
  W --> OK["Validate ID,destination,complete ACKs"]
  OK --> FREE["Release old raw source<br/>it becomes next scratch"]
  OK --> MAP["Retained handles<br/>[W,B,...,B+N-2]"]
  MAP --> OWNER["Future Sign owner uses same banks<br/>clear later releases every handle"]
```

Loaded raw secrets use coefficient domain;prepared results use NTT domain.
s1/s2 retain mode1 and t0 mode3 as storage labels;all retain key ID/level.
The operation owner keeps intermediate raw/results private across child
handoffs. Error cleanup includes already transformed replacements plus any
new completed destination,not just the original raw-region mask. Reset is
required for a physical fault with a potentially WRITING destination. A
separate unrelated sentinel remains allocated and must survive normal errors
and clear;global reset intentionally invalidates the whole shared tree.

## Stage5N.4c2 production access control

The unchanged contiguous decoded-key layout below now uses the production
shared service. One load owner controls the same allocator/packer/four banks;
new compute/sampling descriptors and public reads are blocked until its done
retires. complete is filtered with whole-key hidden. External releases are
blocked on acceptance and throughout loading/held done;internal rollback
releases have their own mux selection into the existing release port.

The plan still consumes12/17/23 existing regions,with no extra key/polynomial
RAM. Prior public-read responses and Keccak/sampler retirement must drain
before a load can start. Header and region handles are valid at successful
held done and must be retained by the future Sign owner. Reset clears validity
and ownership across the one shared tree;payload RAM is not securely erased.
The Stage5N.4c1 diagram/layout below remains applicable;its standalone-only
scope describes that historical checkpoint.

## Stage5N.4c1 tentative expanded-key layout

The new loader is tested against the real memory primitive;production service
arbitration is the next checkpoint. No memory dimensions change:
4 logical banks x1024 words x92 bits;flat region={bank2,region4};each region
has64 words x4 coefficients x23 bits. A decoded key occupies12/17/23 regions,
or8832/12512/16928 coefficient-payload bytes. These are logical allocated
payload sizes within the existing banks,not extra RAM or fitted resource counts.

| Section | Level2/3/5 polynomial count | Flat regions from command base B | Metadata |
|---|---|---|---|
|s1|4/5/7|B through B+l-1|mode1,coefficient domain,key ID,level |
|s2|4/6/8|B+l through B+l+k-1|mode1,coefficient domain,key ID,level |
|t0|4/6/8|B+l+k through B+l+2k-1|mode3,coefficient domain,key ID,level |

```mermaid
flowchart TB
  IN["Expanded SK bytes"] --> DEC["Decoder<br/>rho256 / K256 / tr512<br/>76-bit payload reservoir"]
  DEC --> DMA["One23-bit coefficient at a time<br/>core0 packing context"]
  DMA --> MAP["Region plan B..B+l+2k-1<br/>s1 then s2 then t0<br/>64 words x92 bits/region"]
  MAP --> B0["Bank0<br/>1024 x92<br/>flat regions0..15"]
  MAP --> B1["Bank1<br/>1024 x92<br/>flat regions16..31"]
  MAP --> B2["Bank2<br/>1024 x92<br/>flat regions32..47"]
  MAP --> B3["Bank3<br/>1024 x92<br/>flat regions48..63"]
  B0 --> OUT["Existing checked92-bit read port<br/>4 natural-order coefficients/word"]
  B1 --> OUT
  B2 --> OUT
  B3 --> OUT
```

The7-bit end calculation rejects overflow instead of wrapping. Any occupied
region rejects the whole plan before input/allocation. Each polynomial gets
64 write ACKs before primitive finish0;all earlier commits remain hidden.
Whole-key done0 publishes the complete region mask and header. On error,
finish1 frees the active partial region,then release handshakes free every
earlier committed region. Unrelated data is preserved and checked by sentinel
readback. The owner must mask complete and block public reads;the primitive
alone does not enforce whole-key privacy. Locks last through held done.
Reset clears validity,not payload bits;this is not secure key erasure.

## Stage5N.4b signing hash storage

The formatter holds a selected1024-bit prefix and128-bit merge reservoir,
plus counters;there is no full context/message RAM. Raw hash requests allocate
no polynomial region. Mask-nonce tests use the existing sampler allocation,
packing/ACK/commit path and read back64x92-bit words(256 coefficients).
The focused host then releases that scratch region;this is not a permanent
Sign memory allocation. Existing four-bank geometry/KeyGen map are unchanged.
The future decoded-key loader must keep its whole-key allocations private;
the hash client does not implement that loader or retain full keys.

## Stage5N.4a decoded-key boundary

The standalone sign_key_decode retains rho256 + K256 + tr512 =1024 header
bits and a76-bit payload reservoir. It emits canonical23-bit coefficients,
tagged by s1/s2/t0 section,polynomial,index and ID. It currently allocates no
shared-bank regions and changes none of the maps/geometry below.
The future key-memory owner must reserve/protect destination regions and keep
the ENTIRE key private until decoder done_code0,not publish each polynomial
as it arrives. Error or reset invalidates all tentative header/payload output.
No signing key lifetime map or bank-ingestion implementation is claimed here.

## Stage5N.3 signing-process use of the existing four banks

Geometry and accepted KeyGen allocations below are unchanged. Signing process
commands select free scratch regions;the complete signing lifetime map is
pending its schedule. No permanent new RAM or regions are reserved here.

```mermaid
flowchart LR
  SRC["Complete source A / B regions<br/>each256x23 bits<br/>64x92-bit words"]
  READ["Port B checked reads<br/>region6 / word6 / ID16<br/>mode2 / level2 / domain1"]
  CACHE["DMA caches<br/>A92 + B92 bits<br/>B used only for Mhint"]
  PROCESS["x4 process<br/>high4x6 / signed low4x19<br/>or reject / hint4"]
  FORMAT["Scalar write formatting<br/>negative low +q;high zero-extend<br/>or hint0/1;index8 / last1"]
  PACK["memory.sv contexts0/1<br/>4x23 ->92 bits<br/>Port A writes + ACKs"]
  LOW["Selected dest region<br/>64x92 bits<br/>canonical low or hints"]
  HIGH["Selected high region<br/>64x92 bits<br/>Decompose only"]
  PUB["Full successful packet<br/>+64 ACKs / result +finish<br/>publish both Decompose results together"]
  SRC --> READ --> CACHE --> PROCESS --> FORMAT --> PACK
  PACK --> LOW --> PUB
  PACK --> HIGH --> PUB
```

CNB allocates no destination. Decompose uses two scalar packing contexts;
Mhint uses context0. Sources are leased from command acceptance through done
retirement. Results stay private until success;late metadata/high/data errors
discard all owned partial results with finish_code!=0. Reset invalidates
ownership;old physical BRAM bits cannot be read as complete objects.
Full stored high23 is validated before6-bit narrowing. Production arbitration
enforces leases/publication. The historical Stage5N.2 boundary follows.

Stage5N.2 adds standalone x4 signing arithmetic but does not change this memory
map or allocate new regions. Each92-bit word naturally supplies its four23-bit
input lanes. Future DMA must store Decompose lows as canonical23-bit residues,
zero-extend highs,and keep tentative results unpublished until a full packet
passes. Sign-process protocol errors invalidate earlier tentative output.
CNB/Mhint per-polynomial reductions still need vector-level owner/control.

Stage5N.1 moves the physical banked service under dilithium.services.datapath.
All bank dimensions,regions,packing,IDs and lifetimes below remain unchanged.
KeyGen owns the services through post-completion cleanup,including cycles when
the main FSM is IDLE but the child is still busy freeing regions. The common
request/response records carry existing memory ports at full width;they add no
memory. See ARCHITECTURE.md for the main-owned service diagram.

## Stage5L full-key read ownership and cleanup

The full-key encoder owns the existing public bank-read client while the
polynomial scheduler holds its final REPORT state. No source region is freed
until the complete key-output operation retires. Reads are serialized through
one92-bit word cache;four23-bit coefficients feed the existing Bitpkg.
The packer has its existing87-bit reservoir. Additional encoder payload
registers are rho256,K256 and tr512;there is no whole encoded-key buffer.

| Encoding section | Bank regions | Source ID | Field format |
|---|---|---|---|
|0:PK t1|flat40+i =bank2/local8+i|base+768+i|10 bits/coefficient |
|1:SK s1|flat1+j =bank0/local1+j|base+16+j|eta-s,3 or4 bits |
|2:SK s2|flat8+i =bank0/local8+i|base+16+l+i|eta-s,3 or4 bits |
|3:SK t0|flat56+i =bank3/local8+i|base+768+i|4096-low,13 bits |

Every read verifies region,word,ID,level,coefficient domain and provenance
mode before feeding its cache. Headers come from retained rho/K/tr registers.
The encoder starts only after all matrix rows finish and their temporaries
are released;shared Keccak absorption cannot block future matrix sampling.
PK data is forked to host and hash with two acknowledgement bits;memory/packer
advancement waits for both. SK only requires output acceptance.

```mermaid
flowchart LR
  B["Existing four1024x92-bit banks<br/>retained t1,s1,s2,t0"] --> C["One92-bit read cache<br/>4 x23-bit coefficients"]
  C --> P["Existing Bitpkg<br/>87-bit reservoir ->64-bit word"]
  H["rho256 / K256 / tr512 registers"] --> M["Header/field word sequencer"]
  P --> M
  M --> O["Tagged64-bit key output<br/>valid/ready,type,index,last,ID"]
  M --> K["PK words only<br/>same dual-Keccak raw service<br/>SHAKE256(pk,64)"]
  K --> H
```

At successful overall retirement,the previous cleanup order is retained:
raw s1,transformed s1,s2,t0 and t1. The next command is accepted only after
reservations return to zero. Reset clears descriptors/handshakes,not RAM
payload bytes. Exact complete key comparison validates used field values;
the11179 encoder-read count also includes metadata-checked abort prefixes,
not a separate claim of11179 logged raw-word value comparisons.

## Stage5K retained P2R arrays

ROUND_OUTPUTS=1 extends the existing KeyGen schedule without adding banks:

| Flat regions | Physical logical bank / local region | Contents |
|---|---|---|
|40..40+k-1|Bank2 /8..8+k-1|t1[i],10-bit high zero-extended in23-bit lanes |
|56..56+k-1|Bank3 /8..8+k-1|t0[i],signed low represented canonically modulo q |

Each polynomial still occupies64 x92 bits =736 bytes. At level5,the arrays
occupy8 x736=5888 bytes each,total11776 bytes. This is existing coefficient RAM
allocation,not the eventual packed key-byte size. Bank2 regions0..l-1 retain
s1_hat;bank3 regions0..l-1 stage the current matrix row. Since l<=7,the new
regions8..15 cannot overlap either existing client.

```mermaid
flowchart LR
  T["Bank1 region3:t[i]<br/>64 x92 bits"] --> P["Existing P2R process DMA<br/>D=13,positive4096 tie"]
  P --> L["Bank3 regions8..8+k-1<br/>t0[i] canonical23-bit<br/>64 x92 bits each"]
  P --> H["Bank2 regions8..8+k-1<br/>t1[i] high10-bit in23-bit lane<br/>64 x92 bits each"]
  L --> S["Retain through overall completion<br/>future Bitpkg read client"]
  H --> S
```

The process client acknowledges both64-word writes and atomically exposes the
pair before row publication. Row t/u/matrix release does not release these
arrays. Following overall completion acceptance and pending-read drain,the
scheduler releases raw s1,transforms,s2,then all t0 regions and all t1 regions.
The rounded test reads every retained field and exercises resets/reuse.
Future full-key serialization must consume the arrays before accepting overall
completion. No encoded-key RAM is allocated by the standalone Bitpkg block.

## Stage5J autonomous KeyGen live ranges

Active controller:`src/controller/memory.sv` (module memory),formerly named
bank_poly_store. Physical geometry remains four1024x92-bit banks. Primitive
helpers move to controller/memory/;the former scalar memory moves to
legacy/slot_memory.sv. Historical sections retain the names used in their
evidence snapshots.

| Flat region | Bank / local region | Contents / lifetime |
|---|---|---|
|1..l|0 /1..l|Raw s1;preserved through overall completion |
|8..8+k-1|0 /8..8+k-1|Raw s2,nonce=l+i;preserved through overall completion |
|32..32+l-1|2 /0..l-1|Pre-NTT(s1);computed once,reused across all rows |
|48..48+l-1|3 /0..l-1|Current A_hat row;released after its t row is consumed |
|16|1 /0|Transform accumulator;row scheduler releases after inverse |
|17|1 /1|One PWM product scratch;released after each accumulator ADD |
|18|1 /2|Inverse row u;held through final s2 addition and row consumption |
|19|1 /3|t=u+s2[i];caller reads before accepting row result |

Each region is64 words x92 bits =256 x23-bit coefficients =736 bytes.
At level5,raw s1 uses regions1..7 and raw s2 uses8..15,which do not overlap.
This is a derived KeyGen allocation using the selected LightHD bank geometry,
not a claim that the paper publishes these exact KeyGen address tables.

```mermaid
flowchart LR
  S["RTL sample nonces0..l+k-1"] --> B0["Bank0:1024 x92<br/>raw s1 regions1..l<br/>raw s2 regions8..8+k-1"]
  B0 --> PRE["Existing Pre-NTT<br/>small s1 only"]
  PRE --> B2["Bank2:1024 x92<br/>retained s1_hat regions0..l-1"]
  A["RTL sample rho || j || i"] --> B3["Bank3:1024 x92<br/>one A_hat row regions0..l-1"]
  B2 --> ROW["PWM / ADD / inverse NTT"]
  B3 --> ROW
  ROW --> B1["Bank1:1024 x92<br/>region0 accumulator<br/>region1 scratch<br/>region2 inverse u<br/>region3 final t"]
  B0 --> ADD["Add s2[i] modulo q"]
  B1 --> ADD
  ADD --> B1
  B1 --> OUT["Tagged row readout<br/>4 coefficients /92-bit word"]
```

After each accepted t row,the controller waits for pending public reads,then
releases t,u and that matrix row. The next row reuses the same regions.
It never regenerates or retransforms s1 between rows. After overall completion
is accepted,it waits for pending reads,then releases raw s1,s1_hat and raw s2.
Future key encoding must consume those secrets before this final cleanup;
the current polynomial-phase output is not a complete key object.

IDs are16-bit:seed=base;secret=base+16+nonce;transform=base+64+j;
matrix=base+128+8*i+j;row=base+256+32*i;t=base+512+i.
All arithmetic wraps modulo65536. Existing row helper allocates intermediate
IDs inside each32-ID row interval. The ID65500 regression checks wrap.

## Stage5I seed state;coefficient-bank geometry unchanged

The seed source retains 1024 payload bits outside coefficient RAM:rho256,
rho-prime512 and K256,plus validity/level/command control. Seed collection
uses the existing 1024-bit collection register before copying the accepted
result. The sample formatter snapshots its 512-bit seed input as before.
These are logical register dimensions,not fitted resource estimates.

```mermaid
flowchart LR
  H["Shared Keccak raw output<br/>128 bits per accepted beat"] --> C["Collector<br/>8 x 128 = 1024 bits"]
  C --> S["Retained seed material<br/>rho256 + rho-prime512 + K256"]
  S --> F["Message formatter<br/>64-bit absorption words"]
  F --> P["Shared SHAKE / sampler<br/>tagged23-bit coefficients"]
  P --> W["Existing two context packers<br/>4 x 23 -> 92-bit word"]
  W --> M["Existing four banks<br/>1024 words x 92 bits each"]
```

No bank regions or encoded-key buffers are newly allocated by this stage.
The Stage5H layout below is reused for raw/transformed s1,staged matrix rows,
accumulator,scratch and inverse output. The caller still provides FREE
destinations. Raw seed expansion never allocates a polynomial region.
Seed state reset does not imply secure erasure of bank payload RAM.
Future s2/key-output lifetimes require the main-controller schedule.

## Selected architecture — LightHD four-bank storage

**User decision2026-10-20:**follow LightHD's published memory architecture and
reuse schedule. This supersedes the ten-slot/cached-secret and four-slot/
regeneration proposals below. Neither old proposal is selected. The first
implementation includes the tested bank foundation,Stage5E connected sampling
adapter,Stage5F banked NTT DMA/result writeback,Stage5G process DMA and Stage5H
row reuse. The old Stage4 top remains
a scalar regression/synthesis baseline;selector5/bank_ntt uses the new banks.

### Published geometry and our implementation

```mermaid
flowchart TB
  SAM["Sampler<br/>23-bit coefficient stream"] --> PACK["Implemented per-context word packers<br/>2 x92-bit registers;4 x23 per word"]
  NTT["NTT / Pre-NTT / PWM / INTT"] <--> AD["Implemented sequential word DMA/result packing<br/>Pre regrouping remains inside the accepted NTT engine"]
  PROC["Implemented ADD/SUB/P2R DMA<br/>Planned full hash/phase controller"] <--> FUT["Shared compute ownership implemented<br/>Full phase scheduling planned"]
  FUT <--> ARB["bank_poly_store:implemented sampling ownership<br/>64 descriptors;per-bank write acknowledgements"]
  PACK --> ARB
  AD <--> ARB
  subgraph BANKS["memory_banks.sv — implemented and tested foundation"]
    B1["BRAM1 logical bank<br/>1024 words x92 bits<br/>ports A/B,address10 each"]
    B2["BRAM2 logical bank<br/>1024 words x92 bits<br/>ports A/B,address10 each"]
    B3["BRAM3 logical bank<br/>1024 words x92 bits<br/>ports A/B,address10 each"]
    B4["BRAM4 logical bank<br/>1024 words x92 bits<br/>ports A/B,address10 each"]
  end
  ARB <--> B1
  ARB <--> B2
  ARB <--> B3
  ARB <--> B4
  B1 --> RD["Port B checked word readback<br/>92-bit word + owner/domain/bounds metadata"]
  B2 --> RD
  B3 --> RD
  B4 --> RD
```

Source:LightHD SectionIII-B,Figure2,and SectionIV/Figure7. The paper's Figure2
and7 were visually inspected. Geometry is four independent **logical** banks,
not four physical Intel M10Ks. Each bank contains94208 bits=11776 bytes;
total376832 bits=47104 bytes=**46 KiB**. A full23-bit polynomial occupies
64 words=5888 bits=736 bytes. Thus one bank has16 full-width polynomial-sized
regions,and the whole array has64 such capacity equivalents. Actual regions
have phase-specific purposes and some fields use narrower packing.

The new foundation consists of poly_bram.sv(one bank) and memory_banks.sv(four
instances). It has eight independent handshake ports,two per bank. Full-word
writes avoid read-modify-write for individual23-bit coefficients. Lane0 is
word[22:0],lane1[45:23],lane2[68:46],lane3[91:69]. A natural-order polynomial
uses word base+floor(index/4),lane=index mod4. LightHD's Pre regrouping is a
separate address/packing transformation;the bank primitive does not perform it.

| Primitive port contract | Meaning |
|---|---|
| Port indexing |[port][bank];port0=A,1=B;bank0..3=paper BRAM1..4 |
| Request |valid,ready,write1,address10,data92 |
| Read response |Synchronous registered data92,address10,write0,valid/ready |
| Write response |Registered acknowledgement,address10,write1;response data unspecified |
| Backpressure |One response slot per port;can consume old response and accept a new request on the same edge |
| Independent banks |All eight ports can accept simultaneously when addresses/response space allow |
| Same-bank same-address read/read |Both accepted |
| Same-bank same-address pair containing write |A wins that edge;B holds until ready;no device-dependent mixed-port collision |
| Reset |Cancels requests/responses,not memory contents;ownership controller must prevent stale publication |
| Payload validity |Unwritten word data unspecified;primitive has no polynomial/domain/ID checks |

Collision serialization and elastic handshakes are our control implementation;
the paper does not publish complete RTL. Continuous conflicting A requests may
delay B indefinitely;the main scheduler must give bounded port grants. Each
port can otherwise accept one operation per cycle. No physical RAM inference,
M10K count,Fmax or area is claimed before a new synthesis.

### Stage5F compute ownership and packed DMA

keccak_sampler_ntt_banks is the tested sequential owner of bank_poly_store.
Compute descriptors name flat6-bit A,B and destination regions,source IDs16,
result ID16 and operation2. Flat region is {bank2,region4};each region contains
64 natural-order92-bit words. These are caller-selected addresses,not an
automatic whole-algorithm allocator or a second scalar polynomial payload array.

| Step | Ownership/data behavior |
|---|---|
| Accept |Wait until sampler jobs/status drain and external read retires;lease A and B(for PWM) immediately |
| Validate |Read word0 metadata;check committed source/ID,domain,parameter compatibility and actual small bounds for Pre |
| Reserve |Reject destination equal to a used source;otherwise wait for selected region FREE;unrelated completed regions may release |
| Load |One held92-bit word gives four23-bit scalar beats;64 words per unary operation,128 for PWM(A then B) |
| Writeback |Reuse context0 packer after sampling drains;256 scalar results become64 full-word writes through bank port A |
| Publish |Wait for all64 write acknowledgements plus engine completion;inherit source mode/parameter,use result ID and operation-derived domain |
| Retire |Hold completion and protect destination/source regions until its handshake;then source leases clear |
| Reset |Clear leases,descriptors,packers and response ownership;old RAM payload remains unreadable until a new complete job |

Code0=success;1=missing/stale source;2=domain/parameter/Pre-bound violation;
3=destination aliases a used source. A busy distinct destination is backpressure,
not a command error. Internal malformed write/order/count violations raise sticky
fault and require reset. The wrapper blocks external reads during compute and
masks leased sources from complete_o;the store retains their committed metadata
for DMA. There is one storage controller,so no independent client may bypass
these release/read guards. The destination's small flag is recomputed from actual
results;NTT/Pre/PWM set transform domain and INTT sets coefficient domain.

Checked:16 sample jobs,54 operations(30 successful,21 rejected,3 aborted),2944
exact92-bit reads and2952 physical writes/2951 acknowledgements. Thirty successful
computations account for1920 result words;the reset during writeback accepted8
additional words and7 acknowledgements. No phase-specific packed w1/key/hint
allocator or full KeyGen schedule is claimed. Process-block bank routing is next.

### Stage5G process DMA and Power2Round storage

The optional process client in keccak_sampler_ntt_banks shares this same store;
no extra bank or polynomial array is added. It caches two92-bit source words.
Process commands name operation2,A/B regions6,A/B IDs16,result ID16,low/residue
destination6 and high destination6. Opcodes0 ADD,1 SUB,2 Power2Round;3 rejects.

ADD/SUB lease both sources,validate identical domain/parameter metadata,and
reserve one distinct destination. P2R leases A,requires coefficient domain,and
waits for both selected destinations to be free. Destinations must differ from
A and each other;B is ignored for P2R. The controller then allocates packer0 for
residue/low and packer1 for high. Sampling/NTT cannot accept while this client
owns storage. Unrelated completed regions may release to unblock a destination.

| Output | Stored representation | Domain / lifetime |
|---|---|---|
| ADD/SUB |Four23-bit canonical residues/92-bit word;64 words |Same domain as operands;result lease through held completion |
| P2R low |Signed low converted modulo q;four canonical23-bit values/word;64 words |Coefficient domain;eligible for subsequent ordinary NTT |
| P2R high |Zero-extended10-bit high in each23-bit lane;64 words |Coefficient domain;t1 role owned by the schedule,awaiting key packing |

The source mode/parameter are inherited for provenance. They do not mean t1 is
a newly sampled secret. This is an initial full-width temporary layout,not final
10-bit public-key/13-bit secret-key byte packing. No encoded-key buffers are
silently allocated. The source and result regions are retained until explicit
release or reset;phase scheduling will assign their LightHD roles/lifetimes.

Both P2R outputs wait for256 scalar writes and64 acknowledgements each. Low
and high commit on separate internal handshakes,while the public complete mask
hides the pair until both have committed. Reads are exclusive to the client;
destination/source release stays blocked until completion acceptance. Reset
after low commit invalidates both. Actual partial-publication snapshots are
captured and independently checked,including a reset before the high commit.

Status0 success,1 missing/stale source,2 domain/parameter mismatch,3 destination
alias,4 invalid opcode. Busy distinct destinations wait. Internal arithmetic
tag/index/error violations halt the client and all new commands until reset.
Checked:71 process commands,34 successes,33 rejections,4 aborts plus15 real NTT
commands and23 samples. Full row/phase scheduling remains next.

### Stage5H row workspace and destructive accumulator reuse

The tested row layout below is derived for this compute gate,not presented as
LightHD's complete KeyGen address table. The four-bank geometry is unchanged.
Rows are fully staged before arithmetic;the sources are retained through row
completion. The caller selects all region addresses through descriptors.

| Logical bank | Local regions / word addresses | Tested role |
|---|---|---|
| Bank0 / BRAM1 |regions1..7,words64..511 |Raw sampled s1 coefficients,retained for later encoding |
| Bank1 / BRAM2 |region0,words0..63 |One transform-domain row accumulator;freed after inverse NTT |
| Bank1 / BRAM2 |region1,words64..127 |One PWM product scratch;freed after every accumulation |
| Bank1 / BRAM2 |region2,words128..191 |Coefficient-domain row output u;retained for caller consumption |
| Bank2 / BRAM3 |regions0..6,words0..447 |Retained transformed s1,from ordinary NTT or eligible Pre-NTT |
| Bank3 / BRAM4 |regions0..6,words0..447 |One staged matrix row,4/5/7 polynomials;released/restaged between rows |

Negative tests temporarily use region62 for a deliberately wrong-parameter
matrix polynomial. No full matrix or extra encoded-key buffer is allocated.
Future s2,t0,packing and Sign roles must respect the published phase lifetimes;
this provisional row layout is not a final whole-operation allocator.

```mermaid
flowchart LR
  A["Bank3:staged A_hat row<br/>4 /5 /7 x64 words x92 bits"] --> P["Existing PWM engine"]
  S["Bank2:retained s1_hat<br/>4 /5 /7 x64 words x92 bits"] --> P
  P -->|"First product"| ACC["Bank1 region0<br/>64 x92-bit accumulator"]
  P -->|"Later products"| TMP["Bank1 region1<br/>64 x92-bit scratch"]
  ACC --> READ["Cache old A/B words<br/>2 x92-bit registers"]
  TMP --> READ
  READ --> ADD["Modular ADD<br/>overwrite accumulator after reading"]
  ADD --> ACC
  ACC --> INV["Existing inverse NTT"]
  INV --> OUT["Bank1 region2<br/>64 x92-bit coefficient result"]
```

process_inplace_i=1 explicitly allows ADD/SUB only when destination equals A.
The ordinary flag0 path still rejects source aliasing;P2R never allows it.
After source ID/domain validation,the store rebinds A to the new result ID and
marks it WRITING. Private reads may access only untouched words:4*read_word >=
accepted scalar write count. The DMA loads both source words before writing
any lane and advances sequentially;written/partially overwritten words cannot
be reread as old source data. The old A version is consumed;B remains retained.
In-place ADD is exercised in this row gate;in-place SUB is not part of its
workload. Reset invalidates the partially rewritten descriptor,not RAM payload.

The row owner blocks external jobs,compute,reads and releases while active.
All used source descriptors and its three workspace regions remain leased.
Internal scratch/accumulator releases are routed by the row owner;they cannot
free a retained matrix/secret region. The coefficient output becomes visible
only at whole-row completion and cannot release until that completion retires.
Busy/overlapping workspace is rejected before arithmetic rather than waited on.
Completed rows free accumulator/scratch and retain output/sources. Stage5H
checks6918 old-word reads and12544 exact public word responses without adding
payload RAM. Full phase scheduling and physical RAM inference remain future.

### Figure2 region map — peak Sign configuration

Offsets below are92-bit **word addresses**,derived from the figure's stacked
region depths. This is the published Sign-phase layout,not a claim that the
paper supplies a complete KeyGen address/FSM table. Unused regions and buffer
depths depend on level and phase.

| Paper bank | Word addresses | Depth | Figure2 role |
|---|---|---:|---|
| BRAM1 |0..447|448|y,seven polynomials |
| BRAM1 |448..959|512|s2,eight polynomials;secret cache region |
| BRAM1 |960..1023|64|Remaining region |
| BRAM2 |0..63|64|One reusable row accumulator /w0 temporary |
| BRAM2 |64..575|512|t0,eight-polynomial secret/transform cache |
| BRAM2 |576..1023|448|Other seven w0 components |
| BRAM3 |0..447|448|s1,seven-polynomial secret/transform cache |
| BRAM3 |448..895|448|Transformed y,seven polynomials |
| BRAM3 |896..1023|128|Packed w1 region |
| BRAM4 |0..447|448|z,seven polynomials;phase-reused matrix buffering |
| BRAM4 |448..511|64|Transformed challenge;phase-reused matrix buffering |
| BRAM4 |512..1023|512|w0-c*s2;phase-reused matrix buffering |

### Scheduling that the controller must implement next

- Retain s1,s2,t0 for subsequent signing;after their initial transforms,lock
  transformed secret regions for reuse in retries/future operations as permitted
  by the current key. Domain metadata must distinguish raw and transformed data.
- Generate matrix entries into a bounded BRAM4 staging region while earlier
  entries are consumed. The paper specifies a9-polynomial circular A buffer
  for levels2/3;do not extend that number to level5 without deriving its schedule.
- Compute matrix-vector products **row by row**. Reuse the same64-word BRAM2
  accumulator region across columns,then INTT/process/store the completed row
  before reusing it. This avoids retaining all product polynomials.
- Interleave A and s2 sampling during KeyGen to respect A staging capacity.
  Sampling/NTT overlap and early launch come with their port/ownership proofs;
  the current legacy sequential top does not provide them yet.
- Preserve final FIPS204 seed/hash/key bytes with level2/3/5 labels. The paper's
  pseudocode is not the selected byte-exact standard contract.

KeyGen offsets and release/overwrite times must be derived from its actual
live ranges,then checked before connection. A bank capacity decision does not
authorize an unproved overwrite. Extra7488-byte encoded-key buffers from the
old proposal are not automatically allocated. The paper does not define our
external key-byte transport;its final-standard packer/delivery contract will be
specified when the controller is connected.

### Stage5E connected sampling and ownership — implemented

`keccak_sampler_banks.sv` connects the real Keccak/sampler helper to
`bank_poly_store.sv`,which owns the same four memory_banks instances. The caller
chooses bank[1:0] and region[3:0] at job acceptance. Each region is one aligned
64-word polynomial. This is controller-addressed storage,not an automatic
free-list allocator. Role assignment for the complete KeyGen/Sign schedule
remains future work.

| Stored control | Dimensions | Purpose |
|---|---|---|
| Region descriptors |64 entries x33 logical bits|state2,mode2,parameter2,ID16,count9,domain1,bounded1 |
| Context-to-region ownership |Two valid bits plus two6-bit region numbers|Bind each live sampling core to its destination |
| Word packers |Two92-bit words plus full/sent flags and6-bit word indices|Keep interleaved contexts' partial coefficients separate |
| Acknowledgement counts |Two7-bit counters|Count0..64 committed write responses |
| Pending bank writes |Four valid bits plus four owner bits|At most one packed word awaiting acknowledgement per bank |
| Read response |92-bit data plus35 metadata/error bits|Hold address,ID,mode,parameter,domain,bounded flag and error under stall |

Natural-order coefficient index i writes lane i mod4 of word floor(i/4).
Only a complete group of four coefficients creates a bank write. The write
address is `{region4,word6}`. A full packed word stays stable until its bank
write acknowledgement returns;the selected context pauses rather than
overwriting it. Other already-packed words and the read port may progress;
the sampler's shared output can still stall behind its held context. Requests to
the same bank choose context0 first;each sampling job is bounded to256 values.

Publication requires **all** of:

1. 256 canonical,correctly indexed/tagged coefficients,with last only at255.
2. 64 packed writes acknowledged;no complete word remains pending.
3. Successful matching external sampling status handshake after hash drain.

The64-bit reserved/complete masks distinguish FREE,WRITING and COMPLETE regions.
Expected sampling errors free the reservation once pending full words drain;
partial packing is discarded. Normal backpressure is not an error. Wrong owner,
noncanonical/misframed/extra coefficients and premature/wrong-ID success set
sticky fault;publication/new work halt until coordinated reset. These are
internal protocol violations,not ordinary parameter-error responses.

Public read commands name bank2,region4,word6. Only COMPLETE regions return
data. Other requests return an error with zero ID/mode/parameter/domain/bounded
metadata. The controller has one outstanding checked read:request -> synchronous
bank response -> held external92-bit response. It checks the returned bank
address/type and snapshots owner metadata. A new read waits until the previous
response is consumed. Release waits for any matching read/response,and a
same-edge accepted read has priority over release. Successful release marks
the region FREE without clearing RAM. Reset invalidates descriptors,context
packers and pending responses;old RAM bits cannot become readable as a new job.

This path does not yet implement NTT source leases,compute-result writeback,
in-place row accumulation or the LightHD Pre regroup adapter. Narrow packed
w1/key/hint fields also need their own range/phase ownership policy;these
aligned canonical-polynomial descriptors do not define it. Those must be
connected before replacing the old Stage4 all-engine top. No new synthesis or
physical RAM mapping is claimed.

Measured:104 jobs,88 successful polynomials,8 expected parameter errors,8 reset
aborts.23173 input comparisons=22528 completed coefficients+645 aborted prefixes.
5792 packed writes=5632 completed words+160 aborted-job words.5790 acknowledgements
=5632 completed words+158 aborted-job words;two writes are reset before their
acknowledgements are accepted. Five accepted prefix coefficients never form a
full word. All5632 completed92-bit words read back exactly(22528 coefficients).
All64 regions fill,then are protected/reused across the workload;24 combinations
of core/mode/parameter are observed. Witnesses:8 occupied-region stall cycles,
1070 held-read cycles,50 read/coefficient-write overlaps,2 resets of held valid
read responses(successful and error),11 invalid reads. Eight injected protocol
fault kinds are contained;12 Python capture corruptions are rejected.

### Stage5D foundation verification

14872 accepted requests,14864 responses:9509 exact92-bit reads,5355 write
acknowledgements,and8 accepted writes whose pending acknowledgements are reset.
Eight additional blocked request offers are canceled without acceptance. All
4096 bank words are initialized and read;random traffic covers both ports/all
banks. Payload retention and canceled-write absence are checked after reset.
Witnesses:73 collisions serialized,4112 dual same-address read pairs,1031 cycles
with all eight ports accepting,3075 request stalls,3034 response stalls and14807
response replacements. Twelve checker corruptions are rejected. No keygen/
main-top migration,BRAM mapping or full-operation output is claimed by this gate.

## Preserved Stage4 implemented memory — four-slot configuration

The diagram below describes `src/controller/memory.sv` inside
`keccak_sampler_ntt`. It shows logical storage and interfaces. Physical M10K
packing for this subsystem has not been measured. Four slots are four regions
of **one declared1024 x23-bit array**,not four independently accessible RAMs.

```mermaid
flowchart TB
  C["Controller commands<br/>allocate / finish / release / execute"]
  S["Sampler<br/>data23 + index8 + core1 + ID16 + last"]
  N["NTT result stream<br/>data23 + index8 + last"]
  R["Read owner mux outside memory.sv<br/>public inspection OR NTT DMA<br/>slot2 + index8"]
  subgraph MEM["memory.sv — shared polynomial pool"]
    META["Slot metadata:4 entries x36 bits<br/>ownership / state / count / domain / bounded flag"]
    CTRL["Allocation / validation / source locks<br/>compute reservation and commit"]
    WA["One write-port selector<br/>NTT result priority,otherwise sampler<br/>23-bit word;flat10-bit address"]
    subgraph PAY["payload_r:1024 words x23 bits =23552 bits =2944 bytes"]
      P0["Slot0:256 x23<br/>word addresses0..255<br/>736 bytes"]
      P1["Slot1:256 x23<br/>word addresses256..511<br/>736 bytes"]
      P2["Slot2:256 x23<br/>word addresses512..767<br/>736 bytes"]
      P3["Slot3:256 x23<br/>word addresses768..1023<br/>736 bytes"]
    end
    RD["One synchronous read port<br/>flat address=slot*256+index"]
    RESP["Elastic response register<br/>data23 + metadata32 + valid1 =56 bits"]
    EX["Compute state9 bits<br/>held reservation reply6 bits<br/>sticky fault1 bit"]
  end
  O["Read response owner mux outside memory.sv<br/>public output OR23-bit NTT input"]
  C --> CTRL
  CTRL <--> META
  CTRL --- EX
  S --> WA
  N --> WA
  META -. "write permission and destination" .-> WA
  WA --> PAY
  R --> RD
  PAY --> RD
  RD --> RESP
  META -. "snapshot ID,domain and parameter" .-> RESP
  RESP --> O
```

Arrows into the pool use one selected write address;the four slot boxes are
not parallel write ports. A read accepts at most one request per cycle,and its
response is available after the clock edge. A blocked response prevents another
read unless it is consumed on that edge. The legal source/destination states
prevent reading a partially written slot. Engine-private FIFOs are separate.

### Storage and bus dimensions

| Storage/interface | Width | Depth / count | Contents and role |
|---|---:|---:|---|
| Shared coefficient payload |23 bits|1024 words|Four256-coefficient polynomials |
| Per-slot metadata |36 bits|4 entries|Fields below;not included in2944 payload bytes |
| Read response |56 bits total|1 entry|23 data +32 metadata/error +1 valid |
| Compute ownership state |9 bits|1 operation|active1,opcode2,A-slot2,B-slot2,destination2 |
| Compute reservation reply |6 bits|1 entry|valid1,code3,slot2 |
| Protocol fault |1 bit|1|Sticky until coordinated reset |
| Read/write coefficient index |8 bits|Each transaction|Index0..255 within slot |
| Slot selector |2 bits|Each transaction|Slot0..3;not a job ID |
| Flattened word address |10 bits|Each payload access|slot*256+index;no byte-address bus |

Metadata per slot:state2,mode2,parameter2,core1,poison1,ID16,count9,
compute-destination1,NTT-domain1,small-coefficient1 =36 bits. Four entries use
144 logical bits. Response metadata/error32 =slot2+index8+ID16+mode2+parameter2+
domain1+error1. The dimensions count declared logical fields,not fitted area.
For another SLOTS value,slot/address widths and metadata total change.

### What enters and leaves

1. **Sampler allocation:**reserve FREE slot;capture core/ID/mode/parameter.
   The output slot number tells the controller where the polynomial will live.
2. **Sampler writes:**tagged23-bit coefficients enter in order0..255. Their
   tags select the reserved slot. Memory checks canonical value,index and last.
3. **Sampling publication:**matching successful retirement plus256 prior writes
   changes WRITING to COMPLETE. Receiving coefficient255 alone is insufficient.
4. **NTT operation:**validate and lock one/two COMPLETE source slots as IN_USE;
   reserve a distinct FREE destination as WRITING. DMA reads source coefficients
   through the one response path and passes them to NTT. PWM loads A then B.
5. **Writeback:**256 tagged-by-reservation NTT results use the write selector.
   Engine completion commits the destination and unlocks the source slots.
6. **Inspection/release:**read COMPLETE slots via the public response;release
   only after consumers finish and no same-slot response remains pending.

Sampling and NTT are scheduled sequentially in the current top. The memory
write selector defines result priority,but does not itself implement concurrent
system scheduling. Allocation/execute replies and coefficient read responses
are separate handshakes. Faults invalidate affected work and require reset.

### Other storage boundaries

| Location | Logical storage | Relationship to the shared pool |
|---|---|---|
| Keccak |Two1600-bit permutation states plus input/output/control registers|Produces tagged128-bit hash beats;not polynomial slots |
| Keccak-to-sampler bridge |Two128-bit payload entries plus byte-count/core/pointers|Temporary hash beats,not persistent polynomials |
| Sampler |Per-context parsing/collection state;Ball512 x2-bit memory|Private implementation;see sampler SPECIFICATION.md |
| NTT coefficient FIFOs |32 x92,32 x92,16 x92 bits|Private working words,each packs four23-bit coefficients |
| NTT second PWM operand |64 x92 bits|Private256-coefficient operand copy |
| Seed collection |128-byte expansion result:rho32,rho-prime64,K32|Implemented in keygen_seed_collect;separate from polynomial pool;focused shared-service gate PASS |
| Encoded keys/signatures/message buffers |Not implemented or sized yet|Require an explicit storage/interface decision |

Do not sum these logical capacities into a physical M10K claim or assume they
replace encoded-key storage. Reset of the pool clears ownership and response
validity,not the payload;it prevents stale publication and is not secure erasure.

## Superseded ten-slot proposal — not selected or implemented

The earlier recommendation was to instantiate the configurable pool with **10 slots** for the
first full KeyGen controller,cache all transformed s1 polynomials,and add
separate addressed byte buffers for encoded public/secret keys. This proposal
was superseded by the user's LightHD memory decision above;the legacy connected
top remains at four slots until migration.

| Proposed storage | Logical capacity | Reason |
|---|---:|---|
| Polynomial pool |10 x256 x23 =58880 bits =7360 bytes|Largest l=7 cached transforms plus3 temporary slots |
| Public-key buffer |2592 x8 bits =2592 bytes|Largest level5 encoded public key;hash it to form tr |
| Secret-key buffer |4896 x8 bits =4896 bytes|Retain encoded secrets/t0 while tr is produced;deliver only after completion |
| Expansion collector |128 bytes|rho32,rho-prime64,K32;not polynomial slots |

This is14976 logical data bytes in total,excluding metadata/control and other
engines' private storage. Physical RAM block use is not measured. Compared to
the current four-slot payload,the ten-slot pool adds4416 logical bytes.
No signature/message buffer is included;Sign/Verify schedules may require
additional capacity and a separate decision.

| KeyGen phase | Largest live polynomial set |
|---|---|
| Build s1 cache |Already cached transforms + current sampled s1 + new transform;at most l+1 |
| Multiply a later matrix column |l cached transforms + accumulator + current A_hat + product =l+3 |
| Accumulate |l cached transforms + old accumulator + product + new accumulator =l+3 |
| Inverse row |l cached transforms + transform accumulator + INTT output =l+2 |
| Add s2 |l cached transforms + INTT output + s2 + resulting t =l+3 |
| Round/pack row |l cached transforms + t;stream both t1/t0 into key buffers before releasing t |

Pack each sampled s1 into its secret-key buffer position before releasing its
coefficient slot;keep only its transform in the cache. Pack s2 likewise before
releasing its temporary slot. Matrix entries are generated on demand and freed
after PWM. Source/result slots stay distinct. Modular ADD and round/pack routing
are still unimplemented;this table sizes their required lifetime rather than
claiming a completed schedule.

Cached s1 needs l forward transforms:4/5/7 for levels2/3/5. Regenerating it for
every row requires k*l=16/30/56. This recommendation saves12/25/49 forward
transforms and the corresponding repeated sampling;PWM/INTT counts are unchanged.
These are algorithmic counts,not measured cycle reductions.

Proposed byte offsets are public key rho[0..31],then t1 row i at32+320*i;
secret key rho[0..31],K[32..63],tr[64..127],then s1 at128,s2 at128+l*eta_bytes,
and t0 at128+(l+k)*eta_bytes. eta_bytes is96 or128 by parameter. Fill tr after
hashing the complete public key. Keep key-valid false until all fields are
written and checked;reset cancels pending keys. External command/key-transfer
ports will be specified before implementation;these offsets are internal.

Alternative:keep four slots and the same encoded-key buffers,but regenerate
s1 for each row as below. This saves coefficient capacity at a higher compute
cost. Neither alternative is adopted by merely documenting it.

## Earlier four-slot KeyGen live-range proposal - not implemented

Level2 needs k=l=4. Four slots are sufficient for a sequential mathematical
row schedule if secrets are regenerated when needed and results are delivered
to a separately defined key-output destination. This differs from caching all
four s1 polynomials and their transforms. No expanded memory allocation or
key-output protocol is approved by this proposal.

| Step in row i,column j | Live polynomial roles at peak | Action releasing capacity |
|---|---|---|
| Sample A_hat[i,j] and s1[j];transform s1[j] |Accumulator,A_hat,s1,s1_hat:4 |Release coefficient s1 after transform;regenerate it for later rows/key encoding|
| PWM(A_hat,s1_hat) |Accumulator,A_hat,s1_hat,product:4 |Release A_hat and s1_hat after PWM|
| Add product into NTT-domain accumulator |Old accumulator,product,new accumulator:3 |Release old accumulator/product;first column can keep product directly|
| Finish row |Accumulator,INTT result:2 |Release transform accumulator|
| Add sampled s2[i] |INTT result,s2,t:3 |Release INTT result and s2|
| Power2Round/pack |t plus external key-output storage |Release t only after both t1/t0 are delivered safely|

For this regeneration schedule,level2 uses16 forward transforms,16 PWM,12
transform-domain additions,4 inverse transforms and4 coefficient-domain error
additions. Cached s1_hat would require only4 forward transforms;the extra12
transforms are an explicit tradeoff,not an unnoticed throughput result.
These are logical operation counts,not measured hardware cycle counts.

Key output is a separate unresolved lifetime:pk needs rho and all t1 rows;
sk needs rho,K,tr,s1,s2,t0. tr depends on the complete encoded pk. t0 rows must
survive until written in the chosen output/key-storage protocol. A four-slot
coefficient pool does not itself store all encoded keys. Options to review are
addressed key-byte output or explicit byte storage;neither is implemented yet.

Raw SHAKE now has an optional finite-output route in keccak_sampler and a tested
seed collector. Raw jobs reserve a core but do not allocate polynomial slots.
Sampling jobs still publish through the memory status contract. The current
Stage4 top explicitly disables the optional raw route until the main-controller
connection is added. No second dual-core engine is instantiated by this service.
Final FIPS204 bytes are selected with level2/3/5 names. LightHD's four-bank
memory is now selected above;the earlier proposals are superseded. Main key-output
transport still needs specification. The preserved Stage4 top remains on its
old scalar pool until the verified foundation is connected through new adapters.

## Stage4 extension:NTT ownership and writeback

The approved four-slot capacity is unchanged. memory.sv now adds a sequential
compute reservation,source locks and a distinct result writer,used by
keccak_sampler_ntt.sv. The preserved Stage3 wrapper explicitly disables these
ports;its regression still checks the earlier sampling-only contract below.

Slot states are now FREE,WRITING,COMPLETE and IN_USE. Compute reservation
validates source state,expected IDs,domain,parameter agreement and bounded
Pre eligibility before changing ownership. Invalid commands return code1 or2
without allocation/engine activity. Valid commands wait for a free destination
and for an old read response to drain. The helper protects source release
immediately on command acceptance,including the destination-capacity wait.
Unrelated completed slots can still be released to supply capacity.
At reservation,sources transition COMPLETE -> IN_USE;
the destination transitions FREE -> WRITING. PWM may read one source twice.

Locked slots cannot be released/reallocated. The internal DMA may read IN_USE
slots;the public read path waits during compute. The helper accepts compute
commands only after active sampling contexts retire,and pauses new sampling
until completion is accepted. Consequently the first schedule is sequential.
The RAM's result write has priority over a sampler write;if a future scheduler
permits overlap,it must verify that arbitration and revise this contract.

After256 correct result writes and engine done,destination becomes COMPLETE
and sources return COMPLETE. Reset invalidates all roles and pending replies.
An internal write/ordering fault prevents valid publication and requires reset.
No partially written result is readable as a completed polynomial.

Domain is now an explicit metadata bit,independent of original sampling mode.
For example INTT(A) retains mode=A but has coefficient-domain output. Compute
results inherit source A's mode/parameter and receive the new result job ID.
NTT/Pre/PWM output is transform-domain;INTT output is coefficient-domain.
The per-slot bounded flag is accumulated from actual values,including writeback.

Source interfaces,run commands and measured Stage4 gates are in the shared
SPECIFICATION.md,REFERENCE_VERIFICATION.md and INTEGRATION_VERIFICATION_TESTPLAN.md.
There is no new fitted PPA/physical RAM-packing result for this extension.

## Preserved Stage3 sampling contract

The user approved the simple four-slot pool on2026-10-20. It is implemented in
src/controller/memory.sv and connected through keccak_sampler_memory.sv.
Functionality-first integration continues;PPA optimization is deferred until
correct full-operation outputs. No Stage3 synthesis/PPA result is claimed.

The implementation uses a configurable shared pool of four polynomial slots, simple
arbitration and sequential NTT scheduling. This is an initial integration
configuration, not the final capacity for full KeyGen/Sign/Verify.

| Item | Implemented contract |
|---|---|
| Polynomial |256 coefficients,23 bits each|
| Initial capacity |4 slots;4 x256 x23=23552 coefficient bits=2944 bytes|
| Slot address |2-bit slot number plus8-bit coefficient index|
| Allocation |Reserve a free slot before accepting a sampling job|
| Ownership |Record actual assigned core,job ID,mode and domain for that reservation|
| Sampling states |FREE,WRITING,COMPLETE;only FREE slots may be allocated;Stage4 adds IN_USE for compute sources|
| Writes |Accept only the owning job's next coefficient;check index,last and count|
| Completion |Exactly256 accepted coefficients plus successful matching status|
| Reads |Only COMPLETE slots return valid payload;other requests return an error response;ready/valid holds stalled responses|
| Release |Explicit controller release after all scheduled consumers finish|
| Errors/reset |Invalidate affected partial slots;reset clears metadata rather than bulk RAM contents|
| Arbitration |Shared sampler write stream plus independent synchronous read port;read wins a simultaneous same-slot release;pending responses block release|

Three slots allow two retained PWM operands and a separate result destination.
A fourth provides another reservation for the producer. This does not promise
unrestricted simultaneous dual-job sampling and NTT operation. If all slots
are reserved, stall new commands. First schedules will be serial;derive larger
capacity and ports from actual algorithm live ranges before supporting overlap.

The arithmetic above counts coefficient storage only. Metadata, handshake
registers and physical FPGA RAM packing add resources;no M10K/area result is
claimed before implementation and measurement. These are logical slots, not
a promise of four physical RAM blocks or a particular banking layout.

## Domain and interface obligations

The sampler emits tagged23-bit coefficients with8-bit index and last flag.
Retirement status follows SHAKE drain;receiving the last coefficient alone
must not publish a polynomial as valid. Job IDs can be reused after retirement;
slot ownership and lifecycle must prevent old contents from being mistaken
for a new polynomial.

Matrix A values are already in the transform domain. Secret/mask/challenge
polynomials begin in the coefficient domain. Preserve this distinction in
metadata;NTT representation/scaling metadata will be finalized in Stage4.

Successful status and slot commit are the same external handshake. Status
stall keeps the slot WRITING even after coefficient255. Ordinary sampler errors
free the reservation. An owned malformed write is consumed but poisons the slot;
wrong-owner traffic and premature success also raise sticky fault_o. A poisoned
slot cannot become COMPLETE. fault_o is an internal protocol failure,requires
coordinated reset,and must be handled by the future controller;it is distinct
from an expected sampler parameter-error status. Read errors are ordinary
responses and do not set fault_o. Error-response data is unspecified;ignore it.

Reads are synchronous with one response register,which can be replaced on the
same edge the previous response is accepted. Metadata is captured with each
read,so stalls cannot change its ID,domain or parameter. Reset clears metadata
and pending responses,not payload RAM;this provides validity isolation,not
secure erasure. Do not interpret two-bit slot addresses as permanent job IDs.

Read-only inspection of ntt_v2:src/ntt_LightHD/ntt_engine.sv confirms one23-bit
coefficient per accepted beat. NTT/INTT load256 values;PWM loads256 A followed
by256 B;results stream256 values with backpressure. Do not import that package
or implement its controller until Stage4. Memory has no dependency on its
internal bank organization.

## Stage3 verification gate

- Feed independently checked SHAKE-sampler jobs into allocated slots;read back
  and compare all256 coefficients,IDs,indices and domains.
- Interleave both contexts with different jobs and hold input/read/status
  handshakes;verify no mixing,overwrite or changing stalled response.
- Reject reads before successful retirement,including after coefficient255.
- Exercise pool exhaustion,explicit release and reuse with different contents.
- Inject expected parameter errors and reset during partial writes/read stalls;
  prove no partial or stale polynomial becomes readable afterward.
- Preserve the existing Stage2 checker and standalone module tests.

## Measured Stage3 source results

104 jobs:88 complete,8 expected errors,8 reset aborts.23180 input coefficients
match independently computed expectations:22528 complete values plus652 aborted
prefix values. All88 successful slots are read back exactly once:22528 values,
including ID,index,mode,parameter and domain.88 explicit releases and99 invalid
reads pass. Full-pool blocking is witnessed for8 cycles,read-response stalls
for1321 cycles and concurrent read/write for170 cycles in this workload.

The companion memory_protocol_test uses SLOTS=3 to check non-power-of-two bounds.
It rejects8 fault kinds:wrong index,wrong last,noncanonical value,wrong write ID,
premature success,simultaneous early write/success,extra257th coefficient,and
wrong finish ID. It also checks consecutive read-response replacement,
simultaneous same-slot read/release priority and reset of a stalled valid read.
The integrated test resets partial writes and a pending error response,checks
post-reset invalid reads,and reuses IDs with different messages.

The separate Python lifecycle checker confirms ownership,commit/release/reset,
all stored outputs and exact totals.12/12 deliberately corrupted captures are
rejected. The preserved Stage2 regression also passes104 jobs/23089 values and
12 checker faults. See REFERENCE_VERIFICATION.md for commands and evidence.
