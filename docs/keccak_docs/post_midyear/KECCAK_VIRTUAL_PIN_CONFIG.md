# Keccak dual-core virtual pin configuration

This table describes the current synthesis top, `keccak_dual_interleaved`,
for Cyclone V `5CGXFC7C7F23C8`. Widths are the current default parameter
values from `keccak_pkg.sv` and `keccak_dual_interleaved.sv`.

The Quartus file `quartus/dual_interleaved/keccak_dual_interleaved.qsf`
marks every interface signal below **virtual**, except `clk`. Virtual pins
are logical ports used for core-level synthesis and timing; they are **not**
assigned FPGA package pads. `clk` is not marked virtual, but the QSF has no
physical `set_location_assignment` for it either. This is not a board pin map.

| Top-level signal | Direction | Width | Virtual? | Meaning |
|---|---|---:|---|---|
| `clk` | Input | 1 | No | Clock for both cores and the wrapper. No package pad assigned yet. |
| `rst` | Input | 1 | Yes | Active-high reset. |
| `request_valid_i` | Input | 1 | Yes | New SHAKE job request is available. |
| `request_ready_o` | Output | 1 | Yes | Wrapper can accept a job; acceptance occurs when valid and ready are both high. |
| `request_core_o` | Output | 1 | Yes | Core selected for the next accepted request: 0 or 1. |
| `keccak_mode_i[0]` | Input | 1 | Yes | `0` selects SHAKE128; `1` selects SHAKE256. |
| `message_len_i[15:0]` | Input | 16 | Yes | Number of input message bytes for the new job. |
| `output_len_i[15:0]` | Input | 16 | Yes | Requested output bytes; zero selects continuous output until stopped. |
| `input_data_i[63:0]` | Input | 64 | Yes | Shared input data, up to eight message bytes per accepted beat. |
| `input_valid_i` | Input | 1 | Yes | Input data beat is available. |
| `input_ready_o` | Output | 1 | Yes | Wrapper can accept the input beat; transfer occurs with valid high. |
| `input_core_o` | Output | 1 | Yes | Core currently receiving the shared input stream. |
| `stop_i[1:0]` | Input | 2 | Yes | Stop request for each core in continuous-output mode; bit 0 is core 0. |
| `core_busy_o[1:0]` | Output | 2 | Yes | Per-core busy status; bit 0 is core 0. |
| `core_done_o[1:0]` | Output | 2 | Yes | Per-core completion indication; bit 0 is core 0. |
| `busy_o` | Output | 1 | Yes | High when either core is busy. |
| `output_data_o[127:0]` | Output | 128 | Yes | Shared output data beat. |
| `output_valid_o` | Output | 1 | Yes | Output beat is available. |
| `output_bytes_o[4:0]` | Output | 5 | Yes | Number of valid bytes in the current 128-bit output beat. |
| `output_core_o` | Output | 1 | Yes | Source core tag for the shared output beat. |
| `output_ready_i` | Input | 1 | Yes | Receiver accepts output when valid and ready are both high. |

The data buses are shared at the wrapper boundary. The two `keccak_core`
instances have separate internal connections, but no separate external
input or output bus pins.
