# ML-DSA sampler (`sampler_v1`)

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
