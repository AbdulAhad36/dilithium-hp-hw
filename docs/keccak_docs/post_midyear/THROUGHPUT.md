# Keccak Throughput

This document defines the throughput numbers used for the current dual-core
interleaved Keccak design. All byte rates use decimal GB/s, where
`1 GB/s = 1,000,000,000 bytes/s`.

**Evidence status (2026-09-27):** These are the last recorded byte-exact
source-simulation cycle counts, converted using the timing-clean 148 MHz
Quartus operating point. This documentation audit did not rerun the test.
No post-fit timing simulation, FPGA-board throughput or complete ML-DSA
throughput is claimed.

## Current Architecture

- Two independent Keccak-f[1600] cores are instantiated in the interleaved
  wrapper.
- Each core executes one Keccak round per clock.
- One permutation contains 24 rounds and therefore needs 24 round clocks.
- SHAKE128 has a 168-byte rate; SHAKE256 has a 136-byte rate.
- Jobs are independent. The wrapper dispatches them between the two cores.
- The second core is normally launched with a 26-cycle offset.
- The external input datapath is shared and 64 bits wide, or 8 bytes per beat.
- The shared output datapath is 128 bits wide, or 16 bytes per beat.
- The last fitted Quartus design closes the 148 MHz internal clock target.
  The simulation counts cycles and uses 148 MHz to convert them to GB/s.

## Two Different Throughput Numbers

### Permutation-only throughput

Permutation-only throughput is the theoretical rate-byte ceiling of the
Keccak permutation engines. It assumes each core produces one complete rate
block every 24 clocks and ignores command, input, output, arbitration, and
other controller cycles.

For `N` cores:

```text
permutation_only_GBps = rate_bytes * N * frequency_MHz / (24 * 1000)
```

At 148 MHz, the calculated ceilings are:

| Mode | One core | Two cores |
|---|---:|---:|
| SHAKE128 | 1.036000 GB/s | 2.072000 GB/s |
| SHAKE256 | 0.838667 GB/s | 1.677333 GB/s |

Example for dual-core SHAKE128:

```text
(168 bytes * 2 cores * 148 MHz) / (24 clocks * 1000)
= 2.072000 GB/s
```

This is useful as an architectural upper bound, but it is not the complete
Keccak throughput delivered by the implemented interface.

### Actual transfer-inclusive throughput

The main practical result is the transfer-inclusive throughput measured by
`tb_keccak_dual_throughput`. It includes:

- request acceptance and dispatch;
- transfer of each 32-byte message through the shared 64-bit input;
- absorb and squeeze permutations;
- two-core scheduling and output arbitration;
- transfer of all output through the shared 128-bit output.

The measurement does not include a future UART, FPGA host interface, memory
system, or the rest of ML-DSA. It is therefore the sustained throughput of the
complete implemented dual-core Keccak block in source-RTL simulation, evaluated
at the accepted 148 MHz post-fit clock.

## How `tb_keccak_dual_throughput` Measures It

The module is in `tb_uvm/tb_uvm_keccak_v2/tb_top.sv`. It is executed alongside
the functional regressions when `sim/run.do` runs `tb_top`.

For each SHAKE mode, `run_benchmark` performs these steps:

1. Clear the expected-output queues and byte counters.
2. Build two independent 32-byte messages.
3. Calculate the golden output for every byte with the independent
   `shake_compute` reference function.
4. Reset the dual-core DUT and submit one long-output job for each core.
5. Record `first_accept_cycle` when the first request is accepted.
6. Keep `output_ready` asserted and monitor every accepted 128-bit output beat.
7. Check the source-core tag, legal byte count, and every output byte against
   the expected queue.
8. Record `final_output_cycle` when all bytes from both jobs have been accepted.
9. Fail the test if data is wrong, a timeout occurs, or either result is below
   1 GB/s at 148 MHz.

The elapsed cycle count and throughput are:

```text
elapsed_cycles = final_output_cycle - first_accept_cycle + 1
total_bytes     = bytes_from_job_0 + bytes_from_job_1
bytes_per_cycle = total_bytes / elapsed_cycles
actual_GBps     = bytes_per_cycle * frequency_MHz / 1000
```

Keeping `output_ready` high measures the DUT's maximum sustained output rate.
It does not hide input, permutation, wrapper, or output-transfer overhead;
those cycles remain inside the interval from first accepted request to final
accepted byte.

## Measured Results

The current benchmark uses 65,520 output bytes per SHAKE128 job and 65,416
output bytes per SHAKE256 job. These are 390 SHAKE128 rate blocks and 481
SHAKE256 rate blocks per job, respectively. Long XOF outputs make the result a
sustained-throughput measurement instead of a short-message latency result.

| Mode | Total checked bytes | Measured cycles | Bytes/clock | Actual throughput at 148 MHz |
|---|---:|---:|---:|---:|
| SHAKE128 | 131,040 | 14,462 | 9.060987 | **1.341026 GB/s** |
| SHAKE256 | 130,832 | 16,867 | 7.756685 | **1.147989 GB/s** |

Detailed calculations:

```text
SHAKE128:
bytes_per_cycle = 131040 / 14462 = 9.060987
actual_GBps     = 9.060987 * 148 / 1000 = 1.341026 GB/s

SHAKE256:
bytes_per_cycle = 130832 / 16867 = 7.756685
actual_GBps     = 7.756685 * 148 / 1000 = 1.147989 GB/s
```

Relative to the permutation-only ceiling, the complete datapath sustains about
64.72% for SHAKE128 and 68.44% for SHAKE256. The remaining difference is real
interface, control, arbitration, and scheduling overhead.

These are aggregate dual-core results for two independent jobs. They must not
be presented as single-core throughput, single-job latency, or full-board
throughput.

## Reproducing the Result

From the `sim` directory, run QuestaSim 2024.1:

```text
C:\questasim64_2024.1\win64\vsim.exe -do run.do
```

The transcript must contain both `THROUGHPUT_RESULT` lines followed by:

```text
DUAL_THROUGHPUT_PASS: both modes exceed 1 GB/s at 148.00 MHz with byte-exact outputs
```

The most recent verified run completed with zero simulator errors and reported
the two results shown above.
