# Dilithium design and integration plan

## Latest milestone:Stage5N.3 shared signing-process memory service

sign_process_dma now runs inside the one main-owned banked service through
request_t.sign / response_t.sign. It checks every read's owner,address,level,
coefficient domain and retained mode;validates full23-bit highs before narrowing;
stores signed lows canonically;and protects sources/results until done retires.
Decompose publishes both results after all acknowledged writes. Late errors
discard tentative destinations. CNB returns a polynomial rejection flag;
Mhint writes hint bits and returns a9-bit polynomial count.

| New gate | Result |
|---|---|
| sign_dma |71 commands,65 completions,21 expected errors,6 reset aborts;14284 exact scalar writes,3570 packed ACKs;32 checker corruptions rejected |
| sign_service |33 commands,30 completions,9 expected errors,3 reset aborts;192 sampled source words,768 exact result words;33 checker corruptions rejected |

The service gate uses actual SHAKE/sampling and the existing shared banks.
It checks row/NTT/scalar/pending-read priority,held-completion leases,exclusive
ownership and atomic result visibility at levels2/3/5. These component fixtures
are locally generated FIPS-derived cases,not published standalone NIST Sign
vectors. Fresh regression results/evidence are in REFERENCE_VERIFICATION.md.
All six current gates pass,including local full_keygen and all75 official
nist_keygen keypairs(433600 exact bytes). Frozen evidence:
evidence/stage5n3_sign_memory.zip and.sha256 sidecar;prior archives preserved.

**Next Stage5N.4:**signing key/input decoding and hash-message formatting,
with independent field/byte checks. Then vector-wide norm/hint reductions,
retry control and signature packing. Stage5N overall is unfinished;main
Sign/Verify remain unsupported. No duplicate engine tree,polynomial RAM,encoded
key RAM or external dilithium.sv ports were added. KeyGen drives sign='0.
Keep functionality first,the four-bank/shared-engine architecture and6.757ns
constraint. No full UVM/PPA/netlist stage advance,commit or branch operation.
Ask about material scope/interface/resource departures;routine choices remain
delegated. Earlier milestone sections below describe their historical state.

## Prior milestone:Stage5N.2 signing-process arithmetic

Working Decompose x4,CNB and Mhint arithmetic now sits behind sign_process,
a one-stage elastic x4 packet transport. It checks64 ordered groups,locks
ID/op/level/relevant kind,and returns Decompose high/low,per-lane norm/hint
results,sticky polynomial norm rejection and polynomial hint count.
It supports all levels2/3/5. Errors invalidate tentative packet output;reset
clears pending output and reductions. No source/model imports from RTL.

Current focused gate:7752 accepted groups,7746 exact results,45 expected
invalid-input/protocol errors,6 reset aborts,117 complete polynomials and27
checker corruptions rejected. Python/C agree on30996 scalar fixtures;the
unchanged C decomposition also passes all8380417 residues at each level.
Concrete tie/wrap/bound/sticky/hint witnesses are in the universal test plan.

All three current-source gates pass:sign_process,full_keygen(8 complete,
3 rejects,5 resets,37 checker faults),nist_keygen(75 exact keypairs,41 faults).
All48 pre-existing RTL files and6.757ns SDC are unchanged. Earlier diagnostic
results remain in Stage5N.1 evidence,not claimed newly rerun here. No synthesis,
new PPA,main Sign implementation or external top-level port change.
Frozen evidence:evidence/stage5n2_sign_process.zip and SHA256 sidecar.

Next Stage5N.3:connect the x4 process to shared banks with checked command,
read/metadata and write-acknowledgement ownership. Convert signed Decompose
lows to canonical23-bit residues and validate full stored highs before6-bit
narrowing. Keep tentative results unpublished until full error-free packets;
retain sources/results through completion retirement. Exercise reject/error,
backpressure/reset and same-ID reuse through the real memory path.
Then continue signing key/input decoding,hash formatting,vector reductions,
retry and signature packing in bounded steps. Sign/Verify remain unsupported;
Stage5N overall is not complete. Preserve full-KeyGen/NIST gates;stay with the
agreed LightHD shared-engine/four-bank architecture. No commit/branch operation
or synthesis;ask for material scope/interface/resource departures.

## Prior milestone:Stage5N.1 main-owned shared services

dilithium.sv now owns one dilithium_services instance containing the existing
banked SHAKE/sampler/NTT/process/row service and one unchanged Bitpkg. KeyGen
and its encoder are clients of packed request/response records defined in
helpers/dilithium_service_pkg.sv. No external top-level port changes,new engine
copies,bank RAM or pipeline registers are introduced by this boundary.
The main ownership gate stays active through post-completion cleanup,even
when the main FSM has returned to IDLE. Idle/unowned requests are zero.

Four current-source gates and their checker fault tests pass:

| Selector | Current result |
|---|---|
| nist_keygen |75 official keypairs,433600 exact bytes;41 checker corruptions rejected |
| full_keygen |8 complete,3 rejects,5 reset aborts;37 checker corruptions rejected |
| keygen |7 complete,3 rejects,4 reset aborts;34 rows,172304 scalar writes,8448 reads;29 checker faults |
| rounded_keygen |7 complete,3 rejects,4 reset aborts;34 rows,190224 writes,12800 reads;36 checker faults |

Local and NIST captures are identical to Stage5M apart from freshness headers
and the new Q ownership witness. All25 accepted engine files,the row wrapper,
Bitpkg and6.757ns SDC are unchanged. No new PPA result is claimed.
Frozen evidence:evidence/stage5n1_shared_services.zip and matching SHA256.

Next Stage5N.2:implement Decompose x4,CNB and Mhint as working shared process
blocks with independent Python/C boundary checks and focused RTL capture.
Then connect their memory/DMA use,signing inputs/key decoding,hash formatting
and retry/packing control in further bounded substeps. Do not add placeholder
Sign/Verify implementations or duplicate engine trees. The Sign controller,
remaining signing formats and Verify are still unimplemented;Stage5N as a
whole is not complete. Preserve current KeyGen/NIST gates during new work.
Keep functionality-first integration;no synthesis,commit or branch operation.
Ask for material scope/interface/resource departures;routine agreed choices
remain delegated. Universal docs and one launcher/Python flow continue.

## Prior milestone:Stage5M official NIST KeyGen

