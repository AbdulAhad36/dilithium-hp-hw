# Past builds and experiments

This is the historical record. Build identifiers here identify experiments,
not current production filenames. Passing a source-level test did not imply
timing closure, current-source coverage or FPGA acceptance. Results below are
the scope recorded for each build; they must not be applied to a different
source revision. A reconstruction of published LightHD architecture is not
source equivalence to its unavailable RTL.

## Where the detailed evidence lives

The original integration Markdown and workspace notes before this cleanup are
preserved byte-for-byte in
`sim/dilithium/reference_build/evidence/documentation_history/before_current_names.zip`.
Its `manifest.csv` records paths, byte lengths and SHA-256 hashes. This preserves
uncommitted technical notes as well as the shorter summaries below. Referenced
historical archive names in those notes are original provenance, not a claim
that every old external archive is still present in this checkout.

Original qualified archives remain under `docs/dilithium_docs/evidence/`.
Protected timing freezes, reports, proof logs and captures remain under
`sim/dilithium/reference_build/timing_screen/`. The `active`, `next`, `dev`,
`work`, `probe` and `trial` profiles there are historical source-bound evidence,
not the active production source directories. Frozen source/tool copies keep
their original paths and hashes. Loose superseded reports are under
`reference_build/historical_logs/` or the evidence area. Renamed live artifacts
are recorded in `reference_build/evidence/current_names/rename_manifest.csv`.

## Producer and memory foundations

**Engine import and connected producer (Stages 1-2).** Keccak and sampler were
imported with their reusable verification/synthesis packages. The connected
producer established tagged dual-core SHAKE, ordered 128-to-64-bit transport,
finite output/drain and independent sampling comparisons. Functionality passed
within that subsystem; there was no full KeyGen/Sign/Verify controller yet.

**Early producer timing trials.** Lane-qualified absorb writes, dedicated global
enable routing, retiming/mapping settings and launch-decision registers were
tried. Several correct variants worsened placement/timing: examples included
125.20 MHz and 93.59 MHz; another reached 134.17 MHz but still missed its target.
A registered-credit bridge improved the sampler/hash readiness boundary, but
the subsystem results did not establish whole-accelerator timing closure.

**Four-slot pool and scalar arithmetic (Stages 3-4).** Sampling was connected to
a small four-polynomial store and then NTT/result writeback, proving coefficient
and domain handoffs. A ten-slot KeyGen storage proposal was documented but not
selected. These layouts were superseded by the fixed four-bank shared memory;
their ownership/coverage model is not the current physical-port model.

## Process and complete operation construction

**Process, seed/hash and bank foundation (Stage5A-E).** Modular arithmetic,
P2R, hash-message formatting, finite raw SHAKE and seed collection were brought
up independently, then connected to four 1024 x 92-bit banks. Sampling writes,
readback, bounds, collision handling and reset/drain were tested. This proved
building blocks, not a complete signing accelerator.

**Banked NTT, row scheduling and KeyGen polynomial phase (Stage5F-J).** Shared
bank/NTT/Process chains, row accumulation and seed-driven sampling were joined
under an autonomous KeyGen scheduler. Transformed secrets were retained and
reused. Polynomial outputs and negative-capture checks passed, while final
rounding, serialization and public-key hashing were still required.

**Complete KeyGen and official comparisons (Stage5K-M).** P2R and BitPkg were
connected, public-key hashing and secret-key serialization completed, and
official input/expected files were used to compare complete encoded keys.
This replaced earlier polynomial-only acceptance; successful arithmetic alone
was no longer treated as a complete KeyGen result.

**Signing input, preparation and masks (Stage5N.1-4f).** Shared services were
connected to decoded SK ingestion, mu/mask-seed hashing, retained secrets,
mask expansion, matrix products and decomposition. Focused independent checks
covered intermediate banks, frames and resets. The work still stopped before
an accepted, encoded signature and did not justify full Sign acceptance.

**Challenge, responses, hints and retries (Stage5N.4g-4h).** Packed w1 hashing,
SampleInBall, challenge transforms/products, z/low-term correction, norm tests,
hint construction and retry ownership were added, followed by complete signature
encoding. Official Sign and corruption tests qualified byte-level results;
the service/handle-heavy controller structure was later replaced for area and
timing rather than retained as the production hierarchy.

