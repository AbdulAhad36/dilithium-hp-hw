# NTT verification test plan — FIFO candidate

**Stage:** 4, in progress. **DUT:** the self-contained `src/ntt_LightHD/` RTL (`ntt_core.sv`, package, multiplier, butterfly, twiddle ROM, and serial wrapper). Its focused Questa files are in `sim/ntt_LightHD/`; its Quartus project is in `quartus/ntt_LightHD/`. This is a reconstruction of LightHD's published four-butterfly, three-FIFO structure; it is not the authors' RTL. The saved four-bank design remains the comparison and rollback reference.

## Meaning of a pass and a coverage hit

A test passes only when 256 accepted output coefficients match an independent expected polynomial, `m_tlast` occurs exactly on accepted beat 255, and no timeout or UVM error occurs. The scoreboard's `checked_ap` publishes a transaction to `ntt_coverage` **after** those conditions pass. Thus the existing 100% `op × input-kind` coverage means its 12 standard-mode bins were hit by passing transactions. It does **not** mean every FIFO state, twiddle, Pre-NTT case, code branch, timing corner, or physical implementation was covered. The Python vector comparison checks output files separately; its input and expected polynomials come from the independent FIPS 204 NTT reference implementation, not NIST-supplied NTT vectors.

The current candidate has these passing source checks: Python compare 18/18 cases (4,608/4,608 coefficients), core directed 39/39, engine directed 34/34, and UVM 66/66 (53 standard plus 13 Pre-NTT). These counts and the 12 standard plus three Pre case-class bins are not Stage 4 coverage closure. The relocated candidate run is `sim/ntt_LightHD/uvm.log`; the saved four-bank build still passes 53/53 in `experiments/ntt_stage3/banked_baseline/sim/uvm_stage4_pre_compat.log`.

## Requirement and checker matrix

| ID | Requirement / expected behavior | Stimulus and observed check | Present evidence / Stage 4 action |
|---|---|---|---|
| M1 | Modular multiplication returns `(a*b) mod q`, including 0, 1, `q-1`, and values near reduction boundaries. | Directed and randomized operands; compare each result with wide-integer `% q` software reference, including pipeline latency. | Existing reference/unit checks cover main arithmetic; add explicit boundary and back-to-back pipeline cases. |
| M2 | Forward CT and inverse GS butterfly signs, twiddle use, and inverse `/2 mod q` are correct. | Unit-level known pairs at each edge and random values; check both outputs and exact valid/tag delay. | Core transform results pass; add unit cases for odd/even inverse scaling and all twiddle classes. |
| T1 | ROM and decoder select the FIPS 204 twiddle for every `(operation, stage, issue, lane)` used. | Exhaustive 8 stages × 32 issues × 4 lanes address/value check against an independent generated table. | Python FIFO index proof covers pair positions; add direct twiddle address/value proof and RTL trace. |
| F1 | Three FIFO stores preserve the intended coefficient order without overflow, underflow, stale reads, or cross-transaction leakage. | Index-tag proof for all 128 pairs per stage; runtime assertions on push/pop counts and valid tags; alternating unrelated polynomials. | Index proof passes for standard and Pre paths; add runtime assertions and coverage of occupancy extrema and each source/destination selection. |
| F2 | Four butterfly lanes perform all 128 pairs each stage and route results to the proper FIFO words. | Instrument accepted issue/writeback tags; assert each stage sees 128 unique pair IDs and 256 output destinations exactly once. | End-to-end comparisons pass; add per-stage trace checker to localize errors. |
| O1 | General NTT matches FIPS 204 for any canonical polynomial, including zero, max, deltas, ramp, and random. | Independent Python output comparison and SV golden model; all 256 coefficients and output framing checked. | 18/18 Python cases overall and directed/UVM passes; expand random seeds and boundary values. |
| O2 | INTT returns the specified inverse transform; `INTT(NTT(a)) = a`. | Random and edge polynomials; compare standalone inverse and round-trip outputs. | Existing vector, core, engine, UVM tests pass; add inverse twiddle and scaling bins. |
| O3 | PWM produces 256 coefficient-wise modular products from two separately loaded polynomials. | Zero, max, delta, random, and independent A/B patterns; check operand ordering and 512 accepted input beats. | Existing vector, directed, and UVM checks pass; add B-load boundary and stall checks. |
| P1 | `OP_PRE_NTT` equals general NTT for secrets whose signed coefficients are in `[-4,4]`. | Exhaustive single-coefficient values `-4..4` at boundary indices, mixed eta-2/eta-4 random secrets, all 256 outputs checked; compare Pre and standard modes. | Directed eta-4, one independent bounded vector, gaps/stalls, and 13 checked UVM Pre cases pass. Add random bounded seeds and explicit Pre/standard equivalence transactions. |
| P2 | Pre-NTT first-stage lookup/regrouping never applies silently to an ineligible coefficient. | Inject residues outside `[-4,4]`; simulation must reject the job or a documented hardware validity protocol must block it. | Current core uses a simulation `$fatal` and has no synthesizable rejection/fallback. Define and verify an integration-side eligibility guarantee before deployment. |
| H1 | Input transfer advances only on `s_tvalid && s_tready`; gaps and output backpressure do not change data/order. | Gap patterns at first/middle/last input beat; output `m_tready` stalls at first/middle/last beat; stable `m_tdata/m_tlast` while stalled. | Engine directed gaps/stalls pass; add explicit ready/valid stability assertions and full PWM/Pre stall matrix. |
| H2 | Reset, repeated jobs, and operation changes do not leak FIFO/tag state. | Reset idle, during load, during run, during output; no reset between unlike completed jobs; check first next output and timeout behavior. | UVM resets per transaction, so no-reset repetition is still open. Add directed sequences and reset assertions. |
| L1 | Core and wrapper latencies are measured from documented handshake boundaries. | Count start-to-done and launch-to-last accepted output, with no stalls; separately count transfer and compute cycles. | 266/266/74/235 core and 780/780/844/749 full cycles measured. Add assertions or tolerances for each no-stall mode; label stalled latency separately. |
| I1 | Future SHAKE/sampler adapter only sends eligible secrets to Pre-NTT and preserves job/core tags. | Contract-level descriptor tests; variable sampler acceptance, buffering, rejection, and backpressure. | No sampler or Keccak integration exists here; Stage 6 owns end-to-end dataflow. |

