# LightHD NTT specification

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


**Updated after Stage 5, 2026-10-11.** Active RTL: `src/ntt/ntt_engine.sv` and its
local dependencies. This is an independent reconstruction of the published
four-butterfly, three-FIFO architecture; the authors' RTL was not available.

## Mathematics and operations

Polynomial length is 256, modulus q = 8,380,417, coefficient width 23 bits.
Inputs and outputs use ordinary canonical residues 0..q-1, not Montgomery
encoded coefficients. Forward twiddles are derived from root 1753 and the
Dilithium bit-reversed exponent convention. Small negative secrets are sent
as residues, for example -1 as q-1.

| `op_i` | Operation | Accepted input coefficients | Output |
|---|---|---:|---|
| 0 | NTT | 256 for A | 256 forward-transform coefficients |
| 1 | INTT | 256 for A | 256 inverse-transform coefficients, including 1/256 scaling |
| 2 | PWM | 256 for A, then 256 for B | 256 products A[i]*B[i] modulo q |
| 3 | Pre-NTT | 256 bounded-secret coefficients | Same forward result as ordinary NTT |

PWM inputs must already be in the transform domain for polynomial multiplication.
A coefficient-domain polynomial product requires NTT(A), NTT(B), PWM, then INTT.
Pre-NTT applies only when every coefficient represents a value in [-4,4]. Its
simulation guard rejects other inputs; synthesized hardware requires the
sampler/controller to guarantee eligibility. There is no hardware rejection flag.

## External interface

| Port | Direction | Bits | Meaning |
|---|---|---:|---|
| clk | input | 1 | Rising-edge clock |
| rst | input | 1 | Active-high asynchronous reset, aborts the current job |
| start_i | input | 1 | Request sampled when idle; send a pulse |
| op_i | input | 2 | Operation captured on the accepted request |
| busy_o | output | 1 | Loading, computation or output is in progress |
| done_o | output | 1 | One-clock completion pulse after the final output is accepted |
| s_tdata | input | 23 | Next coefficient, index 0 through 255 |
| s_tvalid | input | 1 | Producer presents a coefficient |
| s_tready | output | 1 | Engine is accepting coefficients |
| s_tlast | input | 1 | Present for interface compatibility; RTL ignores it |
| m_tdata | output | 23 | Next result coefficient, index 0 through 255 |
| m_tvalid | output | 1 | Result coefficient is available |
| m_tready | input | 1 | Receiver accepts a result |
| m_tlast | output | 1 | Asserted with output coefficient 255 |

A transfer occurs only on a rising edge with valid AND ready. The producer
must hold its beat until accepted. The receiver may stall; output data/last
remain stable until accepted. Input gaps are allowed. The engine counts 256
accepted coefficients per operand, rather than relying on input `s_tlast`.
Requests while busy are not queued. One complete job is processed at a time:
load A (and B for PWM), compute, then emit the result. The wrapper cannot
load the next polynomial while it computes the current one.

Reset cancels the job and clears control/FIFO/tag state. FIFO and ROM memory
contents are not required to be erased; cleared occupancy/valid state prevents
old contents from being used as live data. Main UVM verifies cancellation and
recovery at nine observed points with a different fresh job.

## Internal architecture

Four radix-2 butterflies process four pairs per issue clock.
Combined FIFO/coefficient one-hot selectors are registered at FIFO read launch;
a masked OR selects each operand before the existing butterfly input register.
This replaces serial word/lane muxes without adding pipeline latency. Three coefficient
FIFOs hold 32, 32 and 16 words, each 4*23 = 92 bits. A separate 64-word store
holds the second PWM operand. Forward uses CT butterflies; inverse uses GS
and modular halves at each stage, eliminating a separate final scaling pass.
Pre-NTT uses a nine-entry small-secret lookup for the first stage, decoded
from the sign bit and low three bits for its contracted -4..4 residue domain.
FIFO routes use explicit stage/issue-bit decoding and direct read enables.
Every initialized twiddle ROM entry is in [1,q-1]. Inverse twiddles are Q-tw;
the redundant zero guard is removed without changing the read latency.
Butterfly modular subtraction computes raw a-b and corrected a-b+q in parallel;
the corrected carry-save candidate compresses a, the 24-bit complement of b,
and q+1. Borrow selects the canonical result. The unchanged Pre helper uses
the equivalent q plus injected-one form; see `COVERAGE.md` for the proof.
Inverse kept-sum reduction uses S+8191: bit23 selects the canonical S-q
candidate. Five actual GS sum thresholds are checked on all four lanes in main UVM.

