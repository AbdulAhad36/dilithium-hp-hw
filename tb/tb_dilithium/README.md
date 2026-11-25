# Focused Dilithium verification

The complete reusable UVM environment is in `tb_uvm/tb_uvm_dilithium/`.
This directory contains the independent file-capture and focused block checks.

| Location | Contents |
|---|---|
| `tb_main.sv` | Complete RTL NIST input/output capture used by `sim/dilithium/run.do` |
| `tb_keygen.sv` | Standalone KeyGen capture |
| `tb_sign.sv` | Standalone Sign capture |
| `tb_sign_protocol.sv` | Sign framing/reset/error capture |
| `unit/` | Reusable block, arithmetic, queue, memory and timing tests |
| `support/` | Bank/service fixtures and compatibility wiring |
| `reference/` | Independent C oracles and frozen SystemVerilog reference models |
| `reference/legacy/` | Historical reference models retained for traceability |

The current Python vector tool resolves these locations. Reference models
retain their independent provenance and must not be rewritten to match a DUT
change. Frozen evidence runners are replayed against their own source snapshot.

For manual NIST output inspection, start with `tb_main.sv`. For UVM stimulus,
monitoring, checking and coverage, use the separate component files documented
in `tb_uvm/tb_uvm_dilithium/README.md`.
