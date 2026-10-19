# Sampler Quartus baseline

## Current retained Stage4.9r

3537 actual placed ALMs,3931 registers,4256 ALUTs,one M10K/1024 bits,zero DSP.
Worst Fmax164.74MHz(Slow85:167.59,Slow0:164.74),setup+0.430ns/hold+0.141ns
at6.500ns. All4 corners0 setup/hold TNS. All original register guards pass.

Permanent project settings:seed1,STANDARD FIT,HIGH PERFORMANCE EFFORT,
PHYSICAL_SYNTHESIS_REGISTER_RETIMING OFF. The explicit retiming-OFF setting
preserves the pipeline register structure checked by report_paths.tcl.

### Run in Quartus GUI

1. Open/reopen `quartus/sampler/sampler.qpf` so current QSF settings load.
2. Choose **Processing > Start Compilation** for synthesis,fit and timing.
3. Read actual placed ALMs from Fitter Resource Usage's
   **[A] ALMs used in final placement** row. Needed is an estimate and is not
   the project's area-selection metric.
4. Read both slow-corner Fmax values and all-corner setup/hold summaries.

No SDC or QSF edits are needed. The constraint is153.85MHz/6.500ns;Fmax is a
separate fitted estimate. Virtual data I/O are excluded from standalone timing;
no physical board integration is claimed. Stage5 functional netlists passed.
Evidence:docs/sampler_docs/post_midyear/STAGE4_9R_RESULTS.json.


Accepted by user on2026-10-19. Current fit database and reports are retained.
Old synthesis-helper builds/netlists were removed. Stage5 generated distinct synthesis-only and fitted functional netlists and both
passed main UVM/Python checks. generate_netlists.ps1 records source/settings and
netlist hashes in netlist_provenance.json. See SAMPLER_NETLIST_RESULTS.json.
