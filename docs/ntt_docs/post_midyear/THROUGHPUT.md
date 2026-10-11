# LightHD NTT cycles and throughput

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


**Stage 4, 2026-10-10.** Cycle counts come from the standalone capture transcript
for `src/ntt_LightHD/ntt_engine.sv`. They are also checked by main UVM's observed
internal trace. A 10 ns simulation clock does not establish FPGA Fmax.

## Measured cycle boundaries

Core latency counts from the sampled `core_start` to `core_done`. Wrapper
latency counts from the accepted external start to accepted final output.
The no-stall cases keep input valid and output ready continuously.

| Operation | Issue clocks | Measured core clocks | Load + output beats | Measured wrapper clocks |
|---|---:|---:|---:|---:|
| NTT | 256 | 267 | 256 + 256 | 781 |
| INTT | 256 | 267 | 256 + 256 | 781 |
| PWM | 64 | 75 | 512 + 256 | 845 |
| Pre-NTT | 224 | 236 | 256 + 256 | 750 |

For NTT/INTT, `512 + 267 + 2 = 781`; for PWM,
`768 + 75 + 2 = 845`; for Pre, `512 + 236 + 2 = 750`.
The two additional clocks are wrapper start/read control relative to the
measured core interval. Core latency includes pipeline and controller drain;
issue clocks alone are not operation latency. Pre has its additional startup
control after first-stage lookup writeback. The actual event boundaries are
implemented in `tb_uvm/tb_uvm_ntt_LightHD/tb_ntt_vectors.sv` and printed as
`NTT_VECTOR_CORE_LATENCY` / `NTT_VECTOR_LATENCY`.

The wrapper accepts/emits at most one 23-bit coefficient per clock. Inside the
core, a transform issue handles eight coefficients (four butterflies); PWM
handles four products. A single job occupies the wrapper through loading,
computation and output; these phases do not form a pipeline across polynomials.

## Current comparison with published LightHD (2026-10-12)

Our selected design reconstructs LightHD's four-butterfly, three-FIFO structure.
It uses our own arithmetic/control implementation and a separate PWM operand
store; it is not source-identical to the authors' implementation.

### Architecture and compute cycles

| Item | Published LightHD | Current implementation |
|---|---|---|
| Polynomial parameters | n=256, q=8,380,417 | Same |
| Butterfly units | 4 | 4 |
| Reorder FIFOs | 92-bit words, depths 32/32/16 | Same |
| Supported operations | NTT, INTT, PWM, small-secret Pre-NTT | Same |
| Forward NTT | 264 clocks | 267 clocks (+3, 1.14%) |
| Inverse NTT | 264 clocks | 267 clocks (+3, 1.14%) |
| PWM | 70 clocks | 75 clocks (+5, 7.14%) |
| Eligible Pre-NTT | 235 clocks | 236 clocks (+1, 0.43%) |
| Two ordinary coefficient-domain operands: 2 NTT + PWM + INTT | 862 compute clocks | 876 compute clocks (+14, 1.62%) |
| Sampler and full accelerator integration | Implemented | Pending Stage 6 |

The two-input totals are `3*264 + 70 = 862` and `3*267 + 75 = 876`.
They exclude transfers and scheduling gaps. Pre-NTT applies only to eligible
small secret polynomials; our input contract is canonical residues of [-4,4].
The published and measured core event boundaries may differ slightly.

### Clock and resources

| Metric | Published LightHD | Current implementation |
|---|---|---|
| FPGA | Xilinx Artix-7 | Intel Cyclone V 5CGXFC7C7F23C8 |
| Reported accelerator clock / approved operating clock | 212.8 MHz | Nominal 148 MHz |
| Worst-corner fitted Fmax | Not separately identified in this comparison | 150.49 MHz |
| Logic | 2,601 LUTs, polynomial module | 2,475 ALMs, complete NTT wrapper/core |
| Registers | 2,730 FFs, polynomial module | 2,414 registers |
| DSP resources | 8 DSPs | 5 DSP blocks |
| Block memory | Polynomial module: 0 BRAM; separate full-accelerator memory: 12 BRAM | 20 M10Ks; 37,325 implemented memory bits |
| Worst setup slack | Not reported in the cited comparison table | +0.111 ns at approved operating constraint |
| Worst hold slack | Not reported in the cited comparison table | +0.152 ns at approved operating constraint |

ALMs are not interchangeable with Xilinx LUTs; DSP and RAM block capabilities
also differ. Module boundaries differ: LightHD accounts for shared memory
separately, while our fit includes the standalone wrapper and its storage.
The paper additionally reports 104 LUTs for Pre-NTT regrouping and 336 LUTs
for its lookup module. These figures do not establish an area or memory winner.
Our positive slack does not establish closure at 200 MHz; that benchmark fails.

