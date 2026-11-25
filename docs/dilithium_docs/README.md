# Dilithium integration

This folder describes the current integrated KeyGen, Sign and Verify design.
The production top is `src/controller/dilithium_fpga.sv`, containing the main
controller and one shared Keccak/sampler/NTT/Process/memory datapath. User level
names 2/3/5 select final FIPS 204 ML-DSA-44/65/87.

The current functional design supports external pure-message and internal-message
Sign/Verify inputs. The qualified functional campaign covers 345 supported cases:
75 KeyGen, 180 Sign and 90 Verify. Prehash and externally supplied mu are not
supported. This is simulation evidence, not FPGA-board acceptance. Physical
timing, placed area and full UVM coverage need qualification against the current
source revision; the target remains 150+ MHz with positive setup slack.

| Document | Read it for |
|---|---|
| [DILITHIUM_PLAN.md](DILITHIUM_PLAN.md) | Work order, gates, naming and evidence policy |
| [SPECIFICATION.md](SPECIFICATION.md) | Supported operations, parameters and interface contract |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Current controller, shared engines and data paths |
| [PROCESS_FLOW.md](PROCESS_FLOW.md) | KeyGen, Sign and Verify execution steps |
| [MEMORY_MAP.md](MEMORY_MAP.md) | Four-bank geometry, addresses, lifetimes and diagram |
| [PROCESS_BLOCKS.md](PROCESS_BLOCKS.md) | Arithmetic, packing, hints and formatting |
| [PIN_CONFIG.md](PIN_CONFIG.md) | Current production ports and virtual-pin configuration |
| [REFERENCE_VERIFICATION.md](REFERENCE_VERIFICATION.md) | Functional evidence and reference boundaries |
| [INTEGRATION_VERIFICATION_TESTPLAN.md](INTEGRATION_VERIFICATION_TESTPLAN.md) | Tests and acceptance criteria |
| [COVERAGE.md](COVERAGE.md) | Functional/code coverage model and reporting |
| [THROUGHPUT.md](THROUGHPUT.md) | Current operation clocks and measurement rules |
| [OUTPUT_SIM_COMAPRE.md](OUTPUT_SIM_COMAPRE.md) | Software, hardware and file-comparison commands |
| [PAST_BUILDS.md](PAST_BUILDS.md) | Historical experiment summaries and frozen evidence |

Active simulation files have descriptive names in `sim/dilithium/`. Open
`quartus/dilithium/dilithium_full.qpf` for the production Quartus project.
Current source paths and reusable individual module packages remain unchanged.
Historical reports and source freezes are separate from the current build and
must not be presented as fresh measurements of it.
