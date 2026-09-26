# Keccak SHAKE Engine Specification

## Document Status

This document describes the active Keccak design on `keccak_v2`. The single-core
reference and committed dual baseline are historical checkpoints; the current
dual-core fit and source-RTL coverage are working-tree results. Use the reports
and test transcript for the exact revision being discussed.

Last reviewed: 27 September 2026.

## 1. Scope

The design implements Keccak-f[1600], SHAKE128 and SHAKE256 for ML-DSA. Two verified one-round-per-clock cores are combined by `keccak_dual_interleaved`, which dispatches jobs with a 26-cycle launch offset and merges their tagged output streams. Each underlying `keccak_core` remains independently usable.

The design does not use AXI. Commands, input and output use protocol-neutral ready/valid handshakes.

### Architecture summary

| Property | Single `keccak_core` | Active `keccak_dual_interleaved` |
|---|---|---|
| Keccak cores | 1 | 2 independent cores |
| Round architecture | Iterative, one round per clock | Same architecture in each core |
| Permutation latency | 24 round clocks | 24 round clocks per core |
| Input datapath | 64 bits | Shared 64-bit stream with one elastic beat per core |
| Output datapath | Parameterized; 64-bit default | Shared, tagged 128-bit stream |
| Job scheduling | Direct start | Round-robin with minimum 26-clock launch spacing |
| Parallelism | One active SHAKE context | Two independent SHAKE contexts |
| Active synthesis top | No | Yes |

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

## 3. Single-Core Architecture

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

The current implementation generates three forced local copies of the five
Theta column parities. Destination rows select a copy using `y % 3`. This is a
physical-architecture choice rather than an algorithmic change: all copies
compute the same parity, but their reduced fanout gives the fitter more local
routing options. The earlier dual baseline used five copies, one per destination
row. Three copies reduce area while retaining timing closure.

The core does not pipeline different messages through the 24 rounds. One state
occupies one core until its current permutation completes. Consequently, one
core commits one round each clock but completes only one permutation every 24
round clocks.

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

### Cycle model

For a message of `M` bytes, SHAKE rate `R` bytes, and requested output `O`
bytes:

```text
input_beats       = ceil(M / 8)
absorb_blocks     = floor(M / R) + 1
output_blocks     = ceil(O / R), for bounded O > 0
permutations      = absorb_blocks + max(output_blocks - 1, 0)
round_clocks      = 24 * permutations
dual_output_beats = ceil(O / 16)
```

`absorb_blocks` includes the block that receives the SHAKE suffix and final
padding bit. Exact total latency also includes command acceptance, controller
transitions, input/output handshakes, stalls, and final partial beats. This is
why measured transfer-inclusive throughput is lower than permutation-only
throughput.

## 5. Single-Core Interface

`keccak_core` has a fixed 64-bit input and a parameterized output interface.
The legacy single-core default remains 64 bits; the active dual-core top uses
128-bit output beats.

| Parameter | Current meaning |
|---|---|
| `OUTPUT_DWIDTH` | Output width; 64-bit default, 128 bits in the active dual top |
| Input bytes per accepted beat | 8 |
| Output bytes per dual-top beat | 16 |
| Message/output length width | 16 bits |

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
- The 26-clock offset is a scheduling rule, not a connection between the round
  datapaths. Core 1 never continues or pipelines core 0's state.
- A fair round-robin arbiter merges their valid output words.
- `output_core_o` identifies the source core on every valid output beat.
- Backpressure reaches only the selected source; the other core retains its pending word.

This follows LightHD's published principle: two independent iterative Keccak cores operate with a fixed 26-cycle offset and produce interleaved output. Our scheduler and ready/valid integration are original SystemVerilog around the existing cores; no LightHD RTL was copied.

The old four-lane parallel wrapper has been removed. The active multi-core
architecture is `keccak_dual_interleaved`.

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

The dual top improves aggregate sustained throughput only when at least two
independent jobs are available. It does not halve the latency of one SHAKE job.
The shared input can feed only one message at a time, while execution and output
from the two accepted contexts may overlap.

