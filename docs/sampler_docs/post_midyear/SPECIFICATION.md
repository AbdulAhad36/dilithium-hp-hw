# Sampler specification

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

Stage 5 implementation verification passed on 2026-10-19 for distinct current
post-synthesis and post-fit functional netlists; see SAMPLER_NETLIST_RESULTS.json. No board, integration or security
signoff is claimed. Native 128-bit processing is not active: accepted 128-bit
beats issue ordered 64-bit chunks internally.

## Current architecture

Input capture → fine/coarse/carry preparation → extraction → local compaction →
packed/admit → aligned commit → per-context collector → registered context read
→ shared formatted output. Each context has 32 collector entries; pending tokens
reserve capacity and quota before issue. Reset clears ownership, not every
unowned payload bit. Errors drain outstanding ownership before status/reuse.

- Matrix A extracts little-endian three-byte candidates, clears bit 23, rejects
  values at least q=8380417, and preserves residual bytes per context. Full
  64-bit chunks produce 2/3/3 candidates. Successful output is already NTT-domain.
- Secret sampling uses four 16-bit lanes and low-first nibbles, eta=2 for
  parameters 0/2 and eta=4 for parameter 1. Stable compaction preserves order.
  Secret values remain four-bit encoded in collectors and become canonical
  23-bit residues at shared output formatting.
- Mask expansion consumes contiguous 18-bit fields for parameter 0 or 20-bit
  fields for parameters 1/2. It maps t to gamma1-t modulo q, with no rejection.
  Exactly 576/640 input bytes describe a polynomial. Shared A/mask alignment
  uses 131-bit fine and 147-bit registered streams; carry remains context-owned.
- The mask converter stays before packing and uses one 20-bit subtract with
  q=2^23-8191. Lower-half base is gamma; upper-half base is gamma-8191, with
  high output bits 111. t=gamma is explicitly zero. Six main-UVM boundary jobs
  cover both widths, contexts and modular-borrow points.
- Four rotated wide commit slots share storage with 16 four-bit secret slots,
  for 140 payload bits. Registered row masks own every collector write. Stable
  context mode selects challenge/ordinary data; tags never infer job ownership.
- Two 64-bit secret payload stages and all 128 challenge sign bits must survive
  fitting. report_paths.tcl checks original payload/reservation register guards.

### Challenge / SampleInBall

sampler_ball.sv contains one shared sequential controller and a 512-entry,
two-bit memory: 256 entries per context, encoding zero, +1 and -1. A new
challenge clears its 256 entries serially; memory contents have no bulk reset.
Both contexts retain their own 64 sign bits, sign-byte count, position counter,
initialization state and done/exhausted flags. The first eight bytes supply
little-endian signs, consumed least significant bit first. Parameter encodings
0/1/2 select tau=39/49/60, hence starting positions 217/207/196.

A candidate byte j is rejected if j>i. An accepted position performs a synchronous
read of old c[j], a separate copy write c[i]=old c[j], then a sign write c[j]=+/-1.
Only acceptance advances i and consumes a sign. The separate writes preserve
j==i semantics and repeated-position read-after-write dependencies. No coefficient
is emitted until the complete shuffle is immutable. A read request then transfers
one stored coefficient into the existing collector; challenge output groups
contain four canonical 23-bit results, including zeros.

CLEAR, COPY, SIGN and READ_OUT share the memory controller. Initialization and
completed-output reads can stall another challenge's byte processing. The shared
128-bit holding adapter consumes challenge bytes one at a time and retains the
remainder while the controller is busy. This bounded baseline deliberately does
not unroll dependent indexed updates. The memory uses synchronous reads, with writes suppressed during reset/abort.
Each job clears its own 256 entries before use. Finite source exhaustion before
the shuffle completes reports EXHAUSTED; no challenge polynomial is emitted.
source_stop asserts at shuffle completion. A new job cannot reuse old memory.

## Interface contract

All transfers occur on rising clk when valid and ready are both asserted.
Reset is active high and synchronous. All command/data/response payloads must
remain stable under stall; reset explicitly cancels both jobs and pending output.

