# NTT reference-vector provenance

FIPS 204 specifies the NTT arithmetic used by ML-DSA. `ntt_inputs.txt` and `ntt_expected.txt` are **FIPS 204-derived reference vectors**, not files published by NIST. We did not identify a public standalone NIST NTT/INTT/PWM `.rsp` set analogous to the SHAKE files. NIST's ML-DSA ACVP material instead addresses complete key generation, signing, and verification. See [FIPS 204](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf) and the [ML-DSA ACVP specification](https://pages.nist.gov/ACVP/draft-celi-acvp-ml-dsa.html).

From the repository root, `py sim/ntt_vectors.py prepare` deterministically regenerates both files. The script uses FIPS 204's `q = 8380417`, `n = 256`, `zeta = 1753`, bit-reversed twiddle order, canonical residues `0..q-1`, and inverse scaling by `1/256 mod q`. It checks the butterfly reference against direct polynomial evaluation and inverse evaluation, and checks NTT-based polynomial multiplication against an independently computed negacyclic schoolbook product. Its fixed random seeds make regeneration reproducible.

The design's observed outputs are generated separately in `sim/ntt_dut_outputs.txt`; they are never used to construct `ntt_expected.txt`. See [FIPS204_NTT.md](../docs/ntt_docs/post_midyear/FIPS204_NTT.md) for the exact commands and recorded results.
