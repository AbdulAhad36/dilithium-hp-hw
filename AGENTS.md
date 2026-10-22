# Agent onboarding - integration

LATEST Stage5N.3:sign_process_dma connected to main-owned dilithium_services
through nested sign request/response records,row wrapper and bank arbitration.
One existing memory tree;no polynomial/key RAM or external top ports added.
KeyGen drives sign='0;main Sign/Verify remain unsupported. New DMA checks
every source read's owner/region/word/level/coefficient-domain/retained mode,
validates high23 before6-bit narrowing,and stores negative low19 modulo q.
CNB returns polynomial OR,Mhint writes0/1 and returns9-bit polynomial weight.
No in-place signing writes. Sources/results leased through held done;both
Decompose results publish after all64 word ACKs and both finish handshakes.
Late read/data/high errors drain/discard tentative allocations via nonzero
finish and clear process packet/reduction state;same-ID recovery is tested.
Focused DMA PASS:71 commands/65 completions/21 expected errors/6 resets;
14284 exact scalar writes/3570 packed ACKs,including1108/276 reset prefixes;
32 checker corruptions rejected. Shared service PASS:33 commands/30 completions/
9 expected errors/3 resets;192 sampled source words/768 exact result words;
33 checker faults. All levels2/3/5;actual SHAKE/sampler sources/shared banks.
Row/NTT/scalar/pending-read priority,held ownership and atomic publication pass.
Selectors sign_dma/sign_service use existing run.do/single Python script.
Current token:b224a41318be58d790ee39d066ce6d27290538fdf003a7ea282e7162265a86ac.
All six current-source gates PASS:sign_dma,sign_service,sign_process,
bank_process,full_keygen,nist_keygen. Local fullKeyGen8/3rejects/5aborts/
37 checker faults;official NIST75/75 keypairs/433600 exact bytes/41 faults.
All48 other prior RTL files/6.757ns unchanged. Only five previous RTL files
change(service types/wrappers and KeyGen zero assignment),plus new DMA.
Frozen evidence:evidence/stage5n3_sign_memory.zip +.sha256,create-only;
preserve prior archives. Details in REFERENCE_VERIFICATION.md.
Next Stage5N.4:signing key/input decode and hash formatting with independent
byte/field checks;then vector norm/hint reduction,retry and signature packing.
Stage5N overall unfinished. Keep functionality first/shared LightHD engines/
four-bank memory and6.757ns SDC. No PPA/netlist/UVM stage advance,commit or
branch operation. Ask only material decisions;routine choices delegated.
Universal docs updated;preserve all immutable archives. Historical status below.

LATEST Stage5N.2:working process/decompose.sv,decompose_x4.sv,cnb.sv,mhint.sv,
sign_process.sv. One elastic x4 transport,64 ordered groups/polynomial;
op0 Decompose,1 CNB,2 optimized low/high Mhint. Canonical23-bit inputs;
Decompose low is signed19-bit,high6. CNB kind0/1/2 = z/r0/ct0 bounds.
Lock ID/op/param/relevant kind;last iff63. Errors zero result and flush packet;
reset cancels held result/tracker/prefix reductions. Per-polynomial CNB sticky
OR and hint count9;vector reduction/retry/control remain later work.
Focused PASS:7752 accepted/7746 outputs/45 expected errors/6 aborted groups/
117 full packets(53 Decompose,44 CNB,20 Mhint),27 checker corruptions rejected.
30996 Python/C lane fixtures PASS;C decomposition exhaustively passes8380417
canonical inputs at each level. Do not call RTL tests exhaustive.
Early CNB failure followed by passing groups,reset after nonzero prefix,
isolated changing-op metadata and hint count256 are explicitly checked.
Three current gates PASS:sign_process,full_keygen8/3/5/37 checker faults,
nist_keygen75 keypairs/433600 bytes/41 checker faults. Source token:
9c78215f9e0edec3dfd474b7999acd338ba37a30f6ab46c46d9ed4ed55d19bd2.
All48 prior RTL files/6.757ns unchanged;full-key event streams equal Stage5N.1
excluding freshness. No current-source rerun claim for older diagnostic gates.
Immutable evidence:docs/dilithium_docs/evidence/stage5n2_sign_process.zip and
stage5n2_sign_process.sha256;create-only,preserve prior archives.
New selector sign_process uses same run.do/single Python prepare/compare/selftest.
No integration into main Sign/memory DMA yet. Main Sign/Verify unsupported.
Next Stage5N.3:checked shared-bank DMA/leases/acknowledged publication for x4
processes;coefficient domain/owner/parameter checks;canonical low conversion;
full stored-high validation before narrowing;error/abort/private partial data.
Then signing input/key decode/hash/vector reduction/retry/signature packing.
Stay within Stage5N;do not claim full Sign or start full UVM/PPA/netlists.
No commit,branch operation or synthesis. Ask about material scope/interface/
resource departures;routine shared LightHD-compatible choices are delegated.
Earlier status paragraphs below describe historical accepted milestones.

