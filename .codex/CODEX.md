# Codex Project Notes

This folder is the project-local home for Codex working notes, plans, and
generated reading artifacts. Keep repo source files focused on the thesis/RTL;
put Codex-specific summaries and temporary analysis here.

## Repository Context

Thesis: hardware design and verification of CRYSTALS-Dilithium / ML-DSA
(FIPS 204) in SystemVerilog, targeting Intel Cyclone V FPGA.

Branch model:

- `main`: software reference model and shared docs.
- `1_hashing`: Keccak/SHAKE engine.
- `2_ntt`: NTT/INTT/PWM engine branch.
- `keccak_v2`: active two-core interleaved Keccak/SHAKE work.

## Current State

- On `keccak_v2`, the active synthesis top is
  `keccak_dual_interleaved`: two independent one-round-per-clock
  SHAKE128/SHAKE256 cores, shared 64-bit input, tagged 128-bit output,
  and at least 26 clocks between core launches.
- Last recorded source-RTL result: 904/904 standalone-core UVM
  transactions, 81/81 integrated-wrapper jobs, 87.55% weighted
  functional coverage and 99.06% structural code coverage scoped to
  the integrated dual DUT. These were not rerun during the September 27
  documentation audit.
- Last recorded Quartus fit: Cyclone V `5CGXFC7C7F23C8`,
  7,581 ALMs, 3,501 registers, positive setup/hold slack at the
  148 MHz target. Dual-core Stage 2/3 netlist simulations and
  FPGA/UART testing are pending.
- The older four-lane, 208-test, 100%-covergroup and 84.31 MHz
  descriptions belong to historical Keccak checkpoints.

- Historical NTT branch snapshot (refresh on `2_ntt` before citing):
  - Forward NTT, inverse NTT, and point-wise multiply.
  - 2x2 butterfly tile, 4-bank conflict-free memory.
  - q-specific shift-add modular reduction.
  - 208/208 golden model checks, 33/33 core, 23/23 engine, 53/53 UVM passing.
  - 100% functional coverage.
  - Quartus result: 75.44 MHz, 2,313 ALMs, 6 DSP, 18 M10K.

## Important Local Artifacts

- `.codex/doc_extract/`: extracted text and manifests from all PDFs/DOCX under
  `docs/`.
- `.codex/PLAN.md`: current recommended technical plan.
- `.codex/DOC_READING_SUMMARY.md`: summary of what the extracted documents add
  to the thesis.

## Ground Rules

- Do not mix module RTL across branches.
- Verify the exact RTL revision before claiming correctness or coverage.
- Keep source-RTL coverage, mapped-netlist checks, fitted-netlist checks,
  TimeQuest timing and board validation as separate evidence.
- Use `docs/keccak_docs/post_midyear/keccak-design-and-verification.md`
  as the living Keccak progress record; `SPECIFICATION.md`,
  `COVERAGE.md` and `THROUGHPUT.md` explain its current measurements.
- Re-run Quartus synthesis and `report_paths.tcl` after RTL timing changes.
- Treat `.vscode/settings.json`, `sim/ntt_run.do`, and midyear DOCX changes as
  existing user workspace changes unless explicitly told otherwise.
