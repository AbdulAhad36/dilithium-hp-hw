# Stage5 complete ? 2026-10-19

Accepted Stage4.9r unchanged:3537 placed ALMs,164.74MHz,+0.430ns setup,
+0.141ns hold at6.500ns. User authorized Stage5;both distinct current-build
netlists pass184 main-UVM jobs/39936 comparisons each (156 complete,24 errors,
4 aborts). All104-job captures(source/synth/fit) byte-identical and match Python
19456 values. Fresh source621/159628,C48/12288,checker12 pass. Source coverage
95.99% functional/95.53% code;netlists72.92%,internal source groups unsampled.
Timing/structural guards refreshed;96-case CSV preserved hash-identical,not rerun.
Read docs/sampler_docs/post_midyear/SAMPLER_NETLIST_RESULTS.json and
SAMPLER_PLAN.md. Freeze evidence in evidence/sampler_stage5.zip+SHA256.
Next is Stage6 planning;no integration/branch/import/commit without instruction.
Prior handoff below is historical and preserved unchanged.

---

# Current acceptance and cleanup status ? 2026-10-19

User accepted Stage4.9r:3537 placed ALMs,164.74MHz,+0.430ns setup,+0.141ns
hold at6.500ns. This supersedes historical acceptance-pending instructions below.
Canonical current roadmap:docs/sampler_docs/post_midyear/SAMPLER_PLAN.md.
Current task is directory cleanup;Stage5 current-build netlist verification is
next,not yet executed. No commit,branch change,module import or integration.
User confirmed historical cleanup. Obsolete checkpoint records/archives and
leftover NTT folders are removed;49 protected files hash unchanged. Only R
JSON/ZIP/SHA remain. Two Python helpers retained after review rejected deletion.
The following prior handoff remains unchanged as historical context.

---

# Current retained Stage4.9r - 2026-10-19

3537 ACTUAL PLACED ALMs,3931 registers(3860 implementation+71 router),4256
ALUTs,one M10K/1024 bits,zero DSP.Worst Fmax164.74MHz(Slow85:167.59,
Slow0:164.74),setup+0.430ns/hold+0.141ns at unchanged6.500ns.All4 corners0TNS.
VersusJ:91 fewer placed ALMs(2.51%),Fmax+1.58MHz,149 fewer ALUTs,3 more
router registers.Area metric is placed ALMs only;never needed estimates.
All96 performance CSV rows byte-identical toJ;operating throughput unchanged.

R is exact O RTL:only J mask_coefficient changes to one20-bit subtraction
using q=2^23-8191 and explicit zero at t=gamma.Original stage placement,
canonical collector values,challenge-read predicate,ports/depth/cycles retained.
Quartus seed1,HIGH PERFORMANCE EFFORT,PHYSICAL_SYNTHESIS_REGISTER_RETIMING OFF.
Every original register guard passes unchanged;no guard waiver.Fresh full fit,
structural and multicorner reports.Source results reused from O only after26
RTL/UVM/model/launcher hashes match.Compiler-only changes do not need new
source simulations when identity is proved;functional netlist checks stay gated.

Main621 complete(A150,secret200,mask130,challenge141),182 expected errors,
51 reset aborts,159628 comparisons.Six added main-UVM mask boundary jobs
cover zero/gamma/8191/516097 borrow boundaries on both contexts/all params.
Python104/19456,C48/12288,checker12,performance96,five zero-credit faults PASS.
Functional1652/1721=95.99%,69 reachable gaps;raw code15093/15799=95.53%,706
unwaived misses.No invented bins,exclusions or coverage ceiling.

K..P are immutable rejected fits.Q's retimed3536/168.27 point fails original
mask register guard(31/64),so it is NOT selected.Q archive is diagnostic;
omitted compile.log/reconstructed QSF provenance is explicitly recorded.
R disables retiming and passes every original mask/secret/payload/sign guard.
Do not overwrite any JSON/ZIP/SHA checkpoints.No commit,branch/import,
integration,stage advancement or new functional netlist simulations authorized.
Native128 inactive.User acceptance pending;stayStage4.

Next trial must beat3537 placed ALMs,preserve164.74MHz/all96 cycle rows and
positive6.5ns timing.Use an explicit retained --baseline=4.9r in the checkpoint
helper;source-reuse requires matching RTL/UVM/models/launcher hashes.Read
STAGE4_9R_RESULTS.json,COVERAGE,THROUGHPUT,SPECIFICATION and SAMPLER_PLAN.