LATEST Stage5N.1:main dilithium.sv owns dilithium_services(one existing
keccak_sampler_row RAW_SERVICE=1 and one Bitpkg). keygen/keygen_encode are
clients;new helpers/dilithium_service_pkg.sv defines packed full-width ports.
No additional engine/bank/key RAM or request/response pipeline is introduced.
keygen_owner covers DISPATCH and child_busy,including post-done cleanup while
main is IDLE. Unowned requests zero;responses/faults remain visible.
Full-key TB verifies routed requests,unowned quiescence and cleanup lifetime.
Current gates PASS:full_keygen8/3rejects/5aborts/37faults;
nist_keygen75pairs/433600bytes/41faults;keygen7/3/4,34rows/172304writes/
8448reads/29faults;rounded_keygen7/3/4,34rows/190224writes/12800reads/36faults.
Source token830c05c8b16215688d1923497ed1b147ecf6b2aea526d4cf54688e8a0ab4a345.
Q local988082owned/195cleanup/52idle;NIST9142284/2225/151. Local campaign
6676943064ps unchanged. All local/NIST events equal Stage5M except token/Q.
All25 engines,row wrapper,Bitpkg and6.757ns unchanged. No PPA/synthesis claim.
Frozen evidence:docs/dilithium_docs/evidence/stage5n1_shared_services.zip and
stage5n1_shared_services.sha256;create-only,preserve previous archives.
Next Stage5N.2:working Decompose x4,CNB,Mhint blocks with independent Python/C
boundary tests;then shared DMA,signing input/key decode/hash/retry/packing
substeps. Sign/Verify are still unsupported;Stage5N is not complete overall.
Never duplicate accelerator trees or add fake sign/verify placeholders.
Preserve complete KeyGen/NIST gates. Four gates above are freshly rerun;
other historical focused results stay in prior archives. Same launcher/script
and universal docs. No commit,branch operation or synthesis in this stage.
Ask the user about material scope/interface/resource departures;routine
LightHD-compatible choices are delegated. Earlier milestone text is historical.

LATEST Stage5M:all75 official NIST ACVP KeyGen cases PASS,25 each at
ML-DSA-44/65/87(level2/3/5).54200 exact64-bit key words/433600 bytes,
18300 PK hash words,4800 tr bytes,112000 field-read metadata records.
39/39 checker corruptions rejected. nist_keygen uses the same run.do,
dilithium_vectors.py and tb_full_keygen(NIST_VECTORS=1);expected keys are
copied directly from pinned NIST JSON,not generated by C/Python.
Corpus:NIST/ML-DSA-keyGen-FIPS204;commit2972def23bf9f3680c2c531561ed9bdd0f1086ad.
Raw files have script-pinned SHA256 and provenance.json. All75 C pairs also
agree with NIST. Source token22f42dd20700ee8b0e014dee66c45118bcb0edc647f8ded54949f658bd0a6461.
The local full_keygen gate freshly repeats8 success/3 rejects/5 aborts and
35 checker faults on that token. These two current gates pass;the prior
all16-gate result is preserved in Stage5L,not claimed freshly rerun here.
All46 RTL SV files and6.757ns SDC unchanged from Stage5L.
Frozen evidence:evidence/stage5m_nist_keygen.zip and stage5m_nist_keygen.sha256
under docs/dilithium_docs;create-only,preserve earlier archives.
Next Stage5N:shared-resource Sign integration,remaining Decompose/CNB/MakeHint
and signing control in bounded steps. Expose existing datapath/packer ownership
at main-controller arbitration;never duplicate whole accelerator trees.
Keep full-KeyGen/NIST byte tests passing. Ask for material scope/interface/
resource departures;routine LightHD-compatible choices are delegated.
No Sign/Verify implementation,full UVM/PPA advance,commit/branch operation,
synthesis or netlist run is claimed/authorized by this stage.
Earlier Stage5L and older status statements below are historical milestones.

Current Stage5L:FULL_KEYGEN=1 on dilithium/keygen implements complete encoded
PK/SK output through helpers/keygen_encode.sv,using existing banks/Bitpkg/raw
Keccak. It enables P2R,accepts internal rows,hashes full PK into64-byte tr,
then emits SK. Separate host/hash word acknowledgements prevent duplicates.
No encoded-key RAM or second hash engine. Default0 preserves diagnostic modes.
key_valid/ready,data64,bytes4,type1,index10,last1,ID16 ports now exist.
External polynomial inspection is disabled in full-key mode.

Selector5/full_keygen passes8 complete C-reference keypairs(all3 levels),
3 expected rejects,5 reset aborts;5433 exact output words,2058 hash words,
656 tr bytes,11179 read-metadata records.35 checker corruptions reject.
434 host-ahead/1939 hash-ahead cycles witness independent acknowledgement order.
Test randombytes injects xi into unchanged C crypto_sign_keypair;13 valid
fixture seeds produce complete expected pairs. These are local reference
vectors,NOT official downloaded NIST conformance yet.
All16 focused integration gates and their checker fault tests freshly PASS on
source token b4c3284a2fe1cacad64c73cde32f43674e3ad3c17fd04b6197bd033a0b6b55b6.
Frozen evidence:docs/dilithium_docs/evidence/stage5l_full_keygen.zip and
stage5l_full_keygen.sha256;create-only,preserve all earlier archives.
Next Stage5M:official NIST KeyGen vectors/provenance and exact comparison;
then Sign/remaining LightHD blocks/Verify. No PPA/UVM-stage advance until
required supported outputs. No commit/branch/netlist/synthesis authorized here.
When adding Sign/Verify,lift/expose the existing datapath/packer ownership to
main-controller arbitration;operation FSMs must share the current engines and
banks,not instantiate duplicate accelerator trees. Keep whole-KeyGen byte
tests passing through that future refactor.
Older Stage5K planned-interface statements below are historical;Stage5L above
is current. Keep all immutable archives and accepted engine sources.

