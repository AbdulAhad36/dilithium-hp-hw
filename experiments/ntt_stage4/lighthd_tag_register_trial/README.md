# Control-tag delay registers ? 2026-10-10

Start from the selected 150.49 MHz / 2,475 ALM / -1.645 ns checkpoint.
Only `ntt_core.sv` changes: disable automatic shift-register recognition on
the short tag pipeline so its delay stays in flip-flops. The selected slow85
critical path is tick -> packed tag shift RAM input. No polynomial FIFO,
PWM B storage, BF/multiplier arithmetic, pipeline length, external interface,
clock constraint, testbench or golden-model change. Total BF/return remains
7/10 clocks. Exact six-file RTL and SHA256 hashes are retained here.

Fresh UVM passes 118/118 jobs, zero errors/fatals, fourteen implemented checked
functional covergroup types 100%. Separate Python passes 18/18 cases and
4,608/4,608 coefficients. Core cycles 267/267/75/236 and no-stall wrapper
cycles 781/781/845/750 are unchanged. Raw code-coverage counts are unchanged
because the synthesis directive adds no executable SV behavior. No exclusions.
Existing negative-checker evidence is retained; it has not been newly rerun.

## Fitted result: not selected on its own

Full fit completed 2026-10-10 18:22:58. Tag shift RAM is absent. Resources:
2,458 ALMs, 2,471 registers, 5 DSPs, 19 M10Ks, 37,280 RAM bits.
Slow85/slow0 Fmax 146.93/149.52 MHz; setup -1.806/-1.688 ns at unchanged 5 ns.
Setup TNS -799.111/-925.742 ns. Worst all-corner hold +0.165 ns, pulse -0.555 ns.
The old tag RAM path is removed, but slow85 now limits at Pre valid -> FIFO1
write data, with Pre upper selection the next path. Slow0 limits at tick[6] ->
FIFO2 head pointer. Worst setup is 0.161 ns worse than selected baseline despite
lower TNS, 17 fewer ALMs and one fewer M10K. Keep as an experiment, not the
selected source. A separate follow-up targets the measured Pre/write-data mux.
