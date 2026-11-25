# Dilithium synthesis

Open `dilithium_full.qpf` in Quartus and choose Processing > Start Compilation.
The production top is `dilithium_fpga`; its current controller is
`src/controller/dilithium.sv`. The project source list includes all three
operations and the shared Keccak, NTT, sampler, Process and memory resources.

The device remains Cyclone V 5CGXFC7C7F23C8 with the existing 6.500 ns target
and unchanged hold constraints. `report_full.tcl` checks retained hardware
and reports all timing corners. The alternate `dilithium.qpf` uses the
same production source list.

Current-source physical qualification is pending. Generated output directories
are not proof that their reports match the live source. Protected source-bound
evidence is retained separately; its index is in docs/dilithium_docs/PAST_BUILDS.md.
Source renaming alone is not a new fit. Keep stable production filenames when
promoting an accepted improvement and preserve the replaced build in evidence.