Stage5K frozen evidence:all15 focused gates,independent comparisons and checker
fault tests freshly PASS on one source token. Preserve create-only archive
docs/dilithium_docs/evidence/stage5k_rounding_bitpkg.zip and SHA256 sidecar.

User direction reaffirmed2026-10-21:reconstruct LightHD's complete controller,
shared processing blocks and four-bank reuse schedule;improve measured
weaknesses and adapt interfaces for our accepted engines. Make routine
architecture choices that support that goal;do not repeatedly ask for them.
Do not claim source-identical reconstruction from an incomplete paper or treat
compatibility changes as measured PPA improvements.
Selected full-key output:tagged64-bit words with byte count/backpressure,
retain t1/t0 in existing banks,no extra encoded-key RAM. This is our compatible
interface choice,not a claimed published LightHD port specification.
Next key sequencer should start SHAKE256(pk,64) only after matrix sampling
finishes,share the existing raw Keccak service,and fork stable PK words to
both hash/host sinks exactly once. Collect tr,then emit SK fields;cleanup
waits for key output/completion acceptance. Specification records the planned
word tags/order. This interface is selected,not yet implemented.

Stage5K:ROUND_OUTPUTS=1 on keygen/dilithium connects P2R and retains t0 at56+i,
t1 at40+i through overall completion;cleanup releases them after raw secrets.
Default0 preserves Stage5J. rounded_keygen test:7 complete,3 rejects,4 resets,
34 rows,190224 scalar values,12800 exact92-bit reads,36 checker faults PASS.
No additional physical/logical banks;both arrays use existing regions8..15.

process/bitpkg.sv implements t1(10 bits),t0(13),eta-s(3/4) polynomial encoding.
One87-bit reservoir;tagged64-bit words,held completion;not a complete key-byte
sequencer yet. bitpkg test:97 commands,60 successes,31 expected errors,6 resets,
18292 input values,2482 exact words,15 checker faults. Python/C packers agree on
66 valid fixture packets/18496 bytes;prepare builds C models at levels2/3/5.
New C wrapper:tb/tb_dilithium/bitpkg_reference.c;source token hashes dependencies.
Use selectors5/rounded_keygen and5/bitpkg in the same run.do/Python.
Next:bank read/Bitpkg routing,full key field order and SHAKE256(pk,64).
User delegated the choice:use tagged64-bit key streaming and retained rounded
arrays in existing banks,without encoded-key RAM. Independent rounding/packing
work is authorized. No new PPA/commit/branch/netlist work.

Current Stage5J:controller/keygen.sv autonomously samples all s1/s2 and all
matrix rows,retains/Pre-transforms s1,and returns t=A*s1+s2 at all3 levels.
controller/dilithium.sv is the actual operation FSM;op0 polynomial phase works;
Sign/Verify explicitly unsupported(code2),not implemented. Invalid level code1.
7 complete operations,3 rejects,4 reset aborts;34 rows,172304 exact scalar
writes,8448 exact92-bit reads,29 checker corruptions PASS. Same-ID different-xi
recovery,16-bit ID wrap and cleanup/restart are checked.136 pending-read
handoff checks protect the final response before freeing output regions.
All13 focused source/comparison/checker gates freshly PASS on one source token.
Create-only evidence:docs/dilithium_docs/evidence/stage5j_keygen_polynomials.zip
and matching SHA256 sidecar;preserve all checkpoints.
Select5/keygen;read REFERENCE_VERIFICATION.md and MEMORY_MAP.md before edits.

User's current layout:root memory.sv,keygen.sv,sign.sv,verify.sv,dilithium.sv;
Sign/Verify files added with working implementation later,not placeholder FSMs.
All LightHD process blocks belong in process/:P2R,Decompose x4,CNB,Mhint,
Bitpkg plus required UseHint/checking helpers. power2round.sv now contains
working extracted arithmetic;other new process blocks remain planned.
Active bank_poly_store renamed module memory in root memory.sv;the historical
scalar memory is slot_memory under legacy/. Other helper paths:datapath/,
helpers/,memory/;build scripts/QSF/tests updated. Historical snapshots keep
their old filenames;do not alter immutable archives. Engine RTL unchanged.
Next:connect P2R and key bit packing,hash encoded public key,and compare full
KeyGen key bytes. Ask about major external key storage/output choices.
No new synthesis/PPA,netlist,commit or branch action authorized by continuation.

