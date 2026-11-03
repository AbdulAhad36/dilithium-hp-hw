# Dilithium synthesis

Open `dilithium_full.qpf` in Quartus and choose Processing > Start Compilation.
The production top is `dilithium_fpga`; its current controller is
`src/controller/dilithium.sv`. The project source list includes all three
operations and the shared Keccak, NTT, sampler, Process and memory resources.

The device remains Cyclone V 5CGXFC7C7F23C8 with the existing 6.500 ns target
and unchanged hold constraints. `report_full.tcl` checks retained hardware
and reports all timing corners. The alternate `dilithium.qpf` now uses the
same production source list rather than the retired Stage4 subsystem.

Existing generated reports predate source cleanup/renaming. The latest
qualified timing evidence is in the protected timing-screen workspace,
not necessarily `output_full`. Source renaming alone is not a new fit.