**Verify construction (Stage5V.1-4).** PK/signature decoding, canonical sparse
hints, z bounds, tr/mu/challenge processing, shared NTT equation work, UseHint,
w1 hashing and verdict comparison were added in steps. Early decoder/equation
checks were not full verification; the final main-owned operation established
the full host-to-verdict path. Its general service hierarchy was superseded.

**Full-operation baseline and main UVM (Stages 6 / 7A).** External-message
KeyGen, Sign and Verify were combined, with official final outputs and a
33-scenario UVM foundation. Coverage measured checked outcomes rather than
merely generated transactions. This established correctness for that interface,
not all FIPS API modes, physical closure or FPGA behavior.

## General-controller reduction and compact reconstruction

**Stage7B helper/metadata experiments.** Wide parallel region/context checks
were serialized or restructured and descriptor/decoder representations were
examined. Output checks passed for qualified variants, but excessive control
and routing remained. The production wrapper removed exported internal debug
ports. This did not itself make the underlying controller a compact fixed
schedule; that hierarchy was replaced rather than kept as the final solution.

**Stage7C.1 shared fixed-bank datapath.** The replacement used one physical
four-bank fabric, shared NTT/sampling/Process engines and fixed role lifetimes.
Focused engine/DMA/ownership checks established the foundation. It was not yet
a complete replacement KeyGen/Sign/Verify main.

**Stage7C.2 KeyGen and paired scheduling.** Complete compact KeyGen matched all
75 official keypairs (433,600 bytes). Protocol/reset and checker-corruption tests
were added, then A/s2 production began before the final secret transforms
finished, with paired A jobs and a bounded nine-slot ring. This improved actual
sampling/arithmetic overlap; Sign/Verify and whole-main timing were still open.

**Stage7C.3 Sign.** The fixed-bank Sign controller reused transformed secrets
and one attempt loop. All 90 then-supported signatures (310,680 bytes), 69
protocol commands and 62 deliberate comparator corruptions passed. Rejection
reasons, hashes and nonce progression were checked. It qualified the Sign
component, not yet the replacement full main or its fitted performance.

**Stage7C.4 Verify and mixed main.** Verify and all three operations were joined
on the replacement datapath. The mixed 210-command and 88-command protocol
campaigns exposed a real bug: idle KeyGen raw-ready could inspect another
operation's hash response. Restricting readiness to KeyGen's own hash phases
fixed the ownership error. Exact outputs and resets/recoveries passed; the next
step was qualifying the actual production wrapper and physical-port UVM probes.

**Stage7C.5 production binding.** `dilithium_fpga` was bound to the compact main,
with child-ID completion protection and a comparison spelling that avoided a
Quartus elaboration problem. Full/protocol payloads and clocks matched the
qualified core. UVM was updated for physical port ownership. The result was
functional production binding, not timing acceptance.

**Stage7C.6 response buffering.** Registered occupancy plus RAM-response/skid
storage removed a response-ready feedback loop while preserving operation
clocks in the checked corpus. Direct RAM, NTT contention, full/protocol and
UVM checks passed. The fitted result was only 39.37 MHz with -18.645 ns setup;
removing a loop did not remove the other dominant control paths.

**Stage7C.7 decoded input queue.** A two-packet 92-bit decoded boundary and
separate admission/commit tracking shortened loader/decoder control. Full
outputs and focused malformed/reset cases passed. The fit reached 51.78 MHz,
34,302 placed ALMs, but still had -12.556 ns setup. The memory command path
remained a major bottleneck.

**Stage7C.8 command geometry.** Burst bounds were rewritten into simpler
equivalent comparisons and checked across 16,842,752 combinations. Full outputs
and operation clocks remained unchanged. The fit reached 55.53 MHz and 34,333
placed ALMs, with -11.251 ns setup. Later expanded contention tests exposed
a split-port renewal race absent from its original campaign.

