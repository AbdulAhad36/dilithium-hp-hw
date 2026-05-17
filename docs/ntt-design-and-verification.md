# The NTT Engine — Design and Verification Report

**Project:** Hardware Implementation of CRYSTALS-Dilithium (ML-DSA, FIPS 204)
**Branch:** `2_ntt`
**Author:** Muhammad Abdul Ahad
**Status:** LIVING DOCUMENT — started 2026-05-18, updated as the engine is built
**Last updated:** 2026-05-18

---

## About this document

This is the design-and-verification report for the Number-Theoretic-Transform
(NTT) engine — the second module of the Dilithium hardware accelerator, after
the Keccak/SHAKE engine of branch `1_hashing`. It is written the same way as
the Keccak report: it states what other published designs achieve, what we
propose and why, what we build, the problems we hit, the results we measure,
and how we compare. It is updated continuously as the branch progresses — it
is intended to become the NTT chapter of the thesis.

---

## 1. Role of the NTT in CRYSTALS-Dilithium

Dilithium is built on polynomial arithmetic over the ring
**R_q = Z_q[x] / (x²⁵⁶ + 1)** with **n = 256** and the prime
**q = 8 380 417**. Every signing, key-generation and verification operation is
dominated by **polynomial multiplication** in this ring.

Schoolbook polynomial multiplication is O(n²). The NTT — a Fourier transform
over a finite field instead of the complex numbers — reduces it to
O(n log n):

```
a · b  =  INTT( NTT(a) ⊙ NTT(b) )
```

where ⊙ is coefficient-wise (point-wise) multiplication in the NTT domain.
Dilithium was *designed* to be NTT-friendly: q satisfies q ≡ 1 (mod 2n), so a
2n-th root of unity exists (**ζ = 1753**), and the negacyclic twist of the
ring x²⁵⁶ + 1 can be folded directly into the twiddle factors.

Profiling of published implementations (ParaPM 2026) shows the
**signature-generation phase is ~74 % of total execution time**, and that time
is dominated by the polynomial multiplications inside the rejection-sampling
loop. The NTT is therefore the single most performance-critical arithmetic
block in the whole accelerator — which is why it is the focus of this branch.

---

## 2. Background — How the NTT Works

### 2.1 Forward and inverse transform

For a polynomial a with coefficients a[0..n-1]:

```
NTT  :  â[i] = Σ_j a[j] · ζ^(...)   mod q
INTT :  a[i] = n⁻¹ · Σ_j â[j] · ζ^(-...)   mod q
```

In hardware the transform is computed stage-by-stage with **butterfly
operations**, exactly like an FFT. For n = 256 there are **log₂(n) = 8 radix-2
stages**, each stage applying 128 butterflies.

### 2.2 The two butterfly types

| Butterfly | Used for | Operation |
|-----------|----------|-----------|
| **Cooley-Tukey (CT)** | forward NTT | t = ζ·b; a′ = a + t; b′ = a − t |
| **Gentleman-Sande (GS)** | inverse NTT | a′ = a + b; b′ = ζ·(a − b) |

CT takes naturally-ordered input and produces bit-reversed output; GS does the
reverse. Using CT for the forward and GS for the inverse transform means the
bit-reversal cancels out — no explicit re-ordering pass is needed.

### 2.3 Modular reduction

Every butterfly contains one modular multiplication (a·b mod q). The choice of
reduction algorithm sets the critical path:

- **Barrett** — works for any q; needs one precomputed constant. Used here.
- **Montgomery** — fast, but requires operands in a transformed domain.
- **q-specific** — q = 2²³ − 2¹³ + 1, so 2²³ ≡ 2¹³ − 1 (mod q), enabling a
  shift-add reduction. Cheapest, but more error-prone to verify.

We start with **Barrett** for verifiability and revisit the q-specific path as
an Fmax optimisation later (see §8).

---

## 3. Related Work — What Others Achieve

We surveyed the NTT-relevant papers in `docs/refernce-paper-hw/`. Published
Dilithium NTT designs split into two architectural families.

### 3.1 Family A — Memory-based (iterative) NTT

Coefficients live in BRAM; butterfly units read/write each cycle via a
conflict-free address scheme.

| Work | Device | Architecture | Fmax | Notes |
|------|--------|--------------|-----:|-------|
| Aikata, TCHES 2022 | Artix-7 | 4 BFUs, **folding transform** (each BFU time-slices 2 layers), DIT-NTT / DIF-INTT, conflict-free BRAM | 96.9 MHz | NTT delay 296 cyc; NTT only ~6 % of LUTs, 8 DSPs |
| ML-DSA-OSH 2025 | UltraScale+ | **2×2 butterfly** (4 coeffs/cyc, 2 layers/cyc), Barrett, CT-NTT / GS-INTT | — | **Open-source RTL**, directly comparable |
| Area-Time Efficient 2025 | Versal Premium | **2×2 butterfly** (2 stages/cyc), Barrett in each datapath, conflict-free memory + address resolver | **328 MHz** | Best Fmax + ATP; argues 1-stage/cyc "underutilises the pipeline" |
| EMINEM 2025 | Kintex US+ | **Radix-4 / mixed-radix**, 8 RAM banks cross-bank-writeback, Montgomery | 324 MHz | Dilithium n=256: **271 cycles, 1552 LUT / 6 DSP** — best efficiency |

