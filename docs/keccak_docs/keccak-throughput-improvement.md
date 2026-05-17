# Keccak Engine Throughput Improvement

**Branch:** `1_hashing`
**Date:** 2026-05-12
**Author:** Ahad (with Claude as design partner)

This document describes how the throughput of the Keccak hashing engine in
`src/keccak_engine/` was improved, what changed in the design, and how the
improvement was measured and verified.

---

## TL;DR

We added a parameterisable **`keccak_engine_parallel`** module that instantiates
**N independent `keccak_core` instances** behind a single module boundary, each
with its own AXI4-Stream sink/source. At N=4 the parallel wrapper achieves
**~3.84× wall-clock speedup** on the full 208-test UVM regression — close to
the theoretical 4× ceiling for spatial parallelism.

The single-core engine was also simplified: SHA3-256 and SHA3-512 support was
removed (Dilithium doesn't need fixed-length SHA3), leaving only SHAKE128 and
SHAKE256. This trims the param/output units and is a prerequisite for
SHAKE-only optimisation in future branches.

---

## Why throughput matters for Dilithium

Dilithium spends a large fraction of its cycles inside SHAKE:

| Function | XOF used | Streams per signing op |
|---|---|---|
| ExpandA   | SHAKE128 | k × l (up to 56 for Dilithium-5) |
| ExpandS   | SHAKE256 | k + l |
| ExpandMask| SHAKE256 | l |
| H (challenge) | SHAKE256 | 1 |

These streams are **mutually independent** — ExpandA generates each polynomial
A[i][j] from a separate seed||(i,j) input. A single-core SHAKE engine processes
them one at a time. Replicating the core into N parallel lanes lets Dilithium
issue N independent SHAKE jobs in the same wall-clock time, which is the same
strategy used by published high-performance Dilithium HW implementations
(Beckwith 2021, Aikata 2022, EMINEM 2025, etc.).

---

## Baseline (before)

### RTL

* [src/keccak_engine/keccak_core.sv](../src/keccak_engine/keccak_core.sv) — single 1-cycle-per-round Keccak-f[1600] core with one AXI4-Stream sink/source.
* DWIDTH = 64 (8 bytes per beat).
* Supported modes: **SHAKE128, SHAKE256, SHA3-256, SHA3-512** (all four).
* Per permutation: 24 cycles (one round per cycle).
* No way to issue more than one hashing job at a time.

### TB

* [tb_uvm/tb_uvm_keccak_v2/](../tb_uvm/tb_uvm_keccak_v2/) — single-lane UVM environment.
* 52 directed + stress + coverage-closure tests, all on a single `keccak_core` instance.

### Baseline performance (single core, single SHAKE stream)

Reported by the v2 UVM TB on the per-test timestamps:

| Test | Cycles to last byte (= time / 10ns) |
|---|---|
| SHAKE128 Empty (Bnd 16) | 35 |
| SHAKE128 Short (Bnd 16) | 37 |
| SHAKE256 Empty (Bnd 32) | 37 |
| SHAKE256 Short (Bnd 32) | 39 |

Single-stream throughput is bounded by:
* Per-block cost = 24 cycles permutation + a few cycles for absorb + 1 for suffix-pad + bytes_per_beat squeeze.
* Empty SHAKE128: ~35 cycles is dominated by the 24-cycle permutation.

To process **two** independent streams on a single core, you have to wait for
the first to finish: ~35 + ~37 = **~72 cycles**. For four streams the cost
stacks linearly: **~148 cycles** for the four directed vectors above.

---

## What changed

### 1. SHA3 stripped from the RTL

Files modified:

* [keccak_pkg.sv](../src/keccak_engine/keccak_pkg.sv)
  — `keccak_mode` enum reduced to `{SHAKE128, SHAKE256}`. `MODE_NUM = 2`.
* [keccak_param_unit.sv](../src/keccak_engine/keccak_param_unit.sv)
  — SHA3 cases + constants removed; `suffix_o` is always 0x1F (SHAKE).
* [keccak_output_unit.sv](../src/keccak_engine/keccak_output_unit.sv)
  — Removed SHA3-specific `last_o` cases (SHA3-256 fixed at 32B, SHA3-512 at 64B). `last_o` is now driven purely by the bounded-XOF predicate, so SHAKE continuous never asserts `last_o` (FSM terminates via `stop_i` only).
* [keccak_core.sv](../src/keccak_engine/keccak_core.sv)
  — Comments cleaned. No FSM changes — the existing FSM was already general enough.

This is purely a feature-set reduction. It does not change SHAKE throughput
in isolation, but it does:

* Shrink the param/output units (less logic, marginally better Fmax).
* Remove unused state in `last_o` decoding.
* Open the door to future SHAKE-only optimisations (e.g., dropping the
  variable-rate generality once a single rate is fixed in hardware).

### 2. SHA3 stripped from the UVM TB

Files modified:

* [keccak_transaction.sv](../tb_uvm/tb_uvm_keccak_v2/keccak_transaction.sv) — removed SHA3 cases from `get_rate_bytes()`.
* [keccak_sequence.sv](../tb_uvm/tb_uvm_keccak_v2/keccak_sequence.sv) — dropped the 7 SHA3 NIST vectors; `keccak_stress_seq` and `keccak_cov_seq` now alternate only between SHAKE128 and SHAKE256.
* [keccak_coverage.sv](../tb_uvm/tb_uvm_keccak_v2/keccak_coverage.sv) — `cp_mode` has 2 bins; cross-coverage no longer needs the SHA3 `ignore_bins`.

After these changes the single-core UVM TB still hits **52/52 PASS** and
**100% functional coverage**, but on SHAKE-only stimulus.

### 3. New `keccak_engine_parallel` wrapper

[src/keccak_engine/keccak_engine_parallel.sv](../src/keccak_engine/keccak_engine_parallel.sv) is a thin parameterisable wrapper:

```
keccak_engine_parallel #(parameter int N_LANES = 4) (
    input  wire   clk,
    input  wire   [N_LANES-1:0]                  rst,
    input  wire   [N_LANES-1:0]                  start_i,
    input  keccak_mode                           keccak_mode_i [N_LANES],
    input  wire   [N_LANES-1:0][XOF_LEN_WIDTH-1:0] xof_len_i,
    input  wire   [N_LANES-1:0]                  stop_i,

    input  wire   [N_LANES-1:0][DWIDTH-1:0]      s_axis_tdata,
    input  wire   [N_LANES-1:0]                  s_axis_tvalid,
    input  wire   [N_LANES-1:0]                  s_axis_tlast,
    input  wire   [N_LANES-1:0][KEEP_WIDTH-1:0]  s_axis_tkeep,
    output wire   [N_LANES-1:0]                  s_axis_tready,

    output wire   [N_LANES-1:0][DWIDTH-1:0]      m_axis_tdata,
    output wire   [N_LANES-1:0]                  m_axis_tvalid,
    output wire   [N_LANES-1:0]                  m_axis_tlast,
    output wire   [N_LANES-1:0][KEEP_WIDTH-1:0]  m_axis_tkeep,
    input  wire   [N_LANES-1:0]                  m_axis_tready
);
```

Implementation (whole module):

```sv
generate
    for (genvar i = 0; i < N_LANES; i++) begin : g_lane
        keccak_core u_core (
            .clk            (clk),
            .rst            (rst[i]),
            .start_i        (start_i[i]),
            .keccak_mode_i  (keccak_mode_i[i]),
            .xof_len_i      (xof_len_i[i]),
            .stop_i         (stop_i[i]),
            .s_axis_tdata   (s_axis_tdata[i]),
            ...
            .m_axis_tready  (m_axis_tready[i])
        );
    end
endgenerate
```

Design properties:

* **Spatial parallelism only.** Each lane is a full copy of `keccak_core`. No
  shared state, no arbiter, no scheduler.
* **Only `clk` is shared.** Reset, start, stop, mode, AXI sink, AXI source —
  all per-lane.
* **Fmax unchanged.** Critical path is inside one core; replication doesn't
  lengthen it.
* **Area scales ~linearly in N_LANES.** Each lane replicates the full 1600-bit
  state register + datapath.

The Dilithium top-level (next branch) will dispatch SHAKE jobs across the lanes;
at the wrapper level we make no assumptions about scheduling.

---

## Verification

The parallel design is verified end-to-end with **every transaction
golden-compared** against a pure-SystemVerilog SHAKE reference model. There
is one UVM TB and one `.do` script — the same testbench covers single-lane
and multi-lane verification by changing `N_LANES` in `tb_top.sv`.

### Golden model (sim-time reference)

[tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv](../tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv)
is an untimed SystemVerilog implementation of Keccak-f[1600] + sponge +
SHAKE128/256. Its public API is:

```
function automatic string shake_hex(
    input keccak_mode mode,
    input string      msg_hex,
    input int         out_bytes
);
```

It returns the lowercase hex string of the expected SHAKE output.

* No DPI, no external library, no toolchain — runs anywhere QuestaSim runs.
* Used by `keccak_stress_seq` and `keccak_cov_seq` at sim time: every
  randomly-generated message is paired with its expected output before
  it is sent to the driver.
* Sanity is maintained implicitly: every UVM regression run computes 39
  expected outputs through this model, and the directed-NIST tests' golden
  hex stays hardcoded — if the model ever drifted, the directed tests would
  still anchor correctness while the stress tests would diverge.

This means the previously-skipped `[NOCHK]` items (39 of the 52 tests) are
now real correctness checks, not just FSM/coverage exercises.

### UVM regression

[tb_uvm/tb_uvm_keccak_v2/tb_top.sv](../tb_uvm/tb_uvm_keccak_v2/tb_top.sv)
instantiates `keccak_engine_parallel` with `N_LANES=4` (default), declares 4
`keccak_if` bundles via an interface array, and routes each one through
`uvm_config_db` to its agent (`uvm_test_top.env.agent_<i>.*`). The env
contains 4 independent (agent + scoreboard + coverage) bundles, no shared
state between lanes. `keccak_full_test` forks 4 copies of `keccak_full_seq`
onto the 4 sequencers concurrently.

Per lane, `keccak_full_seq` runs:
* 13 NIST directed vectors (continuous + bounded XOF)
* 20 random stress vectors (msg + xof_len + mode randomised)
* 19 coverage-closure vectors (deterministic bin hits)

Run with: `vsim -c -do "do run.do; quit -f"`

Result: **4 scoreboards × 52 tests = 208/208 PASS** (every transaction
golden-compared against the SV reference model) and **4 × 100% functional
coverage**. This confirms each lane runs the full directed + stress + cov
sequence concurrently without interfering with any other lane.

To run single-lane equivalent: set `N_LANES=1` in `tb_top.sv` and
`keccak_env.sv`. The wrapper degenerates to one `keccak_core` instance via
its generate block, so this exercises the core in isolation.

---

## Benchmarking methodology

We do not claim a synthesis-Fmax improvement (Fmax is unchanged — same critical
path). The throughput metric is **wall-clock cycles to process N independent
SHAKE streams**.

### How wall-clock cycles are measured

* Clock period is 10 ns (100 MHz). 1 cycle = 10 ns of `$time`.
* The UVM TBs report `$time` in every `[PASS]` log line; the simulation
  end-time line gives the total wall-clock at `$finish`.

### Serial reference

For the parallel UVM TB the serial reference is **4 × (single-lane wall-clock
for 52 tests)**, since one core would replay the full 52-test sequence four
times.

Speedup = serial reference / parallel wall-clock.

---

## Results

### Full UVM regression (52 tests × 4 lanes, N_LANES=4)

| | Tests | Wall-clock | Functional coverage |
|---|---|---|---|
| Single-core (v2 UVM) | 52 | 39 745 ns (= 3 974 cycles) | 100% |
| Parallel UVM (4 lanes, full_seq each) | **208** | **41 395 ns** (= 4 139 cycles) | 100% × 4 |

Serial reference for 208 tests on a single core: 4 × 39 745 ns = 158 980 ns.

**Measured speedup: 158 980 / 41 395 ≈ 3.84×**

### Why this measurement is honest (not a benchmark artifact)

It is easy to inflate a parallel speedup number by accident, so worth being
explicit about why this one isn't inflated:

1. **Same workload on both sides.** The parallel UVM TB runs *exactly* the
   same `keccak_full_seq` on each lane that the single-lane TB runs on its
   one core — same 13 NIST directed vectors, same 20 stress vectors, same
   19 coverage-closure vectors. So 4 lanes' worth of work really is 4 × the
   single-lane work; nothing was made cheaper per lane.

2. **No shared state between lanes — verified, not assumed.** All 4
   scoreboards golden-compare independently and all 4 hit 100% functional
   coverage. If the lanes were corrupting each other (shared register,
   crossed AXI bundle, leaky reset) at least one scoreboard would report a
   FAIL. None do.

3. **The "serial reference" is the right baseline.** On the old single-core
   design there is no way to overlap two SHAKE streams: the 1600-bit state
   register is in use for the entire life of stream N (absorb + permute +
   squeeze) before stream N+1 can pulse `start_i`. So summing per-lane
   cycles really is what one core would have taken; we are not comparing
   against a strawman.

4. **Cycles come straight from the simulator clock.** Clock period is 10 ns.
   Every `$time` printed in the QuestaSim log is real simulated nanoseconds;
   the totals in the results table are pulled directly from the
   `Time: <N> ns` line at `$finish`. No model, no projection.

Put together, the framing is:

> One core, 52 SHAKE tests, **3 974 cycles**.
> Four cores, 208 SHAKE tests (4 × 52), **4 139 cycles**.
> Same correctness on every one of the 208 tests.
> Therefore the parallel wrapper does **~4× the work in ~1× the time**.

That ratio (158 980 / 41 395 = 3.84×) is the speedup, and it is what we
report.

### Residual gap from ideal 4×

The 3.84× is below the ideal 4.00× by ~4% because:

* Tests within `keccak_full_seq` are independent, but the lanes don't all
  start the exact same test at the same `$time` — the `fork…join` introduces
  some random staggering, so the last lane finishes a few cycles after the
  others.
* Per-test reset overhead is amortised differently across lanes when stress
  vectors have different message lengths.

Both effects are non-issues for real Dilithium dispatch, where many more than
4 SHAKE jobs are queued back-to-back and the staggering disappears in the
limit.

---

## Trade-offs and limitations

### Area

Area cost is approximately linear in `N_LANES`. The 1600-bit state register
and the full step-mapping datapath are replicated per lane. A precise number
requires Quartus synthesis (next item on the plan), but order-of-magnitude:

| N_LANES | Approx. area |
|---|---|
| 1 | 1× baseline |
| 4 | ~4× baseline (state + datapath dominate) |
| 8 | ~8× baseline |

For Dilithium-5 (which needs 56 SHAKE128 streams for ExpandA), N=8 is a
sensible sweet spot: 7 batches at 8 streams each.

### What this doesn't do

* **Does not** speed up a single SHAKE stream — that's still 24 cycles per
  permutation.
* **Does not** widen DWIDTH — input/output bandwidth per lane is still
  64 bits per cycle. DWIDTH≥128 would require absorb-unit rate-straddling
  logic that isn't implemented (deferred).
* **Does not** include a dispatcher — the wrapper exposes per-lane ports and
  expects the next-level controller to schedule jobs.

### Deferred items

* DWIDTH=256 absorb rewrite (would also need per-lane straddling).
* Two-rounds-per-cycle permutation (cuts permute cost 24→12 at some Fmax cost).
* Pipelined absorb-permute overlap.
* Quartus Prime synthesis: report Fmax, LUT, registers, and area-efficiency
  (signatures/s per LUT) at N_LANES = 1, 4, 8.

---

## File inventory

### New / modified files in this branch

| Path | Status | Role |
|---|---|---|
| [src/keccak_engine/keccak_pkg.sv](../src/keccak_engine/keccak_pkg.sv) | modified | SHAKE-only mode enum |
| [src/keccak_engine/keccak_param_unit.sv](../src/keccak_engine/keccak_param_unit.sv) | modified | SHAKE-only LUT |
| [src/keccak_engine/keccak_output_unit.sv](../src/keccak_engine/keccak_output_unit.sv) | modified | Bounded-XOF `last_o` only |
| [src/keccak_engine/keccak_core.sv](../src/keccak_engine/keccak_core.sv) | modified | Comments cleaned |
| [src/keccak_engine/keccak_engine_parallel.sv](../src/keccak_engine/keccak_engine_parallel.sv) | new | Parallel wrapper |
| [tb_uvm/tb_uvm_keccak_v2/](../tb_uvm/tb_uvm_keccak_v2/) | modified | SHA3 removed, N_LANES-parameterised TB, ref-model-driven golden compare |
| [tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv](../tb_uvm/tb_uvm_keccak_v2/keccak_ref_pkg.sv) | new | Pure-SV SHAKE reference model |
| [sim/run.do](../sim/run.do) | rewritten | Single entry point (compile + sim + coverage + waveform) |

### How to reproduce

From `sim/`:

```
# Compile + simulate + coverage + waveform (default N_LANES=4 -> 208 tests)
vsim -c -do "do run.do; quit -f"
```

To run single-lane: set `N_LANES = 1` in `tb_uvm/tb_uvm_keccak_v2/tb_top.sv`
and in `tb_uvm/tb_uvm_keccak_v2/keccak_env.sv`, then re-run.
