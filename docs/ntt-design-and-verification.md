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

We surveyed the NTT-relevant papers in `docs/refernce-paper-hw/` — all read in
full, not from abstracts. Published Dilithium NTT designs split into two
architectural families.

### 3.1 Family A — Memory-based (iterative) NTT

Coefficients live in BRAM; butterfly units read/write each cycle via a
conflict-free address scheme.

| Work | Device | Architecture | Fmax | Notes |
|------|--------|--------------|-----:|-------|
| Zhao et al., TCHES 2022 | Artix-7 | 4 BFUs, **folding transform** (each BFU time-slices 2 layers), DIT-NTT / DIF-INTT, conflict-free BRAM | 96.9 MHz | 96.9 MHz is the *full-accelerator* Fmax (confirmed by Area-Time 2025 & PALS 2026, both citing this work). Conflict-Free 2026 lists its NTT-only latency as 533 cyc (4 BFU) |
| ML-DSA-OSH 2025 | UltraScale+ | **2×2 butterfly** (4 coeffs/cyc, 2 layers/cyc), Barrett, CT-NTT / GS-INTT; from Beckwith FPT 2021 | 230 MHz (set) | **Open-source RTL** (KU Leuven). NTT+Keccak = 50 % of area. 2×2 chosen over 4×4 to avoid large area penalty |
| Area-Time Efficient 2025 | Versal Premium | **2×2 butterfly** (2 stages/cyc, 4 BFUs), Barrett in each datapath, conflict-free memory + address-resolver ROMs, bit-reversed layout | **328 MHz** | Best Fmax + ATP. Stage-1→stage-2 results forwarded via muxes — **no intermediate memory write**; INTT 1/N merged into final stage |
| EMINEM 2025 | Kintex US+ | **Radix-4 / mixed-radix**, 8 RAM banks cross-bank-writeback, Montgomery | 324 MHz | Dilithium n=256: **271 cycles, 1552 LUT / 6 DSP** — best efficiency |
| Conflict-Free NTT, eprint 2026/621 | Zynq US+ | single-/dual-butterfly, **PTM-code conflict-free scheme** using only single-port RAMs; Montgomery w/ shift-add constant mults (1 multiplier/BF) | 332 / 308 MHz | NTT compute (I/O excluded): single-BF **1075 cyc / 4 DSP**, dual-BF **563 cyc / 8 DSP**; 4-BF projected ~270 cyc |
| KiD 2023 | Artix-7 / Zynq / US+ | unified **Kyber+Dilithium** NTT, configurable count of radix-2 BFUs, conflict-free memory, fully pipelined | — | Unified-NTT reference; standalone Dilithium NTT beats prior compact designs |

### 3.2 Family B — Pipelined / streaming MDC NTT

A fixed dataflow of butterflies + delay-line shift registers + commutator (C2)
units; no address controller, but long pipeline-fill latency.

| Work | Device | Architecture | Fmax | Notes |
|------|--------|--------------|-----:|-------|
| PQShield NTT 2024 | Zynq US+ | **MDC streaming**, single butterfly-config unit doing NTT+INTT on one resource set, ML-KEM + ML-DSA | 322 MHz | 3821 LUT / 2970 FF / 20 DSP / 5 BRAM; claims best ATP among NTT engines |
| MDC-NTT (Cui) 2025 | Artix-7 | improved fully-pipelined **radix-2 MDC**, GS butterfly, C2 commutators, parallel modular mult | **297 MHz** | NTT-only: 286 cyc, 4187 LUT, 18 DSP, 0 BRAM |
| ParaPM 2026 | Artix-7 / Zynq | **R2MDC** NTT/INTT, 5-stage pipelined butterfly, decoupled on-the-fly PWM (4 PEs) | 270 MHz | 256-pt latency 379 cyc — ~66 % is pipeline fill |
| LightHD 2026 | Artix-7 | MDC-NTT pipeline; **eliminates first NTT stage via LUT regrouping** for small-bit-width polys (−11.7 % cycles) | 212.8 MHz (system) | Lightweight focus |

A third, niche direction: **Unified FFT/NTT 2025** (IISc) augments a 512-pt
complex-FFT accelerator to also do the 256-pt NTT, sharing arithmetic between
DSP and PQC — not a competing NTT architecture, but a resource-sharing idea.

### 3.3 Reading of the field

