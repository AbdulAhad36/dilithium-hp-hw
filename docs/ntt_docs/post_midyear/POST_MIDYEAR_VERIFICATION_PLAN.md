# NTT v2 Post-Midyear Plan

**Status:** Stages 1 and 2 are complete as measured source/implementation work. Stage 3 has a verified, fitted four-butterfly, three-FIFO LightHD reconstruction with a bounded-secret Pre-NTT path. Its working RTL is in `src/ntt_LightHD/`, all candidate testbench `.sv` files are in `tb_uvm/tb_uvm_ntt_LightHD/`, simulation scripts and generated outputs are in `sim/ntt_LightHD/`, and the independent Quartus project is in `quartus/ntt_LightHD/`; Stage 3 experiment files remain historical evidence. It is selected for Stage 4 detailed verification and timing work; the four-bank RTL remains saved as a comparison baseline. The 5 ns setup target, Keccak/sampler integration, netlist verification, and FPGA validation remain open.

**Latest selected Stage 4 checkpoint:** 148.46 MHz worst-corner Fmax, 2,490
ALMs, 5 DSPs, 21 M10Ks; main UVM 118/118 and separate Python 4,608/4,608.
Core NTT/INTT/PWM/Pre cycles are 267/267/75/236. Setup at 5 ns improves to
-1.736 ns but remains negative. See the latest first-fold pipeline section
below for measured timing, area and latency tradeoffs.

This is the staged plan for the `ntt_v2` development branch. The starting RTL is the historical `2_ntt` branch. Its recorded checks and Quartus results are a baseline to rerun, not evidence for future modified RTL. The active Keccak counterpart is `keccak_v2`; its dual-core SHAKE design has one shared 64-bit input, one tagged 128-bit output, and a minimum 26-cycle offset between job launches. Keccak FPGA/UART validation and the rejection sampler remain pending.

## Recorded starting point and measurement rules

The `2_ntt` report records 208/208 reference self-checks, 33/33 core checks, 23/23 engine checks, and 53/53 UVM transactions. Its 100% functional-coverage number means that 19 existing covergroup bins were hit; RTL code/FSM/toggle coverage and a requirements-based coverage model were not established. The last recorded Cyclone V fit is 75.44 MHz, 2,313 ALMs, 6 DSPs, and 18 M10Ks. The recorded compute-only latencies are approximately 299 forward-NTT cycles, 372 inverse-NTT cycles, and 74 pointwise-multiply cycles. The old plan estimates about 1,067 no-stall cycles for one complete top-level forward-NTT transaction, including its one-coefficient-per-beat input and two-cycle-per-coefficient output interface. Rerun and label all of these measurements before using them as a new baseline.

For every comparison, state the DUT revision, FPGA/device, operation, input/output inclusion, clock frequency, constraints, and evidence path. A source test pass does not prove post-synthesis, post-fit, timing, or FPGA behavior. ALMs are not interchangeable with Xilinx LUTs, and Cyclone V NTT-only Fmax is not directly comparable to LightHD's Artix-7 full-accelerator 212.8 MHz. Report ALMs, registers, DSPs, M10Ks, setup slack, hold slack, Fmax, and operation throughput separately; use a documented conversion only if an equivalent-area estimate is needed.

## Stage 1 — Establish NTT functionality and an independent vector flow

1. Rerun the existing reference, core, engine, and UVM checks on unmodified `ntt_v2`. Export the actual pass counts, failures, current 19-bin coverage result, and operation latencies. Do not treat a simulator exit code or a coverage percentage alone as proof of correct outputs.
2. Check NIST's FIPS 204 and ACVP sources for public **standalone NTT/INTT/pointwise-multiply** vectors. The currently located public ML-DSA ACVP sets cover key generation, signature generation, and signature verification; no SHAKE-style standalone NTT `.rsp` set has been identified. Record the source and version of any official component vectors found. If none exist, generate NTT vectors from FIPS 204 conventions and an independently checked C/software reference, and label them **FIPS-derived reference vectors**, not “NIST NTT vectors.” Preserve source material and provenance under `FIPS204_NTT/` on `ntt_v2`. The repository's existing C reference and pure-SV model can be cross-checks, but neither should silently validate itself.
3. Mirror the simple Keccak file flow with **one Python script**, planned as `FIPS204_NTT/ntt_vectors.py` with `prepare` and `compare` commands. `prepare` makes a single case input file and a separate expected-output file. A dedicated, fast `sim/run_ntt_vectors.do` runs only the NTT vector capture test and writes observed DUT outputs to a third file; it must not launch the full regression. `compare` matches case ID, operation, all 256 coefficients, and order, then prints exact mismatch locations and a clear PASS/FAIL total. Keep the existing SV golden model and its checks.
4. Include forward NTT, inverse NTT, pointwise multiplication, round trip, and two-input polynomial multiplication checked against schoolbook multiplication. Cover zero, one, `q-1`, sparse, boundary-position, and random polynomials. Resolve FIPS/reference choices for twiddle ordering, coefficient normalization, and inverse scaling before declaring a mismatch to be an RTL defect.
5. Create `docs/ntt_docs/post_midyear/FIPS204_NTT.md` **when the flow exists**. Explain the actual source of every vector, generated files, commands, comparison logic, case counts, and observed results. Add end-to-end official ML-DSA vectors later when the whole signer/verifier exists.

**Gate:** Every retained independent case matches exactly; the existing regression and existing coverage model are reported with observed numbers and known limitations. Fix functionality failures before optimizing performance.

**Stage 1 evidence:** The fresh baseline passed 208/208 reference, 33/33 core, 23/23 engine, and 53/53 UVM checks. The existing 19-bin input-sampled covergroup reported 100%; RTL code coverage was not compiled. The separate capture/compare flow passed 18/18 cases and 4,608/4,608 exact coefficients. Measured core start-to-done counts are 302 NTT, 377 INTT, and 77 PWM; complete no-stall external transactions are 1,071, 1,146, and 1,102 cycles, respectively. See [FIPS204_NTT.md](FIPS204_NTT.md) for files, commands, provenance, and limits. These results apply only to this source RTL.

## Stage 2 — Measure and improve the current architecture

**Fresh starting fit (2026-10-05, source revision `6d86fa8`):** Quartus Prime Lite 25.1std.0, `ntt_engine`, Cyclone V `5CGXFC7C7F23C8`, 5.000 ns clock constraint with input/output paths excluded. Analysis/synthesis, fitter, and TimeQuest all completed. Fitted resources: 2,313 ALMs, 951 registers, 6 DSPs, 18 M10Ks. TimeQuest reports 75.44 MHz at slow 85°C and **74.38 MHz at slow 0°C**; the worst setup slack across the listed corners is **−8.444 ns** at slow 0°C, while worst hold slack is **+0.100 ns** at fast 0°C. Thus the 200 MHz constraint is not met. The slow 85°C worst setup path runs from `u_core|m_r1_r` through `u_bf0` modular subtraction and the `u_mul` DSP input to `prod_s1`; `report_paths.tcl` reports −8.256 ns for that path. The fitter also reports 59 unassigned physical pins, so this is an internal timing/area baseline rather than board pin closure. The original Quartus summary files were overwritten by later experimental fits; the baseline path report remains in `quartus/output_files/ntt_stage2_paths.log`, and the baseline resource/timing values were transcribed from the completed fit and TimeQuest runs. Refit and remeasure after any RTL change.

**First retained change (2026-10-05):** Replaced power-of-two address multiplications and nonoverlapping address additions with shifts and bit placement in `ntt_core.sv`. The baseline and new fit used the same project, device, 5 ns constraint, and Quartus version. The four original reference/core/engine/UVM checks passed (208/208, 33/33, 23/23, 53/53), as did the separate FIPS-derived output comparison (18/18 cases, 4,608/4,608 coefficients). Core and complete external transaction cycles stayed at 302/1,071 NTT, 377/1,146 INTT, and 77/1,102 PWM. Fitted resources changed from **2,313 to 2,294 ALMs**, **951 to 953 registers**, **6 to 4 DSPs**, and **18 to 18 M10Ks**. Slow 85°C Fmax changed from 75.44 to 76.52 MHz; the worse slow 0°C Fmax changed from **74.38 to 75.37 MHz**. Worst setup slack at the 5 ns target changed from −8.444 to **−8.267 ns**; worst hold slack changed from +0.100 to **+0.158 ns**. The resulting no-stall forward-NTT external rate is 75.37 million / 1,071 = approximately **70,373 polynomials/s** at the estimated Fmax, versus 69,449/s at baseline; this is an NTT-only model, not integrated Dilithium throughput. Current evidence: `quartus/output_files/ntt_stage2_addr_fit.summary`, `ntt_stage2_addr_sta.rpt`, `ntt_stage2_addr_paths.log`, and the `sim/ntt_stage2_addr_*.log` runs (generated locally, ignored by Git). The current slow 85°C worst path is `u_core|pw_s2` through `u_bf3|u_mul` to `prod_s1`, so the multiplier-input path still needs work.

**Rejected pipeline experiment:** Registering `mod_mul` inputs passed the same functional checks but increased core cycles to 310 NTT, 387 INTT, and 79 PWM and ALMs to 2,334. Its worst-corner Fmax was only 74.98 MHz. This change was reverted before the retained address optimization.

**Second retained change (2026-10-05):** `ntt_engine.sv` now prefetches the next synchronous-memory read when an output beat is accepted. The output remains stable during backpressure; a new directed stall case checks that behavior and final `m_tlast`. The 208/208 reference, 33/33 core, 24/24 engine, and 53/53 UVM checks passed, as did the separate 18/18 FIPS-derived cases and 4,608/4,608 output coefficients. Core cycles remained 302 NTT, 377 INTT, and 77 PWM. Complete no-stall transactions changed from **1,071 to 816 NTT**, **1,146 to 891 INTT**, and **1,102 to 847 PWM** cycles. The fit changed from the address-only checkpoint's 2,294 ALMs, 953 registers, 4 DSPs, 18 M10Ks to **2,313 ALMs, 967 registers, 4 DSPs, 18 M10Ks**. Slow 0°C Fmax decreased from 75.37 to **70.97 MHz** and worst setup slack at 5 ns from −8.267 to **−9.090 ns**; worst hold slack is **+0.126 ns**. At each fit's estimated Fmax, no-stall forward output rate increased from 75.37 million / 1,071 = 70,373 to 70.97 million / 816 = **86,973 polynomials/s** (+23.6%). This is an NTT-only estimate, not integrated Dilithium throughput. Evidence: `quartus/output_files/ntt_stage2_stream_fit.summary`, `ntt_stage2_stream_sta.rpt`, `ntt_stage2_stream_paths.log`, and `sim/ntt_stage2_stream_*.log` (generated locally, ignored by Git). The 5 ns constraint still fails; the next slow 85°C critical path goes from a core shift-register RAM through `u_bf3|u_mul` to `prod_s1`.

**Third retained change (2026-10-05, uncommitted):** `ntt_core.sv` uses four drain clocks **between passes** while retaining enough final drain clocks to complete all memory writebacks before `done_o`. The dedicated capture test now reports FSM phase counts and fails if `done_o` rises with a pending writeback or RUN and SCALE/PWM attempt simultaneous writeback. A uniform four-clock drain gave correct sequentially read vector outputs but asserted `done_o` before the final writeback, so it was rejected. Three inter-pass clocks failed 7/18 output cases. Final drains one clock shorter than the retained values also failed the pending-writeback check. The retained split passed 208/208 reference, 33/33 core, 24/24 engine, 53/53 UVM, and 18/18 FIPS-derived cases with 4,608/4,608 coefficients. Core cycles are now **280 NTT, 344 INTT, 72 PWM**; no-stall external transactions are **794, 858, 842** cycles. The fit on the same Cyclone V and 5 ns constraint reports **2,325 ALMs, 992 registers, 4 DSPs, 18 M10Ks**, worst-corner slow 0°C Fmax **72.63 MHz**, worst setup slack **−8.768 ns**, and worst hold slack **+0.127 ns**. Compared with the previous stream fit, the estimated forward external rate is 72.63 million / 794 = **91,474 polynomials/s** versus 86,973/s, a **5.2%** gain; ALMs rose by 12 and registers by 25. The 5 ns setup target remains unmet. The slow 85°C critical path runs from `u_core|sc_s2` through `u_bf3|u_mul` to `prod_s1`. Evidence: `sim/ntt_stage2_splitdrain_final_*.log`, `quartus/output_files/ntt_stage2_splitdrain_fit.summary`, `ntt_stage2_splitdrain_sta.rpt`, and `ntt_stage2_splitdrain_paths.log` (local generated files, ignored by Git).

**Fourth retained change (2026-10-05, uncommitted):** Four extra modular-multiply lanes scale the four coefficients of each **final inverse-pass tile** as its butterfly results emerge. Their delayed address tags write normalized values back to the four banks, eliminating the separate 64-cycle memory reread/SCALE issue pass. The final inverse drain is long enough to clear those new writebacks before `done_o`; the capture test checks that condition and conflicting writebacks. Exact outputs passed 18/18 cases and 4,608/4,608 coefficients; directed core/engine and UVM passed 33/33, 24/24, and 53/53. The independent reference self-check remains 208/208. Core cycles are now **280 NTT, 283 INTT, 72 PWM** and no-stall external transactions **794, 797, 842** cycles. The same-device fit reports **2,860 ALMs, 1,173 registers, 8 DSPs, 19 M10Ks**, worst-corner slow 0°C Fmax **75.06 MHz**, worst setup slack **−8.322 ns**, and worst hold slack **+0.103 ns** at 5 ns. Compared with the third change, this costs **535 ALMs, 181 registers, 4 DSPs, and 1 M10K**. Estimated inverse external rate rises from 72.63 million / 858 = **84,650** to 75.06 million / 797 = **94,178 polynomials/s** (+11.3%); forward rate is 75.06 million / 794 = **94,534 polynomials/s**. These are NTT-only no-stall estimates. The new slow 85°C worst path is inside `u_bf0|u_mul`, from `t2_q` to `r_o` through the final modular-reduction folds. The 5 ns setup target still fails. Evidence: `sim/ntt_stage2_fusedscale_*.log`, `quartus/output_files/ntt_stage2_fusedscale_fit.summary`, `ntt_stage2_fusedscale_sta.rpt`, and `ntt_stage2_fusedscale_paths.log` (local generated files, ignored by Git).

