# Sampler RTL

CURRENT4.6a:four local4x4 secret compactors feed dense candidate registers;
two-level group merge replaces the old16x4 global compactor. A remains3x23.
No extra cycle. Fresh2901 ALMs/102.27 MHz,setup+0.222 ns/hold+0.145 ns at100 MHz.
Main UVM391 complete/100733 checks;Python104 and fault gates pass. All96
performance rows unchanged. User acceptance pending;old3.3k/Stage5 descriptions
below are historical and their netlists do not verify this candidate.

Stage4.5 changes only UVM/coverage/launch documentation. RTL/settings still match
the archived Stage3.3k fit:3543 ALMs,100.33 MHz worst Fmax,+0.033 ns setup and
+0.144 ns hold at100 MHz (internal paths only). All96 performance records match.
Read COVERAGE.md/STAGE4_5_RESULTS.json for349 checked complete polynomials,
72 seeded random jobs and refusal probes. Stage5 generates distinct synthesized/
fitted functional netlists with the same RTL;each passes184 jobs/39936 checks
and independent Python104-job comparison. No new full fit is claimed.

sampler_pkg.sv defines operation/status codes. sampler.sv implements the selected
four-mode sampler with a shared tagged128-bit holding adapter, two contexts,
registered candidate/packed stages, circular collectors and tagged23-bit output.

- sampler_compact.sv: lane/payload-sized stable prefix packing, instantiated
  as16x4 for secrets and3x23 for matrix A. Shared circular collector alignment
  and one admitted chunk-count update remain in sampler.sv.
- sampler_secret_lane.sv: four instances, four nibble candidates each; eta=2/4
  acceptance/mapping to four-bit signed candidates. sampler.sv restores their
  canonical23-bit representation at collector write after compaction.
- sampler_mask_unpack.sv: shared up-to-four-field18/20-bit extractor with one
  alignment shift and fixed carry slices. The sampler's packed stage converts
  raw mask fields to canonical coefficients; no mask compaction is required.
  Saved residual bits remain per job; reconstructed control, not authors' RTL.
  A beat-local working carry/width is loaded at input acceptance, avoiding a
  context mux before mask alignment on each64-bit chunk.
  The holding adapter zeros invalid bytes at acceptance; the unpacker expects
  that padding and uses its byte count only for field/carry accounting.
- sampler_ball.sv: shared sequential challenge engine, 512x2-bit memory, per-job
  signs/index/initialization state and immutable polynomial drain. Serial clear,
  synchronous read and ordered copy/sign writes preserve shuffle dependencies.
  Stage3.2 isolates an unreset RAM/read-register process from controller reset;
  serial clear initializes each context before use.

Matrix/mask/challenge output groups contain four results; secret groups contain
16. Per-job collectors hold 32 entries for worst-case secret append. Challenge
consumes single bytes while other modes consume up-to-64-bit chunks.
The adapter holds non-challenge payload stationary and selects its low/high half;
only challenge uses byte shifting. This keeps capacity control off a wide mux.

All four modes pass main-UVM smoke checks. See SPECIFICATION.md and
STAGE1_RESULTS.md in the module docs. Stage 2 independent Python/C/vector checks also pass; RTL was unchanged during Stage 2.
Stages3.1/3.2 correct counting and RAM mapping. Stage3.3 pipelines compaction,
uses circular collectors and stages mask conversion after extraction.
Packed payloads retain the forwarded collector write address, removing the
context mux before alignment. Source assertions check address/carry ownership.
THROUGHPUT.md records selected and rejected fitted checkpoints and measured
cycle changes. The original10433-ALM/17.15-MHz baseline is archived.
Do not infer100 MHz timing closure from source simulation; use the fresh reports.
