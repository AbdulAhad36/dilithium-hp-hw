# Dilithium cycles,throughput and implementation metrics

## Stage5N.3 memory-path measurements

| Focused campaign | Observed work |
|---|---|
| sign_dma |71 commands,65 completions,21 expected errors,6 resets;14284 exact scalar writes,3570 acknowledged packed writes |
| sign_service |33 commands,30 completions,9 expected errors,3 resets;192 sampled source words +768 exact result words |

The DMA count includes verified partial write prefixes later canceled by reset.
The service result count is768x4=3072 coefficients;source count is192x4=768.
These are directed campaigns with imposed stalls,not signing throughput figures.
sign_process can accept one x4 group/cycle unstalled,but this sequential DMA
uses the existing one23-bit coefficient/write beat and two word caches. It is
not a four-coefficient-per-cycle full-memory datapath. Decompose writes512
coefficients;Mhint writes256;CNB writes none. All read/commit/retirement overhead
must be included in future operation measurements.

No synthesis,Fmax,area or timing improvement is claimed. The6.757ns constraint
is unchanged. Full Sign/Verify latency and throughput are not measured yet.

## Stage5N.2 focused process counts

sign_process accepts up to one4-coefficient group/cycle with one elastic
register stage. This is an interface capability,not an integrated throughput
measurement. The directed test accepts7752 groups and returns7746 results;
six held groups abort on reset.45 returned groups are expected errors.
Thus7701 valid arithmetic groups cover30804 lanes;180 error lanes are checked
for zeroed payloads.117 full polynomial packets are included.
7509 simultaneous replacements,2865 input stalls and2903 output stalls are
deliberately exercised. Per-polynomial hint counts include256,so a9-bit count
is required. CNB failure is a sticky prefix OR,not a count.
No Quartus/PPA measurement or operating-frequency claim is made for the new
process. Existing6.757ns integration SDC remains unchanged.

## Stage5N.1 ownership relocation

All key-byte/hash/read totals below remain unchanged in the freshly rerun
full_keygen and nist_keygen gates. The local simulated campaign duration is
6676943064ps,identical to Stage5M. Local ownership witness:988082 owned cycles,
195 post-completion cleanup-owner cycles,52 unowned-idle cycles. NIST witness:
9142284 owned,2225 cleanup-owner,151 unowned-idle cycles. These count the whole
directed workload with imposed stalls;they are not per-key throughput figures.
No extra request/response pipeline or memory is added. No new area,Fmax or
slack measurement is claimed;6.757ns remains unchanged.

## Stage5M NIST functional counts

All75 cases succeed:25 at each level2/3/5. Successful key bytes total
25*(3872+5984+7488)=433600,or54200 accepted64-bit output words.
PK hash inputs:25*(164+244+324)=18300 words;tr:75*64=4800 bytes.
Encoding field reads:25*64*(16+23+31)=112000 metadata-checked words.
These counts include no aborted prefixes. Fork witnesses are3632 host-ahead
and17452 hash-ahead cycles. Output stalls are deliberate,so these are not
sustained-throughput results. All46 RTL files and the6.757ns constraint are
unchanged from Stage5L. No new Fmax,area,slack or full-top synthesis is claimed.

## Stage5L complete-key functional counts

No new clock,Fmax,placed-area or slack measurement is claimed. The fixed
6.757ns constraint remains unchanged;the Quartus top is still the historical
scalar helper. Full-key cycle totals include sampling,compute,word packing,
host/hash stalls and final cleanup;no throughput benchmark is inferred here.

Eight successful operations emit36704 valid key bytes =4588 output words.
The full capture contains5433 words =43464 bytes;the extra845 words =6760
bytes are reset-aborted prefixes. Do not count them as successful keys.
The successful set is six level2 keypairs,one level3 and one level5.

