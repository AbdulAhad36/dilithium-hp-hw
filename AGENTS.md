# Integration workspace

## Source cleanup and naming

The superseded service/handle controller hierarchy and its dependent benches
have been removed. Current RTL and focused benches have no `lighthd_` prefix;
the main package is `dilithium_pkg`. Production sources are listed in
`quartus/dilithium/dilithium_full.qsf`. `sim/dilithium/run.do` now defaults to
the current main capture; obsolete Stage2-5 selectors are retired. Historical
qualified scratch inputs, source freezes and evidence archives retain their
original names and hashes. Their PPA results predate this nominal cleanup;
do not compare those freezes directly to the renamed live source tree.

- Branch: integration. Do not commit,push or switch branches without instruction.
- Preserve user-authored/uncommitted RTL,tests,reference models and NIST data.
- Maintain src/keccak,src/ntt,src/sampler,src/controller/process and controller memory/FSM organization. Keep individual module verification/synthesis packages reusable.
- Implement final FIPS204 ML-DSA-44/65/87 with user-facing level names2/3/5. Reconstruct published LightHD architecture accurately;do not claim equivalence to unavailable RTL.

## Current objective

Reach150+MHz with positive setup slack while retaining correct outputs and roughly the current32K placed-ALM footprint. Area reduction is deferred. Same CycloneV5CGXFC7C7F23C8,6.500ns target,unchanged hold constraints. Do not hide failing timing with false paths or selectively report fast corners.

## Efficient workflow

- One measured critical cone and one candidate at a time. Focused tests and a structural/synthesis screen precede any full fit.
- Full NIST/UVM regression is for a candidate intended to be retained. No automatic chain of full runs after small edits.
- Reuse existing runners and one scratch workspace. No per-trial scripts,JSONs,ZIPs or document copies.
- Update Dilithium docs only for significant verified improvements,accepted milestones or major architectural decisions. Keep routine trial notes in existing local logs.
- Give concise decision/result updates. Ask for major architectural decisions;routine implementation choices are already authorized.
- Use actual final placed ALMs[A],worst four-corner Fmax/setup/hold and measured operation clocks/rates. Report failures and limitations plainly.
- Do not advance to Stage8/netlist/FPGA acceptance without the user's gate.
- Preserve current operation cycle counts. User declined the proposed Process
  output buffer;use equivalent control/data rewrites without added latency.

## Active aligned Keccak output plus physical-duplication fit

Qualified fallback remains protected trial87.17MHz/31959placedALMs. Previous
selected FSM/packer fit was REJECTED despite lower area:31566placedALMs;
slow85C85.89/-5.143/+.289,slow0C87.34/-4.950/+.195,
fast85C175.22/+.793/+.129,fast0C198.41/+1.460/+.101. All239hashes/50guards
passed,but Fmax priority lost versus87.17. Restored ALL59RTL exact baseline.
No full210/protocol88/UVM33 replay for rejected fit. Controller FSM phase
experiments and discarded-payload packer optimization are NOT live now.

New ONLY live production RTL changes:src/keccak/keccak_output_unit.sv and
src/keccak/keccak_core.sv. Output unit adds safe-default ALIGNED_COUNTER=0;
core enables it because its counter writes are only0 or+OUTPUT_BYTES. New
posedge assertion checks low counter bits stay0. Under that invariant,rate
remaining is below one beat iff rate/counter high fields match;low rate bits
give the tail. Original XOF clipping,permutation decision,data indexing and
counter updates remain. Self-equality of rate bits preserves old procedural
X behavior and is hardware true for known bits. No new RTL FFs or clocks.

Actual qualified-output-unit comparison PASS:64bit2801712+128bit3563568=
6365280 all-output checks;all2048rates/aligned8bitcounters;all65536XOF lengths
per available bound;X/Z rate and XOF probes. Existing registered-launch TB
also PASS18SHAKE128/256 outputs,offset0/1/26,stalls,pending-reset. New proof
top tb_keccak_output_bounds was added to that EXISTING bench file,no new.do.
Fresh main9NIST PASS27700exact key/signature bytes/3Verify digests;all9cycles
exact8849,19791,11483,15183,29674,17150,24534,44489,27785. Core counter
alignment assertions active. Golden models unchanged. No full210/88/UVM33
for this candidate yet. Functional/code coverage remain baseline evidence.

