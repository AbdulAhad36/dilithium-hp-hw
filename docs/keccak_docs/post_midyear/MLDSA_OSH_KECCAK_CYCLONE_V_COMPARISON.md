# ML-DSA-OSH Keccak Cyclone V Comparison

**Date:** 2026-09-13  
**Branch:** `keccak_v2`  
**Device:** Cyclone V `5CGXFC7C7F23C8`  
**Status:** Source, post-synthesis, post-fit, and timing experiments complete

## 1. Purpose

This branch preserves the local one-round-per-clock Keccak design and adds an
unchanged copy of the ML-DSA-OSH Keccak for a controlled comparison on the
same Cyclone V. No result in this report is copied from a paper: verification,
area, timing, and throughput calculations come from this repository's runs.

The imported source is from:

- Repository: `https://github.com/KULeuven-COSIC/ML-DSA-OSH`
- Commit: `751009199ac081091a9059805e6921453bde0154`
- Upstream directory: `ref_combined/src`
- Local vendor directory: `third_party/ML-DSA-OSH/keccak`
- Import integrity: all 16 VHDL files match the upstream files by SHA-256

The vendor VHDL was not edited. Local protocol adaptation, verification, and
Quartus files are outside the vendor directory.

## 2. Local Baseline Restoration

Before creating `keccak_v2`, the local design was returned to the archived
one-round-per-clock source/configuration used around the 147 MHz result. The
complete old fitter database was not archived, so two results must remain
distinct:

| Local result | Constraint | Fmax | Setup | Hold | ALMs | Registers |
|---|---:|---:|---:|---:|---:|---:|
| Archived placement, seed 3 | 147 MHz | 147.21 MHz | +0.010 ns | +0.168 ns | 4,265 | 1,674 |
| Clean rebuild of restored source | 147 MHz | 141.82 MHz | -0.248 ns | +0.169 ns minimum across fast corners | 3,452 | 1,674 |

The clean rebuild proves the one-round architecture is restored, but it does
not recreate the old placement. At its reported 141.82 MHz Fmax, its
permutation-only rates are 992.74 MB/s for SHAKE128 and 803.65 MB/s for
SHAKE256. The archived 147.21 MHz placement corresponds to 1,030.47 MB/s and
834.19 MB/s respectively.

## 3. Integration

The upstream core uses active-low FIFO-style readiness and a header word. The
local adapter translates that protocol to the existing UVM ready/valid
interface without changing the upstream implementation:

- Encodes SHAKE mode, input bit length, and output bit length in the upstream
  header.
- Reverses byte order at the two 64-bit interface boundaries.
- Buffers one input word and one output word to preserve ready/valid behavior.
- Converts bounded output directly.
- Implements the local continuous-output stop behavior with a finite upstream
  request followed by local stop/reset handling.
- Exposes local busy, done, and debug state for the existing testbench.

The four-lane UVM wrapper instantiates four independent adapter/core pairs.
The Quartus performance project synthesizes the native single `keccak_top`,
not the adapter, so area and Fmax describe the imported Keccak core itself.

## 4. Three-Stage Verification

### Stage 1: source VHDL through UVM

The complete regression ran against the original imported VHDL through the
adapter using QuestaSim 2024.1.

| Result | Value |
|---|---:|
| Checked transactions | 888/888 passed |
| Lane totals | 228, 226, 218, 216 passed |
| UVM warnings/errors/fatals | 0 / 0 / 0 |
| Functional coverage | 99.64% (280/281 bins) |
| Total filtered structural coverage | 83.36% |

Structural coverage breakdown:

| Metric | Coverage |
|---|---:|
| Statements | 88.49% |
| Branches | 92.46% |
| Conditions | 68.00% |
| Expressions | 71.87% |
| FSM states | 82.95% |
| FSM transitions | 51.75% |
| Toggles | 95.14% |
| Assertions | 100.00% |
| Directives | 83.33% |

The one missing functional bin is the local internal permutation-step bin.
That internal SystemVerilog observation point does not exist in the unchanged
VHDL core. This is reported as a real scope limitation rather than waived to
produce 100%.

The simulator emits time-zero arithmetic warnings while some upstream VHDL
signals are still unknown before reset settles. They produce no UVM warning or
failure, but remain visible in the transcript.

The full transcript, UCDB, and text summary are preserved in
`sim/mldsa_osh_stage1_full`.

### Common 125-transaction equivalence suite

The same port-only suite, seed, scoreboard, and expected SHAKE outputs were
run against all three DUT representations:

| Representation | Result | Functional coverage | UVM issues |
|---|---:|---:|---:|
| Source VHDL | 125/125 | 72.60% | 0 |
| Post-synthesis functional netlist | 125/125 | 72.60% | 0 |
| Post-fit functional netlist | 125/125 | 72.60% | 0 |

All three `checked_transactions.txt` files have this SHA-256 hash:

