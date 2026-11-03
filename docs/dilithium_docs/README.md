# Dilithium integration

Current C22 passes all210 official commands,protocol88,checker90,main33UVM/
negative and physical hardware/four-corner gates. Actual30577 placed ALMs,
20389registers/59M10Ks/8DSP;worst68.23MHz,setup-7.899ns/hold+0.087ns.
It uses736 more ALMs than C21 but is7.67% faster with unchanged cycles.
Functional116/170,overall code127904/170039=75.22%. C21 stays the smaller
saved checkpoint. Original ASM crash and successful manual ASM/STA recovery
are separately recorded. Under20K/148MHz remains open;next is qualified
unpacker field-comparison/output conversion work. See the universal plan,
THROUGHPUT.md and C22 evidence archive.

Historical C21 passes all210 official commands,protocol88,checker90,main33UVM/
negative and same-FPGA full compile/hardware guards. Actual29841 placed ALMs,
20199registers/59M10Ks/8DSP;worst63.37MHz,setup-9.023ns/hold+0.094ns.
It saves814 ALMs versus C20 but loses0.35% Fmax/rates;all operation clocks
match. Functional116/170,overall code127075/169194=75.11%. Preserve faster
C20. Under20K/148MHz remains open;next is qualified unpacker feedback work.
See DILITHIUM_PLAN.md,THROUGHPUT.md,MEMORY_MAP.md and the C21 evidence archive.

Historical C14 passes210 official commands,88 protocol commands,checker90,
main33 UVM/negative and same-FPGA full compile/retained-hardware checks.
Actual31,882 placed ALMs/22,120registers/59M10Ks/8DSP;worst56.72MHz,
setup-10.875ns/hold+0.104ns. Cycles equal C12;area-3.55%,estimated rates-1.15%.
Functional116/170,overall code120528/167402=72.00%. The shared Process hint
codec is physically retained once. Under20K/148MHz and full reconstruction
remain open;next is qualified direct-data memory routing. See THROUGHPUT.md,
PROCESS_BLOCKS.md,MEMORY_MAP.md and the C14 archive under evidence/.

Previous C12 passes210 official commands,88 protocol commands,main33 UVM/
negative,standalone NTT748 and same-FPGA full compile/ASM/STA/retained guards.
Actual33056 placed ALMs/22797 registers/59M10Ks/8DSP;worst57.38MHz,
setup-10.671ns/hold+0.090ns. All cycles equal C11R1;area changes only-10 ALMs,
estimated rates-0.33%. Performance targets remain open. The user rejected
shared controller-context RAM/formatter;next is measured memory-to-Process
timing and control/selection overhead. C12 evidence is under evidence/.

Previous C11R1 passes210 official commands,88 protocol commands,main33 UVM/
negative,both167-command formatter modes and exhaustive arithmetic gates.
Actual placed33066 ALMs/23054regs/59M10Ks/4DSP;worst57.57MHz/setup−10.612ns/
hold+0.095ns. All cycles equal C10;area−4.60%,estimated rates+1.62%. The user's
under20000 target still needs13067 ALMs removed;148MHz setup still fails.
That later proposal was rejected;follow the current C12 plan above.

Previous Stage7C.10 source qualification passes210 official commands,88 protocol
commands and main33 UVM/negative. The fresh physical build completes at34660
placed ALMs/56.65MHz/setup-10.894ns/hold+0.122ns,59M10Ks/8DSP. Estimated
operation throughput improves about9% versus C7;148MHz setup still fails.
See THROUGHPUT.md for measured cycle costs,all corners and estimate limits.

Frozen Stage7C.9 R1 passes210 official commands,88 protocol commands,main33
UVM/negative and the expanded48-case split-port renewal gate. Source tests
and measured cycle overhead are in REFERENCE_VERIFICATION.md/THROUGHPUT.md.
Same-device physical qualification passes at34535 placed ALMs/53.85MHz;this
regresses versus C8 and is not performance-accepted. No FPGA/performance acceptance is
implied by passing the source campaigns. Earlier milestones below are history.