There are2058 actual PK absorption words =16464 bytes,including abort prefixes.
656 tr bytes =512 from successful operations +144 from partial/aborted ones.
11179 field read responses include metadata checks for aborted prefixes;
complete byte comparison validates the data encoded into keys.
Fork witnesses434 host-ahead cycles and1939 hash-ahead cycles demonstrate
both acknowledgement orders in this workload. They are not performance
targets and do not measure sustained key-generation throughput.

## Stage5K functional packing/rounding counts

No synthesis or new Fmax/ALM/slack measurement is performed. The6.757ns
constraint remains unchanged. Bitpkg's87-bit reservoir size is a logical RTL
width,not fitted area or a promised frequency.

Rounded KeyGen writes190224 values =172304 from the polynomial baseline
+70 complete rounded polynomials x256. There are35 rounded pairs:34 delivered
rows plus the completed first row subsequently reset while held.
Public readback12800 words =8448 baseline +68 retained rounded polynomials
x64 words. The additional68 correspond to34 successfully consumed rows.

Bitpkg checks2482 accepted64-bit words=19856 bytes,including valid prefixes
of failed/aborted packets. Successful packets alone contain16832 bytes.
The independent C comparison covers66 full valid fixture inputs,including
abort/recovery fixtures,total18496 bytes;these are different denominators.
Do not report this stimulus-dependent word count as sustained throughput or
whole-KeyGen key generation latency. Full-key serialization/hash work remains.

## Stage5J functional work and counting

Current result is functional polynomial computation,not a new timing/area run.
No change to the6.757ns constraint or new ALM/Fmax/slack claim is made.
The controller samples/transforms sequentially and waits for caller row reads.

Seven successful operations produce34 t rows (18 across the three ordinary
levels plus16 in four level2 recovery runs).8448 public words contain33792
coefficients:8704 t values plus25088 retained-secret/transform values.

The scalar-write count is172304:673 complete polynomials x256 values plus
8 secret-prefix values and8 accumulator-prefix values from reset tests.
This includes internal products/sums/transforms,not just the34 final rows.
Actual elapsed KeyGen latency includes caller stalls and all sampling/loading,
compute,output and cleanup phases. Byte encoding/hash work is still absent;
do not label this whole-KeyGen throughput or multiply core Fmax by row counts.

## Stage5I functional observations

Seed-driven row capture:190 source commands =20 successful seed expansions,
163 successful samples and7 rejected adapter commands. Each expansion consumes
five64-bit absorption words and produces eight128-bit output beats;all2560
bytes match. Sampling consumes1103 formatter words in this workload.
The row workload remains13 complete rows,27 rejects and7 reset aborts with
161 NTT commands and55 ADDs. Re-expansions include resets and deliberate
level switches in negative-fixture setup;this is not the final KeyGen schedule.

No new synthesis,ALM,Fmax,slack or throughput claim is made for this added
seed/control path. The historical scalar top and6.757ns constraint are unchanged.
Seed collection,formatting,sampling and compute remain sequentially scheduled;
whole-KeyGen latency cannot be inferred from standalone NTT cycle counts.
Correct full-operation outputs still precede PPA optimization.

## Stage5H row-scheduler observations

A successful l-column row issues l PWM commands,l-1 in-place ADDs and one inverse
NTT. Thus levels2/3/5 use4/5/7 PWM,3/4/6 ADD and one inverse respectively.
Secret transforms are retained across rows;the test uses both ordinary NTT and
eligible Pre-NTT. No new arithmetic pipelines or parallel cores are added.

Payload DMA reads128 words per PWM,128 per ADD and64 per inverse:256*l-64 word
reads per row. Payload writes64 words per result:128*l per row. These counts
exclude metadata validation reads and external observation. The scalar engine
still needs one23-bit coefficient per beat;this is not LightHD32-cycle loading.
One accumulator and one scratch region are reused;the coefficient result has
its own region. Each is64 words x92 bits. Total bank geometry stays46KiB.

