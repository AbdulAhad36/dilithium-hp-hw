# Dilithium reference verification

## Stage5N.3 shared signing-process memory verification

This is local component verification,not a published standalone NIST signing
corpus. The existing single script uses independent division/wrap decomposition,
centered norm comparison and HighBits-change hint calculation. RTL is not
imported as a model. Existing scalar C crosschecks remain in prepare.

```powershell
# Repository root,before current-source capture
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa GUI Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST sign_service
do dilithium/run.do
# For the deeper DMA/error/reset gate,use sign_dma instead.
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit sign_service
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit sign_service
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit sign_dma
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit sign_dma
```

Run each selector in Questa before comparing its capture. The same launcher
provides waves for DMA ownership,word/lane progress,allocations/finish and ACKs.
Require explicit capture PASS,separate comparison PASS and checker PASS.

| File(s),under sim/dilithium/ | Creator / contents |
|---|---|
| stage5_sign_dma_inputs.txt |Single Python prepare:71 commands,source coefficients,high values,explicit response-fault/reset selectors;freshness token |
| stage5_sign_dma_outputs.txt |tb_sign_process_dma:C command,W accepted scalar writes,P packed BRAM requests,Q ACKs,U finish,D completion,R committed readback,A reset-aborted command,T witnesses,F totals |
| stage5_sign_service_outputs.txt |tb_sign_service:actual main-owned shared services;S sampled source words,C command,D completion,R result words,A aborted command,T arbitration/lease witnesses,F totals |
| stage5_sign_dma/sign_service.log |Questa Transcripts;matching _console.log captures batch output |
| stage5_sign_dma/sign_service_compare.log |Separate exact-file Python comparisons |
| stage5_sign_dma/sign_service_checker_selftest.log |Deliberate capture corruption rejection results |

DMA gate:71 commands,65 completions(44 successes +21 expected errors),6 reset
aborts;14284 exact scalar writes and3570 acknowledged packed writes. This
includes correct partial prefixes later canceled by reset:1108 scalar writes
and276 ACKs. Non-reset cases account for13176 scalar writes/3294 ACKs.
The checker verifies request-before-ACK and all64 ACKs before successful finish,
exact rollback finish codes,result metadata,canonical values and held leases.
All32 deliberately corrupted captures are rejected,including early ACK/finish,
bad reset-prefix data and missing source-lease evidence.

Shared-service gate:33 commands,30 completions(21 successes +9 expected errors),
3 reset aborts. All3 levels each exercise Decompose,4 successful CNB commands
and2 successful Mhint commands,plus owner/level/high errors and an abort.
192 source words=768 sampled coefficients;768 result words=3072 exact process
coefficients. The source is actual SHAKE256 -> sampler mask output from the
existing stage2 cases12/14/16,not a preloaded RAM image. No RTL forcing is used.
Priority probes submit rejected row/NTT/scalar commands and hold a public read;
signing waits. Other clients stay blocked during held signing completion.
All33 capture corruptions are rejected. Test declarations/checks are in
tb/tb_dilithium/tb_sign_service.sv;arithmetic/partial-write tests use
tb_sign_process_dma.sv and the production memory.sv/memory_banks/poly_bram.

The retained regression also freshly passes sign_process(7752 groups,117
complete polynomials,45 expected errors,6 aborts,27 checker faults),bank_process
(23 samples,15 NTTs,71 process commands,29 checker faults),and full_keygen
(8 complete keypairs,3 expected rejects,5 reset aborts,37 checker faults).
All75 official nist_keygen cases also freshly PASS:433600 exact key bytes,
54200 key words,18300 PK hash input words,4800 tr bytes and112000 field-read
records;41/41 checker corruptions rejected. The sequential six-gate run ends
with ALL_STAGE5N3_CURRENT_GATES_PASS. Earlier diagnostic gates not listed here
retain historical evidence;they are not claimed newly rerun.

Compared with Stage5N.2 evidence,48 previous RTL files remain byte-identical.
Only five prior RTL files change:the service package,service wrapper,row/bank
wrappers,and KeyGen's zero assignment for the new sign request. The new DMA
is a separate process file. The6.757ns SDC is byte-identical. The prepared
Quartus list adds the DMA;no fit or post-netlist result is claimed.

Current source token:b224a41318be58d790ee39d066ce6d27290538fdf003a7ea282e7162265a86ac.
Immutable evidence:evidence/stage5n3_sign_memory.zip and matching.sha256
sidecar,created without overwriting prior checkpoints. The archive includes
current source/references/docs,prepared fixtures,six fresh captures,comparison
and checker logs,and a size/SHA256 manifest. No full Sign/Verify or PPA claim.

## Stage5N.2 Decompose/CNB/Mhint flow

This is a local FIPS-derived process test,not a downloaded standalone NIST
process-vector corpus. The same single Python script prepares and compares it.
Python defines decomposition by integer division/positive ties/special wrap,
norms by centered absolute value,and Mhint by a high-bit-change calculation.
It separately checks scalar results against unchanged C decompose,make_hint
and poly_chknorm through tb/tb_dilithium/sign_process_reference.c.
No RTL arithmetic is imported into either oracle.

```powershell
# Repository root
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa GUI Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST sign_process
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit sign_process
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit sign_process
```

| File in sim/dilithium/ | Producer / contents |
|---|---|
| stage5_sign_process_inputs.txt |Python:case,op,param,kind,ID,group,last,abort,packed92-bit data,packed24-bit high |
| stage5_sign_process_expected.txt |Python:case,error,high24,low76,hint mask,lane-reject mask,prefix reject,prefix weight |
| stage5_sign_process_outputs.txt |RTL bench:J accepted case,P actual tagged results,A aborted case,X reset,F totals |
| stage5_sign_process.log |Questa Transcript;GUI waves show input/output,packet tracker and accumulators |
| stage5_sign_process_compare.log |Separate complete-file Python verdict |
| stage5_sign_process_checker_selftest.log |27 deliberate corruption rejections |
| stage5_sign_process_c_reference.log |Independent Python/C scalar agreement and exhaustive C decomposition checks |

Current process results:7752 accepted x4 groups,7746 exact returned results,
45 expected protocol/data errors,6 reset-aborted groups and117 complete
256-coefficient polynomials:53 Decompose,44 CNB and20 Mhint packets.
7746*4=30984 returned lane positions,including180 zeroed error lanes;
7701 valid groups=30804 mathematical lane results.
C checks30996 scalar input fixtures:18040/6488/6468 at levels2/3/5. This
includes aborted inputs;three invalid-level groups(12 lanes) have no C level
executable and are instead checked as RTL error cases. Counts must not be
confused with only successfully completed polynomials.

The unchanged C decomposition passes all8380417 canonical coefficients at
each level(25141251 level/input pairs). This exhaustive statement applies to
the C oracle,not the RTL. RTL tests target every high-bin/tie/wrap boundary,
random values,all norm-bound signs/equalities,all lanes,late/sticky norm
failure,hint negative ties/high wraps and omega/omega+1 counts.
7509 simultaneous input/output handshakes,2865 input stalls and2903 output
stalls occur in this directed campaign. Six resets cancel held middle/final
results,then recover with the same ID and different data. Invalid opcode,
level,data/high,kind,index,last and changing packet identity are exercised.
All27 checker corruptions reject,including missing sticky reject/hint weight.

The new blocks are not yet connected to main memory DMA/Sign. Final frozen
source also passes full_keygen(8 complete,3 expected rejects,5 reset aborts,
37 checker corruptions) and all75 NIST keypairs(433600 exact key bytes,
41 checker corruptions). All48 pre-existing RTL files and6.757ns SDC remain
byte-identical to Stage5N.1;both complete-key capture streams match Stage5N.1
except freshness headers. No KeyGen arithmetic/schedule change is introduced.