**Rejected reduction-pipeline experiment (2026-10-05):** Splitting the modular multiplier's final reduction into two registered stages passed the source regression and 18/18 exact-output cases, but added 2/3/1 core cycles to NTT/INTT/PWM. An initial fit appeared to reach 80.21 MHz; review found that the 16-clock final inverse drain had been truncated into a four-bit constant and worked only through wraparound. After widening the counter and constants, the same checked outputs and cycle counts held, but the corrected fit was **74.29 MHz worst-corner Fmax**, **2,839 ALMs, 1,356 registers, 8 DSPs, 19 M10Ks**, worst setup slack **−8.461 ns**, and worst hold slack **+0.149 ns** at 5 ns. Its estimated forward and inverse external rates (74.29 million / 796 = **93,329/s**, 74.29 million / 800 = **92,863/s**) are lower than the fourth retained change's 94,534/s and 94,178/s. The extra pipeline and width change were reverted. The pre-fix 80.21 MHz fit is **not** a valid performance result for the corrected trial. Evidence: `sim/ntt_stage2_reduction4_widthfix_*.log`, `quartus/output_files/ntt_stage2_widthfix_fit.summary`, `ntt_stage2_widthfix_sta.rpt`, and `ntt_stage2_widthfix_paths.log` (local generated files, ignored by Git).

**Fifth retained change (2026-10-06, uncommitted):** A registered butterfly input now isolates its CT/GS operand selection from the DSP input, while the final modular reduction is split across two registered stages. Butterfly latency rises from four to six clocks, and the final inverse-scale tag follows the four-clock multiplier. The drain counter and constants are explicitly five bits so the 18-clock final inverse drain cannot truncate. The standalone capture passed 18/18 FIPS-derived cases and 4,608/4,608 coefficients, including the pending-writeback and conflict checks. Reference, core, engine, and UVM checks passed 208/208, 33/33, 24/24, and 53/53; the existing narrow UVM covergroup reported 100%. Measured core counts are **284 NTT, 288 INTT, 74 PWM**; complete no-stall external transactions are **798, 802, 844** clocks. The same Cyclone V fit reports **2,925 ALMs, 1,322 registers, 8 DSPs, 19 M10Ks**. TimeQuest reports 87.34 MHz at slow 85°C and 89.70 MHz at slow 0°C, so **87.34 MHz** is the worse slow-corner Fmax. Worst setup slack at the 5 ns constraint is **−6.449 ns** (slow 85°C); worst hold slack is **+0.086 ns** (fast 0°C). Compared with the fourth change, this costs 65 ALMs and 149 registers while keeping DSP/M10K counts unchanged. Estimated no-stall external rates rise from 94,534 to **109,449 NTT polynomials/s** (87.34 million / 798), from 94,178 to **108,903 INTT polynomials/s** (87.34 million / 802), and from 89,145 to **103,483 PWM polynomials/s** (87.34 million / 844). The slow 85°C critical path now starts at `u_core|fwd`, passes through `u_bf0` modular addition/compare, and ends at the inferred shift-register RAM for writeback tags. This is a source-functional and fitted-timing result, not timing closure at 200 MHz or an integrated Dilithium benchmark. Evidence: `sim/ntt_stage2_combined_*.log`, `quartus/output_files/ntt_stage2_combined_fit.summary`, `ntt_stage2_combined_sta.rpt`, and `ntt_stage2_combined_paths.log` (local generated files, ignored by Git).

**Sixth retained change (2026-10-06, uncommitted):** In `butterfly_unit.sv`, raw operands for the CT/GS kept result are registered before the GS modular addition. This splits the prior `fwd`-to-writeback critical path without changing the six-clock butterfly pipeline or any operation cycle count. Exact vectors passed 18/18 and 4,608/4,608 coefficients; core, engine, reference, and UVM passed 33/33, 24/24, 208/208, and 53/53. The fit is **2,834 ALMs, 1,509 registers, 8 DSPs, 19 M10Ks**. Slow-corner Fmax is **89.88 MHz** (85°C; 90.46 MHz at 0°C); worst setup/hold slack is **−6.126/+0.128 ns** at 5 ns. Relative to the fifth change, this gains 2.54 MHz and saves 91 ALMs at a cost of 187 registers. The new worst path ends at the butterfly multiplier input register. Evidence: `sim/ntt_stage2_keepstage_*.log` and `quartus/output_files/ntt_stage2_keepstage_{fit.summary,sta.rpt,paths.log}` (local generated files, ignored by Git).

**Seventh retained change (2026-10-06, uncommitted):** The butterfly now registers the CT multiplier operand and the GS modular difference separately, then selects between those registered candidates before multiplication. Combined with the sixth change, this separates mode selection from GS subtraction and moves the fitted critical path to the coefficient-memory writeback crossbar. Exact output comparison passed **18/18 cases and 4,608/4,608 coefficients**; reference/core/engine/UVM checks passed **208/208, 33/33, 24/24, 53/53**, with zero UVM failures. Core cycles remain **284/288/74** and no-stall external cycles **798/802/844** for NTT/INTT/PWM. The Cyclone V fit uses **2,845 ALMs, 1,690 registers, 8 DSPs, 19 M10Ks**. TimeQuest reports 90.81 MHz at slow 85°C and **90.33 MHz at slow 0°C**, the worse slow-corner Fmax. Worst setup slack is **−6.071 ns** (slow 0°C) at the 5 ns constraint; worst hold slack is **+0.137 ns** (fast 0°C). Versus the sixth change, Fmax gains 0.45 MHz for 11 ALMs and 181 registers. Estimated complete no-stall rates are **113,195 NTT/s** (90.33 million / 798), **112,631 INTT/s** (90.33 million / 802), and **107,026 PWM/s** (90.33 million / 844). The rate gain over the fifth change is about 3.4% with unchanged cycles; this is NTT-only, not integrated Dilithium throughput. The 5 ns constraint still fails. Evidence: `sim/ntt_stage2_mulselect_*.log` and `quartus/output_files/ntt_stage2_mulselect_{fit.summary,sta.rpt,paths.log}` (local generated files, ignored by Git).

**Eighth retained change (2026-10-06, uncommitted):** The writeback tag now carries each lane's two-bit bank ID, computed at issue time, rather than recomputing the four-way address XOR at memory writeback. The existing bank and address tags advance together, so operation cycle counts remain **284/288/74 core** and **798/802/844 complete no-stall external** for NTT/INTT/PWM. The dedicated capture passed **18/18 cases and 4,608/4,608 coefficients**; core/engine/reference/UVM checks passed **33/33, 24/24, 208/208, 53/53**. The same Cyclone V fit reports **2,843 ALMs, 1,704 registers, 8 DSPs, 19 M10Ks**, slow-corner Fmax **93.41 MHz at 85°C** (93.55 MHz at 0°C), worst setup slack **−5.705 ns** at 5 ns, and worst hold slack **+0.095 ns**. Relative to the seventh change, worst-corner Fmax rises **3.08 MHz**, ALMs fall by 2, and registers rise by 14. Estimated complete no-stall rates are **117,055 NTT/s** (93.41 million / 798), **116,471 INTT/s** (93.41 million / 802), and **110,675 PWM/s** (93.41 million / 844). This is NTT-only throughput, with the 5 ns constraint still unmet. The worst setup path still runs from a writeback tag shift-memory output through bank write routing to coefficient memory. Evidence: `sim/ntt_stage2_banktaged_*.log` and `quartus/output_files/ntt_stage2_banktaged_{fit.summary,sta.rpt,paths.log}` (local generated files, ignored by Git).

**Rejected early RUN-selector register (2026-10-06):** Registering RUN bank selectors one clock before data writeback retained exact output matches and passed 33/33 core, 24/24 engine, 208/208 reference, and 53/53 UVM checks. The fit dropped worst-corner Fmax to **93.05 MHz** (slow 0°C), with **2,866 ALMs, 1,737 registers, 8 DSPs, 20 M10Ks**, worst setup slack **−5.747 ns**, and worst hold slack **+0.100 ns** at 5 ns. The new worst path moved inside an inverse-scale multiplier. This is worse than the eighth retained change in worst-corner Fmax, ALMs, registers, M10Ks, and setup slack, so the experiment was reverted. The restored `ntt_core.sv` matched its pre-trial backup byte-for-byte before a comment-only edit. Its `sim/ntt_stage2_runbank_*.log` and `quartus/output_files/ntt_stage2_runbank_{fit.summary,sta.rpt,paths.log}` remain as local ignored evidence. Because this rejected trial was the last Quartus run, the generic `ntt.fit.summary` and `ntt.sta.rpt` currently describe it; use the eighth change's named snapshots for retained-RTL metrics until the next retained-RTL fit.

**Rejected explicit crossbar route (2026-10-06):** Replacing the dynamic indexed write assignments with a 13-source per-bank one-hot/OR route passed 18/18 exact vector cases (4,608/4,608 coefficients), 33/33 core, 24/24 engine, 208/208 reference, and 53/53 UVM checks. The fitted worst-corner Fmax dropped from 93.41 to **92.64 MHz** while ALMs rose from 2,843 to **2,955** and registers from 1,704 to **1,718**; DSP/M10K counts stayed 8/19. Worst setup/hold slack was **−5.795/+0.094 ns** at the 5 ns constraint. The route was reverted byte-for-byte to the eighth checkpoint. Evidence: `sim/ntt_stage2_crossbar_*.log` and `quartus/output_files/ntt_stage2_crossbar_{fit.summary,sta.rpt,paths.log}` (local generated files, ignored by Git).

**Ninth retained change: stable output under backpressure (2026-10-06, uncommitted):** A new directed case with varying inverse coefficients exposed that `m_tdata` changed while `m_tvalid=1` and `m_tready=0`. During output streaming, the core's synchronous RAM read ports kept returning stale tile addresses whenever `rd_en_i=0`. `ntt_core.sv` now holds the most recent external read offset while idle, so the selected RAM output stays stable until the next accepted/prefetched read. The directed monitor now drives ready before the rising edge and checks accepted beats and stall stability at that edge. The enlarged engine suite passes **30/30**, including sparse and random NTT/INTT with input gaps and output stalls. Exact vector comparison remains **18/18 cases and 4,608/4,608 coefficients**; core/reference/UVM pass **33/33, 208/208, 53/53**. Core cycles remain **284/288/74** and no-stall external cycles **798/802/844** for NTT/INTT/PWM. The fresh Cyclone V fit reports **2,873 ALMs, 1,718 registers, 8 DSPs, 19 M10Ks**. Slow-corner Fmax is **92.71 MHz at 0°C** (99.27 MHz at 85°C); worst setup slack is **−5.786 ns** at 5 ns and worst hold slack is **+0.150 ns**. Relative to the eighth checkpoint, the functional repair costs 30 ALMs, 14 registers, and 0.70 MHz worst-corner Fmax. The worst setup path is now inside `u_bf0|u_mul`, from product register to second reduction register. Estimated no-stall external rates at the measured Fmax are **116,178 NTT/s** (92.71 million / 798), **115,599 INTT/s** (92.71 million / 802), and **109,846 PWM/s** (92.71 million / 844). Evidence: `sim/ntt_stage2_stall_fix_*.log`, `sim/ntt_stage2_paced_edgefixed.log` for the pre-fix failure, and `quartus/output_files/ntt_stage2_stallfix_{fit.summary,sta.rpt,paths.log}` (local generated files, ignored by Git). The generic Quartus summary files now correspond to this retained revision.

**Measured producer/backpressure sensitivity (source simulation, no sampler attached):** The 30-check directed engine test drives one idle input clock between successive coefficients as a repeatable slow-producer model, and separately holds `m_tready` low for two of every seven output-loop clocks. The directed golden-model comparison passes for each paced case. These are complete request-to-last-output counts at the same testbench boundary; the no-stall counts agree with the independent vector bench. The one-gap NTT case adds exactly 255 clocks for 255 gaps. The inverse stall pattern adds 102 clocks, and the combined case adds 255 + 102 = 357 clocks. This models handshake sensitivity, not an actual rejection-sampler acceptance rate or Keccak/NTT integrated throughput.

| Directed case | No-stall clocks | Paced clocks | Added clocks |
|---|---:|---:|---:|
| NTT, one input gap between accepted coefficients | 798 | 1,053 | 255 |
| INTT, output-stall pattern only | 802 | 904 | 102 |
| INTT, input gaps plus output stalls | 802 | 1,159 | 357 |

**Dual-core Keccak interface handoff:** The current `keccak_v2:src/keccak_engine/keccak_dual_interleaved.sv` has one shared 64-bit message input and a shared 128-bit SHAKE output with `output_valid_o`, `output_ready_i`, `output_bytes_o`, and `output_core_o`. The `ntt_v2:src/ntt_engine/ntt_engine.sv` sink accepts one 23-bit coefficient per `s_tvalid && s_tready` clock, with a separate operation request and 256-beat polynomial load. A future adapter therefore needs a job descriptor linking each accepted Keccak request/core tag to sampler mode and destination polynomial; byte collection across partial output beats; coefficient validity and indexing; buffering between bursty/variable sampler output and the one-coefficient NTT sink; and ready propagation back to Keccak when that buffer fills. The two SHAKE cores must remain separately tagged until their respective jobs are unpacked and sampled. The present NTT top has no descriptor or multi-coefficient load port, and no sampler is connected, so neither an actual SHAKE-wait count nor an integrated throughput claim exists yet. This is an interface contract for Stage 3 evaluation and Stage 6 integration, not a claim of completed Keccak/NTT compatibility.

**Stage 2 handoff decision:** Source functionality, timing, resources, core phases, full transaction cycles, and a paced producer/consumer case are now measured for the retained four-bank tile. The 284/288/74 core counts still exceed the plan's 264/264/70 compute-cycle comparison by 20/24/4 cycles. The Cyclone V 5 ns setup target remains violated by 5.786 ns; no board pins or integrated sampler have been tested. Wider coefficient loading, load/compute overlap, LightHD-style FIFO scheduling, and small-secret Pre-NTT would alter the interface/schedule enough to require architecture comparison. Stage 3 will evaluate those choices on the same Cyclone V and preserve the current banked implementation as the measured reference. The Stage 2 measurement pass is complete with these explicit misses; the performance challenge is not marked achieved.