### 3.2 Family B — Pipelined / streaming MDC NTT

A fixed dataflow of butterflies + delay-line shift registers + commutator (C2)
units; no address controller, but long pipeline-fill latency.

| Work | Device | Architecture | Fmax | Notes |
|------|--------|--------------|-----:|-------|
| MDC-NTT (Cui) 2025 | Artix-7 | improved fully-pipelined **radix-2 MDC**, GS butterfly, C2 commutators, parallel modular mult | **297 MHz** | NTT-only: 286 cyc, 4187 LUT, 18 DSP, 0 BRAM |
| ParaPM 2026 | Artix-7 / Zynq | **R2MDC** NTT/INTT, 5-stage pipelined butterfly, decoupled on-the-fly PWM (4 PEs) | 270 MHz | 256-pt latency 379 cyc — ~66 % is pipeline fill |
| LightHD 2026 | Artix-7 | MDC-NTT pipeline; **eliminates first NTT stage via LUT regrouping** for small-bit-width polys (−11.7 % cycles) | 212.8 MHz (system) | Lightweight focus |

### 3.3 Reading of the field

- The clear 2024–2025 trend is the **2×2 butterfly** (2 NTT layers per cycle).
  Single-stage-per-cycle designs are now considered to under-use the pipeline.
- **Memory-based** designs have deterministic latency and are far simpler to
  golden-model; **streaming MDC** designs pay a large pipeline-fill penalty for
  a one-shot NTT (ParaPM wastes 251 of 379 cycles on fill).
- Raw Fmax tracks the **device**, not just the design: Versal/UltraScale+/Artix-7
  are faster fabrics than Cyclone V. Comparing MHz across families is unfair.
- Every recent paper competes on **area-time product (ATP / EADP)** — a
  fabric-neutral metric a good Cyclone V design *can* win.

---

## 4. Our Approach — Design Decisions

### 4.1 Architecture: memory-based NTT with a 2×2 butterfly tile

We adopt **Family A** — a memory-based core with a **2×2 butterfly tile**
(4 coefficients in/out per cycle, 2 radix-2 stages collapsed per memory pass).
Reasons:

- **Verifiability.** Deterministic, fixed latency; trivial to golden-model with
  the UVM-v2 pattern. Streaming MDC's delay-line/commutator bookkeeping is far
  harder to verify within an MS-thesis timeline.
- **Current best practice.** The 2×2 tile is what the strongest recent designs
  (Area-Time 2025, ML-DSA-OSH 2025) use; it halves the pass count — 8 radix-2
  stages collapse into **N_PASSES = 4** memory passes.
- **No pipeline-fill penalty.** Unlike streaming MDC, a memory-based core does
  not waste ~250 cycles filling a delay line for a single NTT.

We deliberately do **not** use pure radix-4 (EMINEM) as the first design: the
4-point butterfly is a verification burden. Radix-4 is noted as a later option.

### 4.2 Modular reduction: Barrett

q is 23-bit; a butterfly product is 46-bit. We use Barrett reduction:

```
est = (P · M) >> 46          M = floor(2⁴⁶ / q) = 8 396 807
r   = P − est·q              r ∈ [0, 2q)
out = (r ≥ q) ? r − q : r    at most ONE conditional subtract
```

The constant M and the single-conditional-subtract bound were verified
exhaustively over random products before being embedded (see `mod_mul.sv`).

### 4.3 Twiddle factors

twiddle[i] = ζ^(bitreverse8(i)) mod q for i = 0..255, ζ = 1753 — the standard
Dilithium ordering, with the negacyclic twist folded in. The table is
script-generated (not hand-written) and stored in a ROM.

### 4.4 Keccak ↔ NTT interface — *important*

The NTT does **not** mirror the parallel-Keccak (`N_LANES`) structure, and that
is deliberate. The dataflow is:

```
4× keccak_core (parallel)  →  sampler (rejection)  →  coeff FIFO  →  NTT
```

- Matrix **A is sampled directly in the NTT domain** (ExpandA gives Â) — no NTT
  is applied to A. The NTT operates on s₁, s₂, y, c, t₀.
- Rejection sampling makes the coefficient rate **bursty**; the NTT consumes at
  a **fixed** 4 coeffs/cycle.
- A **decoupling FIFO** between sampler and NTT absorbs the mismatch. The 4
  Keccak lanes stay parallel because *sampling* is the parallel workload —
  replicating the NTT to 4 lanes would only waste area, since the polynomials
  fed to the NTT are not 56-way independent the way ExpandA's SHAKE jobs are.

