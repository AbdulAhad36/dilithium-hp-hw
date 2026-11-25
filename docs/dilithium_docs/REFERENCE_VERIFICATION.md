# Current reference verification

## Functional scope

The current production RTL supports KeyGen, Sign and Verify at levels 2/3/5
using final FIPS 204 formats. Sign/Verify support both external pure messages
and already formatted internal messages. SHAKE still computes mu internally;
prehash and externally supplied mu are unsupported.

| Qualified functional check | Result |
|---|---|
| Supported main corpus | 345 operations: 75 KeyGen, 180 Sign, 90 Verify |
| Expected key/signature output bytes | 1,054,960 exact |
| Verify verdicts | 18 valid, 72 invalid |
| Independent Verify equation digests | 70 checked |
| Sign attempts/challenges/rejections | All 180 cases checked against independent arithmetic |
| Actual hardware/C readable output comparison | Byte-exact, 2,131,308 bytes |
| Protocol campaign | 88 commands; 29 expected errors, 3 normal invalids, 12 resets, 44 recoveries |
| Protocol output prefixes/full data | 148,704 checked bytes |

These results qualify the functional RTL, not timing closure or FPGA execution.
The actual unchanged C text-file writer was used for the byte-exact comparison.
The qualified readable output SHA-256 is
`7b424d01231bc96ba11386beb3d6a04d993c3057e6c0f3dd32b42d759e50dfe7`.
Subsequent naming-only cleanup preserves raw evidence headers/hashes rather
than relabeling old captures with a new source token. A new current capture
must carry the fingerprint generated for its own test tools and RTL.

External formatter checks exercised 141 jobs, 111 completions and 31 resets
per storage mode, with 232,689 checked bytes. Internal formatter checks
exercised 144 jobs, 114 completions and 31 resets per storage mode, with
231,786 independently expected bytes. Busy command-mode changes were covered.

## Inputs, expected values and observed outputs

```text
NIST prompt.json -> Python preparation -> main_inputs.txt -> tb_main -> RTL
NIST expectedResults.json -------------------------------> independent compare
RTL -> outputs_hw.txt <-------------------------- compare_outputs.py
C reference -> outputs_sw.txt --------------------------^
```

Expected key/signature bytes are not fed into the RTL. Testbench stimulus
contains required seed/key/signature/message/context/randomness input bytes.
For Verify, the supplied signature is an input; its validity is the result.
The readable output is written directly by the testbench, not constructed by
a Python exporter. The detailed main capture also records intermediate audit
events, retries, completion metadata and operation clocks.

The single vector tool is `sim/dilithium/dilithium_vectors.py`; use its stable
`main_prepare`, `main_compare` and `main_diagnostic_compare` commands. The
separate `compare_outputs.py` compares existing HW/SW text files and generates
no crypto outputs. See [OUTPUT_SIM_COMAPRE.md](OUTPUT_SIM_COMAPRE.md).

## Reference sources and limits

Stored ACVP JSON under `NIST/ML-DSA-keyGen-FIPS204`, `ML-DSA-sigGen-FIPS204`
and `ML-DSA-sigVer-FIPS204` provides prompts and expected results. Original
suite/group/case IDs are preserved. Local loaders permit edited JSON and do
not enforce saved provenance hashes. Current hashes identify the files used;
an edited expected result is not an untouched official expectation.

The C adapter under `dilithium-sw-model/golden/` invokes the unchanged algorithms
under `dilithium-sw-model/ref/`. Python arithmetic and independent focused
references check additional intermediates and malformed captures. Agreement
of HW and SW is useful but is separate from agreement with stored NIST
expectations. C matrix traces are local observations, not NIST intermediate
vectors. Unsupported prehash/external-mu cases must be reported as skipped.

## Reproduction and freshness

Use the working Questa at `C:/questasim64_2024.1/win64`. `run.do` prepares the
selected operation set, compiles when needed, captures all selected cases and
prints the independent comparison command. Content-checked caches reuse
unchanged preparation/compilation and invalidate after relevant edits.
Do not overwrite capture headers to bypass source-freshness checks.

The normal complete capture is `main_outputs.txt`; the fast focused subset is
`main_diagnostic_outputs.txt`; the protocol capture is `main_protocol_outputs.txt`.
The plaintext `outputs_hw.txt` reflects the latest capture operation set.
Wait for completion and select matching SW cases before comparison.

The current fitted RTL passed the 345-operation capture and the 88-case protocol
campaign. The current UVM result and its external-message scope are recorded in
[COVERAGE.md](COVERAGE.md). Timing closure, internal-message UVM coverage and
netlist/board acceptance remain open. Frozen functional evidence is retained
in the existing reference-build/evidence area.