The campaign checks13 full rows,27 rejections,7 resets;163 samples,161 NTT/Pre/
PWM/INTT commands,55 in-place ADDs,96264 scalar writes,24066 packed writes/acks,
12544 public word reads and6918 old-word cache reads.160 held-row and4 pending-
read refusal checks pass. These are source workload counts,not sustained
throughput,full-KeyGen latency or a new fitted Fmax/area/slack/RAM result.
Rows are fully staged and execute sequentially. Overlap/PPA work stays deferred.
## Stage5G banked process observations

23 sample jobs,15 NTT commands and71 process commands pass. Processing has34
successes,33 expected rejections and4 reset aborts. Actual accepted arithmetic
operands8978,completed outputs8976;the two extra inputs are canceled by reset.
Stored low/high/residue writes are separately checked,including partial aborted
work. Full campaign:22297 scalar writes,5574 packed writes/acknowledgements,
8512 exact92-bit read responses. These counts are workload evidence,not a
sustained throughput measurement or full-KeyGen latency.

The client reads A and B as two92-bit words for each binary four-coefficient
group:128 reads per ADD/SUB,64 per P2R. It feeds one coefficient into the existing
elastic arithmetic stage,waits for the residue/low write and,for P2R,the high
write,before advancing. Each unary result region uses64 packed writes. P2R uses
two regions/128 writes. Requests/responses,packing acknowledgement and exclusive
ownership add cycles;the one-coefficient-per-cycle unit rate is not the whole
DMA rate. Pipelining/overlap is deferred until full-operation correctness.

Witnesses:36 wait/source-release refusal checks,188 held-result release checks,
4 pending-read refusal checks and22 actual partial-P2R-publication snapshots.
Logical payload stays46KiB;two92-bit word caches and control add unsynthesized
logic. No new fit,Fmax,placed-area,slack or physical RAM count is available.

## Stage5F banked NTT observations

The real banked connection passes16 sample jobs/54 commands,with30 completed
arithmetic results,21 expected rejections and3 reset aborts. It checks9746 scalar
DMA values,7712 engine outputs and2944 exact92-bit word reads. Witnesses:
24 destination-wait cycles,206 held-completion cycles,295 public read-response
stall cycles,33 source leases,4 compute-refusal checks during a pending read
and120 blocked result-release checks while completion is held.

DMA reads one92-bit word and holds it through four scalar NTT input handshakes.
Thus a unary load needs64 word reads/256 scalar transfers;PWM needs128 reads/
512 transfers. Request/response control adds cycles. Result packing writes64
words for each successful operation and pauses the engine while a packed word
awaits acknowledgement. Sampling and compute are sequential. This reduces RAM
request count from the old scalar DMA but does not implement LightHD's32-cycle
wide NTT loading or establish maximum sustained/full-operation throughput.

No NTT arithmetic RTL,pipeline,core count or internal compute latency changes.
Memory payload remains46KiB. This new controller has no synthesis/fit result;
there is no current banked-system placed-ALM,Fmax,slack or physical RAM count.
The6.757ns benchmark remains unchanged;PPA optimization is deferred.

## Stage5E connected packed-bank storage observations

Source workload104 jobs produces88 complete polynomials and5632 exact92-bit
word readbacks. It observes8 occupied-region stall cycles,1070 held-read cycles
and50 simultaneous read-request/coefficient-write handshakes. Two held responses
are reset. Publication includes the final word acknowledgement and hash drain.

Each context packs four coefficients,then pauses until its word write is
acknowledged;the implementation allows one outstanding sampler write per bank.
This is a correctness baseline,not a maximum-throughput claim. Public checked
reads use one global outstanding response and wait through the synchronous RAM
and response-register stages. Memory capacity is unchanged at46KiB payload;
descriptor/packing/control registers add logic that has not been synthesized.
The scalar NTT wrapper and its measured cycles are unchanged. Full-system
Fmax/placed area/throughput remain unmeasured for this new path.

## Stage5D bank-memory foundation observations

Published/selected logical capacity:four1024x92-bit banks=376832 bits=47104
bytes=46KiB. This is16 times the old four-slot payload2944 bytes,not a physical
M10K count. Each bank has two ports and each92-bit word holds four coefficients.