| Port | Direction | Bits | Meaning |
|---|---|---:|---|
| clk, rst | input | 1 each | Clock and synchronous reset |
| job_valid_i / job_ready_o | input/output | 1 each | Descriptor transfer |
| job_core_i | input | 1 | Context slot, matching assigned Keccak core |
| job_id_i | input | 16 | Controller's polynomial identifier |
| job_mode_i | input | 2 | 0=A, 1=secret, 2=mask, 3=challenge |
| job_param_i | input | 2 | 0=ML-DSA-44, 1=65, 2=87; 3 invalid |
| input_data_i | input | 128 | Consecutive SHAKE bytes, earliest in bits 7:0 |
| input_bytes_i | input | 5 | Valid contiguous low bytes, 1..16 |
| input_core_i | input | 1 | Context for the whole beat |
| input_last_i | input | 1 | Optional finite-source exhaustion after this beat |
| input_valid_i / input_ready_o | input/output | 1 each | Source transfer |
| output_data_o | output | 23 | Canonical coefficient in 0..q-1 |
| output_core_o, output_id_o | output | 1,16 | Result context/job |
| output_index_o | output | 8 | Polynomial index 0..255 |
| output_last_o | output | 1 | Index 255 |
| output_valid_o / output_ready_i | output/input | 1 each | Coefficient transfer |
| status_valid_o / status_ready_i | output/input | 1 each | Completion/error transfer |
| status_core_o, status_id_o | output | 1,16 | Completed/failed descriptor |
| status_code_o | output | 3 | 0=OK, 1=source exhausted, 2=unsupported mode, 3=invalid parameters, 4=invalid byte count |
| active_o | output | 2 | Slot owned until its status is accepted |
| source_stop_o | output | 2 | Stop producing for this slot; held until status acceptance |

Two descriptors may be live, one per slot. Never reuse a slot until its status
has been accepted AND the integration controller has stopped/drained its old
Keccak source. A core ID is not a globally unique job ID. No independent cancel
command is exposed initially: coordinated reset aborts both jobs. Per-job cancel
needs a separate future protocol decision and tests.

The input adapter holds at most one 128-bit beat and presents its low bytes
first, then its high bytes. It retains tag and last across both chunks. Per-slot
collectors now hold up to 32 results to support a secret chunk appending up to
16 results when at most 16 are already buffered. All non-challenge modes reserve space for pending tokens within the same32
entries; matrix chunks append at most three results. Collector and group
counters were widened accordingly; this is required secret baseline capacity. This is minimum bounded elastic storage, not a deep
performance FIFO. Output arbitrates groups of four (A/mask/challenge) or 16 (secret);
within each job all coefficients remain ordered. A group stays selected during
backpressure. Do not wire interleaved jobs blindly into a single NTT polynomial:
the future destination adapter must demultiplex to tagged storage or restrict
job admission. No integrated throughput claim follows from this serial port.

Success is reported only after 256 accepted output coefficients. Sampling stops
when 256 values have been generated (challenge stops its source at shuffle completion); surplus bytes/candidates from its final
accepted beat are discarded, not transferred into another job. Error status may
follow a partial result prefix: the entire failed polynomial must be discarded
by the destination. An already offered output group drains before error status;
other pending coefficients are discarded. Stalled payloads remain stable until
accepted or reset, including when the job encounters an error. Invalid idle-source tags are
not accepted. Malformed valid-byte counts on an active source are accepted and
fail that job. No zero padding and no repeated SHAKE prefix on exhaustion.

## Keccak and NTT contracts inspected

Keccak branch fe54a782e3df9ed684dc960b0067b39ce323289d exposes tagged 128-bit
output with low-byte order, valid-byte count and ready/valid. Its core explicitly
defines output_len_i=0 as continuous output; stop_i is sampled in SQUEEZE.
Baseline integration uses continuous SHAKE and drives stop for a completed job.
The controller must handle stop acknowledgement, already offered data and
request reuse. A bounded stream uses input_last_i from a controller tracking its
requested length; Keccak has no equivalent last pin on this output port.
No live length-extension operation is required for the continuous strategy.

NTT branch 577a34b2fff19864cb16b490b7629ed211613000 accepts one 23-bit
canonical coefficient/beat, 256 beats/load with separate operation command.
Matrix A is already NTT-domain and routes to operand storage/PWM, not forward
NTT. Small secrets can use ordinary or eligible Pre-NTT; the existing Pre path
already owns its first-stage transformation. Sampler does not apply it again.

## Timing and limits

Permanent target 6.500 ns; seed 1; HIGH PERFORMANCE EFFORT; physical register
retiming OFF. Setup/hold/TNS and Fmax use fresh multicorner TimeQuest results.
Data pins are virtual and excluded from the standalone internal timing scope.
No physical I/O, board, side-channel or security signoff is implied.
