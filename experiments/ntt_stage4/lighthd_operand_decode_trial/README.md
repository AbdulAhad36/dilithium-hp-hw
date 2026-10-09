# Combined operand selector trial - 2026-10-10

Only ntt_core.sv differs from lighthd_tw_nonzero_checkpoint (140.69MHz).
Decode combined FIFO/coefficient selection at the FIFO read-launch edge.
The registered one-hot masks align with fifo_q*, source_*_q and tag[0].
Replace serial FIFO-word then coefficient selection with a masked OR mux.
PWM keeps butterfly A=0 and routes operand A into butterfly B; zeta is the
second PWM operand. No pipeline stage, interface, tag latency or cycle change.
Independent UVM routing/operand/writeback checker and golden model unchanged.
Main117/117, zero UVM errors/fatals,14checked covergroup types100%.
Python18/18cases,4608/4608coefficients. Raw code counts changed with the selector
implementation; see saved main report. No exclusions or failed-UCDB merges.
REJECTED after fresh map/fit/STA/paths: 137.87MHz worst(slow0),139.88MHz
slow85;2579ALMs,2101registers,5DSP,21M10Ks,37252memorybits.
Worst setup/hold/pulse slacks -2.253/+0.165/-0.555ns.
The saved140.69MHz/2427ALM/20M10K reference is faster and smaller.
Both slow-corner worst paths moved to Pre lookup(load_pack -> pre_product_q).
No pipeline/cycle changes. This candidate is saved, not selected. Nothing staged/committed.

Separate fresh UVM checker sensitivity runs detect corrupted operand and FIFO
writeback observations despite real correct outputs, with checked_jobs=0.
The coverage gate rejects all five deliberately bad jobs without added credit.
Their expected-failure UCDBs are not merged into the main passing database.
Core raw source counts: statements277/289, branches223/237, conditions65/102,
expressions28/29, FSM5/5states9/9transitions, toggles3293/3301.
Other instance counts unchanged. Toggle totals are raw Questa counts; the new
unpacked selector arrays are not listed as per-bit nodes in the toggle report.
Independent UVM still checks every registered operand and physical writeback.
Two new synthesis warnings report legacy source_a_q/source_b_q as unused; map
removes them. Existing ROM unused write-port and s_tlast warnings remain.

Map RAM summary identifies the extra32bits as tag[0].inverse8x4shift RAM.
It is not an added coefficient buffer or a one-hot selector ROM. New grouping
of delayed controls changes the inferred tag memory. Source/count evidence is
preserved here with the rejected fit.