Stage6 complete: current full-operation main passes 75/75 official KeyGen,
90/90 Sign and 45/45 Verify cases. Exact matches: 433600 key bytes, 310680
signature bytes and 9 valid / 36 invalid Verify verdicts. Checker faults reject
41/41, 152/152 and 158/158 corruptions. All 74 RTL files, 21 production C/H
and SDC remain unchanged. Fresh evidence: evidence/stage6_full_operation_qualification.zip
and SHA256. Universal REFERENCE_VERIFICATION.md contains the single DO/Python
flow and unsupported-mode audit. Next Stage7: main UVM and whole-main Quartus
baseline, then measured PPA improvements. No new fit or commit in Stage6.

Stage5V.4 complete:main op2 now runs the approved PK/SIG/ctx||M stream through
the existing preparation/equation clients.118 scenarios pass:23 valid Verify,
60 invalid Verify,19 expected errors,14 resets/faults,two mixed operations.
All45 official pure verdicts match (9 valid,36 invalid);10 structural invalids
stop before arithmetic.2624604 exact writes/51466 reads;170/170 checker faults
reject. Fresh Sign45 and KeyGen-only16 compatibility pass under the same token.
Only main RTL changes plus new verify.sv (74 total);72 old RTL/C/H/SDC unchanged.
Same four-bank pool and clock target. Evidence:evidence/stage5v4_full_verify.zip
and SHA256. NextStage6:full current-source published operation suites,then
Stage7 UVM/synthesis/optimization. No new fit,netlist or commit.

Stage5V.3 complete:actual prepared context ->Az-c*t1hat,inverse NTT,UseHint,
shared packing/SHAKE and challenge comparison.87 scenarios pass:19 valid,
35 cryptographically invalid,23 expected errors,10 reset/fault aborts.
All35 structurally valid official verdicts agree (9 valid/26 invalid).
2104627 exact writes/49903 reads;966 UseHint cases;172/172 checker corruptions
reject. Fresh verify_math134 compatibility passes unchanged. C/Python44
inputs/519168 equation values agree. All71 old RTL/SDC unchanged;two new RTL.
Private peaks22/30/40 within the same64-region pool. Evidence:
evidence/stage5v3_verify_equation.zip +SHA256. Main op2 is still unwired;
next5V.4 connects the approved three-frame stream. No new PPA or commit.

Stage5V.2b complete:real raw-context adoption,third-frame mu hashing,challenge
sampling and shared FNTT/Pre-NTT.134 requests=65 prepared contexts+57 expected
errors+12 resets/faults.236834 writes/84099 packed reads;848 NTTs including68
Pre-NTTs;112/112 checker corruptions reject. C/Python56 inputs/191232 values
agree. Fresh5V.2a133-scenario capture/compare passes under the same fingerprint.
All70 old RTL and6.757ns SDC unchanged,one new control module. Evidence:
evidence/stage5v2b_verify_math.zip and SHA256. Next5V.3:Verify equation,UseHint,
w1 hash/challenge comparison;main op2 later. No commit or new PPA/signoff.

Stage5V.2a complete:real PK/signature bank loading and shared SHAKE256(PK)->tr.
133 requests=49 prepared contexts+73 expected errors+11 resets/faults;360545
exact scalar writes/61827 packed reads,87/87 checker corruptions rejected.
Fresh shared SK-load138,full KeyGen16 and main Sign45 scenarios pass;SK-load
and KeyGen checkers reject95/95 and37/37 corruptions. Main Verify/op2 remains
unsupported. Next5V.2b:third ctx||M frame,mu,challenge and NTT preparation.
Evidence:evidence/stage5v2a_verify_prepare.zip and SHA256. Universal reference,
memory,process and plan docs explain commands,results,lifetimes and study order.
No new fit,full-system UVM/netlist claim,commit or branch change.

Stage5V.1 Verify decoder complete:383 scenarios/705010 checked values,
99 expected errors/9 resets,and37 checker corruptions rejected. Independent
C/Python decoding agrees;C Verify matches45/45 official verdicts. Main RTL
Verify is still pending. Approved host:PK/signature/ctx||M three-frame stream.
Fresh KeyGen compatibility and37 checker faults pass. Source67prior RTL/SDC
unchanged,one decoder added. Evidence:evidence/stage5v1_verify_decode.zip and
SHA256. Next5V.2:decoded bank loading/PK hash. Universal reference/plan own
results,commands,limits and future steps;no new PPA/full-UVM/netlist claim.

