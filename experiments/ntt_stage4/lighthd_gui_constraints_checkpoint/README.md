# Permanent GUI constraint checkpoint - 2026-10-11

Use project `quartus/ntt_LightHD/ntt.qpf`, revision `ntt`, and GUI
**Processing > Start Compilation**. No manual SDC changes or revision switch.
Intel documents this stage-specific constraint mechanism in section2.4.3:
https://www.intel.com/programmable/technical-pdfs/683068.pdf

`ntt.sdc` selects5ns in `quartus_map`/`quartus_fit`, and6.756757ns in
final timing analysis. Standalone200MHz benchmark remains separate.
All six RTL files are unchanged from the saved operating checkpoint.

Validation completed: fresh full `quartus_sh --flow compile ntt -c ntt`
(the same compiler flow as GUI Start Compilation) passed synthesis, fitter,
assembler and final timing analysis with zero errors. Fit summary timestamp
**2026-10-11 01:29:08**. Permanent SDC contents/hash were unchanged by the build.
All 20 final timing checks have positive slack and zero TNS:
worst setup/hold/pulse **+0.111/+0.152/+1.201 ns**, recovery/removal
**+4.090/+0.391 ns**. Fmax slow85/slow0 **151.79/150.49 MHz**; resources
**2,475 ALMs,2,414 registers,5 DSPs,20 M10Ks**,37,325 RAM bits. These reproduce the
accepted physical result. The separate 200 MHz check still has worst setup
**-1.645 ns** and pulse **-0.555 ns**. No 200 MHz operating closure is claimed.

Fresh logs: `gui_compile.log`, `gui_constraints_paths.log`,
`gui_constraints_benchmark200.log`. Current review copies are refreshed in
`quartus/ntt_LightHD/results/`; future GUI builds update `output_files/` only.
The exact project/RTL/hashes and fresh reports plus a 20-check parsed timing
gate are saved under `experiments/ntt_stage4/lighthd_gui_constraints_checkpoint/`.
Identical RTL retains the earlier UVM 118/118 and Python 4608/4608 evidence;
no source simulation rerun is claimed for this SDC-only change.

`project_before/` preserves the prior manual-switch SDC/launcher; `project/`
contains the new permanent constraints and scripts. Neither project snapshot
is a standalone checkout: RTL paths assume the original project directory.
`rtl/` and `rtl.sha256` preserve exact accepted source. Source UVM evidence
remains in the preceding operating checkpoint; no new coverage result added.
Internal-only constraints still false-path external I/O. Board/netlist/sampler
integration and Stage4 acceptance remain separate. Nothing committed.