All75 published NIST ACVP KeyGen cases pass through the complete RTL path:
25 each at ML-DSA-44/65/87,called levels2/3/5 here. All433600 key bytes match
the downloaded expected keys. Actual PK hash input,tr,read ownership,ID wrap
and cleanup/reuse are checked;39 deliberate checker corruptions reject.
The existing full-KeyGen bench/one launcher/one Python script are reused.
Official files and pinned provenance are under NIST/ML-DSA-keyGen-FIPS204/.
All46 production RTL files remain identical to Stage5L;no PPA change is claimed.
The local reset/recovery/rejection full_keygen gate also freshly passes with
35 checker faults. These are the two current-token gates;the earlier16-gate
regression remains preserved in Stage5L. Frozen Stage5M evidence:
evidence/stage5m_nist_keygen.zip and stage5m_nist_keygen.sha256.

Next Stage5N:begin Sign by exposing shared engine/bank/packer ownership to
main-controller arbitration,and implement the remaining Decompose/CNB/MakeHint
processing and signing schedule in bounded steps. Keep complete KeyGen/NIST
tests passing during refactoring. Sign/Verify remain unsupported until their
actual output gates pass. Stage6 whole-operation scope remains open for those
operations;Stage7 full UVM/PPA and Stage8 netlists/FPGA are not started.
Routine choices follow the agreed LightHD reconstruction/shared-memory model;
ask the user for a material scope/interface/resource departure. No commit,
branch operation or synthesis is authorized by this continuation.
See REFERENCE_VERIFICATION.md for provenance,commands and detailed results.

## Prior milestone:Stage5L complete software-reference KeyGen

FULL_KEYGEN=1 now connects the retained banks to Bitpkg,streams the public key
to output and the same Keccak raw service,collects tr=SHAKE256(pk,64),then
streams rho,K,tr,s1,s2,t0 as the complete secret key. The main operation FSM
waits for all output/hash/packet work before held completion and cleanup.
Default0 preserves earlier polynomial inspection modes.

Eight complete keypair operations at levels2/3/5 match the unchanged software
KeyGen byte-for-byte. Three expected rejects and five reset/recovery cases
also pass. The capture checks5433 key words,2058 PK hash input words,656 tr
bytes and11179 field-read metadata records;35 checker corruptions reject.
No additional encoded-key RAM or hash engine is introduced.

All16 focused integration gates and their checker fault tests freshly pass
on the same source token. Frozen source,reference,captures,logs and docs are in
evidence/stage5l_full_keygen.zip with stage5l_full_keygen.sha256. All25 imported
Keccak/sampler/NTT SystemVerilog files remain byte-identical to Stage5K.

Next Stage5M:obtain official NIST full-KeyGen vectors,validate source/provenance
and compare the exact published key bytes through this RTL path. After this
conformance gate,continue the Sign controller and remaining LightHD CNB,
Decompose x4,Mhint/Bitpkg extensions,then Verify. Keep the shared controller/
memory reuse architecture;document compatibility decisions and measure any
claimed improvements. Comprehensive full-system UVM/PPA remain after supported
outputs. No commit,branch change,synthesis or netlist run in this continuation.

## Prior milestone:Stage5K rounding and Bitpkg

The ROUND_OUTPUTS=1 KeyGen path now stores t1/t0 after each t row and retains
both arrays through overall completion. It uses existing bank2/3 regions8..15,
not extra memory banks. Default0 preserves the earlier polynomial gate.
Seven successful operations,three expected rejects,four reset cases and34
delivered rows pass:190224 scalar values,12800 exact92-bit reads and36 checker
corruptions. Retained rounded arrays are released only during final cleanup.

process/bitpkg.sv now implements t1,t0 and secret polynomial field packing.
97 commands include60 valid packets,31 errors and6 resets;2482 exact64-bit
words and15 checker corruptions pass.66 full valid fixtures/18496 bytes agree
with unchanged software C packers at levels2/3/5. The other LightHD process
blocks remain in their planned Sign/Verify stages.
All15 focused integration gates and checker fault tests pass on one current
source token;the previous13 remain selectable and independently checked.

Next:connect bank reads to Bitpkg,serialize the complete key fields,and
hash the encoded public key into tr. The user reaffirmed reconstruction of
LightHD's shared controller/memory reuse with justified improvements and
delegated compatible architecture decisions. Select tagged64-bit key streaming,
retaining t1/t0 in existing banks and adding no encoded-key RAM. This selection
is our interface decision,not a claim about unpublished LightHD port signals.
Stage5L will connect bank reads/Bitpkg,PK word forking to host/shared hash,
tr collection,then SK field order and final cleanup. Do not begin PK hashing
before the final matrix sampling has completed. This stage does not claim
complete encoded keys;see SPECIFICATION.md for the selected next interface.
Keep the one launcher/script,universal docs,accepted engines and6.757ns target.
No PPA optimization,commit,branch operation or new netlist run.

## Prior milestone:Stage5J autonomous polynomial phase

The requested root controller organization is now active:memory.sv,keygen.sv
and dilithium.sv contain working RTL. sign.sv and verify.sv are the designated
files for their implementation steps. Shared data/memory/control helpers are
kept in subfolders. All processing arithmetic/formatting belongs under process/,
including working power2round.sv. The requested LightHD process inventory is
CNB,Decompose x4,Mhint,Bitpkg and P2R plus required UseHint/checking helpers;
see PROCESS_BLOCKS.md for current/planned status.

keygen.sv now autonomously expands xi,samples every s1/s2 nonce,retains raw
secrets,Pre-transforms s1 once,processes every A_hat row,and adds s2[i] after
inverse NTT. It presents coefficient-domain t rows and cleans up all regions
after overall completion acceptance. The bench no longer schedules these
internal commands. Seven polynomial-phase operations,three expected rejects,
four reset cases and34 t rows pass independent comparisons;29 corrupted
captures are rejected. All13 focused gates and checker fault tests pass on the
same source token. Old scalar/banked/row gates remain selectable.

Next bounded step:connect Power2Round to the KeyGen scheduler and implement
Bitpkg for t1/t0 and secrets,then public-key hashing and exact encoded key
outputs. Ask before major external key-storage/interface decisions. Only after
full KeyGen output checks advance to Sign/Verify controller/process steps.
Complete FIPS204 bytes use level2/3/5 names. No new PPA optimization,commit,
branch operation or netlist simulation is authorized by this continuation.

## Prior milestone:Stage5I seed-driven row path PASS

