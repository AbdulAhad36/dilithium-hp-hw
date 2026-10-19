# Sampler vectors: prepare, capture, compare

Accepted implementation: Stage4.9r.

## 1. The simple flow

```text
Python prepare
  |-- sampler_inputs.txt   -> UVM driver -> actual sampler RTL
  |-- sampler_expected.txt                       |
  |                                      UVM monitor
  |                                             |
  |                               sampler_dut_outputs.txt
  |                                             |
  +----------- Python compare <------------------+
```

1. Python chooses deterministic seeds or explicit bytes, calculates expected
   coefficients, and writes the input and expected files.
2. Questa runs only sampler_vector_test in the existing main UVM environment.
   The driver sends file inputs to the real RTL. The monitor captures actual
   accepted outputs. The capture component writes those observations to a file.
3. You run Python compare yourself. It checks each observed coefficient against
   the corresponding expected coefficient and prints PASS or the first mismatch.

The existing independent SV scoreboard remains enabled. The capture component
**never reads sampler_expected.txt** and never substitutes expected values for
observations. The main regression remains a separate default test selection.

## 2. Run it yourself

### Stage 5: post-synthesis and post-fit

First compile `quartus/sampler/sampler.qpf` in Quartus GUI using **Processing >
Start Compilation**. Keep the existing QSF/SDC settings. From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File quartus/sampler/generate_netlists.ps1
python FIPS204_SAMPLER/sampler_vectors.py prepare
```

The export script checks accepted RTL/settings, creates a separate synthesis-only
helper, exports the fitted database, and records distinct netlist SHA256 hashes in
`quartus/sampler/netlist_provenance.json`. Export completion is not a simulation PASS.
The process-local execution-policy option does not change the machine policy.

In a fresh Questa GUI session, working directory `sim/`, run one at a time:

```tcl
do sampler/run_post_synthesis.do
# Finish that run before launching the other:
do sampler/run_post_fit.do
```

Then compare each capture from the repository root:

```powershell
python FIPS204_SAMPLER/sampler_vectors.py compare --outputs sim/sampler/post_synthesis_outputs.txt
python FIPS204_SAMPLER/sampler_vectors.py compare --outputs sim/sampler/post_fit_outputs.txt
```

Each launcher uses the same main UVM, independent scalar scoreboard and vendor
libraries. Require the `SAMPLER NETLIST UVM PASS` marker and a separate Python
`SAMPLER COMPARE PASS`. The 104 file jobs are captured for Python; another 80
successful jobs remain checked by the SV scoreboard. Waves and functional
coverage appear in Questa. Source-only hierarchy probes are unsampled; no RTL
code coverage or SDF timing claim is made for these functional netlists.
Cyclone V warning 10905 is expected; TimeQuest supplies the timing evidence.

Do not rerun `prepare` between capture and comparison: it creates a fresh run ID.
Results and frozen evidence for this accepted-build run are recorded in
`SAMPLER_NETLIST_RESULTS.json` after all checks passed.

### A. Prepare - terminal at the repository root

```powershell
python FIPS204_SAMPLER/sampler_vectors.py prepare
```

Prepare also builds and invokes the existing C reference automatically. This
machine uses C:/MinGW/bin/gcc.exe; if GCC is not on PATH:

```powershell
python FIPS204_SAMPLER/sampler_vectors.py prepare --cc C:/MinGW/bin/gcc.exe
```

One Python script handles preparation, comparison and checker self-tests.
Prepare requires GCC and Python; compare needs only Python's standard library.

### B. Generate RTL outputs - Questa GUI Transcript

```tcl
cd D:/GitHub/dilithium-hp-hw/sim
set SAMPLER_MODE vectors
do sampler/run_uvm.do
```

Wait for `SAMPLER VECTOR CAPTURE COMPLETE`. This means capture and the SV checks
finished; run the Python comparison next. Waves/coverage remain available in the
GUI. No separate vector .do or non-UVM bench is used.

Batch equivalent, terminal with sim/ as working directory:

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l sampler/vector.log -do 'set SAMPLER_MODE vectors; do sampler/run_uvm.do; quit -f'
```

### C. Compare - terminal at the repository root

```powershell
python FIPS204_SAMPLER/sampler_vectors.py compare
```

Optional checker self-test after a valid capture:

```powershell
python FIPS204_SAMPLER/sampler_vectors.py selftest
```

For the original regression, from sim/ in Questa Transcript:

```tcl
do sampler/run_uvm.do
```

The script clears SAMPLER_MODE after a normal run; select vectors explicitly
for each capture. Run sessions sequentially because modelsim.ini is shared.
The 10 ns simulation clock is not a fitted FPGA frequency claim.

## 3. Files and how they are made