**Where the no-stall cycles go now:** The standalone capture's measured external totals decompose as follows. The interface takes one coefficient per input beat and now emits one coefficient per output clock; the residual is the measured difference after subtracting transfer and core cycles, not a separately timed RTL block. SHAKE waiting and sampler acceptance cannot be measured until those blocks are connected.

| Operation | Input beats | Core start-to-done | Output clocks | Residual | External total |
|---|---:|---:|---:|---:|---:|
| NTT | 256 | 284 | 256 | 2 | 798 |
| INTT | 256 | 288 | 256 | 2 | 802 |
| PWM | 512 | 74 | 256 | 2 | 844 |

PWM input transfer now dominates its 74-cycle computation, while NTT/INTT input and output transfers remain comparable to core computation. This makes wider loading and safe load/compute overlap high-priority Stage 2 measurements alongside core cycle reduction and timing repair.

1. Rerun Quartus synthesis, fitting, and TimeQuest on the frozen functional baseline. Record the true worst setup/hold paths and account for each DSP and M10K. Investigate the two DSPs inferred by address-generation multiplication; replace power-of-two multiplies with shifts or small decoded cases if the measured implementation improves.
2. Instrument the complete path: request/input transfer, SHAKE waiting, sampler output rate when a sampler exists, NTT loading, core computation, pipeline drains, result transfer, and backpressure. Until the sampler exists, measure the NTT portions with a representative producer model and label those results as estimates. Measure compute latency and complete transaction latency separately.
3. Improve the measured NTT bottleneck with one change at a time and rerun functional checks and Quartus after each RTL change. Candidates: register the measured modular-multiplier input path; reduce unnecessary inter-pass drains; merge inverse scaling into the final pass if correctness and timing allow; remove the two address DSPs; load several coefficients into the four banks per clock; reduce output-interface cycles; and overlap safe input/storage work with computation. Do not assume any proposed Fmax gain until a new fit proves it.
4. Make the NTT compatible with today's **dual-core** Keccak output, not the older four-lane assumption: a job descriptor must associate each tagged SHAKE byte stream with its sampler mode and destination polynomial; buffers must handle partial bytes, variable rejection acceptance, and backpressure. This is an interface design and measurement task here; actual sampler integration is Stage 6.
5. Study LightHD's four-butterfly FIFO schedule, DSP use, memory scheduling, and small-coefficient Pre-NTT. Add a Pre-NTT path only for eligible bounded secret polynomials, after its first-stage lookup and data-regrouping behavior is independently checked. General inputs must retain a correct full transform. Consider more butterfly/memory parallelism if cycle count is the binding limit and area is available.

**Performance challenge:** Aim for at least comparable **compute-only** cycles to LightHD's reported 264 forward NTT, 264 inverse NTT, and 70 pointwise multiplication, with 235 forward cycles as the relevant small-coefficient Pre-NTT reference. Seek equal or better complete-operation throughput under a documented workload, with positive worst-case setup and hold slack. The user-directed Fmax stretch target is 212.8 MHz, LightHD's reported Artix-7 **full-accelerator** clock; reaching that on our Cyclone V NTT is unproven and is not a valid cross-FPGA win by itself. Document any remaining gap and its cause rather than claiming an ALM/LUT equivalence or performance win from dissimilar measurements.

## Stage 3 — Architecture decision

Implement the user-directed LightHD four-butterfly, three-FIFO architecture from the published description on the **same Cyclone V**, while preserving the measured four-bank tile as the reference. Reconstruct the unpublished control details, prove the FIFO schedule, and compare correctness, forward/inverse/PWM cycles, complete transaction throughput, Fmax, setup/hold slack, ALMs, registers, DSPs, and M10Ks under the same constraints. Include the small-secret Pre-NTT path with an explicit eligibility contract and independent tests. Choose the integration architecture from the measured results and record any remaining gap to the paper; do not imply source-level identity without the authors' RTL.

**Review started (2026-10-05):** The dedicated vector testbench now counts cycles spent in each core FSM phase. Its 18/18 cases still match 4,608/4,608 expected coefficients. The counts below are from `sim/ntt_stage2_stage3_phases.log`; they sum exactly to the measured core start-to-done latency. The 256 NTT issue cycles are four passes of 64 four-butterfly tiles. The 44 drain cycles are 11 after each pass. The inverse has an additional 64-cycle scaling issue phase and 11-cycle drain. The PWM core issues 64 tiles and drains for 11 cycles. The two remaining cycles are control transitions. These are measured implementation costs, not mathematical requirements of the NTT.

| Core operation | Run issue | Run drain | Scale issue | Scale drain | PWM issue | PWM drain | Control | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Forward NTT | 256 | 44 | 0 | 0 | 0 | 0 | 2 | 302 |
| Inverse NTT | 256 | 44 | 64 | 11 | 0 | 0 | 2 | 377 |
| Pointwise multiply | 0 | 0 | 0 | 0 | 64 | 11 | 2 | 77 |

LightHD reports 264 cycles each for standard forward and inverse NTT (256 operation + 8 setup) and 70 for pointwise multiplication. Its small-coefficient Pre-NTT takes 235 cycles only for eligible small secret polynomials. Against those **compute-only** figures, the pre-change core in the table above was 38 cycles slower in forward NTT, 113 in inverse NTT, and 7 in PWM; the inverse gap included its 75-cycle separate scaling phase. The cycle boundaries and memory interfaces may differ, so these gaps guide experiments rather than establish a complete-operation performance ranking. LightHD uses a four-butterfly FIFO schedule; our design uses four banked memories and a 2×2 tile. LightHD's reported Artix-7 full-accelerator clock and area cannot be compared directly with our Cyclone V NTT-only fit. Source: the local LightHD paper in `docs/refernce-paper-hw/2026/`.

After the retained Stage 2 pipeline change, the corresponding compute-cycle gaps are **20 forward, 24 inverse, and 4 PWM**. The 284/288/74 counts include 26 RUN-drain clocks for forward NTT, 30 RUN-drain clocks for inverse NTT (three 4-cycle inter-pass waits and an 18-cycle final scaled-writeback wait), and 8 PWM-drain clocks. There is no separate inverse SCALE issue phase in the active schedule. The 5 ns fitted setup violation remains open. These are updated measurements, while the table above preserves the pre-change review baseline.

**Saved reference:** The verified four-bank 2x2 tile, its RTL, output files, test logs, Quartus reports, and file hashes are preserved in `experiments/ntt_stage3/banked_baseline/`. Its measured core cycles are 284 NTT, 288 INTT, and 74 PWM; complete no-stall transactions are 798, 802, and 844 cycles. The last fit on Cyclone V `5CGXFC7C7F23C8` reports 2,873 ALMs, 8 DSPs, 19 M10Ks, 92.71 MHz worst slow-corner Fmax, and -5.786 ns setup slack at the 5 ns target. The main four-bank RTL remains active while the LightHD candidate is built separately.

**Requested LightHD reconstruction:** Build from scratch around the published architecture: four butterfly units; three 92-bit FIFO stores with depths 32, 32, and 16; a signal generator; BU, twiddle, and FIFO decoders; and the NTT, INTT, and PWM schedules. The first-stage LUT and input regrouping apply only to eligible small secret polynomials; general inputs retain the standard transform. The external `ntt_engine` 23-bit wrapper may be reused to measure the same workload, but its transfer cycles must be reported separately from LightHD's compute cycles. Before synthesis, prove the FIFO coefficient-index schedule across all eight stages and compare outputs against the same independent cases and SystemVerilog reference checks.

The local LightHD paper in `docs/refernce-paper-hw/2026/` reports 264/264/70 compute cycles and a three-cycle modular reducer. Its cited precursor, Ni et al., *Towards a Lightweight CRYSTALS-Kyber in FPGAs: An Ultra-lightweight BRAM-free NTT Core* (ISCAS 2023), explains the three-FIFO reorder pattern. No released LightHD RTL or complete state/decoder truth tables were found with the published paper; the missing control details were derived and checked as a reconstruction. This RTL still uses our butterfly/modular multiplier and a separate PWM operand store, so it is not source-identical or microarchitecturally identical to LightHD. A prior oversized parallel experiment was deleted at the user's direction and is not part of this decision.

**Stage 3 measured gate:** `experiments/ntt_stage3/lighthd_fifo/` contains four butterfly units, three 92-bit FIFOs (32/32/16 words), FIFO/twiddle decoders, a Pre-NTT first-stage lookup/regrouping path for bounded secrets, and an index proof covering all eight stages. The final direct-decoder checkpoint is frozen under `evidence/direct_decoder_fit/`. Python comparison passed 18/18 cases and 4,608/4,608 coefficients, core directed 39/39, engine directed 34/34 including Pre-NTT gaps/stalls, and standard-mode UVM 53/53. The same-device fit succeeded and TimeQuest was run for all corners.

| Measured metric | Saved four-bank tile | LightHD FIFO reconstruction |
|---|---:|---:|
| Core NTT / INTT / PWM cycles | 284 / 288 / 74 | 266 / 266 / 74 |
| Core eligible secret Pre-NTT cycles | unavailable | 235 |
| Complete NTT / INTT / PWM cycles | 798 / 802 / 844 | 780 / 780 / 844 |
| Complete eligible secret Pre-NTT cycles | unavailable | 749 |
| ALMs / registers | 2,873 / 1,718 | 3,003 / 1,973 |
| DSP / RAM blocks | 8 / 19 | 6 / 20 |
| Worst-corner Fmax | 92.71 MHz | 96.56 MHz |
| Worst setup / hold slack at 5 ns | -5.786 / +0.150 ns | -5.356 / +0.087 ns |
| Complete no-stall NTT time | 8.6075 us | 8.0779 us |

The external NTT time is 6.15% lower under the same serial wrapper and FPGA constraints, at a cost of 130 ALMs, 255 registers, and one RAM block, while using two fewer DSP blocks. No-stall complete NTT throughput is 116,178 versus 123,795 operations/s (one complete transaction at a time, reciprocal of the measured time); this is not compute-only or system-level ML-DSA throughput. LightHD's published 264/264/70 compute cycles remain 2/2/4 cycles ahead of this reconstruction, and the 5 ns setup target still fails. Keep the FIFO candidate separate while Stage 4 adds architecture-specific coverage and attacks the measured butterfly/storage path; retain the four-bank implementation as a rollback and comparison reference. The Stage 3 source/fit gate is met, so begin Stage 4 without claiming final timing closure or replacement of the active RTL.

**Stage 4 first increment:** `NTT_VERIFICATION_TESTPLAN.md` now maps requirements to checks and planned FIFO/Pre coverage. The UVM scoreboard now publishes coverage only after exact 256-beat output and `m_tlast` checks pass. Candidate UVM adds 13 bounded-secret Pre-NTT transactions and reports 66/66 passed, 100% of the 12 standard operation/input-kind bins, and 100% of three Pre case-class bins (`uvm_stage4_pre.log`). The unchanged four-bank UVM build also passes 53/53 (`banked_baseline/sim/uvm_stage4_pre_compat.log`). These small functional models are not Stage 4 coverage closure; stage/lane/twiddle/FIFO occupancy, backpressure, reset, and DUT code coverage remain open.

**Initial Stage 3 relocation evidence:** The six LightHD-inspired RTL files were copied into `src/ntt_LightHD/`, the candidate-specific directed/vector testbenches and scripts initially into `sim/ntt_LightHD/`, and the Quartus project into `quartus/ntt_LightHD/`. The latter compiles only `src/ntt_LightHD/` RTL. From those locations, the independent vector compare passed 18/18 cases and 4,608/4,608 coefficients; core 39/39, engine 34/34, and UVM 66/66 passed; the FIFO index proof passed. A new Quartus map/fit/STA/path run reproduced 3,003 ALMs, 6 DSP blocks, 20 RAM blocks, 96.56 MHz worst-corner Fmax, -5.356 ns worst setup slack, and +0.087 ns worst hold slack. Selected new reports are in `quartus/ntt_LightHD/results/`; the Stage 3 experiment directory remains frozen historical evidence. The four-bank `src/ntt_engine/` remains separate and unchanged by this relocation. The testbench `.sv` files have since moved to `tb_uvm/tb_uvm_ntt_LightHD/` while scripts and generated files remain in `sim/ntt_LightHD/`.
## Stage 4 — Detailed test plan, coverage, and iterative synthesis

**Latest coefficient-routing UVM checkpoint (2026-10-09):** The main run
remains **115/115**, zero UVM errors/fatals. `ntt_routing_trace.sv` reconstructs
logical FIFO coefficient IDs and reference values, checks the actual loaded
memory, derives all mathematical pairings and routes, compares registered
BF inputs, nine-clock writeback and physical FIFO writes, then checks output
read addresses and values in order. Per-stage pairs and destinations must
occur exactly once. The scoreboard gates these observations with the final
output comparison; the thirteenth covergroup closes 2,944 pair bins, 5,888
transform-destination bins, 256 PWM IDs and 1,024 mode/output-position bins.
This is simulation evidence, not a formal all-input proof.

Two separate UVM self-tests corrupt one observed operand or writeback bit.
Each detects the routing error and credits zero checked jobs, while the real
DUT output still matches the golden polynomial. Main coverage remains
separate from these deliberately rejected observations. No RTL or Quartus
performance claim changed. Next work is the remaining condition/expression
review, broader protocol combinations and fitted timing/performance tuning.
Stage 4 remains in progress; Stage 5 still requires user result acceptance.

The earlier checkpoints below are historical.


**Latest UVM reset/equivalence checkpoint (2026-10-09):** The main
`run_uvm.do` passes **115/115**, zero UVM errors/fatals. This is 53 standard
+ 13 Pre + four no-reset + four flow + nine reset/recovery + 32 paired
bounded-random general/Pre jobs. All twelve implemented covergroups close.
The monitor observes the actual reset state, input count, cleared controls,
FIFO counts and pending tags; a different fresh job must then pass without
another reset before a reset-point bin credits (9/9). Sixteen eta-2/eta-4
pairs compare actual Pre/general outputs and both golden results (2/2 bins).