# Historical retained Stage4.9j - 2026-10-19

3168 needed/3628 placed ALMs,3928 registers(3860+68router),4405 ALUTs,
one M10K/1024 bits,zero DSP. Worst Fmax163.16MHz,setup+0.371ns/hold+0.161ns
at unchanged6.500ns. Slow85/0 Fmax164.07/163.16;all4 corners0 setup/hold TNS.
Compared with4.9h:456 fewer needed ALMs(12.58%),125 fewer placed(3.33%),
Fmax+1.22MHz;ALUTs increase220. All96 performance CSV rows equal4.9h exactly.
Collector data is selected by stable per-context job mode and shared across
circular rows;row masks own enables. No stage,depth,port or throughput change.
Source assertions check source exclusivity and mode ownership.All fit guards pass.

Default source test sampler_stage4_9_test extends the main UVM:615 complete/
182 expected errors/51 aborts/158092 comparisons.54 rejection-burst jobs,
128 invalid-byte cases with same-ID recovery and24 long-stall jobs added.
23 groups,88 coverpoints,36 crosses:1652/1721 raw functional bins=95.99%,
69 reachable gaps. Raw DUT code15084/15790=95.53%,706 misses unwaived.
Never fabricate impossible bins or cap measured coverage at92-93%.
Python104/19456,C48/12288,checker12,performance96 and5 fault gates PASS.
Each fault0/1721 and all5 checked CSV witness files empty.Models unchanged.

I's parallel collector masking passed source but3780ALMs/154.87MHz lost;
immutable I archive retained.Its inherited fault-bin metadata914 is stale;
actual archived logs0/1721.J records the correction and parses denominators.
J initially hit Quartus inline-genvar syntax rejection;standalone declarations
fix portability and all source/vector/performance/fault gates were rerun.
Keep I/J JSON/ZIP/SHA create-only.No branch,commit,integration,imports,stage
advancement or new functional netlist simulation.User acceptance pending.
Native128 is not active.Read STAGE4_9J_RESULTS.json,COVERAGE,THROUGHPUT and
SAMPLER_VERIFICATION_TESTPLAN for exact gaps.Further area work must preserve
163.16MHz,positive6.5ns timing and all96 performance rows.

# Historical retained Stage4.9h - 2026-10-19

3624 needed/3753 placed ALMs,3928 registers(3860 implementation+68 router),
4185 ALUTs,one M10K/1024 bits,zero DSP. Worst Fmax161.94MHz(Slow85:161.94,
Slow0:163.72),setup+0.325ns/hold+0.148ns at unchanged6.500ns. All4 corners0TNS.
Relative to4.9b:-239ALMs(-6.19%),-188registers,+1.43MHz. Relative to4.7s:
-495ALMs(-12.02%),+3.99MHz. All96 performance CSV rows equal4.9b/4.7s exactly;
operating throughput at153.85MHz is unchanged. Native128 is NOT active.
Main409 complete/54 errors/51 aborts/105356 values,Python104/19456,C48/12288,
checker12,performance96 and five zero-credit fault gates PASS. Functional914/
914;raw DUT code14991/15698=95.50%,707 unwaived misses;expressions162/178=91.01%.
Models/main UVM unchanged. Denominators shift with RTL;no exclusion/new-hit claim.

A/mask share131/147-bit alignment;A fields derive from shared stream,zero
separate A field bank. Fixed-context failure equations keep error priority.
Phase3 carry PAYLOAD ignores accept/reset;READY retains both qualifiers.
Short challenge words CAN restart preparation before phase4.4.9e's no-overlap
assertion failed at188115ns;its fit was canceled and failure archived. Current
assertions enforce ready only in phase4 and ready low after acceptance.
Challenge last uses ball_remaining directly. IDLE RAM address uses read_valid
else byte address without ready qualification. FSM transitions retain valid/
ready;unaccepted read data cannot be consumed. All fitted payload guards pass,
including140 commit bits,64-bit secret banks and128 sign bits. No extra cycles,
ports,buffer depth or memory blocks. Power/switching/board rates unmeasured.

C/D/F/G are immutable intermediate fits losing Fmax versus4.9b;E is a source
failure,not a valid hardware point. H passes area/Fmax/cycle gate against4.9b.
Preserve all create-only JSON/ZIP/SHA256. Read STAGE4_9H_RESULTS.json,canonical
SAMPLER_PLAN.md,THROUGHPUT.md,COVERAGE.md. StillStage4;user acceptance pending.
No commit,branch change,module import,integration or new netlist simulation.

