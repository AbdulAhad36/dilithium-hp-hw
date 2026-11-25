# Software, hardware and output comparison

Use this guide to run the software reference, run the hardware simulation, and
compare their final outputs. Level names **2 / 3 / 5** mean
**ML-DSA-44 / ML-DSA-65 / ML-DSA-87**.

All PowerShell commands below start from the repository root:

```powershell
cd D:\GitHub\dilithium-hp-hw
```

## 1. Run the software model

The adapter is `dilithium-sw-model/golden/golden.py`. It builds and calls the C
reference under `dilithium-sw-model/ref/`. Python and GCC must be available on
PATH. This adapter does not require OpenSSL or Make. If GCC is elsewhere:

```powershell
$env:CC = 'C:\path\to\gcc.exe'
```

### All supported NIST cases, all levels

```powershell
python dilithium-sw-model/golden/golden.py nist --operation all --level all --out dilithium-sw-model/golden/output_compare --overwrite
```

### Only KeyGen, Sign or Verify

Run the command for the operation you want:

```powershell
python dilithium-sw-model/golden/golden.py nist --operation keygen --level all --out dilithium-sw-model/golden/output_compare --overwrite
python dilithium-sw-model/golden/golden.py nist --operation sign --level all --out dilithium-sw-model/golden/output_compare --overwrite
python dilithium-sw-model/golden/golden.py nist --operation verify --level all --out dilithium-sw-model/golden/output_compare --overwrite
```

These commands reuse the same folder. Each run replaces the named result files;
running all three commands successively leaves the **last operation's** outputs.
Use `--operation all` to keep all three operations in one output file, or use
different `--out` folders to keep separate runs.

### A small run with matrices and intermediate values

```powershell
python dilithium-sw-model/golden/golden.py nist --operation all --level all --limit 1 --trace --out dilithium-sw-model/golden/output_study --overwrite
```

`--limit 1` selects at most one supported case per operation and level.
`--trace` saves actual C matrix/polynomial observations in `traces/`. For
example, a KeyGen trace can contain `A_hat`, `s1`, `s2`, `t1` and `t0`.
Avoid tracing the full batch unless you need it: Sign retries can produce
large trace files. Traces are not independently validated by final-output
NIST comparisons.

### One selected NIST case

```powershell
python dilithium-sw-model/golden/golden.py nist --operation keygen --level 2 --tc-id 1 --trace --out dilithium-sw-model/golden/output_study --overwrite
```

Use the desired operation, level and original `tcId`. To run your own JSON inputs:

```powershell
python dilithium-sw-model/golden/golden.py custom --input dilithium-sw-model/golden/example_inputs.json --trace --out dilithium-sw-model/golden/output_custom --overwrite
```

The hardware NIST launcher does not automatically consume this custom JSON.
For HW/SW comparison, both runs must use the same inputs and case identities.

### Software output files

For the main commands above, open `dilithium-sw-model/golden/output_compare/`:

| File | Contents |
|---|---|
| `outputs_sw.txt` | Full generated public/secret keys, signatures and Verify true/false results |
| `inputs.json` | Exact selected software inputs and original case identities |
| `outputs.json` | Machine-readable software results |
| `expected.json` | Selected expectations copied from the NIST files |
| `comparison.txt` | Software-versus-NIST checks, including first differences |
| `provenance.json` | Recorded source/build hashes and unsupported cases skipped |
| `traces/*.txt` | Matrices/intermediate values when `--trace` is enabled |

`--overwrite` replaces the runner's named outputs. It does not recursively
delete the folder; old trace files may remain when a later run selects fewer
cases. Use the current `inputs.json` to identify the current run.

## 2. Run the hardware model in Questa

Use the working Questa installation at `C:\questasim64_2024.1\win64`.
Enter the following commands in the **Questa Transcript**, not PowerShell.

### All supported NIST cases

```tcl
cd D:/GitHub/dilithium-hp-hw
set DILITHIUM_TEST all
set DILITHIUM_FAST 1
do sim/dilithium/run.do

or

vsim -do "set DILITHIUM_TEST all; set DILITHIUM_FAST 1; do D:/GitHub/dilithium-hp-hw/sim/dilithium/run.do"
```

### Only KeyGen, Sign or Verify

Choose one of these values before launching:

```tcl
set DILITHIUM_TEST keygen
# Alternatively: set DILITHIUM_TEST sign
# Alternatively: set DILITHIUM_TEST verify
set DILITHIUM_FAST 1
do sim/dilithium/run.do
```

Set `DILITHIUM_TEST` again for each launch: the script internally converts these
operation shortcuts to the main testbench selector.

