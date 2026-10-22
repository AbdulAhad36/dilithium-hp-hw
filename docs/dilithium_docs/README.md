# Dilithium integration

Stage5N.3 adds sign_process_dma to the main-owned service and shares its existing
four banks. Canonical low/high/hint storage,checked reads,error rollback,leases,
all-write acknowledgments and atomic Decompose publication are verified.
New gates:71 DMA commands/32 checker faults and33 shared-service commands/33
checker faults. The service uses actual SHAKE/sampling;main Sign is still pending.
All six current gates pass;all75 official KeyGen cases match433600 exact bytes.
Frozen evidence:evidence/stage5n3_sign_memory.zip and its.sha256 sidecar.
See [MEMORY_MAP.md](MEMORY_MAP.md) for the updated diagram,
[SPECIFICATION.md](SPECIFICATION.md) for internal commands/error codes and
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for execution/results.
Next Stage5N.4:signing key/input decode and hash formatting. Earlier milestone
paragraphs below describe their historical state.

Stage5N.2 implements and verifies Decompose x4,CNB and Mhint through the new
sign_process unit:7752 accepted groups,117 complete polynomials,45 intentional
errors,6 resets and27 checker faults. Local KeyGen and all75 official NIST
keypairs also freshly pass. The process unit is not yet connected to shared
bank DMA or main Sign. Next Stage5N.3:checked memory/lease/commit integration.
See [PROCESS_BLOCKS.md](PROCESS_BLOCKS.md) for the arithmetic and
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for execution/results.

Stage5N.1 moves physical engine/bank/Bitpkg ownership to dilithium.sv through
the new typed shared-service boundary. All75 NIST keypairs and the local
reset/recovery plus both diagnostic gates pass. Cleanup ownership is checked
after main completion acceptance. [ARCHITECTURE.md](ARCHITECTURE.md) shows the
new structure;[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) records
the four current-source gates. Next Stage5N.2:Decompose x4,CNB and Mhint.
Sign/Verify remain unimplemented;no PPA claim or commit accompanies this step.

Stage5M:all75 official NIST KeyGen cases pass,25 each for ML-DSA-44/65/87.
433600 complete public/secret-key bytes match;39 checker corruptions reject.
Use selector nist_keygen in the same launcher/script. Corpus,provenance and
run commands are in [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).
RTL is unchanged from Stage5L. Next:shared-resource Sign integration.

Stage5L now produces complete encoded public and secret keys with
dilithium(FULL_KEYGEN=1),using existing banks,Bitpkg and the shared Keccak.
Selector5/full_keygen:8 complete keypairs at all levels match unchanged C
KeyGen;3 rejects,5 resets,5433 exact64-bit key words and35 checker faults PASS.

Use [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) for prepare,Questa
capture and Python comparison. Main output ports are documented in
[SPECIFICATION.md](SPECIFICATION.md). Earlier diagnostic modes remain available.

Stage5M completes the official-vector follow-up described above.
Next:Sign and its remaining LightHD process blocks.
This milestone has no new synthesis/PPA/full-system UVM result.

Stage5K connects post-sum Power2Round in the ROUND_OUTPUTS=1 path and retains
all t1/t0 arrays in the existing banks. Selector5/rounded_keygen checks34 rows,
190224 scalar values and12800 exact92-bit reads;36 checker faults rejected.

process/bitpkg.sv now implements t1,t0 and secret polynomial encodings.
Selector5/bitpkg:97 commands,60 successful packets,31 expected errors and6
aborts;2482 exact64-bit words.66 valid fixture encodings/18496 bytes match the
unchanged C packers.15 checker corruptions rejected. Commands and scope:
[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).

The Stage5K bank-to-Bitpkg and full-key serialization follow-up is completed
by Stage5L above. Earlier stage descriptions below are historical milestones.

Stage5J adds real `controller/keygen.sv` and main FSM `dilithium.sv`.
The autonomous polynomial phase expands xi,samples all s1/s2,retains/transforms
s1,processes all matrix rows,and returns t=A*s1+s2 at levels2/3/5.
Selector5/keygen:7 complete operations,3 rejects,4 resets;34 rows,
172304 exact scalar writes and8448 exact92-bit reads;29 checker faults PASS.

The active banked controller is now memory.sv;its primitives,datapath helpers
and legacy scalar tests are in dedicated subfolders. process/power2round.sv
contains working P2R arithmetic. Sign/Verify and the requested LightHD CNB,
Decompose x4,Mhint and Bitpkg files are planned for their working integration
steps. Key encoding and complete KeyGen outputs remain next.
Commands/scope:[REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md).

Stage5I now connects RTL seed expansion and message formatting to the real
banked sampling/NTT/row path. Select5/seed_row:20 seed expansions,2560 exact
SHAKE bytes,163 RTL-formatted samples and13 successful row outputs PASS.
Seven adapter errors,27 row rejections and7 row reset/recovery cases pass;
23 seed-path checker corruptions are rejected. Existing eleven gates remain
separate regressions. Commands/results:REFERENCE_VERIFICATION.md.

Next:autonomous KeyGen scheduling,all s2 nonces,s2 addition,rounding and key
encoding. The bench still schedules row/NTT descriptors;full KeyGen bytes and
new PPA/full-system UVM coverage are not claimed.

Stage5H now schedules whole staged rows through PWM -> reusable accumulator
ADD -> inverse NTT. It reuses retained secret transforms and one product scratch.
Select5/row:13 full rows,27 rejections,7 reset aborts and12544 exact92-bit public
readbacks PASS. Six full reference rows also match schoolbook multiplication;
26 checker corruptions rejected. Output is u=A*s1 before s2 addition. Next:
shared seed/message scheduling,s2 addition,rounding and first full KeyGen encoding.
Commands/results:REFERENCE_VERIFICATION.md. No new synthesis/PPA/full-KeyGen claim.

