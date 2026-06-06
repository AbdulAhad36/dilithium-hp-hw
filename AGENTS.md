# AGENTS.md — AI Agent Onboarding

This file is the entry point for any AI coding agent (Codex, Claude Code, etc.)
working on this repository. Read this first, then read the living design document
at `docs/ntt-design-and-verification.md` for full context.

## What this repo is

M.Engg IC Design thesis: **hardware implementation of CRYSTALS-Dilithium (ML-DSA,
FIPS-204)** in SystemVerilog, synthesised on Cyclone V FPGA. One module per branch.

| Branch | Module | Status |
|---|---|---|
| `main` | Software reference model + shared docs | stable |
| `1_hashing` | Keccak/SHAKE-128/256 engine | complete, 84 MHz on Cyclone V |
| `2_ntt` | **NTT engine (current active branch)** | complete + optimised |

## Current branch: `2_ntt` — NTT/INTT/PWM engine

Polynomial multiplication over `Z_q[x]/(x^256+1)`, q=8380417, n=256.

### Architecture (src/ntt_engine/)
- `ntt_pkg.sv` — ring params, enums (`BARRETT_*` constants vestigial now)
- `mod_mul.sv` — 3-cycle pipelined modular multiplier, **q-specific shift-add reduction** (`2^23 ≡ 2^13−1 mod q`; one multiply + four shift-add folds; replaced Barrett 2026-06-04)
- `butterfly_unit.sv` — CT (forward) / GS (inverse) radix-2 butterfly, 4-cycle latency
- `twiddle_rom.sv` — 256 precomputed twiddles
- `ntt_core.sv` — 2×2 butterfly tile, 4-bank conflict-free BRAM memory, FSM
- `ntt_engine.sv` — AXI-Stream front-end wrapping ntt_core

### Verification (tb_uvm/tb_uvm_ntt/)
- `ntt_ref_pkg.sv` — pure-SV golden model (NTT/INTT/PWM + schoolbook poly_mul)
- Full UVM environment: driver, monitor, scoreboard, coverage, sequences
- **Status: 53/53 UVM, 33/33 core, 23/23 engine, 100% functional coverage**

### Synthesis results (Quartus Prime Lite 25.1std, Cyclone V 5CGXFC7C7F23C8)
| Metric | Value |
|---|---|
| Fmax | 75.44 MHz (Slow 85°C) |
| ALMs | 2,313 / 56,480 |
| DSP | 6 / 156 |
| M10K | 18 / 686 |
| NTT latency | ~299 cyc ≈ 3.96 µs |

## Commands

### Simulation (run from sim/)
```bash
# Full UVM regression (headless)
vsim -c -do "vlib ntt_work; vmap work ntt_work; do ntt_run.do; quit -f"

# Directed checks
vsim -c -do "do ntt_core_check.do;   quit -f"   # 33/33
vsim -c -do "do ntt_engine_check.do; quit -f"   # 23/23
vsim -c -do "do ntt_ref_check.do;    quit -f"   # 208/208
```

### Synthesis (run from quartus/)
```powershell
$Q = "F:\altera\quartus\bin64"
& "$Q\quartus_map.exe" ntt -c ntt   # synthesis
& "$Q\quartus_fit.exe" ntt -c ntt   # place & route
& "$Q\quartus_sta.exe" ntt -c ntt   # timing (Fmax)
& "$Q\quartus_sta.exe" -t report_paths.tcl   # critical path detail
```
Reports land in `quartus/output_files/`.

## What was done (most recent first)

- **2026-06-04** — Full Fmax/area optimisation: A1 (register addr-gen) + D1
  (register datapath inputs) + **R (shift-add reduction)**: 56.85→75.44 MHz,
  DSP 18→6. All steps verified before committing. Design doc §7.1/§7.2 records
  the full progression and honest ATP comparison vs published designs.
- **2026-06-04** — First synthesis pass (Barrett baseline): 56.85 MHz, 18 DSP.
  Critical path was read-address generation, NOT the datapath.
- **2026-05-25** — OP_PWM complete. UVM 53/53, 100% coverage.
- **2026-05-24** — 4-bank conflict-free BRAM memory (M10K inference confirmed).
- **2026-05-24** — 2×2 butterfly tile + intra-tile forwarding (~297 NTT cycles).
- **2026-05-23** — Full UVM environment, ntt_core+engine verified end-to-end.

## What is next

**Remaining Fmax headroom (optional, this branch):**
Register `mod_mul` inputs to isolate the surviving `a·b` multiply → ~110–120 MHz.
+1 cycle latency; ripples `BF_LAT` through `butterfly_unit` + `ntt_core`. See
`docs/ntt-design-and-verification.md` §8.

**Integration branch (next major milestone):**
- Keccak + NTT + rejection sampler dataflow
- Pipelined sampler→NTT reordering (PALS-style, avoids ~62-cycle bubble)
- Right-size keccak N_LANES (probably 1–2, not 4)
- Full Dilithium signing path

## Key invariants — do not break

1. **Always re-run synthesis + `report_paths.tcl` after any RTL change** before
   claiming a Fmax improvement. The critical path moves every time.
2. **Verify before committing**: all three directed checks + UVM must pass.
   The golden model in `ntt_ref_pkg.sv` is the arbiter of correctness.
3. **One module per branch**: do not mix keccak RTL into `2_ntt` or vice versa.
4. `ntt_run.do` has its `vdel`/`vmap` lines commented out (fast-iteration mode).
   If the sim library gets stale, prepend `vlib ntt_work; vmap work ntt_work;`
   or restore those lines.

## Living design document

`docs/ntt-design-and-verification.md` — the canonical reference. Covers the
NTT mathematics, all architecture decisions + rationale, the full verification
plan, synthesis results progression (§7.1), and honest ATP comparison vs
published designs (§7.2). Read §4.2 for the shift-add reduction, §7.1 for the
optimisation story, §8 for what is still deferred.