**Stage7C.9 initial attempt and R1.** The first admission-only attempt failed
mixed Verify and was stopped. R1 added deferred physical retirement and NTT
read-completion memory so split A/B renewals retained ownership. All 48 forced
splits in the expanded NTT test passed, along with full/protocol/UVM checks.
At 53.85 MHz and -11.812 ns setup it fixed correctness without performance
acceptance; the slower result remained historical evidence.

**Stage7C.10 completion decisions.** Registered NTT release/final-completion
decisions preserved correct split-port renewal. Full and focused checks passed;
operation clock changes were measured rather than relabeled as exact. The
fit reached 56.65 MHz, 34,660 placed ALMs and -10.894 ns setup, leaving timing
far below target.

**Stage7C.11R1-C12 Process and resource reduction.** Arithmetic/formatter and
direct memory/Process work reduced placed area to about 33,000 ALMs, with
qualified results around 57 MHz. Reported C11R1/C12 rates were 57.57/57.38 MHz;
all checked clocks were unchanged. A controller-context-RAM proposal was
rejected by the user, so it was not a selected architecture.

**Stage7C.14 shared hints.** One physically shared hint codec replaced duplicated
formatting resources. Official/protocol/UVM tests passed; placed area was
31,882 ALMs. Its 56.72 MHz result regressed frequency despite saving area,
showing that sharing alone did not solve routing/control delay.

**Stage7C.16 registered Process operands.** A registered operand/tag boundary
and range-logic changes passed exhaustive norm/hint comparisons, actual-RAM DMA,
stall/reset, full/protocol/UVM checks. Recorded results were 31,893 placed ALMs
and about 63 MHz. It was a correctness-qualified timing step, not target closure.

**Stage7C.13 control routing trial.** Control-switch routing was rewritten and
checked with 400,000 pin/state comparisons as well as full/protocol/UVM tests.
Operation clocks matched C12, but the fit grew to 33,647 placed ALMs and fell
to 57.04 MHz with -10.775 ns setup. The performance trial was rejected; source
correctness did not justify keeping the slower/larger physical implementation.

**Stage7C.15 direct memory data.** Memory-to-Process data selection/routing was
made more direct and checked across 2,097,152 Process port comparisons and
the full campaigns. Placed area fell to 31,768 ALMs, but worst frequency was
56.67 MHz with -10.889 ns setup and unchanged operation clocks. It remained
a qualified historical step rather than timing acceptance; the R1 archive
preserves the same reported design/result with corrected evidence packaging.

**Stage7C.17 shared ALU and stream formatting.** Process arithmetic sharing and
stream formatting were reworked. Full/protocol/UVM checks passed with exact
payload/status/attempt records, while clock deltas were newly measured.
The fit was 31,771 placed ALMs at 60.19 MHz and -9.856 ns setup, slower than
the preceding registered-Process result and still far below the target.

**Stage7C.18R1 payload lifetimes.** Process payload storage, Verify mu overlay
and unpacker admission isolation reduced retained register lifetimes. Extensive
Process/ring/shadow checks and complete output campaigns qualified the source.
The fit used 31,329 placed ALMs at 62.18 MHz and -9.325 ns setup. This became
a retained proof dependency; its source is not replaceable with current RTL
when replaying those exhaustive arithmetic checks.

**Stage7C.20 registered writer.** The normal sampler-writer handoff was registered
and checked with real-RAM polynomials, consecutive writes, stress batches,
occupied resets and the connected chain. Complete outputs remained qualified.
Placed area was 30,655 ALMs, worst frequency 63.59 MHz and setup -8.968 ns.
The handoff improved local structure without meeting full-system timing.

**Stage7C.21 controller lifetimes.** Register-held controller values were reduced
according to actual lifetimes. Full/protocol/UVM checks and unchanged clocks
passed. At 29,841 placed ALMs and 63.37 MHz it saved 814 ALMs but lost about
0.35% frequency/rate against C20. It was retained as a smaller alternative,
not evidence that area reduction improved throughput.

**Stage7C.22 readiness isolation.** Ready/control isolation improved worst
frequency to 68.23 MHz with -7.899 ns setup, using 30,577 placed ALMs. Complete
outputs/protocol/UVM checks passed with unchanged clocks. This was faster than
C21 at some area cost and became the selected fallback for the following
packing/conversion trials. An ASM issue and its manual recovery were recorded
separately rather than silently treating the original flow as clean.

