# Evolving Dilithium synthesis project

Open `dilithium.qpf` in Quartus GUI and choose **Processing > Start Compilation**.
The current top is `keccak_sampler_ntt` (Stage4). The project will grow to the full
controller/memory/process/NTT system as those parts are implemented.

Initial target chosen by the user:about148MHz,permanent6.757ns SDC for this
baseline. No manual SDC edit is needed. Seed1,HIGH PERFORMANCE EFFORT,
Cyclone V5CGXFC7C7F23C8.294 non-clock bits are virtual.
Virtual data I/O timing is excluded;this is an internal timing benchmark.

Stage4 all-engine source/Python checks pass,but its synthesis/fit has not been run.
Existing output_files reports are the earlier Stage2 producer-only build and
must not be reported as current Stage4 PPA. report_paths.tcl refuses an old
database lacking memory metadata or the NTT datapath. Full-system optimization
remains deferred;the project is prepared for GUI compilation when needed.

The first fit missed timing at129.18MHz/-0.984ns setup. On2026-10-20 the user
superseded timing-first work:integrate for functionality and full-operation
outputs,then optimize Fmax/area/throughput. Timing closure does not block memory.
Historical Stage2 trial8:global retiming OFF,Keccak hierarchy ON,
sampler hierarchy OFF,physical combinational synthesis/duplication ON,and
maximum router timing effort. Ordinary clock-enable mapping is restored;
each Keccak core predecodes absorb-ready without adding a processing cycle.
The lane-write and forced-global-enable trials were rejected and removed.
Keccak's launch-offset-zero flag is registered without changing launch gaps.
The helper has a two-slot register queue with registered-credit upstream ready.
Command ready relies on ownership,with sampler-readiness equivalence asserted
in source simulation. The main project uses seed1;its completed fit has11293
placed ALMs,137.74MHz worst Fmax,-0.503ns setup and+0.157ns hold. Structural
guards pass;timing remains open. The isolated seed2 compile also finished;
it is not selected. No build remains active and no further timing experiment
is planned before functional integration. This is not a timing-closed baseline.

Read **[A] ALMs used in final placement** for area,all-corner TimeQuest setup/
hold/TNS and both slow-corner Fmax summaries. A positive source-test result does
not establish FPGA Fmax. Run `quartus_sta -t report_paths.tcl` from this folder
to check the accepted sampler's payload/register guards inside the combined top.

Current measurements and limitations belong in the universal
docs/dilithium_docs/THROUGHPUT.md. Standalone module reports remain standalone;
they do not define system area or timing.