Historical records follow.

# Current retained Stage4.9b - lower area,higher Fmax,unchanged cycles

Latest user direction:optimize the157.95MHz64-bit-chunk design for lower ALMs;
preserve/increase Fmax and throughput as main priority. Native128 is not active.
Fresh4.9b:3863 needed/3964 placed ALMs,4116 regs(4015 implementation+101 router),
4396 ALUTs,one M10K/1024 bits,zero DSP. Worst Fmax160.51MHz(Slow85:160.51,
Slow0:164.10),setup+0.270ns/hold+0.151ns at unchanged6.500ns. All corners0TNS.
Versus4.7s:-256ALMs(-6.22%),-220registers,+2.56MHz. All96 performance rows are
byte-identical;operating throughput at153.85MHz is preserved,not increased.

4.9a shares4 wide rotated values across16 destination slots. Row masks own
writes,wide append<=4 ensures unique modulo4 destinations;secret remains16x4.
Original commit payload140=4*19+16*4 rather than368;guard verifies this and all
64-bit secret banks.4.9a fit3986ALMs/156.35MHz loses Fmax;archived,not selected.
4.9b additionally preloads each context's next unowned sign byte while IDLE
and count<8. Actual handshake alone advances count;start/reset override writes,
COPY/SIGN require8 accepted bytes. All128 fitted sign bits survive. No added
latency/depth. Power/switching unmeasured.

Main409/54 errors/51 aborts/105356 comparisons,Python104/19456,C48/12288,
checker12,performance96 and five zero-credit fault gates PASS. Functional914/
914 defined bins;raw DUT code15280/15987=95.58%,707 misses;expressions89.81%.
Continuous cycles:A302-304,secret285-320,mask270,Ball902-969. Independent models
and main UVM unchanged. Preserve4.7s,4.9a/b and rejected4.8a immutable evidence.
Read STAGE4_9B_RESULTS.json,SAMPLER_PLAN.md,THROUGHPUT.md,COVERAGE.md.
StillStage4;user acceptance pending. No commit,branch switch,integration,
module imports or new functional netlist verification authorized.

Historical records follow.

## Stage4.8a native128 evaluation: rejected;4.7s restored

The trial passes471 main UVM polynomials/121098 comparisons,Python104/19456,
performance96 and five fault gates. Cycles:A270,secret268,mask269,Ball902-969.
But8151ALMs,6857registers,117.74MHz,setup-1.993ns and hold+0.118ns at6.5ns
lose to4.7s. Create-only STAGE4_8A_RESULTS.json/evidence ZIP preserve the trial.
RTL/UVM/models/build scripts are restored to exact4.7s hashes. Source/vector/
performance gates pass;fresh4.8b fit reproduces4119ALMs,157.95MHz,+0.169ns
setup/+0.155ns hold at6.5ns. STAGE4_8B_RESULTS.json records restoration. Native128 is
not active. Next Stage4 hypothesis:full-word extraction feeding narrow ordered
commits and an extra secret-merge register boundary. Define pending ownership,
credits,quota,error drain and reset/reuse first. Do not repeat64-entry wide
collector doubling. User acceptance pending;no integration,new functional
netlist simulation,branch switch or commit.

# Retained Stage4.7s -150+MHz achieved and6.5ns timing closed

Fresh fit:4119 needed ALMs,4224 placement ALMs,4336 registers(4243+93 router),
5038 ALUTs,one M10K/1024 logical bits,zero DSP. Worst Fmax157.95MHz;Slow85
160.75MHz,Slow0 157.95MHz. Setup+0.169ns,hold+0.155ns at unchanged153.85MHz/
6.500ns. All four corners have zero setup/hold TNS. Preserve this SDC.

USER ACCEPTANCE PENDING;stay Stage4. No stage advancement,new functional
netlist simulation,integration,Keccak/NTT module import,branch switch or commit
authorized. Native128 remains deferred. Sources accept128 bits but still issue
64-bit chunks. Structural fitted guards are not functional netlist signoff.

Main409 complete(A94,secret144,mask86,Ball85),54 errors,51 aborts,105356 checked
values=409*256+652 partial-job values.18 exact preparation reset targets cover
3 phases x2 contexts x3 modes;all same-ID recovery checks pass. Python104/
19456,C48/12288,checker12,performance96 and five zero-credit fault gates pass.
Defined functional914/914;raw DUT code15274/15981=95.58%,707 misses. Expressions
141/157=89.81%;unwaived gaps remain. Models independent and unchanged.