**Stage7C.23 packed-field conversion.** Shared power-of-two field conversion
passed functional qualification but routed at 62.42 MHz with 30,115 placed
ALMs. The 462-ALM saving cost 8.52% frequency/rate versus C22. It was rejected
and exact C22 source/fixtures were restored; C23 captures were not retagged.

**Stage7C.24 centered packing.** Centered encoding and registered raw/high
selection passed output and protocol checks. The fit saved 454 ALMs relative
to C22 but reached only 67.59 MHz, a 0.938% rate regression with unchanged
operation clocks. It was archived as an area option and the faster C22 was
restored for timing-first work.

**Stage7C.25R2 registered transport.** Timing-first transport changes were
qualified at the tighter 6.500 ns target. The fit reached 71.60 MHz and 31,720
placed ALMs, but worst setup was still -7.466 ns. Generated-bank retention
report scoping was corrected without changing physical results; the first
failed guard remained in evidence. The working timing candidate was not
user-accepted target closure.

**Stage7C.26 readiness/control refinement.** Further control/admission work
preserved the proof foundations and progressed the routed result to 72.36 MHz,
31,923 placed ALMs and -7.320 ns worst setup. Fast corners were higher but
were not used to claim closure. Its original metrics, source freeze and logs
remain under reference_build; they do not measure the later source revisions.

## Timing-focused pipeline work

**Saved 83.28/87.17 MHz family and early screens.** The focus changed from
area to Fmax, worst setup and operation rates. Register/control rewrites and
physical screens produced qualified fallbacks; some merely moved the critical
path and were not retained. The saved baseline and per-trial patches are in
the existing timing journal, not reconstructed from current source filenames.

**85.69 MHz sampler preparation.** Shorter matrix-A preparation improved one
measured cone and passed the candidate's functional checks, but remaining
readiness/control paths limited the overall frequency. It became a protected
fallback rather than evidence of target closure.

**86.21 MHz admission-only quarantine.** Sampler work was combined with
admission-scoped control/fault checks, preserving immediate fatal quarantine
and measured output behavior. It improved the qualified fallback but did not
resolve formatter/command/ownership routing bottlenecks.

**87.99 MHz formatting/message pipeline.** A two-entry encoded formatting
boundary and shared KeyGen input stage were enabled only for integration, with
safe standalone defaults retained. Focused format/DMA tests and full/protocol/
UVM checks passed. Placed ALMs were 32,104. Added clocks were measured, and
the user allowed them where operation time/rates improved.

**89.02 MHz local-base capture.** Local command bases were captured at coherent
admission boundaries without adding an operation clock. Exhaustive descriptor
and actual memory tests, full/protocol/UVM checks passed with unchanged clocks.
The fit used 32,186 placed ALMs, with -4.734 ns worst setup and +0.096 ns worst
hold. The hint codec then became a prominent fitted bottleneck.

**Rejected hint-only fits (88.94 and 88.16 MHz).** Shared suffix append/read
changes and a registered append stage passed focused/full/protocol/UVM tests
and sometimes saved substantial area. Both full fits regressed worst frequency
against the protected 89.02 MHz revision. They were rejected and source was
restored byte-for-byte rather than promoting an area-only improvement.

**89.81 MHz input/cache pipeline.** The retained timing revision combined a
finite two-entry SHAKE input FIFO, parallel Process bounds, registered hint
append and an 8 x 64 x 4-bit predecoded hint cache with row credits. Full 210
external-message operations, protocol88 and UVM33 passed. The four-corner fit
used 33,542 placed ALMs, 59 M10Ks and 8 DSPs; worst Fmax was 89.81 MHz, setup
-4.635 ns and hold +0.122 ns at the 6.500 ns target. It was a small gain, not
closure. This fit predates the internal-message API and does not qualify its
physical timing.

**Rejected combined boundary batch (89.00 MHz).** Four boundaries were tried
together: registered sampling completion, NTT command/credit, Process
admission/ownership and global-idle/start readiness. Focused and full checks
passed after the protocol bench was corrected for registered-ready timing.
The fit used 33,676 placed ALMs but regressed worst Fmax to 89.00 MHz and all
nine mean operation rates by about 1.1-1.3%. It was rejected; qualified source
and benches were restored, with replayed versus fresh evidence labeled.

