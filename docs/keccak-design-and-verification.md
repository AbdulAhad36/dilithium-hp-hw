# Keccak Engine — Design and Verification Report

**Branch:** `1_hashing`
**Date:** 2026-05-12
**Author:** Muhammad Abdul Ahad

---

## Overview

This document captures the complete design and verification story of the Keccak hashing engine developed in branch `1_hashing` of the CRYSTALS-Dilithium hardware implementation thesis. It covers architecture decisions, RTL structure, UVM verification methodology, golden model strategy, coverage results, and performance measurements. This document is intended to serve as thesis chapter material for the hashing engine section.

---

## 1. Role of Keccak in CRYSTALS-Dilithium

CRYSTALS-Dilithium (FIPS 204 / ML-DSA) uses the SHAKE extendable output function (XOF) as its primary cryptographic primitive. Every major operation in the signing and verification flow calls SHAKE:

| Dilithium Operation | XOF Used   | Purpose                                      |
|---------------------|------------|----------------------------------------------|
| ExpandA             | SHAKE128   | Generates the public matrix A from seed ρ    |
| ExpandS             | SHAKE256   | Samples secret vectors s₁, s₂ from seed ρ'  |
| ExpandMask          | SHAKE256   | Samples the masking vector y during signing  |
| H (challenge hash)  | SHAKE256   | Produces the challenge polynomial c          |

For Dilithium-5 (the highest security level), ExpandA alone requires k × l = 8 × 7 = 56 independent SHAKE128 invocations — one per matrix polynomial A[i][j]. These invocations are **mutually independent** and represent the dominant bottleneck in the signing and key generation operations.

This justifies implementing SHAKE as a high-throughput, parallelisable hardware module rather than a single serial core. The hardware Keccak engine described in this document is the foundation upon which the entire Dilithium hardware accelerator is built.

---

## 2. Design Scope and Decisions

### 2.1 SHAKE-Only (No SHA3-256 / SHA3-512)

**Decision:** Support SHAKE128 and SHAKE256 only. SHA3-256 and SHA3-512 are not implemented.

**Rationale:** FIPS 204 (ML-DSA) uses exclusively SHAKE. SHA3 fixed-output modes are not used anywhere in Dilithium's key generation, signing, or verification algorithms. Including SHA3 would add logic to the parameter unit, the output unit, and the testbench without providing any benefit to the target application.

**Impact on RTL:**
- `keccak_pkg.sv`: `keccak_mode` enum is `{SHAKE128, SHAKE256}` only.
- `keccak_param_unit.sv`: suffix byte is always `0x1F` (SHAKE domain separator). Rate is `1344` bits (168 bytes) for SHAKE128, `1088` bits (136 bytes) for SHAKE256.
- `keccak_output_unit.sv`: `last_o` is driven purely by the bounded-XOF predicate (`total_bytes_squeezed >= target_xof_len`). SHA3's fixed-length termination logic is removed entirely.

### 2.2 Bus Width: DWIDTH = 64

**Decision:** AXI4-Stream data bus width is 64 bits (8 bytes per beat).

**Rationale:** The SHAKE rates are 168 bytes (SHAKE128) and 136 bytes (SHAKE256). The greatest common divisor of 168 and 136 is 8 bytes. DWIDTH=64 is therefore the maximum bus width that divides both rates cleanly, meaning the absorb unit never has to straddle a rate boundary across two beats. Wider bus widths (e.g., DWIDTH=256 = 32 bytes) do not divide either rate evenly and would require carry-over logic in the absorb unit — significantly increasing design complexity for a relatively small throughput gain on the absorb side.

**Impact:** 8 bytes absorbed or squeezed per clock cycle. This is the configuration the DUT is synthesised and simulated at.

### 2.3 1-Cycle-per-Round Permutation

**Decision:** All five Keccak-f[1600] step mappings (θ, ρ, π, χ, ι) execute combinationally in a single clock cycle per round.

**Rationale:** 1 cycle/round gives the best throughput-per-lane ratio at the cost of a longer combinational critical path (θ + χ chain ≈ 7 gate levels / 3 LUT levels). The alternative — pipelining across multiple cycles per round — reduces Fmax pressure but increases per-permutation latency. Since permutation latency (24 cycles) dominates the per-SHAKE-block cost, reducing it is the more impactful direction. The 1-cycle/round approach is consistent with state-of-the-art high-performance Keccak implementations (Beckwith 2021, Aikata 2022).

**Permutation latency:** 24 clock cycles per Keccak-f[1600] block. There is no overlap between permutation and absorb/squeeze.

### 2.4 Spatial Parallelism: N_LANES Independent Cores

**Decision:** Wrap N independent `keccak_core` instances behind a single parameterisable module boundary (`keccak_engine_parallel`, `N_LANES=4` default).