These three freshly captured gates share source token
9c78215f9e0edec3dfd474b7999acd338ba37a30f6ab46c46d9ed4ed55d19bd2.
Other gates retain their previous archived evidence;they are not claimed
freshly rerun. The create-only evidence/stage5n2_sign_process.zip and SHA256
sidecar preserve source,models,corpus,current inputs/golden files,three fresh
captures/verdicts and universal docs. MANIFEST.csv records sizes/hashes.
No new functional/code coverage percentage,PPA or synthesis result is claimed.

## Stage5N.1 shared-service refactor verification

The complete-KeyGen benches now instantiate the same external dilithium top
with its engines/banks/Bitpkg owned by dilithium_services. The source/golden
token includes both new service files. Reuse the existing prepare command and
selectors full_keygen,nist_keygen,keygen,rounded_keygen;there is no new launcher
or second Python script. See the Stage5M commands below for nist_keygen.

tb_full_keygen additionally checks the entire routed request record every
owned cycle. Without an owner it requires zero requests,no live bank regions,
engine jobs/responses or packed output/completion. It observes ownership after
main completion acceptance while the main FSM is IDLE and the child is still
freeing retained regions. Removing that cleanup lease would fail this check.
Reset aborts continue to cancel the client and the same shared physical engines.

New Q record:owned-cycle count,post-completion cleanup-owner cycle count,
unowned-idle cycle count. Each must be positive and cleanup must be a strict
subset of owned cycles. The checker requires exactly one Q record;the fault
suite now deletes it and zeroes its cleanup count as two additional negative
tests. The main byte/hash/metadata/reset oracles remain independent and intact.

The local full_keygen gate passes8 complete keypairs,3 expected rejects,
5 reset aborts and37 checker corruptions. Its Q witness is988082 owned cycles,
195 cleanup-owner cycles and52 unowned-idle cycles. Its simulated campaign
duration remains6676943064ps,identical to the frozen Stage5M local run. These
are directed-test observations,not a sustained-throughput or PPA benchmark.
The full official-vector gate also passes75/75 keypairs,433600 exact key bytes
and41 checker corruptions. Its Q witness is9142284 owned cycles,2225
cleanup-owner cycles and151 unowned-idle cycles. All local/NIST capture events
match the frozen Stage5M streams exactly except freshness headers and Q.
Both diagnostic gates also freshly pass:keygen checks34 rows,172304 scalar
writes,8448 exact92-bit reads and29 checker faults;rounded_keygen checks34
rows,190224 writes,12800 reads and36 checker faults. Each has7 complete,
3 expected rejects and4 reset aborts.

These four gates share source token
830c05c8b16215688d1923497ed1b147ecf6b2aea526d4cf54688e8a0ab4a345.
Frozen source,reference,prepared inputs,official corpus,four captures/verdicts
and universal docs are in evidence/stage5n1_shared_services.zip with SHA256
sidecar. Prior archives remain unchanged. Other focused gates retain their
previous archived evidence;they are not claimed freshly rerun here.
Sign/Verify and multi-client contention remain unimplemented;this step verifies
the main-owned resource boundary with its current KeyGen client only.

## Stage5M official NIST KeyGen flow

The official corpus is NIST's [ACVP-Server ML-DSA KeyGen FIPS204 directory](https://github.com/usnistgov/ACVP-Server/tree/2972def23bf9f3680c2c531561ed9bdd0f1086ad/gen-val/json-files/ML-DSA-keyGen-FIPS204),
pinned at commit2972def23bf9f3680c2c531561ed9bdd0f1086ad. It contains75 AFT
cases:25 each for ML-DSA-44/65/87,called levels2/3/5 in our interface. Every
case is included;there is no subset selection. This is the published corpus
at that revision,not a claim to cover every possible NIST validation case.

| File | Origin and use |
|---|---|
| NIST/ML-DSA-keyGen-FIPS204/prompt.json |Downloaded unchanged from NIST;32-byte seed,parameter set,tgId,tcId |
| NIST/ML-DSA-keyGen-FIPS204/expectedResults.json |Downloaded unchanged;published complete pk/sk bytes |
| NIST/ML-DSA-keyGen-FIPS204/provenance.json |Pinned URLs,revision,retrieval time,byte sizes and SHA256 |
| sim/dilithium/stage5_nist_keygen_inputs.txt |Python joins cases by(tgId,tcId);writes seed/level/operation ID for RTL |
| sim/dilithium/stage5_nist_keygen_expected.txt |Python copies published keys into one readable file;index,tgId,tcId,parameter,seed,pk,sk |
| sim/dilithium/stage5_nist_keygen_outputs.txt |Questa captures actual key words,hash transfers,field-read metadata,completion and cleanup |
| sim/dilithium/stage5_nist_keygen_compare.log |Separate Python byte/protocol comparison verdict |
| sim/dilithium/stage5_nist_keygen_checker_selftest.log |Deliberate-corruption rejection verdict |
| sim/dilithium/stage5_nist_keygen_c_reference.log |Additional C-versus-NIST check;C does not supply the expected RTL keys |

Simple flow:

```text
NIST seed + level -> input file -> unchanged full-KeyGen RTL -> output file
NIST published pk/sk -----------> expected file -----------+-> Python compare
```

Run from the repository root:

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

Then run in the Questa GUI Transcript,working directory sim/:

```tcl
set DILITHIUM_STAGE 5
set DILITHIUM_TEST nist_keygen
do dilithium/run.do
```

