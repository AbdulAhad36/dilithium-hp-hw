# Golden model: explicit inputs, full outputs and matrices

This adapter uses the C reference in `../ref`. Level **2 = ML-DSA-44**, **3 = ML-DSA-65**, **5 = ML-DSA-87**. It supports KeyGen, Sign and Verify.

The old `test_vectors.c` chooses its own test data. This runner instead accepts your exact inputs. Its matrix/intermediate dump belongs to that operation, not to a separate random example.

## Start here

Open PowerShell:

```powershell
cd D:\GitHub\dilithium-hp-hw\dilithium-sw-model
python .\golden\golden.py nist --level all --limit 1 --trace --out .\golden\output_demo --overwrite
python golden/golden.py nist --operation all --level all  --trace --out golden/output_one --overwrite 
python golden/golden.py nist --operation keygen --level 2  --trace --out golden/output_one --overwrite
```

This runs nine examples: one KeyGen, one Sign and one Verify per level. It reads the existing files under the repository's `NIST/` folder and builds the required C executables automatically. Python and GCC on PATH are sufficient; OpenSSL and Make are not required. If GCC is elsewhere, set `$env:CC = 'C:\path\to\gcc.exe'`.

Open `golden/output_demo/`:

| File | Purpose |
|---|---|
| `inputs.json` | Exact input bytes, operation, level, case IDs and expected values |
| `outputs_sw.txt` | Full public key, secret key, signature or Verify result, easy to read/copy |
| `outputs.json` | Same full results, in a format the comparison command can read |
| `expected.json` | Expected values copied from the selected NIST cases |
| `comparison.txt` | PASS/FAIL per field, lengths and first differing byte on failure |
| `traces/*.txt` | Actual matrix and intermediate polynomial values, if `--trace` was requested |
| `provenance.json` | Source/compiler/binary hashes and any unsupported NIST cases skipped |

For example, `traces/0001_keygen_L2_keygen.txt` contains the matrix and secrets for the first NIST level-2 KeyGen seed. Find `A_hat[0][0]`, `s1[0]`, `s2[0]`, `t1[0]` or `t0[0]`. Each polynomial contains 256 signed decimal coefficients. Each row identifies coefficient indices, for example `coeff[000..015]`.

`--overwrite` explicitly permits replacing the runner's named result files. Without it, a nonempty output folder is rejected. It never recursively deletes a directory. Reusing a folder with fewer traced cases can leave old trace files; use the numbered files for the cases in the current `inputs.json`, or choose a fresh output folder.

## Run one official case

```powershell
python .\golden\golden.py nist --operation keygen --level 2 --tc-id 1 --trace --out .\golden\output_one
```

The first KeyGen case IDs are 1 / 26 / 51 for levels 2 / 3 / 5. Case IDs are scoped to a suite: specify `--operation` when selecting an individual case.

The flow is:

```text
NIST prompt.json --> explicit input bytes --> C reference
                                                |
                              full outputs + actual matrix/intermediates
                                                |
NIST expectedResults.json --> byte/status comparison --> comparison.txt
```

Expected bytes do not enter the C executable. Python compares them only after the executable returns. A failure exits with code 1; malformed input/build/runtime errors exit with code 2. In PowerShell, inspect `$LASTEXITCODE`.

No downloads are needed. The runner allows locally edited `prompt.json` and `expectedResults.json`; it does not enforce the saved provenance hashes. Current file hashes are still recorded in the output report. If you edit these files, results compare against your edited expectations and do not establish agreement with the original official vectors.

## Run all supported NIST cases

```powershell
python .\golden\golden.py nist --out .\golden\output_nist --overwrite
```

Omit `--trace` for the batch: signatures can need many rejected attempts, and dumping all polynomials creates large files. Add `--trace` to a selected case when studying it.

Supported interfaces:

- External **pure ML-DSA**: Python supplies `0 || context_length || context || message` to the reference's internal API.
- Internal message API: Python passes the NIST message as-is, with no additional prefix/context.
- Explicit 32-byte signing randomness; deterministic signing uses 32 zero bytes.

Explicitly unsupported: **HashML-DSA prehash cases** and **external-mu cases**. Their IDs/reasons are written to `comparison.txt` and `provenance.json`; they are not counted as passing. The terminal and `comparison.txt` also summarize each skipped group by operation, level, `tgId`, mode (`prehash` or `external-mu`) and skipped case count. They would need additional API support. This runner does not silently reinterpret them as pure ML-DSA.

