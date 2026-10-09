# Direct FIFO route decoder trial - 2026-10-10

Alternative to the selected 145.73 MHz keep-bias checkpoint. Only ntt_core.sv
changes: explicit stage/issue-bit route decoding replaces variable shifts,
and FIFO synchronous read enables use direct Boolean source routes.
Pipeline and operation cycles are unchanged. Three coefficient FIFOs remain.

Fresh main UVM: 118/118 jobs, zero errors/fatals, fourteen checked covergroup
types at 100%. Independent Python: 18/18 cases, 4608/4608 coefficients.
Separate operand and physical-writeback corruption tests both reject correctly
without checked coverage credit. Failed UCDBs are separate.

| Metric | Selected keep-bias | Direct route trial |
|---|---:|---:|
| Worst Fmax MHz | 145.73 | 140.43 |
| Slow 85 C Fmax MHz | 145.73 | 141.06 |
| Slow 0 C Fmax MHz | 146.01 | 140.43 |
| ALMs | 2568 | 2436 |
| Registers | 2117 | 2150 |
| DSP / M10K | 5 / 21 | 5 / 20 |
| RAM bits | 37252 | 37216 |
| Worst setup at 5 ns | -1.862 | -2.121 |
| Worst all-corner hold ns | +0.104 | +0.163 |
| Worst pulse-width at 5 ns | -0.555 | -0.555 |

132 fewer ALMs and one fewer M10K, but worst Fmax falls 3.64%; not selected
for speed. The 9x4 valid-tag RAM disappears; 8x4 inverse-tag RAM remains.
Coefficient storage capacity is unchanged. M10K count is not FIFO/bank count.
Both slow-corner worst paths now run load_pack -> pre_product_q (Pre lookup).
Same Cyclone V device, Quartus 25.1std Lite, fit settings and 5 ns constraint.

Raw core coverage: statements 295/307, branches 232/245, conditions 53/84,
expressions 51/52, FSM states 5/5, transitions 9/9, toggles 3405/3683.
Changed source changes denominators; 278 missed toggle bins remain (272
constant selector bits plus six constant scalar selector bits). No exclusions.

Exact RTL and results are archived here. Original logs are route_decode_*.log
in quartus/ntt_LightHD and *_route_decode.log in sim/ntt_LightHD.
No netlist or FPGA claim. Nothing staged or committed.
