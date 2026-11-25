# Current coverage model

## What coverage establishes

Functional coverage records which defined behaviors were exercised with
scoreboard-checked outcomes. Code coverage records enabled RTL statements,
branches, conditions, expressions, toggles and inferred FSM activity. Neither
one alone proves the algorithm correct; exact output/reference checks and
protocol assertions remain necessary.

The current `dilithium_regression_test` completed 30 scoreboard checks and
three reset aborts with zero UVM errors or fatals. Functional coverage was
116/170 (68.24%), and overall DUT code coverage was 142,350/185,835 (76.60%).
The suite covers external messages. Internal-message UVM coverage still needs
stimulus and coverage bins. The separate NIST capture and unit proofs do not
contribute to these UVM counts.

## Functional groups in the reusable UVM

Definitions: `tb_uvm/tb_uvm_dilithium/dilithium_coverage.sv`.

| Group | Coverpoints / crosses |
|---|---|
| `operation_cg` | KeyGen/Sign/Verify, levels 2/3/5, operation x level |
| `command_cg` | Zero/max/other job ID; context-length classes; message-length classes |
| `outcome_cg` | Operation, completion code, normal valid/invalid Verify |
| `transport_cg` | Input/output/done waits and operation crosses; impossible Verify encoded-output stall excluded |
| `tail_cg` | Channel, valid-byte count, channel x tail; fixed-width key-word cases excluded |
| `retry_cg` | Level, accepted attempt-count ranges, level x retry |
| `sequence_cg` | Previous/current operation and ordered pairs |
| `memory_cg` | Operation, observed physical port-ownership peak, cross |
| `reset_cg` | Aborted operation, recovery operation, cross |

Only scoreboard-checked retirements enter the coverage subscriber. Reset
aborts are accounted for separately and must not count as completed crypto
results. Code in a helper proof is not full-main coverage. Message-mode and
mode-transition bins/tests must be added with actual UVM stimulus support;
the current transaction driver does not yet exercise that entire API.

## Run and view

From repository-root PowerShell, after relevant source changes:

```powershell
python sim/dilithium/dilithium_vectors.py uvm_prepare
```

In the Questa Transcript, from the repository root:

```tcl
do sim/dilithium/run_uvm.do
```

The GUI opens waves and functional/code coverage views. At completion, the
Transcript prints functional totals and enabled DUT module/package code
coverage. `report_uvm_coverage.tcl` calculates raw hit/total counts rather than
averaging percentages. Source freshness is checked before launch.

| Active output | Purpose |
|---|---|
| `uvm.ucdb` | Main saved coverage database |
| `uvm.wlf` | Recorded UVM waveforms |
| `uvm_functional.rpt` | Detailed functional bins |
| `uvm_code.rpt` | Enabled code coverage detail |
| `uvm_package_code.rpt` | Executable shared-package code coverage |
| `uvm_checked.csv` | Scoreboard-checked outcomes |
| `uvm_latency.csv` | Per-case latency measurements |

Set `DILITHIUM_UVM_TEST dilithium_random_stall_test` before launch for bounded
random transport stalls. It preserves crypto input bytes. To return to normal,
set `DILITHIUM_UVM_TEST dilithium_regression_test`. Negative key injection uses
`DILITHIUM_INJECT_BAD_KEY 1` and a separate output prefix; set it back to zero
after the expected-failure test. Never merge an expected-failure run into a
claimed clean qualification.

## Reporting requirements

Report source identity, test name/seed, checked outcomes/reset aborts, errors,
bin totals, excluded-bin rationale and genuine misses. Exclusions require a
functional reason. No artificial ceiling is applied; 100% on a small group
is valid when all its bins were checked, but does not establish full-design
closure. Post-fit and board validation remain separate acceptance work.