The focused test observes1031 cycles with all eight requests accepted,4112
dual-read same-address pairs,73 serialized collisions,3075 request stalls,
3034 response stalls and14807 response replacements. Each unblocked port can
accept one word per cycle. These are source-test observations,not a clock/Fmax
or complete system throughput result. No synthesis/fit or RAM inference measured.

The current NTT wrapper remains one23-bit coefficient per beat;LightHD's32-cycle
input loading needs the corresponding wide engine input/controller integration.
The memory foundation alone does not change any measured NTT cycle count.

## Stage5C shared-service observations

The focused test sees67 cycles with both a raw and sampling owner,333 with
two raw owners,60 raw-output stalls,298 raw-completion stalls and44 held seed
result cycles. One simultaneous descriptor conflict confirms raw priority.
These count ownership/handshake conditions,not overlapping permutation clocks.
26 commands produce1699 checked SHAKE bytes and1792 sampled coefficients.
Finite raw transfers honor partial bytes at the136/168-byte rate boundaries.

No added hash cores;the128-byte expansion collector adds logical register state.
The current Stage4 top leaves RAW_SERVICE disabled. No fit/synthesis was run;
do not infer current placed ALMs,Fmax or throughput from old Stage2 reports.

## Stage5B message-builder observations

The formatter emits five64-bit words for seed/matrix messages,or nine for
secret messages,after descriptor acceptance. It can emit one word per cycle
when the hash service is ready. The final word has two valid bytes. Message
completion is separate from hash completion;no full-KeyGen latency is measured.

The focused165-command test observes111 descriptor,288 input,757 completion and
671 hash-output stall cycles;883 accepted words include7 reset-aborted-prefix
words. Python matches5888 SHAKE bytes. These workload witnesses are not FPGA
Fmax or system throughput. The main top is unchanged;no new synthesis/PPA.

## Stage5A process-unit observations

The isolated elastic unit observes10009 same-edge output/input replacements,
3505 blocked-input cycles and3511 held-output cycles in its10349-case workload.
It permits one coefficient per cycle when both ends are ready. These observations
do not establish FPGA Fmax or full-polynomial/Dilithium throughput. The unit is
now connected through Stage5G above;its banked PPA remains unmeasured.

The candidate four-slot KeyGen schedule in MEMORY_MAP.md requires16 forward
transforms at level2 if s1 is regenerated for each row,instead of4 with cached
transforms. This tradeoff is not adopted yet. Record its impact when deciding
the full-controller memory schedule;do not hide it in a compute-only comparison.

## Current boundary:Stage4 all three engines through memory

The top is now keccak_sampler_ntt. No Stage4 synthesis/fit has been run;there
is no current integrated placed-area,Fmax,slack or RAM-packing claim. Existing
output_files reports still describe the earlier Stage2 producer-only top.
The6.757ns benchmark constraint is unchanged. PPA optimization stays deferred.

Stage4 checks4096 sampled values,9745 DMA loads,7713 NTT outputs and11776
stored reads.30 complete result polynomials account for7680 NTT outputs;
33 additional outputs were accepted before a reset. The other abort targets
were during loading and computation.24 full-pool wait cycles,188 completion
stall cycles,699 read-response stall cycles and33 source-lock observations
are functional witnesses,not a throughput rate. All earlier Stage2/3 cycle
observations remain scoped to their own test workloads.

The initial DMA waits for each synchronous response/engine acceptance before
requesting the next coefficient. NTT compute/sampling are scheduled serially.
Its latency/throughput must not be equated with the standalone engine's no-gap
wrapper numbers or the internal four-butterfly issue rate. Wider/pipelined DMA,
more banks and overlap are later measured optimization options.

Relocated standalone NTT correctness was refreshed. Its original branch PPA
under quartus/ntt/results is historical;no fresh relocation fit was requested.

## Historical source boundary:Stage3 Keccak+sampler+memory

