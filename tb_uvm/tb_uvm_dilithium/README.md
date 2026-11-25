# Complete Dilithium UVM environment

Compile through the launcher: component files are included by the package,
not compiled individually.

The DUT is the production `dilithium_fpga` top. Levels 2/3/5 select final
ML-DSA-44/65/87. The default test is `dilithium_regression_test`.

| File | Responsibility |
|---|---|
| `dilithium_if.sv` | Production pins and read-only observation probes |
| `dilithium_types.sv` | Event names and hex-byte helpers |
| `dilithium_transaction.sv` | Command, observed event and checked-result transaction; field automation |
| `dilithium_config.sv` | Input-only fixture loading and agent mode |
| `dilithium_sequencer.sv` | Typed sequencer and shared configuration |
| `dilithium_sequence.sv` | Sends the input cases through sequence items |
| `dilithium_driver.sv` | Drives command/data streams, stalls and reset scenarios |
| `dilithium_monitor.sv` | Independently observes accepted transfers and checks protocol stability |
| `dilithium_scoreboard.sv` | Loads separate expected results; checks bytes, frames, ownership, status and retirement |
| `dilithium_coverage.sv` | Samples checked outcomes, tails and reset recovery through an analysis export |
| `dilithium_agent.sv` | Active/passive agent; creates driver and sequencer only in active mode |
| `dilithium_env.sv` | Connects monitor -> scoreboard -> coverage |
| `dilithium_tests.sv` | Factory-created full regression test and historical test-name alias |
| `dilithium_uvm_pkg.sv` | Imports and ordered component includes |
| `tb_top.sv` | Clock, interface, production DUT and observation wiring |

```text
sequence -> sequencer -> driver -> DUT pins
                                    |
                                 monitor
                                    |
                                 scoreboard <- separate NIST expected file
                                    |
                          checked-result analysis port
                                    |
                                 coverage
```

The driver never reads expected keys/signatures. The monitor never trusts
sequence intent as proof that the DUT accepted a transfer. Coverage is released
only after the scoreboard validates complete output and physical retirement.
An aborted reset case does not receive normal completion credit. This retains
the existing 33 scenarios and raw coverage definitions; percentages are measured,
not forced toward a target.

From the repository root, prepare after verification source changes:

```powershell
python sim/dilithium/dilithium_vectors.py uvm_prepare
```

Then run in the Questa Transcript:

```tcl
do sim/dilithium/run_uvm.do
```

The launcher opens waves and coverage in the GUI and prints functional and code
coverage in the Transcript.
To check that a bad output is detected, set `DILITHIUM_INJECT_BAD_KEY` to 1 before
running the same launcher. That negative test is expected to fail at byte zero;
it must produce no checked-outcome coverage. Unset the variable afterward.

Standalone file capture for manual NIST comparison remains in
`tb/tb_dilithium/tb_main.sv` and `sim/dilithium/run.do`. It is separate from the
main UVM environment. Focused block tests, support fixtures and independent
reference models are organized under `tb/tb_dilithium/`.

For constrained-random input/output/completion pressure on the same NIST data:

```tcl
set DILITHIUM_UVM_TEST dilithium_random_stall_test
do sim/dilithium/run_uvm.do
```

The random sequence copies each input transaction and randomizes only its
bounded stall profile. Message/key/randomness bytes remain those of the official
case, so the expected outputs remain independent published answers. The launcher
uses a fixed simulator seed for reproducibility. Unset `DILITHIUM_UVM_TEST` to
return to the default regression.


Current-source coverage requires a fresh run. Internal-message stimulus/coverage
needs extension; saved database percentages are not current API signoff.
