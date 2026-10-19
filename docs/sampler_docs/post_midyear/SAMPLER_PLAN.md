# Sampler design and verification plan

## Accepted baseline — Stage4.9r

The user accepted this design on 2026-10-19. It is the main sampler baseline:
**3537 actual placed ALMs, 164.74 MHz worst Fmax**, setup **+0.430 ns** and
hold **+0.141 ns** at the permanent **6.500 ns / 153.85 MHz** operating target.
3931 registers, 4256 ALUTs, one M10K (1024 logical bits), zero DSPs.
All four corners have zero setup/hold TNS. Area means final-placement ALMs.

Main UVM: 621 complete polynomials, 182 expected errors, 51 reset aborts,
159628 coefficient comparisons. Functional coverage: **1652/1721 = 95.99%**;
raw DUT code coverage: **15093/15799 = 95.53%**. Gaps remain unwaived.
Python: 104 jobs / 19456 coefficients; independent C: 48 cases / 12288 values;
checker self-test: 12 corruptions rejected; performance: 96 checked polynomials;
five injected mismatch kinds receive zero successful coverage credit.

Evidence: [STAGE4_9R_RESULTS.json](STAGE4_9R_RESULTS.json) and
[frozen archive](evidence/stage4_9r.zip), with its SHA256 sidecar.
The immutable checkpoint records acceptance as pending at its creation;
this later user acceptance supersedes that status without rewriting evidence.
Source checks were reused from byte-identical Stage4.9o after 26 file hashes
matched; the retained build has fresh fit, timing and structural checks.

Next: Stage 5 implementation verification. Current-build post-synthesis and
post-fit functional verification is pending. No board, integration or security
signoff is claimed. Native 128-bit processing is not active: accepted 128-bit
beats issue ordered 64-bit chunks internally.

## Completed work

| Stage | Scope | Current disposition |
|---|---|---|
| 0 | LightHD reconstruction decisions and interface contracts | Defined in STAGE0_DECISIONS.md |
| 1 | Four-mode sampler RTL and main UVM | Implemented |
| 2 | Independent Python/C vectors and file comparison | Passing; FIPS-derived, not standalone NIST vectors |
| 3 | Standalone synthesis and performance baseline | Measured; superseded by accepted Stage4.9r |
| 4 | Pipeline, area/timing optimization and broader UVM | Accepted by user on 2026-10-19 |
| 5 | Accepted-build synthesis/fit functional netlist verification | Next; pending |
| 6 | Keccak → sampler → NTT integration | Separate authorization required |

## Functional scope and retained architecture

Support ML-DSA-44/65/87: matrix A rejection, small-secret rejection,
mask expansion and SampleInBall. Preserve complete state for two tagged jobs,
partial-byte/carry ownership, stable ready/valid stalls, exact 256-coefficient
completion, finite-source errors and reset/reuse. Output is a tagged canonical
23-bit coefficient stream. Matrix A is already in the NTT domain.

Input capture → staged preparation → extraction → local compaction →
packed/admit → aligned commit → 32-entry per-context collectors → per-context
read slots → shared formatted output. Challenge storage uses one M10K.
Reservations include outstanding tokens; errors drain ownership before reuse.
The short mask conversion stays before packing. Quartus uses seed 1,
HIGH PERFORMANCE EFFORT and physical register retiming OFF; original payload
and ownership guards remain mandatory. See SPECIFICATION.md for details.

The architecture is reconstructed from the publication, not copied authors' RTL.
User notes remain in ../LIGHTHD_SAMPLER.md and ../SAMPLER.md. Required tagged
interfaces, backpressure, canonical output and partial-word handling are
compatibility choices; do not present them as measured publication improvements.

## Execution rules

- Keep RTL in src/sampler, UVM in tb_uvm/tb_uvm_sampler, launchers/results in
  sim/sampler, and synthesis files in quartus/sampler.
- Use the main UVM and independent references. Only scoreboard-accepted
  observations credit successful functional coverage; show genuine gaps.
- Keep exactly three runnable .do launchers. Vectors/performance select modes
  of run_uvm.do. Do not create auxiliary non-UVM benches for coverage.
- Preserve the 6.500 ns constraint. Report worst-corner setup/hold and actual
  placed ALMs; virtual-pin internal timing does not close physical board I/O.
- Never overwrite frozen evidence. No commit, branch change, module import or
  integration without explicit instruction.
- Future optimization is optional after this acceptance; compare area, Fmax,
  all 96 measured performance records and correctness before selecting changes.

## 10. Stage 5 - acceptance and implementation verification

Begin after the user is satisfied with the selected source implementation:

1. Freeze source/settings hashes, tool/device/seed, modes and approved operating
   clock. Report worst setup/hold/TNS/pulse checks and applicable I/O constraints.
   Internal/virtual-pin timing is not physical board-interface closure.
2. Generate **distinct** post-synthesis and post-fit functional netlists from
   the frozen build; record hashes and generation commands. Do not simulate
   the same netlist twice under different labels.
3. Reuse main UVM with adapters for hierarchy-dependent source observations.
   Retain external value/protocol checks for all feasible modes/parameters,
   interleaving, stalls and reset. Label netlist exclusions and reasons.
