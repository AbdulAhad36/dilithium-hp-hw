# The Keccak / SHAKE Hashing Engine — Complete Design, Verification and Synthesis Report

**Project:** Hardware Implementation of CRYSTALS-Dilithium (ML-DSA, FIPS 204)
**Branch:** `1_hashing`
**Author:** Muhammad Abdul Ahad
**Last updated:** 2026-05-17

---

## Abstract

This report is the complete, self-contained account of the Keccak / SHAKE
hashing engine built in branch `1_hashing` of the CRYSTALS-Dilithium hardware
thesis. It explains what Keccak is and why Dilithium depends on it, surveys how
other published hardware implementations approached the same primitive,
describes the architecture and RTL we designed, documents the UVM verification
methodology and golden-model strategy, lists the concrete problems encountered
during design/verification/synthesis and how each was solved, presents the
verification and Quartus synthesis results, compares those results honestly
against the published state of the art, and finally lays out the optimisation
backlog and the path to the next module (the NTT).

It is written to double as the hashing-engine chapter of the thesis. It
supersedes and merges the two earlier working documents
(`keccak-design-and-verification.md` and `keccak-throughput-improvement.md`).

---

## Table of Contents

1. [Background — What Keccak, SHA-3 and SHAKE Are](#1-background)
2. [Why Dilithium Needs Keccak](#2-why-dilithium-needs-keccak)
3. [Related Work — How Others Implemented Keccak](#3-related-work)
4. [Our Approach — Design Goals and Decisions](#4-our-approach)
5. [RTL Architecture](#5-rtl-architecture)
6. [Implementation Detail — FSM, Datapath, Step Mappings](#6-implementation-detail)
7. [Verification Methodology](#7-verification-methodology)
8. [Problems Faced and How They Were Solved](#8-problems-faced)
9. [Results — Verification](#9-results-verification)
10. [Results — Throughput and Parallelism](#10-results-throughput)
11. [Results — Quartus Synthesis](#11-results-synthesis)
12. [Comparison With Published Designs](#12-comparison)
13. [Future Work and Optimisation Backlog](#13-future-work)
14. [Conclusion](#14-conclusion)

---

<a name="1-background"></a>
## 1. Background — What Keccak, SHA-3 and SHAKE Are

### 1.1 The sponge construction

Keccak is the algorithm selected by NIST in 2012 as the winner of the SHA-3
competition. Unlike the Merkle–Damgård construction behind SHA-1 and SHA-2,
Keccak is built on the **sponge construction**. A sponge has an internal state
of `b` bits split into two parts:

- the **rate** `r` — the part of the state that interacts with input/output;
- the **capacity** `c` — the part that is never directly touched by I/O and
  provides the security margin (`b = r + c`).

Hashing proceeds in two phases:

- **Absorb:** the message is padded and split into `r`-bit blocks. Each block
  is XORed into the rate portion of the state, then the permutation `f` is
  applied to the whole state.
- **Squeeze:** output is read `r` bits at a time from the rate portion; if more
  output is needed, the permutation is applied again and another `r` bits are
  read. This continues for as long as output is required.

The capacity `c` is never exposed, so an attacker cannot directly control or
observe it — this is what gives the sponge its security.

### 1.2 Keccak-f[1600]

For SHA-3 and SHAKE the state is `b = 1600` bits. It is viewed as a
5 × 5 array of 64-bit **lanes** (5 × 5 × 64 = 1600). The permutation
`Keccak-f[1600]` consists of **24 rounds**, each round being the composition of
five step mappings applied in a fixed order:

| Step | Symbol | Function |
|------|--------|----------|
| Theta | θ | Column-parity diffusion: each bit is XORed with the parities of two neighbouring columns. Provides long-range diffusion. |
| Rho   | ρ | Per-lane bitwise rotation by fixed offsets. Provides intra-lane diffusion. |
| Pi    | π | Permutation of lane positions within the 5 × 5 array. Provides inter-lane dispersion. |
| Chi   | χ | The only non-linear step: `A[x] = A[x] XOR ((NOT A[x+1]) AND A[x+2])` across each row. |
| Iota  | ι | XOR a round-specific constant into lane (0,0). Breaks round symmetry. |

Each round is `R = ι ∘ χ ∘ π ∘ ρ ∘ θ`. θ and χ dominate the combinational
cost — θ because of its wide XOR fan-in across columns, χ because it is a
3-input non-linear function evaluated over the whole state.

### 1.3 SHA-3 vs SHAKE

The SHA-3 family fixes the output length:

- **SHA3-256 / SHA3-512** — fixed-length digests; `r` = 1088 / 576 bits.
- **SHAKE128 / SHAKE256** — *extendable output functions* (XOFs). They produce
  output of **arbitrary length** by squeezing as many blocks as the caller
  asks for. SHAKE128 uses `r` = 1344 bits (168 bytes), SHAKE256 uses
  `r` = 1088 bits (136 bytes).

The two families differ only in the **domain-separation suffix** appended to
the message before padding: `0x06` for SHA-3, `0x1F` for SHAKE. The
permutation itself is identical.

This engine implements **SHAKE128 and SHAKE256 only** — see §4.1 for why.

---

<a name="2-why-dilithium-needs-keccak"></a>
## 2. Why Dilithium Needs Keccak

CRYSTALS-Dilithium (standardised as ML-DSA in FIPS 204) is a lattice-based
post-quantum digital signature scheme. It uses the SHAKE XOF as its **only**
symmetric primitive — there is no AES, no SHA-2, nothing else. SHAKE is used
both as a hash and as a deterministic pseudo-random generator for sampling
polynomials.

| Dilithium operation | XOF | Purpose |
|---------------------|-----|---------|
| ExpandA    | SHAKE128 | Expand the public matrix **A** from the seed ρ |
| ExpandS    | SHAKE256 | Sample the secret vectors **s₁, s₂** from ρ′ |
| ExpandMask | SHAKE256 | Sample the masking vector **y** during signing |
| H (challenge) | SHAKE256 | Hash μ‖w₁ into the challenge polynomial **c** |

The dominant cost is **ExpandA**. For Dilithium-5 (highest security level) the
matrix **A** has dimensions k × l = 8 × 7, so ExpandA performs **56 independent
SHAKE128 invocations** — one per polynomial A[i][j], each seeded by
ρ‖(i,j). Because the index (i,j) differs per call, these 56 jobs are
**mutually independent**: no data dependency, no ordering requirement.

This is the single most important architectural observation in the whole
branch. It means SHAKE is not just *a* bottleneck — it is a bottleneck made of
**dozens of embarrassingly-parallel jobs**, which directly motivates a
*replicated multi-lane* hardware engine rather than a single faster core.
Everything downstream in the Dilithium accelerator is built on top of this
engine, so it had to be correct, well-verified, and throughput-scalable.

---

<a name="3-related-work"></a>
## 3. Related Work — How Others Implemented Keccak

Published Keccak hardware for PQC clusters around a few recurring design
choices. The two axes that matter most are **how a round is scheduled in time**
and **how multiple SHAKE jobs are parallelised in space**.

### 3.1 Round scheduling

- **1 round / cycle (un-pipelined).** All five step mappings evaluated
  combinationally in one clock. Highest bytes-per-cycle, longest critical path.
  Used by Beckwith 2021, Aikata 2022, MDC-NTT 2024, ML-DSA-OSH 2025 — it is the
  de-facto standard for high-performance Dilithium hardware.
- **Unrolled (2 rounds / cycle).** Two rounds chained combinationally —
  fewer cycles per permutation, even longer path. Sundal & Chaves 2017 do this
  on Virtex-7 and reach very high throughput at high area cost.
- **Pipelined (round split across cycles).** A register is inserted *inside*
  the round to shorten the critical path. Lower bytes-per-cycle, higher Fmax.
  Common in ASIC Keccak; less common in FPGA Dilithium because the round is
  usually not the FPGA critical path.

### 3.2 Spatial parallelism

High-performance Dilithium designs almost universally **replicate the Keccak
core** to exploit ExpandA's independence. The replication factor varies, but
the strategy — N independent cores fed by a dispatcher — is shared by Beckwith
2021, Aikata 2022, EMINEM 2025 and others.

### 3.3 Dual-core interleaving (LightHD 2026)

LightHD (2026, Artix-7 XC7A200T) introduces a refinement at the *intra-core
scheduling* level: **two Keccak cores running with a 26-cycle phase offset**,
so that one core is absorbing a new block while the other is still permuting
the previous one. This hides permutation latency without doubling area
proportionally. Their single-core baseline runs at 96.9 MHz; the dual-core
interleaved design reaches 212.8 MHz effective. This idea is noted here as a
future lever (see §13).

### 3.4 Reference points used in this report

| Work | Year | Device | Round arch. | Fmax | Per-core throughput |
|------|------|--------|-------------|-----:|--------------------:|
| Sundal & Chaves | 2017 | Virtex-7 | unrolled 2 rounds/cyc | ~400 MHz | ~22 GB/s |
| Beckwith et al. | 2021 | Artix-7 | 1 round/cyc | ~250 MHz | ~1.7 GB/s |
| Tan et al. | 2021 | **Cyclone V GX** | 1 round/cyc | ~140 MHz | ~0.98 GB/s |
| Aikata et al. (TCHES) | 2022 | Artix-7 | 1 round/cyc, shared | ~166 MHz | ~1.16 GB/s |
| MDC-NTT (Aikata) | 2024 | Artix-7 | 1 round/cyc | ~270 MHz | ~1.9 GB/s |
| ML-DSA-OSH | 2025 | Artix-7 | 1 round/cyc | ~200 MHz | ~1.4 GB/s |
| LightHD | 2026 | Artix-7 | dual-core, 26-cyc offset | 212.8 MHz | — |

Tan 2021 is the **only** Cyclone V comparison and is therefore the fairest
single benchmark for this work — Artix-7 is a faster fabric and direct MHz
comparison against it understates a Cyclone V design.

---

<a name="4-our-approach"></a>
## 4. Our Approach — Design Goals and Decisions

The design philosophy of this branch is: **correctness first, then verified
parallelism, then synthesis-driven Fmax optimisation** — in that order, never
mixing them. Four decisions shaped the RTL.

### 4.1 SHAKE-only (no SHA3-256 / SHA3-512)

**Decision:** support SHAKE128 and SHAKE256 only.

**Rationale:** FIPS 204 uses SHAKE exclusively. SHA-3 fixed-output modes appear
nowhere in Dilithium key generation, signing, or verification. Implementing
them would add cases to the parameter unit, the output unit, and the testbench
for zero benefit to the target application.

**RTL impact:**
- `keccak_pkg.sv` — `keccak_mode` enum is `{SHAKE128, SHAKE256}`, `MODE_NUM = 2`.
- `keccak_param_unit.sv` — suffix byte is always `0x1F`; rate is 168 bytes
  (SHAKE128) or 136 bytes (SHAKE256).
- `keccak_output_unit.sv` — `last_o` is driven purely by the bounded-XOF
  predicate (`total_bytes_squeezed >= target_xof_len`); SHA-3's fixed-length
  termination logic is removed entirely.

### 4.2 Bus width DWIDTH = 64

**Decision:** AXI4-Stream data bus is 64 bits wide (8 bytes per beat).

**Rationale:** the SHAKE rates are 168 and 136 bytes; `gcd(168, 136) = 8`.
DWIDTH=64 is therefore the widest bus that divides **both** rates cleanly, so
the absorb unit never has to straddle a rate boundary across two beats. A wider
bus (e.g. DWIDTH=256 = 32 bytes) divides neither rate and would need carry-over
logic in the absorb unit — a large complexity increase for a modest absorb-side
gain. DWIDTH=256 is coded but commented out, deferred to a future branch.

### 4.3 1-cycle-per-round permutation (baseline)

**Decision (baseline):** evaluate all five step mappings combinationally in one
cycle per round; 24 cycles per Keccak-f[1600] permutation.

**Rationale:** 1 round/cycle gives the best throughput-per-lane and matches the
high-performance literature (Beckwith, Aikata). The alternative — pipelining
the round — trades bytes-per-cycle for Fmax. We started at 1 round/cycle and
*measured* before changing it; the synthesis story in §11 shows why this
ordering mattered.

### 4.4 Spatial parallelism — N independent cores

**Decision:** wrap N independent `keccak_core` instances behind one
parameterisable module boundary, `keccak_engine_parallel`, default `N_LANES=4`.

**Rationale:** this is the direct hardware answer to §2 — ExpandA's 56
independent jobs. A single core processes them serially; N replicated lanes
process N at a time. The wrapper is the **synthesisable top-level** of the
branch; the Dilithium controller in a later branch will dispatch jobs across
the lanes. Changing `N_LANES` scales throughput linearly at proportional area.

---

<a name="5-rtl-architecture"></a>
## 5. RTL Architecture

### 5.1 Module hierarchy

```
keccak_engine_parallel        (top-level, parameterisable N_LANES)
└── keccak_core   [×N_LANES]   (one independent lane each)
    ├── keccak_param_unit  (KPU)   — mode → rate + suffix byte
    ├── keccak_step_unit   (KSU)   — θ→ρ→π→χ→ι round datapath
    │   ├── theta_step.sv
    │   ├── rho_step.sv
    │   ├── pi_step.sv
    │   ├── chi_step.sv
    │   └── iota_step.sv
    ├── keccak_absorb_unit (KAU)   — XOR message into state; suffix padding
    └── keccak_output_unit (KOU)   — read output lanes; signal re-permutation
```

All parameters live in `keccak_pkg.sv`.

### 5.2 keccak_core — submodule roles

| Module | Role |
|--------|------|
| `keccak_param_unit` (KPU) | Combinational lookup: mode → rate (168/136 B) and suffix (`0x1F`). |
| `keccak_absorb_unit` (KAU) | XORs incoming AXI beats into the 1600-bit state; appends the SHAKE suffix and the `0x80` pad byte at the rate boundary. |
| `keccak_step_unit` (KSU) | Executes one Keccak round: instantiates the five step submodules. |
| `keccak_output_unit` (KOU) | During SQUEEZE, reads output bytes from the state, tracks `total_bytes_squeezed` vs `target_xof_len`, and raises `last_o` / requests re-permutation. |

### 5.3 keccak_engine_parallel — the wrapper

A purely structural generate-block wrapper with no state or logic of its own:

```systemverilog
module keccak_engine_parallel #(parameter int N_LANES = 4) (
    input  wire        clk,
    input  wire        [N_LANES-1:0]                  rst,
    input  wire        [N_LANES-1:0]                  start_i,
    input  keccak_mode                                keccak_mode_i [N_LANES],
    input  wire        [N_LANES-1:0][XOF_LEN_WIDTH-1:0] xof_len_i,
    input  wire        [N_LANES-1:0]                  stop_i,
    // per-lane AXI4-Stream sink + source (packed arrays) ...
);
    generate
        for (genvar i = 0; i < N_LANES; i++) begin : g_lane
            keccak_core u_core (.clk(clk), .rst(rst[i]), /* ...per-lane... */);
        end
    endgenerate
endmodule
```

Key properties:
- **Only `clk` is shared.** Reset, start, stop, mode, XOF length, and both AXI
  bundles are per-lane.
- **No arbiter, no scheduler.** Dispatch is the next-level controller's job.
- **Fmax is unchanged** vs a single core — replication does not lengthen any
  combinational path.
- **Area ≈ linear in N_LANES** — every lane replicates the full 1600-bit state
  register and datapath.
- `keccak_mode_i` is an **unpacked array of the enum type** (not a packed
  vector) to satisfy QuestaSim's strict enum type-matching and avoid
  `vsim-3999` connection errors.

### 5.4 Key parameters (`keccak_pkg.sv`)

| Parameter | Value | Description |
|-----------|-------|-------------|
| `DWIDTH` | 64 | AXI data bus width in bits (8 bytes/beat) |
| `KEEP_WIDTH` | 8 | 1 bit per data byte (= DWIDTH/8) |
| `LANE_SIZE` | 64 | Keccak lane width |
| `ROW_SIZE` / `COL_SIZE` | 5 / 5 | State-array dimensions |
| `MAX_ROUNDS` | 24 | Rounds per Keccak-f[1600] permutation |
| `XOF_LEN_WIDTH` | 16 | XOF output-length field width; `0` = continuous |
| `N_LANES` | 4 | Number of parallel `keccak_core` instances |

---

<a name="6-implementation-detail"></a>
## 6. Implementation Detail — FSM, Datapath, Step Mappings

### 6.1 keccak_core FSM

A five-state Mealy FSM. State transitions are combinational; the state register
is synchronous with asynchronous reset.

```
         start_i
IDLE ─────────────► ABSORB
  ▲                   │
  │                   │ bytes_absorbed == rate ──► PERMUTE ──► ABSORB
  │                   │                                        (multi-block)
  │                   │ msg_received ──► SUFFIX_PADDING
  │                                          │
  │                                          └──► PERMUTE (24 rounds)
  │                                                    │
  │                                                    ▼
  └──── stop_i / last_o ──── SQUEEZE ◄───────── (permute done)
                                │   ▲
                                └───┘  re-permute for multi-block XOF squeeze
```

| State | Description |
|-------|-------------|
| IDLE | Waiting for `start_i`. Latches mode, rate, suffix, `xof_len`. |
| ABSORB | XORs AXI beats into the state via KAU. Backpressure via `s_axis_tready`. |
| SUFFIX_PADDING | Applies the `0x1F` SHAKE suffix and the `0x80` pad byte at the rate boundary. |
| PERMUTE | Runs Keccak-f[1600]. Returns to ABSORB (more message blocks) or to SQUEEZE (absorb complete). |
| SQUEEZE | Reads output bytes via KOU. Re-enters PERMUTE when a rate block is exhausted and more XOF output is required. Returns to IDLE on `last_o` or `stop_i`. |

- `start_i` is sampled only in IDLE.
- `stop_i` is sampled only in SQUEEZE — it aborts continuous (`xof_len = 0`)
  XOF output.

### 6.2 The round datapath (`keccak_step_unit`)

The KSU instantiates the five step submodules — `theta_step`, `rho_step`,
`pi_step`, `chi_step`, `iota_step` — and chains them θ→ρ→π→χ→ι.

In the **baseline** the whole chain is combinational (1 round/cycle). In the
**final design** the KSU is **2-stage pipelined**: a 1600-bit register
(`pi_out_reg`) sits between Stage A (θ+ρ+π) and Stage B (χ+ι). The FSM dwells
**two cycles per round** via a 1-bit `permute_phase` register, so PERMUTE now
takes 48 cycles instead of 24. PERMUTE exits only when
`round_idx == 23 && permute_phase == 1`. (The why of this change is in §11.)

### 6.3 Absorb and output units

- **KAU** absorbs 8 message bytes per beat, XORing them into the rate portion
  of the state. At end-of-message it appends the SHAKE suffix and, at the rate
  boundary, the `0x80` pad byte. A popcount of `s_axis_tkeep` tells it how many
  bytes of the final beat are valid.
- **KOU** during SQUEEZE reads 8 output bytes per cycle, maintains
  `total_bytes_squeezed`, compares it against `target_xof_len`, drives `last_o`
  when the bounded length is reached, and requests a re-permutation when the
  current rate block is exhausted but more output is still required.

---

<a name="7-verification-methodology"></a>
## 7. Verification Methodology

### 7.1 Goals

1. Functional correctness of SHAKE128 and SHAKE256 against NIST vectors.
2. Correct operation across all message lengths — empty, short, full-rate,
   multi-block.
3. Correct bounded **and** continuous XOF behaviour.
4. Correct **parallel** operation: N lanes produce correct, independent output
   simultaneously with no cross-lane interference.
5. 100% functional coverage of all mode × message-length × XOF-length crosses.
6. **Every transaction** golden-compared — no unchecked tests.

### 7.2 UVM environment

The active testbench is `tb_uvm/tb_uvm_keccak_v2/`. It targets
`keccak_engine_parallel` (default `N_LANES=4`). One `tb_top` covers both the
single-lane and the multi-lane configuration.

```
tb_top.sv
├── keccak_engine_parallel #(.N_LANES(4))     [DUT]
├── keccak_if vif [4]                         (per-lane interface array)
└── keccak_full_test
    └── keccak_env
        ├── keccak_agent[0] → keccak_scoreboard[0] + keccak_coverage[0]
        ├── keccak_agent[1] → keccak_scoreboard[1] + keccak_coverage[1]
        ├── keccak_agent[2] → keccak_scoreboard[2] + keccak_coverage[2]
        └── keccak_agent[3] → keccak_scoreboard[3] + keccak_coverage[3]
```

Each agent has a sequencer, driver, and monitor. Each lane has its **own
independent scoreboard and coverage collector** — there is no shared state
between lanes anywhere in the TB. `keccak_full_test` forks four copies of
`keccak_full_seq` onto the four sequencers concurrently.

### 7.3 TB design principles

These principles were adopted deliberately after an earlier testbench
(`tb_uvm_keccak/`, now abandoned) failed because of each one's opposite. They
are carried forward as the template for the NTT testbench.

| Principle | Reasoning |
|-----------|-----------|
| **No clocking blocks anywhere.** | Clocking blocks introduced a 1-cycle sampling delay that caused the monitor to miss SQUEEZE handshakes. All sampling is `@(posedge vif.clk)` + direct `vif.<sig>` reads. |
| **`m_axis_tready` owned exclusively by the monitor.** | The old TB had three components fighting over it. The monitor now sets it to 1 at the start of output collection and 0 at the end; nothing else touches it. |
| **Negedge handshake on `s_axis`.** | Absorb inputs are driven on the negedge so they are cleanly sampled at the next posedge. Mirrors the working non-UVM TB. |
| **Per-transaction async reset.** | The driver asserts `rst=1` for 3 cycles between every transaction, so the DUT always starts each test from a clean IDLE. |
| **Driver↔Monitor coordination via `uvm_event`.** | `collection_done` is triggered by the monitor after it writes the observed transaction; the driver waits on it before starting the next transaction. |
| **Per-lane independence.** | Four separate (agent, scoreboard, coverage) triples; no cross-lane UVM objects. |

### 7.4 Golden reference model

`keccak_ref_pkg.sv` is a **pure-SystemVerilog** implementation of the complete
SHAKE algorithm — Keccak-f[1600] + sponge + SHAKE128/256. Public API:

```systemverilog
function automatic string shake_hex(
    input keccak_mode mode,      // SHAKE128 or SHAKE256
    input string      msg_hex,   // message as lowercase hex
    input int         out_bytes  // number of output bytes
);
```

- No DPI, no C model, no external library — runs anywhere QuestaSim runs.
- Round constants `RC[24]` and rho offsets `RHO[5][5]` are declared `static`
  inside automatic functions so they persist across calls without global scope.
- A 4-vector NIST self-test (`shake_self_test()`) is embedded in the package.

The stress and coverage-closure sequences call `shake_hex()` at sim time for
every randomly-generated message, storing the result as `exp_hex` in the
transaction. Directed NIST tests keep their `exp_hex` hardcoded — so the golden
model gives a redundant cross-check on directed tests while anchoring stress
tests. The net result: **every single transaction has a precomputed expected
output and is really compared. There is no `[NOCHK]` skip path.**

### 7.5 Test plan (per lane)

`keccak_full_seq` runs three sub-sequences in order.

**Directed — 13 tests per lane.** NIST FIPS 202 vectors, run in both bounded
XOF (specific `xof_len`) and continuous XOF (`xof_len=0`, monitor-stopped):

| Vector | Mode | Message | Out bytes | Both modes? |
|--------|------|---------|-----------|-------------|
| SHAKE128 Empty | SHAKE128 | empty | 16 | yes |
| SHAKE128 Short | SHAKE128 | `abc` | 16 | yes |
| SHAKE128 Long  | SHAKE128 | 200-byte fill | 32 | bounded only |
| SHAKE256 Empty | SHAKE256 | empty | 32 | yes |
| SHAKE256 Short | SHAKE256 | `abc` | 32 | yes |
| SHAKE256 Long  | SHAKE256 | 200-byte fill | 64 | bounded only |

(3 SHAKE128 × {cont,bnd} + 3 SHAKE256 × {cont,bnd} + 1 SHAKE128-long-bnd +
1 SHAKE256-long-bnd = 13.)

**Random stress — 20 tests per lane.** Randomised mode, message length
(0–250 B), XOF output length (8–200 B bounded), and message content. Expected
output via `shake_hex()`.

**Coverage closure — 19 tests per lane.** Deterministic items chosen to hit
covergroup bins random stress is unlikely to reach: empty message + large XOF,
exact rate-length message, multi-block squeeze, multi-block absorb, max XOF
length, etc. Expected output via `shake_hex()`.

Total per lane = 13 + 20 + 19 = **52 tests**.

### 7.6 Scoreboard and coverage

The scoreboard receives expected transactions from the driver's analysis port
into `exp_fifo` and observed transactions from the monitor's analysis port into
`obs_fifo`. `compare_tx()` dequeues one from each, compares `obs_hex` against
`exp_hex` character-by-character, logs `[PASS]`/`[FAIL]` with full transaction
detail, and prints a summary at `$finish`. No skip paths.

`keccak_coverage.sv` covergroup:

| Coverpoint | Bins |
|------------|------|
| `cp_mode` | SHAKE128, SHAKE256 |
| `cp_msg_len` | empty(0), short(1–15), medium(16–135), full_rate(136), long(137+) |
| `cp_xof_len` | small(1–15), medium(16–63), large(64–255), xlarge(256+), continuous(0) |
| `cross_shake_xof` | `cp_mode` × `cp_xof_len` |
| `cross_mode_msg` | `cp_mode` × `cp_msg_len` (unreachable bins excluded) |

---

<a name="8-problems-faced"></a>
## 8. Problems Faced and How They Were Solved

This section is the honest record of what went wrong and how it was fixed —
the part most useful to anyone repeating the work.

### 8.1 Verification problems

**Monitor missed the SQUEEZE handshake (old TB).** The first testbench used a
clocking block on the monitor interface. The clocking block's implicit input
skew delayed every sample by one cycle, so the monitor read `m_axis` one clock
*after* the DUT presented it and missed short SQUEEZE bursts. **Fix:** dropped
clocking blocks entirely; the v2 TB samples with direct `@(posedge vif.clk)` +
`vif.<sig>` reads. This is now a standing TB principle (§7.3).

**Three components fighting over `m_axis_tready` (old TB).** Driver, monitor,
and a sequence all drove `m_axis_tready`, producing an unpredictable resolved
value. **Fix:** the monitor is the *sole* owner — 1 during collection, 0
otherwise.

**Stress tests were not really checked.** In an earlier revision the 39
non-directed tests were tagged `[NOCHK]` — the scoreboard exercised the FSM but
did not compare output, because there was no expected value for a random
message. **Fix:** the pure-SV `keccak_ref_pkg.sv` golden model computes the
expected hex for every random message at sim time, so the `[NOCHK]` path was
deleted and all 208 transactions are now genuinely compared.

**Abort sequence deadlock.** To cover the three async-reset FSM transitions
(see §9.2) a `keccak_abort_seq` was prototyped that asserts `rst` mid-operation.
It deadlocked: the driver's blocking wait-for-`tready` loop raced against the
async reset and never returned. **Status:** deferred. A correct fix needs a
genuinely non-blocking abort driver (no internal `forever` loop), or a
carefully-scoped `fork…disable`.

### 8.2 Synthesis problems (Quartus Prime Lite 25.1std.0)

These surfaced only when the design first hit Quartus — QuestaSim had accepted
all of them.

| Problem | Cause | Fix |
|---------|-------|-----|
| Generate blocks rejected | Quartus 25.1 requires **named** `generate` blocks | Added labels: `begin : gen_theta_x`, `begin : gen_theta_y` in `theta_step.sv` |
| `$countones` not synthesisable | Not supported in Quartus Lite | Replaced with an explicit popcount for-loop in `keccak_absorb_unit.sv` |
| Latch inference | `always_comb` variables (`state_array_in_sel`, `start_lane_idx`) not assigned on every path | Added unconditional defaults at the top of each `always_comb` |
| Wrong device | Targeted `5CGXFC7D6F31C6N` not in the installed device DB | Selected the equivalent `5CGXFC7C7F23C8`; Cyclone V device pack installed separately via Tools → Install Devices |
| 805 I/O pins on the wrapper | `keccak_engine_parallel` at N_LANES=4 exposes 4× the per-lane ports — far more than any package | Synthesis targets `keccak_core` directly; parallelism is verified in simulation only |

### 8.3 The critical-path misdiagnosis (most important lesson)

The biggest single lesson of the branch: **the obvious critical path was the
wrong one.** Intuition said the five-step Keccak round (θ→ρ→π→χ→ι) over a
1600-bit register would be the Fmax bottleneck. It was not. Pipelining the
round (iteration 2 in §11) bought only **+2.5 MHz**. TimeQuest's post-fit
report showed the *real* worst-case path was in the **SQUEEZE-side XOF control
logic** — a long combinational chain from the `total_bytes_squeezed` and
`target_xof_len` registers, through KOU's adders/comparators, into the
`init_wr_en` net, feeding the enable/D inputs of many wide registers.

The takeaway, now recorded as a standing rule: **always read the TimeQuest
post-fit timing report before deciding what to pipeline.** The obvious-looking
path is often not the real one.

---

<a name="9-results-verification"></a>
## 9. Results — Verification

### 9.1 Test results

| Configuration | Tests | Result | Functional coverage |
|---------------|-------|--------|---------------------|
| Single-lane (N_LANES=1) | 52 / 52 | ALL PASS | 100% |
| 4-lane parallel (N_LANES=4) | **208 / 208** | **ALL PASS** | 100% × 4 lanes |

All 208 transactions golden-compared against the pure-SV reference model.

### 9.2 DUT instance coverage

Measured at `keccak_engine_parallel` after the 4-lane 208-test run:

| Metric | Coverage |
|--------|----------|
| Statements | 94.28% (99/105) |
| Branches | 97.22% (70/72) |
| Conditions | 81.81% (9/11) |
| Expressions | 100% |
| Toggles | 98.83% (17207/17409) |
| FSM States | 100% (5/5) |
| FSM Transitions | 72.72% (8/11) |
| **Total** | **≥ 92%** |

**The 3 uncovered FSM transitions** are the asynchronous-reset paths from
mid-operation states back to IDLE — ABSORB→IDLE, SUFFIX_PADDING→IDLE,
PERMUTE→IDLE via async reset. Covering them requires asserting `rst` mid-op
(an abort). The `keccak_abort_seq` prototype deadlocked (§8.1); this is
deferred and does **not** affect functional correctness of the SHAKE
computation.

---

<a name="10-results-throughput"></a>
## 10. Results — Throughput and Parallelism

The parallelism claim is **not** a synthesis-Fmax claim — Fmax is unchanged by
replication. The metric is **wall-clock cycles to process N independent SHAKE
streams**.

### 10.1 Measurement method

- Clock period 10 ns (100 MHz in sim); 1 cycle = 10 ns of `$time`.
- Every `[PASS]` log line carries `$time`; the `$finish` line gives total
  wall-clock.
- **Serial reference** = 4 × (single-lane wall-clock for 52 tests), because one
  core must replay the full 52-test sequence four times — the 1600-bit state
  register is occupied for the entire life of one stream, so two streams cannot
  overlap on a single core.
- **Speedup** = serial reference / parallel wall-clock.

### 10.2 Result

| Configuration | Tests | Wall-clock | Notes |
|---------------|-------|-----------|-------|
| Single core, 52 tests | 52 | 39 745 ns (3 974 cyc) | per-lane baseline |
| 4 lanes, 208 tests | 208 | **41 395 ns** (4 139 cyc) | 4× the work |
| Serial equivalent (4 × single) | 208 | 158 980 ns | what 1 core would take |
| **Measured speedup** | — | **3.84×** | 96% of the ideal 4× |

> One core, 52 tests, 3 974 cycles. Four cores, 208 tests, 4 139 cycles. Same
> correctness on every one of the 208 tests. The wrapper does ~4× the work in
> ~1× the time.

### 10.3 Why the measurement is honest

1. **Same workload both sides** — each lane runs *exactly* the same
   `keccak_full_seq` the single-lane TB runs; nothing was made cheaper per lane.
2. **No shared state — verified, not assumed** — all 4 scoreboards
   golden-compare independently and all 4 hit 100% coverage. Cross-lane
   corruption would surface as a FAIL. None do.
3. **The serial reference is the right baseline** — a single core genuinely
   cannot overlap two streams, so summing per-lane cycles is what one core
   would really take.
4. **Cycles come straight from the simulator clock** — no model, no projection.

The ~4% residual below the ideal 4× comes from `fork…join` staggering and
non-uniform stress-test message lengths. In real Dilithium dispatch, with many
more than 4 SHAKE jobs queued back-to-back, the staggering vanishes in the
limit.

---

<a name="11-results-synthesis"></a>
## 11. Results — Quartus Synthesis

Synthesised in **Quartus Prime Lite 25.1std.0** on **2026-05-13**.

### 11.1 Toolchain and target

| Setting | Value |
|---------|-------|
| Tool | Quartus Prime Lite 25.1std.0 (Build 1129) |
| Family / Device | Cyclone V / `5CGXFC7C7F23C8` |
| Top-level entity | `keccak_core` (single lane — see §8.2) |
| DWIDTH | 64 |
| SDC clock | 5.0 ns (200 MHz target) |
| I/O constraints | `set_false_path` on all inputs and outputs |
| Clock uncertainty | `derive_clock_uncertainty` |

`keccak_core` is the synthesis target (not the parallel wrapper) because
(a) every published comparison reports single-core numbers and (b) the wrapper
has 805 I/O pins — far beyond any package. The 3.84× parallel speedup is the
relevant multi-lane metric and is verified in simulation.

### 11.2 Optimisation iterations

Four synthesis runs, each guided by TimeQuest's post-fit timing report. The
208/208 + 100%-coverage regression was re-verified after every change.

| Iter. | Change | Fmax | ALMs | Registers |
|-------|--------|-----:|-----:|----------:|
| 1 — Baseline | 1-cycle round, all steps combinational | 73.96 MHz | 4,222 | 1,657 |
| 2 — Pipelined round | Register between (θ+ρ+π) and (χ+ι); FSM dwells 2 cyc/round | 76.42 MHz | 3,747 | 3,293 |
| 3 — Gate state-array clear | `state_array <= '0` fires only in IDLE, not at SQUEEZE→IDLE | 81.93 MHz | ~3,747 | ~3,293 |
| 4 — Drop `init_wr_en` at SQUEEZE end | `init_wr_en` removed from SQUEEZE entirely | **84.31 MHz** | ~3,747 | ~3,293 |

Net improvement: **+14%** (73.96 → 84.31 MHz), with **no functional
regression** — all 208/208 tests still pass.

### 11.3 Final resource utilisation (iteration 4)

| Resource | Used | Available | Utilisation |
|----------|-----:|----------:|------------:|
| Logic (ALMs) | ~3,747 | 56,480 | 7% |
| Registers | ~3,293 | — | (+1,600 for the pipeline register) |
| DSP blocks | 0 | 156 | 0% |
| Block RAM | 0 bits | 7,024,640 | 0% |
| PLLs / DLLs | 0 / 0 | 13 / 4 | 0% |

Zero DSPs and zero BRAM is expected — Keccak is pure XOR/AND/rotate logic over
a register-held state.

### 11.4 What the critical path actually was

Both before and after the round pipeline, TimeQuest reported the worst-case
path as:

```
total_bytes_squeezed[i] / target_xof_len
  → KOU.output_bytes_this_cycle   (xof_len − total_bytes_squeezed)
  → KOU.last_o                    (running total ≥ xof_len)
  → init_wr_en  (FSM action decoder in SQUEEZE)
  → D-input / enable of state_array, bytes_absorbed,
                total_bytes_squeezed, bytes_squeezed  (wide registers)
```

This chain has 3–4 cascaded 16-bit adders/comparators feeding a wide MUX into
~1,700 register bits. The Keccak round was **shorter** — which is why
iteration 2 (pipelining the round) gave only +2.5 MHz.

**Why iterations 3 and 4 worked:** they killed the
`KOU.last_o → init_wr_en → wide-registers` path. The `init_wr_en` assertion at
SQUEEZE→IDLE is **functionally redundant** — it resets counters/flags/state at
the end of a hash, but the very next `start_i` in IDLE re-asserts `init_wr_en`
and reloads everything anyway. No FSM logic observes the inter-hash residual
values, so clearing them at SQUEEZE end is unnecessary; removing the assertion
eliminates the long path and correctness is preserved by IDLE+`start_i`.

### 11.5 Throughput note

The 2-stage round pipeline halves bytes-per-cycle (3.5 vs 7.0), and the +14%
Fmax does not compensate for that on a *single-hash* basis — so single-hash
pipelined throughput is actually slightly lower than the baseline. The pipeline
register is kept anyway, because the right thesis metric is **system-level
signatures/second**, where a higher Fmax helps every downstream module (NTT,
sampler, controller), and because §13's backlog will recover much more Fmax on
top of it.

---

<a name="12-comparison"></a>
## 12. Comparison With Published Designs

| Work | Year | Device | Round arch. | Fmax | Per-core throughput |
|------|------|--------|-------------|-----:|--------------------:|
| **This work (iter. 4)** | 2026 | **Cyclone V** (28 nm) | 2-stage pipelined | **84.31 MHz** | ~0.30 GB/s |
| Sundal & Chaves | 2017 | Virtex-7 | unrolled 2 rounds/cyc | ~400 MHz | ~22 GB/s |
| Beckwith et al. | 2021 | Artix-7 | 1 round/cyc | ~250 MHz | ~1.7 GB/s |
| **Tan et al.** | 2021 | **Cyclone V GX** | 1 round/cyc | **~140 MHz** | ~0.98 GB/s |
| Aikata et al. (TCHES) | 2022 | Artix-7 | 1 round/cyc, shared | ~166 MHz | ~1.16 GB/s |
| MDC-NTT (Aikata) | 2024 | Artix-7 | 1 round/cyc | ~270 MHz | ~1.9 GB/s |
| ML-DSA-OSH | 2025 | Artix-7 | 1 round/cyc | ~200 MHz | ~1.4 GB/s |
| LightHD (single-core baseline) | 2026 | Artix-7 | 1 round/cyc | ~96.9 MHz | — |
| LightHD (dual-core, 26-cyc offset) | 2026 | Artix-7 | interleaved | 212.8 MHz | — |
| ASIC roof | — | 28 nm ASIC | pipelined | 1–2 GHz | 5–10 GB/s |

### 12.1 Honest assessment

- **Against Artix-7 designs the raw MHz looks low — but that comparison is
  unfair.** Artix-7 is a faster fabric than Cyclone V; a MHz-for-MHz comparison
  across families systematically understates a Cyclone V design.
- **The fair comparison is Tan 2021 (Cyclone V GX, ~140 MHz).** At 84.31 MHz we
  are roughly **1.7× behind** the closest same-family reference.
- **The honest mitigations:** (1) LightHD's *single-core* baseline is only
  96.9 MHz on a faster device — i.e. only ~15% above ours, so the result is
  more defensible than the headline 212.8 MHz number suggests; (2) the
  remaining gap is **not** in the Keccak round — it is in the SQUEEZE-side XOF
  control logic, which §13's backlog targets directly; (3) the 4-lane aggregate
  throughput is competitive even though per-core Fmax is short.
- **Conclusion:** the per-core Fmax gap is real but **recoverable**, and the
  recovery is deferred — deliberately — until after NTT bring-up, to keep one
  module in flight at a time.

---

<a name="13-future-work"></a>
## 13. Future Work and Optimisation Backlog

### 13.1 Keccak Fmax backlog (NTT-blocked)

Targeting ~140–180 MHz on Cyclone V (parity with Tan 2021):

| Item | Expected gain | Effort |
|------|--------------:|--------|
| Register `KOU.last_o`, `KOU.keep_o` | +20–40 MHz | Low |
| Pre-compute `bytes_remaining_total` as a registered value | +10–20 MHz | Low |
| Replicate high-fanout `target_xof_len` / `is_xof_fixed_len` | small | Trivial |
| Pipeline the KAU XOR plane | +10–20 MHz | Medium |
| Two-stage iota / chi+iota register split | +30–60 MHz | Medium |
| Width-clean integer literals (kill 138 hygiene warnings) | none | Low |

### 13.2 Deferred architectural idea — dual-core interleaving

Adopt LightHD's dual-core, 26-cycle-offset scheme at the *intra-core scheduling*
level: while one core permutes, the other absorbs the next block, hiding
permutation latency. This complements — does not replace — the existing
`N_LANES` spatial parallelism. Flagged for consideration after NTT bring-up.

### 13.3 Other deferred work

- **Abort-mid-operation FSM coverage** — the 3 missing async-reset transitions;
  needs a non-blocking abort driver (§8.1).
- **DWIDTH=256** — 4× I/O bandwidth, but requires absorb carry-over logic
  because 168 and 136 are not divisible by 32.
- **138 synthesis warnings** — literal-width truncation, a dead `rate_bytes`
  signal, unused upper bits of `keccak_mode_i`. Hygiene only, no functional or
  timing risk.

### 13.4 Next module — the NTT

After the `1_hashing` branch is merged, the next branch is `2_ntt` for the
Number-Theoretic-Transform polynomial multiplier (Dilithium parameters
n = 256, q = 8 380 417, ω = 1753). The NTT testbench will reuse the v2 UVM
pattern documented in §7.3 — no clocking blocks, negedge handshake,
per-transaction reset, golden-model comparison on every transaction.

---

<a name="14-conclusion"></a>
## 14. Conclusion

Branch `1_hashing` delivers a complete, fully-verified SHAKE128/SHAKE256
hashing engine for the Dilithium accelerator:

- A clean SHAKE-only RTL — `keccak_core` plus the parameterisable
  `keccak_engine_parallel` wrapper.
- A robust UVM environment that golden-compares **every one of 208
  transactions** across 4 parallel lanes, with 100% functional coverage and
  ≥92% DUT instance coverage.
- A measured **3.84× parallel speedup** at N_LANES=4 — 96% of the ideal — using
  an honest serial baseline.
- A Quartus synthesis result of **84.31 MHz** on Cyclone V after a
  four-iteration, TimeQuest-guided optimisation pass (+14% over baseline).

The headline lesson — recorded so it is not forgotten — is that **the obvious
critical path was the wrong one**: the Keccak round was never the bottleneck;
the SQUEEZE-side XOF control logic was. Post-fit timing analysis, not
intuition, must drive pipelining decisions.

The per-core Fmax is ~1.7× behind the closest Cyclone V reference (Tan 2021),
but the gap is well-understood, localised to the squeeze-side control logic,
and recoverable via the §13 backlog — deferred deliberately until after NTT
bring-up so that only one module is ever in flight.

---

## Reproduction

**Simulation** (from `sim/`):

```bash
vsim -c -do "do run.do; quit -f"     # headless: compile + sim + coverage
vsim -do run.do                      # GUI
vcover report keccak_cov.ucdb        # coverage report
```

To run single-lane: set `N_LANES = 1` in both `tb_top.sv` and `keccak_env.sv`.

**Synthesis** (`quartus/`):

```
keccak.qpf   # project file (top = keccak_core)
keccak.qsf   # settings: Cyclone V 5CGXFC7C7F23C8, RTL source list
keccak.sdc   # 5 ns clock, false-path I/O, derive_clock_uncertainty
```

Open `keccak.qpf` → Processing → Start Compilation →
Tools → TimeQuest Timing Analyzer → Report Fmax Summary.