The RTL seed collector and message formatter are now connected to the real
banked Keccak/sampler/NTT/row path through keygen_sample_source.sv.
Selector5/seed_row passes190 commands:20 seed expansions,163 sampling jobs and
7 expected adapter errors. All2560 seed bytes and1103 sampling absorption words
match Python;retained rho,rho-prime,K match. The existing row workload passes
13 complete rows,27 rejections,7 reset aborts and12544 exact92-bit readbacks.
23 seed-path checker corruptions are rejected;all eleven earlier focused
gates also pass on the current source token.

This is a verified command adapter connection,not full KeyGen. The bench still
schedules sampling/NTT/row descriptors. Connected tests cover s1 and two matrix
rows per level2/3/5;all s2 nonces and remaining rows await the next schedule.
Next Stage5J:implement autonomous KeyGen polynomial scheduling,retain s2,
add s2[i] to inverse rows,then connect Power2Round and key serialization in
bounded follow-ups. Establish exact public/secret-key outputs before Sign/Verify
and before PPA/full-system UVM optimization. Keep the accepted engine RTL,
LightHD-shaped four banks,one launcher/script and universal documentation.
No new commit,branch change,synthesis or netlist simulation is part of this gate.

## 1. Purpose and current status

**Current user decision (2026-10-20): functionality first.** Stop the Stage2
timing optimization campaign and proceed with incremental integration. Establish
correct outputs through memory, NTT, processing and full KeyGen/Sign/Verify
before optimizing Fmax, placed area and throughput in Stage7. The existing
6.757 ns synthesis constraint remains a benchmark; meeting it is not a gate
before Stage3. This supersedes the earlier timing-first instruction.

**Integration means the Dilithium project.** This is the shared roadmap for
connecting our accepted Keccak, sampler and NTT, building the controller and
memory, adding the remaining processing blocks, and verifying the complete
accelerator. Do not create a second plan for the same work under another name.

The working branch is `integration`, created from `sampler_v1` at `e1b9c84`.
The sampler is already present. Its accepted Stage4.9r implementation has
3537 actual placed ALMs, 164.74 MHz worst Fmax, +0.430 ns setup and +0.141 ns
hold at a 6.500 ns constraint. Stage5 source, post-synthesis and post-fit checks
passed. These are **standalone sampler results**, not integrated design metrics.

Keccak is imported from `keccak_v2` at `fe54a78` and its standalone relocation
checks pass. NTT is imported from `ntt_v2` at `577a34b` with its standalone
UVM,reference,simulation,Quartus and documentation assets. Complete encoded
KeyGen now passes local software-reference checks in the Stage5L full-key mode.
Sign/Verify and official full-KeyGen vector conformance remain next.
The active four-bank memory supersedes the preserved Stage3 scalar pool.
See SPECIFICATION.md for exact snapshot provenance.

The user has approved this structure and incremental import approach and has
authorized incremental integration. Ask before major architecture decisions,report what
was done and verified at each stage,and always state the next step. Do not
commit or push subsequent work without an explicit request.

## 2. Agreed folder structure

```text
src/
  keccak/                         # Keccak RTL, imported when needed
  ntt/                            # NTT/INTT/PWM/Pre-NTT RTL
  sampler/                        # Accepted sampler RTL
  controller/
    memory.sv                     # Active four-bank ownership/packing controller
    keygen.sv                     # KeyGen scheduling;polynomial phase implemented
    sign.sv                       # Planned Sign FSM,added when implemented
    verify.sv                     # Planned Verify FSM,added when implemented
    dilithium.sv                  # Main operation FSM
    process/                      # P2R,Decompose x4,CNB,Mhint,Bitpkg,etc.
    memory/                       # Four-bank/BRAM implementation primitives
    datapath/                     # Shared Keccak/sampler/NTT/row connections
    helpers/                      # Seed collection and row command scheduling
    legacy/                       # Preserved older scalar-pool regression helpers

tb_uvm/
  tb_uvm_reusable/                 # Shared reusable verification components
  <individual module UVM folders>/
  tb_uvm_dilithium/                # Full Dilithium UVM, when that stage begins

tb/
  tb_dilithium/                    # Focused integration testbenches as needed

sim/
  keccak/                         # Individual Keccak simulation
  ntt/                            # Individual NTT simulation
  sampler/                        # Individual sampler simulation
  dilithium/                      # Evolving full-design simulation project

quartus/
  keccak/                         # Individual Keccak synthesis project
  ntt/                            # Individual NTT synthesis project
  sampler/                        # Individual sampler synthesis project
  dilithium/                      # Evolving full-design synthesis project

docs/
  keccak_docs/                     # Imported module documentation/evidence
  ntt_docs/                        # Imported module documentation/evidence
  sampler_docs/                    # Existing module documentation/evidence
  dilithium_docs/                  # Universal full-design documentation
    DILITHIUM_PLAN.md
    ...
```

Use the spelling `controller` consistently. `dilithium.sv` is the main
controller/top. Operation FSMs live beside it;shared helpers use the subfolders
above. All processing arithmetic and formatting belongs under
`src/controller/process/`. Sign/Verify and remaining process files are added
with working logic at their implementation steps. Additional files must have a
clear purpose rather than forcing an entire subsystem into one large file.

Testbench source belongs in `tb/` or `tb_uvm/`, RTL in `src/`, launchers and
generated simulation output in `sim/`, and synthesis projects in `quartus/`.
Create folders and runnable scripts when used; do not create empty test launchers.

## 3. Import an individual module as a complete package

Bring modules in as integration reaches them. Each import includes:

1. The selected accepted RTL and required ROM/table/initialization files.
2. Its existing UVM testbench and independent reference/checking assets.
3. Its standalone simulation launchers and required vector/reference files.
4. Its standalone Quartus project, constraints and synthesis helper scripts.
5. Its module documentation and relevant accepted evidence.

Keep standalone module verification and synthesis runnable on this branch.
Retain each module's existing UVM folder name unless an actual naming conflict
requires a documented change. Map imported RTL to `src/keccak/` and `src/ntt/`,
and update file lists, relative paths, include paths, ROM paths and project
assignments. Check for package/module/library collisions before compiling all
three together. Re-run the relevant standalone checks after relocation.

Record branch, commit, original paths, destination paths, changes and verification
in the shared Dilithium specification. Preserve frozen imported evidence exactly;
its historical paths and standalone metrics describe the original build. New
verification records must identify the relocated build separately.

Do not merge whole branches or import historical experiment trees and obsolete
generated databases merely to obtain a module. Preserve the accepted branches.
The evolving `sim/dilithium/` and `quartus/dilithium/` projects must use the current
combined source set as each part is added.

