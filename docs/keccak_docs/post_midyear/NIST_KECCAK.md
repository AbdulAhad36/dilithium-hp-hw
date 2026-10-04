# NIST SHAKE verification: files, commands, and results

**Branch:** `keccak_v2`
**Last verified:** 2026-10-01
**Scope:** SHAKE128 and SHAKE256 on the two standalone `keccak_core` instances.

## What this test proves

The test sends the published NIST SHAKE inputs to the RTL, records the bytes
produced by each core, and compares those bytes with NIST's published output.
The Python script does **not** calculate SHAKE. The comparison is a direct
hex-string and length check for every case on both cores.

```text
Six NIST .rsp files
       |  python sim/nist_shake.py prepare
       +--> sim/nist_shake_inputs.txt ----> NIST-only UVM test ----> two keccak_core DUTs
       |                                                       |
       +--> sim/nist_shake_expected.txt                         v
                                            sim/nist_shake_dut_outputs.txt
                                                      |
                              python sim/nist_shake.py compare
                                                      |
                                                 PASS or FAIL
```

The simulator's `COMPLETE_KECCAK_NIST_CAPTURE` message means the output file
was produced and the UVM input/protocol/length checks finished. The final
**NIST byte verdict** is `NIST COMPARE PASS` from the Python `compare` command.
Both steps must succeed.

## Files and how they are made

| File | Who makes it | What it contains |
|---|---|---|
| `NIST/shakebytetestvectors.zip` and six `.rsp` files | [Published NIST byte-oriented SHAKE vector archive](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/sha3/shakebytetestvectors.zip), extracted locally | Original input messages and published outputs. |
| [`sim/nist_shake.py`](../../../sim/nist_shake.py) | Project script | One Python file with `prepare` and `compare` commands. |
| [`sim/nist_shake_inputs.txt`](../../../sim/nist_shake_inputs.txt) | Python `prepare` | `case_id mode input_hex output_bytes`. This is the **only vector file the testbench reads**. |
| [`sim/nist_shake_expected.txt`](../../../sim/nist_shake_expected.txt) | Python `prepare` | `case_id nist_expected_hex`. The testbench does not read this file. |
| [`sim/nist_shake_dut_outputs.txt`](../../../sim/nist_shake_dut_outputs.txt) | UVM scoreboard during simulation | `case_id core_id observed_hex`, one row from each core for each case. The simulation deletes the old output file before capturing a new one. |
| [`sim/run_nist.do`](../../../sim/run_nist.do) | Project script | Selects the NIST-only simulation top and starts capture. |
| `sim/nist_only_transcript.log` | Saved console output from the recorded run; you can generate a new one with the command below | Simulator compile, capture counts, error summary, and completion marker. |

The six selected response files are `SHAKE128ShortMsg.rsp`,
`SHAKE128LongMsg.rsp`, `SHAKE128VariableOut.rsp`, `SHAKE256ShortMsg.rsp`,
`SHAKE256LongMsg.rsp`, and `SHAKE256VariableOut.rsp`. The local archive's SHA-256 is
`DEBFEBC3157B3CEEA002B84CA38476420389A3BF7E97DC5F53EA4689A16DE4C7`.
NIST's message and output lengths are written in bits; `prepare` checks that
they are whole bytes and converts them. For a zero-length message, NIST writes
`Msg = 00` as a placeholder; the input file uses `-` to mean no message bytes.

Example for the empty SHAKE128 case:

```text
Input:    SHAKE128ShortMsg_0000 0 - 16
Expected: SHAKE128ShortMsg_0000 7f9c2ba4e88f827d616045507605853e
DUT:      SHAKE128ShortMsg_0000 0 7f9c2ba4e88f827d616045507605853e
DUT:      SHAKE128ShortMsg_0000 1 7f9c2ba4e88f827d616045507605853e
```

Here `0` in the **input mode** means SHAKE128 (`1` means SHAKE256). In the
DUT file, the number after the case ID is the **core ID**: core 0 or core 1.
The `-` is an empty input message, and `16` requests 16 output bytes.

## Run it yourself

Use PowerShell from the repository root:

```powershell
python sim\nist_shake.py prepare
cd sim
& "C:\questasim64_2024.1\win64\vsim.exe" -c -do "do run_nist.do; quit -f"
cd ..
python sim\nist_shake.py compare
```