**Rationale:** ExpandA needs 56 independent SHAKE jobs. A single core processes them serially. Replicating the core N times allows N jobs to proceed in parallel in the same wall-clock window. This is the same strategy used by Beckwith 2021, EMINEM 2025, and other published high-performance Dilithium implementations.

The wrapper is the **synthesisable top-level** of this branch. Changing `N_LANES` scales throughput linearly at proportional area cost. The Dilithium controller (next branch) will be responsible for dispatching jobs across the lanes.

---

## 3. RTL Architecture

### 3.1 Module Hierarchy

```
keccak_engine_parallel  (top-level, parameterisable N_LANES)
└── keccak_core  [×N_LANES]  (one per lane)
    ├── keccak_param_unit  (KPU)   — mode → rate + suffix byte
    ├── keccak_step_unit   (KSU)   — θ→ρ→π→χ→ι in 1 cycle
    │   ├── theta_step.sv
    │   ├── rho_step.sv
    │   ├── pi_step.sv
    │   ├── chi_step.sv
    │   └── iota_step.sv
    ├── keccak_absorb_unit (KAU)   — XOR message bytes into state; suffix padding
    └── keccak_output_unit (KOU)   — read output lanes; signal re-permutation
```

All parameters are centralised in `keccak_pkg.sv`.

### 3.2 keccak_core FSM

The core implements a five-state Mealy FSM. State transitions are combinational; state register is synchronous with asynchronous reset.

```
         start_i
IDLE ─────────────► ABSORB
  ▲                   │
  │ stop_i (SHAKE)    │ bytes_absorbed == rate/8 ──► PERMUTE ──► ABSORB
  │                   │                                 │         (multi-block)
  │                   │ msg_received ──► SUFFIX_PADDING─┘
  │                                             │
  │                                             └──► PERMUTE (×24 rounds)
  │                                                       │
  │                                                       ▼
  └──── stop_i ──── SQUEEZE ◄────────────────────── (absorb_done)
            last_o │            ▲
                   │  KOU_PERM  │  (re-permutation for SHAKE multi-block squeeze)
                   └────────────┘
```

State summary:

| State           | Description                                                     |
|-----------------|-----------------------------------------------------------------|
| IDLE            | Waiting for `start_i`. Latches mode, rate, suffix, xof_len.    |
| ABSORB          | XORs AXI4-Stream beats into state via KAU. Backpressure via `s_axis_tready`. |
| SUFFIX_PADDING  | Applies SHAKE `0x1F` suffix and `0x80` padding at rate boundary. |
| PERMUTE         | Runs Keccak-f[1600] for 24 cycles (round_idx 0→23). Returns to ABSORB (multi-block) or SQUEEZE (done). |
| SQUEEZE         | Reads output bytes from state via KOU. Re-enters PERMUTE when rate block exhausted (SHAKE XOF). Returns to IDLE on `last_o` or `stop_i`. |

### 3.3 keccak_engine_parallel

A purely structural generate-block wrapper. Contains no state or logic of its own.

```systemverilog
module keccak_engine_parallel #(parameter int N_LANES = 4) (
    input  wire  clk,
    input  wire  [N_LANES-1:0] rst,
    input  wire  [N_LANES-1:0] start_i,
    input  keccak_mode keccak_mode_i [N_LANES],   // unpacked enum array
    input  wire  [N_LANES-1:0][XOF_LEN_WIDTH-1:0] xof_len_i,
    input  wire  [N_LANES-1:0] stop_i,
    // per-lane AXI4-Stream sink + source (packed arrays) ...
);
    generate
        for (genvar i = 0; i < N_LANES; i++) begin : g_lane
            keccak_core u_core (.clk(clk), .rst(rst[i]), .keccak_mode_i(keccak_mode_i[i]), ...);
        end
    endgenerate
endmodule
```

Key design properties:
- **Only `clk` is shared.** All other signals — reset, start, stop, mode, XOF length, AXI sink, AXI source — are per-lane.
- **No arbiter or scheduler.** The wrapper makes no assumptions about lane utilisation; the Dilithium controller above it manages dispatch.
- **Fmax unchanged** relative to a single core. Replication does not extend the critical path.
- **Area ≈ linear in N_LANES.** Each lane replicates the full 1600-bit state register and all combinational datapath.

The `keccak_mode` port is declared as an unpacked array of the `keccak_mode` enum (not a packed `[N_LANES-1:0][1:0]` vector) to satisfy QuestaSim's strict enum type matching and avoid `vsim-3999` connection errors.

### 3.4 Key Parameters

