# NTT v2 Post-Midyear Plan

**Status:** Stage 1 complete on 2026-10-05 for the inherited `2_ntt` source RTL: baseline checks and the separate FIPS-derived vector flow passed. Stage 2 performance measurement and RTL changes are next. Later stages remain proposed work.

This is the staged plan for the `ntt_v2` development branch. The starting RTL is the historical `2_ntt` branch. Its recorded checks and Quartus results are a baseline to rerun, not evidence for future modified RTL. The active Keccak counterpart is `keccak_v2`; its dual-core SHAKE design has one shared 64-bit input, one tagged 128-bit output, and a minimum 26-cycle offset between job launches. Keccak FPGA/UART validation and the rejection sampler remain pending.

## Recorded starting point and measurement rules

The `2_ntt` report records 208/208 reference self-checks, 33/33 core checks, 23/23 engine checks, and 53/53 UVM transactions. Its 100% functional-coverage number means that 19 existing covergroup bins were hit; RTL code/FSM/toggle coverage and a requirements-based coverage model were not established. The last recorded Cyclone V fit is 75.44 MHz, 2,313 ALMs, 6 DSPs, and 18 M10Ks. The recorded compute-only latencies are approximately 299 forward-NTT cycles, 372 inverse-NTT cycles, and 74 pointwise-multiply cycles. The old plan estimates about 1,067 no-stall cycles for one complete top-level forward-NTT transaction, including its one-coefficient-per-beat input and two-cycle-per-coefficient output interface. Rerun and label all of these measurements before using them as a new baseline.

For every comparison, state the DUT revision, FPGA/device, operation, input/output inclusion, clock frequency, constraints, and evidence path. A source test pass does not prove post-synthesis, post-fit, timing, or FPGA behavior. ALMs are not interchangeable with Xilinx LUTs, and Cyclone V NTT-only Fmax is not directly comparable to LightHD's Artix-7 full-accelerator 212.8 MHz. Report ALMs, registers, DSPs, M10Ks, setup slack, hold slack, Fmax, and operation throughput separately; use a documented conversion only if an equivalent-area estimate is needed.

## Stage 1 — Establish NTT functionality and an independent vector flow

1. Rerun the existing reference, core, engine, and UVM checks on unmodified `ntt_v2`. Export the actual pass counts, failures, current 19-bin coverage result, and operation latencies. Do not treat a simulator exit code or a coverage percentage alone as proof of correct outputs.
2. Check NIST's FIPS 204 and ACVP sources for public **standalone NTT/INTT/pointwise-multiply** vectors. The currently located public ML-DSA ACVP sets cover key generation, signature generation, and signature verification; no SHAKE-style standalone NTT `.rsp` set has been identified. Record the source and version of any official component vectors found. If none exist, generate NTT vectors from FIPS 204 conventions and an independently checked C/software reference, and label them **FIPS-derived reference vectors**, not “NIST NTT vectors.” Preserve source material and provenance under `FIPS204_NTT/` on `ntt_v2`. The repository's existing C reference and pure-SV model can be cross-checks, but neither should silently validate itself.
3. Mirror the simple Keccak file flow with **one Python script**, planned as `sim/ntt_vectors.py` with `prepare` and `compare` commands. `prepare` makes a single case input file and a separate expected-output file. A dedicated, fast `sim/run_ntt_vectors.do` runs only the NTT vector capture test and writes observed DUT outputs to a third file; it must not launch the full regression. `compare` matches case ID, operation, all 256 coefficients, and order, then prints exact mismatch locations and a clear PASS/FAIL total. Keep the existing SV golden model and its checks.
4. Include forward NTT, inverse NTT, pointwise multiplication, round trip, and two-input polynomial multiplication checked against schoolbook multiplication. Cover zero, one, `q-1`, sparse, boundary-position, and random polynomials. Resolve FIPS/reference choices for twiddle ordering, coefficient normalization, and inverse scaling before declaring a mismatch to be an RTL defect.
5. Create `docs/ntt_docs/post_midyear/FIPS204_NTT.md` **when the flow exists**. Explain the actual source of every vector, generated files, commands, comparison logic, case counts, and observed results. Add end-to-end official ML-DSA vectors later when the whole signer/verifier exists.

**Gate:** Every retained independent case matches exactly; the existing regression and existing coverage model are reported with observed numbers and known limitations. Fix functionality failures before optimizing performance.

**Stage 1 evidence:** The fresh baseline passed 208/208 reference, 33/33 core, 23/23 engine, and 53/53 UVM checks. The existing 19-bin input-sampled covergroup reported 100%; RTL code coverage was not compiled. The separate capture/compare flow passed 18/18 cases and 4,608/4,608 exact coefficients. Measured core start-to-done counts are 302 NTT, 377 INTT, and 77 PWM; complete no-stall external transactions are 1,071, 1,146, and 1,102 cycles, respectively. See [FIPS204_NTT.md](FIPS204_NTT.md) for files, commands, provenance, and limits. These results apply only to this source RTL.