| File | Producer / use |
|---|---|
| FIPS204_SAMPLER/sampler_vectors.py | Single hand-written independent Python model and prepare/compare/selftest commands |
| FIPS204_SAMPLER/sampler_inputs.txt | prepare: job commands, actual SHAKE bytes, packet sizes, interleaving/waits/resets |
| FIPS204_SAMPLER/sampler_expected.txt | prepare: independently calculated coefficients and expected completion/error/reset records |
| FIPS204_SAMPLER/provenance.json | prepare: seeds/nonces, labels, sources, C revision, hashes, manifest ID and exact counts |
| tb_uvm/tb_uvm_sampler/reference_check.c | Thin C wrapper calling the unchanged existing software sampling functions |
| sim/sampler/reference_build/ | prepare: three ignored C executables for DILITHIUM_MODE=2/3/5 |
| tb_uvm/tb_uvm_sampler/sampler_vector_classes.svh | File-driven UVM sequence, observation-only capture subscriber and vector test |
| sim/sampler/sampler_dut_outputs.txt | UVM monitor/capture: actual accepted RTL output coefficients/status/reset observations |
| sim/sampler/vector.log or vector_gui.log | Questa batch/GUI capture transcripts |
| sim/sampler/vector.ucdb, vector.wlf, vector_code.rpt, vector_coverage.rpt | Separate vector-run coverage and wave artifacts |
| sim/sampler/compare.log, checker_selftest.log | Python equality / deliberate-corruption self-test results |
| docs/sampler_docs/post_midyear/STAGE4_9R_RESULTS.json | Tested source/evidence hashes and current result totals |

The fast capture executes the vector set only, not the 47-polynomial smoke
regression. Its simulation ends at 406 us in this run. This is simulated elapsed
time under the current stalls/schedule, not an isolated sampler cycle benchmark.
Coverage collection uses separate files; vector and regression databases are not
merged or represented as one result. RTL was unchanged in Stage 2.

## 4. Where expected values come from

Sources reviewed on 2026-10-16:

- [Final FIPS 204](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf),
  Algorithms 29-34 and coefficient/bit conversion definitions.