- The clear 2024–2026 trend is the **2×2 butterfly** (2 NTT layers per cycle).
  Single-stage-per-cycle designs are now considered to under-use the pipeline;
  4×4 (16 BFUs) is rejected by ML-DSA-OSH as too area-costly. **2×2 is the
  consensus sweet spot** — and is exactly what we adopted.
- The 2026 papers **confirm rather than overturn** the memory-based + 2×2 +
  conflict-free direction. Conflict-Free 2026 adds a cheaper conflict-free
  scheme (PTM code); PALS 2026 is a *system-level* pipelining paper, not a new
  NTT datapath.
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
  stages collapse into **N_PASSES = 4** memory passes. ML-DSA-OSH explicitly
  rejects 4×4 (16 BFUs) as too area-costly, and Area-Time rejects 1-stage/cyc
  as under-using the pipeline — 2×2 is the agreed sweet spot.
- **No pipeline-fill penalty.** Unlike streaming MDC, a memory-based core does
  not waste ~250 cycles filling a delay line for a single NTT.

**Intra-tile forwarding (confirmed by Area-Time 2025).** Inside the 2×2 tile,
the two stage-1 butterfly results are forwarded directly to the stage-2
butterflies through multiplexers — they are **not** written back to memory
between the two stages. This halves coefficient-memory traffic versus a
single-stage design and is the main reason the 2×2 tile is worth its area.

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

**q-specific reduction is now a firm planned optimisation, not a "maybe."**
Conflict-Free NTT 2026 demonstrates that `q = 2²³ − 2¹³ + 1 = (2¹⁰−1)·2¹³ + 1`
lets the constant multiplications in modular reduction collapse into
shift-and-add — `t·q = (((t≪10) − t)≪13) + t` — so a butterfly needs only
**one true multiplier**. The branch keeps **Barrett first** for verifiability,
then switches the verified `mod_mul` to the q-specific shift-add path as a
defined Fmax/area optimisation (§8) once the golden model passes.

### 4.3 Twiddle factors

twiddle[i] = ζ^(bitreverse8(i)) mod q for i = 0..255, ζ = 1753 — the standard
Dilithium ordering, with the negacyclic twist folded in. The table is
script-generated (not hand-written) and stored in a ROM.

### 4.3a Conflict-free address generation

`ntt_core` needs a conflict-free address scheme so the 2×2 tile can read 4
coefficients and write 4 back every cycle without two accesses colliding on one
BRAM port. Two viable schemes from the literature:

- **Address-resolver ROMs + bit-reversed layout** (Area-Time 2025, Beckwith
  2021 / ML-DSA-OSH) — small ROMs map (pass, position) → bank/address.
- **PTM code** (Conflict-Free NTT 2026) — the bank select is just the XOR of
  the coefficient-counter bits; enables single-port RAMs, near-zero logic.

**Decision:** adopt the **address-resolver ROM** approach, because it is what
the 2×2-tile references (our closest architectural match) use, and it pairs
naturally with the 2-stage tile. The PTM scheme's headline benefit —
single-port RAM — is moot on Cyclone V, whose BRAM is natively dual-port; it is
kept as a fallback if the resolver ROMs hurt timing.

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

**Integration insight from PALS 2026 (for the integration branch, not now).**
PALS shows the dominant cost in a full ML-DSA accelerator is the *data-format
mismatch* between modules: writing sampler output to BRAM and re-reading it in
NTT order severs the pipeline (~62-cycle bubble). PALS removes it with
pipelined "reordering units" + speed-matched submodules, saving ~37 % on the
worst state. When this branch's NTT meets the sampler at integration, prefer a
**pipelined reordering path** over a plain store-to-BRAM decoupling buffer —
the FIFO above is the minimum, not the target.

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
| `mod_mul.sv` | **Complete & verified** | 3-cycle pipelined Barrett modular multiplier. **Bug fixed 2026-05-23:** the stage-2 estimate `prod·M` was evaluated at the 46-bit context width and truncated — the 70-bit product is now formed explicitly (`EST_W'(...)` casts) |
| `butterfly_unit.sv` | **Complete & verified** | CT/GS butterfly, fixed 4-cycle latency, shared multiplier — exercised through `ntt_core` |
| `twiddle_rom.sv` | **Complete & verified** | 256 twiddles, ζ^brv8(i) mod q, synchronous read — cross-checked vs the golden model |
| `ntt_core.sv` | **Increment 3a — pipelined, verified** | Single-butterfly memory-based NTT/INTT + SCALE, now **fully pipelined** — one butterfly issued per cycle, BF_LAT-deep write-delay line, inter-stage drain. ~1.1k cycles/transform (~10× faster than increment 2). 33/33 golden-compared. Increment 3b widens to the 4-butterfly 2×2 tile; OP_PWM is a later increment |
| `ntt_engine.sv` | **Increment 4 — complete & verified** | AXI-Stream front-end (RX 256 → RUN core → TX 256) wrapping `ntt_core`. 23/23 golden-compared checks pass. Decoupling input FIFO deferred to the integration branch |

