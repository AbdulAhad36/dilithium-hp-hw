# Standalone Keccak Quartus project

Open `keccak_dual_interleaved.qpf` in Quartus GUI and select
**Processing > Start Compilation**. No manual SDC changes are needed.

This is the accepted `keccak_v2` project relocated from `quartus/dual_interleaved/`.
Only the RTL paths changed to `../../src/keccak/`. The declared clock remains
6.757 ns, with virtual data pins and the original standalone I/O exceptions.
It does not establish an integrated Dilithium operating clock or board timing.

Read actual placed ALMs from **[A] ALMs used in final placement** in the Fitter
report, and worst-corner Fmax/setup/hold/TNS in TimeQuest. Fresh relocation
results are recorded in `docs/dilithium_docs/SPECIFICATION.md`.

The simulation project is `sim/keccak/`; current generated netlists must be
exported to `simulation_postsynth/` and `simulation_postfit/` before its netlist
launchers run. Cyclone V supports functional post-fit simulation; TimeQuest
provides timing evidence. Historical generated databases were not imported.