- [NIST ACVP ML-DSA schema](https://pages.nist.gov/ACVP/draft-celi-acvp-ml-dsa.html):
  full KeyGen/SigGen/SigVer testing. No standalone sampler input/coefficient suite
  was identified in the reviewed schema/sample material.
- [NIST ACVP sample repository](https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files).

This search result does not mean sampling is unstandardized. Full keys/signatures
are not standalone sampler coefficients, so they were not relabeled as such.

Python sample() implements these mathematical operations independently:

| Mode | Python calculation |
|---|---|
| A | Read three little-endian bytes, clear bit 23, accept only values below q |
| Secret | Read low/high nibbles; eta=2 accepts t<15 then uses 2-(t mod 5); eta=4 accepts t<9 then uses 4-t |
| Mask | Read continuous 18/20-bit fields and calculate gamma1-t; no rejection |
| Challenge | Read eight sign bytes, reject j>i, perform c[i]=old c[j], c[j]=sign until tau updates finish |

Negative results become canonical residues modulo q=8,380,417. For realistic
seed cases Python hashlib supplies SHAKE128 for A and SHAKE256 for other modes.
Explicit-byte cases deliberately exercise rare rejection/boundary behavior.

### C-reference compatibility and limits

The inherited C reference is pinned at the file-history commit
47a187eb1d08cc1c6fbbb825ad06b2b64c97fd75, with exact source/header hashes in
provenance.json. Builds explicitly set DILITHIUM_MODE=2,3,5, matching RTL
parameter encodings 0,1,2. The following sampling details were checked against
final FIPS 204 and exercised through actual Python/C polynomial equality:

| Detail | Checked convention |
|---|---|
| Parameters | eta=2/4/2, gamma1=2^17/2^19/2^19, tau=39/49/60 |
| A input | 32-byte seed plus nonce low byte=column, high byte=row |
| Secret input | 64-byte seed plus two-byte little-endian polynomial nonce |
| Mask input | 64-byte seed plus two-byte little-endian polynomial nonce; consume SHAKE from its beginning |
| Challenge input | Full 32/48/64-byte seed, not a fixed 32-byte truncation |
| Outputs | Compare all 256 canonical coefficients; signed C outputs converted modulo q |

reference_check.c calls poly_uniform, poly_uniform_eta, poly_uniform_gamma1 or
poly_challenge. It does not reimplement their formulas. Its dependencies link
existing NTT/reduction code, but no NTT operation is run or imported into RTL.
Python/C equality covers 48 seed cases / 12,288 coefficients. It establishes
compatibility for these sampling functions, not complete ML-DSA conformance.
Host-generated SHAKE bytes do not test the actual Keccak RTL or full seed/nonce
controller integration; those remain a later stage.

## 5. The text format and simple comparison

Input records:

```text
H manifest_id jobs successful errors aborted
J core job_id mode parameter
B core valid_bytes last hex_word_128
W
R
E
```

J starts a descriptor; B sends a beat; W waits for both slots to finish; R resets;
E ends the file. B's earliest byte is in bits 7:0, the rightmost hex byte.
Invalid byte counts 0/17 are intentional negative cases. Normal counts are 1..16.
A last flag ends a finite byte source, not a SHAKE rate block.

Expected and observed files use the same records:

```text
H manifest_id
J core job_id mode parameter
C core job_id index value last
S core job_id status coefficients accepted_bytes
A core job_id coefficients accepted_bytes
F jobs successful errors aborted coefficients
```

For example, `C 0 1000 0 1314665 0` says job1000/core0 produced coefficient0
with value1314665 and it is not the last coefficient. `S` records a status;
`A` records a reset-aborted descriptor. accepted_bytes counts accepted input
beats with legal valid-byte counts, not internal extractor cycles/bytes.

The comparison validates each job's lifecycle and index order, then matches
records by core/job/index. It permits different interleaving between independent
jobs. It requires exact descriptor metadata, values, last flags, lengths, status,
accepted-byte counts and final totals. Missing/extra/duplicate/malformed/unknown
records fail. A mismatch prints its job/index and expected/observed values and
returns exit code 1. Successful comparison returns 0.

Each prepare creates a fresh manifest ID and hashes input/expected/reference
files plus the sampler RTL and UVM/launcher sources. After source edits, run
prepare and capture again; comparison rejects sources changed since preparation. Capture copies that ID and writes a final footer only after a clean run.
The launcher removes the previous capture before compiling; a failed rerun
cannot silently reuse it. Changed references/files, stale IDs and truncated
captures fail comparison. compare does not launch simulation or synthesis.

## 6. Accepted-build results

Python comparison:104/104 jobs,19456/19456 values PASS. Independent C reference:
48 cases/12288 coefficients PASS. Self-test rejects12 deliberate corruptions.
The models remain independent of DUT functions. Evidence:STAGE4_9R_RESULTS.json
and evidence/stage4_9r.zip. These are generated FIPS-derived vectors, not
downloaded standalone NIST sampler vectors or NIST certification.

## 7. What to study

1. Read one J/B input packet and the corresponding C/S output records.
2. Study Python sample() for the four mathematical mappings.
3. Read sampler_vector_seq: file packets become normal driver transactions.
4. Follow the existing driver -> sampler RTL -> monitor.
5. Read sampler_capture.write(): accepted observations become output-file rows.
6. Read parse_records() and check_equal(): validate order, then compare records.
7. Study the independent SV scoreboard and checked_ap coverage separately.

Stage 3 and subsequent corrective measurements/fit are recorded in
THROUGHPUT.md and the stage-specific result manifests. The original Stage2 code
counts above are historical; current RTL changes require fresh prepare/capture/
compare, and current raw code totals are in THROUGHPUT.md. These vectors alone make no
area/Fmax, netlist, board or real subsystem-integration claim. Nothing was committed.

## Stage 5 accepted-build verification ? 2026-10-19

The accepted RTL and Quartus constraints were not changed. Synthesis used a
separate helper with no fitted database; post-fit export used the retained
accepted fitted database. SHA256 hashes confirm the netlists are distinct.
Export provenance and frozen results are in SAMPLER_NETLIST_RESULTS.json;
self-contained evidence is evidence/sampler_stage5.zip with its SHA256 sidecar.

| Check | Post-synthesis | Post-fit |
|---|---:|---:|
| Total jobs |184|184|
| Complete polynomials |156|156|
| Expected errors / reset aborts |24 /4|24 /4|
| Independently checked coefficients |39936|39936|
| UVM errors / fatals |0 /0|0 /0|
| Python capture jobs / coefficient matches |104 /19456|104 /19456|
| Raw functional coverage |1255/1721 =72.92%|1255/1721 =72.92%|

Each includes104 file jobs plus80 additional successful SV-checked jobs.
The 104-job source/synthesis/fit captures are byte-identical and independently
match Python. Fresh source main regression also passes621 complete,182 expected
errors,51 reset aborts and159628 comparisons. Python/C48 cases/12288 values and
checker self-test12/12 pass. The retained96-case performance CSV is byte-identical
to the accepted archive; it was not rerun or claimed as a new measurement.

SAMPLER_NETLIST disables source-only occupancy/FSM/pipeline observations, not
external value/tag/index/last/status/stall/refusal/reset-recovery checks.
reset_recovery (internal phase snapshots),pipeline_activity,challenge_states and
completion_arbitration groups remain unsampled. External scheduling/error/
lifecycle and extended rejection/stall combinations also have unhit bins. These
are visible limitations, not waivers. No netlist/source coverage is merged;
RTL code remains15093/15799=95.53%,source functional1652/1721=95.99%.

Fresh TimeQuest/structural revalidation confirms the retained internal fit:
3537 placed ALMs,164.74MHz worst Fmax,+0.430ns setup,+0.141ns hold at6.500ns;
all four corners have zero setup/hold TNS and positive minimum pulse width.
Original payload/sign/ownership guards pass. Cyclone V warning10905 means the
post-fit netlist is functional-only; no SDF or timing-simulation claim.
Virtual-pin I/O,board/UART,integration and security signoff remain pending.

Next: Stage6 integration planning,requiring separate branch/import authorization.
No new commit or integration was performed as part of Stage5.
