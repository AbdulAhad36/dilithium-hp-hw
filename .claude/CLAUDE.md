# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hardware implementation of the **CRYSTALS-Dilithium** post-quantum digital signature scheme. The repository is organised **one module per branch**:

| Branch | Module |
|---|---|
| `main` | Dilithium software reference model + shared docs only |
| `1_hashing` | Keccak/SHAKE hashing engine (SHAKE128/256) |
| `2_ntt` | **NTT engine — the current branch** |

This branch (`2_ntt`) implements the **Number-Theoretic Transform** — the polynomial-multiplication primitive of Dilithium. It performs forward NTT, inverse NTT (with 1/N scaling), and pointwise multiplication over the ring `Z_q[x]/(x^256 + 1)`. All RTL is SystemVerilog, simulated with **QuestaSim** and synthesised with **Quartus Prime Lite 25.1std** for **Cyclone V** (`5CGXFC7C7F23C8`).

`2_ntt` was branched from `1_hashing` with all keccak files removed (RTL, testbenches, `docs/keccak_docs/`, keccak Quartus project). The keccak module still lives on `1_hashing` and in history. GitHub issue **#2** tracks NTT work; the living design doc is `docs/ntt-design-and-verification.md`.

## Simulation Commands

All simulation runs from the `sim/` directory. The do-files use NTT-specific names (`ntt_run.do`, `ntt_cov.ucdb`, `ntt_work`) so this branch never collides with the keccak sim flow.

```bash
cd sim

# THE regression: compile RTL + full UVM env, simulate, coverage, waveform
vsim -do ntt_run.do                        # GUI
vsim -c -do "do ntt_run.do; quit -f"       # headless

# Directed (non-UVM) self-checks for individual layers:
vsim -c -do "do ntt_ref_check.do;    quit -f"   # golden model self-check (208/208)
vsim -c -do "do ntt_core_check.do;   quit -f"   # ntt_core directed     (33/33)
vsim -c -do "do ntt_engine_check.do; quit -f"   # ntt_engine directed   (23/23)

# View coverage after a UVM run
vcover report ntt_cov.ucdb
```

`ntt_run.do` compiles RTL package-first, then the UVM TB, and runs with `-coverage -voptargs=+acc`. Coverage is saved to `sim/ntt_cov.ucdb`.

## Synthesis Commands

Quartus Prime Lite 25.1std lives at `F:\altera\quartus\bin64\`. The project is in `quartus/` (`ntt.qpf` / `ntt.qsf` / `ntt.sdc`), top-level entity **`ntt_engine`**, target device `5CGXFC7C7F23C8` (same device as the keccak benchmark, for apples-to-apples comparison). Run headless:

```powershell
$Q = "F:\altera\quartus\bin64"
& "$Q\quartus_map.exe" ntt -c ntt      # analysis & synthesis
& "$Q\quartus_fit.exe" ntt -c ntt      # place & route
& "$Q\quartus_sta.exe" ntt -c ntt      # timing analysis -> Fmax
```

Reports land in `quartus/output_files/` (`ntt.fit.rpt` for area, `ntt.sta.rpt` for Fmax). All Quartus build artifacts (`output_files/`, `db/`, `incremental_db/`, `*.qws`, …) are gitignored; only `ntt.qpf`, `ntt.qsf`, `ntt.sdc` are tracked.

## Architecture

### RTL — `src/ntt_engine/`

`ntt_engine` is the synthesisable top-level: it wraps the verified `ntt_core` with an AXI4-Stream-style I/O front-end (one 23-bit coefficient per beat).

```
start_i pulse ->
  OP_NTT  / OP_INTT : RX A (256)            -> RUN -> TX (256)
  OP_PWM            : RX A (256) -> RX B(256) -> RUN -> TX (256)