Latest Stage5I PASS:seed-retaining keygen_sample_source.sv now drives actual
sampling through optional RAW_SERVICE=1 on banked NTT/row wrappers. One shared
dual Keccak,not a second hash engine. Test selector5/seed_row uses the existing
tb_row_accumulate parameter SEED_SOURCE=1;selector row preserves its old path.
190 commands=20 successful seed expansions+163 samples+7 adapter rejections.
2560 exact hash bytes,1103 absorption words;rho/rho-prime/K match Python.
13 complete rows,27 row rejections,7 row abort/recovery cases,12544 exact92-bit
readbacks PASS;23 checker corruptions rejected. All11 prior focused gates
freshly PASS on the same current source token. No new synthesis/PPA claim.
Read REFERENCE_VERIFICATION.md for commands and exact scope. Seed fixtures are
local FIPS-derived,not official full-KeyGen vectors. The bench still schedules
commands;connected tests use s1 and two matrix rows per level. Next Stage5J:
autonomous KeyGen polynomial scheduling,retain s2 and add it to inverse rows,
then connect rounding/key encoding. Keep functionality-first scope and6.757ns.
No commit/branch/netlist/synthesis work authorized by an ordinary continuation.
Create-only Stage5I evidence:evidence/stage5i_seed_row.zip plus SHA256 sidecar
under docs/dilithium_docs. Preserve it and all prior immutable archives.

## Active direction: functionality first (user decision 2026-10-20)

The user explicitly stopped timing optimization before memory. Integrate the
remaining blocks and establish correct full-operation outputs first; optimize
Fmax, actual placed ALMs and throughput afterward in Stage7. This supersedes
the earlier timing-first gate. Keep the 6.757 ns benchmark constraint; it is
not a requirement for starting Stage3. Do not start more timing experiments.

Branch: integration, created from sampler_v1 at e1b9c84. No commit or push
without explicit instruction. Announce each stage, ask about major architecture
decisions and report completed work with evidence and the next action.
Preserve accepted standalone source/evidence and existing uncommitted work.

Read docs/dilithium_docs/DILITHIUM_PLAN.md first. Integration == Dilithium:
one universal documentation suite under docs/dilithium_docs. RTL layout is
src/keccak, src/ntt, src/sampler, src/controller/process,
src/controller/memory.sv and src/controller/dilithium.sv. Import each accepted
module with its standalone UVM, sim, Quartus and docs assets when needed.
Focused non-UVM tests under tb/tb_dilithium are authorized during integration.
Full-operation reference checks precede comprehensive full-system UVM/PPA work.

Stage1 Keccak import from keccak_v2 fe54a78 is complete: 904 source UVM
transactions plus dual suites and 6364 published NIST output comparisons PASS.
Its immutable import archive preserves the original RTL and standalone PPA.
Current integration Keccak has subsequently verified control changes; do not
apply historical standalone PPA to the modified source.

Stage2 functional PASS. Current trial8 source has atomic ownership/command
binding, a two-slot registered-credit bridge and handshake-before-stop draining.
104 jobs: 88 complete, 8 expected errors, 8 reset aborts; 23089 exact coefficient
checks. All24 mode/parameter/context combinations and12 checker faults PASS.
The modified Keccak core also passes904 transactions plus dual suites and6364
NIST outputs. Sampler RTL is unchanged. Trial8 cycle rows match trial7.
Launcher:sim/dilithium/run.do; checker:sim/dilithium/dilithium_vectors.py.
No full-operation Dilithium/NIST/UVM or integrated netlist completion is claimed.

Historical Stage2 main seed1 fit:11293 PLACED ALMs,7557 registers,15970 ALUTs,
one M10K/1024bits,zero DSP;137.74MHz worst Fmax,setup-0.503ns/hold+0.157ns
at6.757ns. All original sampler/Keccak structural guards PASS. Timing is OPEN.
Main and isolated seed2 compiles have finished;seed2 is not selected.
Keep verified trial8 functional RTL; no new timing experiments before memory.
Initial evidence archive stage2_subsystem_initial.zip is immutable and describes
the earlier single-slot source,not current-source PPA.

Stage3 is complete for the focused functional gate. The user approved the
configurable four-slot pool on2026-10-20. memory.sv and keccak_sampler_memory.sv
implement it.104 jobs/88 complete/8 errors/8 aborts,23180 exact writes and22528
exact readbacks PASS;88 releases,99 rejected reads,8 pool-stall cycles,1321
read-stall cycles and170 concurrent read/write cycles.8 memory fault kinds
are contained;12 Python corruptions rejected. Stage2 freshly passes unchanged.
Commit requires256 writes plus successful matching external status acceptance.
Read data/metadata hold under stalls;release waits for pending responses;
reset invalidates metadata,not RAM. Sticky protocol faults require reset.
Read MEMORY_MAP.md for the full contract;Stage4 below adds the IN_USE leases.
Create-only evidence:docs/dilithium_docs/evidence/stage3_subsystem.zip and
stage3_subsystem.sha256;preserve them. The archive includes source/checker
manifests and captures;no Stage3 fitted PPA is claimed.
Stage4 is complete for its focused functional gate. Imported57 NTT package files
from ntt_v2:577a34b2fff19864cb16b490b7629ed211613000. Six RTL files and existing
UVM are byte-identical;ntt_import_manifest.csv records path adapters/provenance.
Locations:src/ntt,tb_uvm/tb_uvm_ntt_LightHD,sim/ntt,quartus/ntt,FIPS204_NTT,
docs/ntt_docs. No obsolete experiment tree or generated build database imported.
Relocated standalone UVM748 jobs/191488 values PASS;32 group type mean90.4731%,
raw code12990/14093=92.17%. Standalone Python18 cases/4608 values PASS.
These are NTT-only results,not integrated coverage or a fresh synthesis result.