`D78A56C2920C75BD27FC280DE8AD60D8C241A7FB58B162CEB70053DD36D902AC`

This proves byte-for-byte agreement for the selected suite. It is strong
simulation evidence, but it is not a formal equivalence proof. The 72.60%
figure is functional coverage of the deliberately smaller common suite; it is
not post-synthesis or post-fit structural code coverage.

## 5. Cyclone V Synthesis and Fit

Quartus Prime 25.1 Standard Lite synthesized and fitted the native upstream
`keccak_top` with High Performance Effort, Standard Fit, physical synthesis,
maximum router timing optimization, seed 1, and virtual non-clock ports.
Internal register paths remain timed. Only unknown board-level input/output
delays are excluded.

| Metric | ML-DSA-OSH result |
|---|---:|
| Slow 85 C Fmax | 143.64 MHz |
| Slow 0 C Fmax | 144.86 MHz |
| Target constraint | 230 MHz (4.348 ns) |
| Slow 85 C setup slack | -2.614 ns |
| Slow 85 C hold slack | +0.363 ns |
| ALMs | 4,251 |
| Registers | 4,455 |
| DSP blocks | 0 |
| Block memory bits | 0 |
| Virtual pins | 133 |

The core does not meet 230 MHz. Its defensible worst-case fitted frequency is
143.64 MHz. Hold timing passes at all analyzed corners; setup fails only
because the requested clock is substantially faster than the fitted Fmax.

The design performs one Keccak-f[1600] round per clock, or 24 clocks per
permutation. At the fitted 143.64 MHz:

- SHAKE128 permutation-only throughput = `168 * 143.64 / 24` =
  **1,005.48 MB/s**.
- SHAKE256 permutation-only throughput = `136 * 143.64 / 24` =
  **813.96 MB/s**.

These are standard core permutation rates. They do not include input/output
transfer clocks, software, UART, or the rest of ML-DSA.

## 6. Direct Comparison

| Core/build | Fmax | SHAKE128 perm. | SHAKE256 perm. | ALMs | Registers |
|---|---:|---:|---:|---:|---:|
| Local archived placement | 147.21 MHz | 1,030.47 MB/s | 834.19 MB/s | 4,265 | 1,674 |
| Local clean restored rebuild | 141.82 MHz | 992.74 MB/s | 803.65 MB/s | 3,452 | 1,674 |
| ML-DSA-OSH clean seed-1 fit | 143.64 MHz | 1,005.48 MB/s | 813.96 MB/s | 4,251 | 4,455 |

Against the clean restored local rebuild, ML-DSA-OSH is 1.82 MHz faster and
12.74 MB/s faster for SHAKE128 permutation throughput, but uses 799 more ALMs
and 2,781 more registers. Against the archived local placement, ML-DSA-OSH is
3.57 MHz slower and has nearly the same ALM count, while still using 2,781
more registers.

The clean rows are the more reproducible comparison. They are still not a
perfect architecture comparison because the two projects use different
interfaces, fitter seeds, and clock targets. No area or performance victory
should be claimed from the archived placement alone.

## 7. Reproduction

Run from the repository's `sim` directory with the required QuestaSim:

```powershell
C:\questasim64_2024.1\win64\vsim.exe -c -do "do run_mldsa_osh_stage1.do; quit -f"
```

The common source suite can be run from an isolated simulation directory after
setting `KECCAK_REPO`:

```powershell
$env:KECCAK_REPO = "D:/GitHub/dilithium-hp-hw"
C:\questasim64_2024.1\win64\vsim.exe -c -do "do ../run_mldsa_osh_stage_suite.do; quit -f"
```

Compile the Quartus project from `quartus/mldsa_osh_keccak`:

```powershell
F:\altera\quartus\bin64\quartus_sh.exe --flow compile mldsa_osh_keccak
```

Generate the post-synthesis functional netlist after Analysis and Synthesis:

```powershell
F:\altera\quartus\bin64\quartus_map.exe mldsa_osh_keccak --read_settings_files=on --write_settings_files=off
F:\altera\quartus\bin64\quartus_eda.exe mldsa_osh_keccak --simulation --functional=on --tool=questasim --format=verilog --output_directory=simulation_postsynth --read_settings_files=on --write_settings_files=off
```

`sim/run_mldsa_osh_netlist.do` runs the common suite against either generated
netlist selected by `MLDSA_OSH_NETLIST`. The preserved post-fit reports and
netlist are in
`quartus/mldsa_osh_keccak/results/postfit_seed1_20260913`.

## 8. Conclusion

The imported ML-DSA-OSH Keccak is functionally correct under the existing
SHAKE128/SHAKE256 environment and remains correct after synthesis and fitting.
On this Cyclone V it delivers approximately 1.005 GB/s SHAKE128
permutation-only throughput at 143.64 MHz, but it does not reach the 230 MHz
target and is register-heavy relative to the clean local core. The local and
upstream designs are close in single-core frequency; the local clean design
currently has the clearer area advantage.