Stage5N.4h.7:official pure Sign90/90 signatures/310680 exact NIST bytes pass,
with152/152 checker corruptions rejected.15 deterministic+15 randomized per
level2/3/5;the270 prehash/internal-API cases remain unsupported and audited.
All67 RTL files and6.757ns SDC are unchanged. Fresh local main Sign45 scenarios
and196 checker faults also pass. Immutable evidence:
evidence/stage5n4h7_nist_sign.zip and SHA256. REFERENCE_VERIFICATION.md owns provenance,
commands,files,results and study order. Main Verify remains the next task.

Previous Stage5N.4h.6:real main Sign dispatch and approved two-frame64-bit
SK/body input.45 cases PASS:21 signatures/63204 exact bytes,one actual KeyGen,
14 expected errors,9 reset/fault aborts;196 checker corruptions reject.
Physical memory lifetimes and debug isolation pass;normal Sign frees all key/
attempt regions before main done. Encoded and rounded KeyGen compatibility
gates pass too. Main source/default ENABLE_SIGN1 supports op1. Verify remains
unsupported. Next:official NIST Sign output comparison,then main Verify;
current signatures are local C-reference fixtures using official KeyGen keys.
Run/study guide:REFERENCE_VERIFICATION.md. Frozen evidence:
evidence/stage5n4h6_full_sign.zip plus SHA256. No new PPA/full-UVM/netlist signoff.

Latest Stage5N.4h.5 encodes accepted attempts into final signature bytes.
24 scenarios:7 complete signatures/25339 exact bytes,9 expected errors,
8 aborts;163 checker mutations reject. Shared Bitpkg adds18/20-bit z packing;
hint indices/padding/counts and the64-bit final-byte interface are checked.
Atomic adoption and whole cleanup preserve the key. No signature RAM/new bank.
Python/C6 fixtures/22030 bytes agree;three also match unchanged full C signing.
Shared packer188-case and full KeyGen compatibility gates are rerun. Results,
commands,study order and limits:REFERENCE_VERIFICATION.md. Evidence:
evidence/stage5n4h5_sign_encode.zip plus SHA256. Next:main Sign host dispatch;
main Verify remains open. These are local reference-derived signatures,not
official NIST signature-output vectors. No PPA/full-UVM/netlist signoff here.

Latest Stage5N.4h.4 connects the six attempt clients into an automatic retry
loop.47 scenarios pass:19 accepted results,12 expected service failures,
5 nonce-exhaustion stops,11 aborts;87 attempts and45 genuine rejections.
Exact hash/mask bytes,105667 y coefficients,56256 reads and the physical
memory ledger pass;152/152 checker faults reject. The normal-mode mask78-case
regression/85 checker faults pass too. C/Python13 starts/26 attempts agree.
No message replay/private-seed rehash or nonce wrap. Next:signature encoding,
then main Sign dispatch;Verify remains open. Universal reference/specification/
memory/process/throughput docs include the interfaces,commands,limits and
study order. Evidence:evidence/stage5n4h4_sign_retry.zip plus SHA256 sidecar.

Earlier Stage5N.4h.3 connects CNB norms,combined-low ADD,Mhint and whole-vector
weight acceptance.59 cases:18 accepted candidates,5 genuine rejections,
21 errors,15 aborts;70944 exact writes/157888 packed reads. All118 checker
faults reject;Python/C8 fixtures/25794 values pass. Rejection frees payloads
but retains mu/private seed/nextnonce;service errors remain distinct.
No new bank/engine. Next:nonce retry/seed reuse,then signature encoding and
main Sign. Main Verify remains open. See REFERENCE_VERIFICATION.md for run
commands,evidence,study order and limits;MEMORY_MAP.md has the memory diagram.
Fresh prior products63-case regression and84/84 checker corruptions also pass.
Immutable archive:evidence/stage5n4h3_sign_accept.zip plus SHA256 sidecar.

