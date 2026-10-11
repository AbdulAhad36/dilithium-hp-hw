# Earlier active-folder cleanup archive

The initial cleanup moved older active-folder material here on 2026-10-12.
A subsequent experiment cleanup removed redundant generated builds and trials.
See [the retained evidence index](../../README.md) for the current inventory.

- `legacy/` retains the original four-bank RTL, UVM bench and root launchers.
- `evidence/` retains NTT reports/logs extracted from the former `generated/`
  tree; original relative paths are preserved below `evidence/`.
- `manifest.json` records the initial 649-item relocation. It is a historical
  record, not an assertion that every generated item still exists.
- `preserved_active_hashes.json` records 43 active design/project file hashes.
- `../../cleanup_manifest.json` records subsequent removals and retained hashes.

The former `generated/` cache has been removed. Old wave files, simulator
libraries and Quartus databases are not backups retained by this archive.
Archived launchers may require their original relative directory structure.
The finalized implementation remains in the active src/tb_uvm/sim/quartus
folders. Stage 6 integration remains pending. Nothing was committed.