Pipeline:input capture -> fine/coarse alignment/carry preparation -> extraction
->local compact ->packed/admit ->aligned commit ->collector ->per-context read
->shared formatted output. Capacity registers include pending/current issue.
Counter+pending addition=stored+all stage bounds+refund+pending pop credits.
Unowned count/credits clear together one inactive clock after status;monitor
checks all cycles and forbids unowned append/fetch. Reuse initializes both.
Challenge issued-read indices,room24<=25 stored+2 outstanding=27<32,and byte
prefetch have ownership assertions. S registers validity into row masks,clears
them on reset,and uses local failure cancellation. Nonzero masks must own valid
active tokens. All fitted guards pass:secret/preparation/output payloads,
capacity2,pending add8,pop2,prefetch8,challenge signs128,plus row masks.

Continuous cycles:A302-304,secret285-320,mask270,Ball902-969. All96 rows are
byte-identical toQ/R,SHA25621c86ec78e842ce742f8216d2350a9bce337e9d81eb27e79a52ee2557906b53b.
At timing-qualified153.85MHz,cycle-derived Mcoeff/s:A129.555-130.413,
secret123.077-138.192,mask145.869,Ball40.645-43.664. Not integrated ML-DSA rates.

Read STAGE4_7S_RESULTS.json,SAMPLER_PLAN.md,COVERAGE.md,SPECIFICATION.md and
THROUGHPUT.md. Preserve immutable A-R checkpoints;Q151.61/R150.13 meet Fmax but
miss6.5ns setup,S is retained. Old100MHz4.6r/4.6z stays archived. Do not repeat
rejected rewrites. Checkpoint JSON/ZIP/SHA256 writes are create-only;use
sim/sampler/stage4_checkpoint.py,which refuses existing paths. Three runnable
.do launchers remain;main UVM owns all source coverage and independent checks.
The frequency objective is achieved;further work waits at the acceptance gate.

## Historical direction below is superseded by the150+MHz requirement

# Current direction - Stage4 optimization

User acceptance PENDING;native128 deferred;no stage advancement,netlist
verification,integration,branch change or commit authorized by continuation.
Read STAGE4_6Z_RESULTS.json,COVERAGE.md,THROUGHPUT.md and SAMPLER_PLAN.md.

Selected candidate4.6r:3487 ALMs,2445 fitted registers,one M10K,zero DSP;
109.54 MHz worst Fmax,+0.871ns setup/+0.147ns hold at unchanged100 MHz.
Only sampler.sv changes from preserved4.6e/4.6o:packed payload captures every
clock;packed_valid owns every consumer. Same two stages,early admission,
reservations,error/reset draining and all96 performance records. No TB/reference
or build-script change. Main391 complete/54 errors/33 aborts/100733 comparisons;
functional914/914,code8198/8755=93.64%. Python104/19456,C48/12288,checker12,
performance96 and5 zero-credit fault gates pass. Both64 original secret banks
survive fitting,with1 decode/28 packed router copies counted separately.
Needed ALMs+5;Fmax+1.87MHz;setup+0.159ns;hold+0.005ns versus4.6e.
RTL declares no additional registers;fitter2390 implementation+55 router=2445.
No higher operating clock,power,board or new functional netlist signoff claimed.

Rejected4.6p:late commit clipping,3511 ALMs,89.38MHz,-1.188ns setup.
Rejected4.6q:direct raw<remaining exhaustion check,3554 ALMs,100.63MHz,
+0.063ns setup.4369 legal equivalence cases pass with no coverage credit.
Both pass the391-job suite/Python/fault gates and preserve96 cycle rows.
Their changed clipping placement/probes are archived and removed;4.6r starts
from exact4.6e. Prior4.6f/g/i/j/k/m/n variants also remain rejected.

