# Registered FIFO compute-word trial - 2026-10-10

Base: selected lighthd_fold_pipeline_checkpoint (148.46 MHz, 2490 ALMs).
Only ntt_core.sv changes. The committed checkpoint c2cccd2 remains preserved.

## Change

The measured worst path was return tag[9].pwm -> late word selection -> FIFO2
RAM data input. Reassemble the same A/B words combinationally, preserving the
original held B value during PWM. In the existing result register stage,
preselect each FIFO's compute word using tag[8] PWM/destination. Return-stage
push_word selection then uses the registered word rather than late PWM and
destination decoding. Load/Pre/compute priority and push controls are unchanged.
Registered result_a/b remain for the independent inverse-half observations.

No extra stage: multiplier/BF/return5/7/10, core267/267/75/236 and wrapper
781/781/845/750 unchanged. No interface, FIFO capacity, golden arithmetic or
reference-file changes. Main UVM still independently checks actual operands,
all mathematical physical writes, complete final outputs and framing.

## Source verification

uvm_return_words.log passes118/118,zero errors/fatals,fourteen checked groups
at100%. vector_return_words.log / compare_return_words.log passes18/18cases,
all4608coefficients. routing_writeback_return_words.log deliberately corrupts
one observed write word while real output remains correct: checker PASS,
checked_jobs=0. Its failed UCDB is separate and not merged.
Earlier unchanged fault-credit/operand/GS/Pre-eligibility evidence remains
preserved; those tests are not newly rerun here.

Core raw coverage:306/318statements,232/245branches,53/84conditions,
51/52expressions,5/5states,9/9transitions,4325/4603toggles. Compared with the
base,11new statements are hit and920new toggle bins are hit (460new signal
bits x two directions). The same278constant-bit misses remain. Source changes
alter denominators; no exclusions. Other DUT instance counts are unchanged.

## Fitted result: rejected

Fresh map/fit/STA and both slow-corner critical paths completed 2026-10-10.
Worst Fmax 141.80 MHz (slow85), slow0 143.25 MHz; 2630 ALMs, 2581 registers,
5 DSP, 20 M10K, 37325 RAM bits. At the unchanged 5 ns constraint, worst
setup -2.052 ns, all-corner hold +0.163 ns, pulse width -0.555 ns.
Worst slow85 path moved to pre_v1 -> FIFO1 RAM data; slow0 instead limits
at BF kept-data RAM -> BF output. Compared with the selected 148.46 MHz
checkpoint, Fmax fell 6.66 MHz and setup worsened 0.316 ns. Do not select.
The exact RTL, verification evidence and fitted reports are retained here.
