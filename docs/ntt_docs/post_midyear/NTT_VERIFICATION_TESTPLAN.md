# NTT verification test plan — FIFO candidate

**Current source verification (2026-10-12):** 748/748 UVM jobs,
191,488 compared coefficients, zero UVM errors/fatals, 32 checked covergroup
types at **90.47% overall functional type average**. Ten new groups and 128
new tests extend the prior 620-job checkpoint. The raw bin aggregation is
73.33%; the large transition/shape/flow cross remains only 5.47%, so this is
an incomplete-coverage review checkpoint. Original 22 groups retain their
>=90% gate; overall must reach >=90%, with no upper-bound failure or suppression
of valid hits. Code counts, RTL, golden model and fit metrics are unchanged.
See [COVERAGE.md](COVERAGE.md) for exact definitions, all misses and evidence.
Older dated counts below are historical checkpoints. Stage 6 has not begun.


**Stage:** 5 functional netlist verification complete; source code holes remain documented. **DUT:** the self-contained `src/ntt_LightHD/` RTL (`ntt_core.sv`, package, multiplier, butterfly, twiddle ROM, and serial wrapper). All candidate UVM and directed testbench `.sv` files are in `tb_uvm/tb_uvm_ntt_LightHD/`; Questa scripts and generated outputs are in `sim/ntt_LightHD/`; the Quartus project is in `quartus/ntt_LightHD/`. This is a reconstruction of LightHD's published four-butterfly, three-FIFO structure; it is not the authors' RTL. The saved four-bank design remains the comparison and rollback reference.

## Meaning of a pass and a coverage hit

A source UVM test passes only when 256 accepted output coefficients match an independent expected polynomial, `m_tlast` occurs exactly on accepted beat 255, a valid observed internal trace is present, and no timeout or UVM error occurs. The scoreboard's `checked_ap` publishes a transaction to `ntt_coverage` **after** those conditions pass. Thus the existing 100% `op × input-kind` coverage means its 12 standard-mode bins were hit by passing transactions. It does **not** mean every FIFO state, twiddle, Pre-NTT case, code branch, timing corner, or physical implementation was covered. The Python vector comparison checks output files separately; its input and expected polynomials come from the independent FIPS 204 NTT reference implementation, not NIST-supplied NTT vectors.

The primary run is `sim/ntt_LightHD/run_uvm.do`, with the full UVM environment.
Current source result: **620/620**, original 118 plus 502 expanded jobs; 22 checked
groups at 99.51% type average and minimum 92.36%. Its 620 trace/routing/profile
witnesses are in `uvm_expanded.log`. Golden output, internal routing and observed
flow profiles must pass before coverage credit. A group must reach at least 90%,
with remaining bins reviewed. `coverage_gate_expanded.log` rejects seven bad
observations without new credit, in a separate UCDB. See COVERAGE.md and the
expansion section below for exact requirements, sample logic and remaining bins.

Current supporting check is separate Python compare 18/18 (4,608 coefficients).
Earlier non-UVM core/engine/arithmetic counts are historical; those redundant
benches and launchers were removed. Main UVM supplies source coverage. The saved
four-bank UVM environment remains separate. This is a Stage 4 increment,
not coverage or timing closure.

## Requirement and checker matrix