**Read-only routed-family diagnosis.** Sixty-four paths across 16 endpoint
families and two slow corners were audited for retained and rejected layouts.
High interconnect/fanout dominated several completion, owner/start, sampler/
memory, hash/formatter and unpacker paths. The next four-family redesign scope
was identified, but that audit implemented no candidate and proved no new Fmax.

## Test infrastructure and API work

**UVM organization and capture cleanup.** Main UVM was split into proper
components with independent monitoring/scoreboard and checked-result coverage.
Normal and bounded random-stall campaigns each passed 33 scenarios; a corrupted
first key byte earned no checked/coverage credit. Focused references were moved
to reusable folders. Saved percentages applied to their source snapshots,
not automatically to later API or naming changes.

**Internal-message support.** A latched command bit selected original-message
formatting or already formatted Mprime, retaining internal mu calculation and
requiring zero separate context in internal mode. The resulting 345 supported
operations passed with 1,054,960 exact expected key/signature bytes, 70 Verify
equation digests and 18 valid/72 invalid verdicts. Actual readable C/HW files
matched byte-for-byte. This added functional scope without a new physical fit
or full UVM-mode coverage claim.

**Fast capture mode and safe caches.** Broad debug access/waves were disabled
optionally, unchanged preparation/compilation was cached, and a separate data
directory enabled isolated checks. Fifteen matched diagnostic cases took
18.092-23.893 seconds versus 80.844 seconds with debug access. Detailed/plain
outputs, retries and clocks were exact. This saved host simulation time; it
did not improve hardware Fmax or operation clocks.

**Current-name documentation cleanup.** Historical narratives were centralized
here, the original notes were preserved in one verified archive, and live
capture/UVM filenames and public commands were made descriptive. References in
launchers, benches and vector preparation were updated together. No production
RTL, algorithm, NIST data or physical constraint was changed by that cleanup.

The renamed 15-case mixed diagnostic and its independent comparison passed
with 38,056 expected bytes and six Verify equation digests. Detailed records,
retries and clocks matched the preceding run except for its source header;
readable output bytes were exact. UVM fixture freshness and compilation passed;
no new full UVM run, full 345-case run or fit was claimed. All 119 protected
RTL/NIST/C-reference files and all five prepared fixture bodies were unchanged.

## Rejected boundary pipeline candidate (16 November 2026)

Combined local checked sampling completions, local idle initialization of wide
controller storage, per-core Keccak output queues, buffered secret regrouping,
queued Hint commands, and formatter/unpacker pipelines. Focused formatter and
unpacker tests passed, including invalid encodings, stalls and resets; shared
sampling checked 88 polynomials and three raw hashes. The final-source mixed
diagnostic passed 15 operations, 38,056 output bytes and six Verify digests.
Protocol88 passed 148,704 bytes, 29 error cases and 12 resets before the final
Verify idle-initialization refinement. An initial Hint cancellation/ready
deadlock was caught and corrected before fitting. Mapped hardware guards passed.
One seed-1 full fit at the unchanged 6.500 ns target produced 33,600 actual placed
ALMs, 26,850 registers, 59 M10Ks and eight DSPs. Worst routed Fmax was 89.41 MHz,
setup WNS -4.684 ns and setup endpoint TNS -45,737.596 ns; minimum hold slack
across four corners was +0.094 ns, with zero hold TNS. This regressed against the
historical source-qualified 89.81 MHz/-4.635 ns reference, while diagnostic
operation clocks changed by -0.48% to +4.27%. The candidate was rejected; the
pre-experiment RTL and affected benches were restored. No full345/UVM retention
campaign was run. This does not establish new PPA for the restored internal-message
API. The source and recovery record remains in
`reference_build/timing_screen/synthesis.log`. The rejected fit's reports were
preserved under `reference_build/evidence/boundary_pipeline_20261116/`. The
new worst routed path was sampler
writer `started_r[3]` to memory-port `write_r[0]` (10.956 ns); the 150+ MHz and
nonnegative setup-slack targets remain open.