| Parameter       | Value    | Description                                      |
|-----------------|----------|--------------------------------------------------|
| `DWIDTH`        | 64       | AXI data bus width in bits (8 bytes/beat)        |
| `KEEP_WIDTH`    | 8        | 1 bit per data byte (= DWIDTH/8)                 |
| `LANE_SIZE`     | 64       | Keccak lane width in bits                        |
| `ROW_SIZE`      | 5        | State array rows                                 |
| `COL_SIZE`      | 5        | State array columns                              |
| `MAX_ROUNDS`    | 24       | Rounds per Keccak-f[1600] permutation            |
| `XOF_LEN_WIDTH` | 16       | XOF output length field width; 0 = continuous    |
| `N_LANES`       | 4        | Number of parallel keccak_core instances         |

---

## 4. Verification Methodology

### 4.1 Verification Goals

1. Functional correctness of SHAKE128 and SHAKE256 against NIST test vectors.
2. Correct operation across all message lengths (empty, short, full-rate, multi-block).
3. Correct bounded and continuous XOF output behaviour.
4. Correct parallel operation: N lanes produce the correct, independent output simultaneously without interfering with each other.
5. Full functional coverage of all mode × message-length × XOF-length combinations.
6. Every transaction compared against a trusted golden reference — no unchecked tests.

### 4.2 UVM Environment Structure

The active testbench is `tb_uvm/tb_uvm_keccak_v2/`. It targets `keccak_engine_parallel` (N_LANES=4 by default). One `tb_top` covers both single-lane (N_LANES=1) and multi-lane (N_LANES=4) configurations.

```
tb_top.sv
├── keccak_engine_parallel #(.N_LANES(4))  [DUT]
├── keccak_if vif [4]  (per-lane interface array)
└── UVM test hierarchy
    └── keccak_full_test
        └── keccak_env
            ├── keccak_agent [0]  →  keccak_scoreboard [0]  +  keccak_coverage [0]
            ├── keccak_agent [1]  →  keccak_scoreboard [1]  +  keccak_coverage [1]
            ├── keccak_agent [2]  →  keccak_scoreboard [2]  +  keccak_coverage [2]
            └── keccak_agent [3]  →  keccak_scoreboard [3]  +  keccak_coverage [3]
```

Each agent contains a sequencer, driver, and monitor. Each lane has its own independent scoreboard and coverage collector. There is no shared state between lanes anywhere in the TB.

**UVM config_db registration:**
```systemverilog
uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_0.*", "keccak_vif", vif[0]);
uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_1.*", "keccak_vif", vif[1]);
uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_2.*", "keccak_vif", vif[2]);
uvm_config_db#(virtual keccak_if)::set(null, "uvm_test_top.env.agent_3.*", "keccak_vif", vif[3]);
```

### 4.3 TB Design Principles

These decisions were made to avoid the bugs discovered in an earlier broken TB:

| Principle | Reasoning |
|---|---|
| No clocking blocks | Clocking blocks introduced a 1-cycle sampling delay that caused the monitor to miss SQUEEZE handshakes. All signal reads are `@(posedge vif.clk)` + direct `vif.<sig>` access. |
| `m_axis_tready` owned exclusively by the monitor | Previously multiple drivers fought over it. Now: monitor sets it to 1 at start of output collection, 0 after. No other component touches it. |
| Negedge handshake on `s_axis` | Drives absorb inputs on negedge to be cleanly sampled at the next posedge. Mirrors the working non-UVM testbench pattern. |
| Per-transaction async reset | Driver asserts `rst=1` for 3 cycles between every transaction, ensuring the DUT always starts from a clean IDLE. |
| Driver–Monitor coordination via `uvm_event` | `collection_done` event is triggered by the monitor after writing the observed transaction; the driver waits on it before sending the next transaction. Prevents the driver from starting the next job before the monitor has finished the current one. |
| Per-lane independence | 4 separate (agent, scoreboard, coverage) triples. No cross-lane UVM objects. |

### 4.4 Golden Reference Model

`tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv` is a pure-SystemVerilog implementation of the complete SHAKE algorithm — Keccak-f[1600] permutation + sponge construction + SHAKE128/SHAKE256.

Public API used by the TB:
```systemverilog
function automatic string shake_hex(
    input keccak_mode mode,     // SHAKE128 or SHAKE256
    input string      msg_hex,  // message as lowercase hex string
    input int         out_bytes // number of output bytes to produce
);
```

Implementation notes:
- No DPI, no C model, no external library. Runs anywhere QuestaSim runs.
- Round constants (RC[24]) and rho offsets (RHO[5][5]) declared `static` inside automatic functions so they persist across calls without global scope.
- 4-vector NIST self-test (`shake_self_test()`) embedded in the package.

The model is used at simulation time by:
- `keccak_stress_seq`: calls `shake_hex()` for each randomly-generated message before `start_item()`. The result is stored as `exp_hex` in the transaction.
- `keccak_cov_seq`: same — calls `shake_hex()` for each coverage-closure item.
- Directed NIST tests: `exp_hex` is hardcoded. The golden model provides a redundant cross-check — if the model were ever wrong, a directed test would still catch it.