The main UVM report now covers core FSM transitions **9/9** and wrapper
**15/15**. All multiplier upper-bit toggle holes have arithmetic-bound
explanations in `COVERAGE.md`; raw code counts remain unexcluded. Five deliberate
scoreboard corruptions, including failed reset checks, credit no bins.
Three separate UVM illegal Pre inputs trigger the exact DUT eligibility
fatal at first/middle/last positions; these are not normal passing jobs.
Unique coefficient destination proof, the hardware eligibility contract,
condition/expression review, broader protocol combinations and timing remain
open. No RTL or fitted performance claim changed. Stage 4 remains in progress.

The checkpoints below are historical; use this checkpoint and `COVERAGE.md`
for current results.


**Current main UVM checkpoint (2026-10-08):** `run_uvm.do` now owns the
candidate's checked architecture-specific functional coverage and DUT code
coverage. All testbench sources remain in `tb_uvm/tb_uvm_ntt_LightHD/`.
The latest run is **74/74**, zero UVM errors/fatals, with 74 named observed
trace witnesses. Its ten implemented covergroups are 100%: 2,944 schedule
positions, 764 mode/twiddle addresses, 11 source and 11 destination routes,
32 occupancy classes, three scaling classes, 27 Pre value/position bins,
64 PWM words, input-gap/output-stall positions and existing case/restart
bins. The scoreboard requires correct outputs, framing and independently
checked internal traces before publishing coverage.

`ntt_lighthd_cov.ucdb` and `ntt_lighthd_coverage.rpt` are generated by this
main UVM run. Current code FSM transitions remain core 6/9 and wrapper 9/15;
directed transition results below are separate supporting evidence.
`run_scoreboard_gate.do` is a separate UVM self-test: four deliberately
corrupted observed items are rejected without crediting bins. Next priorities
are reset cancellation/recovery in UVM, unique coefficient destination proof,
Pre eligibility and code-hole review. No RTL or Quartus performance result
changed. Stage 4 remains open; Stage 5 requires user result acceptance.

The following checkpoints record earlier increments; `COVERAGE.md` and the
current checkpoint above describe the latest UVM evidence.


**Checked-trace/code-coverage checkpoint (2026-10-08):** The relocated
core directed bench now checks every stage/issue/lane twiddle address against
an independent arithmetic index formula, every registered ROM value against
the golden modular-exponentiation function, all issue and return-tag counts, and
FIFO count bounds. It credits stage/twiddle/route bins only after exact output
comparison; 39/39 jobs passed. Checked bins are 255/255 NTT, 255/255 INTT,
and 254/254 Pre-NTT stage/twiddle addresses, with all three source/destination
FIFO routes seen in each mode. An instrumented DUT-only code-coverage UVM run
passed 66/66; the core reached 253/265 statements, 200/212 branches, 5/5
FSM states, and 6/9 FSM transitions. Exact remaining metrics and limitations
are in `COVERAGE.md`. This is a partial Stage 4 result. No RTL or fitted timing
claim changed; the coverage holes, reset/backpressure matrix, and timing gate
remain open.

The LightHD candidate now has its own UVM sources in
`tb_uvm/tb_uvm_ntt_LightHD/`; its scripts compile from that folder. The
four-bank UVM sources remain in `tb_uvm/tb_uvm_ntt/`. After the move, the
candidate core, engine, and UVM checks passed 39/39, 34/34, and 66/66.

**Next Stage 4 increment (2026-10-08):** Checked core jobs now record FIFO
empty/partial/full classes and peak counts. NTT/INTT see FIFO1 and FIFO2
reach 32/32, while FIFO3 peaks at 11/16; Pre-NTT sees FIFO1 at 32/32,
FIFO2 at 31/32, and FIFO3 at 16/16. Missing full classes need a reachability
proof before exclusion. Directed engine tests now abort at idle, input load,
compute, and stalled output, verify no stale output/control, then check a
different 256-coefficient job. The expanded engine suite passes 42/42; its
separate DUT-only code-coverage run also passes. No RTL or Quartus metrics
changed. See `COVERAGE.md` for precise meaning and open work.

**Further Stage 4 increment (2026-10-08):** PWM now passes A/B boundary gaps,
gaps within both operands, and combined output stalls. The directed engine
suite reaches 45/45. Candidate-only UVM also runs NTT, INTT, PWM, and
Pre-NTT consecutively without reset; all four checked jobs pass, raising UVM
to 70/70. An operation × reset covergroup records 8/8 bins after scoreboard
pass. Its code-coverage report and the separate directed engine report are
kept distinct; no RTL or fitted performance claim changed.

**Arithmetic/occupancy/reset review (2026-10-08):** The earlier Pre-NTT
FIFO2 peak of 31 was a monitor sampling gap, not an unreachable full state.
The trace now samples the final settled count at DONE and observes 32/32;
Pre occupancy classes are complete for all three FIFOs. The exhaustive
`PIPE=9` index schedule proves standard NTT/INTT FIFO3 peaks at 11/16, so
their full bins are excluded only for the current legal controller schedule.
The core trace enforces that bound and independently checks registered
inverse words against multiplication by `(q+1)/2 mod q`; zero, even-nonzero,
and odd scaling classes all pass. Core remains 39/39.

The arithmetic bench passes 1,312 multiplier inputs and 1,312 CT/GS pairs,
including boundary pairs, every twiddle in both modes, random cases, and
continuous inputs with exact 4/6-clock alignment. Five additional targeted
reset states raise directed engine tests to 55/55. The instrumented directed
run now hits all core FSM transitions (9/9) and wrapper transitions (15/15).
Other code-coverage holes, protocol coverage, eligibility/gating proof, and
the timing gate remain open. No RTL or Quartus metrics changed.

Create `docs/ntt_docs/post_midyear/NTT_VERIFICATION_TESTPLAN.md` for the chosen architecture. Enumerate testable requirements and expected results for modular arithmetic, CT/GS butterflies, twiddle ROM, every stage/pass, bank conflicts, pipeline latency/drain, forward/inverse/PWM, inverse scaling, reset, repeated jobs, input gaps, output stalls, and future sampler handshakes. Define stimulus, independent oracle, assertions, scoreboard checks, and functional coverpoints/crosses for each requirement. Sample coverage from observed, **successfully checked** DUT transactions; distinguish hit bins from correct functionality. Enable DUT-only statement, branch, condition/expression, FSM, and toggle coverage, review holes, and document justified exclusions.

Run regression, coverage, synthesis, fitting, and TimeQuest during each meaningful design iteration. Pursue higher Fmax and positive setup/hold slack while preserving exact outputs and improving cycles/throughput. Track the trade-off in ALMs, registers, DSPs, and M10Ks rather than optimizing one number in isolation. Maintain `SPECIFICATION.md`, `THROUGHPUT.md`, `COVERAGE.md`, and `NTT_VIRTUAL_PIN_CONFIG.md` in this directory as soon as their measured interfaces and evidence are stable; update them after relevant changes. They are documentation deliverables, not substitutes for logs and checkers.

**Gate:** Requirements and coverage are reviewed, all priority checks pass, uncovered paths are explained, and fitted performance meets the agreed target or has an explicit accepted trade-off.

**Earlier retained Stage 4 RTL optimization (2026-10-09):** Removed the redundant
non-UVM candidate core/engine/arithmetic benches and launchers; historical
counts above remain earlier evidence. Main UVM owns regression and coverage.
The separately requested file-capture/Python comparison flow remains available.
The accepted LightHD RTL and fitted reports were saved in
`experiments/ntt_stage4/lighthd_before_sum_split/` before editing.

The measured baseline critical path was the inverse butterfly sum/reduction
feeding an inferred delay RAM. Registering the raw sum one existing stage
earlier passed verification but moved the bottleneck to the multiplier's two
folds and reduced worst-corner Fmax to 95.00 MHz; that intermediate result is
saved in `experiments/ntt_stage4/lighthd_sum_split_only/`, not selected alone.
The retained candidate also rebalances the four-cycle multiplier: product,
fold 1, folds 2/3, then fold 4/final reduction. No pipeline cycle was added.

| Measured metric | Saved baseline | Sum split only (not selected) | Retained sum split + reduction rebalance |
|---|---:|---:|---:|
| ALMs | 3,003 | 2,979 | **2,937** |
| Registers | 1,973 | 1,971 | **2,017** |
| DSP blocks | 6 | 6 | **6** |
| M10Ks | 20 | 20 | **20** |
| Slow 85 C Fmax (MHz) | 98.69 | 100.80 | **107.61** |
| Worst-corner Fmax, slow 0 C (MHz) | 96.56 | 95.00 | **101.28** |
| Worst setup slack at 5 ns (ns) | -5.356 | -5.526 | **-4.874** |
| Worst hold slack (ns) | +0.087 | +0.134 | **+0.121** |
| Core NTT / INTT / PWM / Pre cycles | 266 / 266 / 74 / 235 | unchanged | **unchanged** |
| Wrapper no-stall cycles, same order | 780 / 780 / 844 / 749 | unchanged | **unchanged** |

Same project/device/Quartus version/5 ns constraint were used. Worst-corner
Fmax rises about 4.89%, ALMs fall about 2.20%, and registers rise by 44.
The no-stall wrapper forward-NTT model is `Fmax*1e6/780`: 123,795 polynomials/s
at baseline versus **129,846 polynomials/s** now. This excludes integrated
SHAKE/sampler/controller waiting; it is not complete Dilithium throughput.

Fresh main UVM passes **115/115**, zero errors/fatals, and all thirteen
implemented checked functional covergroup types reach 100%. Independent Python
comparison passes **18/18 cases, 4,608/4,608 coefficients**. Evidence:
`sim/ntt_LightHD/uvm_balanced.log`, `vector_balanced.log`, `compare_balanced.log`,
`ntt_lighthd_coverage.rpt`; Quartus `results/ntt.fit.summary`, `ntt.sta.rpt`,
and `critical_paths.log` under `quartus/ntt_LightHD/`.
The RTL golden model is unchanged. At that checkpoint the worst setup path was multiplier
`t1_q[24] -> t3_q[22]` in both slow corners; input-index loading was near-critical.
Those measurements motivated the following retained changes.

**Stage 4 remains open:** the 5 ns setup and minimum pulse-width constraints
still fail; worst hold is positive. Continue timing/condition review and obtain
user acceptance before Stage 5. No post-synthesis/post-fit or FPGA result is
claimed for this changed RTL. No changes were committed.

**Latest retained Stage 4 iteration (2026-10-09):** Two further measured changes
preserve architecture and cycle counts:

1. Carry-save compression computes each q-specific fold with one final
   carry-propagate addition rather than serial subtraction/addition. The exact
   38-bit two's-complement identity is recorded in the saved checkpoint README.
2. Four fixed input-packing slices replace a variable bit offset `index*23`.
   The preceding critical-path report confirmed an inferred `u_core|Mult0`
   multiplier on that offset path. The four arithmetic butterfly multipliers
   remain; the final implementation uses one fewer DSP block.

| Same-device fitted metric | Previous retained | Carry-save only | Latest carry-save + fixed packing |
|---|---:|---:|---:|
| Worst-corner Fmax, slow 0 C (MHz) | 101.28 | 106.96 | **114.26** |
| Slow 85 C Fmax (MHz) | 107.61 | 109.05 | **116.06** |
| ALMs | 2,937 | 2,942 | **2,777** |
| Registers | 2,017 | 2,040 | **2,058** |
| DSP blocks | 6 | 6 | **5** |
| M10Ks | 20 | 20 | **20** |
| Worst setup at 5 ns (ns) | -4.874 | -4.349 | **-3.752** |
| Worst hold (ns) | +0.121 | +0.146 | **+0.079** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | unchanged | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | unchanged | **unchanged** |

The same Cyclone V device, Quartus version and 5 ns constraints are used.
Versus the preceding retained fit, worst-corner Fmax improves **12.82%** and
ALMs fall **5.45%**; registers rise by 41 and worst hold margin is smaller but
positive. The original LightHD fit was 96.56 MHz/3,003 ALMs, preserved separately.
The standalone NTT latency-based rate `114.26e6/780` is **146,487 polynomials/s**;
it excludes restart gaps, stalls and integrated Keccak/sampler/controller time.

Main UVM passes **115/115**, zero errors/fatals, and all thirteen implemented
checked covergroup types at 100%. Separate Python comparison passes **18/18
cases, 4,608/4,608 coefficients**; the SV golden model is unchanged. Exact logs:
`uvm_fixed_load.log`, `vector_fixed_load.log`, `compare_fixed_load.log` under
`sim/ntt_LightHD/`. Fresh synthesis, fit, all-corner STA and both slow critical
paths are in `quartus/ntt_LightHD/results/`. Intermediate rollback files are in
`experiments/ntt_stage4/lighthd_101mhz_checkpoint/` and `lighthd_csa_checkpoint/`.

The current setup bottleneck is the inferred butterfly operand-delay RAM through
final CT modular addition into `a_o`. This is the next measured timing target.
The planned [SPECIFICATION.md](SPECIFICATION.md), [THROUGHPUT.md](THROUGHPUT.md)
and [NTT_VIRTUAL_PIN_CONFIG.md](NTT_VIRTUAL_PIN_CONFIG.md) now document the current
interface, defined cycle/rate arithmetic and actual pin assignments. Current
Quartus settings use 59 package pins and zero virtual pins; no board locations
are manually assigned.

**Stage 4 remains open:** setup and minimum pulse width still fail at 5 ns;
condition/expression review, hardware Pre eligibility/integration and user result
review remain. Stage 5 has not begun. No netlist or FPGA result is claimed for
this changed RTL. No changes were committed.

### Stage 4 parallel modular-add checkpoint (2026-10-09)

The final CT sum path measured in the 114.26 MHz fit was replaced by parallel
raw/biased add candidates: q=2^23-8191, so for canonical operands the carry of
`a+t+8191` selects the already-corrected low bits. The biased candidate uses
carry-save compression. No pipeline latency changed.

