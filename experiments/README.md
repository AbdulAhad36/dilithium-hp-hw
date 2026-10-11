# Retained NTT experiment evidence

Cleaned on 2026-10-12. This directory is a historical evidence archive;
active simulation and synthesis do not depend on it.

## Kept

- `ntt_stage3/`: original banked baseline and initial LightHD reconstruction,
  including source and comparison evidence.
- `ntt_stage4/`: optimization measurements and verification logs. Full source
  is retained for the selected write-control/prefetch design, 148 MHz operating
  checkpoint, expanded coverage checkpoint and interaction coverage checkpoint.
  Other folders retain reports and logs; rejected trial RTL has been removed.
- `ntt_stage5/`: functional post-synthesis/post-fit verification checkpoint.
- `ntt_cleanup_archive/2026-10-12/legacy/`: original four-bank RTL, testbench and
  launchers, retained as a small source backup.
- `ntt_cleanup_archive/2026-10-12/evidence/`: NTT reports and logs extracted from
  the old generated-artifact archive, preserving their original subpaths.

## Removed

Old simulator libraries, temporary wave histories, Quartus databases, duplicate
netlists/bitstreams, unrelated old generated output and rejected trial RTL.
2,598 files totaling **33.48 GiB** were removed. Retained evidence/source files
occupied approximately **171 MiB** before adding this index and the manifest.
The finalized RTL, benches, simulation launchers and Quartus project were
unchanged, verified against their 43 saved hashes.

`cleanup_manifest.json` records removed paths/sizes, retained hashes and moved
evidence paths. The older cleanup archive's manifest describes the earlier
active-folder relocation; this newer manifest records the subsequent pruning.
Historical documents may refer to removed trial source or original generated
locations. Use the remaining reports and this manifest to locate evidence.
Archived scripts are historical and may require their original layout to run.
No synthesis or simulation was rerun for this evidence-only cleanup. No commit
was made. Stage 6 sampler/integration remains pending.
