# LightHD NTT specification

**Stage 4, 2026-10-10.** Active RTL: `src/ntt_LightHD/ntt_engine.sv` and its
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

## Verification and implementation limits

Main UVM `tb_uvm/tb_uvm_ntt_LightHD/tb_top.sv` checks outputs with the independent
SV model and checks observed operands, twiddles, FIFO writes/routing, reset and
stream flow before awarding coverage. Current regression is 118/118 passing
jobs and fourteen implemented covergroup types at 100%. This is not exhaustive
input verification or 100% raw code coverage; see [COVERAGE.md](COVERAGE.md).
Separate output capture and Python comparison are in [FIPS204_NTT.md](FIPS204_NTT.md).
These are independent FIPS-derived cases, not NIST-published standalone NTT vectors.

Implementation target is Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite,
5 ns clock. Setup timing is still open. Current fitted evidence and retained
iterations are in [the plan](POST_MIDYEAR_VERIFICATION_PLAN.md) and
`quartus/ntt_LightHD/results/`. No board pinout, current-RTL netlist simulation,
or Keccak/sampler integration result is claimed. See the plan for Stage 5/6 gates.
