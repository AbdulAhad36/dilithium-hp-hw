# Dilithium integration plan

## Current objective and scope

Maintain correct KeyGen, Sign and Verify for final ML-DSA-44/65/87, using level
names 2/3/5. The current functional interface includes external pure messages
and internal formatted messages. Next physical work targets 150+ MHz with
positive worst-corner setup slack, while improving measured operation times
and rates. Area reduction is secondary to those objectives beyond fitting the
same Cyclone V. No new optimization or board-acceptance work is started by the
documentation/naming cleanup.

## Workspace organization

```text
src/
  keccak/                         reusable engine
  ntt/                            reusable engine
  sampler/                        reusable sampler
  controller/
    dilithium_fpga.sv              production boundary
    dilithium.sv                   main owner/FSM
    keygen.sv, sign.sv, verify.sv   operation schedules
    datapath/                     shared adapters/DMA/engine connections
    helpers/dilithium_pkg.sv       request types and fixed roles
    memory/                       RAM, ports, routing and ownership
    process/                      P2R, Decompose, CNB, hints, packing
tb/tb_dilithium/                   capture benches; unit/reference/support
tb_uvm/tb_uvm_dilithium/            reusable full-operation UVM
sim/dilithium/                     current launchers, fixtures and captures
quartus/dilithium/                 current production synthesis project
docs/dilithium_docs/               universal current integration documents
```

Individual module RTL, UVM, simulation, synthesis and documentation packages
remain reusable. Bring all relevant package parts when importing another module.
Do not create a separate universal document set for each pair of integrated
modules: integration means the same complete Dilithium project.

## Current files and historical evidence

Use descriptive stable names for the active design: `main_inputs.txt`,
`main_outputs.txt`, `uvm_inputs.txt`, `uvm.ucdb`, `run.do`, `run_uvm.do` and
`dilithium_full.qpf`. See the simulation README for the exact catalog.
Active documentation describes the present design, not a succession of builds.

Before replacing an accepted implementation, preserve its exact RTL, constraints,
source identity, tests/captures and measured results in the existing evidence
area. Historical evidence may use its build identifier; preserve frozen names
and hashes. Promote a verified improvement into the same normal active paths;
do not accumulate numbered production copies. Summarize the replaced or rejected
build in [PAST_BUILDS.md](PAST_BUILDS.md), including change, result and disposition.
Retain meaningful evidence, not a new archive/script/JSON for every small edit.

## Execution and gates

1. Keep the current functional chain and file-comparison flow reproducible.
   Verify the selected NIST inputs and exact keys, signatures and verdicts.
2. Expand full UVM verification for the current interface, including both message
   modes, stalls, malformed frames, reset/recovery, repeated IDs and operation
   transitions. Report genuine functional and enabled code-coverage gaps.
3. Optimize timing and operation rates using the workflow below. Update universal
   docs only for meaningful verified improvements or architecture decisions.
4. With the user's acceptance, qualify the selected current source using
   post-synthesis and post-fit simulation. Do not infer these results from RTL.
5. With a separate user gate, implement the physical board/host interface,
   choose a timing-clean operating clock, program the FPGA and compare actual
   on-chip outputs against software/NIST expectations.

Do not silently advance to netlist/FPGA acceptance. Ask for major architectural
or public-interface decisions; routine implementation work is authorized.
Do not commit, push or switch branches without instruction.

## Efficient improvement workflow

Read routed timing reports before choosing changes. Find several dominant
path families and batch 3-4 substantial related changes into one candidate.
Preserve the qualified fallback. Run focused fast simulation, then synthesis
and structural checks for retained pipelines, correct RAM/DSP inference and
shorter cones. Reject weak candidates before one full fit. Use one placement
seed initially and reuse the fitted database for additional timing reports.
Reserve full NIST/UVM regression for candidates intended for retention.

Retain reusable compiled libraries/databases. Skip programming-file generation
for timing experiments when not needed; use supported parallel compilation
and carefully scoped incremental compilation where beneficial. Avoid competing
heavy jobs. Keep device, clock/hold constraints and worst-corner reporting;
never manufacture closure with false paths or selected fast corners.

Targeted pipelines are authorized when measured operation time or throughput
improves despite added clocks. Compare actual final placed ALMs, all four
corners' Fmax/setup/hold, and measured clocks/rates. A synthesis estimate is
not a fitted Fmax. A different source revision needs its own physical results.

## Future integration/performance work

Prioritize measured command/admission fanout, hash ingress/egress scheduling,
sampler/memory retirement and Process/formatter/unpack readiness cones. Preserve
dual-core identity, finite drain, reset recovery, fault quarantine and standalone
safe defaults. Improve sampling/arithmetic overlap and data movement only with
output and schedule evidence. Security hardening, power and board measurements
remain separate work; current correctness tests are not security certification.