Trials4.6s/t completed;no new RTL retained.4.6s Boolean secret formatter:
3467ALMs,106.42MHz,+0.603ns setup/+0.146ns hold.16 known nibble mappings
match the original algebraically(no RTL coverage credit).4.6t registers16
wide-address selectors beside packed base:3479ALMs,104.61MHz,+0.441ns setup/
+0.137ns hold. Ownership assertion and16-original-register fitted guard pass.
Both pass391 complete/100733 comparisons,Python104/19456,checker12 and5 faults;
all96 performance rows equal4.6r. Both hit914/914 functional bins. Their raw code
is8193/8750=93.63% and8231/8788=93.66%;do not merge these with selected4.6r.
Timing priority keeps4.6r.4.6u restores/revalidates all source/build hashes;
trial-only address probe is archived then removed from active reports.
4.6v holds one eta4 bit from beat acceptance;source checks/ownership assertion
and96 byte-identical performance rows pass. Its fitted bit survives,but3510ALMs,
102.27MHz worst Fmax,+0.222ns setup/+0.145ns hold lose to4.6r. Rejected/archived.
4.6w restores/revalidates exact4.6r with fresh reports;no RTL gain retained.
4.6x matrix working carry:3492ALMs,104.50MHz,+0.431ns setup/+0.144ns hold;
all18 snapshot bits survive fitting.4.6y direct secret compaction:3494ALMs,
106.13MHz,+0.578ns setup/+0.147ns hold. Both rejected for worse timing/area.
Both pass391/100733,Python104/19456,C48/12288,checker12,5 zero-credit faults,
and96 byte-identical performance rows. Rawcode X8242/8799=93.67%,Y8068/8625=
93.54%;557 misses unchanged,no new test credit. Immutable X/Y archives preserved.
4.6z restores/revalidates exact4.6r,including fresh source checks and fitted
reports. No new RTL change retained from X/Y;user acceptance still PENDING.
Next bounded Stage4 review:redistribute part of secret rotation across the
existing packed register. Derive append-address ownership,tail forwarding and
reservation behavior before editing;preserve depth/cycles/error/reset draining.
No promised gain. Do not repeat rejected carry/parameter snapshots,secret input
gating,formatter,address,quota,depth or late-clipping variants unchanged.
Checkpoint JSON/zip/SHA256 writes MUST be exclusive x/xb and refuse existing
paths. Preserve4.6e/4.6o and all other immutable archives.4.6a-c fitted claims
remain withdrawn for secret payload synthesis loss.64 ORIGINAL bits per secret
bank remain required;router copies are counted separately. Code conditions/
expressions remain unwaived below90%;defined-bin100% is not full verification.

## Historical checkpoint notes (direction below is superseded)

# Current plan - sampler_v1

Canonical roadmap: docs/sampler_docs/post_midyear/SAMPLER_PLAN.md.
Read AGENTS.md,README.md and user LIGHTHD_SAMPLER.md/SAMPLER.md.

Updated2026-10-17. Current3.3k: 3543 ALMs, 2388 registers, one M10K, 100.33 MHz worst Fmax, setup +0.033 ns and hold +0.144 ns at 100 MHz.
Status: functional checks pass; standalone internal timing passes at 100 MHz. Read THROUGHPUT.md/STAGE3_3K_RESULTS.json.
Stage4.5 main UVM349 complete/54 errors/33 aborts/89981 coefficients; Python104 jobs/
19456 values,C48 cases,checker12/12,performance96 polynomials/72 scenarios pass.
A/mask262 continuous single clocks,secret262-273,challenge899-966.
Stage4.5:20 groups,76 points,31 crosses;914/914 defined bins=100%,
raw DUT code7749/8267=93.73%.5 separate faults each0/914 bins andzero credits.
Defined-bin completion is not full verification;conditions/expressions below90%.
RTL/settings match the existing3.3k fit; no new synthesis was needed.
72 random polynomials/3 seeds and idle/busy/stopped refusals pass.
Two full runs reproduce six checked witness/summary CSV hashes.
Both unlocked status choices,held surplus,stopped completion and initialized
challenge abort/recovery pass. Monitor refusals now publish before status retirement.
Remaining gaps are classified,not formally waived. User continued past Stage4
review on2026-10-18. Stage5 distinct functional netlists each pass184 jobs,
156 complete/24 expected errors/4 aborts/39936 comparisons. Both104-job Python
captures match19456 values and each other. Source349-job revalidation and all96
performance rows remain unchanged. Raw netlist730/914 bins;internal probes/groups
unsampled;no RTL code or SDF timing claim. Three runnable .do launchers.
Next:Stage6 actual integration planning;explicit authorization needed before
module imports or branch changes. Read COVERAGE.md/STAGE5_RESULTS.json.

Retain current and archived checkpoints. One Python script and main UVM only;
references remain independent. Narrow16x4 secret/3x23 A compactors,mask
conversion in packed stage,secret formatting at circular collector write.
Capacity32/context,external128-bit tagged input/23-bit output unchanged.
I/O paths,including circular-output read mux,are excluded from internal timing;
functional netlists pass;no actual sink/board/integration/security signoff. Do not relax100 MHz.
No commit,push or branch change without explicit instruction.