New helper:keccak_sampler_ntt. Same four-slot pool now supports IN_USE locks,
separate result reservations and explicit domain/bounded-eligibility metadata.
Sequential sampling/compute;one outstanding DMA read. NTT uses canonical23-bit
residues and Dilithium ordering;INTT scales by1/256. Matrix A goes straight to
PWM. Pre checks all values represent[-4,4]. Invalid/stale source code1;domain/
parameter/Pre rejection code2;success0. Invalid commands never start the engine.
Compute source slots are protected even while waiting for a free destination;
only unrelated slots may be released then. Inputs are preserved;PWM aliasing
is allowed. Results publish only after256 writes and engine done. Faults halt
the helper until coordinated reset. Do not mistake mode metadata for domain.

Stage4 source/Python PASS:16 sampled jobs,50 commands,30 complete results,
17 rejects,3 reset aborts.4096 sampled values,9745 DMA values,7713 NTT outputs
(7680 complete+33 aborted-prefix values),11776 readbacks.43 releases,6 invalid
reads,4 resets. Witnesses:24 pool-wait cycles,188 completion-stall cycles,
699 read-stall cycles,33 source locks.12 checker corruptions rejected.
Reset targets:load17 values,coreRUN after256 loads,and writeback after32 outputs;
same IDs recover using different messages. Stage2/3 freshly revalidated.

Default sim/dilithium/run.do runs Stage4;set DILITHIUM_STAGE 2 or3 for old gates.
One Python prepare/check/compare/selftest script;--stage 2/3/4,default4.
Shared sampling files plus stage4_expected.txt with26 arithmetic expectations.
Quartus top is now keccak_sampler_ntt,294 virtual non-clock bits;6.757ns unchanged.
NO Stage4 synthesis/fit/netlist/PPA run. Old Stage2 reports are historical only.
Create-only Stage4 evidence:docs/dilithium_docs/evidence/stage4_subsystem.zip
and stage4_subsystem.sha256. Preserve all existing milestone archives unchanged.
Stage5A audit/shared arithmetic is implemented;Stage5 full controller is NOT done.
User decision2026-10-20:implement final FIPS204 ML-DSA-44/65/87,retaining
LightHD-style level2/3/5 names. Parameter port0/1/2 maps to44/65/87.
These are naming aliases,not a claim of legacy round-3 byte equivalence.
The user previously chose LightHD's full scope,but
its printed32-byte tr/challenge rules conflict with our local software's64-byte
tr,parameter-bound seed expansion and32/48/64-byte challenge lengths. The cited
2023 draft itself uses64-byte tr. Do not infer a byte-exact paper implementation.
Final FIPS204 now governs dependent seed/message/key bytes.
Audit evidence/table and25-file reference_manifest.csv are in universal docs.

Shared controller/process/poly_process.sv is independent of this choice:
opcode0 ADD,1 SUB,2 Power2Round,3 invalid;canonical23-bit residues,D=13;
rounding high10,signed low14,packed t0=4096-low13. Positive tie4096 is retained.
One elastic stage transports ID/index/last;13 errors cover bad opcode,operand
and framing. Scalar unit has no polynomial ordering/memory ownership yet.
PASS:10349 accepted,10346 exact outputs,3 reset aborts,13 expected errors;
9208 dense rounding points;10009 replacements,3505 input/3511 output stalls.
Python/C agree on all cases;unchanged C Power2Round separately passes8380417
canonical inputs(checksum1c750000). That exhaustive C check is NOT exhaustive RTL.
12 process checker corruptions rejected. Stage2/3/4 all freshly pass again.

Main top/default stage remains4(keccak_sampler_ntt). Select DILITHIUM_STAGE 5
and Python --stage 5 for the isolated process gate,NOT full KeyGen. prepare now
needs GCC at C:/MinGW/bin/gcc.exe;build outputs stay in sim/dilithium/reference_build.
No existing software/sampler RTL/UVM/Quartus source was changed. Quartus lists
the process source but it is not connected to the top;294 virtual non-clock bits
and6.757ns remain. No PPA work or new synthesis/netlist run.
Create-only Stage5A evidence:evidence/stage5a_process.zip and .sha256 under
docs/dilithium_docs. Preserve earlier archives unchanged.

Stage5B keygen_hash_message.sv formats xi32||K||L,rho32||column||row,and
rho-prime64||nonce_le16. Validates parameter,row/column and KeyGen secret nonce.
165 commands/162 done(14 expected errors)/3 reset aborts PASS.883 absorption
words and5888 exact real-Keccak SHAKE bytes match Python;12 corruptions rejected.
All102 matrix positions/34 secret nonces tested. This is a message builder,
not a seed-result collector or main-controller connection. Done means message
accepted,not hash complete. Seed expansion requests128 finite bytes;sampling
requests continuous0. Focused hash-only TB bounds sampling to32 output bytes.
In Tcl:set DILITHIUM_STAGE 5;set DILITHIUM_TEST hash_format.
Python:--stage 5 --unit hash_format. No accepted engine source changed.

