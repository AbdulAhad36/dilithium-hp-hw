# Sampler verification test plan

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

## Current arithmetic-boundary expansion

Default `sampler_stage4_9_test` now adds six mask polynomials to the615-job
suite below:each context and all three parameter sets. Fields include0,1,
gamma-1,gamma,gamma+1,gamma+8190/8191/8192,and wide-field values around the
516097 borrow boundary,plus2*gamma-1. Inputs are serialized bit-by-bit;the
unchanged scalar scoreboard checks all256 canonical coefficients and status.
No direct DUT-function calls or fabricated coverage hits are used.

Latest source totals:621 complete(A150,secret200,mask130,challenge141),182
expected errors,51 reset aborts,159628 comparisons=621*256+652 partial values.
Require `SAMPLER MASK FORMAT BOUNDARY PASS:6 complete jobs` as well as the
existing robustness/merge/reset gates. Any future optimization must preserve the accepted area/timing/cycle baseline.
The independent models,23 functional groups and1721-bin denominator remain.

## Stage4.9 robustness expansion - 2026-10-19

The default source launcher now runs `sampler_stage4_9_test`, extending the
existing main UVM sequence, driver, monitor and independent scalar scoreboard.
The following sections describing391 jobs/100MHz are historical checkpoints.
No reference algorithm is changed by this expansion.

| Requirement | New directed stimulus | Required result |
|---|---|---|
| Rejection cannot corrupt the next accepted candidate |54 complete jobs: A/secret/challenge x2 contexts x3 parameters x3 burst lengths | All256 indexed coefficients and success status match the independent oracle |
| All invalid5-bit byte counts are refused with the specified error |0 and17..31 in each of4 modes on both contexts:128 errors | Byte-count error, followed by exact same-ID/same-mode recovery |
| Output/status payload and ownership survive prolonged backpressure |24 jobs:4 modes x2 contexts x3 parameters; output stalled1024 clocks and status4096 clocks from command issue | No data/tag/index/last loss; eventual independently checked completion after readiness returns |

Burst targets are17,129,513 rejected candidates. Secret nibbles are transported
in bytes, so odd targets round up to18,130,514. Matrix rejects use three bytes
each. Challenge signs are supplied first, followed by rejected255 bytes and
then legal candidates. All inputs use the external interface; no force/deposit.
Existing18 preparation reset/recovery targets and1282 merge patterns remain.

Three new success-gated groups extend the original20 groups to23:

- `stream_context`: context x mode x parameter x accepted beat length1..16.
- `rejection_bursts`: context x rejection-sampling mode x parameter x consecutive
  rejection length, including reachable extended runs2048 or more. Sample only
  when the next candidate is accepted, after whole-polynomial checking succeeds.
- `backpressure_context`: context x mode x observed maximum output/status stall,
  with separate0,1..16,17..127,128..1023,1024+ clock ranges.

The checked-error group now has individual bins for all16 invalid byte counts
and their mode/context cross. Its cross is sampled only on byte-count errors.
`smoke_checked_robustness.csv` records each successful job's maximum rejection
run and observed stalls. Every mismatch fault must leave this file empty as
well as the existing four checked witness files.

## Requirement traceability

The following tables retain test/coverage definitions. Earlier-stage counts describe test development, not additional current results. The accepted totals above are authoritative.


## Requirements and verification mapping

These tables retain the test requirements; accepted totals above supersede earlier development counts.

| Requirement | Stimulus/check | Evidence and limit |
|---|---|---|
| C31 unlocked status tie |7000/7010 prime the turn; simultaneous byte error7001/7011 and invalid descriptor7002/7012; assert both eligible and unlocked and expected chosen core | Both selector choices hit; each status independently checked; same-ID exact recoveries pass |
| C32 held surplus |7100/7101:120 secret bytes then16-byte final beat,80-clock output stall | Hold/core/generated=256 witnessed; cleanup statement/branch/condition hit; exactly256 outputs and OK |
| C33 refusal through status |7200/7201:mask source-stop then hold input-valid through status-ready/acceptance | Every edge refuses input; pre-edge ownership checked before retirement; correct polynomial/status |
| C34 initialized IDLE abort |7300/7301:challenge clear then malformed metadata then same-ID recovery | Byte error and recovered challenge checked; initialized byte-ready abort term hit |