The Stage3 project selected keccak_sampler_memory with four logical
polynomial slots. Stage3 has source/Python functional results only;there is no
fresh Stage3 fit,Fmax,placed-area,slack or RAM-inference claim. Timing/resource
measurements below describe the prior Stage2 top and are historical.

The Stage3 workload checks23180 writes (22528 complete values+652 aborted-prefix
values),22528 readbacks,88 releases and99 rejected reads. It observes8 full-pool
blocked command cycles,1321 held-response cycles and170 concurrent read/write
cycles. These are functional witnesses,not throughput benchmarks. The configured
payload is23552 logical bits/2944 bytes;FPGA RAM packing is not measured yet.

## Historical measured boundary:Stage2 Keccak+sampler

The previous Stage2 project synthesized the real Keccak+sampler helper,
not a complete Dilithium accelerator. The project grows with the
controller,memory,NTT and process blocks. The user selected an initial148MHz
target:6.757ns,unchanged. The first combined fit is complete:129.18MHz worst Fmax and-0.984ns setup;
the requested148MHz timing target is NOT met.

Current main trial8:137.74MHz worst Fmax,-0.503ns setup,+0.157ns hold and11293
placed ALMs. Structural guards pass. On2026-10-20 the user stopped timing
optimization in favor of functionality-first integration. Fmax,area and
throughput optimization follow correct full-operation outputs;the timing miss
does not block Stage3 memory. The initial fit table below is historical.

Do not sum standalone module area or substitute the148MHz target for fitted
Fmax. All resource headlines use actual placed ALMs. Physical data I/O are
virtual/excluded from this internal benchmark;board timing is not closed.

## Functional-workload cycle observations

`sim/dilithium/stage2_jobs.csv` records104 jobs with case/ID/core/mode/param,
abort flag,and clock indices for command acceptance,first SHAKE beat accepted,
first sampler beat accepted,first/last coefficient,source stop and retirement.
The focused testbench has a6757ps rising-edge interval. Below are the22
successful jobs in each mode from this paired,stalled,boundary-length workload.

| Mode | Command acceptance → last coefficient | Command acceptance → first SHAKE beat accepted |
|---|---:|---:|
| Matrix A |750–1117 cycles|See stage2_jobs.csv|
| Secret |507–909 cycles|See stage2_jobs.csv|
| Mask |744–1185 cycles|See stage2_jobs.csv|
| Challenge |981–1921 cycles|See stage2_jobs.csv|

These ranges include deliberately varied input lengths/source gaps,peer work,
and output/status stalls. They are not isolated sampler compute latency or a
continuous-throughput benchmark. Negative timestamp fields mean the event was
not reached before an error/abort. Completion rates must later be measured
under a specified workload,with first-to-last intervals and pipeline overlap
boundaries. No full KeyGen/Sign/Verify latency is claimed.

Current functional observations:drops99,bridge cancellations140,blocked hash
cycles33316,dual-owned cycles37383,and upstream-retirement waits293. The queue
was full for34198 observed cycles,with128 simultaneous push/pop events. These prove
the exercised control paths;they are not coverage percentages or throughput.

## Initial synthesis record

Combined settings: Cyclone V5CGXFC7C7F23C8,Quartus25.1std,seed1,HIGH PERFORMANCE
EFFORT,physical register retiming OFF. Both engines' accepted RTL remains
unchanged. The new scalar SHAKE-mode decode replaced a port expression that
Quartus interpreted as an implicit net;that initial diagnostic run was stopped
and excluded. The current full fit uses the corrected source.

The combined TimeQuest helper preserves original sampler payload/register
guards with hierarchy-qualified names. Current structural guards pass,while timing misses the target as recorded below. Pipeline/area
optimization was attempted before memory. That ordering is now superseded by
the user's functionality-first decision;the benchmark constraint stays intact.

## First combined fit ? functional PASS,timing target OPEN

