# Restored selected source after BF delay timing trials ? 2026-10-10

Both BF delay mapping trials are rejected because worst setup regresses at the
unchanged 5 ns constraint. The trials and complete evidence remain saved.
All six active RTL files are restored byte-for-byte from
`lighthd_write_select_prefetch_checkpoint/rtl/`; SHA256 hashes are identical.
No testbench, golden model, interface, FIFO capacity or operation cycle changes.

## Fresh source verification

`uvm_bf_delay_restore.log`: 118/118 jobs, zero UVM errors/fatals, all fourteen
implemented checked functional covergroup types 100%. This run produces the
current main UCDB and raw coverage report; rejected-trial UCDBs are separate.
`vector_bf_delay_restore.log` / `compare_bf_delay_restore.log`: 18/18 cases,
4,608/4,608 coefficients. Core NTT/INTT/PWM/Pre cycles 267/267/75/236;
no-stall wrapper cycles 781/781/845/750. Raw selected code-coverage counts are
unchanged. Existing negative-checker evidence is retained, not newly rerun.

## Fresh implementation rebuild

Full map/fit/STA and `report_paths.tcl` completed successfully. Fit timestamp
2026-10-10 05:29:37; timing/path reports completed at 05:29:53.
Resources exactly reproduce the selected checkpoint: 2,475 ALMs, 2,414 registers,
5 DSPs, 20 M10Ks, 37,325 RAM bits, 59 physical / 0 virtual pins.
Slow85/slow0 Fmax 151.79/150.49 MHz; setup -1.588/-1.645 ns at unchanged 5 ns.
Setup TNS -919.242/-1002.192 ns. Worst all-corner hold +0.152 ns;
worst pulse width -0.555 ns. No timing improvement is claimed from the trials.

Slow85 again limits at tick -> packed tag shift-memory input. Slow0 again
limits at the packed BF kept-operand delay RAM -> final BF result. Shared mapped
RAM instance labels do not imply a change in logical butterfly lane routing.
The active Quartus database and current review copies in `quartus/ntt_LightHD/results/`
now match the restored selected source. Previous checkpoints and both rejected
trials remain saved. Stage 4 remains open; no 200 MHz closure, Stage 5 or commit.