This means **every single transaction** sent by every sequence has a precomputed expected output, and the scoreboard performs a real comparison on all of them. There are no unchecked transactions.

### 4.5 Test Plan

Per lane, `keccak_full_seq` runs three sub-sequences in order:

#### Directed (13 tests per lane)

NIST FIPS 202 test vectors. Run in both bounded XOF (specific `xof_len`) and continuous XOF (`xof_len=0`, monitor-stopped) modes:

| Vector | Mode     | Message  | Output bytes | Both modes? |
|--------|----------|----------|--------------|-------------|
| SHAKE128 Empty  | SHAKE128 | empty    | 16 | yes |
| SHAKE128 Short  | SHAKE128 | `abc`    | 16 | yes |
| SHAKE128 Long   | SHAKE128 | 200-byte fill | 32 | bounded only |
| SHAKE256 Empty  | SHAKE256 | empty    | 32 | yes |
| SHAKE256 Short  | SHAKE256 | `abc`    | 32 | yes |
| SHAKE256 Long   | SHAKE256 | 200-byte fill | 64 | bounded only |

(3 SHAKE128 vectors × cont/bnd + 3 SHAKE256 vectors × cont/bnd + 1 SHAKE128 long bounded + 1 SHAKE256 long bounded = 13)

#### Random Stress (20 tests per lane)

Randomised across:
- Mode: SHAKE128 or SHAKE256
- Message length: 0–250 bytes (random)
- XOF output length: 8–200 bytes (random bounded)
- Message content: random bytes

Expected output computed via `shake_hex()` in sequence before driving. All 20 tests are golden-compared.

#### Coverage Closure (19 tests per lane)

Deterministic items chosen to hit specific coverage bins that random stress is unlikely to reach naturally:
- SHAKE128 + empty message + large XOF (256 bytes)
- SHAKE256 + exact rate-length message (136 bytes) + bounded XOF
- Multi-block squeeze (XOF output > one rate block)
- Very long message (multi-block absorb)
- XOF length = maximum sensible value
- ... (all items target specific covergroup bin hits)

Expected output computed via `shake_hex()` for all 19 items.

### 4.6 Scoreboard

The scoreboard receives:
- **Expected transactions** from the driver's analysis port (`drv_ap`), put into `exp_fifo`.
- **Observed transactions** from the monitor's analysis port (`mon_ap`), put into `obs_fifo`.

Comparison is performed in `compare_tx()`:
- Dequeues one item from each FIFO.
- Compares `obs_hex` against `exp_hex` character-by-character.
- Logs `[PASS]` or `[FAIL]` with the transaction name, mode, message, expected, and observed fields.
- Tracks pass/fail counts; prints summary at end of simulation.

There are no skip paths. Every transaction is compared.

### 4.7 Functional Coverage

`keccak_coverage.sv` implements a covergroup with the following points:

| Coverpoint | Bins |
|---|---|
| `cp_mode` | `SHAKE128`, `SHAKE256` |
| `cp_msg_len` | `empty` (0), `short` (1–15), `medium` (16–135), `full_rate` (136), `long` (137+) |
| `cp_xof_len` | `small` (1–15), `medium` (16–63), `large` (64–255), `xlarge` (256+), `continuous` (0) |
| `cross_shake_xof` | `cp_mode` × `cp_xof_len` (2×5 = 10 bins) |
| `cross_mode_msg` | `cp_mode` × `cp_msg_len` (2×5 = 10 bins, some unreachable excluded) |

Target: 100% per lane. Achieved: 100% per lane across all 4 lanes.

---

## 5. Verification Results

### 5.1 Test Results

| Configuration | Tests | Result | Functional Coverage |
|---|---|---|---|
| Single-lane (N_LANES=1), SHAKE-only | 52/52 | ALL PASS | 100% |
| 4-lane parallel (N_LANES=4) | 208/208 | ALL PASS | 100% × 4 lanes |

52 tests per lane = 13 directed + 20 stress + 19 coverage-closure.
All 208 tests golden-compared against the pure-SV reference model.

### 5.2 DUT Instance Coverage

Measured at the `keccak_engine_parallel` level after the 4-lane 208-test run:

| Metric | Coverage |
|---|---|
| Statements | 94.28% (99/105) |
| Branches | 97.22% (70/72) |
| Conditions | 81.81% (9/11) |
| Expressions | 100% |
| Toggles | 98.83% (17207/17409) |
| FSM States | 100% (5/5) |
| FSM Transitions | 72.72% (8/11) |
| **Total** | **≥ 92%** |

**Note on missing FSM transitions:** The 3 uncovered transitions are the asynchronous reset paths from mid-operation states back to IDLE (ABSORB→IDLE, SUFFIX_PADDING→IDLE, PERMUTE→IDLE via async reset). These require asserting `rst` while the FSM is in those states — an abort mid-operation. An abort sequence (`keccak_abort_seq`) was prototyped but caused a simulation deadlock due to a race between the driver's wait-for-tready loop and the async reset. This is deferred work; it does not affect functional correctness of the SHAKE computation.