`DILITHIUM_FAST 1` disables broad debug visibility and wave logging, while
retaining the selected cases and testbench checks. For GUI waves/debug access,
use `set DILITHIUM_FAST 0` **before** the next launch. This does not change a
simulation already running. Unchanged preparation and compilation are cached;
changed source/NIST inputs invalidate the relevant cache.

### What runs and what files it produces

```text
NIST prompt.json
       |
       v
dilithium_vectors.py
       |
       v
sim/dilithium/main_inputs.txt
       |
       v
tb/tb_dilithium/tb_main.sv --> complete production RTL
       |
       +--> sim/dilithium/outputs_hw.txt
       +--> sim/dilithium/main_outputs.txt
```

`outputs_hw.txt` is the readable final-output file, written directly by the
testbench. `main_outputs.txt` is the detailed capture containing
command records, output words, completion information and diagnostic records.
The input file contains one line per case. Cases run sequentially: all selected
KeyGen cases, then Sign, then Verify. Every run replaces the main output files.

The Transcript reports the selected case count. A `COMPACT_MAIN_PROGRESS` line
is a periodic update for the current case; its clock count is cumulative across
the simulation. `COMPACT_MAIN_CASE_PASS ... cycles` gives that case's operation
clocks and indicates the bench's transaction checks passed. Exact output
agreement still requires comparison after capture completes.

The launcher prints the independent NIST comparison command when finished.
For the normal main capture, run it in PowerShell with the same operation:

```powershell
python sim/dilithium/dilithium_vectors.py main_compare --operation all
```

Replace `all` with `keygen`, `sign` or `verify` when that was the captured run.
This command checks the current main capture against the selected expectations
and independent reference checks.

## 3. Compare software outputs with hardware outputs

First run **the same operation selection** on both sides, using the same current
NIST inputs. For a full comparison, use `--level all` and no `--limit` on the
software side, and `DILITHIUM_TEST all` on hardware.

Then run in PowerShell from the repository root:

```powershell
python sim/dilithium/compare_outputs.py --sw dilithium-sw-model/golden/output_compare/outputs_sw.txt --hw sim/dilithium/outputs_hw.txt
```

The script works automatically when both files contain only KeyGen, only Sign,
only Verify, or all operations. It matches by **case ID + level + operation**;
file order does not matter. By default, missing or extra cases fail.

To compare one operation from mixed files:

```powershell
python sim/dilithium/compare_outputs.py --sw dilithium-sw-model/golden/output_compare/outputs_sw.txt --hw sim/dilithium/outputs_hw.txt --operation keygen
```

Use `--operation sign` or `--operation verify` similarly. The option filters
operations, not levels or individual case IDs. A one-case software study run
will therefore not match an entire hardware KeyGen batch without missing-case
failures. The quick hardware diagnostic also chooses its own subset; it is
not automatically the same subset as software `--limit 1`.

### Read the result

The script prints totals and writes **`comparison_hw_sw.txt`** in the current
directory. To choose the report location, append:

```powershell
--report sim/dilithium/comparison_hw_sw.txt
```

| Operation | Compared outputs |
|---|---|
| KeyGen | Every public-key byte and every secret-key byte |
| Sign | Every signature byte |
| Verify | `valid = true` or `valid = false` |

The report lists PASS/FAIL per case. On a byte mismatch it gives both lengths
and the first differing byte, using an index starting at zero. If both KeyGen
keys differ, that counts as **one failed case and two mismatched fields**.
A Verify result of `false` passes comparison when both models return `false`.

Exit codes: **0** means agreement, **1** means differences or missing cases,
and **2** means an input/report error. In PowerShell, inspect `$LASTEXITCODE`.
Neither output file is modified. The comparator does not run the models or
generate expected values. File names are arbitrary: pass their actual paths
with `--sw` and `--hw`; the current writers use `outputs_sw.txt` and
`outputs_hw.txt`.

## Scope and important checks

- Both models support pure external-message and internal-message cases for
  levels 2/3/5. Prehash and external-mu cases are outside this flow; the software
  reports unsupported cases/groups instead of treating them as passing.
- Select the same inputs, context, signing randomness and message mode on both
  sides. Otherwise different signatures can be expected even with the same
  human-readable message.
- Current loaders allow locally edited NIST files without enforcing saved
  provenance hashes. Comparing edited expectations does not establish agreement
  with the original official vectors. Preparation-cache hashes detect changes;
  they do not prohibit those edits.
- HW/SW agreement and agreement with NIST expectations are separate checks.
  Use the software `comparison.txt` and hardware independent comparison as well
  when establishing NIST agreement.
- Wait for hardware capture to finish before comparing. A file from a running
  simulation can be incomplete or missing later cases.

For the original software adapter details, see
[the golden-model README](../../dilithium-sw-model/golden/README.md). For main
simulation and fast-mode details, see [the simulation README](../../sim/dilithium/README.md).