Stage5C optional RAW_SERVICE in keccak_sampler and keygen_seed_collect now PASS.
Same two hash cores;captured per-core type/ID/remaining bytes;registered held
raw completion;ingress owner routes64-bit input;raw output bypasses sampler.
Finite raw lengths1..65535;zero refuses raw request. Raw descriptor priority.
26 commands,18 raw requests,7 sampled polynomials,7 seed results(including1
parameter error),3 reset aborts;1699 exact SHAKE bytes/1792 coefficients PASS.
Sampling uses actual RTL-collected rho/rho-prime,not Python seed injection.
Both core tags,rate-boundary short beats,raw/raw and raw/sampling ownership,
arbitration,held completions and coordinated reset/ID reuse pass.12 corruptions
rejected. All Stage2/3/4 and Stage5 process/hash_format gates freshly pass.
Use DILITHIUM_TEST shared_hash with stage5;Python --stage 5 --unit shared_hash.
Main Stage3/4 wrappers tie raw ports off;top ports/four-slot capacity unchanged.
New PROCESS_BLOCKS.md specifies implemented/planned processing;MEMORY_MAP.md
has dimensioned memory diagram and the concrete KeyGen storage proposal.

User resolved the storage choice2026-10-20:"whatever LightHD is doing do that".
Follow published four logical1024x92-bit dual-port banks,not either proposed
scalar-pool alternative. Capacity376832bits=47104bytes=46KiB;this is NOT four
physical M10Ks. Read MEMORY_MAP.md selected architecture/Sign region map.
Do not allocate old proposal's extra7488 encoded-key bytes automatically.
Final FIPS204 bytes/level2/3/5 labels remain selected.

Stage5D foundation poly_bram.sv/memory_banks.sv now source/Python PASS.
Full-word92-bit writes,independent A/B response slots per bank,A-priority
serialization when same-address pair contains a write;dual reads allowed.
14872 accepted/14864 responses,9509 exact92-bit reads,5355 write acks,
8 reset-aborted acks and8 unaccepted blocked offers canceled.4096 words covered;
73 collision events,4112 dual-read pairs,1031 all-eight-port cycles;12 corruptions
rejected. No RAM reset;payload retention checked. RAM inference/PPA not measured.
Use stage5,DILITHIUM_TEST bank_memory;Python --stage 5 --unit bank_memory.
The old Stage4 top still uses memory.sv/four slots. Do not claim bank migration
or LightHD32-cycle NTT loading:current NTT input remains scalar23-bit.

Stage5E bank_poly_store/keccak_sampler_banks now connect real sampling to banks.
Caller-select bank2/region4;64 aligned64-word regions. Per-core92-bit packing,
tag/index/canonical checks,64 write acks before successful external status
commit;protected92-bit reads/release;domain and[-4,4]metadata;sticky fault/reset.
PASS104 jobs:88 complete,8 errors,8 aborts;23173 coefficient checks,
5792 packed writes,5790 acks,5632 read words=22528 complete coefficients.
Partial aborted work accounts for645 coefficients/160 writes/158 acks;two
writes are reset before ack acceptance;five coefficients remain partial words.
All64 regions,24 core/mode/param combinations;occupied-target stalls8,read
stalls1070,read/write overlaps50,held-read resets2,invalidreads11.
Eight protocol fault cases contained;12 checker corruptions rejected.
Use stage5,DILITHIUM_TEST bank_store;Python --stage 5 --unit bank_store.
Main defaultStage4 still old all-engine top;bank sampler is a new connected
path,not yet NTT or process migration. No new synthesis/netlist/PPA/coverage.
All seven previous gates and their checker selftests freshly PASS. Immutable
evidence:docs/dilithium_docs/evidence/stage5e_bank_store.zip and .sha256;
115 members verified;do not overwrite. New source/TB files are captured there.

Stage5F completes the banked NTT connection through keccak_sampler_ntt_banks.
Sampling/compute are sequential;the existing bank_poly_store packer0 is reused
after sampling drains. New allocation flags set computed domain explicitly.
Sources lease at acceptance;release blocked through held completion retirement.
Explicit destination aliases reject(code3);busy distinct destinations wait while
unrelated regions may release. External pending reads block compute acceptance;
allocated results cannot release before completion retirement. Each92-bit read
feeds four23-bit scalar engine beats;PWM loads A then B. Publication waits for
256 results,64 write acknowledgements and engine completion. No extra cores.
Source/Python PASS:16 sample jobs,54 commands,30 results,21 rejections,3 aborts;
4096 sample coefficients,9746 DMA values,7712 NTT outputs,2952 packed writes,
2951 acks,2944 exact92-bit reads. Four banks,same-bank/cross-bank,A==B,all ops/
params,source preservation,Pre bounds and resets tested. Ownership witnesses:
24 destination waits,33 leases,4 read-lock checks,120 held-result checks.
Checker19/19 faults rejected. All eight earlier focused gates and selftests
freshly PASS at the current token. Use stage5/bank_ntt,Python --stage 5 --unit
bank_ntt. Default4 and Quartus top remain legacy
scalar baselines. No new PPA/netlist/full-system coverage/full-KeyGen claim.