## 9. FPGA Implementation

Both projects target Intel Cyclone V `5CGXFC7C7F23C8` with Standard Fit, High Performance Effort, physical synthesis, register retiming and duplication, maximum router timing optimization, virtual data/control pins and multicorner timing analysis.

### Active dual-core checkpoint

| Property | Current value |
|---|---:|
| Quartus top entity | `keccak_dual_interleaved` |
| Clock constraint | 6.757 ns / 147.99 MHz |
| Slow-corner estimated Fmax in September 24 TimeQuest report | 149.63 MHz |
| Worst setup slack | +0.074 ns |
| Worst all-corner hold slack | +0.166 ns |
| Setup and hold TNS | 0 ns |
| ALMs | 7,581 |
| Registers | 3,501 |
| DSP blocks | 0 |
| Block RAM blocks | 0 |
| Fitter seed | 1 |

The accepted fit has zero setup and hold TNS across all analyzed corners. Its
147.99 MHz operating constraint is below the reported 149.63 MHz worst slow-corner
Fmax, so the design has real positive margin. Virtual pins make this a
core-level implementation result rather than board-I/O timing closure.
An older `critical_paths/fmax_summary.rpt` dated September 16 reports
149.25 MHz for an earlier fit; the September 24 `output_files/*.sta.rpt`
is the source for the 149.63 MHz figure above.

The original timing recovery came from three RTL changes: local replicated Theta
parity logic, removal of a variable XOF-byte arithmetic path from the state
feedback decision, and one elastic input register per core. The current area
optimization reduces the Theta parity replicas from five per core to three.
Compared with commit `783b17b`, it removes 574 ALMs while raising the accepted
operating clock from 145 MHz to 148 MHz. Intermediate fits that violated setup
or were dominated in both area and timing were diagnostic only.

### Preserved single-core implementation reference

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

This row is the last separately fitted single-core checkpoint. It predates the
current three-copy Theta optimization and therefore must not be presented as a
fresh synthesis of the exact current working-tree RTL. The current RTL remains
independently instantiable as one `keccak_core`, but the accepted current fit is
the two-core top described above. A new standalone fit is required before
claiming current per-core area or Fmax.

Virtual pins make both checkpoints internal core measurements, not complete
board-level I/O timing results.

### Dual optimization comparison

| Metric | Committed dual baseline `783b17b` | Current optimized dual top |
|---|---:|---:|
| Constrained operating clock | 145 MHz | 148 MHz |
| Estimated slow-corner Fmax | 149.25 MHz | 149.63 MHz |
| Worst setup slack | +0.197 ns | +0.074 ns |
| Worst hold slack | +0.167 ns | +0.166 ns |
| ALMs | 8,155 | 7,581 |
| Registers | 3,505 | 3,501 |

The optimization saves 574 ALMs, or approximately 7.0 percent, while raising
the accepted operating clock by 3 MHz. Setup margin is smaller but remains
positive at every analyzed corner, with zero setup and hold TNS.

## 10. Throughput

### 10.1 Throughput definitions

Three different metrics are used and must not be interchanged:

1. **Permutation-only throughput** measures rate bytes produced per 24-round
   permutation. It ignores commands, input transfer, output transfer, control
   transitions and stalls. This is useful for comparison with publications.
2. **Transfer-inclusive throughput** measures from the first accepted command
   through the final accepted output beat. It includes the implemented 64-bit
   input and 128-bit output interfaces and all controller/permutation cycles.
3. **Board/application throughput** would additionally include UART, memories,
   the ML-DSA controller and downstream consumers. It has not been measured.

All `GB/s` values below use decimal gigabytes: `1 GB/s = 10^9 bytes/s`.

### 10.2 Permutation-only throughput

For clock frequency `F` in MHz, rate `R` in bytes, 24 rounds per permutation,
and `N` continuously occupied cores:

```text
throughput_GBps = (R * N * F) / (24 * 1000)
```

At the accepted 148 MHz operating clock, one core provides:

```text
SHAKE128 = (168 * 1 * 148) / (24 * 1000)
         = 1.036000 GB/s

SHAKE256 = (136 * 1 * 148) / (24 * 1000)
         = 0.838667 GB/s
```

With both cores continuously occupied, aggregate permutation-only throughput is:

```text
SHAKE128 = (168 * 2 * 148) / (24 * 1000)
         = 2.072000 GB/s

SHAKE256 = (136 * 2 * 148) / (24 * 1000)
         = 1.677333 GB/s
```

The 149.63 MHz TimeQuest Fmax is an estimated ceiling, not the declared
operating clock. If used only as a projection, it gives 2.094820 GB/s for
SHAKE128 and 1.695807 GB/s for SHAKE256 across both cores.

| Mode | One core at 148 MHz | Two-core aggregate at 148 MHz | Dual projection at 149.63 MHz |
|---|---:|---:|---:|
| SHAKE128 | 1.036000 GB/s | 2.072000 GB/s | 2.094820 GB/s |
| SHAKE256 | 0.838667 GB/s | 1.677333 GB/s | 1.695807 GB/s |

These figures require continuously available independent work and ignore all
transfer and control overhead. They are not the primary usable-throughput claim.

### 10.3 Measured dual transfer-inclusive throughput

The accepted 128-bit-output design was measured in source simulation with a
long byte-exact benchmark. Measurement starts at the first accepted command and
ends at the final accepted output beat. Output ready remains asserted, so the
result includes command handling, 64-bit input transfer, setup, every
permutation, arbitration and 128-bit output transfer, but no artificial output
stalls.

The calculation is:

```text
bytes_per_cycle = total_output_bytes / elapsed_cycles
throughput_GBps = bytes_per_cycle * 148 / 1000
```

For SHAKE128:

```text
bytes_per_cycle = 131040 / 14462
                = 9.060987 bytes/cycle

throughput      = 9.060987 * 148 / 1000
                = 1.341026 GB/s
```

For SHAKE256:

```text
bytes_per_cycle = 130832 / 16867
                = 7.756685 bytes/cycle

throughput      = 7.756685 * 148 / 1000
                = 1.147989 GB/s
```

| Mode | Output bytes | Elapsed cycles | Bytes/cycle | Measured throughput |
|---|---:|---:|---:|---:|
| SHAKE128 | 131,040 | 14,462 | 9.060987 | 1.341026 GB/s |
| SHAKE256 | 130,832 | 16,867 | 7.756685 | 1.147989 GB/s |

Relative to the dual permutation-only ceilings at the same clock, the complete
implemented path sustains approximately 64.7 percent for SHAKE128 and 68.4
percent for SHAKE256. The difference is real interface and control overhead,
not failed rounds or incorrect output.

### 10.4 Preserved single-core analytical reference

The earlier single-core report used a 142.86 MHz checkpoint and a simplified
one-rate-block model that included 64-bit input transfer but did not reproduce
the current dual benchmark methodology:

```text
SHAKE128 input beats = 168 / 8 = 21
estimate             = 168 * 142.86 / (24 + 21) / 1000
                     = 0.533344 GB/s

SHAKE256 input beats = 136 / 8 = 17
estimate             = 136 * 142.86 / (24 + 17) / 1000
                     = 0.473877 GB/s
```

Its permutation-only values were approximately 1.000020 GB/s for SHAKE128 and
0.809540 GB/s for SHAKE256. These are retained as historical single-core
references, not current measured results and not evidence of current per-core
area or Fmax.

Dual-core interleaving improves aggregate throughput and output availability.
A single job still executes on one core and does not become twice as fast.

## 11. Verification Status

The latest recorded source-RTL regression for the active dual-core design
checked 904/904 standalone-core UVM transactions, 81/81 integrated-wrapper
jobs, and four long-stream throughput jobs, with zero UVM errors or fatals.
Ten accepted jobs were intentionally cancelled by reset or stop and checked
for recovery. These are separate counts, not 989 independent requirements.

