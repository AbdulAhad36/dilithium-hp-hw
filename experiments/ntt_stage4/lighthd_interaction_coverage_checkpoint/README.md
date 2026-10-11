# LightHD NTT interaction coverage checkpoint - 2026-10-12

748/748 UVM jobs; 191,488/191,488 coefficients; zero UVM errors/fatals.
32 group types, equal-weight type average 90.4730902778%. Raw coverpoint/cross
bins: 16,166/22,047 (73.33%); these are different aggregations. The explicit
shape/dual-flow cross is 219/1,152; transition/shape/flow is 252/4,608.

The old 620-job evidence is retained in the adjacent checkpoint unchanged.
This checkpoint adds ten interaction groups and 128 tests. All hits remain
visible. The seven-fault source checker also requires unchanged interaction
coverage. RTL and golden hashes match the previous checkpoint; no fit rerun
is needed for this TB-only extension. Full 117-job netlist suites were not
rerun; their retained Stage 5 evidence is unchanged.

- `results.json`: all groups, points, cross counts, every missing bin, code metrics, seeds.
- `source_and_evidence_hashes.json`: SHA256 for exact source and result copies.
- `src/`, `tb_uvm/`, `sim/`: source snapshots, three launchers, logs, main UCDB/report and separate checker artifacts.

Run from `sim/`: `vsim -c -l ntt_LightHD/uvm_interactions.log -do "do ntt_LightHD/run_uvm.do; quit -f"`.
In the Questa GUI use `do ntt_LightHD/run_uvm.do`; waves and both coverage views remain available.
