# NTT coverage status — FIFO candidate

**Scope:** source simulation of `src/ntt_LightHD/`. Stage 4 coverage expansion is in progress. The relocated checked-coverage run is `sim/ntt_LightHD/uvm.log` (66 passed, zero failed, zero UVM errors/fatals). The ordinary four-bank build passes 53/53 in `experiments/ntt_stage3/banked_baseline/sim/uvm_stage4_pre_compat.log`.

## What the reported 100% means

| Model in `tb_uvm/tb_uvm_ntt/ntt_coverage.sv` | Exact legal bins | Hit / total | How a hit is justified |
|---|---|---:|---|
| Standard `cg_ntt` | `NTT`, `INTT`, `PWM` crossed with `zero`, `max`, `delta`, `random` | 12/12 | `ntt_cov_seq` drives each combination; the output monitor collects accepted beats; the scoreboard checks all 256 coefficients and final-beat `m_tlast`, then calls `checked_ap.write` on pass. |
| Candidate Pre `cg_pre` | bounded uniform/boundary values, mixed eta-2, mixed eta-4 | 3/3 | Candidate-only `ntt_pre_seq` sends 13 jobs; all 13 match the SV golden NTT and pass output framing before sampling. |

Coverage wiring is `ntt_driver.drv_ap` → scoreboard expected FIFO, `ntt_monitor.mon_ap` → scoreboard observed FIFO, and scoreboard `checked_ap` → coverage subscriber. The logic is in `ntt_env.sv`, `ntt_scoreboard.sv`, and `ntt_coverage.sv`. A failed or incomplete transaction does not publish on `checked_ap`. The monitor records `observed_count` and `output_framing_ok`; the scoreboard requires 256 accepted beats and `m_tlast` on only the final accepted beat in addition to coefficient-by-coefficient equality.

The separate file comparison in `sim/ntt_LightHD/compare.log` passes 18/18 cases and 4,608/4,608 coefficients against the independent Python FIPS 204 NTT reference. `sim/ntt_LightHD/run_vectors.do` generates the DUT output file; `FIPS204_NTT/ntt_vectors.py compare --observed ...` performs the comparison. These are not NIST-published NTT vectors.

## Limits and next coverage work

The 12/12 and 3/3 percentages are small transaction-class models. They do not show that all stages, lanes, twiddle addresses, FIFO routes/occupancies, inverse scaling corner cases, resets, no-reset repeated jobs, or backpressure combinations were exercised. The candidate `sim/ntt_LightHD/uvm.log` has Pre-NTT without input gaps/output stalls; those cases pass in the separate directed `sim/ntt_LightHD/engine.log` but are not yet included in checked UVM coverage. DUT-only statement, branch, condition/expression, FSM, and toggle coverage have not been measured for this candidate. No post-synthesis, post-fit, or FPGA coverage is claimed.

`NTT_VERIFICATION_TESTPLAN.md` defines the planned bins, checkers, assertions, code coverage review, and closure gate. The next implementation step is to collect stage/lane/twiddle/FIFO events per transaction and commit those bins only after the transaction passes. Any impossible bin will need a specific reachability explanation; a high aggregate percentage alone is insufficient.
