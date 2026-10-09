# NTT pin configuration

**Stage 4, 2026-10-09.** Top: `src/ntt_LightHD/ntt_engine.sv`.
This table describes the logical top-level pins and their purpose.

The current `quartus/ntt_LightHD/ntt.qsf` does **not** declare these as Quartus
virtual pins. The fitted report says **59 total pins, 0 virtual pins** and
warns that no exact package locations have been assigned for all 59 pins.
Do not interpret this table as a board package pinout. Adding virtual-pin
assignments later changes the implementation settings and requires a fresh fit.

| Signal / pin group | Direction | Width | Purpose |
|---|---|---:|---|
| clk | input | 1 | Main rising-edge clock |
| rst | input | 1 | Active-high asynchronous reset / job abort |
| start_i | input | 1 | Start a job when idle |
| op_i[1:0] | input | 2 | 0 NTT, 1 INTT, 2 PWM, 3 bounded-secret Pre-NTT |
| busy_o | output | 1 | Engine is processing a job |
| done_o | output | 1 | One-clock completion pulse |
| s_tdata[22:0] | input | 23 | Input coefficient, canonical residue 0..q-1 |
| s_tvalid | input | 1 | Input coefficient is valid |
| s_tlast | input | 1 | Compatibility input; ignored by current RTL |
| s_tready | output | 1 | Engine can accept the input coefficient |
| m_tdata[22:0] | output | 23 | Output coefficient |
| m_tvalid | output | 1 | Output coefficient is valid |
| m_tlast | output | 1 | Output coefficient is index 255 |
| m_tready | input | 1 | Receiver can accept the output coefficient |

Input bits: `1+1+1+2+23+1+1+1 = 31`.
Output bits: `1+1+1+23+1+1 = 28`. Total: **59**, matching the fitter report.
There is no internal coefficient FIFO or butterfly signal exported as a pin.

The clock constraint is 5 ns in `quartus/ntt_LightHD/ntt.sdc`. All input/output
paths are false-pathed for this standalone core benchmark; this does not verify
a real board I/O timing budget. Board validation needs actual package locations,
I/O standards and external timing requirements. See [SPECIFICATION.md](SPECIFICATION.md)
for the transfer contract and [the plan](POST_MIDYEAR_VERIFICATION_PLAN.md) for gates.
