# All butterfly delay stages in registers ? 2026-10-10

Base: saved `lighthd_write_select_prefetch_checkpoint` (150.49 MHz,
2,475 ALMs, setup -1.645 ns at 5 ns). Only `butterfly_unit.sv` changes.
Exact six RTL files and SHA256 hashes are retained here.

## Method

The measured slow0 worst path is packed butterfly kept-operand delay RAM
through routing and the final modular adder to a_o. Disable automatic shift
register recognition on the butterfly_unit entity so its short operand/mode
delays stay in registers. The Intel Standard Edition compilation guide documents
this entity attribute in [Using altera_attribute to Set Intel Quartus Prime Logic
Options](https://docs.altera.com/r/docs/683283/18.1/intel-quartus-prime-standard-edition-user-guide-design-compilation/using-altera_attribute-to-set-intel-quartus-prime-logic-options?contentId=t3Rv0yFyeC1Ik6iypY7qYA).

No arithmetic, reset behavior, delay length, FIFO capacity, clock constraint,
external interface, TB, golden model or reference output change. The pipeline
remains multiplier/BF/return 5/7/10; core 267/267/75/236, wrapper 781/781/845/750.
Source simulation alone cannot establish the physical benefit of this mapping.

## Fresh source verification

Main `uvm_bf_register_delay.log` passes 118/118, zero UVM errors/fatals,
all fourteen checked functional covergroup types 100%. Separate
`vector_bf_register_delay.log` / `compare_bf_register_delay.log` passes
18/18 cases, 4,608/4,608 coefficients and confirms unchanged operation cycles.
Raw coverage denominators/hits are unchanged from the selected baseline because
the synthesis directive adds no executable SV behavior. Independent golden/TB
mathematics are unchanged. Existing separate negative-checker evidence remains
retained, not freshly rerun for this trial.

## Fitted result: rejected

Fresh mapping confirms BF delay RAM is absent; core tag delay RAM remains.
Fit completed 2026-10-10 05:14:31. Resources: 2,418 ALMs, 2,929 registers,
5 DSPs, 17 M10Ks, 36,845 RAM bits. Slow85/slow0 Fmax 136.78/140.10 MHz.
At unchanged 5 ns, setup slow85/slow0 = -2.311/-2.138 ns; worst hold +0.129 ns,
pulse -0.555 ns. Both corners now limit at pre_upper_q1 -> FIFO1 RAM data.
Next paths include Pre operand/product -> Pre subtract result.

Setup TNS improves to -783.296/-828.230 ns (slow85/slow0) from baseline
-919.242/-1002.192 ns, but worst setup worsens 0.666 ns. TNS is the sum of
negative endpoint setup slacks within each corner, not an operation latency.
It cannot justify selecting a worse maximum delay. Preserve but reject this
mapping; baseline 150.49 MHz / -1.645 ns remains the selected checkpoint.