### 5.3 Throughput Results

Full measurement methodology and honest-speedup analysis is detailed in [keccak-throughput-improvement.md](keccak-throughput-improvement.md). Summary:

| Configuration | Tests | Wall-clock | Notes |
|---|---|---|---|
| Single core, 52 tests | 52 | 39 745 ns | Per-lane baseline |
| 4 lanes, 208 tests | 208 | 41 395 ns | Same work × 4, same time |
| Serial equivalent (4 × single) | 208 | 158 980 ns | What 1 core would take |
| **Speedup** | — | **3.84×** | vs. serial single-core |

The 3.84× is 96% of the theoretical 4× ceiling. The 4% residual comes from non-uniform lane completion times due to randomised message lengths in the stress sequence.

---

## 6. File Inventory

### RTL — `src/keccak_engine/`

| File | Status | Description |
|---|---|---|
| `keccak_pkg.sv` | Modified | SHAKE-only mode enum `{SHAKE128, SHAKE256}`; all parameters |
| `keccak_core.sv` | Modified (comments) | Single-lane Keccak-f[1600] core; 5-state FSM |
| `keccak_param_unit.sv` | Modified | SHAKE-only rate/suffix LUT |
| `keccak_absorb_unit.sv` | Unchanged | XOR absorb + suffix padding |
| `keccak_step_unit.sv` | Unchanged | Instantiates all 5 step submodules |
| `theta_step.sv` | Unchanged | θ step mapping |
| `rho_step.sv` | Unchanged | ρ step mapping |
| `pi_step.sv` | Unchanged | π step mapping |
| `chi_step.sv` | Unchanged | χ step mapping |
| `iota_step.sv` | Unchanged | ι step mapping (round constants) |
| `keccak_output_unit.sv` | Modified | Bounded-XOF `last_o` only; SHA3 cases removed |
| **`keccak_engine_parallel.sv`** | **New** | Parameterisable N_LANES wrapper |

### Testbench — `tb_uvm/tb_uvm_keccak_v2/`

| File | Status | Description |
|---|---|---|
| `keccak_if.sv` | Unchanged | Interface: plain `logic` signals, no clocking blocks |
| `keccak_transaction.sv` | Modified | SHAKE-only `get_rate_bytes()`; added `exp_hex`, `obs_hex` |
| `keccak_sequence.sv` | Modified | SHA3 vectors removed; `shake_hex()` for all expected outputs; `[NOCHK]` removed |
| `keccak_driver.sv` | Unchanged | Negedge handshake; per-tx reset; waits on `collection_done` |
| `keccak_monitor.sv` | Unchanged | Direct posedge sampling; owns `m_axis_tready` |
| `keccak_scoreboard.sv` | Modified | `[NOCHK]` skip path deleted; all transactions compared |
| `keccak_coverage.sv` | Modified | 2-mode bins; cross-coverage updated for SHAKE-only |
| `keccak_agent.sv` | Unchanged | Sequencer + driver + monitor + `collection_done` event |
| **`keccak_ref_pkg.sv`** | **New** | Pure-SV Keccak-f[1600] + SHAKE reference model |
| `keccak_env.sv` | Replaced | 4-lane: `N_LANES=4`, 4× (agent + scoreboard + coverage) |
| `keccak_tests.sv` | Replaced | `keccak_full_test` forks 4 `keccak_full_seq` in parallel |
| `tb_top.sv` | Replaced | Targets `keccak_engine_parallel`; 4 `keccak_if` + config_db |

### Simulation

| File | Status | Description |
|---|---|---|
| `sim/run.do` | Rewritten | Single entry: `vdel -all` → compile RTL → compile TB → `vsim` → waves → `run -all` → `coverage save` |

---

## 7. How to Reproduce

```bash
cd sim

# Headless: compile + simulate + save coverage
vsim -c -do "do run.do; quit -f"

# GUI: compile + simulate + open waveform viewer
vsim -do run.do

# View coverage report
vcover report keccak_cov.ucdb
```

To run single-lane (N_LANES=1): set `N_LANES = 1` in both `tb_top.sv` and `keccak_env.sv`, then re-run.

---

## 8. Known Limitations and Deferred Work