Finally run separately from the repository root:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit nist_keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit nist_keygen
```

The simulator uses tb_full_keygen with NIST_VECTORS=1 and FULL_KEYGEN=1 on
the main RTL. It receives no expected keys. It starts all75 operations,
stalls the output periodically,holds completion,and waits for zero bank
reservations before the next seed. There is only an initial reset;successive
keypairs reuse the same physical resources. Operation IDs cross65535.
The16-case local suite remains selectable as full_keygen and covers resets
and rejected commands separately.

Python first verifies pinned raw-file hashes,metadata,75 unique joined cases,
seed/key lengths and parameter counts. Seed hex in NIST is byte order;the
input file reverses that byte string into a little-endian256-bit SV literal.
Actual output word bits7:0 are the first byte. The comparator checks every
PK/SK byte,word index,type,ID,byte count,last,PK-before-SK order,hash data,
tr,field-read ownership and cleanup/completion order. It requires every case
and the final totals. No result is inferred merely from simulator exit0.
The prepare command also checks all75 complete C keypairs against NIST.

All input/golden/capture files are bound to current source and corpus hashes.
Changes to the script,TB or corpus require prepare and a fresh capture.
Earlier Stage5L evidence remains immutable;old loose captures have their
historical token and must not be compared against the updated preparation.
Stage5M results:75/75 complete NIST keypairs match,25 per parameter set.
54200 accepted64-bit key words =433600 exact bytes;18300 exact public-key
hash input words,4800 exact tr bytes and112000 field-read metadata records.
All75 completions and subsequent zero-reservation cleanup pass. The fork
witnesses3632 host-ahead and17452 hash-ahead cycles;these are protocol witnesses,
not throughput. All39 checker corruptions are rejected,including the final
byte of both keys at all three levels and a missing complete case.

Counting:25*(3872+5984+7488)=433600 successful key bytes;there are no aborted
prefixes in the NIST campaign. PK absorption is25*(164+244+324)=18300 words.
tr is75*64=4800 bytes. Field reads are25*64*(16+23+31)=112000 words.
All46 production RTL SystemVerilog files are byte-identical to Stage5L.

The local full_keygen suite also freshly passes8 complete keypairs,3 expected
rejects,5 reset aborts and35 checker corruptions with this updated harness.
Both captures use source token
22f42dd20700ee8b0e014dee66c45118bcb0edc647f8ded54949f658bd0a6461.
The other15 gates' most recent complete regression is the immutable Stage5L
archive;they are not claimed newly rerun for Stage5M. Freeze this stage in
evidence/stage5m_nist_keygen.zip with stage5m_nist_keygen.sha256,including raw
official corpus,provenance,current source/reference/input files,both fresh
captures and verdicts. MANIFEST.csv checks every member's size and SHA256.

This is source known-answer testing,not NIST certification,full-system UVM
coverage,timing signoff or FPGA testing. Sign/Verify remain unimplemented.

## Stage5L complete software-reference KeyGen

FULL_KEYGEN=1 on dilithium/keygen now enables the complete encoded-key path.
The autonomous polynomial scheduler retains rounded fields,then
helpers/keygen_encode.sv reads them through the existing bank interface,
uses the existing Bitpkg,and forks each public-key word to the output and
the same finite raw-SHAKE service. SHAKE256(pk,64) supplies tr. The controller
then emits the secret key and holds overall completion before source cleanup.
No second Keccak or encoded-key RAM is introduced.

Run the one-script capture/compare flow:

```powershell
# Repository root;GCC builds the independent C reference programs.
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa GUI Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST full_keygen
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit full_keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit full_keygen
```

Inputs:stage5_full_keygen_inputs.txt contains16 operation/level/ID/xi/reset
cases. Expected complete keys:stage5_full_keygen_expected.txt. The Python
prepare command builds three C executables from the unchanged reference
crypto_sign_keypair,polyvec,polynomial,packing,rounding and SHAKE sources.
tb/tb_dilithium/keygen_reference.c only injects the supplied32-byte xi through
a test randombytes implementation;it checks that KeyGen requests it exactly
once.13 valid fixture seeds generate deterministic complete reference keys;
three rejected commands have no expected keys. Source tokens include these
reference sources and the expected key bytes.

The bench supplies start,output-ready,done-ready and reset;no external row,
sample,NTT,process or packing commands are driven. Actual RTL key words are
captured in stage5_full_keygen_outputs.txt. Python checks every accepted byte,
key type,index,ID,last and length against the C output. It independently
compares all public-key absorption words and all tr bytes using hashlib,
validates every encoding read's section/poly/word/region/owner/parameter/domain,
and forbids retained-source releases before operation retirement.
Reports:stage5_full_keygen_compare.log,stage5_full_keygen_checker_selftest.log
and stage5_full_keygen_c_reference.log.

Results:8 successful complete keypair operations,3 expected rejects and5 reset
aborts. The successful runs cover all levels2/3/5,plus five level2 recoveries.
5433 exact64-bit output words,2058 public-key SHAKE input words,656 tr bytes
and11179 metadata-checked field-read words are captured,including abort prefixes.
The eight successful operations emit36704 complete key bytes. The whole capture
also contains6760 aborted-prefix bytes;those are not successful key objects.
35 deliberate corruptions are rejected,including secret-key data,hash bytes,
duplicate fork deliveries,missing hash retirement and premature source release.

Resets target hash-accepted/host-stalled first PK word,partial PK field,
first128-bit tr beat,partial SK secret field,and held final completion after
both keys have streamed. Recovery reuses the ID with different xi. The
parameter2 normal run starts with ID65500 to exercise internal16-bit wrap.
Three ordinary operations run consecutively without reset,proving cleanup/reuse.
Four-cycle held overall completion and independently stalled hash/output
paths are checked. Fork witnesses:434 host-ahead cycles and1939 hash-ahead
cycles in this directed run;these are handshake observations,not throughput.

The final regression also reruns all15 earlier focused gates and their checker
fault tests;all16 gates pass on source token
b4c3284a2fe1cacad64c73cde32f43674e3ad3c17fd04b6197bd033a0b6b55b6.
The create-only evidence/stage5l_full_keygen.zip preserves current RTL,
testbenches,independent references,input/golden files,all16 captures/verdicts,
universal docs and prepared project files. MANIFEST.csv records member sizes
and SHA256;stage5l_full_keygen.sha256 records the archive digest. All25 imported
Keccak/sampler/NTT SystemVerilog files are unchanged from the Stage5K archive.

This is complete deterministic KeyGen against the local final-format software
reference,not official downloaded NIST conformance yet. Official KeyGen vectors
are the next gate before Sign controller work. Sign/Verify still return
unsupported code2. No new PPA,synthesis,netlist,full-system UVM coverage or FPGA
result is claimed. Earlier sections below describe preserved historical gates.

The official-vector follow-up above completes that Stage5L next gate.

## Stage5K connected Power2Round and Bitpkg arithmetic

The new rounded KeyGen path enables ROUND_OUTPUTS=1 on keygen/dilithium.
After t=A*s1+s2,it runs the existing acknowledged P2R process DMA. It retains
each row's t0 in flat region56+i and t1 in40+i through overall completion,
then releases both arrays after the existing secret cleanup.
The earlier selector keygen explicitly retains ROUND_OUTPUTS=0 as its baseline.

Two new selectors use the same launcher and Python script:

```powershell
# Repository root
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa GUI Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST rounded_keygen
do dilithium/run.do
# Select bitpkg instead for the standalone packet-format gate.
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit rounded_keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit rounded_keygen
# After running selector bitpkg:
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bitpkg
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bitpkg
```

Rounded result:7 successful polynomial-phase operations,3 expected rejects,
4 resets and34 delivered t rows.190224 scalar values and12800 exact92-bit
read words match. Retained t0/t1 metadata and every rounded coefficient are
checked before overall completion. Both regions must be COMPLETE before
row output becomes valid. Rounded-specific checker corruptions target each
array's values/IDs,allocations and high-region commit;36 total corruptions
are rejected. The source still exposes t rows for inspection;it does not yet
emit serialized public or secret keys.

Bitpkg result:97 commands,60 successful packets,31 expected errors,6 reset
aborts;18292 accepted input coefficients and2482 exact64-bit words. Formats
are t1(10 bits),t0(13 bits),eta-s(3 bits at levels2/5,4 at level3).
Six patterns cover zeros,extreme values,alternation,boundaries and pseudorandom
values for each format/level. Reject tests cover invalid command/level,
out-of-format coefficients,wrong index and early/missing last. Reset aborts
at17 accepted coefficients or a held first output;different data reuses the ID.
Output/data/tag/index/last hold under backpressure;final status also holds.
15 capture corruptions are rejected.

The Python preparation now builds a C packing oracle for levels2/3/5 from the
unchanged software poly.c packers and their dependencies.66 valid fixtures,
including abort/recovery inputs,match18496 C-encoded bytes. This is independent
development-reference evidence,not official NIST full-key vectors.

Inputs:stage5_bitpkg_inputs.txt and the existing stage5_keygen_inputs.txt.
Captures:stage5_bitpkg_outputs.txt and stage5_rounded_keygen_outputs.txt;
each has its own compare/checker logs. C witness:stage5_bitpkg_c_reference.log.
Prepared source tokens include the C adapter and its actual software sources.
Next:connect bank reads to Bitpkg,serialize complete key fields in final FIPS
order,and hash the encoded public key to obtain tr. Bitpkg is currently tested
as a working process block;it is not yet the complete key-output pipeline.
The selected next interface is tagged64-bit key streaming,with rounded fields
retained in existing banks and no additional encoded-key RAM. This choice is
documented in SPECIFICATION.md;its main output ports are not implemented yet.
All15 focused gates and their checker fault tests freshly pass on the same
source token. Create-only evidence:evidence/stage5k_rounding_bitpkg.zip and
its SHA256 sidecar include current source,captures,C oracle sources and
per-file hashes. Preserve all earlier immutable snapshots.

## Stage5J autonomous KeyGen polynomial phase

New RTL:`src/controller/keygen.sv` schedules the shared seed/sampler,retained
secret transforms,all matrix rows,existing row accumulator and final modular
s2 addition. `src/controller/dilithium.sv` is the main operation FSM;currently
operation0 selects this polynomial phase. Sign/Verify return explicit unsupported
code2 and do not start a child. This is not complete encoded KeyGen.

Use the same single script and launcher:

```powershell
# Repository root
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa GUI Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST keygen
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit keygen
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit keygen
```

The input file stage5_keygen_inputs.txt contains14 operation/level/ID/xi/reset
cases. The bench supplies only start/read/response controls,not polynomial
commands or preformatted messages. Python independently derives all secrets,
matrix entries,transforms,products,partial sums,inverse rows and final t rows.
Each allocated region's ID/order,every accepted scalar value,index,last,
commit,readback metadata and release is checked. Row0 at each level also
matches a coefficient-domain negacyclic schoolbook calculation.

Results:7 complete polynomial-phase operations,3 expected rejects and4 resets;
34 delivered t=A*s1+s2 rows.172304 scalar writes and8448 exact92-bit reads match.
The three ordinary runs cover all34 secret nonces and102 matrix positions
across levels2/3/5;four recovery runs use level2 with different xi and reused IDs.
The parameter2 run uses ID65500,exercising16-bit wrap. Invalid parameter3 and
unimplemented Sign/Verify commands have no sampling/allocation side effects.
The controller retires every temporary and retained region after overall
completion acceptance,then runs again without reset. Raw s1/s2 and s1_hat
remain readable while overall completion is held.

Reset targets:half-collected seed output,first secret after8 accepted values,
first t row held before consumption,and the first accumulator rewrite after8
accepted values. Recovery uses the same ID with a different xi. Pending-read
handoff:all34 row completions retire while their last read response is held;
136 checks prove the controller keeps the region reserved until that response
retires.29 deliberately corrupted captures are rejected.

All13 focused integration gates and their checker fault tests pass on the same
current source token after relocation and Power2Round extraction.
Frozen create-only source/capture evidence:`evidence/stage5j_keygen_polynomials.zip`
and its SHA256 sidecar. Earlier archives retain their snapshot paths unchanged.

Capture/verdicts:stage5_keygen_outputs.txt,stage5_keygen_compare.log and
stage5_keygen_checker_selftest.log. Require
DILITHIUM_STAGE5J_KEYGEN_POLYNOMIAL_CAPTURE_PASS,the independent
DILITHIUM STAGE5J KEYGEN POLYNOMIAL COMPARE PASS,schoolbook and checker PASS.
This is local FIPS-derived intermediate testing,not official full-key NIST KATs.
Key encoding,public-key hashing and complete public/secret-key output remain
next. No new synthesis,PPA,full-system UVM or coverage percentage is claimed.

Source relocation:old bank_poly_store is now module memory in controller/memory.sv;
the old scalar memory is slot_memory under legacy/. The legacy scalar tests
remain selectable. Historical Stage5I and earlier sections below refer to their
snapshot names. See SPECIFICATION.md for the current layout.

## Stage5I seed-driven sampling and row execution

The new synthesizable `src/controller/keygen_sample_source.sv` retains the
RTL-expanded seed and supplies messages to the existing banked row subsystem.
The focused bench connects the adapter to `keccak_sampler_row #(.RAW_SERVICE(1))`.
There is one dual-core Keccak, one sampler, one NTT and one four-bank store.
No second hash engine or full-polynomial buffer is added.