## 4. One documentation set for all integration milestones

All integration work updates **the same documents in `docs/dilithium_docs/`**.
A Keccak-to-sampler milestone and a later memory-to-NTT milestone are sections
of these documents, not separate documentation suites. Individual imported
module documentation remains under its own module folder for standalone use.

| Document | Contents and when to create/update it |
|---|---|
| DILITHIUM_PLAN.md | This roadmap, agreed structure, stages, current status and next work |
| README.md | Navigation, actual simulation/synthesis commands and current supported scope |
| SPECIFICATION.md | Supported algorithm/version/parameters, exact imported snapshots, ports, reset/clock and command contracts |
| ARCHITECTURE.md | Datapath, controller, adapters, routing and memory connections |
| PROCESS_FLOW.md | Step-by-step data movement, scheduling and eventual KeyGen/Sign/Verify sequences |
| PROCESS_BLOCKS.md | Purpose,math,representations,interfaces,status and verification of arithmetic/rounding/hints/norms/packing/hash-format blocks |
| MEMORY_MAP.md | Polynomial layout, banks/ports, allocation, addresses, lifetimes, ownership and arbitration |
| INTEGRATION_VERIFICATION_TESTPLAN.md | Full-design requirements, independent checking, tests and later detailed UVM/coverage plan |
| THROUGHPUT.md | Measurement boundaries, cycles, stalls, loading/compute/output time, system throughput, placed ALMs, Fmax and slack |
| COVERAGE.md | Functional/code coverage, bin-hit justification, observed gaps and implementation-verification scope |
| PIN_CONFIG.md | Full-design top-level virtual pins, widths and meaning; physical assignments only when actually selected |
| REFERENCE_VERIFICATION.md | Reference provenance, vectors, file formats, preparation/capture/comparison commands and measured results |

Create each document when its work becomes concrete and maintain it throughout
the project. Do not fill documents with invented results or runnable placeholders.
Separate proposed targets, standalone historical metrics and measured system data.
Store only useful milestone evidence; avoid a new JSON/archive for every small trial.

## 5. Initial architecture and interface decisions

The starting datapath is:

```text
Commands / seeds / messages
             |
    dilithium.sv controller
      | scheduling / memory ownership / error handling
      v
 Keccak -> Sampler -> Polynomial memory <-> NTT/INTT/PWM/Pre-NTT
                            ^
                            |
                  controller/process blocks
```

This is a starting structure; finalize the detailed contracts before wiring it.

- Keep Keccak's shared 64-bit input and tagged 128-bit output interfaces.
  The current sampler accepts 128-bit beats and processes ordered 64-bit chunks
  internally. This does not become native128 sampling merely through connection.
- Associate the sampler job with Keccak's actual accepted core assignment.
  Maintain the complete job ID, sampling mode, parameters, seed/nonce and
  destination. A core/context number alone is not a permanent polynomial ID.
- Define continuous SHAKE operation, sampler completion/stop requests,
  already-offered output handling and safe context reuse. Finite-source handling
  must not repeat SHAKE prefixes, insert zero padding or silently truncate data.
- Resolve reset conventions at the top level. Preserve each module's defined
  reset behavior and verify cancellation, draining and subsequent fresh work.
- Keep canonical 23-bit residues at the current sampler/NTT boundary. Check
  transform ordering, modular representation and scaling explicitly when
  comparing software; do not equate an intermediate Montgomery representation
  with canonical coefficients without the required conversion.
- Matrix A sampling already produces transform-domain values. Route them to
  operand storage/PWM, not through an unnecessary forward NTT. Ordinary secrets
  can use forward NTT or the existing eligible Pre-NTT operation. Assign one
  owner for Pre-NTT so its first stage is never applied twice.
- Use one shared clock initially, with an operating target selected from the
  imported modules' constraints and actual integrated timing. Standalone sampler
  Fmax is not an integrated Fmax guarantee.

### Memory decisions to settle before implementation

The sampler can interleave two jobs; the current NTT wrapper handles one complete
operation at a time and transfers one 23-bit coefficient per beat. Use memory
to separate polynomial ownership and production/consumption schedules.

Define 256-coefficient polynomial storage, coefficient addresses, domain metadata,
slot allocation and states such as free/writing/complete/in-use. Set the actual
bank/slot count from the first workload and expected live ranges. Do not invent
a large all-parameter memory allocation before deriving capacity and port demand.

Mark a sampled polynomial usable only after successful completion. Invalidate
partial results on errors/abort. Track both PWM operands, writeback ownership,
simultaneous read/write hazards and reset/reuse. Preserve input polynomials still
needed by later operations. Add ping-pong storage or more ports when measurements
justify them. Wider NTT ports and deeper queues are later measured changes.

## 6. Execution stages and completion gates

Announce the stage before starting it. Work in bounded steps and update these
universal docs after each meaningful milestone. A passing subset must not be
reported as complete Dilithium or complete verification.

| Stage | Work | Evidence required before moving on |
|---|---|---|
| 1 — Contracts and imports | Inspect accepted snapshots, import Keccak with its standalone assets, define commands/reset/tags and initial memory contracts | Relocated standalone checks pass; interface and source provenance documented |
| 2 — Keccak + sampler | Feed real SHAKE outputs into all four sampling modes; handle two contexts, stop/drain, valid bytes and backpressure | Seeded polynomial outputs match independent expectations; ordering, context reuse, reset and errors checked |
| 3 — Memory | Implement memory.sv, allocation, write/read paths, completion validity and arbitration | Exact polynomial readback; no mixing, overwrite, stale reuse or premature reads under stalls/abort |
| 4 — NTT integration | Import accepted NTT with all standalone assets; connect load/command/result paths through memory | Sampled/transformed outputs and polynomial operations match software with explicit domain/scaling conventions |
| 5 — Controller and remaining processes | Build dilithium.sv scheduling and required process blocks; begin with sequential operation schedules | Each added process and full supported flow produces independently checked outputs; rejection/retry and error handling exercised |
| 6 — Full-operation reference/NIST flow | Complete the supported KeyGen/Sign/Verify interfaces and file-based capture/comparison | Exact official-vector comparisons for the declared algorithm/parameter/mode; limitations and unsupported cases explicit |
| 7 — Full UVM and synthesis optimization | Build comprehensive Dilithium UVM/coverage, synthesize the whole design and improve timing/area/throughput | Correctness retained; detailed functional/code coverage and honest gaps; fresh measured PPA and positive timing at the agreed operating clock |
| 8 — Implementation and FPGA verification | Verify distinct whole-design synthesis/fit netlists, then board interfaces and hardware testing | Implementation checks and timing reports; FPGA results only after actual execution |