Multiplier latency is five clocks; butterfly latency is seven; FIFO read,
registered butterfly inputs and registered writeback bring issue-to-return
latency to ten. The multiplier stages are product, first-fold carry-save
compression, first-fold carry propagation, fold2 and fold3 with parallel
canonical correction; its intermediate bounds and exact
reduction argument are documented in `COVERAGE.md`. There are 256 issue clocks for NTT/INTT, 64 for PWM and 224
for Pre-NTT after the shortcut. Measured start-to-done latency also includes
pipeline/start/drain control; see [THROUGHPUT.md](THROUGHPUT.md).

The selected write path predecodes each FIFO's A/B result choice in three
control flops alongside result_a/b. Return data selection uses these bits;
write enables and load/Pre/compute priority are unchanged. FIFO3 never receives
B in legal routes, so its B-select is constant zero. This adds no operation clock.
The wrapper prepares index+1 throughout E_TX_VALID; it issues a read only when
the current output is accepted and is not final. Every enabled address remains
identical; inactive addresses are not consumed. First output and stalled data/
last behavior are unchanged. See the measured selection history in the plan.

## Verification and implementation limits

Main UVM `tb_uvm/tb_uvm_ntt_LightHD/tb_top.sv` checks outputs with the independent
SV model and checks observed operands, twiddles, FIFO writes/routing, reset and
stream flow before awarding coverage. Current regression is 620/620 passing
jobs and 22 covergroup types at 99.51% average (minimum 92.36%). This is not exhaustive
input verification or 100% raw code coverage; see [COVERAGE.md](COVERAGE.md).
Separate output capture and Python comparison are in [FIPS204_NTT.md](FIPS204_NTT.md).
These are independent FIPS-derived cases, not NIST-published standalone NTT vectors.

Implementation target is Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite.
The user approved an operating clock near current Fmax: nominal 148 MHz.
The requested 6.756757 ns period is represented by TimeQuest as 6.756 ns
(148.02 MHz). The permanent `ntt.sdc` selects 5 ns during synthesis/fitting and the approved
operating constraint during final Timing Analyzer execution. In Quartus open
`quartus/ntt/ntt.qpf`, revision `ntt`, then **Processing > Start Compilation**.
No SDC edits are required. Optional CLI: `quartus/ntt/build_operating.ps1`.
See the Quartus README for compiler-stage labels and report locations.
Fresh full rebuild passes all 20 operating checks with zero TNS: worst setup/hold/
pulse +0.111/+0.152/+1.201 ns. Worst Fmax 150.49 MHz, 2,475 ALMs, 2,414 registers,
5 DSPs, 20 M10Ks. The 200 MHz benchmark remains in `ntt_benchmark_200mhz.sdc`;
it is unmet. External I/O is false-pathed; closure covers standalone internal
timing, not board/sampler timing.
Current fitted evidence and retained iterations are in
[the plan](POST_MIDYEAR_VERIFICATION_PLAN.md) and
`quartus/ntt/results/`. Board pinout/validation and Keccak/sampler
integration remain pending. Current functional netlist results are below.

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

Run `do ntt/run_uvm.do` from `sim/`; require `NTT EXPANDED UVM PASS`.
Default simulator seed 20261011; new flow seed 439041101. Current log:
`uvm_expanded.log`; main UCDB/raw-report names are unchanged. Exact evidence is
in `experiments/ntt_stage4/lighthd_expanded_coverage_checkpoint/`.
RTL/golden, fitted timing/resources and cycle counts are unchanged. Stage 5
retains its archived 117-job netlist results; only its checker compatibility
self-test was rerun with the updated UVM. No 620-job full-netlist result,
FPGA result, Stage 6 integration or commit is claimed.
