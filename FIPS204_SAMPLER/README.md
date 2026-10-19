# Independent sampler vectors

One script, three steps:

1. From the repository root: `python FIPS204_SAMPLER/sampler_vectors.py prepare`.
2. In Questa Transcript from sim/: `set SAMPLER_MODE vectors`, then `do sampler/run_uvm.do`.
3. From the repository root: `python FIPS204_SAMPLER/sampler_vectors.py compare`.

Optional: `python FIPS204_SAMPLER/sampler_vectors.py selftest`.

prepare calculates expected coefficients and cross-checks seed cases against the
unchanged C reference (GCC required). The UVM capture writes actual RTL output.
compare needs no compiler and performs exact file comparison. These are locally
generated FIPS-derived cases, not downloaded standalone NIST sampler vectors.

See [the complete guide](../docs/sampler_docs/post_midyear/FIPS204_SAMPLER.md)
for files, formats, commands, provenance, results and study order.