## Functional coverage model to implement

Coverage must be sampled from **observed, checked results**. For internal FIFO/stage events, collect a per-job event bitmap during execution and commit its bins only after that job passes the scoreboard. Record failures separately; do not let a failed job close a functional bin.

| Coverpoint / cross | Intended bins | Why it matters |
|---|---|---|
| Operation × input class | NTT, INTT, PWM × zero, max, delta, random; Pre-NTT × boundary, eta-2, eta-4. Add more bounded shapes where legal. | Shows each legal mode has a correct result for representative polynomial shapes. The current models close only these 12 + 3 case-class bins. |
| Stage × lane × direction | Eight stages × four lanes × NTT/INTT, plus Pre-NTT stages 1–7 and lookup stage 0. | Shows every scheduling position participated in a passing transform. |
| Twiddle class × stage | Unity, nonunity, positive/negative inverse mapping, lowest/highest ROM address. | Exposes decoder omissions despite good random end results. |
| FIFO route × occupancy | Each source/destination route and empty, mid, full capacity states for FIFO1/2/3. | Covers reorder paths and full/empty boundaries. Illegal overflow/underflow are assertions, not coverage goals. |
| Inverse scaling class | Even/odd coefficient and zero/nonzero at the scaling input. | Exercises the conditional modular half operation. |
| Pre secret value × position | All signed values `-4..4` at first/last index and across all four lanes; eta-2 and eta-4 polynomials. | Demonstrates lookup and regrouping, including negative residues. |
| Input/output flow | No gaps, first/middle/last input gap; no stall, first/middle/last output stall; PWM B operand boundary; repeated jobs. | Verifies that valid/ready and state transitions are correct. |
| Reset point | Idle, input load, compute, output. | Demonstrates clean cancellation and restart. |

For each bin, preserve a case ID and the checker result in the coverage report so a reviewer can go from the percentage to a passing waveform/log entry. Crosses should include only reachable combinations; document ignored bins and their reason. Add a deliberate failing output case to prove failed transactions do not raise checked coverage.

## Assertions and code coverage

Add executable checks for FIFO occupancy bounds; no pop from empty/no push to full unless a simultaneous legal pop occurs; issue IDs and destination tags staying aligned through pipeline latency; exactly 128 distinct pairs per transform stage; output `m_tdata` and `m_tlast` stable while stalled; exactly 256 accepted output beats and one accepted `m_tlast`; no output after aborted reset; and bounded-secret eligibility for Pre-NTT. Check assertions both with the FIFO index model and in RTL simulation where signals are available. Separate an expected illegal-input test from the normal passing regression.

Run Questa DUT-only statement, branch, expression/condition, FSM, and toggle coverage for the candidate core, butterfly, multiplier, ROM, and wrapper. Report each metric and uncovered lines/states with a test or a justified exclusion. Do not use testbench or vendor library code in the DUT denominator. Source code coverage is not a proof of output correctness; link it to the checked functional cases above.

## Reproducible execution and exit gate

From `sim/`, run the candidate `run_vectors.do`, `run_core_check.do`, `run_engine_check.do`, and `run_uvm.do` commands listed in `sim/ntt_LightHD/README.md`. Then run `py -3 FIPS204_NTT/ntt_vectors.py compare --observed sim/ntt_LightHD/ntt_dut_outputs.txt` from the root. Require the explicit `NTT COMPARE PASS`, directed `ALL ... CHECKS PASSED`, UVM zero-failure summary, and assertion/coverage report; a simulator exit code alone is insufficient. After any RTL change, rerun these and `quartus_map`, `quartus_fit`, `quartus_sta`, and `report_paths.tcl` in `quartus/ntt_LightHD/` before updating Fmax, ALMs, or slack.

Stage 4 closes when the priority requirements above have passing checkers, the architecture-specific coverage bins are reviewed with documented exclusions, code-coverage holes are reviewed, and the user accepts the measured fit trade-off. The current 5 ns setup constraint fails, so timing closure remains open. Stage 5 post-synthesis/post-fit functional checks and Stage 6 sampler integration have not begun.