| ID | Requirement / expected behavior | Stimulus and observed check | Present evidence / Stage 4 action |
|---|---|---|---|
| M1 | Modular multiplication returns `(a*b) mod q`, including 0, 1, `q-1`, and values near reduction boundaries. | Directed and randomized operands; compare each result with wide-integer `% q` software reference, including pipeline latency. | Historical removed arithmetic bench checked 1,312 pairs at the earlier four-clock latency. Current five-clock multiplier is verified in main UVM through independent operands, every physical writeback and complete output comparisons, including the all-lane PWM boundary job; observed return alignment is ten clocks. |
| M2 | Forward CT and inverse GS butterfly signs, twiddle use, and inverse `/2 mod q` are correct. | Unit-level known pairs at each edge and random values; check both outputs and exact valid/tag delay. | Historical removed unit bench checked 1,312 butterfly pairs at the earlier six-clock latency. Current BF latency is seven clocks; main UVM checks ten-clock issue-return alignment, independently derived twiddles, every physical write and final output. Registered inverse words pass modular-half checks; zero/even-nonzero/odd bins 3/3. |
| T1 | ROM and decoder select the FIPS 204 twiddle for every `(operation, stage, issue, lane)` used. | Exhaustive 8 stages × 32 issues × 4 lanes address/value check against an independent generated table. | Stage 4 trace checks all legal addresses with an independent stage/group formula and registered ROM values with reference modular exponentiation; 118/118 UVM jobs pass. |
| F1 | Three FIFO stores preserve the intended coefficient order without overflow, underflow, stale reads, or cross-transaction leakage. | Index-tag proof for all 128 pairs per stage; runtime assertions on push/pop counts and valid tags; alternating unrelated polynomials. | All routes and reachable occupancy classes observed. Pre FIFO2-full corrected by final settled sample. Standard FIFO3-full excluded by exhaustive fixed PIPE=10 schedule (max 11/16), enforced by RTL trace. Unlike jobs pass without reset. |
| F2 | Four butterfly lanes perform all 128 pairs each stage and route results to the proper FIFO words. | Instrument accepted issue/writeback tags; assert each stage sees 128 unique pair IDs and 256 output destinations exactly once. | UVM trace checks each issue ID once, all four lane twiddles, and valid/PWM/destination alignment through an independent ten-clock delay. The new independent UVM FIFO ID/value model verifies all 128 mathematical pairs and 256 destinations per active stage, registered operands, writeback words, physical writes and ordered outputs; 118/118 jobs pass. |
| O1 | General NTT matches FIPS 204 for any canonical polynomial, including zero, max, deltas, ramp, and random. | Independent Python output comparison and SV golden model; all 256 coefficients and output framing checked. | 18/18 Python cases overall and directed/UVM passes; expand random seeds and boundary values. |
| O2 | INTT returns the specified inverse transform; `INTT(NTT(a)) = a`. | Random and edge polynomials; compare standalone inverse and round-trip outputs. | Existing vector, core, engine, UVM tests pass; UVM inverse twiddle and scaling bins now close; expand randomized equivalence. |
| O3 | PWM produces 256 coefficient-wise modular products from two separately loaded polynomials. | Zero, max, delta, random, and independent A/B patterns; check operand ordering and 512 accepted input beats. | Existing vector/UVM checks and directed B-load boundary gaps, both-operand gaps, and output-stall checks pass. |
| P1 | `OP_PRE_NTT` equals general NTT for secrets whose signed coefficients are in `[-4,4]`. | Exhaustive single-coefficient values `-4..4` at boundary indices, mixed eta-2/eta-4 random secrets, all 256 outputs checked; compare Pre and standard modes. | Directed eta-4, one independent bounded vector, 13 checked UVM Pre cases and an additional UVM Pre gap/stall job pass; nine signed values at first/middle/last positions close 27/27 bins. Sixteen bounded-random eta-2/eta-4 pairs now compare actual Pre/general outputs as well as both golden results; 2/2 equivalence bins close. Expand seeds/combinations. |
| P2 | Pre-NTT first-stage lookup/regrouping never applies silently to an ineligible coefficient. | Inject residues outside `[-4,4]`; simulation must reject the job or a documented hardware validity protocol must block it. | Three separate UVM illegal cases (+5 at 0, -5 at 128, +5 at 255) trigger the exact simulation eligibility `$fatal`; there is no synthesizable rejection/fallback. Define and verify an integration-side eligibility guarantee before deployment. |
| H1 | Input transfer advances only on `s_tvalid && s_tready`; gaps and output backpressure do not change data/order. | Gap patterns at first/middle/last input beat; output `m_tready` stalls at first/middle/last beat; stable `m_tdata/m_tlast` while stalled. | Main UVM passes gaps/stalls in all four modes, including gaps in both PWM operands and at A/B boundary. Input regions 16/16, output positions 16/16, PWM boundary 1/1; stalled data/last stability is checked. Longer/random stall combinations remain. |
| H2 | Reset, repeated jobs, and operation changes do not leak FIFO/tag state. | Reset idle, during load, during run, during output; no reset between unlike completed jobs; check first next output and timeout behavior. | Nine observed UVM abort/recovery scenarios pass, with 9/9 checked reset-point bins. Main UVM FSM transitions close core 9/9 and wrapper 15/15; 8/8 reset-before-job bins also remain complete. Expand mode/pulse-width combinations. |
| L1 | Core and wrapper latencies are measured from documented handshake boundaries. | Count start-to-done and launch-to-last accepted output, with no stalls; separately count transfer and compute cycles. | 266/266/74/235 core and 780/780/844/749 full cycles measured. Add assertions or tolerances for each no-stall mode; label stalled latency separately. |
| I1 | Future SHAKE/sampler adapter only sends eligible secrets to Pre-NTT and preserves job/core tags. | Contract-level descriptor tests; variable sampler acceptance, buffering, rejection, and backpressure. | No sampler or Keccak integration exists here; Stage 6 owns end-to-end dataflow. |

