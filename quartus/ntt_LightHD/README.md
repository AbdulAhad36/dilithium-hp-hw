# LightHD NTT Quartus project

This project fits `src/ntt_LightHD/ntt_engine.sv` on Cyclone V
`5CGXFC7C7F23C8`. The approved operating clock is nominal **148 MHz**.

## Run from the Quartus GUI

1. Select **File > Open Project** and open
   `D:\GitHub\dilithium-hp-hw\quartus\ntt_LightHD\ntt.qpf`.
2. Select revision **ntt**; the top entity is **ntt_engine**.
3. Click **Processing > Start Compilation**. No SDC edits or revision switching.
4. After compilation, inspect **Compilation Report > Fitter > Fitter Summary**
   for resources, and **Timing Analyzer > Multicorner Timing Analysis Summary**
   for all-corner setup/hold/recovery/removal/pulse slack and TNS.
5. Inspect both slow85C and slow0C **Fmax Summary** panels; report the worse one.

`ntt.sdc` permanently selects the constraint by compiler stage:

| Stage | Constraint | Purpose |
|---|---|---|
| Analysis/synthesis and fitter | 5.000 ns / 200 MHz | Aggressive optimization target |
| Final Timing Analyzer | 6.756757 ns / nominal 148 MHz | Approved operating timing check |