Stage5G completes banked process reads/writeback. New process/poly_process_dma.sv
uses the existing poly_process arithmetic and two92-bit caches. Optional
PROCESS_SERVICE=1 in keccak_sampler_ntt_banks enables it;default0 preserves the
NTT-only gate. Same four banks/two packers;exclusive sampling/NTT/process access.
ADD/SUB require matching domains/parameters;P2R coefficient domain only. Source
leases protect accepted commands while waiting for distinct explicit destinations.
P2R low is canonical modulo q,high zero-extended10-bit,in separate64-word regions.
No encoded-key bytes or extra polynomial RAM. Low/high commit separately but
public visibility is atomic;both result/source leases last through held completion.
Status0 success,1 source,2 domain/param,3 alias,4 invalid op. Fault requires reset.
Source/Python/C PASS:23 samples,15 NTT commands,71 process commands(34 successes,
33 rejections,4 aborts);8978 process inputs,8976 completed results,22297 scalar
writes,5574 packed writes/acks,8512 exact92-bit reads. All three parameters,
real PWM/ADD/SUB/INTT/P2R and canonical-low -> NTT chains,source preservation,
busy destinations,held results and resets tested. Reset phases:initial DMA,
partial writeback,between low/high writes,and after low commit before high commit.
Witnesses36 wait checks,188 held-result checks,4 pending-read checks,22 actual
partial-publication snapshots.29 checker corruptions rejected. Use selector5/
bank_process and Python --stage 5 --unit bank_process. Main/default Quartus top
remains legacy;no synthesis/netlist/PPA/full-system coverage/full-KeyGen claim.
Exact commands and representation limits are in shared REFERENCE_VERIFICATION,
MEMORY_MAP and PROCESS_BLOCKS docs. Preserve all earlier checkpoints unchanged.
All nine earlier source/checker gates freshly pass at the current token.
Create-only evidence:docs/dilithium_docs/evidence/stage5g_bank_process.zip and
stage5g_bank_process.sha256;verify CRC/manifest/member hashes before reporting.
That Stage5G snapshot uses distinct destinations;Stage5H below adds explicit
destructive row accumulation with checked ownership/read-before-write.

Stage5H completes staged-row scheduling through row_accumulate.sv and
keccak_sampler_row.sv(one existing banked subsystem,not another engine/RAM).
Level2/3/5 use4/5/7 staged A_hat/s1_hat pairs. Validate all sources before child
arithmetic;retain/lease sources throughout. First PWM initializes accumulator;
later PWMs use scratch;explicit in-place ADD overwrites accumulator;release
scratch after each ADD;final inverse writes u=A*s1;release accumulator.
Hold output/source leases through row completion retirement. Busy/alias workspace
code3 rejects before work;source1/domain-level2/invalid-param-row4;success0.
Unexpected child errors halt until reset. Three workspace regions are caller-
selected and distinct from sources. All outside interfaces block while row owns.
Row index input4bits validates against k4/6/8;descriptor arrays7entries use l.

New process_inplace_i defaults0 in old benches;1 allows ADD/SUB dest=A only.
P2R still rejects in-place. Store alloc_rewrite_i rebinds a COMPLETE source to
WRITING under new ID;private reads allowed only when4*word>=scalar write count.
DMA caches both92-bit source words before writing any lane,so original values
are consumed in order. Reset invalidates partial rewrite;payload RAM not reset.
Ordinary flag0 process commands retain prior behavior. Row tests exercise ADD
in-place,not in-place SUB. Old source A is consumed;retained secrets/B untouched.

Source/Python/C PASS:47 row commands=13 successes+27 rejections+7 aborts;
163 real samples,161 NTT/Pre/PWM/INTT commands,55 in-place ADDs;96264 scalar
writes,24066 packed writes/acks,12544 exact92-bit public reads,6918 checked
old-word cache reads.6 reference rows also match independent coefficient-domain
schoolbook products;C ADD13833 inputs/13832 completed results.26 checker faults
rejected. Two different matrix rows reuse transformed secrets per level;eligible
secrets use Pre-NTT and ordinary NTT. Resets:validation,PWM,first accumulator,
partial destructive ADD,scratch release,inverse execution,held row completion.
160 held-row refusal checks,4 pending-read checks;IDs reused with different row.
Use selector5/row and Python --stage 5 --unit row. Fixture messages are final
FIPS formatted but seed collection/message RTL are not connected by this gate.
No full KeyGen,NIST whole-operation,UVM coverage or new synthesis/PPA claim.
Default4 and Quartus top remain scalar baselines. Preserve earlier archives.
All ten earlier source gates/checker selftests freshly PASS at the current
source token. Create-only evidence:docs/dilithium_docs/evidence/stage5h_row.zip
and stage5h_row.sha256;verify CRC,manifest hashes and member bytes. Keep all
earlier checkpoints unchanged. No extra trial JSON/checkpoint trees are needed.