`prepare` prints the number of cases taken from each NIST file and creates
the two text files. `run_nist.do` captures DUT outputs; it calls `run.do` with
the NIST mode flag, which selects `tb_nist_top`. It does **not** start the
integrated wrapper regression or throughput benchmark, and it does not
collect coverage. Running plain `run.do` is the separate full regression.
Finally, `compare` prints a pass count for each core and exits with a nonzero
status if any output differs, has the wrong length, or is missing, duplicated,
or unexpected.

To save the simulator output in a log while running from `sim/`, use:

```powershell
& "C:\questasim64_2024.1\win64\vsim.exe" -c -do "do run_nist.do; quit -f" *> nist_only_transcript.log
```

Python prints its comparison result in the terminal; it does not currently
write a separate comparison report file. The input, NIST expected-output,
and DUT output files remain available for inspecting individual cases.

For a short practice run, replace the first command with
`python sim\nist_shake.py prepare --max-per-file 2`. This selects two cases
from each of the six files. Run the simulation and comparison afterward.
Run `prepare` again without that option before the next full test.

## Recorded full result: 2026-10-01

| Vector family | SHAKE128 cases | SHAKE256 cases |
|---|---:|---:|
| ShortMsg | 337 | 273 |
| LongMsg | 100 | 100 |
| VariableOut | 1,126 | 1,246 |
| **Total per mode** | **1,563** | **1,619** |

- **3,182 cases per core; 6,364 captured DUT outputs in total.**
- Both UVM scoreboards: **3,182/3,182 input/protocol/length checks** and zero
  UVM errors/fatals.
- Python: **3,182/3,182 NIST outputs matched on core 0 and 3,182/3,182 on
  core 1**, for **6,364/6,364 total** (`NIST COMPARE PASS`).
- The NIST-only simulator run completed in **28 seconds** on the recorded
  machine. Time on another machine can differ.

The final Python output was:

```text
Core 0: 3182/3182 NIST outputs match
Core 1: 3182/3182 NIST outputs match
NIST COMPARE PASS: 6364 DUT outputs match published NIST vectors
```

Evidence is the `COMPLETE_KECCAK_NIST_CAPTURE` marker and zero-error summary
in `sim/nist_only_transcript.log`, the 6,364 rows in
`sim/nist_shake_dut_outputs.txt`, and the comparison output above. The
published hex values in `sim/nist_shake_expected.txt` are the comparison
reference. The local archive hash above identifies the source vector ZIP.

## Where the behavior is implemented

Read these in order when studying or explaining the test:

1. [`sim/nist_shake.py`](../../../sim/nist_shake.py): `read_cases()`,
   `prepare()`, and `compare()`.
2. [`sim/run_nist.do`](../../../sim/run_nist.do) and
   [`sim/run.do`](../../../sim/run.do): the NIST mode selects `tb_nist_top` and
   passes the DUT output-file path to the simulator.
3. [`tb_top.sv`](../../../tb_uvm/tb_uvm_keccak_v2/tb_top.sv): `tb_nist_top`
   starts only the standalone-core UVM test.
4. [`keccak_tests.sv`](../../../tb_uvm/tb_uvm_keccak_v2/keccak_tests.sv) and
   [`keccak_sequence.sv`](../../../tb_uvm/tb_uvm_keccak_v2/keccak_sequence.sv):
   both cores receive the same input cases.
5. [`keccak_driver.sv`](../../../tb_uvm/tb_uvm_keccak_v2/keccak_driver.sv),
   [`keccak_monitor.sv`](../../../tb_uvm/tb_uvm_keccak_v2/keccak_monitor.sv),
   and [`keccak_scoreboard.sv`](../../../tb_uvm/tb_uvm_keccak_v2/keccak_scoreboard.sv):
   drive input bytes, collect accepted output bytes, check protocol, and write
   the DUT output file.

This campaign covers the six independent-case files above. The NIST Monte
Carlo files require a dependent multi-iteration procedure and are not part
of this run. The NIST inputs are not fed through the integrated dual wrapper.
The NIST-only capture is separate from the full regression's functional and
code coverage, which are documented in [COVERAGE.md](COVERAGE.md).
