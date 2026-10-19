# tb_uvm/tb_uvm_sampler

## Current main UVM

`sampler_stage4_9_classes.svh` extends the existing4.6 sequence/test. The
default launcher now uses `sampler_stage4_9_test`:621 checked complete jobs,
182 expected errors,51 reset aborts,159628 comparisons. Six additional mask
jobs targetzero/modular-borrow boundaries on both contexts/all parameters. Independent scalar
reference formulas are unchanged. Rejection bursts,all invalid5-bit byte counts
and prolonged output/status stalls are driven through public handshakes.

`sampler_coverage.svh` has15 success-gated groups;
`sampler_outcome_coverage.svh` has8 checked outcome/protocol groups. Raw overall
functional coverage is1652/1721=95.99%,with69 genuine unhit bins. The new
robustness CSV is emitted only for fully checked successful polynomials.
Mismatch fault tests must leave all five checked witness files empty.
Read the current SAMPLER_VERIFICATION_TESTPLAN.md/COVERAGE.md for scope and
per-group raw counts. Percentage thresholds are not used to fabricate holes.

## Historical checkpoint notes

Historical4.6a:sampler_stage4_6_classes.svh extends the main test with1282
secret chunks (625 group-count tuples plus16 local masks per eta),packed into
42 complete independently checked secret polynomials. Default total391 jobs/
100733 checks. Scalar models unchanged. Source functional914/914,code93.63%.
Historical4.5/Stage5 records below are retained;user acceptance remains pending.

Main UVM: sampler_uvm_pkg.sv contains transaction, sequence, driver, monitor,
scoreboard, environment and original smoke test. sampler_ref_pkg.sv holds
scalar reference helpers. sampler_if.sv and tb_top.sv connect the real DUT.

All four modes pass Stage 1 source-smoke checks. The scoreboard independently
uses byte candidates (A), signed nibble formulas (secret), a scalar bit FIFO
(mask), and a signed indexed-array/sign FIFO shuffle (challenge). Literal mask
and complete challenge examples additionally check known outputs. Two tagged
jobs, mixed modes, stalls, errors and reset/reuse are exercised. Only complete,
exactly matched successful jobs reach checked_ap functional coverage.

Study sequence -> driver -> monitor -> oracle/scoreboard -> checked_ap coverage.
Launch via sim/sampler/run_uvm.do with sim/ as working directory.

Stage5 adds sampler_netlist_classes.svh in this same environment. It runs104
file jobs then80 public-port cases (72 fixed-seed random plus8 mode/core
refusal/completion cases). Capture.enabled stops file recording after104 jobs;
the independent SV checker continues through all184. SAMPLER_NETLIST removes
source hierarchy connections from tb_top and sets vif.source_probes=0. The
monitor skips source occupancy assertions/internal snapshots; reset recovery
credits internal-state coverage only if actually observed. External equality,
tags/index/last/status,stability,reset/reuse and admission checks stay enabled.
Run post-synthesis/post-fit through their sim/sampler launchers. No separate
non-UVM bench, fabricated source observations or gate-code percentage is used.
Stage 2 adds sampler_vector_classes.svh: file sequence, observation-only capture
subscriber and sampler_vector_test, using the same environment and SV checker.
reference_check.c wraps the unchanged C model for Python preparation cross-checks.
See FIPS204_SAMPLER.md for the one-script prepare/capture/compare flow.

sampler_performance_classes.svh adds a main-UVM measurement test/subscriber.
A separate ordered timing port samples raw clock events; scoreboard.checked_ap
must verify the whole polynomial before a timing row is published. Source-only
probes in sampler_if/tb_top distinguish activity overlays from exclusive cycle
buckets. EV_STREAM drives contiguous packets for throughput measurements.

Stage3.3 expands smoke to52 complete polynomials,19 expected errors and11
reset aborts. pipeline_cases() exercises occupied-stage reset, invalid metadata
with packed work pending and subsequent context/ID reuse. Source-only monitor
witness counters fail the test if those hazards were never stimulated; they do
not credit success coverage. Performance accepted-candidate counts follow
collector commit, independently from extraction-cycle candidate/byte counts.

Historical Stage4.1: sampler_stage4_classes.svh extends that smoke sequence.
Main UVM checked178 complete polynomials,19 expected errors,
11 reset aborts and46173 coefficients. sampler_coverage.svh implements12 groups,
38 coverpoints and17 crosses. The scoreboard releases per-job accepted-byte
transcripts only after full equality and OK status; coverage replay is separate
from reference computation. Separate injected first-output corruption proves
zero successful credits/0 of589 functional bins. See COVERAGE.md for commands,
bin evidence, the15 genuine success gaps and remaining Stage4 requirements.

Historical Stage4.2 adds sampler_stage4_2_classes.svh and
sampler_outcome_coverage.svh.229 complete/44 expected errors/25 aborts/59261
coefficient checks pass.17 groups:773/785 functional bins;DUT code93.24%.
scoreboard.outcome_ap publishes verified errors and reset observations only
after exact recovery; internal snapshots wait for successful job validation.
Monitor count-conservation checks and owner-qualified FSM probes supplement
the independent oracle.5 fault kinds each fail before any credit. See COVERAGE.md.

Current Stage4.5:349 complete/54 expected errors/33 reset aborts/89981 checks.
Default sampler_stage4_5_test adds both unlocked status choices,held surplus,
stopped valid through completion,and initialized challenge abort/recovery.
Monitor refusals publish before status retirement,using pre-edge ownership.
20 groups/76 points/31 crosses remain914/914 functional bins100%;raw DUT code
7749/8267=93.73%.5 fault kinds each0/914 bins and zero success/outcome/activity/
protocol rows.72 fixed-seed random jobs and prior directed cases remain included.
Two full runs reproduce six checked witness/summary CSV hashes. RTL/all96
performance records/3.3k fit unchanged. Read COVERAGE.md/STAGE4_5_RESULTS.json.
Remaining code misses are classified without formal waivers;conditions86.78%
and expressions89.58% remain below90%. Stage5 now passes both distinct functional
netlists:184 jobs/39936 checks each;104-job Python captures match19456 values and
each other. Netlist raw730/914 bins,source-only groups unsampled. Read
STAGE5_RESULTS.json/COVERAGE.md. Next:separate actual integration planning.
Finite-model100% is not full signoff.