NEXT:shared seed/hash/nonce scheduling for first level2 KeyGen,then s2 addition,
Power2Round and key byte encoding/full-reference comparison. Follow LightHD secret retention,row accumulator
reuse,bounded A staging and later port-overlap schedule. Figure2 describes peak
Sign regions,not a complete KeyGen FSM table;derive/check missing lifetimes.
NTT still accepts
one23-bit coefficient per beat;do not claim32-cycle loading yet. Aligned-region
sampling metadata is not the final packed w1/key-field ownership policy.
No extra key buffers/ports or PPA optimization silently added.
Create-only Stage5C evidence:docs/dilithium_docs/evidence/stage5c_shared_hash.zip
and stage5c_shared_hash.sha256.99 members verified;do not overwrite. Current
PROCESS_BLOCKS corrects the snapshot's t1-shift explanation(1023<<13=q-1);
no RTL/result changes from that documentation correction.
MEMORY_MAP.md retains superseded scalar-pool proposals for context. The shared raw service is
tested but not wired into the main Stage4 top;do not duplicate full engines.
Do not silently expand memory or add key-output interfaces. Ask major decisions.
Do not start PPA optimization or claim full Dilithium/KeyGen.
Keep native128 sampler processing deferred:input beats still issue64-bit chunks.

Scope:final FIPS204 KeyGen/Sign/Verify,using level2/3/5 names for44/65/87,
starting level2. Full-operation official vectors must match this selected format.
No full-operation conformance is established by the component tests.

The sampler history below is accepted standalone evidence. Its old instructions
restricting integration are superseded by the user's integration authorization.

## Accepted sampler baseline inherited from sampler_v1

User accepted Stage4.9r on2026-10-19. Main baseline:3537 actual placed ALMs,
164.74MHz worst Fmax,+0.430ns setup,+0.141ns hold at unchanged6.500ns.
3931 registers,4256 ALUTs,one M10K/1024bits,zero DSP. All4 corners0TNS.
Quartus seed1,HIGH PERFORMANCE EFFORT,physical register retiming OFF.
Original payload/sign/reservation structural guards pass. Area ALWAYS means
actual final-placement ALMs. Never use needed estimates for area claims.

Read README.md and docs/sampler_docs/post_midyear/SAMPLER_PLAN.md before work,
then SPECIFICATION.md,COVERAGE.md,THROUGHPUT.md,STAGE4_9R_RESULTS.json and the
user's docs/sampler_docs/LIGHTHD_SAMPLER.md and SAMPLER.md.
Main UVM621 complete/182 expected errors/51 aborts/159628 comparisons PASS;
functional1652/1721=95.99%,code15093/15799=95.53%. Python104/19456,C48/12288,
checker12,performance96 and five zero-credit fault gates PASS. Source checks
reuse byte-identical O after26 hashes;R has fresh fit/timing/structural evidence.
All96 performance rows match the preceding selected implementation.

Stage5 completed on2026-10-19 using DISTINCT current synthesis/fit netlists.
Each main-UVM run:184 jobs,156 complete,24 expected errors,4 reset aborts,
39936 checks,zero errors/fatals. All104-job source/synthesis/fit captures match
byte-for-byte and Python19456 values. Fresh source621/159628,P/C48/12288,
checker12 pass. Source functional95.99%,code95.53%;netlists1255/1721=72.92%,
source-only groups unsampled. Timing/structural refresh passes unchanged.
Read SAMPLER_NETLIST_RESULTS.json and evidence/sampler_stage5.zip. Preserve
both accepted R and Stage5 evidence. The96 performance CSV rows match accepted
archive;not rerun. CycloneV netlists are functional only;TimeQuest is timing.
Next Stage6 requires separate integration-branch/import authorization. Do not
start integration,change branches,import modules or commit without instruction.

RTL:src/sampler;UVM:tb_uvm/tb_uvm_sampler;common templates:tb_uvm/tb_uvm_reusable;
simulation:sim/sampler;Quartus:quartus/sampler;docs:docs/sampler_docs/post_midyear.
Keep exactly3 .do launchers:run_uvm.do,run_post_synthesis.do,run_post_fit.do.
Vectors/performance are modes of the main UVM. Independent models must not call
DUT functions. Coverage credits only scoreboard-accepted observations. Genuine
gaps stay visible;no artificial percentage ceiling or impossible bins.

Native128 remains inactive:tagged128-bit beats issue64-bit chunks. Current
pipeline:capture→staged prepare→extract→local compact→packed/admit→aligned
commit→32-entry/context collectors→per-context read→shared formatted output.
Mask conversion stays before packing;secret values remain4-bit encoded until
output formatting. Preserve complete state,credit/quota ownership and drain
before reuse. Do not relax6.500ns or waive original register guards.

Frozen Stage4.9r JSON/ZIP/SHA are immutable;never overwrite them. Its recorded
acceptance-pending field predates the explicit user acceptance. Mutable docs
record that acceptance. User-confirmed cleanup on2026-10-19 removed obsolete
checkpoint records/archives and leftover sim/ntt_LightHD and quartus/ntt_LightHD
folders. Stage4.9r evidence remains,with the new Stage5 result/archive/checksum added. All49 protected
source/model/settings/evidence files passed before/after hash checks. Two Python
analysis/checkpoint helpers remain after automatic review rejected their deletion.