Fresh fit improved worst-corner Fmax from **114.26 to 119.33 MHz** (+4.44%),
with slow 85 C **121.33 MHz**. ALMs changed **2,777 -> 2,808**, registers
**2,058 -> 2,042**, DSP/M10K **5/20 unchanged**. Worst setup at 5 ns improved
**-3.752 -> -3.380 ns**; worst hold changed **+0.079 -> +0.072 ns**.
Core and wrapper cycles stayed 266/266/74/235 and 780/780/844/749.

One directed first-stage arithmetic-boundary job was added to the **main UVM**.
It forces raw CT sums zero/below q/equal q/above q/maximum and all subtraction
signs. Actual registered operands, writebacks and all final outputs must pass
before crediting five sum and three subtraction bins. Main UVM now passes
**116/116**, zero errors/fatals, all **14** implemented covergroup types 100%.
The separate gate self-test falsely populates these masks on rejected jobs and
confirms no coverage credit. Python passes 18/18 cases, 4,608/4,608 coefficients.
The golden SV model is unchanged.

Evidence: `uvm_biased_add.log`, `vector_biased_add.log`, `compare_biased_add.log`,
`coverage_gate_arithmetic.log`; exact RTL and fitted reports are saved under
`experiments/ntt_stage4/lighthd_119mhz_checkpoint/`. The preceding 114.26 MHz
checkpoint is also saved. Timing moved to Pre arithmetic at slow 85 C and final
multiplier fold/correction at slow 0 C, motivating the next measured iteration.

### Latest retained Stage 4 arithmetic result (2026-10-09)

After the parallel CT add, both newly measured paths were optimized:

1. `ntt_core.pre_add()` uses the same parallel raw/biased sum candidates,
   removing the measured Pre sum -> comparison -> correction chain.
2. `mod_mul` specializes its final one-bit fold/correction to a single
   `low+8191` addition. The bound `fold3 <= 8,454,135` ensures that a high bit
   folds to at most 73,718, already canonical. With no high bit, the same
   adder carry selects `low-q` only when needed. The full derivation is in
   `experiments/ntt_stage4/lighthd_129mhz_checkpoint/README.md`.

| Same-device measured metric | Saved 114 MHz | Parallel CT add | Latest selected arithmetic |
|---|---:|---:|---:|
| Worst-corner Fmax, slow 0 C (MHz) | 114.26 | 119.33 | **129.08** |
| Slow 85 C Fmax (MHz) | 116.06 | 121.33 | **130.79** |
| ALMs | 2,777 | 2,808 | **2,717** |
| Registers | 2,058 | 2,042 | **2,078** |
| DSP blocks | 5 | 5 | **5** |
| M10Ks | 20 | 20 | **20** |
| Worst setup at 5 ns (ns) | -3.752 | -3.380 | **-2.747** |
| Worst hold, all corners (ns) | +0.079 | +0.072 | **+0.154** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | unchanged | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | unchanged | **unchanged** |

Against the saved 114.26 MHz fit, worst-corner Fmax improves **12.97%** and
ALMs fall **2.16%**; registers increase by 20. The same device, Quartus version,
5 ns constraint and fit settings were used. The standalone forward latency
model is `780/129.08 = 6.04 us`, with rate `129.08e6/780 = 165,487
polynomials/s`. This rate excludes restart gaps, stalls and integrated
SHAKE/sampler/controller time; it is not measured sustained Dilithium throughput.

Fresh **main UVM** passes **116/116**, zero errors/fatals, all **14** implemented
checked covergroup types 100%. Python passes **18/18 cases, 4,608/4,608
coefficients**. The strengthened separate UVM gate self-test passes: five
rejected jobs with falsely complete arithmetic masks cannot credit bins.
Exact source evidence: `uvm_final_fold.log` (also `uvm_stage4.log`),
`vector_final_fold.log`, `compare_final_fold.log`, `coverage_gate_final_fold.log`,
and `ntt_lighthd_coverage.rpt` under `sim/ntt_LightHD/`. The raw multiplier
toggle count is now 622/676 (54 constant-upper-bit misses); no code coverage
exclusions or directed coverage merge were applied.

Selected fresh fitted reports are in `quartus/ntt_LightHD/results/`; the exact
RTL/reports are also saved in `experiments/ntt_stage4/lighthd_129mhz_checkpoint/`.
The four-bank reference and prior 114/119 MHz checkpoints remain preserved.
The new worst paths in both slow corners start at the inferred butterfly
operand-delay RAM and end at final CT subtraction output `b_o`. This is the
next measured optimization target.

**Stage 4 remains open:** the 200 MHz target is not met. Worst setup is
-2.747 ns and minimum pulse width -0.555 ns at 5 ns; worst hold is positive.
Remaining code-condition/expression review, Pre hardware eligibility/integration
and user result review are still required. Stage 5 has not begun; no netlist
or FPGA result is claimed. Nothing was staged or committed.

### Stage 4 parallel-subtraction trial (2026-10-09)

The 129.08 MHz fit measured butterfly operand-delay RAM -> final CT subtraction
as its worst path. `butterfly_unit.msub()` now computes two candidates in
parallel: raw 24-bit `a-b` and corrected `a+~b+q+1`, using a carry-save
compressor for the corrected candidate. For canonical operands, the raw
wrapped difference's bit 23 is the borrow flag. Selecting corrected low bits
only on borrow gives the same canonical result, without a serial compare /
addition / subtraction chain. No register or pipeline clock is added.

The subtraction-only intermediate passes main UVM 116/116, Python 18/18 cases
and 4,608/4,608 coefficients, and the strengthened coverage gate. Its fresh fit
reduces ALMs 2,717 -> 2,589 and registers 2,078 -> 2,009, with 5 DSPs and 20
M10Ks unchanged, but worst-corner Fmax regresses 129.08 -> 125.16 MHz (slow
85 C; slow 0 C 126.55 MHz). Worst setup is -2.990 ns; worst hold +0.137 ns.
This intermediate is **not selected alone**. Its exact source and reports are
saved in `experiments/ntt_stage4/lighthd_parallel_sub_only/`. Critical paths
moved to `pre_product_q -> pre_diff_q` at both slow corners, so the next trial
applies the same parallel correction to `ntt_core.pre_sub()`.

The existing main-UVM arithmetic-boundary job now plants ten first-stage pairs,
including `(a,t)=(0,q-1)` and `(q-1,0)`. The observed raw differences must reach
`-(q-1)` and `q-1`, and checked canonical outputs must be 1 and q-1 respectively.
`cg_butterfly_arithmetic.cp_sub` expands from three sign bins to five classes:
minimum, other negative, zero, other positive, maximum. Together with the five
sum bins it closes 10/10, still within fourteen implemented covergroup types.
All bin credit remains gated by actual operands/writebacks and final golden
output/framing. The separate gate self-test poisons all five subtraction bits
on rejected jobs and verifies no coverage credit (`coverage_gate_parallel_sub.log`).
The golden model is unchanged.

### Stage 4 Pre subtraction and FIFO-data trial (2026-10-09)

The combined butterfly/Pre parallel-subtraction trial passes main UVM 116/116,
all fourteen implemented functional covergroups 100%, and Python 18/18 cases /
4,608/4,608 coefficients. Fresh fit: 2,594 ALMs, 2,005 registers, 5 DSPs,
20 M10Ks, 121.33 MHz worst Fmax (slow 85 C; slow 0 C 124.86 MHz), -3.242 ns
worst setup and +0.122 ns worst hold. This is another **non-selected**
intermediate, saved in `experiments/ntt_stage4/lighthd_pre_parallel_sub/`.

The new measured path is `state.IDLE -> FIFO2 portadatain`: state/input-valid/
address decode propagated through the write-data mux. The next trial keeps
all existing write enables/pop controls and data values on actual writes,
but selects data independently of loading eligibility. Data selection uses
registered Pre/compute return flags; inactive RAM data ports are not zeroed.
A simulation assertion checks that load/Pre/compute write sources cannot
coincide. Reset clears their valid flags, and the controller drains Pre and
compute returns before changing to the next write phase.

The independent main UVM model checks every active write value, destination,
pointer and physical memory update; it does not rely on unused data being zero.
The FIFO-data source trial passes main UVM 116/116 with zero errors/fatals and
all fourteen functional groups 100%. Python compares 18/18 cases and 4,608/4,608
coefficients. `routing_writeback_write_mux.log` records `UVM ROUTING CHECKER
PASS`: a deliberately corrupted observed writeback is rejected with zero
checked jobs/bins while actual DUT output remains correct. These source checks
do not select the candidate until its fresh fitted result is reviewed.

### Earlier selected Stage 4 subtraction/FIFO result (2026-10-09)

After both arithmetic trials regressed timing, separating the FIFO write-data
selection from loading eligibility produced a measured improvement. All four
butterflies, three coefficient FIFOs, PWM operand memory and pipeline lengths
remain unchanged. The golden SV mathematics are unchanged.

| Same-device measured metric | Saved selected | Butterfly sub only (not selected) | +Pre sub (not selected) | +FIFO data selection (selected) |
|---|---:|---:|---:|---:|
| Worst-corner Fmax (MHz) | 129.08 | 125.16 | 121.33 | **131.22** |
| Slow 85 C Fmax (MHz) | 130.79 | 125.16 | 121.33 | **131.32** |
| Slow 0 C Fmax (MHz) | 129.08 | 126.55 | 124.86 | **131.22** |
| ALMs | 2,717 | 2,589 | 2,594 | **2,428** |
| Registers | 2,078 | 2,009 | 2,005 | **2,022** |
| DSP blocks | 5 | 5 | 5 | **5** |
| M10Ks | 20 | 20 | 20 | **20** |
| Worst setup at 5 ns (ns) | -2.747 | -2.990 | -3.242 | **-2.621** |
| Worst hold, all corners (ns) | +0.154 | +0.137 | +0.122 | **+0.129** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | unchanged | unchanged | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | unchanged | unchanged | **unchanged** |

Against the saved selected build, Fmax improves **1.66%**, ALMs fall **10.64%**
(289 fewer), and registers fall by 56. Hold margin decreases by 0.025 ns but
remains positive. The same device, Quartus version, fit settings and 5 ns
constraints were used. The standalone forward wrapper latency model becomes
`780/131.22 = 5.94 us`; its latency-based rate is `131.22e6/780 = 168,231
polynomials/s`, excluding restart gaps, stalls and integrated SHAKE/sampler time.
This is not measured sustained Dilithium throughput.

Fresh main UVM: **116/116**, zero errors/fatals, all **14** implemented checked
covergroup types 100%, including **10/10** arithmetic bins. Python: **18/18
cases, 4,608/4,608 coefficients**. The negative coverage-credit and corrupted
writeback UVM self-tests pass without merging their deliberate failures into
the main coverage. Exact logs: `uvm_write_mux.log` (also `uvm_stage4.log`),
`vector_write_mux.log`, `compare_write_mux.log`, `coverage_gate_write_mux.log`,
`routing_writeback_write_mux.log` under `sim/ntt_LightHD/`. The main raw core
counts are statements 262/274, branches 218/233, conditions 64/103, expressions
28/29, states 5/5, transitions 9/9 and toggles 3661/3669. No code exclusions.

Selected fresh fit/STA/critical-path reports are in `quartus/ntt_LightHD/results/`,
and exact RTL/reports are saved in `experiments/ntt_stage4/lighthd_write_mux_checkpoint/`.
The earlier 129.08 MHz checkpoint and both non-selected trials remain saved.
New measured targets: **Pre lookup (`load_pack -> pre_product_q`) at slow 85 C**
and **multiplier folds 2/3 (`t1_q -> t3_q`) at slow 0 C**.

**Stage 4 remains open:** 200 MHz setup and minimum pulse width still fail
(-2.621 ns and -0.555 ns); raw condition/expression review, Pre hardware
eligibility/integration and user result review remain. Stage 5 has not begun.
Nothing was staged or committed.

### Earlier Stage 4 decoder/reducer trial review (2026-10-09)

Two isolated changes were implemented, verified with MAIN UVM and separate
Python comparison, and measured with fresh map/fit/STA plus both slow-corner
critical-path reports. Neither is selected. No golden mathematics changed.

| Same-device metric | Selected reference / restored RTL | Narrow Pre decoder trial | Collapsed multiplier trial |
|---|---:|---:|---:|
| Worst-corner Fmax (MHz) | **131.22** | 129.70 | 123.38 |
| Slow 85 C Fmax (MHz) | 131.32 | 132.12 | 125.23 |
| Slow 0 C Fmax (MHz) | 131.22 | 129.70 | 123.38 |
| ALMs | **2,428** | 2,392 | 2,671 |
| Registers | 2,022 | 2,017 | 2,078 |
| DSP / M10K | 5 / 20 | 5 / 20 | 5 / 20 |
| Worst setup at 5 ns (ns) | -2.621 | -2.710 | -3.105 |
| Worst hold, all corners (ns) | +0.129 | +0.163 | +0.172 |
| Minimum pulse width at 5 ns (ns) | -0.555 | -0.555 | -0.555 |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | unchanged | unchanged |
| Wrapper no-stall cycles | 780/780/844/749 | unchanged | unchanged |
| Main UVM passing jobs | 117/117 after restoration | 116/116 | 117/117 |
| Separate Python cases / coefficients | 18 / 4,608 | 18 / 4,608 | 18 / 4,608 |

**Narrow Pre decoder:** the nine canonical residues for -4..4 have unique keys
`{x[22],x[2:0]}`. Replacing full-width lookup comparisons saved 36 ALMs, but the
worst Fmax fell. The critical path moved to twiddle ROM -> `bf_zi_q` at both
slow corners. Invalid +8 aliases zero in the narrow lookup; the unchanged exact
simulation eligibility guard rejects it before a passing job. This is not
synthesized hardware validation. The full-width selected decoder is restored.
Saved source/reports: `experiments/ntt_stage4/lighthd_pre_decode_trial/`.

**Collapsed multiplier:** split stage-2 `t1=L+2^23*H`, with
`H=1024*Hhi+Hlo`. Since `1024*8191=q+7167`, a congruent value is
`T=L+(Hlo<<13)-Hlo+7167*Hhi`. An eight-entry high correction and parallel
raw/biased carry-save candidates replace two serial folds. Because
`T<=16,818,169` can exceed `2q`, stage 3 subtracts q once when required and the
existing final stage completes canonical reduction; no latency is added.
The candidate is functionally correct in the exercised tests, but its routed
stage-3 path is slower and it costs 243 more ALMs. Both slow critical paths are
`t1_q[6] -> t3_q[14]`. Saved source/reports:
`experiments/ntt_stage4/lighthd_collapsed_reduce_trial/`.

