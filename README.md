# Dilithium integration (`integration`)

## Historical Stage7B.9 baseline

Stage7B.9 baseline complete: the user-approved production top is
`src/controller/dilithium_fpga.sv`. It wraps the unchanged controller with all
three operations enabled;debug remains in the core and standalone tests.
The production interface has51 signal groups/1027 bits including clock.
Main UVM and `quartus/dilithium/dilithium_full.qpf` now target this wrapper.
Fresh main33 UVM and the corrupted-key/zero-credit gate pass. The full design
now routes on the same Cyclone V at51,162 actual placed ALMs,62 M10Ks and27 DSPs.
Timing remains far from target:Fmax23.97MHz,setup−34.965ns,hold+0.099ns at the
unchanged6.757ns constraint. Next is measured Verify-path timing optimization;
Stage7 is not closed. Earlier failed-route results retain their historical scope.
[Plan](docs/dilithium_docs/DILITHIUM_PLAN.md) and
[coverage](docs/dilithium_docs/COVERAGE.md) contain scope and remaining gaps.

Stage6 complete: the current full-operation main passes 75/75 published
KeyGen, 90/90 pure external Sign and 45/45 pure external Verify cases.
All 433600 key bytes, 310680 signature bytes and 9 valid / 36 invalid Verify
verdicts match. Checkers reject 41/41, 152/152 and 158/158 corruptions.
At that milestone,all74 RTL files and the clock constraint matched the preceding
functional stage;later Stage7 changes are qualified separately above. Evidence is frozen
in docs/dilithium_docs/evidence/stage6_full_operation_qualification.zip +SHA256.
Next Stage7: full-main UVM and Quartus baseline, then Fmax/area/throughput work.
[Commands,results and mode limits](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5V.4 complete:main now dispatches KeyGen,Sign and Verify. The full-operation
configuration uses FULL_KEYGEN=1 with both later features enabled. Verify's
PK/signature/ctx||M stream passes118 scenarios and all45 official pure verdicts
(9 valid,36 invalid),with2624604 exact writes/51466 reads.170/170 checker faults
reject. Fresh Sign45 and KeyGen-only16 compatibility pass. Same memory/clock
target;72 old RTL and production C/SDC unchanged,main updated,verify.sv added.
NextStage6:current-source full published operation suites,then UVM/PPA work.
[Results,commands and study order](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5V.3 complete:the real Verify preparation chain now feeds the equation,
UseHint,shared packing/hash and challenge comparison.87 scenarios pass:
19 valid,35 cryptographically invalid,23 expected errors,10 resets/faults.
All35 structurally valid official verdicts agree;966 UseHint cases and172
checker faults pass.2104627 exact writes/49903 reads;fresh134-scenario prior
preparation regression passes unchanged. Same four-bank pool;71 old RTL/SDC
unchanged,two new modules. Next5V.4:main Verify/op2 three-frame connection.
[Commands,results and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5V.2b complete:message hashing,challenge sampling and shared NTT/Pre-NTT
now prepare the Verify arithmetic context.134 scenarios pass:65 contexts,
57 expected errors,12 resets/faults;236834 exact writes/84099 packed reads,
848 NTT commands including68 Pre-NTTs.112/112 checker corruptions reject.
Fresh5V.2a revalidation also passes. All70 prior RTL files remain unchanged.
Next5V.3:Verify equation,UseHint and challenge comparison. Main op2 follows.
[Commands,results and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5V.2a complete:Verify PK/signature loading uses the existing four banks
and computes tr with shared SHAKE256.133 scenarios pass:49 prepared contexts,
73 expected errors,11 reset/fault cases;360545 exact coefficient writes and
61827 packed reads.87/87 checker corruptions reject. Fresh shared SK-load,
full KeyGen and main Sign compatibility pass. Main RTL Verify remains pending.
Next5V.2b:ctx||M hashing,challenge and NTT preparation. No commit or new PPA.
[Results,commands and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5V.1 Verify decoder complete:383 scenarios/705010 exact values,99 expected
errors/9 resets;37 checker corruptions rejected. Full C Verify matches45/45
official NIST pure verdicts (9valid/36invalid). This is a decoder/software gate;
main RTL Verify remains unwired. The three-frame PK/signature/ctx||M interface
is approved. Next:bank loading and public-key hashing,then Verify arithmetic.
Fresh full-KeyGen compatibility and37 checker faults also pass. No commit.
[Results,commands and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4h.7 official NIST Sign gate:90/90 pure signatures match310680
published bytes,15 deterministic+15 randomized per level2/3/5.152/152 checker
corruptions reject. All360 original cases are retained/audited;270 prehash/
internal-API cases are explicitly unsupported. All67 RTL files are unchanged.
Fresh local main Sign45 scenarios and196 checker faults also pass. Main Verify
is next. Frozen evidence:docs/dilithium_docs/evidence/stage5n4h7_nist_sign.zip
and SHA256. Nothing committed;no new PPA/full-UVM/netlist claim.
[Source,results,execution and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

## Previous checkpoints

Stage5N.4h.6 connects the actual main Sign controller and approved64-bit
two-frame input (expanded SK,then ctx||message). Fresh45 cases PASS:
21 complete signatures/63204 exact bytes,one mixed KeyGen,14 expected errors,
9 reset/fault aborts;196/196 checker corruptions reject. KeyGen compatibility
gates pass. One physical services tree;key/payload cleanup before Sign done.
These signatures match unchanged production C Sign+Verify and are local
reference-derived fixtures. Next:official NIST Sign vectors,then main Verify.
[Results,commands and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4h.5 adds complete signature encoding after the real attempt/retry
path.24 scenarios pass:7 full signatures/25339 exact bytes,9 expected errors,
8 aborts;163 checker corruptions reject. It uses the shared packer and existing
banks,with atomic source ownership,backpressure and whole-context cleanup.
Independent Python/C agree;three fixtures also match full C signing. These
are local reference-derived signatures,not official NIST signature vectors.
Next:connect main Sign host dispatch;main Verify remains unfinished.
[Run commands,results and study order](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4h.4 connects automatic candidate retry with retained private-seed
reuse. Fresh47 cases pass:19 accepted results,12 expected service failures,
5 nonce-exhaustion stops and11 aborts;87 attempts/45 genuine rejections,
105667 exact y coefficients/56256 packed reads. All152 checker faults reject.
The original78-case mask regression and85 checker faults pass too. No message
replay or private-seed rehash on retry;no nonce wrap. Next:signature encoding
and main Sign dispatch. Main Verify remains unfinished.
[Results,commands and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4h.3 connects whole-attempt CNB,combined-low ADD and Mhint checks.
Fresh59 cases pass:18 accepted candidates,5 genuine rejections,21 expected
errors,15 reset/fault aborts;70944 exact writes/157888 packed reads. All118
checker corruptions reject;Python/C agree on8 fixtures/25794 values. One
rotating hint region reuses the existing banks. Rejection retains private
retry headers after discarding payloads. Next:nonce retry with seed reuse,
then signature packing/main Sign. Main Verify remains unfinished.
The prior63-case products regression and84 checker faults also pass.
[Run commands,results and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4h.2 connects challenge/secret PWM+INTT products and in-place
z/low correction.63 cases pass:24 arithmetic completions,21 expected errors,
18 reset/fault aborts;425955 exact writes,99584 packed reads;84 checker faults.
Prior51-case transform regression passes too. Retry headers remain with the
result. Next:norm/hint acceptance,then retry/signature bytes. Main Sign/Verify
remain unfinished. [Results and run commands](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4h.1 adds atomic matrix/challenge ownership transfer,dead-yhat reuse
and FNTT(c).51 cases pass:24 successes,12 expected errors,15 reset/fault
aborts;7875 exact writes,85760 packed reads,64 checker faults. The prior
81-case challenge regression also passes. Key/raw y remain retained;the
new context holds w0/w1/chat and ctilde. Next:secret products and response
arithmetic;main Sign/Verify remain unfinished.
[Results,commands and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4g connects retained w1 to shared packing,SHAKE256(mu||w1) and
SampleInBall. Fresh81 cases pass:24 successes,39 expected errors,18 reset/
fault aborts;8640 c writes,171264 packed reads and77 checker corruptions.
Python/C agree on six complete challenge fixtures. Extended136-case shared
packer and full-KeyGen regressions pass. Main Sign/Verify remain unfinished;next are safe
memory ownership handoffs,challenge/secret products,z/hints/norms and retry.
[Commands,results and study guide](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4f connects ordinary NTT(y),full A*y and x4 decomposition through the
existing shared services. All levels pass:24 whole-vector executions,24
expected errors,18 reset/fault aborts,1060230 exact writes and102336 packed
reads;66 checker corruptions reject. Python/C agree on96256 intermediate
values;fresh KeyGen regression passes. Key/original-y storage is preserved.
Main Sign/Verify remain unfinished. Next:w1 packing,challenge hashing and
SampleInBall. [Results and run commands](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4e connects retained signing keys to real shared Keccak/sampler/banks:
mu -> private mask seed -> full4/5/7-polynomial y vector.78 command cases,
6800 digest bytes,49094 scalar writes and83136 packed reads pass independent
comparison;85 checker faults reject. Fresh KeyGen regression also passes.
Main Sign/Verify remain unfinished. Next:NTT(y),A*y and decomposition.
Commands/provenance/results:
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4d prepares and retains signing keys through the existing shared
services:Pre-NTT for s1/s2,forward NTT for t0,one rotating scratch region.
All75 official KeyGen SK inputs match independent expected transforms;
retention,clear,rollback and eight reset/fault cases pass.55 checker faults
and fresh KeyGen/shared-loader regressions pass. Main Sign/Verify are still
unfinished. Next:retained-key signing hashes and mask generation. Results:
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4c2 connects key loading to the production shared service and its
existing four banks. The gate checks all75 official KeyGen SKs,late rollback,
reset/reuse,prior-owner arbitration and actual key-to-CNB handoff. No duplicate
engines/memory. Main Sign/Verify remain unfinished;validated key retention and
shared secret transforms are next. Current commands/results are in
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4c1 adds whole-key memory ingestion:138 commands,449992 checked scalar
writes,105728 exact packed readbacks and all75 official KeyGen secret keys.
Late failures roll back every earlier polynomial;five reset cases pass.
This is a real-bank client gate;connection to the production shared arbiter
is next(Stage5N.4c2). Main Sign/Verify remain unfinished. Run instructions:
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).

Stage5N.4b implements signing-message formatting against the actual shared
Keccak/sampler/bank service:167 commands,7760 exact raw SHAKE bytes,6400 mask
coefficients,29 peer jobs,9 actual digest forwards and61 checker faults PASS.
Decoder/shared-process/local KeyGen regressions pass;all55 prior RTL files
and6.757ns SDC are unchanged. Next:whole-key private bank ingestion.
Main Sign/Verify,RTL w1 packing and full signatures remain unfinished.
See universal reference/specification docs for limits and error-drain ownership.

Stage5N.4a adds a streamed expanded signing-key decoder,verified with all75
official KeyGen secret keys plus malformed/reset/boundary cases:129 commands,
436424 exact emitted coefficients and35 checker corruptions. This is a process
foundation;main Sign/Verify and decoder-memory ingestion remain pending.
Next Stage5N.4b:signing hash-message formatting and shared-Keccak checks.
Run instructions and result distinctions are in the universal reference docs.
Earlier milestone paragraphs below describe their historical state.

Stage5N.3 connects Decompose/CNB/Mhint to the existing main-owned shared banks
through sign_process_dma. It checks read ownership/metadata,canonical result
storage,late-error rollback,source/result leases and acknowledged atomic
Decompose publication. New DMA and shared-service gates pass at levels2/3/5;
the latter uses real SHAKE/sampler sources. Exact counts/run commands are in
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).
Next:signing key/input decode and hash formatting,then retrying Sign control.
Main Sign/Verify and whole-system UVM/PPA remain pending. The following earlier
milestone paragraphs describe their historical implementation boundaries.

Stage5N.2 adds verified Decompose x4,CNB and Mhint arithmetic with tagged
polynomial transport.7752 x4 groups and117 complete polynomials are checked;
local KeyGen and all75 official NIST keypairs still pass. Next connect these
new processes to shared memory DMA,then continue Sign. Main Sign/Verify are
not implemented yet;the universal docs below describe the exact boundary.

Stage5N.1 now places the shared engines,banks and Bitpkg under the main
controller,with KeyGen as an operation client. All75 official KeyGen cases,
the local reset/recovery suite and both polynomial diagnostic modes pass.
Next:Decompose x4,CNB and Mhint,then further Sign integration. The universal
docs linked below hold the current architecture and evidence.

Current full-KeyGen RTL uses FULL_KEYGEN=1 and produces complete encoded
public/secret keys at levels2/3/5. Stage5L matched the independent C reference
and preserved all16 integration gates. Stage5M passes all75 official NIST KeyGen
cases through the same launcher/script;433600 key bytes match. See commands in
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).
Sign/Verify and whole-system UVM/PPA remain later work. Earlier stage summaries
below are historical milestones.

Canonical roadmap: [DILITHIUM_PLAN.md](docs/dilithium_docs/DILITHIUM_PLAN.md).
It records the agreed controller/process/memory layout, incremental module
imports with their standalone assets, universal Dilithium documentation, and
the progression from focused integration tests to full-operation vector checks
and comprehensive UVM/synthesis optimization.

Stage1 Keccak import is verified:904 source UVM transactions plus dual suites,
6364 exact NIST output matches,and a fresh standalone Quartus timing PASS.
See [SPECIFICATION.md](docs/dilithium_docs/SPECIFICATION.md) for provenance and
placed-area/timing results. Stage2 now connects real Keccak to the sampler:
104 source jobs/23089 coefficient checks and12 checker fault cases pass.
See [the shared integration docs](docs/dilithium_docs/README.md) for the current
architecture and run commands. The initial combined clock target is148MHz;
the initial combined fit reaches129.18MHz,11059 placed ALMs and?0.984ns setup.
Timing at148MHz remains open. On2026-10-20 the user chose functionality-first
integration, with Fmax/area/throughput optimization after correct full-operation
outputs. The6.757ns benchmark stays unchanged;it does not block Stage3 memory.
Major architecture decisions will be confirmed with the user.

The user approved the four-slot pool;Stage3 now connects Keccak,sampler and
polynomial memory.104 jobs pass with23180 write checks and22528 exact readbacks.
Stage4 now adds the accepted NTT package from ntt_v2:577a34b and its standalone
assets. The default simulation exercises all three engines through memory:
50 commands,30 arithmetic results,17 rejections,3 reset aborts and11776 exact
stored readbacks PASS. See the shared docs for `compare --stage 4` and preserved
Stage2/3 modes. Next:Stage5 algorithm audit/controller/process work.
Quartus points to keccak_sampler_ntt;Stage4 has no fresh fit or PPA claim.

Stage5A adds the shared ADD/SUB/Power2Round unit under controller/process:
10349 accepted cases,10346 exact outputs,3 reset aborts and13 expected errors
PASS. Select DILITHIUM_STAGE=5 for its isolated gate. The user selected final
ML-DSA-44/65/87 bytes with level2/3/5 labels. Stage5B adds a checked seed/nonce
message formatter:165 commands,5888 exact SHAKE bytes. Full KeyGen and shared
main-controller scheduling remain work in progress;see the shared docs for commands.
Stage5C now verifies optional shared raw-SHAKE routing and seed collection using
the same two hash cores:26 commands,1699 exact hash bytes and1792 coefficients
sampled from RTL-collected seeds PASS. Main Stage4 top still disables the raw
client;KeyGen storage is now selected as LightHD's four1024x92-bit banks. The
bank foundation passes14872 requests/9509 exact reads;controller migration is
in progress. Stage5E now stores real sampled polynomials through per-context
packing/ownership:104 jobs,88 complete,5632 exact92-bit readbacks PASS. NTT
DMA/compute ownership is next;the default all-engine Stage4 baseline is retained.
PROCESS_BLOCKS.md and the
dimensioned MEMORY_MAP.md diagram are in docs/dilithium_docs/.

## Accepted sampler baseline

Accepted main design: **Stage4.9r — 3537 placed ALMs,164.74 MHz worst Fmax**.
Setup +0.430 ns,hold +0.141 ns at permanent6.500 ns;3931 registers,one M10K,zero DSP.
Main UVM621 complete/182 expected errors/51 aborts/159628 comparisons passes.
Functional coverage95.99%;raw DUT code coverage95.53%,with gaps left visible.

## Run it yourself

1. Open `quartus/sampler/sampler.qpf` in Quartus; **Processing → Start Compilation**.
   No SDC/QSF edits are needed.
2. In Questa GUI Transcript,from `sim/`: `do sampler/run_uvm.do`.
   Waves,functional coverage and DUT code coverage use the main UVM.
3. Independent vectors: `python FIPS204_SAMPLER/sampler_vectors.py prepare`;
   set `SAMPLER_MODE vectors` before the same .do,then run the Python `compare` command.

## Layout

| Folder | Contents |
|---|---|
| src/sampler | Accepted RTL |
| tb_uvm/tb_uvm_sampler | Main UVM and independent references |
| tb_uvm/tb_uvm_reusable | Common reusable templates |
| sim/sampler | Three .do launchers and current verification results |
| quartus/sampler | Project,constraints,current fit/timing reports and database |
| FIPS204_SAMPLER | One Python reference/vector script and input/expected files |
| docs/sampler_docs/post_midyear | Current design and verification documentation |

Start with [SAMPLER_PLAN.md](docs/sampler_docs/post_midyear/SAMPLER_PLAN.md).
Frozen evidence: [STAGE4_9R_RESULTS.json](docs/sampler_docs/post_midyear/STAGE4_9R_RESULTS.json)
and its self-contained evidence archive. Stage 5 accepted-build synthesis/fit verification passed:184 jobs and39936
coefficient checks per netlist;104-job captures match Python and source exactly.
See docs/sampler_docs/post_midyear/SAMPLER_NETLIST_RESULTS.json; Keccak/sampler/NTT integration follows separately. Native128 processing
is not active;the128-bit interface issues64-bit chunks internally.
