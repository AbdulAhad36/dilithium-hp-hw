# AGENTS.md - AI Agent Onboarding

## Repository and active implementation

M.Engg IC Design thesis: SystemVerilog ML-DSA / CRYSTALS-Dilithium on
Cyclone V. Current branch: `ntt_v2`. Read
`docs/ntt_docs/post_midyear/POST_MIDYEAR_VERIFICATION_PLAN.md`,
`SPECIFICATION.md`, `COVERAGE.md` and `NTT_VERIFICATION_TESTPLAN.md` in that
same directory before changing the active NTT.

- RTL: `src/ntt_LightHD/` only. Four butterflies and three FIFO stores;
  NTT, INTT, PWM and restricted small-coefficient Pre-NTT.
- Verification: `tb_uvm/tb_uvm_ntt_LightHD/`; reusable components in
  `tb_uvm/tb_uvm_reusable/`. Main UVM owns coverage. Standalone vector capture
  exists only for the independent Python comparison.
- Simulation: `sim/ntt_LightHD/`, with exactly three `.do` entry points.
- Quartus: `quartus/ntt_LightHD/ntt.qpf`, revision `ntt`.
- Python: `FIPS204_NTT/ntt_vectors.py` with `prepare` and `compare`.
- Older four-bank design and root-level launchers are archived at
  `experiments/ntt_cleanup_archive/2026-10-12/legacy/`; retained reports/logs
  are under its `evidence/` tree. Redundant generated caches and rejected trial
  RTL were removed; see `experiments/README.md` and `cleanup_manifest.json`.
  `docs/ntt_docs/ntt-design-and-verification.md` describes the historical design.

## Accepted checkpoints

Ring: n=256, q=8380417. Core cycles NTT/INTT/PWM/Pre = 267/267/75/236.
Selected fit: 2475 ALMs, 5 DSP, 20 M10K; worst Fmax 150.49 MHz.
Approved operating constraint: 148 MHz, worst setup/hold +0.111/+0.152 ns.
The 200 MHz benchmark is unmet. Source regression: 748 checked UVM jobs,
32 functional types, 90.47% type average. Raw bin aggregation is a different
metric; use COVERAGE.md for definitions and genuine misses.
Distinct functional post-synthesis and post-fit netlists each passed 117 jobs.
Cyclone V netlist simulation is functional only, without SDF.
Stage 6 sampler/integration and FPGA/UART validation remain pending.
Revalidate generated evidence before claiming new results.

## Running

From `sim/` in Questa Transcript:

```tcl
do ntt_LightHD/run_uvm.do
do ntt_LightHD/run_post_synthesis.do
do ntt_LightHD/run_post_fit.do
```

Run sequentially: the scripts share `sim/modelsim.ini`. GUI runs retain waves,
coverage and design; batch callers may append `quit -f`. For standalone capture
in a fresh session: `set NTT_MODE vectors; do ntt_LightHD/run_uvm.do`.
Then run `py -3 FIPS204_NTT/ntt_vectors.py compare` from the repo root.
Open the Quartus QPF above in GUI and use Start Compilation; no manual SDC edit.

## Invariants

1. Do not commit without an explicit user request.
2. Preserve the SV golden model; verify outputs before crediting coverage.
3. Rerun relevant UVM checks after RTL changes. Rerun synthesis, multicorner
   timing and `report_paths.tcl` before claiming timing/area improvements.
4. Report clock constraints separately from Fmax and use the worst corner.
5. Keep Keccak RTL on its own branch; sampler/integration is a separate stage.
6. Keep testbench SV under `tb_uvm/`, RTL under `src/`, simulation launchers under
   `sim/`, and synthesis projects under `quartus/`.
7. Preserve historical checkpoints. Do not fabricate coverage or cap actual hits.