### Clock-based compute estimates

The following arithmetic uses LightHD's reported full-accelerator clock of
212.8 MHz and our approved nominal 148 MHz. These are cross-platform estimates,
not a controlled same-device benchmark or sustained measured throughput.

| Operation | LightHD compute time | Current compute time |
|---|---:|---:|
| NTT / INTT | 264/212.8 = 1.241 us | 267/148 = 1.804 us |
| PWM | 70/212.8 = 0.329 us | 75/148 = 0.507 us |
| Pre-NTT | 235/212.8 = 1.104 us | 236/148 = 1.595 us |

Reciprocal NTT compute rates are approximately 806,061 transforms/s
(`212.8e6/264`) and 554,307 transforms/s (`148e6/267`). Both exclude loading,
output, restart gaps and sampler waiting. Our serial wrapper instead takes
781 clocks for NTT/INTT, 845 for PWM and 750 for Pre-NTT, as defined above.
Do not compare LightHD's 264 compute clocks with our 781 wrapper clocks.
A comparable published wrapper boundary has not been established here.

### Verification status and remaining limitations

Current source verification passes 748/748 UVM jobs and 191,488 compared
coefficients, with zero UVM errors/fatals. Functional coverage is 90.47%
(equal-weight type average); raw DUT code coverage is 92.17% (12,990/14,093
bins). These are different metrics, with genuine misses documented in
[COVERAGE.md](COVERAGE.md). Separate Python comparison passes 18/18 cases
and 4,608 coefficients. Distinct functional post-synthesis and post-fit
netlists each passed 117/117 jobs. These results do not establish exhaustive
correctness, board validation or integrated ML-DSA performance. No equivalent
coverage percentage for LightHD is claimed.

Compute-cycle scheduling is nearly matched; the reported clock remains higher
for LightHD. Our serial input/output and lack of overlap between polynomial
jobs dominate standalone latency. Memory utilization warrants review, the
+0.111 ns setup margin is small, and upstream logic must enforce Pre-NTT
eligibility. Sampler buffering, tagging and backpressure remain integration
work. Area superiority and full-system performance superiority are unproven.

### Sources and evidence