**Stage 4 UVM checkpoint for T1/F1/F2:** The main UVM monitor observes
every legal stage/issue/lane twiddle address and registered ROM value,
credits 2,944/2,944 schedule positions and 764/764 mode/address bins only
after scoreboard pass, and checks ten-clock issue-to-return destination
alignment. All legal source/destination routes and 32 reachable occupancy
classes close. Fixed-schedule exclusions are justified in `COVERAGE.md`.
The UVM coefficient-routing model now requires exact pair/destination sets per active stage and actual operand/writeback/memory data equality. Two isolated observation-corruption tests prove errors block checked coverage.

## Functional coverage model and remaining extensions

Coverage must be sampled from **observed, checked results**. For internal FIFO/stage events, collect a per-job event bitmap during execution and commit its bins only after that job passes the scoreboard. Record failures separately; do not let a failed job close a functional bin.

| Coverpoint / cross | Intended bins | Why it matters |
|---|---|---|
| Operation × input class | NTT, INTT, PWM × zero, max, delta, random; Pre-NTT × boundary, eta-2, eta-4. Add more bounded shapes where legal. | Shows each legal mode has a correct result for representative polynomial shapes. These 12 + 3 case-class bins are closed in UVM alongside the internal groups below. |
| Stage × lane × direction | Eight stages × four lanes × NTT/INTT, plus Pre-NTT stages 1–7 and lookup stage 0. | Shows every scheduling position participated in a passing transform. |
| Twiddle class × stage | Unity, nonunity, positive/negative inverse mapping, lowest/highest ROM address. | Exposes decoder omissions despite good random end results. |
| FIFO route × occupancy | Each source/destination route and empty, mid, full capacity states for FIFO1/2/3. | Covers reorder paths and full/empty boundaries. Illegal overflow/underflow are assertions, not coverage goals. |
| Inverse scaling class | Even/odd coefficient and zero/nonzero at the scaling input. | Exercises the conditional modular half operation. |
| Pre secret value × position | All signed values `-4..4` at first/last index and across all four lanes; eta-2 and eta-4 polynomials. | Demonstrates lookup and regrouping, including negative residues. |
| Input/output flow | No gaps, first/middle/last input gap; no stall, first/middle/last output stall; PWM B operand boundary; repeated jobs. | Verifies that valid/ready and state transitions are correct. |
| Reset point | Idle, input load, compute, output. | Demonstrates clean cancellation and restart. |

For each bin, preserve a case ID and the checker result in the coverage report so a reviewer can go from the percentage to a passing waveform/log entry. Crosses should include only reachable combinations; document ignored bins and their reason. The separate UVM coverage gate test now proves wrong data, incomplete output, wrong framing missing trace and failed reset checks cannot raise checked coverage.

## Assertions and code coverage

