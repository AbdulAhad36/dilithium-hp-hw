# Current operation flows

## Common command lifetime

The host presents a command and waits for start ready. On acceptance the main
controller grants one child the shared datapath. That child runs its fixed
schedule. Input/output words transfer only on valid and ready. Completion is
held until accepted, resources drain, and the main controller retires the owner
before a new command. Internal sampling and arithmetic may overlap even though
public commands are sequential.

## KeyGen

1. Expand the 32-byte seed with the selected parameter bytes using SHAKE256
   into rho, rhoprime and K.
2. Use rhoprime and polynomial nonces to sample small s1 and s2. Store compact
   secrets and transform s1 through the supported small-secret Pre-NTT path.
3. Expand matrix A from rho using SHAKE128 and row/column identifiers. Keep a
   bounded matrix ring while rows are consumed by NTT-domain multiply/accumulate.
4. For each row compute Ahat times s1hat, inverse transform, then add s2.
5. Power2Round splits each t coefficient into high t1 and low t0. Pack t1 for
   the public key and retain t0 for the secret key.
6. Stream the public key rho plus packed t1. Hash its exact encoded bytes to
   obtain the final-format 64-byte tr.
7. Stream the expanded secret key rho, K, tr, packed s1, s2 and t0. Retire the
   finite hash, memory and output work before successful completion.

## Sign

1. Receive and decode the expanded secret-key frame. Retain its scalar headers
   and load/check packed s1, s2 and t0 into fixed bank roles.
2. Receive the body frame. External mode formats the context/message; internal
   mode uses Mprime directly. Compute mu and derive the signing mask seed from
   K, explicit randomness and mu.
3. Prepare cached secret transforms. For each attempt, expand y with fresh
   nonce positions and compute w = A*y through shared matrix/NTT resources.
4. Decompose w into w1 and w0. Pack w1 and hash mu with its encoding to form
   ctilde. Sample the sparse challenge c and transform it.
5. Compute the challenge products and response z, corrected low terms and
   hints. Run all required norm and hint-weight tests.
6. On rejection, retain reusable key/hash material, advance nonces and execute
   another attempt. Rejected attempts do not publish a signature.
7. On acceptance, pack ctilde, z and the canonical sparse hint suffix into the
   signature output stream. Complete only after the final accepted output and
   shared-service drain.

Attempts, rejections and next nonce are observable status. Different inputs
can take very different clock counts because the rejection loop is real.

## Verify

1. Receive the public key, signature and body as three separate frames.
2. Fork the public-key bytes into decoding and hashing to compute tr. Validate
   framing, encoding, sparse-hint counts/order/padding and the z bound. Malformed
   transport is distinct from a normally invalid signature.
3. Compute mu from tr and the chosen external/internal message representation.
   Sample c from ctilde. Transform z, shifted t1 and c as required.
4. For each row compute Ahat*z_hat minus c_hat*t1_hat*2^d, then inverse transform.
5. Use the decoded hints to reconstruct w1. Pack it and hash with mu.
6. Compare the full challenge hash with the signature's ctilde. Return valid
   only on normal completion and agreement. Invalid signatures may terminate
   earlier after canonical/norm checks, so their timing is not a valid-signature
   throughput measurement.

## Where to study the implementation

Start at `src/controller/dilithium_fpga.sv` and `dilithium.sv`, then the selected
`keygen.sv`, `sign.sv` or `verify.sv`. Follow request types in
`helpers/dilithium_pkg.sv` into `datapath/datapath.sv`, the engine adapters,
`process/` and `memory/`. For simulation stimulus, start at `tb_main.sv` and
`sim/dilithium/dilithium_vectors.py`. See [OUTPUT_SIM_COMAPRE.md](OUTPUT_SIM_COMAPRE.md)
for commands and [PROCESS_BLOCKS.md](PROCESS_BLOCKS.md) for the arithmetic.
