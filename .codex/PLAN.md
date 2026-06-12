# Current Plan

## Recommendation

Build the sampler next, then integrate Keccak + sampler + NTT.

Reason: the docs and papers point to the sampler/reordering boundary as the
next real missing Dilithium block. Keccak and NTT are already complete enough
to support the next stage.

## Near-Term Options

1. Sampler branch
   - Implement rejection sampling from SHAKE byte stream to Dilithium
     coefficients.
   - Add a pure-SV golden reference and UVM testbench.
   - Verify coefficient bounds, rejection behavior, stream stalls, and
     deterministic seeds.

2. Integration branch
   - Combine Keccak, sampler, reorder/FIFO, and NTT.
   - Prefer PALS-style sampler-to-NTT reordering over a plain BRAM staging
     buffer once functionality is stable.
   - Measure throughput matching before choosing final Keccak lane count.

3. Optional NTT Fmax pass
   - Register `mod_mul` inputs.
   - Expected target: roughly 110-120 MHz.
   - Cost: +1 cycle through multiplier/butterfly pipeline; must update latency
     constants and re-run all directed/UVM/synthesis checks.

4. Optional Keccak Fmax pass
   - Register or simplify squeeze-side `KOU.last_o`, `keep_o`, and
     bytes-remaining logic.
   - Useful only if integration timing shows Keccak is the system limiter.

5. Thesis/documentation pass
   - Clean stale comments in RTL docs.
   - Consolidate comparison tables.
   - Turn Keccak/NTT design docs into final thesis chapters.

## Best Next Milestone

Sampler branch first.

It gives one clean module to verify before full integration and creates the
missing bridge between the completed Keccak and NTT engines.
