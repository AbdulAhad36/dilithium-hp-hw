# Document Reading Summary

## Extraction Status

Poppler was installed with `winget`.

Processed documents:

- 41 PDFs under `docs/`
- 5 DOCX files under `docs/`

Extracted text and indexes are in `.codex/doc_extract/`.

## Must-Cite Documents

- FIPS 202: SHA-3 / SHAKE / Keccak standard.
- FIPS 204: ML-DSA standard and final algorithm authority.
- Dilithium Round 3 specification: historical algorithm detail.
- Beckwith 2021: complete high-performance Dilithium hardware.
- Zhao/TCHES 2022: compact/high-performance Dilithium accelerator.
- Mao 2023: configurable HW/SW Dilithium co-design.
- Wang/TCHES 2024: Kyber/Dilithium RISC-V SoC co-design.
- ML-DSA-OSH 2025: open-source ML-DSA hardware reference.
- EMINEM 2025: efficient mixed-radix NTT benchmark.
- Conflict-Free NTT 2026: alternative NTT memory banking using PTM code.
- ParaPM 2026 and LightHD 2026: recent full-accelerator comparisons.
- PALS 2026: most relevant next-stage paper for sampler-to-NTT reordering.

## Useful But Secondary

- PQShield 2024: high-performance NTT for ML-KEM/ML-DSA.
- KiD 2023: unified Kyber/Dilithium NTT direction.
- Area-Time Efficient 2025: comparison point for NTT area/time.
- MDC-NTT 2025: streaming/pipelined NTT comparison.
- SHA-3 Artix-7 2026: Keccak hardware background, not Dilithium-specific.
- GPU Dilithium papers: acceleration background, not direct FPGA RTL
  comparison.

## Low-Scope Or Administrative

- Turnitin/similarity PDFs: administrative only.
- Thesis proposal format template: formatting guidance only.
- THED threshold Dilithium: protocol-level threshold signature work, not
  immediate RTL accelerator work.
- MSP430 optimization paper: software/microcontroller reference, not FPGA RTL.
- Some 2019 files appear duplicated by extraction/text content.

## Updated Understanding

Completed:

- Keccak/SHAKE primitive.
- NTT/INTT/PWM primitive.
- UVM methodology and golden-model workflow.
- Initial Cyclone V synthesis and timing-analysis discipline.

Still needed for full ML-DSA:

- Rejection/secret/mask/challenge sampling.
- Polynomial-vector and matrix-vector orchestration.
- Rounding/decomposition/hint logic.
- Packing/unpacking.
- Keygen/sign/verify top-level controller.
- Memory map and dataflow scheduling.
- End-to-end KAT verification.

Best next technical move: sampler branch, then integration.