Run the same prepare command, then select the new test in Questa:

```tcl
# Questa Transcript; working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST seed_row
do dilithium/run.do
```

```powershell
# Repository root, after simulation
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit seed_row
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit seed_row
```

`prepare` creates `stage5_seed_inputs.txt`: three deterministic 32-byte xi
values, one per level. It derives them with SHA256("banked-row-level-p").
These are local reproducible inputs, not official NIST KeyGen vectors.
The RTL hashes xi||byte(k)||byte(l), collects 128 SHAKE256 bytes, and retains
rho(32 bytes), rho-prime(64) and K(32). Commands then select A[row,column] or a
secret nonce. The RTL formatter supplies rho||column||row or rho-prime||nonce_le16.
The test supplies descriptors and xi; its seed-driven branch does not drive
preformatted fixture bytes into the DUT.

The existing row bench has a SEED_SOURCE parameter; selector seed_row sets it
to 1. Selector row retains the original fixture-driven baseline. Its 48 message
fixtures remain independent expectations for both tests. The seed-driven
capture is `stage5_seed_row_outputs.txt`; verdicts are in
`stage5_seed_row_compare.log` and `stage5_seed_row_checker_selftest.log`.
The source token includes the new helper, changed wrappers, bench and checker.

Additional ledger events:SC(source command),SR(raw descriptor),SI(raw absorption),
SO(raw output),SE(raw retirement),SF(sample absorption),SD(source retirement and
retained seed). Python checks every seed byte, every accepted absorption word,
tag/core ownership and retirement order before applying the existing row,
packed-memory, direct-transform, schoolbook and C-ADD checkers.

Results:190 source commands =20 successful seed expansions +163 successful
sampling commands +7 expected rejections. All2560 raw SHAKE bytes and1103
sampling absorption words match. All163 polynomials feed the established
row campaign:13 complete rows,27 row rejections,7 row reset aborts,161 NTT
commands,55 ADDs and12544 exact92-bit readbacks. The seven adapter rejections
are missing seed,invalid opcode,invalid seed level,mismatched retained level,
out-of-range secret nonce,row and column. Rejected requests cause no hash,
sampling or bank allocation. Completion holds four cycles per command without
accepting another command or changing retained material. Reset invalidates
seed validity and the bank/row state together.

23 deliberate capture corruptions are rejected. Existing eleven focused gates
are rerun separately on the same source token. These checks do not establish
whole-KeyGen output or comprehensive UVM coverage. Current row fixtures use
s1 nonces and two matrix rows per level; all s2 nonces and remaining matrix rows
are not exercised in this connected campaign. Seed/absorption-phase resets
remain covered by earlier isolated helper tests, not a new Stage5I reset sweep.
The bench still schedules polynomial/NTT/row commands. Next:automate the
KeyGen sequence,retain s2,add it to each inverse row,then round and encode keys.

The Stage5H section below describes the preserved fixture-driven baseline.

Frozen evidence:`evidence/stage5i_seed_row.zip` and
`evidence/stage5i_seed_row.sha256`. The create-only archive contains current
source,fixtures,captures,all12 gate verdicts,documentation and a per-file hash
manifest. Preserve earlier archives;their snapshots describe earlier source.

## Current scope

### Stage5H row multiply/accumulate and inverse NTT

New RTL:row_accumulate.sv and keccak_sampler_row.sv under src/controller/.
The existing process DMA/store gain an explicit destructive accumulation mode.
Test:tb/tb_dilithium/tb_row_accumulate.sv. Same single script and launcher:

```powershell
# Repository root
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa GUI Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST row
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit row
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit row
```

Require DILITHIUM_STAGE5H_ROW_CAPTURE_PASS,then DILITHIUM STAGE5H ROW COMPARE
PASS,ROW_SCHOOLBOOK_PASS and C_ROW_ADD_PASS. Inputs:stage5_row_samples.txt has48
FIPS-formatted secret/matrix message fixtures;stage5_row_expected.txt contains
six complete expected coefficient-domain rows. Python expands deterministic xi
with SHAKE256(xi||k||l),then formats rho||column||row and rho-prime||nonce_le16.
The test drives those messages into actual SHAKE/sampler RTL. Seed collection
and message-formatter RTL are still separately tested helpers,not connected by
this row scheduler. These fixtures are locally generated,not official NIST KATs.

The bench exercises two rows per level2/3/5,retaining transformed secrets between
rows,plus seven reset/recovery cases. Ordinary NTT and eligible Pre-NTT feed the
retained secret bank. Each successful row uses l PWM commands,l-1 destructive
ADDs,and one normalized inverse NTT. Row source metadata is validated before
arithmetic;all lower commands,IDs,domains,write/ack/commit and release order are
independently checked. The resulting polynomial is u_i=(A*s1)_i. Addition of s2,
Power2Round,key encoding and full-KeyGen output comparison remain next work.