Add executable checks for FIFO occupancy bounds; no pop from empty/no push to full unless a simultaneous legal pop occurs; issue IDs and destination tags staying aligned through pipeline latency; exactly 128 distinct pairs per transform stage; output `m_tdata` and `m_tlast` stable while stalled; exactly 256 accepted output beats and one accepted `m_tlast`; no output after aborted reset; and bounded-secret eligibility for Pre-NTT. Check assertions both with the FIFO index model and in RTL simulation where signals are available. Separate an expected illegal-input test from the normal passing regression.

Run Questa DUT-only statement, branch, expression/condition, FSM, and toggle coverage for the candidate core, butterfly, multiplier, ROM, and wrapper. Report each metric and uncovered lines/states with a test or a justified exclusion. Do not use testbench or vendor library code in the DUT denominator. Source code coverage is not a proof of output correctness; link it to the checked functional cases above.

## Reproducible execution and exit gate

From `sim/`, run the candidate `run_uvm.do` with `NTT_MODE vectors` and the main UVM `run_uvm.do` commands listed in `sim/ntt_LightHD/README.md`. Then run `py -3 FIPS204_NTT/ntt_vectors.py compare --observed sim/ntt_LightHD/ntt_dut_outputs.txt` from the root. Require the explicit `NTT COMPARE PASS`, UVM 117/117 zero-failure summary, and assertion/coverage report; a simulator exit code alone is insufficient. After any RTL change, rerun these and `quartus_map`, `quartus_fit`, `quartus_sta`, and `report_paths.tcl` in `quartus/ntt_LightHD/` before updating Fmax, ALMs, or slack.

Stage 4 closes when the priority requirements above have passing checkers, the architecture-specific coverage bins are reviewed with documented exclusions, code-coverage holes are reviewed, and the user accepts the measured fit trade-off. The user approved operating timing near current Fmax (nominal 148 MHz). The 5 ns constraint remains a separate unmet benchmark; assess the timing gate at the approved operating clock using `build_operating.ps1` and all four corners. Stage 5 post-synthesis/post-fit functional checks now pass as recorded below; Stage 6 sampler integration has not begun.

The redundant non-UVM core/engine/arithmetic benches were removed on 2026-10-09. Earlier directed counts are historical evidence; they are not current exit commands. The separate vector capture remains for the independent Python comparison.

### Added arithmetic-boundary requirement (2026-10-09)

The main UVM sequence must force and observe raw CT sums zero, below q, exactly
q, above q and maximum 2q-2, plus minimum `-(q-1)`, other negative, zero, other positive and maximum `q-1`
raw CT subtraction. The two added pairs are `(a,t)=(0,q-1)` and `(q-1,0)`,
which must return canonical subtraction outputs 1 and q-1 respectively.
Registered operand checks and expected writebacks must pass, followed by the
full golden output/framing pass, before sampling the five sum and five
subtraction bins in `cg_butterfly_arithmetic`. The named boundary job prints
`CHECKED_ARITHMETIC_BOUNDARIES`; the current run reaches 10/10 bins. The coverage
gate self-test also confirms falsely populated arithmetic masks on five rejected
jobs cannot credit these bins. Golden-model mathematics remain unchanged.

### FIFO data-selection requirement (2026-10-09)

Load, Pre-return and compute-return writes must be mutually exclusive. The
selected implementation separates data selection from loading eligibility;
actual write enables and pointer updates retain their original priority.
The UVM routing model must compare each enabled write word, destination and
subsequent physical FIFO contents; no requirement is imposed on an inactive
RAM data port. A simulation guard detects source overlap. Its failure path
has not been forced in a separate injection test; keep the raw hole visible.
The existing UVM writeback-observation corruption test passes on this RTL
(`routing_writeback_final_rebalance.log`) with real outputs correct and checked
jobs/bins zero. Main raw coverage counts and timing are in COVERAGE.md/the plan.

## Product/carry boundary increment (2026-10-09)

