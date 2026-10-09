# Sum-split-only candidate: rejected as a performance improvement

2026-10-09. Independent verification passed: main UVM 115/115, all thirteen
implemented functional covergroup types 100%, Python comparison 18/18 cases
and 4,608/4,608 coefficients. Core/wrapper cycles stayed unchanged.

Same Cyclone V device, Quartus version and 5 ns clock constraint as baseline:

| Metric | Accepted baseline | Sum split only |
|---|---:|---:|
| ALMs | 3,003 | 2,979 |
| Registers | 1,973 | 1,971 |
| DSPs | 6 | 6 |
| M10Ks | 20 | 20 |
| Worst-corner Fmax, MHz | 96.56 | 95.00 |
| Worst setup slack, ns | -5.356 | -5.526 |
| Worst hold slack, ns | +0.087 | +0.134 |

The slow 85 C critical path moved from the butterfly sum to multiplier
`prod_s1[23] -> t2_q[26]`, the stage performing two reduction folds. The active
next candidate combines this sum split with a multiplier pipeline rebalance:
fold 1 in stage 2, folds 2/3 in stage 3, fold 4/final reduction in stage 4.
This directory preserves the intermediate result, not a selected improvement.
The remaining four RTL sources match `../lighthd_before_sum_split/`.