Dual-Keccak helper counter->outputbytes7.772->7.488ns,counter->internal
12.022->11.848ns;global worst data-path10.349->10.290ns. This is a small
UNPLACED gain,not a fitted Fmax claim. Selected rejected layout's measured
worst came from bytes_squeezed[4] fanout263 through output-byte metadata to
Sign state,11.383ns;most delay was routing. Current test therefore enables
PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION ON in SCRATCH probe.qsf ONLY. All
other meaningful settings match protected trial/production. Production QSF
still OFF;SDC unchanged6.500ns/samehold/device/seed. No registered-next-state
or extra pipeline stage was introduced. Check fitter duplication logs before
claiming that the compiler actually duplicated registers.

ONE fit now RUNNING:background Python PID16532(launcher98205),revision probe.
Read probe_compile.log,probe_compile_console.log,probe_fit_errors.log. Header
KOU_PHYS_POST_MAP_SOURCE_FREEZE contains239post-map hashes. Pre-fit audit
passedall50permanentguards/8DSP/409446blockbits. Full unplaced source paths:
counter->Sign12.157ns,counter->KeyGen13.054ns,global20.473ns (not better than
20.469 baseline);physical duplication is a FITTER optimization,not yet applied
in those map estimates. The post-map audit script had an indentation typo
(NameError baseline);independent corrected audit verified all238other hashes
and EXACTLY the one allowed QSF setting change. Valid synthesis/STA reports
were reused,not rerun. Old probe_compile_errors.log records that resolved
audit typo;current fitter errors are in probe_fit_errors.log.

Pipeline runs fitter then permanent report_full.tcl with strict Tcl catch,
all4corners and retention guard,critical_probe outputs. Require BOTH
KOU_PHYS_FIT_REPORT_PASS and KOU_PHYS_FIT_AND_REPORT_COMPLETE before using PPA.
Until then,critical_probe corner files are OLD rejected85.89MHz FSM results.
Compare actual placed[A]ALMs,worst4cornerFmax/setup/hold against87.17;no area
estimate substitution. Only if intended retained,run full210official/88protocol/
33mainUVM and compare protected trial captures/latencies. No Stage8 or150+claim.

