# Keccak SHAKE Engine Specification

## Document Status

This document is the authoritative specification of the current Keccak design on the `keccak_v2` branch. The verified single-core RTL is based on commit `35fe8d7`; the active working-tree architecture adds a dual-core interleaved scheduler. The dual-core changes are not committed yet.

Last reviewed: 16 September 2026.

## 1. Scope

The design implements Keccak-f[1600], SHAKE128 and SHAKE256 for ML-DSA. Two verified one-round-per-clock cores are combined by `keccak_dual_interleaved`, which dispatches jobs with a 26-cycle launch offset and merges their tagged output streams. Each underlying `keccak_core` remains independently usable.

The design does not use AXI. Commands, input and output use protocol-neutral ready/valid handshakes.

## 2. Algorithm Parameters

| Property | Specification |
|---|---:|
| Permutation | Keccak-f[1600] |
| State width | 1600 bits |
| State organization | 5 x 5 lanes of 64 bits |
| Rounds per permutation | 24 |
| SHAKE domain suffix | `0x1F` |
| Padding | SHAKE domain separation followed by Keccak `pad10*1` |
| Byte order | Little-endian within each 64-bit transfer word |

| Mode | Rate | Capacity | Rate bytes |
|---|---:|---:|---:|
| SHAKE128 | 1344 bits | 256 bits | 168 bytes |
| SHAKE256 | 1088 bits | 512 bits | 136 bytes |

## 3. Core Architecture

Each `keccak_core` uses an iterative one-round-per-clock architecture. A 1600-bit state register feeds one fully combinational Keccak round and receives the result on the next active clock edge.

```text
64-bit input
    |
    v
Absorb and padding logic
    |
    v
1600-bit state register
    |
    v
Theta -> Rho -> Pi -> Chi -> Iota
    |
    +---------- round feedback ----------+
    |
    v
Parameterized squeeze/output logic
```

One permutation requires 24 clock cycles. The state-register-to-round-logic-to-state-register feedback path is the principal timing path.

The round modules are:

- `theta_step`: column parity and Theta diffusion.
- `rho_step`: fixed lane rotations.
- `pi_step`: lane-position permutation.
- `chi_step`: nonlinear row transformation.
- `iota_step`: round-constant injection into lane `(0,0)`.

The current implementation uses replicated local Theta parity logic. This costs
additional ALMs but shortens high-fanout routing on the round-feedback path.

## 4. Core Control

Each core contains these operating states:

```text
IDLE -> ABSORB -> SUFFIX_PADDING -> PERMUTE -> SQUEEZE
```

- `IDLE`: waits for an accepted start.
- `ABSORB`: accepts and XORs message bytes into the state.
- `SUFFIX_PADDING`: inserts the SHAKE suffix and final padding bit.
- `PERMUTE`: executes 24 Keccak rounds.
- `SQUEEZE`: presents output words through ready/valid.

Multiblock input returns from `PERMUTE` to `ABSORB`. Additional output blocks return from `SQUEEZE` to `PERMUTE`. Completion or an accepted stop returns the core to `IDLE`.

## 5. Single-Core Interface

`keccak_core` has a fixed 64-bit input and a parameterized output interface.
The legacy single-core default remains 64 bits; the active dual-core top uses
128-bit output beats.

| Input | Width | Meaning |
|---|---:|---|
| `clk` | 1 | Core clock |
| `rst` | 1 | Active-high reset |
| `start_i` | 1 | Starts an operation while idle |
| `keccak_mode_i` | 1 | Selects SHAKE128 or SHAKE256 |
| `message_len_i` | 16 | Message length in bytes |
| `output_len_i` | 16 | Requested bytes; zero selects continuous output |
| `stop_i` | 1 | Stops continuous output |
| `input_data_i` | 64 | Input data |
| `input_valid_i` | 1 | Input-valid handshake signal |
| `output_ready_i` | 1 | Output-ready handshake signal |

| Output | Width | Meaning |
|---|---:|---|
| `busy_o` | 1 | Core is processing |
| `done_o` | 1 | Operation completed |
| `input_ready_o` | 1 | Core can accept an input word |
| `output_data_o` | `OUTPUT_DWIDTH` | SHAKE output data; 64-bit default |
| `output_valid_o` | 1 | Output-valid handshake signal |
| `output_bytes_o` | `$clog2(OUTPUT_BYTES+1)` | Valid bytes in the output beat |

Lengths range from 0 through 65,535 bytes. Output data and byte count remain stable while valid is asserted and ready is deasserted.

## 6. Reset and State Handling

Reset is active high. Control state resets asynchronously. The 1600-bit state array is synchronously cleared whenever a new request is accepted, removing the large asynchronous reset fanout while ensuring every SHAKE operation begins from zero state.