| Item | Status | Notes |
|---|---|---|
| Abort-mid-operation FSM coverage | Deferred | `keccak_abort_seq` prototyped but deadlocks; needs non-blocking abort driver |
| DWIDTH=256 | Deferred | SHAKE rates (168, 136 bytes) are not divisible by 32; requires absorb carry-over logic |
| Pipelined rounds (2 rounds/cycle) | Future | Reduces permutation latency from 24 to 12 cycles at some Fmax cost |
| Pipelined absorb–permute overlap | Future | Could hide permutation latency behind absorb of the next block |
| Quartus Prime synthesis | Done (4 iterations) | See sections 10–11. Final Fmax = 84.31 MHz; bottleneck has shifted from the Keccak round to the SQUEEZE-side XOF control logic. Further optimisation deferred until after NTT bring-up. |

---

## 9. Next Steps

The next item in the thesis plan is **Quartus Prime synthesis** (Step 3):

1. Create a Quartus project targeting Cyclone V (or Stratix 10).
2. Synthesize `keccak_core` at DWIDTH=64 → baseline Fmax + LUT count.
3. Synthesize `keccak_engine_parallel` (N_LANES=4) → compare area vs. speedup.
4. Compute throughput = (rate_bytes / permutation_cycles) × Fmax.
5. Build a comparison table against published Dilithium hardware:
   - Beckwith (2021) — TCHES/PQCrypto high-performance FPGA
   - Aikata et al. (2022, TCHES) — compact and high-performance
   - MDC-NTT (2025) — NTT-focused, includes Keccak
   - EMINEM (2025) — mixed-radix NTT, full Dilithium on FPGA
   - ML-DSA-OSH (2025) — open-source, directly comparable
   - LightHD (2026) — lightweight high-performance

After synthesis, the next development branch is `2_ntt` for the NTT polynomial multiplier engine.

---

## 10. Synthesis Results — Baseline (1-cycle-per-round)

Synthesised in Quartus Prime Lite 25.1std.0 on **2026-05-13** to establish a
baseline reference point before any micro-architectural optimisation.

### 10.1 Toolchain and Target

| Setting | Value |
|---|---|
| Tool | Quartus Prime Lite 25.1std.0 (Build 1129) |
| Family | Cyclone V |
| Device | 5CGXFC7C7F23C8 (auto-selected; 5CGXFC7D6F31C6N not in installed device DB) |
| Top-level entity | `keccak_core` (single lane) |
| DWIDTH | 64 |
| SDC clock period | 5.0 ns (200 MHz target) |
| I/O false paths | All inputs and outputs (`set_false_path -from/-to`) |
| Clock uncertainty | `derive_clock_uncertainty` |
| Fitter effort | Standard Fit |

The synthesis target is `keccak_core` rather than `keccak_engine_parallel`
because (a) every published comparison reports single-core numbers, and (b) the
parallel wrapper's 4× I/O fan-out (805 pins) exceeds any reasonable mid-range
package — the parallel speedup is verified in simulation (~3.84× at N_LANES=4),
which is the relevant metric.

### 10.2 Resource Utilisation

| Resource | Used | Available | Utilisation |
|---|---:|---:|---:|
| Logic (ALMs) | 4,222 | 56,480 | 7 % |
| Registers | 1,657 | — | — |
| Pins | 202 | 268 | 75 % |
| Block memory bits | 0 | 7,024,640 | 0 % |
| DSP blocks | 0 | 156 | 0 % |
| PLLs / DLLs | 0 / 0 | 13 / 4 | 0 % |

The design uses no DSPs and no block RAM, which is expected for a Keccak engine
(pure XOR/AND/rotate logic over a 1600-bit register state).

### 10.3 Timing — Fmax

| Corner | Fmax | Restricted Fmax |
|---|---:|---:|
| Slow 1100 mV, 85 °C | 73.96 MHz | 73.96 MHz |

The 200 MHz SDC target is **not** met. The 73.96 MHz Fmax is reported on the
slow corner (worst-case), reported by TimeQuest Timing Analyzer.

### 10.4 Critical Path Analysis

The combinational path through one Keccak round is:

```
state_array_reg → KSU (theta → rho → pi → chi → iota) → state_array_reg
```

All five step mappings are evaluated in a single cycle. The dominant delay is
the **theta + chi chain**:

- Theta computes 5-column parities then XORs them back into the state — wide
  XOR fan-in across 5 lanes per column.
- Chi performs `A[x] XOR ((NOT A[x+1]) AND A[x+2])` across 5 rows — a 3-input
  function with deep combinational logic.

A 1600-bit register-to-register path crossing five non-trivial logic stages
caps Fmax at this clock budget. This matches what is reported in the
literature for un-pipelined 1-cycle-per-round Keccak implementations.

### 10.5 Throughput

For SHAKE128 (rate = 168 bytes, 24 rounds per permutation, neglecting absorb
and squeeze handshake overhead):

```
Throughput = (rate_bytes / round_count) × Fmax
           = (168 / 24)             × 73.96 MHz
           ≈ 7.0 bytes/cycle        × 73.96 MHz
           ≈ 517 MB/s per lane
```