| Requirement | Stimulus/check | Coverage/evidence |
|---|---|---|
| C28 idle-source refusal | Both slots,8-clock input offers without descriptors; every offered edge must keep input ready low | Scoreboard checks absence of ownership before protocol_refusals credit;16 idle-cycle rows in checked_protocol.csv |
| C29 busy/stopped refusal | Each mode/core: blocked second descriptor then source-stop input offer,8 clocks each; original job must still match all256 outputs/status | Retain owned witnesses until successful completion;8 busy and8 stopped job rows; protocol kind/core and owned kind/mode crosses |
| C30 reproducible random workloads | 3 fixed seeds *4 modes *3 parameters *2 cores; random bytes/valid-byte partitions/source gaps/interleaving/readies | Every coefficient/index/tag/last/status checked by independent oracle;72 successful activity rows; randomized_jobs crosses all72 combinations |

| Requirement | Stimulus/check | Coverage/evidence |
|---|---|---|
|C22 peer errors with recovery |4000/4010 exhaust/invalid-param while challenge peer remains live;recover failed ID then finish peer |Former checked_errors peer cells hit only after validated statuses;all recovered/peer coefficients match |
|C23 reset parameter combinations |4100..4107 actual occupied-stage resets and same-ID recovery |Former8 reset mode/core/parameter cells hit after exact recovery |
|C24 final truncation |6-byte first beat,final full beat with surplus A/mask candidates |4200/4202 exact256 outputs plus owned clipping witnesses in *_checked_activity.csv |
|C25 completion arbitration |Hold status ready low until both pending,then release;all4 modes |completion_arbitration mode/core/pending/stall;stable offers and exact statuses. Does not imply unlocked tie-selection branch hit |
|C26 error during RAM work |9-byte prefix,malformed metadata accepted during COPY |Registered abort reaches SIGN;error and recovery4400/4401 checked. COPY/READ_OUT abort terms remain reviewed misses |
|C27 complete tag width |FFFF,8000,AAAA,5555 polynomial IDs |Every output/status tag compared exactly;upper ID-bit toggle holes reduced |

| Requirement | Stimulus | Observation/check | Credit/review |
|---|---|---|---|
|C15 checked error reasons |Each mode/core:finite16-byte exhaustion,param3,byte count0/17; same-ID exact recovery |Code/ID/core independently expected by scoreboard; every emitted prefix already compared |checked_errors,mode x reason/core x reason/reason x live peer |
|C16 reset and clean recovery |Reset with both pending stages; challenge CLEAR/COPY/SIGN/READ_OUT on both contexts; same-ID recovery |Pre-reset state snapshots; no unowned output; later256-value exact recovery |reset_recovery,mode/core/param plus held/decode/packed/collector/prefix/FSM state. Queue records until verified recovery |
|C17 lifecycle |Success/error/reset followed by another operation |Prior checked outcome and current successful completion |lifecycle_recovery; no successful-polynomial credit for the error/abort itself |
|C18 collector/pipeline |All main jobs plus prolonged backpressure |Clock-to-clock count conservation from append delta/output pop;bounds<=32/16;pending context tags;head/tail wrap,admission clipping,source stop |pipeline_activity samples owned snapshots only after exact success. Challenge has no candidate/packed/clipping path |
|C19 challenge FSM |All parameters,interleaving,reset at observed RAM phases |Actual owner-qualified IDLE/CLEAR/COPY/SIGN/READ_OUT states and legal edges; independent full challenge equality |challenge_states and param x state; functional FSM coverage is distinct from inferred code FSM coverage |
|C20 success gaps |Source gaps with ready outputs;stall actual output/status offer for9/40 cycles;mask6-bit carry then1/7 bytes |Accepted transfers and stable stalled payload;scalar bit queue for masks |Original15 success misses now hit; all12 success groups100%,not full overall closure |
|C21 checker faults |Separate first value/index/tag/last/status corruption |COEFFICIENT/STATUS fatal before first credit;empty success/outcome witness CSVs |All5 runs0/1721 bins; excluded from positive percentages |