**Useful verification retained:** `ntt_reduction_boundary_seq` adds one main-UVM
PWM job. Five real operand pairs are repeated across all four lanes; the
independent golden and observed outputs are `0/1/1/10000/30000`. The pairs
force the trial's zero/one/two-correction cases, final high-bit folding and
raw T bit 24. The last bit was initially unhit and was exercised with a real
canonical operand pair rather than labeled constant. All registered operands,
physical FIFO writes, 256 outputs and framing pass before the scoreboard
prints `CHECKED_REDUCTION_BOUNDARIES`. See `COVERAGE.md` for exact inputs.
This adds no covergroup; all fourteen checked types remain 100%.

All six active RTL files are restored byte-for-byte from
`lighthd_write_mux_checkpoint`. Main `uvm_selected_restore.log` (also
`uvm_stage4.log`) passes **117/117**, zero UVM errors/fatals, with 117 checked
trace/routing witnesses and unchanged raw code counts. Separate
`vector_selected_restore.log` / `compare_selected_restore.log` pass **18/18
cases, 4,608/4,608 coefficients**. The exact +8 DUT eligibility fatal is checked
in `pre_invalid_alias_selected_restore.log`; its failed UCDB is kept separate.
Fresh selected map/fit/STA/critical paths completed after restoration and
reproduce **131.22 MHz, 2,428 ALMs, 2,022 registers, 5 DSPs and 20 M10Ks**;
worst setup/hold/pulse slacks remain **-2.621/+0.129/-0.555 ns**.
The active database therefore matches the selected RTL rather than a rejected
candidate. Reports in `quartus/ntt_LightHD/results/` are refreshed from this
build; logs use the `selected_restore_*` prefix.

**Next Stage 4 work:** retain the measured winner; investigate the selected
Pre lookup and multiplier stage-3 paths, including physical fanout/routing and
pipeline balance. Any further latency change requires updating butterfly,
return-tag and independent UVM schedules together before measuring Fmax.
The 200 MHz setup/pulse-width target, raw code-hole review, hardware eligibility
integration and user result acceptance remain open. Stage 5 has not started.
No files were staged or committed.

### Earlier selected Stage 4 multiplier rebalance (2026-10-09)

A fresh isolated trial redistributed the same four multiplier registers:
product / fold1 / fold2 / fold3 with parallel canonical correction. Previously
stage 3 performed two serial folds and stage 4 performed the fourth fold and
correction. The third-fold bound is already below 2q, permitting direct
canonical correction. All other five RTL files match the 131.22 MHz checkpoint;
no BF/controller/tag/FIFO latency or golden-model change was needed.

| Same-device measured metric | Saved reference | Selected rebalance |
|---|---:|---:|
| Worst-corner Fmax (MHz) | 131.22 | **134.50** |
| Slow 85 C Fmax (MHz) | 131.32 | **139.30** |
| Slow 0 C Fmax (MHz) | 131.22 | **134.50** |
| ALMs | 2,428 | **2,487** |
| Registers | 2,022 | **2,081** |
| DSP / M10K | 5 / 20 | **5 / 20** |
| Block memory bits | 37,220 | **37,220** |
| Worst setup at 5 ns (ns) | -2.621 | **-2.435** |
| Worst hold, all corners (ns) | +0.129 | **+0.172** |
| Worst minimum pulse width at 5 ns (ns) | -0.555 | **-0.555** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | **unchanged** |

Fmax improves **2.50%** for **59 more ALMs (+2.43%)** and 59 more registers.
Worst setup improves by 0.186 ns and hold by 0.043 ns. This is a timing/area
tradeoff, not an area reduction. Same Cyclone V 5CGXFC7C7F23C8, Quartus 25.1std
Lite, standard fit and 5 ns constraints. Source correctness and fresh physical
measurement support retaining this result; the 131.22 MHz checkpoint stays saved.

For fold-two result t2, `H=t2>>23<=8`, `L=t2[22:0]`, and
`T=L+(H<<13)-H<=8,454,135<2q`. Parallel candidates T and T+8191 use carry-save
compression and one final carry propagation each. Because `T+8191<2^24`, its
bit23 is true exactly when T>=q; selecting the low23 bits returns T-q. Otherwise
return T. This includes T>=2^23 and eliminates a separate fourth fold. The full
argument and width/constant-bit coverage proof are in `COVERAGE.md`.

Main `uvm_final_rebalance.log` (also `uvm_stage4.log`) passes **117/117**, zero
errors/fatals, fourteen checked functional covergroup types 100%, 117 trace and
routing witnesses, ten CT arithmetic bins, and observed all-lane PWM boundary
results 0/1/1/10000/30000. Each multiplier now has **35/35 statements, 10/10
branches and 876/990 raw toggles**; 114 misses are both directions on 57
constant bits, individually explained without exclusions. Core/wrapper/butterfly
raw counts are unchanged. Its former two-term OR condition was replaced by a
single-bit selection, so there are no instrumented logical condition terms in
this helper; selection outcomes are still branch bins.

Separate Python `vector_final_rebalance.log` / `compare_final_rebalance.log`
passes **18/18 cases, 4,608/4,608 coefficients**, with identical mode cycle
boundaries. Fresh UVM `coverage_gate_final_rebalance.log` rejects five corrupted
items without credit, and `routing_writeback_final_rebalance.log` rejects a
corrupted observed FIFO write with real DUT output correct and checked_jobs=0.
Expected-failure UCDBs are not merged into passing coverage.

Fresh selected reports are in `quartus/ntt_LightHD/results/`; build logs are
`final_rebalance_map.log`, `final_rebalance_fit.log`, `final_rebalance_sta.log`
and `final_rebalance_paths.log`. Exact source/reports and source evidence are
saved in `experiments/ntt_stage4/lighthd_final_rebalance_checkpoint/`.
Synthesis/fitter warning classes are unchanged: read-only ROM unused inputs,
unused s_tlast, licensing and unassigned physical I/O. The core-only benchmark
still uses 59 auto-assigned physical pins, zero virtual pins and false-pathed
external I/O; no board-interface timing validation is implied.

The fitted-clock NTT wrapper estimate is `780/134.50=5.80 us`, core estimate
`266/134.50=1.98 us`, and latency-based rate `134.50e6/780=172,436 polynomials/s`.
This excludes restart gaps, input/output stalls and SHAKE/sampler waiting;
it is not measured sustained Dilithium throughput.

**Next measured Stage 4 target:** inverse-butterfly input subtraction
`bf_bi_q[0][0] -> mul_gs_reg[10]` is worst at both slow corners. FIFO read and
twiddle-ROM paths also appear in the top three. The full two-corner path report
is preserved for the next decision; do not assume the multiplier remains worst.
**Stage 4 stays open:** 200 MHz setup and pulse-width timing still fail, raw
code-hole review and hardware eligibility/integration remain, and user result
acceptance precedes Stage 5. No post-netlist or FPGA result is claimed.
No files were staged or committed.

### Earlier selected Stage 4 q+1 subtraction (2026-10-09)

The measured inverse GS input subtraction path was optimized by absorbing its
two's-complement +1 into constant q+1 before carry-save compression. The helper
still computes raw x-y and corrected x-y+q in parallel and selects correction
on borrow. It is also used by CT output subtraction. Only `butterfly_unit.sv`
changes from the 134.50 MHz checkpoint; the Pre helper and other five RTL files
are unchanged. Pipeline, controller and FIFO schedules are unchanged.

| Same-device measured metric | Saved reference | Selected q+1 rewrite |
|---|---:|---:|
| Worst-corner Fmax (MHz) | 134.50 | **137.04** |
| Slow 85 C Fmax (MHz) | 139.30 | **139.06** |
| Slow 0 C Fmax (MHz) | 134.50 | **137.04** |
| ALMs | 2,487 | **2,451** |
| Registers | 2,081 | **2,071** |
| DSP / M10K | 5 / 20 | **5 / 20** |
| Memory bits | 37,220 | **37,220** |
| Worst setup at 5 ns (ns) | -2.435 | **-2.297** |
| Worst hold, all corners (ns) | +0.172 | **+0.169** |
| Worst minimum pulse width at 5 ns (ns) | -0.555 | **-0.555** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | **unchanged** |

Worst Fmax improves **1.89%**, area falls **36 ALMs (1.45%)**, registers fall
by ten, and worst setup improves by 0.138 ns. Slow85 Fmax falls 0.24 MHz and
worst hold falls 0.003 ns, remaining positive. Selection uses worst-corner
performance rather than the more favorable temperature alone. Same device,
Quartus version, standard fit and constraints as the reference.

For canonical x/y, the wrapped 24-bit raw difference has bit23 set exactly
when x<y. With a 24-bit complement, `x+~y+(q+1)=x-y+q+2^24`; taking 24 bits
returns x-y+q, which fits the width. The constant includes +1 before the
compressor, so its shifted carry word ends in zero. On borrow the corrected
answer lies in [1,q-1]; otherwise raw lies in [0,q-1]. The proof and unchanged
Pre helper distinction are documented in `COVERAGE.md`.

Main `uvm_sub_qplus1.log` (also `uvm_stage4.log`) passes **117/117**, zero
UVM errors/fatals, fourteen checked functional covergroup types 100%, 117 trace/
routing witnesses, ten CT arithmetic bins and the all-lane PWM product/carry
witness. Butterfly raw counts remain 54/54 statements, 17/17 branches, 1/1
condition and 656/656 toggles in every lane; all other raw code counts remain
unchanged. No code exclusions, directed-test merge or failed-UCDB merge.

Separate `vector_sub_qplus1.log` / `compare_sub_qplus1.log` passes **18/18
cases, 4,608/4,608 coefficients** with identical cycle boundaries. Golden SV
and Python mathematics and vector files are unchanged. Existing checker
sensitivity evidence is preserved with the preceding checkpoint; no checker
code or latency contracts changed, and those separate expected failures are
not counted as new passing jobs or newly rerun in this arithmetic-only trial.

Fresh selected reports are in `quartus/ntt_LightHD/results/`; build logs are
`sub_qplus1_map.log`, `sub_qplus1_fit.log`, `sub_qplus1_sta.log` and
`sub_qplus1_paths.log`. Exact RTL and evidence are saved in
`experiments/ntt_stage4/lighthd_sub_qplus1_checkpoint/`; the 134.50 MHz checkpoint
remains saved. NTT wrapper/core estimates at fitted worst Fmax are
`780/137.04=5.69 us` and `266/137.04=1.94 us`; latency-based rate is
`137.04e6/780=175,692 polynomials/s`, excluding restart gaps, stalls and
SHAKE/sampler time. This is not sustained integrated Dilithium throughput.

**Next measured Stage 4 target:** twiddle-ROM read -> `bf_zi_q` is worst at
both slow corners (lane3 at85C; lane2 at0C). Inspect ROM output registration,
address/value alignment and physical clock/routing delay before changing it;
any new latency must be reflected in the independent UVM observation schedule.
**Stage 4 remains open:** 200 MHz setup/pulse width still fail, raw code-hole
review and hardware eligibility/integration remain, and user result acceptance
precedes Stage 5. No netlist/FPGA verification result is claimed.
No files were staged or committed.

### Earlier selected Stage 4 twiddle-guard removal (2026-10-10)

The previous worst path was twiddle ROM -> equality/control logic -> bf_zi_q.
Remove only the inverse `tw[lane] != 0` guard in `ntt_core.sv`. Every one of
256 initialized ROM entries is in [1,q-1], including address zero (value 1),
so inverse Q-tw is canonical and the guard is redundant. Mode/PWM selection
remains. The existing independent UVM observes actual registered twiddle values
and FIFO writebacks; no oracle, vector, pipeline, interface or schedule changed.

| Same-device measured metric | Saved q+1 checkpoint | Selected guard removal |
|---|---:|---:|
| Worst-corner Fmax (MHz) | 137.04 | **140.69** |
| Slow 85 C Fmax (MHz) | 139.06 | **143.43** |
| Slow 0 C Fmax (MHz) | 137.04 | **140.69** |
| ALMs | 2,451 | **2,427** |
| Registers | 2,071 | **2,123** |
| DSP / M10K | 5 / 20 | **5 / 20** |
| Memory bits | 37,220 | **37,220** |
| Worst setup at 5 ns (ns) | -2.297 | **-2.108** |
| Worst hold, all corners (ns) | +0.169 | **+0.086** |
| Worst minimum pulse width at 5 ns (ns) | -0.555 | **-0.555** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | **unchanged** |

Worst Fmax improves **2.66%**; area falls **24 ALMs (0.98%)**. Registers rise
by 52 due to fitted implementation changes, despite no added RTL pipeline stage.
Worst setup improves 0.189 ns. All-corner hold falls 0.083 ns but remains
positive. Same Cyclone V device, Quartus version, standard fit and constraints.

Main `uvm_tw_nonzero.log` (also `uvm_stage4.log`) passes **117/117**, zero UVM
errors/fatals, fourteen checked covergroup types 100%, 117 trace/routing
witnesses, all ten CT arithmetic bins and the all-lane PWM product/carry witness.
Raw core conditions are **64/102**, formerly 64/103: a redundant condition was
removed, with no extra hit claimed. All other raw counts remain unchanged.
No code exclusions or failed/directed-UCDB merges.

Fresh separate checker runs: `coverage_gate_tw_nonzero.log` rejects five bad
jobs without credit; `routing_writeback_tw_nonzero.log` detects a corrupted
observed FIFO write despite correct final outputs; `pre_invalid_alias_tw_nonzero.log`
reaches the exact intended illegal +8 Pre-input fatal. These are checker
sensitivity/expected-failure results, not extra passing regression jobs.

`vector_tw_nonzero.log` / `compare_tw_nonzero.log` pass **18/18 cases,
4,608/4,608 coefficients**. NTT wrapper/core modeled latencies are
`780/140.69=5.54 us` and `266/140.69=1.89 us`; latency-based rate is
`140.69e6/780=180,372 polynomials/s`. Restart gaps, stalls and SHAKE/sampler
waiting are excluded; this is not sustained integrated Dilithium throughput.

