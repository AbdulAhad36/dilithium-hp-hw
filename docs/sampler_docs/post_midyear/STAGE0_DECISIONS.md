# Stage 0 baseline decisions

Date: 2026-10-16. Status: Stage 0 contract frozen; no RTL results at this gate.

This record accompanies SPECIFICATION.md and the canonical SAMPLER_PLAN.md.
The 128-to-64 adapter, tagged context selection and serial coefficient sink
are baseline compatibility decisions. They are not measured improvements.

| Decision | Resolution |
|---|---|
| A01 width | One 128-bit holding register, two ordered up-to-64-bit chunks; no native 128-bit sampling yet |
| A02 contexts | Two context banks selected by accepted tag; no fixed 15/17-beat schedule |
| A03 identity | 16-bit job ID plus core slot; one live job/slot until acknowledged status and source drain |
| A04 state | Residual bytes/bits, collector, generated/emitted count and mode-specific state per job |
| A05 flow | Bounded collectors, reserved capacity, held output group during stall |
| A06 output | Tagged canonical 23-bit coefficients; four-result matrix groups; inter-job group arbitration |
| A07 routing | A is already NTT-domain; future adapter demultiplexes job output to storage/NTT |
| A08 refill | Existing Keccak output_len_i=0 continuous mode with stop_i; finite-source last explicitly reports exhaustion |
| A09 completion | Exactly 256 accepted outputs for OK; surplus final input discarded; error invalidates partial polynomial |
| A10 unknown details | Our explicit collector/arbitration control is reconstructed, not authors' RTL |
| A11 timing | No constant-time/security claim; record actual input/stall dependence and failure behavior |
| A12 reset/errors | Synchronous reset cancels both slots; typed errors; independent per-job cancel deferred |

Read SPECIFICATION.md for exact ports, ordering and lifecycle. Source contracts
were inspected at keccak_v2 fe54a78 and ntt_v2 577a34b using git show; no module
RTL was imported. Keccak already supports continuous XOF, resolving the refill
investigation without a speculative new Keccak extension. Integration must still
verify the stop/drain/reuse sequence against actual source RTL.

Stage 0 gate: published/reconstructed/compatibility boundary and initial ports
documented. Next: Stage 1.1 matrix A implementation with main-UVM smoke checking.

## Mask reconstruction detail - Stage 1.3

The paper does not disclose the full Mask pipeline. The selected baseline uses
one shared up-to-four-field extractor per accepted 64-bit chunk, 19 saved bits
and a count per context, and four-result output groups. This is an explicit
reconstruction/formatting choice, not a claimed LightHD improvement. Modes 0/1/2
were implemented at Stage 1.3; challenge follows in Stage 1.4. Exact mask unpacking follows the
final FIPS bit order and gamma1 range; user explanation bytes are not NIST vectors.

## Challenge reconstruction detail - Stage 1.4

The paper names distributed RAM without the complete controller schedule. The
baseline therefore uses one shared sequential engine with a 512x2-bit memory,
separate per-context sign/index state, serial 256-entry job initialization,
synchronous indexed read and two ordered writes per accepted position. Separate
copy/sign writes handle j==i without a special combinational bypass. Completed
polynomials drain through the existing four-result collector/serializer. No
mutable challenge coefficient streams out before shuffle completion.

The 128-bit adapter retains a challenge beat and consumes one byte per engine
handshake. Source stop occurs at shuffle completion; finite-source exhaustion is
checked after the final byte's dependent writes. Error/reset cancels engine work;
new jobs clear their storage before reading it. These are necessary baseline
reconstruction and compatibility choices, not measured improvements. The shared
controller can stall one challenge while initializing/draining another. Record
that scheduling cost and verify actual RAM inference in Stage 3.