## Supply your own inputs

Edit `golden/example_inputs.json`, then run:

```powershell
python .\golden\golden.py custom --input .\golden\example_inputs.json --trace --out .\golden\output_custom --overwrite
```

The example runs all three levels. Each `roundtrip` case generates keys, signs the supplied message and verifies that signature. It saves three corresponding traces. This local roundtrip checks consistency; it is not an independent NIST comparison unless expected bytes are also supplied.

Minimal single-case input:

```json
{
  "cases": [
    {
      "id": "my_keygen",
      "operation": "keygen",
      "level": 2,
      "seed": "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    }
  ]
}
```

All byte inputs use hex, two hex characters per byte. Empty message/context is `""`. A text message `abc` is `"616263"`. `id` identifies the case; it is not a crypto input.

| Operation | Required crypto fields |
|---|---|
| `keygen` | `seed`: exactly 32 bytes |
| `sign` | `sk`, `rnd`: exactly 32 bytes, `message`; optional `context` |
| `verify` | `pk`, `signature`, `message`; optional `context` |
| `roundtrip` | `seed`, `rnd`, `message`; optional `context` |

The 32-byte KeyGen seed is the actual algorithm input. It is **not** the old KAT program's 48-byte RNG initialization seed. `rnd` must be explicit: use 64 zero hex characters for deterministic signing. Supply the same randomness to compare signatures byte-for-byte. Context is at most 255 bytes.

| Level | Public key bytes | Secret key bytes | Signature bytes | Matrix dimensions |
|---|---:|---:|---:|---|
| 2 | 1312 | 2560 | 2420 | 4 x 4 polynomials |
| 3 | 1952 | 4032 | 3309 | 6 x 5 polynomials |
| 5 | 2592 | 4896 | 4627 | 8 x 7 polynomials |

An optional `expected` object holds full expected fields (`pk`, `sk`, `signature` or Boolean `valid`). Without expected data, KeyGen/Sign are labeled **GENERATED ONLY**, not PASS. Invalid signatures are valid Verify test inputs; `false` is the correct result for a negative case.

To reuse official inputs as a custom file, copy a case from the generated `inputs.json` into a `{"cases": [...]}` file. It includes its exact expected results. Changing inputs while retaining those expected values should cause a mismatch.

Advanced: `"interface": "internal"` passes the supplied `message` directly to the internal API and rejects a nonempty `context`. The default is external pure ML-DSA.

## Compare another output file, including hardware captures

The standalone comparison command does not run C:

```powershell
python .\golden\golden.py compare --actual .\golden\output_demo\outputs.json --expected .\golden\output_demo\expected.json --report .\golden\comparison.txt
```

For hardware comparison, put captured hardware bytes in a JSON file with the same case IDs, levels and operations:

```json
{
  "cases": [
    {
      "id": "my_keygen",
      "level": 2,
      "operation": "keygen",
      "outputs": {"pk": "FULL_HEX_PUBLIC_KEY", "sk": "FULL_HEX_SECRET_KEY"}
    }
  ]
}
```

Replace the placeholders with actual complete bytes. Compare this file against the C runner's `outputs.json` for the same input cases. The comparator matches cases by `(id, level, operation)` and reports missing/unexpected cases, lengths, and the first mismatching byte (zero-based).

This adapter does **not** automatically launch Questa, modify the UVM scoreboard, or parse the existing simulator-specific capture format. The hardware file above must contain independently captured bytes; copying golden outputs into it would not test hardware. NIST expected results remain the independent authority for selected official cases. The standalone compare command accepts matching outputs_sw.txt-format files as well as JSON.

## What the matrix trace means

| Label | Meaning |
|---|---|
| `rho` | Matrix seed extracted/generated by that operation |
| `A_hat[row][column]` | Expanded public matrix in the reference's NTT representation/order |
| `s1`, `s2` | Actual small secret vectors, before NTT |
| `s1_hat` | KeyGen's transformed secret vector |
| `t` | KeyGen's canonical `A*s1+s2`, before rounding |
| `t1`, `t0` | KeyGen's high/low Power2Round parts, or decoded key parts in Sign/Verify |
| `mu`, `rhoprime` | Signing/verification message digest and signing mask seed where applicable |
| `y` | Signing mask for the labeled attempt |
| `z_hat` | NTT working vector: transformed y in Sign, transformed signature z in Verify |
| `w`, `w1`, `w0` | Signing matrix product and its decomposition |
| `c_tilde`, `c` | Challenge bytes and sparse challenge polynomial before NTT |
| `z`, `hint` | Accepted signature coefficients and hint values |
| `w1_recovered` | Verify's high parts after applying hints |

