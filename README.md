# dilithium-hp-hw

M.Engg IC Design thesis (EL-08): hardware implementation of ML-DSA /
CRYSTALS-Dilithium in SystemVerilog on Cyclone V.

## Active NTT implementation (`ntt_v2`)

| Folder | Contents |
|---|---|
| `src/ntt_LightHD/` | Selected four-butterfly, three-FIFO NTT/INTT/PWM/Pre-NTT RTL |
| `tb_uvm/tb_uvm_ntt_LightHD/` | Finalized UVM environment, references and capture top |
| `tb_uvm/tb_uvm_reusable/` | Reusable UVM components |
| `sim/ntt_LightHD/` | Main UVM, post-synthesis and post-fit launchers |
| `quartus/ntt_LightHD/` | Quartus project, constraints, reports and netlists |
| `FIPS204_NTT/` | One Python prepare/compare script and independent reference vectors |

In the Questa Transcript:

```tcl
cd D:/GitHub/dilithium-hp-hw/sim
do ntt_LightHD/run_uvm.do
```

For Quartus GUI, open `quartus/ntt_LightHD/ntt.qpf` and use Start Compilation.
See [simulation instructions](sim/ntt_LightHD/README.md),
[Quartus instructions](quartus/ntt_LightHD/README.md) and the
[staged plan](docs/ntt_docs/post_midyear/POST_MIDYEAR_VERIFICATION_PLAN.md).
Stage 6 sampler/integration remains pending.

Older active-folder content is preserved in the
[cleanup archive](experiments/ntt_cleanup_archive/2026-10-12/README.md).
Historical experiments remain under `experiments/`.