Fresh selected reports are in `quartus/ntt_LightHD/results/`, generated by
`tw_nonzero_map.log`, `tw_nonzero_fit.log`, `tw_nonzero_sta.log` and
`tw_nonzero_paths.log`. Exact RTL, main UCDB/report and logs are saved in
`experiments/ntt_stage4/lighthd_tw_nonzero_checkpoint/`. The preceding
137.04 MHz checkpoint remains saved.

**Next measured Stage 4 target:** FIFO1 RAM read -> word/operand selection ->
`bf_bi_q[0][12]` is worst at both slow corners. Inspect mux structure and
physical routing before adding latency; any retiming must preserve independent
operand/tag alignment checks. **Stage 4 remains open:** 200 MHz setup/pulse
width still fail, raw code-hole review and hardware eligibility/integration
remain, and user result acceptance precedes Stage 5. No netlist/FPGA result.
Nothing staged or committed.

### Earlier selected Stage 4 operand-selector rewrite (2026-10-10)

The 140.69 MHz reference's worst path was FIFO RAM -> word selection ->
coefficient selection -> registered BF input. Decode the combined FIFO and
coefficient selection alongside the FIFO read instead. Registered one-hot
masks then select data directly from fifo_q1/2/3. Masks align with tag[0] and
the synchronous RAM outputs. No extra pipeline stage, interface change,
controller/FIFO schedule change, oracle change or cycle change. Only
`ntt_core.sv` differs from the saved reference; unused source_a_q/source_b_q
registers are removed. Independent registered-operand/writeback checks remain.

| Same-device measured metric | Saved smaller reference | Rejected generic masks | Selected fixed Boolean masks |
|---|---:|---:|---:|
| Worst-corner Fmax (MHz) | 140.69 | 137.87 | **145.18** |
| Slow 85 C Fmax (MHz) | 143.43 | 139.88 | **145.18** |
| Slow 0 C Fmax (MHz) | 140.69 | 137.87 | **148.37** |
| ALMs | 2,427 | 2,579 | **2,592** |
| Registers | 2,123 | 2,101 | **2,152** |
| DSP / M10K | 5 / 20 | 5 / 21 | **5 / 21** |
| Memory bits | 37,220 | 37,252 | **37,252** |
| Worst setup at 5 ns (ns) | -2.108 | -2.253 | **-1.888** |
| Worst hold, all corners (ns) | +0.086 | +0.165 | **+0.168** |
| Worst minimum pulse width at 5 ns (ns) | -0.555 | -0.555 | **-0.555** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | unchanged | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | unchanged | **unchanged** |

The generic version uses variable one-hot bit indexing and unpacked masks.
It passed source correctness but was slower and larger, so it is rejected.
The selected version uses fixed Boolean equations and packed masks; their
bits are visible to raw toggle coverage. Worst Fmax improves **3.19%** over
the saved reference, at a cost of **165 ALMs (6.80%), 29 registers and one
M10K**. Hold improves 0.082 ns, setup improves 0.220 ns. This is explicitly a
speed/area tradeoff. The smaller 140.69 MHz source and reports remain saved.
All measurements use the same Cyclone V device, Quartus and 5 ns constraints.

The selected map RAM summary identifies the extra 32 bits as an inferred
8x4 tag inverse shift RAM, not a new polynomial buffer. Fixed Boolean masks
do not by themselves prevent Quartus from regrouping control shift registers.
The original coefficient FIFO dimensions and PWM store are unchanged.

Main `uvm_operand_boolean.log` (also `uvm_stage4.log`) passes **117/117**, zero
UVM errors/fatals, fourteen checked covergroup types 100%, all 117 trace/routing
witnesses, CT arithmetic boundaries and all-lane PWM product/carry boundaries.
Raw core counts: **270/282 statements, 219/233 branches, 55/92 conditions,
47/48 expressions, 5/5 states, 9/9 transitions, 3399/3677 toggles**. Counts
change with the source structure; no blanket percentage improvement is claimed.
`COVERAGE.md` accounts for all 278 missed core toggles: 272 constant selector
bins plus six existing constant control bins. No exclusions or failed-UCDB merges.

Fresh separate `coverage_gate_operand_boolean.log` rejects five bad jobs without
credit. `routing_operand_operand_boolean.log` and
`routing_writeback_operand_boolean.log` detect corrupted observed operands and
FIFO writes despite correct real outputs, with checked_jobs=0. These expected
failures stay outside the passing UCDB. The unchanged Pre eligibility guard's
previous exact-fatal evidence remains saved; it was not newly rerun here.

Separate `vector_operand_boolean.log` / `compare_operand_boolean.log` passes
**18/18 cases, 4,608/4,608 coefficients**; SV/Python mathematics and vector
files unchanged. NTT modeled wrapper/core latency is `780/145.18=5.37 us` /
`266/145.18=1.83 us`; latency-based rate is `145.18e6/780=186,128 polynomials/s`.
Restart gaps, stalls and SHAKE/sampler time are excluded. No sustained integrated
Dilithium throughput is claimed.

Fresh reports are in `quartus/ntt_LightHD/results/`, from
`operand_boolean_map.log`, `operand_boolean_fit.log`, `operand_boolean_sta.log`
and `operand_boolean_paths.log`. Exact source, main UCDB/report, checker logs
and full map RAM report are saved in
`experiments/ntt_stage4/lighthd_operand_boolean_checkpoint/`. The rejected
variant is saved in `lighthd_operand_decode_trial/`; the smaller reference
remains in `lighthd_tw_nonzero_checkpoint/`.

**Next measured Stage 4 targets:** slow85 worst path is BF lane2 keep_sum_reg
-> shared keep_dly shift RAM; slow0 worst path remains FIFO1 RAM -> lane0
bf_bi_q. Inspect operand-delay RAM packing/routing and the remaining read path
before changing latency. **Stage 4 remains open:** 200 MHz setup/pulse width
still fail, raw code-hole review and hardware eligibility/integration remain,
and user acceptance precedes Stage 5. No netlist or FPGA result. Nothing committed.

### Latest selected Stage 4 kept-sum reduction (2026-10-10)

The measured slow85 path was keep_sum_reg -> wide comparison/reduction ->
shared keep_dly RAM. Replace the inverse kept-sum comparator with a carry-bit
identity in `butterfly_unit.sv`. For S=a+b from canonical a/b, S is in[0,2q-2].
B=S+8191 is in[8191,16769023], below2^24. B[23] is set iff S>=q; its low23
bits then equal S-q. Otherwise choose S. CT still keeps a. Only the butterfly
RTL differs from the145.18MHz checkpoint; no pipeline, FIFO, interface, oracle
or cycle change. The four-cycle multiplier/six-cycle BF/nine-cycle return remain.

| Same-device measured metric | Saved operand-selector checkpoint | Selected carry reduction |
|---|---:|---:|
| Worst-corner Fmax (MHz) | 145.18 | **145.73** |
| Slow85 Fmax (MHz) | 145.18 | **145.73** |
| Slow0 Fmax (MHz) | 148.37 | **146.01** |
| ALMs | 2,592 | **2,568** |
| Registers | 2,152 | **2,117** |
| DSP / M10K | 5 / 21 | **5 / 21** |
| Memory bits | 37,252 | **37,252** |
| Worst setup at5ns (ns) | -1.888 | **-1.862** |
| Worst hold, all corners (ns) | +0.168 | **+0.104** |
| Worst pulse width at5ns (ns) | -0.555 | **-0.555** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | **unchanged** |
| Wrapper no-stall cycles | 780/780/844/749 | **unchanged** |

Worst Fmax improves0.38%, area falls24ALMs(0.93%), registers fall35, setup
improves0.026ns. Slow0Fmax falls2.36MHz; worsthold falls0.064ns but remains
positive. Selection uses the worst corner. Same device/Quartus/fit/constraints.

Main UVM now passes **118/118**, zero UVM errors/fatals and fourteen checked
covergroup types100%. One new `ntt_inverse_sum_boundary_seq` follows the prior117
jobs. INTT stage0 adjacent pairs force sums0,q-1,q,q+1,2q-2 on all four lanes.
The routing trace classifies actual registered GS operands with plain integer
addition. The named job requires all five classes on every lane before
scoreboard publication, plus independent physical writeback and full256-output
comparison. `CHECKED_GS_SUM_BOUNDARIES` prints11111/11111/11111/11111.
This is a directed correctness witness, not an invented fifteenth covergroup.

Fresh separate `gs_sum_gate_keep_bias.log` hides lane2's exact-q observation
while retaining correct real outputs; the scoreboard rejects it and checked_jobs
stays1. `coverage_gate_keep_bias.log` rejects the five existing deliberate
failures without credit. Failed UCDBs stay separate. Earlier operand/writeback
corruption and Pre eligibility evidence remain preserved, not newly rerun here.
Each BF raw coverage:55/55statements,17/17branches,704/704toggles. The former
comparator's logical condition disappears; carry selection has no such bin.
Core/wrapper/multiplier raw counts unchanged; no exclusions.

Logs: `uvm_keep_bias.log` (also `uvm_stage4.log`), `vector_keep_bias.log`,
`compare_keep_bias.log`; Python passes **18/18cases,4608/4608coefficients**.
Vector files and SV/Python golden mathematics unchanged. NTT modeled wrapper/
core latency780/145.73=5.35us /266/145.73=1.83us; latency-based rate
145.73e6/780=186833polynomials/s. Excludes restart gaps, stalls, SHAKE/sampler
waiting; not measured sustained integrated Dilithium throughput.

Fresh selected reports in `quartus/ntt_LightHD/results/` come from
`keep_bias_map.log`, `keep_bias_fit.log`, `keep_bias_sta.log`, `keep_bias_paths.log`.
Exact RTL/main coverage/checker logs are saved in
`experiments/ntt_stage4/lighthd_keep_bias_checkpoint/`. Prior145.18MHz and
smaller140.69MHz checkpoints remain saved.

**Next measured targets:** slow85 tick[6] -> FIFO read-enable decode;
slow0 lane2 multiplier prod_s1 -> t1_q. Inspect controller decode/fanout and multiplier
read alignment before adding latency. **Stage4 remains open:**200MHz setup/
pulse timing fails, raw code-hole review and hardware eligibility/integration
remain. User acceptance precedes Stage5. No netlist/FPGA result. Nothing committed.

### Direct FIFO route decoder trial (2026-10-10)

Replace variable group shifts in `ntt_core.sv` with explicit stage/issue-bit
route decoding and direct Boolean FIFO read enables. No latency, operation
schedule, interface, coefficient storage or golden-model change. Fresh main
UVM passes **118/118**, with zero errors/fatals and all fourteen checked
covergroup types at 100%. Python passes **18/18 cases, 4,608/4,608 coefficients**.
Separate operand and physical-writeback corruption tests reject correctly
without checked coverage credit; failed UCDBs stay separate.

| Same-device metric | Selected keep-bias | Direct route trial |
|---|---:|---:|
| Worst Fmax (MHz) | 145.73 | 140.43 |
| Slow85 / slow0 Fmax (MHz) | 145.73 / 146.01 | 141.06 / 140.43 |
| ALMs / registers | 2,568 / 2,117 | 2,436 / 2,150 |
| DSP / M10K | 5 / 21 | 5 / 20 |
| RAM bits | 37,252 | 37,216 |
| Worst setup at 5 ns (ns) | -1.862 | -2.121 |
| Worst all-corner hold (ns) | +0.104 | +0.163 |
| Worst pulse width at 5 ns (ns) | -0.555 | -0.555 |

This saves 132 ALMs and one M10K but lowers worst Fmax by 3.64%; preserve it
as a smaller alternative, not the speed selection. The 36-bit valid-tag RAM
mapping disappears; coefficient FIFO capacity is unchanged. Both slow-corner
worst paths now run `load_pack -> pre_product_q`, exposing the Pre lookup.
Core 266/266/74/235 and wrapper 780/780/844/749 cycles remain unchanged.

Exact RTL, UVM/Python/checker logs, raw code report and map/fit/STA/path evidence:
`experiments/ntt_stage4/lighthd_route_decode_trial/`. Core raw coverage is
295/307 statements, 232/245 branches, 53/84 conditions, 51/52 expressions,
5/5 states, 9/9 transitions and 3,405/3,683 toggles. Source changes alter the
coverage denominators; the same 278 constant-bit toggle misses remain.
No exclusions. No netlist/FPGA claim. Nothing staged or committed.

### Direct route plus narrow Pre lookup trial (2026-10-10)

The direct-route trial exposed `load_pack -> pre_product_q` as its measured
worst path. On that source, decode the Pre lookup from `{x[22],x[2:0]}`.
For canonical residues representing -4..4, these four bits uniquely identify
all nine legal values (`q mod 8 = 1`). All products remain exactly
`x*4808194 mod q`. Invalid inputs can alias legal keys. The full simulation
eligibility guard remains; hardware callers still must guarantee eligibility.
No hardware rejection flag was added.

| Same-device metric | Selected keep-bias | Route plus narrow Pre key |
|---|---:|---:|
| Worst Fmax (MHz) | 145.73 | 145.20 |
| Slow85 / slow0 Fmax (MHz) | 145.73 / 146.01 | 150.24 / 145.20 |
| ALMs / registers | 2,568 / 2,117 | 2,362 / 2,102 |
| DSP / M10K | 5 / 21 | 5 / 20 |
| RAM bits | 37,252 | 37,216 |
| Worst setup at 5 ns (ns) | -1.862 | -1.887 |
| Worst all-corner hold (ns) | +0.104 | +0.156 |
| Worst pulse width at 5 ns (ns) | -0.555 | -0.555 |

Area falls 206 ALMs (8.02%) and one M10K. Although slow85 reaches 150.24 MHz,
worst-corner Fmax falls 0.36%. Preserve this as a smaller alternative. The lookup
is no longer the worst path: slow0 is lane0 multiplier `prod_s1[37] -> t1_q[34]`;
slow85 is `pre_sum_q[24] -> FIFO1 write data`.

