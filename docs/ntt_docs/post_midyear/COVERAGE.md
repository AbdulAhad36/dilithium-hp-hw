# NTT coverage status - LightHD UVM

## Current interaction coverage checkpoint - 2026-10-12

**748/748 main UVM jobs, 191,488/191,488 compared coefficients, zero UVM
errors/fatals. 32 checked covergroup types; overall functional type average
90.4730903% (90.47%).** This adds ten groups and 128 jobs to the previous
620-job checkpoint. Every valid hit is retained. The user's 90-91% target is
a review checkpoint; no test fails for exceeding 91%, and no sampling is
stopped, hidden or excluded to enforce an upper percentage.

### New covergroups and genuine remaining gaps

| Group | Hit/legal bins | Type coverage | Requirement |
|---|---:|---:|---|
| `cg_shape_input_flow` | 108/192 | 56.25% | Mode x actual A polynomial shape x observed maximum input-gap class |
| `cg_shape_output_flow` | 108/192 | 56.25% | Mode x actual A polynomial shape x observed maximum output-stall class |
| `cg_shape_reset` | 64/64 | 100.00% | Mode x actual A shape x observed reset between jobs |
| `cg_pwm_shapes` | 64/64 | 100.00% | Actual PWM A shape x actual PWM B shape |
| `cg_pre_spatial_values` | 144/144 | 100.00% | Exact signed Pre value (-4..4) x 64-coefficient quadrant x lane |
| `cg_output_lane_ranges` | 104/128 | 81.25% | Mode x observed output range x coefficient lane |
| `cg_input_spatial_ranges` | 148/148 | 100.00% | Accepted operand stream x input range x 64-coefficient quadrant |
| `cg_transition_flow` | 186/576 | 32.29% | Previous/current checked mode x observed gap x observed stall |
| `cg_shape_dual_flow` | 32/32, 36/36, 219/1152 | 73.00% | Explicit cross of mode/shape and gap/stall, plus its two marginals |
| `cg_transition_shape_flow` | 252/4608 | 5.47% | Previous/current checked mode x actual A shape x gap x stall |

For `cg_shape_dual_flow`, the three counts are the two marginals (32/32,
36/36) and their **219/1,152 cross (19.01%)**. Its default equal-weight type
score is `(100 + 100 + 19.0104167)/3 = 73.0034722%`; it must not be described
as 73% of cross combinations. All coverpoint/cross weights use Questa defaults.
The overall headline is `sum(32 type percentages)/32`, matching the existing
headline definition. The raw report truncates the display to **90.47%**.

For transparency, across all coverpoint/cross goals the raw counts are
**16,166/22,047 bins = 73.33%**. This includes marginal and cross goals, not
independent requirements. It is a different aggregation from the type average.
The ten interaction types average **70.4513889%**. Several individual types
reach 100%; these do not erase the incomplete crosses.

### Bin definitions and reachability

- `mode`: NTT=0, INTT=1, Pre=2, PWM=3.
- `shape`: zero=0, nonzero constant=1, single nonzero=2, alternating=3,
  ascending=4, descending=5, mixed eta-2=6, other=7, in this priority order.
  Classification uses captured accepted A/B coefficients, not sequence labels.
- `gap`/`stall`: none=0, 1 clock=1, 2 clocks=2, 3-7=3, 8-15=4, 16+=5.
  These are measured maxima, checked against the requested profile. The tested
  maximum remains 63 clocks; this does not claim an arbitrary duration proof.
- `quadrant = coefficient_index/64`, `lane = coefficient_index%4`.
- Input streams: NTT A=0, INTT A=1, PWM A=2, PWM B=3, Pre A=4. The eight
  coefficient ranges retain the earlier definition below. Only Pre ranges
  3,4,5 are ignored (12 quadrant bins, IDs140..151), because they violate
  the bounded-secret contract. No new observed legal misses are excluded.
- Encodings: shape/flow=`(mode*8+shape)*6+duration`; shape/reset=
  `(mode*8+shape)*2+reset`; PWM shapes=`Ashape*8+Bshape`; Pre spatial=
  `((signed_value+4)*4+quadrant)*4+lane`; output ranges=
  `(mode*8+range)*4+lane`; input spatial=`(stream*8+range)*4+quadrant`;
  transition flow=`(prior*4+current)*36+gap*6+stall`; transition shape flow=
  `((prior*4+current)*8+shape)*36+gap*6+stall`.
- Reset means an observed reset between checked jobs, including the independently
  checked abort/recovery witness. Transition crosses do not claim that an
  aborted operation produced an accepted result. There is no predecessor sample
  for the first checked job.

### New tests and checker connection

`ntt_interaction_seq` runs **128** new jobs through the main UVM environment:
64 mode/shape/flow jobs (4 operations x 8 shapes x 2 profiles, with varied
reset and backpressure), then all 64 PWM A/B shape pairs. Its xorshift seed
is **1831565813 (0x6d2b79f5)**; the retained 502-job extension keeps seed
439041101; the simulator seed is 20261011. Tests never query coverage.

The driver sends operands; the monitor's `ntt_trace` and independent routing
model collect actual transfers/results. The scoreboard compares all 256 outputs,
framing, routing and flow-duration observations. Only its `checked_ap` publishes
passing jobs. `ntt_coverage::write` calls `sample_interactions` before updating
the previous checked mode, then samples the retained groups. Each job prints
`CHECKED_INTERACTIONS` with name, modes, actual shape, measured gap/stall and reset.

The source checker self-test also saves the interaction mean and confirms all
seven deliberate failures leave it and the checked-job count unchanged.
`coverage_gate_interactions.log` reports `UVM COVERAGE GATE PASS` with zero
UVM errors/fatals. The gate database remains separate from the passing regression.

### Remaining verification work

The unhit bins are real gaps. Shape/input and shape/output flow each miss 84/192;
output ranges by lane miss 24/128; transition/flow misses 390/576; the explicit
shape/dual-flow cross misses 933/1,152; transition/shape/flow misses 4,356/4,608.
Next closure work would vary gap/stall profiles for structured inputs, force
output ranges onto each lane, and exercise transitions with controlled shapes
and flow. The 90.47% checkpoint does **not** mean these areas are fully verified.
No integration coverage is credited; sampler/Keccak Stage 6 remains pending.

### Current DUT code coverage

These raw counts are unchanged from the previous checkpoint. Conditions remain
below 90%; the existing code-hole discussion below still applies. No code
exclusions or RTL changes were made to alter these numbers.

| Metric | Hit/total | Coverage |
|---|---:|---:|
| Statements | 762/775 | 98.32% |
| Toggles | 11691/12735 | 91.80% |
| Branches | 388/402 | 96.52% |
| Conditions | 56/85 | 65.88% |
| Expressions | 56/59 | 94.92% |
| FSM States | 13/13 | 100.00% |
| FSM Transitions | 24/24 | 100.00% |

### Run and evidence

In Questa:

```tcl
cd D:/GitHub/dilithium-hp-hw/sim
do ntt_LightHD/run_uvm.do
```