Results:47 row commands=13 successes+27 expected rejections+7 reset aborts.
163 successful sample jobs,161 NTT/Pre/PWM/INTT commands and55 in-place ADD
commands are captured.96264 scalar writes,24066 physical packed writes and
24066 acknowledgements match. Public readbacks12544 words=50176 coefficients;
6918 process word-cache reads verify old data,updated owner ID and exact
read-before-overwrite frontier. C independently matches13832 completed ADD
results from13833 accepted operands(the final extra input is reset-aborted).
The six reference rows also match coefficient-domain negacyclic schoolbook
products,independently of the hardware scheduling.

Rejections cover invalid level/row index,workspace alias/busy state,stale A/S
owners,wrong parameter,untransformed secret and missing matrix source. No child
arithmetic starts for these commands. Sources and result remain protected while
completion is held. The single accumulator and scratch are reused/released;
matrix/secret preservation is checked with full readback. Reset targets:
metadata validation,first PWM execution,first accumulator completion,in-place
partial overwrite,scratch release,inverse execution,and held whole-row completion.
Recovery reuses row IDs with a different matrix row. All old descriptors reject
reads after reset. Witnesses:160 held-row refusal checks and4 pending-read checks.

Capture extends the existing scalar/word ledger with B(row descriptor array),
DROW(row retirement),Z(row abort),M(old source-word cache read and write frontier)
and L(region release,internal/external). Python models the exact child command
sequence and snapshots the old accumulator before rewrite.26 checker corruptions
are rejected,including incorrect term count,stale source,missing ADD/ack/commit,
wrong cached old data/frontier and wrong row result. Files:stage5_row_outputs.txt,
stage5_row_compare.log and stage5_row_checker_selftest.log. GUI waves show the
row FSM,column counter,leases,PWM/ADD/inverse commands and accumulator updates.

This is a source-tested sequential staged-row implementation. It does not yet
overlap matrix sampling with row arithmetic or implement the full KeyGen/Sign/
Verify controller. No new synthesis,physical RAM/Fmax/area result or full-system
UVM coverage percentage is claimed. Default selector4/Quartus top stay unchanged.
All ten earlier source gates and checker selftests freshly pass at the current
source token. Frozen evidence:evidence/stage5h_row.zip and stage5h_row.sha256,
containing current source/references,fixtures,all eleven source captures/verdicts,
universal docs and the prepared Quartus project. CRC/member bytes and per-member
manifest hashes are verified. Older evidence remains unchanged.

### Stage5G banked ADD/SUB/Power2Round and NTT chains

New RTL:src/controller/process/poly_process_dma.sv. It is connected inside
keccak_sampler_ntt_banks with PROCESS_SERVICE=1. Test:tb/tb_dilithium/
tb_bank_process.sv. The same single Python script and run.do drive this gate.
The earlier arithmetic unit and all three standalone engines are unchanged.

```powershell
# Repository root
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

Require DILITHIUM_STAGE5G_CAPTURE_PASS,then the independent DILITHIUM STAGE5G
BANK PROCESS COMPARE PASS and C_BANK_PROCESS_PASS. Prepare generates
stage5_process_banks_inputs.txt:262 scheduled sample,NTT,process,read and reset
actions,plus the common104 messages. RTL captures stage5_process_banks_outputs.txt.
Python keeps its own region/owner/domain/value and write/ack/commit ledger.
It computes ordinary modular arithmetic and integer Power2Round,with direct
NTT/inverse and schoolbook references for the real connected NTT chains.
The rebuilt process_reference C executable separately checks actual accepted
process operands using repository power2round() and modular arithmetic.

Results:23 successful sample jobs;15 successful NTT operations;71 process
commands=34 successes+33 expected rejections+4 reset aborts. There are8978
accepted process inputs and8976 completed outputs,all matching Python/C.
The ledger checks22297 coefficient writes,5574 packed writes and5574 acks,
plus8512 exact92-bit reads(34048 coefficients). Completed jobs account for21760
coefficient writes;537 belong to aborted prefixes. Packed writes5440 belong to
completed jobs,134 to aborted prefixes;one additional prefix coefficient never
forms a full word. These are checked observations,not all possible input values.

All three parameters are exercised. Chains include sampled secrets -> NTT,
sampled matrix -> PWM -> ADD/SUB -> INTT -> ADD -> Power2Round,and stored low ->
real NTT. ADD/SUB cover both domains,A==B,negative modular differences and
round-trip recovery. Source preservation is checked. Invalid op,stale/missing
A/B,domain/parameter mismatch,and destination aliasing reject without arithmetic
or allocation side effects. Busy destinations wait while unrelated release
unblocks them. Held completions protect result regions. Pending public reads
block process acceptance. Resets reach initial DMA,arithmetic with partial
writeback,between low/high writes,and after low commit before high commit.
Recovery reuses source IDs with different messages. Full KeyGen formatting,
row scheduling and key encoding remain future work;these are not NIST KATs.

Power2Round writes low modulo q and zero-extended high into two64-word regions.
Public complete bits mask partial publication until both commits. The signed
low and13-bit encoding4096-low are also checked at the arithmetic boundary;
key byte encoding is not implemented. Observed rounding spans high0..1023,
low-4095..4088;exact positive4096 ties are covered by the separate Stage5A
directed RTL gate,not asserted reached by this banked workload.

Capture:J/S sample allocation/retirement,O NTT command,C process command,V
region allocation,W scalar store,P/Q packed write/ack,U internal region commit,
T NTT input,N NTT output,I process input,K all arithmetic outputs,R/E public
read/rejection,L release,A reset-aborted process,X reset,Y partial-publication
snapshot,G ownership witnesses,F totals. The checker validates262 actions,
all physical packing/order/metadata and atomic-publication snapshots. It rejects
29 deliberate corruptions,including missing high commit and a false visible
partial result. Logs:stage5_process_banks_compare.log,
stage5_process_banks_c_reference.log,stage5_process_banks_checker_selftest.log.

This gate establishes the tested shared bank/process connection. It is not full
KeyGen,whole-operation official-vector conformance,full-system UVM coverage or
a new synthesis/timing/area result. Default selector4 and Quartus top are still
the preserved scalar baseline;the banked process path has its explicit selector.
All nine earlier source gates and checker selftests are freshly revalidated.
Frozen evidence:evidence/stage5g_bank_process.zip and stage5g_bank_process.sha256.
The archive preserves current sources,reference code,prepared inputs,all ten
source captures/verdicts,shared documentation and the prepared Quartus project.
CRC,manifest hashes and member bytes are verified. Earlier archives are unchanged;
no new synthesis/netlist run is represented by this checkpoint.

### Stage5F sampling through banked NTT and result storage

New controller:src/controller/keccak_sampler_ntt_banks.sv. Focused test:
tb/tb_dilithium/tb_keccak_sampler_ntt_banks.sv. The actual SHAKE,sampler and NTT
run together;the same Python script supplies independent hashlib/scalar sampler
and direct-transform/schoolbook polynomial expectations. This is not an official
NIST full-operation test.

```powershell
# Repository root
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

Require DILITHIUM_STAGE5F_CAPTURE_PASS and DILITHIUM STAGE5F BANK NTT COMPARE
PASS. Capture:stage5_ntt_banks_outputs.txt;verdict:stage5_ntt_banks_compare.log;
checker fault verdict:stage5_ntt_banks_checker_selftest.log. GUI waves include
leases,word/lane DMA,engine streams,word acknowledgements and public reads.

Results:16 successful sample jobs;54 arithmetic commands comprising30 successes,
21 expected rejections and3 reset aborts. Checks cover4096 sampled coefficients,
9746 accepted DMA values,7712 engine outputs and2944 exact92-bit readbacks
(11776 coefficients). Physical writes2952=1024 sample+1920 successful compute+
8 aborted-compute words. Acknowledgements2951=2944 completed-job words+7 aborted
words;reset cancels the final outstanding acknowledgement. Successful compute
DMA9216 values plus530 aborted-prefix values(18+256+256) gives9746. Engine
outputs7680 from30 completed polynomials plus32 before reset gives7712.