`ntt_reduction_boundary_seq` is part of `ntt_full_seq`, not a separate non-UVM
bench. Its five operand pairs are repeated on every multiplier lane. The main
observed trace checks operands, FIFO writebacks and physical writes; all 256
outputs must match unchanged SV PWM mathematics. A passing job prints
`CHECKED_REDUCTION_BOUNDARIES` with results `0/1/1/10000/30000`. See the table
in `COVERAGE.md` for inputs and why these are meaningful cases.

Both narrow-Pre-decoder and collapsed-reduction timing trials passed correctness
but regressed worst-corner Fmax. They are saved, not active. Selected-source
verification is `uvm_selected_restore.log`; fourteen checked functional groups
remain 100%. The separate +8 invalid Pre test is expected to fail at the DUT
eligibility guard; it adds no passing coverage. This is not hardware enforcement
of the bounded-secret contract. Stage 4 and the Stage 5 result-review gate remain open.

## Earlier four-cycle reduction rebalance (2026-10-09)

The selected multiplier now registers product / fold1 / fold2 / fold3 plus
canonical correction. No BF/tag/controller latency changes were made. Main
`uvm_final_rebalance.log` passes 117/117, with fourteen checked covergroups 100%;
`uvm_stage4.log` is refreshed from it. Current source/raw code counts, constant
bit explanations and the reduction proof are in `COVERAGE.md`.

Fresh separate Python capture/compare passes 18/18 cases and 4,608 coefficients.
The coverage-credit and corrupted-writeback UVM sensitivity tests pass on this
RTL; their failed UCDBs remain separate. Fresh map/fit/STA/paths retain the
134.50 MHz / 2,487 ALM result. The prior 131.22 MHz / 2,428 ALM checkpoint remains
saved. Setup at 200 MHz, raw code-hole review, user result review and Stage 5
netlist verification are still open. The next measured path is inverse-butterfly
input subtraction (`bf_bi_q -> mul_gs_reg`) at both slow corners.

## Earlier subtraction constant rewrite (2026-10-09)

The selected butterfly absorbs the corrected candidate's +1 into q+1 before
carry-save compression; borrow selection and latency are unchanged. Main
`uvm_sub_qplus1.log` passes 117/117 with fourteen checked covergroup types 100%.
The directed CT subtraction extrema and signs, inverse golden comparisons,
physical writebacks and every output still pass. Raw counts remain unchanged;
`COVERAGE.md` explains the current arithmetic and existing raw holes.

Separate Python compares 18/18 cases, 4,608 coefficients; no golden-model or
reference-vector changes. Earlier checker sensitivity evidence remains separate
and no checker code/contract changed. Fresh map/fit/STA/paths select 137.04 MHz /
2,451 ALMs; the 134.50 MHz checkpoint is preserved. Twiddle ROM -> `bf_zi_q` is
now worst at both slow corners. Stage 4 timing/code-hole review and the Stage 5
result-acceptance gate remain open. No netlist or board result is claimed.

## Earlier selected twiddle-guard removal (2026-10-10)

The inverse twiddle zero guard is redundant: all 256 initialized ROM values
are canonical and nonzero. The independent registered-twiddle/operand/FIFO
checks and full output comparison remain unchanged. Main `uvm_tw_nonzero.log`
passes 117/117, zero UVM errors/fatals, fourteen checked covergroup types 100%.
Raw core conditions are 64/102 instead of 64/103 by removing one condition,
with no extra hit claimed. All other raw code counts remain unchanged.

Fresh separate coverage-credit and corrupted-writeback tests detect deliberate
failures without credit; +8 Pre input reaches its exact intended DUT fatal.
Their UCDBs stay separate. Python compares 18/18 cases and 4,608 coefficients.
Fresh map/fit/STA/paths select 140.69 MHz / 2,427 ALMs; 137.04 MHz remains saved.
Next measured path: FIFO RAM read/word and operand selection -> bf_bi_q.
Stage 4 timing/code-hole review and Stage 5 user-acceptance gate remain open.

## Earlier selected operand selectors (2026-10-10)

