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

## Current Stage 4 fit (2026-10-10)

The selected source adds a first-fold carry-save register stage to the saved
smaller route/Pre-key variant. Multiplier/BF/return latency is **5/7/10**.
The independent main UVM models require ten-clock return alignment; golden
arithmetic, FIFO capacities and the external interface are unchanged.

Fresh `results/`: **2,490 ALMs, 2,396 registers, 5 DSPs, 21 M10Ks,
148.46 MHz worst Fmax** (slow85); slow0 **150.20 MHz**. RAM bits:37,348.
Worst setup **-1.736 ns**, hold **+0.133 ns**, pulse **-0.555 ns** at 5 ns.
Against the prior selected145.73MHz checkpoint: setup improves0.126ns,
worst Fmax improves1.87%, ALMs fall78, registers increase279. RAM bits
increase96; coefficient FIFO capacity and M10K block count stay unchanged.
The 200MHz target is still unmet. No constraint relaxation.

Logs: `fold_pipeline_map.log`, `fold_pipeline_fit.log`,
`fold_pipeline_sta.log`, `fold_pipeline_paths.log`. Exact source and evidence:
`experiments/ntt_stage4/lighthd_fold_pipeline_checkpoint/`.
The prior selected145.73MHz checkpoint and smaller/rejected alternatives
remain saved. Both slow-corner worst paths now run tag[9].pwm -> FIFO2
write-data selection. The first fold is no longer a reported top-three path.

Main UVM **118/118**, zero errors/fatals, fourteen checked groups100%; Python
**18/18 cases,4608/4608coefficients**. Fresh separate coverage-credit,
operand/writeback corruption and missing-GS-witness tests reject without new
coverage credit. Failed UCDBs remain separate. Raw code counts and bounds
are documented in COVERAGE.md; no exclusions.

Measured core NTT/INTT/PWM/Pre cycles **267/267/75/236**; no-stall wrapper
**781/781/845/750**. The extra stage costs one clock per operation. Modeled
NTT wrapper rate improves1.74% after that cost. No sustained system rate,
netlist or FPGA claim. Stage4open; nothing staged or committed.

## Earlier decoder/reducer trials and restoration (2026-10-09)

Narrow Pre decoder: 2,392 ALMs, 129.70 MHz worst Fmax. Collapsed stage-3
reduction: 2,671 ALMs, 123.38 MHz. Both passed source correctness but regressed
worst-corner timing and are saved, not selected. Their exact RTL and reports are
in `lighthd_pre_decode_trial/` and `lighthd_collapsed_reduce_trial/` under
`experiments/ntt_stage4/`. At that point RTL was restored byte-for-byte from the faster
`lighthd_write_mux_checkpoint` (131.22 MHz, 2,428 ALMs).

That project/database was rebuilt using logs `selected_restore_map.log`,
`selected_restore_fit.log`, `selected_restore_sta.log` and
`selected_restore_paths.log`. Latest selected reports now come from the first-fold pipeline result above.
Main source UVM now passes 117/117 with a useful all-lane PWM boundary increment;
fourteen checked covergroup types remain 100%. Separate Python still matches
18/18 cases and 4,608 coefficients. Raw code and 200 MHz timing closure remain
open; source correctness does not constitute netlist or board validation.

## Rejected first-fold trials (2026-10-10)

Carry-select split: 121.30 MHz worst, 2397 ALMs, 5 DSPs / 20 M10Ks,
setup -3.244 ns, hold +0.131 ns. Rewritten carry candidate: 120.11 MHz worst,
2466 ALMs, 5 DSPs / 20 M10Ks, setup -3.326 ns, hold +0.075 ns. Both pass source
UVM/Python but regress timing; exact source and evidence remain archived under
experiments/ntt_stage4. At that earlier checkpoint RTL/results/database were restored to the
145.73 MHz source. The newer selected pipeline is described above.
No clock/constraint relaxation. Stage 4 remains open; nothing committed.