All four banks,three parameters and four operations are exercised,including
same-bank source/destination placement,A==B PWM,round trips and independent
schoolbook multiplication. Original inputs remain readable and unchanged.
Rejections check nonexistent/stale A and B,domain/parameter/Pre eligibility and
destination aliasing. A busy explicit destination waits;source release attempts
are blocked. Pending external reads block compute acceptance. Held completion
blocks destination release. Reset targets load,execution and packed writeback;
recovery reuses IDs with different input values.

Capture records retain the Stage4 J/W/S,O/V/T/K/D/B,R/E/L,X/F ledger. O additionally
names the requested destination;R includes the actual small-coefficient flag.
P/Q record physical packed writes/acknowledgements with sampler/compute owner,
region and word index;P also carries all92 data bits. G records ownership
witnesses. Python checks exact arithmetic,packing,lane order,addresses,IDs,
domains,bounds,write-before-ack-before-publication,source preservation and reset.
Nineteen corruptions of values,tags,packing,acknowledgements,publication records,
witnesses and freshness are rejected. This is focused source verification,not a
new full-system coverage percentage or PPA/full-KeyGen result.
All eight earlier focused source gates and their checker selftests freshly
pass with the current source token. The create-only evidence/stage5f_bank_ntt.zip
and stage5f_bank_ntt.sha256 preserve sources,references,all nine captures/verdicts,
shared docs and the prepared Quartus project. MANIFEST.csv records each member's
SHA256;no new synthesis/fit is claimed. Earlier evidence archives are unchanged.

### Stage5E real sampling into packed banks

New RTL:bank_poly_store.sv and keccak_sampler_banks.sv under src/controller/.
Tests:tb_keccak_sampler_banks.sv and bank_store_protocol_test.sv under
tb/tb_dilithium/. Same single Python script and run.do;the common104-job
stage2_inputs/expected files drive the actual SHAKE/sampler engines.

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST bank_store
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bank_store
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bank_store
```

Require DILITHIUM_STAGE5_STORE_PASS,BANK_STORE_PROTOCOL_PASS and DILITHIUM
STAGE5 STORE COMPARE PASS. Output:stage5_store_outputs.txt;comparison and fault
checker logs:stage5_store_compare.log/stage5_store_checker_selftest.log.

Results:104 accepted jobs,88 completed,8 expected errors,8 reset aborts.
23173 accepted coefficients match Python;5792 physical packed writes and5790
acknowledgements are checked. Readback5632 words equals22528 completed-polynomial
coefficients. MEMORY_MAP.md explains aborted prefixes and the two unaccepted
write acknowledgements. All64 aligned regions are filled/inspected,occupied
regions reject replacement until released,and fresh jobs overwrite/revalidate
them. Both contexts and all four modes/three parameters are checked.

Capture:J descriptor/core/region/ID,W coefficient,K92-bit bank write,B write
ack,S external retirement,R checked word response,E rejected read,L release,
A abort,X reset,G protocol-fault gate,F totals. Python independently checks
coefficient values,23-bit lane order,physical word addresses,write acknowledgements,
publication,IDs/domain/bounds metadata,read order,region reuse and exact totals.
It rejects12 intentional corruptions,including removing a physical write.

The companion injects wrong coefficient index,last,value,ID,core;premature or
wrong-ID success;and a257th coefficient. All raise sticky fault without any
successful publication. Reset recovery is checked between faults. Main tests
also reset held successful/error read responses and invalidate stale regions.
These are focused integration checks;no new full-system UVM/coverage/PPA or
full-operation result is claimed. Stage5F above adds banked NTT DMA/writeback;
default Stage4 remains available as the historical scalar baseline.

Frozen checkpoint:evidence/stage5e_bank_store.zip and stage5e_bank_store.sha256.
115 members preserve RTL/references,all eight focused captures/verdicts and
the then-current shared docs. CRC,manifest/member bytes and SHA256 verified;
preserve this archive unchanged during NTT migration.

### Stage5D LightHD four-bank memory foundation

User selected the published four1024x92-bit dual-port logical banks over the
earlier scalar-pool proposals. Files:src/controller/poly_bram.sv,
src/controller/memory_banks.sv,tb/tb_dilithium/tb_memory_banks.sv. Same Python
script and launcher;no new full-system UVM or standalone .do is added.

```powershell
# Repository root
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,from sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST bank_memory
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit bank_memory
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit bank_memory
```

Require DILITHIUM_STAGE5_BANKS_PASS and DILITHIUM STAGE5 BANKS COMPARE PASS.
Input:stage5_banks_inputs.txt;capture:stage5_banks_outputs.txt;verdict and checker
logs:stage5_banks_compare.log,stage5_banks_checker_selftest.log. The generated
program has14880 offers:14872 accepted,8 deliberately blocked/canceled on reset.
Of the14872 accepted requests,14864 receive responses and8 write acknowledgements
are canceled by reset. The writes themselves had committed and persist.
Responses comprise9509 exact92-bit reads plus5355 write acknowledgements.

Python keeps a separate(bank,address)->92-bit word model and a pending response
per port. Each accepted read snapshots its expected value;responses must match
ID,port,address,operation and data and occur after their acceptance edge. Write
acknowledgement payload is unspecified and not compared. Reset cancels queued
responses without clearing modeled payload. Recovery reads prove that accepted
writes persist and unaccepted blocked writes did not happen.

The program writes/reads every one of4096 bank words,then tests same-address
read/read,read/write,write/write,independent ports,random traffic,stalls and
reset. Witnesses:73 collisions,4112 same-address dual-read pairs,1031 cycles
with eight accepted requests,3075 request stalls,3034 response stalls,14807
same-edge response replacements. Twelve capture corruptions are rejected.
Capture records:J accepted request,R response,A reset-aborted response,X reset,
F totals. All prior six integration/process/hash gates were freshly rerun PASS.

The bank primitive is not an ownership controller. This gate does not prove
correct KeyGen scheduling,packing/Pre regrouping,physical BRAM inference or
LightHD's32-cycle NTT input loading. The legacy Stage4 top remains unchanged.
Current NTT ports are scalar23-bit,so wide memory alone does not provide that
loading rate. MEMORY_MAP.md lists migration work and the inspected paper regions.

### Stage5C shared hash service and RTL seed collection

Files:the optional RAW_SERVICE route in src/controller/keccak_sampler.sv,
src/controller/keygen_seed_collect.sv,and tb/tb_dilithium/tb_shared_hash.sv.
The existing single Python script/launcher now support unit shared_hash.
Stage3/4 wrappers tie the route off;their main ports/capacity are unchanged.

```powershell
# Repository root
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST shared_hash
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit shared_hash
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit shared_hash
```

Require DILITHIUM_STAGE5_SHARED_HASH_PASS and DILITHIUM STAGE5 SHARED HASH
COMPARE PASS. Generated input:stage5_shared_inputs.txt;capture:
stage5_shared_outputs.txt;verdict/selftest:stage5_shared_compare.log and
stage5_shared_checker_selftest.log. These are local component vectors,not
official full-operation NIST vectors.

Measured:26 accepted commands,18 raw hash requests,7 completed sampled
polynomials,7 seed results(including1 expected parameter error),3 reset aborts.
The18 raw requests are9 expansion attempts plus9 direct finite hashes;the
rejected parameter case issues no hash. Six expansion results succeed;one
additional128-byte hash finishes before its held seed result is reset.
Reset-aborted input and output attempts contribute no completed seed result.

**1699 SHAKE bytes** match hashlib:6 successful expansions*128 +16 accepted
bytes before an output reset +128 bytes before a held-result reset +787 direct
raw bytes. The partial-input reset contributes no hash bytes. **1792 sampled
coefficients=7*256** match the independent sampler model. Three A/secret pairs
cover all parameters,and one additional A job runs alongside a raw job.

Crucially,the sampling message formatter consumes rho/rho-prime from the actual
RTL collector via the harness's seed-cache registers. Expected Python seed
material is used only for checking,not to drive the sampler. The main controller
and persistent polynomial/key-storage schedule are not implemented by this test.

Cases include empty/partial/multi-rate absorption,output lengths1/15/16/17/
32/128/137/169/272,both SHAKE modes,both physical cores,two raw jobs,raw+sampling,
simultaneous request arbitration,held raw completion while a peer finishes,
held seed results and ID reuse after reset. Resets target two accepted input
words,one accepted output beat,and a complete but unaccepted seed result.
Ownership overlap witnesses:mixed raw/sampling67 cycles,two raw333 cycles.
Held raw output/completion/seed-result witnesses:60/298/44 cycles;one raw-priority
arbitration edge is observed. These are ownership/workload observations,not
measurements of simultaneous permutation throughput.

Capture:J accepted command,R raw descriptor,W raw absorption,O tagged raw byte
beat,D raw completion,Z collected seed fields,S sampling descriptor,P sampling
absorption,C coefficient,T sampling status,A abort,X reset,F totals. Python
checks live core ownership,exact bytes/fields/order,completion boundaries and
all totals. Only output_bytes low bytes are compared;SHAKE rate boundaries can
produce short beats before the next permutation. Twelve corrupted captures
(raw data/core/ID/size,seeds,coefficients,error,completion and token) are rejected.
No new main-top PPA,netlist,full-operation or integrated coverage claim.

Frozen evidence:evidence/stage5c_shared_hash.zip with
stage5c_shared_hash.sha256.99 members preserve current RTL/references,all six
focused captures/verdicts and the then-current docs. CRC,manifest/member bytes
and archive SHA256 were verified. The mutable PROCESS_BLOCKS.md subsequently
corrects its shift-range explanation:valid t1 shifted by13 already fits0..q-1;
this documentation correction changes no RTL or measured result.

### Stage5B final-standard KeyGen message formatting

The chosen algorithm is final FIPS204 ML-DSA-44/65/87,called level2/3/5 in our
interface/docs. This gate checks only seed expansion and the absorbed matrix/
secret sampling messages,not full KeyGen keys or sampled coefficients.

Files added:src/controller/keygen_hash_message.sv and
tb/tb_dilithium/tb_keygen_hash_message.sv. The existing single Python script,
launcher and Quartus source list are extended. No standalone engine is changed.
Normative rules:FIPS204 Algorithms6,32,33;local sign.c/symmetric-shake.c agree.
These are generated component vectors,not published NIST full-operation vectors.

Flow:Python generates commands -> RTL formatter -> existing dual-Keccak in the
focused test -> stage5_hash_outputs.txt -> separate Python hashlib comparison.
Expected bytes are not used by RTL. The TB additionally checks every accepted
absorption word against the independently generated message. SHAKE samples use
rho/rho-prime derived from the fixed test seed for the selected parameter set.

```powershell
# Repository root; needs GCC for the other Stage5 process-reference gate.
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,working directory sim/
set DILITHIUM_STAGE 5
set DILITHIUM_TEST hash_format
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5 --unit hash_format
python sim/dilithium/dilithium_vectors.py selftest --stage 5 --unit hash_format
```

Require DILITHIUM_STAGE5_HASH_FORMAT_PASS and DILITHIUM STAGE5 HASH FORMAT
COMPARE PASS. Measured2026-10-20:165 accepted,162 message completions including
14 expected errors,3 reset aborts;883 absorption words,5888 exact SHAKE bytes.
The148 successful hashes are12 seed expansions and136 sampling-message hashes:
102 matrix coordinates(16+30+56) and34 secret nonces(8+11+15).
Twelve seed expansions include3 same-ID reset recoveries plus9 pattern/parameter
cases. Output bytes=12*128+136*32=5888. Absorption words=12*5+102*5+34*9+7
aborted-prefix words=883. Seed output slicing is rho32,rho-prime64,K32;an RTL
collector is now tested by Stage5C above;the Stage5B gate itself only checks bytes.

Errors cover parameter3,opcode3,out-of-range row/column and secret nonces.
Resets hit a held descriptor,after two absorption words,and a held message
completion;all coordinate/hash state resets together. Request/input/done/hash
stalls observe111/288/757/671 cycles;all held offers stay stable. The command
ports are poisoned after acceptance to check snapshots. Both physical core
tags are observed. Twelve intentional checker corruptions are rejected.

Capture records:J command,D descriptor,W absorption word,V SHAKE beat,S message
completion,A abort,E finished hash/error case,X reset,F totals. Python checks
ownership,ordering,bytes,IDs,errors and exact totals. Sampling descriptors retain
output_len0;the test service substitutes32 bytes only to bound the hash test.
Continuous-XOF sampling/drain remains covered by the earlier connected gates.
No main-top connection,full-operation key output,new coverage or PPA claim.

To return to the arithmetic unit:set DILITHIUM_TEST process with stage5.
The default connected gate remains DILITHIUM_STAGE4.

### Stage5A process-unit reference and execution

The algorithm choice is now final FIPS204;these ADD/SUB/Power2Round rules are
also common to the earlier candidate versions. The same Python file generates
stage5_process_inputs.txt with10349 arithmetic/framing cases. During prepare,
GCC builds tb/tb_dilithium/process_reference.c plus the unchanged local rounding.c
under sim/dilithium/reference_build/. Its exhaustive Power2Round reference
check and Python/C agreement appear in stage5_c_reference.log. The C program
uses the original power2round function;no RTL math is called.

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,from sim/:isolated process gate,not complete Stage5/KeyGen
set DILITHIUM_STAGE 5
set DILITHIUM_TEST process
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 5
python sim/dilithium/dilithium_vectors.py selftest --stage 5
```