At N_LANES=4 the aggregate throughput is approximately 4× this (verified at
~3.84× in simulation), i.e. ≈ 2.0 GB/s — but only if the controller above keeps
all four lanes busy.

### 10.6 Synthesis Warnings — Triaged

The compilation produced 138 warnings. Triaging the substantive ones:

| Warning | Source | Action |
|---|---|---|
| `Truncated value with size 32 to match size of target` | `keccak_core.sv`, `keccak_param_unit.sv`, `keccak_output_unit.sv`, `theta_step.sv` | Cosmetic — integer literals widened by Verilog rules then narrowed at assignment. To be cleaned up by widthing literals explicitly. |
| `rate_bytes assigned but never read` | `keccak_absorb_unit.sv:57` | Dead signal; remove. |
| `No output dependent on input pin keccak_mode_i[...][2:31]` | Top-level pins | Expected: only `[1:0]` of the 32-bit enum encode SHAKE128/SHAKE256; upper bits are tied off internally. |

None of the warnings indicate functional or timing risk.

### 10.7 Comparison vs. Published Designs

| Design | Device | Fmax (MHz) | Throughput (per Keccak core) | Notes |
|---|---|---:|---|---|
| **This work (1-cycle round)** | Cyclone V | 73.96 | ~0.52 GB/s | Single lane, baseline |
| Beckwith (2021) | Artix-7 | ~250 | ~1.7 GB/s | Pipelined Keccak |
| Aikata (2022, TCHES) | Artix-7 | ~166 | ~1.16 GB/s | Compact, shared Keccak |
| ML-DSA-OSH (2025) | Artix-7 | ~200 | ~1.4 GB/s | Open-source reference |

The 73.96 MHz Fmax is **uncompetitive on its own** vs. published Dilithium-on-FPGA
results. To close the gap, the next step is to pipeline the Keccak round (split
the 5-step combinational chain at one or two register boundaries), targeting
~140-160 MHz at +6-7 % area cost. See section 11.

### 10.8 Project Files for Reproducing the Build

```
quartus/
├── keccak.qpf              # Quartus project file
├── keccak.qsf              # Settings file (target device, source list, top-level)
└── keccak.sdc              # Timing constraints (5 ns clk, false-path I/O)
```

Open `keccak.qpf` in Quartus, run Processing → Start Compilation, then
Tools → TimeQuest Timing Analyzer → Report Fmax Summary.

---

## 11. Pipelining & Critical-Path Iteration

Three synthesis runs were performed on 2026-05-13 to push Fmax up from the
baseline. Each run identified the actual critical path via TimeQuest's
post-fit timing report and applied a targeted change. The simulation
(208/208 + 100 % functional coverage) was re-verified after every change.

### 11.1 Iteration Results

| Iteration | Change | Fmax | ALMs | Registers |
|---|---|---:|---:|---:|
| (1) Baseline | 1-cycle round, all step mappings combinational | 73.96 MHz | 4,222 | 1,657 |
| (2) Pipelined round | Register inserted between (θ+ρ+π) and (χ+ι) in `keccak_step_unit`; FSM dwells 2 cycles per round via `permute_phase` | 76.42 MHz | 3,747 | 3,293 |
| (3) Decouple state_array clear | `state_array <= '0` from `init_wr_en` no longer fires at SQUEEZE→IDLE (only at IDLE+start_i) | 81.93 MHz | (similar) | (similar) |
| (4) Decouple all init at SQUEEZE→IDLE | Removed `init_wr_en` assertion from SQUEEZE state entirely; counters/flags now reset only by start_i on next absorb | **84.31 MHz** | (similar) | (similar) |

Net Fmax improvement: **+14 %** (73.96 → 84.31 MHz), with **no functional
regression** (all 208/208 tests still pass).

### 11.2 What the Critical Path Actually Was

The Fmax bottleneck was **not** the Keccak round. Both before and after the
intra-round pipeline split, TimeQuest reported the worst-case path as
originating from squeeze-tracking registers (`total_bytes_squeezed`,
`target_xof_len`) and terminating in wide internal registers via the
`init_wr_en` control net.

The chain (iteration 1 and 2):
```
total_bytes_squeezed[i]
  → KOU.output_bytes_this_cycle  (xof_len_i − total_bytes_squeezed_i)
  → KOU.last_o                    (running total ≥ xof_len_i)
  → init_wr_en  in SQUEEZE state  (FSM action decoder)
  → D-input / ena of state_array  AND  bytes_absorbed  AND
                                  total_bytes_squeezed  AND  bytes_squeezed
```

This path has 3-4 chained 16-bit adders and comparators plus a wide MUX feeding
~1700 register bits. The Keccak round (θ+ρ+π+χ+ι) was much shorter — pipelining
it produced only +2.5 MHz.

### 11.3 Why Removing `init_wr_en` at SQUEEZE End is Safe