- [LightHD paper](../../refernce-paper-hw/2026/LightHD_A_Lightweight_and_High-Performance_Hardware_Accelerator_of_CRYSTALS-Dilithium.pdf):
  Section III polynomial architecture/cycles; Table II module resources;
  Table III full-accelerator clock and implementation results.
  DOI: [10.1109/TC.2026.3666457](https://doi.org/10.1109/TC.2026.3666457).
- Current Quartus fit/timing: `quartus/ntt_LightHD/output_files/ntt.fit.summary`,
  `ntt.sta.summary`, and `ntt.sta.rpt`; selected copies under `results/`.
- Current cycle capture: `sim/ntt_LightHD/vector.log`.
- Current UVM/code coverage: `sim/ntt_LightHD/uvm_gui.log` and
  `ntt_lighthd_coverage.rpt`; Python result: `sim/ntt_LightHD/compare.log`.
- Measurement definitions and interface details: [SPECIFICATION.md](SPECIFICATION.md).

## Converting cycles to time and rates

At an assumed operating frequency f MHz:

- Job latency in microseconds = `wrapper_cycles / f`.
- Core compute latency in microseconds = `core_cycles / f`.
- Standalone job latency-based rate = `f*1,000,000 / wrapper_cycles`.

This last rate excludes restart/control gaps between jobs, input/output stalls,
and SHAKE/sampler waiting. It is not measured sustained signing throughput.
A core-only rate also excludes all loading and output, so label it explicitly.
Use the approved **148 MHz operating clock** for the current latency model.
TimeQuest represents the requested 6.756757 ns as 6.756 ns (148.02 MHz);
the following arithmetic uses nominal 148 MHz conservatively.

| Operation | Core time (us) | Wrapper time (us) | Latency-based wrapper rate (polynomials/s) |
|---|---:|---:|---:|
| NTT | 267/148 = 1.804 | 781/148 = 5.277 | 148e6/781 = 189,501 |
| INTT | 267/148 = 1.804 | 781/148 = 5.277 | 148e6/781 = 189,501 |
| PWM | 75/148 = 0.507 | 845/148 = 5.709 | 148e6/845 = 175,148 |
| Pre-NTT | 236/148 = 1.595 | 750/148 = 5.068 | 148e6/750 = 197,333 |

The earlier 150.49 MHz fitted-Fmax estimate gave 192,689 NTT polynomials/s;
that is historical modeled capacity, not the selected operating rate. The
approved clock changes no RTL or cycle count. The 200 MHz benchmark remains
unmet. All rates exclude the gaps/stalls/SHAKE/sampler time listed above.
See the plan and current Quartus reports for the selected physical route.

For two coefficient-domain operands, the constituent core cycles are
`2*267 + 75 + 267 = 876`. Their wrapper latency sum is
`2*781 + 845 + 781 = 3,188` clocks, excluding gaps between the four requests.
This sum is a schedule model, not a captured sustained multiplication rate.
Pre can replace a forward transform only for an eligible bounded-secret operand.

## Evidence and remaining bottlenecks

Main UVM: `sim/ntt_LightHD/run_uvm.do`; separate output capture:
`run_uvm.do` with `NTT_MODE vectors`; Python final comparison as in [FIPS204_NTT.md](FIPS204_NTT.md).
Fresh fitted resources, all-corner timing and critical paths are under
`quartus/ntt_LightHD/results/`. Retained changes and exact comparisons are in
[the plan](POST_MIDYEAR_VERIFICATION_PLAN.md).

The 200 MHz benchmark still fails; operating timing is checked near Fmax. Future integration must
measure sampler acceptance, coefficient buffering/loading, compute, output and
SHAKE waiting separately. Wider coefficient loading and sampling overlap are
integration choices; no system throughput gain is claimed before that path exists.

## Earlier decoder/reducer trial review (2026-10-09)

The narrow decoder and collapsed multiplier trials changed no cycle boundaries,
but worst-corner fitted clocks fell to 129.70 and 123.38 MHz. Neither is selected.
The selected 131.22 MHz RTL is restored; `vector_selected_restore.log` confirms
the same cycles and Python compares every output. The 5.94 us / 168,231 polynomials/s
figures above remain latency-based estimates with the stated exclusions.

## Earlier selected rebalance (2026-10-09)

`vector_final_rebalance.log` confirms unchanged core cycles 266/266/74/235
and wrapper cycles 780/780/844/749. Python compares all 4,608 coefficients.
Moving one reduction fold into the final stage preserves the four-cycle
multiplier but improves fitted worst Fmax from 131.22 to 134.50 MHz at the
cost of 59 ALMs. The estimates above use this latest selected fit. Setup at
5 ns and minimum pulse-width timing remain open; no signing throughput or
sampler/Keccak integration gain is claimed.

## Earlier selected subtraction (2026-10-09)

`vector_sub_qplus1.log` confirms unchanged core cycles 266/266/74/235 and
wrapper cycles 780/780/844/749. Python compares all 4,608 coefficients.
The q+1 constant rewrite improves worst Fmax from 134.50 to 137.04 MHz and
reduces area by 36 ALMs. The estimates above use this selected fit; restart
gaps, stalls and SHAKE/sampler time remain excluded. Setup and minimum pulse
width at 5 ns still fail; this is not an integrated Dilithium throughput result.

## Earlier selected twiddle-guard removal (2026-10-10)

`vector_tw_nonzero.log` confirms unchanged core cycles 266/266/74/235 and
wrapper cycles 780/780/844/749. Python compares every one of 4,608 coefficients.
Removing the redundant inverse twiddle zero guard raises measured worst Fmax
from 137.04 to 140.69 MHz, with 24 fewer ALMs and 52 more registers. The estimates
above use this selected fit; exclusions are unchanged. Setup and pulse timing
at 5 ns still fail; no integrated Dilithium throughput result is claimed.

## Earlier selected combined selectors (2026-10-10)

`vector_operand_boolean.log` confirms unchanged core cycles266/266/74/235 and
wrapper780/780/844/749. Python compares all 4,608 coefficients. The selected
145.18 MHz fit improves the modeled rate3.19% over140.69MHz with higher area:
2,592ALMs/21M10Ks versus2,427/20. The smaller source/reports remain saved.
The estimates above retain the same exclusions. Setup/pulse at 5 ns still fail;
no integrated Dilithium throughput result is claimed.

## Latest selected kept-sum reduction (2026-10-10)

`vector_keep_bias.log` confirms unchanged core266/266/74/235 and wrapper
780/780/844/749 cycles. Python compares4608coefficients. Worst fitted Fmax
improves145.18->145.73MHz with24fewer ALMs. Timing/area comparison and slower
slow0corner tradeoff are in the plan; the estimates above use worst Fmax.
Restart gaps/stalls/SHAKE/sampler time remain excluded. 200MHz setup/pulse
checks stillfail; no integrated Dilithium throughput result.

## Smaller decoder alternatives (2026-10-10)

Direct route decoding reaches 140.43 MHz worst-corner with 2,436 ALMs and
20 M10Ks. Adding the narrow legal Pre lookup reaches 145.20 MHz worst-corner
with 2,362 ALMs and 20 M10Ks. Both retain every cycle boundary in the table
above and pass the separate Python comparison. The latter's 150.24 MHz slow85
result cannot establish a worst-corner throughput claim: slow0 is 145.20 MHz.

Both are saved as smaller alternatives; the 145.73 MHz keep-bias source is
restored. Fresh `vector_keep_bias_restore.log` confirms unchanged cycles and
`compare_keep_bias_restore.log` checks all 4,608 coefficients. See the plan for
full setup/hold, area and selection evidence. No sustained system rate measured.

## Earlier first-fold trials and proposed latency tradeoff (2026-10-10)

Both first-fold carry-select trials preserve cycle counts but regress fitted
worst Fmax to 121.30 MHz and 120.11 MHz. They are rejected; the selected
145.73 MHz source is restored. Fresh `vector_fold_trials_restore.log` /
`compare_fold_trials_restore.log` confirms unchanged cycles and all 4,608
coefficients. No throughput improvement is claimed for this iteration.

The next proposed trial adds one multiplier/BF/return pipeline clock. The
existing index-only scheduler passes with proposed PIPE=10 at unchanged FIFO
depths. If RTL preserves continuous issuing and only adds one drain clock,
wrapper counts would be 781/781/845/750 and core counts 267/267/75/236.
These are predictions, not measured RTL results. A real trial must verify
all boundaries and measure timing before publishing new latency/rate results.

For the NTT wrapper, the fitted-frequency break-even point would be
`145.73*781/780 = 145.917 MHz`; a slower clock would cancel the benefit.
This calculation includes the same load/output phases and excludes the same
restart gaps, stalls and sampler/SHAKE waiting as the current rate model.
No pipeline change or integrated throughput improvement is active yet.

## Latest measured first-fold pipeline (2026-10-10)

The proposed extra stage is now implemented and measured. Main UVM passes
118/118 and separate Python comparison passes all 4,608 coefficients in
18 cases. vector_fold_pipeline.log confirms core counts 267/267/75/236 and
wrapper counts 781/781/845/750. Fresh fitted worst Fmax is 148.46 MHz; the
operation-count table above uses these measured counts; the current rate uses
the later approved 148 MHz operating clock. FIFO depths and the
one-coefficient wrapper width are unchanged. The older planning predictions
are superseded by this capture. Stage 4 remains open: setup/pulse timing at
200 MHz and integrated throughput remain unclosed.

## Latest source evidence (2026-10-10)

vector_write_select_prefetch.log / compare_write_select_prefetch.log passes
18/18 cases, 4608/4608 coefficients and confirms unchanged core 267/267/75/236,
wrapper 781/781/845/750. Main UVM 118/118 also checks observed internal timing.
The early-write-select-only trial is saved but not selected (144.72 MHz worst).
Selected exact source and complete fit evidence are in
experiments/ntt_stage4/lighthd_write_select_prefetch_checkpoint.

## Operating clock choice (2026-10-10)

The user approved timing closure near current Fmax. This supersedes earlier
sections using fitted Fmax as a modeled operating clock. Build at the aggressive
5 ns fitter target and sign off at the approved nominal 148 MHz operating
constraint. A relaxed-only 148 MHz fit was slower and is retained as rejected
evidence. This frequency choice is not an RTL speed improvement. See
[the operating closure section in the plan](POST_MIDYEAR_VERIFICATION_PLAN.md#stage-4--approved-148-mhz-operating-closure-2026-10-10).

## Stage 5 functional validation (2026-10-11)

Distinct synthesis and fitted models each pass 117/117 main UVM jobs, including
all four operations, gaps/stalls, external resets and Pre/general pairs.
Fresh source UVM again passes 118/118 with unchanged raw coverage counts.
No RTL, interface or pipeline change was made; the cycle table and nominal
148 MHz rate calculations above remain the selected measurements. Netlist
simulation used a functional 10 ns testbench clock, without SDF; it is not a
new Fmax or integrated-throughput measurement. The netlist driver now waits
for the public completion pulse before releasing the next sequence item.
See [the Stage 5 results](POST_MIDYEAR_VERIFICATION_PLAN.md#stage-5---functional-implementation-verification-completed-2026-10-11)
for exact counts, warning review, commands and limitations. Stage 6 integration
and board validation remain pending.

## Expanded source regression (2026-10-11)

620/620 jobs now check additional polynomial shapes, operand ranges, operation
transitions and variable gap/stall durations through 63 clocks. These deliberately
paced transactions are correctness tests, not the no-stall throughput benchmark.
RTL/golden and the measured cycle table are unchanged. Existing fitted timing
is retained; no speed improvement or new full-netlist rate is claimed.