| Metric | Initial complete Stage2 fit |
|---|---:|
| Actual placed ALMs |11059|
| Registers |7396|
| Combinational ALUTs |16025|
| M10K / DSP |1 /0|
| Slow85 / Slow0 Fmax |129.18 /134.16MHz|
| Requested period |6.757ns (about148MHz),unchanged|
| Worst setup slack |?0.984ns|
| Worst hold slack |+0.166ns|
| Slow85 / Slow0 setup TNS |?1118.959 /?493.897ns|
| Hold TNS |0 at all four corners|
| Minimum pulse-width slack |+1.202ns minimum;positive at all four corners|
| Accepted sampler register guards |PASS,including original64-bit secret banks,140-bit commit payload and128 sign bits|

Quartus full compilation succeeds,but its timing-requirements warning is real.
The critical path is Keccak core1 absorb_block_full ? state_array registers,
with7.468ns data delay at the Slow85 corner;about78% of that path delay is
interconnect. See critical_paths/slow_85C_setup.rpt. It is not a sampler oracle
mismatch. The combined project has physical register retiming OFF,whereas the
standalone Keccak project enabled it. Retiming/placement/fanout are candidates
for a controlled review;their individual contribution is not yet measured.

This is an initial subsystem baseline,not an accepted148MHz implementation or
full-system PPA result. No target was relaxed. The earlier choice to close timing
before memory is superseded by the functionality-first decision above.
Initial immutable evidence:stage2_subsystem_initial.zip
and its SHA256 sidecar under evidence/.

### Timing trial1:settings only,no measured gain

Keep global retiming OFF,enable it only for hash hierarchy,and explicitly
disable it for sample hierarchy. Enable combinational physical synthesis,
register duplication and maximum router timing effort as in standalone Keccak.
No RTL,clock period or functional workload changes. The completed fit exactly
reproduces11059 placed ALMs,129.18MHz and-0.984ns setup. Original sampler
register guards PASS. Retiming runs but reports0ps estimated improvement;
this trial did not close timing.

### Timing trial2:lane-qualified Keccak absorb writes,rejected

Only src/keccak/keccak_core.sv changes:an absorbed64-bit word writes its
destination lane;the other lanes retain their state. Permutation and padding
still update the full state at the same edge. This removes absorb-dependent
control from a shared1600-bit write enable without adding a cycle. The initial
accepted Keccak revision remains preserved in the immutable import archive.

Focused104-job source/Python checking and12 checker fault gates PASS with23081
exact values. All104 workload cycle-witness rows match the initial snapshot
byte-for-byte. The full standalone Keccak regression passes904 UVM transactions
plus all dual suites,with zero UVM errors/fatals. After a declaration-only
Quartus syntax correction,the exact current source again passes the104-job
check;all6364 published NIST outputs match exactly. The fit worsens to11758
placed ALMs,7393 registers,16236 ALUTs,125.20MHz worst Fmax and-1.230ns setup;
hold+0.156ns. Slow0 Fmax127.80MHz. Setup TNS is-1010.976/-632.800ns at slow85/0;
all hold TNS remains0. Keccak3200-bit state and original sampler guards PASS.
The critical path moves to Keccak permutation data,with79% routing delay.
This implementation is rejected and restored to the original state-write form.

### Timing trial3:global routing for the original state enable,rejected

Restore original whole-state writes and name their existing combined enable
`state_array_enable = init_wr_en || state_array_wr_en`,with a keep attribute.
The QSF requests a dedicated global route for this1600-register data enable
inside each core. No generated clock or new cycle is introduced;the real clk
and6.757ns constraint are unchanged. Verify actual global routing in the fitter
report,all3200 state bits and the accepted sampler register guards.

Current-source104 jobs/23081 values and12 checker fault gates PASS;all104 cycle
rows match the initial snapshot exactly. Full904-transaction Keccak regression
plus dual suites PASS,zero UVM errors/fatals. Fitter confirms two dedicated
global control networks,each with1600 fanout. All6364 published NIST outputs
match that trial's source. Final fit:11256 placed ALMs,7402 registers,16081 ALUTs,
93.59/94.63MHz slow85/0 Fmax,setup-3.928ns,hold+0.155ns;slow85/0 setup TNS
-12479.887/-11921.846ns,all hold TNS0. Original Keccak/sampler guards PASS.
Dedicated routing increased control arrival delay;this trial is rejected.
Batch Keccak regressions now
omit recursive waveform recording;GUI waveform recording is unchanged.

