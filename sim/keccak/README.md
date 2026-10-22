# Standalone Keccak simulation on the integration branch

Imported from `keccak_v2` at `fe54a782e3df9ed684dc960b0067b39ce323289d`.
RTL now lives in `src/keccak/`; the existing UVM remains in
`tb_uvm/tb_uvm_keccak_v2/`. Launcher paths were adapted; RTL/UVM logic was not.

From `sim/` in the Questa GUI Transcript:

```tcl
do keccak/run.do
```

This runs the full standalone Keccak regression, sets up waves in GUI mode,
prints coverage and saves `sim/keccak/keccak_dual_coverage.ucdb`.
The launcher changes the working directory to `sim/keccak/` so relative vector
paths resolve. Subsequent `do run.do` / `do run_nist.do` commands work there.

For the separate published NIST-vector flow:

```powershell
# Repository-root terminal, before simulation:
python sim/keccak/nist_shake.py prepare
```

```tcl
# Fresh Questa session with working directory sim/:
do keccak/run_nist.do
```

```powershell
# Repository-root terminal, after capture:
python sim/keccak/nist_shake.py compare
```

Capture completion is not the NIST comparison verdict. Require the Python
`NIST COMPARE PASS` marker. The published-vector capture exercises both
standalone cores; wrapper routing/arbitration is checked by the full regression.

`run_post_synthesis.do` and `run_post_fit.do` retain standalone vendor-netlist
flows. Generate fresh netlists for `quartus/keccak/` before using them; old
generated netlists were not imported. `setup_cyclonev_libs.do` is their helper;
`run_netlist_reference.do` is the focused source-reference suite. No new
post-netlist verification is claimed merely by importing these scripts.

Current relocation results and the integration milestones belong in the shared
`docs/dilithium_docs/` specification and roadmap. Imported module documents under
`docs/keccak_docs/` retain historical paths/results from their source branch.
