# Dilithium integration (`integration`)

Stage5N.3 connects Decompose/CNB/Mhint to the existing main-owned shared banks
through sign_process_dma. It checks read ownership/metadata,canonical result
storage,late-error rollback,source/result leases and acknowledged atomic
Decompose publication. New DMA and shared-service gates pass at levels2/3/5;
the latter uses real SHAKE/sampler sources. Exact counts/run commands are in
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).
Next:signing key/input decode and hash formatting,then retrying Sign control.
Main Sign/Verify and whole-system UVM/PPA remain pending. The following earlier
milestone paragraphs describe their historical implementation boundaries.

Stage5N.2 adds verified Decompose x4,CNB and Mhint arithmetic with tagged
polynomial transport.7752 x4 groups and117 complete polynomials are checked;
local KeyGen and all75 official NIST keypairs still pass. Next connect these
new processes to shared memory DMA,then continue Sign. Main Sign/Verify are
not implemented yet;the universal docs below describe the exact boundary.

Stage5N.1 now places the shared engines,banks and Bitpkg under the main
controller,with KeyGen as an operation client. All75 official KeyGen cases,
the local reset/recovery suite and both polynomial diagnostic modes pass.
Next:Decompose x4,CNB and Mhint,then further Sign integration. The universal
docs linked below hold the current architecture and evidence.

Current full-KeyGen RTL uses FULL_KEYGEN=1 and produces complete encoded
public/secret keys at levels2/3/5. Stage5L matched the independent C reference
and preserved all16 integration gates. Stage5M passes all75 official NIST KeyGen
cases through the same launcher/script;433600 key bytes match. See commands in
[REFERENCE_VERIFICATION.md](docs/dilithium_docs/REFERENCE_VERIFICATION.md).
Sign/Verify and whole-system UVM/PPA remain later work. Earlier stage summaries
below are historical milestones.

Canonical roadmap: [DILITHIUM_PLAN.md](docs/dilithium_docs/DILITHIUM_PLAN.md).
It records the agreed controller/process/memory layout, incremental module
imports with their standalone assets, universal Dilithium documentation, and
the progression from focused integration tests to full-operation vector checks
and comprehensive UVM/synthesis optimization.

Stage1 Keccak import is verified:904 source UVM transactions plus dual suites,
6364 exact NIST output matches,and a fresh standalone Quartus timing PASS.
See [SPECIFICATION.md](docs/dilithium_docs/SPECIFICATION.md) for provenance and
placed-area/timing results. Stage2 now connects real Keccak to the sampler:
104 source jobs/23089 coefficient checks and12 checker fault cases pass.
See [the shared integration docs](docs/dilithium_docs/README.md) for the current
architecture and run commands. The initial combined clock target is148MHz;
the initial combined fit reaches129.18MHz,11059 placed ALMs and?0.984ns setup.
Timing at148MHz remains open. On2026-10-20 the user chose functionality-first
integration, with Fmax/area/throughput optimization after correct full-operation
outputs. The6.757ns benchmark stays unchanged;it does not block Stage3 memory.
Major architecture decisions will be confirmed with the user.

The user approved the four-slot pool;Stage3 now connects Keccak,sampler and
polynomial memory.104 jobs pass with23180 write checks and22528 exact readbacks.
Stage4 now adds the accepted NTT package from ntt_v2:577a34b and its standalone
assets. The default simulation exercises all three engines through memory:
50 commands,30 arithmetic results,17 rejections,3 reset aborts and11776 exact
stored readbacks PASS. See the shared docs for `compare --stage 4` and preserved
Stage2/3 modes. Next:Stage5 algorithm audit/controller/process work.
Quartus points to keccak_sampler_ntt;Stage4 has no fresh fit or PPA claim.

Stage5A adds the shared ADD/SUB/Power2Round unit under controller/process:
10349 accepted cases,10346 exact outputs,3 reset aborts and13 expected errors
PASS. Select DILITHIUM_STAGE=5 for its isolated gate. The user selected final
ML-DSA-44/65/87 bytes with level2/3/5 labels. Stage5B adds a checked seed/nonce
message formatter:165 commands,5888 exact SHAKE bytes. Full KeyGen and shared
main-controller scheduling remain work in progress;see the shared docs for commands.
Stage5C now verifies optional shared raw-SHAKE routing and seed collection using
the same two hash cores:26 commands,1699 exact hash bytes and1792 coefficients
sampled from RTL-collected seeds PASS. Main Stage4 top still disables the raw
client;KeyGen storage is now selected as LightHD's four1024x92-bit banks. The
bank foundation passes14872 requests/9509 exact reads;controller migration is
in progress. Stage5E now stores real sampled polynomials through per-context
packing/ownership:104 jobs,88 complete,5632 exact92-bit readbacks PASS. NTT
DMA/compute ownership is next;the default all-engine Stage4 baseline is retained.
PROCESS_BLOCKS.md and the
dimensioned MEMORY_MAP.md diagram are in docs/dilithium_docs/.

## Accepted sampler baseline

Accepted main design: **Stage4.9r — 3537 placed ALMs,164.74 MHz worst Fmax**.
Setup +0.430 ns,hold +0.141 ns at permanent6.500 ns;3931 registers,one M10K,zero DSP.
Main UVM621 complete/182 expected errors/51 aborts/159628 comparisons passes.
Functional coverage95.99%;raw DUT code coverage95.53%,with gaps left visible.

## Run it yourself

1. Open `quartus/sampler/sampler.qpf` in Quartus; **Processing → Start Compilation**.
   No SDC/QSF edits are needed.
2. In Questa GUI Transcript,from `sim/`: `do sampler/run_uvm.do`.
   Waves,functional coverage and DUT code coverage use the main UVM.
3. Independent vectors: `python FIPS204_SAMPLER/sampler_vectors.py prepare`;
   set `SAMPLER_MODE vectors` before the same .do,then run the Python `compare` command.

## Layout

| Folder | Contents |
|---|---|
| src/sampler | Accepted RTL |
| tb_uvm/tb_uvm_sampler | Main UVM and independent references |
| tb_uvm/tb_uvm_reusable | Common reusable templates |
| sim/sampler | Three .do launchers and current verification results |
| quartus/sampler | Project,constraints,current fit/timing reports and database |
| FIPS204_SAMPLER | One Python reference/vector script and input/expected files |
| docs/sampler_docs/post_midyear | Current design and verification documentation |

Start with [SAMPLER_PLAN.md](docs/sampler_docs/post_midyear/SAMPLER_PLAN.md).
Frozen evidence: [STAGE4_9R_RESULTS.json](docs/sampler_docs/post_midyear/STAGE4_9R_RESULTS.json)
and its self-contained evidence archive. Stage 5 accepted-build synthesis/fit verification passed:184 jobs and39936
coefficient checks per netlist;104-job captures match Python and source exactly.
See docs/sampler_docs/post_midyear/SAMPLER_NETLIST_RESULTS.json; Keccak/sampler/NTT integration follows separately. Native128 processing
is not active;the128-bit interface issues64-bit chunks internally.