Fresh `uvm_route_pre_key.log` passes **118/118**, with zero errors/fatals and
all fourteen checked covergroup types at 100%, including 27/27 Pre
value/position bins and sixteen Pre/general equivalence pairs.
`vector_route_pre_key.log` / `compare_route_pre_key.log` passes **18/18 cases,
4,608/4,608 coefficients**. `pre_alias_route_pre_key.log` separately rejects
+8, which shares zero's lookup key, with the exact DUT eligibility fatal.
Its UCDB is not merged. Core/wrapper cycles and SV/Python mathematics are
unchanged. Raw core counts match the direct route trial above; source
coverage denominators differ from the selected source.

Exact RTL and complete evidence are saved in
`experiments/ntt_stage4/lighthd_route_pre_key_trial/`. The selected keep-bias
RTL was restored byte-for-byte. Fresh main UVM and Python again pass 118/118
and 4,608/4,608. Map/fit/STA/paths are rebuilt to align the active source and
implementation database. Stage 4 stays open; Stage 5 requires user acceptance.
Nothing staged or committed.

### Selected checkpoint restoration confirmed (2026-10-10)

Fresh `keep_bias_restore_map.log`, `keep_bias_restore_fit.log`,
`keep_bias_restore_sta.log` and `keep_bias_restore_paths.log` reproduce the
selected result: **145.73 MHz worst Fmax**, slow0 146.01 MHz, **2,568 ALMs**,
2,117 registers, **5 DSPs / 21 M10Ks**, and 37,252 RAM bits. At 5 ns, worst
setup is **-1.862 ns**, worst all-corner hold is **+0.104 ns**, and worst pulse
width is **-0.555 ns**. The active six RTL files match the saved keep-bias
checkpoint byte-for-byte. `quartus/ntt_LightHD/results/` now contains these
fresh restored-build reports and `critical_paths.log`; the implementation
database matches the active source.

Fresh `uvm_keep_bias_restore.log` (also `uvm_stage4.log`) passes **118/118**,
zero UVM errors/fatals, with all fourteen checked functional covergroup types
at 100%. `vector_keep_bias_restore.log` / `compare_keep_bias_restore.log`
passes **18/18 cases, 4,608/4,608 coefficients**. Core and wrapper cycles are
unchanged. Selected raw code coverage returns to the counts in `COVERAGE.md`.
Both smaller trials and all earlier checkpoints remain preserved.

**Next Stage 4 targets:** selected slow85 still runs tick[6] -> FIFO read-enable;
selected slow0 runs lane2 multiplier prod_s1 -> t1_q. The combined smaller
trial removes the read-decode path from the reported worst paths, so its
multiplier first fold and Pre writeback are useful further optimization targets.
Any new RTL trial must repeat the same UVM/Python and full fitted timing checks.
The 200 MHz setup/pulse target remains unmet. Stage 5 still requires user
acceptance; no netlist/FPGA claim. Nothing staged or committed.

### First-fold carry-select mapping trial (2026-10-10)

Starting from the saved smaller route/Pre-key alternative, split the multiplier
first fold's 36-bit carry-propagate addition into two 18-bit halves. Compute
both upper carry candidates and select using the lower carry. No pipeline or
cycle changes. Existing directed PWM pairs drive both carry values on all four
physical multiplier lanes; independent operands, physical writes and all final
outputs remain checked. Golden models and reference files are unchanged.

Main UVM passes 118/118, zero errors/fatals, with fourteen checked groups at
100%; Python passes 18/18 cases and all 4,608 coefficients. Each multiplier
has 44/44 statements and 12/12 branches hit. Its 1,266/1,460 toggle result
leaves only the 194 directions of 97 constant bits listed in the saved report.
Exposing the split adds 40 constant bits (80 bins), so source denominators
change. No exclusions.

**Rejected fit:** slow85 127.53 MHz, slow0/worst 121.30 MHz; 2,397 ALMs,
2,074 registers, 5 DSPs, 20 M10Ks, 37,216 RAM bits. Worst setup/hold/pulse
at 5 ns: -3.244/+0.131/-0.555 ns. The detailed path runs from multiplier
prod_s1[20] through Add1 and then Add2 to t1_q[34]. Quartus implemented the
upper carry-one expression `u+v+1` as serial addition and increment, defeating
the intended parallel path. This is a measured mapping regression despite
correct outputs; it is not selected.

Exact RTL and complete evidence are preserved in
`experiments/ntt_stage4/lighthd_fold_select_trial/`. A follow-up uses the
identity `~(~u+~v) = u+v+1 mod 2^18`, expressing that candidate with one binary
adder; it requires a fresh full fit before any timing claim. The selected
145.73 MHz checkpoint remains preserved. Stage 4 stays open.

### Corrected carry candidate and pipeline feasibility (2026-10-10)

The follow-up expressed the carry-one upper sum as `~(~u+~v)` instead of
`u+v+1`. This identity is exact modulo 2^18, but an equivalent expression
alone does not guarantee a better fitted structure. The result also regresses:

| Same-device metric | Selected keep-bias | First carry-select trial | Rewritten carry candidate |
|---|---:|---:|---:|
| Worst Fmax (MHz) | 145.73 | 121.30 | 120.11 |
| Slow85 Fmax (MHz) | 145.73 | 127.53 | 126.47 |
| ALMs / registers | 2,568 / 2,117 | 2,397 / 2,074 | 2,466 / 2,112 |
| DSP / M10K | 5 / 21 | 5 / 20 | 5 / 20 |
| RAM bits | 37,252 | 37,216 | 37,216 |
| Worst setup at 5 ns (ns) | -1.862 | -3.244 | -3.326 |
| Worst all-corner hold (ns) | +0.104 | +0.131 | +0.075 |
| Worst pulse width at 5 ns (ns) | -0.555 | -0.555 | -0.555 |

Both trials pass main UVM 118/118, zero errors/fatals, all fourteen checked
functional covergroup types at 100%, and Python 18/18 cases with 4,608/4,608
coefficients matching. All four multipliers hit 44/44 statements and 12/12
branches. Each multiplier's 194 missed toggle bins are constant bits, as
listed in the archived report; no exclusions. The rewritten trial's worst
path remains fold1, lane3 prod_s1[24] -> t1_q[28]. No timing improvement is
claimed. The original golden mathematics and operation cycles are unchanged.

Exact rejected RTL and complete source/fit evidence are preserved in
`lighthd_fold_select_trial/` and `lighthd_fold_parallel_trial/` under
`experiments/ntt_stage4/`. The selected keep-bias source is restored
byte-for-byte. Fresh `uvm_fold_trials_restore.log` passes 118/118;
`vector_fold_trials_restore.log` / `compare_fold_trials_restore.log` passes
18/18 cases and all 4,608 coefficients. Fresh `fold_trials_restore_{map,fit,sta,paths}.log` reproduces **145.73 MHz**
worst Fmax (slow0 146.01 MHz), **2,568 ALMs**, 2,117 registers, **5 DSPs /
21 M10Ks**, and 37,252 RAM bits. Worst setup/hold/pulse at 5 ns is again
**-1.862/+0.104/-0.555 ns**. `quartus/ntt_LightHD/results/` and the active
implementation database match the restored source. The 200 MHz target is
still unmet; no performance improvement is claimed for these rejected trials.

**Next concrete trial:** evaluate an additional first-fold pipeline stage.
Before changing RTL, run the existing independent index scheduler at proposed
PIPE=10: all forward/inverse stage pairs and final output order pass, with
FIFO peaks 32/32/11; Pre regrouping and remaining stages pass with peaks
32/32/16. Evidence: `experiments/ntt_stage4/pipeline10_schedule_feasibility.log`.
This is a planning check of ordering/capacity only, not RTL, arithmetic,
latency or timing verification. No FIFO enlargement is indicated by that model.
A real trial must align multiplier/BF/tag delays, reset/drain behavior and UVM
trace checks, then measure its cycles and repeat main UVM/Python/full Quartus.
Current active pipeline remains 4/6/9 and current measured cycles are unchanged.
Stage 4 remains open. No Stage 5/netlist/FPGA result or commit.

### Latest selected first-fold pipeline checkpoint (2026-10-10)

Start from the saved smaller direct-route/narrow-Pre-key alternative, using its
original single carry chain, not either rejected carry-select expression.
In `mod_mul.sv`, register the two 36-bit carry-save first-fold words before
propagating their carry in the next stage. Their sum modulo 2^36 equals the
exact nonnegative fold because the bound is below 2^36. Fold2 and final
canonical correction are unchanged. Still accepts one pair each clock.

Multiplier/BF/return latency changes from 4/6/9 to **5/7/10**. Align the kept
operand/mode delay and core tags. The main UVM's independent delayed-tag and
FIFO-content models now require ten clocks; expected timing is not derived
from the observed DUT tag. Golden arithmetic and reference files are unchanged.

| Same-device measured metric | Prior selected keep-bias | New selected pipeline |
|---|---:|---:|
| Worst Fmax (MHz) | 145.73 | **148.46** |
| Slow85 / slow0 Fmax (MHz) | 145.73 / 146.01 | **148.46 / 150.20** |
| ALMs | 2,568 | **2,490** |
| Registers | 2,117 | **2,396** |
| DSP / M10K | 5 / 21 | **5 / 21** |
| RAM bits | 37,252 | **37,348** |
| Worst setup at 5 ns (ns) | -1.862 | **-1.736** |
| Worst all-corner hold (ns) | +0.104 | **+0.133** |
| Worst pulse width at 5 ns (ns) | -0.555 | **-0.555** |
| Core NTT/INTT/PWM/Pre cycles | 266/266/74/235 | **267/267/75/236** |
| No-stall wrapper cycles | 780/780/844/749 | **781/781/845/750** |

Worst setup improves 0.126 ns; worst Fmax improves 1.87%. Area falls 78 ALMs
(3.04%), but registers increase 279 and RAM bits increase 96. Coefficient FIFO
capacities and M10K block count stay unchanged. Same Cyclone V device, Quartus
25.1std Lite, standard fit and 5 ns constraint; no clock relaxation.
This is an improvement, not 200 MHz timing closure.

Fresh `uvm_fold_pipeline.log` (also `uvm_stage4.log`) passes **118/118**,
zero errors/fatals, with all fourteen checked covergroup types at 100%.
Registered operands, physical writes, all output coefficients, nine reset/
recovery points and pipeline draining remain checked. Separate fresh
coverage-credit, operand-corruption, writeback-corruption and missing-GS-witness
tests all reject faults without new credit; failed UCDBs stay separate.
The earlier unchanged Pre eligibility evidence remains saved, not freshly rerun.

`vector_fold_pipeline.log` / `compare_fold_pipeline.log` passes **18/18 cases,
4,608/4,608 coefficients** and measures the new cycle boundaries above.
At fitted worst Fmax, NTT wrapper/core estimates are 781/148.46=5.26 us and
267/148.46=1.80 us. Latency-based rate is 148.46e6/781=190,090 polynomials/s,
1.74% above the prior selected model after including the added clock. Excludes
restart gaps, stalls and SHAKE/sampler time; not measured sustained Dilithium
throughput.

Raw core coverage is 295/307 statements, 232/245 branches, 53/84 conditions,
51/52 expressions, 5/5 states, 9/9 transitions and 3,405/3,683 toggles.
Each multiplier hits 45/45 statements, 12/12 branches, 1,228/1,418 toggles;
its 190 misses are both directions of 95 constant bits. Each BF remains
55/55 statements, 17/17 branches and 704/704 toggles. Source/denominators
change; no exclusions or blanket code-coverage closure claim.

The index scheduler now enumerates current PIPE=10 as well as saved 8/9
schedules. Its forward/inverse FIFO peaks stay 32/32/11, Pre peaks 32/32/16;
all stage pairs and final order pass. Its scheduled-cycle boundary differs
from RTL start-to-done; use vector logs for measured operation latency.

Fresh review reports in `quartus/ntt_LightHD/results/` come from
`fold_pipeline_{map,fit,sta,paths}.log`. Exact six RTL files, changed UVM
observers, prior UVM versions for rollback and full evidence are saved in
`experiments/ntt_stage4/lighthd_fold_pipeline_checkpoint/`. Prior selected
145.73 MHz checkpoint and every smaller/rejected alternative remain preserved.

**Next measured Stage 4 target:** both slow corners now run return `tag[9].pwm`
-> FIFO2 write-data selection. Other reported paths include op_r -> FIFO3
write-enable and GS operand selection -> DSP product. Optimize the measured
return write-data/control path while preserving the checked FIFO schedule.
Setup/pulse timing at 200 MHz remains open. Stage 5 requires user acceptance;
no netlist/FPGA claim. Nothing staged or committed.

## Stage 5 — Implementation verification after result review

After the user reviews and accepts the Stage 4 result, run focused **post-synthesis and post-fit functional** simulations against the same external checker and case IDs. Review synthesis warnings, resource mapping, and TimeQuest setup/hold reports. Do not call a functional post-fit simulation an SDF timing simulation where Cyclone V SDF is unavailable. Record exact pass counts and any limitations in the specification/coverage/throughput reports. FPGA/UART tests remain a separate physical-validation gate.

## Stage 6 — Sampler and complete data-path integration

Build and verify the rejection sampler after NTT closure, then connect `keccak_v2` → sampler/unpacker → buffering/reordering → NTT/PWM/INTT. Validate matrix-A coefficients sampled directly in NTT representation, bounded secrets, masking vector, and challenge paths according to FIPS 204. Measure SHAKE stalls, sampler acceptance, NTT loading/compute/output, and the resulting KeyGen/Sign/Verify schedule. Add rounding, decomposition, hints, packing, and the ML-DSA controller before claiming complete Dilithium performance or running complete FIPS 204 known-answer tests.

## Primary references

- NIST FIPS 204: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf
- NIST ACVP ML-DSA vector format: https://pages.nist.gov/ACVP/draft-celi-acvp-ml-dsa.html
- LightHD: https://doi.org/10.1109/TC.2026.3666457
- Starting branch report: `2_ntt:docs/ntt_docs/ntt-design-and-verification.md`
- Active Keccak interface and evidence: `keccak_v2:src/keccak_engine/keccak_dual_interleaved.sv` and `keccak_v2:docs/keccak_docs/post_midyear/`
