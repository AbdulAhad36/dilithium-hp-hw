# Stage 3: LightHD architecture reconstruction

**Historical checkpoint:** The ongoing design now lives in
`src/ntt_LightHD/`, with its runnable tests in `sim/ntt_LightHD/` and Quartus
project in `quartus/ntt_LightHD/`. This experiment directory preserves the
Stage 3 source snapshots, logs, and fit evidence. Use the new locations for
future changes and runs; the commands below describe how this checkpoint was
originally measured.

This is a separate NTT candidate. The active `src/ntt_engine/` design and the
measured four-bank snapshot in `../banked_baseline/` are preserved. No source
code from the LightHD authors was available, so the controller and FIFO
decoders here are reconstructed from the published structure and its cited
three-FIFO predecessor. This is **not a claim of RTL identity**.

## Hardware and operation contract

- Four pipelined butterfly units process four coefficient pairs each cycle.
- Three 92-bit FIFO stores have 32, 32, and 16 word capacity. The index-only
  schedule proof is in `../lighthd_fifo_schedule.py`.
- The signal generator drives the FIFO, butterfly, and twiddle decoders for
  eight forward/inverse stages. Inverse scaling is folded into the stages.
- `OP_PWM` reuses the butterfly multipliers and has a separate second-operand
  word store so the existing 23-bit stream wrapper can still be used.
- `OP_PRE_NTT` is the forward NTT for sampled small secrets only. Every input
  coefficient must be the canonical residue of an integer in `[-4,4]`.
  A nine-entry lookup performs the first-stage multiplication during input
  loading; the resulting words are regrouped into the three FIFOs. The core
  then runs stages 1 through 7. This mode has no automatic fallback for an
  out-of-range coefficient; simulation raises an error for such input.
- The experimental NTT still uses our q-specific four-cycle modular
  multiplier, its butterfly RTL, and four twiddle ROM read ports. These are
  implementation differences from LightHD's published reducer/IP strategy.

## Run the checks

From `sim/` in PowerShell, run one command for each test:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -do 'do ../experiments/ntt_stage3/lighthd_fifo/run_vectors.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -do 'do ../experiments/ntt_stage3/lighthd_fifo/run_core_check.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -do 'do ../experiments/ntt_stage3/lighthd_fifo/run_engine_check.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -do 'do ../experiments/ntt_stage3/lighthd_fifo/run_uvm.do; quit -f'
```

From the repository root, compare the separately captured DUT results with
the existing independent FIPS 204 NTT reference file and check FIFO indices:

```powershell
py -3 FIPS204_NTT/ntt_vectors.py compare --observed experiments/ntt_stage3/lighthd_fifo/ntt_dut_outputs.txt
py -3 experiments/ntt_stage3/lighthd_fifo_schedule.py
```

The bounded NTT vector runs through `OP_PRE_NTT`; the other 17 cases use the
normal modes. The core directed test additionally covers eta-4 secrets. The
engine directed test covers Pre-NTT with input gaps and output stalls. The
candidate UVM script compiles with `NTT_FIFO` and adds 13 Pre-NTT transactions.
The ordinary `sim/ntt_run.do` remains compatible with the four-bank design.

The independent Quartus project in `quartus/` targets Cyclone V
`5CGXFC7C7F23C8` and uses the same 5 ns constraint as the saved baseline.
Run `quartus_map`, `quartus_fit`, `quartus_sta`, and `report_paths.tcl` there
before using any area or Fmax figure for a changed RTL revision.

The current simulation results are: independent output file comparison
18/18 cases and 4,608/4,608 coefficients; core directed 39/39; engine
directed 34/34 (including Pre-NTT input gaps and output stalls); and candidate
UVM 66/66 (53 standard plus 13 Pre-NTT). The existing standard-mode
operation/input-kind model and the new Pre case-class model each report 100%,
sampling only transactions that passed all output and framing checks. These
small models do not cover every internal FIFO/twiddle/state behavior. Core start-to-done
latencies are 266 NTT, 266 INTT, 74 PWM, and 235 Pre-NTT cycles. Complete
no-stall launch-to-last-output latencies are 780, 780, 844, and 749 cycles,
respectively. The wrapper spends 256 input beats on a one-operand operation;
its transfer time must not be confused with the compute-only number.

## Fitted same-device comparison

Both projects target Cyclone V `5CGXFC7C7F23C8` with the same 5 ns clock
constraint and the same serial `ntt_engine` wrapper. Fmax is the lowest
multicorner TimeQuest result (Slow 0 C for both), not the 200 MHz constraint.

| Metric | Saved four-bank baseline | This FIFO candidate |
|---|---:|---:|
| ALMs | 2,873 | 3,003 |
| Registers | 1,718 | 1,973 |
| DSP blocks | 8 | 6 |
| RAM blocks | 19 | 20 |
| Worst-corner Fmax | 92.71 MHz | 96.56 MHz |
| Worst setup slack at 5 ns | -5.786 ns | -5.356 ns |
| Worst hold slack | +0.150 ns | +0.087 ns |
| NTT core cycles | 284 | 266 |
| NTT launch-to-last-output cycles | 798 | 780 |
| NTT launch-to-last-output time | 8.6075 us | 8.0779 us |
| Complete NTT operations/second, no stalls | 116,178 | 123,795 |

The candidate is 6.15% faster for this complete NTT transaction and uses
130 more ALMs, two fewer DSP blocks, and one more RAM block. `OP_PRE_NTT`
completes in 749 cycles / 7.7568 us for eligible small secrets. Both fits
violate the 5 ns setup target; these Fmax figures describe the achieved
post-fit frequency, not successful 200 MHz timing closure. The candidate's
worst setup path is between butterfly pipeline/storage nodes, after the
twiddle decoder was simplified. The exact final RTL, tests, fit, and STA
reports are frozen in `evidence/direct_decoder_fit/`.

## Source and measured evidence

The published structure, 264/264/70-cycle standard modes, and small-secret
Pre-NTT idea are from Ni et al., *LightHD*, IEEE Transactions on Computers
(2026), DOI [10.1109/TC.2026.3666457](https://doi.org/10.1109/TC.2026.3666457).
The three-FIFO reorder explanation is from Ni et al., *Towards a Lightweight
CRYSTALS-Kyber in FPGAs: an Ultra-lightweight BRAM-free NTT Core* (ISCAS
2023). The local LightHD PDF is in `docs/refernce-paper-hw/2026/`.

Earlier fitted versions and exact RTL copies are in `evidence/`. The final
Stage 3 fitted checkpoint is `evidence/direct_decoder_fit/`. The current
candidate UVM extension result is `uvm_stage4_pre.log`; the same RTL fit and
timing reports are in `quartus/output_files/` and `critical_paths.log`.