TimeQuest represents the operating period as 6.756 ns (148.02 MHz). The SDC branch labels are `NTT_CONSTRAINT_MODE=FIT_TARGET` or `OPERATING` in the source and direct STA output. Timing reports inside the fitter may still fail at its aggressive
200MHz target; judge operating closure from the final Timing Analyzer reports.
The separate `ntt_benchmark_200mhz.sdc` remains an explicit 200 MHz comparison.
This is Intel's documented stage-specific overconstraint mechanism:
[Standard Edition Timing Analyzer guide, section 2.4.3](https://www.intel.com/programmable/technical-pdfs/683068.pdf).

### Optional command-line build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_operating.ps1
```

The script uses the same permanent SDC and never changes its contents. It runs
map/fit/STA, detailed paths and the separate 200 MHz comparison, then requires all
20 final timing-check slacks positive and all TNS zero before printing
`OPERATING_TIMING_PASS`. The GUI's full compilation also runs its normal
assembler stages; examine final reports rather than relying only on compilation
success. Fresh reports are in `output_files/`; `results/` contains archived
review copies and is not automatically refreshed by your GUI compilation.

To reanalyse the existing route only, use **Processing > Start > Start Timing
Analysis**. For detailed path reporting from this directory:

```powershell
$Q = 'F:\altera\quartus\bin64'
& "$Q\quartus_sta.exe" -t report_paths.tcl
```

## Fresh permanent-constraint build (2026-10-11)

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

## Verified operating checkpoint (2026-10-10)

Fresh `build_operating.ps1` completes **OPERATING_TIMING_PASS**, all 20 checks
positive, zero TNS. Nominal 148 MHz (tool 6.756 ns/148.02 MHz); worst Fmax 150.49 MHz.
**2,475 ALMs, 2,414 registers, 5 DSPs, 20 M10Ks**, 37,325 RAM bits. Worst setup/hold/pulse
**+0.111/+0.152/+1.201 ns**; recovery/removal **+4.090/+0.391 ns**.
Fit timestamp 2026-10-10 19:06:08. Current results/ and database are from this
build; exact evidence is in experiments/ntt_stage4/lighthd_148mhz_operating_checkpoint.
The relaxed-only fit failed and is retained there as rejected evidence.

The same route at 200 MHz still fails setup (-1.645 ns worst) and pulse (-0.555 ns).
Rerun that comparison without changing the operating SDC:

```powershell
$Q = 'F:\altera\quartus\bin64'
& "$Q\quartus_sta.exe" -t report_clock_check.tcl ntt_benchmark_200mhz.sdc
```

Closure covers standalone internal timing. I/O is false-pathed; 59 physical pins
are autoassigned, zero virtual pins. Stage 4 awaits acceptance; netlist/board/
integration remain separate. Nothing committed. Sections below are historical
checkpoints, superseded for current operating timing.

## Historical 200 MHz-target Stage 4 checkpoint (2026-10-10)

Selected source combines early FIFO A/B write-control decoding with unconditional
next-address preparation during E_TX_VALID. Ready/not-last still gates the read
enable. No additional operation clock; multiplier/BF/return remains 5/7/10.
Golden arithmetic, TB models, FIFO capacity and external interface are unchanged.

Fresh results/: **2,475 ALMs, 2,414 registers, 5 DSPs, 20 M10Ks**,37,325 RAM bits.
**150.49 MHz worst Fmax** (slow0); slow85 **151.79 MHz**. At unchanged 5 ns,
worst setup/hold/pulse is **-1.645/+0.152/-0.555 ns**. Against the prior
148.46 MHz checkpoint: Fmax +1.37%, setup +0.091 ns, ALMs-15, registers+18, M10K-1.
This changes mapping, not coefficient storage capacity. The 200 MHz target
remains unmet; no clock relaxation.

Logs:write_select_prefetch_{map,fit,sta,paths}.log. Exact six RTL files,
source hashes and full source/negative/Python/fit evidence:
experiments/ntt_stage4/lighthd_write_select_prefetch_checkpoint.
At that checkpoint, review copies and the active database matched this source.
The 148.46 MHz checkpoint and every prior trial remain saved. The control-only
trial (144.72 MHz) is saved but not selected. Slow0 now limits at packed BF
kept-operand delay RAM -> final BF result; slow85 at tick -> tag shift-memory
input. Mapped shared-memory instance names do not change logical lane routing.

Main UVM 118/118, zero errors/fatals, fourteen checked groups 100%; Python 18/18,
4608/4608 coefficients. Fresh five-fault coverage gate and observed writeback-fault
test reject without new credit; failed UCDBs stay separate. Other unchanged
negative tests remain saved, not freshly rerun. Raw counts are in COVERAGE.md.
Core NTT/INTT/PWM/Pre 267/267/75/236; wrapper 781/781/845/750 unchanged.
Modeled NTT wrapper/core latency 5.19/1.77 us and latency-based rate 192,689 poly/s
exclude gaps/stalls/SHAKE/sampler. No sustained system/netlist/FPGA claim.
Stage 4open; nothing staged or committed.

## Earlier decoder/reducer trials and restoration (2026-10-09)

Narrow Pre decoder: 2,392 ALMs, 129.70 MHz worst Fmax. Collapsed stage-3
reduction: 2,671 ALMs, 123.38 MHz. Both passed source correctness but regressed
worst-corner timing and are saved, not selected. Their exact RTL and reports are
in `lighthd_pre_decode_trial/` and `lighthd_collapsed_reduce_trial/` under
`experiments/ntt_stage4/`. At that point RTL was restored byte-for-byte from the faster
`lighthd_write_mux_checkpoint` (131.22 MHz, 2,428 ALMs).

That project/database was rebuilt using logs `selected_restore_map.log`,
`selected_restore_fit.log`, `selected_restore_sta.log` and
`selected_restore_paths.log`. Latest selected reports now come from the early-write/prefetch result above.
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

## Rejected return-word retiming trials and fresh restoration (2026-10-10)

Registering each FIFO's compute word in the result stage passes UVM/Python but
falls to 141.80 MHz, 2630 ALMs, setup -2.052 ns. Also preselecting FIFO1's
Pre word in its existing arithmetic stage passes verification but falls to
139.33 MHz, 2681 ALMs, setup -2.177 ns. Both use 5 DSPs / 20 M10Ks and preserve
all operation cycles and FIFO capacities; neither is selected.

Exact six-file sources and complete simulation/fit evidence remain under
experiments/ntt_stage4/lighthd_return_words_trial and
lighthd_return_pre_words_trial. The selected pipeline source was restored
byte-for-byte and freshly rebuilt: 148.46 MHz, 2490 ALMs, 2396 registers,
5 DSPs / 21 M10Ks, worst setup/hold/pulse -1.736 / +0.133 / -0.555 ns.
Fresh restored main UVM passes 118/118 and all fourteen checked groups100%;
Python passes 18/18 cases, 4608/4608 coefficients. Evidence and source hashes
are in experiments/ntt_stage4/lighthd_return_trials_restore.
No 200 MHz closure, current netlist/FPGA claim, new commit or Stage 5 start.

## Latest restoration after setup-focused BF delay trials (2026-10-10)

All-register BF delays: worst setup -2.311 ns, worst Fmax 136.78 MHz,
2,418 ALMs / 2,929 registers / 5 DSPs / 17 M10Ks. Final-stage-only register:
worst setup -1.959 ns, worst Fmax 143.70 MHz, 2,468 ALMs / 2,549 registers /
5 DSPs / 20 M10Ks. Both improve setup TNS but worsen worst setup at unchanged
5 ns; both are rejected despite passing main UVM and Python. Exact RTL and
complete evidence are preserved under `experiments/ntt_stage4/`.

All six active RTL files are restored byte-for-byte from the selected
`lighthd_write_select_prefetch_checkpoint`. Fresh
`bf_delay_restore_{map,fit,sta,paths}.log` reproduces **150.49 MHz worst Fmax**,
2,475 ALMs, 2,414 registers, 5 DSPs / 20 M10Ks, 37,325 RAM bits. Slow85/slow0
setup -1.588/-1.645 ns, TNS -919.242/-1002.192 ns; worst hold +0.152 ns,
pulse -0.555 ns. Fit completed 2026-10-10 05:29:37. Current review copies in
`results/` and active implementation database match this restored source.
Source hashes and complete restoration evidence:
`experiments/ntt_stage4/lighthd_bf_delay_trials_restore/`.

Fresh main UVM 118/118, zero errors/fatals, fourteen checked groups 100%; Python
18/18 cases, 4,608/4,608 coefficients. Cycles unchanged. Earlier negative-checker
evidence is retained, not newly rerun. No timing improvement from these trials,
200 MHz closure, Stage 5, staging or commit.

## Latest restore after candidate/tag/write-mask trials (2026-10-10)

All three trials pass main UVM/Python but regress worst setup: BF candidates
-2.622 ns (131.20 MHz, 2,525 ALMs), tag FFs only -1.806 ns (146.93 MHz,
2,458 ALMs), tag FFs with write masks -1.967 ns (143.53 MHz, 2,541 ALMs).
All retain the 5 ns constraint and operation cycle counts; none is selected.
Their full source/hashes and reports remain in separate experiment folders.

All six active RTL files are restored byte-for-byte. Current database and
review copies derive from `candidate_tag_restore_{map,fit,sta,paths}.log`.
Fit timestamp 2026-10-10 18:42:48: 2,475 ALMs, 2,414 registers, 5 DSPs /
20 M10Ks, 37,325 RAM bits. Slow85/slow0 Fmax 151.79/150.49 MHz; setup
-1.588/-1.645 ns and TNS -919.242/-1002.192 ns. Worst hold +0.152 ns,
pulse -0.555 ns. This exactly reproduces the selected result; no new timing win.
Fresh main UVM 118/118, fourteen checked groups 100%, zero errors/fatals;
Python 18/18 cases / 4,608 coefficients. No TB/golden changes, new negative
checker reruns, 200 MHz closure, Stage 5 or commit. Exact restoration source
and complete evidence: `experiments/ntt_stage4/lighthd_candidate_tag_trials_restore/`.

## Stage 5 netlist export

After a successful full build, run `generate_netlists.ps1` from this directory
(or `powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_netlists.ps1`).
It exports post-fit from the main database and creates a synthesis-only helper
under ignored `postsynth_build/` to export a distinct post-synthesis model.
Only Analysis & Synthesis runs in that helper; the main fitted route is preserved.
Generated models: `simulation_postsynth/ntt.vo`, `simulation_postfit/ntt.vo`.
A `--snapshot=synthesized` request against the main fitted Standard Edition
project produced the fitted model too, so that initial export was rejected.
Do not treat two copies of the same fitted graph as separate stage verification.
The final fitted export requests the normal post-fit flow; Cyclone V warning
10905 confirms functional-only output. Use the main UVM launchers documented
in `sim/ntt_LightHD/README.md`. No SDF/timing simulation is claimed.