To revert this candidate:output-unit qualified snapshot is LAST in
root_mux_reference.sv;extract full original /* Module Name:keccak_output_unit
comment to EOF,rename keccak_output_timing_reference back. Core reversion
removes only the added ALIGNED_COUNTER named parameter/comma and appended
alignment-assertion block;verify resulting hash against trial_map.log BEFORE
writing. This exact reconstruction already restored baseline for helper test.
Do not overwrite snapshots blindly:verify live input hash and preserve edits.
Root reference also preserves original controllers/Hint/Bitpkg;extract each
full source only BEFORE next appended comment. Protected trial/kernel/baseline
and other qualified slots remain untouched. No commit,push,branch change,
Stage8,new archive,per-trial scripts/JSONs or universal-doc trial history.

## Earlier packer discard-payload screening

Hint word-mux trial was REJECTED after routing:32124placedALMs,8DSP,59M10K,
409446bits;slow85C86.28/-5.090/+.298,slow0C85.72/-5.166/+.139,
fast85C168.27/+.557/+.135,fast0C190.99/+1.264/+.108. All50 hardware guards
passed and239fit hashes matched,but worst85.72 regressed qualified87.17.
Reverted Hint and verified ALL59RTL exact baseline before the next edit.
No full210/protocol88/UVM33 for that rejected trial. Details in synthesis.log.

Qualified fallback remains trial87.17MHz/31959placedALMs. Packer part of the live candidate
is src/controller/process/bitpkg.sv:payload appends tentatively on push;
invalid value/frame still clears logical count and enters REPORT with the
SAME error code/edge. Removed validation-dependent bits_r clear. Reset and
new-command reservoir clears unchanged. No new registers,buffers or cycles.
Only discarded reservoir contents may differ in REPORT/IDLE after code2/3;
all live payload,control,count,state and valid outputs must remain exact.

Existing tb_pack_stream has optional ALLOW_REJECT_PAYLOAD_RESIDUE=1 profile;
default0 keeps strict old checking. The profile allows ONLY code2/3,non-FEED
payload differences and asserts count0/output_valid0. All other comparisons
remain strict. PASS360jobs/60resets/240malformed/7040words/16701clocks,
793isolated discarded-payload clocks. Independent tb_bitpkg PASS125packets/
15624coeffs/2497words/1654stalls. Models untouched. Existing Hint tests added
last pass remain reusable;their optional baseline reference is preserved.

Measured retained87.17 fitted packer path11.022ns via validation->144bit
synchronous clear;trial.qsf was opened read-only at close and its hash exact.
Helper unplaced data->bits18.019->10.784ns,error control12.964->9.214ns,
overall19.520->16.294ns. These are NOT fitted PPA/Fmax gains.
Full production constraints stay6.500ns/same hold. Full unplaced screen PASS:
pack_raw/Process->packer bits16.681ns;Verify->writer10.593ns;global20.431ns
(process_owner_r->Sign entropy_mask_store_r) versus baseline20.469ns. This
barely changes the global estimate,so NO second routed fit was launched.
Fresh main9 PASS27700NIST bytes/3Verify digests/3valid0invalid;token
77beed954a7bb071594c1653d6273f0272a814dda12d87037615b2fde262c833.
All9cycle counts exactly prior focused run:
8849,19791,11483,15183,29674,17150,24534,44489,27785.
All50permanent storage guard categories PASS;exact144original packer payload
registers verified from fresh names and corrected raw collection query.
One temporary extra-bracket typo made an optional Tcl count string144] and
failed that extra probe;correct reread144 and independent audit resolved it.
No hardware was missing. Map still8DSPs/409446blockbits. Original production
QSF/SDC unchanged;probe QSF canonicalization is audited in probe_map.log.

At completion of that packer-only screen,all jobs had finished and that
change was unfitted. Current combined fit status is given above. Keep qualified trial87.17MHz/31959placedALM and its evidence intact.
No full210/protocol88/UVM33 replay for this candidate yet. Next measured work
is remaining launch/control cones before another costly fit;qualified
baseline's near-tied Verify state->writer fault11.225ns is still relevant.
Current scratch:probe_map/sta/compile.log and probe_{launch,hint,setup}.rpt
are PACKER UNPLACED;probe_retained_registers and probe_mapped_register_names
are its fresh guard outputs. probe_proof.log mixes UTF16old/UTF8append;use
read_bytes().decode('utf-8',errors='replace') for recent appended main9 PASS.
probe_compile_console.log explicitly says no new routed result. critical_probe
fitted corner files remain the REJECTED85.72MHz Hint layout,not packer PPA.
Routine facts stay in synthesis.log;no new JSONs/scripts/archives/doc copies.

root_mux_reference.sv now additionally appends exact qualified bitpkg as
bitpkg_timing_reference. Restore from its original source comment to EOF,
rename module back and verify trial_map source hash. Prior Hint snapshot now
ENDS BEFORE the appended packer comment,so do not blindly take Hint to EOF.
Qualified trial/kernel/baseline slots untouched. Routine notes only locallog;
no Stage8,commit,branch change,new archive or universal-doc trial history.

## Earlier physical screens

These screens predate the active unfitted packer candidate above. At their
completion,all59RTL hashes matched qualified87.17;production QSF/SDC unchanged.
The split writer-fault RTL was rejected before fit:128sticky-state/event model
checks and2997shadow clocks/17batches/2178writes/34completions/4resetrecoveries/
8rejects passed,but helper overall16.620->16.590ns was negligible. Reverted.
writer_probe_reference.sv preserves the exact prior writer for new optional
CYCLE_REFERENCE in existing tb_sampler_writer_queue.sv;preserve this test input.

Physical-only MAX_FANOUT16/PRESERVE_REGISTER ON for Verify state* was tested
in scratch probe.qsf. Correct QSF targets need quotes,NOT literal braces.
Mapping inserted17 copies;genuinely unplaced Verify->writer fault path improved
11.006->9.754ns. But the FULL fit REGRESSED:32018placedALMs,worst85.12MHz/
setup-5.248ns(slow0C),hold+.106ns(fast0C). All four corners:
slow85C85.38/-5.212/+.282;slow0C85.12/-5.248/+.251;
fast85C171.94/+.684/+.129;fast0C196.39/+1.408/+.106. REJECTED;not promoted.
New fitted worst source moved to Keccak stop/state/arbiter->KeyGen state.
Do not treat the local mapped gain as a full-design Fmax improvement.

probe revision/output/probe.* and critical_probe are DISPOSABLE failed-trial
artifacts inside the SAME timing_screen workspace. probe_map.log freezes
59RTL plus actual scratch QSF and baseline production QSF/SDC/report;all63
hashes matched final audit. Independent parsing checked every permanent
retention category against its minimum,6originalVerify state FFs survived,
8DSP/59M10K/409446bits retained. Interactive report emitted no qualifying
failure;the independent guard audit was authoritative,not just a footer.
All background jobs are finished. No full NIST/UVM replay:RTL was byte-identical,
so retained87.17 baseline's full210/protocol88/UVM33 remains applicable.

Only scratch profile and reusable optional writer-shadow bench changed. No
production physical assignments,no commit/branch change,no Stage8,new archive,
JSON,per-trial script or universal-doc history. Routine trial details remain
in synthesis.log. Next work should inspect retained baseline near-tied control
paths and avoid repeating this blanket Verify-state maxfan profile.

## Saved baseline

Current retained design:local ProcessDMA sink-credit clears. Each credit
clears from the OTHER sinks' readiness,removing shared result_fire fanout.
All three original sent registers remain;NO new registers,buffers or clocks
were added to RTL. Prior KeyGen/Sign parallel-ID comparisons remain. All jobs
stopped. Retained-hardware guards and237 source/config/reference hashes PASS.

Same CycloneV/6.500ns,unchanged hold constraints. Actual31959placedALMs/
23238mappedregisters/59M10Ks/8hardDSPs/409446blockbits. Worst87.17MHz/
setup-4.972ns(slow85C),hold+.124ns(fast0C),all four hold reports no violations.
Versus86.48MHz:0.798%Fmax/rate-ceiling improvement,+100placedALMs,
setup improved.092ns,NO new operation clocks. This is a SMALL gain;150+MHz/
positive setup remain OPEN. Do not claim the target is achieved.
Four corners(Fmax/setup/hold):slow85C87.17/-4.972/+.296;
slow0C88.14/-4.846/+.290;fast85C162.47/+.345/+.135;
fast0C186.92/+1.150/+.124. Report worst corners,not the fastest number.

Fresh full210official(75KeyGen/90Sign/45Verify)/744280bytes/35Verifydigests/
9valid36invalid and protocol88/148704bytes PASS. All94312 full and18793
protocol records exact86.48 except separate source tokens. Main33UVM PASS:
30checked/3resetaborts,0errors/fatals;all30 outcome and latency rows exact86.48.
Functional116/170=68.24%;raw code135852/178119=76.27%(modules135840/178012,
package12/107). The coverage exporter now uses dilithium_pkg;this run completed
its reporting normally. Checker90/first-byte negative were NOT rerun;prior
C26 evidence remains prior. No Stage8,commit,push or branch change.

Focused proof:1024 arbitrary binary enable/credit/ready/valid combinations
passed for all three flags. Existing tb_process_dma CYCLE_REFERENCE gate
compared23 output ports plus three credits for17468 clocks;64 arithmetic/
packing/stall/reset cases,11008coefficients,464packed words,3negative and
3reset recoveries PASS. Main9:27700 published bytes/3digests PASS.
Genuinely unplaced standalone screen:packed-ready worst9.368->8.845ns;
matched hint-credit endpoint3.426->3.053ns. These are NOT fitted Fmax numbers.
No per-trial script,JSON,ZIP or universal-doc experiment history was added.
Routine rejected-trial notes remain in synthesis.log;do not retry parity-credit
or append-before-pop rewrites without new evidence. Both passed correctness
but failed the screen,and were restored before this candidate.

ONE workspace:sim/dilithium/reference_build/timing_screen.
PROTECT trial.qsf/output/trial.* and critical_trial:NEW qualified87.17MHz fit.
trial_map.log first line SOURCE_FREEZE has237 hashes(all exact final audit,
including shared report.tcl). trial_full210.txt/trial_protocol88.txt preserve
native captures;trial_uvm.* and trial_uvm_console.log preserve UVM evidence.
trial_compile.log has TRIAL_FIT_AND_REPORT_PASS;trial_proof.log has the local
shadow checks. Native simulations were started hidden in background and are
finished. Current run has no post-map tool-name fixes/hash exceptions.

PROTECT kernel.qsf/output/kernel.* and critical_kernel:qualified86.48MHz/
31859ALMs/-5.064ns/+.124ns fallback. kernel_map.log freezes236 files;its
appended QUALIFIED_ANALYSIS_TOOL hashes explicitly record two earlier naming
fixes in report_full.tcl and report_uvm_coverage.tcl. Do not rewrite that freeze.
kernel_full210.txt/kernel_protocol88.txt and kernel_uvm.* preserve its evidence.
process_dma_trial_reference.sv is its exact pre-change DMA,renamed only to
process_dma_timing_reference;preserve it. Restore the module name to recover
the prior controller. Existing tb_process_dma.sv has the optional shadow gate.
trial_reference.sv is the older83.90 pre-KeyGen-change controller;preserve it.

kernel_old/critical_kernel_old retain83.90MHz;baseline/critical_baseline retain
83.28MHz;candidate/critical_candidate retain79.74MHz;screen/critical_full retain
75.33MHz. These accepted revisions are NOT disposable. Their old source names/
freezes predate cleanup;do not compare them with the renamed live tree.
Next experiments need ONE reusable disposable revision in this SAME workspace;
do not overwrite protected trial/kernel/kernel_old/baseline/candidate/screen.
Main quartus/dilithium/output_full remains historicalC26(31923ALMs/72.36MHz/
-7.320ns/+.088ns),NOT latest RTL evidence.

Next measured cones:Verify state[0]->sampler-writer fault_o,11.225ns(slow85C),
and Sign state[5]->shared hint indices,11.190ns. KeyGen-to-hint-credit is no
longer worst. Inspect these actual paths/fanout before another candidate.
Preserve operation clocks;user declined a new Process output buffer. Physical
interconnect is substantial;consider placement/fanout work with unchanged RTL
if further equivalent logic rewrites keep giving marginal gains.

Screening caution:--post_map can load PLACED databases. Use genuinely unplaced
screens and verify Unassigned locations. Standalone I/O screens used0 input
delay only for matching before/after measurements;production SDC stayed exact.

Qualified fallback archives remain in docs/dilithium_docs/evidence. C25R2 archive SHA256:3acb8226d54ebd8843e7e37550f5e06e5f620159876e85e09c298d3550e1efbb. Its fresh extraction replay passed without fixture regeneration. Preserve C20/C21/C22 and qualified checkpoints;failed scratch artifacts may be cleaned.

## Tools and dependencies

- Production project: quartus/dilithium/dilithium_full.qpf;top dilithium_fpga;report_full.tcl.
- Main simulation: sim/dilithium/run_uvm.do. Reference/vector CLI: sim/dilithium/dilithium_vectors.py.
- Python:C:/Python314/python.exe;Questa:C:/questasim64_2024.1/win64;Quartus:F:/altera/quartus/bin64.
- Current reusable qualification bundle:sim/dilithium/reference_build/stage7c26_*;C25R2 comparison data and C18R1 arithmetic proof dependencies are retained there.
- Coherent admission is enabled only in the paired bank fabric. Keep safe standalone defaults and ownership/IDLE/grant-ready assertions.
- Keep8hardDSPs,original Process/polynomial storage and required buffering. Physical-netlist simulation does not replace TimeQuest timing signoff.
- Retained LightHD reading assets are under tmp/pdfs. Temporary compiled/extracted copies are disposable;never delete source dependencies indiscriminately.
