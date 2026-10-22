# Keccak module documents

These documents were imported from `keccak_v2` at
`fe54a782e3df9ed684dc960b0067b39ce323289d`. Their dated results and original
paths describe that standalone source branch; they were preserved on import.

On the `integration` branch the current standalone paths are:

| Original path | Current path |
|---|---|
| src/keccak_engine/ | src/keccak/ |
| sim/run.do and other Keccak launchers | sim/keccak/ |
| sim/nist_shake.py and its generated text files | sim/keccak/ |
| quartus/dual_interleaved/ | quartus/keccak/ |
| tb_uvm/tb_uvm_keccak_v2/ | Unchanged |
| NIST/ | Unchanged |

Use [the current standalone simulation instructions](../../sim/keccak/README.md)
and [Quartus instructions](../../quartus/keccak/README.md) for actual commands.
Fresh relocation results and all subsequent integration milestones belong in
[the universal Dilithium specification](../dilithium_docs/SPECIFICATION.md) and
[roadmap](../dilithium_docs/DILITHIUM_PLAN.md).

Historical standalone resource/timing/coverage figures are not full-design
Dilithium metrics. Existing SHAKE NIST checks do not validate complete ML-DSA.