Verification components (in `tb_uvm/tb_uvm_ntt/`):

| File | Status | Description |
|------|--------|-------------|
| `ntt_ref_pkg.sv` | **Complete & verified** | Pure-SV golden model — `ntt_fwd`/`ntt_inv`/`pwm` (Dilithium-reference port, normal domain) + independent negacyclic schoolbook `poly_mul` |
| `tb_ntt_ref.sv` | **Complete & passing** | Standalone self-check: 208/208 checks pass (round-trip + NTT-vs-schoolbook multiply, random + edge cases) |
| `tb_ntt_core.sv` | **Complete & passing** | Directed self-check of `ntt_core`: 33/33 golden-compared (NTT, INTT, round-trip; edge + random). Run via `sim/ntt_core_check.do` |
| `tb_ntt_engine.sv` | **Complete & passing** | Directed self-check of `ntt_engine` over AXI-Stream: 23/23 golden-compared. Run via `sim/ntt_engine_check.do` |
| UVM env (`ntt_if`, `ntt_transaction`, `ntt_sequence`, `ntt_driver`, `ntt_monitor`, `ntt_agent`, `ntt_scoreboard`, `ntt_coverage`, `ntt_env`, `ntt_tests`, `tb_top.sv`) | **Complete & passing** | Full UVM environment targeting `ntt_engine`, reusing the keccak-v2 pattern. **38/38 golden-compared, 100 % functional coverage, 0 errors.** Run via `sim/ntt_run.do` |

### 5.1 Engine operations

| `op_i` | Operation |
|--------|-----------|
| `OP_NTT`  | forward NTT |
| `OP_INTT` | inverse NTT; the 1/N (n⁻¹) scaling is **merged into the final butterfly pass** (Area-Time 2025), not run as a separate sweep |
| `OP_PWM`  | point-wise multiply of two NTT-domain polynomials |

PWM reuses the four multipliers inside the butterfly tile — no separate
multiplier block (the folding trick from Zhao et al. TCHES 2022).

---

## 6. Verification Plan

The NTT testbench (`tb_uvm/tb_uvm_ntt/`) reuses the proven UVM-v2 pattern from
the Keccak branch — **complete and passing 38/38 with 100 % functional
coverage** (`vsim -c -do "do ntt_run.do; quit -f"`):

- **No clocking blocks** — direct `@(edge clk)` + `vif.<sig>` sampling.
- **Per-transaction async reset** — DUT starts every test from a clean state.
- **Driver↔Monitor coordination via `uvm_event`** (`collection_done`): the
  driver publishes the expected tx on `drv_ap` before driving, then waits for
  the monitor to finish collecting before issuing the next reset.
- **Golden model compares every transaction** — no skip path. Each item's
  `exp_poly` is computed at sequence time by `ntt_ref_pkg` (`ntt_fwd`/`ntt_inv`).
- Single agent (the engine is one engine, not a replicated parallel wrapper) +
  scoreboard + coverage. Sequences: `ntt_directed_seq` (6 edge cases),
  `ntt_stress_seq` (8 random × NTT/INTT/round-trip), `ntt_cov_seq` (8 cross
  bins). `ntt_full_test` runs all three.

**Golden reference — DONE (`ntt_ref_pkg.sv`).** A pure-SystemVerilog
NTT / INTT / PWM model, a direct port of the CRYSTALS-Dilithium reference
`ntt()` / `invntt_tomont()` kept in the normal integer domain, plus an
independent negacyclic schoolbook `poly_mul`. It is **self-verified** by
`tb_ntt_ref.sv` — 208/208 checks pass:

- round-trip `INTT(NTT(a)) == a`,
- NTT-based multiply `INTT(NTT(a)∘NTT(b)) == poly_mul(a,b)` cross-checked
  against the O(N²) schoolbook,