The recorded weighted functional-coverage result is 87.55%. The integrated
dual DUT's recursive structural code coverage is 99.06%, with 94.44%
condition and 99.04% toggle coverage. The global Questa diagnostic total
also includes a specialized throughput DUT and must not be used as the
integrated design's code-coverage figure. See [COVERAGE.md](COVERAGE.md)
for the bins, tests, scope and remaining holes.

The active `sim/run.do` elaborates one `tb_top`. Its `u_uvm_core` child
contains two standalone `keccak_core` instances and a separate integrated
`keccak_dual_interleaved` DUT. The two UVM lanes exercise the standalone
cores and their isolation. Three covergroups are declared in
`keccak_coverage.sv`: `cg_keccak` for detailed standalone-core behavior,
`cg_dual_core` for each core inside the wrapper, and
`cg_dual_interleaved` for scheduler and protocol behavior. A separate
`u_dual_throughput` child measures long-stream throughput. The integrated
wrapper's directed checks are self-checking SystemVerilog, not a full
dual-top UVM agent/scoreboard environment.

The September 24 Quartus fit passes internal register-to-register setup
and hold at the 6.757 ns constraint. Its virtual pins and false-pathed
external I/O do not establish board-level I/O timing. The dual-core
post-synthesis and post-fit netlist simulations remain **pending** for this
revision; the netlist and SDF files expected by the current scripts are
absent. Do not report the earlier 125/125 single-core comparisons as
dual-core Stage 2 or Stage 3 passes.

### Historical single-core evidence

An earlier standalone single-core checkpoint completed all three verification stages:

| Evidence | Result |
|---|---:|
| Historical source RTL UVM tests | 888 / 888 passed |
| UVM errors and fatals | 0 |
| Historical functional coverage | 281 / 281 bins |
| Historical single-lane code coverage | 98.78 percent |
| Post-synthesis source/netlist comparisons | 125 / 125 passed |
| Post-fit source/netlist comparisons | 125 / 125 passed |

Those results do not describe the current dual-interleaved wrapper or its
present source-RTL coverage model.

The older 880/880, 44-job, 99.49% per-core and 66.67% interleaver figures
were intermediate snapshots. They are superseded by the recorded results
above and in [COVERAGE.md](COVERAGE.md).

## 12. Current Limitations and Pending Work

- Input remains 64 bits; output is 128 bits in the active dual top.
- Each core has one input beat of elasticity; there is no deeper input queue or separate output FIFO.
- Only one message can use the shared input channel at a time.
- No UART or FPGA-board integration.
- No final board pin assignments or board-level I/O timing closure.
- No measured hardware throughput.
- No complete external NIST CAVP and VariableOut regression set.
- Dual-core functional covergroups exceed 80 percent in the last recorded run;
  migration of the integrated wrapper into a full UVM environment is incomplete.
- Dual-core post-synthesis and post-fit equivalence are not complete.
- The downstream dual-context rejection sampler is not implemented yet.

## 13. Authoritative Sources

- Active dual-core scheduler: `src/keccak_engine/keccak_dual_interleaved.sv`
- RTL interface and controller: `src/keccak_engine/keccak_core.sv`
- Algorithm parameters: `src/keccak_engine/keccak_pkg.sv`
- Round datapath: `src/keccak_engine/keccak_step_unit.sv`
- Complete dual-core source regression: `sim/run.do`
- Dual-core post-synthesis simulation: `sim/run_post_synthesis.do`
- Dual-core post-fit timing simulation: `sim/run_post_fit.do`
- Dual-core Quartus project: `quartus/dual_interleaved/keccak_dual_interleaved.qsf`
- Dual-core timing constraints: `quartus/dual_interleaved/keccak_dual_interleaved.sdc`
- Living engineering record: `keccak-design-and-verification.md`
- Verification requirements: `KECCAK_VERIFICATION_TESTPLAN.md`
- LightHD paper: DOI `10.1109/TC.2026.3666457`

If this document disagrees with RTL or reproducible generated reports, the RTL and corresponding tool reports take precedence. Update this specification whenever the interface, architecture, accepted synthesis checkpoint, throughput model or verification status changes.
