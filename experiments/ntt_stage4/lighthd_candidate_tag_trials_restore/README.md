# Restore selected source after candidate/tag/write-mask trials ? 2026-10-10

All three source-correct timing trials regress worst setup at unchanged 5 ns.
Their exact six-file sources, hashes and full verification/implementation
reports remain archived. All six active RTL files are restored byte-for-byte
from `lighthd_write_select_prefetch_checkpoint/rtl/`; hashes match that checkpoint.
Golden-model, reference and TB files are unchanged. No new RTL change is selected.

Fresh main `uvm_candidate_tag_restore.log` passes 118/118, zero errors/fatals,
fourteen checked functional covergroup types 100%; it produces the current
main UCDB/raw report. Separate `compare_candidate_tag_restore.log` passes
18/18 cases and 4,608/4,608 coefficients. Core cycles 267/267/75/236 and no-stall
wrapper cycles 781/781/845/750 remain unchanged. Current raw code-coverage
counts reproduce the selected source. Previous negative-checker evidence
remains retained, not freshly rerun. No exclusions or merging of trial UCDBs.

Fresh `candidate_tag_restore_{map,fit,sta,paths}.log` reproduces the selected
result exactly. Fit completed 2026-10-10 18:42:48; timing/path reports finish at
18:43:05. Slow85/slow0 Fmax 151.79/150.49 MHz; setup -1.588/-1.645 ns at unchanged
5 ns, setup TNS -919.242/-1002.192 ns. Worst all-corner hold +0.152 ns,
pulse -0.555 ns. Resources: 2,475 ALMs, 2,414 registers, 5 DSPs / 20 M10Ks,
37,325 RAM bits, 59 physical / 0 virtual pins. Active RTL, Quartus database
and current review reports now match the selected checkpoint. No new timing
improvement is claimed. Earlier checkpoints and all three rejected trials remain
saved. No new negative-checker reruns, Stage 5, staging or commit.
