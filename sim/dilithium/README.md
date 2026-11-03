# Dilithium simulation

The retained design uses the sources in `quartus/dilithium/dilithium_full.qsf`.
The old service/handle controllers and Stage2-5 simulation paths are retired.
Standalone Keccak, NTT and sampler verification packages remain reusable.

## Main UVM

From the repository root, prepare fixtures after source changes:

```powershell
python sim/dilithium/dilithium_vectors.py uvm_prepare
```

In the Questa Transcript:

```tcl
do sim/dilithium/run_uvm.do
```

The launcher opens GUI waves and functional/code coverage and prints the
coverage summaries in the Transcript. Batch mode is also supported.

## Independent output capture and comparison

In the Questa Transcript, from the repository root:

```tcl
set DILITHIUM_TEST main_diagnostic
do sim/dilithium/run.do
```

Then separately compare the captured bytes:

```powershell
python sim/dilithium/dilithium_vectors.py lighthd_main_diagnostic_compare
```

For all 210 official commands, select `main` and use `lighthd_main_compare`.
For protocol checks, select `main_protocol` and use `lighthd_main_protocol_compare`.
Other selectors are `keygen`, `keygen_protocol`, `sign`, `sign_diagnostic`,
and `sign_protocol`. The launcher prints the matching comparison command.
Python command names retain their existing spelling for compatibility;
current RTL/test filenames and module names have no `lighthd_` prefix.

NIST data and independent reference models are retained. Frozen historical
captures/archives retain their original names and source fingerprints; they
are not fresh qualification of the renamed source tree.
