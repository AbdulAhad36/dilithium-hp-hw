# Multi-agent FPGA optimization workflow

Project: Dilithium KeyGen/Sign/Verify with shared Keccak, NTT and sampler.
Priorities: increase fitted Fmax; eliminate negative setup WNS/TNS while
preserving hold timing; reduce execution clocks and operation time; reduce
placed ALMs secondarily. Keep the same device and honest timing constraints.

## Investigation only

Four specialized roles independently inspect existing source and evidence:

1. Timing Forensics: source-matched routed paths, constraints, hierarchy,
   logic depth, muxing, fanout and routing; rank measurable bottlenecks.
2. Controller Cycles: KeyGen/Sign/Verify FSM schedules, waits, handshakes,
   dependencies and safe overlap; build evidence-based clock breakdowns.
3. Build and Verification Flow: Questa/UVM/NIST/Quartus runners, caches,
   avoidable rebuilding and database reuse; no competing heavy jobs.
4. Independent Reviewer: independently inspect design risks, then challenge
   the other three proposals for evidence, timing/area regressions, incorrect
   pipelining, handshake/ownership errors and functional coverage gaps.

During investigation do not modify RTL, scripts, constraints, project settings
or design documentation. Do not run full simulations/regressions, synthesis or
fitting. Read existing files first. Shared discussion can use agent messages;
an agents-shared directory is permitted if genuinely needed. This workflow
file is the user's explicitly authorized exception before investigation.

Every role must report exact source/report paths and line references, measured
bottlenecks, concrete proposals, predicted effects on Fmax/WNS/TNS/clocks/ALMs,
risks and the cheapest experiment that can reject each proposal. Clearly mark
unmeasured estimates. Establish which source/constraints produced each report;
do not assign an older fit's numbers to the current RTL.

## Main-agent synthesis and approval gate

Wait for all four reports and the reviewer's cross-review. Compare overlaps and
conflicts. Rank proposals by impact, complexity, functional risk and validation
cost. Recommend ONE combined candidate, normally 3-4 complementary substantial
changes rather than a fit after every small edit.

Specify exact modules/logic/FSM changes, targeted paths, expected critical-cone
improvement, operation-clock deltas, ALM cost, focused tests and structural
rejection criteria. Do not promise an unmeasured MHz/TNS gain. Compare against
the original source-qualified measured baseline throughout, with a second
comparison to the latest retained implementation where relevant.

STOP for user approval before implementing. After approval use one implementation
agent; preserve the qualified fallback and user-authored/uncommitted work.

## Validation after approval

1. Focused fast simulation: affected functions, stalls, reset and outputs.
2. Synthesis and structural checks: intended registers, inference, fanout,
   no new loops/invalid exceptions, preserved physical resources.
3. Reject weak candidates before fitting.
4. ONE full Quartus fit using one seed; no competing expensive runs.
5. Reuse the fitted database for further timing analysis.
6. Full NIST/UVM qualification for a candidate intended for retention.

Report actual final placed ALMs, registers/DSP/RAM, all timing corners' Fmax,
setup WNS/TNS and hold slack/TNS, plus measured operation clocks and calculated
times/rates. Match inputs, modes and stall profiles; separate Sign retries and
valid/invalid Verify timing. Added pipeline clocks are acceptable only with
measured overall benefit. Estimates or cleaner RTL do not establish improvement.

## Organization and reporting

Keep stable descriptive current filenames. Preserve source-bound rejected or
replaced builds in evidence with their original names/hashes/tokens. Summarize
changes, result and keep/reject decision in docs/dilithium_docs/PAST_BUILDS.md.
Other active documents describe only the selected present design. Avoid
per-trial scripts/JSONs/archives/docs; reuse one scratch workspace and runners.
Give concise progress updates. No commit/push/branch switch or netlist/FPGA
acceptance without the user's instruction. The objective is actual FPGA
performance and correctness, not merely simulation speed or stylistic cleanup.