```

| Module | Role |
|---|---|
| `ntt_pkg.sv` | Ring params, `bf_mode_e` (CT/GS) and `ntt_op_e` (NTT/INTT/PWM) enums (`BARRETT_*` constants now vestigial) |
| `mod_mul.sv` | 3-cycle pipelined modular multiplier — **q-specific shift-add reduction**: one `a·b` multiply + four shift-add folds (`2²³≡2¹³−1 mod q`) + ≤1 conditional subtract. Replaced Barrett (18→6 DSP, 63→75 MHz) |
| `butterfly_unit.sv` | Configurable radix-2 butterfly: **CT** (forward) or **GS** (inverse). 4-cycle latency (3-cycle `mod_mul` + 1) |
| `twiddle_rom.sv` | 256 precomputed twiddles `zeta^bitreverse8(i) mod q` |
| `ntt_core.sv` | The compute worker: control FSM, conflict-free address generation, **2×2 butterfly tile** (4 BFUs), and the **4-bank coefficient memory** |
| `ntt_engine.sv` | AXI-Stream front-end FSM wrapping `ntt_core` |

### The 2×2 butterfly tile (`ntt_core`)

The core processes **4 coefficients per cycle** through 4 butterfly units in two ranks: BFU0/1 (rank-s) feed BFU2/3 (rank-t) **directly via muxes — no memory hop between the two collapsed stages** (intra-tile forwarding, halves memory traffic). This collapses the 8 radix-2 NTT stages into **`N_PASSES = 4`** memory passes of 64 tiles each.

**4-bank conflict-free memory:** the flat 256×23 coefficient array is split into 4 banks of 64×23 via the XOR bank function `bank(addr) = addr[1:0]^addr[3:2]^addr[5:4]^addr[7:6]` (offset = `addr[7:2]`). Every tile across all NTT/INTT passes maps to a permutation of {bank 0..3}, so each bank needs only **1R+1W per cycle** — exactly a Cyclone V dual-port M10K. A 4-way combinational crossbar routes the 4 tile positions to the 4 physical banks. `OP_PWM` uses a second bank set (`bank_mem_b`) for operand B.

### FSM States

`ntt_core`:
```
S_IDLE → S_RUN → S_RDRAIN → [S_SCALE → S_SDRAIN  (INTT only)] → S_DONE
S_IDLE → S_PWM → S_PDRAIN → S_DONE                              (PWM)
```
- `S_RUN` issues one tile/cycle across the 4 passes; `S_RDRAIN` flushes the BF pipeline at each pass/stage boundary.
- `S_SCALE`/`S_SDRAIN`: INTT-only final pass multiplying every coeff by `N_INV` (1/N scaling), 4 coeffs/cycle.
- `S_PWM`/`S_PDRAIN`: pointwise multiply using all 4 BFUs in CT mode with `a=0, b=A[i], z=B[i]`.

`ntt_engine`:
```
E_IDLE → E_RX_A → [E_RX_B (PWM only)] → E_RUN_START → E_RUN_WAIT → E_TX_RD → E_TX_VALID → E_DONE
```

### Cycle counts (compute-only, measured via UVM)

| Op | Cycles | Notes |
|---|---|---|
| NTT  | ~297 | ≤300 thesis target met |
| INTT | ~370 | includes the SCALE pass |
| PWM  | ~74  | 64 issue + 10 drain (no inter-stage forwarding needed) |

### Testbenches — `tb_uvm/tb_uvm_ntt/`

**THE UVM environment** targets `ntt_engine` and reuses the keccak-v2 pattern: no clocking blocks (`@(posedge vif.clk)` + direct `vif.<sig>`), per-transaction async reset, driver↔monitor sync via a `collection_done` uvm_event, and **every transaction golden-compared** (no skip path). Single agent (the engine is not a parallel wrapper).

| File | Role |
|---|---|
| `ntt_ref_pkg.sv` | **Golden model** — pure-SV `ntt_fwd` (CT), `ntt_inv` (GS + ×N_INV), `pwm`, and an independent negacyclic schoolbook `poly_mul`. Direct port of the Dilithium reference `ntt()`/`invntt_tomont()`. |
| `ntt_if / _transaction / _sequence / _driver / _monitor / _agent / _scoreboard / _coverage / _env / _tests` | Standard UVM components |
| `tb_top.sv` | UVM TB top — instantiates `ntt_engine` + one `ntt_if` |
| `tb_ntt_ref.sv` | Standalone golden-model self-check (208/208), run via `ntt_ref_check.do` |
| `tb_ntt_core.sv` | Directed `ntt_core` golden-compare (33/33), run via `ntt_core_check.do` |
| `tb_ntt_engine.sv` | Directed `ntt_engine` golden-compare (23/23), run via `ntt_engine_check.do` |

**Verification status (2026-05-25):** UVM **53/53**, **100% functional coverage**, 0 errors. Directed: golden 208/208, core 33/33, engine 23/23. The engine supports NTT/INTT/PWM end-to-end.

### Key Parameters (`ntt_pkg.sv`)

- `Q = 8380417` (= 2²³ − 2¹³ + 1), `N = 256`, `LOGN = 8`, `COEFF_W = 23`
- `ZETA = 1753` (2n-th root of unity), `N_INV = 8347681` (256⁻¹ mod q)
- `COEFFS_PER_CYCLE = 4`, `N_PASSES = LOGN/2 = 4`
- `mod_mul` uses the q-specific shift-add reduction (`2²³≡2¹³−1 mod q`); the `BARRETT_K=46`, `BARRETT_M=8396807` constants remain but are vestigial

## Status & Next Steps

Branch `2_ntt` is **feature-complete, fully verified, and synthesised + optimised** on Cyclone V. Current measured: **75.44 MHz, 6 DSP, 2,313 ALM, 18 M10K**, NTT ~299 cyc (~3.96 µs). Optimisation done 2026-06-04: A1 (register addr-gen) + D1 (register datapath inputs) + the **q-specific shift-add reduction** replacing Barrett — cumulatively **56.85→75.44 MHz (+33 %), DSP 18→6 (−67 %)**, all golden-compared. **ATP** is the honest win condition; Fmax is device-limited (Cyclone V trails Artix-7/Versal on raw MHz — a device gap, not a design gap). **Always re-read the actual TimeQuest critical path after every change** — proven 4× this branch; the real win was the algorithmic reduction swap, not registering. See `docs/ntt-design-and-verification.md` §7.1/§7.2.

Deferred to a later **integration branch**: register `mod_mul` inputs (last cheap Fmax lever → ~110–120 MHz), radix-4 evaluation, decoupling input FIFO, and the sampler→NTT pipelined reordering path (PALS-style). See `docs/ntt-design-and-verification.md` §8.