## 7. Dual-Core Interleaved Architecture

`keccak_dual_interleaved` is the active system architecture. It contains exactly two independent `keccak_core` instances and a small scheduler.

```text
Command + input stream
        |
        v
Round-robin dispatcher -- 26-cycle minimum launch spacing
        |                              |
        v                              v
    Keccak core 0                  Keccak core 1
        |                              |
        +------- tagged arbiter -------+
                       |
                       v
              Shared 128-bit output
```

- The first available job is dispatched to the preferred idle core.
- Dispatch preference alternates after every accepted request.
- Consecutive launches are separated by at least 26 clocks. With a waiting request and an available core, the offset is exactly 26 clocks.
- One message at a time uses the shared 64-bit input channel, routed to the core selected at command acceptance.
- Each core has a one-beat elastic input register. This removes the shared core selector from the combinational path into the 1600-bit state update while retaining one accepted input beat per clock after initial fill.
- Both cores run independently after input dispatch.
- A fair round-robin arbiter merges their valid output words.
- `output_core_o` identifies the source core on every valid output beat.
- Backpressure reaches only the selected source; the other core retains its pending word.

This follows LightHD's published principle: two independent iterative Keccak cores operate with a fixed 26-cycle offset and produce interleaved output. Our scheduler and ready/valid integration are original SystemVerilog around the existing cores; no LightHD RTL was copied.

The old `keccak_engine_parallel` four-lane approach is obsolete for active development. Its source remains only for historical regression compatibility, and it is not the synthesis target.

## 8. Dual-Core Interface

The dual-core top accepts one job stream and returns one tagged output stream.

| Group | Important signals |
|---|---|
| Command | `request_valid_i`, `request_ready_o`, `request_core_o`, mode and lengths |
| Input | `input_data_i`, `input_valid_i`, `input_ready_o`, `input_core_o` |
| Per-core control/status | `stop_i[1:0]`, `core_busy_o[1:0]`, `core_done_o[1:0]` |
| Combined status | `busy_o` |
| Output | 128-bit data, valid, ready, byte count and `output_core_o` |

`request_core_o` reports where an accepted request will be dispatched. `input_core_o` reports the destination of the active message transfer. `output_core_o` must accompany output into any downstream sampler so that per-stream partial sampling state remains isolated.

## 9. FPGA Implementation

Both projects target Intel Cyclone V `5CGXFC7C7F23C8` with Standard Fit, High Performance Effort, physical synthesis, register retiming and duplication, maximum router timing optimization, virtual data/control pins and multicorner timing analysis.

### Active dual-core checkpoint

| Property | Current value |
|---|---:|
| Quartus top entity | `keccak_dual_interleaved` |
| Clock constraint | 6.897 ns / 145.00 MHz |
| Slow-corner estimated Fmax | 149.25 MHz |
| Worst setup slack | +0.197 ns |
| Worst all-corner hold slack | +0.167 ns |
| Setup and hold TNS | 0 ns |
| ALMs | 8,155 |
| Registers | 3,505 |
| DSP blocks | 0 |
| Block RAM blocks | 0 |
| Fitter seed | 1 |

The accepted fit has zero setup and hold TNS across all analyzed corners. Its
145 MHz operating constraint is below the reported 149.25 MHz worst slow-corner
Fmax, so the design has real positive margin. Virtual pins make this a
core-level implementation result rather than board-I/O timing closure.

The final timing recovery came from three RTL changes: local replicated Theta
parity logic, removal of a variable XOF-byte arithmetic path from the state
feedback decision, and one elastic input register per core. Intermediate fits
that violated setup were diagnostic only and are not accepted checkpoints.

### Preserved single-core reference

| Property | Reference value |
|---|---:|
| Quartus top entity | `keccak_core` |
| Clock constraint | 7.000 ns / 142.86 MHz |
| Slow-corner estimated Fmax | 143.47 MHz |
| Setup slack | +0.030 ns |
| Worst all-corner hold slack | +0.169 ns |
| ALMs | 3,441 |
| Registers | 1,674 |
| DSP / block RAM | 0 / 0 |

Virtual pins make these internal core measurements, not complete board-level I/O timing results.

## 10. Throughput

The accepted 128-bit-output design was measured in source simulation with a
long byte-exact benchmark. The measurement starts at the first accepted command
and ends at the final accepted output beat, so it includes command, 64-bit input
transfer, setup, every permutation, and 128-bit output transfer cycle.