Require DILITHIUM_STAGE5_PROCESS_PASS and DILITHIUM STAGE5 PROCESS COMPARE PASS.
10349 accepted cases produce10346 exact outputs,3 reset aborts and13 expected
error outputs. C separately checks8380417 canonical inputs;RTL checks9208 dense
rounding points plus modular arithmetic/error/transport cases. Error outputs
count among the10346 compared beats,not extra transactions.12 checker corruptions
are rejected. Source/reference/C-adapter hashes bind the generated file and capture.

stage5_outputs.txt records J(accepted case),P(error,residue,high,signed low,
packed low,ID,index,last,opcode),A(reset abort),X(reset),F(totals). Separate Python
comparison verifies exact arithmetic,metadata,elastic ordering and totals.
GCC is needed only by prepare;Questa's freshness check does not compile C.
The default run and Python --stage remain4 for the current connected subsystem.
No complete KeyGen or official full-operation vector comparison is claimed.
Create-only evidence/stage5a_process.zip and stage5a_process.sha256 preserve
the audit manifest,current source/references,test inputs/captures/verdicts and
shared docs. Its immutable RESULT.txt records the then-pending decisions;
the byte-format choice is resolved above,while key storage remains open.

Stage4 now checks real Keccak -> sampling -> memory -> NTT -> memory. It uses
the same Python script and locally generated subsystem vectors;these are not
official full-operation Dilithium/ML-DSA vectors. Main default commands:

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