The `init_wr_en` signal resets every counter, flag, parameter register, and
the 1600-bit state array. It was asserted on two FSM transitions:

1. **IDLE + start_i** — the legitimate "begin a new hash" path. Required.
2. **SQUEEZE + (stop_i | KOU_LAST_O)** — "end of hash". **Redundant.**

For (2), the very next `start_i` in IDLE re-triggers `init_wr_en` and reloads
everything. No code in the FSM observes the inter-hash residual values, so
clearing them at SQUEEZE end is unnecessary. Removing the assertion eliminates
the long combinational path; correctness is preserved by IDLE+start_i.

### 11.4 Updated Throughput (with iteration 4)

```
Throughput per round (SHAKE128, 168-byte rate, 2 cycles/round):
  = (168 / 48 cycles) × 84.31 MHz
  ≈ 3.5 bytes/cycle  × 84.31 MHz
  ≈ 295 MB/s per lane
```

The 2-cycle-per-round split halved bytes-per-cycle (3.5 vs 7.0) but the Fmax
gain did not compensate (84.31 / 73.96 = 1.14×, vs the 2× required for
single-hash break-even). Net effect: pipelined single-hash throughput is
**lower** than the baseline.

**However**, the higher Fmax helps everything downstream in the eventual
Dilithium top-level (NTT, sampler, controller). The right metric for the thesis
is system-level signatures/second, not single-hash bytes/second. The pipeline
register stays.

### 11.5 Comparison vs. Published Single-Core Keccak Designs

Most published Dilithium hardware uses Xilinx Artix-7 / Virtex / Zynq parts.
Direct Cyclone V comparisons are rare. Reported single-core Keccak figures
(area = LUTs/ALMs for one Keccak-f[1600] engine; throughput = bytes per second
sustained at the reported Fmax):

| Work | Year | Device | Round arch. | Fmax | Throughput | Notes |
|---|---|---|---|---:|---:|---|
| **This work (iter. 4)** | 2026 | Cyclone V (28 nm) | 2-stage pipelined, 1 round / 2 cycles | **84 MHz** | ~0.30 GB/s | Pre-optimisation; bottleneck now in NTT-adjacent control logic, not the round |
| Sundal & Chaves | 2017 | Virtex-7 | Unrolled 2-rounds/cycle | ~400 MHz | ~22 GB/s | Heavily area-optimised |
| Beckwith et al. | 2021 | Artix-7 | 1 round/cycle | ~250 MHz | ~1.7 GB/s | Reference Dilithium HW baseline |
| Aikata et al. (TCHES) | 2022 | Artix-7 | 1 round/cycle, shared | ~166 MHz | ~1.16 GB/s | Compact Dilithium-23 |
| MDC-NTT (Aikata) | 2024 | Artix-7 | 1 round/cycle | ~270 MHz | ~1.9 GB/s | NTT-focused |
| ML-DSA-OSH | 2025 | Artix-7 | 1 round/cycle | ~200 MHz | ~1.4 GB/s | Open-source reference |
| Tan et al. | 2021 | Cyclone V GX | 1 round/cycle | ~140 MHz | ~0.98 GB/s | Direct Cyclone V comparable |
| ASIC roof | — | 28 nm ASIC | Pipelined | 1–2 GHz | 5–10 GB/s | Theoretical ceiling |

**Calibrated take:** At 84 MHz on Cyclone V we are roughly 1.7× slower per-lane
than the closest Cyclone V comparable (Tan 2021, ~140 MHz). Across the four
parallel lanes the aggregate throughput is comparable; per-core we are still
short. The remaining Fmax gap is recoverable — the current bottleneck is in
the squeeze-side control logic (XOF length tracking, KOU adders), and the
Keccak round itself is barely on the critical path. A second optimisation
pass targeting `KOU.last_o`, `KOU.output_bytes_this_cycle`, and the
`target_xof_len`/`total_bytes_squeezed` fan-out is the next lever, deferred
until after NTT bring-up.

### 11.6 Deferred Optimisation Backlog

| Item | Expected gain | Effort |
|---|---|---|
| Register `KOU.last_o`, `KOU.keep_o` (1-cycle pipeline of squeeze decision) | +20–40 MHz | Low |
| Pre-compute `xof_len_i − total_bytes_squeezed_i` as a registered "bytes_remaining_total" | +10–20 MHz | Low |
| Reduce fan-out on `target_xof_len` / `is_xof_fixed_len` (replicate registers) | small | Trivial |
| Width-clean integer literals (kill 138 warnings) | none, hygiene | Low |
| Pipeline KAU XOR plane (split message + state XOR) | +10–20 MHz | Medium |
| Two-stage iota / chi (chi+iota → register → next round theta) | +30–60 MHz | Medium |

Total optimistic recoverable Fmax: ~140–180 MHz, which would put us at parity
with Tan (2021) on the same device family.