| Requirement | Directed stimulus in sampler_stage4_classes.svh or inherited smoke | Independent check | Implemented group and sampling logic |
|---|---|---|---|
| C01 modes/parameters/contexts/completion | Original all-parameter paired tests plus ordered mode pairs |256 exact indexed outputs and OK status |checked_polynomial at checked_ap; mode x core x parameter |
| C02 valid bytes and low/high halves | All1..16-byte partitions; driver poisons unused high bytes |Scalar byte/bit queues ignore invalid bytes |input_format, observed beat size x mode, after job success |
| C03 backpressure and ownership |Periodic stalls; forced output/status stalls; both live slots |Monitor payload stability, scalar stream equality, checked status |scheduling, longest observed per-job output/input/status runs and mode x output stall; paired/switched/reused witnesses |
| C04 successive modes |Each of16 prior/next combinations on both contexts |Each operation completes against its mode's scalar oracle |mode_transitions; prior successful mode per slot, reset/error breaks history |
| C05 matrix boundaries/high bit/candidate order |0,1,q-1,q,q+1,2^23-1, high-bit-set forms; fragments |matrix_candidate scalar oracle and indexed output comparison |matrix_candidates; replay3-byte little-endian candidates until256 accepted; top-bit x acceptance and continuous-byte offset x acceptance |
| C06 secret mapping/lane rejection |All nibble values,eta2/4,all physical nibble positions |secret_candidate scalar modulo5/eta4 oracle |secret_candidates; byte position within each64-bit chunk determines lane0..15; eta x nibble, lane x acceptance |
| C07 stable secret compaction/count |First full chunk deliberately accepts each count0..16; all-reject prefix later completes |Exact output order/count against scalar accepted queue |secret_compaction; examined acceptance mask and count up to completion, not an unverified RTL mask probe |
| C08 mask extrema/zero/sign |Raw fields0,1,gamma-1,gamma,gamma+1,max-1,max,lower/upper interiors |Scalar bit-queue gamma-field and canonical conversion |mask_fields; width x field class, after successful polynomial |
| C09 mask18 carry |Arbitrary accepted-byte partitions and interleaved jobs |Bit-queue oracle plus exact outputs |mask18_alignment; scalar reservoir count before each consumed chunk x chunk bytes; reachable carries0,2,...16 |
| C10 mask20 carry |Same for ML-DSA65/87 |Same independent bit oracle |mask20_alignment; reachable carries0,4,8,12,16 x chunk bytes |
| C11 challenge rejection/shuffle dependencies |j>i,j==i,repeated nonzero positions,all tau values |Signed-array sequential shuffle,exact polynomial and weight |challenge_decisions; replay accepted bytes through sign/index algorithm, param x each decision |
| C12 output endpoints/canonical values |All completed polynomials and boundary-generating inputs |Exact value/index/last and mode range/weight checks |coefficient_shape; checked reference values known equal to actual outputs, mode x canonical lower/upper/zero and index positions |
| C13 active peer survives ID reuse |Challenge1951 partly shuffled; A1950 completes/reuses while peer stays live |Scalar per-job state plus eventual full challenge equality |C03 witnesses and exact checks; no dedicated internal-memory hazard coverage claimed |
| C14 coverage gate rejects wrong data |Separate SAMPLER_INJECT_FAULT run flips first observed coefficient |COEFFICIENT UVM_FATAL before first success |Witness CSV has zero jobs and separate UCDB has0/1721 functional hits; excluded from positive totals |

| Requirement family | Next observation/check and coverage work |
|---|---|
| Checked errors and recovery |Separate checked error outcomes by mode/core/parameter, malformed counts0/17,exhaustion before/after offered output, ID reuse and peer survival; preserve successful-group semantics |
| Reset/cancellation |Checked reset while hold/candidate/packed/collector/status/challenge states are occupied; recovery equality and no stale output; abort activity is not a successful polynomial |
| Internal pipeline/collector |Observe occupancy, pending reservations, simultaneous append/pop, circular wrap, first/last clipping and source stop; release coverage only after the affected observation/job is independently accepted |
| Challenge state/memory hazards |State/transition and self/repeated-index RAM timing observations, per-context signs and drain; distinguish reference input classifications from actual internal state witnesses |
| Protocol corner cases |Idle-tag refusal, blocked descriptor, both pending statuses, stalled offers across peer activity, source stop/drain and legal context lifecycle |
| Former success misses |Closed in Stage4.2. Corrected mask labels:carry6 with1/7 bytes,not carry12 with2/8 |
| Checker strength |Additional targeted value/index/tag/last/status corruptions in separate failing databases; no negative-run coverage merge |
| Code misses |Classify every remaining meaningful condition/expression/toggle miss and any justified unreachable condition; add no unexplained exclusions |