- twiddle spot-checks, edge cases (all-zero, all-(q−1), all-ones, δ-polys),
  100 random vectors.

Run: `cd sim ; vsim -c -do "do ntt_ref_check.do; quit -f"`.

This model is now the **trusted reference**: every `ntt_core` transaction will
be golden-compared against it — no skip path.

**Verification strategy — incremental.** The core is brought up in verifiable
steps, each simulated before the next: (1) golden model ✅ done; (2) a
functionally-correct `ntt_core` checked against the golden model; (3) the
optimised pipelined conflict-free 2×2 datapath; (4) the `ntt_engine` stream
front-end. "Correct first, fast later" — applied step by step.

**Test plan (per operation), reusing the UVM-v2 pattern:**
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
| **Cycles per NTT** (compute-only) | ≤ ~300 | Aim toward EMINEM (271) and the 4-BF designs (~270). **Metric is NTT compute only** — stream-in/out I/O counted separately, per Conflict-Free 2026's convention |
| **Area-time product (ATP)** | competitive / best-in-class | Fabric-neutral — the metric to *win* on Cyclone V |
| **Functional correctness** | 100 % golden-compared | Round-trip + KAT + random |
| **Coverage** | 100 % functional, ≥ 90 % DUT | Same bar as Keccak |
| **Fmax** | reported honestly | **Not** a win condition — Cyclone V will trail Artix-7 / Versal on raw MHz; that is a device gap, not a design gap |

**Cycle-count sanity check.** The 2×2 tile processes 4 coeffs/cycle over
N_PASSES = 4 passes: 4 × (256/4) = 256 cycles of butterfly work, plus pipeline
latency and control overhead → expected **~256–300 compute cycles**, squarely
in range of EMINEM (271) and the 4-butterfly memory designs (Mu 270, Li 284).

**What we are *not* targeting:** beating 328 MHz (Versal) or 324 MHz (Kintex
US+) head-to-head. The honest thesis claim is competitive **cycle count** and
**area-efficiency** on Cyclone V, plus a correct, fully-verified design.

---

## 8. Deferred / Future Work

- **`ntt_core` next step:** control FSM + address-resolver-ROM conflict-free
  generator (§4.3a) + intra-tile stage-1→stage-2 forwarding muxes (§4.1).
- Stream front-end FSM + decoupling input FIFO for `ntt_engine`.
- Pure-SV golden model and the UVM-v2 testbench.
- **q-specific shift-add reduction** — swap the verified Barrett `mod_mul` for
  the `q = 2²³−2¹³+1` shift-add path (§4.2); cuts to one multiplier per BF.
- Radix-4 butterfly evaluation (EMINEM-style) once radix-2 is verified.
- Quartus synthesis on Cyclone V; ATP comparison vs the §3 designs.
- **Integration branch:** pipelined sampler→NTT reordering path (PALS-style),
  not a plain BRAM decoupling buffer (§4.4).

---

## 9. Change Log

