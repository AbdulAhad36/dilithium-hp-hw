# Current Dilithium verification plan

## Verification structure

`tb/tb_dilithium/tb_main.sv` drives the complete production top for exact
file-based NIST output capture. Root focused KeyGen/Sign benches and
`unit/`, `reference/`, `support/` provide reusable component/protocol checks.
The full-operation UVM lives under `tb_uvm/tb_uvm_dilithium/` with a transaction,
sequencer, sequence, driver, monitor, scoreboard, coverage subscriber, agent,
environment, tests, package, interface and top.

The UVM driver uses accepted public commands and framed streams. The monitor
observes independent handshakes; the scoreboard compares expected bytes/status
and publishes checked results. Coverage earns credit only through that checked
analysis stream. The driver completing a request alone is not a passing result.

## Required features and tests

| Feature | Stimulus | Required checks |
|---|---|---|
| KeyGen | All supported seeds, levels 2/3/5 | Full public and secret keys; lengths, ID, framing, no unexpected output |
| Sign | Supported SK, randomness, message and context cases | Every signature byte; challenge, attempts, rejection reasons and nonce progression |
| Verify | Valid and invalid signatures, both message modes | Normal valid/invalid result; canonical/norm gates; independent equation digest where executed |
| Message mode | External formatting; internal Mprime with zero separate context | Exact hash input; mode latched per command; busy changes ignored |
| Command validation | Invalid opcode/level/context/length | No unowned engine work or output; held matching completion |
| Input framing | Wrong byte count/index/last, incomplete and excess frames | Exact accepted prefix; appropriate error and drain; no stale tail publication |
| Backpressure | Input pauses, output stalls, held completion | Stable held payload/metadata; no duplication, drops or premature retirement |
| Reset | During input, sampling, transform, packing, hash and output | Immediate control/ownership invalidation; correct same-ID recovery with changed data |
| Operation transitions | All KeyGen/Sign/Verify ordered pairs | No cross-operation response, core/job mixing or stale state |
| Dual-core hash/sampler | Concurrent eligible internal jobs and partial beats | Per-core ID/state isolation; finite output credits and completion/drain |
| Memory | Parallel ports, same-address conflicts, split renewals | Physical commitment order; one completion per owner; no released-live data |
| NTT / Pre-NTT / MAC | General and eligible compact-secret operands | Independent polynomial results; permutation/domain/scaling correctness |
| Process | Bounds, arithmetic boundaries, packing tails, hint coordinates | Modular/centered results; canonical suffix; independent sink credits |
| Fatal faults | Mismatched identity/physical ownership faults | Immediate quarantine; no output or new work until reset |
| Checker validation | Deliberately corrupted bytes/IDs/status/captures | Failure detected with no false checked-outcome or coverage credit |

No test may substitute expected outputs for RTL-produced output. Locally
generated intermediates must be labeled reference-derived, not standalone
official sampler/NTT vectors. Unsupported algorithms must not count as passed.

## Campaigns and acceptance

1. Focused component equivalence and protocol tests after a relevant change.
2. Fast mixed-operation diagnostic before expensive full qualification.
3. Full supported NIST capture for a candidate intended to be retained, followed
   by exact independent comparison and HW/SW readable-output comparison.
4. Full main UVM normal and bounded random-stall campaigns, negative checker
   injection, reset recovery and genuine functional/code coverage reporting.
5. Synthesis/structural screen and one full fit using the efficient workflow;
   report source-matched placed area and every timing corner.
6. Post-synthesis, post-fit and FPGA campaigns only after the user's gates.

For RTL functional acceptance require complete expected case sets, matching
identity/framing, every output byte/verdict, no unexplained errors/fatals and
source-fresh captures. A complete capture footer alone is insufficient.
Coverage gaps remain explicit; never add impossible bins to lower a percentage
or cap a reported percentage. Current full UVM must be refreshed/extended for
both message modes before claiming its coverage applies to the complete API.

Commands are centralized in [OUTPUT_SIM_COMAPRE.md](OUTPUT_SIM_COMAPRE.md).
Current functional results are in [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md),
the coverage model in [COVERAGE.md](COVERAGE.md), and clock/rate reporting in
[THROUGHPUT.md](THROUGHPUT.md).
