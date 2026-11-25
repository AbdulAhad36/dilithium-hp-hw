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

Reach150+MHz with positive setup slack while retaining correct outputs and improving operation clocks/rates. On2026-11-08 user explicitly prioritized Fmax/setup/cycle times and said forget ALMs;area is not an acceptance criterion beyond fitting the same device. Same CycloneV5CGXFC7C7F23C8,6.500ns target,unchanged hold constraints. Do not hide failing timing with false paths or selectively report fast corners.

## Efficient workflow

- User now requests batching at least 3-4 substantial timing changes into one candidate,then combined testing and ONE full fit. Focused correctness checks and a structural screen still precede that fit. Preserve the qualified89.81MHz fallback;do not fit each small change separately.
- Full NIST/UVM regression is for a candidate intended to be retained. No automatic chain of full runs after small edits.
- Reuse existing runners and one scratch workspace. No per-trial scripts,JSONs,ZIPs or document copies.
- Update Dilithium docs only for significant verified improvements,accepted milestones or major architectural decisions. Keep routine trial notes in existing local logs.
- Give concise decision/result updates. Ask for major architectural decisions;routine implementation choices are already authorized.
- Use actual final placed ALMs[A],worst four-corner Fmax/setup/hold and measured operation clocks/rates. Report failures and limitations plainly.
- Do not advance to Stage8/netlist/FPGA acceptance without the user's gate.
- On2026-11-04 user explicitly APPROVED targeted pipeline stages,accepting
  small operation-clock increases when overall throughput improves. This
  supersedes the prior exact-cycle restriction. Measure clocks/rates and retain
  safe standalone defaults;no unmeasured Fmax or throughput claims.

## Current implementation and qualification

The production RTL includes external and internal-message Sign/Verify via
start_internal_message_i. User-facing levels2/3/5 select final ML-DSA-44/65/87.
Prehash and external-mu are unsupported. Functional qualification passed345
supported operations(75KeyGen/180Sign/90Verify),1,054,960 expected key/signature
bytes,70Verifydigests,18valid72invalid. Protocol88 and formatter mode checks
also passed. Naming-only cleanup is not a fresh full qualification.

The current seed-1 fit reaches 97.10 MHz with -3.799 ns worst setup slack
and -37,243.049 ns worst setup TNS. Full NIST345, protocol88 and external UVM33
qualification passed on this source. Full UVM internal-mode coverage remains
pending. Protect the current pack_fields fit and the 93.68 MHz batch fallback
along with every
qualified timing_screen profile(active,next,dev,work,probe,trial),sourcefreeze,
QSF/SDC,map/fit/report/proof log,capture/UCDB and independent reference.
Do not overwrite them as disposable scratch. Past-build summaries are in
docs/dilithium_docs/PAST_BUILDS.md; exact pre-cleanup notes are in the verified
reference_build/evidence/documentation_history/before_current_names.zip.

## Active naming and documentation

Use stable descriptive active paths. Main fixtures/captures are main_inputs.txt,
main_outputs.txt,main_diagnostic_* and main_protocol_*. UVM uses uvm_inputs.txt,
uvm_expected.txt and uvm.* / uvm_* reports. Public vector commands include
main_prepare,main_compare and main_diagnostic_compare; historical CLI spellings
remain compatibility aliases. Frozen evidence retains original names/hashes.

Before replacing an accepted build,preserve meaningful exact source/constraints,
reports/captures and identity in the existing evidence area,with build-specific
historical names. Promote the accepted replacement into normal active paths.
Record change/result/keep-or-reject in PAST_BUILDS.md. Other active docs describe
only the present design. No per-trial document/JSON/archive proliferation.

Use patch-based edits so the user sees Codex review cards. Preserve original
user work and NIST edits. Never retag an old capture to pass source freshness.
All current capture outputs are written directly by the bench; do not add RTL
JSON exports or a Python output fabricator.

## Simulation and tools

run.do supports all/keygen/sign/verify on tb_main. DILITHIUM_FAST1 disables
broad+acc/waves;GUI defaults0,batch1. Keep RTL checks/cases. Content-sensitive
preparation/compile caches must invalidate on relevant edits; includes force
compile. DILITHIUM_REBUILD1 forces compile. Alternate DATA_DIR/WORK_DIR/LIBRARY
allow isolated tests without disturbing the user's running Questa session.

Python:C:/Python314/python.exe;Questa:C:/questasim64_2024.1/win64;
Quartus:F:/altera/quartus/bin64. Do not use the other unlicensed Questa install.
Production project:quartus/dilithium/dilithium_full.qpf;top dilithium_fpga.
Capture launcher:sim/dilithium/run.do;UVM:sim/dilithium/run_uvm.do.
Reference CLI:sim/dilithium/dilithium_vectors.py. Reuse existing timing_screen
scratch and report tools. A --post_map screen can accidentally load a placed
DB; verify genuinely unplaced locations before treating it as an early screen.

Keep safe standalone defaults,coherent port/admission ownership,immediate
fatal quarantine,finite completion/drain and dual-core job isolation. Do not
remove required NTT DSP/storage/Process buffering to simplify a benchmark.
Physical simulation does not replace TimeQuest signoff. Source-dependent C18R1,
C25R2 and other frozen proof dependencies under reference_build are intentional;
keep their names/bytes. Retained LightHD reading assets are under tmp/pdfs.

## Naming cleanup verification

Current descriptive-name diagnostic15 and independent comparison PASS;38,056
expected bytes/6Verifydigests. All detailed records/clocks/retries exact except
source header;readable text exact. UVM33 fixtures refreshed and full environment
compiled;no new fullUVM/full345/fit. All119 protected RTL/NIST/C-reference files
and all5 fixture bodies unchanged. Normal main/protocol full captures preserve
their own prior source headers;rerun capture before current-source comparison.
Fresh normal diagnostic capture is installed. Never retag the full captures.