The remaining processing work includes polynomial add/subtract, matrix-vector
accumulation, rounding/Power2Round, decomposition, norm checks, hint creation/use,
packing/unpacking, signing rejection/retry control, and seed/nonce/message/key
handling. Define and verify the exact required subset as each algorithm flow is
implemented. Three connected engines alone do not implement all these functions.

### Testing during integration

Focused, efficient non-UVM integration testbenches are explicitly allowed.
Use them to supply real jobs, exercise boundary conditions, dump outputs and
compare with independent models. They must be self-checking and reproducible.
They do not replace the imported standalone UVM suites or justify later full
UVM coverage claims. Keep focused testbench source under `tb/tb_dilithium/`.

After one connection produces the required outputs, add the next block and
repeat independent checking. Start with serial schedules to make faults easy
to locate. During the later optimization stage, overlap sampling, arithmetic
and memory traffic only with ownership/dependency checks and measured benefit.

The full-fledged Dilithium UVM campaign and primary PPA optimization follow
correct end-to-end outputs and the full-operation reference/vector milestone.
Earlier compile/synthesis checks may establish feasibility, RAM inference and
resource limits; they do not imply that full verification or optimization is done.

### Full-operation vector flow

Use the same explainable pattern as Keccak: input vectors -> RTL execution ->
captured outputs -> a separately executed Python comparison command -> explicit
PASS/FAIL with case counts and mismatch details. Keep the reference independent.

At that stage obtain official NIST/ACVP full-operation vectors and record exact
source/version/provenance. The user selected final FIPS204 ML-DSA-44/65/87,
retaining level2/3/5 names (parameter encodings0/1/2). Define exact
message/context formatting and supported operation interfaces. Never silently
mix incompatible vectors or assume legacy reference code is a full FIPS oracle.
Control the specified seed/randomness inputs for exact randomized-operation
comparisons; verification vectors require correct accept/reject outcomes too.

Do not claim official standalone sampler or NTT vectors. Their existing
FIPS-derived/reference checks remain useful component evidence. Full-operation
vector equality is not itself NIST validation or certification.

### Later full UVM, synthesis and optimization

Define the complete feature/test/coverage plan, then exercise modes/parameters,
command sequences, queues, memory hazards, concurrent jobs, stalls, invalid
requests, reset/abort/recovery and signing retries. Credit successful functional
observations only after independent checking. Report raw and averaged coverage
metrics clearly; do not fabricate bins or suppress hits to impose a percentage.

Measure full command-to-completion latency and sustained completion interval,
SHAKE/sampler waiting, memory occupancy/conflicts, NTT load/compute/output and
controller overhead. Report actual placed ALMs, registers, RAM/DSP, worst Fmax,
constraint and worst-corner setup/hold/TNS. Standalone virtual-pin closure is
not board I/O closure. Preserve correctness while improving measured bottlenecks.

The full design will have three main `.do` launchers when implemented: source
UVM with GUI/waves/functional and code coverage, post-synthesis, and post-fit.
Focused early tests can use selectable modes or supporting Tcl/scripts in the
same `sim/dilithium/` project. Use supported vendor functional netlists and
TimeQuest timing evidence; do not promise unsupported Cyclone V SDF simulation.

## 7. Next action and status tracking

**Active Stage5H:reusable row multiply/accumulate scheduler PASS.**
row_accumulate plus keccak_sampler_row schedule one complete staged matrix row
through the single existing NTT/process/bank subsystem. Source descriptors cover
4/5/7 columns at levels2/3/5. Sources are validated/leased before any arithmetic.
First PWM writes the accumulator;later PWMs use one reusable scratch region,
followed by explicit destructive ADD back into the same accumulator. Scratch
is released after each addition. The final inverse NTT produces coefficient-
domain u_i=(A*s1)_i;the accumulator is then released for the next row. Retained
matrix/secret operands are not overwritten. No new polynomial RAM or engines.

The new process_inplace_i flag is explicit and defaults to0 in existing tests.
The store permits private reads only beyond the rewritten coefficient frontier;
both source words are cached before any lane is overwritten. A reset invalidates
the partially rewritten accumulator. This supersedes the earlier distinct-result-
only limitation;the ordinary process/P2R commands retain their existing behavior.

Source/Python/C PASS:13 completed rows,27 expected rejections,7 reset aborts;
163 real SHAKE/sampling jobs,161 NTT/Pre/PWM/INTT commands,55 in-place additions.
96264 scalar writes,24066 packed writes/acks,12544 exact92-bit public readbacks
and6918 old-word cache reads are checked. Six full reference rows also agree
with independent coefficient-domain schoolbook multiplication.26 deliberate
capture corruptions are rejected. Stored transformed secrets are reused across
two different matrix rows per level;eligible secrets exercise Pre-NTT too.
All ten earlier source gates and checker selftests freshly PASS. Create-only
evidence:evidence/stage5h_row.zip and stage5h_row.sha256;earlier archives remain
unchanged. Member hashes/bytes and archive CRC are verified.

Use selector5/row and Python --stage 5 --unit row. The default/Quartus top remains
the preserved scalar baseline;no new PPA or full-system UVM result. Next bounded
step:connect shared seed expansion and seed/nonce message formatting to the
KeyGen sampling schedule,then add s2 to each u_i,Power2Round and final key byte
encoding/reference comparison. Full KeyGen output is still unimplemented.

**Prior Stage5G:banked ADD/SUB/Power2Round and NTT chains PASS.**
poly_process_dma shares the existing four banks through the optional
PROCESS_SERVICE=1 path in keccak_sampler_ntt_banks. Sampling,NTT and processing
have exclusive sequential ownership. ADD/SUB require matching domains/parameters;
Power2Round requires coefficient domain. Source leases and explicit destination
checks apply throughout. Power2Round writes canonical low modulo q and high
into two distinct caller-selected regions,using the two existing packers.
Both outputs become visible together after acknowledged commit;both remain
protected while their completion is held. No extra polynomial payload RAM.

