# LightHD NTT Quartus project

This project fits `src/ntt_LightHD/ntt_engine.sv` and all its local RTL
dependencies on Cyclone V `5CGXFC7C7F23C8`. It uses the same 5 ns clock
constraint as the saved four-bank comparison. Run from this directory:

```powershell
$Q = 'F:\altera\quartus\bin64'
& "$Q\quartus_map.exe" ntt -c ntt
& "$Q\quartus_fit.exe" ntt -c ntt
& "$Q\quartus_sta.exe" ntt -c ntt
& "$Q\quartus_sta.exe" -t report_paths.tcl
```

Reports appear in `output_files/`. Read the worst multicorner Fmax and
setup/hold slack from `ntt.sta.rpt`, not the 200 MHz clock constraint.
`report_paths.tcl` reports detailed critical paths. Historical fitted
evidence remains in `experiments/ntt_stage3/lighthd_fifo/evidence/`.

The relocated source/project was rebuilt with Quartus Prime Lite 25.1std.
Selected reports are preserved in `results/`: 3,003 ALMs, 1,973 registers,
6 DSP blocks, 20 RAM blocks, and 96.56 MHz worst-corner Fmax. Worst setup
slack remains -5.356 ns at the 5 ns constraint; worst hold slack is +0.087 ns.
These reproduce the Stage 3 fit and do not constitute 200 MHz timing closure.
