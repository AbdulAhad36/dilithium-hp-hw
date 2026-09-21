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
- `2_ntt`: active NTT/INTT/PWM engine branch.

## Current State

- Keccak/SHAKE branch is complete and verified:
  - SHAKE128/SHAKE256 only.
  - 4-lane verification wrapper.
  - 208/208 UVM tests passing.
  - 100% functional coverage.
  - Quartus result: about 84.31 MHz single-core on Cyclone V.

- NTT branch is complete and verified:
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
- Verify before claiming correctness.
- Re-run Quartus synthesis and `report_paths.tcl` after RTL timing changes.
- Treat `.vscode/settings.json`, `sim/ntt_run.do`, and midyear DOCX changes as
  existing user workspace changes unless explicitly told otherwise.