## Rejected Process input timing candidate (18 November 2026)

Added a register after Process operand selection and compact expansion, reduced
coefficient error flags in parallel, staged KeyGen hash writes, and moved
memory command withdrawal to the grant output. Process, command withdrawal,
160 NTT operations, the 15-case diagnostic and all 88 protocol cases passed.
Diagnostic KeyGen clocks were unchanged, while Sign and Verify increased by up
to 0.18% and 0.13%. At 6.500 ns the single seed-1 fit reached 88.10 MHz,
with -4.851 ns worst setup slack, -49,529.237 ns worst setup TNS,
+0.072 ns minimum hold slack and 33,707 placed ALMs. The worst path ran from
the Verify FSM through load frame selection and validation to the unpacker's
bit count. Fmax and setup regressed against the qualified 93.68 MHz build.
The qualified RTL and benches were restored byte for byte. The fit, timing
reports and focused captures remain under the `process_timing` revision in
`reference_build/timing_screen/`. The source diff is in `synthesis.log`.

## Verify frame timing candidate (18 November 2026)

Added a two-word frame queue in the shared loader, registered Verify input
ownership, cached the unpacker's expected final-word flag, and restored the
registered Process operand boundary. The loader passed 71 cases, and the
unpacker matched the qualified implementation for 275,740 cycles with exact
ready, output and status. The focused Process suite, 15 full-design
diagnostics and 88 protocol scenarios also passed.

The seed-1 fit reached 93.76 MHz, -4.165 ns worst setup slack, -44,315.729 ns
worst setup TNS, +0.078 ns minimum hold slack and 33,015 placed ALMs. The
Verify-to-unpacker path left the worst-path list. The Sign controller's
state-to-entropy storage path became the worst path at 10.423 ns data delay.
Diagnostic Verify saved 14–38 clocks, while Sign added 42–88. The
0.08 MHz improvement over the qualified build did not offset Sign's cycle
increase. The experiment was archived and the qualified source was restored.
Evidence is in the `verify_frame` reports and captures under
`reference_build/timing_screen/`, with the source diff in `synthesis.log`.

## Sign storage timing candidate (18 November 2026)

Separated Sign's entropy clear from the public completion handshake and
registered its checked hash writes. Also split Process operand selection
from arithmetic and registered Verify input ownership and the unpacker's
last-word check. The unpacker matched the qualified RTL for 275,740 cycles,
and all 64 Process cases, 15 full-design diagnostics and 88 protocol cases
passed. The new assertion confirmed that entropy clears during stalled
completion. Diagnostic KeyGen clocks were unchanged, Sign added 31–55,
and Verify added 7–12.

The single seed-1 fit reached 89.94 MHz at the 6.500 ns constraint with
-4.619 ns worst setup slack, -46,224.039 ns worst setup TNS, +0.083 ns
minimum hold slack and 33,989 placed ALMs. The new worst path ran from
the top-level Sign owner through hint consumer readiness to the Process
pipeline's advance control. It measured 10.886 ns of data delay. The
trial regressed against the qualified build, so the qualified RTL and
benches were restored byte for byte. Reports and captures remain under
the `sign_storage` revision in `reference_build/timing_screen/`. The source
diff is in `synthesis.log`.

## Process result buffer timing candidate (18 November 2026)

Added a two-entry result buffer to isolate the Process arithmetic pipeline
from memory, packing and hint readiness. Combined it with the earlier
operand, load-frame, Verify ownership and Sign storage changes. The focused
Process suite passed 64 cases, including resets with both queues full. The
loader and unpacker checks, 15 full-design diagnostics and 88 protocol
cases passed. The fitted timing netlist had zero direct paths from the
top-level owner registers to the Process arithmetic registers.

The seed-1 fit reached 90.57 MHz at 6.500 ns with -4.541 ns worst setup
slack, -46,706.217 ns worst setup TNS, +0.076 ns minimum hold slack and
33,926 placed ALMs. The worst path ran from KeyGen command validity to
the bank router's deferred-retirement register, with 10.814 ns of data
delay. Diagnostic KeyGen added 13–71 clocks and Sign added 76–142.
Verify saved 2–29 clocks. The design was restored to the qualified RTL
and benches because whole-design timing regressed. Reports, captures and
the source diff are preserved under the `process_results` revision and
`synthesis.log` in `reference_build/timing_screen/`.