## Stage 2 — Measure and improve the current architecture

1. Rerun Quartus synthesis, fitting, and TimeQuest on the frozen functional baseline. Record the true worst setup/hold paths and account for each DSP and M10K. Investigate the two DSPs inferred by address-generation multiplication; replace power-of-two multiplies with shifts or small decoded cases if the measured implementation improves.
2. Instrument the complete path: request/input transfer, SHAKE waiting, sampler output rate when a sampler exists, NTT loading, core computation, pipeline drains, result transfer, and backpressure. Until the sampler exists, measure the NTT portions with a representative producer model and label those results as estimates. Measure compute latency and complete transaction latency separately.
3. Improve the measured NTT bottleneck with one change at a time and rerun functional checks and Quartus after each RTL change. Candidates: register the measured modular-multiplier input path; reduce unnecessary inter-pass drains; merge inverse scaling into the final pass if correctness and timing allow; remove the two address DSPs; load several coefficients into the four banks per clock; reduce output-interface cycles; and overlap safe input/storage work with computation. Do not assume any proposed Fmax gain until a new fit proves it.
4. Make the NTT compatible with today's **dual-core** Keccak output, not the older four-lane assumption: a job descriptor must associate each tagged SHAKE byte stream with its sampler mode and destination polynomial; buffers must handle partial bytes, variable rejection acceptance, and backpressure. This is an interface design and measurement task here; actual sampler integration is Stage 6.
5. Study LightHD's four-butterfly FIFO schedule, DSP use, memory scheduling, and small-coefficient Pre-NTT. Add a Pre-NTT path only for eligible bounded secret polynomials, after its first-stage lookup and data-regrouping behavior is independently checked. General inputs must retain a correct full transform. Consider more butterfly/memory parallelism if cycle count is the binding limit and area is available.

**Performance challenge:** Aim for at least comparable **compute-only** cycles to LightHD's reported 264 forward NTT, 264 inverse NTT, and 70 pointwise multiplication, with 235 forward cycles as the relevant small-coefficient Pre-NTT reference. Seek equal or better complete-operation throughput under a documented workload, with positive worst-case setup and hold slack. The user-directed Fmax stretch target is 212.8 MHz, LightHD's reported Artix-7 **full-accelerator** clock; reaching that on our Cyclone V NTT is unproven and is not a valid cross-FPGA win by itself. Document any remaining gap and its cause rather than claiming an ALM/LUT equivalence or performance win from dissimilar measurements.

## Stage 3 — Architecture decision

Review the measured Stage 2 results against LightHD and against the project's complete-Dilithium throughput goal. If the current four-bank 2×2 tile is promising, retain and refine it. If measured cycle, interface, or timing limits cannot be improved enough, prototype either a LightHD-inspired FIFO engine or a more parallel alternative on the **same Cyclone V**. Compare correctness, forward/inverse/PWM cycles, complete transaction throughput, Fmax, setup/hold slack, ALMs, registers, DSPs, and M10Ks under the same constraints. Choose the architecture from those results; a full LightHD copy is an option to evaluate, not a predetermined outcome.

**Gate:** A documented architecture decision with actual results and a clear explanation of what is still unverified. Do not expand coverage around an architecture that is about to be discarded.

## Stage 4 — Detailed test plan, coverage, and iterative synthesis

Create `docs/ntt_docs/post_midyear/NTT_VERIFICATION_TESTPLAN.md` for the chosen architecture. Enumerate testable requirements and expected results for modular arithmetic, CT/GS butterflies, twiddle ROM, every stage/pass, bank conflicts, pipeline latency/drain, forward/inverse/PWM, inverse scaling, reset, repeated jobs, input gaps, output stalls, and future sampler handshakes. Define stimulus, independent oracle, assertions, scoreboard checks, and functional coverpoints/crosses for each requirement. Sample coverage from observed, **successfully checked** DUT transactions; distinguish hit bins from correct functionality. Enable DUT-only statement, branch, condition/expression, FSM, and toggle coverage, review holes, and document justified exclusions.

Run regression, coverage, synthesis, fitting, and TimeQuest during each meaningful design iteration. Pursue higher Fmax and positive setup/hold slack while preserving exact outputs and improving cycles/throughput. Track the trade-off in ALMs, registers, DSPs, and M10Ks rather than optimizing one number in isolation. Maintain `SPECIFICATION.md`, `THROUGHPUT.md`, `COVERAGE.md`, and `NTT_VIRTUAL_PIN_CONFIG.md` in this directory as soon as their measured interfaces and evidence are stable; update them after relevant changes. They are documentation deliverables, not substitutes for logs and checkers.

**Gate:** Requirements and coverage are reviewed, all priority checks pass, uncovered paths are explained, and fitted performance meets the agreed target or has an explicit accepted trade-off.

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
