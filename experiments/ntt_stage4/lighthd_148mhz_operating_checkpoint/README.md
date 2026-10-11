# 148 MHz operating-clock checkpoint

## Stage 4 — Approved 148 MHz operating closure (2026-10-10)

The user approved closing timing near current Fmax. Nominal operation is
**148 MHz**, requested period6.756757 ns; TimeQuest uses **6.756 ns / 148.02 MHz**.
This is an approved operating-frequency choice, not an RTL speed improvement.
The 5 ns/200 MHz benchmark remains separate and unmet.

### Method and repeatable command

A fresh relaxed-only148 MHz fit failed: 2480 ALMs, 2418 registers, 5 DSP/20 M10K;
slow 85/slow 0 Fmax143.10/144.45 MHz, setup-0.232/-0.167 ns. It is rejected and
archived in the checkpoint's `relaxed_fit_trial/`, not called closed.

The selected flow fits at the tighter **5 ns optimization target**, restores the
approved operating SDC, then runs full multicorner STA, paths and a separate
explicit 200 MHz benchmark. A fresh full rebuild passed; fit summary timestamp
**2026-10-10 19:06:08**. Run from `quartus/ntt_LightHD/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_operating.ps1
```

The script restores `ntt.sdc` even on failure and prints `OPERATING_TIMING_PASS`
only after all 20 timing-check slacks are positive and all TNS values zero.
Use this flow instead of fitting only at the relaxed operating constraint.
Do not run another Quartus job in this project during its temporary fit SDC change.

### Fresh selected measurements

**2,475 ALMs, 2,414 registers, 5 DSPs, 20 M10Ks, 37,325 RAM bits**.
Fmax slow 85/slow 0 **151.79/150.49 MHz**; worst **150.49 MHz**.
All four 1100mV corners pass (slacks below in ns; every TNS is0.000 ns):

| Corner | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|
| Slow 85C | +0.168 | +0.429 | +4.090 | +1.206 | +1.201 |
| Slow 0C | +0.111 | +0.273 | +4.200 | +1.025 | +1.201 |
| Fast 85C | +3.504 | +0.180 | +5.500 | +0.474 | +2.168 |
| Fast 0C | +3.888 | +0.152 | +5.646 | +0.391 | +2.160 |

Worst setup/hold/pulse **+0.111/+0.152/+1.201 ns**; recovery/removal
**+4.090/+0.391 ns**. The explicit 200 MHz analysis of this same route still fails:
slow 85/slow 0 setup **-1.588/-1.645 ns**, minimum pulse width **-0.555 ns**.
Worst slow 0 setup remains BF operand-delay RAM to final BF result; slow 85 is
tick to tag shift-memory input.

### Verification and evidence

All six active RTL files are byte-identical to the saved write-selection/prefetch
checkpoint. No golden model, TB source, interface or cycle changes. Retained,
not newly rerun: `uvm_candidate_tag_restore.log` **118/118**, zero errors/fatals,
fourteen checked groups 100%; Python `compare_candidate_tag_restore.log`
**18/18 cases, 4608/4608 coefficients**. Raw-code holes remain as documented in
COVERAGE.md. Core NTT/INTT/PWM/Pre **267/267/75/236** clocks; wrapper
**781/781/845/750**. At nominal 148 MHz NTT wrapper/core latency is
781/148=**5.277 us**, 267/148=**1.804 us**; latency-based wrapper rate
148e6/781=**189,501 polynomials/s**, excluding gaps/stalls/SHAKE/sampler.

Current review copies: `quartus/ntt_LightHD/results/`. Fresh logs:
`operating148_aggressive_{map, fit, sta, paths, benchmark200}.log`.
Exact RTL/hashes, constraints/scripts, fresh reports, parsed20-check gate,
retained source verification and rejected relaxed fit:
`experiments/ntt_stage4/lighthd_148mhz_operating_checkpoint/`.
Original physical database is local recovery evidence under ignored
`implementation_snapshot/`. Previous trials and four-bank RTL remain preserved.

The operating timing gate is closed within this standalone internal constraint
model. External I/O remains false-pathed; 59 physical pins are autoassigned,
zero are virtual. Board/sampler timing is not signed off. Overall Stage 4 awaits
user review/acceptance of coverage and implementation tradeoffs. No Stage 5
netlist work, Stage 6 integration or new commit.