| Requirement | Stimulus/check | Current evidence |
|---|---|---|
| q boundary and top-bit removal | q rejected, q-1 accepted, FFFFFF rejected after masking, legal high-bit-set candidates; scalar byte oracle | Eleven complete matrix polynomials including mixed-mode jobs |
| Stable compaction/order | Mixed accepted/rejected candidates; exact per-job indexed value comparison | Passing |
| Input adaptation/carry | Full 16-byte words and counts 1..16; 64-bit split and byte fragments | Passing output comparison; detailed internal 2/3/3 witnesses remain Stage 4 |
| Two independent contexts | Paired jobs, alternating accepted packets and different per-job data | Six paired polynomials across parameter encodings 0/1/2 |
| Output groups/backpressure | Periodic ready stalls; stable tagged output and exact last | Passing; detailed group/cross coverage pending |
| Status/backpressure | Periodic status-ready stalls; stable payload, exact ID/code | Passing; simultaneous pending-status adversarial test pending |
| Finite-source exhaustion | One short input and one longer prefix | Expected EXHAUSTED; latter has 24 checked prefix coefficients, no success credit |
| Invalid parameter | Parameter encoding 3 | Expected PARAM |
| Invalid byte count | Counts 0 and 17 | Expected BYTES |
| Reset/reuse | Reset in-progress A/secret/mask and challenge clear/sign/shuffle/drain state; fresh jobs reuse slots | Seven aborted jobs; recovery polynomials pass |
| Idle tag, held command/input, source stop/drain | RTL and future integration contract | Broader directed checks pending |
| Secret eta=2/4 and lanes | All nibble values, both contexts/all parameter sets, mixed A/secret, all-accepted and all-rejected words, partial input counts and canonical signs | Thirteen complete secret polynomials; two zero-acceptance exhausted jobs and one exhausted after output prefix |
| Mask 18/20-bit reservoir | Bit-queue oracle, extrema/zero, all parameter/core combinations, mixed modes, partial words, 576/640-byte completion, reset with 12 residual bits | Twelve complete masks; fixed 18-byte example matches; 1-byte and one-byte-short exhaustion cases return errors |
| Challenge signs/shuffle | Scalar signed-array oracle; little-endian sign bits, j>i rejection, j==i and repeated nonzero locations, exact indexed comparison | Eleven complete challenges, all parameters/both contexts, tau=39/49/60 and coefficient range verified |
| Challenge literal | Signs 29 00 00 00 00 00 00 00, 39 repeated zero candidates, trailing FF surplus; continuous-source last=0 | id620: -1 at 218/221/223, +1 at 0 and remaining 218..255, zero elsewhere |
| Challenge mixed modes | Paired challenge/A, secret/challenge, mask/challenge | Passing with periodic input gaps/output/status stalls |
| Challenge errors/reset | Finite 7/8/16/46-byte streams, malformed 0/17 bytes, invalid parameter; reset during clear/partial signs/shuffle/drain | Seven expected challenge errors, four challenge aborts; recovery id634 passes |
| Independent Python / software check | One prepare/compare script plus unchanged C reference; fast capture in same main UVM | 104 jobs / 19456 coefficients match Python; 48 seed cases / 12288 coefficients also match C |
| File-checker corruption self-tests | Offline altered captures, no simulation/coverage credit | 12/12 corruptions rejected; CLI wrong-value comparison returns 1; UVM fault-injection/coverage-gating self-tests remain Stage 4 |
| Full requirements/coverage expansion | Detailed functional interactions and DUT code gap analysis | Stage 4 pending |

## Coverage implementation and proof

The main UVM uses sampler_uvm_pkg.sv and sampler_ref_pkg.sv with the existing stage test extensions. sampler_coverage.svh and sampler_outcome_coverage.svh sample independently checked observations. C14 mismatch gating now includes value/index/tag/last/status: each gets zero of 1721 bins and empty checked witness CSVs. All 69 current functional misses and 706 code misses remain unwaived; see COVERAGE.md. Source-only internal observations must remain unsampled in netlist runs. No merged RTL/netlist coverage percentage.

## Stage 5 pending checks

Use sampler_netlist_test with the main driver, monitor and independent scoreboard. Its existing scope is 104 file jobs plus 80 additional successes: 156 complete, 24 expected errors, 4 aborts and 39936 coefficient checks. Python compares the 104-job capture (19456 values). These are required counts, not current-build PASS claims. Generate distinct synthesis/fit netlists, verify reset and initialized memories, compare both captures independently and with each other, and document source-only probe exclusions.
