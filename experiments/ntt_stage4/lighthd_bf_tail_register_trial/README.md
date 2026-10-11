# Butterfly final delay register trial ? 2026-10-10

Base: `lighthd_write_select_prefetch_checkpoint`, 150.49 MHz, 2,475 ALMs,
worst setup -1.645 ns at the unchanged 5 ns clock. Only `butterfly_unit.sv`
changes; exact six RTL files and SHA256 hashes are saved here.

## Method

The baseline slow0 worst path starts at the packed kept-operand delay RAM and
passes through the final butterfly modular adder. Keep four existing delay
stages available for RAM inference, and express the fifth as separate operand
and mode registers with automatic shift recognition disabled on those nodes.
The total delay remains five clocks; multiplier/BF/issue-return remains 5/7/10.
No extra operation clock, arithmetic change, FIFO capacity change, interface
change, golden-model change, testbench change or timing-constraint relaxation.

Fresh map confirms a 4 x 96-bit shared butterfly delay RAM (384 bits), replacing
the baseline 5 x 96-bit RAM (480 bits). The tail attributes are recognized on
all four butterflies. This is physical mapping evidence, not timing closure.

## Fresh source verification

`uvm_bf_tail_register.log`: 118/118 checked jobs, zero UVM errors/fatals,
all fourteen implemented checked functional covergroup types 100%.
`compare_bf_tail_register.log`: 18/18 cases, 4,608/4,608 coefficients.
Core NTT/INTT/PWM/Pre cycles remain 267/267/75/236; no-stall wrapper cycles
remain 781/781/845/750. Existing independent negative-checker evidence is
retained, not freshly rerun for this trial.

The separate final-register block changes raw butterfly coverage denominators:
60/60 statements, 19/19 branches and 752/752 toggles per butterfly. Core,
wrapper and multiplier coverage retain their prior counts. No exclusions.

## Fitted result: rejected

Fresh fit completed 2026-10-10 05:22:14. Resources: 2,468 ALMs,
2,549 registers, 5 DSPs, 20 M10Ks, 37,229 RAM bits. Slow85/slow0 Fmax
143.70/147.56 MHz; setup -1.959/-1.777 ns at the unchanged 5 ns clock.
Worst all-corner hold +0.129 ns; pulse width -0.555 ns.
Setup TNS is -889.425/-973.168 ns (slow85/slow0).

Slow85 now limits at pre_v1 -> FIFO1 RAM data; slow0 limits at
bf_ai_q[1][0] -> butterfly[1].mul_gs_reg[0], the GS input subtract path.
Pre control -> FIFO1 data is a close second path at slow0 (-1.772 ns).
Worst setup worsens 0.314 ns against the selected -1.645 ns checkpoint,
despite slightly improved TNS and lower ALMs. The final delay register
removes the original RAM-to-adder critical path but does not improve overall
worst timing. Preserve this trial; do not select it.
