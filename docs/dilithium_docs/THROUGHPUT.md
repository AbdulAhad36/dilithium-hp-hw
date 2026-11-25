# Current operation clocks and performance

## Measurement status

The current Cyclone V 5CGXFC7C7F23C8 fit reaches 97.10 MHz in the slowest
corner. Setup slack is -3.799 ns at the 6.500 ns constraint. The target
is 150+ MHz with positive setup slack. Board throughput remains unmeasured.

The table uses the current 345-command main capture in
`sim/dilithium/main_outputs.txt`. The readable output is
`sim/dilithium/outputs_hw.txt`.

| Operation | Level | Cases | Minimum clocks | Mean clocks | Maximum clocks |
|---|---:|---:|---:|---:|---:|
| KeyGen | 2 | 25 | 8,002 | 8,070.20 | 8,158 |
| KeyGen | 3 | 25 | 13,852 | 13,927.64 | 14,008 |
| KeyGen | 5 | 25 | 21,795 | 21,931.76 | 22,042 |
| Sign | 2 | 60 | 19,090 | 60,646.83 | 225,139 |
| Sign | 3 | 60 | 28,396 | 86,514.70 | 352,467 |
| Sign | 5 | 60 | 42,004 | 126,347.90 | 305,135 |
| Verify, valid only | 2 | 6 | 9,398 | 10,840.17 | 12,410 |
| Verify, valid only | 3 | 6 | 13,993 | 16,170.33 | 17,221 |
| Verify, valid only | 5 | 6 | 21,676 | 22,604.17 | 24,790 |

Sign/Verify include both supported message modes. Invalid Verify early exits
are excluded from these Verify means. Sign means include the actual rejection
loops in the corpus; they are not a fixed worst-case execution bound. Counts
include the bench's framed transport/backpressure conditions. `CASE_PASS cycles`
is the per-case measurement; `PROGRESS clock` is the cumulative simulation clock.

## Convert clocks into time and rate

For a timing-clean operating frequency f in MHz and an operation taking C clocks:

```text
clock period (ns) = 1000 / f
latency (microseconds) = C / f
sequential operation rate (operations/second) = f * 1,000,000 / C
```

These formulas give a sequential rate ceiling for the specified traffic. They
do not demonstrate overlapping public commands, host bandwidth or board
throughput. Use a measured timing-clean clock, not the target frequency, for
claimed hardware performance. Internal four-lane throughput is not the same
quantity as complete KeyGen/Sign/Verify operations per second.

## Simulation runtime

Fast capture mode removes broad debug/wave overhead and caches unchanged
preparation/compilation. On the same 15 diagnostic cases, measured simulation
wall time was 18.092-23.893 seconds versus 80.844 seconds with broad debug
visibility, about 3.4-4.5x faster. Output bytes, retry records and operation clocks
were identical, and independent comparison passed. This is a host simulation
speed measurement; it changes neither hardware clocks nor fitted Fmax.

For commands see [OUTPUT_SIM_COMAPRE.md](OUTPUT_SIM_COMAPRE.md). Historical
physical measurements and experiment comparisons are in [PAST_BUILDS.md](PAST_BUILDS.md).