23 actual sample jobs,15 NTT commands and71 process commands pass:34 process
successes,33 expected rejections and4 reset aborts. Python and C independently
match8976 completed arithmetic results from8978 accepted process inputs.
The full ledger checks22297 scalar writes,5574 packed writes/acknowledgements
and8512 exact92-bit readbacks. Stored canonical low parts feed real forward NTTs.
Twenty-nine checker corruptions are rejected,including missing high-part commit
and partial-publication evidence. See REFERENCE_VERIFICATION.md for execution.
All nine earlier source gates/checker selftests are freshly revalidated. Frozen
evidence:evidence/stage5g_bank_process.zip and stage5g_bank_process.sha256,
with create-only archive/checksum writes and verified per-member hashes.

Use selector5/bank_process and Python --stage 5 --unit bank_process. The legacy
default4/Quartus top and all earlier selectors remain available;PROCESS_SERVICE
defaults to0 for the preserved banked NTT-only test. No full KeyGen,NIST/UVM
coverage or new PPA result is claimed. Next bounded step:row multiply/accumulate
scheduling over the verified PWM/ADD/INTT path,then connect real seed/nonce
formatting and key encoding in the first level2 KeyGen controller. Functionality
remains first;no new timing campaign is authorized by this milestone.
Stage5H above adds explicit destructive row accumulation and the first row
reuse schedule. Full KeyGen/Sign phase lifetimes remain to be derived/verified.

**Prior Stage5F:real sampling -> four banks -> NTT -> four banks PASS.**
keccak_sampler_ntt_banks adds sequential word DMA and result packing around the
unchanged NTT engine. Each92-bit read supplies four23-bit engine beats;PWM loads
A then B. Accepted source leases block release through completion retirement.
Caller-selected destination must differ from the sources;an occupied destination
waits while unrelated regions can be released. Completion waits for all256 results,
64 physical write acknowledgements and engine completion. A held result cannot
be released before its completion handshake. No new hash/NTT cores are added.

16 real sample jobs and54 compute commands pass:30 results,21 expected rejections
and3 reset aborts. Independent Python checks4096 sample coefficients,9746 DMA
values,7712 NTT outputs,2952 packed writes/2951 acknowledgements and2944 exact
92-bit readbacks. Same/different-bank operands/destinations,all four banks,
all four operations/three parameters,round trips,source preservation,Pre bounds,
ID/domain/parameter/alias errors,occupied destinations and reset recovery pass.
Nineteen deliberately corrupted captures are rejected. These are focused source
checks,not full-operation NIST,UVM coverage or new synthesis/PPA results.
All eight earlier focused gates and checker selftests were freshly rerun PASS.
Create-only evidence:evidence/stage5f_bank_ntt.zip and stage5f_bank_ntt.sha256;
preserve the earlier checkpoints unchanged.

Run selector5/bank_ntt and Python --stage 5 --unit bank_ntt,as documented in
REFERENCE_VERIFICATION.md. Default selector4 and the Quartus top remain the
preserved scalar baseline;the banked full connection has its own explicit selector.
Stage5G above connects bank reads/writeback to modular ADD/SUB/Power2Round.
Next:build row accumulation and the first level2 KeyGen schedule around the
verified hash/seed service. Full key encoding and whole-operation comparison
remain required. Optimize PPA after functionality,as already agreed.

**Prior Stage5E:real sampling -> packed banks -> protected readback PASS.**
keccak_sampler_banks connects the existing producer to bank_poly_store and the
four banks. The caller selects aligned bank/region destinations;two packers
keep contexts separate. Publication waits for256 coefficients,64 write acks
and successful external status. Reads/releases check committed ownership and
hold metadata through stalls.104 jobs pass:88 complete,8 expected errors,
8 reset aborts;5632 exact92-bit words=22528 completed coefficients read back.
All64 regions/24 core-mode-parameter combinations,occupied-region stalls,
reuse and reset recovery are covered. Eight malformed write/status fault kinds
are contained;12 capture corruptions rejected. No new PPA/UVM coverage claim.
All seven earlier gates were freshly rerun with passing checker selftests.
Preserved evidence:evidence/stage5e_bank_store.zip plus its create-only SHA256
sidecar;115 manifest/member bytes verified. Keep earlier archives unchanged.

Stage5F above completes NTT word-read DMA,source leases and packed result
writeback. The preserved sampling-only gate remains selector5/bank_store.
No full KeyGen/controller/process migration is claimed by the storage gate.

**Prior Stage5D:LightHD memory selected;four-bank foundation PASS.**
The user answered the storage question:"whatever LightHD is doing do that".
Adopt the paper's four logical1024x92-bit dual-port banks,retained secret data
and row-by-row temporary reuse. This supersedes both scalar-pool proposals;
do not automatically add their extra encoded-key buffers. Final FIPS204 bytes
with level2/3/5 names stay selected. MEMORY_MAP.md now gives the published
dimensions,Figure2 peak Sign regions,and the migration boundaries.

poly_bram.sv/memory_banks.sv pass14872 requests,9509 exact92-bit reads,5355
write acknowledgements,8 reset-aborted acknowledgements and12 checker faults.
All4096 words are covered,with independent ports,collisions,stalls and reset
retention. This is the bank foundation only;the Stage4 top remains on its old
four-slot pool pending migration. No new physical RAM/PPA result is claimed.

**Prior Stage5C:shared raw-SHAKE and seed collection source/reference PASS.**
The existing keccak_sampler now supports optional finite raw hashes through the
same two physical cores. keygen_seed_collect retains rho/rho-prime/K until
accepted. The focused gate passes26 commands,1699 exact SHAKE bytes and1792
coefficients sampled from RTL-collected seeds. Twelve checker corruptions are
rejected. Both raw/raw and raw/sampling ownership,stalls,arbitration,rate-boundary
short beats and three reset/recovery cases are checked. Main Stage4 wrappers
explicitly disable the optional route;no public port/capacity changes yet.
PROCESS_BLOCKS.md now specifies implemented/planned processing blocks;
MEMORY_MAP.md contains a dimensioned implemented memory diagram and the concrete
next KeyGen storage decision,now resolved in favor of LightHD's four banks.

**Prior Stage5B:final FIPS204 selected;KeyGen message formatter PASS.**
The audit found a mismatch between LightHD's displayed32-byte tr and our local
software's final-format64-byte tr,parameter-bound seed expansion and level-
dependent challenge lengths. The user resolved this on2026-10-20:implement
final ML-DSA-44/65/87 with LightHD-style level2/3/5 names. Keep parameter
encodings0/1/2. SPECIFICATION.md records the mapping and audit;legacy round-3
byte compatibility is not implied by those labels.