Earlier Stage5N.4h.2 connects cs1/cs2/ct0 through shared PWM+INTT and rewrites
y->z,w0->r0 through existing ADD/SUB. Whole result includes w1,ct0 and retry
headers.63 cases pass:24 arithmetic completions,21 errors,18 aborts;
425955 exact writes/99584 packed reads;84/84 checker faults. Python sparse
convolution and unchanged C agree on44032 values. Fresh prior transform51
and64/64 checker faults pass. Next:norms/hints/rejection,then retry/signature
packing and main Sign. No new PPA result or completed main Sign/Verify claim.
Universal reference/memory/process docs include commands,limits and evidence.

Latest Stage5N.4h.1 verifies atomic matrix/challenge ownership transfer,
dead-yhat release and ordinary FNTT(c).51 cases:24 successes,12 expected
errors,15 reset/fault aborts;7875 exact writes,85760 packed reads;64/64
checker faults. Python/C agree on6 c/chat fixtures;fresh prior challenge81
and77 checker faults pass. Retained context is w0/w1/chat+ctilde;key/raw y
survive. Next:secret products,z/corrections and later norm/hint/retry logic.
Main Sign/Verify remain unfinished. Universal reference/specification/memory
docs contain commands,contracts,results and the ownership/memory diagrams.

Latest Stage5N.4g connects retained w1 through shared Bitpkg/SHAKE256 and
SampleInBall to c.81 cases pass:24 successes,39 expected errors,18 reset/
fault aborts;8640 exact c writes,171264 packed reads;77/77 checker faults.
Python/C agree on6 fixtures/5120 packed w1 bytes/288 ctilde bytes/1536 c
coefficients. Main Sign/Verify remain unfinished;next are ownership handoffs,
secret products,z/hints/norms and retry. Universal REFERENCE_VERIFICATION.md
contains commands,files,study order and frozen evidence;MEMORY_MAP.md diagrams
the extra single-region lifetime. The shared packer now supports w1 too;
its136-case regression and fresh full-KeyGen8/3/5 plus37 checker faults pass.

Latest Stage5N.4f completes one signing attempt through NTT(y),full A*y and
decomposition,using the real retained-key/mask clients and one shared services
tree.66 cases,1060230 exact scalar writes,102336 packed reads and66 checker
corruptions pass;fresh local KeyGen regression also passes. Original y/key
remain retained and workspace rolls back correctly. The six distinct level/
nonce fixtures agree with unchanged C on96256 values. Main Sign/Verify are
unfinished;next is w1 packing/challenge hashing/SampleInBall. See universal
REFERENCE_VERIFICATION.md for commands/evidence and MEMORY_MAP.md for diagrams.

Latest Stage5N.4d adds a working retained-key preparation client:shared
Pre/FNTT,one rotating scratch,validated ordered handles/header,clear/error
cleanup and fatal reset handling.165 cases include all75 official KeyGen SKs;
55 checker corruptions and fresh shared-loader/KeyGen gates pass. Exact
counts,contracts,run commands and frozen evidence are in the universal docs.
Next:retained-key signing hashes/masks;main Sign/Verify are unfinished.

Prior Stage5N.4c2 wires key ingestion into the existing production services
tree,with private whole-key commits,rollback and held ownership.138 key cases
include all75 official KeyGen SKs;real SHAKE/sampler sentinels,raw-core/public-
read holds and key-to-CNB handoffs test sharing. See REFERENCE_VERIFICATION.md
for exact gates/results. Next:validated key context and shared transforms.
Main Sign/Verify and full signature verification remain unfinished.

Prior Stage5N.4c1 verifies sign_key_load against real memory/four banks:
138 commands,95 successes,38 expected errors,5 resets;all75 official KeyGen
secret keys loaded. Whole-key publication and late-error rollback pass.
Commands,files,results and study pointers are in REFERENCE_VERIFICATION.md;
region layout/diagram in MEMORY_MAP.md. Next:production shared-service
arbitration/owner handoff(Stage5N.4c2). Main Sign/Verify remain unfinished.