The GUI shows waves, covergroups, instance/code coverage and transcript.
Require `NTT INTERACTION UVM PASS: 748/748 jobs` and zero UVM errors/fatals.
See `OVERALL_FUNCTIONAL_COVERAGE` for the actual type average. The main UCDB
and detailed report retain their existing names. Headless execution:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/uvm_interactions.log -do 'do ntt_LightHD/run_uvm.do; quit -f'
```

Evidence and every missing bin are archived in
[interaction checkpoint](../../../experiments/ntt_stage4/lighthd_interaction_coverage_checkpoint/README.md).
`results.json` contains all 32 groups, each point/cross count and missing bin,
seven DUT code metrics and seeds; source/evidence hashes and complete sources,
logs, main UCDB and separate checker UCDB are retained. RTL and golden hashes
match the previous accepted checkpoint. Full netlist suites were not rerun for
this TB-only extension; retained 117-job Stage 5 results remain their evidence.

## Historical 620-job checked coverage - 2026-10-11

The main source regression is now **620/620 passing jobs**, **158,720/158,720
compared coefficients**, zero UVM errors/fatals and 620 checked internal,
coefficient-routing and extended-profile witnesses. It reuses the original
118 jobs and adds **502**: 32 input-shape jobs, three prescribed output-range
jobs, two bounded Pre impulses, one PWM operand-range Cartesian job, 400
randomized flow jobs and 64 jobs checking 32 operation/reset transitions.

The acceptance gate is **at least 90% in every one of 22 covergroup types**,
not a requirement to hit every bin. No percentages are artificially reduced.
The original fourteen types remain at 100%. Of the eight new types:

| New covergroup | Hit/legal bins | Coverage | Checked meaning |
|---|---:|---:|---|
| `cg_input_range` | 37/37 | 100.00% | Four ordinary operand streams plus bounded Pre A; accepted coefficient ranges. |
| `cg_output_range` | 31/32 | 96.88% | Four operations x eight canonical output ranges. |
| `cg_pwm_pairs` | 256/256 | 100.00% | Eight A ranges x eight B ranges x four coefficient lanes. |
| `cg_input_gap_duration` | 60/60 | 100.00% | Four modes x three input regions x five nonzero gap durations. |
| `cg_output_stall_duration` | 60/60 | 100.00% | Four modes x first/middle/last output x five nonzero stall durations. |
| `cg_flow_combination` | 133/144 | 92.36% | Four modes x six maximum-gap classes x six maximum-stall classes. |
| `cg_operation_transition` | 32/32 | 100.00% | Previous/current checked mode x observed intervening reset. |
| `cg_polynomial_shape` | 32/32 | 100.00% | Four modes x eight shapes classified from accepted operand A. |

Questa's covergroup-type average is **99.51%** across 22 types. The eight new
groups' equal-weight mean is **98.65%**, and the lowest group is **92.36%**.
These averages weight groups equally; they are not a count of all bins and
are not the percentage of all possible inputs verified. The 14,000-plus
structural bins do not drown the new behavioral crosses in these averages.

### Definitions and sampling evidence

Canonical coefficient ranges are `0`, `1`, `2..4`, `5..4095`, `4096..floor(q/2)`,
`floor(q/2)+1..q-5`, `q-4..q-2`, and `q-1`. Inputs are contractually canonical.
Pre inputs can occupy only ranges 0,1,2,6,7; its three impossible ranges are
explicitly ignored (32+5=37 legal input-range bins). Gap/stall classes are
none, one, two, 3..7, 8..15 and 16..63 clocks. The final class also categorizes
longer observations, but this run exercises values only through 63; arbitrary
stall lengths are not claimed. Input regions are accepted index <16, >=240,
otherwise middle; output regions are coefficient 0,255,otherwise middle.

`ntt_extended_seq` generates the cases. `ntt_driver.sv` uses per-item gap and
boundary lengths; `ntt_monitor.sv` drives requested output stalls and checks
held data/last. `ntt_trace.sample_durations()` counts actual pin observations,
including full runs and their regions. `ntt_scoreboard.flow_profile_ok()`
independently derives requested per-region run counts and maximum lengths,
and rejects discrepancies before `checked_ap` publication. The existing
independent operand/routing model and all 256 golden comparisons must also
pass. `ntt_coverage.sample_expanded()` then samples accepted operands, actual
outputs, observed reset and measured durations; sequence labels never select
these new bins. Each passing job prints `CHECKED_EXTENDED`.

Shape classification, in priority order, is zero, nonzero constant, one
nonzero coefficient, alternating pair, ascending, descending, mixed eta-2,
and other. Ascending/descending are non-strict order in canonical residues,
not signed order. Transition coverage describes two successive checked jobs;
it does not replace the existing nine mid-job reset scenarios.

Default simulator seed is **20261011**. The new flow generator has separate
xorshift seed **439041101** (`0x1a2b3c4d`), selectable using `+NTT_EXT_SEED`.
It selects gap/stall classes independently and never queries coverage to pick
stimulus. Four operations each receive 100 randomized flow jobs. Both seeds
and exact sources are archived; the remaining gaps are real results of this run.

### Remaining functional bins

Output bin `classes[23]` is unhit: Pre mode (index 2) producing exactly `q-1`.
It is legal, remains in the denominator, and is not waived. The eleven unhit
flow bins below decode as `mode*36 + gap_class*6 + stall_class`:

| Bin | Mode | Max input gap (clocks) | Max output stall (clocks) |
|---|---|---|---|
| 10 | NTT | 1 | 8-15 |
| 18 | NTT | 3-7 | none |
| 37 | INTT | none | 1 |
| 41 | INTT | none | 16-63 |
| 46 | INTT | 1 | 8-15 |
| 58 | INTT | 3-7 | 8-15 |
| 91 | Pre | 3-7 | 1 |
| 103 | Pre | 16-63 | 1 |
| 115 | PWM | 1 | 1 |
| 132 | PWM | 8-15 | none |
| 142 | PWM | 16-63 | 8-15 |

No claim covers arbitrary combinations of reset cycles, backpressure durations
or all 23-bit inputs. The current sampled coverage target is met with the
remaining bins visible.

### Current raw DUT code coverage

Only DUT RTL is instrumented. For each metric, sum hits and bins across the
four ROMs, four multipliers, four butterflies, core and wrapper **self counts**;
parent entries exclude children, so no instance is counted twice.
Percentage = `100 * sum(hits) / sum(bins)`. No code exclusions or negative-test
UCDBs are merged. This is different from Questa's filtered instance summary.

| Code metric | Raw hit/total bins | Coverage |
|---|---:|---:|
| Statements | 762/775 | 98.32% |
| Branches | 388/402 | 96.52% |
| Conditions | 56/85 | 65.88% |
| Expressions | 56/59 | 94.92% |
| Toggles | 11,691/12,735 | 91.80% |
| FSM States | 13/13 | 100.00% |
| FSM Transitions | 24/24 | 100.00% |

Raw counts are unchanged from the Stage 5 source baseline. The added tests
exercise more functional combinations on already executed RTL; they do not
establish new line/branch hits. **Condition coverage remains below 90%**:
core 49/78 plus wrapper 7/7 = 56/85. Reviewed holes include error guards,
correlated INTT/PWM terms and mutually exclusive write routes. The detailed
code-hole review below remains applicable; unresolved attribution/routes are
not automatically called unreachable. Multiplier constant bits, packed
selectors and fixed-width counters explain many toggle misses. FSM coverage
being 100% does not imply complete code coverage.

### Checker proof, run and artifacts

`coverage_gate_expanded.log` records a separate passing checker self-test:
seven corrupted observations (coefficient, beat count, framing, missing trace,
reset status, forged maximum gap, forged maximum stall) are rejected without
increasing checked jobs, schedule/arithmetic coverage or the eight-group mean.
These expected failures are not added to the 620 passing jobs. Its UCDB remains
separate. The existing fitted-netlist checker also passes a compatibility
self-test with the updated shared UVM code; the full netlist evidence remains
the earlier 117-job Stage 5 suite, not a rerun of all 620 expanded source jobs.

Run from Questa with working directory `sim/`:

```tcl
do ntt_LightHD/run_uvm.do
```

Require `NTT EXPANDED UVM PASS`, zero UVM errors/fatals and the 620-job summary.
The main raw report/database are `sim/ntt_LightHD/ntt_lighthd_coverage.rpt` and
`ntt_lighthd_cov.ucdb`; current transcript is `uvm_expanded.log`. Inspect the
UCDB in Questa's Coverage viewer for individual bins/RTL misses. Exact sources,
logs, UCDB/raw report, parsed counts/misses and separate checker evidence:
[expanded coverage checkpoint](../../../experiments/ntt_stage4/lighthd_expanded_coverage_checkpoint/README.md).
RTL, golden arithmetic, fitted area/timing and operation cycle counts are
unchanged. No fresh synthesis or expanded full-netlist run is claimed.

## How an observed event becomes a checked coverage hit

1. `ntt_sequence.sv` generates the input and calculates the expected polynomial
   using the independent pure-SV model in `ntt_ref_pkg.sv`.
2. `ntt_driver.sv` sends the request and coefficients to the real DUT.
3. `tb_top.sv` exposes DUT stage/issue, twiddle, FIFO and pipeline signals through
   read-only observations in `ntt_if.sv`. `ntt_monitor.sv` samples them into
   the per-job `ntt_trace.sv` object while collecting accepted output beats.
4. The trace checks every legal stage/issue exactly once, independently computes
   all four lane twiddle addresses and ROM values, checks FIFO occupancy bounds,
   delays destination/valid tags independently by ten clocks, and compares
   registered inverse result words against reference multiplication by
   `(q+1)/2 mod q`. The monitor also checks data/last stability while stalled.
5. `ntt_scoreboard.sv` requires a valid trace, 256 accepted outputs, correct
   final-beat framing, and equality of **every** coefficient with the golden result.
   Only a passing observed transaction is published on `checked_ap`.
6. `ntt_coverage.sv` samples its real covergroups from that observed trace.
   A failed job cannot credit these groups. Each passing job prints its name,
   counts, occupancy, routes, scaling/Pre value masks and gap/stall masks.

The wiring is in `ntt_env.sv`: driver -> expected FIFO, monitor -> observed FIFO,
scoreboard `checked_ap` -> coverage subscriber. There are no covergroups in
`ntt_trace.sv`; collecting an event alone does not credit a bin.

## Original fourteen implemented UVM coverage groups (still 100%)

All rows below are **100% in the main UVM UCDB**. Counts refer to the listed
coverpoints/crosses, not an invented aggregate percentage.

| Covergroup | Checked bins hit / legal total | What was observed and checked |
|---|---:|---|
| `cg_ntt` operation x input kind | 12/12 | NTT/INTT/PWM x zero/max/delta/random; full output comparison. |
| `cg_pre` | 3/3 | Boundary, eta-2 and eta-4 bounded-secret jobs; golden forward NTT comparison. |
| `cg_reset_abort` | 9/9 | Observed cancellation point, quiet controls/FIFOs/tags and correct different fresh job, without an additional reset. |
| `cg_pre_equivalence` | 2/2 | Bounded-random eta-2 and eta-4 pairs; actual Pre output equals the previous actual general NTT output. |
| `cg_restart` operation x reset before job | 8/8 | Four modes with/without reset between completed jobs. This is not mid-job cancellation coverage. |
| `cg_coefficient_routing.cp_pair` | 2,944/2,944 | Unique mathematical coefficient pairs, independently reconstructed from actual FIFO contents/operand observations. |
| `cg_coefficient_routing.cp_destination` | 5,888/5,888 | Every coefficient ID written exactly once per active transform stage; expected values, push masks, pointers and physical writes checked. |
| `cg_coefficient_routing.cp_pwm_id` | 256/256 | Each PWM coefficient index consumes the matching A/B inputs and returns exactly once. |
| `cg_coefficient_routing.cp_output_order` | 1,024/1,024 | Four modes x 256 sequential output positions; read addresses and actual values checked. |
| `cg_schedule` | 2,944/2,944 | `(8+8+7) stages x 32 issues x 4 lanes`; Pre stage 0 is a lookup, excluded here. All four addresses are checked per issue. |
| `cg_twiddle` | 764/764 | 255 forward + 255 inverse + 254 Pre stage/address bins; independently checked address and registered value. |
| `cg_fifo.cp_source` | 11/11 | Three FIFO source routes per transform mode, two for PWM. |
| `cg_fifo.cp_destination` | 11/11 | Corresponding issued destination routes; return destinations checked against independently delayed issue tags. |
| `cg_fifo.cp_occupancy` | 32/32 | Four modes x three FIFOs x empty/partial/full, minus four unreachable classes explained below. |
| `cg_butterfly_arithmetic.cp_sum` | 5/5 | Actual CT `a+t` is zero, below q, exactly q, above q, or maximum `2q-2`; registered operands, writebacks and full output checked. |
| `cg_butterfly_arithmetic.cp_sub` | 5/5 | Actual CT `a-t` is minimum `-(q-1)`, other negative, zero, other positive or maximum `q-1`; same passing-job gate. |
| `cg_scaling` | 3/3 | Zero, even nonzero and odd values at inverse scaling inputs; independent modular half comparison. |
| `cg_pre_lookup` | 27/27 | Nine signed values `-4..4` x first/middle/last input position; full output correctness required. |
| `cg_pwm_schedule` | 64/64 | Every PWM word issued and returned exactly once; 512 accepted input coefficients checked. |
| `cg_flow.cp_input_gap` | 16/16 | Four modes x no gap/first region/middle/last region. |
| `cg_flow.cp_output_stall` | 16/16 | Four modes x no stall/first beat/middle beat/last beat; stalled data/last remain stable. |
| `cg_flow.cp_pwm_boundary_gap` | 1/1 | Gap between operand A and B in a passing PWM job. |

The original 118-job subset is 53 standard cases + 13 bounded Pre cases + four unlike jobs
without reset + four gap/stall jobs + nine reset/recovery scenarios + 32 jobs
forming 16 bounded-random general/Pre pairs (eight eta-2, eight eta-4) +
one directed arithmetic-boundary NTT job + one product/carry-boundary PWM job +
one inverse GS-sum boundary job.
Every paired output also matches the independent SV oracle. Only a checked
second output credits `cg_pre_equivalence`.

Gap regions are classified from accepted
input count modulo 256: first `<16`, last `>=240`, otherwise middle.
The flow jobs insert two idle input clocks periodically in both PWM operands,
three clocks at the A/B boundary, and two-clock stalls on output beats 0,128,
and 255. Coverage encodings and legal denominators are commented in
`ntt_coverage.sv`; `ntt_lighthd_coverage.rpt` lists individual bin hit counts.

### Arithmetic boundary evidence

`ntt_arithmetic_boundary_seq` plants ten first-stage pairs in one full NTT
polynomial. It sets `b = t * inverse(twiddle) mod q`, using the independent
reference helpers, so the real butterfly product must be the chosen `t`.
The chosen pairs force raw sums 0, q-1, q, q+1, 2q-2, 1, 2 and 3, all
three subtraction signs, and exact subtraction extrema `-(q-1)` and `q-1`. This directly exercises the optimized final adder.

`ntt_routing_trace.note_ct_arithmetic()` computes these classes from actual
observed registered operands and twiddle, after the operand checker passes.
The class masks reach `cg_butterfly_arithmetic` only after all expected FIFO
writebacks, physical writes, output coefficients and framing pass. The named
job additionally requires all five sum and five subtraction classes; its
passing transcript prints `CHECKED_ARITHMETIC_BOUNDARIES`.

The main report's five sum-bin counts are 23/71/3/67/1, and subtraction counts
are 1/68/23/70/16 (minimum/other negative/zero/other positive/maximum). These count passing jobs that encountered each class, not the
number of butterfly operations. The separate UVM gate self-test poisons failed
jobs' arithmetic masks with every class and confirms neither checked-job count
nor arithmetic coverage can increase (`coverage_gate_write_mux.log`,
`UVM COVERAGE GATE PASS`). Its deliberate failures are not merged into the main
regression. This establishes the exercised boundaries, not exhaustive arithmetic
verification of all coefficient combinations.

### Product/carry boundary evidence

`ntt_reduction_boundary_seq` sends one ordinary PWM job through the MAIN UVM
agent. Each pair below occupies four consecutive coefficient positions, so
all four physical multiplier lanes process it. Expected results are calculated
by the unchanged `ntt_ref_pkg.pwm()`; they are not loaded from DUT arithmetic.

| Operand A | Operand B | Golden and observed result | Starting coefficient index |
|---:|---:|---:|---:|
| 0 | 0 | 0 | 0 |
| 8,380,416 | 8,380,416 | 1 | 4 |
| 4,643,571 | 5,678,082 | 1 | 8 |
| 7,083,480 | 6,206,081 | 10,000 | 12 |
| 6,777,144 | 6,489,384 | 30,000 | 16 |

The independent routing model checks accepted A/B values, registered multiplier
operands, expected FIFO writebacks and physical writes. The scoreboard checks
all 256 accepted outputs and framing before printing
`CHECKED_REDUCTION_BOUNDARIES`: `0/1/1/10000/30000`. This is a directed
correctness witness, not an added covergroup or an invented coverage percentage.
The same fourteen checked covergroup types remain 100%.

These operands exposed final-reduction and carry cases in the collapsed-stage
experiment. That trial passed functionality but fitted at 123.38 MHz / 2,671
ALMs, so it is saved and not selected. The active multiplier uses the rebalanced four-stage fold pipeline
described below. The useful PWM job remains in the main regression;
`uvm_keep_bias.log` verifies it on the latest selected RTL too.

The separate `ntt_pre_invalid_alias_test` sends +8 and must reach the exact
DUT `Pre-NTT requires every coefficient in [-4,4]` fatal before any passing job.
`pre_invalid_alias_selected_restore.log` verifies this on selected RTL. The
value also tested a key alias in the rejected narrow decoder. This is a
simulation eligibility check, not synthesized hardware rejection logic.
Its expected failure UCDB is never merged into the passing coverage.

### Why the parallel subtraction returns the required value

For canonical coefficients `0 <= a,b < q`, raw `a-b` is between `-(q-1)`
and `q-1`. A 24-bit unsigned subtraction wraps a negative value by `2^24`,
so its bit 23 is one exactly when `a<b`; a nonnegative result has bit 23 zero.
The other candidate is `a+~b+(q+1)`, using a **24-bit** complement.
Since `~b=2^24-1-b`, the sum is `a-b+q+2^24`; retaining 24 bits yields
`a-b+q`, whose exact range is `[1,2q-1]` and fits that width.
The selected butterfly now includes the two's-complement +1 in constant q+1
before carry-save compression. The final adder combines the save word and
shifted carry word, whose bit zero remains zero. The preceding implementation
compressed q and injected +1 in that carry bit; the unchanged Pre helper still
uses that equivalent form. No register or pipeline stage was added.

On borrow, `a-b+q` lies in `[1,q-1]` and is selected. Without borrow, the raw
result lies in `[0,q-1]` and is selected. Both candidates are computed in the
same clock; no extra pipeline stage is needed. The butterfly helper serves
forward CT final subtraction and inverse GS input subtraction. The same
identity is used by the current Pre first-stage subtraction.

The directed real CT pairs `(a,t)=(0,q-1)` and `(q-1,0)` require returned
differences 1 and q-1. Zero and both interior signs are also covered. A wrong
borrow selection would fail their immediate expected writebacks and/or the
full independent golden output comparison, preventing functional bin credit.
Study `butterfly_unit.msub()`, then `ntt_arithmetic_boundary_seq`,
`ntt_routing_trace.note_ct_arithmetic()` and `ntt_scoreboard.checked_ap` wiring in `ntt_env.sv`.

### FIFO occupancy exclusions

Passing UVM jobs observe FIFO1/FIFO2 peaks of 32/32 for every transform mode;
standard NTT/INTT FIFO3 peaks at 11/16, Pre FIFO3 reaches 16/16, and PWM FIFO3
remains empty. Thus:

- Standard NTT/INTT FIFO3-full: two excluded bins. The exhaustive fixed
  `PIPE=10` schedule in `sim/ntt_LightHD/fifo_schedule.py` proves peak 11.
  Legal input gaps delay loading; output stalls delay reads from FIFO1/2.
  Neither can create additional FIFO3 pushes. The trace enforces the bound.
- PWM FIFO3 partial/full: two excluded bins. PWM uses only FIFO1/2.

These are explicit `ignore_bins` in `cg_fifo`. Revisit them if controller
routing or pipeline latency changes. The earlier directed Pre FIFO2 peak of
31 was a monitor sampling gap; observing the settled final count corrected it
to 32 without changing RTL.

## Coefficient routing: what the new check establishes

`ntt_routing_trace.sv` is a UVM per-job observation object owned by `ntt_trace`.
It has **no covergroups**. It records accepted input data and gives each
coefficient an independent logical index, 0..255. These IDs exist only in the
checker; there are no hardware coefficient tags added to RTL.

At the first compute issue it builds three reference FIFO queues from the
captured polynomial. In Pre mode it independently calculates the stage-0
butterflies and initial regrouping. It compares every loaded logical word
with the actual FIFO memory at the observed head. During computation it:

1. Derives source/destination queues from transform length and issue groups,
   rather than copying the RTL decoder's bit expressions. It checks the
   actual source/destination selections, FIFO counts and pointer progression.
2. Pops the model words before same-clock writes, matching the synchronous
   RAM contract. For a stage with length `L`, every lower coefficient ID must
   pair with `ID+L` in the same `2L` group. Exactly 128 distinct lower IDs
   must occur once. For example, forward stage 0 pairs `(0,128)` through
   `(127,255)`; the last stage pairs `(0,1)`, `(2,3)`, etc.
3. Independently derives twiddles from those pair IDs and calculates CT/GS
   results using the unchanged reference arithmetic helpers. It checks the
   actual registered butterfly input data, twiddle and mode two clocks after
   the issue. Values for future stages are computed by the model, never
   copied from DUT results.
4. Delays expected output words by ten clocks. It checks the actual FIFO
   push mask and packed writeback value, checks the resulting physical memory
   location on the next clock, and requires all 256 destination IDs exactly
   once in each active stage. Forward/inverse cover eight stages; Pre covers
   stages 1..7 here (stage 0 is checked during initial-content validation).
5. Checks PWM coefficient/B-operand indexing and all 256 sequential output
   read addresses and accepted output values. Gaps and output stalls remain
   supported; queue state changes only on observed legal transfer events.

`ntt_trace.valid_job` now also requires this routing object's complete check
to pass. Its bitmaps can reach `cg_coefficient_routing` only through the
scoreboard's checked port after the final golden output/framing pass.
The pair-bin ordinal is `(ID/(2L))*L + ID%L`, 0..127. Counts are:

- Pairs: `(8+8+7)*128 = 2,944`.
- Transform destinations: `(8+8+7)*256 = 5,888`.
- PWM index bins: 256 (input-index and return-index checks both required).
- Ordered output bins: `4*256 = 1,024`.

A passing standard job checks 1,024 pairs and 2,048 destinations; a Pre job
checks 896 pairs and 1,792 destinations; PWM checks 256 IDs/destinations.
The current 116 passing jobs close all these bins. This is a simulation
routing check over the exercised controller schedule and test data, not a
formal proof for every possible data pattern. Identical coefficient values
can mask data swaps in a constant-input case; random and distinct ramp
inputs, the actual source/pointer checks, and final golden comparisons
provide additional evidence.

### Routing checker rejection tests

`run_uvm.do` with `NTT_TEST ntt_routing_operand_fault_test` or `ntt_routing_writeback_fault_test` runs separate UVM tests that deliberately flip one
**observation bit inside the checker**, leaving the actual RTL and expected
polynomial unchanged. One test corrupts a registered butterfly operand
observation; the other corrupts a FIFO writeback observation. Each detects
exactly one routing error, the scoreboard rejects the trace, and checked job
count/checked routing coverage stay at zero even though all real DUT output
coefficients match the golden result. `routing_operand_gate.log` and
`routing_writeback_gate.log` contain **`UVM ROUTING CHECKER PASS`**.
The two expected errors per test (routing plus scoreboard rejection) are
caught only in these isolated self-tests; normal errors are not suppressed.
Their intentionally failed polynomial job and UCDB are not merged into the
116 passing jobs or main coverage report.

## Observed reset/cancellation and recovery

`ntt_reset_seq` requests nine scenarios: idle, A input load, computation,
stalled output, run-start, PWM B input load, output prefetch, Pre drain and
pipeline drain. The driver prepares an earlier polynomial and asserts reset
at the requested phase. The monitor observes the actual wrapper/core state
on the reset edge and checks the accepted input count (17 for partial A,
273 for partial PWM B). It then checks settled controls, all FIFO counts and
all pending valid tags during reset and for three quiet clocks after release.

The driver next sends a different complete polynomial with **no additional
reset**. Only after that job's 256 outputs, framing and internal trace pass
does the scoreboard allow the observed reset-point bin to sample. The nine
`RESET_OBSERVED` lines and corresponding `[PASS] RESET recovery...` lines in
`uvm_stage4.log` are the witnesses. These nine scenarios do not claim all
operation x reset-time combinations or every possible reset pulse width.

## Pre eligibility negative tests

Separate UVM tests in `ntt_tests.sv`, launched by `run_uvm.do` with `NTT_TEST ntt_pre_invalid_first_test`, `ntt_pre_invalid_middle_test`, or `ntt_pre_invalid_last_test`,
send +5 at index 0, -5 (residue `q-5`) at index 128, and +5 at index 255.
Each of `eligibility_first.log`, `eligibility_middle.log` and
`eligibility_last.log` contains the exact DUT diagnostic:
`Fatal: Pre-NTT requires every coefficient in [-4,4]`.
A generic failure or timeout would not establish this result. These expected
illegal runs are not passing polynomial jobs and their coverage is not merged
into the main UCDB. The RTL guard is simulation-only: hardware still requires
the sampler/controller to guarantee eligible inputs or implement rejection.

## Failed-job coverage gate proof

`run_uvm.do` with `NTT_TEST ntt_coverage_gate_test` runs a separate UVM checker self-test with one real
passing job and seven rejected observations. The current expansion additionally
checks forged gap/stall maxima; the earlier five-fault results below are retained
historical evidence. See the expansion section above for current counts and log.
Its UCDB is never merged with the normal regression.

## Main UVM DUT code coverage

`run_uvm.do` compiles only RTL with `+cover=sbceft`, covering statements,
branches, conditions, expressions, FSMs and toggles. Testbench, golden model
and UVM library are outside the code coverage denominator.
Artifacts: `ntt_lighthd_cov.ucdb` and `ntt_lighthd_coverage.rpt` under
`sim/ntt_LightHD/`. The main script includes code coverage directly; no separate code coverage launcher is needed.

| DUT instance (excluding child instances) | Statement | Branch | Condition | Expression | FSM states | FSM transitions | Toggle |
|---|---:|---:|---:|---:|---:|---:|---:|
| FIFO core `/tb_top/dut/u_core` | 300/312 | 234/247 | 49/78 | 55/58 | 5/5 | 9/9 | 3409/3689 |
| Serial wrapper `/tb_top/dut` | 50/51 | 38/39 | 7/7 | 1/1 | 8/8 | 15/15 | 298/302 |
| Each butterfly | 55/55 | 17/17 | - | - | - | - | 704/704 |
| Each modular multiplier | 45/45 | 12/12 | - | - | - | - | 1228/1418 |

These are raw tool counts, without code exclusions or a merge from directed
benches. **All extracted core and wrapper FSM states/transitions now close in
UVM.** Remaining statement/branch/condition holes need separate explanations;
FSM closure alone is not full code coverage.

### Code-hole review (no code exclusions applied)

| Uncovered item | Source explanation / next action |
|---|---|
| Wrapper/core FSM `default` recovery | Normal reset/start cannot enter an invalid encoding; separate fault injection would be needed to verify recovery. |
| Core `pre_mul` default and Pre eligibility `$fatal` | Separate first/middle/last and +8 illegal UVM runs trigger eligibility rejection; their coverage stays outside the passing regression. |
| Core FIFO underflow/overflow `$fatal` guards | Reaching these guards would be a controller/protocol failure. Maintain assertions; do not inflate passing coverage with illegal traffic. |
| Core FIFO3 B write route | `dest_b` is only FIFO1/2; FIFO3 receives A or Pre sum. Its unused B branch/conditions remain in raw counts. The former source_a_q word mux is removed. |
| Registered FIFO3 B select `return_use_b_q[2]` | Always zero for legal routes: B targets FIFO1/2, FIFO3 receives A. Two new constant toggle misses remain; no exclusion. |
| Core three untoggled scalar nodes | `source_a[1]`, `dest_b[1]` and `load_dest[1]` stay zero. Their six toggle bins remain in the raw denominator. Unused registered source copies are removed. |
| Packed selector arrays | 136 constant-zero bits across combinational/registered masks produce 272 missed bins. All 28 variable selectors toggle both ways in both copies (112 hits). See exact arithmetic below; no exclusions. |
| Wrapper `rx_idx[8]`, `tx_idx[8]` | Counters reset/wrap at accepted index 255; four constant toggle bins remain. |
| Packing case implicit default | All four known two-bit lane codes are checked. X/Z index behavior would need fault injection; implicit default stays in raw counts. |
| Inverse twiddle selection | All ROM entries are nonzero; zero guard removed earlier. Remaining mode/PWM terms are correlated because INTT never issues PWM tags. Independent checks still verify actual twiddles. |
| Correlated route alternatives | `dest_b == 1` follows rejection of FIFO1 and only two B routes are legal. Correlated FIFO read/pop cases remain under review; no blanket waiver. |
| Defensive-assertion conditions | 21 missed terms are in illegal Pre-input and FIFO-failure guards. Separate Pre expected-failure coverage stays separate. |
| Write-source exclusivity guard | Load, Pre and compute writes occupy disjoint phases. Four condition terms and fatal branch stay unhit by legal traffic; no separate overlap fault-injection result is claimed. |
| Core `done_o = (state == DONE)` | Raw expression report is 0/1 although FSM DONE has 120 hits and completed transactions pass. Keep the miss visible pending tool-attribution investigation; no exclusion or unreachable-state claim. |

Each multiplier now covers **45/45 statements, 12/12 branches** and
**1,228/1,418 raw toggle bins**. The new first-fold compression registers add
reset branches, both hit by main UVM. Final correction still selects from a
single carry bit. Source changes alter denominators; no new functional
covergroup percentage is invented.

The **190 missed toggle bins** are both directions on 95 constant bits:

| Node | Constant bits | Value | Bit count |
|---|---|---:|---:|
| `s2_carry` | 0 | 1 | 1 |
| `s2_shift` | 0..12 | 0 | 13 |
| `s2_low` | 23..35 | 0 | 13 |
| `s2_neg` | 23..35 | 1 | 13 |
| `s3_t2` | 27..37 | 0 | 11 |
| `s4_bias_carry` | 0 | 0 | 1 |
| `s4_carry` | 0 | 0 | 1 |
| `s4_high_shift` | 0..12 and 17..23 | 0 | 20 |
| `s4_low` | 23 | 0 | 1 |
| `s4_neg_high` | 4..23 | 1 | 20 |
| `s4_save` | 23 | 1 | 1 |

For all unsigned 23-bit operands, `product <= (2^23-1)^2`. The conservative
bound `U_next=floor(U/2^23)*8191+(2^23-1)` gives successive fold limits
68,719,460,353 (36 bits), 75,481,088 (27 bits), and 8,454,135 (24 bits).
These bounds justify 36-bit first-fold carry-save addition modulo 2^36 and
27-bit fold2 storage. Complementing hi introduces its -1; fixing carry bit0
to one supplies the two's-complement +1. The first fold is nonnegative and
fits 36 bits, so its modulo result is the exact value. Other constant rows
follow from zero padding, shift bit0, high complement bits and
`0 XOR 0 XOR 1 = 1` for s4_save[23].
Thus `2*(1+13+13+13+11+1+1+20+1+20+1)=190`. No exclusions.

### Why the rebalanced final stage returns the required value

Let `H=t2_q>>23` and `L=t2_q[22:0]`. The fold is
`T=L+(H<<13)-H`, preserving the residue because `2^23=8191 mod q`.
The bound above gives `H<=8` and `T<=8,454,135<2q`.
Therefore the canonical answer is T if T<q, otherwise T-q.

The raw and biased candidates are computed in parallel: T and T+8191.
Since `T+8191<2^24`, bit 23 of the biased candidate is one exactly when
`T>=2^23-8191=q`. Its low 23 bits then equal T-q. If the bit is zero,
select raw T. Carry-save compression combines L, H shifted by 13, and ~H;
the missing +1 for -H occupies the shifted carry word's zero bit. A second
compressor introduces the bias before a single carry propagation. All arithmetic
is modulo 2^24 internally, and the bounds above guarantee the exact nonnegative
T and T+8191 fit that width.

The five registered stages are now product / first-fold compression /
first-fold carry propagation / fold2 / fold3+canonical correction. The former
fourth fold is unnecessary because fold3 is below 2q. Latency is five clocks;
all four lane outputs, physical writes and full jobs are checked by main UVM. The product/carry witness above remains part of that run.
This bound and the exercised tests do not claim exhaustive RTL equivalence.

## Supporting checks and remaining Stage 4 work

Historical directed checks passed core 39/39, engine 55/55, and 1,312
multiplier inputs plus 1,312 butterfly pairs. Those redundant benches and their
launchers were removed on 2026-10-09 after the main UVM environment acquired
end-to-end output, internal operand/routing, reset and flow checks. They are
not current regression or coverage commands. The main UVM report independently
hits core FSM transitions 9/9 and wrapper transitions 15/15.

The standalone independent Python comparison passes 18/18 cases and
4,608/4,608 coefficients. It remains a separate output-file flow described in
`FIPS204_NTT.md`; these are FIPS 204-derived reference cases, not NIST-published
NTT vectors. None of these directed results is used to claim a UVM bin hit.

Remaining priorities: the hardware-side Pre eligibility integration contract,
expanded combinations of stalls/resets, remaining condition/expression review,
and fitted timing/performance improvement. Coefficient pair/destination checking
is now implemented in the main UVM simulation as described above. The implemented flow positions are complete; all possible
stall durations/combinations are not claimed. Timing closure and user review
remain required. No post-synthesis, post-fit, or FPGA coverage is claimed.
See `NTT_VERIFICATION_TESTPLAN.md` for the full Stage 4 exit gate.

## Run and study

From `sim/` in Questa:

```tcl
do ntt_LightHD/run_uvm.do
```

For the separate coverage gate proof:

```tcl
set NTT_TEST ntt_coverage_gate_test; do ntt_LightHD/run_uvm.do
```

Study in this order: `ntt_sequence.sv` -> `ntt_driver.sv` -> `ntt_monitor.sv`
(and `ntt_trace.sv` / `ntt_routing_trace.sv`) -> `ntt_scoreboard.sv` -> `ntt_coverage.sv` -> `ntt_env.sv`
-> `tb_top.sv` -> the corresponding RTL. Search the transcript for a job's
`CHECKED_TRACE` and `[PASS]` lines, then look up its bin in the detailed report.
Generated reports/logs/UCDBs are ignored by Git and reproducible.

## Testbench cleanup (2026-10-09)

The redundant non-UVM core/engine/arithmetic benches and their launchers have been removed. Earlier directed counts in this document are historical. The main UVM environment supplies checked functional and DUT code coverage; the separate vector-capture bench remains only for Python comparison.

## Earlier pipeline-rebalance checkpoint (2026-10-09)

The earlier main UVM run was `uvm_balanced.log`:
115/115 passing jobs, zero UVM errors/fatals, all thirteen implemented checked
functional covergroup types 100%. The independent Python run compares all
4,608 coefficients across 18 cases successfully. Golden-model mathematics
are unchanged. Butterfly latency remains six clocks and internal return tags
remain aligned to nine clocks; observed core and wrapper cycle counts are unchanged.

The raw inverse sum moved to the existing butterfly input register; the
multiplier now uses stages product / fold 1 / folds 2+3 / fold 4+reduction.
Fresh map/fit/STA and both slow critical-path reports show 2,937 ALMs,
2,017 registers, 6 DSPs, 20 M10Ks, 101.28 MHz worst-corner Fmax,
-4.874 ns worst setup and +0.121 ns worst hold at the unchanged 5 ns constraint.
Setup and minimum pulse-width constraints still fail. See the plan's comparison
table and `quartus/ntt_LightHD/results/` for evidence; Stage 4 is not closed.

## Earlier carry-save/fixed-packing checkpoint (2026-10-09)

`uvm_fixed_load.log` (also copied to `uvm_stage4.log`) passes 115/115 jobs,
zero UVM errors/fatals, all thirteen implemented checked functional covergroup
types 100%. Separate Python comparison passes 18/18 cases and 4,608/4,608
coefficients. Actual cycles remain 266/266/74/235 core and 780/780/844/749 wrapper.
That main UVM report recorded
28/28 multiplier statements and 256/268 core statements, 204/217 core branches.
No raw code exclusions or directed-test coverage merge have been applied.

That checkpoint fit is 2,777 ALMs, 2,058 registers, 5 DSPs, 20 M10Ks,
114.26 MHz worst-corner Fmax, -3.752 ns worst setup and +0.079 ns worst hold.
Setup and minimum pulse-width constraints still fail at 5 ns. This is a verified
improvement, not Stage 4 closure. Its next timing target was the butterfly delay-RAM
output through final modular addition; see the plan and project results.

## Earlier retained arithmetic result (2026-10-09)

`uvm_final_fold.log` (also `uvm_stage4.log`) passes 116/116, zero errors/fatals,
all fourteen checked covergroup types 100%. The arithmetic-boundary witness
and the exact raw code counts above come from this main run. The separate
`coverage_gate_final_fold.log` confirms five failed jobs cannot credit these
bins. Python compares 18/18 cases and 4,608/4,608 coefficients successfully.
No golden model changes, code exclusions or directed-test coverage merges.

Fresh map/fit/STA/critical paths: 2,717 ALMs, 2,078 registers, 5 DSPs, 20 M10Ks,
129.08 MHz worst-corner Fmax (130.79 MHz at slow 85 C), -2.747 ns worst setup
and +0.154 ns worst hold. Core/wrapper cycles are unchanged. Timing at 5 ns
still fails setup and minimum pulse width; Stage 4 is open. The next path is
the butterfly operand-delay RAM through final CT subtraction. See the plan
for the arithmetic identity, saved checkpoints and exact comparison table.

## Earlier selected subtraction/FIFO source run (2026-10-09)

Main `uvm_write_mux.log` / `uvm_stage4.log`: 116/116, zero errors/fatals,
fourteen implemented checked functional covergroups 100%, ten arithmetic bins.
The raw source counts above reflect this run. The separate
`coverage_gate_write_mux.log` rejects five corrupted jobs without credit;
`routing_writeback_write_mux.log` rejects a corrupted observed FIFO writeback
while real outputs remain correct. Their coverage is not merged into main UVM.
Python compares 18/18 cases and 4,608/4,608 coefficients successfully.

Parallel butterfly/Pre subtraction and independent FIFO data selection preserve
all legal write enables, destinations, values and physical memory updates.
Unused RAM data is not forced to zero. The UVM routing model checks actual
writes; a runtime assertion checks that load/Pre/compute sources never overlap.
All fourteen groups remain closed, but this is not full raw code coverage.

Fresh selected fit: 2,428 ALMs, 2,022 registers, 5 DSPs, 20 M10Ks, 131.22 MHz
worst-corner Fmax, -2.621 ns worst setup and +0.129 ns worst hold. The 200 MHz
setup and pulse-width targets still fail; Stage 4 remains open. The next paths
are Pre lookup at slow 85 C and multiplier folds 2/3 at slow 0 C. See the plan
for both rejected trials, saved checkpoints and the exact comparison table.

## Earlier restored source verification (2026-10-09)

Both timing trials were rejected and the six active RTL files restored exactly
from `lighthd_write_mux_checkpoint`. Main UVM now passes 117/117 with zero
errors/fatals, 117 trace/routing witnesses, fourteen checked covergroup types
100% and 10/10 CT arithmetic bins. The added PWM product/carry case is described
above. Core/wrapper raw counts remained unchanged; the multiplier at that point was
28/28 statements and 622/676 toggles. There were no exclusions.

Current logs: `uvm_selected_restore.log` (also `uvm_stage4.log`),
`vector_selected_restore.log`, `compare_selected_restore.log` and
`pre_invalid_alias_selected_restore.log`. Python passes 18/18 cases and
4,608/4,608 coefficients. Previous negative coverage-credit/writeback checks
still apply to the same restored RTL; their deliberately failing UCDBs stay
separate. Trial source/reports are preserved under `experiments/ntt_stage4/`.
See the plan for measured timing selection. Stage 4 remains open.

## Earlier selected multiplier rebalance (2026-10-09)

`uvm_final_rebalance.log` (also `uvm_stage4.log`) passes **117/117**, zero
errors/fatals, with fourteen checked functional covergroup types 100%, 117
trace/routing witnesses and the all-lane product/carry witness. Raw code counts
above are from this run; core/wrapper/butterfly counts remain unchanged.
The lower multiplier toggle percentage reflects additional constant wires,
not ignored bins; the table and arithmetic above account for every miss.

`coverage_gate_final_rebalance.log` records rejection of five deliberate
failures without credit. `routing_writeback_final_rebalance.log` detects an
incorrect observed FIFO write while real outputs are correct and checked_jobs=0.
Their expected-failure coverage is not merged. Python passes 18/18 cases and
4,608/4,608 coefficients in `compare_final_rebalance.log`.

Fresh selected implementation: **134.50 MHz worst Fmax, 2,487 ALMs, 2,081
registers, 5 DSPs, 20 M10Ks**, worst setup -2.435 ns and hold +0.172 ns.
Stage 4 remains open: 200 MHz setup and minimum pulse width still fail.
Selected source/reports are saved in `lighthd_final_rebalance_checkpoint`;
the 131.22 MHz checkpoint remains available. See the plan for the comparison.

## Earlier selected q+1 subtraction (2026-10-09)

`uvm_sub_qplus1.log` (also `uvm_stage4.log`) passes **117/117**, zero UVM
errors/fatals, fourteen checked functional covergroup types 100%, 117 trace/
routing witnesses, all ten CT arithmetic bins and the observed product/carry
witness. Raw code counts in the current table are unchanged. Every butterfly
has 54/54 statements, 17/17 branches, 1/1 condition and 656/656 toggles.
No code exclusions or expected-failure coverage merges were applied.

`vector_sub_qplus1.log` and `compare_sub_qplus1.log` pass **18/18 cases,
4,608/4,608 coefficients**, with unchanged mode cycle counts. The checker code
and latency contracts are unchanged; the preceding checkpoint preserves its
separate negative coverage-credit/writeback sensitivity runs. They are not
newly rerun or merged as part of this arithmetic-only trial.

Fresh selected fit: **137.04 MHz worst Fmax, 2,451 ALMs, 2,071 registers,
5 DSPs, 20 M10Ks**. Worst setup/hold/pulse slacks at 5 ns are
**-2.297/+0.169/-0.555 ns**. Slow85 Fmax falls from 139.30 to 139.06 MHz, while
slow0 improves from 134.50 to 137.04 MHz; selection uses the worst corner.
Stage 4 remains open and the next worst path is twiddle ROM -> `bf_zi_q`.
Exact RTL and evidence are in `lighthd_sub_qplus1_checkpoint`.

## Earlier selected twiddle-guard removal (2026-10-10)

`uvm_tw_nonzero.log` (also `uvm_stage4.log`) passes **117/117**, zero UVM
errors/fatals, fourteen checked functional covergroup types 100%, 117 checked
trace/routing witnesses and the unchanged CT/product boundary witnesses.
Only the known-nonzero inverse twiddle guard was removed. The independent
checker still checks actual registered twiddle values, FIFO writes and outputs.
Raw core conditions change **64/103 -> 64/102** by removing one redundant
condition; hit count stays 64. Other raw table counts are unchanged.
No exclusions, oracle changes or failed-UCDB merges.

Fresh separate `coverage_gate_tw_nonzero.log` rejects five corrupted jobs
without coverage credit; `routing_writeback_tw_nonzero.log` detects corrupted
observed FIFO writeback while real outputs remain correct and checked_jobs=0.
`pre_invalid_alias_tw_nonzero.log` reaches the intended illegal +8 Pre-input
fatal. These expected-failure runs are not merged into passing coverage.
Python `compare_tw_nonzero.log` passes **18/18 cases, 4,608/4,608 coefficients**.

Fresh fit: **140.69 MHz worst Fmax, 2,427 ALMs, 2,123 registers, 5 DSPs,
20 M10Ks**. Worst setup/hold/pulse slacks: **-2.108/+0.086/-0.555 ns** at 5 ns.
Previous 137.04 MHz checkpoint remains saved; current exact source/evidence is
in `lighthd_tw_nonzero_checkpoint`. The worst path moves to FIFO read/operand
selection. Stage 4 remains open; 200 MHz setup/pulse timing still fails.

## Earlier selected operand-selector rewrite (2026-10-10)

`uvm_operand_boolean.log` (also `uvm_stage4.log`) passes **117/117**, zero UVM
errors/fatals, fourteen checked covergroup types 100%, 117 trace/routing
witnesses and the unchanged arithmetic/product witnesses. Combined FIFO and
coefficient selectors are decoded at read launch and registered with the
FIFO outputs; data goes through a masked OR instead of serial word/lane muxes.
No latency changes and no oracle changes. The independent checker still
checks real registered operands, expected/physical writes and every output.

The current raw table is from this run. Source restructuring changes counts;
it is not a blanket improvement in exercised conditions. The packed masks are
instrumented, including constant bits. Reachable A selectors by lane are
**2/3/3/4 (12)**; B selectors **5/4/4/3 (16)**. For p>=2 the same lane index
is selected from the decoded source FIFO. For p=1/0 the fixed half/adjacent
permutations use FIFO1/FIFO2; PWM uses FIFO1/FIFO2 and A=0. Thus 28 selectors
can vary, and both their combinational and registered copies toggle both ways:
`28*2*2=112 hits`. The four 48-bit masks contain 192 bits; the other 136 bits
stay zero: `136*2=272 misses`. Three scalar constant nodes contribute six
more: **272+6=278 missed core toggle bins**, all retained without exclusions.

The rejected unpacked trial omitted mask bits from the toggle denominator
and reported 3293/3301. Removing unused source registers removes eight bins
and six hits; adding packed masks adds 384 bins and 112 hits:
`3293-6+112=3399`, `3301-8+384=3677`. The lower raw percentage reflects
newly instrumented constant bits, not lost functional route coverage.

Fresh separate `coverage_gate_operand_boolean.log` rejects five deliberately
bad jobs without credit. `routing_operand_operand_boolean.log` and
`routing_writeback_operand_boolean.log` detect corrupt observations despite
correct final outputs, checked_jobs=0. Their failed UCDBs are not merged.
The unchanged Pre guard's earlier exact-fatal evidence remains saved; not
newly rerun here. Python passes **18/18 cases, 4,608/4,608 coefficients**.

Fresh fit: **145.18 MHz worst Fmax, 2,592 ALMs, 2,152 registers, 5 DSPs,
21 M10Ks**; setup/hold/pulse **-1.888/+0.168/-0.555 ns** at 5 ns.
This is 3.19% faster for 165 more ALMs, 29 registers and one extra M10K than
saved140.69MHz. Both options remain saved. Stage 4 remains open; 200 MHz timing
still fails. Exact selected source/evidence: `lighthd_operand_boolean_checkpoint`.

## Latest selected inverse kept-sum carry reduction (2026-10-10)

Main `uvm_keep_bias.log` / `uvm_stage4.log`: **118/118**, zero UVM errors/fatals,
fourteen checked covergroup types100%,118trace/routing witnesses. The added
inverse job does not create a new covergroup percentage. Its five raw GS sums
are checked on every physical butterfly lane before any scoreboard publication.

| Actual GS operand A | Operand B | Raw sum | Canonical GS sum |
|---:|---:|---:|---:|
| 0 | 0 | 0 | 0 |
| 0 | q-1 | q-1 | q-1 |
| 1 | q-1 | q | 0 |
| 2 | q-1 | q+1 | 1 |
| q-1 | q-1 | 2q-2 | q-2 |

`ntt_inverse_sum_boundary_seq` places these adjacent pairs at indices
8*c+2*lane /8*c+2*lane+1 for class c0..4 and lane0..3. The unchanged inverse
oracle calculates all256expected outputs. `ntt_routing_trace.note_gs_sum()`
classifies actual registered operands with integer addition, after the
independent operand checker. `ntt_scoreboard.compare_tx()` requires each lane's
mask11111, correct expected/physical writes, output framing and every output.
Only then does `CHECKED_GS_SUM_BOUNDARIES` print11111/11111/11111/11111 and
`checked_ap` publish the job. The stage-by-stage inverse halves remain checked.

For S in[0,2q-2], B=S+8191 fits24bits; B[23] is1 iffS>=q. On that branch,
B[22:0]=S-q; otherwise S[22:0]=S. The optimized helper uses this carry bit
instead of a separate comparator. No pipeline change. All five thresholds
above are exercised on every GS lane, and full golden results pass.
Each BF now55/55statements,17/17branches,704/704toggles. Its old logical
comparator condition is removed; single carry-bit selection has no condition
bin. The added24-bit wire contributes48hit toggles. No exclusions.
Core/wrapper/multiplier raw counts stay unchanged; current table reflects this.

`ntt_gs_sum_gate_test`, separate from main, runs a real passing boundary job,
then clears only lane2's exact-q mask bit while retaining correct real outputs.
The scoreboard rejects the missing witness and checked_jobs stays1:
`UVM GS SUM GATE PASS` in `gs_sum_gate_keep_bias.log`. The existing five-fault
credit gate also passes freshly (`coverage_gate_keep_bias.log`). Their failed
UCDBs are never merged. This demonstrates that output correctness alone cannot
satisfy this boundary witness. Main remains118passing jobs, not these failures.

Fresh fit145.73MHz/2568ALMs/2117registers/5DSP/21M10K; worstsetup/hold/pulse
**-1.862/+0.104/-0.555ns** at5ns. Python18/18cases,4608/4608coefficients.
Prior145.18MHz andsmaller140.69MHz checkpoints saved. Stage4 timing remains
open; no netlist/board claim. Exact source/evidence:`lighthd_keep_bias_checkpoint`.

## Route/Pre decoder trial review (2026-10-10)

Both saved trials passed 118/118 main UVM jobs, with all fourteen checked
functional covergroup types at 100%. Separate Python comparison matched all
4,608 coefficients across 18 cases. The route trial's separate operand and
physical-writeback corruption checks reject without checked coverage credit.
The narrow-key trial's separate +8 alias case triggers the exact DUT Pre
eligibility fatal; its failed UCDB is not merged. Golden models and expected
files are unchanged. Neither trial is selected for worst-corner speed.

Their core raw counts are 295/307 statements, 232/245 branches, 53/84 conditions,
51/52 expressions, 5/5 states, 9/9 transitions and 3,405/3,683 toggles. Direct
route logic changes source and denominators; the six additional hit toggle bins
come from three new scalar flags. The same 278 constant-bit misses remain.
These counts do not replace the selected RTL's raw counts above. No exclusions.

The selected keep-bias source was restored byte-for-byte. Fresh
`uvm_keep_bias_restore.log` passes 118/118, with zero errors/fatals and all
fourteen groups at 100%. The main UCDB/code report again describes that restored
source. Trial reports, UCDBs, source and logs are preserved in their individual
experiment folders.

## First-fold carry-select trial review (2026-10-10)

Both first-fold trials passed 118/118 main UVM jobs, zero errors/fatals,
all fourteen checked functional covergroup types at 100%, and 4,608/4,608
independent Python comparisons. They were rejected for fitted timing, not
functional mismatches. Their RTL and reports remain in separate experiment
folders; the selected source and its raw coverage table above are restored.

Existing `ntt_reduction_boundary_seq` drives (0,0) and (q-1,q-1) on all four
physical multiplier lanes. In the trials these produce lower-half carry one
and zero, respectively. The registered operands, physical writes and every
final output are independently checked by the main UVM environment. Golden
mathematics and expected files are unchanged.

Each trial multiplier hits 44/44 statements and 12/12 branches; 1,266/1,460
toggle bins hit. The 194 misses correspond to both directions of 97 constant
bits listed in the report. Exposing the split adds 40 constant bits over the
previous source (80 bins): one fixed carry bit, thirteen shift zeros, thirteen
zero-extension bits and thirteen complement-one bits. No exclusions. Changed
source denominators must not be compared as if they were the same code.

Fresh `uvm_fold_trials_restore.log` (also `uvm_stage4.log`) again passes
118/118 with fourteen groups at 100%. Its UCDB/code report describes the
selected restored source. The PIPE=10 index-model feasibility check in the
plan is not UVM coverage or proof of a new RTL pipeline; no pipeline change
is active and no new coverage percentage is claimed for that planning check.

## Latest selected first-fold pipeline evidence (2026-10-10)

The active multiplier/BF/return pipeline is now 5/7/10. Both independent UVM
models require ten-clock return alignment while still deriving coefficient
values, pair IDs, destinations and physical writes independently of DUT results.
All 118 jobs and fourteen checked groups pass in uvm_fold_pipeline.log.
The extra stage also passes nine reset/recovery points and complete drain checks.

Fresh separate coverage_gate_fold_pipeline.log rejects five faults without
credit. routing_operand_fold_pipeline.log and routing_writeback_fold_pipeline.log
reject corrupted observations despite correct real output, with checked_jobs=0.
gs_sum_gate_fold_pipeline.log rejects the missing GS witness without new credit.
Failed UCDBs remain separate. Earlier Pre eligibility rejection evidence is
preserved, not newly rerun; its RTL guard is unchanged.

fifo_schedule.py now enumerates PIPE=10. Current forward/inverse FIFO3 peak
remains 11/16; Pre peak is 16/16. All pair sets and output ordering pass.
This model proves index schedule/capacity, not arithmetic or clock frequency.
Raw counts above describe the selected RTL; historical counts below earlier
headings retain their earlier sources. No exclusions. Fitted setup improves to
-1.736 ns at 5 ns, but Stage 4 is still open and no netlist/FPGA result is claimed.

## Return-word retiming experiments (2026-10-10, rejected)

Both trials pass the main UVM 118/118 with fourteen checked functional groups
at 100%, zero errors/fatals, and separate Python 18/18 cases, 4,608/4,608 coefficients.
Each fresh writeback-corruption test detects the injected observation error
while real outputs remain correct and checked_jobs=0. Fault UCDBs are separate.
The SV golden model, mathematical references, TB timing models and FIFO sizes
are unchanged. Neither source-correct trial improves fitted timing; both are
rejected and the selected 148.46 MHz source is restored byte-for-byte.

| Raw core metric (hits / legal bins) | Selected/restored | Compute words trial | Compute + Pre word trial |
|---|---:|---:|---:|
| Statements | 295/307 | 306/318 | 308/320 |
| Branches | 232/245 | 232/245 | 232/245 |
| Conditions | 53/84 | 53/84 | 53/84 |
| Expressions | 51/52 | 51/52 | 51/52 |
| FSM states/transitions | 5/5,9/9 | 5/5,9/9 | 5/5,9/9 |
| Toggles | 3405/3683 | 4325/4603 | 4509/4787 |

New source adds 11/13 hit statements and 920/1,104 hit toggle bins respectively.
The latter represent 460/552 new signal bits toggled both ways. The same 278
constant-bit misses remain. This denominator change is not additional
functional feature coverage. Other DUT instance counts are unchanged; no
exclusions. Exact reports are under each trial's experiments/ntt_stage4 folder.

Fresh restored-source main UCDB/report comes from uvm_return_trials_restore.log
and again gives 118 passing jobs, all fourteen groups 100%, and the selected raw
counts above. Core/wrapper cycles stay 267/267/75/236 and 781/781/845/750.
Other unchanged negative-credit/operand/GS/Pre-eligibility evidence remains
retained and is not claimed as freshly rerun during this restoration.

## Selected early write selection and prefetch checkpoint (2026-10-10)

Latest main uvm_write_select_prefetch.log passes 118/118, zero UVM errors/fatals,
with all fourteen implemented checked functional covergroup types 100%. Main
UCDB and raw report describe this source; the primary code table above is updated.
The control-only trial also passes 118/118 but is not selected because worst
Fmax regresses. Both have300/312 core statements, 234/247 branches, 49/78 conditions,
55/58 expressions, 5/5 states, 9/9 transitions, 3409/3689 toggles. Moving decode changes
coverage categories/denominators; it does not add functional covergroup types.
The FIFO1/2 select bits each toggle both ways; FIFO3's B-select bit stays zero,
adding two constant misses to the previous 278. No exclusions.

The selected wrapper's unconditionally prepared next address changes raw
counts to 50/51 statements, 38/39 branches, 7/7 conditions, 1/1 expressions,
8/8 states, 15/15 transitions, 298/302 toggles. Enabled read addresses and read edges
are unchanged. Main UVM checks every actual output read/order and output
coefficient, plus stalled output data/last and nine reset/recovery scenarios.
Other DUT instance counts remain unchanged.

Fresh coverage_gate_write_select_prefetch.log rejects five corrupted observed
jobs without new checked credit. Fresh routing_writeback_write_select_prefetch.log
detects the observed write fault despite correct real final outputs, checked_jobs=0.
Negative UCDBs stay separate. Other unchanged operand/GS/Pre-eligibility negative
evidence remains saved, not freshly rerun. Separate Python passes 18/18 cases,
4608/4608 coefficients. Core/wrapper cycles remain 267/267/75/236 and781/781/845/750.
Full exact source and evidence: lighthd_write_select_prefetch_checkpoint under
experiments/ntt_stage4. Fitted worst Fmax 150.49 MHz and setup/hold/pulse
-1.645/+0.152/-0.555 ns at 5 ns do not close Stage 4 or establish netlist/FPGA results.

## Setup-focused delay mapping trials and restoration (2026-10-10)

Both BF delay mapping trials pass 118/118 main UVM jobs and all fourteen checked
functional covergroup types. Separate Python matches 18/18 cases and 4,608/4,608
coefficients for each. Their fitted worst setup slacks (-2.311 and -1.959 ns)
regress the selected -1.645 ns baseline, so both are rejected and preserved.
A pass in source simulation does not imply a timing improvement.

Active RTL is restored byte-for-byte from the 150.49 MHz checkpoint. Fresh
`uvm_bf_delay_restore.log` is the current main UCDB/raw-report producer;
`compare_bf_delay_restore.log` again passes all 4,608 coefficients. Raw selected
coverage counts and cycle counts are unchanged. The trial with a separate final
BF register block has different source denominators (60/60 statements, 19/19
branches, 752/752 toggles per BF); its UCDB is archived separately and is not
merged into the current restored-source database. No exclusions, golden-model
changes or TB changes. Earlier negative-checker evidence remains retained;
it was not freshly rerun for these mapping-only trials/restoration.

Exact sources and simulation evidence are in the three corresponding
`experiments/ntt_stage4/lighthd_bf_*` trial/restoration folders. The plan records
both slow-corner setup/TNS, hold, resources, Fmax and the selection decision.

## BF candidate/tag/write-mask trials and restoration (2026-10-10)

Three setup-focused trials each pass main UVM 118/118 and separate Python
18/18 cases / 4,608 coefficients. Fourteen checked functional covergroup types
remain 100%. Fitted worst setup regresses to -2.622, -1.806 and -1.967 ns;
all are rejected. A source-coverage or output-correctness pass is not a timing win.
Complete sources, UCDBs, raw reports and timing evidence remain in the three
named trial folders under `experiments/ntt_stage4/`.

The BF candidate-register trial exposes 55 constant bits (110 missed toggle
bins): raw BF 72/72 statements, 22/22 branches and 1,500/1,610 toggles. The
write-mask trial changes core source denominators: 305/317 statements,
221/233 branches, 49/78 conditions, 63/64 expressions, 3,421/3,701 toggles.
These trial reports remain separate; no coverage exclusions or merging of
incompatible source revisions. No golden-model, reference or TB changes.

All six active RTL files are restored byte-for-byte from the selected 150.49 MHz
checkpoint. Fresh `uvm_candidate_tag_restore.log` produces the current main
UCDB/raw report and passes 118/118 with zero errors/fatals. Python again passes
all 4,608 coefficients. Selected raw coverage counts and operation cycles are
unchanged. Previous negative-checker evidence remains retained, not newly rerun.
Restoration source/hashes and evidence are in
`experiments/ntt_stage4/lighthd_candidate_tag_trials_restore/`.

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