keygen_hash_message.sv now builds the final-standard seed-expansion,matrix and
KeyGen-secret messages. Focused real-Keccak/Python checks pass165 commands,
162 completions(including14 expected errors),3 reset aborts,883 absorption words
and5888 SHAKE bytes. All102 matrix positions and34 secret nonces are exercised.
Twelve checker corruptions are rejected. The formatter is not yet connected
to the Stage4 main top;shared raw hash/seed collection now pass Stage5C above.

Independent common arithmetic was implemented under src/controller/process:
modular ADD/SUB and Power2Round.10349 accepted cases/10346 outputs/3 reset aborts/
13 expected errors PASS,with12 checker corruptions rejected. The unchanged C
Power2Round reference passes all8380417 canonical inputs;RTL uses targeted
boundaries/random cases,not an exhaustive8.3-million-value simulation.
Stage5G above now connects the unit to memory;no full KeyGen output is claimed.
Preserved evidence:evidence/stage5a_process.zip and stage5a_process.sha256.
The archive records the pending format/architecture choices explicitly;it is
not a completed Stage5 checkpoint. Earlier Stage2/3/4 regressions were refreshed.

Next:extend the verified banked NTT/process path with shared hash scheduling,
row accumulation and key encoding in the first
level2 controller. The old four-slot/ten-slot plans are superseded. Do not
duplicate Keccak cores or claim LightHD's32-cycle input loading through the
current scalar NTT wrapper. PPA optimization remains deferred.

**Prior milestone:Stage4 NTT integration functional PASS;PPA deferred.**
The real path is Keccak -> sampler -> four-slot memory -> NTT -> memory.
The imported six NTT RTL files and existing UVM remain byte-identical to
ntt_v2:577a34b2fff19864cb16b490b7629ed211613000;path adapters and original/destination
hashes are in ntt_import_manifest.csv. Relocated standalone checks pass748 UVM
jobs/191488 coefficients and18 Python cases/4608 coefficients. These are source
checks;no fresh relocated synthesis or netlist simulation was run.

Focused integration checks16 sampled jobs and50 NTT commands:30 complete,
17 rejected and3 reset-aborted.4096 sampled values,9745 DMA operands,7713 NTT
outputs (7680 complete+33 aborted-prefix values) and11776 stored readbacks match
independent Python expectations. All4 operations,all3 parameter encodings,
source retention,Pre eligibility,domain/ID checks,full-pool waiting,stalls and
reset/recovery at load/compute/writeback pass.12 checker corruptions are rejected.
Stage2/3 remain selectable and independently checked. There is no Stage4 PPA,
full-system UVM,full-operation official-vector or FPGA claim.
Frozen Stage4 source/import/capture evidence:evidence/stage4_subsystem.zip and
stage4_subsystem.sha256. Its manifest distinguishes unchanged imported RTL/UVM,
path adapters and the new integration helper/memory extension.

Stage5 follow-up:the user selected final FIPS204 bytes with level2/3/5 labels;
derive the first level2 KeyGen schedule and polynomial live ranges,then add
required arithmetic/rounding/packing blocks incrementally. Confirm major
algorithm/memory/interface decisions with the user. Do not begin PPA optimization.

**Prior milestone:Stage3 memory functional PASS;PPA optimization deferred.**
The user approved a configurable four-slot pool on2026-10-20. Real
Keccak-sampler outputs now write src/controller/memory.sv through
keccak_sampler_memory.sv.104 jobs pass:88 complete,8 expected errors,8 reset
aborts;23180 exact writes and22528 exact readbacks.88 releases,99 invalid reads,
full-pool backpressure and concurrent reads/writes pass.8 protocol fault kinds
are contained and12 checker corruptions rejected. Stage2 remains reproducible
and passes unchanged. No Stage3 fitted PPA or full-operation output is claimed.
Next:Stage4 accepted NTT package import and memory-to-NTT load/result control.
Frozen source/test/capture evidence:evidence/stage3_subsystem.zip and its
SHA256 sidecar. It contains no Stage3 fitted PPA claim.
Finalize ordering,scaling,representation and operand/destination lifetimes
before arithmetic comparisons. Read MEMORY_MAP.md for the implemented contract.

**Prior milestone:Stage2 functional PASS;148MHz timing target OPEN.**
The real Keccak+sampler helper is implemented under src/controller and exercised
by the focused testbench under tb/tb_dilithium.104 jobs pass:88 complete,
8 expected parameter errors,8 reset aborts,and23089 exact coefficient checks
on the current two-slot registered-credit bridge (trial8 functional source).
All24 mode/parameter/context combinations are observed;12 checker corruptions
are rejected. The user chose about148MHz as the initial combined synthesis
target:6.757ns. The first combined fit has11059 placed ALMs,129.18MHz Fmax,-0.984ns setup
and+0.166ns hold at that unchanged target;the148MHz goal is not met.
Original sampler structural guards pass. Evidence:evidence/stage2_subsystem_initial.zip.
Timing trials are recorded in THROUGHPUT.md. Trial6 cuts the measured sampler
stop/ready path into Keccak using a two-slot register queue;source checking
includes full-queue reset and simultaneous push/pop. The unchanged148MHz
target remains open until a fresh complete fit and structural guards pass.
Clean trial6c reached134.17MHz/-0.696ns at12542 placed ALMs. Active trial7
restores the smaller ordinary clock-enable mapping and predecodes absorb-ready
in each core. Source104 jobs/23089 values and full904-transaction Keccak+dual
regressions and6364-output NIST comparison pass;no added processing cycles.
Trial7 fit still misses at124.72MHz/-1.261ns,but area recovers to11204 placed
ALMs. Active trial8 removes sampler-ready gating redundant with ownership;
104 jobs/23089 values and12 checker faults pass,with identical cycle records.
The completed main seed1 fit reaches137.74MHz worst Fmax at11293 placed ALMs,
with-0.503ns setup and+0.157ns hold at6.757ns;structural guards pass.
Timing remains open and its optimization is deferred by the user's latest
decision. No further timing experiment is required before adding memory.
No polynomial memory,NTT connection,main algorithm controller or full-operation
NIST/UVM completion is claimed. See ARCHITECTURE.md,PROCESS_FLOW.md,
REFERENCE_VERIFICATION.md and THROUGHPUT.md.

**Prior milestone:Stage1 Keccak import and standalone revalidation PASS.**
Keccak RTL/UVM/vector/module-doc assets are imported,with original RTL/UVM
bytes preserved. Path adapters pass the904-transaction source suite plus dual
regressions,and all6364 captured outputs match3182 published NIST cases on
both cores. Fresh standalone Quartus:8058 actual placed ALMs,149.63MHz Fmax,
setup+0.074ns/hold+0.166ns at6.757ns. All four corners have zero setup/hold TNS.
These are standalone metrics from the prior import milestone.
Evidence:evidence/keccak_import.zip+SHA256.