4. Use supported Cyclone V vendor-library functional simulation; do not promise
   unsupported SDF timing simulation. TimeQuest supplies timing evidence.
   Check initialized memories and reset behavior in both implementations.
5. Require explicit PASS markers and exact compared job/coefficient totals,
   zero unexpected errors/fatals and fresh artifacts. A zero process exit alone
   is not a pass. Do not merge netlist statistics into RTL code coverage claims.
6. Update specification, testplan, vector report, throughput, coverage and pins.
   Keep board/UART and full-system work explicitly pending unless performed.

## 11. Stage 6 - separate integration

Create/select the integration branch only when explicitly authorized. Combine
accepted Keccak, sampler and NTT snapshots there, keeping module baselines intact.

- Verify real Keccak request-to-sampled-polynomial behavior with independent
  seeded expectations, not only a modeled byte producer.
- Check per-job tags/nonce/parameters, partial valid-byte beats, refill/exhaustion,
  cancellation/reuse, upstream backpressure and downstream memory ownership.
- Route A directly to NTT-domain storage/PWM operands. Route eligible secrets
  through forward NTT or the single-owner Pre-NTT path. Route y/challenge as
  required by the arithmetic schedule.
- Verify against serial/batched reference computations before adding overlap.
- Measure SHAKE waiting, sampling, queue occupancy, NTT load/compute/output and
  completion intervals. Wider ports alone do not prove a system gain.
- Full KeyGen/Sign/Verify benchmarking and official full-operation ACVP checks
  follow implementation of the remaining controller/arithmetic/encoding paths.
  A working Keccak-sampler-NTT subsystem is not a complete ML-DSA accelerator.

## Future work inventory

### 9.2 Improvement inventory from both sources

These candidates combine the user's LIGHTHD_SAMPLER.md and earlier discussion.
They are hypotheses, not proven publication defects. Anything required by
Stage 0 is baseline compatibility and must not be counted again as an improvement.

| ID / origin | Experiment | Evidence and constraints |
|---|---|---|
| I01 - both | Native 128-bit sampling; matrix 5/5/6 candidates over three full beats and up to 32 secret nibble candidates/beat | Compare against the same 128-to-64 baseline adapter; include partial words, rejection, compactor timing, area and fitted clock. Full beats every clock are only a peak assumption. |
| I02 - both | More elastic scheduling/context handling beyond mandatory two-job correctness | Measure switch cost, stalls and realistic arbitration. Extra contexts or batching are optional; keep complete descriptors. |
| I03 - prior discussion + wider-path notes | Balanced/prefix compaction, staged muxes or pipelining | Use measured critical paths; preserve job tags and ordering through pipelines, context hazards and cancellation. |
| I04 - user notes | Mode-specialized decoding with selective sharing of extraction/formatting/storage | Sharing may increase mux cost. Measure all four modes; do not claim unified logic is automatically smaller. |
| I05 - both | Tuned input/coefficient queue depths | Show occupancy, fewer producer/consumer idle cycles and RAM/logic cost. Finite buffers do not solve sustained bandwidth mismatch. |
| I06 - both | NTT-compatible packing, wider writes and reduced staging traffic | Current NTT is serial; actual interface changes belong to later integration decisions. A is already NTT-domain. Measure transfer savings, not only candidate rate. |
| I07 - both / earlier NTT plan | Small-secret Pre-NTT regrouping and packing | LightHD already has this feature. Assign one owner so sampler and NTT do not both execute the first stage. Verify exact ordinary-NTT equivalence and eligibility. |
| I08 - both | Sampling/NTT overlap, ping-pong storage, queued jobs and improved scheduling | LightHD already overlaps sampling and NTT; demonstrate an additional benefit, respect operand dependencies and measure full completion intervals. |
| I09 - prior discussion | Lower-overhead refill/exhaustion management | Baseline correctness already requires safe handling. Reduce stalls without altering the distribution, repeating SHAKE bytes or returning incomplete output. |
| I10 - both | Memory/MLAB/register packing and serializer/formatter efficiency | Inspect depth/width/ports and physical allocation; judge logic, RAM, Fmax and net throughput together. |
| I11 - user notes | Later challenge-shuffle optimization | Preserve repeated-index sequential semantics and memory hazards; missing authors' datapath detail limits exact claims. Defer aggressive parallel shuffle initially. |
| I12 - user notes + prior discussion | Timing/information-flow review | Examine visible stalls/refills and secret-state behavior; fixed loops alone are insufficient. Functional tests do not prove power/EM/timing resistance. |

Do not use the notes' earlier Keccak-only GB/s benchmark as measured sampler
performance. Use actual seed/nonce lengths, XOF output requests, burst patterns
and backpressure. KeyGen/Sign/Verify gains cannot be measured until those full
paths exist. Label intermediate subsystem models explicitly.

## Handoff

Read SAMPLER_PLAN.md, SPECIFICATION.md, COVERAGE.md, THROUGHPUT.md and
STAGE4_9R_RESULTS.json. Stage4.9r is accepted. Finish directory cleanup, then
perform Stage 5 when instructed. Keep the accepted RTL/settings fixed while
validating distinct generated implementations. Do not reuse historical netlist
PASS claims for the current build. Do not start integration automatically.
