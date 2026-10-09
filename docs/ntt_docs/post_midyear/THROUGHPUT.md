# LightHD NTT cycles and throughput

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

## Converting cycles to time and rates

At an assumed operating frequency f MHz:

- Job latency in microseconds = `wrapper_cycles / f`.
- Core compute latency in microseconds = `core_cycles / f`.
- Standalone job latency-based rate = `f*1,000,000 / wrapper_cycles`.

This last rate excludes restart/control gaps between jobs, input/output stalls,
and SHAKE/sampler waiting. It is not measured sustained signing throughput.
A core-only rate also excludes all loading and output, so label it explicitly.
Use the worst-corner fitted Fmax as a timing estimate, not the 200 MHz constraint
as an achieved clock. The latest retained **148.46 MHz** fit gives NTT wrapper
latency `781/148.46 = 5.26 us`, core latency `267/148.46 = 1.80 us`, and
latency-based rate `148.46e6/781 = 190,090 polynomials/s`. Compared with the
saved 145.73 MHz checkpoint's 780-clock wrapper, this improves the modeled
rate 1.74% after including the added pipeline clock. It uses 78 fewer ALMs,
279 more registers and the same 5 DSPs / 21 M10Ks. Setup at 5 ns improves
0.126 ns but remains negative. This is not measured sustained system throughput.
See the plan and selected Quartus reports for exact before/after metrics.

For two coefficient-domain operands, the constituent core cycles are
`2*267 + 75 + 267 = 876`. Their wrapper latency sum is
`2*781 + 845 + 781 = 3,188` clocks, excluding gaps between the four requests.
This sum is a schedule model, not a captured sustained multiplication rate.
Pre can replace a forward transform only for an eligible bounded-secret operand.

## Evidence and remaining bottlenecks

Main UVM: `sim/ntt_LightHD/run_uvm.do`; separate output capture:
`run_vectors.do`; Python final comparison as in [FIPS204_NTT.md](FIPS204_NTT.md).
Fresh fitted resources, all-corner timing and critical paths are under
`quartus/ntt_LightHD/results/`. Retained changes and exact comparisons are in
[the plan](POST_MIDYEAR_VERIFICATION_PLAN.md).

Timing work is active and setup at 5 ns still fails. Future integration must
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
current table and rate above use these measured counts. FIFO depths and the
one-coefficient wrapper width are unchanged. The older planning predictions
are superseded by this capture. Stage 4 remains open: setup/pulse timing at
200 MHz and integrated throughput remain unclosed.