| Date | Change |
|------|--------|
| 2026-05-18 | Document created. Branch `2_ntt` set up; RTL foundation (`ntt_pkg`, `mod_mul`, `butterfly_unit`, `twiddle_rom`) complete; `ntt_core` / `ntt_engine` scaffolded. |
| 2026-05-22 | §3.1 — added PQShield NTT 2024 and Conflict-Free NTT (eprint 2026/621) to the Family A survey. |
| 2026-05-22 | Full-text review of all NTT papers (incl. 6 newly added: PQShield 2024, TCHES co-design 2024, KiD 2023, Unified FFT/NTT 2025, PALS 2026, Conflict-Free 2026). §3: corrected the 2022 TCHES paper attribution (Zhao et al., not "Aikata"); moved PQShield to Family B (it is MDC-streaming, not memory-based); added KiD 2023. §4.1: documented intra-tile stage-forwarding. §4.2: q-specific reduction promoted to a firm planned optimisation. §4.3a (new): conflict-free address-generation decision — address-resolver ROMs. §4.4: added PALS integration insight. §5.1: INTT 1/N scaling merged into final pass. §7: cycle target clarified as compute-only + sanity check. **Conclusion: core approach (memory-based 2×2 + Barrett-first + conflict-free) is unchanged — the 2026 literature confirms it.** |
| 2026-05-22 | **Verification increment 1 — golden model complete & verified.** Added `tb_uvm/tb_uvm_ntt/ntt_ref_pkg.sv` (pure-SV NTT/INTT/PWM + negacyclic schoolbook reference) and `tb_ntt_ref.sv` (standalone self-check) + `sim/ntt_ref_check.do`. Self-check passes **208/208** in QuestaSim (round-trip, NTT-vs-schoolbook multiply, twiddle spot-checks, edge cases, 100 random vectors). The golden model is now the trusted reference for `ntt_core`. Next: increment 2 — a functionally-correct `ntt_core` golden-compared against it. |
| 2026-05-23 | **Verification increment 2 — `ntt_core` functionally complete & verified.** Implemented the single-butterfly memory-based core (control FSM mirroring the reference NTT/INTT schedule + SCALE pass) and `tb_ntt_core.sv` (directed golden-compare) + `sim/ntt_core_check.do`. **33/33 checks pass** (NTT, INTT, round-trip; edge + random). The incremental-verify process **caught a latent bug in `mod_mul.sv`**: the Barrett stage-2 multiply `prod_s1·BARRETT_M` was being truncated to the 46-bit context width instead of the full 70 bits — fixed by explicit `EST_W` casts. `mod_mul` / `butterfly_unit` / `twiddle_rom` are now verified through the core. |
| 2026-05-23 | **Verification increment 4 — `ntt_engine` stream front-end complete & verified.** Implemented the AXI-Stream front-end FSM (RX 256 → RUN → TX 256) wrapping `ntt_core`, plus `tb_ntt_engine.sv` + `sim/ntt_engine_check.do`. **23/23 checks pass**. Two testbench handshake bugs found & fixed during bring-up (premature `m_tready` deassert; `start` pulsed during the 1-cycle `E_DONE` state) — RTL was correct, TB now waits on `busy_o`; a watchdog was added. |
| 2026-05-23 | **Increment 3a — `ntt_core` pipelined.** Reworked the core from hold-each-butterfly (increment 2, ~13k cycles) to a true pipeline: one butterfly issued per cycle, agen→feed→write stages, a BF_LAT-deep write-delay line, and a short inter-stage drain (the only hazard is stage→stage). SCALE pass pipelined likewise. **~10× faster (~1.1k cycles/transform)**, still 33/33 (core) and 23/23 (engine) golden-compared. Remaining: increment 3b (widen to the 4-butterfly 2×2 tile + conflict-free banking → ~300 cycles) and OP_PWM. |
| 2026-05-23 | **UVM environment built for `ntt_engine`.** Added the full UVM TB under `tb_uvm/tb_uvm_ntt/` (interface, transaction, sequences, driver, monitor, agent, scoreboard, coverage, env, tests, `tb_top.sv`), reusing the keccak-v2 pattern (no clocking blocks, per-tx async reset, `uvm_event` driver↔monitor sync, every tx golden-compared). `ntt_run.do` updated to compile it. **Passes 38/38 with 100 % functional coverage, 0 errors** on first run. This supersedes the directed `tb_ntt_engine.sv` as the regression environment. |
| 2026-05-24 | **Increment 3b-i — 4-butterfly 2×2 tile + intra-tile forwarding.** Rewrote `ntt_core.sv` as a true radix-2² tile: 4 BFUs in two ranks (BFU0/1 rank-s, BFU2/3 rank-t, rank-s outputs feed rank-t directly with no mem hop), 3 twiddle ROMs, one tile issued per cycle (4 coeffs/cycle). 8 radix-2 stages collapse to 4 memory passes of 64 tiles each. Flat 256×23 memory with 4R+4W per cycle (synthesis-bank refactor deferred to 3b-ii; compute schedule and cycle count are the same either way). SCALE pass widened to 4 coeffs/cycle using the 4 BFUs in parallel. **~297 compute cycles for NTT, ~370 for INTT** (measured via UVM TB) — the ≤300-cycle thesis target for NTT compute is met. **One bug found & fixed during bring-up:** `pass_r << 1` was evaluated in 2-bit context, overflowing for `pass_r ≥ 2` and silently re-running pass 0 four times — fixed by widening the shift amount via explicit 4-bit signals. After fix: **33/33 (tb_ntt_core), 38/38 (UVM env)**, 100 % functional coverage. Remaining: 3b-ii (4-bank conflict-free memory for synthesis-to-BRAM) and OP_PWM. |