The [Cyclone V handbook](https://cdrdv2-public.intel.com/666995/cv_5v2-683375-666995.pdf)
describes using global routing for high-fanout controls including clock enables.
This trial changes routing of a synchronous data enable,not the clock definition
or timing exceptions.

### Timing trial4:original RTL,local clock-enable mapping change

Restore the exact initial RTL(source vector token matches the initial snapshot).
Disable AUTO_CLOCK_ENABLE_RECOGNITION only on hash state_array registers;leave
sampler mapping unchanged. Analysis confirms3200 fewer clock-enable registers:
6153 initially versus2953 now. This selects feedback multiplexers for the two
Keccak states;it adds no clock,cycle or protocol change. Fresh104-job checking/
23081 values and12 checker fault gates PASS. Final fit:12366 placed ALMs,7395
registers,16558 ALUTs,130.92/130.79MHz slow85/0 Fmax;worst setup-0.889ns,
hold+0.146ns. Slow85/0 setup TNS-198.974/-152.546ns;hold TNS0 everywhere.
Original sampler and3200-bit Keccak state guards PASS. This is not timing
closure;its area increase is not accepted as a final design. Critical path is
offset_count through request/start/init decoding to Keccak state synchronous clear.

The [Quartus Standard mapping guide](https://docs.altera.com/r/docs/683283/18.1/design-compilation-user-guide-quartus-prime-standard-edition/controlling-clock-enable-signals-with-auto-clock-enable-replacement-and-direct_enable?contentId=lEZsrgY7vUwiSGtgN95~0Q)
documents this per-register option and its feedback-mux implementation.

### Timing trial5:predecoded launch-offset ready,still open

Retain trial4 mapping while registering the offset-count-zero decision one
cycle ahead. Reset/zero-offset launches set ready;loading a nonzero interval
clears ready;decrementing count1 sets ready for the following zero-count cycle.
The26-cycle launch gap is unchanged. A source invariant checks the flag against
the counter,and a fitted-register guard requires the new flag to survive mapping.
104 focused jobs/23081 exact values and12 checker fault gates PASS;all104 cycle
witness rows match the initial snapshot. Full Keccak904-transaction regression
plus all dual suites PASS,zero UVM errors/fatals. Core SHAKE RTL remains exactly
the initial source whose6364 published NIST outputs passed;only the wrapper's
countdown flag changed. Fit:12356 placed ALMs,7396 registers,16574 ALUTs,
129.27/131.32MHz slow85/0 Fmax,setup-0.979ns/hold+0.164ns. Slow85/0 setup
TNS-205.562/-114.946ns;hold TNS0. Original state/payload guards and the new
offset flag guard PASS. The worst path now crosses sampler generated/source_stop
through bridge discard/ready into Keccak squeeze/permutation counter control.

### Timing trial6:two-slot registered-credit bridge,still open

Keep trial5's local state mapping and offset flag. Replace the one-slot bridge
and combinational ready chain with a two-slot queue. Upstream room depends only
on registered occupancy;draining-context bypass depends only on registered
drain state. Immediate sampler source_stop still cancels that context's head
offer;status retirement checks both queue slots. Simultaneous push/pop remains
possible,without changing external ports or either engine's processing stages.

Fresh104-job source/Python PASS:88 complete,8 expected errors,8 reset aborts,
23089 checked values(22528 complete+561 aborted prefixes),24 mode/param/core
combinations;12 checker corruptions rejected. Four reset phases reach both
owned contexts;phase0 now requires a full two-slot queue. Full-queue cycles34198
and simultaneous push/pop128 are observed. Stops follow discarded release
handshakes;all public offers remain stable under stalls.

This deliberately stalled workload finishes at retirement clock48525 versus
48911 initially. Some individual latencies increase and others decrease due
to changed queueing/peer/stall phases;this is not a sustained-throughput claim.
Command-to-last-output ranges:A750-1117,secret507-909,mask744-1185,challenge
981-1921cycles. Clean trial6c fit:12542 placed ALMs,7581 registers,16711 ALUTs,
one M10K/1024 bits,zero DSP. Slow85/0 Fmax134.77/134.17MHz;worst setup-0.696ns,
hold+0.150ns. Slow85/0 setup TNS-105.438/-59.416ns;all hold TNS0,min pulse-width
slack+1.202ns. Original sampler/Keccak guards,offset flag and all256 queue
payload bits PASS. The remaining worst path is Keccak state-to-state permutation
logic,7.221ns data delay at slow0. Timing remains open.

The first trial6 mapping inferred block RAM for the two-entry payload. It was
interrupted;the first stop failed and a replacement briefly overlapped it.
Both task-owned process trees were then terminated and the generated db and
incremental_db directories cleared. Neither interrupted run is a PPA result.
The active trial6c is a clean full build with ramstyle="logic" on the payload;
synthesis confirms only1024 block RAM bits(the original sampler Ball memory).
The fitted helper must retain all256 bridge payload registers as well as the
original Keccak/sampler registers. No polynomial memory has been added.

### Timing trial7:predecoded absorb-ready,original compact mapping

Remove trial4's clock-enable suppression to restore the original smaller state
mapping. Add one absorb-ready flag per core,maintained from accepted message
words,rate-boundary events and final permutation rounds. An invariant requires
it to equal STATE_ABSORB && !absorb_block_full && !msg_received. The wide write
uses that flag with input valid;the permutation mux uses the current state
directly. No extra absorb/permutation cycle or interface change is introduced.

104 jobs/23089 exact values and12 checker faults PASS;all104 cycle rows match
trial6 byte-for-byte. The fitted helper requires both new flags to survive.
Full904-transaction Keccak regression plus dual suites PASS,zero UVM errors/
fatals. All6364 captured outputs match the published NIST vectors on both cores.
Fit:11204 placed ALMs,7570 registers,15995 ALUTs,1M10K/0DSP. Slow85/0 Fmax
124.72/128.50MHz;setup-1.261ns/hold+0.162ns. Slow85/0 setup TNS
-1618.286/-912.227ns;all hold TNS0. All register guards PASS. The worst path
starts in sampler active_r,through the command-ready mux,into Keccak state
initialization. The permutation-only path is also late(-0.891ns at slow85).

### Current functional implementation:trial8 ownership-qualified command ready

An unowned context is sampler-inactive:reset clears both,commands set both,and
ownership releases only with the external sampler-status handshake. Thus the
extra sampler_job_ready condition is redundant beside !owned. Remove that
combinational feedback from request_valid/job_ready,while checking both
sampler_active implies owned and accepted-command implies sampler_job_ready.
Atomic starts still use the same common handshake and core assignment.

104 jobs/23089 values and12 checker faults PASS;all104 cycle rows match trial7.
Keccak RTL is unchanged from the904-transaction/6364-NIST passing trial7.
Seed1 and an isolated seed2 fit use identical RTL,device,clock and settings.
Both compiles have finished. The main seed1 build reports11293 placed ALMs,
7557 registers,15970 ALUTs,one M10K/1024bits and zero DSP. Slow85/Slow0 Fmax
is138.06/137.74MHz;worst setup is-0.503ns and worst hold+0.157ns across four
corners at6.757ns. Setup TNS is-147.307/-47.642ns at the two slow corners;
hold TNS is zero at all four corners. Keccak/sampler register guards pass.
Evidence:quartus/dilithium/output_files/dilithium.fit.rpt,
dilithium.sta.rpt and stage2_timing8_guard.log. The isolated seed2 experiment
is not selected. Further PPA work is deferred;retain the verified functional
source for Stage3 integration.
