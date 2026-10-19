# Sampler coverage

## Current retained Stage4.9r - 2026-10-19

Main UVM621 complete(A150,secret200,mask130,challenge141),182 expected errors,
51 reset aborts,159628 coefficient comparisons=621*256+652 partial values.
Six additional mask polynomials target zero/gamma/8191/516097 borrow boundaries
in both widths,on both contexts. Independent scalar/Python/C formulas remain
unchanged. No direct DUT-function sampling or invented coverage holes.

R RTL/UVM/models/launcher are byte-identical toO:26 hashes checked before
reusing its passing source main,Python104/19456,C48/12288,checker12 and
performance96/five fault results. Every performance CSV row equalsJ exactly.
All5 faults hit0/1721 bins and leave all5 checked witness CSVs empty.
R has a fresh full Quartus compile,original-register guards and multicorner
timing reports;source coverage is not functional fitted-netlist verification.

23 groups/88 coverpoints/36 crosses:1652/1721 raw functional bins=95.99%,
69 reachable gaps. The detailed gap list below remains applicable. A percentage
ceiling is not imposed. Raw DUT code15093/15799=95.53%,706 unwaived misses.

| Raw DUT category | Hits / bins | Percent |
|---|---:|---:|
| Statements |954 /956|99.79%|
| Branches |819 /829|98.79%|
| Conditions |185 /199|92.96%|
| Expressions |162 /178|91.01%|
| Toggles |12973 /13637|95.13%|
| Overall summed bins |15093 /15799|95.53%|

The changed formatter adds/removes enabled code bins;denominator changes are
not solely stimulus improvements. All remaining code gaps stay unwaived.
Fresh R implementation:3537 placed ALMs,164.74MHz,setup+0.430ns/hold+0.141ns
at6.5ns;all4 corners0 setup/hold TNS. High-performance mode is enabled,but
physical register retiming is explicitly OFF. All original64-bit mask/secret
guards,140-bit commit payload and128 sign bits pass unchanged. No current-build functional netlist run is claimed.

### Functional coverage:1652/1721=95.99%,69 unhit bins

23 groups,88 coverpoints,36 crosses. The original model's914 bins expand by
14 individual invalid-byte bins,128 error mode/context/count cross bins,and
665 bins in three new success-gated groups. No unreachable bins,exclusions,
weights or artificial ceiling are used to force92-93%. Sampling remains gated
by independent scoreboard acceptance;error/reset outcomes have separate checks.

| New success group | Raw hits / bins | Raw percent | Open bins |
|---|---:|---:|---:|
| stream_context |405 /409|99.02%|4|
| rejection_bursts |122 /160|76.25%|38|
| backpressure_context |69 /96|71.88%|27|

These69 gaps are reachable but untested combinations,not observed DUT failures:

- Four challenge context/parameter/beat-length combinations:core1,param0,15
  bytes;core0,param1,13 bytes;core0,param0,13 bytes;core0,param0,5 bytes.
- Rejection runs32..127 and2048+ have no credited observations:2 coverpoint
  bins and36 context/mode/parameter cross bins. Directed bursts target17,129,
  513;odd secret targets round up to18,130,514 because bytes contain2 nibbles.
-27 backpressure bins remain,including output stalls1024+ and several medium
  output/status/context combinations. The1024-clock output stall command starts
  before output becomes valid,so the observed consecutive valid-blocked time
  can be shorter. Coverage uses observed duration,not commanded duration.

The GUI's per-coverpoint group mean is a different metric(three new groups
99.79%,90.00%,82.92%);use summed raw bins above for overall reporting.
Witnesses:`sim/sampler/smoke_checked_robustness.csv`;exact bins in
`sim/sampler/smoke_functional.rpt`;zero-filtered view in
`sim/sampler/smoke_functional_misses.rpt`. Wildcard cross rows may represent
multiple misses;do not count display rows as individual bins.

## Where to run and see results

From sim/ in the Questa GUI Transcript:

```tcl
do sampler/run_uvm.do
```

The default test is sampler_stage4_9_test. Waves and coverage views are set up by
the same launcher. At completion the Transcript prints each functional group,
the equal-group mean, raw overall functional hits/bins, code categories and raw
overall DUT code coverage. The current revision was batch-verified; GUI layout
has not been visually reviewed in this step.

| File under sim/sampler/ | Meaning |
|---|---|
|smoke_functional.rpt|Detailed functional bin names,counts and misses |
|smoke_code.rpt|DUT-only statement/branch/condition/expression/toggle details |
|smoke_coverage.rpt|General detailed report |
|smoke_checked_jobs.csv|One row per scoreboard-accepted complete polynomial; ID,mode,parameter,core,input sizes and scheduling/reuse witnesses |
|smoke_functional_summary.csv|Per-group percentages,equal-group mean and credited job count |
|smoke.ucdb / smoke.wlf|Coverage database and waves |
|smoke.log|Batch run Transcript; GUI writes uvm_gui.log |

Reports regenerate on each run. Frozen results are in STAGE4_9R_RESULTS.json and evidence/stage4_9r.zip.

## How a coverage hit is justified

1. The monitor observes actual accepted bytes and outputs, plus external stalls.
2. The independent scoreboard builds the expected polynomial from those bytes.
3. Every accepted output must match value,index,core,ID and last. Success also
   requires256 outputs and correct status,mask-byte bounds/challenge weight.
4. Only then does checked_ap release that job's observed transcript. Any UVM
   error/fatal prevents new coverage credit. Errors/aborts do not sample these
   successful-operation groups.
5. sampler_coverage.svh replays the validated transcript to classify candidates,
   alignments and challenge decisions. Its logic does not generate expected
   results for the scoreboard. Byte parsing stops after256 accepted values.

Example: the first secret chunk in job1600 contains only rejected nibbles, then
enough accepted bytes to complete. After all256 outputs match, its first chunk
credits the zero-acceptance-mask/count bins. An all-rejected exhausted job would
not credit that successful-operation group. For candidate/lane/field definitions,
tests and proof limits see C01-C14 in SAMPLER_VERIFICATION_TESTPLAN.md.

## Acceptance and remaining work

The user accepted Stage4.9r on 2026-10-19. The 69 functional gaps and 706 code misses remain open, not waived. Stage 5 will report current-build netlist checks separately from RTL code coverage.