Signing traces include rejected attempts and their rejection reason, followed by the accepted attempt. An invalid Verify case can return before reaching matrix expansion; its trace then stops at the checks actually executed. It does not invent intermediates for code that never ran.

These matrices are observations of the C reference, not separately published NIST matrix vectors. NIST agreement checks the final keys/signatures/validity. RTL intermediate comparisons also need matching order/domain and modular normalization: lazy signed NTT values can represent the same residue with different integers.

## Files and implementation

- `golden.py`: one Python entry point for build, input selection, execution and comparison.
- `bridge.c`: small file adapter calling the existing C APIs with explicit inputs; no replacement hash, sampler or NTT implementation.
- `example_inputs.json`: editable three-level example.
- `test_golden.py`: adapter regression, negative tests, trace checks and original-source preservation checks.
- `build/`: reusable ignored executables/manifests and a generated traced copy of `sign.c`.

Original reference sources, old tests/KAT tools, RTL, UVM and official NIST data are unchanged. KeyGen receives the explicit seed through a strict test-only `randombytes` shim. Sign calls the existing internal API with explicit randomness and prefix. Verify calls the existing internal API with the same prefix convention.

Tracing inserts observation-only calls into a generated build copy using exact guarded source anchors. If the original source structure changes, tracing fails rather than guessing injection points. Normal executables include the original `sign.c` directly. Cached builds are invalidated when the source/compiler/options or executable hash changes. Source and binary hashes are saved with each run.

## Verified results

Local validation on 2026-11-09:

| Operation | Level 2 | Level 3 | Level 5 | Total |
|---|---:|---:|---:|---:|
| KeyGen, exact pk + sk | 25 | 25 | 25 | 75 |
| Sign, exact signature | 60 | 60 | 60 | 180 |
| Verify, expected valid/invalid | 30 | 30 | 30 | 90 |
| Total supported cases | 115 | 115 | 115 | **345** |

All 345 matched the stored official expected results: **1,054,960 key/signature bytes**, plus **18 valid / 72 invalid** Verify outcomes. The suite has 615 cases in total; **270 unsupported cases are explicitly skipped**, not passed. These were the software checks at the original adapter milestone. The RTL now also accepts internal messages;see the later functional qualification below.

Run the adapter regression:

```powershell
python .\golden\test_golden.py
```

It compares traced versus untraced C results against NIST, checks the trace's t1 against the returned packed public key and the Power2Round equation, exercises custom inputs/tampering, and tests comparison failures/input validation.

## Local suite filtering (2026-11-11)

The working Sign/Verify prompt and expected-result files now exclude prehash and external-mu groups, retaining every remaining original tgId/tcId and input/output field. Sign has 180 cases; Verify has 90. Internal-message groups with externalMu=false remain. KeyGen is unchanged. The golden runner therefore selects 345 cases and reports 0 unsupported skips from these filtered suites. The results above describe the earlier unfiltered suite; filtering is not a new cryptographic verification run.

A byte-exact backup of both suites as they existed immediately before filtering (including any user edits) is in `../../NIST/before_mode_filter_2026-11-11.zip`. Saved upstream hashes in provenance describe the original downloads; local_filter records the working subset. Edited cases may intentionally fail against unchanged expected outputs. The strict hardware vector runner still expects the complete pinned upstream files; this filtering does not change or relax that runner.

## RTL message API parity (2026-11-12)

Hardware now supports the same external-pure and internal-message APIs as this
runner. Its new start_internal_message_i bit defaults0(external) and selects1
for already formatted input with separate context length0. Fresh345-case RTL
results match all supported NIST expected values and the unchanged C reference;
the actual outputs_hw.txt and software-format text are byte-exact. Prehash and
external-mu remain unsupported by both the adapter and hardware. The main UVM
has not been extended/rerun for internal messages;this qualification uses the
main RTL file-capture bench and independent comparisons.