Combined FIFO/coefficient masks are decoded at read launch, aligned with RAM
outputs and tags, without adding latency. Independent registered operand,
FIFO physical-write and full output checks remain unchanged. Main
`uvm_operand_boolean.log` passes117/117, zero UVM errors/fatals and14checked
covergroup types100%. Packed selectors now expose per-bit toggles; all278raw
core misses are accounted for in `COVERAGE.md`, without exclusions.

Fresh coverage-credit, operand-corruption and writeback-corruption self-tests
reject deliberate failures without credit; failed UCDBs stay separate. Separate
Python passes18/18cases,4608coefficients. Fresh fit selects145.18MHz at2592ALMs,
2152registers,5DSP/21M10K; the smaller140.69MHz/2427ALM/20M10K remains saved.
Next measured paths are BF keep-sum to shared delay RAM atslow85 and FIFO
read to BF input atslow0. Stage4 remains open; Stage5 requires user acceptance.

## Latest selected inverse kept-sum reduction (2026-10-10)

Main `uvm_keep_bias.log` passes118/118, zero UVM errors/fatals and14checked
covergroup types100%. One new inverse job plants rawGS sums0,q-1,q,q+1,2q-2
on all four lanes. Actual registered operands are independently checked and
classified with integer sums. The scoreboard requires11111per lane plus correct
physical writes/framing/all256outputs before credit. `CHECKED_GS_SUM_BOUNDARIES`
is a directed witness, not a new covergroup percentage. Study its sequence,
`ntt_routing_trace.note_gs_sum()` and the scoreboard gate; `COVERAGE.md` gives
operand values and the S+8191carry-reduction proof.

The separate `ntt_gs_sum_gate_test` hides lane2 exact-q metadata while keeping
real outputs correct. It is rejected without credit (`UVM GS SUM GATE PASS`).
Existing five-fault credit gate also passes freshly; failed UCDBs remain separate.
Each BF raw55/55statements,17/17branches,704/704toggles; other raw counts unchanged.
Python18/18cases,4608coefficients. Fresh fit145.73MHz/2568ALMs; worstsetup
-1.862ns,hold+0.104ns,pulse-0.555ns. Stage4 remains open; Stage5 needs acceptance.

## Selected first-fold pipeline timing increment (2026-10-10)

Current multiplier/BF/return latency is 5/7/10. Independent observed-tag and
physical-writeback models require ten clocks; expected arithmetic is unchanged.
Fresh main UVM passes 118/118, with fourteen groups at 100%. Separate Python
comparison passes 18/18 cases and 4,608/4,608 coefficients. Measured core counts
are 267/267/75/236, and wrapper counts are 781/781/845/750. Fresh fault-credit,
operand, writeback and GS-witness tests reject without credit. Exact logs, raw
counts and setup/hold/resource tradeoffs are in the plan and COVERAGE.md.
Worst setup improves 0.126 ns to -1.736 ns; timing remains open.

## Latest selected early-write/prefetch checkpoint (2026-10-10)

Main UVM 118/118, zero errors/fatals, fourteen implemented checked covergroup types
100%; observed tag delay remains ten clocks. New RTL predecodes three write
select bits and prepares next read address without ready/last gating; read
enable is unchanged. Actual enabled read addresses, FIFO writes, output order,
framing, stalls and nine reset/recovery scenarios pass the existing independent
models. No testbench, golden arithmetic or reference-file change.
Fresh five-fault coverage-credit gate and observed writeback-fault tests reject
without new credit; failed UCDBs remain separate. Separate Python 18/18 cases,
4608/4608 coefficients. Current raw coverage denominators are in COVERAGE.md;
FIFO3 B-select is constant zero and remains a visible miss. Other unchanged
negative-test evidence is retained, not freshly rerun. Fitted worst Fmax 150.49 MHz,
setup/hold/pulse -1.645/+0.152/-0.555 ns at 5 ns; Stage 4open, Stage 5requires acceptance.

## Approved operating timing closure (2026-10-10)

