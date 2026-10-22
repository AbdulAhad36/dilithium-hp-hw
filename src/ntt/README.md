# LightHD-inspired NTT source

This is the active source location for the four-butterfly, three-FIFO NTT
implementation selected through Stages 4 and 5. All six RTL dependencies are
in this directory. Stage 6 sampler/integration is pending. The older four-bank
design is archived at
`experiments/ntt_cleanup_archive/2026-10-12/legacy/src/ntt_engine/`.
Compile only this active implementation.

| File | Role |
|---|---|
| `ntt_pkg.sv` | Ring constants and NTT/INTT/PWM/Pre-NTT operation codes |
| `mod_mul.sv` | Q-specific modular multiplication |
| `butterfly_unit.sv` | CT/GS butterfly datapath |
| `twiddle_rom.sv` | Twiddle table |
| `ntt_core.sv` | Four butterflies, three FIFO stores, scheduling, Pre-NTT path |
| `ntt_engine.sv` | Serial coefficient input/output wrapper |

`OP_PRE_NTT` accepts only canonical residues of signed coefficients in
`[-4,4]`. An upstream sampler/controller must enforce this contract; the
current RTL uses a simulation assertion and does not provide a hardware
fallback for other values.

Run the simulation scripts from `sim/ntt_LightHD/` **with the working
directory set to `sim/`**; see its README. The independent Quartus project
is `quartus/ntt_LightHD/`. The Stage 3 experiment and exact fitted source
snapshot remain under `experiments/ntt_stage3/lighthd_fifo/evidence/`.

The scheduling logic is a reconstruction of the published LightHD structure.
The authors' RTL and decoder tables were unavailable, and this implementation
retains our own multiplier, butterfly, and PWM operand store.