Current source snapshot:keccak_v2 at fe54a782e3df9ed684dc960b0067b39ce323289d.
See SPECIFICATION.md for source provenance,path mapping and initial contracts.
Next:Stage5 controller/process work. Keep the verified functional source and accepted
standalone baselines. The four-slot memory proposal is approved and verified;
later major architecture changes still need agreement. The user selected LightHD's full CRYSTALS-Dilithium
scope:KeyGen,Sign and Verify at all three security levels2/3/5;bring up level2
first. Final FIPS204 was selected explicitly on2026-10-20;choose its official
NIST/reference vector suite. The paper's level names and draft-standard citation
alone do not establish final-byte compatibility. See the
algorithm-scope decision in SPECIFICATION.md. The initial clock is now6.757ns;
later major changes require user agreement.

| Milestone | Revision and workload | Result | Limitation / next action |
|---|---|---|---|
| Stage5L complete encoded KeyGen |8 complete C-reference keypairs,3 rejects,5 aborts |5433 exact key words,2058 PK hash words,656 tr bytes,11179 read metadata records;35 checker faults | Next:official NIST KeyGen vectors,then Sign;no new PPA/full-system UVM claim |
| Stage5K rounded KeyGen and Bitpkg |34 rounded rows;97 packet commands |190224 scalar values,12800 exact92-bit reads,36 rounded checker faults;2482 exact packed words,15 packer checker faults;C66 fixtures/18496 bytes | Next:bank-to-Bitpkg routing,full key field order and public-key hashing;external full-key interface pending |
| Stage5J autonomous KeyGen polynomial phase |14 operations;7 complete,3 rejected,4 aborted;34 t rows |172304 scalar values,8448 exact92-bit reads,29 checker corruptions;all levels/s1/s2/matrix rows | Next:P2R,Bitpkg,public-key hash and complete encoded keys;Sign/Verify remain unimplemented;no new PPA |
| Stage5I seed-driven rows |190 commands;20 seed expansions;163 RTL-formatted samples;13 successful rows |2560 exact SHAKE bytes,1103 absorption words,12544 exact92-bit reads;23 checker faults;all12 focused gates PASS | Command adapter connected;bench schedules work;all s2 nonces/full KeyGen controller and key bytes next;no new PPA claim |
| Stage5H row scheduler |163 samples;161 NTT commands;55 in-place ADDs;12544 exact92-bit reads | Source/Python/C PASS;13 rows,27 rejections,7 aborts;26 checker faults;6 schoolbook reference rows | Staged sequential rows,not full KeyGen;s2/rounding/key encoding and seed scheduling next;no PPA claim |
| Stage5G banked process arithmetic |23 samples;15 NTT commands;71 process commands;8512 exact92-bit reads | Source/Python/C PASS;34 process successes,33 expected rejections,4 aborts;29 checker faults | Sequential process DMA;row scheduling/full KeyGen next;no new PPA/coverage claim |
| Stage5F banked NTT connection |16 real sample jobs;54 compute commands;2944 exact92-bit reads | Source/Python PASS;30 results,21 rejections,3 aborts;19 checker faults | Sequential scalar engine DMA;banked process/row scheduling next;no new PPA/full KeyGen claim |
| Stage5E sampled polynomials in packed banks |104 jobs;5632 completed92-bit read words | Source/Python PASS;88 successes,8 errors,8 aborts;8 protocol faults contained;12 checker faults | Sampling/storage connected;NTT DMA and compute leases/writeback next;no PPA claim |
| Stage5D LightHD memory foundation |Four1024x92-bit dual-port banks;14872 requests | Source/Python PASS;9509 exact reads,5355 acks,8 reset aborts;12 checker faults | Foundation only;controller/DMA migration next;no RAM inference/PPA claim |
| Stage5C shared raw hash and seed collection |26 commands;18 raw requests;7 sampler jobs;1699 SHAKE bytes;1792 coefficients | Source/Python PASS;7 seed results including1 error,3 resets;12 checker faults | Optional route tested;main top unchanged;memory choice subsequently resolved to LightHD banks |
| Stage5B KeyGen message formatting |165 commands;883 absorption words;5888 real-Keccak output bytes | Source/Python PASS;102 matrix positions,34 secret nonces;14 errors,3 resets;12 checker faults | Isolated formatter;shared raw-hash routing/seed collection next;no main KeyGen/PPA claim |
| Stage5A shared arithmetic |10349 accepted arithmetic/framing cases;exhaustive C rounding reference | Source/Python/C PASS;10346 outputs,3 aborts,13 errors;12 checker faults | Not memory-connected;not exhaustive RTL rounding or full KeyGen |
| Stage4 NTT package and memory datapath |748 standalone UVM jobs;18 Python cases;16 integrated sample jobs/50 commands/11776 readbacks | Source/Python PASS;30 NTT results,17 rejections,3 reset aborts;12 checker faults | No Stage4 PPA/full-operation claim;next algorithm audit and Stage5 controller/process work |
| Stage3 polynomial memory |104 jobs;23180 write checks;22528 readbacks;8 injected memory faults;12 checker corruptions | Source/Python PASS;four slots,ownership,commit,read/release,reset/reuse | Historical memory gate without synthesis/PPA;NTT added in Stage4 |
| Stage1 Keccak package relocation | keccak_v2 fe54a782e3df9ed684dc960b0067b39ce323289d;904 source UVM transactions plus dual suites;3182 NIST cases per core;full standalone Quartus compile | PASS;RTL/UVM unchanged;6364 exact NIST matches;positive multicorner timing | No new netlist simulation or connected datapath. Next:Stage2 adapter and user-confirmed major decisions |
| Stage2 real Keccak-sampler source connection |104 generated subsystem jobs;88 complete,8 expected errors,8 aborts;23089 exact values;12 checker faults | Source/Python PASS;four reset phases,stop/drain,backpressure and same-ID recovery exercised | Current main fit11293 placed ALMs/137.74MHz/-0.503ns setup at6.757ns;structural guards PASS;timing optimization deferred;next Stage3 memory |

Maintain a concise milestone table here with the stage, source revision,
workload, explicit check result, measured limitations and next action. Keep the
same specification, process, memory, throughput and verification documents as
the system grows; do not start a parallel suite for each pair of modules.
