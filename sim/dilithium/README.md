# Dilithium simulation

Stage5N.3 uses the same single prepare/launcher/Python flow. Prepare from the
repository root,then use the Questa GUI Transcript from sim/:

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
set DILITHIUM_STAGE 5
set DILITHIUM_TEST sign_service
do dilithium/run.do
# Select sign_dma for the deeper real-memory fault/reset test.
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit sign_service
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit sign_service
# After capturing sign_dma,compare/selftest with --unit sign_dma.
```

Require capture,comparison and checker PASS separately. sign_dma:71 commands,
65 completions,21 expected errors,6 resets,14284 exact scalar writes,3570 ACKs,
32 rejected corruptions. sign_service:33 commands,30 completions,9 expected
errors,3 resets,192 source words and768 exact result words,33 corruptions
rejected. GUI wave setup is included for both selectors. No extra .do or
Python launcher is added. Main Sign control remains pending. Older status
paragraphs below record their historical stage boundaries.

Stage5N.2 signing arithmetic uses the same prepare command,then select
DILITHIUM_STAGE=5 and DILITHIUM_TEST=sign_process in Questa. After capture:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit sign_process
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit sign_process
```

Require DILITHIUM_STAGE5N2_SIGN_PROCESS_CAPTURE_PASS,the complete comparison
and27/27 checker PASS. Inputs,golden and captured output use the
stage5_sign_process_ prefix. Reference verification and concrete boundary
witnesses are documented in the universal Dilithium docs. This is a standalone
process gate;main Sign and shared-bank process DMA remain later work.

Stage5N.1 uses the same selectors after moving the engine/Bitpkg instances
under dilithium.services. prepare hashes the new package and service wrapper.
The full-key bench checks ownership,including cleanup after main done;its
Q record contains owned,cleanup-owner and idle cycle counts. The local checker
now rejects37 corruptions;the official-vector checker tests41,including
missing ownership evidence and a zero cleanup-owner count. Require fresh
capture/compare/selftest verdicts after prepare. Historical counts below
describe their original checkpoints;current results are in the universal
REFERENCE_VERIFICATION.md.

Official KeyGen selector:use the same prepare command and launcher with
DILITHIUM_STAGE=5,DILITHIUM_TEST=nist_keygen. It runs all75 published NIST
cases through tb_full_keygen(NIST_VECTORS=1),without altering RTL.
Then run:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit nist_keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit nist_keygen
```

Require stage5_nist_keygen_CAPTURE_PASS plus the separate NIST comparison
and checker PASS. Corpus/provenance,exact GUI commands and results are in
docs/dilithium_docs/REFERENCE_VERIFICATION.md. Expected keys come directly
from the pinned NIST JSON files,not from the C/Python implementation.
Stage5M result:75/75 keypairs,433600 exact key bytes and39 checker faults PASS.
The local full_keygen suite also freshly passes8 complete,3 rejects,5 resets
and35 checker faults. Other earlier selectors retain their historical Stage5L
evidence;rerun them after prepare if a current-token capture is wanted.

Latest complete KeyGen selector:prepare the single Python script,then:

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST full_keygen
do dilithium/run.do
```

```powershell
# Repository root,after simulation
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit full_keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit full_keygen
```

Require stage5_full_keygen_CAPTURE_PASS,the independent whole-key
comparison and35/35 checker-fault PASS. The bench drives only start/output/
done/reset controls. Inputs:stage5_full_keygen_inputs.txt;C expected keys:
stage5_full_keygen_expected.txt;capture:stage5_full_keygen_outputs.txt.
Eight complete keypairs at all3 levels match unchanged software KeyGen.
These are deterministic local-reference vectors,not official NIST KATs.
See universal REFERENCE_VERIFICATION.md for exact workload and scope.

Latest selectors:rounded_keygen enables ROUND_OUTPUTS=1 and checks retained
t1/t0 arrays;bitpkg checks polynomial field encoding against Python/C.
Use the existing prepare command,then select one in the Questa Transcript:

```tcl
set DILITHIUM_STAGE 5
set DILITHIUM_TEST rounded_keygen
do dilithium/run.do
# For the packet block,use DILITHIUM_TEST bitpkg instead.
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit rounded_keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit rounded_keygen
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bitpkg
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bitpkg
```

Run each corresponding simulation before its compare/selftest.
Rounded KeyGen:190224 scalar values,12800 exact92-bit reads,36 checker faults.
Bitpkg:97 commands,2482 exact output words,15 checker faults.
prepare builds the independent C packers(66 valid fixtures/18496 bytes).
The above block-only selectors are preserved diagnostic gates;full_keygen
implements complete encoded keys and the public-key hash.

Latest autonomous polynomial phase:prepare with the existing Python script,
then set DILITHIUM_STAGE5 and DILITHIUM_TEST keygen in Questa:

```tcl
set DILITHIUM_STAGE 5
set DILITHIUM_TEST keygen
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit keygen
```

Inputs:stage5_keygen_inputs.txt(operation/level/ID/xi/reset phase only).
Captures/verdicts:stage5_keygen_outputs.txt,stage5_keygen_compare.log,
stage5_keygen_checker_selftest.log.7 complete polynomial-phase operations,
3 rejects,4 resets,34 t=A*s1+s2 rows;29 corrupted captures rejected.
The bench drives no sample/NTT/process/row descriptors in this selector.
This still precedes rounding/encoded-key outputs. The previous selectors
below remain regression baselines after controller/helper relocation.

Stage5I is the latest seed-driven row connection. From the repository root:

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

In the Questa GUI Transcript,with working directory sim/:

```tcl
set DILITHIUM_STAGE 5
set DILITHIUM_TEST seed_row
do dilithium/run.do
```

Then from the repository root:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit seed_row
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit seed_row
```

Require DILITHIUM_STAGE5I_SEED_ROW_CAPTURE_PASS,the Python seed/row comparison,
ROW_SCHOOLBOOK_PASS,C_ROW_ADD_PASS and the23/23 checker-fault verdict.
20 actual RTL seed expansions produce2560 exact bytes;163 RTL-formatted
sampling jobs feed13 successful row outputs,27 row rejections and7 reset cases.
Input stage5_seed_inputs.txt contains xi only;RTL constructs all absorption
messages. Outputs/verdicts:stage5_seed_row_outputs.txt,stage5_seed_row_compare.log,
stage5_seed_row_checker_selftest.log. GUI adds seed,raw service and formatter
waves alongside row/NTT/process waves. Scope:REFERENCE_VERIFICATION.md in the
universal docs. Full KeyGen scheduling,s2/rounding/key encoding remain next.
Selector row below preserves the fixture-driven Stage5H baseline.

Stage5H runs the latest staged-row scheduler:

```powershell
# Repository root,first
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST row
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit row
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit row
```

Require DILITHIUM_STAGE5H_ROW_CAPTURE_PASS and the separate Python whole-row,
schoolbook and C ADD PASS markers.13 completed rows,27 expected rejections,
7 reset aborts;163 sample jobs,161 NTT commands,55 destructive ADDs and12544
exact92-bit public reads;26 checker corruptions rejected. Inputs:
stage5_row_samples.txt/stage5_row_expected.txt. Capture/verdicts:
stage5_row_outputs.txt,stage5_row_compare.log,stage5_row_checker_selftest.log.
GUI waves include row state,column,leases,child commands and accumulator data.
Full scope/limits:docs/dilithium_docs/REFERENCE_VERIFICATION.md. This returns
u=A*s1,not an encoded key;full KeyGen/synthesis/UVM/PPA remain later work.

Stage5G runs the latest banked process/NTT connection:

```powershell
# Repository root,first
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST bank_process
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bank_process
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bank_process
```

Require DILITHIUM_STAGE5G_CAPTURE_PASS,Python COMPARE PASS and C_BANK_PROCESS_PASS.
23 samples,15 NTT commands,71 process commands;34 successes,33 expected rejections,
4 reset aborts;8512 exact92-bit reads;29 checker corruptions rejected. Prepared
schedule:stage5_process_banks_inputs.txt;capture:stage5_process_banks_outputs.txt;
verdicts:stage5_process_banks_compare.log,stage5_process_banks_c_reference.log,
stage5_process_banks_checker_selftest.log. GUI waves include process leases,
word caches,arithmetic low/high outputs and physical packed write acknowledgements.
Full scope:docs/dilithium_docs/REFERENCE_VERIFICATION.md. Default selector4 and
Quartus top preserve the old scalar baseline;no full-KeyGen/PPA result implied.

Stage5F runs the new complete banked connection:

```powershell
# Repository root,first
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST bank_ntt
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bank_ntt
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bank_ntt
```

Require DILITHIUM_STAGE5F_CAPTURE_PASS and the separate Python COMPARE PASS.
16 real sample jobs,54 commands,30 results,21 expected rejections,3 reset aborts,
2944 exact92-bit reads and19 rejected checker corruptions. Capture/verdict names:
stage5_ntt_banks_outputs.txt,stage5_ntt_banks_compare.log and
stage5_ntt_banks_checker_selftest.log. GUI waves include leases,word/lane DMA,
engine streams and packed write acknowledgements. Full scope/results are in
docs/dilithium_docs/REFERENCE_VERIFICATION.md. Default stage4 remains the old
scalar regression;no synthesis or full-operation result is implied by this test.

Stage5E connects the real producer to the new banks:

```tcl
# Questa Transcript,from sim/;prepare vectors from repository root first
set DILITHIUM_STAGE 5
set DILITHIUM_TEST bank_store
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bank_store
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bank_store
```

Require DILITHIUM_STAGE5_STORE_PASS,BANK_STORE_PROTOCOL_PASS and Python COMPARE
PASS.104 jobs,88 completed polynomials,5632 exact92-bit words(22528 coefficients),
8 expected errors/8 reset aborts;8 protocol faults contained/12 capture corruptions
rejected. All64 regions fill/protect/reuse. Source:tb/tb_dilithium;capture:
stage5_store_outputs.txt. Stage5F above adds banked NTT DMA/writeback;default
stage4 remains the prior scalar path. No complete KeyGen or PPA claim.

Stage5C shared raw-SHAKE/seed test uses the same launcher and Python script:

```tcl
# Questa Transcript,from sim/;run Python prepare from repository root first
set DILITHIUM_STAGE 5
set DILITHIUM_TEST shared_hash
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit shared_hash
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit shared_hash
```

26 commands,1699 exact SHAKE bytes and1792 exact sampled coefficients PASS.
The sampled seeds come from the real RTL collector. Includes1 parameter error,
3 resets,raw/raw and raw/sampling ownership,stalls and12 checker corruptions.
Capture:stage5_shared_outputs.txt. Main connected top remains Stage4;no complete
KeyGen or synthesis claim. Shared docs give the protocol and result arithmetic.

Current `run.do` exercises Stage4's real Keccak→sampler→memory→NTT path using a focused
non-UVM testbench under `tb/tb_dilithium/`. Main Dilithium UVM and implementation
launchers will replace/extend this evolving project at their actual stages.

Stage5A also adds an isolated process gate:in Questa use
`set DILITHIUM_STAGE 5` and `set DILITHIUM_TEST process` before this launcher;then Python compare/selftest
with `--stage 5`. It checks ADD/SUB/Power2Round:10349 accepted,10346 exact outputs,
3 reset aborts,13 expected errors. It does not run full KeyGen. Preparation
now needs GCC for the unchanged C rounding reference;it is available as
C:/MinGW/bin/gcc.exe in this workspace. Return to selector4 for the connected test.

Stage5B tests final FIPS204 seed/nonce formatting using level2/3/5 labels for
ML-DSA-44/65/87. Prepare as below,then in the Questa Transcript (from sim/):

```tcl
set DILITHIUM_STAGE 5
set DILITHIUM_TEST hash_format
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit hash_format
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit hash_format
```

165 commands/162 message completions/14 expected errors/3 reset aborts PASS;
883 absorption words and5888 SHAKE bytes match. Captures:stage5_hash_outputs.txt;
inputs:stage5_hash_inputs.txt. This gate uses one existing Keccak instance in
a focused harness;the formatter is not connected to the main top yet. Sampling
messages are hashed for32 bytes here,not sampled into polynomials. Full commands,
file formats and limits:docs/dilithium_docs/REFERENCE_VERIFICATION.md.

Repository-root terminal:

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

Questa GUI Transcript,working directory `sim/`:

```tcl
do dilithium/run.do
```

Repository-root terminal after capture:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 4
python sim/dilithium/dilithium_vectors.py selftest --stage 4
```