The Keccak engine itself is **kept as-is on branch `1_hashing` for now**; its
single-core Fmax optimisation and the final `N_LANES` count are deferred to the
integration branch, where they will be re-tuned by throughput matching against
the measured sampler/NTT rates.

---

## 5. RTL Architecture

All RTL lives in `src/ntt_engine/`.

```
ntt_engine          top-level: stream I/O front-end + decoupling FIFO
└── ntt_core        memory-based core: coeff banks + 2×2 butterfly tile + FSM
    ├── twiddle_rom  256-entry twiddle ROM (script-generated)
    └── butterfly_unit  [×4]   configurable CT/GS radix-2 butterfly
        └── mod_mul          pipelined Barrett modular multiplier
ntt_pkg             parameters: q, n, ζ, n⁻¹, Barrett constants, types
```

| File | Status | Description |
|------|--------|-------------|
| `ntt_pkg.sv` | Complete | Ring + Barrett constants, `bf_mode_e`, `ntt_op_e` |
| `mod_mul.sv` | Complete | 3-cycle pipelined Barrett modular multiplier |
| `butterfly_unit.sv` | Complete | CT/GS butterfly, fixed 4-cycle latency, shared multiplier |
| `twiddle_rom.sv` | Complete | 256 twiddles, ζ^brv8(i) mod q, synchronous read |
| `ntt_core.sv` | Scaffold | Coeff banks + 4-butterfly tile instantiated; control FSM + conflict-free address generator are TODO |
| `ntt_engine.sv` | Scaffold | Port list + core instance; stream front-end FSM + input FIFO are TODO |

### 5.1 Engine operations

| `op_i` | Operation |
|--------|-----------|
| `OP_NTT`  | forward NTT |
| `OP_INTT` | inverse NTT, includes the 1/N (n⁻¹) scaling |
| `OP_PWM`  | point-wise multiply of two NTT-domain polynomials |

PWM reuses the four multipliers inside the butterfly tile — no separate
multiplier block (the folding trick from Aikata 2022).

---

## 6. Verification Plan

The NTT testbench (`tb_uvm/tb_uvm_ntt/`) reuses the proven UVM-v2 pattern from
the Keccak branch:

- **No clocking blocks** — direct `@(posedge clk)` + `vif.<sig>` sampling.
- **Per-transaction async reset** — DUT starts every test from a clean state.
- **Driver↔Monitor coordination via `uvm_event`.**
- **Golden model compares every transaction** — no skip path.

**Golden reference:** a pure-SystemVerilog NTT / INTT / PWM model
(`ntt_ref_pkg.sv`, to be written) implementing the same ring arithmetic, so
every random and directed transaction has a precomputed expected polynomial.

**Test plan (per operation):**
- Directed: known-answer NTT/INTT pairs; round-trip `INTT(NTT(a)) == a`;
  PWM cross-checked against schoolbook `a·b mod (x²⁵⁶+1)`.
- Random stress: random polynomials, all three operations.
- Coverage closure: edge coefficients (0, q−1), all-zero / all-max polynomials.

**Coverage targets:** 100 % functional coverage; ≥ 90 % DUT instance coverage —
the same bar met on the Keccak branch.

---

## 7. Targets

The thesis goal is to *exceed* the published state of the art. For the NTT on
Cyclone V, that is framed honestly as follows.

| Metric | Target | Rationale |
|--------|--------|-----------|
| **Cycles per NTT** | ≤ ~300 | Beat Aikata (296); aim toward EMINEM (271) |
| **Area-time product (ATP)** | competitive / best-in-class | Fabric-neutral — the metric to *win* on Cyclone V |
| **Functional correctness** | 100 % golden-compared | Round-trip + KAT + random |
| **Coverage** | 100 % functional, ≥ 90 % DUT | Same bar as Keccak |
| **Fmax** | reported honestly | **Not** a win condition — Cyclone V will trail Artix-7 / Versal on raw MHz; that is a device gap, not a design gap |

**What we are *not* targeting:** beating 328 MHz (Versal) or 324 MHz (Kintex
US+) head-to-head. The honest thesis claim is competitive **cycle count** and
**area-efficiency** on Cyclone V, plus a correct, fully-verified design.

---

## 8. Deferred / Future Work

- Conflict-free address generator and control FSM for `ntt_core` (next step).
- Stream front-end FSM + decoupling input FIFO for `ntt_engine`.
- Pure-SV golden model and the UVM-v2 testbench.
- q-specific (2²³ ≡ 2¹³ − 1) modular reduction as an Fmax optimisation.
- Radix-4 butterfly evaluation (EMINEM-style) once radix-2 is verified.
- Quartus synthesis on Cyclone V; ATP comparison vs the §3 designs.

---

## 9. Change Log

| Date | Change |
|------|--------|
| 2026-05-18 | Document created. Branch `2_ntt` set up; RTL foundation (`ntt_pkg`, `mod_mul`, `butterfly_unit`, `twiddle_rom`) complete; `ntt_core` / `ntt_engine` scaffolded. |