Stage5N.4b verifies mu/private-seed/challenge/mask-nonce messages through the
actual shared service:167 commands,7760 raw bytes,6400 mask values,29 peer-core
jobs,9 actual RTL digest forwards and61 checker corruptions. Invalid payloads
drain and retire with error;their diagnostics are not successful sign results.
All55 prior RTL files remain unchanged;decoder/shared-process/local KeyGen
regressions pass. Evidence:evidence/stage5n4b_sign_hash.zip +.sha256.
Next:decoded-key private bank ingestion. Main Sign/Verify remain pending.

Stage5N.4a implements sign_key_decode.sv,streaming rho/K/tr and canonical
s1/s2/t0. All75 official KeyGen secret keys decode correctly;the focused
129-command campaign checks436424 emitted coefficients,32 expected errors,
five resets and35 checker corruptions. This is not full NIST Sign testing.
Fresh shared-service and local KeyGen regressions pass;all54 prior RTL files
are unchanged. Frozen evidence:evidence/stage5n4a_sign_decode.zip +.sha256.
Next Stage5N.4b:signing hash formatting,then bank ingestion/main Sign control.
See [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for execution and
[SPECIFICATION.md](SPECIFICATION.md) for the interface/validation contract.
Earlier stage summaries below describe their historical boundaries.

Stage5N.3 adds sign_process_dma to the main-owned service and shares its existing
four banks. Canonical low/high/hint storage,checked reads,error rollback,leases,
all-write acknowledgments and atomic Decompose publication are verified.
New gates:71 DMA commands/32 checker faults and33 shared-service commands/33
checker faults. The service uses actual SHAKE/sampling;main Sign is still pending.
All six current gates pass;all75 official KeyGen cases match433600 exact bytes.
Frozen evidence:evidence/stage5n3_sign_memory.zip and its.sha256 sidecar.
See [MEMORY_MAP.md](MEMORY_MAP.md) for the updated diagram,
[SPECIFICATION.md](SPECIFICATION.md) for internal commands/error codes and
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for execution/results.
Next Stage5N.4:signing key/input decode and hash formatting. Earlier milestone
paragraphs below describe their historical state.

Stage5N.2 implements and verifies Decompose x4,CNB and Mhint through the new
sign_process unit:7752 accepted groups,117 complete polynomials,45 intentional
errors,6 resets and27 checker faults. Local KeyGen and all75 official NIST
keypairs also freshly pass. The process unit is not yet connected to shared
bank DMA or main Sign. Next Stage5N.3:checked memory/lease/commit integration.
See [PROCESS_BLOCKS.md](PROCESS_BLOCKS.md) for the arithmetic and
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for execution/results.

Stage5N.1 moves physical engine/bank/Bitpkg ownership to dilithium.sv through
the new typed shared-service boundary. All75 NIST keypairs and the local
reset/recovery plus both diagnostic gates pass. Cleanup ownership is checked
after main completion acceptance. [ARCHITECTURE.md](ARCHITECTURE.md) shows the
new structure;[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) records
the four current-source gates. Next Stage5N.2:Decompose x4,CNB and Mhint.
Sign/Verify remain unimplemented;no PPA claim or commit accompanies this step.

Stage5M:all75 official NIST KeyGen cases pass,25 each for ML-DSA-44/65/87.
433600 complete public/secret-key bytes match;39 checker corruptions reject.
Use selector nist_keygen in the same launcher/script. Corpus,provenance and
run commands are in [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).
RTL is unchanged from Stage5L. Next:shared-resource Sign integration.

Stage5L now produces complete encoded public and secret keys with
dilithium(FULL_KEYGEN=1),using existing banks,Bitpkg and the shared Keccak.
Selector5/full_keygen:8 complete keypairs at all levels match unchanged C
KeyGen;3 rejects,5 resets,5433 exact64-bit key words and35 checker faults PASS.

Use [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for prepare,Questa
capture and Python comparison. Main output ports are documented in
[SPECIFICATION.md](SPECIFICATION.md). Earlier diagnostic modes remain available.

Stage5M completes the official-vector follow-up described above.
Next:Sign and its remaining LightHD process blocks.
This milestone has no new synthesis/PPA/full-system UVM result.

Stage5K connects post-sum Power2Round in the ROUND_OUTPUTS=1 path and retains
all t1/t0 arrays in the existing banks. Selector5/rounded_keygen checks34 rows,
190224 scalar values and12800 exact92-bit reads;36 checker faults rejected.

Stage5K originally implemented t1,t0 and secret polynomial encodings.
Its historical gate:97 commands,60 successful packets,31 expected errors and6
aborts;2482 exact64-bit words.66 valid fixture encodings/18496 bytes match the
unchanged C packers.15 checker corruptions rejected. Commands and scope:
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).

The Stage5K bank-to-Bitpkg and full-key serialization follow-up is completed
by Stage5L above. Earlier stage descriptions below are historical milestones.

Stage5J adds real `controller/keygen.sv` and main FSM `dilithium.sv`.
The autonomous polynomial phase expands xi,samples all s1/s2,retains/transforms
s1,processes all matrix rows,and returns t=A*s1+s2 at levels2/3/5.
Selector5/keygen:7 complete operations,3 rejects,4 resets;34 rows,
172304 exact scalar writes and8448 exact92-bit reads;29 checker faults PASS.

The active banked controller is now memory.sv;its primitives,datapath helpers
and legacy scalar tests are in dedicated subfolders. process/power2round.sv
contains working P2R arithmetic. Sign/Verify and the requested LightHD CNB,
Decompose x4,Mhint and Bitpkg files are planned for their working integration
steps. Key encoding and complete KeyGen outputs remain next.
Commands/scope:[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).

Stage5I now connects RTL seed expansion and message formatting to the real
banked sampling/NTT/row path. Select5/seed_row:20 seed expansions,2560 exact
SHAKE bytes,163 RTL-formatted samples and13 successful row outputs PASS.
Seven adapter errors,27 row rejections and7 row reset/recovery cases pass;
23 seed-path checker corruptions are rejected. Existing eleven gates remain
separate regressions. Commands/results:REFERENCE_VERIFICATION.md.

Next:autonomous KeyGen scheduling,all s2 nonces,s2 addition,rounding and key
encoding. The bench still schedules row/NTT descriptors;full KeyGen bytes and
new PPA/full-system UVM coverage are not claimed.

Stage5H now schedules whole staged rows through PWM -> reusable accumulator
ADD -> inverse NTT. It reuses retained secret transforms and one product scratch.
Select5/row:13 full rows,27 rejections,7 reset aborts and12544 exact92-bit public
readbacks PASS. Six full reference rows also match schoolbook multiplication;
26 checker corruptions rejected. Output is u=A*s1 before s2 addition. Next:
shared seed/message scheduling,s2 addition,rounding and first full KeyGen encoding.
Commands/results:REFERENCE_VERIFICATION.md. No new synthesis/PPA/full-KeyGen claim.

Stage5G connects ADD/SUB/Power2Round to the same banks,with stored low/high
outputs and real NTT chains. Select5/bank_process.23 samples,15 NTT commands,
71 process commands(34 successes,33 expected rejections,4 aborts),8512 exact
92-bit reads PASS. Python/C agree on8976 completed arithmetic results;29 checker
corruptions rejected. Next:row accumulation scheduling,then the first full
level2 KeyGen controller(Stage5H above now adds row scheduling).
Execution/results:REFERENCE_VERIFICATION.md.

Stage5F now connects real sampling -> four banks -> NTT/INTT/PWM/Pre -> four
banks. Select stage5/bank_ntt in the existing launcher and Python comparison.
16 sample jobs,54 compute commands,30 results,21 expected rejections,3 reset
aborts and2944 exact92-bit readbacks PASS;19 checker corruptions rejected.
Source/destination leases and packed write acknowledgements are checked.
Stage5G above completes banked process arithmetic/writeback;row scheduling is next.
See REFERENCE_VERIFICATION.md for commands. No new PPA or full KeyGen claim.

Processing reference:[PROCESS_BLOCKS.md](PROCESS_BLOCKS.md). Dimensioned shared
memory diagram,ports and lifetimes:[MEMORY_MAP.md](MEMORY_MAP.md).

Stage5D:user selected LightHD memory:four1024x92-bit dual-port logical banks,
46KiB total. The bank foundation passes14872 requests/9509 exact reads plus
collision/stall/reset checks. Main controller/DMA migration remains next;
the Stage4 connected regression still uses its old four-slot pool.
Use DILITHIUM_STAGE5,DILITHIUM_TEST bank_memory and Python --stage 5 --unit bank_memory;
see REFERENCE_VERIFICATION.md for exact commands. No new PPA or full KeyGen claim.

This is the universal documentation set for the `integration` branch. Add each
integration milestone to these documents as the complete design grows.

Stage5E now connects real Keccak/sampling to the four-bank memory through
per-context word packing and checked region ownership.104 jobs/88 complete/
5632 exact92-bit readbacks PASS. Select stage5/bank_store using the commands
in REFERENCE_VERIFICATION.md. Stage5F above adds NTT DMA/compute ownership;
default Stage4 still preserves the old scalar-pool regression.

| Document | Purpose |
|---|---|
| [DILITHIUM_PLAN.md](DILITHIUM_PLAN.md) | Agreed layout,stages,decision gates and next work |
| [SPECIFICATION.md](SPECIFICATION.md) | Imported source provenance,current interfaces and relocation results |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Current connected datapath,ownership,bridge and drain contract |
| [MEMORY_MAP.md](MEMORY_MAP.md) | Approved Stage3 slot memory,ownership,readback and measured results |
| [PROCESS_FLOW.md](PROCESS_FLOW.md) | Current transaction steps and planned algorithm processing |
| [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) | One-script prepare/capture/compare flow and measured results |
| [INTEGRATION_VERIFICATION_TESTPLAN.md](INTEGRATION_VERIFICATION_TESTPLAN.md) | Focused integration requirements/checks;later full UVM scope |
| [THROUGHPUT.md](THROUGHPUT.md) | Current cycle witnesses and combined implementation measurements |
| [PIN_CONFIG.md](PIN_CONFIG.md) | Current subsystem top ports and virtual-pin assignments |

Comprehensive coverage documentation will be added when that work begins.
Do not create a separate documentation suite for each module pair.

Stage5C now adds tested shared raw-SHAKE routing and seed collection. Select
`set DILITHIUM_STAGE 5` and `set DILITHIUM_TEST shared_hash` in the existing launcher;
use Python --stage 5 --unit shared_hash.26 commands,1699 hash bytes and1792
coefficients derived from RTL-collected seeds pass. Main top ports/memory are
unchanged;the memory choice is now resolved above. Full commands:REFERENCE_VERIFICATION.md.

Current direction (2026-10-20):integrate for correct functionality and outputs
first,then optimize Fmax,area and throughput. Stage4 all-engine functional checks
pass;next is Stage5 algorithm audit/controller/process work. The open148MHz
goal does not block that work.

Stage5A has now completed the initial audit and shared arithmetic unit tests:
10349 accepted cases,10346 outputs,3 reset aborts and13 expected errors.
Final FIPS204 ML-DSA-44/65/87 bytes are selected,with level2/3/5 names.
Stage5B's isolated KeyGen message formatter passes165 commands and5888 SHAKE
bytes;see REFERENCE_VERIFICATION.md for execution and limits. MEMORY_MAP.md's
KeyGen storage schedule remains a proposal needing a major architecture choice.
Selector5 tests process by default,or hash_format with DILITHIUM_TEST;the default4
continues to test the current all-engine connected subsystem.

Current runnable projects are standalone:

- Keccak: [simulation](../../sim/keccak/README.md),
  [Quartus](../../quartus/keccak/README.md).
- Sampler: [simulation](../../sim/sampler/README.md),
  [Quartus](../../quartus/sampler/README.md).
- NTT: [simulation](../../sim/ntt/README.md),
  [Quartus](../../quartus/ntt/README.md);source/UVM relocated unchanged from ntt_v2.

The current connected Stage4 top is src/controller/keccak_sampler_ntt.sv;
focused tests use [sim/dilithium](../../sim/dilithium/README.md),and the evolving
combined project is [quartus/dilithium](../../quartus/dilithium/README.md).
The main algorithm controller and remaining process blocks follow the shared
roadmap. Standalone metrics are not system metrics.