Stage5G connects ADD/SUB/Power2Round to the same banks,with stored low/high
outputs and real NTT chains. Select5/bank_process.23 samples,15 NTT commands,
71 process commands(34 successes,33 expected rejections,4 aborts),8512 exact
92-bit reads PASS. Python/C agree on8976 completed arithmetic results;29 checker
corruptions rejected. Next:row accumulation scheduling,then the first full
level2 KeyGen controller(Stage5H above now adds row scheduling).
Execution/results:REFERENCE_VERIFICATION.md.

Stage5F now connects real sampling -> four banks -> NTT/INTT/PWM/Pre -> four
banks. Select stage5/bank_ntt in the existing launcher and Python comparison.
16 sample jobs,54 compute commands,30 results,21 expected rejections,3 reset
aborts and2944 exact92-bit readbacks PASS;19 checker corruptions rejected.
Source/destination leases and packed write acknowledgements are checked.
Stage5G above completes banked process arithmetic/writeback;row scheduling is next.
See REFERENCE_VERIFICATION.md for commands. No new PPA or full KeyGen claim.

Processing reference:[PROCESS_BLOCKS.md](PROCESS_BLOCKS.md). Dimensioned shared
memory diagram,ports and lifetimes:[MEMORY_MAP.md](MEMORY_MAP.md).

Stage5D:user selected LightHD memory:four1024x92-bit dual-port logical banks,
46KiB total. The bank foundation passes14872 requests/9509 exact reads plus
collision/stall/reset checks. Main controller/DMA migration remains next;
the Stage4 connected regression still uses its old four-slot pool.
Use DILITHIUM_STAGE5,DILITHIUM_TEST bank_memory and Python --stage 5 --unit bank_memory;
see REFERENCE_VERIFICATION.md for exact commands. No new PPA or full KeyGen claim.

This is the universal documentation set for the `integration` branch. Add each
integration milestone to these documents as the complete design grows.

Stage5E now connects real Keccak/sampling to the four-bank memory through
per-context word packing and checked region ownership.104 jobs/88 complete/
5632 exact92-bit readbacks PASS. Select stage5/bank_store using the commands
in REFERENCE_VERIFICATION.md. Stage5F above adds NTT DMA/compute ownership;
default Stage4 still preserves the old scalar-pool regression.

| Document | Purpose |
|---|---|
| [DILITHIUM_PLAN.md](DILITHIUM_PLAN.md) | Agreed layout,stages,decision gates and next work |
| [SPECIFICATION.md](SPECIFICATION.md) | Imported source provenance,current interfaces and relocation results |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Current connected datapath,ownership,bridge and drain contract |
| [MEMORY_MAP.md](MEMORY_MAP.md) | Approved Stage3 slot memory,ownership,readback and measured results |
| [PROCESS_FLOW.md](PROCESS_FLOW.md) | Current transaction steps and planned algorithm processing |
| [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) | One-script prepare/capture/compare flow and measured results |
| [INTEGRATION_VERIFICATION_TESTPLAN.md](INTEGRATION_VERIFICATION_TESTPLAN.md) | Focused integration requirements/checks;later full UVM scope |
| [THROUGHPUT.md](THROUGHPUT.md) | Current cycle witnesses and combined implementation measurements |
| [PIN_CONFIG.md](PIN_CONFIG.md) | Current subsystem top ports and virtual-pin assignments |

Comprehensive coverage documentation will be added when that work begins.
Do not create a separate documentation suite for each module pair.

Stage5C now adds tested shared raw-SHAKE routing and seed collection. Select
`set DILITHIUM_STAGE 5` and `set DILITHIUM_TEST shared_hash` in the existing launcher;
use Python --stage 5 --unit shared_hash.26 commands,1699 hash bytes and1792
coefficients derived from RTL-collected seeds pass. Main top ports/memory are
unchanged;the memory choice is now resolved above. Full commands:REFERENCE_VERIFICATION.md.

Current direction (2026-10-20):integrate for correct functionality and outputs
first,then optimize Fmax,area and throughput. Stage4 all-engine functional checks
pass;next is Stage5 algorithm audit/controller/process work. The open148MHz
goal does not block that work.

Stage5A has now completed the initial audit and shared arithmetic unit tests:
10349 accepted cases,10346 outputs,3 reset aborts and13 expected errors.
Final FIPS204 ML-DSA-44/65/87 bytes are selected,with level2/3/5 names.
Stage5B's isolated KeyGen message formatter passes165 commands and5888 SHAKE
bytes;see REFERENCE_VERIFICATION.md for execution and limits. MEMORY_MAP.md's
KeyGen storage schedule remains a proposal needing a major architecture choice.
Selector5 tests process by default,or hash_format with DILITHIUM_TEST;the default4
continues to test the current all-engine connected subsystem.

Current runnable projects are standalone:

- Keccak: [simulation](../../sim/keccak/README.md),
  [Quartus](../../quartus/keccak/README.md).
- Sampler: [simulation](../../sim/sampler/README.md),
  [Quartus](../../quartus/sampler/README.md).
- NTT: [simulation](../../sim/ntt/README.md),
  [Quartus](../../quartus/ntt/README.md);source/UVM relocated unchanged from ntt_v2.

The current connected Stage4 top is src/controller/keccak_sampler_ntt.sv;
focused tests use [sim/dilithium](../../sim/dilithium/README.md),and the evolving
combined project is [quartus/dilithium](../../quartus/dilithium/README.md).
The main algorithm controller and remaining process blocks follow the shared
roadmap. Standalone metrics are not system metrics.
