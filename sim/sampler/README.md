# Sampler simulation

Accepted RTL:Stage4.9r. Keep exactly three launchers:

| Launcher | Purpose |
|---|---|
| run_uvm.do | Main UVM,GUI waves,functional and DUT code coverage |
| run_post_synthesis.do | Main UVM against synthesis netlist (Stage5 pending) |
| run_post_fit.do | Main UVM against fitted functional netlist (Stage5 pending) |

From sim/ in Questa GUI Transcript:

```tcl
do sampler/run_uvm.do
```

Default sampler_stage4_9_test:621 complete,182 expected errors,51 reset aborts,
159628 checked coefficients. Transcript prints functional95.99% and raw DUT
code95.53%;smoke.ucdb/smoke.wlf retain coverage/waves. Checked witness CSVs and
smoke_* reports provide per-test/bin evidence. Genuine gaps are not waived.

For file vectors,first run `python FIPS204_SAMPLER/sampler_vectors.py prepare`
from repo root;in Questa set `SAMPLER_MODE vectors` before the same .do;then
run Python `compare` from repo root. Set `SAMPLER_MODE performance` for96
checked performance cases and performance.csv. Restart/reset the mode when
returning to regression. Full instructions:docs/sampler_docs/post_midyear/FIPS204_SAMPLER.md.

Current source verification outputs remain here. Trial logs,caches and old
netlists have been removed;compiled libraries regenerate on demand. Do not use
historical post-fit results as proof of this implementation. Stage5 must create
and verify fresh distinct netlists before those launchers can run successfully.