```tcl
# Questa Transcript,from sim/
set DILITHIUM_STAGE 4
do dilithium/run.do
```

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 4
python sim/dilithium/dilithium_vectors.py selftest --stage 4
```

Preparation writes the shared sampling files and stage4_expected.txt with26
arithmetic polynomials. Python imports the unchanged mathematical functions in
FIPS204_NTT/ntt_vectors.py. Direct polynomial evaluation/inverse evaluation
provide transform expectations;independent schoolbook multiplication checks
the Matrix A/secret product chain. The SV test does not generate expected
NTT values using the DUT or a mirrored RTL function.

stage4_outputs.txt records J/W/S sampling lifecycle,O(compute descriptor),
V(reservation decision/destination),T(each DMA value with source slot/ID/index),
K(each NTT output/index/last),D(public completion),B(reset abort),R(stored
readback including domain),E(rejected read),L(release),X(reset) andF(totals).
The separate Python checker maintains slot ownership and source locks,
derives eligibility from actual expected values,checks every transfer and
all metadata,and requires exact lifecycle/totals. It computes each operation
again from the expected source polynomials;captured RTL values are never
used as the golden input to later expected arithmetic.

PASS:16 sampled jobs,50 commands,30 successes,17 rejects,3 reset aborts;
4096 sampled values,9745 DMA values,7713 result values and11776 stored reads.
Result arithmetic:30*256=7680 completed values plus33 accepted before reset.
All16 source polynomials and30 completed results are read in full:46*256=11776.
The three aborted destinations never publish complete results. Reset also
invalidates their source slots;43 explicit releases and6 invalid reads pass.
12 checker corruptions cover output,DMA value/ID,stored value/domain,source ID,
reservation/completion,missing output/commit,stale token and extra read.
Logs:stage4.log,stage4_compare.log,stage4_checker_selftest.log.

Relocated standalone NTT source UVM passes748 jobs/191488 values;18 original
standalone Python cases/4608 values match. Logs under sim/ntt/import_* identify
this relocation separately from historical branch evidence. No fresh standalone
or integrated synthesis/netlist run was made in this functionality-first stage.
Create-only evidence/stage4_subsystem.zip and stage4_subsystem.sha256 preserve
the imported module package,current integration source/reference/tests,
prepared projects,source captures/verdicts and universal docs. MANIFEST.csv
hashes each member;RESULT.txt states functional scope and unrun PPA/netlist work.

## Preserved Stage3 scope and commands

Stage3 extends the same one-script flow to real sampled polynomial storage.
Select DILITHIUM_STAGE=3 to run tb_keccak_sampler_memory. Inputs and expected
polynomials remain stage2_inputs.txt/stage2_expected.txt for both stages;these
names preserve the original generated format. Stage3 writes a distinct
stage3_outputs.txt with slot lifecycle and stored readbacks.

Current commands after `prepare`,from the Questa GUI Transcript in sim/:

```tcl
set DILITHIUM_STAGE 3
do dilithium/run.do
```

Then from the repository root:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 3
python sim/dilithium/dilithium_vectors.py selftest --stage 3
```

Require DILITHIUM_STAGE3_CAPTURE_PASS,MEMORY_PROTOCOL_PASS and the independent
DILITHIUM STAGE3 COMPARE PASS.104 jobs pass:88 complete,8 expected errors,
8 aborts;23180 exact writes (22528 complete+652 aborted-prefix values),22528
exact stored readbacks,88 releases,99 invalid reads and5 integrated resets.
All24 successful mode/parameter/actual-core combinations are present.
The three-slot fault companion separately proves8 protocol-fault cases,bounds,
pipelined read responses and reset of a stalled successful response.

Stage3 capture records:J(case,core,slot,ID),W(case,core,index,value,last),
S(case,core,status),A(case,core,prefix count),R(case,slot,index,value,ID,mode,
parameter,domain),E(slot,index rejected),L(slot release),X(reset),F(totals).
Python maintains its own slot/live-job model;it checks allocation,publication,
every write/read,release/reset and exact totals against the independent golden
polynomials.12 deliberate corruptions cover data,slot,index,ID,mode,parameter,
domain,missing read,duplicate job,missing commit,stale token and extra read.
All are rejected. stage3.log,stage3_compare.log and stage3_checker_selftest.log
record the verdicts. No official full-operation vectors or full UVM claim.
The create-only evidence/stage3_subsystem.zip and stage3_subsystem.sha256
preserve current RTL,testbenches,independent script,vectors,captures,logs,
universal docs and prepared Quartus files. MANIFEST.csv lists each member's
SHA256. RESULT.txt distinguishes source verification from unrun Stage3 synthesis.

## Preserved Stage2 flow

Stage2 checks the real SHAKE-to-sampling connection. The vectors are generated
locally;they are not official full-operation NIST vectors. The absorbed messages
include deterministic seeded bytes and arbitrary boundary lengths. This does
not validate full KeyGen/Sign/Verify seed expansion,encoding or signing randomness.

One script,`sim/dilithium/dilithium_vectors.py`,provides prepare/check/compare and
checker self-test. It uses Python hashlib SHAKE128/SHAKE256 and the unchanged
independent scalar sampler reference in `FIPS204_SAMPLER/sampler_vectors.py`.
No RTL function or SV golden result is used to generate the expected polynomial.

## Simple flow and commands

```text
Python messages -> SHAKE in hashlib -> independent sampling -> expected file
       |
       +-> input file -> real Keccak+sampler RTL -> captured output file
                                                      |
                          separate Python compare ----+-> PASS/FAIL
```

From repository root:

```powershell
python sim/dilithium/dilithium_vectors.py prepare
```

From `sim/` in the Questa GUI Transcript:

```tcl
set DILITHIUM_STAGE 2
do dilithium/run.do
```

From repository root after capture:

```powershell
python sim/dilithium/dilithium_vectors.py compare --stage 2
python sim/dilithium/dilithium_vectors.py selftest --stage 2
```

| File under sim/dilithium/ | Producer and meaning |
|---|---|
| stage2_inputs.txt | Python:case index,ID,mode,param,abort flag,byte length,message hex |
| stage2_expected.txt | Python:expected status/abort/count and canonical coefficients |
| stage2_outputs.txt | Simulator:J descriptor,C coefficient,S status,A abort,F totals |
| stage2.log | Saved headless Transcript;GUI displays its own Transcript |
| stage2_compare.log | Separate Python verdict |
| stage2_checker_selftest.log | Deliberate-corruption rejection verdict |
| stage2.wlf | Wave database;GUI launcher adds public and bridge/control waves |

The two input/golden files carry the same SHA256 token,bound to their contents,
reference and actual source/test/launcher files. The launcher checks freshness
before compilation;comparison recomputes it. Re-run prepare and capture after
source changes. Do not compare an old capture against a different token.

The simulator checks values/index/core/ID/last and status against the generated
golden file,plus independent protocol/ownership assertions. It requires an
explicit test_passed flag after all104 jobs. A fatal or watchdog without that
flag makes the launcher fail. The separate Python checker verifies all records
and exact totals again;process exit alone is not a passing result.

## Measured source results

104 accepted jobs:88 complete polynomials,8 expected invalid-parameter errors,
8 reset aborts. Current two-slot bridge:23089 coefficients match:22528 from88*256
complete polynomials plus561 accepted aborted-prefix coefficients. All24 combinations
of4 modes,3 valid parameters and2 contexts are observed in successful jobs.

Four reset targets reach both owned contexts:full blocked bridge,held Keccak output,
drain pending,and externally stalled status. Recovery reuses the same IDs with
different messages. All12 checker corruptions are rejected:value,index,core,
job ID,last,status,case,footer,missing coefficient,duplicate descriptor,extra
coefficient and stale token.

The queue reaches full occupancy for34198 observed cycles and simultaneous
push/pop128 times. Status checks both queued tags before retirement. The
initial one-slot workload checked23081 values;that historical capture remains
in evidence/stage2_subsystem_initial.zip. Changed abort timing explains the
different number of checked prefix values;all88 complete polynomials stay256
coefficients long. See THROUGHPUT.md for workload cycles and timing-trial status.

These are focused source tests. Full Dilithium UVM coverage,full-operation
official-vector checks,new integrated netlist simulation and FPGA testing remain
future stages. The standalone Keccak NIST suite is separately documented.