## Registered bank retirement candidate (18 November 2026)

Separated client acknowledgement from physical bank retirement. The router
captures lane masks with command descriptors, arbitrates on staged offers,
and blocks withdrawn offers at dispatch. The retirement register records
acknowledgement independently of grant selection. The NTT test verified
48 split-port renewals and a withdrawn winning offer. All 40,960 NTT
coefficients, 15 full-design diagnostics, and 88 protocol scenarios matched
the references.

The seed-1 fit reached 92.79 MHz with -4.277 ns worst setup slack at 6.500 ns,
-38,387.453 ns worst setup TNS, +0.080 ns minimum hold slack, and 33,816 placed
ALMs. The worst path moved to Process packing mode through BitPkg format
validation. The fit served as the basis for the packing variant. Its source
diff, captures and reports remain under `bank_retirement` in
`reference_build/timing_screen/`.

## Qualified memory admission build (17 November 2026)

The registered memory admission build passed all 345 supported NIST cases,
88 protocol cases and 33 UVM scenarios. Its seed-1 fit reached 93.68 MHz
with -4.175 ns worst setup slack, -45,271.145 ns worst setup TNS,
+0.103 ns minimum hold slack and 33,819 placed ALMs. The Process packing
and bank retirement redesign replaced it after full qualification.
The fallback source and captures remain in
`reference_build/evidence/qualified_memory_admission_20261117/`.
Routed reports remain under the `batch` revision.

## Registered hint and load handoffs (19 November 2026)

Registered hint decode admission and frame decisions, buffered Process-to-hint
beats, and reused the sampler completion slot for loads. The 15 diagnostics and
88 protocol cases passed, as did the hint proof against the independent codec.
KeyGen diagnostic clocks were unchanged. Sign added 11–21 clocks and Verify
added 7–10. The mapped and fitted netlists had zero direct paths for all three
targeted endpoint pairs.

The seed-1 fit reached 94.56 MHz with -4.075 ns worst setup slack at 6.500 ns,
-41,592.490 ns worst setup TNS, +0.089 ns minimum hold slack, and 33,828 placed
ALMs. The new worst path was the Sign formatter's payload counter to its bit
reservoir, with 10.234 ns data delay. Two other paths were within 0.013 ns of
its slack. The whole-design timing regression ruled out promotion, so the
qualified 97.10 MHz source was restored. Reports, captures, and the source
diff are under the `hint_handoffs` revision and `synthesis.log` in
`reference_build/timing_screen/`.

## Formatter, KeyGen and sampler timing boundaries (19 November 2026)

Combined the hint/load handoffs with registered payload framing in the
Sign/Verify formatter, staged KeyGen material writes and a two-entry sampler
packet buffer. The formatter matched the external reference pin for pin and
passed its internal-message byte oracle. All 15 diagnostic and 88 protocol
cases matched. Diagnostic KeyGen clocks were unchanged. Sign added 22–54
clocks and Verify added 16–26. All six targeted paths disappeared in both
the mapped and fitted netlists.

The seed-1 fit reached 94.12 MHz with -4.125 ns worst setup slack,
-37,401.088 ns worst setup TNS, +0.124 ns minimum hold slack and 33,775
placed ALMs at the 6.500 ns constraint. The longest path moved from the
Sign FSM through hint admission to the Verify input challenge registers,
with 10.344 ns data delay. The 97.10 MHz build remains qualified and was
restored after the fit. Candidate reports, captures and source diff remain
under the `engine_boundaries` revision and `synthesis.log` in
`reference_build/timing_screen/`.

## Policy for the next replacement

When an improved design is accepted, move its predecessor's meaningful source,
constraints, source-bound reports and captures into evidence under its build
identity. Summarize the change, failed/passed gates and keep/reject decision
here. The selected design always uses the normal source/simulation/synthesis
paths; current documents describe only that selected implementation. Never
rename a frozen report or rewrite its token to imply a new build was verified.