The user approved timing near current Fmax. All six RTL files match the selected
checkpoint byte-for-byte; UVM 118/118 and Python 4608/4608 evidence is retained,
not rerun. Fresh aggressive-target map/fit followed by approved 148 MHz STA
passes all 20 checks, zero TNS, worst setup/hold/pulse +0.111/+0.152/+1.201 ns.
No coverage bins, exclusions, checkers or golden models changed. The 200 MHz
benchmark still fails. The operating timing gate is closed within the standalone
internal model; overall Stage 4 needs user acceptance. See the approved 148 MHz
section in [the plan](POST_MIDYEAR_VERIFICATION_PLAN.md) for all-corner results,
rejected relaxed fit, commands and limits. Stage 5/netlist, board and sampler
integration remain pending. Nothing committed.

## Stage 5 functional netlist results (2026-10-11)

Both distinct post-synthesis and post-fit models pass the same main UVM top:
**117/117 jobs and 29,952/29,952 coefficients each**, zero UVM errors/fatals.
Each gate includes 117 completions, seven aborts, eight reset witnesses and
16 Pre/general equivalence pairs. All 109 non-reset source jobs are reused;
eight external reset scenarios replace the nine RTL-state source scenarios.

Fresh source UVM passes **118/118**, with 118 checked trace/routing witnesses,
all fourteen functional covergroup types at 100%, and unchanged raw code counts.
Its current transcript/report producer is `uvm_stage5_source.log`.
Netlist mode creates no coverage subscriber and credits no internal bins or
code coverage. It checks public behavior with the unchanged independent model.
The separate external checker self-test rejects five corrupted observations;
its intentional rejections are not added to the passing regression totals.

No RTL or golden-model change was required. The netlist driver waits for `done`
after the final accepted output so completion is checked before another reset
or request. Cyclone V models are functional, without SDF; operating timing
remains the positive 148 MHz TimeQuest result. Board and integration tests are
pending. Commands, warning review, scope and archived evidence are in
[the Stage 5 plan section](POST_MIDYEAR_VERIFICATION_PLAN.md#stage-5---functional-implementation-verification-completed-2026-10-11).

## Expanded source coverage after Stage 5 (2026-10-11)

The main UVM regression now passes **620/620 jobs, 158,720 coefficients**, zero
UVM errors/fatals. Eight new covergroup types bring the model to 22; each meets
the 90% review threshold. Average across types is **99.51%**, minimum **92.36%**.
Output ranges hit 31/32; mode/gap/stall combinations hit 133/144. The original
fourteen groups remain 100%. No percentages are forced below 100% and no missed
legal bins are waived. The 502 added jobs cover input shapes, prescribed
outputs, PWM A/B range pairs, 400 reproducible variable-flow jobs and all 32
checked operation/reset transitions. Actual measured durations are checked
against requested profiles before coverage credit. A separate seven-fault
checker self-test rejects corrupted observations without new credit.

Raw DUT code coverage: statements **762/775 (98.32%)**, branches **388/402
(96.52%)**, conditions **56/85 (65.88%)**, expressions **56/59 (94.92%)**,
toggles **11,691/12,735 (91.80%)**, FSM states **13/13** and transitions **24/24**.
Counts are unchanged from Stage 5; no exclusions or failed UCDB merges.
Condition coverage remains below target, with reviewed guards/correlations and
remaining review items described in [COVERAGE.md](COVERAGE.md). That document
also lists every unhit new bin, sample/checker logic and arithmetic of totals.

Run `do ntt_LightHD/run_uvm.do` from `sim/`; require `NTT EXPANDED UVM PASS`.
Default simulator seed 20261011; new flow seed 439041101. Current log:
`uvm_expanded.log`; main UCDB/raw-report names are unchanged. Exact evidence is
in `experiments/ntt_stage4/lighthd_expanded_coverage_checkpoint/`.
RTL/golden, fitted timing/resources and cycle counts are unchanged. Stage 5
retains its archived 117-job netlist results; only its checker compatibility
self-test was rerun with the updated UVM. No 620-job full-netlist result,
FPGA result, Stage 6 integration or commit is claimed.