16 sampling jobs and50 compute commands:30 completed,17 rejected,3 reset-aborted.
Require `DILITHIUM_STAGE4_CAPTURE_PASS` and independent
`DILITHIUM STAGE4 COMPARE PASS`;4096 sampled values,9745 DMA operands,7713 NTT
outputs and11776 stored readbacks match. All12 checker corruptions are rejected.
GUI waves include commands,DMA progress,NTT streams and memory lifecycle.
No complete Dilithium UVM/coverage/PPA claim.

To rerun the preserved Stage2 test in Questa:

```tcl
set DILITHIUM_STAGE 2
do dilithium/run.do
```

Then use Python compare/selftest with `--stage 2`. Set `DILITHIUM_STAGE 3`
for the preserved sampling-memory test (104 jobs/22528 readbacks),and use
`--stage 3` for its Python verdict. Set `DILITHIUM_STAGE 4` to return to the
current all-engine test. All stages use the same sampling input/expected files
and the same Python script. Stage4 adds stage4_expected.txt with26 independently
calculated arithmetic expectations. Stage-specific captures are named
stage2_outputs.txt,stage3_outputs.txt andstage4_outputs.txt. Python defaults to4.

Golden vectors bind to the source/test/launcher/reference hash;rerun prepare and
capture after changing them. Current workload cycle witnesses are in
stage2_jobs.csv. Universal docs:docs/dilithium_docs/REFERENCE_VERIFICATION.md,
ARCHITECTURE.md and THROUGHPUT.md. Standalone module projects remain separate.
