# Dilithium specification

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
