# Selected pipeline restored after return-word trials - 2026-10-10

Both return-word experiments pass source verification but regress fitted
worst-corner timing. Active RTL in rtl/ matches all six files in
lighthd_fold_pipeline_checkpoint byte-for-byte; see rtl.sha256. No TB or
reference change. The selected source remains the committed c2cccd2 design.
This trial/restoration work is uncommitted.

## Fresh source verification

Main uvm_return_trials_restore.log: 118/118 passing, zero UVM errors/fatals,
all fourteen checked functional covergroup types at 100%. Main UCDB/report
are in results/. Core raw counts: 295/307 statements, 232/245 branches,
53/84 conditions, 51/52 expressions, 5/5 states, 9/9 transitions,
3405/3683 toggles. No exclusions; same 278 constant toggle misses.
Separate vector/compare logs: 18/18 cases, 4608/4608 coefficients.
Core NTT/INTT/PWM/Pre cycles: 267/267/75/236; no-stall wrapper: 781/781/845/750.
Unchanged negative-test evidence remains saved; not newly rerun here.

## Fresh fitted restoration

return_trials_restore_{map,fit,sta,paths}.log: map/fit/STA/path report all
successful. Same Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std Lite, standard fit
and unchanged 5 ns constraint. Fit completed 2026-10-10 04:10:56.

- Fmax: slow85 148.46 MHz, slow0 150.20 MHz; worst 148.46 MHz.
- Resources: 2490 ALMs, 2396 registers, 5 DSP, 21 M10K, 37348 RAM bits.
- Worst multicorner setup/hold/pulse: -1.736 / +0.133 / -0.555 ns.
- Both slow corners' worst path: tag[9].pwm -> FIFO2 RAM write data.
- 59 physical autoassigned pins, zero virtual pins; IO is false-pathed.

Exact same source, resources and timing as the selected checkpoint are
reproduced. Complete generated reports/logs are in results/. Active database
and quartus/ntt_LightHD/results review copies match this restoration.
Rejected trials remain in their separate folders. Setup/pulse at 200 MHz
remains open; no Stage 5, netlist, board or integrated-throughput claim.