| Mode | Dual-core sustained throughput | Single-core reference |
|---|---:|---:|
| SHAKE128 | 1.313843 GB/s at 145 MHz | Approximately 0.533 GB/s at 142.86 MHz |
| SHAKE256 | 1.124719 GB/s at 145 MHz | Approximately 0.474 GB/s at 142.86 MHz |

The measured workloads produced 131,040 bytes in 14,462 cycles for SHAKE128
and 130,832 bytes in 16,867 cycles for SHAKE256. Output was always ready; these
are core-level sustained simulation results, not UART, board, or complete
ML-DSA throughput.

Dual-core interleaving improves aggregate throughput and smooths output availability. A single job still executes on one core and does not become twice as fast.

## 11. Verification Status

The established single-core design has completed all three verification stages:

| Evidence | Result |
|---|---:|
| Source RTL UVM tests | 888 / 888 passed |
| UVM errors and fatals | 0 |
| Functional coverage | 281 / 281 bins |
| Single-lane code coverage | 98.78 percent |
| Post-synthesis source/netlist comparisons | 125 / 125 passed |
| Post-fit source/netlist comparisons | 125 / 125 passed |

The final dual-core source regressions currently pass:

- Mixed SHAKE128 and SHAKE256 jobs checked byte-for-byte against the independent golden model.
- Exact 26-cycle launch offset.
- Alternating dispatch to both cores.
- Correct shared-input routing.
- Tagged output interleaving.
- Final partial output words.
- Output stability under backpressure, including simultaneous pending outputs from both cores.
- Long-run byte-exact throughput checks for both SHAKE modes.
- Thirty-eight coverage jobs spanning empty, unaligned, rate-boundary and multirate messages, full and partial output beats, rate-tail beats, mixed modes, delayed launches and multiple backpressure patterns.

Measured functional coverage:

| Scope | Functional coverage |
|---|---:|
| Core 0 | 99.35 percent, 61/62 bins |
| Core 1 | 99.35 percent, 61/62 bins |
| Dual interleaver | 90.91 percent, 31/35 bins |
| Aggregate covergroup metric | 95.12 percent |

Measured structural code coverage for the complete dual regression is 91.33
percent. Its component metrics are 99.68 percent statements, 99.05 percent
branches, 77.77 percent conditions, 87.23 percent expressions, 100 percent FSM
states, 72.72 percent FSM transitions and 99.05 percent toggles. The lower
condition and transition figures remain visible; no exclusions were used to
make the total appear higher.

The dual tests are self-checking SystemVerilog regressions with covergroups, not
a completed dual-top UVM environment. The established single-core evidence is
UVM-based. Dual-top post-synthesis and post-fit functional comparison also
remain pending; the timing-clean fit is static-timing evidence, not netlist
functional equivalence.

## 12. Current Limitations and Pending Work

- Input remains 64 bits; output is 128 bits in the active dual top.
- Each core has one input beat of elasticity; there is no deeper input queue or separate output FIFO.
- Only one message can use the shared input channel at a time.
- No UART or FPGA-board integration.
- No final board pin assignments or board-level I/O timing closure.
- No measured hardware throughput.
- No complete external NIST CAVP and VariableOut regression set.
- Dual-core functional covergroups exceed 80 percent, but migration into a full UVM environment is not complete.
- Dual-core post-synthesis and post-fit equivalence are not complete.
- The downstream dual-context rejection sampler is not implemented yet.

## 13. Authoritative Sources

- Active dual-core scheduler: `src/keccak_engine/keccak_dual_interleaved.sv`
- RTL interface and controller: `src/keccak_engine/keccak_core.sv`
- Algorithm parameters: `src/keccak_engine/keccak_pkg.sv`
- Round datapath: `src/keccak_engine/keccak_step_unit.sv`
- Deprecated wrapper: `src/keccak_engine/keccak_engine_parallel.sv`
- Dual-core source regression: `sim/run_dual_interleaved.do`
- Dual-core throughput benchmark: `sim/run_dual_throughput.do`
- Dual-core functional/code coverage regression: `sim/run_dual_coverage.do`
- Dual-core Quartus project: `quartus/dual_interleaved/keccak_dual_interleaved.qsf`
- Dual-core timing constraints: `quartus/dual_interleaved/keccak_dual_interleaved.sdc`
- Single-core reference project: `quartus/performance/keccak_performance.qsf`
- Living engineering record: `keccak-design-and-verification.md`
- Verification requirements: `KECCAK_VERIFICATION_TESTPLAN.md`
- LightHD paper: DOI `10.1109/TC.2026.3666457`

If this document disagrees with RTL or reproducible generated reports, the RTL and corresponding tool reports take precedence. Update this specification whenever the interface, architecture, accepted synthesis checkpoint, throughput model or verification status changes.
